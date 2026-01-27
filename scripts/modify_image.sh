#!/bin/bash
set -e

IMAGE_FILE="$1"
BUILD_ARTIFACTS_DIR="$2"
PAYLOAD_DIR="$3"
INTERNAL_SCRIPT="$4"

if [ -z "$IMAGE_FILE" ] || [ -z "$BUILD_ARTIFACTS_DIR" ]; then
    echo "Usage: $0 <image_file> <artifacts_dir> <payload_dir> <internal_script>"
    exit 1
fi

# WSL Workaround: Copy image to native Linux FS to avoid loopback issues on /mnt/c
ORIGINAL_IMAGE="$IMAGE_FILE"
WORK_DIR=$(mktemp -d)
TEMP_IMAGE="$WORK_DIR/working.img"
# CRITICAL: Mount point must ALSO be in native FS, not on /mnt/c
MOUNT_DIR="$WORK_DIR/mnt"

echo "Copying image to temporary workspace ($WORK_DIR) for modification..."
cp "$ORIGINAL_IMAGE" "$TEMP_IMAGE"
IMAGE_FILE="$TEMP_IMAGE"

# 1. Expand the image (add 2GB space to ensure room for deps)
echo "Expanding image by 2GB..."
dd if=/dev/zero bs=1G count=2 >> "$IMAGE_FILE"

# 2. Setup Loop Device
echo "Setting up loop device..."
LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"
# Wait for partitions
sudo partprobe "$LOOP_DEV" || true
sleep 3
lsblk "$LOOP_DEV"

# 2.5 Resize Partition and Filesystem
echo "Resizing Root Partition to utilize new space..."
# Resize partition 2 (root) to 100% of the loop device
sudo parted -s "$LOOP_DEV" resizepart 2 100%
sudo partprobe "$LOOP_DEV" || true
sleep 2

# Resize EXT4 filesystem
echo "Resizing Filesystem..."
sudo e2fsck -f -p "${LOOP_DEV}p2" || true  # force check, preen
sudo resize2fs "${LOOP_DEV}p2"

clean_up() {
    # Extract Kernel and Initrd for QEMU testing
    echo "Extracting kernel for QEMU..."
    # We look for the newest kernel in the boot directory
    # We look for the newest kernel in the boot directory (check both firmware and root boot)
    KERNEL_PATH=$(ls -t "$MOUNT_DIR/boot/firmware/vmlinuz"* "$MOUNT_DIR/boot/firmware/kernel8.img"* "$MOUNT_DIR/boot/vmlinuz"* "$MOUNT_DIR/boot/kernel8.img"* 2>/dev/null | head -n1)
    INITRD_PATH=$(ls -t "$MOUNT_DIR/boot/firmware/initrd.img"* "$MOUNT_DIR/boot/initrd.img"* 2>/dev/null | head -n1)
    
    if [ -f "$KERNEL_PATH" ]; then
        cp "$KERNEL_PATH" "./kernel_qemu"
        cp "$INITRD_PATH" "./initrd_qemu"
        echo "Kernel extracted to ./kernel_qemu"
    else
        echo "WARNING: Could not find kernel in image to extract!"
    fi

    # Unmount pseudo-filesystems first
    echo "Unmounting..."
    sudo umount "$MOUNT_DIR/dev/pts" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/dev" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/proc" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/sys" 2>/dev/null || true
    
    sudo umount "$MOUNT_DIR/boot/firmware" 2>/dev/null || true
    sudo umount "$MOUNT_DIR" 2>/dev/null || true
    sudo losetup -d "$LOOP_DEV" || true
    
    # Move back if successful (we check if script didn't fail before this trap)
    # Actually, we should do the move explicitly at the end of script.
    # Trap just cleans up temp dir
    rm -rf "$WORK_DIR"
}
trap clean_up EXIT

# 3. Mount Partitions
# p1 = boot, p2 = root
mkdir -p "$MOUNT_DIR"

echo "Mounting Root Partition (${LOOP_DEV}p2)..."
if [ ! -b "${LOOP_DEV}p2" ]; then
    echo "ERROR: Partition ${LOOP_DEV}p2 does not exist!"
    ls -l /dev/loop*
    exit 1
fi

sudo mount -v "${LOOP_DEV}p2" "$MOUNT_DIR"
sudo mkdir -p "$MOUNT_DIR/boot/firmware"
sudo mount "${LOOP_DEV}p1" "$MOUNT_DIR/boot/firmware"

echo "Partitions mounted at $MOUNT_DIR"

# Debug: Check FS
echo "Debug: Checking Root FS content:"
ls -la "$MOUNT_DIR" | head -n 5

if [ ! -d "$MOUNT_DIR/etc" ]; then
    echo "ERROR: Root filesystem appears corrupted (no /etc). Please delete the .img file and rebuild."
    exit 1
fi

sudo mkdir -p "$MOUNT_DIR/usr/bin"

# 4. Copy QEMU Static (Critical for Chroot)
if [ ! -f /usr/bin/qemu-aarch64-static ]; then
    echo "Error: qemu-aarch64-static not found on host. Please install qemu-user-static."
    exit 1
fi
sudo cp /usr/bin/qemu-aarch64-static "$MOUNT_DIR/usr/bin/"

# 5. Inject 86Box Binary and Roms
echo "Injecting 86Box..."
sudo cp "$BUILD_ARTIFACTS_DIR/86Box" "$MOUNT_DIR/usr/local/bin/"
sudo mkdir -p "$MOUNT_DIR/usr/local/share/86Box"
sudo cp -r "$BUILD_ARTIFACTS_DIR/roms" "$MOUNT_DIR/usr/local/share/86Box/"

# 6. Inject Payload Files
echo "Injecting Payload..."
# Service
sudo cp "$PAYLOAD_DIR/retro-pc.service" "$MOUNT_DIR/etc/systemd/system/"
# Scripts
sudo cp "$PAYLOAD_DIR/input_daemon.py" "$MOUNT_DIR/usr/local/bin/"
sudo cp "$PAYLOAD_DIR/show_menu.sh" "$MOUNT_DIR/usr/local/bin/"
# Xinitrc (Needs to go to /home/pi/ but permission fix is done in internal script)
sudo cp "$PAYLOAD_DIR/xinitrc" "$MOUNT_DIR/home/pi/.xinitrc"
# Audio Config
sudo mkdir -p "$MOUNT_DIR/etc/pipewire/pipewire.conf.d"
sudo cp "$PAYLOAD_DIR/latency.conf" "$MOUNT_DIR/etc/pipewire/pipewire.conf.d/"

# 7. Inject Internal Installer
sudo cp "$INTERNAL_SCRIPT" "$MOUNT_DIR/install_deps_internal.sh"
sudo chmod +x "$MOUNT_DIR/install_deps_internal.sh"

# 8. Modify cmdline.txt for silent boot
echo "Configuring Silent Boot..."
CMDLINE="$MOUNT_DIR/boot/firmware/cmdline.txt"
# We append our params if not present
CURRENT_CMDLINE=$(cat "$CMDLINE")
# Replace console=tty1 with console=tty3
NEW_CMDLINE=${CURRENT_CMDLINE/console=tty1/console=tty3}
# Add quiet settings
NEW_CMDLINE="$NEW_CMDLINE loglevel=3 logo.nologo vt.global_cursor_default=0 quiet splash"
echo "$NEW_CMDLINE" | sudo tee "$CMDLINE"

# 9. Prepare Network for Chroot
echo "Configuring DNS for Chroot..."
if [ -L "$MOUNT_DIR/etc/resolv.conf" ]; then
    # It's a symlink, just rename it
    sudo mv "$MOUNT_DIR/etc/resolv.conf" "$MOUNT_DIR/etc/resolv.conf.bak"
else
    # It's a file?
    sudo mv "$MOUNT_DIR/etc/resolv.conf" "$MOUNT_DIR/etc/resolv.conf.bak" || true
fi
sudo cp /etc/resolv.conf "$MOUNT_DIR/etc/resolv.conf"

# 10. Enter Chroot to install dependencies
echo "Entering Chroot..."
# Mount pseudo-filesystems for chroot
sudo mount -t proc /proc "$MOUNT_DIR/proc"
sudo mount -t sysfs /sys "$MOUNT_DIR/sys"
sudo mount -o bind /dev "$MOUNT_DIR/dev"
sudo mount -o bind /dev/pts "$MOUNT_DIR/dev/pts"

sudo chroot "$MOUNT_DIR" /bin/bash /install_deps_internal.sh

# 11. Restore Network Config
echo "Restoring Network Config..."
sudo rm "$MOUNT_DIR/etc/resolv.conf"
if [ -e "$MOUNT_DIR/etc/resolv.conf.bak" ]; then
    sudo mv "$MOUNT_DIR/etc/resolv.conf.bak" "$MOUNT_DIR/etc/resolv.conf"
fi

echo "=== [Modify] Image Modification Complete ==="

# Copy back the modified image
echo "Moving modified image back to $ORIGINAL_IMAGE ..."
mv "$TEMP_IMAGE" "$ORIGINAL_IMAGE"

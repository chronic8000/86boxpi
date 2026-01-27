#!/bin/bash
set -e

# Configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
IMAGE_FILE="$SCRIPT_DIR/../86box-pi5-appliance.img"
KERNEL_URL="http://ftp.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux"
INITRD_URL="http://ftp.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz"

echo "=== 86Box Appliance QEMU Test Runner ==="

# 1. Check for QEMU
if ! command -v qemu-system-aarch64 &> /dev/null; then
    echo "Error: qemu-system-aarch64 not found."
    echo "Please install it: sudo apt install qemu-system-arm"
    exit 1
fi

# 2. Download Generic Debian Kernel (The "Proxy" Method)
# We use the official Debian Bookworm generic kernel. This ensures 64-bit compatibility
# and VirtIO support, allowing checks of the filesystem.
# Note: Modules won't load due to version mismatch, but it WILL boot to login.

GENERIC_KERNEL_URL="https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux"
GENERIC_INITRD_URL="https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz"

KERNEL_FILE="$SCRIPT_DIR/../kernel_generic_bookworm"
INITRD_FILE="$SCRIPT_DIR/../initrd_generic_bookworm"

if [ ! -f "$KERNEL_FILE" ]; then
    echo "Downloading generic Debian Kernel for QEMU testing..."
    wget "$GENERIC_KERNEL_URL" -O "$KERNEL_FILE"
fi
if [ ! -f "$INITRD_FILE" ]; then
    echo "Downloading generic Debian Initrd..."
    wget "$GENERIC_INITRD_URL" -O "$INITRD_FILE"
fi

# 3. Warning about Image
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: Image file $IMAGE_FILE not found. Did the build finish?"
    exit 1
fi

# 4. Create a Temporary Copy (Bypass File Locks)
# QEMU often locks the file, preventing re-runs if the previous process is zombie/stuck.
# We work on a copy to ensure a clean state every time.
TEST_IMAGE="${SCRIPT_DIR}/../qemu-test-copy.img"
echo "Creating a temporary copy of the image for testing..."
echo "Source: $IMAGE_FILE"
echo "Dest:   $TEST_IMAGE"
cp "$IMAGE_FILE" "$TEST_IMAGE"

echo "Starting QEMU with Debian Generic Kernel..."
echo "NOTE: This verifies the IMAGE STRUCTURE and USERSPACE."
echo "NOTE: Drivers specific to Pi (Sound/Video) will fail, but the system will boot."
echo "NOTE: Press Ctrl+A, then X to exit."

qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a72 \
    -smp 4 \
    -m 4G \
    -kernel "$KERNEL_FILE" \
    -initrd "$INITRD_FILE" \
    -append "root=/dev/vda2 rw console=ttyAMA0 rootwait panic=1" \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive if=none,id=hd0,format=raw,file="$TEST_IMAGE" \
    -device virtio-gpu-pci \
    -device usb-ehci -device usb-kbd -device usb-mouse \
    -display gtk,gl=on,grab-on-hover=on \
    -serial stdio \
    -netdev user,id=net0,hostfwd=tcp::10022-:22 \
    -device virtio-net-pci,netdev=net0

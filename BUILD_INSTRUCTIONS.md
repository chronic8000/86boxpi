# 86Box Raspberry Pi 5 Appliance: Build Instructions

This guide details how to build the custom 86Box appliance image using Windows Subsystem for Linux (WSL2).

## Prerequisites

*   **Windows 10/11** with WSL2 enabled.
*   **Ubuntu 22.04/24.04** distribution installed in WSL.
*   **Administrator Privileges** (required for mounting disk images).
*   **Disk Space**: At least **15GB** of free space in your WSL distribution.

## 1. Environment Setup

Open your Ubuntu terminal in WSL.

### 1.1 Install system dependencies
These packages are required for the build script, cross-compilation, and image modification.

```bash
sudo apt update
sudo apt install -y \
    docker.io \
    qemu-user-static \
    binfmt-support \
    kpartx \
    dosfstools \
    git \
    wget \
    xz-utils \
    parted \
    udev
```

### 1.2 Configure Docker (Optional but Recommended)
To run Docker without `sudo` (the build script handles sudo, but this is good practice):

```bash
sudo usermod -aG docker $USER
# You will need to log out and back in for this to take effect.
```

Ensure the Docker service is running:
```bash
sudo service docker start
```

## 2. Cloning the Repository

Clone this project to your WSL filesystem (e.g., in your home directory).
**IMPORTANT**: Do NOT clone this to `/mnt/c/`. It must be on the native Linux filesystem (`~/` or `/home/youruser/`) for permissions and loopback devices to work correctly.

```bash
cd ~
git clone <repository-url> 86box-pi-builder
cd 86box-pi-builder
```

## 3. Running the Build

The build process is automated by `build.sh`.

```bash
chmod +x build.sh
./build.sh
```

### What the script does:
1.  **Checks Dependencies**: Verifies Docker and QEMU are installed.
2.  **Downloads Base Image**: Fetches the official Raspberry Pi OS Lite (ARM64).
3.  **Compiles 86Box**:
    *   Starts a Docker container (Debian Bookworm ARM64).
    *   Cross-compiles 86Box specifically for the Raspberry Pi 5 (Cortex-A76).
    *   Outputs the binary to `build_artifacts/86Box`.
4.  **Modifies Image**:
    *   Expands the `.img` file by 2GB.
    *   Mounts the image partitions.
    *   Injects the 86Box binary, ROMs, and payload scripts.
    *   Enters the image via `chroot` to install runtime dependencies (Qt5, SDL2, etc.).
    *   Configures systemd to boot directly into X11/86Box.

### Build Duration
*   **First Run**: ~10-20 minutes (depends on download speed and CPU).
*   **Subsequent Runs**: Faster, as 86Box compilation is cached/skipped if binary exists (delete `build_artifacts/86Box` to force recompile).

## 4. Output

Upon success, you will see:
```text
==========================================
       BUILD SUCCESSFUL
==========================================
Output Image: 86box-pi5-appliance.img
```

The file `86box-pi5-appliance.img` is your ready-to-flash image.

## 5. Cleaning Up

The script creates working files in `/tmp`. These are cleaned up automatically.
If the build fails halfway, you might need to manually unmount:

```bash
sudo losetup -D
```

#!/bin/bash
set -e

# Configuration
IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-11-raspios-bookworm-arm64-lite.img.xz"
IMAGE_XZ="raspios-lite.img.xz"
IMAGE_RAW="86box-pi5-appliance.img"

echo "=========================================="
echo "   86Box Raspberry Pi 5 Image Builder     "
echo "=========================================="

# 1. Check Dependencies
echo "[1/4] Checking Host Dependencies..."
command -v docker >/dev/null 2>&1 || { echo >&2 "Docker is required but not installed."; exit 1; }
dpkg -s qemu-user-static >/dev/null 2>&1 || { echo >&2 "qemu-user-static is required. Run 'sudo apt install qemu-user-static'"; exit 1; }

# 2. Download Image
echo "[2/4] Preparing Base Image..."
if [ ! -f "$IMAGE_RAW" ]; then
    if [ ! -f "$IMAGE_XZ" ]; then
        echo "Downloading Raspberry Pi OS Lite..."
        wget "$IMAGE_URL" -O "$IMAGE_XZ"
    fi
    echo "Extracting Image..."
    unxz -kf "$IMAGE_XZ"
    mv "${IMAGE_XZ%.xz}" "$IMAGE_RAW"
else
    echo "Base image already exists."
fi

# 3. Build 86Box
echo "[3/4] Compiling 86Box (Artifact Generation)..."
./scripts/compile_86box.sh

# 4. Modify Image
echo "[4/4] Injecting Artifacts into Image..."
# Verify we have artifacts
if [ ! -f "build_artifacts/86Box" ]; then
    echo "Error: 86Box binary missing. Compilation failed?"
    exit 1
fi

sudo ./scripts/modify_image.sh \
    "$IMAGE_RAW" \
    "$(pwd)/build_artifacts" \
    "$(pwd)/payload" \
    "$(pwd)/scripts/install_deps_internal.sh"

echo "=========================================="
echo "       BUILD SUCCESSFUL                   "
echo "=========================================="
echo "Output Image: $IMAGE_RAW"
echo "Flash this image to your SD card using Raspberry Pi Imager."

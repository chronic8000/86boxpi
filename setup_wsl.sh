#!/bin/bash
set -e

echo "=== Setting up WSL Environment for 86Box Builder ==="

# 1. Update Repo
sudo apt-get update

# 2. Install QEMU User Static (Required for Chroot magic)
echo "Installing QEMU User Static..."
sudo apt-get install -y qemu-user-static binfmt-support

# 3. Install Docker (If not present)
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker.io..."
    sudo apt-get install -y docker.io
    # Add user to docker group
    sudo usermod -aG docker $USER
    echo "NOTE: You may need to log out and back in for Docker group changes to take effect."
else
    echo "Docker is already installed."
fi

# 4. Install Utility Tools
echo "Installing Utils (wget, xz-utils)..."
sudo apt-get install -y wget xz-utils

echo "=== Setup Complete ==="
echo "You can now run ./build.sh"

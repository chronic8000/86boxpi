#!/bin/bash
# This script runs INSIDE the Raspberry Pi Image (QEMU Chroot)

echo "=== [Internal] Installing Dependencies ==="
set -e
export DEBIAN_FRONTEND=noninteractive

# 1. Update Apt
# Ensure we are pure 64-bit to avoid multi-arch hell (libc6 skew)
dpkg --remove-architecture armhf || true
rm -rf /var/lib/apt/lists/*
apt-get update
# Fix for multi-arch version skew (libc6 errors) if any remain
apt-get upgrade -y

# 2. Install Runtime Libraries
apt-get install -y \
    libqt5widgets5 \
    libqt5gui5 \
    libsdl2-2.0-0 \
    libopenal1 \
    libfreetype6 \
    libglib2.0-0 \
    libslirp0 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    librtmidi6 \
    libfluidsynth3 \
    libserialport0 \
    xserver-xorg \
    xinit \
    openbox \
    xdotool \
    python3-evdev \
    python3-evdev \
    python3-pip \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    pipewire \
    pipewire-alsa \
    pipewire-pulse

# Try installing yad separately (might fail on some minimal repos)
apt-get install -y yad || echo "Warning: YAD installation failed, menu might not work."

# 3. Setup User Permissions
# Ensure 'pi' user exists (it should in RaspiOS) or default user
if id "pi" &>/dev/null; then
    echo "User 'pi' found."
    # Add to input group for reading /dev/input/event*
    usermod -a -G input,video,render,audio pi
else
    echo "User 'pi' NOT found. Creating..."
    useradd -m -s /bin/bash pi
    usermod -a -G input,video,render,audio pi
    echo "pi:raspberry" | chpasswd
fi

# 4. Enable Services
systemctl enable retro-pc.service
systemctl set-default graphical.target

# 86Box Binary and ROMs are injected by modify_image.sh
echo "Setting permissions for 86Box..."
chmod +x /usr/local/bin/86Box

# 5. Fix permissions for our injected files
chmod +x /usr/local/bin/input_daemon.py
chmod +x /usr/local/bin/show_menu.sh
chmod +x /home/pi/.xinitrc
chown pi:pi /home/pi/.xinitrc

# 6. Clean up
apt-get clean
rm -f /install_deps_internal.sh

echo "=== [Internal] Setup Complete ==="

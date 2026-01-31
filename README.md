# 86Box Raspberry Pi 5 Appliance Builder

This directory contains a complete toolchain to generate a custom Raspberry Pi OS image that boots directly into 86Box.

## Download Pre-built Image
Don't want to build it yourself? Download the latest pre-compiled image for Raspberry Pi 5 here:
[Download 86Box Pi Appliance (Google Drive)](https://drive.google.com/file/d/1zFrmpkwZU72tUEtExmdRbPSTmDMlamTn/view?usp=sharing)

## Prerequisites
- Windows 10/11 with WSL 2.0 (Ubuntu or Debian).
- At least 15GB of free disk space (for Docker images and uncompressed filesystem).

## Quick Start (WSL)

1. **Setup Environment**:
   Run the setup script to install QEMU and Docker.
   ```bash
   chmod +x setup_wsl.sh
   ./setup_wsl.sh
   # NOTE: If docker was installed, you might need to close and reopen your terminal.
   ```

2. **Build the Image**:
   Run the master build script. This will download the OS, compile 86Box, and inject it.
   ```bash
   chmod +x build.sh
   sudo ./build.sh
   ```
   *Warning: The build process involves `sudo` for mounting disk images. Review `scripts/modify_image.sh` if concerned.*

3. **Flash**:
   Take the resulting `86box-pi5-appliance.img` and flash it to an SD card using **Raspberry Pi Imager** or **BalenaEtcher**.

## What's Inside?

### The "Payload" (Injected into the Pi)
- **86Box v5.0+**: compiled with Cortex-A76 optimizations (New Dynarec).
- **Silent Boot**: Kernel parameters tuned to hide text.
- **Auto-Start**: Systemd unit (`retro-pc.service`) launching X11/Openbox.
- **F8+F12 Menu**: A Python daemon (`input_daemon.py`) that executes `yad` for a settings GUI.

### Key Files
- `usr/local/bin/86Box`: The emulator.
- `usr/local/bin/input_daemon.py`: The hotkey listener.
- `home/pi/.xinitrc`: The startup script.

## Customization
To add more ROMs or change default settings before building, edit the `scripts/compile_86box.sh` script or place files in the `payload/` directory and update `scripts/modify_image.sh` to copy them.

Picture of it running on Pi4 port I still do not have a Pi5 :( -

https://drive.google.com/file/d/1zcR1YFaaiojshSBRNxZMLZkawA-BHp0e/view?usp=sharing

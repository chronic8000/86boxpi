# Dockerfile for 86Box Cross-Compilation
FROM debian:bookworm

# Enable multi-arch for ARM64
RUN dpkg --add-architecture arm64

# Update and install cross-compilers and dependencies
RUN apt-get update && apt-get install -y \
   build-essential cmake git python3 \
   crossbuild-essential-arm64 \
   pkg-config \
   libsdl2-dev:arm64 libqt5widgets5:arm64 qtbase5-dev:arm64 \
   libfreetype6-dev:arm64 libglib2.0-dev:arm64 \
   libopenal-dev:arm64 libslirp-dev:arm64 \
   libxkbcommon-dev:arm64 libxkbcommon-x11-dev:arm64 \
   libpcap-dev:arm64 libsndfile1-dev:arm64 \
   libxi-dev:arm64 libxcursor-dev:arm64 \
   librtmidi-dev:arm64 libfluidsynth-dev:arm64 \
   qttools5-dev:arm64 qttools5-dev-tools \
   qtbase5-private-dev:arm64 \
   libserialport-dev:arm64 libevdev-dev:arm64

# Create build directory
WORKDIR /build

# Default command
CMD ["/bin/bash"]

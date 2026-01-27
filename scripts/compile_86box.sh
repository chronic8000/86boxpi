#!/bin/bash
set -e

# Define directories
BUILD_DIR=$(pwd)/build_artifacts
mkdir -p "$BUILD_DIR"

echo "=== Building Cross-Compilation Container ==="
docker build -t 86box-cross-builder .

echo "=== Compiling 86Box for ARM64 ==="
# We run the container to compile 86Box
# We mount the artifacts directory to extract the binary
docker run --rm -v "$BUILD_DIR":/output 86box-cross-builder /bin/bash -c '
    set -e
    
    echo "Cloning 86Box..."
    git clone --depth 1 https://github.com/86Box/86Box.git
    cd 86Box
    
    echo "Configuring CMake..."
    # Set PKG_CONFIG paths for ARM64
    export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
    export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
    
    # Debug: Check if sndfile.pc exists
    echo "Checking for sndfile.pc in $PKG_CONFIG_PATH..."
    ls -l /usr/lib/aarch64-linux-gnu/pkgconfig/sndfile.pc || echo "sndfile.pc NOT FOUND"

    cmake -B build -S . \
        -DNEW_DYNAREC=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DOPTIMIZED=ON \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DQt5_DIR=/usr/lib/aarch64-linux-gnu/cmake/Qt5 \
        -DVDE_NETWORKING=ON \
        -DCMAKE_C_FLAGS="-mcpu=cortex-a76 -mtune=cortex-a76" \
        -DCMAKE_CXX_FLAGS="-mcpu=cortex-a76 -mtune=cortex-a76"
        
    echo "Building..."
    # -j$(nproc) uses all cores
    cmake --build build -j$(nproc)
    
    echo "Packaging..."
    cp build/src/86Box /output/86Box
    
    # Download ROMs
    echo "Downloading 86Box ROMs..."
    rm -rf /output/roms
    git clone --depth 1 https://github.com/86Box/roms.git /output/roms
    rm -rf /output/roms/.git
    
    echo "Compilation Complete. Artifacts in /output"
'

echo "=== Build Process Finished ==="
ls -l "$BUILD_DIR/86Box"


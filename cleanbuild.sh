#!/usr/bin/env bash
set -e

# Define directories
DEBUG_DIR="build-debug"
RELEASE_DIR="build-release"

# Function to build a specific configuration
build_target() {
    local TYPE=$1    # Debug or Release
    local DIR=$2     # build-debug or build-release

    echo ">>> Preparing $TYPE build in $DIR..."
    mkdir -p "$DIR"
    
    # Configure
    cmake -S . -B "$DIR" \
      -DCMAKE_BUILD_TYPE="$TYPE" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DUSE_WAYLAND_WSI=OFF

    # Build
    echo ">>> Compiling $TYPE..."
    cmake --build "$DIR" -- -j"$(nproc)"
}

# 1. Build Debug version
build_target "Debug" "$DEBUG_DIR"

# 2. Build Release version
build_target "Release" "$RELEASE_DIR"

# 3. Handle compile_commands.json for Neovim LSP
# We link the Debug one by default as it's usually better for development
echo ">>> Linking compile_commands.json to root..."
ln -sf "$DEBUG_DIR/compile_commands.json" .

echo ">>> All builds complete."
echo ">>> Debug binary:   $DEBUG_DIR/your_binary_name"
echo ">>> Release binary: $RELEASE_DIR/your_binary_name"

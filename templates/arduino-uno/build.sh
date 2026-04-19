#!/bin/bash
set -e

# Arduino Uno Build Script
# Uses arduino-cli to compile for ATmega328P

FQBN="arduino:avr:uno"
PROJECT_DIR="."
BUILD_DIR="build"

echo "Arduino Uno Build Script"
echo "========================="

# Compile the project
echo "Compiling..."
arduino-cli compile --fqbn "$FQBN" --build-path "$BUILD_DIR" "$PROJECT_DIR"

# Show build results
if [ -f "$BUILD_DIR/arduino-uno.ino.hex" ]; then
    SIZE=$(stat -f%z "$BUILD_DIR/arduino-uno.ino.hex" 2>/dev/null || stat -c%s "$BUILD_DIR/arduino-uno.ino.hex")
    echo "✓ Build complete! Binary: $(pwd)/$BUILD_DIR/arduino-uno.ino.hex"
    echo "  Size: $SIZE bytes"
else
    echo "✗ Build failed!"
    exit 1
fi

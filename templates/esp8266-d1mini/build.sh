#!/bin/bash
# Build script for ESP8266 D1 Mini using Arduino CLI

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Board configuration
FQBN="esp8266:esp8266:d1_mini"

echo "ESP8266 D1 Mini Build Script"
echo "============================="

# Compile using arduino-cli
echo "Compiling..."
arduino-cli compile --fqbn "$FQBN" --build-path "$BUILD_DIR" "$PROJECT_DIR"

echo "✓ Build complete! Binary: $BUILD_DIR/$PROJECT_NAME.ino.bin"

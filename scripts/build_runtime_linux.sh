#!/usr/bin/env bash
# Compile the native C/SDL2 host runtime from source on Linux
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="$(uname -m)"
BUILD_DIR="$REPO_DIR/build-runtime"

echo "=========================================================="
echo "Compiling Native Lua/SDL2 Host Runtime for Linux ($ARCH)"
echo "=========================================================="

# Check for required tools
for cmd in git meson ninja; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required tool '$cmd' is not installed." >&2
    echo "On Debian/Ubuntu: sudo apt-get install -y gcc git meson ninja-build libsdl2-dev libfreetype6-dev libpcre2-dev" >&2
    echo "On Fedora/RHEL:   sudo dnf install -y gcc git meson ninja-build SDL2-devel freetype-devel pcre2-devel" >&2
    echo "On Arch Linux:    sudo pacman -S --needed gcc git meson ninja sdl2 freetype2 pcre2" >&2
    exit 1
  fi
done

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -d "lite-xl-src" ]; then
  echo "Fetching minimal SDL2/Lua runtime source..."
  git clone --depth 1 --branch v2.1.8 https://github.com/lite-xl/lite-xl.git lite-xl-src
fi

cd lite-xl-src
echo "Configuring Meson build..."
meson setup --buildtype=release build-dir

echo "Compiling native binary via Ninja..."
ninja -C build-dir

COMPILED_BIN="$BUILD_DIR/lite-xl-src/build-dir/src/lite-xl"
if [ ! -f "$COMPILED_BIN" ]; then
  COMPILED_BIN="$BUILD_DIR/lite-xl-src/build-dir/lite-xl"
fi

if [ -f "$COMPILED_BIN" ]; then
  mkdir -p "$REPO_DIR/bin"
  OUTPUT_BIN="$REPO_DIR/bin/lualamp-linux-$ARCH"
  cp "$COMPILED_BIN" "$OUTPUT_BIN"
  chmod +x "$OUTPUT_BIN"
  echo "✓ Native Linux binary compiled successfully: $OUTPUT_BIN"
  
  echo "Bundling Linux release..."
  LUALAMP_LINUX_BIN="$OUTPUT_BIN" "$REPO_DIR/scripts/bundle_linux.sh"
else
  echo "Error: Compiled binary not found in build directory." >&2
  exit 1
fi

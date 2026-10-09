#!/usr/bin/env bash
# Build the native Lua Lamp C/SDL3 engine from source
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_DIR/bin"
mkdir -p "$BIN_DIR"

echo "=== Building Lua Lamp Native Engine ==="

# 1. Detect Homebrew prefix
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
elif [ -d "/opt/homebrew" ]; then
  BREW_PREFIX="/opt/homebrew"
elif [ -d "/usr/local" ]; then
  BREW_PREFIX="/usr/local"
fi

if [ -z "$BREW_PREFIX" ]; then
  echo "Error: Homebrew prefix could not be determined. Please install Homebrew." >&2
  exit 1
fi

# 2. Check and prompt/install dependencies if missing
MISSING_DEPS=()
[ ! -d "$BREW_PREFIX/opt/sdl3" ] && MISSING_DEPS+=("sdl3")
[ ! -d "$BREW_PREFIX/opt/freetype" ] && MISSING_DEPS+=("freetype")
[ ! -d "$BREW_PREFIX/opt/pcre2" ] && MISSING_DEPS+=("pcre2")
[ ! -d "$BREW_PREFIX/opt/libpng" ] && MISSING_DEPS+=("libpng")

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  echo "Installing missing dependencies via brew: ${MISSING_DEPS[*]}..."
  brew install "${MISSING_DEPS[@]}"
fi

SDL3_DIR="$BREW_PREFIX/opt/sdl3"
FREETYPE_DIR="$BREW_PREFIX/opt/freetype"
PCRE2_DIR="$BREW_PREFIX/opt/pcre2"
LIBPNG_DIR="$BREW_PREFIX/opt/libpng"

# 3. Check for static vs dynamic libraries
LINK_LIBS=("-L$SDL3_DIR/lib" "-lSDL3")

if [ -f "$FREETYPE_DIR/lib/libfreetype.a" ]; then
  LINK_LIBS+=("$FREETYPE_DIR/lib/libfreetype.a")
else
  LINK_LIBS+=("-L$FREETYPE_DIR/lib" "-lfreetype")
fi

if [ -f "$PCRE2_DIR/lib/libpcre2-8.a" ]; then
  LINK_LIBS+=("$PCRE2_DIR/lib/libpcre2-8.a")
else
  LINK_LIBS+=("-L$PCRE2_DIR/lib" "-lpcre2-8")
fi

if [ -f "$LIBPNG_DIR/lib/libpng.a" ]; then
  LINK_LIBS+=("$LIBPNG_DIR/lib/libpng.a")
elif [ -f "$LIBPNG_DIR/lib/libpng16.a" ]; then
  LINK_LIBS+=("$LIBPNG_DIR/lib/libpng16.a")
else
  LINK_LIBS+=("-L$LIBPNG_DIR/lib" "-lpng")
fi

LINK_LIBS+=("-lz" "-lbz2")
LINK_LIBS+=(
  "-framework" "Cocoa"
  "-framework" "CoreFoundation"
  "-framework" "CoreServices"
  "-framework" "IOKit"
  "-framework" "QuartzCore"
  "-framework" "ApplicationServices"
  "-framework" "CoreGraphics"
  "-framework" "Network"
  "-framework" "AVFoundation"
)

# 4. Gather C & ObjC sources
SOURCES=(
  "$REPO_DIR"/engine/*.c
  "$REPO_DIR"/engine/api/*.c
  "$REPO_DIR"/engine/api/dirmonitor/fsevents.c
  "$REPO_DIR"/engine/bundle_open.m
)

# Gather Lua sources (excluding standalone CLI main files lua.c and luac.c)
for f in "$REPO_DIR"/engine/lua/*.c; do
  bname="$(basename "$f")"
  if [ "$bname" != "lua.c" ] && [ "$bname" != "luac.c" ]; then
    SOURCES+=("$f")
  fi
done

OUTPUT_BIN="$BIN_DIR/lualamp_bin"

echo "Compiling ${#SOURCES[@]} source files..."
clang -O2 \
  -DMACOS_USE_BUNDLE \
  -DLITE_PROJECT_VERSION_STR=\"1.0.0\" \
  -DPCRE2_CODE_UNIT_WIDTH=8 \
  -DLUA_USE_MACOSX \
  -I"$SDL3_DIR/include" \
  -I"$FREETYPE_DIR/include/freetype2" \
  -I"$PCRE2_DIR/include" \
  -I"$REPO_DIR/engine" \
  -I"$REPO_DIR/engine/lua" \
  "${SOURCES[@]}" \
  "${LINK_LIBS[@]}" \
  -o "$OUTPUT_BIN"

chmod +x "$OUTPUT_BIN"
echo "✓ Native engine compiled successfully: $OUTPUT_BIN"

if [ -f "$REPO_DIR/engine/netauth.m" ]; then
  echo "Compiling netauth companion helper..."
  clang -O2 -framework Foundation -framework Network "$REPO_DIR/engine/netauth.m" -o "$BIN_DIR/netauth"
  chmod +x "$BIN_DIR/netauth"
  echo "✓ Netauth companion helper compiled: $BIN_DIR/netauth"
fi

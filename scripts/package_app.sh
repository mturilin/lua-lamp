#!/usr/bin/env bash
# Lua Lamp Universal Application Packager
# Packages any downstream Lua Lamp project into a 100% standalone native executable bundle.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect Homebrew prefix
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
elif [ -d "/opt/homebrew" ]; then
  BREW_PREFIX="/opt/homebrew"
elif [ -d "/usr/local" ]; then
  BREW_PREFIX="/usr/local"
fi

show_help() {
  cat << EOF
📦 Lua Lamp Universal Application Packager

Usage:
  package_app.sh <project_dir> [options]

Options:
  --macos         Build standalone macOS .app bundle
  --dmg           Build standalone macOS .app bundle and compressed .dmg disk image (default on macOS)
  --linux         Build standalone Linux portable package (.tar.gz and AppImage layout)
  --out-dir <dir> Custom output directory (default: <project_dir>/dist)
  --clean         Clean output directory before packaging
  --help, -h      Show this help message

Examples:
  ./scripts/package_app.sh ./examples/pinglet
  ./scripts/package_app.sh ./examples/pinglet --dmg
  ./scripts/package_app.sh ./my-tool --out-dir ./releases
EOF
}

TARGET_DIR=""
BUILD_MACOS=false
BUILD_DMG=false
BUILD_LINUX=false
CUSTOM_OUT_DIR=""
DO_CLEAN=false

# Default platform detection
if [ "$(uname -s)" = "Darwin" ]; then
  BUILD_MACOS=true
  BUILD_DMG=true
else
  BUILD_LINUX=true
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --macos)
      BUILD_MACOS=true
      BUILD_LINUX=false
      shift
      ;;
    --dmg)
      BUILD_MACOS=true
      BUILD_DMG=true
      BUILD_LINUX=false
      shift
      ;;
    --linux)
      BUILD_LINUX=true
      BUILD_MACOS=false
      BUILD_DMG=false
      shift
      ;;
    --out-dir)
      CUSTOM_OUT_DIR="$2"
      shift 2
      ;;
    --clean)
      DO_CLEAN=true
      shift
      ;;
    *)
      if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$1"
        shift
      else
        echo "Error: Unknown argument '$1'" >&2
        show_help
        exit 1
      fi
      ;;
  esac
done

if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR="."
fi

APP_DIR="$(cd "$TARGET_DIR" && pwd)"
if [ ! -d "$APP_DIR" ]; then
  echo "Error: Target project directory does not exist: $APP_DIR" >&2
  exit 1
fi

# 1. Parse app.json metadata if present
APP_JSON="$APP_DIR/app.json"

read_json_field() {
  local key="$1"
  local default_val="$2"
  if [ -f "$APP_JSON" ]; then
    local res=""
    if command -v python3 >/dev/null 2>&1; then
      res="$(python3 -c "import json; d=json.load(open('$APP_JSON')); print(d.get('$key', ''))" 2>/dev/null || true)"
    fi
    if [ -z "$res" ]; then
      res="$(grep -m 1 "\"$key\"" "$APP_JSON" 2>/dev/null | sed -E 's/.*"'$key'"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)"
    fi
    if [ -n "$res" ]; then
      echo "$res"
      return
    fi
  fi
  echo "$default_val"
}

DIR_NAME="$(basename "$APP_DIR")"
# Capitalize directory name for default app title
DEFAULT_NAME="$(echo "${DIR_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${DIR_NAME:1}"

DIR_LOWER="$(echo "$DIR_NAME" | tr '[:upper:]' '[:lower:]')"
APP_NAME="$(read_json_field "name" "$DEFAULT_NAME")"
DISPLAY_NAME="$(read_json_field "displayName" "$APP_NAME")"
APP_ID="$(read_json_field "identifier" "com.lualamp.$DIR_LOWER")"
APP_VERSION="$(read_json_field "version" "1.0.0")"
ENTRY_FILE="$(read_json_field "entry" "main.lua")"
ICON_REL="$(read_json_field "icon" "")"

# Normalize executable name (lowercase, no spaces)
EXEC_NAME="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"

OUT_DIR="${CUSTOM_OUT_DIR:-$APP_DIR/dist}"
mkdir -p "$OUT_DIR"

if [ "$DO_CLEAN" = true ]; then
  echo "Cleaning output directory $OUT_DIR..."
  rm -rf "$OUT_DIR"/*
fi

echo "=========================================================="
echo "💡 Lua Lamp Universal Application Packager"
echo "=========================================================="
echo "Project Path:  $APP_DIR"
echo "App Name:      $APP_NAME ($DISPLAY_NAME)"
echo "Identifier:    $APP_ID"
echo "Version:       $APP_VERSION"
echo "Output Dir:    $OUT_DIR"
echo "=========================================================="

# 2. Ensure native engine is built
ENGINE_BIN="$REPO_DIR/bin/lualamp_bin"
if [ ! -f "$ENGINE_BIN" ]; then
  echo "Building native C/SDL3 host engine..."
  "$REPO_DIR/scripts/build_engine.sh"
fi

if [ ! -f "$ENGINE_BIN" ]; then
  echo "Error: Native engine binary not found at $ENGINE_BIN" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# macOS Native Packaging (.app + .dmg)
# -----------------------------------------------------------------------------
if [ "$BUILD_MACOS" = true ]; then
  TARGET_APP="$OUT_DIR/$APP_NAME.app"
  echo "Packaging macOS Application Bundle: $TARGET_APP..."

  rm -rf "$TARGET_APP"
  mkdir -p "$TARGET_APP/Contents/MacOS"
  mkdir -p "$TARGET_APP/Contents/Resources"
  mkdir -p "$TARGET_APP/Contents/Resources/core"
  mkdir -p "$TARGET_APP/Contents/Resources/src"
  mkdir -p "$TARGET_APP/Contents/Resources/fonts"
  mkdir -p "$TARGET_APP/Contents/Resources/app"

  # Install Mach-O executable
  cp "$ENGINE_BIN" "$TARGET_APP/Contents/MacOS/$EXEC_NAME"
  chmod +x "$TARGET_APP/Contents/MacOS/$EXEC_NAME"

  # Bundle libSDL3.0.dylib and rewrite dynamic load paths
  if [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" ]; then
    cp "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib"
    chmod 755 "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib"
    install_name_tool -id "@executable_path/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib" 2>/dev/null || true
    install_name_tool -change "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" "@executable_path/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/$EXEC_NAME" 2>/dev/null || true
  fi

  # Install Lua Lamp runtime and framework modules
  if [ -d "$REPO_DIR/runtime" ]; then
    cp -R "$REPO_DIR/runtime/"* "$TARGET_APP/Contents/Resources/"
  fi
  cp "$REPO_DIR/core.lua" "$TARGET_APP/Contents/Resources/core.lua"
  cp -R "$REPO_DIR/src/"* "$TARGET_APP/Contents/Resources/src/"
  cp -R "$REPO_DIR/fonts/"* "$TARGET_APP/Contents/Resources/fonts/"

  # Install Application Code into app/
  # Copy all files from project directory excluding dist and git
  rsync -av --exclude="dist" --exclude=".git" --exclude="*.dmg" "$APP_DIR/" "$TARGET_APP/Contents/Resources/app/" 2>/dev/null || {
    cp -R "$APP_DIR/"* "$TARGET_APP/Contents/Resources/app/" 2>/dev/null || true
    rm -rf "$TARGET_APP/Contents/Resources/app/dist"
  }

  # Forwarder in core/init.lua
  cat << 'EOF' > "$TARGET_APP/Contents/Resources/core/init.lua"
-- Lua Lamp Core Forwarder
return dofile((MACOS_RESOURCES or DATADIR) .. "/core.lua")
EOF

  # Generate or copy App Icon
  ICON_FILE="$TARGET_APP/Contents/Resources/icon.icns"
  if [ -n "$ICON_REL" ] && [ -f "$APP_DIR/$ICON_REL" ]; then
    if [[ "$ICON_REL" == *.icns ]]; then
      cp "$APP_DIR/$ICON_REL" "$ICON_FILE"
    elif [[ "$ICON_REL" == *.png ]] && [ -f "$REPO_DIR/scripts/generate_icon.swift" ]; then
      swift "$REPO_DIR/scripts/generate_icon.swift" "$APP_DIR/$ICON_REL" "$ICON_FILE" 2>/dev/null || cp "$REPO_DIR/LuaLamp.icns" "$ICON_FILE"
    fi
  elif [ -f "$APP_DIR/icon.icns" ]; then
    cp "$APP_DIR/icon.icns" "$ICON_FILE"
  elif [ -f "$APP_DIR/icon.png" ] && [ -f "$REPO_DIR/scripts/generate_icon.swift" ]; then
    swift "$REPO_DIR/scripts/generate_icon.swift" "$APP_DIR/icon.png" "$ICON_FILE" 2>/dev/null || cp "$REPO_DIR/LuaLamp.icns" "$ICON_FILE"
  else
    cp "$REPO_DIR/LuaLamp.icns" "$ICON_FILE"
  fi

  # Install companion netauth helper and dylib for macOS local network permission discovery
  if [ -f "$REPO_DIR/engine/netauth.m" ]; then
    echo "Compiling netauth companion helper and dylib..."
    clang -O2 -framework Foundation -framework Network "$REPO_DIR/engine/netauth.m" -o "$TARGET_APP/Contents/MacOS/netauth"
    chmod +x "$TARGET_APP/Contents/MacOS/netauth"
    clang -shared -fPIC -O2 -framework Foundation -framework Network "$REPO_DIR/engine/netauth.m" -o "$TARGET_APP/Contents/Resources/libnetauth.dylib"
  elif [ -f "$REPO_DIR/bin/netauth" ]; then
    cp "$REPO_DIR/bin/netauth" "$TARGET_APP/Contents/MacOS/netauth"
    chmod +x "$TARGET_APP/Contents/MacOS/netauth"
  fi

  # Privacy usage descriptions
  LOCAL_NET_DESC="$(read_json_field "localNetworkUsageDescription" "$DISPLAY_NAME requires local network access to discover devices, measure latency, and diagnose network connectivity.")"
  CAMERA_DESC="$(read_json_field "cameraUsageDescription" "$DISPLAY_NAME requires camera access for video features.")"
  MIC_DESC="$(read_json_field "microphoneUsageDescription" "$DISPLAY_NAME requires microphone access for audio recording.")"
  APPLEVENTS_DESC="$(read_json_field "appleEventsUsageDescription" "$DISPLAY_NAME requires AppleEvents access to automate tasks.")"

  # Generate Info.plist
  cat << EOF > "$TARGET_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>$DISPLAY_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$EXEC_NAME</string>
	<key>CFBundleGetInfoString</key>
	<string>$DISPLAY_NAME $APP_VERSION</string>
	<key>CFBundleIconFile</key>
	<string>icon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>$APP_ID</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$APP_VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© $(date +%Y) $APP_NAME</string>
	<key>NSLocalNetworkUsageDescription</key>
	<string>$LOCAL_NET_DESC</string>
	<key>NSBonjourServices</key>
	<array>
		<string>_http._tcp</string>
		<string>_bonjour._tcp</string>
	</array>
	<key>NSCameraUsageDescription</key>
	<string>$CAMERA_DESC</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>$MIC_DESC</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>$APPLEVENTS_DESC</string>
</dict>
</plist>
EOF

  # Clear Apple quarantine and ad-hoc codesign
  xattr -cr "$TARGET_APP" 2>/dev/null || true
  codesign --force --deep -s - "$TARGET_APP" 2>/dev/null || true

  echo "✓ Successfully created standalone application: $TARGET_APP"

  # Optional DMG Creation
  if [ "$BUILD_DMG" = true ]; then
    DMG_NAME="$APP_NAME-$APP_VERSION.dmg"
    TARGET_DMG="$OUT_DIR/$DMG_NAME"
    echo "Creating compressed DMG installer: $TARGET_DMG..."

    STAGING_DIR="$(mktemp -d /tmp/lualamp_dmg_staging.XXXXXX)"
    cp -R "$TARGET_APP" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"
    xattr -cr "$STAGING_DIR" 2>/dev/null || true
    codesign --force --deep -s - "$STAGING_DIR/$APP_NAME.app" 2>/dev/null || true

    rm -f "$TARGET_DMG"
    hdiutil create \
      -volname "$APP_NAME" \
      -srcfolder "$STAGING_DIR" \
      -ov \
      -format UDZO \
      "$TARGET_DMG" >/dev/null

    rm -rf "$STAGING_DIR"
    echo "✓ Successfully created disk image: $TARGET_DMG"
  fi
fi

# -----------------------------------------------------------------------------
# Linux Portable Package (.tar.gz & .desktop)
# -----------------------------------------------------------------------------
if [ "$BUILD_LINUX" = true ]; then
  ARCH="${ARCH:-x86_64}"
  PORTABLE_DIR="$OUT_DIR/$APP_NAME-linux-$ARCH"
  TARBALL="$OUT_DIR/$APP_NAME-linux-$ARCH.tar.gz"

  echo "Packaging Linux Portable Package: $PORTABLE_DIR..."
  rm -rf "$PORTABLE_DIR" "$TARBALL"
  mkdir -p "$PORTABLE_DIR/bin"
  mkdir -p "$PORTABLE_DIR/data/core"
  mkdir -p "$PORTABLE_DIR/data/src"
  mkdir -p "$PORTABLE_DIR/data/fonts"
  mkdir -p "$PORTABLE_DIR/data/app"
  mkdir -p "$PORTABLE_DIR/share/applications"
  mkdir -p "$PORTABLE_DIR/share/icons/hicolor/256x256/apps"

  # Copy engine executable
  cp "$ENGINE_BIN" "$PORTABLE_DIR/bin/$EXEC_NAME"
  chmod +x "$PORTABLE_DIR/bin/$EXEC_NAME"

  # Copy runtime, framework, fonts
  if [ -d "$REPO_DIR/runtime" ]; then
    cp -R "$REPO_DIR/runtime/"* "$PORTABLE_DIR/data/"
  fi
  cp "$REPO_DIR/core.lua" "$PORTABLE_DIR/data/core.lua"
  cp -R "$REPO_DIR/src/"* "$PORTABLE_DIR/data/src/"
  cp -R "$REPO_DIR/fonts/"* "$PORTABLE_DIR/data/fonts/"

  # Copy user app code
  rsync -av --exclude="dist" --exclude=".git" "$APP_DIR/" "$PORTABLE_DIR/data/app/" 2>/dev/null || {
    cp -R "$APP_DIR/"* "$PORTABLE_DIR/data/app/" 2>/dev/null || true
    rm -rf "$PORTABLE_DIR/data/app/dist"
  }

  # Desktop integration file
  cat << EOF > "$PORTABLE_DIR/share/applications/$EXEC_NAME.desktop"
[Desktop Entry]
Name=$DISPLAY_NAME
Exec=$EXEC_NAME
Icon=$EXEC_NAME
Type=Application
Categories=Utility;Application;
Comment=$DISPLAY_NAME powered by Lua Lamp
Terminal=false
EOF

  # Create tarball release archive
  tar -czf "$TARBALL" -C "$OUT_DIR" "$APP_NAME-linux-$ARCH"
  echo "✓ Successfully created Linux release tarball: $TARBALL"
fi

echo "=========================================================="
echo "🎉 Build Complete!"
echo "=========================================================="

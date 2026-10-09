#!/usr/bin/env bash
# Bundle Lua Lamp as an independent standalone macOS application
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
TARGET_APP="$DIST_DIR/Lua Lamp.app"
APPLICATIONS_APP="/Applications/Lua Lamp.app"

echo "=== Packaging Standalone Lua Lamp.app ==="

# 1. Detect Homebrew prefix
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
elif [ -d "/opt/homebrew" ]; then
  BREW_PREFIX="/opt/homebrew"
elif [ -d "/usr/local" ]; then
  BREW_PREFIX="/usr/local"
fi

# 2. Build the native C/SDL3 engine if needed
echo "Building native C/SDL3 engine..."
"$REPO_DIR/scripts/build_engine.sh"

ENGINE_BIN="$REPO_DIR/bin/lualamp_bin"
if [ ! -f "$ENGINE_BIN" ]; then
  echo "Error: Native engine binary not found at $ENGINE_BIN" >&2
  exit 1
fi

# 3. Create clean app bundle directory hierarchy
echo "Creating application bundle layout at $TARGET_APP..."
mkdir -p "$DIST_DIR"
rm -rf "$TARGET_APP"
mkdir -p "$TARGET_APP/Contents/MacOS"
mkdir -p "$TARGET_APP/Contents/Resources"
mkdir -p "$TARGET_APP/Contents/Resources/core"
mkdir -p "$TARGET_APP/Contents/Resources/src"
mkdir -p "$TARGET_APP/Contents/Resources/fonts"

# 4. Install Mach-O C/SDL3 binary
echo "Installing Mach-O executable and libraries..."
cp "$ENGINE_BIN" "$TARGET_APP/Contents/MacOS/lualamp"
chmod +x "$TARGET_APP/Contents/MacOS/lualamp"

# 4.5. Compile companion netauth helper
if [ -f "$REPO_DIR/engine/netauth.m" ]; then
  echo "Compiling netauth companion helper and dylib..."
  clang -O2 -framework Foundation -framework Network "$REPO_DIR/engine/netauth.m" -o "$TARGET_APP/Contents/MacOS/netauth"
  chmod +x "$TARGET_APP/Contents/MacOS/netauth"
  clang -shared -fPIC -O2 -framework Foundation -framework Network "$REPO_DIR/engine/netauth.m" -o "$TARGET_APP/Contents/Resources/libnetauth.dylib"
fi

# 5. Bundle libSDL3.0.dylib and adjust load paths
if [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" ]; then
  echo "Bundling libSDL3.0.dylib..."
  cp "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib"
  chmod 755 "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib"
  install_name_tool -id "@executable_path/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/libSDL3.0.dylib" 2>/dev/null || true
  install_name_tool -change "$BREW_PREFIX/opt/sdl3/lib/libSDL3.0.dylib" "@executable_path/libSDL3.0.dylib" "$TARGET_APP/Contents/MacOS/lualamp" 2>/dev/null || true
fi

# 6. Install Core Runtime resources from runtime/
echo "Installing Lua runtime bridge scripts..."
if [ -d "$REPO_DIR/runtime" ]; then
  cp -R "$REPO_DIR/runtime/"* "$TARGET_APP/Contents/Resources/"
fi

# 7. Install Lua Lamp application source code
echo "Installing Lua Lamp application code & fonts..."
cp "$REPO_DIR/core.lua" "$TARGET_APP/Contents/Resources/core.lua"
cp -R "$REPO_DIR/src/"* "$TARGET_APP/Contents/Resources/src/"
cp -R "$REPO_DIR/fonts/"* "$TARGET_APP/Contents/Resources/fonts/"

# 8. Install Lua Lamp forwarder in core/init.lua
cat << 'EOF' > "$TARGET_APP/Contents/Resources/core/init.lua"
-- Lua Lamp Core Forwarder
return dofile((MACOS_RESOURCES or DATADIR) .. "/core.lua")
EOF

# 9. Build and install icon
if [ ! -f "$REPO_DIR/LuaLamp.icns" ]; then
  echo "Generating icon assets via Swift..."
  swift "$REPO_DIR/scripts/generate_icon.swift"
fi
cp "$REPO_DIR/LuaLamp.icns" "$TARGET_APP/Contents/Resources/icon.icns"
cp "$REPO_DIR/LuaLamp.icns" "$TARGET_APP/Contents/Resources/LuaLamp.icns"

# Documentation
[ -f "$REPO_DIR/SPECIFICATION.md" ] && cp "$REPO_DIR/SPECIFICATION.md" "$TARGET_APP/Contents/Resources/"
[ -f "$REPO_DIR/README.md" ] && cp "$REPO_DIR/README.md" "$TARGET_APP/Contents/Resources/"
[ -f "$REPO_DIR/AGENTS.md" ] && cp "$REPO_DIR/AGENTS.md" "$TARGET_APP/Contents/Resources/"

# 10. Write clean Info.plist
cat << 'EOF' > "$TARGET_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Lua Lamp</string>
	<key>CFBundleExecutable</key>
	<string>lualamp</string>
	<key>CFBundleGetInfoString</key>
	<string>Lua Lamp — Native Lua &amp; SDL3 Application Starter Template</string>
	<key>CFBundleIconFile</key>
	<string>icon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.lualamp.app</string>
	<key>CFBundleName</key>
	<string>Lua Lamp</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 Lua Lamp</string>
	<key>NSLocalNetworkUsageDescription</key>
	<string>Lua Lamp requires local network access to discover devices, measure gateway latency, and diagnose network connectivity.</string>
	<key>NSBonjourServices</key>
	<array>
		<string>_http._tcp</string>
		<string>_bonjour._tcp</string>
	</array>
	<key>NSCameraUsageDescription</key>
	<string>Lua Lamp requires camera access for video features.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Lua Lamp requires microphone access for audio recording.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>Lua Lamp requires AppleEvents access to automate tasks.</string>
</dict>
</plist>
EOF

# 11. Clear quarantine attributes recursively
echo "Clearing Apple quarantine attributes..."
xattr -cr "$TARGET_APP" 2>/dev/null || true

# 12. Ad-hoc code signing
echo "Ad-hoc code signing app bundle..."
codesign --force --deep -s - "$TARGET_APP" 2>/dev/null || true

# 13. Install to /Applications/
echo "Installing to /Applications/Lua Lamp.app..."
rm -rf "$APPLICATIONS_APP"
cp -R "$TARGET_APP" "$APPLICATIONS_APP"
xattr -cr "$APPLICATIONS_APP" 2>/dev/null || true
codesign --force --deep -s - "$APPLICATIONS_APP" 2>/dev/null || true

# 14. Refresh LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPLICATIONS_APP" 2>/dev/null || true

echo "✓ Successfully created: $TARGET_APP"
echo "✓ Successfully installed: $APPLICATIONS_APP"

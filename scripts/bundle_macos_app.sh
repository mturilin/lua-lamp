#!/usr/bin/env bash
# Bundle Lua Lamp as an independent standalone macOS application
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
TARGET_APP="$DIST_DIR/Lua Lamp.app"
APPLICATIONS_APP="/Applications/Lua Lamp.app"

RUNTIME_BIN=""
RUNTIME_RES=""
if [ -d "/Applications/Lite XL.app" ]; then
  RUNTIME_BIN="/Applications/Lite XL.app/Contents/MacOS/lite-xl"
  RUNTIME_RES="/Applications/Lite XL.app/Contents/Resources"
elif [ -d "/Applications/Pinglet.app" ]; then
  RUNTIME_BIN="/Applications/Pinglet.app/Contents/MacOS/pinglet"
  RUNTIME_RES="/Applications/Pinglet.app/Contents/Resources"
elif [ -d "/Applications/Chicken Scratch.app" ]; then
  RUNTIME_BIN="/Applications/Chicken Scratch.app/Contents/MacOS/chickenscratch"
  RUNTIME_RES="/Applications/Chicken Scratch.app/Contents/Resources"
fi

if [ ! -f "$RUNTIME_BIN" ]; then
  echo "Error: Lua/SDL2 platform runtime binary not found in Applications." >&2
  exit 1
fi

echo "==> Building standalone Lua Lamp.app..."
mkdir -p "$DIST_DIR"
rm -rf "$TARGET_APP"
mkdir -p "$TARGET_APP/Contents/MacOS"
mkdir -p "$TARGET_APP/Contents/Resources/core"
mkdir -p "$TARGET_APP/Contents/Resources/src/ui"
mkdir -p "$TARGET_APP/Contents/Resources/fonts"

# 1. Install Mach-O C/SDL2 binary
cp "$RUNTIME_BIN" "$TARGET_APP/Contents/MacOS/lualamp"
chmod +x "$TARGET_APP/Contents/MacOS/lualamp"

# 2. Install Lua C-binding wrappers from platform runtime
for mod in renderer.lua system.lua process.lua regex.lua utf8extra.lua dirmonitor.lua globals.lua string.lua; do
  if [ -f "$RUNTIME_RES/$mod" ]; then
    cp "$RUNTIME_RES/$mod" "$TARGET_APP/Contents/Resources/"
  fi
done

# Install process.lua and utf8string.lua helpers into core/
if [ -f "$RUNTIME_RES/core/process.lua" ]; then
  cp "$RUNTIME_RES/core/process.lua" "$TARGET_APP/Contents/Resources/core/"
fi
if [ -f "$RUNTIME_RES/core/utf8string.lua" ]; then
  cp "$RUNTIME_RES/core/utf8string.lua" "$TARGET_APP/Contents/Resources/core/"
fi

# 3. Install Lua Lamp application source code
cp "$REPO_DIR/core.lua" "$TARGET_APP/Contents/Resources/core.lua"
cp -R "$REPO_DIR/src/"* "$TARGET_APP/Contents/Resources/src/"
cp -R "$REPO_DIR/fonts/"* "$TARGET_APP/Contents/Resources/fonts/"

# 4. Install Lua Lamp bootstrap files in Contents/Resources/core/
cat << 'EOF' > "$TARGET_APP/Contents/Resources/core/start.lua"
-- Lua Lamp Standalone Bootstrap
SCALE = tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE")) or 1
PATHSEP = package.config:sub(1, 1)

EXEDIR = EXEFILE:match("^(.+)[/\\][^/\\]+$")
DATADIR = MACOS_RESOURCES or (EXEDIR .. PATHSEP .. '..' .. PATHSEP .. 'Resources')
USERDIR = os.getenv("LUALAMP_USERDIR") or os.getenv("LITE_USERDIR") or DATADIR

-- USERDIR takes precedence for development overrides
package.path = USERDIR .. '/?.lua;' ..
               USERDIR .. '/?/init.lua;' ..
               DATADIR .. '/?.lua;' ..
               DATADIR .. '/?/init.lua;' ..
               package.path

local suffix = PLATFORM == "Mac OS X" and 'lib' or (PLATFORM == "Windows" and 'dll' or 'so')
package.cpath =
  USERDIR .. '/?.' .. ARCH .. "." .. suffix .. ";" ..
  DATADIR .. '/?.' .. ARCH .. "." .. suffix .. ";" ..
  DATADIR .. '/?.' .. suffix .. ";" ..
  package.cpath

package.native_plugins = {}
package.searchers = { package.searchers[1], package.searchers[2], function(modname)
  local path, err = package.searchpath(modname, package.cpath)
  if not path then return err end
  return system.load_native_plugin, path
end }

table.pack = table.pack or pack or function(...) return {...} end
table.unpack = table.unpack or unpack

require "core.utf8string"
require "core.process"
EOF

cat << 'EOF' > "$TARGET_APP/Contents/Resources/core/init.lua"
-- Lua Lamp Core Forwarder
return dofile((MACOS_RESOURCES or DATADIR) .. "/core.lua")
EOF

# 5. Build and install icon
if [ ! -f "$REPO_DIR/LuaLamp.icns" ]; then
  echo "Generating icon assets via Swift..."
  swift "$REPO_DIR/scripts/generate_icon.swift"
fi
cp "$REPO_DIR/LuaLamp.icns" "$TARGET_APP/Contents/Resources/icon.icns"

# 6. Write clean Info.plist
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
	<string>Lua Lamp — Lua &amp; SDL2 Application Starter Template</string>
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
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

# 7. Ad-hoc code signing
codesign --force --deep -s - "$TARGET_APP" 2>/dev/null || true

# 8. Install to /Applications/
rm -rf "$APPLICATIONS_APP"
cp -R "$TARGET_APP" "$APPLICATIONS_APP"

echo "✓ Successfully created: $TARGET_APP"
echo "✓ Successfully installed: $APPLICATIONS_APP"

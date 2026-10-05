#!/usr/bin/env bash
# Bundle Lua Lamp for Linux (Portable Package & AppImage)
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
ARCH="${ARCH:-x86_64}"
APP_NAME="lualamp"
PACKAGE_NAME="lualamp-linux-$ARCH"
PORTABLE_DIR="$DIST_DIR/$PACKAGE_NAME"
APP_DIR="$DIST_DIR/Lua_Lamp.AppDir"

echo "==> Packaging Lua Lamp for Linux ($ARCH)..."
mkdir -p "$DIST_DIR"
rm -rf "$PORTABLE_DIR" "$APP_DIR"
mkdir -p "$PORTABLE_DIR/bin"
mkdir -p "$PORTABLE_DIR/data/core"
mkdir -p "$PORTABLE_DIR/data/src/ui"
mkdir -p "$PORTABLE_DIR/data/fonts"
mkdir -p "$PORTABLE_DIR/share/applications"
mkdir -p "$PORTABLE_DIR/share/icons/hicolor/256x256/apps"
mkdir -p "$PORTABLE_DIR/share/icons/hicolor/scalable/apps"

# 1. Locate or fetch Linux C runtime binary
LINUX_BIN=""
if [ -n "$LUALAMP_LINUX_BIN" ] && [ -f "$LUALAMP_LINUX_BIN" ]; then
  LINUX_BIN="$LUALAMP_LINUX_BIN"
elif [ -f "$REPO_DIR/bin/lualamp-linux-$ARCH" ]; then
  LINUX_BIN="$REPO_DIR/bin/lualamp-linux-$ARCH"
elif [ -f "$REPO_DIR/build/lite-xl" ]; then
  LINUX_BIN="$REPO_DIR/build/lite-xl"
fi

if [ -z "$LINUX_BIN" ]; then
  echo "Notice: Local Linux runtime binary not found."
  echo "Attempting to download prebuilt Lua/SDL2 platform runtime from GitHub release (v2.1.8)..."
  CACHE_DIR="$HOME/.cache/lualamp"
  mkdir -p "$CACHE_DIR"
  TARBALL="$CACHE_DIR/lite-xl-v2.1.8-linux-$ARCH-portable.tar.gz"
  
  if [ ! -f "$TARBALL" ]; then
    URL="https://github.com/lite-xl/lite-xl/releases/download/v2.1.8/lite-xl-v2.1.8-linux-$ARCH-portable.tar.gz"
    echo "Downloading $URL..."
    if command -v curl >/dev/null 2>&1; then
      curl -L "$URL" -o "$TARBALL" || rm -f "$TARBALL"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "$TARBALL" "$URL" || rm -f "$TARBALL"
    fi
  fi

  if [ -f "$TARBALL" ]; then
    EXTRACT_DIR="$CACHE_DIR/extracted-$ARCH"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$TARBALL" -C "$EXTRACT_DIR"
    FOUND_BIN=$(find "$EXTRACT_DIR" -type f -name "lite-xl" | head -n 1)
    if [ -n "$FOUND_BIN" ]; then
      LINUX_BIN="$FOUND_BIN"
      # Also copy runtime Lua C-wrappers if available
      FOUND_RES=$(find "$EXTRACT_DIR" -type d -name "lite-xl" | grep "/share/" | head -n 1)
      if [ -n "$FOUND_RES" ]; then
        cp -R "$FOUND_RES/"* "$PORTABLE_DIR/data/" 2>/dev/null || true
      fi
    fi
  fi
fi

if [ -z "$LINUX_BIN" ] || [ ! -f "$LINUX_BIN" ]; then
  echo "Warning: Could not automatically acquire Linux ELF binary."
  echo "Creating stub binary. On Linux, run './scripts/build_runtime_linux.sh' to compile native binary."
  cat << 'EOF' > "$PORTABLE_DIR/bin/lualamp"
#!/bin/sh
echo "Lua Lamp: Please install native binary or run ./scripts/build_runtime_linux.sh"
exit 1
EOF
  chmod +x "$PORTABLE_DIR/bin/lualamp"
else
  cp "$LINUX_BIN" "$PORTABLE_DIR/bin/lualamp"
  chmod +x "$PORTABLE_DIR/bin/lualamp"
fi

# 2. Copy Lua Lamp Core, Application Source & Fonts into data/
cp "$REPO_DIR/core.lua" "$PORTABLE_DIR/data/core.lua"
cp "$REPO_DIR/init.lua" "$PORTABLE_DIR/data/init.lua"
cp -R "$REPO_DIR/src/"* "$PORTABLE_DIR/data/src/"
cp -R "$REPO_DIR/fonts/"* "$PORTABLE_DIR/data/fonts/"

# 3. Create Linux Bootstrap (start.lua & init.lua)
cat << 'EOF' > "$PORTABLE_DIR/data/core/start.lua"
-- Lua Lamp Linux Standalone Bootstrap
SCALE = tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE") or os.getenv("GDK_SCALE")) or 1
PATHSEP = package.config:sub(1, 1)

EXEDIR = EXEFILE:match("^(.+)[/\\][^/\\]+$")
local prefix = EXEDIR:match("^(.+)[/\\]bin$")
DATADIR = prefix and (prefix .. PATHSEP .. 'data') or (EXEDIR .. PATHSEP .. '..' .. PATHSEP .. 'data')
if not system.get_file_info(DATADIR) then
  DATADIR = prefix and (prefix .. PATHSEP .. 'share' .. PATHSEP .. 'lualamp') or (EXEDIR .. PATHSEP .. 'data')
end

USERDIR = os.getenv("LUALAMP_USERDIR") or os.getenv("LITE_USERDIR") or DATADIR

package.path = USERDIR .. '/?.lua;' ..
               USERDIR .. '/?/init.lua;' ..
               DATADIR .. '/?.lua;' ..
               DATADIR .. '/?/init.lua;' ..
               package.path

local suffix = PLATFORM == "Windows" and 'dll' or 'so'
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

local appimage_owd = os.getenv("OWD")
if os.getenv("APPIMAGE") and appimage_owd then
  system.chdir(appimage_owd)
end
EOF

cat << 'EOF' > "$PORTABLE_DIR/data/core/init.lua"
-- Lua Lamp Core Forwarder
return dofile((DATADIR or ".") .. "/core.lua")
EOF

# 4. Copy Icons & Desktop file
if [ -f "$REPO_DIR/resources/lualamp.png" ]; then
  cp "$REPO_DIR/resources/lualamp.png" "$PORTABLE_DIR/share/icons/hicolor/256x256/apps/lualamp.png"
  cp "$REPO_DIR/resources/lualamp.png" "$PORTABLE_DIR/lualamp.png"
fi
if [ -f "$REPO_DIR/resources/lualamp.svg" ]; then
  cp "$REPO_DIR/resources/lualamp.svg" "$PORTABLE_DIR/share/icons/hicolor/scalable/apps/lualamp.svg"
fi

cat << 'EOF' > "$PORTABLE_DIR/lualamp.desktop"
[Desktop Entry]
Name=Lua Lamp
Comment=Lua & SDL2 Application Starter Template
Exec=lualamp %F
Icon=lualamp
Terminal=false
Type=Application
Categories=Development;Utility;
Keywords=lua;sdl2;template;graphics;
StartupNotify=true
EOF

cp "$PORTABLE_DIR/lualamp.desktop" "$PORTABLE_DIR/share/applications/lualamp.desktop"

# 5. Create Standalone Shell Launcher inside portable dir
cat << 'EOF' > "$PORTABLE_DIR/lualamp"
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LUALAMP_USERDIR="$SCRIPT_DIR/data"
exec "$SCRIPT_DIR/bin/lualamp" "$@"
EOF
chmod +x "$PORTABLE_DIR/lualamp"

# 6. Create Tarball archive
TARBALL_OUT="$DIST_DIR/$PACKAGE_NAME.tar.gz"
echo "Creating $TARBALL_OUT..."
(cd "$DIST_DIR" && tar -czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME")
echo "✓ Portable Linux tarball ready: $TARBALL_OUT"

# 7. Optionally build AppImage if appimagetool is present
if command -v appimagetool >/dev/null 2>&1; then
  echo "Building Linux AppImage..."
  cp -R "$PORTABLE_DIR" "$APP_DIR"
  cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/sh
HERE="$(cd "$(dirname "$0")" && pwd)"
export LUALAMP_USERDIR="$HERE/data"
exec "$HERE/bin/lualamp" "$@"
EOF
  chmod +x "$APP_DIR/AppRun"
  appimagetool "$APP_DIR" "$DIST_DIR/Lua_Lamp-$ARCH.AppImage"
  echo "✓ AppImage generated: $DIST_DIR/Lua_Lamp-$ARCH.AppImage"
fi

echo "✓ Linux packaging complete!"

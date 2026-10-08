#!/usr/bin/env bash
# Create a distributable macOS DMG for Lua Lamp
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
APP_PATH="$DIST_DIR/Lua Lamp.app"
VERSION="1.0.0"
DMG_NAME="LuaLamp-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="Lua Lamp"

echo "=== Creating Lua Lamp DMG Disk Image ==="

# 1. Build and bundle latest app if needed
if [ ! -d "$APP_PATH" ]; then
  echo "Application bundle not found. Building first..."
  "$REPO_DIR/scripts/bundle_macos_app.sh"
else
  echo "Found existing bundle at $APP_PATH. Rebuilding to ensure fresh distribution..."
  "$REPO_DIR/scripts/bundle_macos_app.sh"
fi

# 2. Setup output and temporary staging directories
mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d /tmp/lualamp_dmg_staging.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Staging DMG contents at $STAGING_DIR..."
cp -R "$APP_PATH" "$STAGING_DIR/Lua Lamp.app"

# 3. Add Applications symlink for drag-and-drop installation
ln -s /Applications "$STAGING_DIR/Applications"

# 4. Include user guide & documentation
[ -f "$REPO_DIR/README.md" ] && cp "$REPO_DIR/README.md" "$STAGING_DIR/README.md"
[ -f "$REPO_DIR/SPECIFICATION.md" ] && cp "$REPO_DIR/SPECIFICATION.md" "$STAGING_DIR/SPECIFICATION.md"

# 5. Clear quarantine attributes and sign
echo "Clearing quarantine attributes..."
xattr -cr "$STAGING_DIR/Lua Lamp.app" 2>/dev/null || true

echo "Signing staged app bundle..."
codesign --force --deep -s - "$STAGING_DIR/Lua Lamp.app" 2>/dev/null || true

# 6. Build the compressed DMG image
echo "Building disk image: $DMG_PATH..."
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

# 7. Verify DMG
echo "Verifying generated disk image..."
hdiutil verify "$DMG_PATH"

DMG_SIZE="$(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "=== DMG Successfully Created! ==="
echo "File: $DMG_PATH ($DMG_SIZE)"
echo "You can mount and test it with: open \"$DMG_PATH\""

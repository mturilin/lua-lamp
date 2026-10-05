#!/usr/bin/env bash
# Install Lua Lamp CLI launcher to ~/.local/bin/lualamp
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$SCRIPT_DIR/bin/lualamp"
DEST_DIR="$HOME/.local/bin"
DEST_BIN="$DEST_DIR/lualamp"

mkdir -p "$DEST_DIR"
chmod +x "$BIN_SRC"
ln -sf "$BIN_SRC" "$DEST_BIN"

echo "✓ Lua Lamp CLI successfully installed to $DEST_BIN"
echo "You can now run 'lualamp' from any terminal."

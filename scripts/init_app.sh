#!/usr/bin/env bash
# Lua Lamp Project Scaffolder
# Initializes a clean, lightweight downstream application project powered by Lua Lamp.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

show_help() {
  cat << EOF
💡 Lua Lamp Project Scaffolder

Usage:
  init_app.sh <project_dir> [AppName] [DisplayName]

Arguments:
  <project_dir>  Target directory for the new project
  [AppName]      App class / bundle name (e.g. Pinglet, MyTool)
  [DisplayName]  Human-readable window title and menu name

Examples:
  ./scripts/init_app.sh ./apps/pinglet Pinglet "Pinglet — Latency Monitor"
  ./scripts/init_app.sh ./my-tool
EOF
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
  show_help
  exit 0
fi

TARGET_DIR="$1"
mkdir -p "$TARGET_DIR"
APP_DIR="$(cd "$TARGET_DIR" && pwd)"

DIR_NAME="$(basename "$APP_DIR")"
DEFAULT_NAME="$(echo "${DIR_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${DIR_NAME:1}"

APP_NAME="${2:-$DEFAULT_NAME}"
DISPLAY_NAME="${3:-$APP_NAME}"
APP_ID="com.lualamp.$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')"

echo "Creating new Lua Lamp application at: $APP_DIR"

# 1. Write app.json
cat << EOF > "$APP_DIR/app.json"
{
  "name": "$APP_NAME",
  "displayName": "$DISPLAY_NAME",
  "identifier": "$APP_ID",
  "version": "1.0.0",
  "entry": "main.lua",
  "window": {
    "width": 1000,
    "height": 650
  }
}
EOF

# 2. Write main.lua
cat << 'EOF' > "$APP_DIR/main.lua"
-- Application Entry Point
-- Powered by the Lua Lamp Framework
local lamp = require "src.framework"
local style = lamp.Style
local ui = lamp.UI
local icons = lamp.Icons

-- 1. Register Application Menus (Native macOS Menu Bar / Linux In-Window Bar)
lamp.Menu:register("Application", {
  { text = "Check for Updates…", command = "app:check-updates", action = function()
    local MessageBox = lamp.MessageBox
    MessageBox("Updates", "You are running the latest version!"):show()
  end }
})

-- 2. Extend Modal Settings Window
lamp.Settings:register_section("my_tab", "Preferences", icons.settings, function(px, py, pw, ph, s, c, dlg)
  local font = style.font_large or style.font_normal
  renderer.draw_text(font, "Custom Application Settings", px + math.floor(20 * s), py + math.floor(20 * s), c.text_primary or style.syntax.text)
end)

-- 3. Define Main Application View
local MainView = lamp.View:extend()

function MainView:new()
  MainView.super.new(self)
  self.counter = 0
end

function MainView:draw()
  self:draw_background(style.colors.background)
  local s = style.scale

  -- Centered Greeting Card
  local title_font = style.font_large or style.font_hero
  local title = "Hello from " .. (system.get_window_title and system.get_window_title():match("^(.-) —") or "Lua Lamp App")
  local tx = math.floor((self.size.x - title_font:get_width(title)) / 2)
  local ty = math.floor(self.size.y * 0.35)
  renderer.draw_text(title_font, title, tx, ty, style.colors.text_primary)

  -- Counter Label
  local count_text = string.format("Interactive Clicks: %d", self.counter)
  local cx = math.floor((self.size.x - style.font_normal:get_width(count_text)) / 2)
  local cy = ty + math.floor(40 * s)
  renderer.draw_text(style.font_normal, count_text, cx, cy, style.colors.text_secondary)

  -- Pinglet Button Highlight Standard Action Button
  local bw, bh = math.floor(180 * s), math.floor(36 * s)
  local bx = math.floor((self.size.x - bw) / 2)
  local by = cy + math.floor(36 * s)
  ui.draw_button(style.font_normal, "Click to Increment", bx, by, bw, bh, {
    variant = "solid",
    accent_theme = "cyan",
    is_active = true,
  })
end

function MainView:on_mouse_pressed(button, px, py, clicks)
  local s = style.scale
  local bw, bh = math.floor(180 * s), math.floor(36 * s)
  local bx = math.floor((self.size.x - bw) / 2)
  local ty = math.floor(self.size.y * 0.35)
  local by = ty + math.floor(76 * s)

  if ui.point_in_rect(px, py, bx, by, bw, bh) then
    self.counter = self.counter + 1
    lamp.core.redraw = true
    return true
  end
  return false
end

-- 4. Initialize and launch application
return lamp.App {
  initial_view = MainView(),
}
EOF

# 3. Write README.md
cat << EOF > "$APP_DIR/README.md"
# $DISPLAY_NAME

A lightweight, high-performance desktop application built on **Lua Lamp**.

## Development
Run the application in development mode (hot run against the installed Lua Lamp engine):
\`\`\`bash
lualamp run .
\`\`\`

## Packaging Standalone Distribution
Package into a 100% standalone native executable bundle with zero external dependencies:
\`\`\`bash
# On macOS: produces dist/$APP_NAME.app and dist/$APP_NAME-1.0.0.dmg
lualamp build .

# On Linux: produces dist/$APP_NAME-linux-x86_64.tar.gz
lualamp build . --linux
\`\`\`
EOF

echo "✓ Successfully scaffolded $APP_NAME in $APP_DIR"
echo "  Run:   lualamp run $APP_DIR"
echo "  Build: lualamp build $APP_DIR"

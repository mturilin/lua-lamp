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
  -- Create non-blocking inline permission warning banner if access is not granted
  self.banner = lamp.create_permission_banner(lamp.Permissions.LOCAL_NETWORK, {
    message = "Local network access required to ping gateway and discover devices.",
  })
end

function MainView:draw()
  self:draw_background(style.colors.background)
  local s = style.scale

  -- Draw Permission Warning Banner at Top of View if needed
  local banner_h = 0
  if self.banner and self.banner.visible and not self.banner.dismissed then
    banner_h = self.banner:draw(0, 0, self.size.x, math.floor(36 * s))
  end

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

function MainView:on_mouse_moved(px, py, dx, dy)
  local s = style.scale
  if self.banner and self.banner.visible and not self.banner.dismissed then
    self.banner:on_mouse_moved(px, py, 0, 0, self.size.x, math.floor(36 * s))
  end
end

function MainView:on_mouse_pressed(button, px, py, clicks)
  local s = style.scale
  local banner_h = math.floor(36 * s)
  if self.banner and self.banner:on_mouse_pressed(button, px, py, 0, 0, self.size.x, banner_h) then
    return true
  end

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
  permissions = { "local_network" },
  initial_view = MainView(),
}

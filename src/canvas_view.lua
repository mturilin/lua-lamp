-- ============================================================================
-- Lua Lamp Primary Application View Component (`src/canvas_view.lua`)
--
-- Serves as the top-level active RootView content component, providing a dual-mode
-- desktop user interface:
-- 1. "gallery": Full-featured Framework Component Showcase & Interactive Testbed
--    (Sliders, Toggles, Buttons, Inputs, ScrollViews, Banners, Badges, Modals, and Icons).
-- 2. "canvas": Classic Centered Stage Card with filament glow, click ripples, and live telemetry.
--
-- Key Responsibilities:
-- - Houses the centered top segmented mode switcher pill (Gallery vs Canvas).
-- - Routes mouse, wheel, keyboard, and text input events to the active sub-interface.
-- - Maintains live mouse coordinate telemetry and click ripples across both view modes.
-- - Completely suppresses text editor document tabs.
--
-- Public Exports:
-- - CanvasView class inheriting from core.view.
-- ============================================================================

local View = require "core.view"
local canvas = require "src.canvas"
local gallery = require "src.gallery"
local style = require "src.style"
local ui = require "src.ui"
local icons = require "src.icons"

---@class CanvasView : core.view
local CanvasView = View:extend()

--- Instantiates the primary application view.
function CanvasView:new()
  CanvasView.super.new(self)
  self.mode = "gallery" -- Default to the comprehensive component showcase
  self.show_tabs = false -- Never render text editor document tabs over the application view
end

--- Returns the display name of this view.
---@return string
function CanvasView:get_name()
  return "Lua Lamp Framework"
end

--- Calculates the geometry of the top mode switcher segmented pill.
--- Positioned cleanly in the exact horizontal center of the window in both Gallery and Canvas modes.
---@param w number Window width in pixels
---@param s number Current DPI display scale multiplier
---@return number seg_x Top-left X coordinate of the segmented track
---@return number seg_y Top-left Y coordinate of the segmented track
---@return number seg_w Width of the segmented track
---@return number seg_h Height of the segmented track
---@return number half_w Width of each segment button
function CanvasView:get_switcher_rect(w, s)
  local seg_w = math.floor(210 * s)
  local seg_h = math.floor(30 * s)
  -- Center horizontally in the window to guarantee zero overlap with left branding and right buttons
  local seg_x = math.floor((w - seg_w) / 2)
  local seg_y = (self.mode == "gallery") and math.floor((48 * s - seg_h) / 2) or math.floor(16 * s)
  local half_w = math.floor((seg_w - 6 * s) / 2)
  return seg_x, seg_y, seg_w, seg_h, half_w
end

--- Composites the active view mode (Gallery or Canvas) and the centered mode switcher pill.
function CanvasView:draw()
  local w, h = self.size.x, self.size.y
  local s = style.scale or 1.0

  if self.mode == "gallery" then
    gallery:draw(w, h)
  else
    canvas.draw(w, h)
  end

  -- Render Centered Mode Switcher Capsule Track
  local seg_x, seg_y, seg_w, seg_h, half_w = self:get_switcher_rect(w, s)
  ui.draw_segmented_track(seg_x, seg_y, seg_w, seg_h, math.floor(7 * s))

  local mouse_x = (self.mode == "gallery") and (gallery.mouse_x or 0) or canvas.mouse_x
  local mouse_y = (self.mode == "gallery") and (gallery.mouse_y or 0) or canvas.mouse_y
  local is_gal = (self.mode == "gallery")
  local is_can = (self.mode == "canvas")

  local h1 = ui.point_in_rect(mouse_x, mouse_y, seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s)
  ui.draw_button(style.font_small, "Gallery", seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s, {
    variant = is_gal and "solid" or "ghost",
    accent_theme = "cyan",
    is_active = is_gal,
    is_hover = h1,
    icon = icons.layout,
  })

  local h2 = ui.point_in_rect(mouse_x, mouse_y, seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s)
  ui.draw_button(style.font_small, "Canvas", seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s, {
    variant = is_can and "solid" or "ghost",
    accent_theme = "cyan",
    is_active = is_can,
    is_hover = h2,
    icon = icons.bulb,
  })
end

--- Dispatches mouse motion events to telemetry state and the active interface.
---@param px number Window X coordinate
---@param py number Window Y coordinate
---@param dx number Delta X movement
---@param dy number Delta Y movement
function CanvasView:on_mouse_moved(px, py, dx, dy)
  -- Keep canvas coordinates in sync for telemetry & tests
  canvas.on_mouse_moved(px, py)

  if self.mode == "gallery" then
    gallery:on_mouse_moved(px, py)
  end
end

--- Handles mouse button press events: mode switching, ripple generation, and control clicks.
---@param button string|number Mouse button ("left" or 1)
---@param px number Window X coordinate
---@param py number Window Y coordinate
---@param clicks integer Click count
---@return boolean True if the event was consumed
function CanvasView:on_mouse_pressed(button, px, py, clicks)
  local s = style.scale or 1.0
  canvas.add_ripple(px, py)

  -- Check mode switcher pill click (centered in window)
  local seg_x, seg_y, seg_w, seg_h, half_w = self:get_switcher_rect(self.size.x, s)
  if ui.point_in_rect(px, py, seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s) then
    self.mode = "gallery"
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  if ui.point_in_rect(px, py, seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s) then
    self.mode = "canvas"
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  if self.mode == "gallery" then
    return gallery:on_mouse_pressed(button, px, py)
  else
    local core = require "core"
    return canvas.on_mouse_pressed(button, px, py, core)
  end
end

--- Dispatches mouse release events to conclude active dragging.
---@param button string|number Mouse button
---@param px number Window X coordinate
---@param py number Window Y coordinate
function CanvasView:on_mouse_released(button, px, py)
  if self.mode == "gallery" then
    gallery:on_mouse_released(button, px, py)
  end
end

--- Dispatches mousewheel events to the active sub-interface.
---@param y number Vertical scroll delta (positive is up, negative is down)
---@param x number Horizontal scroll delta
---@return boolean True if consumed
function CanvasView:on_mouse_wheel(y, x)
  if self.mode == "gallery" then
    return gallery:on_mouse_wheel(y, x)
  end
  return false
end

--- Steps 60 FPS physics and interpolation across frame redraws.
function CanvasView:update()
  CanvasView.super.update(self)
  if self.mode == "gallery" then
    gallery:update()
  end
end

--- Dispatches text input to focused input boxes.
---@param text string UTF-8 input text
function CanvasView:on_text_input(text)
  if self.mode == "gallery" then
    gallery:on_text_input(text)
  end
end

return CanvasView

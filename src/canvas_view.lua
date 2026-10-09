-- Lua Lamp Primary Application View Component
-- Provides a dual-mode interactive desktop interface:
-- 1. "gallery": Full-featured Framework Component Showcase & Gallery (Sliders, Toggles,
--    Buttons, Inputs, ScrollViews, Banners, Badges, Modals, and Icons).
-- 2. "canvas": Classic Centered Stage Card with Lamp glow, click ripples, and live telemetry.

local View = require "core.view"
local canvas = require "src.canvas"
local gallery = require "src.gallery"
local style = require "src.style"
local ui = require "src.ui"
local icons = require "src.icons"

---@class CanvasView : core.view
local CanvasView = View:extend()

function CanvasView:new()
  CanvasView.super.new(self)
  self.mode = "gallery" -- Default to the comprehensive component showcase
end

function CanvasView:get_name()
  return "Lua Lamp Framework"
end

function CanvasView:draw()
  local w, h = self.size.x, self.size.y
  local s = style.scale or 1.0

  if self.mode == "gallery" then
    gallery:draw(w, h)

    -- Top Mode Switcher Pill in Top Bar (Right of logo)
    local seg_w = math.floor(240 * s)
    local seg_h = math.floor(30 * s)
    local seg_x = math.floor(340 * s)
    local seg_y = math.floor((48 * s - seg_h) / 2)

    ui.draw_segmented_track(seg_x, seg_y, seg_w, seg_h, math.floor(7 * s))

    local half_w = math.floor((seg_w - 6 * s) / 2)
    local h_gal = (self.mode == "gallery")
    local h_can = (self.mode == "canvas")

    local h1 = ui.point_in_rect(gallery.mouse_x or 0, gallery.mouse_y or 0, seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s)
    ui.draw_button(style.font_small, "Gallery", seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s, {
      variant = h_gal and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = h_gal,
      is_hover = h1,
      icon = icons.layout,
    })

    local h2 = ui.point_in_rect(gallery.mouse_x or 0, gallery.mouse_y or 0, seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s)
    ui.draw_button(style.font_small, "Canvas", seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s, {
      variant = h_can and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = h_can,
      is_hover = h2,
      icon = icons.bulb,
    })
  else
    -- Draw classic centered stage card & ripples
    canvas.draw(w, h)

    -- Mode Switcher Banner at top of canvas
    local seg_w = math.floor(240 * s)
    local seg_h = math.floor(32 * s)
    local seg_x = math.floor((w - seg_w) / 2)
    local seg_y = math.floor(16 * s)

    ui.draw_segmented_track(seg_x, seg_y, seg_w, seg_h, math.floor(8 * s))

    local half_w = math.floor((seg_w - 6 * s) / 2)
    local h_gal = (self.mode == "gallery")
    local h_can = (self.mode == "canvas")

    local h1 = ui.point_in_rect(canvas.mouse_x, canvas.mouse_y, seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s)
    ui.draw_button(style.font_small, "Gallery", seg_x + 3 * s, seg_y + 3 * s, half_w, seg_h - 6 * s, {
      variant = h_gal and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = h_gal,
      is_hover = h1,
      icon = icons.layout,
    })

    local h2 = ui.point_in_rect(canvas.mouse_x, canvas.mouse_y, seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s)
    ui.draw_button(style.font_small, "Canvas", seg_x + 3 * s + half_w, seg_y + 3 * s, half_w, seg_h - 6 * s, {
      variant = h_can and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = h_can,
      is_hover = h2,
      icon = icons.bulb,
    })
  end
end

function CanvasView:on_mouse_moved(px, py, dx, dy)
  -- Keep canvas coordinates in sync for telemetry & tests
  canvas.on_mouse_moved(px, py)

  if self.mode == "gallery" then
    gallery:on_mouse_moved(px, py)
  end
end

function CanvasView:on_mouse_pressed(button, px, py, clicks)
  local s = style.scale or 1.0
  canvas.add_ripple(px, py)

  -- 1. Check mode switcher pill click in Gallery mode
  if self.mode == "gallery" then
    local seg_w = math.floor(240 * s)
    local seg_h = math.floor(30 * s)
    local seg_x = math.floor(340 * s)
    local seg_y = math.floor((48 * s - seg_h) / 2)
    local half_w = math.floor((seg_w - 6 * s) / 2)

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

    -- Forward to gallery
    if gallery:on_mouse_pressed(button, px, py) then
      return true
    end
  else
    -- Mode switcher pill click in Canvas mode
    local seg_w = math.floor(240 * s)
    local seg_h = math.floor(32 * s)
    local seg_x = math.floor((self.size.x - seg_w) / 2)
    local seg_y = math.floor(16 * s)
    local half_w = math.floor((seg_w - 6 * s) / 2)

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

    local core = require "core"
    return canvas.on_mouse_pressed(button, px, py, core)
  end

  return false
end

function CanvasView:on_mouse_released(button, px, py)
  if self.mode == "gallery" then
    gallery:on_mouse_released(button, px, py)
  end
end

function CanvasView:on_mouse_wheel(y, x)
  if self.mode == "gallery" then
    return gallery:on_mouse_wheel(y, x)
  end
  return false
end

function CanvasView:on_text_input(text)
  if self.mode == "gallery" then
    gallery:on_text_input(text)
  end
end

return CanvasView

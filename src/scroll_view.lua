-- Lua Lamp — ScrollView Component
-- A high-performance, smooth-scrolling container with scissor clipping,
-- mousewheel/trackpad support, coordinate transformations, and native macOS-style scrollbars.

local Object = require "core.object"
local style = require "src.style"
local ui = require "src.ui"

---@class ScrollView : core.object
local ScrollView = Object:extend()

function ScrollView:new(options)
  options = options or {}
  self.scroll_y = 0
  self.scroll_to_y = 0
  self.scroll_x = 0
  self.scroll_to_x = 0
  self.content_w = 0
  self.content_h = 0
  self.viewport_x = 0
  self.viewport_y = 0
  self.viewport_w = 0
  self.viewport_h = 0

  self.dragging = false
  self.drag_start_y = 0
  self.drag_start_scroll = 0
  self.hovering_thumb = false
  self.fade_alpha = 0.0
  self.scroll_speed = options.scroll_speed or 42
  self.scrollbar_width = options.scrollbar_width or 5
end

function ScrollView:set_content_size(w, h)
  self.content_w = w or 0
  self.content_h = h or 0
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))
end

function ScrollView:set_viewport(x, y, w, h)
  self.viewport_x = x
  self.viewport_y = y
  self.viewport_w = w
  self.viewport_h = h
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))
end

function ScrollView:is_in_viewport(px, py)
  return ui.point_in_rect(px, py, self.viewport_x, self.viewport_y, self.viewport_w, self.viewport_h)
end

function ScrollView:to_content_y(py)
  return py + math.floor(self.scroll_y)
end

function ScrollView:get_thumb_rect()
  if self.content_h <= self.viewport_h or self.viewport_h <= 0 then
    return nil
  end

  local s = style.scale or 1.0
  local track_h = self.viewport_h
  local thumb_h = math.max(math.floor(28 * s), math.floor(track_h * (self.viewport_h / self.content_h)))
  local max_scroll = math.max(1, self.content_h - self.viewport_h)
  local scroll_ratio = math.max(0, math.min(1.0, self.scroll_y / max_scroll))
  local thumb_y = self.viewport_y + math.floor((track_h - thumb_h) * scroll_ratio)
  local thumb_w = math.floor((self.hovering_thumb or self.dragging) and (7 * s) or (self.scrollbar_width * s))
  local thumb_x = self.viewport_x + self.viewport_w - thumb_w - math.floor(3 * s)

  return thumb_x, thumb_y, thumb_w, thumb_h
end

function ScrollView:on_mouse_wheel(dy, dx)
  if not self:is_in_viewport(self.last_mouse_x or self.viewport_x, self.last_mouse_y or self.viewport_y) then
    return false
  end

  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  if max_scroll <= 0 then return false end

  local s = style.scale or 1.0
  local delta = (dy or 0) * (self.scroll_speed * s)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y - delta))
  self.fade_alpha = 1.0

  local core = require "core"
  if core then core.redraw = true end
  return true
end

function ScrollView:on_mouse_moved(px, py)
  self.last_mouse_x = px
  self.last_mouse_y = py

  local s = style.scale or 1.0
  local tx, ty, tw, th = self:get_thumb_rect()
  if tx then
    local hit_margin = math.floor(4 * s)
    self.hovering_thumb = ui.point_in_rect(px, py, tx - hit_margin, ty, tw + hit_margin * 2, th)
    if self.hovering_thumb then self.fade_alpha = 1.0 end
  else
    self.hovering_thumb = false
  end

  if self.dragging then
    local track_h = self.viewport_h
    local thumb_h = th or math.floor(28 * s)
    local delta_y = py - self.drag_start_y
    local max_scroll = math.max(1, self.content_h - self.viewport_h)
    local available_track = math.max(1, track_h - thumb_h)
    local scroll_delta = (delta_y / available_track) * max_scroll

    self.scroll_to_y = math.max(0, math.min(max_scroll, self.drag_start_scroll + scroll_delta))
    self.scroll_y = self.scroll_to_y
    self.fade_alpha = 1.0
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  return self.hovering_thumb
end

function ScrollView:on_mouse_pressed(button, px, py)
  if button ~= "left" and button ~= 1 then return false end

  local tx, ty, tw, th = self:get_thumb_rect()
  if tx then
    local s = style.scale or 1.0
    local hit_margin = math.floor(4 * s)
    if ui.point_in_rect(px, py, tx - hit_margin, ty, tw + hit_margin * 2, th) then
      self.dragging = true
      self.drag_start_y = py
      self.drag_start_scroll = self.scroll_y
      self.fade_alpha = 1.0
      local core = require "core"
      if core then core.redraw = true end
      return true
    end
  end

  return false
end

function ScrollView:on_mouse_released(button, px, py)
  if self.dragging then
    self.dragging = false
    local core = require "core"
    if core then core.redraw = true end
    return true
  end
  return false
end

function ScrollView:update()
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))

  -- Smooth 60 FPS interpolation
  if math.abs(self.scroll_to_y - self.scroll_y) > 0.5 then
    self.scroll_y = self.scroll_y + (self.scroll_to_y - self.scroll_y) * 0.32
    local core = require "core"
    if core then core.redraw = true end
  else
    self.scroll_y = self.scroll_to_y
  end

  -- Fade scrollbar over time if not active
  if not self.dragging and not self.hovering_thumb and self.fade_alpha > 0 then
    self.fade_alpha = math.max(0, self.fade_alpha - 0.035)
    local core = require "core"
    if core then core.redraw = true end
  end
end

--- Begin scrollable viewport rendering
--- Clips output and returns relative drawing origin (x, y - scroll_y)
function ScrollView:begin_clip(x, y, w, h, content_h)
  self:set_viewport(x, y, w, h)
  self:set_content_size(w, content_h)
  self:update()

  renderer.set_clip_rect(x, y, w, h)
  return x, y - math.floor(self.scroll_y)
end

--- End scrollable viewport rendering and draw overlay scrollbar
function ScrollView:end_clip()
  local win_w, win_h = renderer.get_size()
  renderer.set_clip_rect(0, 0, win_w, win_h)

  -- Draw macOS-style modern rounded scrollbar thumb
  local tx, ty, tw, th = self:get_thumb_rect()
  if tx and (self.fade_alpha > 0.05 or self.dragging or self.hovering_thumb) then
    local effective_alpha = math.floor(self.fade_alpha * ((self.dragging or self.hovering_thumb) and 180 or 100))
    local thumb_col = { 255, 255, 255, effective_alpha }
    ui.draw_rounded_rect(tx, ty, tw, th, math.floor(tw / 2), thumb_col)
  end
end

return ScrollView

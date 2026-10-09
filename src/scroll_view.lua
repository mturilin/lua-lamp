-- ============================================================================
-- Lua Lamp ScrollView Component (`src/scroll_view.lua`)
--
-- High-performance, lightweight scrollable viewport container conforming to the
-- architecture of modern reactive UI frameworks (Flutter's SingleChildScrollView
-- and Avalonia's ScrollViewer).
--
-- Key Responsibilities:
-- - Viewport scissor clipping via renderer.set_clip_rect() with local origin translation.
-- - Smooth 60 FPS exponential damping scroll interpolation (scroll_to_y -> scroll_y).
-- - Native macOS-style rounded capsule scrollbar thumb with dynamic width expansion and auto-fade.
-- - Coordinate transformation between window viewport space and scrollable content space.
-- - Mousewheel, trackpad, and thumb dragging interaction with hit testing.
--
-- Public Exports:
-- - ScrollView class table callable as ScrollView(options).
-- ============================================================================

local Object = require "core.object"
local style = require "src.style"
local ui = require "src.ui"

---@class ScrollView : core.object
local ScrollView = Object:extend()

--- Instantiates a new ScrollView container instance with configurable physics.
---@param options table? Configuration options:
---   - `scroll_speed`: Pixels per mousewheel notch before scaling (default: 42).
---   - `scrollbar_width`: Base resting width of scrollbar in unscaled pixels (default: 5).
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

--- Configures the total scrollable dimensions of the child content.
--- Clamps target scroll position to valid bounds.
---@param w number Total width of child content
---@param h number Total height of child content
function ScrollView:set_content_size(w, h)
  self.content_w = w or 0
  self.content_h = h or 0
  -- Re-clamp target scroll position to prevent overscroll when content shrinks
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))
end

--- Updates the visible viewport bounding box in window pixel coordinates.
---@param x number Top-left X coordinate of the viewport
---@param y number Top-left Y coordinate of the viewport
---@param w number Viewport width
---@param h number Viewport height
function ScrollView:set_viewport(x, y, w, h)
  self.viewport_x = x
  self.viewport_y = y
  self.viewport_w = w
  self.viewport_h = h
  -- Re-clamp target scroll position when viewport dimensions change
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))
end

--- Tests whether a point in window coordinates lies inside this scroll viewport.
---@param px number Point X in window pixels
---@param py number Point Y in window pixels
---@return boolean True if the point is within the viewport bounds
function ScrollView:is_in_viewport(px, py)
  return ui.point_in_rect(px, py, self.viewport_x, self.viewport_y, self.viewport_w, self.viewport_h)
end

--- Translates a window Y coordinate to the corresponding virtual Y in scroll content space.
--- Useful for hit testing child widgets inside scrolled views.
---@param py number Y coordinate in window pixels
---@return number Translated content Y coordinate
function ScrollView:to_content_y(py)
  return py + math.floor(self.scroll_y)
end

--- Calculates the geometry of the macOS-style scrollbar thumb capsule.
--- Returns nil if content fits entirely within the viewport without scrolling.
---@return number? thumb_x Window X coordinate of thumb
---@return number? thumb_y Window Y coordinate of thumb
---@return number? thumb_w Width of thumb capsule (expands on hover/drag)
---@return number? thumb_h Height of thumb capsule
function ScrollView:get_thumb_rect()
  if self.content_h <= self.viewport_h or self.viewport_h <= 0 then
    return nil
  end

  local s = style.scale or 1.0
  local track_h = self.viewport_h

  -- Thumb height is proportional to the visible fraction of content, clamped to a 28px minimum
  local thumb_h = math.max(math.floor(28 * s), math.floor(track_h * (self.viewport_h / self.content_h)))
  local max_scroll = math.max(1, self.content_h - self.viewport_h)
  local scroll_ratio = math.max(0, math.min(1.0, self.scroll_y / max_scroll))

  -- Calculate vertical thumb position within the available track height
  local thumb_y = self.viewport_y + math.floor((track_h - thumb_h) * scroll_ratio)

  -- Width expands from resting size (e.g. 5px) to 7px during active interaction
  local thumb_w = math.floor((self.hovering_thumb or self.dragging) and (7 * s) or (self.scrollbar_width * s))
  local thumb_x = self.viewport_x + self.viewport_w - thumb_w - math.floor(3 * s)

  return thumb_x, thumb_y, thumb_w, thumb_h
end

--- Handles mousewheel scroll events.
--- Converts vertical wheel delta into scaled target offset with boundary clamping.
---@param dy number Vertical scroll delta (positive is up, negative is down)
---@param dx number? Horizontal scroll delta (reserved for horizontal scrolling)
---@return boolean True if the scroll event was consumed
function ScrollView:on_mouse_wheel(dy, dx)
  if not self:is_in_viewport(self.last_mouse_x or self.viewport_x, self.last_mouse_y or self.viewport_y) then
    return false
  end

  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  if max_scroll <= 0 then return false end

  local s = style.scale or 1.0
  local delta = (dy or 0) * (self.scroll_speed * s)

  -- Negative dy moves down the content (increasing scroll_to_y offset)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y - delta))
  self.fade_alpha = 1.0

  local core = require "core"
  if core then core.redraw = true end
  return true
end

--- Tracks cursor movement for scrollbar thumb hover detection and active drag physics.
---@param px number Mouse cursor X in window pixels
---@param py number Mouse cursor Y in window pixels
---@return boolean True if the mouse is hovering or dragging the scrollbar thumb
function ScrollView:on_mouse_moved(px, py)
  self.last_mouse_x = px
  self.last_mouse_y = py

  local s = style.scale or 1.0
  local tx, ty, tw, th = self:get_thumb_rect()
  if tx then
    -- Add a 4px optical hit margin around the narrow thumb for easier grabbing
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

    -- Map mouse pixel travel linearly to content scroll space
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

--- Initiates scrollbar thumb dragging if clicked on the thumb handle.
---@param button string|number Mouse button ("left" or 1)
---@param px number Mouse X coordinate in window pixels
---@param py number Mouse Y coordinate in window pixels
---@return boolean True if thumb dragging was initiated
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

--- Terminates active thumb dragging on mouse release.
---@param button string|number Mouse button ("left" or 1)
---@param px number Mouse X coordinate
---@param py number Mouse Y coordinate
---@return boolean True if active drag was concluded
function ScrollView:on_mouse_released(button, px, py)
  if self.dragging then
    self.dragging = false
    local core = require "core"
    if core then core.redraw = true end
    return true
  end
  return false
end

--- Steps 60 FPS exponential damping scroll physics and scrollbar fade timer.
function ScrollView:update()
  local max_scroll = math.max(0, self.content_h - self.viewport_h)
  self.scroll_to_y = math.max(0, math.min(max_scroll, self.scroll_to_y))

  -- Exponential damping towards target position: 32% step per frame yields native fluid feel
  if math.abs(self.scroll_to_y - self.scroll_y) > 0.5 then
    self.scroll_y = self.scroll_y + (self.scroll_to_y - self.scroll_y) * 0.32
    local core = require "core"
    if core then core.redraw = true end
  else
    self.scroll_y = self.scroll_to_y
  end

  -- Gradually fade out the scrollbar thumb after user stops scrolling or hovering
  if not self.dragging and not self.hovering_thumb and self.fade_alpha > 0 then
    self.fade_alpha = math.max(0, self.fade_alpha - 0.035)
    local core = require "core"
    if core then core.redraw = true end
  end
end

--- Begins viewport scissor clipping and calculates translated local drawing origin.
--- Must be matched by a corresponding sv:end_clip() call.
---@param x number Viewport top-left X in window coordinates
---@param y number Viewport top-left Y in window coordinates
---@param w number Viewport width
---@param h number Viewport height
---@param content_h number Total height of scrollable child content
---@return number ox Translated X origin to draw children at (x)
---@return number oy Translated Y origin to draw children at (y - scroll_y)
function ScrollView:begin_clip(x, y, w, h, content_h)
  self:set_viewport(x, y, w, h)
  self:set_content_size(w, content_h)
  self:update()

  renderer.set_clip_rect(x, y, w, h)
  return x, y - math.floor(self.scroll_y)
end

--- Concludes viewport clipping and renders the overlaid native-style capsule scrollbar thumb.
function ScrollView:end_clip()
  -- Reset clipping rectangle to full window bounds
  local win_w, win_h = renderer.get_size()
  renderer.set_clip_rect(0, 0, win_w, win_h)

  -- Render macOS-style modern rounded capsule scrollbar thumb if visible
  local tx, ty, tw, th = self:get_thumb_rect()
  if tx and (self.fade_alpha > 0.05 or self.dragging or self.hovering_thumb) then
    local effective_alpha = math.floor(self.fade_alpha * ((self.dragging or self.hovering_thumb) and 180 or 100))
    local thumb_col = { 255, 255, 255, effective_alpha }
    ui.draw_rounded_rect(tx, ty, tw, th, math.floor(tw / 2), thumb_col)
  end
end

return ScrollView

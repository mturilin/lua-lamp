-- Lua Lamp UI Helper Functions & Vector Drawing Primitives
-- Provides reusable drawing components on top of the SDL2 renderer.

local ui = {}

--- Check if point (px, py) is inside rectangle (rx, ry, rw, rh)
function ui.point_in_rect(px, py, rx, ry, rw, rh)
  return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

--- Draw filled rectangle with optional border
function ui.draw_box(x, y, w, h, bg_color, border_color, border_width)
  if bg_color and bg_color[4] > 0 then
    renderer.draw_rect(x, y, w, h, bg_color)
  end
  if border_color and border_width and border_width > 0 and border_color[4] > 0 then
    local bw = border_width
    renderer.draw_rect(x, y, w, bw, border_color)                -- Top
    renderer.draw_rect(x, y + h - bw, w, bw, border_color)        -- Bottom
    renderer.draw_rect(x, y + bw, bw, h - bw * 2, border_color)   -- Left
    renderer.draw_rect(x + w - bw, y + bw, bw, h - bw * 2, border_color) -- Right
  end
end

--- Draw rounded box (subtle corner bevel/radius using stepped rectangles)
function ui.draw_rounded_box(x, y, w, h, radius, bg_color, border_color, border_width)
  local r = math.min(radius or 6, math.floor(h / 2), math.floor(w / 2))
  if r <= 2 then
    return ui.draw_box(x, y, w, h, bg_color, border_color, border_width)
  end

  -- Background fill
  if bg_color and bg_color[4] > 0 then
    renderer.draw_rect(x + r, y, w - r * 2, h, bg_color)
    renderer.draw_rect(x, y + r, r, h - r * 2, bg_color)
    renderer.draw_rect(x + w - r, y + r, r, h - r * 2, bg_color)

    -- Soft corner stepped pixels
    local steps = math.min(r, 6)
    for i = 1, steps do
      local inset = math.floor(r * (1 - math.sin(math.acos((steps - i) / steps))))
      local cy1 = y + steps - i
      local cy2 = y + h - steps + i - 1
      renderer.draw_rect(x + inset, cy1, r - inset, 1, bg_color)
      renderer.draw_rect(x + w - r, cy1, r - inset, 1, bg_color)
      renderer.draw_rect(x + inset, cy2, r - inset, 1, bg_color)
      renderer.draw_rect(x + w - r, cy2, r - inset, 1, bg_color)
    end
  end

  -- Optional border
  if border_color and border_width and border_width > 0 and border_color[4] > 0 then
    local bw = border_width
    renderer.draw_rect(x + r, y, w - r * 2, bw, border_color)
    renderer.draw_rect(x + r, y + h - bw, w - r * 2, bw, border_color)
    renderer.draw_rect(x, y + r, bw, h - r * 2, border_color)
    renderer.draw_rect(x + w - bw, y + r, bw, h - r * 2, border_color)
  end
end

--- Draw centered text horizontally and vertically inside bounding box
function ui.draw_centered_text(font, text, x, y, w, h, color)
  if not font or not text then return end
  local text_w = font:get_width(text)
  local text_h = font:get_height()
  local tx = math.floor(x + (w - text_w) / 2)
  local ty = math.floor(y + (h - text_h) / 2)
  renderer.draw_text(font, text, tx, ty, color)
  return tx, ty, text_w, text_h
end

--- Draw filled circle approximation
function ui.draw_circle(cx, cy, radius, color)
  if not color or color[4] <= 0 or radius <= 0 then return end
  local r = math.floor(radius)
  for dy = -r, r do
    local dx = math.floor(math.sqrt(math.max(0, r * r - dy * dy)))
    renderer.draw_rect(cx - dx, cy + dy, dx * 2, 1, color)
  end
end

--- Draw pill badge (e.g. tag or status badge)
function ui.draw_pill_badge(font, text, x, y, bg_color, text_color, pad_x, pad_y)
  local px = pad_x or 10
  local py = pad_y or 4
  local tw = font:get_width(text)
  local th = font:get_height()
  local bw = tw + px * 2
  local bh = th + py * 2
  ui.draw_rounded_box(x, y, bw, bh, math.floor(bh / 2), bg_color, nil, 0)
  renderer.draw_text(font, text, x + px, y + py, text_color)
  return bw, bh
end

return ui

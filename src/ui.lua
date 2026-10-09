-- Lua Lamp UI Helper Functions & Vector Drawing Primitives
-- Provides reusable drawing components on top of the SDL3 renderer.

local style = require "src.style"
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

--- Draw filled rounded rectangle with smooth anti-aliased corners
local function draw_rounded_fill(x, y, w, h, radius, col)
  if not col or (col[4] and col[4] <= 0) then return end
  local cr, cg, cb = col[1] or 0, col[2] or 0, col[3] or 0
  local base_a = col[4] or 255

  -- Middle body
  if h > 2 * radius then
    renderer.draw_rect(x, y + radius, w, h - 2 * radius, col)
  end

  -- Top and bottom curved caps
  for dy = 0, radius - 1 do
    local dist_y = (radius - 0.5) - dy
    local dist_x = math.sqrt(math.max(0, radius * radius - dist_y * dist_y))
    local exact_inset = radius - dist_x
    local floor_inset = math.floor(exact_inset)
    local coverage = 1.0 - (exact_inset - floor_inset)

    local solid_inset = floor_inset + 1
    local solid_w = w - 2 * solid_inset

    if solid_w > 0 then
      renderer.draw_rect(x + solid_inset, y + dy, solid_w, 1, col)
      renderer.draw_rect(x + solid_inset, y + h - 1 - dy, solid_w, 1, col)
    end

    if coverage > 0.05 then
      local aa_col = { cr, cg, cb, math.floor(base_a * coverage) }
      renderer.draw_rect(x + floor_inset, y + dy, 1, 1, aa_col)
      renderer.draw_rect(x + floor_inset, y + h - 1 - dy, 1, 1, aa_col)
      renderer.draw_rect(x + w - 1 - floor_inset, y + dy, 1, 1, aa_col)
      renderer.draw_rect(x + w - 1 - floor_inset, y + h - 1 - dy, 1, 1, aa_col)
    end
  end
end

--- Draw rounded rectangle border with smooth anti-aliased corners (1px thickness)
local function draw_rounded_border_1px(x, y, w, h, radius, col)
  if not col or (col[4] and col[4] <= 0) then return end
  local cr, cg, cb = col[1] or 0, col[2] or 0, col[3] or 0
  local base_a = col[4] or 255

  -- Straight horizontal segments
  if w > 2 * radius then
    renderer.draw_rect(x + radius, y, w - 2 * radius, 1, col)
    renderer.draw_rect(x + radius, y + h - 1, w - 2 * radius, 1, col)
  end

  -- Straight vertical segments
  if h > 2 * radius then
    renderer.draw_rect(x, y + radius, 1, h - 2 * radius, col)
    renderer.draw_rect(x + w - 1, y + radius, 1, h - 2 * radius, col)
  end

  -- Curved corner strokes
  for dy = 0, radius - 1 do
    local dist_y = (radius - 0.5) - dy
    local dist_x = math.sqrt(math.max(0, radius * radius - dist_y * dist_y))
    local exact_inset = radius - dist_x
    local floor_inset = math.floor(exact_inset)
    local coverage = 1.0 - (exact_inset - floor_inset)

    local stroke_col = col
    if coverage < 0.95 then
      stroke_col = { cr, cg, cb, math.floor(base_a * coverage) }
    end
    renderer.draw_rect(x + floor_inset, y + dy, 1, 1, stroke_col)
    renderer.draw_rect(x + floor_inset, y + h - 1 - dy, 1, 1, stroke_col)
    renderer.draw_rect(x + w - 1 - floor_inset, y + dy, 1, 1, stroke_col)
    renderer.draw_rect(x + w - 1 - floor_inset, y + h - 1 - dy, 1, 1, stroke_col)
  end
end

--- Draw rounded box (smooth anti-aliased corners for both fill and border)
function ui.draw_rounded_box(x, y, w, h, radius, bg_color, border_color, border_width)
  x = math.floor(x)
  y = math.floor(y)
  w = math.floor(w)
  h = math.floor(h)
  local r = math.floor(math.min(radius or 6, w / 2, h / 2))

  if r <= 1 then
    return ui.draw_box(x, y, w, h, bg_color, border_color, border_width)
  end

  -- 1. Background fill
  if bg_color and (not bg_color[4] or bg_color[4] > 0) then
    draw_rounded_fill(x, y, w, h, r, bg_color)
  end

  -- 2. Optional border
  if border_color and border_width and border_width > 0 and (not border_color[4] or border_color[4] > 0) then
    local bw = math.floor(border_width)
    for b = 0, bw - 1 do
      local cur_r = math.max(0, r - b)
      if cur_r <= 1 then
        ui.draw_box(x + b, y + b, w - b * 2, h - b * 2, nil, border_color, 1)
      else
        draw_rounded_border_1px(x + b, y + b, w - b * 2, h - b * 2, cur_r, border_color)
      end
    end
  end
end

--- Draw centered text horizontally and vertically inside bounding box with optical baseline compensation
function ui.draw_centered_text(font, text, x, y, w, h, color, optical_shift)
  if not font or not text then return end
  local scale = SCALE or 1
  local shift = optical_shift
  if shift == nil then
    shift = math.floor(1.2 * scale)
  end
  local text_w = font:get_width(text)
  local text_h = font:get_height()
  local tx = math.floor(x + (w - text_w) / 2)
  local ty = math.floor(y + (h - text_h) / 2) + shift
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
  local scale = SCALE or 1
  local px = pad_x or math.floor(10 * scale)
  local py = pad_y or math.floor(4 * scale)
  local tw = font:get_width(text)
  local th = font:get_height()
  local bw = tw + px * 2
  local bh = th + py * 2
  ui.draw_rounded_box(x, y, bw, bh, math.floor(bh / 2), bg_color, nil, 0)
  local optical_shift = math.floor(1.2 * scale)
  renderer.draw_text(font, text, x + px, y + py + optical_shift, text_color)
  return bw, bh
end

--- Draw centered icon and text together horizontally inside bounding box with decoupled optical alignment
function ui.draw_centered_icon_and_text(icon_font, icon_text, text_font, label_text, x, y, w, h, icon_color, label_color, gap)
  local scale = SCALE or 1
  gap = gap or math.floor(8 * scale)
  local iw = (icon_font and icon_text) and icon_font:get_width(icon_text) or 0
  local tw = (text_font and label_text) and text_font:get_width(label_text) or 0
  local total_w = (iw > 0 and tw > 0) and (iw + gap + tw) or (iw + tw)

  local cur_x = math.floor(x + (w - total_w) / 2)
  if iw > 0 then
    local icon_shift = math.floor(1.0 * scale)
    local iy = math.floor(y + (h - icon_font:get_height()) / 2) + icon_shift
    renderer.draw_text(icon_font, icon_text, cur_x, iy, icon_color or label_color)
    cur_x = cur_x + iw + gap
  end
  if tw > 0 then
    local text_shift = math.floor(1.2 * scale)
    local ty = math.floor(y + (h - text_font:get_height()) / 2) + text_shift
    renderer.draw_text(text_font, label_text, cur_x, ty, label_color)
  end
  return total_w
end

--- Word-wrap text to fit within max_w pixels using font measurement.
--- Respects existing newlines and wraps at word boundaries.
---@param font renderer.font
---@param text string
---@param max_w number Maximum width in pixels
---@return string[] lines Array of wrapped text lines
function ui.wrap_text(font, text, max_w)
  if not font or not text or max_w <= 0 then return { tostring(text or "") } end
  local lines = {}

  for raw_line in (tostring(text) .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if font:get_width(raw_line) <= max_w then
      table.insert(lines, raw_line)
    else
      local cur_line = ""
      for word in raw_line:gmatch("%S+") do
        local test_line = (cur_line == "") and word or (cur_line .. " " .. word)
        if font:get_width(test_line) <= max_w then
          cur_line = test_line
        else
          if cur_line ~= "" then
            table.insert(lines, cur_line)
            cur_line = word
          else
            -- If a single word is longer than max_w, break it character-by-character
            local partial = ""
            for i = 1, #word do
              local ch = word:sub(i, i)
              if font:get_width(partial .. ch) <= max_w then
                partial = partial .. ch
              else
                table.insert(lines, partial)
                partial = ch
              end
            end
            cur_line = partial
          end
        end
      end
      if cur_line ~= "" then
        table.insert(lines, cur_line)
      end
    end
  end

  if #lines == 0 then table.insert(lines, "") end
  return lines
end

--- Draw multi-line text with automatic word wrapping within max_w
---@param font renderer.font
---@param text string
---@param x number Left coordinate
---@param y number Top coordinate
---@param max_w number Maximum width in pixels
---@param color renderer.color
---@param line_spacing? number Additional spacing between lines (defaults to 3 * SCALE)
---@return number total_h Total rendered height in pixels
---@return number count Number of lines rendered
function ui.draw_wrapped_text(font, text, x, y, max_w, color, line_spacing)
  if not font or not text then return 0, 0 end
  local scale = SCALE or 1
  local lh = font:get_height() + (line_spacing or math.floor(3 * scale))
  local lines = ui.wrap_text(font, text, max_w)
  local cur_y = y
  for _, line in ipairs(lines) do
    renderer.draw_text(font, line, x, cur_y, color)
    cur_y = cur_y + lh
  end
  return #lines * lh, #lines
end

--------------------------------------------------------------------------------
-- Pinglet Button Highlight Standard Primitives
--------------------------------------------------------------------------------

--- Draw sunken capsule track for segmented control groups (Pinglet style)
---@param x number Left coordinate
---@param y number Top coordinate
---@param w number Width
---@param h number Height
---@param radius? number Corner radius (defaults to math.floor(8 * SCALE))
---@param bg_color? renderer.color Background color
---@param border_color? renderer.color Optional border color
function ui.draw_segmented_track(x, y, w, h, radius, bg_color, border_color)
  local style = require "src.style"
  local s = SCALE or 1
  local c = style.colors
  local r = radius or math.floor(8 * s)
  local bg = bg_color or c.track_bg or { 15, 20, 28, 255 }
  local border = border_color or c.track_border
  ui.draw_rounded_box(x, y, w, h, r, bg, border, border and 1 or 0)
end

--- Standard Pinglet button drawing primitive adhering to the 5 Cardinal Directives:
--- 1. Invariant: Zero 1px wireframe border strokes (borderless filled surface)
--- 2. Active Solid (e.g. Pinglet '60s'): Vibrant filled pill with inverted dark high-contrast text
--- 3. Active Tinted (e.g. Pinglet '123 Follow', '+ Add Target'): Luminous translucent tint with glowing text & icon
--- 4. Hover: Smooth translucent pill highlight
--- 5. Resting: Transparent (inside segmented track) or subtle surface
--- 6. Optical baseline compensation applied for text and icon independently
---@param text_font renderer.font Font for the label
---@param label string Text label
---@param x number Left coordinate
---@param y number Top coordinate
---@param w number Width
---@param h number Height
---@param opts? table Options:
---   - variant: "solid" | "tinted" | "surface" | "ghost" (default: "solid" if is_active, else "ghost")
---   - is_active: boolean Whether button is currently active / toggled
---   - is_hover: boolean Whether mouse cursor is hovering over button
---   - icon: string Optional Tabler icon glyph
---   - icon_font: renderer.font Font for icon (defaults to style.font_icon)
---   - accent_theme: "cyan" | "gold" (default: "cyan" for Pinglet sky-400)
---   - radius: number Corner radius (default: math.floor(6 * SCALE))
---   - gap: number Gap between icon and label (default: math.floor(7 * SCALE))
---@return number x, number y, number w, number h
function ui.draw_button(text_font, label, x, y, w, h, opts)
  opts = opts or {}
  local style = require "src.style"
  local s = SCALE or 1
  local c = style.colors
  local radius = opts.radius or math.floor(6 * s)
  local is_active = opts.is_active or false
  local is_hover = opts.is_hover or false
  local accent = opts.accent_theme or "cyan"
  local variant = opts.variant

  if not variant then
    if is_active then
      variant = "solid"
    elseif is_hover then
      variant = "hover"
    else
      variant = "ghost"
    end
  end

  local bg_col = nil
  local text_col = c.text_primary
  local icon_col = c.text_primary

  if is_active then
    if variant == "solid" then
      -- Vibrant solid pill (Pinglet 60s active button style)
      bg_col = (accent == "gold") and c.btn_gold_bg or c.btn_accent_bg
      text_col = (accent == "gold") and c.btn_gold_text or c.btn_accent_text
      icon_col = text_col
    elseif variant == "tinted" then
      -- Luminous translucent tinted pill (Pinglet Follow / Add Target style)
      bg_col = is_hover and ((accent == "gold") and c.btn_gold_tint_hover or c.btn_tint_hover)
                         or ((accent == "gold") and c.btn_gold_tint_bg or c.btn_tint_bg)
      text_col = (accent == "gold") and c.btn_gold_tint_text or c.btn_tint_text
      icon_col = text_col
    else
      bg_col = is_hover and c.surface_hover or c.surface_active
      text_col = (accent == "gold") and c.lamp_gold or c.btn_accent_bg
      icon_col = text_col
    end
  else
    if is_hover then
      -- Smooth translucent hover highlight pill
      if variant == "tinted" then
        bg_col = (accent == "gold") and c.btn_gold_tint_hover or c.btn_tint_hover
        text_col = (accent == "gold") and c.btn_gold_tint_text or c.btn_tint_text
      else
        bg_col = c.btn_surface_hover or c.surface_hover
        text_col = c.btn_surface_text or c.text_primary
      end
      icon_col = text_col
    else
      -- Resting state
      if variant == "surface" then
        bg_col = c.btn_surface_bg or c.surface_hover
        text_col = c.btn_surface_muted or c.text_secondary
        icon_col = text_col
      elseif variant == "tinted" then
        bg_col = (accent == "gold") and c.btn_gold_tint_bg or c.btn_tint_bg
        text_col = (accent == "gold") and c.btn_gold_tint_text or c.btn_tint_text
        icon_col = text_col
      else
        -- Ghost (inside segmented track): transparent background
        bg_col = nil
        text_col = c.btn_surface_muted or c.text_secondary
        icon_col = text_col
      end
    end
  end

  -- Draw borderless pill background with subpixel AA corners
  if bg_col then
    ui.draw_rounded_box(x, y, w, h, radius, bg_col, nil, 0)
  end

  -- Draw label and icon with decoupled optical centerlines
  if opts.icon and opts.icon ~= "" then
    local ifont = opts.icon_font or style.font_icon
    ui.draw_centered_icon_and_text(ifont, opts.icon, text_font, label, x, y, w, h, icon_col, text_col, opts.gap or math.floor(7 * s))
  else
    ui.draw_centered_text(text_font, label, x, y, w, h, text_col)
  end

  return x, y, w, h
end

--- Draw interactive horizontal Slider
---@param x number
---@param y number
---@param w number
---@param h number
---@param value number 0.0 to 1.0
---@param opts { accent_theme: string?, is_hover: boolean?, is_dragging: boolean?, label: string? }?
function ui.draw_slider(x, y, w, h, value, opts)
  opts = opts or {}
  local s = style.scale or 1.0
  local c = style.colors

  value = math.max(0, math.min(1.0, value or 0))

  local track_h = math.floor(6 * s)
  local track_y = y + math.floor((h - track_h) / 2)
  local track_r = math.floor(track_h / 2)

  -- 1. Recessed track background
  ui.draw_rounded_box(x, track_y, w, track_h, track_r, c.track_bg or { 15, 23, 42, 180 }, nil, 0)

  -- 2. Filled active portion
  local fill_w = math.floor(w * value)
  if fill_w > track_h then
    local fill_col = (opts.accent_theme == "amber") and c.lamp_gold or (c.btn_accent_bg or { 56, 189, 248, 255 })
    ui.draw_rounded_box(x, track_y, fill_w, track_h, track_r, fill_col, nil, 0)
  end

  -- 3. Draggable circular thumb
  local thumb_r = math.floor((opts.is_dragging or opts.is_hover) and (10 * s) or (8 * s))
  local thumb_cx = x + math.floor(value * w)
  local thumb_cy = y + math.floor(h / 2)

  -- Thumb glow
  if opts.is_hover or opts.is_dragging then
    ui.draw_circle(thumb_cx, thumb_cy, thumb_r + math.floor(4 * s), { 56, 189, 248, 50 })
  end

  -- Thumb body
  ui.draw_circle(thumb_cx, thumb_cy, thumb_r, { 255, 255, 255, 255 })
  ui.draw_circle(thumb_cx, thumb_cy, math.floor(thumb_r / 2), (opts.accent_theme == "amber") and c.lamp_gold or { 56, 189, 248, 255 })

  return x, y, w, h
end

--- Draw interactive Toggle Switch
---@param x number
---@param y number
---@param w number
---@param h number
---@param active boolean
---@param opts { accent_theme: string?, is_hover: boolean? }?
function ui.draw_toggle(x, y, w, h, active, opts)
  opts = opts or {}
  local s = style.scale or 1.0
  local c = style.colors

  local r = math.floor(h / 2)
  local bg_col
  if active then
    bg_col = (opts.accent_theme == "emerald") and { 16, 185, 129, 255 } or (c.btn_accent_bg or { 56, 189, 248, 255 })
  else
    bg_col = opts.is_hover and { 255, 255, 255, 38 } or { 255, 255, 255, 22 }
  end

  -- Track capsule
  ui.draw_rounded_box(x, y, w, h, r, bg_col, nil, 0)

  -- Sliding circular thumb
  local thumb_pad = math.floor(3 * s)
  local thumb_d = h - thumb_pad * 2
  local thumb_r = math.floor(thumb_d / 2)
  local thumb_cx = active and (x + w - thumb_pad - thumb_r) or (x + thumb_pad + thumb_r)
  local thumb_cy = y + math.floor(h / 2)

  ui.draw_circle(thumb_cx, thumb_cy, thumb_r, { 255, 255, 255, 255 })

  return x, y, w, h
end

--- Draw interactive CheckBox with label
---@param font any
---@param x number
---@param y number
---@param size number
---@param checked boolean
---@param label string?
---@param opts { is_hover: boolean? }?
function ui.draw_checkbox(font, x, y, size, checked, label, opts)
  opts = opts or {}
  local s = style.scale or 1.0
  local c = style.colors
  local icons = require "src.icons"

  local r = math.floor(4 * s)
  local box_bg
  local check_col = { 255, 255, 255, 255 }

  if checked then
    box_bg = c.btn_accent_bg or { 56, 189, 248, 255 }
    check_col = { 15, 23, 42, 255 } -- Dark checkmark on active pill
    ui.draw_rounded_box(x, y, size, size, r, box_bg, nil, 0)
    local check_icon = icons.check or "✓"
    local font_icon = style.font_icon or font
    local iw = font_icon:get_width(check_icon)
    local ix = x + math.floor((size - iw) / 2)
    local iy = y + math.floor((size - font_icon:get_height()) / 2) + math.floor(1.0 * s)
    renderer.draw_text(font_icon, check_icon, ix, iy, check_col)
  else
    box_bg = opts.is_hover and { 255, 255, 255, 20 } or { 255, 255, 255, 10 }
    local border_col = opts.is_hover and { 255, 255, 255, 80 } or { 255, 255, 255, 40 }
    ui.draw_rounded_box(x, y, size, size, r, box_bg, border_col, 1)
  end

  local total_w = size
  if label and label ~= "" then
    local lx = x + size + math.floor(8 * s)
    local ly = y + math.floor((size - font:get_height()) / 2) + math.floor(1.2 * s)
    renderer.draw_text(font, label, lx, ly, opts.is_hover and c.text_primary or c.text_secondary)
    total_w = total_w + math.floor(8 * s) + font:get_width(label)
  end

  return x, y, total_w, size
end

--- Draw interactive Progress Bar
---@param x number
---@param y number
---@param w number
---@param h number
---@param progress number 0.0 to 1.0
---@param opts { accent_theme: string?, show_label: boolean? }?
function ui.draw_progressbar(x, y, w, h, progress, opts)
  opts = opts or {}
  local s = style.scale or 1.0
  local c = style.colors

  progress = math.max(0, math.min(1.0, progress or 0))
  local r = math.floor(h / 2)

  -- Recessed track
  ui.draw_rounded_box(x, y, w, h, r, c.track_bg or { 15, 23, 42, 180 }, nil, 0)

  -- Fill
  local fill_w = math.floor(w * progress)
  if fill_w > r then
    local fill_col = (opts.accent_theme == "emerald") and { 16, 185, 129, 255 } or (c.btn_accent_bg or { 56, 189, 248, 255 })
    ui.draw_rounded_box(x, y, fill_w, h, r, fill_col, nil, 0)
  end

  return x, y, w, h
end

--- Draw interactive Text Input Box
---@param font any
---@param x number
---@param y number
---@param w number
---@param h number
---@param text string
---@param is_focused boolean
---@param opts { placeholder: string?, is_hover: boolean? }?
function ui.draw_input_box(font, x, y, w, h, text, is_focused, opts)
  opts = opts or {}
  local s = style.scale or 1.0
  local c = style.colors

  local r = math.floor(6 * s)
  local bg_col = opts.is_hover and { 255, 255, 255, 18 } or { 255, 255, 255, 12 }
  local border_col = is_focused and (c.btn_accent_bg or { 56, 189, 248, 255 }) or (opts.is_hover and { 255, 255, 255, 45 } or { 255, 255, 255, 25 })

  ui.draw_rounded_box(x, y, w, h, r, bg_col, border_col, is_focused and 2 or 1)

  local pad_x = math.floor(12 * s)
  local ty = y + math.floor((h - font:get_height()) / 2) + math.floor(1.2 * s)

  if text and text ~= "" then
    renderer.draw_text(font, text, x + pad_x, ty, c.text_primary)
    if is_focused then
      local tw = font:get_width(text)
      local cx = x + pad_x + tw + 1
      renderer.draw_rect(cx, ty - 1, 2, font:get_height() + 2, c.text_primary)
    end
  else
    local placeholder = opts.placeholder or "Type here..."
    renderer.draw_text(font, placeholder, x + pad_x, ty, c.text_tertiary)
    if is_focused then
      renderer.draw_rect(x + pad_x, ty - 1, 2, font:get_height() + 2, c.text_primary)
    end
  end

  return x, y, w, h
end

-- Backward compatibility and intuitive alias
ui.draw_rounded_rect = ui.draw_rounded_box

return ui

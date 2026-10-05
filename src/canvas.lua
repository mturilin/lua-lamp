-- Lua Lamp Blank Canvas Component
-- Renders the central "Hello World" canvas with interactive glowing lamp,
-- live coordinate telemetry, click ripples, and theme toggle controls.

local style = require "src.style"
local ui = require "src.ui"

local canvas = {
  lamp_on = true,
  glow_time = 0,
  click_ripples = {},
  mouse_x = 0,
  mouse_y = 0,
  hover_theme_btn = false,
  hover_pulse_btn = false,
  frame_count = 0,
  start_time = 0,
}

function canvas.init()
  canvas.start_time = system.get_time()
end

--------------------------------------------------------------------------------
-- 1. Animation & State Updates
--------------------------------------------------------------------------------

function canvas.update(dt)
  canvas.glow_time = canvas.glow_time + dt
  canvas.frame_count = canvas.frame_count + 1

  -- Update click ripples
  for i = #canvas.click_ripples, 1, -1 do
    local r = canvas.click_ripples[i]
    r.radius = r.radius + dt * 180 * style.scale
    r.alpha = r.alpha - dt * 1.5
    if r.alpha <= 0 or r.radius >= r.max_radius then
      table.remove(canvas.click_ripples, i)
    end
  end
end

function canvas.add_ripple(x, y)
  table.insert(canvas.click_ripples, {
    x = x,
    y = y,
    radius = 6 * style.scale,
    max_radius = 90 * style.scale,
    alpha = 1.0,
  })
end

function canvas.toggle_lamp()
  canvas.lamp_on = not canvas.lamp_on
end

--------------------------------------------------------------------------------
-- 2. Mouse & Keyboard Event Handlers
--------------------------------------------------------------------------------

function canvas.on_mouse_moved(px, py)
  canvas.mouse_x = px
  canvas.mouse_y = py
end

function canvas.on_mouse_pressed(button, px, py, core)
  canvas.add_ripple(px, py)

  -- Check if clicked theme button or pulse button
  if canvas.hover_theme_btn then
    style.toggle_theme()
    return true
  end
  if canvas.hover_pulse_btn then
    canvas.toggle_lamp()
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- 3. Rendering Compositor
--------------------------------------------------------------------------------

function canvas.draw(win_w, win_h)
  local c = style.colors
  local s = style.scale

  -- 1. Blank Canvas Background
  renderer.draw_rect(0, 0, win_w, win_h, c.background)

  -- 2. Subtle Grid Pattern on the blank canvas
  local grid_size = math.floor(32 * s)
  local grid_color = { c.border[1], c.border[2], c.border[3], 35 }
  for x = 0, win_w, grid_size do
    renderer.draw_rect(x, 0, 1, win_h, grid_color)
  end
  for y = 0, win_h, grid_size do
    renderer.draw_rect(0, y, win_w, 1, grid_color)
  end

  -- 3. Draw Click Ripples
  for _, r in ipairs(canvas.click_ripples) do
    local alpha = math.floor(math.max(0, math.min(255, r.alpha * 180)))
    local rip_color = { c.lamp_gold[1], c.lamp_gold[2], c.lamp_gold[3], alpha }
    ui.draw_circle(r.x, r.y, r.radius, rip_color)
  end

  -- 4. Central "Hello World" Stage Card
  local card_w = math.min(win_w - 40 * s, math.floor(580 * s))
  local card_h = math.floor(430 * s)
  local card_x = math.floor((win_w - card_w) / 2)
  local card_y = math.floor((win_h - card_h) / 2)

  -- Card shadow & background surface
  ui.draw_rounded_box(card_x, card_y + 4 * s, card_w, card_h, 14 * s, { 0, 0, 0, 45 }, nil, 0)
  ui.draw_rounded_box(card_x, card_y, card_w, card_h, 14 * s, c.surface, c.border, 1)

  -- 5. Animated Lamp Icon in the Center
  local lamp_cx = math.floor(card_x + card_w / 2)
  local lamp_cy = card_y + math.floor(70 * s)

  -- Ambient Lamp Glow Pulse
  if canvas.lamp_on then
    local pulse = 0.5 + 0.5 * math.sin(canvas.glow_time * 3.0)
    local glow_r1 = math.floor((55 + pulse * 15) * s)
    local glow_r2 = math.floor((35 + pulse * 10) * s)

    local outer_alpha = math.floor(25 + pulse * 15)
    local inner_alpha = math.floor(55 + pulse * 25)
    ui.draw_circle(lamp_cx, lamp_cy, glow_r1, { c.lamp_amber[1], c.lamp_amber[2], c.lamp_amber[3], outer_alpha })
    ui.draw_circle(lamp_cx, lamp_cy, glow_r2, { c.lamp_gold[1], c.lamp_gold[2], c.lamp_gold[3], inner_alpha })
  end

  -- Lamp Bulb Head (Circle & socket)
  local bulb_r = math.floor(22 * s)
  local bulb_bg = canvas.lamp_on and c.lamp_gold or c.text_tertiary
  ui.draw_circle(lamp_cx, lamp_cy, bulb_r, bulb_bg)

  -- Hot white/gold core filament
  if canvas.lamp_on then
    local core_r = math.floor(10 * s)
    ui.draw_circle(lamp_cx, lamp_cy, core_r, { 255, 255, 240, 230 })
  end

  -- Metallic socket base below bulb
  local socket_w = math.floor(16 * s)
  local socket_h = math.floor(12 * s)
  local socket_x = lamp_cx - math.floor(socket_w / 2)
  local socket_y = lamp_cy + bulb_r - 2 * s
  ui.draw_rounded_box(socket_x, socket_y, socket_w, socket_h, 2 * s, c.text_secondary, nil, 0)
  ui.draw_box(socket_x + 2 * s, socket_y + socket_h, socket_w - 4 * s, math.floor(4 * s), c.text_tertiary, nil, 0)

  -- 6. "Hello, World!" Heading
  local text_y = lamp_cy + bulb_r + math.floor(32 * s)
  ui.draw_centered_text(style.font_hero, "Hello, World!", card_x, text_y, card_w, style.font_hero:get_height(), c.text_primary)

  -- 7. App Title & Subtitle
  text_y = text_y + style.font_hero:get_height() + math.floor(8 * s)
  ui.draw_centered_text(style.font_heading, "Welcome to Lua Lamp", card_x, text_y, card_w, style.font_heading:get_height(), c.lamp_gold)

  text_y = text_y + style.font_heading:get_height() + math.floor(8 * s)
  local sub_str = "A lightweight, cross-platform Lua & SDL2 starter template"
  ui.draw_centered_text(style.font_normal, sub_str, card_x, text_y, card_w, style.font_normal:get_height(), c.text_secondary)

  -- 8. Technology Pills / Badges
  text_y = text_y + style.font_normal:get_height() + math.floor(18 * s)
  local badges = { "Lua 5.4", "SDL2 Platform", "60 FPS Compositor", "Cross-Platform" }
  local total_badge_w = 0
  local badge_widths = {}
  for i, b in ipairs(badges) do
    local bw = style.font_small:get_width(b) + 16 * s
    badge_widths[i] = bw
    total_badge_w = total_badge_w + bw + 8 * s
  end
  total_badge_w = total_badge_w - 8 * s

  local cur_bx = math.floor(card_x + (card_w - total_badge_w) / 2)
  for i, b in ipairs(badges) do
    ui.draw_pill_badge(style.font_small, b, cur_bx, text_y, c.pill_bg, c.pill_text, 8 * s, 3 * s)
    cur_bx = cur_bx + badge_widths[i] + 8 * s
  end

  -- 9. Interactive Action Buttons
  text_y = text_y + math.floor(36 * s)
  local btn_w = math.floor(150 * s)
  local btn_h = math.floor(32 * s)
  local btn_gap = math.floor(16 * s)
  local btn_total = btn_w * 2 + btn_gap

  local b1_x = math.floor(card_x + (card_w - btn_total) / 2)
  local b2_x = b1_x + btn_w + btn_gap

  -- Button 1: Toggle Theme
  canvas.hover_theme_btn = ui.point_in_rect(canvas.mouse_x, canvas.mouse_y, b1_x, text_y, btn_w, btn_h)
  local b1_bg = canvas.hover_theme_btn and c.surface_hover or c.surface_active
  ui.draw_rounded_box(b1_x, text_y, btn_w, btn_h, 6 * s, b1_bg, c.border, 1)
  local theme_label = (style.current_theme == "dark") and "☀  Light Theme" or "☾  Dark Theme"
  ui.draw_centered_text(style.font_normal, theme_label, b1_x, text_y, btn_w, btn_h, c.text_primary)

  -- Button 2: Toggle Lamp
  canvas.hover_pulse_btn = ui.point_in_rect(canvas.mouse_x, canvas.mouse_y, b2_x, text_y, btn_w, btn_h)
  local b2_bg = canvas.hover_pulse_btn and c.surface_hover or c.surface_active
  ui.draw_rounded_box(b2_x, text_y, btn_w, btn_h, 6 * s, b2_bg, c.border, 1)
  local lamp_label = canvas.lamp_on and "Turn Lamp Off" or "Turn Lamp On"
  ui.draw_centered_text(style.font_normal, lamp_label, b2_x, text_y, btn_w, btn_h, c.text_primary)

  -- 10. Live Status Bar Inside Card
  local footer_h = math.floor(34 * s)
  local footer_y = card_y + card_h - footer_h
  ui.draw_box(card_x, footer_y, card_w, 1, c.border)

  local uptime = math.max(0, math.floor(system.get_time() - canvas.start_time))
  local min = math.floor(uptime / 60)
  local sec = uptime % 60
  local stat_left = string.format("Canvas: %dx%d  |  Mouse: (%d, %d)", win_w, win_h, canvas.mouse_x, canvas.mouse_y)
  local stat_right = string.format("FPS: 60  |  Uptime: %02d:%02d", min, sec)

  renderer.draw_text(style.font_small, stat_left, card_x + 14 * s, footer_y + 8 * s, c.text_tertiary)
  local rw = style.font_small:get_width(stat_right)
  renderer.draw_text(style.font_small, stat_right, card_x + card_w - rw - 14 * s, footer_y + 8 * s, c.text_tertiary)

  -- 11. Bottom Help Hint Bar (Fixed at window bottom)
  local hint_y = win_h - math.floor(26 * s)
  local hint_text = "Press <Space> to toggle lamp glow  •  <T> to switch theme  •  <Click> to spawn ripple  •  <Q> to quit"
  ui.draw_centered_text(style.font_small, hint_text, 0, hint_y, win_w, style.font_small:get_height(), c.text_tertiary)
end

return canvas

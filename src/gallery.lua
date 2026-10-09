-- Lua Lamp — Interactive Framework Component Showcase & Gallery
-- Provides live interactive demos for all framework components:
-- Buttons, Segmented Tracks, Sliders, Toggles, Checkboxes, Text Inputs,
-- Progress Bars, Nested ScrollViews, Permission Banners, Modals, and Iconography.

local style = require "src.style"
local ui = require "src.ui"
local icons = require "src.icons"
local ScrollView = require "src.scroll_view"
local permissions = require "src.permissions"

local gallery = {
  active_tab = "all",
  scroll_view = ScrollView(),
  nested_scroll = ScrollView(),

  -- Live Interactive State
  slider_vol = 0.68,
  slider_bright = 0.85,
  slider_speed = 0.40,
  dragging_slider = nil,

  toggle_wifi = true,
  toggle_alerts = true,
  toggle_haccel = true,
  toggle_debug = false,

  check_analytics = true,
  check_autoupdate = true,
  check_telemetry = false,

  segmented_val = "60s",
  button_clicks = 0,

  input_url = "https://github.com/mturilin/lua-lamp",
  input_name = "Lua Lamp Engine",
  input_focused = nil,

  status_msg = "Ready. Click or drag any component to interact.",
}

-- Initialize interactive permission banner
gallery.banner = permissions.create_banner(permissions.LOCAL_NETWORK, {
  message = "Local network access required to discover local gateways and monitor latency.",
  action_label = "Open Settings",
  on_action = function()
    permissions.open_settings(permissions.LOCAL_NETWORK)
  end,
  on_dismiss = function()
    gallery.status_msg = "Permission banner dismissed."
  end,
})

gallery.TABS = {
  { id = "all", title = "All Components", icon = icons.layout or "A" },
  { id = "buttons", title = "Buttons & Badges", icon = icons.box or "B" },
  { id = "sliders", title = "Sliders & Progress", icon = icons.adjustments_horizontal or "S" },
  { id = "toggles", title = "Toggles & Checks", icon = icons.check or "T" },
  { id = "inputs", title = "Text & Inputs", icon = icons.typography or "I" },
  { id = "scroll", title = "Scrollable Panels", icon = icons.list or "P" },
  { id = "modals", title = "Banners & Modals", icon = icons.alert_triangle or "M" },
  { id = "icons", title = "Iconography & Text", icon = icons.star or "*" },
}

function gallery:on_mouse_wheel(dy, dx)
  -- 1. Check nested scrollview first if cursor is directly over it
  if self.nested_scroll:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) then
    if self.nested_scroll:on_mouse_wheel(dy, dx) then return true end
  end

  -- 2. Main gallery scrollview: scroll if in content area
  if self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) then
    return self.scroll_view:on_mouse_wheel(dy, dx)
  end

  -- 3. Also allow scrolling when cursor is over sidebar or padding (fallback)
  return self.scroll_view:on_mouse_wheel(dy, dx, true)
end

function gallery:update()
  self.scroll_view:update()
  self.nested_scroll:update()
end

function gallery:on_mouse_moved(px, py)
  self.mouse_x = px
  self.mouse_y = py

  local s = style.scale or 1.0

  -- Handle slider dragging
  if self.dragging_slider then
    local sx = self.dragging_slider.x
    local sw = self.dragging_slider.w
    local rel_x = math.max(0, math.min(sw, px - sx))
    local new_val = rel_x / sw

    if self.dragging_slider.id == "vol" then
      self.slider_vol = new_val
    elseif self.dragging_slider.id == "bright" then
      self.slider_bright = new_val
    elseif self.dragging_slider.id == "speed" then
      self.slider_speed = new_val
    end

    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  -- Forward to scrollviews
  self.scroll_view:on_mouse_moved(px, py)
  self.nested_scroll:on_mouse_moved(px, py)

  if self.banner and self.banner.visible and not self.banner.dismissed then
    if self.banner_x and self.banner_y then
      self.banner:on_mouse_moved(px, py, self.banner_x, self.banner_y, self.banner_w, self.banner_h)
    end
  end

  return false
end

function gallery:on_mouse_released(button, px, py)
  if self.dragging_slider then
    self.dragging_slider = nil
    local core = require "core"
    if core then core.redraw = true end
  end
  self.scroll_view:on_mouse_released(button, px, py)
  self.nested_scroll:on_mouse_released(button, px, py)
end

function gallery:on_text_input(text)
  if self.input_focused == "url" then
    self.input_url = self.input_url .. text
    local core = require "core"
    if core then core.redraw = true end
  elseif self.input_focused == "name" then
    self.input_name = self.input_name .. text
    local core = require "core"
    if core then core.redraw = true end
  end
end

function gallery:on_key_pressed(key)
  if key == "backspace" then
    if self.input_focused == "url" and #self.input_url > 0 then
      self.input_url = self.input_url:sub(1, -2)
      local core = require "core"
      if core then core.redraw = true end
    elseif self.input_focused == "name" and #self.input_name > 0 then
      self.input_name = self.input_name:sub(1, -2)
      local core = require "core"
      if core then core.redraw = true end
    end
  elseif key == "return" or key == "escape" then
    self.input_focused = nil
    local core = require "core"
    if core then core.redraw = true end
  end
end

function gallery:draw(win_w, win_h)
  local s = style.scale or 1.0
  local c = style.colors

  -- Background fill
  renderer.draw_rect(0, 0, win_w, win_h, c.background)

  -- 1. Top Navigation Bar (Header)
  local nav_h = math.floor(48 * s)
  ui.draw_box(0, 0, win_w, nav_h, c.surface, c.border, 1)

  local logo_x = math.floor(18 * s)
  local logo_y = math.floor((nav_h - style.font_heading:get_height()) / 2) + math.floor(1.2 * s)
  renderer.draw_text(style.font_heading, "Lua Lamp Gallery", logo_x, logo_y, c.lamp_gold)

  local sub_x = logo_x + style.font_heading:get_width("Lua Lamp Gallery") + math.floor(10 * s)
  local sub_y = math.floor((nav_h - style.font_small:get_height()) / 2) + math.floor(1.2 * s)
  ui.draw_pill_badge(style.font_small, "v1.0", sub_x, sub_y, c.pill_bg, c.pill_text, 6 * s, 2 * s)

  -- Top Right Action Buttons: Settings Dialog launcher & Theme Toggle
  local tr_btn_w = math.floor(110 * s)
  local tr_btn_h = math.floor(28 * s)
  local tr_x1 = win_w - tr_btn_w - math.floor(18 * s)
  local tr_x2 = tr_x1 - tr_btn_w - math.floor(8 * s)
  local tr_y = math.floor((nav_h - tr_btn_h) / 2)

  local hover_set = ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, tr_x1, tr_y, tr_btn_w, tr_btn_h)
  ui.draw_button(style.font_small, "Settings", tr_x1, tr_y, tr_btn_w, tr_btn_h, {
    variant = "surface",
    icon = icons.settings,
    is_hover = hover_set,
  })

  local hover_theme = ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, tr_x2, tr_y, tr_btn_w, tr_btn_h)
  local theme_label = (style.current_theme == "dark") and "Light Mode" or "Dark Mode"
  local theme_icon = (style.current_theme == "dark") and icons.sun or icons.moon
  ui.draw_button(style.font_small, theme_label, tr_x2, tr_y, tr_btn_w, tr_btn_h, {
    variant = "tinted",
    accent_theme = "amber",
    icon = theme_icon,
    is_hover = hover_theme,
  })

  -- 2. Left Sidebar (Categories)
  local sidebar_w = math.floor(210 * s)
  local sidebar_y = nav_h
  local sidebar_h = win_h - nav_h - math.floor(32 * s)
  ui.draw_box(0, sidebar_y, sidebar_w, sidebar_h, c.surface, c.border, 1)

  local tab_y = sidebar_y + math.floor(14 * s)
  local tab_h = math.floor(34 * s)
  local tab_gap = math.floor(4 * s)
  local tab_w = sidebar_w - math.floor(24 * s)
  local tab_x = math.floor(12 * s)

  for _, tab in ipairs(self.TABS) do
    local is_active = (self.active_tab == tab.id)
    local is_hover = ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, tab_x, tab_y, tab_w, tab_h)

    if is_active then
      ui.draw_rounded_box(tab_x, tab_y, tab_w, tab_h, math.floor(6 * s), c.btn_accent_bg or { 56, 189, 248, 30 }, nil, 0)
    elseif is_hover then
      ui.draw_rounded_box(tab_x, tab_y, tab_w, tab_h, math.floor(6 * s), c.surface_hover, nil, 0)
    end

    local icon_col = is_active and c.text_primary or c.accent
    local text_col = is_active and c.text_primary or (is_hover and c.text_primary or c.text_secondary)
    local ix = tab_x + math.floor(10 * s)
    local iy = tab_y + math.floor((tab_h - style.font_icon:get_height()) / 2) + math.floor(1.0 * s)
    renderer.draw_text(style.font_icon, tab.icon, ix, iy, icon_col)

    local tx = ix + style.font_icon:get_width(tab.icon) + math.floor(10 * s)
    local ty = tab_y + math.floor((tab_h - style.font_normal:get_height()) / 2) + math.floor(1.2 * s)
    renderer.draw_text(style.font_normal, tab.title, tx, ty, text_col)

    tab_y = tab_y + tab_h + tab_gap
  end

  -- 3. Bottom Status Bar (Footer)
  local footer_h = math.floor(32 * s)
  local footer_y = win_h - footer_h
  ui.draw_box(0, footer_y, win_w, footer_h, c.surface, c.border, 1)

  local stat_ty = footer_y + math.floor((footer_h - style.font_small:get_height()) / 2) + math.floor(1.2 * s)
  renderer.draw_text(style.font_small, self.status_msg, math.floor(16 * s), stat_ty, c.text_secondary)

  local coords_text = string.format("Mouse: (%d, %d) • Scale: %.1fx", self.mouse_x or 0, self.mouse_y or 0, s)
  local cw = style.font_small:get_width(coords_text)
  renderer.draw_text(style.font_small, coords_text, win_w - cw - math.floor(16 * s), stat_ty, c.text_tertiary)

  -- 4. Right Main Content Area (Managed by ScrollView!)
  local panel_x = sidebar_w + math.floor(18 * s)
  local panel_y = nav_h + math.floor(14 * s)
  local panel_w = win_w - panel_x - math.floor(18 * s)
  local panel_h = win_h - nav_h - footer_h - math.floor(28 * s)

  -- Measure total content height dynamically
  local content_h = self:measure_content_height(self.active_tab, panel_w, s)

  -- Begin ScrollView scissor clipping and obtain scrolled draw origin
  local _, content_y = self.scroll_view:begin_clip(panel_x, panel_y, panel_w, panel_h, content_h)

  -- Draw the active category components
  self:draw_content(self.active_tab, panel_x, content_y, panel_w, s, c)

  -- End ScrollView clipping and overlay modern scrollbar
  self.scroll_view:end_clip()
end

function gallery:measure_content_height(tab_id, panel_w, s)
  if tab_id == "buttons" then
    return math.floor(580 * s)
  elseif tab_id == "sliders" then
    return math.floor(480 * s)
  elseif tab_id == "toggles" then
    return math.floor(420 * s)
  elseif tab_id == "inputs" then
    return math.floor(460 * s)
  elseif tab_id == "scroll" then
    return math.floor(620 * s)
  elseif tab_id == "modals" then
    return math.floor(480 * s)
  elseif tab_id == "icons" then
    return math.floor(560 * s)
  else
    -- "all" tab contains every section sequentially
    return math.floor(2400 * s)
  end
end

function gallery:draw_content(tab_id, px, cy, pw, s, c)
  local cur_y = cy
  local gap = math.floor(20 * s)

  if tab_id == "all" or tab_id == "buttons" then
    cur_y = self:draw_buttons_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "sliders" then
    cur_y = self:draw_sliders_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "toggles" then
    cur_y = self:draw_toggles_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "inputs" then
    cur_y = self:draw_inputs_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "scroll" then
    cur_y = self:draw_scroll_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "modals" then
    cur_y = self:draw_modals_section(px, cur_y, pw, s, c) + gap
  end

  if tab_id == "all" or tab_id == "icons" then
    cur_y = self:draw_icons_section(px, cur_y, pw, s, c) + gap
  end
end

-- 1. Section: Buttons & Segmented Controls
function gallery:draw_buttons_section(x, y, w, s, c)
  local card_h = math.floor(220 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "1. Buttons & Segmented Controls (Pinglet Standard)", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Borderless filled surfaces conforming to Rule 1 & Rule 2 of the Aesthetics Protocol.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(16 * s)

  -- Row 1: Button Variants
  local bw = math.floor(118 * s)
  local bh = math.floor(32 * s)
  local bgap = math.floor(12 * s)
  local bx = x + pad

  -- Solid Pill (Cyan)
  local h1 = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, bx, ty, bw, bh)
  ui.draw_button(style.font_normal, "Solid Pill", bx, ty, bw, bh, { variant = "solid", accent_theme = "cyan", is_hover = h1 })
  bx = bx + bw + bgap

  -- Solid Pill (Amber)
  local h2 = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, bx, ty, bw, bh)
  ui.draw_button(style.font_normal, "Amber Pill", bx, ty, bw, bh, { variant = "solid", accent_theme = "amber", is_hover = h2 })
  bx = bx + bw + bgap

  -- Tinted Pill with Icon
  local h3 = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, bx, ty, bw, bh)
  ui.draw_button(style.font_normal, "Tinted Icon", bx, ty, bw, bh, { variant = "tinted", accent_theme = "cyan", icon = icons.star, is_hover = h3 })
  bx = bx + bw + bgap

  -- Surface Button
  local h4 = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, bx, ty, bw, bh)
  ui.draw_button(style.font_normal, "Surface", bx, ty, bw, bh, { variant = "surface", is_hover = h4 })

  -- Row 2: Segmented Control Track
  ty = ty + bh + math.floor(18 * s)
  local track_w = math.floor(280 * s)
  local track_h = math.floor(34 * s)
  ui.draw_segmented_track(x + pad, ty, track_w, track_h, math.floor(8 * s))

  local seg_items = { "10s", "30s", "60s", "Follow" }
  local seg_btn_w = math.floor((track_w - 6 * s) / #seg_items)
  local seg_btn_h = track_h - math.floor(6 * s)
  local seg_x = x + pad + math.floor(3 * s)
  local seg_y = ty + math.floor(3 * s)

  for _, item in ipairs(seg_items) do
    local is_sel = (self.segmented_val == item)
    local is_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, seg_x, seg_y, seg_btn_w, seg_btn_h)
    ui.draw_button(style.font_normal, item, seg_x, seg_y, seg_btn_w, seg_btn_h, {
      variant = is_sel and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = is_sel,
      is_hover = is_hov,
    })
    seg_x = seg_x + seg_btn_w
  end

  -- Clicks counter label
  local clicks_text = string.format("Interactive Clicks: %d", self.button_clicks)
  renderer.draw_text(style.font_normal, clicks_text, x + pad + track_w + math.floor(20 * s), ty + math.floor(8 * s), c.lamp_gold)

  return y + card_h
end

-- 2. Section: Sliders & Progress Bars
function gallery:draw_sliders_section(x, y, w, s, c)
  local card_h = math.floor(230 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "2. Sliders & Progress Indicators", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Smooth draggable tracks with fill progress, glow rings, and responsive values.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(16 * s)

  local slider_w = math.floor(320 * s)
  local slider_h = math.floor(24 * s)

  -- Slider 1: Volume
  local v_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, slider_w, slider_h)
  ui.draw_slider(x + pad, ty, slider_w, slider_h, self.slider_vol, { accent_theme = "cyan", is_hover = v_hov, is_dragging = (self.dragging_slider and self.dragging_slider.id == "vol") })
  renderer.draw_text(style.font_normal, string.format("Volume Level: %d%%", math.floor(self.slider_vol * 100)), x + pad + slider_w + math.floor(16 * s), ty + math.floor(3 * s), c.text_primary)

  -- Slider 2: Brightness (Amber)
  ty = ty + slider_h + math.floor(14 * s)
  local b_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, slider_w, slider_h)
  ui.draw_slider(x + pad, ty, slider_w, slider_h, self.slider_bright, { accent_theme = "amber", is_hover = b_hov, is_dragging = (self.dragging_slider and self.dragging_slider.id == "bright") })
  renderer.draw_text(style.font_normal, string.format("Lamp Brightness: %d%%", math.floor(self.slider_bright * 100)), x + pad + slider_w + math.floor(16 * s), ty + math.floor(3 * s), c.lamp_gold)

  -- Progress Bar Demo
  ty = ty + slider_h + math.floor(16 * s)
  local prog_w = math.floor(320 * s)
  local prog_h = math.floor(10 * s)
  ui.draw_progressbar(x + pad, ty, prog_w, prog_h, self.slider_speed, { accent_theme = "emerald" })
  renderer.draw_text(style.font_small, string.format("Task Completion Progress: %d%%", math.floor(self.slider_speed * 100)), x + pad + prog_w + math.floor(16 * s), ty - math.floor(2 * s), c.text_secondary)

  return y + card_h
end

-- 3. Section: Toggles & Checkboxes
function gallery:draw_toggles_section(x, y, w, s, c)
  local card_h = math.floor(190 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "3. Toggles & Checkboxes", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Native-feeling animated switch pills and check controls.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(16 * s)

  -- Toggles
  local tw = math.floor(44 * s)
  local th = math.floor(24 * s)

  local t1_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, tw, th)
  ui.draw_toggle(x + pad, ty, tw, th, self.toggle_wifi, { accent_theme = "cyan", is_hover = t1_hov })
  renderer.draw_text(style.font_normal, "Wi-Fi Gateway Discovery", x + pad + tw + math.floor(12 * s), ty + math.floor(3 * s), c.text_primary)

  local tx2 = x + pad + math.floor(260 * s)
  local t2_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, tx2, ty, tw, th)
  ui.draw_toggle(tx2, ty, tw, th, self.toggle_alerts, { accent_theme = "emerald", is_hover = t2_hov })
  renderer.draw_text(style.font_normal, "Background Latency Alerts", tx2 + tw + math.floor(12 * s), ty + math.floor(3 * s), c.text_primary)

  -- Checkboxes
  ty = ty + th + math.floor(20 * s)
  local cb_size = math.floor(18 * s)

  local c1_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, math.floor(160 * s), cb_size)
  ui.draw_checkbox(style.font_normal, x + pad, ty, cb_size, self.check_autoupdate, "Automatic Updates", { is_hover = c1_hov })

  local c2_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, tx2, ty, math.floor(160 * s), cb_size)
  ui.draw_checkbox(style.font_normal, tx2, ty, cb_size, self.check_telemetry, "Send Anonymous Diagnostics", { is_hover = c2_hov })

  return y + card_h
end

-- 4. Section: Text Inputs & Forms
function gallery:draw_inputs_section(x, y, w, s, c)
  local card_h = math.floor(190 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "4. Text Inputs & Editable Fields", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Click into any input box and type directly from your keyboard.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(16 * s)

  local in_w = math.floor(340 * s)
  local in_h = math.floor(34 * s)

  local in1_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, in_w, in_h)
  ui.draw_input_box(style.font_normal, x + pad, ty, in_w, in_h, self.input_url, self.input_focused == "url", { placeholder = "Remote Git URL...", is_hover = in1_hov })

  ty = ty + in_h + math.floor(12 * s)
  local in2_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, in_w, in_h)
  ui.draw_input_box(style.font_normal, x + pad, ty, in_w, in_h, self.input_name, self.input_focused == "name", { placeholder = "Project Name...", is_hover = in2_hov })

  return y + card_h
end

-- 5. Section: Scrollable Panels & Nested ScrollView
function gallery:draw_scroll_section(x, y, w, s, c)
  local card_h = math.floor(300 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "5. Scrollable Panels & Viewports (ScrollView)", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Nested ScrollView demonstrating 60 FPS trackpad damping, clipping, and drag scrollbar.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(14 * s)

  local n_w = w - pad * 2
  local n_h = math.floor(180 * s)
  local item_h = math.floor(38 * s)
  local item_count = 20
  local total_items_h = item_count * (item_h + math.floor(6 * s))

  -- Inner nested scrollview
  ui.draw_rounded_box(x + pad, ty, n_w, n_h, math.floor(8 * s), c.track_bg or { 15, 23, 42, 120 }, c.border, 1)

  local _, n_content_y = self.nested_scroll:begin_clip(x + pad + 2, ty + 2, n_w - 4, n_h - 4, total_items_h)

  local cur_iy = n_content_y + math.floor(6 * s)
  for i = 1, item_count do
    local is_hov = self.nested_scroll:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad + math.floor(8 * s), cur_iy, n_w - math.floor(28 * s), item_h)
    local row_bg = is_hov and c.surface_hover or c.surface
    ui.draw_rounded_box(x + pad + math.floor(8 * s), cur_iy, n_w - math.floor(28 * s), item_h, math.floor(6 * s), row_bg, nil, 0)

    local row_text = string.format("Item #%02d — High-performance scrollable row component", i)
    renderer.draw_text(style.font_normal, row_text, x + pad + math.floor(20 * s), cur_iy + math.floor(10 * s), is_hov and c.text_primary or c.text_secondary)

    local tag_text = string.format("%d ms", i * 12)
    ui.draw_pill_badge(style.font_small, tag_text, x + pad + n_w - math.floor(85 * s), cur_iy + math.floor(8 * s), c.pill_bg, c.accent, 6 * s, 2 * s)

    cur_iy = cur_iy + item_h + math.floor(6 * s)
  end

  self.nested_scroll:end_clip()

  return y + card_h
end

-- 6. Section: Modals & Warning Banners
function gallery:draw_modals_section(x, y, w, s, c)
  local card_h = math.floor(180 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "6. Warning Banners & Modal Triggers", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "Interactive permission banners with action and dismiss triggers.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(14 * s)

  if self.banner and self.banner.visible and not self.banner.dismissed then
    self.banner_x = x + pad
    self.banner_y = ty
    self.banner_w = w - pad * 2
    self.banner_h = math.floor(38 * s)
    self.banner:draw(self.banner_x, self.banner_y, self.banner_w, self.banner_h)
  else
    local rbtn_w = math.floor(160 * s)
    local rbtn_h = math.floor(30 * s)
    local rhov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, x + pad, ty, rbtn_w, rbtn_h)
    ui.draw_button(style.font_small, "Restore Banner", x + pad, ty, rbtn_w, rbtn_h, { variant = "tinted", accent_theme = "cyan", icon = icons.refresh, is_hover = rhov })
  end

  return y + card_h
end

-- 7. Section: Iconography Grid & Typography
function gallery:draw_icons_section(x, y, w, s, c)
  local card_h = math.floor(260 * s)
  ui.draw_rounded_box(x, y, w, card_h, math.floor(10 * s), c.surface, c.border, 1)

  local pad = math.floor(18 * s)
  local ty = y + pad
  renderer.draw_text(style.font_heading, "7. Verified Tabler Icons Grid", x + pad, ty, c.text_primary)

  ty = ty + style.font_heading:get_height() + math.floor(4 * s)
  renderer.draw_text(style.font_small, "True FreeType glyphs mapped to fonts/tabler-icons.ttf with zero mismatch.", x + pad, ty, c.text_secondary)

  ty = ty + style.font_small:get_height() + math.floor(14 * s)

  local icon_list = {
    { "shield", icons.shield }, { "shield_check", icons.shield_check },
    { "camera", icons.camera }, { "microphone", icons.microphone },
    { "folder", icons.folder }, { "router", icons.router },
    { "wifi", icons.wifi }, { "bell", icons.bell },
    { "desktop", icons.device_desktop }, { "accessible", icons.accessible },
    { "settings", icons.settings }, { "refresh", icons.refresh },
    { "check", icons.check }, { "star", icons.star },
    { "heart", icons.heart }, { "power", icons.power },
    { "sun", icons.sun }, { "moon", icons.moon },
  }

  local box_size = math.floor(38 * s)
  local gap = math.floor(8 * s)
  local ix = x + pad
  local iy = ty

  for _, item in ipairs(icon_list) do
    local is_hov = self.scroll_view:is_in_viewport(self.mouse_x or 0, self.mouse_y or 0) and ui.point_in_rect(self.mouse_x or 0, self.mouse_y or 0, ix, iy, box_size, box_size)
    local ibg = is_hov and (c.btn_accent_bg or { 56, 189, 248, 40 }) or c.surface_hover
    ui.draw_rounded_box(ix, iy, box_size, box_size, math.floor(6 * s), ibg, nil, 0)

    local iw = style.font_icon:get_width(item[2])
    local icx = ix + math.floor((box_size - iw) / 2)
    local icy = iy + math.floor((box_size - style.font_icon:get_height()) / 2) + math.floor(1.0 * s)
    renderer.draw_text(style.font_icon, item[2], icx, icy, is_hov and { 255, 255, 255, 255 } or c.text_primary)

    ix = ix + box_size + gap
    if ix + box_size > x + w - pad then
      ix = x + pad
      iy = iy + box_size + gap
    end
  end

  return y + card_h
end

function gallery:on_mouse_pressed(button, px, py)
  if button ~= "left" and button ~= 1 then return false end

  local s = style.scale or 1.0

  -- 1. Check Top Bar buttons
  local tr_btn_w = math.floor(110 * s)
  local tr_btn_h = math.floor(28 * s)
  local win_w = renderer.get_size()
  local tr_x1 = win_w - tr_btn_w - math.floor(18 * s)
  local tr_x2 = tr_x1 - tr_btn_w - math.floor(8 * s)
  local nav_h = math.floor(48 * s)
  local tr_y = math.floor((nav_h - tr_btn_h) / 2)

  if ui.point_in_rect(px, py, tr_x1, tr_y, tr_btn_w, tr_btn_h) then
    local settings = require "src.settings_dialog"
    settings:show()
    return true
  end

  if ui.point_in_rect(px, py, tr_x2, tr_y, tr_btn_w, tr_btn_h) then
    style.toggle_theme()
    return true
  end

  -- 2. Check Left Sidebar Category Tabs
  local sidebar_w = math.floor(210 * s)
  if px <= sidebar_w and py >= nav_h then
    local tab_y = nav_h + math.floor(14 * s)
    local tab_h = math.floor(34 * s)
    local tab_gap = math.floor(4 * s)
    local tab_w = sidebar_w - math.floor(24 * s)
    local tab_x = math.floor(12 * s)

    for _, tab in ipairs(self.TABS) do
      if ui.point_in_rect(px, py, tab_x, tab_y, tab_w, tab_h) then
        self.active_tab = tab.id
        self.scroll_view.scroll_y = 0
        self.scroll_view.scroll_to_y = 0
        local core = require "core"
        if core then core.redraw = true end
        return true
      end
      tab_y = tab_y + tab_h + tab_gap
    end
    return true
  end

  -- 3. Check Main ScrollView scrollbar thumb click
  if self.scroll_view:on_mouse_pressed(button, px, py) then
    return true
  end

  -- 4. Check Nested ScrollView scrollbar thumb click
  if self.nested_scroll:on_mouse_pressed(button, px, py) then
    return true
  end

  -- 5. Intercept interactive controls inside content
  local content_py = self.scroll_view:to_content_y(py)
  local panel_x = sidebar_w + math.floor(18 * s)

  -- Check Button clicks
  local bw = math.floor(118 * s)
  local bh = math.floor(32 * s)
  local bgap = math.floor(12 * s)
  local pad = math.floor(18 * s)

  for i = 0, 3 do
    local bx = panel_x + pad + i * (bw + bgap)
    local by = content_py
    -- Check row 1 buttons
    if ui.point_in_rect(px, content_py, bx, nav_h + math.floor(14 * s) + pad + style.font_heading:get_height() + style.font_small:get_height() + math.floor(20 * s), bw, bh) then
      self.button_clicks = self.button_clicks + 1
      self.status_msg = string.format("Button clicked! Total clicks: %d", self.button_clicks)
      local core = require "core"
      if core then core.redraw = true end
      return true
    end
  end

  -- Check Segmented Control click
  local seg_top = nav_h + math.floor(14 * s) + pad + style.font_heading:get_height() + style.font_small:get_height() + math.floor(20 * s) + bh + math.floor(18 * s)
  local track_w = math.floor(280 * s)
  local track_h = math.floor(34 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, seg_top, track_w, track_h) then
    local seg_items = { "10s", "30s", "60s", "Follow" }
    local seg_btn_w = math.floor((track_w - 6 * s) / #seg_items)
    local idx = math.floor((px - (panel_x + pad)) / seg_btn_w) + 1
    if seg_items[idx] then
      self.segmented_val = seg_items[idx]
      self.status_msg = "Segmented control selected: " .. seg_items[idx]
      local core = require "core"
      if core then core.redraw = true end
      return true
    end
  end

  -- Check Sliders interaction
  local slider_w = math.floor(320 * s)
  local slider_h = math.floor(24 * s)
  local s1_y = nav_h + math.floor(14 * s) + math.floor(220 * s) + math.floor(20 * s) + pad + style.font_heading:get_height() + style.font_small:get_height() + math.floor(20 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, s1_y, slider_w, slider_h) then
    self.dragging_slider = { id = "vol", x = panel_x + pad, w = slider_w }
    self.slider_vol = math.max(0, math.min(1.0, (px - (panel_x + pad)) / slider_w))
    self.status_msg = string.format("Volume set to %d%%", math.floor(self.slider_vol * 100))
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  local s2_y = s1_y + slider_h + math.floor(14 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, s2_y, slider_w, slider_h) then
    self.dragging_slider = { id = "bright", x = panel_x + pad, w = slider_w }
    self.slider_bright = math.max(0, math.min(1.0, (px - (panel_x + pad)) / slider_w))
    self.status_msg = string.format("Brightness set to %d%%", math.floor(self.slider_bright * 100))
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  -- Check Toggles interaction
  local tw = math.floor(44 * s)
  local th = math.floor(24 * s)
  local tog_y = s2_y + slider_h + math.floor(230 * s) - math.floor(40 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, tog_y, tw, th) then
    self.toggle_wifi = not self.toggle_wifi
    self.status_msg = "Wi-Fi Toggle: " .. (self.toggle_wifi and "ON" or "OFF")
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  local tx2 = panel_x + pad + math.floor(260 * s)
  if ui.point_in_rect(px, content_py, tx2, tog_y, tw, th) then
    self.toggle_alerts = not self.toggle_alerts
    self.status_msg = "Alerts Toggle: " .. (self.toggle_alerts and "ON" or "OFF")
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  -- Check Checkboxes interaction
  local cb_y = tog_y + th + math.floor(20 * s)
  local cb_size = math.floor(18 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, cb_y, math.floor(160 * s), cb_size) then
    self.check_autoupdate = not self.check_autoupdate
    self.status_msg = "Automatic Updates: " .. (self.check_autoupdate and "Enabled" or "Disabled")
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  if ui.point_in_rect(px, content_py, tx2, cb_y, math.floor(160 * s), cb_size) then
    self.check_telemetry = not self.check_telemetry
    self.status_msg = "Telemetry: " .. (self.check_telemetry and "Enabled" or "Disabled")
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  -- Check Text Input focus
  local in_w = math.floor(340 * s)
  local in_h = math.floor(34 * s)
  local in_y = cb_y + cb_size + math.floor(190 * s) - math.floor(60 * s)
  if ui.point_in_rect(px, content_py, panel_x + pad, in_y, in_w, in_h) then
    self.input_focused = "url"
    self.status_msg = "Editing Remote Git URL"
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  if ui.point_in_rect(px, content_py, panel_x + pad, in_y + in_h + math.floor(12 * s), in_w, in_h) then
    self.input_focused = "name"
    self.status_msg = "Editing Project Name"
    local core = require "core"
    if core then core.redraw = true end
    return true
  end

  -- Defocus input if clicked elsewhere
  if self.input_focused then
    self.input_focused = nil
    local core = require "core"
    if core then core.redraw = true end
  end

  -- Check Banner clicks
  if self.banner and self.banner.visible and not self.banner.dismissed then
    if self.banner_x and self.banner_y then
      if self.banner:on_mouse_pressed(button, px, content_py, self.banner_x, self.banner_y, self.banner_w, self.banner_h) then
        return true
      end
    end
  else
    local rbtn_w = math.floor(160 * s)
    local rbtn_h = math.floor(30 * s)
    local restore_y = in_y + in_h * 2 + math.floor(400 * s)
    if ui.point_in_rect(px, content_py, panel_x + pad, restore_y, rbtn_w, rbtn_h) then
      self.banner.visible = true
      self.banner.dismissed = false
      self.status_msg = "Permission banner restored."
      local core = require "core"
      if core then core.redraw = true end
      return true
    end
  end

  return false
end

return gallery

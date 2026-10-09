-- Lua Lamp Extensible Modal Settings Window
-- A floating, tabbed modal dialog implementing native display scale switching,
-- typography configuration, theme toggling, and third-party plugin tabs.

local style = require "src.style"
local ui = require "src.ui"
local icons = require "src.icons"

local settings = {
  visible = false,
  active_tab = "display",
  custom_sections = {},
  x = 0,
  y = 0,
  w = 0,
  h = 0,
  is_custom_pos = false,
  dragging = false,
  drag_offset_x = 0,
  drag_offset_y = 0,
  hover_close = false,
  hover_footer_close = false,
  hover_tab = nil,
  hover_item = nil,
  font_family = "Public Sans",
  font_size_preset = "Standard",
}

--- Register a custom tab / section for other applications/plugins to extend Settings
---@param id string Unique identifier (e.g. "database", "plugins")
---@param title string Human-readable tab title
---@param icon string Tabler icon code or label glyph
---@param render_fn fun(panel_x: number, panel_y: number, panel_w: number, panel_h: number, scale: number, colors: table, dialog: table)
function settings:register_section(id, title, icon, render_fn)
  for i, s in ipairs(self.custom_sections) do
    if s.id == id then
      self.custom_sections[i] = { id = id, title = title, icon = icon, render = render_fn }
      return
    end
  end
  table.insert(self.custom_sections, {
    id = id,
    title = title,
    icon = icon,
    render = render_fn,
  })
end

function settings:show()
  self.visible = true
  self.dragging = false
  local core = require "core"
  core.redraw = true
end

function settings:hide()
  self.visible = false
  self.dragging = false
  self.mouse_x = nil
  self.mouse_y = nil
  local core = require "core"
  core.redraw = true
end

function settings:toggle()
  if self.visible then
    self:hide()
  else
    self:show()
  end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function settings:on_mouse_moved(px, py)
  if not self.visible then return false end

  local s = style.scale
  self.mouse_x = px
  self.mouse_y = py

  if self.dragging then
    self.x = px - self.drag_offset_x
    self.y = py - self.drag_offset_y
    self.is_custom_pos = true
    local core = require "core"
    core.redraw = true
    return true
  end

  -- Check hover close button
  local close_btn_x = self.x + self.w - math.floor(38 * s)
  local close_btn_y = self.y + math.floor(8 * s)
  local close_btn_size = math.floor(28 * s)
  self.hover_close = ui.point_in_rect(px, py, close_btn_x, close_btn_y, close_btn_size, close_btn_size)

  -- Check hover footer close button
  local footer_h = math.floor(46 * s)
  local footer_y = self.y + self.h - footer_h
  local footer_btn_w = math.floor(84 * s)
  local footer_btn_h = math.floor(30 * s)
  local footer_btn_x = self.x + self.w - footer_btn_w - math.floor(18 * s)
  local footer_btn_y = footer_y + math.floor((footer_h - footer_btn_h) / 2)
  self.hover_footer_close = ui.point_in_rect(px, py, footer_btn_x, footer_btn_y, footer_btn_w, footer_btn_h)

  -- Check sidebar tabs hover
  self.hover_tab = nil
  local sidebar_x = self.x + math.floor(12 * s)
  local sidebar_w = math.floor(164 * s)
  local tab_y = self.y + math.floor(54 * s)
  local tab_h = math.floor(36 * s)
  local tab_gap = math.floor(4 * s)

  local all_tabs = self:get_tabs()
  for _, tab in ipairs(all_tabs) do
    if ui.point_in_rect(px, py, sidebar_x, tab_y, sidebar_w, tab_h) then
      self.hover_tab = tab.id
    end
    tab_y = tab_y + tab_h + tab_gap
  end

  local core = require "core"
  core.redraw = true

  -- Intercept all mouse moves over the dialog or modal background
  return true
end

function settings:on_mouse_pressed(button, px, py)
  if not self.visible then return false end
  if button ~= "left" and button ~= 1 then return true end

  local s = style.scale

  -- 1. Click outside modal box: dismiss dialog
  if not ui.point_in_rect(px, py, self.x, self.y, self.w, self.h) then
    self:hide()
    return true
  end

  -- 2. Click close button in header
  local close_btn_x = self.x + self.w - math.floor(38 * s)
  local close_btn_y = self.y + math.floor(8 * s)
  local close_btn_size = math.floor(28 * s)
  if ui.point_in_rect(px, py, close_btn_x, close_btn_y, close_btn_size, close_btn_size) then
    self:hide()
    return true
  end

  -- 3. Click footer close button
  local footer_y = self.y + self.h - math.floor(46 * s)
  local footer_btn_w = math.floor(84 * s)
  local footer_btn_h = math.floor(30 * s)
  local footer_btn_x = self.x + self.w - footer_btn_w - math.floor(18 * s)
  if ui.point_in_rect(px, py, footer_btn_x, footer_y + math.floor(8 * s), footer_btn_w, footer_btn_h) then
    self:hide()
    return true
  end

  -- 4. Click header drag area
  local header_h = math.floor(46 * s)
  if ui.point_in_rect(px, py, self.x, self.y, self.w - math.floor(48 * s), header_h) then
    self.dragging = true
    self.drag_offset_x = px - self.x
    self.drag_offset_y = py - self.y
    return true
  end

  -- 5. Click sidebar tab
  local sidebar_x = self.x + math.floor(12 * s)
  local sidebar_w = math.floor(164 * s)
  local tab_y = self.y + math.floor(54 * s)
  local tab_h = math.floor(36 * s)
  local tab_gap = math.floor(4 * s)

  local all_tabs = self:get_tabs()
  for _, tab in ipairs(all_tabs) do
    if ui.point_in_rect(px, py, sidebar_x, tab_y, sidebar_w, tab_h) then
      self.active_tab = tab.id
      local core = require "core"
      core.redraw = true
      return true
    end
    tab_y = tab_y + tab_h + tab_gap
  end

  -- 6. Content panel interactions
  local panel_x = self.x + math.floor(190 * s)
  local panel_y = self.y + math.floor(54 * s)
  local panel_w = self.w - math.floor(206 * s)
  local panel_h = self.h - math.floor(106 * s)

  if self.active_tab == "display" then
    self:handle_display_click(px, py, panel_x, panel_y, panel_w, panel_h)
  elseif self.active_tab == "typography" then
    self:handle_typography_click(px, py, panel_x, panel_y, panel_w, panel_h)
  elseif self.active_tab == "theme" then
    self:handle_theme_click(px, py, panel_x, panel_y, panel_w, panel_h)
  end

  return true
end

function settings:on_mouse_released(button, px, py)
  if not self.visible then return false end
  if self.dragging then
    self.dragging = false
    local core = require "core"
    core.redraw = true
  end
  return true
end

function settings:get_tabs()
  local tabs = {
    { id = "display", title = "Display & Scale", icon = icons.device_desktop or icons.refresh },
    { id = "typography", title = "Typography", icon = icons.typography or "T" },
    { id = "theme", title = "Appearance", icon = (style.current_theme == "dark") and icons.moon or icons.sun },
  }
  for _, custom in ipairs(self.custom_sections) do
    table.insert(tabs, custom)
  end
  return tabs
end

--------------------------------------------------------------------------------
-- Interactive Actions Handlers
--------------------------------------------------------------------------------

function settings:handle_display_click(px, py, x, y, w, h)
  local s = style.scale
  local core = require "core"

  local head_h = style.font_heading:get_height() + math.floor(4 * s)
  local sub_lines = ui.wrap_text(style.font_small, "Select UI scaling multiplier or auto-detect based on screen DPI.", w)
  local sub_h = #sub_lines * (style.font_small:get_height() + math.floor(3 * s))
  local opt_y = y + head_h + sub_h + math.floor(14 * s) + math.floor(32 * s)

  local auto_s = core.get_default_scale()
  local scales = {
    { label = "Auto", val = auto_s },
    { label = "1.0x", val = 1.0 },
    { label = "1.25x", val = 1.25 },
    { label = "1.5x", val = 1.5 },
    { label = "1.75x", val = 1.75 },
    { label = "2.0x", val = 2.0 },
    { label = "2.5x", val = 2.5 },
  }

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(36 * s)
  local btn_h = track_h - track_pad * 2
  local num_scales = #scales
  local track_w = math.min(w, math.floor(430 * s))
  local btn_w = math.floor((track_w - track_pad * 2) / num_scales)
  local cur_x = x + track_pad

  for _, opt in ipairs(scales) do
    if ui.point_in_rect(px, py, cur_x, opt_y + track_pad, btn_w, btn_h) then
      core.rescale(opt.val)
      return
    end
    cur_x = cur_x + btn_w
  end
end

function settings:handle_typography_click(px, py, x, y, w, h)
  local s = style.scale
  local core = require "core"

  local head_h = style.font_heading:get_height() + math.floor(4 * s)
  local sub_lines = ui.wrap_text(style.font_small, "Manage interface font family, sizing presets, and rendering preview.", w)
  local sub_h = #sub_lines * (style.font_small:get_height() + math.floor(3 * s))
  local cur_y = y + head_h + sub_h + math.floor(14 * s)

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(36 * s)
  local btn_h = track_h - track_pad * 2

  -- Font family segmented track check
  cur_y = cur_y + style.font_large:get_height() + math.floor(8 * s)
  local fam_track_w = math.min(w, math.floor(380 * s))
  local fam_btn_w = math.floor((fam_track_w - track_pad * 2) / 2)
  local ps_x = x + track_pad
  local ss_x = ps_x + fam_btn_w

  if ui.point_in_rect(px, py, ps_x, cur_y + track_pad, fam_btn_w, btn_h) then
    self.font_family = "Public Sans"
    core.redraw = true
    return
  elseif ui.point_in_rect(px, py, ss_x, cur_y + track_pad, fam_btn_w, btn_h) then
    self.font_family = "Source Sans 3"
    core.redraw = true
    return
  end

  -- Sizing presets segmented track check
  cur_y = cur_y + track_h + math.floor(14 * s) + style.font_large:get_height() + math.floor(8 * s)
  local sz_track_w = math.min(w, math.floor(380 * s))
  local sz_btn_w = math.floor((sz_track_w - track_pad * 2) / 3)
  local sizes = { "Compact", "Standard", "Large" }
  local cur_sz_x = x + track_pad

  for _, sz in ipairs(sizes) do
    if ui.point_in_rect(px, py, cur_sz_x, cur_y + track_pad, sz_btn_w, btn_h) then
      self.font_size_preset = sz
      core.redraw = true
      return
    end
    cur_sz_x = cur_sz_x + sz_btn_w
  end
end

function settings:handle_theme_click(px, py, x, y, w, h)
  local s = style.scale
  local core = require "core"
  local canvas = require "src.canvas"

  local head_h = style.font_heading:get_height() + math.floor(4 * s)
  local sub_lines = ui.wrap_text(style.font_small, "Customize color scheme, ambient background, and animated effects.", w)
  local sub_h = #sub_lines * (style.font_small:get_height() + math.floor(3 * s))
  local cur_y = y + head_h + sub_h + math.floor(14 * s)

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(38 * s)
  local btn_h = track_h - track_pad * 2

  -- Color palette segmented track check
  cur_y = cur_y + style.font_large:get_height() + math.floor(8 * s)
  local theme_track_w = math.min(w, math.floor(380 * s))
  local theme_btn_w = math.floor((theme_track_w - track_pad * 2) / 2)
  local dark_x = x + track_pad
  local light_x = dark_x + theme_btn_w

  if ui.point_in_rect(px, py, dark_x, cur_y + track_pad, theme_btn_w, btn_h) then
    style.set_theme("dark")
    core.redraw = true
    return
  elseif ui.point_in_rect(px, py, light_x, cur_y + track_pad, theme_btn_w, btn_h) then
    style.set_theme("light")
    core.redraw = true
    return
  end

  -- Lamp Pulse Animation toggle check
  cur_y = cur_y + track_h + math.floor(20 * s) + style.font_large:get_height() + math.floor(8 * s)
  local glow_w = math.min(w, math.floor(260 * s))
  local glow_h = math.floor(38 * s)
  if ui.point_in_rect(px, py, x, cur_y, glow_w, glow_h) then
    canvas.toggle_lamp()
    core.redraw = true
    return
  end
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function settings:draw(win_w, win_h)
  if not self.visible then return end

  local c = style.colors
  local s = style.scale

  -- 1. Modal Dimming Backdrop (dark translucent shield)
  renderer.draw_rect(0, 0, win_w, win_h, { 0, 0, 0, 115 })

  -- 2. Dialog Dimensions & Centering
  self.w = math.min(win_w - math.floor(32 * s), math.floor(660 * s))
  self.h = math.min(win_h - math.floor(32 * s), math.floor(450 * s))

  if not self.is_custom_pos then
    self.x = math.floor((win_w - self.w) / 2)
    self.y = math.floor((win_h - self.h) / 2)
  else
    -- Constrain within screen bounds
    self.x = math.max(0, math.min(win_w - self.w, self.x))
    self.y = math.max(0, math.min(win_h - self.h, self.y))
  end

  local radius = math.floor(12 * s)

  -- 3. Dialog Dropshadow
  ui.draw_rounded_box(self.x, self.y + math.floor(6 * s), self.w, self.h, radius, { 0, 0, 0, 85 }, nil, 0)

  -- 4. Dialog Base Card
  ui.draw_rounded_box(self.x, self.y, self.w, self.h, radius, c.surface, c.border, 1)

  -- 5. Title Bar Header
  local header_h = math.floor(46 * s)
  -- Subtle divider below header
  renderer.draw_rect(self.x, self.y + header_h, self.w, 1, c.border)

  -- Header Icon and Title
  local optical_header_shift = math.floor(1.2 * s)
  local icon_shift = math.floor(1.0 * s)

  local icon_w = style.font_icon:get_width(icons.settings)
  local title_w = style.font_heading:get_width("Settings")
  local h_x = self.x + math.floor(18 * s)

  local icon_y = self.y + math.floor((header_h - style.font_icon:get_height()) / 2) + icon_shift
  renderer.draw_text(style.font_icon, icons.settings, h_x, icon_y, c.lamp_gold)

  local title_y = self.y + math.floor((header_h - style.font_heading:get_height()) / 2) + optical_header_shift
  renderer.draw_text(style.font_heading, "Settings", h_x + icon_w + math.floor(10 * s), title_y, c.text_primary)

  -- Subtitle badge
  local badge_text = "System Configuration"
  local bw = style.font_small:get_width(badge_text) + math.floor(14 * s)
  local bx = h_x + icon_w + math.floor(10 * s) + title_w + math.floor(12 * s)
  local by = self.y + math.floor((header_h - math.floor(20 * s)) / 2)
  ui.draw_pill_badge(style.font_small, badge_text, bx, by, c.pill_bg, c.pill_text, math.floor(7 * s), math.floor(2 * s))

  -- Close Button [✕] in header
  local close_size = math.floor(28 * s)
  local close_x = self.x + self.w - close_size - math.floor(10 * s)
  local close_y = self.y + math.floor((header_h - close_size) / 2)
  local close_bg = self.hover_close and c.surface_active or { 0, 0, 0, 0 }
  ui.draw_rounded_box(close_x, close_y, close_size, close_size, math.floor(6 * s), close_bg, nil, 0)
  local close_icon_col = self.hover_close and c.accent_red or c.text_secondary
  ui.draw_centered_text(style.font_icon, icons.x, close_x, close_y, close_size, close_size, close_icon_col)

  -- 6. Left Navigation Sidebar
  local sidebar_x = self.x + math.floor(12 * s)
  local sidebar_w = math.floor(164 * s)
  local sidebar_y = self.y + header_h + 1
  local sidebar_h = self.h - header_h - math.floor(46 * s) - 1

  -- Vertical divider between sidebar and content panel
  renderer.draw_rect(sidebar_x + sidebar_w + math.floor(8 * s), sidebar_y, 1, sidebar_h, c.border)

  -- Sidebar Tabs
  local tab_y = sidebar_y + math.floor(10 * s)
  local tab_h = math.floor(36 * s)
  local tab_gap = math.floor(4 * s)

  local all_tabs = self:get_tabs()
  for _, tab in ipairs(all_tabs) do
    local is_active = (self.active_tab == tab.id)
    local is_hover = (self.hover_tab == tab.id)

    local tab_bg = is_active and (c.btn_gold_tint_bg or c.surface_active) or (is_hover and c.surface_hover or nil)
    if tab_bg then
      ui.draw_rounded_box(sidebar_x, tab_y, sidebar_w, tab_h, math.floor(6 * s), tab_bg, nil, 0)
    end

    -- Active indicator pill bar on left
    if is_active then
      renderer.draw_rect(sidebar_x + 1, tab_y + math.floor(8 * s), math.floor(3 * s), tab_h - math.floor(16 * s), c.lamp_gold)
    end

    local tab_icon_col = is_active and c.lamp_gold or (is_hover and c.text_primary or c.text_secondary)
    local tab_text_col = is_active and (c.btn_gold_tint_text or c.lamp_gold) or (is_hover and c.text_primary or c.text_secondary)

    -- Decoupled icon and label rendering with optical baseline compensation
    local iw = (tab.icon and style.font_icon:get_width(tab.icon)) or 0
    local label_x = sidebar_x + math.floor(14 * s)
    if iw > 0 then
      local iy = tab_y + math.floor((tab_h - style.font_icon:get_height()) / 2) + math.floor(1.0 * s)
      renderer.draw_text(style.font_icon, tab.icon, label_x, iy, tab_icon_col)
      label_x = label_x + iw + math.floor(10 * s)
    end

    local ty = tab_y + math.floor((tab_h - style.font_normal:get_height()) / 2) + math.floor(1.2 * s)
    renderer.draw_text(style.font_normal, tab.title, label_x, ty, tab_text_col)

    tab_y = tab_y + tab_h + tab_gap
  end

  -- 7. Main Content Panel
  local panel_x = sidebar_x + sidebar_w + math.floor(20 * s)
  local panel_y = self.y + header_h + math.floor(14 * s)
  local panel_w = self.w - (panel_x - self.x) - math.floor(18 * s)
  local panel_h = self.h - header_h - math.floor(60 * s)

  if self.active_tab == "display" then
    self:draw_display_tab(panel_x, panel_y, panel_w, panel_h, s, c)
  elseif self.active_tab == "typography" then
    self:draw_typography_tab(panel_x, panel_y, panel_w, panel_h, s, c)
  elseif self.active_tab == "theme" then
    self:draw_theme_tab(panel_x, panel_y, panel_w, panel_h, s, c)
  else
    -- Custom section tab
    for _, custom in ipairs(self.custom_sections) do
      if custom.id == self.active_tab and custom.render then
        custom.render(panel_x, panel_y, panel_w, panel_h, s, c, self)
        break
      end
    end
  end

  -- 8. Footer Bar
  local footer_h = math.floor(46 * s)
  local footer_y = self.y + self.h - footer_h
  renderer.draw_rect(self.x, footer_y, self.w, 1, c.border)

  -- Footer note
  local note_text = "Settings are applied live • 60 FPS compositor"
  local footer_btn_w = math.floor(84 * s)
  local footer_btn_h = math.floor(30 * s)
  local n_max_w = self.w - footer_btn_w - math.floor(48 * s)
  local n_ty = footer_y + math.floor((footer_h - style.font_small:get_height()) / 2) + math.floor(1.2 * s)
  ui.draw_wrapped_text(style.font_small, note_text, self.x + math.floor(18 * s), n_ty, n_max_w, c.text_tertiary)

  -- Footer Close Button
  local footer_btn_x = self.x + self.w - footer_btn_w - math.floor(18 * s)
  local footer_btn_y = footer_y + math.floor((footer_h - footer_btn_h) / 2)
  ui.draw_button(style.font_normal, "Close", footer_btn_x, footer_btn_y, footer_btn_w, footer_btn_h, {
    variant = "surface",
    is_hover = self.hover_footer_close,
    radius = math.floor(6 * s),
  })
end

--------------------------------------------------------------------------------
-- Tab Panels Rendering
--------------------------------------------------------------------------------

function settings:draw_display_tab(x, y, w, h, s, c)
  local core = require "core"

  -- Tab Header
  renderer.draw_text(style.font_heading, "Display Scaling", x, y, c.text_primary)
  y = y + style.font_heading:get_height() + math.floor(4 * s)
  local sub_h = select(1, ui.draw_wrapped_text(style.font_small, "Select UI scaling multiplier or auto-detect based on screen DPI.", x, y, w, c.text_secondary))
  y = y + sub_h + math.floor(14 * s)

  -- Current Scale Telemetry Pill
  local auto_s = core.get_default_scale()
  local scale_label = (s == math.floor(s)) and string.format("%dx", math.floor(s)) or string.format("%.2fx", s)
  local auto_label = (auto_s == math.floor(auto_s)) and string.format("%dx", math.floor(auto_s)) or string.format("%.2fx", auto_s)
  local pct = math.floor(s * 100 + 0.5)

  local cur_info = string.format("Current: %s (%d%%)  •  Native Display: %s", scale_label, pct, auto_label)
  ui.draw_pill_badge(style.font_small, cur_info, x, y, c.pill_bg, c.pill_text, math.floor(10 * s), math.floor(4 * s))
  y = y + math.floor(32 * s)

  -- Scale Segmented Control Track (Pinglet Style)
  local scales = {
    { label = "Auto", val = auto_s },
    { label = "1.0x", val = 1.0 },
    { label = "1.25x", val = 1.25 },
    { label = "1.5x", val = 1.5 },
    { label = "1.75x", val = 1.75 },
    { label = "2.0x", val = 2.0 },
    { label = "2.5x", val = 2.5 },
  }

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(36 * s)
  local btn_h = track_h - track_pad * 2
  local num_scales = #scales
  local track_w = math.min(w, math.floor(430 * s))
  local btn_w = math.floor((track_w - track_pad * 2) / num_scales)
  local actual_track_w = btn_w * num_scales + track_pad * 2

  ui.draw_segmented_track(x, y, actual_track_w, track_h, math.floor(8 * s))

  local cur_x = x + track_pad
  for _, opt in ipairs(scales) do
    local is_selected = (math.abs(s - opt.val) < 0.05) and (opt.label ~= "Auto" or math.abs(s - auto_s) < 0.05)
    local is_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, cur_x, y + track_pad, btn_w, btn_h)

    ui.draw_button(style.font_normal, opt.label, cur_x, y + track_pad, btn_w, btn_h, {
      variant = is_selected and "solid" or "ghost",
      accent_theme = "cyan",
      is_active = is_selected,
      is_hover = is_hover,
      radius = math.floor(6 * s),
    })
    cur_x = cur_x + btn_w
  end
  y = y + track_h + math.floor(20 * s)

  -- Telemetry Details Box
  local box_h = math.floor(118 * s)
  ui.draw_rounded_box(x, y, w, box_h, math.floor(8 * s), c.surface_hover, c.border, 1)

  local rw, rh = renderer.get_size()
  local ww, wh = system.get_window_size()
  local win_mode = system.get_window_mode and system.get_window_mode() or "normal"

  local t_y = y + math.floor(12 * s)
  local t_x = x + math.floor(16 * s)
  local t_max_w = w - math.floor(32 * s)

  renderer.draw_text(style.font_large, "Display Architecture Telemetry", t_x, t_y, c.text_primary)
  t_y = t_y + style.font_large:get_height() + math.floor(10 * s)

  local line1 = string.format("• Logical Window Size: %d × %d points (%s mode)", ww, wh, win_mode)
  local line2 = string.format("• Framebuffer Pixel Resolution: %d × %d px", rw, rh)
  local line3 = string.format("• Backing Pixel Density: %.2f pixels per point", (ww > 0) and (rw / ww) or 1.0)

  local h1 = select(1, ui.draw_wrapped_text(style.font_small, line1, t_x, t_y, t_max_w, c.text_secondary))
  t_y = t_y + h1 + math.floor(4 * s)
  local h2 = select(1, ui.draw_wrapped_text(style.font_small, line2, t_x, t_y, t_max_w, c.text_secondary))
  t_y = t_y + h2 + math.floor(4 * s)
  ui.draw_wrapped_text(style.font_small, line3, t_x, t_y, t_max_w, c.text_secondary)
end

function settings:draw_typography_tab(x, y, w, h, s, c)
  -- Tab Header
  renderer.draw_text(style.font_heading, "Typography & Fonts", x, y, c.text_primary)
  y = y + style.font_heading:get_height() + math.floor(4 * s)
  local sub_h = select(1, ui.draw_wrapped_text(style.font_small, "Manage interface font family, sizing presets, and rendering preview.", x, y, w, c.text_secondary))
  y = y + sub_h + math.floor(14 * s)

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(36 * s)
  local btn_h = track_h - track_pad * 2

  -- Font Family Selector (Pinglet Segmented Track)
  renderer.draw_text(style.font_large, "Font Family", x, y, c.text_primary)
  y = y + style.font_large:get_height() + math.floor(8 * s)

  local fam_track_w = math.min(w, math.floor(380 * s))
  local fam_btn_w = math.floor((fam_track_w - track_pad * 2) / 2)
  local fam_actual_w = fam_btn_w * 2 + track_pad * 2

  ui.draw_segmented_track(x, y, fam_actual_w, track_h, math.floor(8 * s))

  local is_ps = (self.font_family == "Public Sans")
  local ps_x = x + track_pad
  local is_ps_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, ps_x, y + track_pad, fam_btn_w, btn_h)
  ui.draw_button(style.font_normal, "Public Sans (Modern)", ps_x, y + track_pad, fam_btn_w, btn_h, {
    variant = is_ps and "solid" or "ghost",
    accent_theme = "gold",
    is_active = is_ps,
    is_hover = is_ps_hover,
    radius = math.floor(6 * s),
  })

  local is_ss = (self.font_family == "Source Sans 3")
  local ss_x = ps_x + fam_btn_w
  local is_ss_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, ss_x, y + track_pad, fam_btn_w, btn_h)
  ui.draw_button(style.font_normal, "Source Sans 3", ss_x, y + track_pad, fam_btn_w, btn_h, {
    variant = is_ss and "solid" or "ghost",
    accent_theme = "gold",
    is_active = is_ss,
    is_hover = is_ss_hover,
    radius = math.floor(6 * s),
  })

  y = y + track_h + math.floor(14 * s)

  -- Sizing Presets (Pinglet Segmented Track)
  renderer.draw_text(style.font_large, "Size Preset", x, y, c.text_primary)
  y = y + style.font_large:get_height() + math.floor(8 * s)

  local sz_track_w = math.min(w, math.floor(380 * s))
  local sz_btn_w = math.floor((sz_track_w - track_pad * 2) / 3)
  local sz_actual_w = sz_btn_w * 3 + track_pad * 2

  ui.draw_segmented_track(x, y, sz_actual_w, track_h, math.floor(8 * s))

  local sizes = { "Compact", "Standard", "Large" }
  local cur_sz_x = x + track_pad
  for _, sz in ipairs(sizes) do
    local is_sz = (self.font_size_preset == sz)
    local is_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, cur_sz_x, y + track_pad, sz_btn_w, btn_h)
    ui.draw_button(style.font_normal, sz, cur_sz_x, y + track_pad, sz_btn_w, btn_h, {
      variant = is_sz and "solid" or "ghost",
      accent_theme = "gold",
      is_active = is_sz,
      is_hover = is_hover,
      radius = math.floor(6 * s),
    })
    cur_sz_x = cur_sz_x + sz_btn_w
  end

  y = y + track_h + math.floor(16 * s)

  -- Live Typography Preview Box
  local inner_pad = math.floor(14 * s)
  local inner_w = w - inner_pad * 2
  local prev_h = math.floor(118 * s)
  ui.draw_rounded_box(x, y, w, prev_h, math.floor(8 * s), c.surface_hover, c.border, 1)

  local p_y = y + math.floor(12 * s)
  local p_x = x + inner_pad

  local h1 = select(1, ui.draw_wrapped_text(style.font_large, "The quick brown fox jumps over the lazy dog.", p_x, p_y, inner_w, c.text_primary))
  p_y = p_y + h1 + math.floor(4 * s)
  local h2 = select(1, ui.draw_wrapped_text(style.font_normal, "0123456789  •  !@#$%^&*()_+-=[]{}|;':,./<>?", p_x, p_y, inner_w, c.text_secondary))
  p_y = p_y + h2 + math.floor(4 * s)

  local preview_note = "Rendered via native TrueType rasterizer with subpixel grayscale anti-aliasing."
  ui.draw_wrapped_text(style.font_small, preview_note, p_x, p_y, inner_w, c.lamp_gold)
end

function settings:draw_theme_tab(x, y, w, h, s, c)
  local canvas = require "src.canvas"

  -- Tab Header
  renderer.draw_text(style.font_heading, "Appearance & Themes", x, y, c.text_primary)
  y = y + style.font_heading:get_height() + math.floor(4 * s)
  local sub_h = select(1, ui.draw_wrapped_text(style.font_small, "Customize color scheme, ambient background, and animated effects.", x, y, w, c.text_secondary))
  y = y + sub_h + math.floor(14 * s)

  local track_pad = math.floor(3 * s)
  local track_h = math.floor(38 * s)
  local btn_h = track_h - track_pad * 2

  -- Color Palette (Pinglet Segmented Track with Luminous Tinted Buttons)
  renderer.draw_text(style.font_large, "Color Palette", x, y, c.text_primary)
  y = y + style.font_large:get_height() + math.floor(8 * s)

  local theme_track_w = math.min(w, math.floor(380 * s))
  local theme_btn_w = math.floor((theme_track_w - track_pad * 2) / 2)
  local theme_actual_w = theme_btn_w * 2 + track_pad * 2

  ui.draw_segmented_track(x, y, theme_actual_w, track_h, math.floor(8 * s))

  local is_dark = (style.current_theme == "dark")
  local dark_x = x + track_pad
  local is_dark_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, dark_x, y + track_pad, theme_btn_w, btn_h)
  ui.draw_button(style.font_normal, "Dark Mode", dark_x, y + track_pad, theme_btn_w, btn_h, {
    variant = is_dark and "tinted" or "ghost",
    accent_theme = "gold",
    is_active = is_dark,
    is_hover = is_dark_hover,
    icon = icons.moon,
    radius = math.floor(6 * s),
  })

  local is_light = (style.current_theme == "light")
  local light_x = dark_x + theme_btn_w
  local is_light_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, light_x, y + track_pad, theme_btn_w, btn_h)
  ui.draw_button(style.font_normal, "Light Mode", light_x, y + track_pad, theme_btn_w, btn_h, {
    variant = is_light and "tinted" or "ghost",
    accent_theme = "gold",
    is_active = is_light,
    is_hover = is_light_hover,
    icon = icons.sun,
    radius = math.floor(6 * s),
  })

  y = y + track_h + math.floor(20 * s)

  -- Lamp Pulse Animation Toggle (Pinglet Luminous Tinted Button)
  renderer.draw_text(style.font_large, "Canvas Animation", x, y, c.text_primary)
  y = y + style.font_large:get_height() + math.floor(8 * s)

  local glow_w = math.min(w, math.floor(260 * s))
  local glow_h = math.floor(38 * s)
  local is_glow_hover = self.mouse_x and self.mouse_y and ui.point_in_rect(self.mouse_x, self.mouse_y, x, y, glow_w, glow_h)
  local glow_icon = canvas.lamp_on and icons.bulb_filled or icons.bulb_off
  local glow_label = canvas.lamp_on and "Glowing Filament: Active" or "Glowing Filament: Off"

  ui.draw_button(style.font_normal, glow_label, x, y, glow_w, glow_h, {
    variant = "tinted",
    accent_theme = "gold",
    is_active = canvas.lamp_on,
    is_hover = is_glow_hover,
    icon = glow_icon,
    radius = math.floor(7 * s),
  })
end

return settings

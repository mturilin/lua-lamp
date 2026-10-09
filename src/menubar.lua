-- Lua Lamp In-Window Menu Bar Component (for Linux / Windows platforms)
-- Follows AGENTS.md optical baseline compensation and borderless surface styling.

local style = require "src.style"
local ui = require "src.ui"

local menubar = {
  active_menu = nil,      -- category name of currently opened dropdown
  hover_category = nil,   -- category name currently hovered in top bar
  hover_item_idx = nil,   -- index of item hovered in active dropdown
  bounds = {},            -- map of category -> { x, y, w, h }
  dropdown_bounds = nil,  -- { x, y, w, h, items } for active dropdown
}

function menubar.get_height()
  local s = style.scale or 1
  return math.floor(28 * s)
end

function menubar.close()
  menubar.active_menu = nil
  menubar.hover_item_idx = nil
  menubar.dropdown_bounds = nil
end

function menubar.is_open()
  return menubar.active_menu ~= nil
end

function menubar.on_mouse_moved(px, py)
  local s = style.scale or 1
  menubar.hover_category = nil

  -- 1. Check top bar item hover
  local bar_h = menubar.get_height()
  if py <= bar_h then
    for cat, b in pairs(menubar.bounds) do
      if px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h then
        menubar.hover_category = cat
        -- If another menu is already open, hover switches active dropdown (standard desktop behavior)
        if menubar.active_menu and menubar.active_menu ~= cat then
          menubar.active_menu = cat
        end
        return true
      end
    end
  end

  -- 2. Check dropdown item hover
  if menubar.dropdown_bounds then
    local d = menubar.dropdown_bounds
    if px >= d.x and px <= d.x + d.w and py >= d.y and py <= d.y + d.h then
      local item_h = math.floor(26 * s)
      local cur_y = d.y + math.floor(4 * s)
      menubar.hover_item_idx = nil
      for i, item in ipairs(d.items) do
        local h = (item.text == "-" or item == "-") and math.floor(8 * s) or item_h
        if py >= cur_y and py < cur_y + h then
          if item.text ~= "-" and item ~= "-" then
            menubar.hover_item_idx = i
          end
          break
        end
        cur_y = cur_y + h
      end
      return true
    else
      menubar.hover_item_idx = nil
    end
  end

  return menubar.active_menu ~= nil
end

function menubar.on_mouse_pressed(button, px, py, menu_registry)
  if button ~= 1 and button ~= "left" then return false end
  local s = style.scale or 1

  -- 1. Clicked top bar category header
  local bar_h = menubar.get_height()
  if py <= bar_h then
    for cat, b in pairs(menubar.bounds) do
      if px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h then
        if menubar.active_menu == cat then
          menubar.close()
        else
          menubar.active_menu = cat
        end
        return true
      end
    end
  end

  -- 2. Clicked item inside active dropdown
  if menubar.dropdown_bounds and menubar.hover_item_idx then
    local item = menubar.dropdown_bounds.items[menubar.hover_item_idx]
    if item and item.command then
      local cmd = item.command
      menubar.close()
      if menu_registry and menu_registry.trigger then
        menu_registry:trigger(cmd)
      end
      return true
    end
  end

  -- 3. Clicked outside active menu
  if menubar.active_menu then
    menubar.close()
    return true
  end

  return false
end

function menubar.draw(win_w, win_h, categories_order, categories_map)
  local c = style.colors
  local s = style.scale or 1
  local bar_h = menubar.get_height()

  -- 1. Top Menu Bar Background Strip
  local bar_bg = { c.surface[1], c.surface[2], c.surface[3], 240 }
  renderer.draw_rect(0, 0, win_w, bar_h, bar_bg)
  renderer.draw_rect(0, bar_h - 1, win_w, 1, c.border)

  -- Optical baseline compensation
  local optical_shift = math.floor(1.2 * s)
  local font = style.font_small or style.font_normal
  local font_h = font:get_height()
  local text_y = math.floor((bar_h - font_h) / 2) + optical_shift

  -- 2. Draw Top Bar Categories
  local cur_x = math.floor(12 * s)
  menubar.bounds = {}

  for _, cat in ipairs(categories_order) do
    local text_w = font:get_width(cat)
    local btn_pad_x = math.floor(8 * s)
    local btn_w = text_w + btn_pad_x * 2
    local btn_h = math.floor(22 * s)
    local btn_y = math.floor((bar_h - btn_h) / 2)

    menubar.bounds[cat] = { x = cur_x, y = btn_y, w = btn_w, h = btn_h }

    local is_hover = (menubar.hover_category == cat)
    local is_active = (menubar.active_menu == cat)

    if is_active then
      ui.draw_rounded_box(cur_x, btn_y, btn_w, btn_h, 5 * s, c.surface_active, nil, 0)
    elseif is_hover then
      ui.draw_rounded_box(cur_x, btn_y, btn_w, btn_h, 5 * s, c.surface_hover, nil, 0)
    end

    local text_col = (is_active or is_hover) and c.text_primary or c.text_secondary
    renderer.draw_text(font, cat, cur_x + btn_pad_x, text_y, text_col)

    cur_x = cur_x + btn_w + math.floor(4 * s)
  end

  -- 3. Draw Active Dropdown Menu
  if menubar.active_menu and categories_map[menubar.active_menu] then
    local items = categories_map[menubar.active_menu]
    local b = menubar.bounds[menubar.active_menu] or { x = 12 * s, y = 0, w = 60 * s, h = bar_h }

    local drop_x = b.x
    local drop_y = bar_h

    -- Compute dropdown width and height
    local min_w = math.floor(180 * s)
    local max_item_w = min_w
    local total_h = math.floor(8 * s) -- top + bottom padding
    local item_h = math.floor(26 * s)

    for _, item in ipairs(items) do
      if item == "-" or item.text == "-" then
        total_h = total_h + math.floor(8 * s)
      else
        local tw = font:get_width(item.text or item.label or "")
        local sw = item.shortcut and (font:get_width(item.shortcut) + 24 * s) or 0
        max_item_w = math.max(max_item_w, tw + sw + 40 * s)
        total_h = total_h + item_h
      end
    end

    local drop_w = max_item_w
    if drop_x + drop_w > win_w - 8 * s then
      drop_x = win_w - drop_w - 8 * s
    end

    menubar.dropdown_bounds = {
      x = drop_x,
      y = drop_y,
      w = drop_w,
      h = total_h,
      items = items,
    }

    -- Dropdown Shadow & Surface
    ui.draw_rounded_box(drop_x, drop_y + 4 * s, drop_w, total_h, 8 * s, { 0, 0, 0, 80 }, nil, 0)
    ui.draw_rounded_box(drop_x, drop_y, drop_w, total_h, 8 * s, c.surface, c.border, 1)

    -- Render Menu Items
    local item_y = drop_y + math.floor(4 * s)
    for i, item in ipairs(items) do
      if item == "-" or item.text == "-" then
        local sep_y = item_y + math.floor(3 * s)
        renderer.draw_rect(drop_x + 8 * s, sep_y, drop_w - 16 * s, 1, c.border)
        item_y = item_y + math.floor(8 * s)
      else
        local is_item_hover = (menubar.hover_item_idx == i)
        local row_pad_x = math.floor(8 * s)
        local row_w = drop_w - row_pad_x * 2

        if is_item_hover then
          ui.draw_rounded_box(drop_x + row_pad_x, item_y, row_w, item_h, 5 * s, c.surface_hover, nil, 0)
        end

        local item_text_y = item_y + math.floor((item_h - font_h) / 2) + optical_shift
        local item_text_col = is_item_hover and c.text_primary or c.text_secondary
        local label = item.text or item.label or ""

        renderer.draw_text(font, label, drop_x + row_pad_x + 8 * s, item_text_y, item_text_col)

        -- Shortcut badge (right-aligned)
        if item.shortcut then
          local sw = font:get_width(item.shortcut)
          local sx = drop_x + drop_w - row_pad_x - 8 * s - sw
          renderer.draw_text(font, item.shortcut, sx, item_text_y, c.text_tertiary)
        end

        item_y = item_y + item_h
      end
    end
  end
end

return menubar

-- Lua Lamp Unified Menu System & Cross-Platform Menu Registry
-- Routes to native macOS NSMenu on Apple, and in-window MenuBar on Linux/Windows.

local menubar = require "src.menubar"

local menu = {
  DIVIDER = { text = "-" },
  categories_order = {},
  categories = {},
  command_handlers = {},
}

--- Register or append items to a menu category
---@param category string Category name (e.g. "Lua Lamp", "File", "View", "Tools", "Help")
---@param items table List of menu items: { text = string, shortcut = string?, command = string?, action = function()? }
function menu:register(category, items)
  if not self.categories[category] then
    table.insert(self.categories_order, category)
    self.categories[category] = {}
  end

  for _, item in ipairs(items) do
    if type(item) == "string" and (item == "-" or item == "---") then
      table.insert(self.categories[category], { text = "-" })
    elseif type(item) == "table" then
      local entry = {
        text = item.text or item.label or "-",
        shortcut = item.shortcut,
        command = item.command,
        icon = item.icon,
      }
      table.insert(self.categories[category], entry)

      if item.command and item.action then
        self.command_handlers[item.command] = item.action
      end
    end
  end

  -- Synchronize with native macOS menu bar if on Apple
  self:sync_native()
end

--- Register a command execution handler
function menu:bind(command_id, handler_fn)
  self.command_handlers[command_id] = handler_fn
end

--- Trigger a menu command by ID
function menu:trigger(command_id)
  if not command_id then return false end

  local handler = self.command_handlers[command_id]
  if handler then
    handler()
    return true
  end

  -- Built-in system command dispatchers
  if command_id == "app:quit" then
    local core = require "core"
    core.quit_requested = true
    return true
  elseif command_id == "canvas:toggle-theme" then
    local style = require "src.style"
    style.toggle_theme()
    local core = require "core"
    core.redraw = true
    return true
  elseif command_id == "app:toggle-fullscreen" then
    if system.get_window_mode and system.set_window_mode then
      local mode = system.get_window_mode()
      system.set_window_mode(mode == "fullscreen" and "normal" or "fullscreen")
      local core = require "core"
      core.redraw = true
      return true
    end
  elseif command_id == "app:open-settings" then
    local ok, settings = pcall(require, "src.settings_dialog")
    if ok and settings and settings.show then
      settings:show()
      local core = require "core"
      core.redraw = true
      return true
    end
  elseif command_id == "app:about" then
    local ok, MessageBox = pcall(require, "libraries.widget.messagebox")
    if ok and MessageBox then
      local msg = MessageBox("About Lua Lamp",
        "Lua Lamp v1.0.0\n\n" ..
        "Native Lua 5.4 & SDL3 Desktop Application Platform.\n" ..
        "Extensible native menus, modal dialogs, and high-performance compositor.")
      msg:show()
      local core = require "core"
      core.redraw = true
      return true
    end
  end

  return false
end

--- Synchronize registered menus with the native OS menu bar (macOS Cocoa AppKit)
function menu:sync_native()
  if PLATFORM == "Mac OS X" and system.set_native_menu then
    local tree = {}
    for _, cat in ipairs(self.categories_order) do
      local cat_items = self.categories[cat] or {}
      local items_copy = {}
      for _, it in ipairs(cat_items) do
        table.insert(items_copy, {
          text = it.text,
          shortcut = it.shortcut,
          command = it.command,
        })
      end
      table.insert(tree, {
        title = cat,
        items = items_copy,
      })
    end
    system.set_native_menu(tree)
  end
end

--- Draw in-window menu bar (Linux / Windows)
function menu:draw(win_w, win_h)
  if PLATFORM ~= "Mac OS X" then
    menubar.draw(win_w, win_h, self.categories_order, self.categories)
  end
end

function menu:on_mouse_moved(px, py)
  if PLATFORM ~= "Mac OS X" then
    return menubar.on_mouse_moved(px, py)
  end
  return false
end

function menu:on_mouse_pressed(button, px, py)
  if PLATFORM ~= "Mac OS X" then
    return menubar.on_mouse_pressed(button, px, py, self)
  end
  return false
end

function menu:is_open()
  if PLATFORM ~= "Mac OS X" then
    return menubar.is_open()
  end
  return false
end

function menu:close()
  if PLATFORM ~= "Mac OS X" then
    menubar.close()
  end
end

function menu:get_height()
  if PLATFORM ~= "Mac OS X" then
    return menubar.get_height()
  end
  return 0
end

--- Initialize standard default application menus
function menu.init_defaults()
  local is_mac = (PLATFORM == "Mac OS X")

  if is_mac then
    -- On macOS, the standard application menu lives in the system app menu (item 0).
    -- Registering "Lua Lamp" configures Settings… and About in the system application menu.
    menu:register("Lua Lamp", {
      { text = "About Lua Lamp", command = "app:about" },
      menu.DIVIDER,
      { text = "Settings…", shortcut = "Cmd+,", command = "app:open-settings" },
    })
  else
    -- On Linux / Windows, in-window menu bar requires "File" menu containing Settings and Quit
    menu:register("File", {
      { text = "Settings…", shortcut = "Ctrl+,", command = "app:open-settings" },
      menu.DIVIDER,
      { text = "Quit Lua Lamp", shortcut = "Ctrl+Q", command = "app:quit" },
    })
  end

  -- View Menu
  menu:register("View", {
    { text = "Toggle Theme", shortcut = "T", command = "canvas:toggle-theme" },
    { text = "Toggle Fullscreen", shortcut = "F11", command = "app:toggle-fullscreen" },
  })

  -- Help Menu
  menu:register("Help", {
    { text = "About Lua Lamp", command = "app:about" },
  })
end

return menu

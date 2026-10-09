-- Lua Lamp — Developer Application Framework ("Mini-Flutter for Lua & SDL3")
-- Standardized facade providing first-class access to UI widgets, layout containers,
-- vector graphics primitives, theming, modal dialogs, and native menu subsystems.

local framework = {}

-- 1. Core Platform & Engine Primitives
local core = require "core"
framework.core = core
framework.View = require "core.view"
framework.add_thread = core.add_thread
framework.rescale = core.rescale
framework.get_scale = core.get_default_scale

-- 2. Styling, Vector Graphics & Tabler Icons
framework.Style = require "src.style"
framework.UI = require "src.ui"
framework.Icons = require "src.icons"
framework.draw_button = framework.UI.draw_button
framework.draw_segmented_track = framework.UI.draw_segmented_track

-- 3. Cross-Platform Menu, Permissions & Settings Subsystems
framework.Menu = require "src.menu"
framework.Permissions = require "src.permissions"
framework.Settings = require "src.settings_dialog"
framework.Canvas = require "src.canvas"

-- 4. Lite XL UI Layer Widgets (Retained Mode Component Tree)
framework.Widget      = require "widget"
framework.Button      = require "widget.button"
framework.Label       = require "widget.label"
framework.Toggle      = require "widget.toggle"
framework.CheckBox    = require "widget.checkbox"
framework.TextBox     = require "widget.textbox"
framework.NoteBook    = require "widget.notebook"
framework.SelectBox   = require "widget.selectbox"
framework.ListBox     = require "widget.listbox"
framework.ScrollBar   = require "widget.scrollbar"
framework.ProgressBar = require "widget.progressbar"
framework.ColorPicker = require "widget.colorpicker"
framework.MessageBox  = require "widget.messagebox"
framework.Dialog      = require "widget.dialog"

--- Declarative Application Launcher / Configuration
---@param config { name: string?, title: string?, width: number?, height: number?, menu: table?, settings: table?, initial_view: any, on_init: function? }
function framework.App(config)
  if type(config) ~= "table" then return end

  if config.title and system.set_window_title then
    system.set_window_title(config.title)
  end

  if config.width and config.height and system.set_window_size then
    local _, _, cur_x, cur_y = system.get_window_size()
    system.set_window_size(config.width, config.height, cur_x or 80, cur_y or 80)
  end

  if config.menu then
    for category, items in pairs(config.menu) do
      framework.Menu:register(category, items)
    end
  end

  if config.settings then
    for _, s in ipairs(config.settings) do
      framework.Settings:register_section(s.id, s.title, s.icon, s.render)
    end
  end

  if config.on_init then
    config.on_init()
  end

  local view = config.initial_view or (config.build and config.build())
  if view and core.root_view then
    core.root_view.root_node.views = { view }
    core.root_view.root_node.active_view = view
    core.active_view = view
    core.redraw = true
  end

  return view
end

return framework

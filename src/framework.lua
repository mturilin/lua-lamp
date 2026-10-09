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
framework.ScrollView = require "src.scroll_view"

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

--- Check current status of a permission ("granted", "denied", "not_determined", "unsupported")
function framework.get_permission_status(perm_type, options)
  return framework.Permissions.get_status(perm_type, options)
end

--- Check if a permission is currently granted
function framework.is_permission_granted(perm_type)
  return framework.Permissions.is_granted(perm_type)
end

--- Request authorization for a permission asynchronously with optional callback
function framework.request_permission(perm_type, options, callback)
  return framework.Permissions.request(perm_type, options, callback)
end

--- Create a Pinglet-standard inline permission warning/action banner
function framework.create_permission_banner(perm_type, options)
  return framework.Permissions.create_banner(perm_type, options)
end

--- Declarative Application Launcher / Configuration
---@param config { name: string?, title: string?, width: number?, height: number?, menu: table?, settings: table?, permissions: table?, initial_view: any, on_init: function? }
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

  -- Normalize & Process Declarative System Permissions
  local declared_perms = {}
  local raw_perms = config.permissions or (core.manifest and core.manifest.permissions)
  if type(raw_perms) == "table" then
    for k, v in pairs(raw_perms) do
      if type(k) == "number" and type(v) == "string" then
        declared_perms[v] = { auto_request = true }
      elseif type(k) == "string" then
        if type(v) == "table" then
          declared_perms[k] = v
        elseif v == true then
          declared_perms[k] = { auto_request = true }
        elseif v == false then
          declared_perms[k] = { auto_request = false }
        end
      end
    end
  end

  framework.declared_permissions = declared_perms

  if framework.Permissions.is_macos() then
    for perm_id, opts in pairs(declared_perms) do
      if opts.auto_request ~= false then
        framework.Permissions.request(perm_id, opts, function(status, granted)
          if opts.on_change then
            opts.on_change(status, granted)
          end
          if core then core.redraw = true end
        end)
      end
    end
  end

  if config.on_init then
    config.on_init()
  end

  local view = config.initial_view or (config.build and config.build())
  if view then
    view.permissions = declared_perms
    if core.root_view then
      core.root_view.root_node.views = { view }
      core.root_view.root_node.active_view = view
      core.active_view = view
      core.redraw = true
    end
  end

  return view
end

return framework

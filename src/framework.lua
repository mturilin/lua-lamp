-- Lua Lamp — Developer Application Framework ("Mini-Flutter for Lua & SDL3")
-- Standardized facade providing first-class access to UI widgets, layout containers,
-- vector graphics primitives, theming, modal dialogs, and native menu subsystems.

local framework = {}

-- 1. Core Platform & Engine Primitives
local core = require "core"
framework.core = core
framework.add_thread = core.add_thread
framework.rescale = core.rescale
framework.get_scale = core.get_default_scale

-- 2. Styling, Vector Graphics & Tabler Icons
framework.Style = require "src.style"
framework.UI = require "src.ui"
framework.Icons = require "src.icons"
framework.draw_button = framework.UI.draw_button
framework.draw_segmented_track = framework.UI.draw_segmented_track

-- 3. Cross-Platform Menu & Settings Subsystems
framework.Menu = require "src.menu"
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

return framework

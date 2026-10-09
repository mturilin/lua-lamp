-- Lua Lamp Automated Verification Suite
-- Tests engine initialization, styling, canvas rendering, and event dispatching.

print("========================================")
print("LUA LAMP AUTOMATED VERIFICATION SUITE")
print("========================================")

local style = require "src.style"
local ui = require "src.ui"
local canvas = require "src.canvas"
local core = require "core"

-- 1. Test Engine Initialization
core.init()
assert(core.initialized == true, "Engine should be marked initialized")
assert(style.colors ~= nil, "Style colors should be populated")
assert(style.current_theme == "dark", "Default theme should be dark")
print("[PASS] Engine initialized successfully.")

local icons = require "src.icons"

-- 2. Test Font System & Tabler Icons
assert(style.font_hero ~= nil, "Hero font should be loaded")
assert(style.font_heading ~= nil, "Heading font should be loaded")
assert(style.font_normal ~= nil, "Normal font should be loaded")
assert(style.font_icon ~= nil, "Tabler icon font should be loaded")
assert(style.font_icon_large ~= nil, "Large Tabler icon font should be loaded")

local text_w = style.font_hero:get_width("Hello, World!")
assert(text_w > 0, "Hero font width should be greater than 0")

local sun_w = style.font_icon:get_width(icons.sun)
assert(sun_w > 0, "Tabler outline icon (sun) should have non-zero width")
local bulb_w = style.font_icon:get_width(icons.bulb_filled)
assert(bulb_w > 0, "Tabler filled icon (bulb_filled) should have non-zero width")
print(string.format("[PASS] Fonts loaded and measured successfully. Text width: %.1f, Tabler icon width: %.1f", text_w, sun_w))

-- 3. Test Theme Toggling
local t1 = style.toggle_theme()
assert(t1 == "light", "Toggling from dark should switch to light")
assert(style.current_theme == "light", "Current theme state mismatch")
local t2 = style.toggle_theme()
assert(t2 == "dark", "Toggling from light should switch back to dark")
print("[PASS] Theme toggle (dark <-> light) verified.")

-- 4. Test Canvas State & Interactive Ripple System
assert(canvas.lamp_on == true, "Lamp should default to ON")
canvas.toggle_lamp()
assert(canvas.lamp_on == false, "Lamp toggle should turn OFF")
canvas.toggle_lamp()
assert(canvas.lamp_on == true, "Lamp toggle should turn back ON")

local initial_ripples = #canvas.click_ripples
canvas.add_ripple(400, 300)
assert(#canvas.click_ripples == initial_ripples + 1, "Adding ripple should increment ripple count")
canvas.update(0.05)
assert(canvas.click_ripples[1].radius > 6, "Ripple should expand over time")
print("[PASS] Canvas state transitions and ripple animations verified.")

-- 5. Test UI Geometry Helpers & Text Wrapping
assert(ui.point_in_rect(50, 50, 0, 0, 100, 100) == true, "Point should be inside rect")
assert(ui.point_in_rect(150, 50, 0, 0, 100, 100) == false, "Point should be outside rect")

local wrap_sample = "Rendered via native TrueType rasterizer with subpixel grayscale anti-aliasing."
local wrapped_lines = ui.wrap_text(style.font_small, wrap_sample, 250)
assert(#wrapped_lines >= 2, "Long sample text should wrap into 2 or more lines when constrained to 250px")
for _, line in ipairs(wrapped_lines) do
  assert(style.font_small:get_width(line) <= 250, "Every wrapped line must fit within max width constraint")
end

local long_word = "Supercalifragilisticexpialidocious_unbroken_long_string"
local broken_lines = ui.wrap_text(style.font_small, long_word, 80)
assert(#broken_lines >= 2, "Unbroken long string must wrap into multiple lines via character break")

local wrapped_h, line_count = ui.draw_wrapped_text(style.font_small, wrap_sample, 10, 10, 250, { 255, 255, 255, 255 })
assert(line_count == #wrapped_lines, "draw_wrapped_text line count should match wrap_text output")
assert(wrapped_h > 0, "draw_wrapped_text total height must be positive")
print("[PASS] UI geometric calculations and multi-line text wrapping verified.")

-- 6. Test Coroutine Scheduler
local thread_executed = false
core.add_thread(function()
  thread_executed = true
end)
assert(#core.threads == 1, "Thread should be registered in scheduler")
core.step_threads()
assert(thread_executed == true, "Thread should have executed upon stepping")
assert(#core.threads == 0, "Dead thread should be purged from scheduler")
print("[PASS] Coroutine worker thread scheduler verified.")

-- 7. Test Frame Rendering Compositor
local win_w, win_h = renderer.get_size()
print(string.format("Testing SDL3 Compositor Frame Rendering (Window: %dx%d)...", math.floor(win_w), math.floor(win_h)))

renderer.begin_frame()
core.draw()
renderer.end_frame()
print("[PASS] Canvas frame rendered with zero errors.")

-- 8. Test Event Dispatching
core.on_event("mousemoved", 250, 180)
assert(canvas.mouse_x == 250 and canvas.mouse_y == 180, "Mouse move event should update canvas coordinates")

local cur_rips = #canvas.click_ripples
core.on_event("mousepressed", "left", 320, 240)
assert(#canvas.click_ripples == cur_rips + 1, "Mouse press should spawn a ripple")

local was_lamp_on = canvas.lamp_on
core.on_event("keypressed", "space")
assert(canvas.lamp_on == not was_lamp_on, "Space key should toggle lamp state")
core.on_event("keypressed", "space")
assert(canvas.lamp_on == was_lamp_on, "Second space key should restore lamp state")

local cur_theme = style.current_theme
core.on_event("keypressed", "t")
assert(style.current_theme ~= cur_theme, "T key should toggle theme")
core.on_event("keypressed", "t")
assert(style.current_theme == cur_theme, "Second T key should restore theme")

print("[PASS] Mouse and keyboard event dispatching verified.")

-- 9. Test UI Layer Framework Primitives & Widgets
local Object = require "core.object"
local View = require "core.view"
local Node = require "core.node"
local RootView = require "core.rootview"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"
local Toggle = require "widget.toggle"
local TextBox = require "widget.textbox"
local Dialog = require "widget.dialog"

assert(Object ~= nil and View ~= nil and Node ~= nil and RootView ~= nil, "UI core primitives should load")
assert(Widget ~= nil and Button ~= nil and Label ~= nil and Toggle ~= nil and TextBox ~= nil and Dialog ~= nil, "UI widgets should load")

local panel = Widget()
panel:set_position(10, 10)
panel:set_size(240, 160)
local test_btn = Button(panel, "Action")
local test_lbl = Label(panel, "Settings")
local test_tog = Toggle(panel, "Active", true)
assert(test_btn ~= nil and test_lbl ~= nil and test_tog ~= nil, "Widgets should instantiate properly")

renderer.begin_frame()
core.draw()
panel:draw()
renderer.end_frame()
print("[PASS] UI Layer (Object, View, Node, RootView, Widgets) verified.")

-- 10. Test High-DPI Display Scale Detection & Dynamic Rescaling
local detected_scale = core.get_default_scale()
assert(detected_scale ~= nil and detected_scale > 0, "Default scale should be greater than 0")
assert(SCALE == detected_scale, "Global SCALE should match automatically detected scale")
print(string.format("[PASS] Automatic display scale detected: %.2fx", detected_scale))

-- Test dynamic scale change event
local prev_scale = SCALE
core.on_event("scalechanged", 3.0)
assert(SCALE == 3.0, "Scale changed event should update global SCALE")
assert(style.scale == 3.0, "Scale changed event should update style.scale")
local large_hero_w = style.font_hero:get_width("Hello, World!")
assert(large_hero_w > 0, "Hero font should be reloaded with 3x scale")

-- Restore detected scale
core.on_event("scalechanged", prev_scale)
assert(SCALE == prev_scale, "Scale should be successfully restored")
print("[PASS] Dynamic display scale change event (scalechanged) verified.")

-- 11. Test Unified Menu System, Extensible Settings Modal, & Mini-Flutter Facade
local menu = require "src.menu"
local settings = require "src.settings_dialog"
local framework = require "src.framework"

-- Test Menu Registry
local custom_menu_clicked = false
menu:register("Tools", {
  { text = "Custom Tool", command = "tools:custom", action = function() custom_menu_clicked = true end }
})
assert(menu.categories["Tools"] ~= nil, "Tools category should be registered")
assert(#menu.categories["Tools"] >= 1, "Tools category should have at least 1 item")
menu:trigger("tools:custom")
assert(custom_menu_clicked == true, "Triggering tools:custom should execute custom handler")

-- Test Triggering Theme Toggle via Menu
local pre_theme = style.current_theme
menu:trigger("canvas:toggle-theme")
assert(style.current_theme ~= pre_theme, "Menu trigger canvas:toggle-theme should toggle theme")
menu:trigger("canvas:toggle-theme") -- restore

-- Test Settings Modal Dialog Lifecycle
assert(settings.visible == false, "Settings dialog should default to closed")
menu:trigger("app:open-settings")
assert(settings.visible == true, "Triggering app:open-settings should open Settings dialog")

-- Test Tab Switching
assert(settings.active_tab == "display", "Default tab should be display")
settings.active_tab = "typography"
assert(settings.active_tab == "typography", "Settings tab should switch to typography")
settings.active_tab = "theme"
assert(settings.active_tab == "theme", "Settings tab should switch to theme")

-- Test Extensible Custom Section Registration
local custom_tab_rendered = false
settings:register_section("my_plugin", "Plugin Options", icons.settings, function(px, py, pw, ph, s, c, dlg)
  custom_tab_rendered = true
end)
local all_tabs = settings:get_tabs()
local found_custom = false
for _, tab in ipairs(all_tabs) do
  if tab.id == "my_plugin" then found_custom = true break end
end
assert(found_custom == true, "Custom section should be present in tabs list")

settings.active_tab = "my_plugin"
renderer.begin_frame()
core.draw()
renderer.end_frame()
assert(custom_tab_rendered == true, "Custom tab render function should be invoked when tab is active")

-- Test Live Scale Change via Settings Action
settings.active_tab = "display"
local test_scale = 1.75
core.rescale(test_scale)
assert(SCALE == test_scale, "Live scale change should update SCALE to 1.75")
assert(style.scale == test_scale, "Live scale change should update style.scale to 1.75")
core.rescale(detected_scale) -- restore

-- Test Escape Key dismisses Settings
core.on_event("keypressed", "escape")
assert(settings.visible == false, "Pressing escape should dismiss Settings dialog")

-- Test Mini-Flutter Framework Facade & Pinglet Button Highlight Standard
assert(framework.Widget ~= nil, "framework.Widget should be defined")
assert(framework.Button ~= nil, "framework.Button should be defined")
assert(framework.NoteBook ~= nil, "framework.NoteBook should be defined")
assert(framework.Dialog ~= nil, "framework.Dialog should be defined")
assert(framework.Settings ~= nil, "framework.Settings should be defined")
assert(framework.Menu ~= nil, "framework.Menu should be defined")
assert(framework.UI ~= nil, "framework.UI should be defined")
assert(framework.Icons ~= nil, "framework.Icons should be defined")
assert(type(framework.draw_button) == "function", "framework.draw_button should be exposed")
assert(type(framework.draw_segmented_track) == "function", "framework.draw_segmented_track should be exposed")

-- Test Pinglet Button Highlight Rendering Primitives (all variants)
renderer.begin_frame()
ui.draw_segmented_track(100, 100, 300, 36, 8)
local bx, by, bw, bh = ui.draw_button(style.font_normal, "60s", 103, 103, 48, 30, {
  variant = "solid", accent_theme = "cyan", is_active = true
})
assert(bx == 103 and bw == 48, "ui.draw_button solid should return geometry")

local tx, ty, tw, th = ui.draw_button(style.font_normal, "Follow", 155, 103, 60, 30, {
  variant = "tinted", accent_theme = "cyan", is_active = true, icon = icons.settings
})
assert(tx == 155 and tw == 60, "ui.draw_button tinted with icon should return geometry")

local sx, sy, sw, sh = ui.draw_button(style.font_normal, "Action", 220, 103, 60, 30, {
  variant = "surface", is_hover = true
})
assert(sx == 220 and sw == 60, "ui.draw_button surface hover should return geometry")

local gx, gy, gw, gh = ui.draw_button(style.font_normal, "Ghost", 285, 103, 40, 30, {
  variant = "ghost", is_active = false
})
assert(gx == 285 and gw == 40, "ui.draw_button ghost should return geometry")
renderer.end_frame()

print("[PASS] Unified Menu System, Extensible Settings Modal, & Pinglet Button Standard verified.")

print("\n========================================")
print("ALL LUA LAMP VERIFICATION TESTS PASSED!")
print("========================================")
os.exit(0)

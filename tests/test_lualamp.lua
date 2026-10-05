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

-- 2. Test Font System
assert(style.font_hero ~= nil, "Hero font should be loaded")
assert(style.font_heading ~= nil, "Heading font should be loaded")
assert(style.font_normal ~= nil, "Normal font should be loaded")
local text_w = style.font_hero:get_width("Hello, World!")
assert(text_w > 0, "Hero font width should be greater than 0")
print("[PASS] Fonts loaded and measured successfully. 'Hello, World!' width:", text_w)

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

-- 5. Test UI Geometry Helpers
assert(ui.point_in_rect(50, 50, 0, 0, 100, 100) == true, "Point should be inside rect")
assert(ui.point_in_rect(150, 50, 0, 0, 100, 100) == false, "Point should be outside rect")
print("[PASS] UI geometric calculations verified.")

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
print(string.format("Testing SDL2 Compositor Frame Rendering (Window: %dx%d)...", math.floor(win_w), math.floor(win_h)))

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

print("\n========================================")
print("ALL LUA LAMP VERIFICATION TESTS PASSED!")
print("========================================")
os.exit(0)

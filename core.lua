-- Lua Lamp Main Engine Core & SDL3 Application Lifecycle
-- High-performance, lightweight generic application development platform based on SDL3.

local style = require "src.style"
local canvas = require "src.canvas"

local core = {
  initialized = false,
  redraw = true,
  quit_requested = false,
  threads = {},
  canvas = canvas,
  style = style,
  clip_rect_stack = { { 0, 0, 0, 0 } },
  root_view = nil,
  active_view = nil,
  cursor_change_req = nil,
  last_mouse_x = 0,
  last_mouse_y = 0,
}

--------------------------------------------------------------------------------
-- 1. Asynchronous Coroutine Scheduler
--------------------------------------------------------------------------------

--- Add an asynchronous worker coroutine to the engine scheduler
function core.add_thread(fn)
  local co = coroutine.create(fn)
  table.insert(core.threads, { co = co, wake_time = 0 })
  return co
end

--- Resume active coroutines whose sleep/yield interval has elapsed
function core.step_threads()
  local now = system.get_time()
  for i = #core.threads, 1, -1 do
    local t = core.threads[i]
    if now >= t.wake_time then
      local ok, delay = coroutine.resume(t.co)
      if not ok then
        print("[Lua Lamp] Coroutine error:", delay)
        table.remove(core.threads, i)
      elseif coroutine.status(t.co) == "dead" then
        table.remove(core.threads, i)
      else
        t.wake_time = now + (tonumber(delay) or 0)
      end
    end
  end
end

--------------------------------------------------------------------------------
-- 2. Clip Rect & UI View Helpers (for View & Widget framework)
--------------------------------------------------------------------------------

function core.push_clip_rect(x, y, w, h)
  local x2, y2, w2, h2 = table.unpack(core.clip_rect_stack[#core.clip_rect_stack])
  if #core.clip_rect_stack > 1 then
    local r = math.max(x, x2)
    local b = math.max(y, y2)
    local r2 = math.min(x + w, x2 + w2)
    local b2 = math.min(y + h, y2 + h2)
    x, y, w, h = r, b, math.max(0, r2 - r), math.max(0, b2 - b)
  end
  table.insert(core.clip_rect_stack, { x, y, w, h })
  renderer.set_clip_rect(x, y, w, h)
end

function core.pop_clip_rect()
  table.remove(core.clip_rect_stack)
  local x, y, w, h = table.unpack(core.clip_rect_stack[#core.clip_rect_stack])
  renderer.set_clip_rect(x, y, w, h)
end

function core.request_cursor(cursor)
  core.cursor_change_req = cursor
end

function core.set_active_view(view)
  if core.active_view ~= view then
    core.active_view = view
    core.redraw = true
  end
end

--------------------------------------------------------------------------------
-- 3. Engine Initialization
--------------------------------------------------------------------------------

function core.init()
  if core.initialized then return end
  core.initialized = true

  -- Determine High-DPI Scaling Factor
  SCALE = tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE")) or 1

  -- Configure Initial SDL3 Window Dimensions & Title
  local _, _, cur_x, cur_y = system.get_window_size()
  local default_w = math.floor(960 * SCALE)
  local default_h = math.floor(640 * SCALE)
  system.set_window_size(default_w, default_h, cur_x or 80, cur_y or 80)
  system.set_window_title("Lua Lamp — Hello World")
  if system.raise_window then system.raise_window() end

  -- Initialize Style, Theme & Typography
  style.init_fonts(SCALE)

  -- Initialize Canvas Component
  canvas.init()

  -- Initialize UI View Hierarchy (RootView) with CanvasView as primary view
  local ok, RootView = pcall(require, "core.rootview")
  if ok and RootView then
    core.root_view = RootView()
    local CanvasView = require "src.canvas_view"
    core.canvas_view = CanvasView()
    core.root_view.root_node.views = { core.canvas_view }
    core.root_view.root_node.active_view = core.canvas_view
    core.active_view = core.canvas_view
  end

  core.redraw = true
end

--------------------------------------------------------------------------------
-- 4. System Event Dispatcher
--------------------------------------------------------------------------------

function core.on_event(type, a, b, c, d)
  if type == "quit" then
    core.quit_requested = true
    return
  elseif type == "resized" or type == "exposed" then
    core.redraw = true
    return
  end

  local win_w, win_h = renderer.get_size()

  -- Forward event to RootView UI tree if present
  if core.root_view then
    if type == "mousemoved" then
      local dx = a - (core.last_mouse_x or a)
      local dy = b - (core.last_mouse_y or b)
      core.last_mouse_x, core.last_mouse_y = a, b
      core.root_view:on_mouse_moved(a, b, dx, dy)
      core.redraw = true
    elseif type == "mousepressed" then
      core.root_view:on_mouse_pressed(a, b, c, d or 1)
      core.redraw = true
    elseif type == "mousereleased" then
      core.root_view:on_mouse_released(a, b, c)
      core.redraw = true
    elseif type == "mousewheel" then
      core.root_view:on_mouse_wheel(b, a)
      core.redraw = true
    elseif type == "textinput" then
      core.root_view:on_text_input(a)
      core.redraw = true
    end
  else
    -- Fallback canvas event handlers when running without RootView
    if type == "mousemoved" then
      canvas.on_mouse_moved(a, b)
      core.redraw = true
      return
    elseif type == "mousepressed" then
      canvas.on_mouse_pressed(a, b, c, core)
      core.redraw = true
      return
    end
  end

  -- Keyboard shortcuts
  if type == "keypressed" then
    local key = a:lower()

    if key == "q" or key == "escape" then
      core.quit_requested = true
    elseif key == "space" then
      canvas.toggle_lamp()
      core.redraw = true
    elseif key == "t" then
      style.toggle_theme()
      core.redraw = true
    elseif key == "f11" then
      local cur_mode = system.get_window_mode and system.get_window_mode() or "normal"
      if system.set_window_mode then
        system.set_window_mode(cur_mode == "fullscreen" and "normal" or "fullscreen")
        core.redraw = true
      end
    end
    return
  end
end

--------------------------------------------------------------------------------
-- 5. Frame Rendering Compositor
--------------------------------------------------------------------------------

function core.draw()
  local win_w, win_h = renderer.get_size()
  core.clip_rect_stack[1] = { 0, 0, win_w, win_h }
  renderer.set_clip_rect(0, 0, win_w, win_h)

  -- Render RootView UI layer & widgets (with CanvasView as root node)
  if core.root_view then
    core.root_view.size.x, core.root_view.size.y = win_w, win_h
    core.root_view:update()
    core.root_view:draw()
    if core.cursor_change_req then
      system.set_cursor(core.cursor_change_req)
      core.cursor_change_req = nil
    end
  else
    canvas.draw(win_w, win_h)
  end
end

--------------------------------------------------------------------------------
-- 6. Main 60 FPS Event Loop
--------------------------------------------------------------------------------

function core.run()
  -- Headless Automated Verification Test Interceptor
  local test_script = os.getenv("LUALAMP_TEST_SCRIPT")
  if test_script then
    dofile(test_script)
    return
  end

  local last_time = system.get_time()
  core.redraw = true

  while not core.quit_requested do
    local now = system.get_time()
    local dt = math.min(0.1, math.max(0.001, now - last_time))
    last_time = now

    -- 1. Poll & Dispatch SDL3 System Events
    for type, a, b, c, d in system.poll_event do
      core.on_event(type, a, b, c, d)
    end

    -- 2. Step Background Coroutines
    core.step_threads()

    -- 3. Update Animations & Canvas State
    canvas.update(dt)

    -- Animated lamp glow & ripples require continuous smooth 60 FPS updates
    if canvas.lamp_on or #canvas.click_ripples > 0 then
      core.redraw = true
    end

    -- 4. Render Frame
    if core.redraw then
      core.redraw = false
      renderer.begin_frame()
      core.draw()
      renderer.end_frame()
    end

    -- 5. Frame Rate Throttling & Power-Saving Sleep
    local elapsed = system.get_time() - now
    local frame_budget = 1.0 / 60.0
    local sleep_time = math.max(0.001, frame_budget - elapsed)
    system.wait_event(sleep_time)
  end

  os.exit(0)
end

--------------------------------------------------------------------------------
-- 7. Graceful Error Handling
--------------------------------------------------------------------------------

function core.on_error(err)
  local err_msg = tostring(err)
  local trace = debug.traceback(nil, 2) or ""
  io.stderr:write("[Lua Lamp Error]: " .. err_msg .. "\n" .. trace .. "\n")

  -- Record to persistent error log
  local home = os.getenv("HOME") or ""
  local log_dir = (PLATFORM == "Mac OS X")
    and (home .. "/Library/Application Support/Lua Lamp")
    or (home .. "/.config/lualamp")

  pcall(function()
    os.execute("mkdir -p " .. string.format("%q", log_dir))
    local fp = io.open(log_dir .. "/error.log", "a")
    if fp then
      fp:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. err_msg .. "\n" .. trace .. "\n\n")
      fp:close()
    end
  end)

  if system and system.show_fatal_error then
    system.show_fatal_error("Lua Lamp Fatal Error",
      "An unexpected error occurred in Lua Lamp:\n\n" .. err_msg ..
      "\n\nA diagnostic log has been written to:\n" .. log_dir .. "/error.log")
  end
  os.exit(1)
end

return core

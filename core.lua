-- Lua Lamp Main Engine Core & SDL3 Application Lifecycle
-- High-performance, lightweight template for Lua + SDL3 desktop applications.

local style = require "src.style"
local canvas = require "src.canvas"

local core = {
  initialized = false,
  redraw = true,
  quit_requested = false,
  threads = {},
  canvas = canvas,
  style = style,
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
-- 2. Engine Initialization
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

  core.redraw = true
end

--------------------------------------------------------------------------------
-- 3. System Event Dispatcher
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

  -- Mouse movement
  if type == "mousemoved" then
    local px, py = a, b
    canvas.on_mouse_moved(px, py)
    core.redraw = true
    return
  end

  -- Mouse button pressed
  if type == "mousepressed" then
    local button, px, py = a, b, c
    canvas.on_mouse_pressed(button, px, py, core)
    core.redraw = true
    return
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
-- 4. Frame Rendering Compositor
--------------------------------------------------------------------------------

function core.draw()
  local win_w, win_h = renderer.get_size()
  canvas.draw(win_w, win_h)
end

--------------------------------------------------------------------------------
-- 5. Main 60 FPS Event Loop
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
-- 6. Graceful Error Handling
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

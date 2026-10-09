-- Lua Lamp Main Engine Core & SDL3 Application Lifecycle
-- High-performance, lightweight generic application development platform based on SDL3.

local style = require "src.style"
local canvas = require "src.canvas"
local menu = require "src.menu"
local settings = require "src.settings_dialog"

local core = {
  initialized = false,
  redraw = true,
  quit_requested = false,
  threads = {},
  canvas = canvas,
  style = style,
  menu = menu,
  settings = settings,
  mod_ctrl = false,
  mod_cmd = false,
  mod_shift = false,
  mod_alt = false,
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
-- 3. High-DPI Display Scaling & Rescaling Engine
--------------------------------------------------------------------------------

--- Automatically detect display scale factor from system, SDL3, or environment
function core.get_default_scale()
  -- 1. Explicit user override from environment variables takes precedence
  local env_scale = tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE") or os.getenv("GDK_SCALE") or os.getenv("QT_SCALE_FACTOR"))
  if env_scale and env_scale > 0 then
    return env_scale
  end

  -- 2. Query native SDL3 window/display scale API
  if system.get_window_scale then
    local s = system.get_window_scale()
    if s and s > 0 then
      return s
    end
  end

  -- 3. Query native display scale API if available
  if system.get_display_scale then
    local ds = system.get_display_scale()
    if ds and ds > 0 then
      return ds
    end
  end

  -- 4. Check macOS backing scale factor global if defined
  if rawget(_G, "MACOS_SCALE") and MACOS_SCALE > 0 then
    return MACOS_SCALE
  end

  -- 5. Calculate ratio of framebuffer pixel size to logical window points
  if renderer and renderer.get_size and system.get_window_size then
    local rw, rh = renderer.get_size()
    local ww, wh = system.get_window_size()
    if ww > 0 and rw > 0 then
      local ratio = rw / ww
      if ratio > 0.5 then
        return ratio
      end
    end
  end

  -- 6. Fallback standard 1x scale
  return 1
end

--- Dynamically rescale UI typography, widgets, and layout when display DPI changes
function core.rescale(new_scale)
  new_scale = tonumber(new_scale) or core.get_default_scale()
  if not new_scale or new_scale <= 0 then return end
  if new_scale == SCALE and core.rescaled then return end

  SCALE = new_scale
  core.rescaled = true

  -- Reinitialize fonts and style metrics for the new scale factor
  style.init_fonts(SCALE)

  -- Synchronize Lite XL runtime style if present
  local ok, rt_style = pcall(require, "core.style")
  if ok and rt_style then
    rt_style.scale = SCALE
  end

  -- Resize UI view hierarchy
  if core.root_view then
    local rw, rh = renderer.get_size()
    core.root_view.size.x = rw
    core.root_view.size.y = rh
    if core.root_view.update then
      core.root_view:update()
    end
  end

  local scale_label = (SCALE == math.floor(SCALE)) and string.format("%dx", math.floor(SCALE)) or string.format("%.1fx", SCALE)
  if system.set_window_title then
    system.set_window_title(string.format("Lua Lamp — Hello World (%s Scale)", scale_label))
  end

  core.redraw = true
end

--------------------------------------------------------------------------------
-- 4. Engine Initialization
--------------------------------------------------------------------------------

function core.init()
  if core.initialized then return end
  core.initialized = true

  -- Determine High-DPI Scaling Factor automatically from system/display
  SCALE = core.get_default_scale()

  -- Configure Initial SDL3 Window Dimensions & Title
  local _, _, cur_x, cur_y = system.get_window_size()
  local default_w = 960
  local default_h = 640
  system.set_window_size(default_w, default_h, cur_x or 80, cur_y or 80)
  local scale_label = (SCALE == math.floor(SCALE)) and string.format("%dx", math.floor(SCALE)) or string.format("%.1fx", SCALE)
  system.set_window_title(string.format("Lua Lamp — Hello World (%s Scale)", scale_label))
  if system.raise_window then system.raise_window() end

  -- Initialize Style, Theme & Typography with detected scale
  style.init_fonts(SCALE)

  -- Initialize Canvas Component
  canvas.init()

  -- Initialize Unified Menu System (Native NSMenu on macOS, In-Window bar on Linux)
  menu.init_defaults()

  -- Auto-register native macOS permissions tab in Settings dialog
  if PLATFORM == "Mac OS X" then
    pcall(function()
      local permissions = require "src.permissions"
      if permissions and permissions.register_settings_tab then
        permissions.register_settings_tab()
      end
    end)
  end

  -- Check for external downstream application project
  local app_dir = os.getenv("LUALAMP_APP_DIR")
  if not app_dir and rawget(_G, "MACOS_RESOURCES") and system.get_file_info(MACOS_RESOURCES .. "/app") then
    app_dir = MACOS_RESOURCES .. "/app"
  elseif not app_dir and rawget(_G, "DATADIR") and system.get_file_info(DATADIR .. "/app") then
    app_dir = DATADIR .. "/app"
  end

  local custom_app_view = nil
  if app_dir then
    package.path = app_dir .. "/?.lua;" .. app_dir .. "/?/init.lua;" .. package.path

    -- Read app.json if present
    local app_json_file = app_dir .. "/app.json"
    local entry_file = nil
    local manifest = nil
    if system.get_file_info(app_json_file) then
      local f = io.open(app_json_file, "r")
      if f then
        local content = f:read("*a")
        f:close()
        -- Fallback parser for app.json fields
        manifest = {}
        manifest.name = content:match('"name"%s*:%s*"([^"]+)"')
        manifest.displayName = content:match('"displayName"%s*:%s*"([^"]+)"')
        manifest.entry = content:match('"entry"%s*:%s*"([^"]+)"')
        local ww = content:match('"width"%s*:%s*(%d+)')
        local wh = content:match('"height"%s*:%s*(%d+)')
        if ww and wh then
          manifest.window = { width = tonumber(ww), height = tonumber(wh) }
        end
        local perms_str = content:match('"permissions"%s*:%s*%[([^%]]*)%]')
        if perms_str then
          manifest.permissions = {}
          for p in perms_str:gmatch('"([^"]+)"') do
            table.insert(manifest.permissions, p)
          end
        end

        core.manifest = manifest

        if manifest then
          if manifest.displayName or manifest.name then
            system.set_window_title(manifest.displayName or manifest.name)
          end
          if manifest.window and manifest.window.width and manifest.window.height then
            local _, _, cur_x, cur_y = system.get_window_size()
            system.set_window_size(manifest.window.width, manifest.window.height, cur_x or 80, cur_y or 80)
          end
          if manifest.entry then
            entry_file = app_dir .. "/" .. manifest.entry
          end
          if manifest.permissions and #manifest.permissions > 0 and PLATFORM == "Mac OS X" then
            pcall(function()
              local permissions = require "src.permissions"
              for _, perm_type in ipairs(manifest.permissions) do
                permissions.request(perm_type, { auto_request = true })
              end
            end)
          end
        end
      end
    end

    if not entry_file or not system.get_file_info(entry_file) then
      if system.get_file_info(app_dir .. "/main.lua") then
        entry_file = app_dir .. "/main.lua"
      elseif system.get_file_info(app_dir .. "/app.lua") then
        entry_file = app_dir .. "/app.lua"
      elseif system.get_file_info(app_dir .. "/init.lua") then
        entry_file = app_dir .. "/init.lua"
      end
    end

    if entry_file and system.get_file_info(entry_file) then
      local ok, res = pcall(dofile, entry_file)
      if ok and res and type(res) == "table" and res.draw then
        custom_app_view = res
      elseif not ok then
        io.stderr:write("[Lua Lamp] Failed to load application entry (" .. entry_file .. "): " .. tostring(res) .. "\n")
      end
    end
  end

  -- Initialize UI View Hierarchy (RootView) with custom app view or default CanvasView
  local ok, RootView = pcall(require, "core.rootview")
  if ok and RootView then
    core.root_view = RootView()
    local primary_view = custom_app_view
    if not primary_view then
      local CanvasView = require "src.canvas_view"
      core.canvas_view = CanvasView()
      primary_view = core.canvas_view
    end
    core.root_view.root_node.show_tabs = false
    core.root_view.root_node.views = { primary_view }
    core.root_view.root_node.active_view = primary_view
    core.active_view = primary_view
  end

  core.redraw = true
end

--------------------------------------------------------------------------------
-- 5. System Event Dispatcher
--------------------------------------------------------------------------------

function core.on_event(type, a, b, c, d)
  if type == "quit" then
    core.quit_requested = true
    return
  elseif type == "resized" or type == "exposed" then
    core.redraw = true
    return
  elseif type == "scalechanged" then
    core.rescale(a)
    return
  elseif type == "menu" then
    menu:trigger(a)
    core.redraw = true
    return
  end

  -- Track keyboard modifier keys
  if type == "keypressed" then
    local kl = a:lower()
    if kl == "left ctrl" or kl == "right ctrl" or kl == "ctrl" then core.mod_ctrl = true end
    if kl == "left cmd" or kl == "right cmd" or kl == "cmd" or kl == "left gui" or kl == "right gui" or kl == "gui" then core.mod_cmd = true end
    if kl == "left shift" or kl == "right shift" or kl == "shift" then core.mod_shift = true end
    if kl == "left alt" or kl == "right alt" or kl == "alt" then core.mod_alt = true end
  elseif type == "keyreleased" then
    local kl = a:lower()
    if kl == "left ctrl" or kl == "right ctrl" or kl == "ctrl" then core.mod_ctrl = false end
    if kl == "left cmd" or kl == "right cmd" or kl == "cmd" or kl == "left gui" or kl == "right gui" or kl == "gui" then core.mod_cmd = false end
    if kl == "left shift" or kl == "right shift" or kl == "shift" then core.mod_shift = false end
    if kl == "left alt" or kl == "right alt" or kl == "alt" then core.mod_alt = false end
  end

  -- 1. Intercept events when Modal Settings Dialog is active
  if settings.visible then
    if type == "mousemoved" then
      if settings:on_mouse_moved(a, b) then
        core.redraw = true
        return
      end
    elseif type == "mousepressed" then
      if settings:on_mouse_pressed(a, b, c) then
        core.redraw = true
        return
      end
    elseif type == "mousereleased" then
      if settings:on_mouse_released(a, b, c) then
        core.redraw = true
        return
      end
    elseif type == "mousewheel" then
      if settings:on_mouse_wheel(a, b) then
        core.redraw = true
        return
      end
    elseif type == "keypressed" then
      local key = a:lower()
      if key == "escape" then
        settings:hide()
        core.redraw = true
        return
      elseif (key == "," or key == "<") and (core.mod_cmd or core.mod_ctrl) then
        settings:toggle()
        core.redraw = true
        return
      end
      return
    end
    return
  end

  -- 2. Intercept events for In-Window Menu Bar on Linux/Windows
  if PLATFORM ~= "Mac OS X" then
    if type == "mousemoved" then
      if menu:on_mouse_moved(a, b) then
        core.redraw = true
        return
      end
    elseif type == "mousepressed" then
      if menu:on_mouse_pressed(a, b, c) then
        core.redraw = true
        return
      end
    end
  end

  -- 3. Forward event to RootView UI tree if present
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
      core.root_view:on_mouse_wheel(a, b)
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

  -- 4. Keyboard shortcuts
  if type == "keypressed" then
    local key = a:lower()

    -- Settings dialog toggle (Cmd+, on macOS, Ctrl+, on Linux/Win)
    if (key == "," or key == "<") and (core.mod_cmd or core.mod_ctrl) then
      menu:trigger("app:open-settings")
      return
    end

    if key == "escape" then
      if menu:is_open() then
        menu:close()
        core.redraw = true
        return
      end
      core.quit_requested = true
      return
    elseif key == "q" then
      if core.mod_cmd or core.mod_ctrl or not core.root_view then
        core.quit_requested = true
        return
      end
    elseif key == "space" then
      canvas.toggle_lamp()
      core.redraw = true
      return
    elseif key == "t" then
      style.toggle_theme()
      core.redraw = true
      return
    elseif key == "f11" then
      local cur_mode = system.get_window_mode and system.get_window_mode() or "normal"
      if system.set_window_mode then
        system.set_window_mode(cur_mode == "fullscreen" and "normal" or "fullscreen")
        core.redraw = true
      end
      return
    end
  end
end

--------------------------------------------------------------------------------
-- 6. Frame Rendering Compositor
--------------------------------------------------------------------------------

function core.draw()
  local win_w, win_h = renderer.get_size()
  core.clip_rect_stack[1] = { 0, 0, win_w, win_h }
  renderer.set_clip_rect(0, 0, win_w, win_h)

  -- 1. Render RootView UI layer & widgets (with CanvasView as root node)
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

  -- 2. Draw In-Window Menu Bar on Linux/Windows
  if PLATFORM ~= "Mac OS X" then
    menu:draw(win_w, win_h)
  end

  -- 3. Draw Floating Modal Settings Window on top of canvas/widgets
  if settings.visible then
    settings:draw(win_w, win_h)
  end
end

--------------------------------------------------------------------------------
-- 7. Main 60 FPS Event Loop
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
-- 8. Graceful Error Handling
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

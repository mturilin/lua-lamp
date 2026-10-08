local scale = system.get_window_scale and system.get_window_scale() or "nil"
print("system.get_window_scale() ->", scale)
local disp_scale = system.get_display_scale and system.get_display_scale() or "nil"
print("system.get_display_scale() ->", disp_scale)
local w, h = system.get_window_size()
print("system.get_window_size() ->", w, h)
print("MACOS_SCALE ->", tostring(MACOS_SCALE))
os.exit(0)

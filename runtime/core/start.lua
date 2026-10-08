-- Lua Lamp runtime environment setup
VERSION = "1.0.0"
MOD_VERSION = "1"

SCALE = tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE") or os.getenv("GDK_SCALE") or os.getenv("QT_SCALE_FACTOR"))
     or (system.get_window_scale and system.get_window_scale())
     or (system.get_display_scale and system.get_display_scale())
     or (MACOS_SCALE and MACOS_SCALE > 0 and MACOS_SCALE)
     or 1
PATHSEP = package.config:sub(1, 1)

EXEDIR = EXEFILE:match("^(.+)[/\\][^/\\]+$")
if MACOS_RESOURCES then
  DATADIR = MACOS_RESOURCES
else
  local prefix = EXEDIR:match("^(.+)[/\\]bin$")
  DATADIR = (prefix and system.get_file_info(prefix .. PATHSEP .. 'share' .. PATHSEP .. 'lualamp') and (prefix .. PATHSEP .. 'share' .. PATHSEP .. 'lualamp'))
         or (system.get_file_info(EXEDIR .. PATHSEP .. 'runtime') and (EXEDIR .. PATHSEP .. 'runtime'))
         or (system.get_file_info(EXEDIR .. PATHSEP .. '..' .. PATHSEP .. 'runtime') and (EXEDIR .. PATHSEP .. '..' .. PATHSEP .. 'runtime'))
         or (EXEDIR .. PATHSEP .. 'data')
end
USERDIR = os.getenv("LUALAMP_USERDIR")
       or os.getenv("LITE_USERDIR")
       or (MACOS_RESOURCES and MACOS_RESOURCES)
       or (prefix and prefix)
       or (system.get_file_info(EXEDIR .. PATHSEP .. 'user') and (EXEDIR .. PATHSEP .. 'user'))
       or (HOME and (HOME .. PATHSEP .. 'Library' .. PATHSEP .. 'Application Support' .. PATHSEP .. 'Lua Lamp' .. PATHSEP .. 'user'))
       or ((os.getenv("XDG_CONFIG_HOME") and os.getenv("XDG_CONFIG_HOME") .. PATHSEP .. "lualamp"))
       or (HOME and (HOME .. PATHSEP .. '.config' .. PATHSEP .. 'lualamp'))

package.path = DATADIR .. '/?.lua;'
package.path = DATADIR .. '/?/init.lua;' .. package.path
package.path = DATADIR .. '/libraries/?.lua;' .. package.path
package.path = DATADIR .. '/libraries/?/init.lua;' .. package.path
package.path = USERDIR .. '/?.lua;' .. package.path
package.path = USERDIR .. '/?/init.lua;' .. package.path

local suffix = PLATFORM == "Mac OS X" and 'lib' or (PLATFORM == "Windows" and 'dll' or 'so')
package.cpath =
  USERDIR .. '/?.' .. ARCH .. "." .. suffix .. ";" ..
  USERDIR .. '/?/init.' .. ARCH .. "." .. suffix .. ";" ..
  USERDIR .. '/?.' .. suffix .. ";" ..
  USERDIR .. '/?/init.' .. suffix .. ";" ..
  DATADIR .. '/?.' .. ARCH .. "." .. suffix .. ";" ..
  DATADIR .. '/?/init.' .. ARCH .. "." .. suffix .. ";" ..
  DATADIR .. '/?.' .. suffix .. ";" ..
  DATADIR .. '/?/init.' .. suffix .. ";"

package.native_plugins = {}
package.searchers = { package.searchers[1], package.searchers[2], function(modname)
  local path, err = package.searchpath(modname, package.cpath)
  if not path then return err end
  return system.load_native_plugin, path
end }

table.pack = table.pack or pack or function(...) return {...} end
table.unpack = table.unpack or unpack

bit32 = bit32 or require "core.bit"

require "core.utf8string"
require "core.process"

-- Because AppImages change the working directory before running the executable,
-- we need to change it back to the original one.
-- https://github.com/AppImage/AppImageKit/issues/172
-- https://github.com/AppImage/AppImageKit/pull/191
local appimage_owd = os.getenv("OWD")
if os.getenv("APPIMAGE") and appimage_owd then
  system.chdir(appimage_owd)
end

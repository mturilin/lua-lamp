-- Lua Lamp Styling, Typography & Theme Manager
-- Provides dark/light themes, DPI scaling, and font caching.

local style = {
  current_theme = "dark",
  scale = 1,
}

--------------------------------------------------------------------------------
-- 1. Color Palette Definitions
--------------------------------------------------------------------------------

local themes = {
  dark = {
    background        = { 13, 17, 23, 255 },       -- #0d1117 (Deep Slate Canvas)
    surface           = { 22, 27, 34, 255 },       -- #161b22 (Card / Panel Surface)
    surface_hover     = { 33, 38, 45, 255 },       -- #21262d
    surface_active    = { 48, 54, 61, 255 },       -- #30363d
    border            = { 48, 54, 61, 255 },       -- #30363d
    border_accent     = { 245, 166, 35, 180 },     -- Warm Amber Border
    text_primary      = { 240, 246, 252, 255 },    -- High contrast crisp white
    text_secondary    = { 139, 148, 158, 255 },    -- Muted steel
    text_tertiary     = { 110, 118, 129, 255 },    -- Subtle hint
    lamp_gold         = { 255, 196, 37, 255 },     -- Hot golden filament
    lamp_amber        = { 245, 140, 20, 255 },     -- Warm amber glow
    lamp_glow_inner   = { 255, 230, 110, 70 },     -- Core bloom
    lamp_glow_outer   = { 245, 150, 20, 25 },      -- Outer ambient aura
    lua_blue          = { 0, 85, 212, 255 },       -- Lua deep blue
    lua_blue_light    = { 64, 153, 255, 255 },     -- Lua cyan/blue highlight
    accent_green      = { 46, 196, 182, 255 },     -- Emerald status
    accent_red        = { 230, 57, 70, 255 },      -- Alert red
    pill_bg           = { 26, 35, 52, 255 },       -- Lua tinted badge
    pill_text         = { 140, 190, 255, 255 },
  },
  light = {
    background        = { 246, 248, 250, 255 },    -- Crisp clean canvas
    surface           = { 255, 255, 255, 255 },    -- Card surface
    surface_hover     = { 243, 244, 246, 255 },
    surface_active    = { 235, 238, 242, 255 },
    border            = { 208, 215, 222, 255 },
    border_accent     = { 217, 130, 0, 200 },
    text_primary      = { 31, 35, 40, 255 },
    text_secondary    = { 87, 96, 106, 255 },
    text_tertiary     = { 140, 149, 159, 255 },
    lamp_gold         = { 217, 130, 0, 255 },
    lamp_amber        = { 190, 95, 0, 255 },
    lamp_glow_inner   = { 255, 210, 80, 80 },
    lamp_glow_outer   = { 245, 160, 40, 25 },
    lua_blue          = { 0, 70, 180, 255 },
    lua_blue_light    = { 0, 110, 230, 255 },
    accent_green      = { 26, 127, 55, 255 },
    accent_red        = { 207, 34, 46, 255 },
    pill_bg           = { 234, 242, 255, 255 },
    pill_text         = { 0, 80, 190, 255 },
  }
}

-- Expose current theme colors
style.colors = themes.dark

function style.set_theme(name)
  if themes[name] then
    style.current_theme = name
    style.colors = themes[name]
  end
end

function style.toggle_theme()
  local next_theme = (style.current_theme == "dark") and "light" or "dark"
  style.set_theme(next_theme)
  return style.current_theme
end

--------------------------------------------------------------------------------
-- 2. Typography & Font Loader
--------------------------------------------------------------------------------

local function find_font_file(filename)
  local datadir = DATADIR or "."
  local userdir = USERDIR or "."
  local candidates = {
    userdir .. "/fonts/" .. filename,
    datadir .. "/fonts/" .. filename,
    "fonts/" .. filename,
    "../fonts/" .. filename,
  }
  for _, path in ipairs(candidates) do
    local f = io.open(path, "rb")
    if f then
      f:close()
      return path
    end
  end
  return nil
end

local function safe_load_font(filename, pt_size)
  local path = find_font_file(filename)
  local scaled_size = math.max(8, math.floor(pt_size * style.scale))
  if path and renderer and renderer.font and renderer.font.load then
    local ok, font = pcall(renderer.font.load, path, scaled_size)
    if ok and font then return font end
  end
  -- Fallback font if specific file cannot be loaded
  if renderer and renderer.font and renderer.font.load then
    local ok, font = pcall(renderer.font.load, scaled_size)
    if ok and font then return font end
  end
  -- Mock font object for headless tests or missing renderer
  return {
    get_width = function(self, text) return #tostring(text) * 8 * style.scale end,
    get_height = function(self) return scaled_size end,
  }
end

local function safe_load_icon_font(pt_size)
  local scaled_size = math.max(8, math.floor(pt_size * style.scale))
  local outline_path = find_font_file("tabler-icons.ttf")
  local filled_path = find_font_file("tabler-icons-filled.ttf")

  if outline_path and renderer and renderer.font and renderer.font.load then
    local ok_o, outline = pcall(renderer.font.load, outline_path, scaled_size)
    if ok_o and outline then
      if filled_path and renderer.font.group then
        local ok_f, filled = pcall(renderer.font.load, filled_path, scaled_size)
        if ok_f and filled then
          local ok_g, grouped = pcall(renderer.font.group, { outline, filled })
          if ok_g and grouped then
            return grouped
          end
        end
      end
      return outline
    end
  end

  return safe_load_font("tabler-icons.ttf", pt_size)
end

function style.init_fonts(scale)
  style.scale = scale or rawget(_G, "SCALE") or tonumber(os.getenv("LUALAMP_SCALE") or os.getenv("LITE_SCALE")) or 1

  -- Primary UI fonts
  style.font_hero       = safe_load_font("PublicSans-Bold.ttf", 38)
  style.font_title      = safe_load_font("PublicSans-Bold.ttf", 26)
  style.font_heading    = safe_load_font("PublicSans-SemiBold.ttf", 18)
  style.font_large      = safe_load_font("PublicSans-Medium.ttf", 16)
  style.font_normal     = safe_load_font("PublicSans-Regular.ttf", 14)
  style.font_small      = safe_load_font("PublicSans-Regular.ttf", 12)
  style.font_mono       = safe_load_font("SourceSans3-Regular.ttf", 13)

  -- Tabler Icons font (grouped outline + filled)
  style.font_icon       = safe_load_icon_font(18)
  style.font_icon_large = safe_load_icon_font(24)
end

return style

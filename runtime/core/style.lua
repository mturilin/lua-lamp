local common = require "core.common"
local style = {}

style.padding = { x = common.round(14 * SCALE), y = common.round(7 * SCALE) }
style.divider_size = common.round(1 * SCALE)
style.scrollbar_size = common.round(4 * SCALE)
style.expanded_scrollbar_size = common.round(12 * SCALE)
style.caret_width = common.round(2 * SCALE)
style.tab_width = common.round(170 * SCALE)

local function resolve_font_path(filename, fallbacks)
  local candidate_dirs = {
    DATADIR .. "/fonts",
    DATADIR .. "/../fonts",
    USERDIR .. "/fonts",
    (rawget(_G, "MACOS_RESOURCES") and (rawget(_G, "MACOS_RESOURCES") .. "/fonts")),
    "fonts"
  }
  for _, dir in ipairs(candidate_dirs) do
    if dir and system.get_file_info(dir .. "/" .. filename) then
      return dir .. "/" .. filename
    end
  end
  if fallbacks then
    for _, fb in ipairs(fallbacks) do
      for _, dir in ipairs(candidate_dirs) do
        if dir and system.get_file_info(dir .. "/" .. fb) then
          return dir .. "/" .. fb
        end
      end
    end
  end
  return DATADIR .. "/fonts/" .. filename
end

local font_path = resolve_font_path("PublicSans-Regular.ttf", { "FiraSans-Regular.ttf", "SourceSans3-Regular.ttf" })
local icon_path = resolve_font_path("tabler-icons.ttf", { "icons.ttf", "tabler-icons-filled.ttf" })
local code_path = resolve_font_path("SourceSans3-Regular.ttf", { "JetBrainsMono-Regular.ttf", "PublicSans-Regular.ttf" })

style.font = renderer.font.load(font_path, 15 * SCALE)
style.big_font = style.font:copy(46 * SCALE)
style.icon_font = renderer.font.load(icon_path, 16 * SCALE, {antialiasing="grayscale", hinting="full"})
style.icon_big_font = style.icon_font:copy(23 * SCALE)
style.code_font = renderer.font.load(code_path, 15 * SCALE)

-- Default UI Palette (Modern Dark Mode)
style.background = { common.color "#1e1e24" }
style.background2 = { common.color "#26262e" }
style.background3 = { common.color "#2d2d38" }
style.text = { common.color "#e2e8f0" }
style.caret = { common.color "#38bdf8" }
style.accent = { common.color "#f59e0b" }
style.dim = { common.color "#64748b" }
style.divider = { common.color "#334155" }
style.selection = { common.color "rgba(56, 189, 248, 0.25)" }
style.line_number = { common.color "#475569" }
style.line_number2 = { common.color "#94a3b8" }
style.line_highlight = { common.color "rgba(255, 255, 255, 0.05)" }
style.scrollbar = { common.color "rgba(255, 255, 255, 0.2)" }
style.scrollbar2 = { common.color "rgba(255, 255, 255, 0.35)" }
style.scrollbar_track = { common.color "rgba(0, 0, 0, 0.1)" }
style.nagbar = { common.color "#ef4444" }
style.nagbar_text = { common.color "#ffffff" }
style.nagbar_dim = { common.color "rgba(0, 0, 0, 0.5)" }
style.drag_overlay = { common.color "rgba(255, 255, 255, 0.1)" }
style.drag_overlay_tab = { common.color "#38bdf8" }
style.good = { common.color "#22c55e" }
style.warn = { common.color "#f59e0b" }
style.error = { common.color "#ef4444" }
style.modified = { common.color "#38bdf8" }

-- Pinglet Button Highlight Standard Tokens
style.track_bg = { common.color "#0f141c" }
style.track_border = { common.color "rgba(30, 41, 59, 0.6)" }
style.btn_accent_bg = { common.color "#38bdf8" }
style.btn_accent_text = { common.color "#0c1018" }
style.btn_tint_bg = { common.color "rgba(56, 189, 248, 0.18)" }
style.btn_tint_text = { common.color "#38bdf8" }
style.btn_tint_hover = { common.color "rgba(56, 189, 248, 0.32)" }
style.btn_gold_bg = { common.color "#ffc425" }
style.btn_gold_text = { common.color "#111418" }
style.btn_gold_tint_bg = { common.color "rgba(255, 196, 37, 0.18)" }
style.btn_gold_tint_text = { common.color "#ffc425" }
style.btn_gold_tint_hover = { common.color "rgba(255, 196, 37, 0.32)" }
style.btn_surface_bg = { common.color "#21262d" }
style.btn_surface_hover = { common.color "rgba(255, 255, 255, 0.09)" }
style.btn_surface_text = { common.color "#f0f6fc" }
style.btn_surface_muted = { common.color "#8b949e" }

style.syntax = {
  ["normal"] = style.text,
  ["symbol"] = style.text,
  ["comment"] = { common.color "#64748b" },
  ["keyword"] = { common.color "#c084fc" },
  ["keyword2"] = { common.color "#f472b6" },
  ["number"] = { common.color "#fb923c" },
  ["literal"] = { common.color "#fb923c" },
  ["string"] = { common.color "#fde047" },
  ["operator"] = { common.color "#38bdf8" },
  ["function"] = { common.color "#60a5fa" },
}
style.syntax_fonts = {}
style.log = {
  ["INFO"]  = { icon = "i", color = style.text },
  ["WARN"]  = { icon = "!", color = style.warn },
  ["ERROR"] = { icon = "!", color = style.error },
}

return style

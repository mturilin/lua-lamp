-- Lua Lamp — Tabler Icons Registry
-- Maps semantic icon names to UTF-8 encoded code points from Tabler Icons (MIT).
-- Bundled via fonts/tabler-icons.ttf (outline) and fonts/tabler-icons-filled.ttf (filled).

local icons = {
  -- Lighting & Energy
  bulb            = "\xee\xa9\x91", -- U+EA51 bulb (outline)
  bulb_off        = "\xee\xa9\x90", -- U+EA50 bulb-off (outline)
  bulb_filled     = "\xef\x99\xaa", -- U+F66A bulb (filled)
  lamp            = "\xee\xbe\xab", -- U+EFAB lamp (outline)
  lamp_off        = "\xef\x85\x8d", -- U+F14D lamp-off (outline)
  sun             = "\xee\xac\xb0", -- U+EB30 sun (outline)
  sun_filled      = "\xef\x9a\xa9", -- U+F6A9 sun (filled)
  moon            = "\xee\xab\xb8", -- U+EAF8 moon (outline)
  moon_filled     = "\xef\x9a\x84", -- U+F684 moon (filled)
  sparkles        = "\xef\x9b\x97", -- U+F6D7 sparkles (outline)
  flame           = "\xee\xb0\xac", -- U+EC2C flame (outline)

  -- UI & System Controls
  power           = "\xee\xac\x8d", -- U+EB0D power
  refresh         = "\xee\xac\x93", -- U+EB13 refresh
  settings        = "\xee\xac\xa0", -- U+EB20 settings
  check           = "\xee\xa9\x9e", -- U+EA5E check
  x               = "\xee\xad\x95", -- U+EB55 x
  star            = "\xee\xac\xae", -- U+EB2E star
  heart           = "\xee\xaa\xbe", -- U+EABE heart
  github          = "\xee\xb0\x9c", -- U+EC1C brand-github

  -- Status Badges & Alerts
  alert_triangle        = "\xee\xa8\x86", -- U+EA06 alert-triangle (outline)
  alert_triangle_filled = "\xef\x9b\xb0", -- U+F6F0 alert-triangle (filled)
  alert_circle          = "\xee\xa8\x85", -- U+EA05 alert-circle (outline)
  alert_circle_filled   = "\xef\x9b\xae", -- U+F6EE alert-circle (filled)
  circle_check          = "\xee\xa9\xa7", -- U+EA67 circle-check (outline)
  circle_check_filled   = "\xef\x9c\x84", -- U+F704 circle-check (filled)
  circle_x              = "\xee\xa9\xaa", -- U+EA6A circle-x (outline)
  circle_x_filled       = "\xef\x9c\xb9", -- U+F739 circle-x (filled)
}

return icons

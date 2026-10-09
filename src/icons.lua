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
  device_desktop  = "\xee\xa9\xb4", -- U+EA74 device-desktop
  typography      = "\xee\xad\x83", -- U+EB43 typography
  palette         = "\xee\xab\xbe", -- U+EAFE palette
  adjustments     = "\xee\xa8\x82", -- U+EA02 adjustments

  -- Status Badges & Alerts
  alert_triangle        = "\xee\xa8\x86", -- U+EA06 alert-triangle (outline)
  alert_triangle_filled = "\xef\x9b\xb0", -- U+F6F0 alert-triangle (filled)
  alert_circle          = "\xee\xa8\x85", -- U+EA05 alert-circle (outline)
  alert_circle_filled   = "\xef\x9b\xae", -- U+F6EE alert-circle (filled)
  circle_check          = "\xee\xa9\xa7", -- U+EA67 circle-check (outline)
  circle_check_filled   = "\xef\x9c\x84", -- U+F704 circle-check (filled)
  circle_x              = "\xee\xa9\xaa", -- U+EA6A circle-x (outline)
  circle_x_filled       = "\xef\x9c\xb9", -- U+F739 circle-x (filled)

  -- Security, Privacy & System Permissions
  shield                = "\xee\xac\x9b", -- U+EB1B shield (outline)
  shield_check          = "\xee\xac\x99", -- U+EB19 shield-check (outline)
  shield_x              = "\xee\xac\x9e", -- U+EB1E shield-x (outline)
  shield_lock           = "\xee\xac\x9a", -- U+EB1A shield-lock (outline)
  lock                  = "\xee\xab\xa5", -- U+EAE5 lock
  lock_open             = "\xee\xab\xa4", -- U+EAE4 lock-open
  wifi                  = "\xee\xad\x92", -- U+EB52 wifi
  router                = "\xee\xac\x98", -- U+EB18 router
  network               = "\xee\xac\x98", -- U+EB18 router / local network alias
  bell                  = "\xee\xa8\xb5", -- U+EA35 bell (Notifications)
  folder                = "\xee\xaa\xb7", -- U+EAB7 folder (Full Disk Access)
  camera                = "\xee\xa9\x97", -- U+EA57 camera
  microphone            = "\xee\xab\xb2", -- U+EAF2 microphone
  external_link         = "\xee\xaa\xa8", -- U+EAA8 external-link
  info_circle           = "\xee\xab\x88", -- U+EAC8 info-circle
}

return icons

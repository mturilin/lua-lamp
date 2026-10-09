-- Lua Lamp — Tabler Icons Registry
-- Maps semantic icon names to UTF-8 encoded code points from fonts/tabler-icons.ttf (MIT).
-- Verified against native FreeType cmap and glyph names.

local icons = {
  -- Lighting & Energy
  bulb                  = "\xee\xa9\x91", -- U+EA51 bulb
  bulb_filled           = "\xef\x99\xaa", -- U+F66A bulb (filled)
  lamp                  = "\xee\xbe\xab", -- U+EFAB lamp
  sun                   = "\xee\xac\xb0", -- U+EB30 sun
  moon                  = "\xee\xab\xb8", -- U+EAF8 moon
  sparkles              = "\xef\x9b\x97", -- U+F6D7 sparkles
  flame                 = "\xee\xb0\xac", -- U+EC2C flame

  -- UI & System Controls
  power                 = "\xee\xac\x8d", -- U+EB0D power
  refresh               = "\xee\xac\x93", -- U+EB13 refresh
  settings              = "\xee\xac\xa0", -- U+EB20 settings
  check                 = "\xee\xa9\x9e", -- U+EA5E check
  x                     = "\xee\xad\x95", -- U+EB55 x
  star                  = "\xee\xac\xae", -- U+EB2E star
  heart                 = "\xee\xaa\xbe", -- U+EABE heart
  device_desktop        = "\xee\xaa\x89", -- U+EA89 device-desktop
  typography            = "\xee\xaf\x85", -- U+EBC5 typography
  palette               = "\xee\xac\x81", -- U+EB01 palette
  adjustments           = "\xee\xa8\x83", -- U+EA03 adjustments
  adjustments_horizontal= "\xee\xb0\xb8", -- U+EC38 adjustments-horizontal
  layout                = "\xee\xab\x9b", -- U+EADB layout
  box                   = "\xee\xa9\x85", -- U+EA45 box
  list                  = "\xee\xad\xab", -- U+EB6B list
  chevron_down          = "\xee\xa9\x9f", -- U+EA5F chevron-down
  chevron_up            = "\xee\xa9\xa2", -- U+EA62 chevron-up
  chevron_right         = "\xee\xa9\xa1", -- U+EA61 chevron-right
  chevron_left          = "\xee\xa9\xa0", -- U+EA60 chevron-left

  -- Status Badges & Alerts
  alert_triangle        = "\xee\xa8\x86", -- U+EA06 alert-triangle
  info_circle           = "\xee\xab\x85", -- U+EAC5 info-circle
  circle_check          = "\xee\xa9\xa7", -- U+EA67 circle-check
  circle_x              = "\xee\xa9\xaa", -- U+EA6A circle-x

  -- Security, Privacy & System Permissions
  shield                = "\xee\xac\xa4", -- U+EB24 shield
  shield_check          = "\xee\xac\xa2", -- U+EB22 shield-check
  shield_x              = "\xee\xac\xa3", -- U+EB23 shield-x
  shield_lock           = "\xee\xb5\x98", -- U+ED58 shield-lock
  lock                  = "\xee\xab\xa2", -- U+EAE2 lock
  lock_open             = "\xee\xab\xa1", -- U+EAE1 lock-open
  wifi                  = "\xee\xad\x92", -- U+EB52 wifi
  router                = "\xee\xac\x98", -- U+EB18 router
  network               = "\xee\xac\x98", -- U+EB18 router / local network
  bell                  = "\xee\xa8\xb5", -- U+EA35 bell
  folder                = "\xee\xaa\xad", -- U+EAAD folder
  camera                = "\xee\xa9\x94", -- U+EA54 camera
  microphone            = "\xee\xab\xb0", -- U+EAF0 microphone
  accessible            = "\xee\xae\xa9", -- U+EBA9 accessible
  video                 = "\xee\xb4\xa2", -- U+ED22 video
  external_link         = "\xee\xaa\x99", -- U+EA99 external-link
}

return icons

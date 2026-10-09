-- Lua Lamp — Native macOS Permissions Framework
-- Provides asynchronous permission checking, authorization requests, System Settings deep-linking,
-- and native-feeling UI components (banners, dialogs, and Settings tabs) for desktop applications.

local core = require "core"
local style = require "src.style"
local ui = require "src.ui"
local icons = require "src.icons"

local permissions = {}

--------------------------------------------------------------------------------
-- 1. Constants & Semantic Enumerations
--------------------------------------------------------------------------------

permissions.LOCAL_NETWORK    = "local_network"
permissions.ACCESSIBILITY    = "accessibility"
permissions.SCREEN_RECORDING = "screen_recording"
permissions.FULL_DISK_ACCESS = "full_disk_access"
permissions.NOTIFICATIONS    = "notifications"
permissions.CAMERA           = "camera"
permissions.MICROPHONE       = "microphone"
permissions.BLUETOOTH        = "bluetooth"
permissions.LOCATION         = "location"

permissions.STATUS = {
  GRANTED        = "granted",
  DENIED         = "denied",
  NOT_DETERMINED = "not_determined",
  RESTRICTED     = "restricted",
  UNSUPPORTED    = "unsupported",
}

--------------------------------------------------------------------------------
-- 2. Metadata Registry & macOS Settings Deep Links
--------------------------------------------------------------------------------

permissions.REGISTRY = {
  [permissions.LOCAL_NETWORK] = {
    id = "local_network",
    title = "Local Network",
    icon = icons.network or icons.router or icons.wifi,
    description = "Discover, ping, and communicate with local gateways, routers, and network devices.",
    reason = "Essential for ping latency tracking, local gateway monitoring, and LAN diagnostics.",
    settings_pane = "local_network",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork",
    help_note = "If access is denied, enable this app in System Settings > Privacy & Security > Local Network.",
  },
  [permissions.ACCESSIBILITY] = {
    id = "accessibility",
    title = "Accessibility",
    icon = icons.shield_check or icons.settings,
    description = "Global hotkey registration, input event observation, and window management.",
    reason = "Allows keyboard shortcuts and system control when running in the background.",
    settings_pane = "accessibility",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    help_note = "Toggle permission in System Settings > Privacy & Security > Accessibility.",
  },
  [permissions.SCREEN_RECORDING] = {
    id = "screen_recording",
    title = "Screen Recording",
    icon = icons.device_desktop or icons.palette,
    description = "Capture display buffers, window coordinates, and pixel color sampling.",
    reason = "Used for screen inspection, color picking, and display streaming.",
    settings_pane = "screen_recording",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
    help_note = "Enable in System Settings > Privacy & Security > Screen & System Audio Recording.",
  },
  [permissions.FULL_DISK_ACCESS] = {
    id = "full_disk_access",
    title = "Full Disk Access",
    icon = icons.folder or icons.lock,
    description = "Read and monitor configuration, log files, and application state across protected folders.",
    reason = "Required to inspect diagnostic logs and read protected system configuration.",
    settings_pane = "full_disk_access",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
    help_note = "Add and enable app in System Settings > Privacy & Security > Full Disk Access.",
  },
  [permissions.NOTIFICATIONS] = {
    id = "notifications",
    title = "Notifications",
    icon = icons.bell or icons.alert_triangle,
    description = "Deliver desktop alerts, latency outage alerts, and background notifications.",
    reason = "Sends timely alerts when network outages or service disruptions occur.",
    settings_pane = "notifications",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications",
    help_note = "Configure banner styles and sounds in System Settings > Notifications.",
  },
  [permissions.CAMERA] = {
    id = "camera",
    title = "Camera",
    icon = icons.camera,
    description = "Access connected webcams and video capture devices.",
    reason = "Required for video input and camera streaming features.",
    settings_pane = "camera",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
    help_note = "Enable in System Settings > Privacy & Security > Camera.",
  },
  [permissions.MICROPHONE] = {
    id = "microphone",
    title = "Microphone",
    icon = icons.microphone,
    description = "Access audio capture devices and input microphones.",
    reason = "Required for voice input and audio recording.",
    settings_pane = "microphone",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
    help_note = "Enable in System Settings > Privacy & Security > Microphone.",
  },
  [permissions.BLUETOOTH] = {
    id = "bluetooth",
    title = "Bluetooth",
    icon = icons.wifi or icons.settings,
    description = "Discover and communicate with nearby Bluetooth LE devices.",
    reason = "Required for peripheral hardware connectivity.",
    settings_pane = "bluetooth",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
    help_note = "Toggle in System Settings > Privacy & Security > Bluetooth.",
  },
  [permissions.LOCATION] = {
    id = "location",
    title = "Location Services",
    icon = icons.star or icons.settings,
    description = "Determine geographic location for regional network telemetry.",
    reason = "Used to pinpoint server latency by geographic region.",
    settings_pane = "location",
    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
    help_note = "Toggle in System Settings > Privacy & Security > Location Services.",
  },
}

-- Order for display in UI lists and settings panels
permissions.ORDER = {
  permissions.LOCAL_NETWORK,
  permissions.ACCESSIBILITY,
  permissions.SCREEN_RECORDING,
  permissions.FULL_DISK_ACCESS,
  permissions.NOTIFICATIONS,
  permissions.CAMERA,
  permissions.MICROPHONE,
}

--------------------------------------------------------------------------------
-- 3. Platform Detection & Status Invariants
--------------------------------------------------------------------------------

--- Check if the host operating system is macOS
---@return boolean
function permissions.is_macos()
  if PLATFORM == "Mac OS X" then return true end
  if system and system.get_file_info and system.get_file_info("/System/Library") ~= nil then
    return true
  end
  return false
end

--- Check if the given permission is applicable/supported on the host platform
---@param perm_type string
---@return boolean
function permissions.is_supported(perm_type)
  if not permissions.is_macos() then return false end
  return permissions.REGISTRY[perm_type] ~= nil
end

--- Get metadata dictionary for a permission
---@param perm_type string
---@return table
function permissions.get_metadata(perm_type)
  return permissions.REGISTRY[perm_type] or {
    id = perm_type,
    title = perm_type:gsub("^%l", string.upper):gsub("_", " "),
    icon = icons.shield or "?",
    description = "System authorization for " .. perm_type,
    reason = "Required for application features.",
    settings_pane = "security",
    url = "x-apple.systempreferences:com.apple.preference.security",
    help_note = "Configure in System Settings > Privacy & Security.",
  }
end

--- Get the macOS System Settings URL for a permission
---@param perm_type string
---@return string
function permissions.get_settings_url(perm_type)
  local meta = permissions.get_metadata(perm_type)
  return meta.url or "x-apple.systempreferences:com.apple.preference.security"
end

--- Cache of last known query results to optimize UI render cycles
local status_cache = {}
local cache_timestamps = {}
local CACHE_TTL_SECONDS = 2.0

--- Query the authorization status of a specific permission
---@param perm_type string
---@param options? table { bypass_cache: boolean }
---@return string "granted" | "denied" | "not_determined" | "restricted" | "unsupported"
function permissions.get_status(perm_type, options)
  options = options or {}
  if not permissions.is_macos() then
    -- On Linux / Windows, permissions are unrestricted or unsupported
    return permissions.STATUS.GRANTED
  end

  local now = system and system.get_time and system.get_time() or os.time()
  if not options.bypass_cache and status_cache[perm_type] and (now - (cache_timestamps[perm_type] or 0) < CACHE_TTL_SECONDS) then
    return status_cache[perm_type]
  end

  local status = permissions.STATUS.UNSUPPORTED
  if system and system.macos_get_permission_status then
    local ok, res = pcall(system.macos_get_permission_status, perm_type)
    if ok and res and res ~= "unsupported" then
      status = res
    end
  end

  -- If status is still unsupported but recognized in registry on macOS, default gracefully
  if status == permissions.STATUS.UNSUPPORTED and permissions.REGISTRY[perm_type] then
    status = permissions.STATUS.NOT_DETERMINED
  end

  status_cache[perm_type] = status
  cache_timestamps[perm_type] = now
  return status
end

--- Check if a specific permission is currently granted
---@param perm_type string
---@return boolean
function permissions.is_granted(perm_type)
  return permissions.get_status(perm_type) == permissions.STATUS.GRANTED
end

--- Check if a specific permission has been explicitly denied
---@param perm_type string
---@return boolean
function permissions.is_denied(perm_type)
  return permissions.get_status(perm_type) == permissions.STATUS.DENIED
end

--- Invalidate cache for a permission or all permissions
---@param perm_type? string
function permissions.invalidate_cache(perm_type)
  if perm_type then
    status_cache[perm_type] = nil
    cache_timestamps[perm_type] = nil
  else
    status_cache = {}
    cache_timestamps = {}
  end
end

--------------------------------------------------------------------------------
-- 4. Deep-Link System Settings Navigation
--------------------------------------------------------------------------------

--- Open the System Settings pane corresponding to the given permission
---@param perm_type string
---@return boolean success
function permissions.open_settings(perm_type)
  local meta = permissions.get_metadata(perm_type)
  local pane = meta.settings_pane or perm_type
  local url = meta.url or permissions.get_settings_url(perm_type)

  if system and system.macos_open_settings_pane then
    local ok, res = pcall(system.macos_open_settings_pane, pane)
    if ok and res then return true end
  end

  -- Fallback to shell open command
  if system and system.exec then
    pcall(system.exec, "open " .. string.format("%q", url))
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- 5. Interactive Authorization Request API
--------------------------------------------------------------------------------

--- Request authorization for a specific permission
---@param perm_type string
---@param options? table { target_ip: string, open_settings_if_denied: boolean }
---@param callback? fun(status: string, is_granted: boolean)
---@return string immediate_status
function permissions.request(perm_type, options, callback)
  options = options or {}

  if not permissions.is_macos() then
    if callback then callback(permissions.STATUS.GRANTED, true) end
    return permissions.STATUS.GRANTED
  end

  permissions.invalidate_cache(perm_type)

  local initial_status = permissions.get_status(perm_type, { bypass_cache = true })
  if initial_status == permissions.STATUS.GRANTED then
    if callback then callback(permissions.STATUS.GRANTED, true) end
    return permissions.STATUS.GRANTED
  end

  -- If already denied and option is enabled, guide directly to System Settings
  if initial_status == permissions.STATUS.DENIED and options.open_settings_if_denied then
    permissions.open_settings(perm_type)
    if callback then callback(initial_status, false) end
    return initial_status
  end

  -- Initiate native OS authorization trigger
  if perm_type == permissions.LOCAL_NETWORK then
    local target_ip = options.target_ip or "192.168.1.1"
    if system and system.macos_request_permission then
      pcall(system.macos_request_permission, "local_network", target_ip)
    end
    -- Try companion helper binary if available (Pinglet companion pattern)
    local candidate_paths = {
      (DATADIR or rawget(_G, "MACOS_RESOURCES") or USERDIR or "") .. "/../MacOS/netauth",
      (DATADIR or rawget(_G, "MACOS_RESOURCES") or USERDIR or "") .. "/bin/netauth",
      "bin/netauth",
    }
    for _, helper_path in ipairs(candidate_paths) do
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        pcall(function()
          local process = require "process"
          process.start({ helper_path, target_ip }, {
            stdout = process.REDIRECT_DISCARD,
            stderr = process.REDIRECT_DISCARD,
          })
        end)
        break
      end
    end
  else
    if system and system.macos_request_permission then
      pcall(system.macos_request_permission, perm_type)
    end
  end

  -- Launch non-blocking coroutine to poll for user decision
  if callback and core and core.add_thread then
    core.add_thread(function()
      local start_time = system.get_time()
      local timeout = 12.0
      while (system.get_time() - start_time) < timeout do
        coroutine.yield(0.5)
        local cur = permissions.get_status(perm_type, { bypass_cache = true })
        if cur == permissions.STATUS.GRANTED or cur == permissions.STATUS.DENIED then
          callback(cur, cur == permissions.STATUS.GRANTED)
          return
        end
      end
      local final_cur = permissions.get_status(perm_type, { bypass_cache = true })
      callback(final_cur, final_cur == permissions.STATUS.GRANTED)
    end)
  end

  return initial_status
end

--------------------------------------------------------------------------------
-- 6. UI Component 1: Non-Intrusive Permission Warning Banner
--------------------------------------------------------------------------------

--- Create an inline UI banner for displaying permission warnings & quick actions
--- Adheres strictly to the 5 Cardinal Directives (Rule 1 Optical Baseline, Rule 2 Borderless Surface).
---@param perm_type string
---@param options? table { message: string, action_label: string, dismissible: boolean, on_action: fun(), on_dismiss: fun() }
---@return table banner
function permissions.create_banner(perm_type, options)
  options = options or {}
  local meta = permissions.get_metadata(perm_type)

  local banner = {
    perm_type = perm_type,
    meta = meta,
    title = meta.title .. " Access Required",
    message = options.message or meta.reason or meta.description,
    action_label = options.action_label or "Open Settings",
    dismissible = (options.dismissible ~= false),
    visible = not permissions.is_granted(perm_type),
    dismissed = false,
    hover_action = false,
    hover_dismiss = false,
    on_action = options.on_action,
    on_dismiss = options.on_dismiss,
    last_check = 0,
  }

  function banner:update(dt)
    if self.dismissed or not self.visible then return end
    local now = system and system.get_time and system.get_time() or os.time()
    if now - self.last_check > 2.0 then
      self.last_check = now
      if permissions.is_granted(self.perm_type) then
        self.visible = false
        if core then core.redraw = true end
      end
    end
  end

  function banner:draw(x, y, w, h)
    if not self.visible or self.dismissed then return 0 end

    local s = style.scale or 1.0
    local c = style.colors

    -- Background: Translucent amber/warning pill (Rule 2: Borderless Surface)
    local banner_bg = { 245, 158, 11, 28 } -- subtle amber glow
    local banner_border = { 245, 158, 11, 45 }
    local radius = math.floor(8 * s)
    ui.draw_rounded_rect(x, y, w, h, radius, banner_bg)

    -- Left Icon: Tabler Warning or Permission Icon (Rule 3: Decoupled Icon measurement)
    local icon_char = icons.alert_triangle or icons.shield or meta.icon
    local icon_font = style.font_icon or style.font_normal
    local icon_w = icon_font:get_width(icon_char)
    local icon_pad_x = math.floor(14 * s)
    local icon_y = y + math.floor((h - icon_font:get_height()) / 2) + math.floor(1.0 * s)
    local warning_col = { 245, 158, 11, 255 }
    renderer.draw_text(icon_font, icon_char, x + icon_pad_x, icon_y, warning_col)

    -- Action Button on Right (Pinglet Button Standard: Tinted pill)
    local btn_w = math.floor(108 * s)
    local btn_h = math.floor(26 * s)
    local right_pad = math.floor(12 * s)
    local dismiss_w = self.dismissible and math.floor(24 * s) or 0
    local btn_x = x + w - right_pad - dismiss_w - btn_w
    local btn_y = y + math.floor((h - btn_h) / 2)

    ui.draw_button(style.font_small or style.font_normal, self.action_label, btn_x, btn_y, btn_w, btn_h, {
      variant = "tinted",
      accent_theme = "amber",
      is_hover = self.hover_action,
      icon = icons.external_link or nil,
    })

    -- Dismiss Button (if enabled)
    if self.dismissible then
      local dis_x = x + w - right_pad - dismiss_w + math.floor(4 * s)
      local dis_y = y + math.floor((h - dismiss_w) / 2)
      if self.hover_dismiss then
        ui.draw_rounded_rect(dis_x, dis_y, dismiss_w - math.floor(4 * s), dismiss_w - math.floor(4 * s), math.floor(4 * s), { 255, 255, 255, 24 })
      end
      local close_icon = icons.x or "x"
      local cw = icon_font:get_width(close_icon)
      local cy = y + math.floor((h - icon_font:get_height()) / 2) + math.floor(1.0 * s)
      renderer.draw_text(icon_font, close_icon, dis_x + math.floor((dismiss_w - 4 * s - cw) / 2), cy, c.text_muted)
    end

    -- Text Center: Title and Message
    local text_x = x + icon_pad_x + icon_w + math.floor(10 * s)
    local text_max_w = btn_x - text_x - math.floor(12 * s)
    local font_title = style.font_bold or style.font_normal
    local font_msg = style.font_small or style.font_normal

    -- Single line or title + brief text
    local ty = y + math.floor((h - font_title:get_height()) / 2) + math.floor(1.2 * s)
    local title_str = self.title .. ": "
    local title_w = font_title:get_width(title_str)

    if text_max_w > title_w + 50 * s then
      renderer.draw_text(font_title, title_str, text_x, ty, c.text)
      local msg_w = text_max_w - title_w
      local short_msg = self.message
      if font_msg:get_width(short_msg) > msg_w then
        -- Truncate cleanly with ellipsis
        while #short_msg > 5 and font_msg:get_width(short_msg .. "...") > msg_w do
          short_msg = short_msg:sub(1, -2)
        end
        short_msg = short_msg .. "..."
      end
      local my = y + math.floor((h - font_msg:get_height()) / 2) + math.floor(1.2 * s)
      renderer.draw_text(font_msg, short_msg, text_x + title_w, my, c.text_muted)
    else
      renderer.draw_text(font_title, self.title, text_x, ty, c.text)
    end

    return h
  end

  function banner:on_mouse_moved(px, py, x, y, w, h)
    if not self.visible or self.dismissed then return false end
    local s = style.scale or 1.0
    local btn_w = math.floor(108 * s)
    local btn_h = math.floor(26 * s)
    local right_pad = math.floor(12 * s)
    local dismiss_w = self.dismissible and math.floor(24 * s) or 0
    local btn_x = x + w - right_pad - dismiss_w - btn_w
    local btn_y = y + math.floor((h - btn_h) / 2)

    self.hover_action = ui.point_in_rect(px, py, btn_x, btn_y, btn_w, btn_h)

    if self.dismissible then
      local dis_x = x + w - right_pad - dismiss_w + math.floor(4 * s)
      local dis_y = y + math.floor((h - dismiss_w) / 2)
      self.hover_dismiss = ui.point_in_rect(px, py, dis_x, dis_y, dismiss_w, dismiss_w)
    else
      self.hover_dismiss = false
    end

    return self.hover_action or self.hover_dismiss
  end

  function banner:on_mouse_pressed(button, px, py, x, y, w, h)
    if not self.visible or self.dismissed then return false end
    if button ~= "left" and button ~= 1 then return false end

    local s = style.scale or 1.0
    local btn_w = math.floor(108 * s)
    local btn_h = math.floor(26 * s)
    local right_pad = math.floor(12 * s)
    local dismiss_w = self.dismissible and math.floor(24 * s) or 0
    local btn_x = x + w - right_pad - dismiss_w - btn_w
    local btn_y = y + math.floor((h - btn_h) / 2)

    if ui.point_in_rect(px, py, btn_x, btn_y, btn_w, btn_h) then
      if self.on_action then
        self.on_action()
      else
        permissions.open_settings(self.perm_type)
      end
      if core then core.redraw = true end
      return true
    end

    if self.dismissible then
      local dis_x = x + w - right_pad - dismiss_w + math.floor(4 * s)
      local dis_y = y + math.floor((h - dismiss_w) / 2)
      if ui.point_in_rect(px, py, dis_x, dis_y, dismiss_w, dismiss_w) then
        self.dismissed = true
        if self.on_dismiss then self.on_dismiss() end
        if core then core.redraw = true end
        return true
      end
    end

    return false
  end

  return banner
end

--------------------------------------------------------------------------------
-- 7. UI Component 2: Dedicated "Permissions" Tab in Settings Dialog
--------------------------------------------------------------------------------

--- Register the native Permissions tab inside framework.Settings
function permissions.register_settings_tab()
  if not permissions.is_macos() then return end
  local settings = require "src.settings_dialog"

  local function render_permissions_tab(panel_x, panel_y, panel_w, panel_h, s, c, dialog)
    local font_head = style.font_heading or style.font_normal
    local font_title = style.font_bold or style.font_normal
    local font_body = style.font_normal
    local font_small = style.font_small or style.font_normal
    local font_icon = style.font_icon or style.font_normal

    -- 1. Section Header & Subtitle
    local head_text = "System Permissions & Privacy"
    local head_y = panel_y + math.floor(1.2 * s)
    renderer.draw_text(font_head, head_text, panel_x, head_y, c.text)

    local sub_y = head_y + font_head:get_height() + math.floor(6 * s)
    local sub_lines = ui.wrap_text(font_small, "Manage macOS security authorizations and hardware access required for application diagnostics and features.", panel_w)
    for _, line in ipairs(sub_lines) do
      renderer.draw_text(font_small, line, panel_x, sub_y, c.text_muted)
      sub_y = sub_y + font_small:get_height() + math.floor(2 * s)
    end

    -- 2. Card List of Permissions
    local card_y = sub_y + math.floor(16 * s)
    local card_h = math.floor(52 * s)
    local card_gap = math.floor(8 * s)
    local card_r = math.floor(8 * s)

    local mx = dialog.mouse_x or -1
    local my = dialog.mouse_y or -1

    for _, perm_type in ipairs(permissions.ORDER) do
      local meta = permissions.get_metadata(perm_type)
      local st = permissions.get_status(perm_type)
      local is_granted = (st == permissions.STATUS.GRANTED)

      local is_hover = ui.point_in_rect(mx, my, panel_x, card_y, panel_w, card_h)
      local card_bg = is_hover and c.surface_hover or c.surface

      -- Card Background (Rule 2: Borderless Surface)
      ui.draw_rounded_rect(panel_x, card_y, panel_w, card_h, card_r, card_bg)

      -- Left Icon
      local icon_box_size = math.floor(32 * s)
      local icon_box_x = panel_x + math.floor(12 * s)
      local icon_box_y = card_y + math.floor((card_h - icon_box_size) / 2)
      local icon_bg = is_granted and { 16, 185, 129, 28 } or { 56, 189, 248, 20 }
      ui.draw_rounded_rect(icon_box_x, icon_box_y, icon_box_size, icon_box_size, math.floor(6 * s), icon_bg)

      local icon_char = meta.icon or icons.shield
      local icon_w = font_icon:get_width(icon_char)
      local icon_x = icon_box_x + math.floor((icon_box_size - icon_w) / 2)
      local icon_y = icon_box_y + math.floor((icon_box_size - font_icon:get_height()) / 2) + math.floor(1.0 * s)
      local icon_col = is_granted and { 16, 185, 129, 255 } or c.accent
      renderer.draw_text(font_icon, icon_char, icon_x, icon_y, icon_col)

      -- Center Information (Title & Description)
      local text_x = icon_box_x + icon_box_size + math.floor(12 * s)
      local title_y = card_y + math.floor(9 * s) + math.floor(1.2 * s)
      renderer.draw_text(font_title, meta.title, text_x, title_y, c.text)

      local desc_y = title_y + font_title:get_height() + math.floor(2 * s)
      local desc_str = meta.description
      local avail_text_w = panel_w - (text_x - panel_x) - math.floor(120 * s)
      if font_small:get_width(desc_str) > avail_text_w then
        while #desc_str > 5 and font_small:get_width(desc_str .. "...") > avail_text_w do
          desc_str = desc_str:sub(1, -2)
        end
        desc_str = desc_str .. "..."
      end
      renderer.draw_text(font_small, desc_str, text_x, desc_y, c.text_muted)

      -- Right Status Badge or Action Button
      local btn_w = math.floor(104 * s)
      local btn_h = math.floor(28 * s)
      local btn_x = panel_x + panel_w - btn_w - math.floor(12 * s)
      local btn_y = card_y + math.floor((card_h - btn_h) / 2)

      if is_granted then
        -- Solid Pill Badge (Rule 2: Pinglet Button Standard)
        local badge_r = math.floor(btn_h / 2)
        ui.draw_rounded_rect(btn_x, btn_y, btn_w, btn_h, badge_r, { 16, 185, 129, 32 })
        local check_char = icons.check or "✓"
        local label_text = "Granted"
        local cw = font_small:get_width(check_char)
        local lw = font_small:get_width(label_text)
        local gap = math.floor(6 * s)
        local total_w = cw + gap + lw
        local cx = btn_x + math.floor((btn_w - total_w) / 2)
        local cy = btn_y + math.floor((btn_h - font_icon:get_height()) / 2) + math.floor(1.0 * s)
        local ty = btn_y + math.floor((btn_h - font_small:get_height()) / 2) + math.floor(1.2 * s)
        local green_col = { 16, 185, 129, 255 }
        renderer.draw_text(font_icon, check_char, cx, cy, green_col)
        renderer.draw_text(font_small, label_text, cx + cw + gap, ty, green_col)
      else
        -- Interactive Button (Pinglet Button Standard: Tinted pill)
        local btn_hover = ui.point_in_rect(mx, my, btn_x, btn_y, btn_w, btn_h)
        ui.draw_button(font_small, "Open Settings", btn_x, btn_y, btn_w, btn_h, {
          variant = "tinted",
          accent_theme = (st == permissions.STATUS.DENIED) and "amber" or "cyan",
          is_hover = btn_hover,
          icon = icons.external_link or nil,
        })
      end

      card_y = card_y + card_h + card_gap
    end

    -- 3. Bottom Refresh Bar
    local refresh_btn_w = math.floor(130 * s)
    local refresh_btn_h = math.floor(30 * s)
    local refresh_btn_y = panel_y + panel_h - refresh_btn_h - math.floor(8 * s)
    local is_ref_hover = ui.point_in_rect(mx, my, panel_x, refresh_btn_y, refresh_btn_w, refresh_btn_h)

    ui.draw_button(font_small, "Refresh Status", panel_x, refresh_btn_y, refresh_btn_w, refresh_btn_h, {
      variant = "surface",
      is_hover = is_ref_hover,
      icon = icons.refresh or nil,
    })
  end

  local function handle_permissions_click(px, py, panel_x, panel_y, panel_w, panel_h, dialog)
    local s = style.scale or 1.0

    -- Header and Subtitle height offset
    local font_head = style.font_heading or style.font_normal
    local font_small = style.font_small or style.font_normal
    local head_y = panel_y + math.floor(1.2 * s)
    local sub_y = head_y + font_head:get_height() + math.floor(6 * s)
    local sub_lines = ui.wrap_text(font_small, "Manage macOS security authorizations and hardware access required for application diagnostics and features.", panel_w)
    local card_y = sub_y + (#sub_lines * (font_small:get_height() + math.floor(2 * s))) + math.floor(16 * s)
    local card_h = math.floor(52 * s)
    local card_gap = math.floor(8 * s)

    -- Check click on each permission card's action button
    for _, perm_type in ipairs(permissions.ORDER) do
      local st = permissions.get_status(perm_type)
      if st ~= permissions.STATUS.GRANTED then
        local btn_w = math.floor(104 * s)
        local btn_h = math.floor(28 * s)
        local btn_x = panel_x + panel_w - btn_w - math.floor(12 * s)
        local btn_y = card_y + math.floor((card_h - btn_h) / 2)

        if ui.point_in_rect(px, py, btn_x, btn_y, btn_w, btn_h) then
          permissions.open_settings(perm_type)
          return true
        end
      end
      card_y = card_y + card_h + card_gap
    end

    -- Check click on "Refresh Status" button
    local refresh_btn_w = math.floor(130 * s)
    local refresh_btn_h = math.floor(30 * s)
    local refresh_btn_y = panel_y + panel_h - refresh_btn_h - math.floor(8 * s)
    if ui.point_in_rect(px, py, panel_x, refresh_btn_y, refresh_btn_w, refresh_btn_h) then
      permissions.invalidate_cache()
      if core then core.redraw = true end
      return true
    end

    return false
  end

  settings:register_section("permissions", "Permissions", icons.shield or "P", render_permissions_tab, handle_permissions_click)
end

-- Auto-register the settings tab on initialization
permissions.register_settings_tab()

return permissions

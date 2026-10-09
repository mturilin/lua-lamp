#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Network/Network.h>
#import <AVFoundation/AVFoundation.h>
#import <dns_sd.h>
#include <fcntl.h>
#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>

double get_macos_backing_scale_factor(void) {
  @autoreleasepool {
    NSScreen *screen = [NSScreen mainScreen];
    if (screen) {
      double factor = (double)[screen backingScaleFactor];
      if (factor > 1.0) {
        return factor;
      }
    }
    NSArray<NSScreen *> *screens = [NSScreen screens];
    if (screens && [screens count] > 0) {
      for (NSScreen *s in screens) {
        double f = (double)[s backingScaleFactor];
        if (f > 1.0) {
          return f;
        }
      }
      return (double)[screens[0] backingScaleFactor];
    }
    return 1.0;
  }
}

#ifdef MACOS_USE_BUNDLE
void set_macos_bundle_resources(lua_State *L)
{ @autoreleasepool
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* bundlePath = [mainBundle bundlePath];
    if ([bundlePath hasSuffix:@".app"]) {
      NSString* resource_path = [mainBundle resourcePath];
      lua_pushstring(L, [resource_path UTF8String]);
      lua_setglobal(L, "MACOS_RESOURCES");
    }

    double factor = get_macos_backing_scale_factor();
    lua_pushnumber(L, factor);
    lua_setglobal(L, "MACOS_SCALE");
}}
#endif

/* Thanks to mathewmariani, taken from his lite-macos github repository. */
void enable_momentum_scroll(void) {
  [[NSUserDefaults standardUserDefaults]
    setBool: YES
    forKey: @"AppleMomentumScrollSupported"];
}

#include <string.h>
#include <SDL3/SDL.h>

#define MAX_PENDING_MENU 32
static char pending_menu_queue[MAX_PENDING_MENU][256];
static int pending_menu_head = 0;
static int pending_menu_tail = 0;

static void push_pending_menu_command(const char *cmd) {
  if (!cmd) return;
  int next = (pending_menu_head + 1) % MAX_PENDING_MENU;
  if (next != pending_menu_tail) {
    strncpy(pending_menu_queue[pending_menu_head], cmd, 255);
    pending_menu_queue[pending_menu_head][255] = '\0';
    pending_menu_head = next;

    SDL_Event ev;
    SDL_zero(ev);
    ev.type = SDL_EVENT_USER;
    SDL_PushEvent(&ev);
  }
}

int pop_pending_menu_command(char *buf, size_t buflen) {
  if (pending_menu_head == pending_menu_tail || !buf || buflen == 0) {
    return 0;
  }
  strncpy(buf, pending_menu_queue[pending_menu_tail], buflen - 1);
  buf[buflen - 1] = '\0';
  pending_menu_tail = (pending_menu_tail + 1) % MAX_PENDING_MENU;
  return 1;
}

@interface LuaLampMenuTarget : NSObject <NSMenuItemValidation, NSUserInterfaceValidations>
- (void)menuItemClicked:(NSMenuItem *)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item;
@end

@implementation LuaLampMenuTarget
- (void)menuItemClicked:(NSMenuItem *)sender {
  NSString *cmd = (NSString *)[sender representedObject];
  if (cmd) {
    push_pending_menu_command([cmd UTF8String]);
  }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  return YES;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
  return YES;
}
@end

static LuaLampMenuTarget *s_menu_target = nil;

static LuaLampMenuTarget *get_menu_target(void) {
  if (!s_menu_target) {
    s_menu_target = [[LuaLampMenuTarget alloc] init];
  }
  return s_menu_target;
}

static void parse_shortcut(const char *shortcut_str, NSString **outKey, NSEventModifierFlags *outMask) {
  *outKey = @"";
  *outMask = 0;
  if (!shortcut_str || !*shortcut_str) return;

  NSString *s = [NSString stringWithUTF8String:shortcut_str];
  NSEventModifierFlags mask = 0;

  if ([s containsString:@"Cmd+"] || [s containsString:@"Command+"]) {
    mask |= NSEventModifierFlagCommand;
    s = [s stringByReplacingOccurrencesOfString:@"Cmd+" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"Command+" withString:@""];
  }
  if ([s containsString:@"Ctrl+"] || [s containsString:@"Control+"]) {
    mask |= NSEventModifierFlagControl;
    s = [s stringByReplacingOccurrencesOfString:@"Ctrl+" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"Control+" withString:@""];
  }
  if ([s containsString:@"Alt+"] || [s containsString:@"Option+"] || [s containsString:@"Opt+"]) {
    mask |= NSEventModifierFlagOption;
    s = [s stringByReplacingOccurrencesOfString:@"Alt+" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"Option+" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"Opt+" withString:@""];
  }
  if ([s containsString:@"Shift+"]) {
    mask |= NSEventModifierFlagShift;
    s = [s stringByReplacingOccurrencesOfString:@"Shift+" withString:@""];
  }

  *outMask = mask;
  *outKey = [s lowercaseString];
}

void setup_default_macos_menu(void) {
  @autoreleasepool {
    NSMenu *mainMenu = [NSApp mainMenu];
    if (!mainMenu) {
      mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
      [NSApp setMainMenu:mainMenu];
    }
    [mainMenu setAutoenablesItems:NO];

    LuaLampMenuTarget *target = get_menu_target();

    // The macOS Application Menu (Item 0)
    // The OS automatically displays CFBundleName / ProcessName ("Lua Lamp") as the title.
    NSMenuItem *appMenuItem = nil;
    NSMenu *appMenu = nil;

    if ([mainMenu numberOfItems] > 0) {
      appMenuItem = [mainMenu itemAtIndex:0];
      appMenu = [appMenuItem submenu];
    } else {
      appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
      [mainMenu addItem:appMenuItem];
    }

    if (!appMenu) {
      appMenu = [[NSMenu alloc] initWithTitle:@"Lua Lamp"];
      [appMenuItem setSubmenu:appMenu];
    }
    [appMenu setAutoenablesItems:NO];

    BOOL foundAbout = NO;
    BOOL foundSettings = NO;
    BOOL foundQuit = NO;

    for (NSMenuItem *item in [appMenu itemArray]) {
      NSString *title = [item title];
      NSString *key = [item keyEquivalent];
      NSEventModifierFlags mask = [item keyEquivalentModifierMask];

      if ([title isEqualToString:@"Settings…"] || [title isEqualToString:@"Preferences…"] ||
          [title hasPrefix:@"Settings"] || [title hasPrefix:@"Preferences"] ||
          ([key isEqualToString:@","] && (mask & NSEventModifierFlagCommand))) {
        [item setTarget:target];
        [item setAction:@selector(menuItemClicked:)];
        [item setRepresentedObject:@"app:open-settings"];
        [item setKeyEquivalent:@","];
        [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [item setEnabled:YES];
        foundSettings = YES;
      } else if ([title hasPrefix:@"About "] || [title isEqualToString:@"About"]) {
        [item setTarget:target];
        [item setAction:@selector(menuItemClicked:)];
        [item setRepresentedObject:@"app:about"];
        [item setEnabled:YES];
        foundAbout = YES;
      } else if ([title hasPrefix:@"Quit "] || [title isEqualToString:@"Quit"] ||
                 ([key isEqualToString:@"q"] && (mask & NSEventModifierFlagCommand))) {
        [item setTarget:target];
        [item setAction:@selector(menuItemClicked:)];
        [item setRepresentedObject:@"app:quit"];
        [item setKeyEquivalent:@"q"];
        [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [item setEnabled:YES];
        foundQuit = YES;
      }
    }

    // Insert missing standard items if SDL did not populate them
    if (!foundAbout) {
      NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About Lua Lamp"
                                                         action:@selector(menuItemClicked:)
                                                  keyEquivalent:@""];
      [aboutItem setTarget:target];
      [aboutItem setRepresentedObject:@"app:about"];
      [aboutItem setEnabled:YES];
      [appMenu insertItem:aboutItem atIndex:0];
    }

    if (!foundSettings) {
      NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings…"
                                                            action:@selector(menuItemClicked:)
                                                     keyEquivalent:@","];
      [settingsItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
      [settingsItem setTarget:target];
      [settingsItem setRepresentedObject:@"app:open-settings"];
      [settingsItem setEnabled:YES];
      NSInteger insIdx = MIN((NSInteger)1, [appMenu numberOfItems]);
      [appMenu insertItem:settingsItem atIndex:insIdx];
    }

    if (!foundQuit) {
      NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Lua Lamp"
                                                        action:@selector(menuItemClicked:)
                                                 keyEquivalent:@"q"];
      [quitItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
      [quitItem setTarget:target];
      [quitItem setRepresentedObject:@"app:quit"];
      [quitItem setEnabled:YES];
      [appMenu addItem:quitItem];
    }
  }
}

int f_set_native_menu(lua_State *L) {
  @autoreleasepool {
    if (!lua_istable(L, 1)) {
      lua_pushboolean(L, false);
      return 1;
    }

    NSMenu *mainMenu = [NSApp mainMenu];
    if (!mainMenu || [mainMenu numberOfItems] == 0) {
      setup_default_macos_menu();
      mainMenu = [NSApp mainMenu];
    }
    [mainMenu setAutoenablesItems:NO];

    LuaLampMenuTarget *target = get_menu_target();
    int num_menus = (int)lua_rawlen(L, 1);

    NSString *processName = [[NSProcessInfo processInfo] processName];

    for (int i = 1; i <= num_menus; i++) {
      lua_rawgeti(L, 1, i);
      if (lua_istable(L, -1)) {
        lua_getfield(L, -1, "title");
        const char *title_str = lua_tostring(L, -1);
        lua_pop(L, 1);

        if (title_str) {
          NSString *nsTitle = [NSString stringWithUTF8String:title_str];

          BOOL isAppMenu = [nsTitle caseInsensitiveCompare:@"Lua Lamp"] == NSOrderedSame ||
                           [nsTitle caseInsensitiveCompare:@"Application"] == NSOrderedSame ||
                           [nsTitle caseInsensitiveCompare:@"App"] == NSOrderedSame ||
                           (processName && [nsTitle caseInsensitiveCompare:processName] == NSOrderedSame);

          lua_getfield(L, -1, "is_app_menu");
          if (lua_isboolean(L, -1) && lua_toboolean(L, -1)) {
            isAppMenu = YES;
          }
          lua_pop(L, 1);

          NSMenuItem *menuItem = nil;
          NSMenu *submenu = nil;

          if (isAppMenu) {
            // Use the standard system application menu at index 0. Never create a duplicate!
            menuItem = [mainMenu itemAtIndex:0];
            submenu = [menuItem submenu];
            if (!submenu) {
              submenu = [[NSMenu alloc] initWithTitle:nsTitle];
              [menuItem setSubmenu:submenu];
            }
            [submenu setAutoenablesItems:NO];
          } else {
            // Search for existing top-level menu starting at index 1
            for (NSUInteger idx = 1; idx < [mainMenu numberOfItems]; idx++) {
              NSMenuItem *item = [mainMenu itemAtIndex:idx];
              if ([item.title isEqualToString:nsTitle] || [item.submenu.title isEqualToString:nsTitle]) {
                menuItem = item;
                break;
              }
            }

            if (!menuItem) {
              menuItem = [[NSMenuItem alloc] initWithTitle:nsTitle action:nil keyEquivalent:@""];
              submenu = [[NSMenu alloc] initWithTitle:nsTitle];
              [menuItem setSubmenu:submenu];

              // Insert menu keeping standard order (keep Window before Help)
              NSUInteger insertIdx = [mainMenu numberOfItems];
              if (![nsTitle isEqualToString:@"Help"]) {
                for (NSUInteger idx = 1; idx < [mainMenu numberOfItems]; idx++) {
                  NSMenuItem *m = [mainMenu itemAtIndex:idx];
                  if ([[m.submenu title] isEqualToString:@"Window"] || [[m.submenu title] isEqualToString:@"Help"]) {
                    insertIdx = idx;
                    break;
                  }
                }
              }
              [mainMenu insertItem:menuItem atIndex:insertIdx];
            } else {
              submenu = [menuItem submenu];
              if (!submenu) {
                submenu = [[NSMenu alloc] initWithTitle:nsTitle];
                [menuItem setSubmenu:submenu];
              }
            }

            [submenu setAutoenablesItems:NO];
            // For non-application menus, clear items to sync fresh with Lua
            [submenu removeAllItems];
          }

          lua_getfield(L, -1, "items");
          if (lua_istable(L, -1)) {
            int num_items = (int)lua_rawlen(L, -1);
            for (int j = 1; j <= num_items; j++) {
              lua_rawgeti(L, -1, j);
              if (lua_istable(L, -1)) {
                lua_getfield(L, -1, "text");
                const char *text_str = lua_tostring(L, -1);
                lua_pop(L, 1);

                if (text_str && (strcmp(text_str, "-") == 0 || strcmp(text_str, "---") == 0)) {
                  if (!isAppMenu) {
                    [submenu addItem:[NSMenuItem separatorItem]];
                  }
                } else if (text_str) {
                  lua_getfield(L, -1, "shortcut");
                  const char *shortcut_str = lua_tostring(L, -1);
                  lua_pop(L, 1);

                  lua_getfield(L, -1, "command");
                  const char *cmd_str = lua_tostring(L, -1);
                  lua_pop(L, 1);

                  NSString *itemTitle = [NSString stringWithUTF8String:text_str];
                  NSString *itemKey = @"";
                  NSEventModifierFlags itemMask = 0;
                  parse_shortcut(shortcut_str, &itemKey, &itemMask);

                  NSMenuItem *subItem = nil;
                  if (isAppMenu) {
                    for (NSMenuItem *existing in [submenu itemArray]) {
                      NSString *exTitle = [existing title];
                      NSString *exKey = [existing keyEquivalent];
                      NSEventModifierFlags exMask = [existing keyEquivalentModifierMask];

                      if ([exTitle isEqualToString:itemTitle] ||
                          ([itemTitle hasPrefix:@"Settings"] && ([exTitle hasPrefix:@"Settings"] || [exTitle hasPrefix:@"Preferences"])) ||
                          ([itemTitle hasPrefix:@"Preferences"] && ([exTitle hasPrefix:@"Settings"] || [exTitle hasPrefix:@"Preferences"])) ||
                          ([itemTitle hasPrefix:@"About"] && [exTitle hasPrefix:@"About"]) ||
                          ([itemKey length] > 0 && [itemKey isEqualToString:exKey] && (itemMask == exMask))) {
                        subItem = existing;
                        break;
                      }
                    }
                  }

                  if (!subItem) {
                    subItem = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                         action:@selector(menuItemClicked:)
                                                  keyEquivalent:itemKey];
                    [subItem setKeyEquivalentModifierMask:itemMask];
                    [subItem setTarget:target];
                    if (cmd_str) {
                      [subItem setRepresentedObject:[NSString stringWithUTF8String:cmd_str]];
                    }
                    [subItem setEnabled:YES];

                    if (isAppMenu) {
                      // Insert before the last separator/Quit item if possible
                      NSInteger insIdx = MAX((NSInteger)1, [submenu numberOfItems] - 2);
                      [submenu insertItem:subItem atIndex:insIdx];
                    } else {
                      [submenu addItem:subItem];
                    }
                  } else {
                    [subItem setTarget:target];
                    [subItem setAction:@selector(menuItemClicked:)];
                    if ([itemKey length] > 0) {
                      [subItem setKeyEquivalent:itemKey];
                      [subItem setKeyEquivalentModifierMask:itemMask];
                    }
                    if (cmd_str) {
                      [subItem setRepresentedObject:[NSString stringWithUTF8String:cmd_str]];
                    }
                    [subItem setEnabled:YES];
                  }
                }
              }
              lua_pop(L, 1);
            }
          }
          lua_pop(L, 1);
        }
      }
      lua_pop(L, 1);
    }

    lua_pushboolean(L, true);
    return 1;
  }
}

static void permissions_bonjour_reply(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                      DNSServiceErrorType errorCode, const char *serviceName,
                                      const char *regtype, const char *replyDomain, void *context) {
  (void)sdRef; (void)flags; (void)interfaceIndex; (void)errorCode;
  (void)serviceName; (void)regtype; (void)replyDomain; (void)context;
}

static void trigger_local_network_prompt(const char *target_ip) {
  if (!target_ip || strlen(target_ip) == 0) {
    target_ip = "192.168.1.1";
  }

  // 1. DNSServiceBrowse triggers the standard macOS Local Network permission prompt
  static DNSServiceRef sdRef = NULL;
  DNSServiceBrowse(&sdRef, 0, 0, "_http._tcp", NULL, permissions_bonjour_reply, NULL);

  // 2. NWBrowser (Network.framework) Bonjour discovery
  nw_browse_descriptor_t desc = nw_browse_descriptor_create_bonjour_service("_http._tcp", NULL);
  nw_parameters_t bparams = nw_parameters_create();
  nw_browser_t browser = nw_browser_create(desc, bparams);
  nw_browser_set_queue(browser, dispatch_get_main_queue());
  nw_browser_start(browser);

  // 3. UDP probe to the local gateway
  nw_endpoint_t endpoint = nw_endpoint_create_host(target_ip, "53");
  nw_parameters_t params = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
  nw_connection_t conn = nw_connection_create(endpoint, params);
  nw_connection_set_queue(conn, dispatch_get_main_queue());
  nw_connection_start(conn);

  dispatch_data_t data = dispatch_data_create("lualamp", 7, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  nw_connection_send(conn, data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, ^(nw_error_t _Nullable error) {
    (void)error;
  });
}

static NSString* get_settings_url_for_pane(NSString *pane) {
  if ([pane isEqualToString:@"local_network"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork";
  } else if ([pane isEqualToString:@"accessibility"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
  } else if ([pane isEqualToString:@"screen_recording"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture";
  } else if ([pane isEqualToString:@"full_disk_access"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles";
  } else if ([pane isEqualToString:@"notifications"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications";
  } else if ([pane isEqualToString:@"camera"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera";
  } else if ([pane isEqualToString:@"microphone"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone";
  } else if ([pane isEqualToString:@"bluetooth"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth";
  } else if ([pane isEqualToString:@"location"]) {
    return @"x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices";
  }
  return @"x-apple.systempreferences:com.apple.preference.security";
}

int f_macos_get_permission_status(lua_State *L) {
  @autoreleasepool {
    const char *perm = luaL_checkstring(L, 1);
    if (strcmp(perm, "accessibility") == 0) {
      BOOL trusted = AXIsProcessTrusted();
      lua_pushstring(L, trusted ? "granted" : "denied");
      return 1;
    } else if (strcmp(perm, "screen_recording") == 0) {
      if (@available(macOS 10.15, *)) {
        BOOL trusted = CGPreflightScreenCaptureAccess();
        lua_pushstring(L, trusted ? "granted" : "denied");
      } else {
        lua_pushstring(L, "granted");
      }
      return 1;
    } else if (strcmp(perm, "camera") == 0) {
      AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
      if (st == AVAuthorizationStatusAuthorized) {
        lua_pushstring(L, "granted");
      } else if (st == AVAuthorizationStatusDenied) {
        lua_pushstring(L, "denied");
      } else if (st == AVAuthorizationStatusRestricted) {
        lua_pushstring(L, "restricted");
      } else {
        lua_pushstring(L, "not_determined");
      }
      return 1;
    } else if (strcmp(perm, "microphone") == 0) {
      AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
      if (st == AVAuthorizationStatusAuthorized) {
        lua_pushstring(L, "granted");
      } else if (st == AVAuthorizationStatusDenied) {
        lua_pushstring(L, "denied");
      } else if (st == AVAuthorizationStatusRestricted) {
        lua_pushstring(L, "restricted");
      } else {
        lua_pushstring(L, "not_determined");
      }
      return 1;
    } else if (strcmp(perm, "full_disk_access") == 0) {
      NSString *home = NSHomeDirectory();
      NSString *tccPath = [home stringByAppendingPathComponent:@"Library/Application Support/com.apple.TCC/TCC.db"];
      int fd = open([tccPath UTF8String], O_RDONLY);
      if (fd >= 0) {
        close(fd);
        lua_pushstring(L, "granted");
        return 1;
      }
      NSString *safariPath = [home stringByAppendingPathComponent:@"Library/Safari/CloudTabs.db"];
      fd = open([safariPath UTF8String], O_RDONLY);
      if (fd >= 0) {
        close(fd);
        lua_pushstring(L, "granted");
        return 1;
      }
      lua_pushstring(L, "denied");
      return 1;
    } else if (strcmp(perm, "local_network") == 0) {
      lua_pushstring(L, "not_determined");
      return 1;
    } else if (strcmp(perm, "notifications") == 0) {
      lua_pushstring(L, "granted");
      return 1;
    }
    lua_pushstring(L, "unsupported");
    return 1;
  }
}

int f_macos_request_permission(lua_State *L) {
  @autoreleasepool {
    const char *perm = luaL_checkstring(L, 1);
    if (strcmp(perm, "accessibility") == 0) {
      NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
      BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
      lua_pushboolean(L, trusted);
      return 1;
    } else if (strcmp(perm, "screen_recording") == 0) {
      if (@available(macOS 10.15, *)) {
        BOOL trusted = CGRequestScreenCaptureAccess();
        lua_pushboolean(L, trusted);
      } else {
        lua_pushboolean(L, true);
      }
      return 1;
    } else if (strcmp(perm, "camera") == 0) {
      [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        (void)granted;
      }];
      lua_pushboolean(L, true);
      return 1;
    } else if (strcmp(perm, "microphone") == 0) {
      [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        (void)granted;
      }];
      lua_pushboolean(L, true);
      return 1;
    } else if (strcmp(perm, "local_network") == 0) {
      const char *target = luaL_optstring(L, 2, "192.168.1.1");
      trigger_local_network_prompt(target);
      lua_pushboolean(L, true);
      return 1;
    } else if (strcmp(perm, "full_disk_access") == 0) {
      NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"];
      BOOL ok = [[NSWorkspace sharedWorkspace] openURL:url];
      lua_pushboolean(L, ok);
      return 1;
    } else if (strcmp(perm, "notifications") == 0) {
      NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"];
      BOOL ok = [[NSWorkspace sharedWorkspace] openURL:url];
      lua_pushboolean(L, ok);
      return 1;
    }
    lua_pushboolean(L, false);
    return 1;
  }
}

int f_macos_open_settings_pane(lua_State *L) {
  @autoreleasepool {
    const char *str = luaL_checkstring(L, 1);
    NSString *pane = [NSString stringWithUTF8String:str];
    NSString *urlString = nil;
    if ([pane hasPrefix:@"x-apple.systempreferences:"] || [pane hasPrefix:@"http://"] || [pane hasPrefix:@"https://"]) {
      urlString = pane;
    } else {
      urlString = get_settings_url_for_pane(pane);
    }
    NSURL *url = [NSURL URLWithString:urlString];
    BOOL ok = [[NSWorkspace sharedWorkspace] openURL:url];
    lua_pushboolean(L, ok);
    return 1;
  }
}


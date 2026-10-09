#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <lua.h>

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

@interface LuaLampMenuTarget : NSObject
- (void)menuItemClicked:(NSMenuItem *)sender;
@end

@implementation LuaLampMenuTarget
- (void)menuItemClicked:(NSMenuItem *)sender {
  NSString *cmd = (NSString *)[sender representedObject];
  if (cmd) {
    push_pending_menu_command([cmd UTF8String]);
  }
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
    if (mainMenu && [mainMenu numberOfItems] > 0) {
      return;
    }
    if (!mainMenu) {
      mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
      [NSApp setMainMenu:mainMenu];
    }

    LuaLampMenuTarget *target = get_menu_target();

    // The macOS Application Menu (Item 0)
    // The OS automatically displays CFBundleName / ProcessName ("Lua Lamp") as the title.
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Lua Lamp"];
    [appMenuItem setSubmenu:appMenu];

    // About Lua Lamp
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About Lua Lamp"
                                                       action:@selector(menuItemClicked:)
                                                keyEquivalent:@""];
    [aboutItem setTarget:target];
    [aboutItem setRepresentedObject:@"app:about"];
    [appMenu addItem:aboutItem];

    [appMenu addItem:[NSMenuItem separatorItem]];

    // Settings… (Cmd+,)
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings…"
                                                          action:@selector(menuItemClicked:)
                                                   keyEquivalent:@","];
    [settingsItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [settingsItem setTarget:target];
    [settingsItem setRepresentedObject:@"app:open-settings"];
    [appMenu addItem:settingsItem];

    [appMenu addItem:[NSMenuItem separatorItem]];

    // Services
    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    [servicesItem setSubmenu:servicesMenu];
    [appMenu addItem:servicesItem];
    [NSApp setServicesMenu:servicesMenu];

    [appMenu addItem:[NSMenuItem separatorItem]];

    // Hide Lua Lamp (Cmd+H)
    NSMenuItem *hideItem = [[NSMenuItem alloc] initWithTitle:@"Hide Lua Lamp"
                                                      action:@selector(hide:)
                                               keyEquivalent:@"h"];
    [hideItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [appMenu addItem:hideItem];

    // Hide Others (Option+Cmd+H)
    NSMenuItem *hideOthersItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                            action:@selector(hideOtherApplications:)
                                                     keyEquivalent:@"h"];
    [hideOthersItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    [appMenu addItem:hideOthersItem];

    // Show All
    NSMenuItem *showAllItem = [[NSMenuItem alloc] initWithTitle:@"Show All"
                                                         action:@selector(unhideAllApplications:)
                                                  keyEquivalent:@""];
    [appMenu addItem:showAllItem];

    [appMenu addItem:[NSMenuItem separatorItem]];

    // Quit Lua Lamp (Cmd+Q)
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Lua Lamp"
                                                      action:@selector(menuItemClicked:)
                                               keyEquivalent:@"q"];
    [quitItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [quitItem setTarget:target];
    [quitItem setRepresentedObject:@"app:quit"];
    [appMenu addItem:quitItem];
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

    LuaLampMenuTarget *target = get_menu_target();
    int num_menus = (int)lua_rawlen(L, 1);

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
                           [nsTitle caseInsensitiveCompare:@"App"] == NSOrderedSame;

          NSMenuItem *menuItem = nil;
          NSMenu *submenu = nil;

          if (isAppMenu) {
            // Use the standard system application menu at index 0. Never create a duplicate!
            menuItem = [mainMenu itemAtIndex:0];
            submenu = [menuItem submenu];
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
              [mainMenu addItem:menuItem];
            } else {
              submenu = [menuItem submenu];
              if (!submenu) {
                submenu = [[NSMenu alloc] initWithTitle:nsTitle];
                [menuItem setSubmenu:submenu];
              }
            }

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
                      if ([existing.title isEqualToString:itemTitle]) {
                        subItem = existing;
                        break;
                      }
                    }
                  }

                  if (!subItem) {
                    subItem = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                         action:@selector(menuItemClicked:)
                                                  keyEquivalent:itemKey];
                    if (isAppMenu) {
                      // Insert before the last separator/Quit item if possible
                      NSInteger insIdx = MAX(0, [submenu numberOfItems] - 2);
                      [submenu insertItem:subItem atIndex:insIdx];
                    } else {
                      [submenu addItem:subItem];
                    }
                  } else {
                    [subItem setKeyEquivalent:itemKey];
                  }

                  [subItem setKeyEquivalentModifierMask:itemMask];
                  [subItem setTarget:target];
                  if (cmd_str) {
                    [subItem setRepresentedObject:[NSString stringWithUTF8String:cmd_str]];
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

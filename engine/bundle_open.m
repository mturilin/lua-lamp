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

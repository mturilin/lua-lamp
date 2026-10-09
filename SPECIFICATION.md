# Lua Lamp — Specification & Intent Invariant Document

> **Document Status**: Authoritative Source of Truth  
> **Application**: Lua Lamp (Cross-Platform Generic Application Development Platform based on SDL3)  
> **Runtime Foundation**: Lua 5.4 + SDL3 + FreeType2 + PCRE2 Host Engine

---

## 1. Executive Summary & Vision

**Lua Lamp** is a clean, modern, zero-bloat generic desktop application development platform built on **Lua** and **SDL3**.

It serves dual purposes:
1. **Immediate Starter Presentation**: Out of the box, it displays a responsive, centered "Hello, World!" stage card featuring animated glowing lamp iconography, live telemetry, and interactive click ripples.
2. **Generic Application Framework**: Under the hood, Lua Lamp bundles the complete, battle-tested UI framework created by Lite XL (under the MIT license) alongside the Lite XL Widgets library. Developers can immediately build native multi-window desktop applications with split panes, dockable views, modern buttons, text inputs, toggles, checkboxes, dialogs, scrollbars, context menus, and command palettes—all rendered at 60 FPS on SDL3 with zero external binary dependencies.

---

## 2. Protected Intent Invariants

### Invariant 1: Blank Canvas Centering
- On launch, the window displays a centered "Hello, World!" stage card against a clean canvas.
- The stage card remains centered dynamically regardless of window resizing or High-DPI display scaling.
- The canvas illustrates live interactive feedback: current display scale ratio (e.g. `Scale: 2x (200%)`), mouse coordinates `(x, y)`, window dimensions `w x h`, frame rate, and animated click ripples.
- The display scale ratio is also dynamically surfaced in the stage card's technology pill badges and native window title bar (`Lua Lamp — Hello World (<scale> Scale)`).

### Invariant 2: Zero External Binary Dependency & MIT UI Framework Integration
- **Zero Binary Dependency**: Lua Lamp **DOES NOT** depend on Lite XL binaries, CLI tools, or external installations. The native C host engine (`engine/`) compiles independently from source, statically embedding Lua 5.4.7 and bundling `libSDL3.0.dylib`.
- **Bundled MIT UI Framework Layer**: Lua Lamp bundles Lite XL's pure-Lua UI framework and Widgets library (MIT license) in `runtime/` for building generic desktop software:
  - `core.object`: Object-oriented prototype inheritance (`Object:extend()`).
  - `core.view`: Base visual component with bounds, clipping, smooth scrolling, cursor styling, and event handlers.
  - `core.node`: Tree-based split-pane layout manager (horizontal/vertical splits, tabs, draggable dividers).
  - `core.rootview`: Top-level window manager and event dispatcher.
  - `core.scrollbar`: Smooth animated scrollbars.
  - `core.contextmenu`: Contextual popup menus.
  - `core.nagview`: Notification banners and modal toasts.
  - `core.command` & `core.keymap`: Command palette and declarative keyboard shortcuts.
  - `core.common`: Math, color manipulation, path, and text helpers.
  - `core.config` & `core.style`: Global style tokens and theme management.
  - `core.docview` & `core.doc`: Syntax-highlighted rich text views and document models.
  - `widget` / `libraries.widget`: Ready-to-use GUI controls (`Button`, `TextBox`, `CheckBox`, `Toggle`, `Label`, `ListBox`, `TreeList`, `SelectBox`, `ProgressBar`, `NumberBox`, `Dialog`, `MessageBox`, etc.).

### Invariant 3: Native Cross-Platform Packaging
- **macOS**: Must produce a 100% standalone `Lua Lamp.app` bundle in `dist/` and distributable `dist/LuaLamp-1.0.0.dmg` with:
  - Native Mach-O executable in `Contents/MacOS/lualamp`.
  - Self-contained `Contents/MacOS/libSDL3.0.dylib` linked via `@executable_path/libSDL3.0.dylib`.
  - Bundled UI framework, widgets, and themes in `Contents/Resources/`.
  - Multi-resolution Retina icon `Contents/Resources/icon.icns` (16x16 through 1024x1024).
  - Standalone `Info.plist` with proper bundle identifiers (`com.lualamp.app`).
  - Recursive quarantine clearing (`xattr -cr`) and ad-hoc code signing (`codesign --force --deep -s -`).
- **Linux**: Must produce a standalone portable directory `lualamp-linux-$ARCH` and `.tar.gz` in `dist/` with:
  - Native ELF executable in `bin/lualamp`.
  - Self-contained `data/` directory housing all Lua code, UI framework, widgets, fonts, and assets.
  - Freedesktop-compliant `lualamp.desktop` and icons.

### Invariant 4: Non-Blocking Asynchronous Execution
- Background tasks, subprocesses, timers, or network probes must run inside coroutines scheduled via `core.add_thread`.
- The 60 FPS event loop in `core.run()` must never be blocked by synchronous sleep or blocking I/O.
- Power-saving frame pacing uses `system.wait_event(sleep_time)`.

### Invariant 5: High-DPI & Scaling Contract
- **Automatic System DPI Detection (Zero Input Requirement)**:
  - On launch, the system automatically detects the display scale factor of the current monitor from the OS/display compositor using native SDL3 APIs (`system.get_window_scale()`, `system.get_display_scale()`, and macOS AppKit `[NSScreen backingScaleFactor]`).
  - No manual inputs or prompts: the user is never asked for aspect ratios or screen resolutions.
  - Automatic detection properly scales typography and UI widgets on 4K / High-DPI displays (e.g. 2.0x, 1.5x, 1.75x, 3.0x).
- **Environment Variable Overrides**:
  - Optional explicit overrides via `LUALAMP_SCALE`, `LITE_SCALE`, `GDK_SCALE`, or `QT_SCALE_FACTOR` take precedence if defined.
- **Dynamic Multi-Monitor Rescaling (`scalechanged`)**:
  - When a window is dragged between displays with differing scale factors (e.g. from a standard 1080p display to a 4K display) or display scaling settings change, the native host generates `"scalechanged"` events (`SDL_EVENT_WINDOW_DISPLAY_CHANGED` and `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`).
  - `core.rescale()` dynamically reloads typography, updates `style.scale`, and refits view bounds at 60 FPS without restarting.
- **Proportional Geometry Contract**:
  - All font sizes, margins, padding, and UI bounding boxes must scale proportionally with `SCALE`.

### Invariant 6: Automated Verification Contract
- Every distribution must pass the automated headless test suite (`bin/lualamp --test` or `tests/test_lualamp.lua`) across all 11 stages with zero assertion failures.
- Headless execution tests engine boot, font loading, theme toggling, canvas animation state, vector drawing, event dispatching, UI framework widget initialization (`Object`, `View`, `Node`, `RootView`, `Widget`, `Button`, `Label`, `Toggle`, `TextBox`, `Dialog`), automatic display scale detection, dynamic `scalechanged` rescaling, unified menu registration, command dispatching, and extensible settings modal dialog operations.

### Invariant 7: Optical Baseline & UI Alignment Invariant
- Text, labels, and badges must never be vertically aligned by naive line-height division alone (`math.floor((h - font:get_height()) / 2)`), which produces an optical upward drift of 1–2px due to Latin font descender reservations.
- All centered UI labels, numerals, and badges must apply optical baseline compensation (`math.floor(1.2 * SCALE)`).
- Icons and labels must be measured independently with decoupled optical vertical centers.
- Interactive controls must use borderless translucent fills (resting/hover/active) rather than high-contrast 1px wireframe outlines.
- All rounded vector curves must compute fractional area coverage for anti-aliasing. See [`AGENTS.md`](file:///Users/mturilin/Dev/lua-lamp/AGENTS.md) for full protocol.

### Invariant 8: Unified Cross-Platform Menu Architecture
- **macOS Top-of-Screen System Menu**: On macOS, menus MUST be rendered in the native top-of-screen menu bar using AppKit `NSMenu` (`[NSApp mainMenu]`), matching Human Interface Guidelines.
  - **Single Application Menu at Index 0**: The macOS system Application menu (`[mainMenu itemAtIndex:0]`) is the sole host for application-level actions. The system automatically titles it with the bundle/process name ("Lua Lamp"). Custom application menus MUST NOT add a redundant duplicate "Lua Lamp" menu to `mainMenu`.
  - **Autoenables & Protocol Validation Contract**: `[mainMenu setAutoenablesItems:NO]` and `[appMenu setAutoenablesItems:NO]` ensure items are never silently grayed out by AppKit's responder-chain heuristics. The C menu target implements `NSMenuItemValidation` and `NSUserInterfaceValidations` (`validateMenuItem:` returning `YES`).
  - **Application Menu Item Wiring**: Standard items (*About Lua Lamp*, *Settings…* <kbd>Cmd+,</kbd>, *Quit* <kbd>Cmd+Q</kbd>) are explicitly wired to target actions, command representations (`app:open-settings`, `app:about`, `app:quit`), and enabled states.
  - **Extensible Downstream Menu Merging**: Dynamic menu sync in `f_set_native_menu` recognizes application menu registrations (`"Lua Lamp"`, `"Application"`, `"App"`, process name, or `is_app_menu = true`) and merges new items into the native Application Menu without duplicates.
  - Native menus dispatch commands (`"app:open-settings"`, `"app:about"`, `"canvas:toggle-theme"`, `"app:quit"`) as `"menu"` SDL events into `core.on_event()`.
- **Linux In-Window Menu Bar**: On non-macOS platforms (Linux, Windows), menus MUST be rendered as an in-window horizontal bar at the top of the canvas via `src/menubar.lua`.
  - Dropdown lists support borderless translucent pills, hover states, subpixel rounded bounds, optical baseline compensation, and shortcut badges.
- **Menu Registry & Extensibility**: All application scripts can dynamically register categories and menu items via `menu:register(category, items)` and bind actions via `menu:bind(command_id, handler)`.

### Invariant 9: Extensible Modal Settings Dialog Contract
- The Settings screen MUST be presented as a separate floating modal window (`src/settings_dialog.lua`), not an inline replacement of the canvas.
- Dimensions: `math.floor(640 * SCALE)` width by `math.floor(430 * SCALE)` height, dynamically centered or draggable by the title bar.
- Closes cleanly via <kbd>Esc</kbd>, close button `[✕]`, `[Close]` footer button, or clicking outside on the modal dimming backdrop.
- **Core Settings Tabs**:
  1. **Display & Scale**: Live scaling multiplier switcher (`Auto`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`, `2.5x`) that executes `core.rescale()` immediately at 60 FPS without restarting, alongside hardware display telemetry.
  2. **Typography**: Font family selector (`Public Sans`, `Source Sans 3`), size presets (`Compact`, `Standard`, `Large`), and live TrueType rendering preview box.
  3. **Appearance**: Color scheme toggle (Dark Mode vs. Light Mode) and animated lamp filament toggle.
- **Extensible Plugin Tabs**: Applications and plugins can extend the Settings dialog with custom tabs via `settings:register_section(id, title, icon, render_fn)`.

### Invariant 10: Mini-Flutter Application Framework Facade Contract
- Lua Lamp provides a standardized developer facade (`src/framework.lua`) exposing:
  - First-class UI widgets: `Widget`, `Button`, `Label`, `Toggle`, `CheckBox`, `TextBox`, `NoteBook`, `SelectBox`, `ListBox`, `ScrollBar`, `ProgressBar`, `ColorPicker`, `MessageBox`, `Dialog`.
  - Drawing & vector primitives: `UI` (anti-aliased rounded boxes, optical baseline text, circles, pill badges, `draw_button`, `draw_segmented_track`).
  - Tabler icons registry: `Icons`.
  - System services: `Menu`, `Settings`, `Canvas`, `Style`, `add_thread`, `rescale`, `get_scale`.

### Invariant 11: Pinglet Button Highlight Standard
- All interactive buttons, segmented control selectors, and toggles across Lua Lamp follow the **Pinglet Button Highlight Design System**:
  1. **The Borderless Surface Principle**: Controls NEVER use 1px wireframe border outlines. All states (resting, hover, active) use cohesive filled surfaces with subpixel anti-aliased rounded corners.
  2. **Segmented Control Capsule Track**: Related options (e.g. scale presets `Auto`, `1.0x`, `2.0x`, font families, size presets) sit within a sunken/recessed capsule track (`c.track_bg`).
  3. **Active Solid Pill (`variant = "solid"`)**: The selected item (like Pinglet `60s`) renders as a vibrant filled pill (`c.btn_accent_bg` sky-400 `#38bdf8` or `c.btn_gold_bg`) with high-contrast inverted dark text (`c.btn_accent_text` `#0c1018`), SemiBold weight, zero border stroke, and optical baseline shift.
  4. **Active Luminous Tinted Pill (`variant = "tinted"`)**: Toggled/action items (like Pinglet `123 Follow`, `+ Add Target`, and Lamp toggle) render as luminous translucent tinted pills (`c.btn_tint_bg` / `c.btn_gold_tint_bg`) with glowing accent text and icon (`c.btn_tint_text`), zero border stroke.
  5. **Translucent Hover Highlight**: Unselected items illuminate smoothly on hover (`c.surface_hover` / `c.btn_tint_hover`) without wireframes.
  6. **Decoupled Icon & Label Geometry**: Text and icons calculate independent optical centerlines (`ui.draw_centered_icon_and_text`) to eliminate typographic baseline drift.

### Invariant 12: Native macOS Permissions Framework Contract
- **Zero-Block Native Privacy & System Permissions**:
  - Lua Lamp provides a native macOS privacy authorizations and permissions framework accessible via `framework.Permissions` (and `src/permissions.lua`).
  - **Native C & Objective-C Host Integration**:
    - `system.macos_get_permission_status(perm)` queries real-time OS authorization without blocking the event loop:
      - `accessibility`: Queries `AXIsProcessTrusted()`.
      - `screen_recording`: Queries `CGPreflightScreenCaptureAccess()`.
      - `camera`: Queries `[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]`.
      - `microphone`: Queries `[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]`.
      - `full_disk_access`: Tests read access against protected TCC database / user safari stores.
      - `local_network`: Tracks Bonjour / UDP connectivity state.
      - `notifications`: Returns notification delivery entitlement status.
    - `system.macos_request_permission(perm, options)` initiates native authorization flows:
      - `accessibility`: Invokes `AXIsProcessTrustedWithOptions` with prompt dictionary.
      - `screen_recording`: Invokes `CGRequestScreenCaptureAccess()`.
      - `camera` / `microphone`: Invokes `[AVCaptureDevice requestAccessForMediaType:completionHandler:]`.
      - `local_network`: Triggers Bonjour discovery (`DNSServiceBrowse`, `nw_browser_t`) and UDP gateway ping (`nw_connection_t`), matching the companion helper pattern.
      - `full_disk_access`: Seamlessly guides the user by opening the target System Settings pane.
    - `system.macos_open_settings_pane(pane)` executes instant deep-linking into exact macOS System Settings panes using `x-apple.systempreferences:` URLs via `[[NSWorkspace sharedWorkspace] openURL:]`.
  - **Asynchronous Coroutine Observation**:
    - `permissions.request(perm, options, callback)` steps non-blocking poll loops via `core.add_thread` and yields control across frames until user consent is captured.
  - **Native Companion Binary Packaging**:
    - Standalone `Contents/MacOS/netauth` helper and `Contents/Resources/libnetauth.dylib` are built from `engine/netauth.m` directly into the `.app` bundle (both for Lua Lamp and any downstream application packaged via `scripts/package_app.sh`).
  - **Native-Feeling UI Components**:
    - `permissions.create_banner(perm, options)`: Renders an inline warning card conforming to Rule 1 and Rule 2 (borderless surface, optical baseline shift, tinted button).
    - `permissions.register_settings_tab()`: Automatically registers a live "Permissions" tab in `framework.Settings` (`Cmd+,`) displaying real-time authorization badges (`Granted`, `Open Settings`). Auto-wired during `core.init()` on macOS.
  - **Framework Level Convenience Accessors**:
    - `framework.get_permission_status(perm, options)`: Returns authorization status string.
    - `framework.is_permission_granted(perm)`: Convenience boolean test.
    - `framework.request_permission(perm, options, callback)`: Non-blocking asynchronous consent flow.
    - `framework.create_permission_banner(perm, options)`: Factory for Pinglet-standard inline permission warning banners.
  - **Declarative Permissions Integration**:
    - Supported in `app.json` (`"permissions": ["local_network", "accessibility"]`) and `framework.App { permissions = { "local_network" } }`.
    - Engine automatically initiates non-blocking preflight consent checks on boot without freezing UI frames.
  - **Cross-Platform Safety**:
    - On Linux/Windows or headless environments, permission queries safely degrade to `"granted"` or `"unsupported"`, preventing unhandled exceptions.

### Invariant 13: Universal Downstream Application SDK & Packaging Pipeline
- **Platform SDK & Dependency Decoupling**:
  - Downstream applications built on Lua Lamp (such as Pinglet or custom developer tools) MUST NOT clone or vendor the C engine, SDL3 build scripts, or core runtime files.
  - Lua Lamp operates as a central Platform SDK providing runtime execution (`lualamp run <dir>`), project scaffolding (`lualamp init <dir> [name]`), and native distribution packaging (`lualamp build <dir> [options]`).
- **Application Project Manifest (`app.json`)**:
  - Downstream projects define metadata via `app.json` (specifying `name`, `displayName`, `identifier`, `version`, `entry`, `icon`, `permissions`, and initial `window` dimensions).
  - The runtime automatically reads `app.json` to configure window titles, sizes, system permissions, and entry scripts without boilerplate.
- **Declarative `framework.App` API**:
  - Applications initialize via `framework.App { name, title, width, height, menu, settings, permissions, initial_view }` and mount views directly into the root view hierarchy.
- **Universal Native Packager (`scripts/package_app.sh`)**:
  - **macOS (`--macos` / `--dmg`)**: Produces a 100% standalone native `<AppName>.app` bundle and compressed `<AppName>-<Version>.dmg`. Automatically injects the Mach-O binary (renamed to the app name), embeds `libSDL3.0.dylib` with `@executable_path` load commands, compiles the `netauth` companion helper and `libnetauth.dylib`, generates Retina `.icns` icons, writes branded `Info.plist` with full privacy usage strings (`NSLocalNetworkUsageDescription`, `NSBonjourServices`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`), clears quarantine flags, and ad-hoc codesigns.
  - **Linux (`--linux`)**: Produces a self-contained portable directory `<AppName>-linux-$ARCH/` and `<AppName>-linux-$ARCH.tar.gz` with native ELF executable, `data/` assets, `.desktop` integration, and icon integration.
- **Zero-Dependency End-User Distribution**:
  - Packaged applications require zero external dependencies: end users do not need Lua, SDL, or Homebrew installed.

### Invariant 14: ScrollView Container & Component Gallery Testbed
- **First-Class Reusable `ScrollView` (`framework.ScrollView` / `src/scroll_view.lua`)**:
  - Provides a lightweight, high-performance scrollable container conforming to the architecture of Flutter (`SingleChildScrollView`) and Avalonia (`ScrollViewer`).
  - **Scissor Viewport Clipping**: Wraps child drawing between `sv:begin_clip(x, y, w, h, content_h)` and `sv:end_clip()` using `renderer.set_clip_rect` and returning a translated local origin `(x, y - scroll_y)`.
  - **Smooth 60 FPS Damping Interpolation**: Scrolling follows exponential damping (`scroll_y = scroll_y + (scroll_to_y - scroll_y) * 0.32`) on frame updates.
  - **macOS-Style Capsule Scrollbar**: Renders an overlay rounded scrollbar thumb with dynamic width expansion on hover/drag (from 4px to 7px), proportional track height mapping, and idle auto-fade (`fade_alpha`).
  - **Coordinate Translation**: Provides `sv:to_content_y(py)` and `sv:is_in_viewport(px, py)` to map mouse and click coordinates accurately into scrollable content spaces regardless of scroll offset.
  - **Modal Integration**: Utilized in the Settings "Permissions" dialog tab with sticky header and sticky "Refresh Status" footer to eliminate card overflow and guarantee full click accessibility.
- **Component Showcase & Gallery Testbed (`src/gallery.lua`)**:
  - Primary default view mounted in `CanvasView` serving as a comprehensive live testbed and showcase of all framework controls.
  - Features dual-mode switching via top-bar segmented pill (`Gallery` vs `Canvas` classic lamp stage card).
  - Categorized sidebar: Buttons & Badges, Sliders & Progress, Toggles & Checkboxes, Text Inputs, Scrollable Panels, Banners & Modals, Iconography & Font Glyphs, All Components.
  - Live interactive controls: draggable sliders (`ui.draw_slider`), macOS/iOS animated toggles (`ui.draw_toggle`), accent checkboxes (`ui.draw_checkbox`), progress bars (`ui.draw_progressbar`), interactive text input with focus ring and cursor (`ui.draw_input_box`), nested scroll views, and privacy warning banners.
  - **Dynamic On-Screen Hitbox Registration Standard**:
    - Interactive controls dynamically register exact screen pixel coordinates (`self:register_hitbox`) during the drawing pass, eliminating coordinate drift and magic offset desynchronization.
    - **Generous Hit Targets**: Toggles and checkboxes feature full-width hit targets spanning both the control pill/box and the accompanying text label (`tw + gap + label_w`), conforming to native macOS desktop accessibility guidelines.
    - **Viewport Scissor Integration**: Clicks are validated against `scroll_view:is_in_viewport(px, py)` to guarantee controls scrolled above or below the fold cannot receive phantom clicks.
    - **Adaptive Dual/Single-Column Layout**: Toggles & Checkboxes dynamically adapt between a two-column grid (`inner_w >= 500 * s`) and an expanded single-column stack on narrow viewports, preventing clipping or overflow.
- **Verified Tabler Icon Font Mapping (`src/icons.lua`)**:
  - All icon constants map directly to exact UTF-8 byte sequences verified against native FreeType cmap in `fonts/tabler-icons.ttf` (`shield`, `shield_check`, `camera`, `microphone`, `folder`, `accessible`, `external_link`, `video`, `layout`, `box`, `list`, `adjustments`, `palette`, `typography`, etc.).

### Invariant 15: Framework Code Documentation & Architectural Clarity Contract
- All framework source code (`core.lua`, `src/*.lua`, `runtime/**/*.lua`) must adhere to strict documentation standards:
  1. **Top-of-File Header**: Every source file must begin with a structured header describing the module's identity, architectural purpose, key invariants/responsibilities, and exported contracts.
  2. **Function Purpose & Parameter Contracts**: Every public or non-trivial function/method must be documented with its purpose, `@param` (name, type, coordinate frame/units), `@return` semantics, and side effects.
  3. **Inline Explanations for Non-Trivial Logic**: Non-trivial algorithms, coordinate transforms, DPI scaling math, subpixel antialiasing/descender compensations, coroutine damping, event interception, and error fallbacks must include explanatory comments explaining the rationale. Simple, trivial assignments do not require noise comments.

---

## 3. Architecture & Directory Blueprint

```
lua-lamp/
├── .github/workflows/
│   └── build.yml               # Automated CI/CD builds for macOS & Linux
├── bin/
│   ├── lualamp                 # Development & CLI launcher script
│   └── lualamp_bin             # Compiled native C/SDL3 host binary (gitignored)
├── dist/                       # Output build artifacts (.app, .dmg, .tar.gz)
├── engine/                     # Vendored native C/SDL3 host engine sources
│   ├── api/                    # C-bindings for system, renderer, font, process, dirmonitor
│   ├── lua/                    # Vendored Lua 5.4.7 core interpreter sources
│   ├── main.c                  # Native host entry point and SDL3 initialization
│   ├── renderer.c              # Software / SDL3 2D rendering pipeline
│   ├── renwindow.c             # SDL3 window management and High-DPI handling
│   ├── bundle_open.m           # macOS bundle resources, menus & native permission bindings
│   ├── netauth.m               # Standalone companion helper for local network auth
│   └── arena_allocator.c       # Fast memory arena allocator
├── fonts/                      # Bundled TrueType typography
│   ├── PublicSans-*.ttf        # UI body typography
│   ├── SourceSans3-*.ttf       # Monospace typography
│   ├── tabler-icons.ttf        # Tabler Icons (outline)
│   └── tabler-icons-filled.ttf # Tabler Icons (filled)
├── resources/                  # Application branding and vector assets
├── runtime/                    # Complete UI Framework and Low-Level C-Bindings
│   ├── colors/                 # Prebuilt color themes (default, monokai, solarized, etc.)
│   ├── core/                   # UI Core: Object, View, Node, RootView, ScrollBar, Command, Keymap, DocView
│   ├── libraries/
│   │   └── widget/             # UI Widgets: Button, TextBox, CheckBox, Toggle, Label, Dialog, ListBox, etc.
│   ├── renderer.lua            # Renderer Lua bindings
│   ├── system.lua              # System & window Lua bindings
│   ├── process.lua             # Subprocess Lua bindings
│   ├── regex.lua               # PCRE2 regex Lua bindings
│   └── globals.lua             # Global table helpers
├── scripts/                    # Build, bundling and generation scripts
│   ├── build_engine.sh         # Standalone C/SDL3 native host compiler
│   ├── bundle_macos_app.sh     # Standalone macOS .app packager with embedded libSDL3
│   ├── create_dmg.sh           # Distributable macOS DMG generator
│   ├── bundle_linux.sh         # Standalone Linux portable & AppImage packager
│   ├── build_runtime_linux.sh  # Native Linux C host runtime compiler
│   └── generate_icon.swift     # Procedural macOS .icns and PNG generator
├── src/                        # Modular application code
│   ├── canvas.lua              # Central "Hello World" canvas component
│   ├── canvas_view.lua         # Dual-mode primary RootView component (Gallery / Canvas)
│   ├── framework.lua           # Mini-Flutter developer application framework facade
│   ├── gallery.lua             # Framework component gallery & interactive testbed
│   ├── icons.lua               # Tabler icon codepoints registry
│   ├── menu.lua                # Unified menu registry & cross-platform dispatcher
│   ├── menubar.lua             # In-window borderless menu bar (Linux/Windows)
│   ├── permissions.lua         # Native macOS permissions & privacy authorization framework
│   ├── scroll_view.lua         # High-performance scrollable container with scissor clipping
│   ├── settings_dialog.lua     # Extensible floating modal settings window
│   ├── style.lua               # Theme management (dark/light) & font loader
│   └── ui.lua                  # Reusable drawing primitives & UI components
├── tests/
│   └── test_lualamp.lua        # Headless automated verification suite (Stages 1-14)
├── Dockerfile                  # Containerized Linux build environment
├── LICENSE                     # MIT Open Source License
├── README.md                   # User documentation and guide
├── SPECIFICATION.md            # Intent Invariant Document (this file)
├── AGENTS.md                   # Operational Directives & UI Aesthetics Protocol
├── core.lua                    # Engine core, event loop, coroutines, RootView host
├── init.lua                    # Entry point forwarder
├── install.sh                  # Installs lualamp command to ~/.local/bin
└── LuaLamp.icns                # Multi-resolution macOS iconset
```

---

## 4. Subsystem Contracts

### 4.1 Native Host Engine (`engine/`)
- Pure C / SDL3 host runtime linking FreeType2, PCRE2, and system frameworks.
- Statically embeds Lua 5.4.7 core interpreter.
- Exposes native C modules: `system`, `renderer`, `process`, `regex`, `dirmonitor`.
- Zero external runtime dependency.
- macOS Host Bridge (`bundle_open.m`): Exposes native Cocoa `NSMenu` construction and dispatches menu action selections as `"menu"` SDL events.

### 4.2 Application Engine Core (`core.lua`)
- **`core.get_default_scale()`**: Automatically determines display scaling factor from `system.get_window_scale()`, `system.get_display_scale()`, macOS AppKit `backingScaleFactor`, framebuffer ratio, or environment variable overrides.
- **`core.rescale(new_scale)`**: Dynamically rescales font sizes, layout metrics, and widget tree when display scale changes (`scalechanged`) or when selected in Settings dialog.
- **`core.init()`**: Configures window size, High-DPI scaling factor, initializes fonts, initializes default menus (`menu.init_defaults()`), instantiates `core.root_view` (`RootView`), and sets up the canvas.
- **`core.root_view`**: Top-level container managing split nodes, floating overlays, dialogs, and event routing.
- **`core.push_clip_rect` / `core.pop_clip_rect`**: Nested hierarchical clipping stack.
- **`core.request_cursor(cursor)`**: Dynamic cursor style requests (`arrow`, `ibeam`, `hand`, `sizeh`, `sizev`).
- **`core.on_event(type, a, b, c, d)`**: Routes SDL3 events to `core.root_view` (mouse, keyboard, text input, wheel, scalechanged, menu), modal settings dialog, and in-window menu bar.
- **`core.step_threads()`**: Manages coroutine wake times and asynchronous workers.
- **`core.draw()`**: Composites base canvas, active views/widgets, in-window menu bar (on Linux/Windows), and floating modal settings window.
- **`core.run()`**: 60 FPS event loop with delta-time calculation and power-saving frame sleep.

### 4.3 UI Layer Framework (`runtime/core/` & `runtime/libraries/widget/`)
- **`View`**: Base class for visual components with positioning, size, clip bounds, smooth scrolling, and mouse/keyboard lifecycle hooks.
- **`Node`**: Split pane container supporting horizontal/vertical splits, tabs, and interactive resizing dividers.
- **`Widget`**: Hierarchy-aware base control with parent/child geometry, relative coordinates, hover states, click events, animations, and tooltips.
- **Widget Controls**: Ready-to-use UI controls including `Button`, `TextBox`, `CheckBox`, `Toggle`, `Label`, `Dialog`, `MessageBox`, `InputDialog`, `ListBox`, `TreeList`, `SelectBox`, `ProgressBar`, `NumberBox`, etc.

### 4.4 Style & Theme System (`src/style.lua` & `runtime/core/style.lua`)
- Supports Dark Theme (default) and Light Theme.
- Exposes `style.colors`, `style.set_theme(name)`, and `style.toggle_theme()`.
- Dynamically resolves and loads TTF fonts from `fonts/` (`PublicSans`, `SourceSans3`, `tabler-icons`).

### 4.5 Unified Menu Subsystem (`src/menu.lua` & `src/menubar.lua`)
- Cross-platform menu registry decoupling menu declaration from operating system presentation.
- **macOS**: Translates menu trees into native Cocoa `NSMenu` objects rendered on the macOS top-of-screen bar.
- **Linux / Windows**: Renders a borderless in-window horizontal menu bar with dropdowns, hover highlights, and shortcut badges.
- Exposes `menu:register(category, items)`, `menu:bind(command_id, fn)`, `menu:trigger(command_id)`.

### 4.6 Extensible Modal Settings Subsystem (`src/settings_dialog.lua`)
- Floating modal dialog with background dimming shield, tabbed navigation, and live control panels.
- Live DPI scaling switcher with instant real-time application (`core.rescale()`).
- Typography typeface selector and live glyph preview.
- Theme palette switcher (Dark/Light) and animated lamp toggle.
- Extensibility hook: `settings:register_section(id, title, icon, render_fn)`.

### 4.7 Mini-Flutter Developer Facade (`src/framework.lua`)
- Comprehensive single-import entry point providing access to widgets, drawing primitives, dialogs, menu, and settings.

### 4.8 Vector Drawing Primitives & Text Wrapping Subsystem (`src/ui.lua`)
- **`ui.wrap_text(font, text, max_w)`**: Word-boundary text wrapping calculating exact font widths. Respects existing line breaks, splits multi-word sentences across lines without exceeding `max_w`, and falls back to character-level wrapping for single long words.
- **`ui.draw_wrapped_text(font, text, x, y, max_w, color, line_spacing)`**: Renders wrapped multi-line text and returns `total_h, count` so callers can advance layout coordinates dynamically and prevent label collisions.
- **Subpixel Anti-Aliased Primitives**: `ui.draw_rounded_box`, `ui.draw_circle`, `ui.draw_pill_badge`, `ui.draw_centered_text`, `ui.draw_centered_icon_and_text` with optical baseline compensation.

---

## 5. Keyboard & Input Interactions

| Input | Trigger | Platform | Action |
|:------|:--------|:---------|:-------|
| <kbd>Cmd+,</kbd> | `keypressed` / `menu` | macOS | Open / toggle modal Settings window |
| <kbd>Ctrl+,</kbd> | `keypressed` / `menu` | Linux / Windows | Open / toggle modal Settings window |
| <kbd>Space</kbd> | `keypressed` | All | Toggle central lamp filament glow & bloom |
| <kbd>T</kbd> | `keypressed` | All | Toggle theme between Dark and Light |
| <kbd>F11</kbd> | `keypressed` | All | Toggle Fullscreen window mode |
| <kbd>Left Click</kbd> | `mousepressed` | All | Spawn radial ripple / interact with controls / switch tabs |
| <kbd>Esc</kbd> | `keypressed` | All | Close open modal Settings dialog or menu dropdown / quit |
| <kbd>Cmd+Q</kbd> / <kbd>Ctrl+Q</kbd> | `keypressed` / `menu` | All | Cleanly terminate application |

---

## 6. Build & Packaging Pipelines

### Native Engine Compilation (`./scripts/build_engine.sh`)
1. Validates Homebrew dependencies (`sdl3`, `freetype`, `pcre2`, `libpng`).
2. Compiles `engine/` sources into standalone `bin/lualamp_bin` with static FreeType/PCRE2 linking.

### macOS Bundle (`./scripts/bundle_macos_app.sh`)
1. Builds native C/SDL3 engine via `scripts/build_engine.sh`.
2. Creates `dist/Lua Lamp.app` bundle directory tree.
3. Installs Mach-O binary and embeds `libSDL3.0.dylib` with `@executable_path` dynamic load path rewriting.
4. Installs UI framework, widgets, themes, application source, and fonts into `Contents/Resources/`.
5. Clears quarantine flags (`xattr -cr`) and applies ad-hoc codesign.
6. Deploys bundle to `/Applications/Lua Lamp.app`.

### macOS Disk Image (`./scripts/create_dmg.sh`)
1. Rebuilds fresh `dist/Lua Lamp.app`.
2. Stages drag-and-drop `/Applications` symlink and documentation.
3. Packages compressed `dist/LuaLamp-1.0.0.dmg` via `hdiutil create -format UDZO`.
4. Performs checksum verification (`hdiutil verify`).

### Linux (`./scripts/bundle_linux.sh`)
1. Resolves Linux ELF runtime binary.
2. Creates `dist/lualamp-linux-$ARCH/` containing `bin/lualamp`, `data/` (with UI framework & widgets), `lualamp.desktop`, and icon assets.
3. Packages portable `lualamp-linux-$ARCH.tar.gz`.
4. Optionally produces `.AppImage` if `appimagetool` is available.

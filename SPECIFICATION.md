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
- The canvas illustrates live interactive feedback: mouse coordinates `(x, y)`, window dimensions `w x h`, frame rate, and animated click ripples.

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
- Every distribution must pass the automated headless test suite (`bin/lualamp --test` or `tests/test_lualamp.lua`) across all 10 stages with zero assertion failures.
- Headless execution tests engine boot, font loading, theme toggling, canvas animation state, vector drawing, event dispatching, UI framework widget initialization (`Object`, `View`, `Node`, `RootView`, `Widget`, `Button`, `Label`, `Toggle`, `TextBox`, `Dialog`), automatic display scale detection, and dynamic `scalechanged` rescaling.

### Invariant 7: Optical Baseline & UI Alignment Invariant
- Text, labels, and badges must never be vertically aligned by naive line-height division alone (`math.floor((h - font:get_height()) / 2)`), which produces an optical upward drift of 1–2px due to Latin font descender reservations.
- All centered UI labels, numerals, and badges must apply optical baseline compensation (`math.floor(1.2 * SCALE)`).
- Icons and labels must be measured independently with decoupled optical vertical centers.
- Interactive controls must use borderless translucent fills (resting/hover/active) rather than high-contrast 1px wireframe outlines.
- All rounded vector curves must compute fractional area coverage for anti-aliasing. See [`AGENTS.md`](file:///Users/mturilin/Dev/lua-lamp/AGENTS.md) for full protocol.

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
│   ├── bundle_open.m           # macOS bundle resource resolution
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
│   ├── icons.lua               # Tabler icon codepoints registry
│   ├── style.lua               # Theme management (dark/light) & font loader
│   └── ui.lua                  # Reusable drawing primitives & UI components
├── tests/
│   └── test_lualamp.lua        # Headless automated verification suite (Stages 1-9)
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

### 4.2 Application Engine Core (`core.lua`)
- **`core.get_default_scale()`**: Automatically determines display scaling factor from `system.get_window_scale()`, `system.get_display_scale()`, macOS AppKit `backingScaleFactor`, framebuffer ratio, or environment variable overrides.
- **`core.rescale(new_scale)`**: Dynamically rescales font sizes, layout metrics, and widget tree when display scale changes (`scalechanged`).
- **`core.init()`**: Configures window size, High-DPI scaling factor, initializes fonts, instantiates `core.root_view` (`RootView`), and sets up the canvas.
- **`core.root_view`**: Top-level container managing split nodes, floating overlays, dialogs, and event routing.
- **`core.push_clip_rect` / `core.pop_clip_rect`**: Nested hierarchical clipping stack.
- **`core.request_cursor(cursor)`**: Dynamic cursor style requests (`arrow`, `ibeam`, `hand`, `sizeh`, `sizev`).
- **`core.on_event(type, a, b, c, d)`**: Routes SDL3 events to `core.root_view` (mouse, keyboard, text input, wheel, scalechanged) and canvas handlers.
- **`core.step_threads()`**: Manages coroutine wake times and asynchronous workers.
- **`core.draw()`**: Composites base canvas and all active views/widgets in `core.root_view`.
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

---

## 5. Keyboard & Input Interactions

| Input | Trigger | Action |
|:------|:--------|:-------|
| <kbd>Space</kbd> | `keypressed` | Toggle central lamp filament glow & bloom |
| <kbd>T</kbd> | `keypressed` | Toggle theme between Dark and Light |
| <kbd>F11</kbd> | `keypressed` | Toggle Fullscreen window mode |
| <kbd>Left Click</kbd> | `mousepressed` | Spawn expanding radial ripple at click coordinates / trigger widget |
| <kbd>Q</kbd> / <kbd>Esc</kbd> | `keypressed` | Cleanly terminate application |

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

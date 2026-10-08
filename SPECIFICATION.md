# Lua Lamp — Specification & Intent Invariant Document

> **Document Status**: Authoritative Source of Truth  
> **Application**: Lua Lamp (Cross-Platform Lua + SDL3 Application Starter Template)  
> **Runtime Foundation**: Lua 5.4 + SDL3 + FreeType2 + PCRE2 Host Engine

---

## 1. Executive Summary & Vision

**Lua Lamp** is a clean, modern, zero-bloat starter template for building high-performance native desktop applications using **Lua** and **SDL3**.

It provides a "blank canvas" starting point featuring a centered "Hello, World!" welcome screen, animated glowing lamp iconography, live window/mouse telemetry, and a built-in coroutine scheduler. Crucially, Lua Lamp is 100% self-contained: it vendors its own bespoke native C/SDL3 host engine, builds directly from source without any external text-editor binaries (Lite XL), bundles all dynamic dependencies (`libSDL3.0.dylib`), and includes complete multi-platform bundling pipelines for **macOS** (`.app` bundle and `.dmg` disk image) and **Linux** (standalone portable directory, `.desktop` integration, and AppImage/tarball).

---

## 2. Protected Intent Invariants

### Invariant 1: Blank Canvas Centering
- On launch, the window must display a centered "Hello, World!" stage card against a clean canvas.
- The stage card must remain centered dynamically regardless of window resizing or High-DPI display scaling.
- The canvas must illustrate live interactive feedback: mouse coordinates `(x, y)`, window dimensions `w x h`, frame rate, and animated click ripples.

### Invariant 2: Zero Text-Editor & External Binary Dependency
- Lua Lamp **MUST NOT** import or depend on Lite XL binaries or text editor modules (`core.doc`, `core.docview`, `core.statusview`, `core.commandview`, etc.).
- Lua Lamp vendors its complete native C host engine in `engine/` and Lua C-bridge wrappers in `runtime/`.
- All application logic lives in `core.lua` and `src/`.
- The application relies exclusively on the underlying C/SDL3 host runtime primitives (`renderer`, `system`, `process`, `renderer.font`).

### Invariant 3: Native Cross-Platform Packaging
- **macOS**: Must produce a 100% standalone `Lua Lamp.app` bundle in `dist/` and distributable `dist/LuaLamp-1.0.0.dmg` with:
  - Native Mach-O executable in `Contents/MacOS/lualamp`.
  - Self-contained `Contents/MacOS/libSDL3.0.dylib` linked via `@executable_path/libSDL3.0.dylib`.
  - Multi-resolution Retina icon `Contents/Resources/icon.icns` (16x16 through 1024x1024).
  - Standalone `Info.plist` with proper bundle identifiers (`com.lualamp.app`).
  - Recursive quarantine clearing (`xattr -cr`) and ad-hoc code signing (`codesign --force --deep -s -`).
- **Linux**: Must produce a standalone portable directory `lualamp-linux-$ARCH` and `.tar.gz` in `dist/` with:
  - Native ELF executable in `bin/lualamp`.
  - Self-contained `data/` directory housing all Lua code, fonts, and assets.
  - Freedesktop-compliant `lualamp.desktop` and icons.

### Invariant 4: Non-Blocking Asynchronous Execution
- Background tasks, subprocesses, timers, or network probes must run inside coroutines scheduled via `core.add_thread`.
- The 60 FPS event loop in `core.run()` must never be blocked by synchronous sleep or blocking I/O.
- Power-saving frame pacing uses `system.wait_event(sleep_time)`.

### Invariant 5: High-DPI & Scaling Contract
- The global multiplier `SCALE` is resolved during initialization via `LUALAMP_SCALE` or `LITE_SCALE`.
- All font sizes, margins, padding, and UI bounding boxes must scale proportionally with `SCALE`.

### Invariant 6: Automated Verification Contract
- Every distribution must pass the automated headless test suite (`bin/lualamp --test` or `tests/test_lualamp.lua`) with zero assertion failures.
- Headless execution tests engine boot, font loading, theme toggling, canvas animation state, vector drawing, and event dispatching.

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
│   ├── icon.png                # Master 1024x1024 Retina icon
│   ├── lualamp.svg             # Scalable vector icon
│   ├── lualamp.png             # 256x256 Linux desktop icon
│   └── lualamp_*.png           # Multi-resolution PNG icon variants
├── runtime/                    # Low-level Lua C-binding bridge wrappers
│   ├── core/                   # Core bootstrap (start.lua, process.lua, utf8string.lua, bit.lua)
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
│   └── test_lualamp.lua        # Headless automated verification suite
├── Dockerfile                  # Containerized Linux build environment
├── LICENSE                     # MIT Open Source License
├── README.md                   # User documentation and guide
├── SPECIFICATION.md            # Intent Invariant Document (this file)
├── AGENTS.md                   # Operational Directives & UI Aesthetics Protocol
├── core.lua                    # Engine core, event loop, coroutines
├── init.lua                    # Entry point forwarder
├── install.sh                  # Installs lualamp command to ~/.local/bin
└── LuaLamp.icns                # Multi-resolution macOS iconset
```

---

## 4. Subsystem Contracts

### 4.1 Native Host Engine (`engine/`) & Runtime (`runtime/`)
- Pure C / SDL3 host runtime linking FreeType2, PCRE2, and system frameworks.
- Statically embeds Lua 5.4.7 core interpreter.
- Exposes native C modules: `system`, `renderer`, `process`, `regex`, `dirmonitor`.
- Resolves macOS bundle paths via `[NSBundle mainBundle]` only when executing from an `.app` container (`MACOS_RESOURCES`), falling back seamlessly to repository paths in CLI development mode.

### 4.2 Engine Core (`core.lua`)
- **`core.init()`**: Configures window size (default `960x640 * SCALE`), window title, loads typography, and initializes canvas state.
- **`core.on_event(type, a, b, c, d)`**: Dispatches events (`quit`, `resized`, `mousemoved`, `mousepressed`, `keypressed`).
- **`core.step_threads()`**: Manages coroutine wake times and execution.
- **`core.draw()`**: Invokes `canvas.draw(win_w, win_h)`.
- **`core.run()`**: Executes 60 FPS event loop with delta-time `dt` calculation.
- **`core.on_error(err)`**: Catches runtime errors, prints stack traces, writes diagnostic logs, and raises fatal error dialogs.

### 4.3 Blank Canvas Component (`src/canvas.lua`)
- Renders the stage card with:
  - Vector glowing lamp with warm radial bloom.
  - "Hello, World!" heading.
  - "Welcome to Lua Lamp" title and descriptive subtitle.
  - Technology badges (`Lua 5.4`, `SDL3 Platform`, `60 FPS Compositor`).
  - Interactive Theme Toggle and Lamp Pulse buttons.
  - Live coordinate and telemetry readout.
  - Interactive click ripple waves.

### 4.4 Style & Theme System (`src/style.lua`)
- Supports Dark Theme (default) and Light Theme.
- Exposes `style.colors`, `style.set_theme(name)`, and `style.toggle_theme()`.
- Dynamically loads TTF fonts from `fonts/` with graceful fallback handling.

---

## 5. Keyboard & Input Interactions

| Input | Trigger | Action |
|:------|:--------|:-------|
| <kbd>Space</kbd> | `keypressed` | Toggle central lamp filament glow & bloom |
| <kbd>T</kbd> | `keypressed` | Toggle theme between Dark and Light |
| <kbd>F11</kbd> | `keypressed` | Toggle Fullscreen window mode |
| <kbd>Left Click</kbd> | `mousepressed` | Spawn expanding radial ripple at click coordinates |
| <kbd>Q</kbd> / <kbd>Esc</kbd> | `keypressed` | Cleanly terminate application |

---

## 6. Build & Packaging Pipelines

### Native Engine Compilation (`./scripts/build_engine.sh`)
1. Detects Homebrew prefix and validates SDL3, FreeType, PCRE2, and libpng dependencies.
2. Compiles `engine/` sources into standalone `bin/lualamp_bin` with static FreeType/PCRE2 linking.

### macOS Bundle (`./scripts/bundle_macos_app.sh`)
1. Builds native C/SDL3 engine via `scripts/build_engine.sh`.
2. Creates `dist/Lua Lamp.app` bundle directory tree.
3. Installs Mach-O binary and embeds `libSDL3.0.dylib` with `@executable_path` dynamic load path rewriting.
4. Installs runtime bridge scripts from `runtime/`.
5. Copies `core.lua`, `src/`, `fonts/`, and `LuaLamp.icns`.
6. Generates `Info.plist`, clears quarantine flags (`xattr -cr`), and applies ad-hoc codesign.
7. Deploys bundle to `/Applications/Lua Lamp.app`.

### macOS Disk Image (`./scripts/create_dmg.sh`)
1. Rebuilds fresh `dist/Lua Lamp.app`.
2. Stages drag-and-drop `/Applications` symlink and documentation.
3. Packages compressed `dist/LuaLamp-1.0.0.dmg` via `hdiutil create -format UDZO`.
4. Performs checksum verification (`hdiutil verify`).

### Linux (`./scripts/bundle_linux.sh`)
1. Resolves local Linux ELF runtime binary or downloads prebuilt binary from release.
2. Creates `dist/lualamp-linux-$ARCH/` containing `bin/lualamp`, `data/`, `lualamp.desktop`, and icon assets.
3. Packages portable `lualamp-linux-$ARCH.tar.gz`.
4. Optionally produces `.AppImage` if `appimagetool` is available.

# Lua Lamp — Specification & Intent Invariant Document

> **Document Status**: Authoritative Source of Truth  
> **Application**: Lua Lamp (Cross-Platform Lua + SDL2 Application Starter Template)  
> **Runtime Foundation**: Lua 5.4 + SDL2 + FreeType2 Host Platform

---

## 1. Executive Summary & Vision

**Lua Lamp** is a clean, modern, zero-bloat starter template for building high-performance native desktop applications using **Lua** and **SDL2**.

It provides a "blank canvas" starting point featuring a centered "Hello, World!" welcome screen, animated glowing lamp iconography, live window/mouse telemetry, and a built-in coroutine scheduler. Crucially, Lua Lamp includes complete multi-platform bundling pipelines for **macOS** (`.app` bundle with native Retina `.icns`) and **Linux** (standalone portable directory, `.desktop` integration, and AppImage/tarball).

---

## 2. Protected Intent Invariants

### Invariant 1: Blank Canvas Centering
- On launch, the window must display a centered "Hello, World!" stage card against a clean canvas.
- The stage card must remain centered dynamically regardless of window resizing or High-DPI display scaling.
- The canvas must illustrate live interactive feedback: mouse coordinates `(x, y)`, window dimensions `w x h`, frame rate, and animated click ripples.

### Invariant 2: Zero Text-Editor Dependency
- Lua Lamp **MUST NOT** import or depend on Lite XL text editor modules (`core.doc`, `core.docview`, `core.statusview`, `core.commandview`, etc.).
- All application logic lives in `core.lua` and `src/`.
- The application relies exclusively on the underlying C/SDL2 host runtime primitives (`renderer`, `system`, `process`, `renderer.font`).

### Invariant 3: Native Cross-Platform Packaging
- **macOS**: Must produce a 100% standalone `Lua Lamp.app` bundle in `dist/` with:
  - Native Mach-O executable in `Contents/MacOS/lualamp`.
  - Multi-resolution Retina icon `Contents/Resources/icon.icns` (16x16 through 1024x1024).
  - Standalone `Info.plist` with proper bundle identifiers.
  - Ad-hoc code signing.
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
│   └── lualamp                 # Development & CLI launcher script
├── dist/                       # Output build artifacts (.app, .tar.gz, .AppImage)
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
├── scripts/                    # Build, bundling and generation scripts
│   ├── bundle_macos_app.sh     # Standalone macOS .app packager
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

### 4.1 Engine Core (`core.lua`)
- **`core.init()`**: Configures window size (default `960x640 * SCALE`), window title, loads typography, and initializes canvas state.
- **`core.on_event(type, a, b, c, d)`**: Dispatches events (`quit`, `resized`, `mousemoved`, `mousepressed`, `keypressed`).
- **`core.step_threads()`**: Manages coroutine wake times and execution.
- **`core.draw()`**: Invokes `canvas.draw(win_w, win_h)`.
- **`core.run()`**: Executes 60 FPS event loop with delta-time `dt` calculation.
- **`core.on_error(err)`**: Catches runtime errors, prints stack traces, writes diagnostic logs, and raises fatal error dialogs.

### 4.2 Blank Canvas Component (`src/canvas.lua`)
- Renders the stage card with:
  - Vector glowing lamp with warm radial bloom.
  - "Hello, World!" heading.
  - "Welcome to Lua Lamp" title and descriptive subtitle.
  - Technology badges (`Lua 5.4`, `SDL2 Platform`, `60 FPS Compositor`).
  - Interactive Theme Toggle and Lamp Pulse buttons.
  - Live coordinate and telemetry readout.
  - Interactive click ripple waves.

### 4.3 Style & Theme System (`src/style.lua`)
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

### macOS (`./scripts/bundle_macos_app.sh`)
1. Detects available platform runtime binary (`Lite XL.app`, `Pinglet.app`, etc.).
2. Creates `dist/Lua Lamp.app` bundle directory tree.
3. Installs Mach-O binary and Lua C-binding wrappers.
4. Copies `core.lua`, `src/`, `fonts/`, and generates `core/start.lua` and `core/init.lua`.
5. Compiles `LuaLamp.icns` via `scripts/generate_icon.swift`.
6. Generates `Info.plist` and applies ad-hoc codesign.

### Linux (`./scripts/bundle_linux.sh`)
1. Resolves local Linux ELF runtime binary or downloads prebuilt binary from release.
2. Creates `dist/lualamp-linux-$ARCH/` containing `bin/lualamp`, `data/`, `lualamp.desktop`, and icon assets.
3. Packages portable `lualamp-linux-$ARCH.tar.gz`.
4. Optionally produces `.AppImage` if `appimagetool` is available.

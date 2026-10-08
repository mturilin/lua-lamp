# 💡 Lua Lamp — Native Lua & SDL3 Application Starter Template

A modern, high-performance, cross-platform desktop application starter kit built on a **bespoke native Lua 5.4 + SDL3** host engine. Completely self-contained with **zero Lite XL binary dependencies**.

```
+-----------------------------------------------------------------------------------------+
|                                    Lua Lamp — Hello World                               |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|                    +-----------------------------------------------+                    |
|                    |                                               |                    |
|                    |                     (💡)                      |                    |
|                    |               [Glowing Lamp]                  |                    |
|                    |                                               |                    |
|                    |                Hello, World!                  |                    |
|                    |             Welcome to Lua Lamp               |                    |
|                    |  A lightweight Lua & SDL3 starter template    |                    |
|                    |                                               |                    |
|                    | [Lua 5.4] [SDL3 Platform] [60 FPS Compositor] |                    |
|                    |                                               |                    |
|                    |   [ ☀ Light Theme ]     [ Turn Lamp Off ]     |                    |
|                    |                                               |                    |
|                    +-----------------------------------------------+                    |
|                    | Canvas: 960x640 | Mouse: (480, 320) | FPS: 60 |                    |
|                    +-----------------------------------------------+                    |
|                                                                                         |
|       Press <Space> to toggle lamp glow  •  <T> to switch theme  •  <Q> to quit         |
+-----------------------------------------------------------------------------------------+
```

---

## ✨ Features

- **Blank Canvas with "Hello World"**:
  - Clean, responsive canvas card centered dynamically regardless of window resizing or DPI scaling.
  - Interactive glowing lamp with pulsating warm amber filament and volumetric light aura.
  - Live window telemetry: dynamic canvas dimensions, live mouse coordinates, and FPS counter.
  - Interactive click ripple waves expanding outward from cursor clicks.
  - Built-in theme switcher (Dark Mode & Light Mode).
- **100% Independent Native Engine (Zero Lite XL Dependency)**:
  - Vendors its own native C/SDL3 host engine in `engine/` linking FreeType2, PCRE2, and system frameworks.
  - Compiles directly with `clang` via `scripts/build_engine.sh`.
  - Statically embeds Lua 5.4.7 core interpreter.
  - No dependency on external Lite XL binaries or text-editor core modules.
- **Cross-Platform Bundling Out of the Box**:
  - **macOS App Bundle**: One-step script (`./scripts/bundle_macos_app.sh`) generating a standalone `Lua Lamp.app` embedding `libSDL3.0.dylib` with `@executable_path` dynamic load path rewriting, custom Retina `.icns`, and ad-hoc codesigning.
  - **macOS DMG Disk Image**: Automated script (`./scripts/create_dmg.sh`) producing a compressed, verified drag-and-drop `dist/LuaLamp-1.0.0.dmg`.
  - **Linux**: One-step script (`./scripts/bundle_linux.sh`) generating a portable tarball (`lualamp-linux-x86_64.tar.gz`), `.desktop` file, and AppImage.
  - **Docker**: Cross-compile native Linux binaries from any operating system with a single `docker build`.
- **Non-Blocking Coroutine Threading**:
  - Background coroutine scheduler (`core.add_thread`) for asynchronous tasks, timers, and subprocesses without stuttering the 60 FPS compositor.
- **Custom Procedural Icon Pipeline**:
  - Swift CoreGraphics script (`./scripts/generate_icon.swift`) generating multi-resolution macOS `.icns` (16x16 to 1024x1024 Retina) and standard Linux desktop PNGs/SVGs.
- **Automated Verification Suite**:
  - Headless test runner (`./bin/lualamp --test`) ensuring zero regressions across font loading, frame rendering, and event dispatching.

---

## 🚀 Quick Start

### 1. Prerequisites (macOS)
```bash
# Install host build dependencies via Homebrew
brew install sdl3 freetype pcre2 libpng
```

### 2. Build Engine & Launch in Development Mode
```bash
# Compiles bin/lualamp_bin if needed and starts the application
./bin/lualamp
```

### 3. Run Headless Verification Tests
```bash
./bin/lualamp --test
```

### 4. Install the CLI Command Globally
```bash
./install.sh
# Now you can run 'lualamp' from anywhere!
lualamp
```

---

## ⌨️ Keyboard & Mouse Controls

| Control | Action |
|:--------|:-------|
| <kbd>Space</kbd> | Toggle central lamp glow & beam animation |
| <kbd>T</kbd> | Toggle between Dark and Light color themes |
| <kbd>Left Click</kbd> | Spawn radiant ripple wave at mouse position |
| <kbd>F11</kbd> | Toggle Fullscreen mode |
| <kbd>Q</kbd> or <kbd>Esc</kbd> | Cleanly quit application |

---

## 📦 Building for macOS

### Standalone `.app` Bundle
To bundle a 100% standalone macOS `.app` installed into `/Applications`:
```bash
./scripts/bundle_macos_app.sh
```
This will:
1. Compile the native C/SDL3 engine (`bin/lualamp_bin`).
2. Assemble `dist/Lua Lamp.app`.
3. Embed `libSDL3.0.dylib` and rewrite dynamic load paths via `install_name_tool`.
4. Install all Lua runtime bridge modules and application code.
5. Ad-hoc codesign the bundle and install directly to `/Applications/Lua Lamp.app`.

### Distributable `.dmg` Disk Image
To package a distributable compressed disk image with a drag-and-drop `/Applications` symlink:
```bash
./scripts/create_dmg.sh
```
Output: `dist/LuaLamp-1.0.0.dmg`.

---

## 🐧 Building for Linux

### Option A: Bundle Portable Linux Package
```bash
./scripts/bundle_linux.sh
```
This script packages:
- `dist/lualamp-linux-x86_64/` (Standalone directory)
- `dist/lualamp-linux-x86_64.tar.gz` (Portable release archive)
- `dist/Lua_Lamp-x86_64.AppImage` (If `appimagetool` is installed)

### Option B: Compile from Source on Linux
```bash
# Ubuntu/Debian dependencies
sudo apt-get install -y gcc git meson ninja-build libsdl3-dev libfreetype6-dev libpcre2-dev

# Compile host and bundle release
./scripts/build_runtime_linux.sh
```

### Option C: Build Linux Package via Docker (From Any OS)
```bash
docker build -t lualamp .
docker run --rm -v $(pwd)/dist:/output lualamp cp -r /app/dist/. /output/
```

---

## 🎨 Icon Generation

Lua Lamp includes a procedural icon generator written in Swift using Apple's CoreGraphics framework:

```bash
swift scripts/generate_icon.swift
```

This generates:
- `LuaLamp.icns`: High-DPI macOS iconset (16x16 up to 1024x1024 Retina).
- `resources/icon.png`: Master 1024x1024 PNG icon.
- `resources/lualamp.png` & `resources/lualamp_*.png`: Multi-resolution PNGs for Linux desktop integration.
- `resources/lualamp.svg`: Scalable vector icon.

---

## 🛠 How to Build Your Own Application

Lua Lamp is structured to be easy to modify and extend:

### 1. Customize the Canvas (`src/canvas.lua`)
The canvas is your playground. Replace the "Hello World" card with your own game view, dashboard, or drawing tools:
```lua
function canvas.draw(win_w, win_h)
  -- Draw whatever you want using the renderer:
  renderer.draw_rect(0, 0, win_w, win_h, style.colors.background)
  renderer.draw_text(style.font_title, "My Awesome App", 100, 100, style.colors.text_primary)
end
```

### 2. Handle Mouse & Keyboard Input (`core.lua` or `src/canvas.lua`)
Events are automatically dispatched in `core.on_event`:
- `type == "mousemoved"`: `px, py = a, b`
- `type == "mousepressed"`: `button, px, py = a, b, c`
- `type == "keypressed"`: `key = a:lower()`

### 3. Run Asynchronous Tasks (`core.add_thread`)
Never block the frame loop with synchronous sleep or blocking I/O. Use coroutines instead:
```lua
core.add_thread(function()
  while true do
    print("Background heartbeat...")
    coroutine.yield(5.0) -- sleeps for 5 seconds without blocking UI!
  end
end)
```

### 4. Adjust Colors & Themes (`src/style.lua`)
Edit the color tables in `src/style.lua` to brand your application. All typography scales automatically with High-DPI displays via `SCALE`.

### 5. Build Desktop UIs with the Bundled Framework & Widgets
Lua Lamp bundles the complete UI framework from Lite XL and the Lite XL Widgets library (under the MIT license) in `runtime/`:
- **Views & Split Panes**: `core.view`, `core.node`, `core.rootview`
- **Widgets**: `widget` (`Button`, `TextBox`, `CheckBox`, `Toggle`, `Label`, `Dialog`, `MessageBox`, `ListBox`, `TreeList`, `SelectBox`, `ProgressBar`, `NumberBox`)
- **Scrollbars & Menus**: `core.scrollbar`, `core.contextmenu`, `core.nagview`
- **Commands & Shortcuts**: `core.command`, `core.keymap`
- **Rich Text Editor**: `core.docview`, `core.doc`

#### Example: Creating Windows, Elements, and Formatted Text
```lua
local Widget = require "widget"
local Button = require "widget.button"
local TextBox = require "widget.textbox"
local Toggle = require "widget.toggle"
local Label = require "widget.label"

-- 1. Create a parent container panel
local panel = Widget()
panel:set_position(40, 40)
panel:set_size(320, 240)

-- 2. Add modern interactive controls
local title = Label(panel, "Application Settings")
local input = TextBox(panel, "Default Value")
local switch = Toggle(panel, "Enable Feature", true)
local btn = Button(panel, "Save Changes")

-- 3. Handle user interactions
btn.on_click = function()
  print("Saved setting:", input:get_text(), "Feature enabled:", switch.enabled)
end
```

---

## 📐 Project Architecture

```
lua-lamp/
├── bin/
│   ├── lualamp                 # CLI & dev launcher
│   └── lualamp_bin             # Native C/SDL3 engine binary (gitignored)
├── core.lua                    # Engine lifecycle, SDL3 loop, coroutine scheduler, RootView
├── init.lua                    # Entry point forwarder
├── engine/                     # Vendored native C/SDL3 host engine sources
│   ├── api/                    # C-bindings for system, renderer, font, process
│   ├── lua/                    # Embedded Lua 5.4.7 interpreter core
│   ├── main.c                  # Native entry point and SDL3 initialization
│   ├── renderer.c              # Software / SDL3 2D rendering pipeline
│   └── renwindow.c             # SDL3 window management & High-DPI scaling
├── runtime/                    # Complete UI Framework and Low-Level C-Bindings
│   ├── colors/                 # Prebuilt color themes (default, monokai, solarized, etc.)
│   ├── core/                   # UI Core: Object, View, Node, RootView, ScrollBar, Command, Keymap, DocView
│   ├── libraries/
│   │   └── widget/             # UI Widgets: Button, TextBox, CheckBox, Toggle, Label, Dialog, ListBox, etc.
│   ├── renderer.lua            # Renderer Lua bindings
│   ├── system.lua              # System & window Lua bindings
│   └── globals.lua             # Global table helpers
├── src/
│   ├── canvas.lua              # Main "Hello World" canvas component
│   ├── icons.lua               # Tabler Icons codepoints registry
│   ├── style.lua               # Theme & font management
│   └── ui.lua                  # Vector drawing primitives & UI components
├── fonts/                      # TrueType fonts (PublicSans, SourceSans, Tabler Icons)
├── resources/                  # Icons (PNG, SVG, ICNS)
├── scripts/
│   ├── build_engine.sh         # Native C/SDL3 compiler
│   ├── bundle_macos_app.sh     # macOS .app bundler (embeds libSDL3 & UI framework)
│   ├── create_dmg.sh           # Distributable macOS DMG disk image creator
│   ├── bundle_linux.sh         # Linux portable & AppImage bundler
│   ├── build_runtime_linux.sh  # Native Linux C host compiler
│   └── generate_icon.swift     # Procedural icon generator
└── tests/
    └── test_lualamp.lua        # Headless automated test suite (Stages 1-9)
```

---

## 📄 License

MIT License. See [LICENSE](file:///Users/mturilin/Dev/lua-lamp/LICENSE) for details.

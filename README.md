# 💡 Lua Lamp — Lua & SDL2 Application Starter Template

A modern, high-performance, cross-platform desktop application starter kit built on the **Lua 5.4 + SDL2** platform.

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
|                    |  A lightweight Lua & SDL2 starter template    |                    |
|                    |                                               |                    |
|                    | [Lua 5.4] [SDL2 Platform] [60 FPS Compositor] |                    |
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
- **Zero Text-Editor Bloat**:
  - Completely stripped of text editor dependencies (`core.doc`, `core.docview`, etc.).
  - Direct access to underlying SDL2 graphics, system events, and native OS APIs.
- **Cross-Platform Bundling Out of the Box**:
  - **macOS**: One-step script (`./scripts/bundle_macos_app.sh`) generating a standalone `Lua Lamp.app` with custom Retina `.icns` and ad-hoc code signing.
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

### 1. Launch in Development Mode
```bash
# Run using the development CLI launcher
./bin/lualamp
```

### 2. Run Headless Verification Tests
```bash
./bin/lualamp --test
```

### 3. Install the CLI Command Globally
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

To bundle a 100% standalone macOS `.app` that can be distributed to users or moved into `/Applications`:

```bash
./scripts/bundle_macos_app.sh
```

This will:
1. Compile the custom Retina `.icns` icon.
2. Assemble `dist/Lua Lamp.app`.
3. Install all Lua runtime wrappers and application code.
4. Ad-hoc codesign the bundle.
5. Symlink/install directly to `/Applications/Lua Lamp.app`.

---

## 🐧 Building for Linux

### Option A: Bundle Portable Linux Package
```bash
./scripts/bundle_linux.sh
```
This script resolves the Linux ELF host binary (or downloads the prebuilt platform runtime from GitHub), sets up the `data/` asset folder, writes the `.desktop` launcher, and packages:
- `dist/lualamp-linux-x86_64/` (Standalone directory)
- `dist/lualamp-linux-x86_64.tar.gz` (Portable release archive)
- `dist/Lua_Lamp-x86_64.AppImage` (If `appimagetool` is installed)

### Option B: Compile from Source on Linux
If you are running Linux (Ubuntu, Debian, Fedora, Arch), compile the host C binary from scratch using:
```bash
# Ubuntu/Debian dependencies
sudo apt-get install -y gcc git meson ninja-build libsdl2-dev libfreetype6-dev libpcre2-dev

# Compile host and bundle release
./scripts/build_runtime_linux.sh
```

### Option C: Build Linux Package via Docker (From Any OS)
If you are on macOS or Windows and want to build the Linux binary without setting up a Linux VM:
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
Never block the frame loop with `io.popen` or `sleep`. Use coroutines instead:
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

---

## 📐 Project Architecture

```
lua-lamp/
├── bin/lualamp                 # CLI & dev launcher
├── core.lua                    # Engine lifecycle, SDL2 loop, coroutine scheduler
├── init.lua                    # Entry point forwarder
├── src/
│   ├── canvas.lua              # Main "Hello World" canvas component
│   ├── icons.lua               # Tabler Icons codepoints registry
│   ├── style.lua               # Theme & font management
│   └── ui.lua                  # Vector drawing primitives & UI components
├── fonts/                      # TrueType fonts (PublicSans, SourceSans, Tabler Icons)
├── resources/                  # Icons (PNG, SVG, ICNS)
├── scripts/
│   ├── bundle_macos_app.sh     # macOS .app bundler
│   ├── bundle_linux.sh         # Linux portable & AppImage bundler
│   ├── build_runtime_linux.sh  # Native Linux C host compiler
│   └── generate_icon.swift     # Procedural icon generator
└── tests/
    └── test_lualamp.lua        # Headless automated test suite
```

---

## 📄 License

MIT License. See [LICENSE](file:///Users/mturilin/Dev/lua-lamp/LICENSE) for details.

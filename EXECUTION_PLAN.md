# Execution Plan: Extensible Menu System, Modal Settings Window, and UI Framework Abstraction

**Document Version**: 1.0.0  
**Target Platform**: macOS (Native `NSMenu` Screen Menu Bar) & Linux (In-Window MenuBar) on Lua 5.4 / SDL3  
**Status**: Ready for Execution  

---

## 1. Executive Summary & Objectives

Lua Lamp is evolving into an extensible, native desktop application starter platform (a "Mini-Flutter for Lua & SDL3"). This plan details the execution strategy for:
1. **Extensible Menu System**:
   - **macOS**: Native screen-top system menu bar (`NSMenu`) via Cocoa/AppKit integration (`Lua Lamp` app menu with *About*, *Settings...* <kbd>Cmd+,</kbd>, *Quit* <kbd>Cmd+Q</kbd>, plus dynamic app menus like *View*, *Tools*, *Help*).
   - **Linux / Windows**: Sleek, borderless in-window menu bar strip rendered at the top of the window canvas with dropdown lists.
   - **Unified Lua API**: Declarative menu registration (`menu:register(...)`) usable by any script or downstream application.
2. **Extensible Modal Settings Window**:
   - A floating, draggable modal dialog (`SettingsDialog`) centered over the application workspace.
   - Triggered via macOS menu (*Lua Lamp* → *Settings...*), shortcut (<kbd>Cmd+,</kbd> on Mac, <kbd>Ctrl+,</kbd> on Linux), or Lua API.
   - Core settings:
     - **Display & Scale**: Stepper/selector (`Auto-Detect`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`, `2.5x`) with immediate 60 FPS live rescaling via `core.rescale()`.
     - **Typography**: UI font family (`Public Sans`, `Source Sans 3`) and size preview.
     - **Theme**: Dark Mode vs. Light Mode toggle.
   - Extensible registration hook (`settings:register_section(...)`) allowing external applications to inject custom tabs/panels.
3. **"Mini-Flutter" Component Abstraction**:
   - A clean public facade exposing `Widget`, `Dialog`, `Button`, `Toggle`, `CheckBox`, `TextBox`, `NoteBook` (tabs), `Node` (split panes), and `Icons` with consistent optical alignment and borderless surfaces.

---

## 2. Architectural Blueprint

```
                      Declarative Application Code / Plugins
                                        │
                                        ▼
                     Unified Menu & Settings Registry (`src/menu.lua`)
                     ┌──────────────────────────────────────────────┐
                     │ menu:register("Tools", { ... })              │
                     │ settings:register_section("Database", fn)    │
                     └──────────────────────┬───────────────────────┘
                                            │
                     ┌──────────────────────┴───────────────────────┐
                     ▼                                              ▼
             [macOS Platform]                               [Linux Platform]
      Native Screen Menu Bar (NSMenu)                In-Window MenuBar (`src/menubar.lua`)
      - App Menu: About, Settings... (Cmd+,), Quit   - Top of window canvas strip
      - Dynamic custom top menus                     - Dropdowns with optical alignment
                     │                                              │
                     └──────────────────────┬───────────────────────┘
                                            ▼
                              Menu Action or Shortcut (Cmd+,)
                                            ▼
                           [Modal Settings Window] (`src/settings_dialog.lua`)
                     ┌──────────────────────────────────────────────┐
                     │  Categories (Tabs)   │  Active Content Panel │
                     │  ──────────────────  │  ───────────────────  │
                     │  [⚙ Display & Scale] │  Scale: (•) 2.0x 4K   │
                     │  [🔤 Typography]      │  Font:  [Public Sans] │
                     │  [🎨 Themes]          │  Theme: [Dark Mode]   │
                     │  [+ Custom App Tabs] │  Custom Widgets...    │
                     │  ──────────────────  │  ───────────────────  │
                     │                      │  [Apply]      [Close] │
                     └──────────────────────────────────────────────┘
                                            │
                                            ▼
                              UI Framework Core Primitives
                     ┌──────────────────────────────────────────────┐
                     │  - Widget, Button, Toggle, NoteBook (Tabs)   │
                     │  - Dialog Modal Engine (RootView:defer_draw) │
                     │  - Vector AA & Optical Alignment (ui.lua)    │
                     │  - 60 FPS Compositor & Dynamic Rescaling     │
                     └──────────────────────────────────────────────┘
```

---

## 3. Detailed Component Specifications

### 3.1 Native macOS Menu Bridge (`engine/bundle_open.m` & `engine/api/system.c`)
- **Objective**: Expose native AppKit `NSMenu` creation to Lua so that on macOS, menus appear at the very top of the Mac display screen.
- **Components**:
  - `system.set_native_menu(menu_tree)`: C-binding accepting a table of menus and items.
  - Native Cocoa action target: Dispatches selected menu command strings into the SDL event queue as `"menu"` events (`core.on_event("menu", command_id)`).
  - Standard macOS Application Menu:
    - *About Lua Lamp* (`app:about`)
    - Separator
    - *Settings...* (`app:open-settings`, keyEquivalent: `","`, modifier: `NSEventModifierFlagCommand`)
    - Separator
    - *Hide Lua Lamp* (`"h"`) / *Hide Others* / *Show All*
    - Separator
    - *Quit Lua Lamp* (`"q"`, `app:quit`)

### 3.2 Linux In-Window Menu Bar (`src/menubar.lua`)
- **Objective**: For non-macOS systems, render a sleek horizontal menu bar at the top of the window.
- **Directives**:
  - Borderless surface design: resting translucent pill or flat, hover highlight (`rgba(255,255,255,0.08)`).
  - Optical baseline compensation: `math.floor(1.2 * SCALE)`.
  - Dropdown lists support click-to-open, mouse hover selection, keyboard navigation, dividers, and right-aligned shortcut badges.

### 3.3 Unified Menu Facade (`src/menu.lua`)
- **API**:
  ```lua
  local menu = require "src.menu"
  menu:register(category, items)
  menu:trigger(command_id)
  menu:draw(win_w, win_h) -- On Linux, renders in-window bar
  ```
- Automatically directs to `system.set_native_menu` on macOS (`PLATFORM == "Mac OS X"`), and `menubar.draw` on Linux.

### 3.4 Extensible Modal Settings Window (`src/settings_dialog.lua`)
- **Architecture**:
  - Inherits from `widget.dialog` or `core.view` rendered via `core.root_view:defer_draw` as a top-level modal overlay.
  - Dimensions: `math.floor(540 * SCALE)` width by `math.floor(380 * SCALE)` height, centered dynamically on screen.
  - Draggable by title bar, dismissible via `[X]` button, <kbd>Esc</kbd>, or clicking outside (optional modal shield).
- **Tabbed Layout**:
  - Left navigation category sidebar (or top tab headers) utilizing `NoteBook` tabs.
  - **Category 1: Display & Scale**:
    - Radio buttons or selector: `Auto-Detect (Current: 2.0x)`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`, `2.5x`.
    - Live effect: Instantly calls `core.rescale(scale)` without closing the dialog or restarting the app.
  - **Category 2: Typography**:
    - Font family picker (`Public Sans`, `Source Sans 3`).
    - Font size slider or stepper.
    - Live glyph sample text preview.
  - **Category 3: Theme**:
    - Dark Mode vs. Light Mode radio or toggle switch.
- **Extensible Plugin Registry**:
  ```lua
  local settings = require "src.settings"
  settings:register_section("Database", "database", function(panel)
    local Label = require "widget.label"
    local TextBox = require "widget.textbox"
    Label(panel, "Host URL:")
    TextBox(panel, "https://api.example.com")
  end)
  ```

### 3.5 Mini-Flutter Public Facade (`src/framework.lua`)
Export a standardized developer facade so application writers don't need to navigate internal directories:
- `framework.Widget`
- `framework.Dialog`
- `framework.Button`
- `framework.Toggle`
- `framework.CheckBox`
- `framework.TextBox`
- `framework.Label`
- `framework.NoteBook`
- `framework.SelectBox`
- `framework.Icons`
- `framework.Menu`
- `framework.Settings`

---

## 4. Phase-by-Phase Implementation Roadmap

### Phase 1: Native macOS Menu Bridge & Host Engine Extension
1. Update `engine/bundle_open.m` to implement Objective-C `NSMenu` construction and action handlers.
2. Update `engine/api/system.c` to expose `system.set_native_menu` and push `"menu"` events through `f_poll_event`.
3. Recompile the native host engine using `scripts/build_engine.sh`.

### Phase 2: Unified Menu System & Linux In-Window MenuBar
1. Implement `src/menubar.lua` for the Linux in-window rendering pipeline.
2. Implement `src/menu.lua` supporting cross-platform registration, default menus (*Lua Lamp*, *View*, *Help*), and dispatch routing.
3. Integrate menu event handling in `core.on_event`.

### Phase 3: Extensible Modal Settings Window
1. Implement `src/settings_dialog.lua` with modal overlay, tabs, and draggable dialog frame.
2. Implement core settings sections:
   - Scale selection with live `core.rescale()` execution.
   - Typography selection with preview.
   - Theme toggle.
3. Implement `settings:register_section(...)` hook for plugin extensibility.

### Phase 4: Keybindings & Event Wiring
1. Bind <kbd>Cmd+,</kbd> (macOS) and <kbd>Ctrl+,</kbd> (Linux) to open the Settings modal.
2. Add menu item *Settings...* to trigger the dialog.
3. Ensure <kbd>Esc</kbd> closes open menus and modal dialogs cleanly.

### Phase 5: Automated Verification Suite (Stage 11)
1. Add Stage 11 to `tests/test_lualamp.lua`:
   - Verify `menu:register()` and command dispatching.
   - Verify `settings:register_section()` and `SettingsDialog` instantiation.
   - Verify live scale switching through the settings subsystem.
2. Run headless test suite `./bin/lualamp --test` to ensure all 11 stages pass.

### Phase 6: Bundling, Artifact Generation, and Specification Sync
1. Run `./scripts/bundle_macos_app.sh` and `./scripts/create_dmg.sh` to update macOS distribution artifacts.
2. Update `SPECIFICATION.md` to document the Menu System, Settings Dialog, and Mini-Flutter abstractions (per the Prime Directive).
3. Update `README.md` with usage instructions and API guides.

---

## 5. Verification & Acceptance Criteria

| # | Checkpoint | Verification Method |
|:--|:---|:---|
| 1 | macOS System Menu Bar | App menu displays *About*, *Settings...* (<kbd>Cmd+,</kbd>), *Quit* (<kbd>Cmd+Q</kbd>) on top screen menu bar. |
| 2 | Linux In-Window Menu | Non-Mac platforms render borderless menu bar with dropdowns inside window canvas. |
| 3 | Modal Settings Window | Clicking *Settings...* or pressing <kbd>Cmd+,</kbd> displays floating, draggable dialog over canvas. |
| 4 | Live DPI Scaling | Changing scale in Settings dialog immediately rescales canvas, typography, and card live at 60 FPS. |
| 5 | Extensibility | Custom section registered via `settings:register_section` renders its custom controls in a new tab. |
| 6 | Headless Test Suite | `bin/lualamp --test` executes all 11 stages with zero assertion failures. |
| 7 | Native Packaging | `dist/Lua Lamp.app` and `dist/LuaLamp-1.0.0.dmg` rebuild and pass ad-hoc signing and checksum verification. |
| 8 | Prime Directive Sync | `SPECIFICATION.md` and `README.md` updated in same turn with zero spec drift. |

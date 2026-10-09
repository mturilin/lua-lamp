# AGENTS.md — Agent Guidelines & Invariant Protocol

This document defines the operational directives, architectural standards, and UI rendering invariants for AI agents working on **Lua Lamp**.

---

## 1. Prime Directive: Intent Invariant Document (Spec) Maintenance

> [!IMPORTANT]
> **The Intent Invariant Document ([`SPECIFICATION.md`](file:///Users/mturilin/Dev/lua-lamp/SPECIFICATION.md)) is the authoritative source of truth for all requirements, architecture, and behavioral contracts.**

### The Maintenance Invariant
1. **Always Update [`SPECIFICATION.md`](file:///Users/mturilin/Dev/lua-lamp/SPECIFICATION.md)**:
   - Whenever you implement a new feature, modify behavior, remap shortcuts, alter theme tokens, add UI primitives, or fix a bug, you **MUST immediately update [`SPECIFICATION.md`](file:///Users/mturilin/Dev/lua-lamp/SPECIFICATION.md)** within the same turn/commit.
   - Code and specification must **never drift**.
2. **Platform Foundation Rule**:
   - Lua Lamp runs on the Lua 5.4 / SDL2 runtime foundation.
   - Lua Lamp **MUST NOT** import or reuse Lite XL's text editor core (`core.doc`, `core.docview`, `core.statusview`, `core.commandview`, etc.).
   - All application logic lives in `core.lua` and `src/`.
3. **Synchronize Documentation**:
   - When shortcuts, features, or CLI commands change, update [`README.md`](file:///Users/mturilin/Dev/lua-lamp/README.md) and [`SPECIFICATION.md`](file:///Users/mturilin/Dev/lua-lamp/SPECIFICATION.md).

---

## 2. Protected Intent Invariants

1. **Blank Canvas Centering**:
   - On launch, the window must display a centered "Hello, World!" stage card against a clean canvas.
   - The stage card must remain centered dynamically regardless of window resizing or High-DPI display scaling.
   - The canvas must illustrate live interactive feedback: mouse coordinates `(x, y)`, window dimensions `w x h`, frame rate, and animated click ripples.
2. **Zero Text-Editor Dependency**:
   - Lua Lamp **MUST NOT** import or depend on Lite XL text editor modules.
   - All application logic lives in `core.lua` and `src/`.
   - The application relies exclusively on the underlying C/SDL2 host runtime primitives (`renderer`, `system`, `process`, `renderer.font`).
3. **Native Cross-Platform Packaging**:
   - **macOS**: Must produce a standalone `Lua Lamp.app` bundle in `dist/` with native Mach-O executable, Retina `.icns`, and ad-hoc codesign.
   - **Linux**: Must produce a standalone portable directory `lualamp-linux-$ARCH` and `.tar.gz` in `dist/` with native ELF executable, self-contained `data/` assets, and `.desktop` integration.
4. **Zero-Block Asynchronous Execution**:
   - Network probes, subprocesses, timers, or background tasks must run in non-blocking coroutines via `core.add_thread`.
   - The 60 FPS event loop in `core.run()` must never be blocked by synchronous sleep or blocking I/O (`io.popen`).
5. **High-DPI & Scaling Contract**:
   - The global multiplier `SCALE` is resolved during initialization via `LUALAMP_SCALE` or `LITE_SCALE`.
   - All font sizes, margins, padding, and UI bounding boxes must scale proportionally with `SCALE`.
6. **Automated Verification Contract**:
   - Every distribution must pass the automated headless test suite (`bin/lualamp --test` or `tests/test_lualamp.lua`) with zero assertion failures.

---

## 3. UI Aesthetics, Precision Alignment, & Edge Rendering Directives

This protocol establishes the mandatory engineering standards for rendering clean, modern, native-feeling user interfaces on custom 2D canvas/pixel runtimes (like SDL2/Lite XL).

### 3.1 Forensic Root Cause Analysis

#### A. Why Naive Code Produces "Shady Alignment Everywhere"
1. **The Typographic Line-Height Trap**:
   - Developers almost universally center text inside a bounding box by writing:
     ```lua
     local ty = container_y + math.floor((container_h - font:get_height()) / 2)
     ```
   - **The Flaw**: `font:get_height()` is the typographic **line height** ($\text{Ascent} + \text{Descent} + \text{Line Gap}$), NOT the visible glyph height.
   - In Latin fonts (Arial, Inter, Public Sans, SF Pro), the **Cap Height** (uppercase letters `A`, `P`, numbers `1`, `2`, and icons) only occupies ~68–72% of the line box. The bottom 25–30% is **descender space** reserved for characters with tails (`g`, `j`, `p`, `q`, `y`).
   - For standard UI labels (`Add Target`, `Light Theme`, `Hello, World!`, `60 FPS`), the descender area is completely empty. Centering the line box centers the empty padding, shifting the visible glyphs **1 to 2 pixels too high**.
   - Inside a 24–28px button or badge, a 2px upward shift creates a 40% margin asymmetry: the text looks crowded against the top edge and stranded from the bottom.
2. **Font-Group Baseline Drift**:
   - Concatenating icons with text into a single string (`icon .. " " .. label`) forces the text engine to align both on the primary font's typographic baseline.
   - Icon fonts (Tabler, FontAwesome) and Latin text fonts use completely different em-box centers, glyph proportions, and vertical centers. Icons end up hovering above or dropping below the text baseline.
3. **Fractional Division Jitter**:
   - Dividing odd dimensions by 2 without explicit floor snapping causes alternating 1px discrepancies between adjacent buttons and nested labels.

#### B. Why Custom Vector Renderers Produce "Rough Edges"
1. **The 1-Pixel Stroke Rasterization Trap**:
   - Web browsers (Chrome, Safari) use 2D vector engines (Skia, CoreGraphics) with 8x multi-sample antialiasing (MSAA) or analytic trapezoid coverage.
   - Low-level engines (SDL2 / Lite XL) only expose axis-aligned integer rectangle primitives (`renderer.draw_rect`).
   - When code attempts to draw a 1-pixel **border stroke** around a rounded rectangle using discrete 1x1 rectangles:
     - At 0° and 90°, the stroke is 1px wide.
     - At 45°, a single diagonal step spans a Euclidean distance of $\sqrt{1^2 + 1^2} \approx 1.414$ px.
     - Without subpixel area integration, the corner degenerates into a jagged polygon staircase with optical pinch points and missing corner pixels.
2. **The Dark-Mode Wireframe Anti-Pattern**:
   - High-contrast 1px outlines (e.g. cyan `#38bdf8` or bright gray on dark charcoal, contrast > 10:1) act as high-frequency visual noise, drawing the user's eye directly to every single raster quantization defect.
   - In modern macOS and iOS UI (macOS Monterey through Sequoia, Safari, Xcode, Linear, Raycast), **toolbar buttons and interactive controls DO NOT have outline wireframe borders**. They use smooth, borderless filled surfaces.

---

### 3.2 The 5 Cardinal Directives for Beautiful UIs

AI agents working on UI must apply these rules right off the bat:

#### Rule 1: The Optical Baseline Compensation Invariant
Whenever centering uppercase text, numerals, title labels, or glyphs inside a button, pill, badge, or table cell, you **MUST** apply optical baseline compensation:
```lua
-- Standard formula: shifts ink down to counter asymmetric font descent
local optical_shift = math.floor(1.2 * SCALE)
local text_y = container_y + math.floor((container_h - font:get_height()) / 2) + optical_shift
```
*Rationale*: Shifting the line box down by $\approx \lfloor 0.15 \times \text{font:get\_height()} \rfloor$ (1px at 1x, 2px at 2x Retina) balances the top and bottom margins, achieving an exact 50/50 visual ink center.

#### Rule 2: The Borderless Surface Principle & Pinglet Button Highlight Standard
Never wrap dark-mode toolbar controls, segmented items, or action buttons in 1px outline border strokes. Adopt the **Pinglet Button Highlight Standard**:
- **Segmented Control Track**: Grouped controls sit inside a recessed dark capsule track (`ui.draw_segmented_track`, `c.track_bg`).
- **Active Solid Pill (`variant = "solid"`)**: Vibrant solid pill (Pinglet `60s` style) with inverted dark text (`#0c1018`), SemiBold weight, and zero border stroke (`c.btn_accent_bg` / `c.btn_accent_text`).
- **Active Tinted Pill (`variant = "tinted"`)**: Luminous translucent tinted pill (Pinglet `123 Follow`, `+ Add Target` style) with glowing text and icon (`c.btn_tint_bg` / `c.btn_tint_text`), zero border stroke.
- **Resting state**: Clean, flat, borderless (`rgba(255, 255, 255, 0)` inside track or subtle translucent surface `c.surface_hover`).
- **Hover state**: Smooth, luminous translucent pill (`rgba(255, 255, 255, 0.09)` to `0.12`).
- **Surface Cohesion**: A filled rounded pill has a cohesive solid surface. Even minor edge antialiasing blends seamlessly, whereas a 1px outline exposes two jagged boundaries (inner and outer). Always use `ui.draw_button` for interactive buttons.

#### Rule 3: Decoupled Icon and Text Measurement
Never concatenate an icon and a text label into a single string if pixel-perfect alignment is required.
- Measure icon width (`font_icon:get_width(icon)`) and text width (`font_text:get_width(label)`) independently.
- Calculate their optical centerlines separately:
  ```lua
  local iy = center_y + math.floor((btn_h - font_icon:get_height()) / 2) + math.floor(1.0 * SCALE)
  local ty = center_y + math.floor((btn_h - font_text:get_height()) / 2) + math.floor(1.2 * SCALE)
  ```
- Enforce an explicit typographic gap (e.g., `8 * SCALE`) between icon and label.

#### Rule 4: Subpixel Alpha Coverage for Curves
Any custom vector curve, arc, or rounded corner drawn via `draw_rect` **MUST** compute fractional geometric area coverage:
```lua
local exact_out = radius - math.sqrt(math.max(0, radius * radius - dist_y * dist_y))
local floor_out = math.floor(exact_out)
local coverage = 1.0 - (exact_out - floor_out)
-- Blend outer edge pixels using proportional alpha:
if coverage > 0.05 then
  local aa_col = { r, g, b, math.floor(base_a * coverage) }
  renderer.draw_rect(x + floor_out, y + dy, 1, 1, aa_col)
end
```
Never render raw, binary 1-bit staircase steps on dark backgrounds.

#### Rule 5: Strict Metric Hierarchy & Integer Snapping
- All layout dimensions must use an 8px/4px base grid (`btn_h = 32 * SCALE`, `pad = 12 * SCALE`, `gap = 8 * SCALE`).
- All calculated coordinates (`x`, `y`, `w`, `h`) **MUST** pass through `math.floor` after multiplying by `SCALE`. Unsnapped floating-point values cause 1px subpixel jitter across frame redraws.

---

## 4. Framework Code Documentation & Architectural Clarity Directives

All framework code in Lua Lamp (`core.lua`, `src/*.lua`, `runtime/**/*.lua`) must be thoroughly, professionally documented so that any engineer or agent can immediately understand its architecture, contracts, and implementation details.

### 4.1 Top-of-File Header Documentation
Every single source file in the framework **MUST** begin with a descriptive header comment block at the very top:
1. **Module Name & Component Identity**: Clear, standardized naming (e.g. `Lua Lamp ScrollView Component`).
2. **File Purpose & Architectural Role**: A concise multi-line summary explaining why this file exists, what subsystem it belongs to, and how it interacts with the rest of the framework.
3. **Key Invariants & Capabilities**: Core guarantees (e.g., non-blocking coroutines, scissor clipping, subpixel anti-aliasing, coordinate transforms).
4. **Public Exports / Contracts**: Overview of what the module exports or returns.

*Example*:
```lua
-- ============================================================================
-- Lua Lamp ScrollView Component (`src/scroll_view.lua`)
--
-- High-performance, lightweight scrollable viewport container conforming to the
-- architecture of Flutter (SingleChildScrollView) and Avalonia (ScrollViewer).
--
-- Key Responsibilities:
-- - Viewport scissor clipping via renderer.set_clip_rect() with local origin translation
-- - Smooth 60 FPS exponential damping scroll interpolation (scroll_to_y -> scroll_y)
-- - Native macOS-style rounded capsule scrollbar thumb with dynamic width expansion and auto-fade
-- - Coordinate transformation between window viewport space and scrollable content space
--
-- Exports:
-- - ScrollView class table callable as ScrollView(options)
-- ============================================================================
```

### 4.2 Function Purpose & Parameter Contracts
Every function, method, and constructor (public or non-trivial internal helper) **MUST** document its purpose, parameters, return values, and side effects using structured doc comments (e.g., EmmyLua format `---@param`, `---@return`):
1. **Purpose**: Plain English explanation of what the function achieves and why it is called.
2. **Parameters (`@param`)**: Parameter name, expected type (`number`, `string`, `table`, `boolean`, `function`), and units or coordinate frames (e.g. `px: number @Mouse X in window pixel coordinates`, `dy: number @Vertical scroll delta; positive is up`).
3. **Return Values (`@return`)**: Returned types and semantic meanings (e.g. `@return boolean @True if event was captured/handled, false to propagate`).
4. **Side Effects / State Changes**: Any changes to global state, clip rect stacks, cursor requests, or thread registrations.

*Example*:
```lua
--- Begins viewport scissor clipping and calculates translated local drawing origin.
--- Must be matched by a corresponding sv:end_clip() call.
---@param x number Viewport top-left X in window coordinates
---@param y number Viewport top-left Y in window coordinates
---@param w number Viewport width
---@param h number Viewport height
---@param content_h number Total height of scrollable child content
---@return number ox Translated X origin to draw children at (x)
---@return number oy Translated Y origin to draw children at (y - scroll_y)
function ScrollView:begin_clip(x, y, w, h, content_h)
```

### 4.3 Inline Explanations for Non-Trivial Logic
Code must be self-explanatory for simple operations, but non-trivial logic **MUST** be accompanied by explanatory comments:
- **Trivial code does NOT need noise comments**: Simple assignments (e.g. `self.x = 0`, `local count = 0`), straightforward table instantiations, and routine getters/setters do not need redundant comments.
- **Non-trivial or subtle logic MUST have comments explaining the "Why"**:
  - **Mathematical & Geometric Formulas**: Explain DPI scaling calculations (`* SCALE`), integer coordinate snapping (`math.floor`), line-height descender compensations, and subpixel alpha coverage.
  - **Coordinate Space Transformations**: Detail translations between screen coordinates, local container coordinates, and virtual scrolled content coordinates.
  - **Interpolation & Damping**: Explain time delta weights, damping factors (`* 0.32`), velocity clamps, and boundary bounce/clamp conditions.
  - **Platform-Specific Hooks**: Document OS-specific logic (e.g., macOS Cocoa `NSMenu`, AppKit backing scale factor, FreeType cmap mappings).
  - **Event Routing & Trapping**: Explain why an event is swallowed (`return true`) or forwarded down the widget tree.
  - **Edge Cases & Error Fallbacks**: Explain recovery mechanisms when a font is missing, a directory monitor fails, or a coroutine encounters an exception.

*Example*:
```lua
-- Shift the line box down by ~15% of font height to compensate for unused descender space,
-- ensuring uppercase glyphs and numerals sit at the exact optical vertical center.
local optical_shift = math.floor(1.2 * SCALE)
local text_y = container_y + math.floor((container_h - font:get_height()) / 2) + optical_shift
```

---

## 5. Verification Checklist

When completing any task:
1. [ ] **Code Changes**: Implemented cleanly in `core.lua` or `src/`.
2. [ ] **Code Documentation**: Verified that every modified/created file has a top-of-file purpose header, every function has documented purpose and parameters, and all non-trivial logic includes explanatory comments.
3. [ ] **Optical Alignment**: Verified that text and icons inside buttons, pills, and headers use optical baseline compensation.
4. [ ] **Edge Smoothing**: Confirmed controls are borderless filled pills or use subpixel antialiasing.
5. [ ] **Test Execution**: Run `bin/lualamp --test` headlessly and confirm all assertions pass.
6. [ ] **Bundle & Packaging**: Run `./scripts/bundle_macos_app.sh` (macOS) or `./scripts/bundle_linux.sh` (Linux) to verify artifact generation.
7. [ ] **Spec Sync**: Update [`SPECIFICATION.md`](file:///Users/mturilin/Dev/lua-lamp/SPECIFICATION.md) to record modified invariants or new features.
8. [ ] **Doc Sync**: Update [`README.md`](file:///Users/mturilin/Dev/lua-lamp/README.md) if user interaction or CLI commands changed.

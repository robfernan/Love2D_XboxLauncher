# Xbox Concept Dashboard (Love2D)

A retro-futuristic, multi-era console desktop launcher and game manager built with **Love2D 11.5**. Experience authentic console dashboard layouts—including the **Xbox Original Sci-Fi Dashboard**, the **Xbox 360 NXE (New Xbox Experience)**, and the **PlayStation 3 / PSP XMB (XrossMediaBar)**—with dynamic procedural backgrounds, sound effects, full controller support, a virtual on-screen keyboard, instant search, and real application launching.

---

## Multiple Console Layout Engines

Switch seamlessly between dashboard eras at any time via **F6**, the controller **Back / Select** button, or the top title bar badge:

* **Xbox 360 NXE (New Xbox Experience, 2008–2010)**
  * Iconic twilight snowy mountain backdrop with shaded mountain facets, pine ridges, crescent moon, and twinkling stars.
  * Real-time reflective frozen icy lake floor mirroring the cards and item counters.
  * Animated concentric water ripple rings emanating from a 3D chrome Xbox Guide button orb.
  * Horizontal 3D perspective card carousel ("The Channel") with glossy active black/green card and lime-green trailing perspective cards.
  * Top-right Gamertag profile HUD with vector mail/friend notifications and Gamerpic tile.
  * Centered category column navigating your actual categories: **`GAMES`**, **`BROWSE`**, **`MEDIA`**, and **`SETTINGS`**.

* **Xbox Original Dashboard**
  * Procedural glowing planet sphere with radial gradients and rotating intersecting orbital wireframe rings.
  * Multi-pass separable Gaussian blur bloom shader pipeline.
  * Dynamic radar sweep grid background with sci-fi telemetry readouts.
  * 3D trapezoidal chevron menu buttons with live selection orb connector lines.

* **PlayStation 3 / PSP XMB (XrossMediaBar)**
  * GLSL-powered procedural ribbon wave shader background with glowing energy lines.
  * Horizontal icon category bar with vertical scrolling sub-item columns.
  * PlayStation controller glyphs (Cross, Circle, Square, Triangle).

---

## Core Features

* **Real Application & Game Launcher**: Spawns local `.exe` and `.bat` programs detached (Windows `start`, macOS `open`, Linux `setsid`) so they keep running after the launcher exits. Also opens web apps and URLs in your default browser.
* **Steam Game Auto-Detection**: Pure Lua cross-platform scanner parses `libraryfolders.vdf` and `.acf` manifests to automatically import installed Steam games into your **GAMES** category.
* **Drag-and-Drop Shortcut Creation**: Drag any `.exe`, folder, file, or image directly into the launcher window to add it immediately.
* **Shortcut Manager & Wizard (`Settings → + Add Shortcut…` / `Y` button)**: Create, edit, and organize shortcuts with custom names, categories, and icons. All items persist cleanly to `userdata/config.json`.
* **Quick Search Overlay (`Ctrl + F` or Gamepad `Y`)**: Instant fuzzy search across your entire game and application catalog.
* **Virtual On-Screen Keyboard (OSK)**: Full console virtual keyboard with controller navigation, mouse clicks, and shortcuts (`A` type, `X` backspace, `Y` space, `Start` confirm).
* **Full Gamepad / Controller Support**: Native XInput / DirectInput support with analog stick navigation, deadzones, trigger handling, and dynamic prompt badge rendering (Xbox `A/B/X/Y` vs. PlayStation `✕/○/□/△`).
* **Custom Frameless Window**: Clean borderless window with draggable title bar, vector close (`✕`) and minimize (`–`) buttons, live digital clock, and layout switcher badge.
* **Live Audio Synthesis**: Procedurally synthesized retro UI sound effects (blip, tick, swoosh, cancel, launch) without relying on external `.wav` files.
* **Dynamic Color Themes & Scaling**: Multiple color profiles (**Green**, **Blue**, **Red**, **Purple**), resolution presets (720p→1440p), and UI scaling (75%–150%) with crisp proportional font scaling.

---

## Controls

### Keyboard & Mouse

| Key / Action | Description |
| :--- | :--- |
| **Up / Down** | Navigate vertical menu items (or categories in NXE) |
| **Left / Right** | Navigate categories (or horizontal 3D card carousel in NXE) |
| **A / Enter / Space** | Select / activate item, open category, or launch app |
| **B / Escape** | Go back one level (at the root menu, app remains open) |
| **X** | Remove selected custom shortcut |
| **Y / E** | Edit highlighted shortcut |
| **F6** | Quick cycle layout (Xbox Original ↔ Xbox 360 NXE ↔ PS3 XMB) |
| **Ctrl + F** | Open Quick Search overlay |
| **Title Bar Drag** | Click and drag the top title bar to move the window |
| **Title Bar Buttons** | Minimize (`–`), close (`✕`), or click `[Layout: ...]` badge to switch layouts |

### Gamepad / Controller

| Button | Action |
| :--- | :--- |
| **D-Pad / Left Stick** | Navigate items, cards, and categories |
| **A / Cross (✕)** | Select / Launch |
| **B / Circle (○)** | Back / Cancel |
| **X / Square (□)** | Remove shortcut |
| **Y / Triangle (△)** | Quick Search (or edit shortcut in menu) |
| **LB / RB (L1 / R1)** | Fast category switching |
| **Back / Select / View** | Cycle layout engine |

---

## Project Structure

```
Xbox_Launcher/
├── conf.lua             — LÖVE window/config bootstrap
├── main.lua             — Application entrypoint & love.* event routing
├── core/                — Modular core subsystems
│   ├── config.lua       — Persistent configuration loader (userdata/config.json)
│   ├── state.lua        — Shared runtime state & font/canvas cache
│   ├── themes.lua       — Color theme palettes
│   ├── menu_data.lua    — Category tree definition (GAMES, BROWSE, MEDIA, SETTINGS)
│   ├── shortcuts.lua    — Shortcut storage and category merging
│   ├── launcher.lua     — Detached process execution & URL launcher
│   ├── steam.lua        — Cross-platform Steam library scanner
│   ├── wizard.lua       — Shortcut creation & edit modal
│   ├── keyboard.lua     — Console On-Screen Virtual Keyboard (OSK)
│   ├── search.lua       — Instant fuzzy search overlay
│   ├── gamepad.lua      — Controller input mapping & prompt badges
│   ├── audio.lua        — Procedural retro sound synthesis
│   ├── settings.lua     — Window mode, resolution, and theme settings
│   ├── layout.lua       — Responsive UI scaling & hit-test helpers
│   ├── menu.lua         — Menu navigation state machine
│   ├── render.lua       — Title bar, bloom pipeline, and frame coordination
│   ├── json.lua         — Dependency-free pure Lua JSON library
│   └── layouts/         — Dashboard Layout Engines
│       ├── xbox.lua     — Xbox Original Sci-Fi Dashboard
│       ├── blades.lua   — Xbox 360 NXE 3D Channel Carousel Dashboard
│       └── xmb.lua      — PlayStation 3 / PSP XMB Dashboard
├── icons/               — App and platform icons
├── shaders/             — GLSL shaders (bloom blur, XMB ribbon wave)
├── rajdhani.ttf         — Primary dashboard font
└── .vscode/tasks.json   — Build task to run via Ctrl+Shift+B
```

---

## Requirements & Running

* **LÖVE (Love2D) 11.5** ([love2d.org](https://love2d.org/))
* **OS:** Windows, macOS, or Linux

### How to Run

1. Clone or open this repository in VS Code.
2. Launch using **`Ctrl + Shift + B`** in VS Code (runs default build task), or run from terminal:
   ```bash
   love .
   ```
3. Custom shortcuts, window settings, and layout preferences are automatically saved to `userdata/config.json`.

---

## License

This project is open-source and intended for personal, hobbyist, and custom launcher use.
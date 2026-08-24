# Xbox Concept Dashboard (Love2D Prototype)

A retro-futuristic, Xbox-inspired desktop launcher prototype built with **Love2D** (LÖVE). It features a custom frameless draggable window, a procedural glowing sphere wrapped in intersecting orbital wireframe rings, a multi-pass bloom shader, a radar grid background, hierarchical category menus with app icons, and live color theme switching.

![Xbox Concept Dashboard — Screenshot](Screenshot_6_07PM_8_24_2026.png)

---

## Features

* **Procedural Glowing Sphere & Orbital Rings** — A central planet body drawn with radial gradient layers, wrapped by intersecting rotating wireframe rings, and enhanced with a two-pass (separable) Gaussian blur bloom shader.
* **Radar Grid Background** — Concentric radar rings and crosshair spokes rendered on a dedicated canvas, tinted to the active theme.
* **Hierarchical Menu System** — Two-tier navigation: four top-level categories (**Games**, **Browse**, **Media**, **Settings**), each with icon sub-items that open URLs via `love.system.openURL`.
* **Dynamic Color Themes** — Four built-in profiles (**Green**, **Blue**, **Red**, **Purple**); cycle with **Left/Right** inside the Settings menu or select the *Theme Cycle* item. Theme changes apply live across the background, sphere, rings, menu, and title bar.
* **Draggable Frameless Window** — Borderless window with a custom title bar, working minimize (–) and close (×) buttons, and click-and-drag window repositioning.
* **Graceful Degradation** — Missing icon files are skipped silently (`pcall` loading), so the launcher still runs without the `icons/` folder.

---

## Controls

| Key / Action | Description |
| :--- | :--- |
| **Up / Down** | Navigate menu items up and down |
| **A / Enter / Keypad Enter** | Select item or open category / launch URL |
| **B / Escape** | Go back to previous menu or quit application |
| **Left / Right** | Cycle color themes when inside the *Settings* menu |
| **Mouse Drag** | Click and drag to move the window |
| **Mouse Click (top-right)** | Minimize (–) or close (×) the window |

---

## Project Structure

```
Xbox_Launcher/
├── conf.lua      — LÖVE window/config bootstrap
├── main.lua      — All game logic, rendering, and UI (single-file prototype)
├── icons/        — App/platform icons loaded by the menu
├── shaders/      — Reference .glsl shaders (bloom blur, orbital rings)
├── arial.ttf     — Font asset
└── Screenshot_6_07PM_8_24_2026.png — Hero screenshot
```

---

## Requirements

* **LÖVE (Love2D) 11.x** — tested against 11.5 (the current stable release). Download from [love2d.org](https://love2d.org/).
* **OS:** Windows, macOS, or Linux (LÖVE is cross-platform).
* No external dependencies or packages required — pure LÖVE + built-in graphics/shaders.

---

## How to Run

1. Install [LÖVE 11.5](https://love2d.org/download/).
2. Run the project from the project root:

   ```bash
   love .
   ```

   Or double-click the `Love2D XboxLauncher.love` archive (if you have one), or open the folder in LÖVE's app launcher.

3. Navigate with the keyboard or controller, and click the top bar to drag the window.

> **Note:** The menu icons in `icons/` are loaded by name. Any missing icon is skipped silently — the launcher works fine without them.

---

## Building a Distributable

To package as a single `.love` file for distribution:

```bash
love pack .
```

This produces a portable `Xbox_Launcher.love` that runs on any OS with LÖVE installed — ideal for the planned [itch.io](https://itch.io/) release.

---

## Roadmap

See [goals.md](goals.md) for the full feature roadmap. Highlights for the next iteration:

* **Config System** — persist theme, resolution, and window mode to `config.json` via `love.filesystem.getSaveDirectory()`.
* **Shortcut Manager** — user-defined apps/URLs/commands stored in `shortcuts.json`, merged into the live menu.
* **Wizard UI** — multi-step "Add App" flow (type → icon → name → category → save).
* **Settings Expansion** — resolution presets, fullscreen toggle, UI scale, custom theme editor.
* **Gamepad Support** — full `love.gamepad` binding (Xbox layout) for true couch/console feel.
* **Module Refactor** — split `main.lua` into `core/`, `ui/`, and `states/` for maintainability.
* **Performance** — batch static radar background to a single texture, pre-bake bloom passes, and reduce per-frame canvas clears.

---

## License

This project is provided as a prototype for personal and educational use. See [goals.md](goals.md) for distribution and monetization plans (targeting itch.io / Steam as a free or paid utility).

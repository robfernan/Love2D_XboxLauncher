# Xbox Concept Dashboard (Love2D Prototype)

A retro-futuristic, Xbox-inspired desktop launcher prototype built with **Love2D**. It features a custom frameless draggable window, dynamic color theme switching, hierarchical menu navigation with platform/app icons, a multi-pass bloom/blur shader, and an iconic glowing sphere with intersecting orbital wireframe rings.

---

## Features

* **Procedural Glowing Sphere & Orbital Rings**: Features a central glowing planet body wrapped with intersecting rotating wireframe rings and enhanced with multi-pass bloom shader effects.
* **Radar Grid Background**: Dynamic background featuring concentric radar rings and grid cross-hairs.
* **Hierarchical Menu System**: Multi-tier navigation structure supporting category browsing (**Games**, **Browse**, **Media**, **Settings**) and sub-item link launching.
* **Dynamic Color Themes**: Seamlessly cycle through multiple color profiles (**Green**, **Blue**, **Red**, **Purple**) via the settings menu or keyboard shortcuts.
* **Draggable Frameless Window**: Custom window title bar equipped with working minimize and close controls, plus window dragging support.
* **Gamepad & Keyboard Controls**: Fully navigable using directional keys, return/enter, and action prompts.

---

## Controls & Keybindings

| Key / Action | Description |
| :--- | :--- |
| **Up / Down** | Navigate menu items up and down |
| **A / Enter / Keypad Enter** | Select item or open category / launch URL |
| **B / Escape** | Go back to previous menu or quit application |
| **Left / Right** | Cycle color themes when inside the *Settings* menu |
| **Mouse Drag** | Click and drag the top title bar to move the window |

---

## Requirements

* **LÖVE (Love2D)** framework (version 11.x recommended).

---

## How to Run

1. Ensure you have [Love2D](https://love2d.org/) installed on your system.
2. Place your application icons inside an `icons/` folder matching the paths defined in the script (e.g., `icons/steam_icon.png`, `icons/github_icon.png`, etc.).
3. Run the project from your terminal or command prompt:

```bash
love .
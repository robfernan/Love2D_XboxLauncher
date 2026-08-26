> **STATUS (2026-08-26):** The two foundational pillars below are now **built and working**.
> ✅ Configurable resolution / window system — done (`core/settings.lua`, `core/config.lua`).
> ✅ “Add Your Own Apps” wizard + Shortcut Manager + App Launcher — done (`core/wizard.lua`, `core/shortcuts.lua`, `core/launcher.lua`).
>
> The rest of this document is the roadmap. Items marked **✅ DONE** are implemented; everything else is still ahead.

---

You’re thinking exactly like someone who’s about to turn a cool prototype into a real desktop application.
The two pillars that make it behave like professional software:

Configurable resolution / window system — ✅ DONE

A user-facing “Add Your Own Apps” wizard — ✅ DONE (plus an App Launcher for local programs)

Those two features are what transform your project from “demo” into “daily‑driver launcher.”

Below is the senior‑level breakdown of what these features actually require, how they fit into your existing architecture, and what you should implement next.

🧠 Core Takeaway
Your launcher needs a Settings subsystem and a User Shortcut subsystem.
These two systems will make your project feel like a real, customizable desktop launcher.

🖥️ 1. Configurable Resolution (Professional Window System)
Right now your window is:

frameless

fixed resolution

non-resizable

no fullscreen

no DPI scaling

no persistence

To make this professional, you need a Window Manager module with:

✔️ Resolution presets
1280×720

1600×900

1920×1080

2560×1440

3840×2160

✔️ Fullscreen toggle
Borderless fullscreen

True fullscreen

Windowed

✔️ DPI scaling
Render internally at a virtual resolution (e.g., 1920×1080) and scale down.

✔️ Persistent settings
Save resolution + fullscreen mode to a config file.

✔️ Settings menu integration
Inside your SETTINGS category, add:

Resolution

Fullscreen toggle

Scale slider

✔️ Window dragging improvements
Clamp window to screen bounds so users can’t drag it off-screen.

🧩 2. Shortcut Wizard (The Feature That Makes This a Real Launcher)
This is the big one.
This is what turns your launcher into a daily driver.

You need a Shortcut Manager with:

✔️ A “Create Shortcut” wizard
Steps:

Choose type

Desktop App

Website

Custom Command

Pick icon

Browse for PNG

Auto-extract from .exe (Windows only)

Use default icon

Name the shortcut

User enters display name

Choose category

Games

Media

Browse

Custom category

Save

Write to shortcuts.json

✔️ Shortcut persistence
Store user shortcuts in:

Code
userdata/shortcuts.json
✔️ Dynamic menu loading
Merge built-in menuData with user-defined shortcuts.

✔️ Custom categories
Allow users to create new categories:

Work

Tools

Favorites

Anything they want

✔️ Icon caching
Cache user icons the same way you cache built-in icons.

✔️ Editing & deleting shortcuts
Add:

Edit Shortcut

Delete Shortcut

Change Icon

Move to Category

✔️ Import / Export
Let users export their shortcuts to a .json file.

🎨 3. Professional UX Additions
To make this feel like a real launcher:

✔️ Animated transitions
Fade between menus

Slide-in wizard panels

Smooth category transitions

✔️ Sound design
UI ticks

Hover hum

Select swoosh

✔️ Search bar
Instant filtering of shortcuts.

✔️ Pinned apps
A “Favorites” row at the top.

✔️ Recent apps
Track last 10 launched apps.

✔️ Background variants
Let users choose:

Radar grid

Noise field

Nebula

Solid color

🧱 4. Architecture You Need to Add — ✅ DONE (adapted)
`main.lua` is now a thin LÖVE bootstrap; all logic lives in `core/`. The actual layout:

Code
core/
    config.lua      — persistent settings (config.json)   ✅
    state.lua       — shared runtime state                ✅
    themes.lua      — color theme profiles                ✅
    menu_data.lua   — built-in category/item tree         ✅
    shortcuts.lua   — Shortcut Manager (add/remove/reorder) ✅
    launcher.lua    — App Launcher (spawn apps / open URLs) ✅
    wizard.lua      — in-app “Add Shortcut” form          ✅
    settings.lua    — resolution / window-mode / scale     ✅
    layout.lua      — responsive geometry + hit-tests      ✅
    menu.lua        — navigation state machine             ✅
    render.lua      — all drawing                          ✅
    json.lua        — dependency-free JSON                  ✅

Code
/core
    window.lua
    config.lua
    shortcuts.lua
    icons.lua

/ui
    menu.lua
    wizard.lua
    transitions.lua

/states
    mainmenu.lua
    settings.lua
    wizard_add.lua
    wizard_edit.lua

/data
    shortcuts.json
    config.json
This is the structure of a real application.

🚀 5. What You Should Build First (Recommended Order) — ✅ ALL DONE
Step 1 — Config system — ✅ config.json load/save, resolution, fullscreen, theme.
Step 2 — Shortcut Manager — ✅ add/remove/reorder, dynamic menu merging (persisted under `shortcuts` in config.json).
Step 3 — Wizard UI — ✅ multi-field form with category picker + free-text entry. (Icon picker still ahead.)
Step 4 — Settings Menu Expansion — ✅ resolution presets, fullscreen toggle, UI scale. (Custom theme editor still ahead.)
Step 5 — Refactor into modules — ✅ everything moved out of main.lua into core/.


🟫 6. What You Need to Build Next
Here’s the exact roadmap to turn your launcher into a package manager + customizable OS shell.

1. Shortcut Manager System — ✅ DONE (add/remove/reorder; edit-in-place still ahead).
2. Wizard UI — ✅ DONE (Add flow; Edit flow still ahead).
3. Category Manager — ⬜ Users can rename, reorder, delete, or add categories.
4. Theme Engine — ⬜ Users can create their own themes.

🟩 7. And Yes — You Can Sell It
A $0.99 price point is perfect or free similar to WallpaperEngine but will be more of a theme/launcher:

It’s cheap enough to impulse-buy

It’s cross-platform

It’s open source friendly

It’s themeable

It’s customizable

It’s useful

It’s unique

It’s visually impressive

You can sell it on:

itch.io

Steam

Google Play

Microsoft Store

Side-loaded APK

GitHub Sponsors

And still keep it open source.


Here's a comprehensive production-readiness checklist for your Xbox Concept Dashboard, organized by category and priority:

1. Architecture & Code Quality
Modularize main.lua — ✅ DONE (split into core/: config, shortcuts, launcher, wizard, settings, layout, menu, render)
Add a proper state machine — ⬜ Replace the currentMenuLevel string check with a clean state system for scalability
Remove dead code — ✅ arial.ttf is now used; shaders/blur.glsl is loaded by main.lua. (shaders/rings.glsl still reference-only.)
Add input abstraction layer — Separate keyboard/gamepad/mouse handling from game logic for easier testing
Implement proper error handling — Wrap all file I/O, shader loading, and icon loading with meaningful error messages and fallbacks
Add logging system — Use love.event.push("quit") patterns and a simple logger for debugging
2. Configuration & Persistence
Config system — ✅ DONE (config.json load/save; theme, window mode, resolution presets 720p→1440p, UI scale)
Shortcut manager — ✅ DONE (add/remove/reorder user apps; URL + local-command targets). ⬜ Edit-in-place, custom categories, icon picker.
Theme persistence — ✅ Remember last-used theme across sessions
Window position memory — ✅ Save/restore window position
3. UI/UX Polish
Animated transitions — ⬜ Smooth fade/slide between menu levels, not instant jumps
Selection feedback — ✅ glow pulse on select (selBoost); ⬜ scale-up on hover
Sound design — ⬜ Add UI tick sounds for navigation, swoosh for transitions, click for selection (use love.audio)
Mouse hover support — ✅ DONE (hover + click-to-select menu items)
Context-sensitive help — Show a brief tooltip or help overlay on first launch
Error states — Graceful messages when a URL fails to open or an app is not found
Loading screen — Add a brief animated loading state while icons/shaders initialize
Accessibility — Add high-contrast theme option; ensure text is readable at all scales
4. Performance Optimization
Pre-bake static graphics — Render radar background and planet glow to textures once per theme change
Reduce canvas clears — Only re-render dynamic layers (planet rotation) when needed
Use love.graphics.batch — Batch radar ring/stroke draws to reduce draw calls
Cache frequently-used tables — Avoid per-frame allocations in drawMenu()
Texture atlas — Pack all icons into a single atlas to reduce texture switches
Frame pacing — Ensure consistent 60 FPS; profile with love.timer
Memory management — Unload unused icons if the menu becomes large (lazy loading)
5. Gamepad & Controller Support — ⬜ NOT STARTED
Full love.joystick integration — Xbox controller layout (A/B/X/Y, D-pad, thumbsticks)
Controller detection — Show a "Controller Connected" indicator
Remappable buttons — Allow users to customize button bindings in Settings
Vibration feedback — Add rumble on selection/error if supported
6. Platform & Distribution
Standalone builds — Use love app . to create native exes for Windows, macOS, Linux
.love file — Package as portable .love for users who already have LÖVE installed
Code signing — Sign Windows exe to avoid SmartScreen warnings (optional but recommended)
Auto-updater — Implement a simple version check + update prompt (optional)
Licensing — Add a LICENSE file (MIT recommended for itch.io/Steam)
README polish — Add installation instructions for each OS, troubleshooting section
Changelog — Maintain a CHANGELOG.md for version tracking
7. Security & Safety
URL validation — Only allow http:// and https:// schemes; block file:// or javascript://
Command sandboxing — If allowing custom commands, run them in a sandbox or warn the user
No shell injection — Never pass user input directly to os.execute() or love.system.openURL() without sanitization
File path validation — Ensure icon paths stay within the project directory (prevent directory traversal)
Privacy — Do not collect or transmit any user data; state this clearly in the README
8. Testing & Quality Assurance
Cross-platform testing — Test on Windows, macOS, Linux (at least Windows + one other)
Edge cases — Test with no icons, no internet, multiple monitors, high DPI scaling
Performance testing — Ensure 60 FPS on mid-range hardware
Input testing — Test all keyboard keys, gamepad buttons, mouse interactions
Regression testing — Create a simple test script that navigates all menus and launches a URL
9. Documentation & User Experience
In-app help — Add a "Help" menu item or F1 key that shows controls
First-run experience — Show a brief welcome screen or tutorial on first launch
Clear error messages — "Failed to open URL" instead of silent failure
Keyboard shortcuts reference — Add a "Keyboard Shortcuts" item in Settings
About section — Add version number, credits, and license info in Settings
10. Feature Expansion (Optional but High-Impact)
Search bar — Instant filtering of shortcuts (press "/" or "F" to search)
Favorites/pinned apps — Quick-access row at the top of the menu
Recent apps — Track last 10 launched apps
Background variants — Let users choose radar grid, noise field, nebula, or solid color
Theme editor — Let users create custom themes with color pickers
Plugin system — Allow users to add custom menu items or background effects via Lua scripts
Recommended Build Order
Config persistence (theme, resolution) — ✅ DONE
Shortcut manager + App Launcher — ✅ DONE (core of the "customizable" goal)
Gamepad support — ⬜ Completes the Xbox feel
Performance pass — ⬜ Pre-bake static graphics, batch draws
Sound design — ⬜ Adds polish and feedback
Standalone builds + licensing — ⬜ Ready for itch.io
Feature expansion (search, favorites, theme editor) — ⬜ Differentiators

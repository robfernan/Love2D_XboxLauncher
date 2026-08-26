# Xbox Concept Dashboard — Goals & Roadmap

## The North Star

> **A person should be able to make this launcher *theirs* — apps, categories,
> icons, colors, sounds, layout — entirely through the UI. No one who isn't a
> programmer should ever need to open a `.lua` file.**

Everything below is judged against that bar. A feature "counts" when a user can
turn it on and change it from inside the app, and have it survive a restart.

---

## What's Built (✅)

The foundation is in place and working:

- **Modular architecture** — `main.lua` is a thin bootstrap; all logic lives in `core/`. Easy to extend without spaghetti.
- **Config system** — theme, resolution, window mode, UI scale, and window position persist to `config.json`.
- **Shortcut Manager** — add / remove / reorder custom apps & websites (`core/shortcuts.lua`).
- **App Launcher** — launches real local programs (Windows/macOS/Linux) *or* opens URLs (`core/launcher.lua`). This is the "package manager" half.
- **Add-Shortcut wizard** — in-app form for name / type / target / category (`core/wizard.lua`).
- **Settings menu** — resolution presets, Borderless/Windowed/Fullscreen, UI scale (75–150%).
- **Dynamic themes** — 4 built-in profiles, live switching.
- **Draggable frameless window** — custom title bar, minimize/close, clamped dragging.

---

## The Gap: "Customizable" vs. "Fully Customizable Without Code"

Right now a user can *add apps* and *pick from presets*. To hit the north star,
the remaining work is about **user-owned content** — things the user creates or
chooses, not just toggles we ship. Prioritized by impact on that goal:

### Tier 1 — Core customization (do these first)

These turn "launcher with some apps" into "my launcher."

- **Icon picker / custom icons** — browse for a PNG (or auto-extract from a `.exe`) and assign it to any shortcut. *Without this, every user app looks generic.*
- **Edit & delete shortcuts in-place** — rename, change target/icon/category, remove. (Add works today; edit is the missing half.)
- **Category manager** — create / rename / reorder / delete categories (Work, Tools, Favorites…). Today categories are fixed to Games/Browse/Media.
- **Custom theme editor** — pick any accent / background / glow color with sliders or a picker and save it as "My Theme." No more choosing only from the 4 we ship.

### Tier 2 — Feel & discoverability

This is what makes it feel like a finished product rather than a config tool.

- **Gamepad support** — full `love.joystick` binding (Xbox A/B/X/Y, D-pad). You already draw A/B hints; wiring real controller input completes the Xbox identity and matters for couch use.
- **Search / filter bar** — press `/` or `F`, type a few letters, jump to any app instantly. Essential once a user has 30+ shortcuts.
- **Favorites & recents** — a pinned "Favorites" row at top; auto-track the last ~10 launched apps.
- **Sound design** — subtle UI ticks on navigation, a swoosh on menu transitions, a click on select (`love.audio`). Cheap to add, huge for perceived polish.

### Tier 3 — Differentiators (what makes it *yours* vs. Wallpaper Engine)

- **Background variants** — let the user choose radar grid / noise field / nebula / solid color, and ideally drop in their own image as a live background.
- **Animated transitions** — fade/slide between menu levels instead of instant jumps.
- **Import / export** — save the whole setup (shortcuts + categories + theme) to one file; share it or move machines. This is the "package manager" payoff: *distributable user configs.*

---

## Recommendations & Suggestions

1. **Lead with Tier 1.** Icon picker + edit-in-place + category manager + custom themes are the four things that make a non-coder say "this is mine." Everything else is polish on top of those.
2. **One settings surface, not many.** Keep all customization reachable from a single Settings area (or a dedicated "Customize" screen). Scattered options feel like a dev tool; one place feels like a product.
3. **Make defaults great so customization is optional.** A first-run experience should already look good out of the box — then power users dig in. Don't force setup on casuals.
4. **Persist *everything* user-facing** to `config.json` (or a sibling file). If it doesn't survive a restart, it isn't "customizable" yet.
5. **Guard the no-code promise with safe fallbacks.** Bad icon path → fall back to a default glyph. Corrupt config → load defaults and keep the user's last-good copy. Never crash on user input.
6. **Security (since users will point it at real programs):** validate URL schemes (`http`/`https` only), quote/sanitize command paths before `os.execute`, and keep icon paths inside the project dir to avoid traversal.
7. **Ship a `LICENSE` (MIT) + `CHANGELOG.md`.** Cheap, and it signals "real software" for itch.io / Steam.

---

## Suggested Build Order

1. Icon picker + custom icons *(Tier 1)*
2. Edit & delete shortcuts in-place *(Tier 1)*
3. Category manager *(Tier 1)*
4. Custom theme editor *(Tier 1)*
5. Gamepad support *(Tier 2 — completes the Xbox feel)*
6. Search bar + Favorites/Recents *(Tier 2)*
7. Sound design *(Tier 2)*
8. Background variants + animated transitions *(Tier 3)*
9. Import / export configs *(Tier 3 — the "package manager" payoff)*

---

## Distribution & Monetization

A **$0.99** price point (or free) fits: cheap enough to impulse-buy, cross-platform, open-source-friendly, themeable, customizable, useful, and visually distinctive.

Platforms: itch.io · Steam · Microsoft Store · Google Play / side-loaded APK · GitHub Sponsors — while staying open source.

---

## Production Readiness Checklist (condensed)

- **Architecture** ✅ modular `core/` · ⬜ clean state machine for menu levels
- **Persistence** ✅ config + shortcuts · ⬜ edit-in-place, custom categories/themes
- **UX polish** ✅ mouse hover/click, selection glow · ⬜ transitions, sound, tooltips, loading screen
- **Performance** ⬜ pre-bake static radar/planet to textures, batch draws, reduce per-frame canvas clears
- **Gamepad** ⬜ full `love.joystick` (Xbox layout), controller indicator, remappable buttons, rumble
- **Platform** ⬜ standalone builds (`love app .`), code signing, auto-updater, LICENSE + CHANGELOG
- **Security** ⬜ URL scheme validation, command sanitization, icon path containment
- **Testing** ⬜ cross-platform (Win + one other), no-icons/no-internet/multi-monitor/high-DPI edge cases, 60 FPS on mid-range hardware

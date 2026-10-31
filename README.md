# Xbox Concept Dashboard

One **Love2D 11.5** launcher, three console eras. Switch between the **Xbox Original** sci-fi dashboard, the **Xbox 360 NXE** (New Xbox Experience), and the **PlayStation 3 / PSP XMB** (XrossMediaBar), then launch the games, sites, and local programs already on your machine. Keyboard, mouse, and a controller drive the same library.

<p align="center">
  <a href="https://youtu.be/KIvuYsxpoYs">
    <img src="https://i.ytimg.com/vi/KIvuYsxpoYs/maxresdefault.jpg" alt="Watch the demo: Transforming My PC Into a Console" width="720">
  </a>
</p>

**[Watch the demo](https://youtu.be/KIvuYsxpoYs)** — *Transforming My PC Into a Console: Custom Xbox-Styled Launcher (Love2D)*

> **Star [Love2D_XboxLauncher](https://github.com/robfernan/Love2D_XboxLauncher)** if this is the desktop dashboard you wanted.

Cycle eras with **F6**, the controller **Back / Select** button, or the title-bar layout badge. The active layout is saved with the rest of your settings.

---

## Three dashboard eras

### Xbox 360 NXE

![Xbox 360 NXE layout: twilight mountain, reflective floor, and a horizontal card carousel on the Settings channel](Screenshot%202026-10-17%20220017.png)

* Twilight mountain backdrop, star field, and a mirrored floor under the cards.
* Horizontal channel carousel: one large active card, with the rest trailing in perspective.
* Profile tile that shows the local username, with the NXE mail and friend badges beside it.
* Guide-button orb in the corner, with ripple rings on the floor.
* The columns are your real categories: **GAMES**, **BROWSE**, **MEDIA**, and **SETTINGS**. Up and down change category; left and right move the carousel.

### Xbox Original

![Xbox Original layout: glowing planet, orbital rings, radar grid, and trapezoidal GAMES, BROWSE, MEDIA, and SETTINGS blades](Screenshot%202026-10-17%20220030.png)

* Glowing planet and orbital rings over a radar grid, with a bloom pass on the dashboard (`shaders/blur.glsl`).
* Trapezoidal blades and a live connector from the planet to the selected entry.
* Up and down move the blade list. This is the layout where **B / Escape** steps back out of a category.

### PlayStation 3 / PSP XMB

![PlayStation XMB layout: ribbon-wave background, horizontal category icons, and a vertical item column](Screenshot%202026-10-17%20220004.png)

* Procedural ribbon-wave background (`shaders/xmb_wave.glsl`).
* Horizontal category bar and a vertical item column, in the XrossMediaBar pattern. Left and right change category; up and down move the column.
* Face-button hints follow the connected controller: Xbox **A/B/X/Y** or PlayStation **Cross / Circle / Square / Triangle**.

**F6** cycles **Xbox Original → PlayStation XMB → Xbox 360 NXE**. A fresh launch opens on the NXE layout.

---

## What you can launch

* **Programs and URLs.** Executables and scripts spawn detached — Windows `start`, macOS `open`, Linux `setsid` — so they keep running after this window closes. URL shortcuts open in the default browser.
* **Steam library scan.** A pure-Lua reader of `libraryfolders.vdf` and app manifests lists installed Steam games under **GAMES** and launches them with `steam://rungameid/<id>`. It checks the usual install locations on Windows, macOS, and Linux.
* **Drop to add.** Drop an executable, file, or image on the window. The shortcut wizard opens with the name and path filled in.
* **Shortcut wizard.** **Settings → + Add Shortcut…** creates an entry. **Y** or **E** edits the highlighted custom shortcut; **X** removes it. Everything persists in `userdata/config.json`.
* **Quick search.** **Ctrl+F**. On a controller, **Y / Triangle** edits the highlighted custom shortcut, and opens search for everything else.
* **On-screen keyboard.** Console keyboard for the wizard. On a controller: **A** types the highlighted key, **X** backspaces, **Y** inserts a space, **Start** confirms, **B** closes it.
* **Frameless window.** Drag the title bar to move it. Minimize, close, a clock, and the layout badge live on that bar. Quit with the close button.
* **Synthesized UI sounds.** Ticks, backs, and select cues are generated in Love2D at runtime.
* **Themes and scale.** Accents: **Green**, **Blue**, **Red**, **Purple**. Resolutions: **1280×720**, **1600×900**, **1920×1080**, **2560×1440**. UI scale: **75%**, **100%**, **125%**, **150%**. Window mode is **Borderless** or **Windowed**.

---

## Controls

### Keyboard and mouse

| Key / action | What it does |
| :--- | :--- |
| **Up / Down** | Next item. On NXE, next or previous category. |
| **Left / Right** | XMB category, NXE carousel, or the value under a Settings row. |
| **A / Enter** | Open the highlighted category or launch the highlighted item. |
| **B / Escape** | Step back on the Xbox Original layout. Quit with the title-bar close button. |
| **X** | Remove the highlighted custom shortcut. |
| **Y / E** | Edit the highlighted custom shortcut. |
| **F6** | Cycle layout. |
| **Ctrl+F** | Quick search. |
| **Title bar** | Drag to move. **–** minimizes, **✕** closes, the layout badge switches eras. |

### Gamepad

| Button | What it does |
| :--- | :--- |
| **D-pad / left stick** | Move through items, cards, and categories. |
| **A / Cross** | Select or launch. |
| **B / Circle** | Back on the Xbox Original layout. |
| **X / Square** | Remove the highlighted custom shortcut. |
| **Y / Triangle** | Edit a custom shortcut, or open Quick Search. |
| **LB / RB (L1 / R1)** | Switch category. |
| **Back / Select / View** | Cycle layout. |

---

## Run it

[LÖVE 11.5](https://love2d.org/) on Windows, macOS, or Linux. From the repo root:

```bash
love .
```

VS Code’s default build task (**Ctrl+Shift+B**) launches `love.exe` from `C:\Love2D\love-11.5-win64\` on Windows. Shortcuts, theme, scale, window placement, and the active layout are written to `userdata/config.json` (that folder is gitignored).

---

## Project structure

```
Love2D_XboxLauncher/
├── conf.lua                 LÖVE window bootstrap
├── main.lua                 love.* callbacks and input routing
├── core/
│   ├── config.lua           userdata/config.json
│   ├── state.lua            Shared runtime state
│   ├── menu.lua             Navigation state machine
│   ├── menu_data.lua        GAMES, BROWSE, MEDIA, SETTINGS
│   ├── launcher.lua         Detached programs and browser URLs
│   ├── steam.lua            Steam library scanner
│   ├── shortcuts.lua        Custom shortcut storage
│   ├── wizard.lua           Add / edit shortcut modal
│   ├── keyboard.lua         On-screen keyboard
│   ├── search.lua           Quick search overlay
│   ├── gamepad.lua          Controller mapping and prompt glyphs
│   ├── audio.lua            Procedural UI sounds
│   ├── themes.lua           Green, Blue, Red, Purple
│   ├── settings.lua         Resolution, window mode, scale, layout cycle
│   ├── layout.lua           1280×720-relative UI scale
│   ├── render.lua           Title bar, bloom, frame coordination
│   ├── json.lua             Pure-Lua JSON
│   ├── hotreload.lua        Dev reload for Lua and shaders
│   └── layouts/
│       ├── xbox.lua         Xbox Original
│       ├── blades.lua       Xbox 360 NXE
│       └── xmb.lua          PlayStation 3 / PSP XMB
├── icons/                   Menu and platform icons
├── shaders/                 Bloom blur, rings, XMB wave
└── rajdhani.ttf             Dashboard font
```

---

## License

GitHub lists this repository as **NOASSERTION** on purpose. [LICENSE](LICENSE) is a custom source-available grant, and the license detector only fills that field for SPDX identifiers. The label is expected.

You may clone, modify, and run it for personal non-commercial use, and you may share free plugins or themes that interface with it. Packaged binaries and storefront builds stay with the author. Copyright (c) 2026 Robert Fernandez. The exact terms are in [LICENSE](LICENSE).

> **Star [Love2D_XboxLauncher](https://github.com/robfernan/Love2D_XboxLauncher)** so the next person looking for an Xbox, 360 NXE, or XMB desktop can find it.

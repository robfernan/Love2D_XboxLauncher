-- ============================================================================
-- XBOX CONCEPT DASHBOARD - Love2D Prototype
-- A retro-futuristic Xbox-inspired launcher with dynamic themes, glowing
-- orbital planets, radar grid backgrounds, and a draggable frameless window.
--
-- This file is the LÖVE bootstrap only: it wires the love.* callbacks to the
-- modules under core/. All logic lives there — see each module's header for
-- its responsibilities:
--   core/config    — persistent settings (userdata/config.json)
--   core/state     — shared runtime state (single source of truth)
--   core/themes    — color theme profiles
--   core/menu_data — category/item tree + icons
--   core/settings  — resolution / window-mode / scale actions
--   core/layout    — responsive geometry + hit-test helpers
--   core/menu      — navigation state machine (keyboard & mouse paths)
--   core/render    — all drawing: radar bg, planet, bloom, title bar, menu
-- ============================================================================

local Config   = require("core.config")
local State    = require("core.state")
local Settings = require("core.settings")
local Menu     = require("core.menu")
local Layout   = require("core.layout")
local Render   = require("core.render")
local Wizard   = require("core.wizard")

-------------------------------------------------------------------------------
-- Window geometry helpers (LÖVE 11/12 compatible).
-------------------------------------------------------------------------------

-- Desktop size; used to clamp the window so it can never be dragged off-screen.
local function desktopSize()
  if love.window.getDesktopDimensions then
    local w, h = love.window.getDesktopDimensions()
    return w or 1920, h or 1080
  end
  -- LÖVE 11 fallback
  if love.graphics.getScreenSize then
    local w, h = love.graphics.getScreenSize()
    return w, h
  end
  return 1920, 1080
end

-- Current window size.
local function windowSize()
  if love.graphics.getWidth then
    return love.graphics.getWidth(), love.graphics.getHeight()
  end
  if love.window.getDimensions then
    return love.window.getDimensions()
  end
  return 800, 600
end

-- Keep at least a sliver of the window visible on any monitor edge.
local function clampWindowPosition(x, y)
  local ww, wh = windowSize()
  local sw, sh = desktopSize()
  local minx = -(ww - math.min(120, ww))
  local maxx = sw - math.min(120, ww)
  local miny = -(wh - math.min(60, wh))
  local maxy = sh - math.min(60, wh)
  if x < minx then x = minx end
  if x > maxx then x = maxx end
  if y < miny then y = miny end
  if y > maxy then y = maxy end
  return x, y
end

-------------------------------------------------------------------------------
-- Asset initialization (fonts, canvases, shader, icons).
-------------------------------------------------------------------------------

-- Fonts are created at a base pixel size (designed for the 1280x720 reference).
-- They are scaled to match Layout.scale() so text stays proportional to all UI
-- geometry at any resolution. Rebuilt whenever scale changes (resize / uiScale).
local FONT_BASE = { big = 20, small = 14, tiny = 10 }
local lastFontScale = nil

local function makeFont(baseSize)
  -- Bundled arial.ttf; fall back to the default font if it is missing.
  local ok, f = pcall(function()
    return love.graphics.newFont("arial.ttf", baseSize)
  end)
  if ok and f then return f end
  return love.graphics.newFont(baseSize)
end

-- Rebuild all fonts at the current Layout.scale(). Cheap enough to call on any
-- resize/scale change; keeps text crisp and proportional.
local function rebuildFonts()
  local S = Layout.scale()
  if lastFontScale == S then return end
  lastFontScale = S
  State.bigFont   = makeFont(math.max(1, math.floor(FONT_BASE.big * S)))
  State.smallFont = makeFont(math.max(1, math.floor(FONT_BASE.small * S)))
  State.tinyFont  = makeFont(math.max(1, math.floor(FONT_BASE.tiny * S)))
end

local function makeCanvases(w, h)
  State.bgCanvas     = love.graphics.newCanvas(w, h)
  State.planetCanvas = love.graphics.newCanvas(w, h)
  State.bloomA       = love.graphics.newCanvas(w, h)
  State.bloomB       = love.graphics.newCanvas(w, h)
end

-- Load a single icon path into the cache (lazy). Returns the Image or nil.
local function loadIcon(path)
  if not path then return nil end
  local cached = State.iconCache[path]
  if cached then return cached end
  local ok, img = pcall(love.graphics.newImage, path)
  if ok and img then
    State.iconCache[path] = img
    return img
  end
  return nil
end

local function loadIcons()
  local MenuData = require("core.menu_data")
  for _, category in ipairs(MenuData.categories) do
    if category.items then
      for _, item in ipairs(category.items) do
        loadIcon(item.icon)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- LÖVE callbacks
-------------------------------------------------------------------------------

function love.load()
  -- Persistent settings first so window/theme reflect the last session.
  Config.load()
  Settings.syncFromConfig()   -- also applies State.activeTheme from config

  local winW = Config.get("window.width") or 1280
  local winH = Config.get("window.height") or 720
  local borderless = Config.get("window.borderless")
  if type(borderless) ~= "boolean" then borderless = true end
  local resizable = Config.get("window.resizable")
  if type(resizable) ~= "boolean" then resizable = false end
  local fullscreen = Config.get("window.fullscreen")
  if type(fullscreen) ~= "boolean" then fullscreen = false end

  love.window.setTitle("Xbox Concept Dashboard")
  love.window.setMode(winW, winH, {
    resizable = resizable, borderless = borderless,
    fullscreen = fullscreen, vsync = true,
  })

  -- Restore last window position if we have one.
  local savedX = Config.get("window.x")
  local savedY = Config.get("window.y")
  if type(savedX) == "number" and type(savedY) == "number" then
    local cx, cy = clampWindowPosition(savedX, savedY)
    love.window.setPosition(cx, cy)
  end

  -- Separable Gaussian blur shader for the bloom pipeline. Loaded from the
  -- bundled .glsl so it stays in sync with shaders/blur.glsl on disk.
  local ok, src = pcall(function() return love.filesystem.read("shaders/blur.glsl") end)
  if ok and type(src) == "string" then
    local shaderOk, shader = pcall(love.graphics.newShader, src)
    if shaderOk then State.blurShader = shader end
  end

  -- Fonts (bundled arial.ttf with safe fallback), scaled to current layout.
  rebuildFonts()

  -- Render canvases + icon cache.
  local w, h = love.graphics.getDimensions()
  makeCanvases(w, h)
  loadIcons()
end

function love.resize(w, h)
  makeCanvases(w, h)
  rebuildFonts()   -- keep text proportional after a resolution change
end

function love.update(dt)
  State.timeacc     = State.timeacc + dt
  State.menuPulse   = State.menuPulse + dt

  -- Smooth the selection orb toward the active index. Uses Menu.activeIndex()
  -- so the orb follows BOTH keyboard and mouse hover identically.
  local target = Menu.activeIndex()
  if type(target) ~= "number" then target = 1 end
  State.selectionAnim = State.selectionAnim + (target - State.selectionAnim) * math.min(1, dt * 10)

  -- Window dragging: follow the cursor, clamped to desktop bounds.
  if State.isDragging then
    local mx, my = love.mouse.getPosition()
    local wx, wy = love.window.getPosition()
    local nx, ny = clampWindowPosition(wx + (mx - State.dragX), wy + (my - State.dragY))
    love.window.setPosition(nx, ny)
  end
end

function love.draw()
  Render.frame()
  -- Add-shortcut wizard overlay (drawn on top when open).
  if Wizard.isOpen() then
    Wizard.render()
  end
end

-------------------------------------------------------------------------------
-- MOUSE INPUT: hover tracking + click-to-activate + title bar buttons + drag.
-- Click-vs-drag is decided on release using a small movement threshold so a
-- window move never accidentally activates the item under the cursor.
-------------------------------------------------------------------------------

function love.mousemoved(x, y)
  State.mouseX, State.mouseY = x, y
  Menu.updateHover(x, y)
end

function love.mousepressed(x, y, button)
  State.mouseX, State.mouseY = x, y
  if button == 1 then
    local btns = Layout.titleBarButtons()
    -- Close (top-right X) — the ONLY way to quit the app.
    if Layout.pointInRect(x, y, btns.close) then
      Config.save()
      love.event.quit()
      return
    end
    -- Minimize (top-right dash).
    if Layout.pointInRect(x, y, btns.minimize) then
      Config.save()
      love.window.minimize()
      return
    end

    -- Only the title bar initiates a window drag. Clicking anywhere else is a
    -- pure click (no accidental window moves from a small cursor slip).
    if y <= btns.barH then
      State.pressX, State.pressY = x, y
      State.isDragging = true
      State.dragX, State.dragY = x, y
    end
  end
end

function love.mousereleased(x, y, button)
  if button ~= 1 then return end

  if State.isDragging then
    -- Press started in the title bar: decide click-vs-drag on release.
    State.isDragging = false
    local dx, dy = math.abs(x - State.pressX), math.abs(y - State.pressY)
    if dx > State.DRAG_THRESHOLD or dy > State.DRAG_THRESHOLD then
      -- It was a drag: persist the new window position.
      local wx, wy = love.window.getPosition()
      Config.set("window.x", math.floor(wx))
      Config.set("window.y", math.floor(wy))
    else
      -- Barely moved — treat as a click on the title bar (no-op; buttons are
      -- handled in mousepressed). Ignore so we don't double-activate.
    end
  else
    -- Press started outside the title bar: it's a pure menu click. Priority:
    --   1) the bottom-left B / A hint badges (act as real buttons),
    --   2) any menu item under the cursor.
    Menu.handleClick(x, y)
  end
end

-------------------------------------------------------------------------------
-- KEYBOARD INPUT: hierarchical navigation + Settings cycling + link launching.
-- Uses the same shared helpers as the mouse path so both stay in sync.
-------------------------------------------------------------------------------

function love.keypressed(key)
  -- While the add-shortcut wizard is open, it owns all keyboard input.
  if Wizard.isOpen() and Wizard.keypressed(key) then
    return
  end

  -- Ignore modifier-key combos (Ctrl/Alt/Shift + letter) so they don't trigger
  -- menu actions. Plain letters still work as expected.
  local ctrlDown = love.keyboard.isDown("lctrl", "rctrl")
  local altDown = love.keyboard.isDown("lalt", "ralt")
  local guiDown = love.keyboard.isDown("lgui", "rgui")
  if ctrlDown or altDown or guiDown then
    return
  end

  if key == "down" then
    Menu.moveSelection(1)
  elseif key == "up" then
    Menu.moveSelection(-1)
  -- Left/Right cycles the *currently highlighted* Settings option.
  elseif (key == "left" or key == "right") and State.currentMenuLevel == "SETTINGS" then
    Menu.cycleSettingsOption((key == "right") and 1 or -1)
  -- A / Enter activates the currently highlighted item.
  elseif key == "a" or key == "return" or key == "kpenter" then
    Menu.activateItem(Menu.activeIndex())
  -- X removes a user shortcut (only works on items that have a shortcutId).
  elseif key == "x" then
    local items = Menu.activeItems()
    local idx = Menu.activeIndex()
    local item = items and items[idx]
    if item and item.shortcutId then
      require("core.shortcuts").remove(item.shortcutId)
    end
  -- B / Escape only go BACK one level. At MAIN they do nothing — the app can
  -- ONLY be quit via the title-bar X button (per design).
  elseif key == "b" or key == "escape" then
    Menu.goBack()
  end
end

-- Guarantee settings are written on every exit path (title-bar X, OS close).
function love.quit()
  local wx, wy = love.window.getPosition()
  Config.set("window.x", math.floor(wx))
  Config.set("window.y", math.floor(wy))
  Config.save()
end


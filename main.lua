-- ============================================================================
-- XBOX CONCEPT DASHBOARD - Love2D Prototype
-- A retro-futuristic Xbox-inspired launcher with dynamic themes, glowing
-- orbital planets, radar grid backgrounds, and a draggable frameless window.
-- ============================================================================

-- Persistent settings (theme, window mode/size). Loaded in love.load().
local Config = require("core.config")

local timeacc = 0
local selected = 1
local activeTheme = 4   -- initialized from Config in love.load()
local bigFont, smallFont, tinyFont
local bgCanvas, planetCanvas
local selectionAnim = 1.0
local menuPulse = 0
local blurShader, bloomA, bloomB

-- Mouse state: hovered item index (per current level) + last mouse position.
local mouseX, mouseY = 0, 0
local hoverIndex = 0        -- 0 = nothing hovered; otherwise 1-based item index

-- Navigation State Machine
local currentMenuLevel = "MAIN" -- "MAIN" or category name like "GAMES", "BROWSE", "MEDIA", "SETTINGS"
local subSelected = 1

-- Icon Cache Table
local iconCache = {}

-- Menu Data Structure mapping categories to items with icons and actions
local menuData = {
  { name = "GAMES", id = "GAMES", items = {
    { name = "Steam",      url = "https://store.steampowered.com", icon = "icons/steam_icon.png" },
    { name = "Epic Games", url = "https://epicgames.com",          icon = "icons/epicgames_icon.png" },
    { name = "Itch.io",    url = "https://itch.io",                icon = "icons/itchio_icon.png" },
    { name = "GOG",        url = "https://gog.com",                icon = "icons/gog_icon.png" },
  }},
  { name = "BROWSE", id = "BROWSE", items = {
    { name = "GitHub",     url = "https://github.com",             icon = "icons/github_icon.png" },
    { name = "YouTube",    url = "https://youtube.com",            icon = "icons/youtube_icon.png" },
    { name = "Pinterest",  url = "https://pinterest.com",          icon = "icons/pinterest_icon.png" },
  }},
  { name = "MEDIA", id = "MEDIA", items = {
    { name = "Netflix",    url = "https://netflix.com",            icon = "icons/netflix_icon.png" },
    { name = "Spotify",    url = "https://spotify.com",            icon = "icons/spotify_icon.png" },
    { name = "Twitch",     url = "https://twitch.tv",              icon = "icons/twitch_icon.png" },
    { name = "Crunchyroll",url = "https://crunchyroll.com",        icon = "icons/crunchyroll_icon.png" },
  }},
  { name = "SETTINGS", id = "SETTINGS", items = {
    { name = "Theme: Purple",        action = "CYCLE_THEME",   icon = "icons/theme_icon.png" },
    { name = "Resolution: 1280x720", action = "CYCLE_RES",     icon = nil },
    { name = "Fullscreen: Off",      action = "TOGGLE_FS",     icon = nil },
    { name = "Window: Borderless",   action = "CYCLE_WINMODE", icon = nil },
    { name = "UI Scale: 100%",       action = "CYCLE_SCALE",   icon = nil },
  }}
}

-- Window dragging state variables
local isDragging = false
local dragX, dragY = 0, 0

-- Resolution presets (cycled by the Settings > Resolution item).
local resPresets = {
  { w = 1280, h = 720 },
  { w = 1600, h = 900 },
  { w = 1920, h = 1080 },
  { w = 2560, h = 1440 },
}
local resIndex = 1

-- Window mode cycle: borderless -> windowed(resizable) -> fullscreen(desktop)
local winModes = {
  { name = "Borderless", borderless = true,  resizable = false, fullscreen = false },
  { name = "Windowed",   borderless = false, resizable = true,  fullscreen = false },
  { name = "Fullscreen", borderless = true,  resizable = false, fullscreen = true  },
}
local winModeIndex = 1

-- UI scale presets (cycled by Settings > UI Scale).
local scalePresets = { 0.75, 1.0, 1.25, 1.5 }
local scaleIndex = 2

-- ============================================================================
-- RESPONSIVE LAYOUT
-- All UI geometry is expressed relative to a 1280x720 reference so the layout
-- looks identical at any window resolution (no more dead space / cut-off).
-- `uiScale` (user setting) multiplies on top for accessibility.
-- ============================================================================
local REF_W, REF_H = 1280, 720

-- Current responsive scale factor (window-relative * user uiScale).
local function layoutScale()
  local w, h = love.graphics.getDimensions()
  -- Scale by the smaller axis ratio so we never overflow either dimension.
  local base = math.min(w / REF_W, h / REF_H)
  local user = Config.get("uiScale")
  if type(user) ~= "number" then user = 1.0 end
  return base * user
end

-- Available dashboard color themes (Primary Accent, Background, Glow/UI Color)
local themeColors = {
  {name = "Green",  color = {0.18, 1.00, 0.38}, bg = {0.02, 0.05, 0.03}, glow = {0.20, 1.00, 0.45}},
  {name = "Blue",   color = {0.18, 0.75, 1.00}, bg = {0.01, 0.03, 0.06}, glow = {0.25, 0.85, 1.00}},
  {name = "Red",    color = {1.00, 0.25, 0.25}, bg = {0.06, 0.01, 0.01}, glow = {1.00, 0.30, 0.30}},
  {name = "Purple", color = {0.95, 0.20, 1.00}, bg = {0.04, 0.00, 0.05}, glow = {1.00, 0.35, 1.00}},
}

-- Helper function to fetch the currently active theme table
local function currentTheme()
  return themeColors[activeTheme] or themeColors[4]
end

-- Helper function to return total theme count
local function themeCount()
  return #themeColors
end

-- Cycle through available color themes (and persist the choice).
local function cycleTheme(delta)
  activeTheme = ((activeTheme - 1 + delta) % themeCount()) + 1
  Config.set("theme.index", activeTheme)
  -- Keep the Settings label live.
  local cat = menuData[4]
  if cat and cat.items then
    for _, it in ipairs(cat.items) do
      if it.action == "CYCLE_THEME" then it.name = "Theme: " .. currentTheme().name end
    end
  end
end

-- Apply a window mode (borderless / windowed / fullscreen) live and persist it.
local function applyWindowMode(idx)
  winModeIndex = ((idx - 1) % #winModes + 1)
  local m = winModes[winModeIndex]
  Config.set("window.borderless", m.borderless)
  Config.set("window.resizable", m.resizable)
  Config.set("window.fullscreen", m.fullscreen)
  love.window.setMode(
    Config.get("window.width") or 1280,
    Config.get("window.height") or 720,
    { borderless = m.borderless, resizable = m.resizable, fullscreen = m.fullscreen, vsync = true }
  )
  -- Keep the Settings label live.
  local cat = menuData[4]
  if cat and cat.items then
    for _, it in ipairs(cat.items) do
      if it.action == "CYCLE_WINMODE" then it.name = "Window: " .. m.name end
    end
  end
end

-- Cycle resolution preset, apply live, persist.
local function cycleResolution(delta)
  resIndex = ((resIndex - 1 + delta) % #resPresets + 1)
  local p = resPresets[resIndex]
  Config.set("window.width", p.w)
  Config.set("window.height", p.h)
  -- Re-apply current window mode at the new size.
  applyWindowMode(winModeIndex)
  -- Keep the Settings label live.
  local cat = menuData[4]
  if cat and cat.items then
    for _, it in ipairs(cat.items) do
      if it.action == "CYCLE_RES" then it.name = string.format("Resolution: %dx%d", p.w, p.h) end
    end
  end
end

-- Toggle fullscreen on/off (quick action).
local function toggleFullscreen()
  local isFs = Config.get("window.fullscreen")
  if type(isFs) ~= "boolean" then isFs = false end
  -- Switch to the Fullscreen mode preset, or back to Borderless.
  applyWindowMode(isFs and 1 or 3)
  -- Keep the Settings label live.
  local cat = menuData[4]
  if cat and cat.items then
    for _, it in ipairs(cat.items) do
      if it.action == "TOGGLE_FS" then
        it.name = (Config.get("window.fullscreen") and true or false) and "Fullscreen: On" or "Fullscreen: Off"
      end
    end
  end
end

-- Cycle UI scale preset, persist.
local function cycleScale(delta)
  scaleIndex = ((scaleIndex - 1 + delta) % #scalePresets + 1)
  local s = scalePresets[scaleIndex]
  Config.set("uiScale", s)
  -- Keep the Settings label live.
  local cat = menuData[4]
  if cat and cat.items then
    for _, it in ipairs(cat.items) do
      if it.action == "CYCLE_SCALE" then it.name = string.format("UI Scale: %d%%", math.floor(s * 100)) end
    end
  end
end

-- Load and cache all icons defined in menuData safely
local function loadIcons()
  for _, category in ipairs(menuData) do
    if category.items then
      for _, item in ipairs(category.items) do
        if item.icon and not iconCache[item.icon] then
          local success, img = pcall(love.graphics.newImage, item.icon)
          if success then
            iconCache[item.icon] = img
          end
        end
      end
    end
  end
end

-- Draws the background radar grid lines centered on screen
local function drawRadarBackground(w, h)
  local theme = currentTheme()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  love.graphics.setBlendMode("alpha")
  
  -- Concentric radar rings
  love.graphics.push()
  love.graphics.translate(w * 0.5, h * 0.5)
  local maxr = math.max(w, h) * 0.75
  for i = 1, 10 do
    love.graphics.setLineWidth(i == 1 and 1.5 or 1.0)
    love.graphics.setColor(glowR, glowG, glowB, 0.04 + (i * 0.005))
    love.graphics.circle("line", 0, 0, maxr * (i / 10))
  end

  -- Diagonal cross-hairs / radar grid vectors
  for angle = 0, math.pi * 2, math.pi * 0.25 do
    love.graphics.setColor(glowR, glowG, glowB, 0.03)
    love.graphics.line(0, 0, math.cos(angle) * maxr, math.sin(angle) * maxr)
  end
  love.graphics.pop()
end

-- Apply a saved theme index (clamped to the valid range).
local function applyThemeIndex(idx)
  local n = themeCount()
  activeTheme = ((idx - 1) % n + 1)
end

-- Clamp the window so it can never be dragged fully off-screen.
-- Uses love.window.getDesktopDimensions() (valid in update/draw on LÖVE 11 & 12),
-- falling back to getScreenSize for older builds.
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

local function windowSize()
  -- LÖVE 12: graphics.getWidth/Height give the current window size.
  if love.graphics.getWidth then
    return love.graphics.getWidth(), love.graphics.getHeight()
  end
  -- LÖVE 11 fallback
  if love.window.getDimensions then
    return love.window.getDimensions()
  end
  return 800, 600
end

local function clampWindowPosition(x, y)
  local ww, wh = windowSize()
  local sw, sh = desktopSize()
  local minx = -(ww - math.min(120, ww))         -- keep at least 120px visible
  local maxx = sw - math.min(120, ww)
  local miny = -(wh - math.min(60, wh))
  local maxy = sh - math.min(60, wh)
  if x < minx then x = minx end
  if x > maxx then x = maxx end
  if y < miny then y = miny end
  if y > maxy then y = maxy end
  return x, y
end

function love.load()
  -- Load persistent settings first so window/theme reflect the last session.
  Config.load()
  applyThemeIndex(Config.get("theme.index") or activeTheme)

  local winW = Config.get("window.width") or 1280
  local winH = Config.get("window.height") or 720
  local borderless = Config.get("window.borderless")
  if type(borderless) ~= "boolean" then borderless = true end
  local resizable = Config.get("window.resizable")
  if type(resizable) ~= "boolean" then resizable = false end
  local fullscreen = Config.get("window.fullscreen")
  if type(fullscreen) ~= "boolean" then fullscreen = false end

  -- Sync the Settings state (resIndex / winModeIndex / scaleIndex) to saved values.
  for i, p in ipairs(resPresets) do
    if p.w == winW and p.h == winH then resIndex = i break end
  end
  if fullscreen then
    winModeIndex = 3
  elseif borderless then
    winModeIndex = 1
  else
    winModeIndex = 2
  end
  local savedScale = Config.get("uiScale")
  if type(savedScale) == "number" then
    for i, s in ipairs(scalePresets) do
      if math.abs(s - savedScale) < 0.01 then scaleIndex = i break end
    end
  end

  love.window.setTitle("Xbox Concept Dashboard")
  -- Configure window from saved settings (frameless, vsync enabled).
  love.window.setMode(winW, winH, {resizable=resizable, borderless=borderless, fullscreen=fullscreen, vsync=true})

  -- Restore last window position if we have one.
  local savedX = Config.get("window.x")
  local savedY = Config.get("window.y")
  if type(savedX) == "number" and type(savedY) == "number" then
    local cx, cy = clampWindowPosition(savedX, savedY)
    love.window.setPosition(cx, cy)
  end

  -- Inline separable Gaussian blur shader for the bloom effect
  local blurCode = [[
    extern vec2 resolution;
    extern vec2 direction;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      vec4 sum = vec4(0.0);
      vec2 tc = texture_coords;
      float blur = 2.0 / resolution.x;
      sum += Texel(texture, tc - 4.0 * blur * direction) * 0.05;
      sum += Texel(texture, tc - 3.0 * blur * direction) * 0.09;
      sum += Texel(texture, tc - 2.0 * blur * direction) * 0.12;
      sum += Texel(texture, tc - 1.0 * blur * direction) * 0.15;
      sum += Texel(texture, tc) * 0.18;
      sum += Texel(texture, tc + 1.0 * blur * direction) * 0.15;
      sum += Texel(texture, tc + 2.0 * blur * direction) * 0.12;
      sum += Texel(texture, tc + 3.0 * blur * direction) * 0.09;
      sum += Texel(texture, tc + 4.0 * blur * direction) * 0.05;
      return sum * color;
    }
  ]]
  pcall(function() blurShader = love.graphics.newShader(blurCode) end)

  -- Initialize fonts using the bundled arial.ttf (falls back to default if missing).
  local function makeFont(size)
    local ok, f = pcall(function()
      return love.graphics.newFont("arial.ttf", size)
    end)
    if ok and f then return f end
    return love.graphics.newFont(size)   -- safe fallback
  end
  bigFont = makeFont(20)
  smallFont = makeFont(14)
  tinyFont = makeFont(10)

  -- Initialize render canvases for background and blooming layers
  local w, h = love.graphics.getDimensions()
  bgCanvas = love.graphics.newCanvas(w, h)
  planetCanvas = love.graphics.newCanvas(w, h)
  bloomA = love.graphics.newCanvas(w, h)
  bloomB = love.graphics.newCanvas(w, h)

  -- Load all platform/app icons into memory
  loadIcons()
end

function love.resize(w, h)
  bgCanvas = love.graphics.newCanvas(w, h)
  planetCanvas = love.graphics.newCanvas(w, h)
  bloomA = love.graphics.newCanvas(w, h)
  bloomB = love.graphics.newCanvas(w, h)
end

function love.update(dt)
  timeacc = timeacc + dt
  menuPulse = menuPulse + dt

  local targetSelection = (currentMenuLevel == "MAIN") and selected or subSelected
  selectionAnim = selectionAnim + (targetSelection - selectionAnim) * math.min(1, dt * 10)

  if isDragging then
    local mx, my = love.mouse.getPosition()
    local wx, wy = love.window.getPosition()
    local nx, ny = clampWindowPosition(wx + (mx - dragX), wy + (my - dragY))
    love.window.setPosition(nx, ny)
  end
end

-- ============================================================================
-- SHARED MENU HELPERS (used by both keyboard and mouse paths)
-- Defined BEFORE drawMenu so it can call them at runtime.
-- ============================================================================

-- Return the list of items visible at the current menu level.
local function activeItems()
  if currentMenuLevel == "MAIN" then
    local out = {}
    for _, cat in ipairs(menuData) do table.insert(out, { name = cat.name }) end
    return out
  end
  for _, cat in ipairs(menuData) do
    if cat.id == currentMenuLevel then return cat.items or {} end
  end
  return {}
end

-- Return the currently active (selected/hovered) 1-based index.
local function activeIndex()
  if hoverIndex > 0 then return hoverIndex end
  return (currentMenuLevel == "MAIN") and selected or subSelected
end

-- Perform the action for a given item at the current level (select/launch/cycle).
local function activateItem(idx)
  local items = activeItems()
  local item = items[idx]
  if not item then return end

  if currentMenuLevel == "MAIN" then
    -- Enter the category.
    local cat = menuData[idx]
    if cat then
      currentMenuLevel = cat.id
      subSelected = 1
      selected = idx
      hoverIndex = 0
      selectionAnim = 1
    end
    return
  end

  -- Sub-menu item: run its action.
  local action = item.action
  if action == "CYCLE_THEME" then
    cycleTheme(1)
  elseif action == "CYCLE_RES" then
    cycleResolution(1)
  elseif action == "TOGGLE_FS" then
    toggleFullscreen()
  elseif action == "CYCLE_WINMODE" then
    applyWindowMode(winModeIndex + 1)
  elseif action == "CYCLE_SCALE" then
    cycleScale(1)
  elseif item.url then
    love.system.openURL(item.url)
  end
end

-- Compute the screen-space rect for menu item `idx` at the current level.
-- MUST match drawMenu's geometry exactly (same layoutScale-based sizing).
local function menuItemRect(idx)
  local w, h = love.graphics.getDimensions()
  local S = layoutScale()
  local cx, cy = w * 0.44, h * 0.5
  local itemW, itemH, spacing = 290 * S, 48 * S, 12 * S
  local items = activeItems()
  local y = cy - (#items * (itemH + spacing)) / 2 + (idx - 1) * (itemH + spacing)
  return cx, y, itemW, itemH
end

-- Renders interactive dashboard menu items with trapezoidal 3D styling and loaded icons.
-- All geometry is scaled by layoutScale() so it stays proportional at any resolution.
local function drawMenu()
  local w, h = love.graphics.getDimensions()
  local S = layoutScale()
  local cx, cy = w * 0.44, h * 0.5
  local itemW, itemH = 290 * S, 48 * S
  local spacing = 12 * S
  local theme = currentTheme()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local items = activeItems()
  local curIdx = activeIndex()

  -- Connector line linking the central planet/orb to the menu selection
  local selY = cy - (#items * (itemH + spacing)) / 2 + (curIdx - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setColor(themeR, themeG, themeB, 0.4)
  love.graphics.setLineWidth(1.5 * S)
  love.graphics.line(w * 0.18 + 75 * S, cy, cx, selY)

  love.graphics.setFont(bigFont)
  for i, item in ipairs(items) do
    local y = cy - (#items * (itemH + spacing)) / 2 + (i - 1) * (itemH + spacing)
    local isSelected = (i == curIdx)
    local selBoost = isSelected and (0.05 * math.sin(menuPulse * 6.0) + 0.05) or 0

    -- Drop shadow / 3D button extrusion effect (scaled)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.polygon("fill",
      cx + 12*S, y + 10*S,
      cx + itemW - 8*S, y + 10*S,
      cx + itemW + 16*S, y + itemH * 0.5,
      cx + itemW - 8*S, y + itemH + 10*S,
      cx + 12*S, y + itemH + 10*S,
      cx + 24*S, y + itemH * 0.5 + 10*S
    )
    love.graphics.setColor(0.06, 0.01, 0.09, isSelected and 0.6 or 0.35)
    love.graphics.polygon("fill",
      cx + 6*S, y + 5*S,
      cx + itemW - 16*S, y + 5*S,
      cx + itemW + 4*S, y + itemH * 0.5,
      cx + itemW - 16*S, y + itemH + 5*S,
      cx + 6*S, y + itemH + 5*S,
      cx + 18*S, y + itemH * 0.5 + 5*S
    )

    -- Main trapezoidal button body
    local baseColor = isSelected and {
      themeR * (0.8 + selBoost),
      themeG * (0.8 + selBoost),
      themeB * (0.8 + selBoost)
    } or {themeR * 0.18, themeG * 0.18, themeB * 0.18}
    
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], isSelected and 0.98 or 0.45)
    love.graphics.polygon("fill",
      cx, y,
      cx + itemW - 24*S, y,
      cx + itemW - 4*S, y + itemH * 0.5,
      cx + itemW - 24*S, y + itemH,
      cx, y + itemH,
      cx + 14*S, y + itemH * 0.5
    )

    -- Top surface highlight sheen (scaled)
    love.graphics.setColor(1, 1, 1, isSelected and 0.15 or 0.05)
    love.graphics.polygon("fill",
      cx + 4*S, y + 2*S,
      cx + itemW - 26*S, y + 2*S,
      cx + itemW - 10*S, y + 6*S,
      cx + 4*S, y + 6*S
    )

    -- Draw Icon if available (scaled)
    local textOffsetX = 45 * S
    if item.icon and iconCache[item.icon] then
      local iconImg = iconCache[item.icon]
      local iw, ih = iconImg:getDimensions()
      local scale = (30 * S) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
      love.graphics.draw(iconImg, cx + 12*S, y + (itemH * 0.5) - (ih * scale * 0.5), 0, scale, scale)
      textOffsetX = 52 * S
    end

    -- Label text (Settings items carry live-updated names from the action handlers)
    love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.6)
    love.graphics.print(item.name, cx + textOffsetX, y + 12 * S)
  end

  -- Animated glowing selection orb indicator next to active menu item (scaled)
  local selYAnim = cy - (#items * (itemH + spacing)) / 2 + (selectionAnim - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.circle("fill", cx - 36*S, selYAnim, 26*S)
  love.graphics.setColor(glowR, glowG, glowB, 1.0)
  love.graphics.circle("fill", cx - 36*S, selYAnim, 12*S)
  love.graphics.setBlendMode("alpha")
end

-- Renders the iconic Xbox glowing sphere with intersecting orbital wireframe rings across its body
local function drawPlanetAndRings()
  local w, h = love.graphics.getDimensions()
  local S = layoutScale()
  local cx, cy = w * 0.18, h * 0.5
  local spin = timeacc * 0.5
  local pulse = 1.0 + 0.03 * math.sin(timeacc * 2.5)
  local theme = currentTheme()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  love.graphics.setCanvas(planetCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.push()
  love.graphics.translate(cx, cy)

  -- 1. Outer planetary pulsing glow halos (scaled)
  love.graphics.setBlendMode("add")
  for i = 1, 4 do
    local r = (70 + i * 14) * S * pulse
    love.graphics.setColor(glowR, glowG, glowB, 0.12 / i)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- 2. Central glowing sphere body with radial gradient layers (scaled)
  love.graphics.setBlendMode("alpha")
  local sphereRadius = 75 * S * pulse
  for i = 30, 1, -1 do
    local t = i / 30
    local r = sphereRadius * t
    local mixVal = 1.0 - t
    local colR = themeR * (0.15 + 0.85 * mixVal)
    local colG = themeG * (0.15 + 0.85 * mixVal)
    local colB = themeB * (0.15 + 0.85 * mixVal)
    love.graphics.setColor(colR, colG, colB, 0.9)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- Core specular highlights on sphere (scaled offsets; radii already scale via sphereRadius)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.8)
  love.graphics.circle("fill", -12*S, -12*S, sphereRadius * 0.3)
  love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
  love.graphics.circle("fill", -18*S, -18*S, sphereRadius * 0.12)

  -- 3. Intersecting orbital wireframe loops wrapping across the sphere surface
  local ringCount = 5
  for i = 1, ringCount do
    love.graphics.push()
    local angleRot = spin * (0.4 + i * 0.2) + (i * math.pi / ringCount)
    love.graphics.rotate(angleRot)
    love.graphics.scale(1.0, 0.38)
    love.graphics.setLineWidth(1.2 * S)
    love.graphics.setColor(themeR, themeG, themeB, 0.75)
    love.graphics.circle("line", 0, 0, sphereRadius * (0.95 + i * 0.04))
    love.graphics.pop()
  end

  love.graphics.pop()
  love.graphics.setCanvas()
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local S = layoutScale()
  local theme = currentTheme()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  -- 1. Render Radar Background Canvas
  love.graphics.setCanvas(bgCanvas)
  love.graphics.clear(theme.bg[1], theme.bg[2], theme.bg[3], 1)
  drawRadarBackground(w, h)
  love.graphics.setCanvas()

  -- 2. Render Planet & Orbital Rings Canvas
  drawPlanetAndRings()

  -- 3. Draw Background Canvas to Screen
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(bgCanvas, 0, 0)

  -- 4. Apply Multi-pass Bloom / Blur Shader to Planet and Rings Canvas
  if blurShader then
    love.graphics.setCanvas(bloomA)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("add")
    love.graphics.draw(planetCanvas, 0, 0)
    love.graphics.setCanvas()

    blurShader:send("resolution", {w, h})
    blurShader:send("direction", {1, 0})
    love.graphics.setShader(blurShader)
    love.graphics.setCanvas(bloomB)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(bloomA, 0, 0)
    love.graphics.setCanvas()

    blurShader:send("direction", {0, 1})
    love.graphics.setCanvas(bloomA)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(bloomB, 0, 0)
    love.graphics.setCanvas()
    love.graphics.setShader()

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.draw(bloomA, 0, 0)
  end

  -- 5. Draw Crisp Planet & Rings Layer over Bloom
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(planetCanvas, 0, 0)

  -- 6. Render Custom Window Title Bar at the Top (responsive height/buttons)
  local barH = 32 * S
  love.graphics.setColor(0.02, 0.02, 0.03, 0.85)
  love.graphics.rectangle("fill", 0, 0, w, barH)
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.line(0, barH, w, barH)

  local btnSize = 20 * S
  local btnPad = 6 * S
  love.graphics.setFont(smallFont)
  love.graphics.setColor(glowR, glowG, glowB, 0.9)
  love.graphics.print("Xbox Concept Dashboard", 14 * S, (barH - smallFont:getHeight()) / 2)
  love.graphics.setColor(glowR, glowG, glowB, 0.5)
  local dragLabel = "DRAG TO MOVE"
  love.graphics.print(dragLabel, w * 0.5 - smallFont:getWidth(dragLabel) / 2, (barH - smallFont:getHeight()) / 2)

  -- Window Control Buttons (Top Right, scaled)
  local closeX = w - btnPad - btnSize
  local minBtnX = closeX - btnSize - 8 * S
  local btnY0 = (barH - btnSize) / 2
  -- Minimize button (-)
  love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
  love.graphics.rectangle("fill", minBtnX, btnY0, btnSize, btnSize, 3 * S, 3 * S)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.rectangle("fill", minBtnX + (btnSize - 10*S)/2, barH/2 - 1*S, 10*S, 2*S)

  -- Close button (X) — the ONLY way to quit the app.
  love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", closeX, btnY0, btnSize, btnSize, 3 * S, 3 * S)
  love.graphics.setColor(1, 1, 1, 0.9)
  local xLabel = "x"
  love.graphics.print(xLabel, closeX + (btnSize - smallFont:getWidth(xLabel))/2, btnY0 + (btnSize - smallFont:getHeight())/2)

  -- 7. Render Menu UI Elements
  drawMenu()

  -- 8. Controller / Key Action Hints (responsive, pinned bottom-left)
  local hintR = 11 * S
  local btnY = h - 28 * S
  local startX = 40 * S
  love.graphics.setFont(smallFont)

  -- Back Button (B) — goes back one level; does NOT quit at MAIN.
  love.graphics.setColor(1.0, 0.2, 0.2)
  love.graphics.circle("fill", startX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local bLabel = "B"
  love.graphics.print(bLabel, startX + hintR - smallFont:getWidth(bLabel)/2, btnY - smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("BACK", startX + hintR*2 + 8*S, btnY - smallFont:getHeight()/2)

  -- Select Button (A)
  local selectX = startX + 110 * S
  love.graphics.setColor(0.18, 0.85, 0.35)
  love.graphics.circle("fill", selectX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local aLabel = "A"
  love.graphics.print(aLabel, selectX + hintR - smallFont:getWidth(aLabel)/2, btnY - smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("SELECT", selectX + hintR*2 + 8*S, btnY - smallFont:getHeight()/2)
end

-- ============================================================================
-- MOUSE INPUT: hover tracking + click-to-activate + title bar buttons + drag.
-- ============================================================================

function love.mousemoved(x, y)
  mouseX, mouseY = x, y
  -- Update hover index based on which menu item the cursor is over.
  local items = activeItems()
  local found = 0
  for i = 1, #items do
    local ix, iy, iw, ih = menuItemRect(i)
    if x >= ix and x <= ix + iw and y >= iy and y <= iy + ih then
      found = i
      break
    end
  end
  hoverIndex = found
end

-- Compute the responsive title-bar button rects (must match love.draw's layout).
local function titleBarButtons()
  local w, h = love.graphics.getDimensions()
  local S = layoutScale()
  local barH = 32 * S
  local btnSize = 20 * S
  local btnPad = 6 * S
  local closeX = w - btnPad - btnSize
  local minBtnX = closeX - btnSize - 8 * S
  local btnY0 = (barH - btnSize) / 2
  return {
    close = { x = closeX, y = btnY0, w = btnSize, h = btnSize },
    minimize = { x = minBtnX, y = btnY0, w = btnSize, h = btnSize },
    barH = barH,
  }
end

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- Track press origin so we can distinguish a click from a drag on release.
local pressX, pressY = 0, 0
local DRAG_THRESHOLD = 6   -- pixels of movement before a press counts as a drag

function love.mousepressed(x, y, button)
  mouseX, mouseY = x, y
  if button == 1 then
    local btns = titleBarButtons()
    -- Close button (top-right X) — the ONLY way to quit the app.
    if pointInRect(x, y, btns.close) then
      Config.save()
      love.event.quit()
      return
    end
    -- Minimize button (top-right dash)
    if pointInRect(x, y, btns.minimize) then
      Config.save()
      love.window.minimize()
      return
    end

    -- Remember press origin; we decide click-vs-drag on release.
    pressX, pressY = x, y
    isDragging = true
    dragX, dragY = x, y
  end
end

function love.mousereleased(x, y, button)
  if button == 1 and isDragging then
    isDragging = false
    local dx, dy = math.abs(x - pressX), math.abs(y - pressY)
    if dx > DRAG_THRESHOLD or dy > DRAG_THRESHOLD then
      -- It was a drag: persist the new window position.
      local wx, wy = love.window.getPosition()
      Config.set("window.x", math.floor(wx))
      Config.set("window.y", math.floor(wy))
    else
      -- It was a click (barely moved): activate the menu item under the cursor,
      -- if any. This keeps clicks clean and separate from drags.
      local items = activeItems()
      for i = 1, #items do
        local ix, iy, iw, ih = menuItemRect(i)
        if x >= ix and x <= ix + iw and y >= iy and y <= iy + ih then
          activateItem(i)
          break
        end
      end
    end
  end
end

-- Keyboard navigation controls with hierarchical sub-menus and link launching.
-- Uses the same shared helpers as the mouse path so both stay in sync.
function love.keypressed(key)
  local items = activeItems()
  local maxItems = #items
  if maxItems == 0 then return end

  -- Track keyboard selection separately from hover; clear hover when using keys.
  hoverIndex = 0

  if key == "down" then
    if currentMenuLevel == "MAIN" then
      selected = math.min(maxItems, selected + 1)
    else
      subSelected = math.min(maxItems, subSelected + 1)
    end
  end

  if key == "up" then
    if currentMenuLevel == "MAIN" then
      selected = math.max(1, selected - 1)
    else
      subSelected = math.max(1, subSelected - 1)
    end
  end

  -- Left/Right cycles the *currently highlighted* Settings option (theme/res/fs/scale).
  if currentMenuLevel == "SETTINGS" and (key == "left" or key == "right") then
    local delta = (key == "right") and 1 or -1
    local idx = activeIndex()
    local item = items[idx]
    if item then
      if item.action == "CYCLE_THEME" then cycleTheme(delta)
      elseif item.action == "CYCLE_RES" then cycleResolution(delta)
      elseif item.action == "TOGGLE_FS" then toggleFullscreen()
      elseif item.action == "CYCLE_WINMODE" then applyWindowMode(winModeIndex + delta)
      elseif item.action == "CYCLE_SCALE" then cycleScale(delta)
      end
    end
  end

  if key == "a" or key == "return" or key == "kpenter" then
    activateItem(activeIndex())
  end

  -- B / Escape only go BACK one level. At the MAIN menu they do nothing —
  -- the app can ONLY be quit via the title-bar X button (per design).
  if key == "b" or key == "escape" then
    if currentMenuLevel ~= "MAIN" then
      currentMenuLevel = "MAIN"
      hoverIndex = 0
      selectionAnim = selected
    end
  end
end

-- Guarantee settings are written on every exit path (keyboard quit, window X,
-- OS close). Config.save() is a no-op when nothing changed.
function love.quit()
  -- Remember final window position one last time.
  local wx, wy = love.window.getPosition()
  Config.set("window.x", math.floor(wx))
  Config.set("window.y", math.floor(wy))
  Config.save()
end
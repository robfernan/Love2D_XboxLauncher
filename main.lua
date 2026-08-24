-- ============================================================================
-- XBOX CONCEPT DASHBOARD - Love2D Prototype
-- A retro-futuristic Xbox-inspired launcher with dynamic themes, glowing
-- orbital planets, radar grid backgrounds, and a draggable frameless window.
-- ============================================================================

local timeacc = 0
local selected = 1
local activeTheme = 4
local bigFont, smallFont, tinyFont
local bgCanvas, planetCanvas
local selectionAnim = 1.0
local menuPulse = 0
local blurShader, bloomA, bloomB

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
    { name = "Theme Cycle", action = "CYCLE_THEME",                icon = "icons/theme_icon.png" },
  }}
}

-- Window dragging state variables
local isDragging = false
local dragX, dragY = 0, 0

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

-- Cycle through available color themes
local function cycleTheme(delta)
  activeTheme = ((activeTheme - 1 + delta) % themeCount()) + 1
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

function love.load()
  love.window.setTitle("Xbox Concept Dashboard")
  -- Configure window: non-resizable, borderless (frameless), vsync enabled
  love.window.setMode(1152, 648, {resizable=false, borderless=true, vsync=true})

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

  -- Initialize fonts
  bigFont = love.graphics.newFont(20)
  smallFont = love.graphics.newFont(14)
  tinyFont = love.graphics.newFont(10)

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
    love.window.setPosition(wx + (mx - dragX), wy + (my - dragY))
  end
end

-- Renders interactive dashboard menu items with trapezoidal 3D styling and loaded icons
local function drawMenu()
  local w, h = love.graphics.getDimensions()
  local cx, cy = w * 0.44, h * 0.5
  local itemW, itemH = 290, 48
  local spacing = 12
  local theme = currentTheme()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local activeItems = {}
  if currentMenuLevel == "MAIN" then
    for _, cat in ipairs(menuData) do table.insert(activeItems, {name = cat.name}) end
  else
    for _, cat in ipairs(menuData) do
      if cat.id == currentMenuLevel then
        activeItems = cat.items
      end
    end
  end

  local activeIndex = (currentMenuLevel == "MAIN") and selected or subSelected

  -- Connector line linking the central planet/orb to the menu selection
  local selY = cy - (#activeItems * (itemH + spacing)) / 2 + (activeIndex - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setColor(themeR, themeG, themeB, 0.4)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(w * 0.18 + 75, cy, cx, selY)

  love.graphics.setFont(bigFont)
  for i, item in ipairs(activeItems) do
    local y = cy - (#activeItems * (itemH + spacing)) / 2 + (i - 1) * (itemH + spacing)
    local isSelected = (i == activeIndex)
    local selBoost = isSelected and (0.05 * math.sin(menuPulse * 6.0) + 0.05) or 0

    -- Drop shadow / 3D button extrusion effect
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.polygon("fill",
      cx + 12, y + 10,
      cx + itemW - 8, y + 10,
      cx + itemW + 16, y + itemH * 0.5,
      cx + itemW - 8, y + itemH + 10,
      cx + 12, y + itemH + 10,
      cx + 24, y + itemH * 0.5 + 10
    )
    love.graphics.setColor(0.06, 0.01, 0.09, isSelected and 0.6 or 0.35)
    love.graphics.polygon("fill",
      cx + 6, y + 5,
      cx + itemW - 16, y + 5,
      cx + itemW + 4, y + itemH * 0.5,
      cx + itemW - 16, y + itemH + 5,
      cx + 6, y + itemH + 5,
      cx + 18, y + itemH * 0.5 + 5
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
      cx + itemW - 24, y,
      cx + itemW - 4, y + itemH * 0.5,
      cx + itemW - 24, y + itemH,
      cx, y + itemH,
      cx + 14, y + itemH * 0.5
    )

    -- Top surface highlight sheen
    love.graphics.setColor(1, 1, 1, isSelected and 0.15 or 0.05)
    love.graphics.polygon("fill",
      cx + 4, y + 2,
      cx + itemW - 26, y + 2,
      cx + itemW - 10, y + 6,
      cx + 4, y + 6
    )

    -- Draw Icon if available
    local textOffsetX = 45
    if item.icon and iconCache[item.icon] then
      local iconImg = iconCache[item.icon]
      local iw, ih = iconImg:getDimensions()
      local scale = 30 / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
      love.graphics.draw(iconImg, cx + 12, y + (itemH * 0.5) - (ih * scale * 0.5), 0, scale, scale)
      textOffsetX = 52
    end

    -- Label text
    love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.6)
    local displayText = item.name
    if currentMenuLevel == "SETTINGS" and item.action == "CYCLE_THEME" then
      displayText = "Theme: " .. currentTheme().name
    end
    love.graphics.print(displayText, cx + textOffsetX, y + 12)
  end

  -- Animated glowing selection orb indicator next to active menu item
  local selYAnim = cy - (#activeItems * (itemH + spacing)) / 2 + (selectionAnim - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.circle("fill", cx - 36, selYAnim, 26)
  love.graphics.setColor(glowR, glowG, glowB, 1.0)
  love.graphics.circle("fill", cx - 36, selYAnim, 12)
  love.graphics.setBlendMode("alpha")
end

-- Renders the iconic Xbox glowing sphere with intersecting orbital wireframe rings across its body
local function drawPlanetAndRings()
  local w, h = love.graphics.getDimensions()
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

  -- 1. Outer planetary pulsing glow halos
  love.graphics.setBlendMode("add")
  for i = 1, 4 do
    local r = (70 + i * 14) * pulse
    love.graphics.setColor(glowR, glowG, glowB, 0.12 / i)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- 2. Central glowing sphere body with radial gradient layers
  love.graphics.setBlendMode("alpha")
  local sphereRadius = 75 * pulse
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

  -- Core specular highlights on sphere
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.8)
  love.graphics.circle("fill", -12, -12, sphereRadius * 0.3)
  love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
  love.graphics.circle("fill", -18, -18, sphereRadius * 0.12)

  -- 3. Intersecting orbital wireframe loops wrapping across the sphere surface
  local ringCount = 5
  for i = 1, ringCount do
    love.graphics.push()
    local angleRot = spin * (0.4 + i * 0.2) + (i * math.pi / ringCount)
    love.graphics.rotate(angleRot)
    love.graphics.scale(1.0, 0.38)
    love.graphics.setLineWidth(1.2)
    love.graphics.setColor(themeR, themeG, themeB, 0.75)
    love.graphics.circle("line", 0, 0, sphereRadius * (0.95 + i * 0.04))
    love.graphics.pop()
  end

  love.graphics.pop()
  love.graphics.setCanvas()
end

function love.draw()
  local w, h = love.graphics.getDimensions()
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

  -- 6. Render Custom Window Title Bar at the Top
  love.graphics.setColor(0.02, 0.02, 0.03, 0.85)
  love.graphics.rectangle("fill", 0, 0, w, 32)
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.line(0, 32, w, 32)

  love.graphics.setFont(smallFont)
  love.graphics.setColor(glowR, glowG, glowB, 0.9)
  love.graphics.print("Xbox Concept Dashboard", 14, 8)
  love.graphics.setColor(glowR, glowG, glowB, 0.5)
  love.graphics.print("DRAG TO MOVE", w * 0.5 - 45, 8)

  -- Window Control Buttons (Top Right)
  -- Minimize button (-)
  love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
  love.graphics.rectangle("fill", w - 58, 6, 20, 20, 3, 3)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.rectangle("fill", w - 53, 15, 10, 2)

  -- Close button (X)
  love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", w - 32, 6, 20, 20, 3, 3)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.print("x", w - 26, 7)

  -- 7. Render Menu UI Elements
  drawMenu()

  -- 8. Controller / Key Action Hints (Pinned cleanly toward the left side)
  local btnY = h - 28
  local startX = 40
  love.graphics.setFont(smallFont)
  
  -- Back Button (B)
  love.graphics.setColor(1.0, 0.2, 0.2)
  love.graphics.circle("fill", startX + 11, btnY, 11)
  love.graphics.setColor(0, 0, 0)
  love.graphics.print("B", startX + 7, btnY - 7)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("BACK", startX + 28, btnY - 7)

  -- Select Button (A)
  local selectX = startX + 110
  love.graphics.setColor(0.18, 0.85, 0.35)
  love.graphics.circle("fill", selectX + 11, btnY, 11)
  love.graphics.setColor(0, 0, 0)
  love.graphics.print("A", selectX + 7, btnY - 7)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("SELECT", selectX + 28, btnY - 7)
end

-- Mouse press handling for custom title bar buttons and window dragging
function love.mousepressed(x, y, button)
  if button == 1 then
    local w = love.graphics.getWidth()
    if x >= w - 32 and x <= w - 12 and y >= 6 and y <= 26 then
      love.event.quit()
      return
    end
    if x >= w - 58 and x <= w - 38 and y >= 6 and y <= 26 then
      love.window.minimize()
      return
    end

    isDragging = true
    dragX, dragY = x, y
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    isDragging = false
  end
end

-- Keyboard navigation controls with hierarchical sub-menus and link launching
function love.keypressed(key)
  local maxItems = 4
  if currentMenuLevel == "MAIN" then
    maxItems = #menuData
  else
    for _, cat in ipairs(menuData) do
      if cat.id == currentMenuLevel then
        maxItems = #cat.items
      end
    end
  end

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

  if currentMenuLevel == "SETTINGS" and (key == "left" or key == "right") then
    cycleTheme(key == "right" and 1 or -1)
  end

  if key == "a" or key == "return" or key == "kpenter" then
    if currentMenuLevel == "MAIN" then
      local chosenCategory = menuData[selected]
      currentMenuLevel = chosenCategory.id
      subSelected = 1
      selectionAnim = subSelected
    else
      for _, cat in ipairs(menuData) do
        if cat.id == currentMenuLevel then
          local item = cat.items[subSelected]
          if item then
            if item.action == "CYCLE_THEME" then
              cycleTheme(1)
            elseif item.url then
              love.system.openURL(item.url)
            end
          end
        end
      end
    end
  end

  if key == "b" or key == "escape" then
    if currentMenuLevel ~= "MAIN" then
      currentMenuLevel = "MAIN"
      selectionAnim = selected
    else
      love.event.quit()
    end
  end
end
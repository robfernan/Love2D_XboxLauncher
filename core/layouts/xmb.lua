-- ============================================================================
-- PLAYSTATION XMB (CROSS MEDIA BAR) LAYOUT ENGINE
-- Inspired by PS3 / PSP XMB interfaces
--
-- Features:
--   - Animated PS3 sine-wave ribbon background (smooth procedural bezier waves)
--   - Ambient floating sparkle dust particles
--   - Horizontal category axis (left-to-right)
--   - Vertical cascading sub-items (top-to-bottom) with smooth lerping
--   - Glowing translucent glass selection focus frame
--   - Context information & metadata pane
-- ============================================================================

local State     = require("core.state")
local Themes    = require("core.themes")
local Layout    = require("core.layout")
local MenuData  = require("core.menu_data")
local Shortcuts = require("core.shortcuts")
local MenuLogic = require("core.menu")

local M = {}

M.id = "XMB"
M.name = "PlayStation XMB"

-- Smooth camera/motion state
local camCategoryAnim = 1.0
local camItemAnim     = 1.0

-- Floating sparkle particles
local sparkles = {}
local SPARKLE_COUNT = 30

local function initSparkles()
  if #sparkles > 0 then return end
  for i = 1, SPARKLE_COUNT do
    table.insert(sparkles, {
      x = math.random(),
      y = math.random(),
      speedX = (math.random() - 0.5) * 0.04,
      speedY = -0.02 - math.random() * 0.05,
      size = math.random(1, 3),
      alpha = math.random() * 0.7 + 0.3,
    })
  end
end

-------------------------------------------------------------------------------
-- Animated PS3 Sine Wave Background + Floating Sparkles
-------------------------------------------------------------------------------
function M.drawBackground(w, h)
  initSparkles()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]
  local colorR, colorG, colorB = theme.color[1], theme.color[2], theme.color[3]
  local S = Layout.scale()

  -- 1) Rich Radial/Vertical Atmosphere Gradient
  love.graphics.setBlendMode("alpha")
  for row = 0, h, 8 do
    local grad = (row / h)
    love.graphics.setColor(
      colorR * 0.12 * (1 - grad * 0.6),
      colorG * 0.12 * (1 - grad * 0.6),
      colorB * 0.12 * (1 - grad * 0.6), 1.0)
    love.graphics.rectangle("fill", 0, row, w, 8)
  end

  -- Subtle horizontal glow horizon
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.08)
  love.graphics.rectangle("fill", 0, h * 0.44 - 60*S, w, 120*S)

  -- 2) Authentic PlayStation Silk Wave Ribbons (Filled translucent ribbons)
  local t = State.timeacc * 0.5
  local waveLayers = 6

  for layer = 1, waveLayers do
    local step = 24
    local layerOffset = layer * 0.95
    local alpha = 0.18 - (layer * 0.022)
    love.graphics.setColor(glowR, glowG, glowB, alpha)

    local baseY = h * 0.52 + math.sin(t * 0.4 + layerOffset) * 45 * S
    local topPoints = {}
    for x = 0, w + step, step do
      local waveY = baseY 
        + math.sin(x * 0.0025 + t * 0.8 + layerOffset) * 60 * S
        + math.cos(x * 0.0042 - t * 0.5 + layerOffset * 1.5) * 40 * S
      table.insert(topPoints, {x = x, y = waveY})
    end

    -- Draw ribbon lines with dynamic thickness
    love.graphics.setLineWidth((2.0 + layer * 0.6) * S)
    local linePoints = {}
    for _, pt in ipairs(topPoints) do
      table.insert(linePoints, pt.x)
      table.insert(linePoints, pt.y)
    end
    if #linePoints >= 4 then
      love.graphics.line(linePoints)
    end

    -- Secondary echo wave
    love.graphics.setColor(colorR, colorG, colorB, alpha * 0.5)
    local echoPoints = {}
    for _, pt in ipairs(topPoints) do
      table.insert(echoPoints, pt.x)
      table.insert(echoPoints, pt.y + 18 * S)
    end
    if #echoPoints >= 4 then
      love.graphics.setLineWidth(1.2 * S)
      love.graphics.line(echoPoints)
    end
  end

  -- 3) Floating Ambient Sparkle Dust
  for _, sp in ipairs(sparkles) do
    sp.x = (sp.x + sp.speedX * 0.016) % 1.0
    sp.y = (sp.y + sp.speedY * 0.016) % 1.0
    local sx = sp.x * w
    local sy = sp.y * h
    local blink = 0.5 + 0.5 * math.sin(State.timeacc * 3.5 + sp.x * 12)
    love.graphics.setColor(1, 1, 1, sp.alpha * blink * 0.55)
    love.graphics.circle("fill", sx, sy, sp.size * S)
  end

  love.graphics.setBlendMode("alpha")
end

-------------------------------------------------------------------------------
-- XMB does not draw the planet; it focuses on clean console cross-media elegance
-------------------------------------------------------------------------------
function M.drawPlanetAndRings()
  -- Intentionally clean wave space for XMB
end

-------------------------------------------------------------------------------
-- Draw the XMB Cross Media Bar (Horizontal Categories + Vertical Items)
-------------------------------------------------------------------------------
function M.drawMenu()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local categories = MenuData.categories
  local activeCatIdx = 1

  if State.currentMenuLevel == "MAIN" then
    activeCatIdx = State.selected
  else
    for i, c in ipairs(categories) do
      if c.id == State.currentMenuLevel then
        activeCatIdx = i
        break
      end
    end
  end

  -- Smooth camera interpolation
  camCategoryAnim = camCategoryAnim + (activeCatIdx - camCategoryAnim) * 0.16
  local targetItem = (State.currentMenuLevel == "MAIN") and 1 or MenuLogic.activeIndex()
  camItemAnim     = camItemAnim + (targetItem - camItemAnim) * 0.18

  -- Layout anchor coordinates (The Intersection Point of the Cross)
  local focusX = w * 0.28
  local focusY = h * 0.44

  local catSpacing = 130 * S
  local itemSpacing = 68 * S

  ---------------------------------------------------------------------------
  -- 1) HORIZONTAL CATEGORY ROW
  ---------------------------------------------------------------------------
  for i, cat in ipairs(categories) do
    local offset = i - camCategoryAnim
    local cx = focusX + offset * catSpacing
    local cy = focusY

    local isFocused = (i == activeCatIdx)
    local dist = math.abs(offset)
    local alpha = math.max(0.2, 1.0 - (dist * 0.35))
    local scale = isFocused and (1.2 + 0.05 * math.sin(State.menuPulse * 4)) or 0.85

    -- Category Icon
    local catIconPath = "icons/theme_icon.png"
    if cat.id == "GAMES" then catIconPath = "icons/steam_icon.png"
    elseif cat.id == "BROWSE" then catIconPath = "icons/internet_icon.png"
    elseif cat.id == "MEDIA" then catIconPath = "icons/video_icon.png"
    elseif cat.id == "SETTINGS" then catIconPath = "icons/settings_icon.png" end

    local iconImg = State.iconCache[catIconPath]
    if iconImg then
      local iw, ih = iconImg:getDimensions()
      local s = ((36 * S) / math.max(iw, ih)) * scale
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(iconImg, cx, cy - 24 * S, 0, s, s, iw / 2, ih / 2)
    end

    -- Category Title label below icon
    love.graphics.setFont(State.smallFont)
    love.graphics.setColor(isFocused and glowR or 1, isFocused and glowG or 1, isFocused and glowB or 1, alpha)
    local nameStr = cat.name
    love.graphics.print(nameStr, cx - State.smallFont:getWidth(nameStr) / 2, cy + 6 * S)
  end

  ---------------------------------------------------------------------------
  -- 2) VERTICAL CASCADING SUB-ITEMS (Active Category)
  ---------------------------------------------------------------------------
  local items = {}
  local catObj = categories[activeCatIdx]
  if catObj then
    items = Shortcuts.mergedItems(catObj.id)
  end

  if #items > 0 then
    local curItemIdx = State.subSelected or 1
    if curItemIdx > #items then curItemIdx = #items end

    for j, item in ipairs(items) do
      local itemOffset = j - camItemAnim
      local ix = focusX
      local iy = focusY + 70 * S + itemOffset * itemSpacing

      local isSelected = (j == curItemIdx)
      local vDist = math.abs(itemOffset)
      local alpha = math.max(0.2, 1.0 - (vDist * 0.32))

      -- Glowing selection frame
      if isSelected then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(glowR, glowG, glowB, 0.25)
        love.graphics.rectangle("fill", ix - 30 * S, iy - 16 * S, 380 * S, 48 * S, 8 * S, 8 * S)
        love.graphics.setColor(glowR, glowG, glowB, 0.8)
        love.graphics.setLineWidth(1.5 * S)
        love.graphics.rectangle("line", ix - 30 * S, iy - 16 * S, 380 * S, 48 * S, 8 * S, 8 * S)
        love.graphics.setBlendMode("alpha")
      end

      -- Item Icon
      local itemIcon = item.icon
      if itemIcon and State.iconCache[itemIcon] then
        local img = State.iconCache[itemIcon]
        local iw, ih = img:getDimensions()
        local s = (32 * S) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, ix - 16 * S, iy - 8 * S, 0, s, s)
      end

      -- Item Name
      love.graphics.setFont(State.bigFont)
      love.graphics.setColor(1, 1, 1, isSelected and 1.0 or alpha)
      love.graphics.print(item.name, ix + 32 * S, iy - 6 * S)
    end
  end

  ---------------------------------------------------------------------------
  -- 3) PREVIEW / METADATA CARD (Right Side)
  ---------------------------------------------------------------------------
  local cardX = w * 0.64
  local cardY = h * 0.32
  local cardW = w * 0.30
  local cardH = h * 0.42

  love.graphics.setColor(0.04, 0.03, 0.07, 0.82)
  love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8 * S, 8 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.4)
  love.graphics.setLineWidth(1.2 * S)
  love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8 * S, 8 * S)

  local curItem = items[math.floor(camItemAnim + 0.5)] or items[1]
  if curItem then
    love.graphics.setFont(State.bigFont)
    love.graphics.setColor(glowR, glowG, glowB, 1.0)
    love.graphics.print(curItem.name:upper(), cardX + 18 * S, cardY + 20 * S)

    love.graphics.setFont(State.smallFont)
    love.graphics.setColor(1, 1, 1, 0.7)
    local target = curItem.url or curItem.cmd or "Console Setting"
    love.graphics.printf(target, cardX + 18 * S, cardY + 60 * S, cardW - 36 * S, "left")

    love.graphics.setColor(glowR, glowG, glowB, 0.5)
    love.graphics.print("SYSTEM: PLAYSTATION XMB READY", cardX + 18 * S, cardY + cardH - 32 * S)
  end
end

return M

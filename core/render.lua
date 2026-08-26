-- ============================================================================
-- RENDER
-- All drawing code: radar background, planet + orbital rings, bloom pipeline,
-- title bar, menu buttons, and bottom hints. Pure presentation — reads shared
-- state, writes pixels. No input handling here.
-- ============================================================================

local State    = require("core.state")
local Themes   = require("core.themes")
local Menu     = require("core.menu_data")
local Layout   = require("core.layout")
local MenuLogic = require("core.menu")

local M = {}

-------------------------------------------------------------------------------
-- Radar grid background (concentric rings + crosshair spokes).
-------------------------------------------------------------------------------
function M.drawRadarBackground(w, h)
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  love.graphics.setBlendMode("alpha")
  love.graphics.push()
  love.graphics.translate(w * 0.5, h * 0.5)
  local maxr = math.max(w, h) * 0.75
  for i = 1, 10 do
    love.graphics.setLineWidth(i == 1 and 1.5 or 1.0)
    love.graphics.setColor(glowR, glowG, glowB, 0.04 + (i * 0.005))
    love.graphics.circle("line", 0, 0, maxr * (i / 10))
  end
  for angle = 0, math.pi * 2, math.pi * 0.25 do
    love.graphics.setColor(glowR, glowG, glowB, 0.03)
    love.graphics.line(0, 0, math.cos(angle) * maxr, math.sin(angle) * maxr)
  end
  love.graphics.pop()
end

-------------------------------------------------------------------------------
-- Glowing sphere + intersecting orbital wireframe rings (rendered to canvas).
-------------------------------------------------------------------------------
function M.drawPlanetAndRings()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local cx, cy = w * 0.18, h * 0.5
  local spin = State.timeacc * 0.5
  local pulse = 1.0 + 0.03 * math.sin(State.timeacc * 2.5)
  local theme = Themes.current()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  love.graphics.setCanvas(State.planetCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.push()
  love.graphics.translate(cx, cy)

  -- Outer pulsing glow halos
  love.graphics.setBlendMode("add")
  for i = 1, 4 do
    local r = (70 + i * 14) * S * pulse
    love.graphics.setColor(glowR, glowG, glowB, 0.12 / i)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- Sphere body with radial gradient layers
  love.graphics.setBlendMode("alpha")
  local sphereRadius = 75 * S * pulse
  for i = 30, 1, -1 do
    local t = i / 30
    local r = sphereRadius * t
    local mixVal = 1.0 - t
    love.graphics.setColor(
      themeR * (0.15 + 0.85 * mixVal),
      themeG * (0.15 + 0.85 * mixVal),
      themeB * (0.15 + 0.85 * mixVal), 0.9)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- Core specular highlights
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.8)
  love.graphics.circle("fill", -12*S, -12*S, sphereRadius * 0.3)
  love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
  love.graphics.circle("fill", -18*S, -18*S, sphereRadius * 0.12)

  -- Intersecting orbital wireframe loops
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

-------------------------------------------------------------------------------
-- Menu buttons with trapezoidal 3D styling + icons.
-------------------------------------------------------------------------------
function M.drawMenu()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local cx, cy = w * 0.44, h * 0.5
  local itemW, itemH = 290 * S, 48 * S
  local spacing = 12 * S
  local theme = Themes.current()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local items = MenuLogic.activeItems()
  local count = #items
  local curIdx = MenuLogic.activeIndex()

  -- Connector line from planet to selection
  local selY = cy - (count * (itemH + spacing)) / 2 + (curIdx - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setColor(themeR, themeG, themeB, 0.4)
  love.graphics.setLineWidth(1.5 * S)
  love.graphics.line(w * 0.18 + 75 * S, cy, cx, selY)

  love.graphics.setFont(State.bigFont)
  for i, item in ipairs(items) do
    local y = cy - (count * (itemH + spacing)) / 2 + (i - 1) * (itemH + spacing)
    local isSelected = (i == curIdx)
    local selBoost = isSelected and (0.05 * math.sin(State.menuPulse * 6.0) + 0.05) or 0

    -- Drop shadow / extrusion
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.polygon("fill",
      cx + 12*S, y + 10*S, cx + itemW - 8*S, y + 10*S,
      cx + itemW + 16*S, y + itemH * 0.5, cx + itemW - 8*S, y + itemH + 10*S,
      cx + 12*S, y + itemH + 10*S, cx + 24*S, y + itemH * 0.5 + 10*S)
    love.graphics.setColor(0.06, 0.01, 0.09, isSelected and 0.6 or 0.35)
    love.graphics.polygon("fill",
      cx + 6*S, y + 5*S, cx + itemW - 16*S, y + 5*S,
      cx + itemW + 4*S, y + itemH * 0.5, cx + itemW - 16*S, y + itemH + 5*S,
      cx + 6*S, y + itemH + 5*S, cx + 18*S, y + itemH * 0.5 + 5*S)

    -- Main trapezoidal body
    local baseColor = isSelected and {
      themeR * (0.8 + selBoost), themeG * (0.8 + selBoost), themeB * (0.8 + selBoost)
    } or {themeR * 0.18, themeG * 0.18, themeB * 0.18}
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], isSelected and 0.98 or 0.45)
    love.graphics.polygon("fill",
      cx, y, cx + itemW - 24*S, y, cx + itemW - 4*S, y + itemH * 0.5,
      cx + itemW - 24*S, y + itemH, cx, y + itemH, cx + 14*S, y + itemH * 0.5)

    -- Top sheen
    love.graphics.setColor(1, 1, 1, isSelected and 0.15 or 0.05)
    love.graphics.polygon("fill",
      cx + 4*S, y + 2*S, cx + itemW - 26*S, y + 2*S,
      cx + itemW - 10*S, y + 6*S, cx + 4*S, y + 6*S)

    -- Icon (if available in cache)
    local textOffsetX = 45 * S
    if item.icon and State.iconCache[item.icon] then
      local iconImg = State.iconCache[item.icon]
      local iw, ih = iconImg:getDimensions()
      local scale = (30 * S) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
      love.graphics.draw(iconImg, cx + 12*S, y + (itemH * 0.5) - (ih * scale * 0.5), 0, scale, scale)
      textOffsetX = 52 * S
    end

    -- Label
    love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.6)
    love.graphics.print(item.name, cx + textOffsetX, y + 12 * S)
  end

  -- Animated selection orb
  local selYAnim = cy - (count * (itemH + spacing)) / 2 + (State.selectionAnim - 1) * (itemH + spacing) + itemH / 2
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.circle("fill", cx - 36*S, selYAnim, 26*S)
  love.graphics.setColor(glowR, glowG, glowB, 1.0)
  love.graphics.circle("fill", cx - 36*S, selYAnim, 12*S)
  love.graphics.setBlendMode("alpha")
end

-------------------------------------------------------------------------------
-- Custom title bar with minimize/close buttons (responsive).
-------------------------------------------------------------------------------
function M.drawTitleBar(w, h)
  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local barH = 32 * S
  love.graphics.setColor(0.02, 0.02, 0.03, 0.85)
  love.graphics.rectangle("fill", 0, 0, w, barH)
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.line(0, barH, w, barH)

  local btnSize = 20 * S
  local btnPad = 6 * S
  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(glowR, glowG, glowB, 0.9)
  love.graphics.print("Xbox Concept Dashboard", 14 * S, (barH - State.smallFont:getHeight()) / 2)
  love.graphics.setColor(glowR, glowG, glowB, 0.5)
  local dragLabel = "DRAG TO MOVE"
  love.graphics.print(dragLabel, w * 0.5 - State.smallFont:getWidth(dragLabel) / 2, (barH - State.smallFont:getHeight()) / 2)

  -- Buttons (top-right)
  local closeX = w - btnPad - btnSize
  local minBtnX = closeX - btnSize - 8 * S
  local btnY0 = (barH - btnSize) / 2
  love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
  love.graphics.rectangle("fill", minBtnX, btnY0, btnSize, btnSize, 3 * S, 3 * S)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.rectangle("fill", minBtnX + (btnSize - 10*S)/2, barH/2 - 1*S, 10*S, 2*S)

  love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", closeX, btnY0, btnSize, btnSize, 3 * S, 3 * S)
  love.graphics.setColor(1, 1, 1, 0.9)
  local xLabel = "x"
  love.graphics.print(xLabel, closeX + (btnSize - State.smallFont:getWidth(xLabel))/2, btnY0 + (btnSize - State.smallFont:getHeight())/2)
end

-------------------------------------------------------------------------------
-- Bottom-left B/A hint badges (responsive).
-------------------------------------------------------------------------------
function M.drawHints(w, h)
  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local hintR = 11 * S
  local btnY = h - 28 * S
  local startX = 40 * S
  love.graphics.setFont(State.smallFont)

  -- B (back)
  love.graphics.setColor(1.0, 0.2, 0.2)
  love.graphics.circle("fill", startX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local bLabel = "B"
  love.graphics.print(bLabel, startX + hintR - State.smallFont:getWidth(bLabel)/2, btnY - State.smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("BACK", startX + hintR*2 + 8*S, btnY - State.smallFont:getHeight()/2)

  -- A (select)
  local selectX = startX + 110 * S
  love.graphics.setColor(0.18, 0.85, 0.35)
  love.graphics.circle("fill", selectX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local aLabel = "A"
  love.graphics.print(aLabel, selectX + hintR - State.smallFont:getWidth(aLabel)/2, btnY - State.smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("SELECT", selectX + hintR*2 + 8*S, btnY - State.smallFont:getHeight()/2)
end

-------------------------------------------------------------------------------
-- Full frame render (called from love.draw). Orchestrates the bloom pipeline.
-------------------------------------------------------------------------------
function M.frame()
  local w, h = love.graphics.getDimensions()
  local theme = Themes.current()

  -- 1. Radar background canvas
  love.graphics.setCanvas(State.bgCanvas)
  love.graphics.clear(theme.bg[1], theme.bg[2], theme.bg[3], 1)
  M.drawRadarBackground(w, h)
  love.graphics.setCanvas()

  -- 2. Planet + rings canvas
  M.drawPlanetAndRings()

  -- 3. Draw background to screen
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(State.bgCanvas, 0, 0)

  -- 4. Multi-pass bloom on planet layer
  if State.blurShader then
    love.graphics.setCanvas(State.bloomA)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("add")
    love.graphics.draw(State.planetCanvas, 0, 0)
    love.graphics.setCanvas()

    State.blurShader:send("resolution", {w, h})
    State.blurShader:send("direction", {1, 0})
    love.graphics.setShader(State.blurShader)
    love.graphics.setCanvas(State.bloomB)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(State.bloomA, 0, 0)
    love.graphics.setCanvas()

    State.blurShader:send("direction", {0, 1})
    love.graphics.setCanvas(State.bloomA)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(State.bloomB, 0, 0)
    love.graphics.setCanvas()
    love.graphics.setShader()

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.draw(State.bloomA, 0, 0)
  end

  -- 5. Crisp planet layer over bloom
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(State.planetCanvas, 0, 0)

  -- 6. Title bar
  M.drawTitleBar(w, h)

  -- 7. Menu
  M.drawMenu()

  -- 8. Bottom hints
  M.drawHints(w, h)
end

return M

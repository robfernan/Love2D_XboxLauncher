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
  local S = Layout.scale()

  love.graphics.setBlendMode("alpha")
  love.graphics.push()
  love.graphics.translate(w * 0.5, h * 0.5)
  local maxr = math.max(w, h) * 0.75

  -- Concentric radar rings
  for i = 1, 10 do
    love.graphics.setLineWidth(i == 1 and 1.5 or 1.0)
    love.graphics.setColor(glowR, glowG, glowB, 0.04 + (i * 0.005))
    love.graphics.circle("line", 0, 0, maxr * (i / 10))
  end

  -- Spoke axes
  for angle = 0, math.pi * 2, math.pi * 0.25 do
    love.graphics.setColor(glowR, glowG, glowB, 0.035)
    love.graphics.line(0, 0, math.cos(angle) * maxr, math.sin(angle) * maxr)
  end

  -- Dynamic rotating radar sweep beam
  local sweepAngle = State.timeacc * 0.7
  love.graphics.setLineWidth(2.0 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.25)
  love.graphics.line(0, 0, math.cos(sweepAngle) * maxr, math.sin(sweepAngle) * maxr)
  love.graphics.setColor(glowR, glowG, glowB, 0.08)
  for trail = 1, 6 do
    local a = sweepAngle - trail * 0.035
    love.graphics.line(0, 0, math.cos(a) * maxr, math.sin(a) * maxr)
  end
  love.graphics.pop()

  -- Sci-Fi Telemetry Data in Corners
  love.graphics.setFont(State.tinyFont or love.graphics.newFont(10))
  love.graphics.setColor(glowR, glowG, glowB, 0.45)
  love.graphics.print("SYSTEM: ONLINE // LATENCY: 0.12ms", 24 * S, 48 * S)
  love.graphics.print("SECTOR 07 // NODE-A3", 24 * S, 62 * S)
  local rightInfo = "RESONANCE: STABLE"
  if State.tinyFont then
    love.graphics.print(rightInfo, w - State.tinyFont:getWidth(rightInfo) - 24 * S, 48 * S)
  end
end

-------------------------------------------------------------------------------
-- Glowing sphere + intersecting orbital wireframe rings (rendered to canvas).
-------------------------------------------------------------------------------
function M.drawPlanetAndRings()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local cx, cy = w * 0.22, h * 0.5
  local spin = State.timeacc * 0.5
  local pulse = 1.0 + 0.03 * math.sin(State.timeacc * 2.5)
  local theme = Themes.current()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  love.graphics.setCanvas(State.planetCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.push()
  love.graphics.translate(cx, cy)

  -- 1) Orbiting energy particles in background
  love.graphics.setBlendMode("add")
  for p = 1, 16 do
    local pAngle = State.timeacc * (0.8 + (p % 3) * 0.4) + (p * 0.39)
    local pDist  = (85 + (p * 7) % 35) * S
    local px = math.cos(pAngle) * pDist
    local py = math.sin(pAngle) * pDist * 0.55
    local pAlpha = 0.3 + 0.5 * math.sin(State.timeacc * 3 + p)
    love.graphics.setColor(glowR, glowG, glowB, pAlpha)
    love.graphics.circle("fill", px, py, (2 + (p % 2)) * S)
  end

  -- 2) Outer pulsing glow halos
  for i = 1, 4 do
    local r = (72 + i * 16) * S * pulse
    love.graphics.setColor(glowR, glowG, glowB, 0.14 / i)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- 3) Sphere body with multi-layered plasma gradient
  love.graphics.setBlendMode("alpha")
  local sphereRadius = 78 * S * pulse
  for i = 32, 1, -1 do
    local t = i / 32
    local r = sphereRadius * t
    local mixVal = 1.0 - t
    -- Volumetric depth shading
    love.graphics.setColor(
      themeR * (0.12 + 0.88 * (mixVal ^ 1.4)),
      themeG * (0.12 + 0.88 * (mixVal ^ 1.4)),
      themeB * (0.12 + 0.88 * (mixVal ^ 1.4)), 0.94)
    love.graphics.circle("fill", 0, 0, r)
  end

  -- 4) Core specular highlights (multi-stage)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.85)
  love.graphics.circle("fill", -14*S, -14*S, sphereRadius * 0.32)
  love.graphics.setColor(1.0, 1.0, 1.0, 0.6)
  love.graphics.circle("fill", -18*S, -18*S, sphereRadius * 0.14)
  love.graphics.setColor(1.0, 1.0, 1.0, 0.85)
  love.graphics.circle("fill", -20*S, -20*S, sphereRadius * 0.05)

  -- 5) Intersecting orbital wireframe loops with perspective line width
  local ringCount = 6
  for i = 1, ringCount do
    love.graphics.push()
    local angleRot = spin * (0.35 + i * 0.18) + (i * math.pi / ringCount)
    love.graphics.rotate(angleRot)
    love.graphics.scale(1.0, 0.36)
    love.graphics.setLineWidth((1.2 + (i % 2) * 0.6) * S)
    love.graphics.setColor(themeR, themeG, themeB, 0.8)
    love.graphics.circle("line", 0, 0, sphereRadius * (0.94 + i * 0.05))
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
  local cx, cy = w * 0.43, h * 0.5
  -- Uniform sizing (must match Layout.menuItemRect exactly).
  local itemW, itemH, spacing = 320 * S, 48 * S, 12 * S
  local theme = Themes.current()
  local themeR, themeG, themeB = theme.color[1], theme.color[2], theme.color[3]
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local items = MenuLogic.activeItems()
  local count = #items
  local curIdx = MenuLogic.activeIndex()

  -- Animated selection orb position
  local orbX = cx - 36 * S
  local selYAnim = cy - (count * (itemH + spacing)) / 2 + (State.selectionAnim - 1) * (itemH + spacing) + itemH / 2

  -- Connector line from planet right edge directly to the animated selection orb
  love.graphics.setColor(themeR, themeG, themeB, 0.45)
  love.graphics.setLineWidth(1.8 * S)
  love.graphics.line(w * 0.22 + 78 * S, cy, orbX, selYAnim)

  love.graphics.setFont(State.bigFont)
  for i, item in ipairs(items) do
    local y = cy - (count * (itemH + spacing)) / 2 + (i - 1) * (itemH + spacing)
    local isSelected = (i == curIdx)
    local selBoost = isSelected and (0.08 * math.sin(State.menuPulse * 6.0) + 0.06) or 0

    -- Outer glow on selected item
    if isSelected then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(glowR, glowG, glowB, 0.2)
      love.graphics.polygon("fill",
        cx - 6*S, y - 4*S, cx + itemW - 20*S, y - 4*S,
        cx + itemW + 12*S, y + itemH * 0.5, cx + itemW - 20*S, y + itemH + 4*S,
        cx - 6*S, y + itemH + 4*S, cx + 8*S, y + itemH * 0.5)
      love.graphics.setBlendMode("alpha")
    end

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.polygon("fill",
      cx + 10*S, y + 8*S, cx + itemW - 12*S, y + 8*S,
      cx + itemW + 12*S, y + itemH * 0.5 + 4*S, cx + itemW - 12*S, y + itemH + 8*S,
      cx + 10*S, y + itemH + 8*S, cx + 20*S, y + itemH * 0.5 + 8*S)

    -- Main chevron body
    local baseColor = isSelected and {
      themeR * (0.85 + selBoost), themeG * (0.85 + selBoost), themeB * (0.85 + selBoost)
    } or {themeR * 0.22, themeG * 0.22, themeB * 0.22}
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], isSelected and 0.98 or 0.55)
    love.graphics.polygon("fill",
      cx, y, cx + itemW - 24*S, y, cx + itemW - 4*S, y + itemH * 0.5,
      cx + itemW - 24*S, y + itemH, cx, y + itemH, cx + 14*S, y + itemH * 0.5)

    -- Top bevel sheen
    love.graphics.setColor(1, 1, 1, isSelected and 0.25 or 0.08)
    love.graphics.polygon("fill",
      cx + 4*S, y + 2*S, cx + itemW - 26*S, y + 2*S,
      cx + itemW - 10*S, y + 6*S, cx + 4*S, y + 6*S)

    -- Border outline
    love.graphics.setLineWidth(1.2 * S)
    love.graphics.setColor(glowR, glowG, glowB, isSelected and 0.9 or 0.3)
    love.graphics.polygon("line",
      cx, y, cx + itemW - 24*S, y, cx + itemW - 4*S, y + itemH * 0.5,
      cx + itemW - 24*S, y + itemH, cx, y + itemH, cx + 14*S, y + itemH * 0.5)

    -- Icon (only rendered if item actually defines one)
    local textOffsetX = 32 * S
    local iconPath = item.icon
    if iconPath and State.iconCache[iconPath] then
      local iconImg = State.iconCache[iconPath]
      local iw, ih = iconImg:getDimensions()
      local scale = (30 * S) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
      love.graphics.draw(iconImg, cx + 14*S, y + (itemH * 0.5) - (ih * scale * 0.5), 0, scale, scale)
      textOffsetX = 54 * S
    elseif iconPath then
      -- Lazy load
      local ok, img = pcall(love.graphics.newImage, iconPath)
      if ok and img then
        State.iconCache[iconPath] = img
        local iw, ih = img:getDimensions()
        local scale = (30 * S) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
        love.graphics.draw(img, cx + 14*S, y + (itemH * 0.5) - (ih * scale * 0.5), 0, scale, scale)
        textOffsetX = 54 * S
      end
    end

    -- Label
    love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.65)
    love.graphics.print(item.name, cx + textOffsetX, y + 10 * S)
  end

  -- Animated selection orb
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.3)
  love.graphics.circle("fill", orbX, selYAnim, 26*S)
  love.graphics.setColor(glowR, glowG, glowB, 1.0)
  love.graphics.circle("fill", orbX, selYAnim, 12*S)
  love.graphics.setBlendMode("alpha")

  -- RIGHT-HAND CONTEXT & PREVIEW PANEL (Balances negative space)
  local panelX = cx + itemW + 40 * S
  local panelW = w - panelX - 45 * S
  local panelH = (count * (itemH + spacing))
  local panelY = cy - panelH / 2

  if panelW > 160 * S then
    -- Panel container (translucent glassmorphism)
    love.graphics.setColor(0.03, 0.02, 0.05, 0.7)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6 * S, 6 * S)
    love.graphics.setColor(glowR, glowG, glowB, 0.35)
    love.graphics.setLineWidth(1.2 * S)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 6 * S, 6 * S)

    -- Header inside panel
    local activeItem = items[curIdx]
    if activeItem then
      love.graphics.setFont(State.bigFont)
      love.graphics.setColor(glowR, glowG, glowB, 1.0)
      love.graphics.print(activeItem.name:upper(), panelX + 16 * S, panelY + 16 * S)

      love.graphics.setFont(State.smallFont)
      love.graphics.setColor(1, 1, 1, 0.7)
      if State.currentMenuLevel == "MAIN" then
        local desc = "Explore " .. activeItem.name:lower() .. " shortcuts & apps."
        love.graphics.printf(desc, panelX + 16 * S, panelY + 54 * S, panelW - 32 * S, "left")
        love.graphics.setColor(glowR, glowG, glowB, 0.5)
        love.graphics.print("STATUS: READY", panelX + 16 * S, panelY + panelH - 30 * S)
      else
        local target = activeItem.url or activeItem.cmd or "System Option"
        love.graphics.setColor(glowR, glowG, glowB, 0.6)
        love.graphics.print("TARGET / INFO:", panelX + 16 * S, panelY + 52 * S)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.printf(target, panelX + 16 * S, panelY + 74 * S, panelW - 32 * S, "left")
        love.graphics.setColor(glowR, glowG, glowB, 0.5)
        love.graphics.print("PRESS A TO LAUNCH", panelX + 16 * S, panelY + panelH - 30 * S)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Custom title bar with minimize/close buttons (responsive).
-------------------------------------------------------------------------------
function M.drawTitleBar(w, h)
  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local barH = 34 * S
  love.graphics.setColor(0.015, 0.01, 0.03, 0.92)
  love.graphics.rectangle("fill", 0, 0, w, barH)
  love.graphics.setColor(glowR, glowG, glowB, 0.35)
  love.graphics.setLineWidth(1 * S)
  love.graphics.line(0, barH, w, barH)

  -- Left: System Logo & Title
  local logoSize = 10 * S
  local logoX = 18 * S
  local logoY = barH / 2
  love.graphics.setColor(glowR, glowG, glowB, 0.95)
  love.graphics.polygon("fill",
    logoX, logoY - logoSize * 0.6,
    logoX + logoSize * 0.6, logoY,
    logoX, logoY + logoSize * 0.6,
    logoX - logoSize * 0.6, logoY
  )

  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(glowR, glowG, glowB, 0.95)
  love.graphics.print("XBOX CONCEPT DASHBOARD", logoX + logoSize + 8 * S, (barH - State.smallFont:getHeight()) / 2)

  -- Center: Sleek Live Digital Clock
  local timeStr = os.date("%I:%M %p")
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.print(timeStr, (w - State.smallFont:getWidth(timeStr)) / 2, (barH - State.smallFont:getHeight()) / 2)

  -- Buttons (top-right)
  local btns = Layout.titleBarButtons()
  local closeX = btns.close.x
  local minBtnX = btns.minimize.x
  local btnSize = btns.close.w
  local btnY0 = btns.close.y

  -- Interactive Layout Switcher Badge
  local Settings = require("core.settings")
  local curLayName = Settings.layoutNames[State.activeLayout] or State.activeLayout
  local layBtn = btns.layout
  love.graphics.setColor(0.12, 0.16, 0.22, 0.85)
  love.graphics.rectangle("fill", layBtn.x, layBtn.y, layBtn.w, layBtn.h, 4 * S, 4 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.45)
  love.graphics.setLineWidth(1 * S)
  love.graphics.rectangle("line", layBtn.x, layBtn.y, layBtn.w, layBtn.h, 4 * S, 4 * S)
  local fontToUse = State.tinyFont or State.smallFont
  love.graphics.setFont(fontToUse)
  love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
  local badgeTxt = "Layout: " .. curLayName
  if fontToUse:getWidth(badgeTxt) > layBtn.w - 8 * S then
    badgeTxt = curLayName
  end
  local btw = fontToUse:getWidth(badgeTxt)
  love.graphics.print(badgeTxt, layBtn.x + (layBtn.w - btw) / 2, layBtn.y + (layBtn.h - fontToUse:getHeight()) / 2)

  -- Minimize button
  love.graphics.setColor(0.12, 0.12, 0.18, 0.8)
  love.graphics.rectangle("fill", minBtnX, btnY0, btnSize, btnSize, 4 * S, 4 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.4)
  love.graphics.rectangle("line", minBtnX, btnY0, btnSize, btnSize, 4 * S, 4 * S)
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.rectangle("fill", minBtnX + (btnSize - 10*S)/2, barH/2 - 1*S, 10*S, 2*S)

  -- Close button (drawn with crisp vector diagonal lines for real 'X')
  love.graphics.setColor(0.75, 0.15, 0.22, 0.85)
  love.graphics.rectangle("fill", closeX, btnY0, btnSize, btnSize, 4 * S, 4 * S)
  love.graphics.setColor(1, 0.35, 0.35, 0.6)
  love.graphics.rectangle("line", closeX, btnY0, btnSize, btnSize, 4 * S, 4 * S)
  
  local cx0 = closeX + btnSize / 2
  local cy0 = btnY0 + btnSize / 2
  local arm = 4.2 * S
  love.graphics.setLineWidth(1.8 * S)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.line(cx0 - arm, cy0 - arm, cx0 + arm, cy0 + arm)
  love.graphics.line(cx0 - arm, cy0 + arm, cx0 + arm, cy0 - arm)
end

-------------------------------------------------------------------------------
-- Bottom-left B/A hint badges (responsive).
-------------------------------------------------------------------------------
function M.drawHints(w, h)
  local S = Layout.scale()

  -- Authentic Xbox 360 NXE style hints when in NXE layout
  if State.activeLayout == "BLADES" then
    local startX = 72 * S
    local btnY = h - 30 * S
    local hintR = 10 * S
    love.graphics.setFont(State.smallFont)

    -- (A) Select
    love.graphics.setColor(0.35, 0.75, 0.15, 1.0)
    love.graphics.circle("fill", startX + hintR, btnY, hintR)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("A", startX + hintR - State.smallFont:getWidth("A")/2, btnY - State.smallFont:getHeight()/2)
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.print("Select", startX + hintR*2 + 6*S, btnY - State.smallFont:getHeight()/2)

    -- (X) Launch / Action
    local xPos = startX + 105 * S
    love.graphics.setColor(0.15, 0.55, 0.95, 1.0)
    love.graphics.circle("fill", xPos + hintR, btnY, hintR)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("X", xPos + hintR - State.smallFont:getWidth("X")/2, btnY - State.smallFont:getHeight()/2)
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.print("Launch", xPos + hintR*2 + 6*S, btnY - State.smallFont:getHeight()/2)

    -- (Y) Game Details / Edit
    local yPos = xPos + 115 * S
    love.graphics.setColor(0.95, 0.80, 0.10, 1.0)
    love.graphics.circle("fill", yPos + hintR, btnY, hintR)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("Y", yPos + hintR - State.smallFont:getWidth("Y")/2, btnY - State.smallFont:getHeight()/2)
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.print("Game Details", yPos + hintR*2 + 6*S, btnY - State.smallFont:getHeight()/2)

    -- [F6] Switch Layout
    local layoutPos = yPos + 140 * S
    love.graphics.setColor(0.15, 0.18, 0.24, 0.85)
    local lText = "[F6] Layout"
    local lw = State.smallFont:getWidth(lText) + 12 * S
    love.graphics.rectangle("fill", layoutPos, btnY - 10 * S, lw, 20 * S, 4 * S, 4 * S)
    love.graphics.setColor(0.85, 0.92, 1.0, 0.85)
    love.graphics.print(lText, layoutPos + 6 * S, btnY - State.smallFont:getHeight() / 2)
    return
  end

  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local Gamepad = require("core.gamepad")
  local prompts = Gamepad.getPromptIcons()

  local hintR = 11 * S
  local btnY = h - 28 * S
  local startX = 40 * S
  love.graphics.setFont(State.smallFont)

  -- Cancel / Back button (B on Xbox, Circle on PlayStation)
  love.graphics.setColor(prompts.cancel.color[1], prompts.cancel.color[2], prompts.cancel.color[3])
  love.graphics.circle("fill", startX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local bLabel = prompts.cancel.label
  love.graphics.print(bLabel, startX + hintR - State.smallFont:getWidth(bLabel)/2, btnY - State.smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("BACK", startX + hintR*2 + 8*S, btnY - State.smallFont:getHeight()/2)

  -- Confirm / Select button (A on Xbox, Cross on PlayStation)
  local selectX = startX + 110 * S
  love.graphics.setColor(prompts.confirm.color[1], prompts.confirm.color[2], prompts.confirm.color[3])
  love.graphics.circle("fill", selectX + hintR, btnY, hintR)
  love.graphics.setColor(0, 0, 0)
  local aLabel = prompts.confirm.label
  love.graphics.print(aLabel, selectX + hintR - State.smallFont:getWidth(aLabel)/2, btnY - State.smallFont:getHeight()/2)
  love.graphics.setColor(glowR, glowG, glowB)
  love.graphics.print("SELECT", selectX + hintR*2 + 8*S, btnY - State.smallFont:getHeight()/2)

  -- Shoulder Bumper Hint (LB/RB or L1/R1 for fast category switching)
  local bumperX = selectX + 130 * S
  love.graphics.setColor(0.15, 0.15, 0.2, 0.85)
  local bmpText = prompts.bumpers .. " SWITCH TABS"
  local bw = State.smallFont:getWidth(bmpText) + 16 * S
  love.graphics.rectangle("fill", bumperX, btnY - 11*S, bw, 22*S, 4*S, 4*S)
  love.graphics.setColor(glowR, glowG, glowB, 0.8)
  love.graphics.print(bmpText, bumperX + 8*S, btnY - State.smallFont:getHeight()/2)
end

local LayoutXbox   = require("core.layouts.xbox")
local LayoutXMB    = require("core.layouts.xmb")
local LayoutBlades = require("core.layouts.blades")

function M.getActiveLayoutEngine()
  if State.activeLayout == "XMB" then
    return LayoutXMB
  elseif State.activeLayout == "BLADES" then
    return LayoutBlades
  else
    return LayoutXbox
  end
end

-------------------------------------------------------------------------------
-- Full frame render (called from love.draw). Orchestrates the bloom pipeline.
-------------------------------------------------------------------------------
function M.frame()
  local w, h = love.graphics.getDimensions()
  local theme = Themes.current()
  local engine = M.getActiveLayoutEngine()

  -- 1. Background canvas (delegated to active layout engine)
  love.graphics.setCanvas(State.bgCanvas)
  love.graphics.clear(theme.bg[1], theme.bg[2], theme.bg[3], 1)
  engine.drawBackground(w, h)
  love.graphics.setCanvas()

  -- 2. Planet / decorative canvas (delegated to active layout engine)
  engine.drawPlanetAndRings()

  -- 3. Draw background to screen
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(State.bgCanvas, 0, 0)

  -- 4. Multi-pass bloom on decorative layer
  if State.blurShader and State.activeLayout == "XBOX" then
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

  -- 5. Crisp decorative layer over bloom (for Xbox layout)
  if State.activeLayout == "XBOX" then
    love.graphics.setBlendMode("alpha")
    love.graphics.draw(State.planetCanvas, 0, 0)
  end

  -- 6. Console Title Bar HUD
  M.drawTitleBar(w, h)

  -- 7. Main Menu (delegated to active layout engine: Xbox or PlayStation XMB)
  engine.drawMenu()

  -- 8. Dynamic Controller Prompts (Xbox or PlayStation)
  M.drawHints(w, h)
end

return M

-- ============================================================================
-- XBOX 360 "NXE" (NEW XBOX EXPERIENCE) LAYOUT ENGINE
-- Faithfully recreates the iconic 2008-2010 Xbox 360 NXE dashboard interface:
--
-- Features:
--   - Snowy twilight starry sky backdrop with crescent moon and twinkling stars
--   - Layered snowy mountain ranges with 3D shaded facets and pine tree ridges
--   - Reflective icy lake floor with real-time mirror reflections
--   - Animated water ripples emanating from the bottom-right 3D Xbox Guide orb
--   - Left vertical category column ("My Xbox", "Game Marketplace", etc.)
--   - Horizontal 3D perspective card carousel ("The Channel") with glossy active card
--   - Xbox 360 lime-green gradient trailing cards with silhouette icons
--   - Top-right Gamertag profile HUD with messages, friends, and Gamerpic
--   - Bottom item counter ("1 of 8") with floor reflection and Xbox button prompts
-- ============================================================================

local State     = require("core.state")
local Themes    = require("core.themes")
local Layout    = require("core.layout")
local MenuData  = require("core.menu_data")
local Shortcuts = require("core.shortcuts")
local MenuLogic = require("core.menu")
local Audio     = require("core.audio")

local M = {}

M.id = "BLADES"
M.name = "Xbox 360 NXE"

-- Animation states with damped spring physics
local catAnim   = 1.0
local itemAnim  = 1.0
local pulseTime = 0.0

-- Deterministic star field for sky
local STARS = {}
local function initStars()
  if #STARS > 0 then return end
  local rng = love.math.newRandomGenerator(3602008)
  for i = 1, 75 do
    table.insert(STARS, {
      x = rng:random(),
      y = rng:random() * 0.58, -- upper 58% of screen
      size = rng:random(10, 26) / 10,
      brightness = rng:random(40, 100) / 100,
      twinkleSpeed = rng:random(15, 40) / 10,
      twinkleOffset = rng:random() * math.pi * 2,
      hasSpike = (i <= 6) -- bright stars with diffraction spike
    })
  end
end

-------------------------------------------------------------------------------
-- Background: Twilight starry sky, crescent moon, snowy mountains & icy lake
-------------------------------------------------------------------------------
function M.drawBackground(w, h)
  initStars()
  local S = Layout.scale()
  local time = State.timeacc or 0
  local horizonY = h * 0.62

  -- 1) Sky Gradient: Midnight deep indigo to twilight horizon blue
  local skySteps = 24
  for i = 0, skySteps - 1 do
    local t1 = i / skySteps
    local t2 = (i + 1) / skySteps
    local y1 = t1 * horizonY
    local y2 = t2 * horizonY
    
    -- Color interpolation: #0a1936 -> #163e75 -> #2a629b
    local r = 0.04 + t1 * 0.12
    local g = 0.10 + t1 * 0.28
    local b = 0.22 + t1 * 0.38
    love.graphics.setColor(r, g, b, 1.0)
    love.graphics.rectangle("fill", 0, y1, w, y2 - y1 + 1)
  end

  -- 2) Star Field with soft twinkling
  love.graphics.setBlendMode("add")
  for _, st in ipairs(STARS) do
    local sx = st.x * w
    local sy = st.y * h
    local tw = math.sin(time * st.twinkleSpeed + st.twinkleOffset)
    local alpha = math.max(0.15, st.brightness * (0.65 + 0.35 * tw))
    
    love.graphics.setColor(0.90, 0.95, 1.0, alpha)
    love.graphics.circle("fill", sx, sy, st.size * S)
    
    -- Soft glow aura
    love.graphics.setColor(0.70, 0.85, 1.0, alpha * 0.3)
    love.graphics.circle("fill", sx, sy, st.size * 2.2 * S)

    -- Diffraction spike for focal stars
    if st.hasSpike then
      love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.6)
      local spikeLen = 8 * S
      love.graphics.line(sx - spikeLen, sy, sx + spikeLen, sy)
      love.graphics.line(sx, sy - spikeLen, sx, sy + spikeLen)
    end
  end
  love.graphics.setBlendMode("alpha")

  -- 3) Crescent Moon in upper center-left
  local moonX = w * 0.36
  local moonY = h * 0.14
  local moonR = 24 * S

  -- Moon atmospheric outer glow
  love.graphics.setBlendMode("add")
  for g = 1, 4 do
    local gr = moonR * (1.0 + g * 0.5)
    love.graphics.setColor(0.60, 0.80, 1.0, 0.07 / g)
    love.graphics.circle("fill", moonX, moonY, gr)
  end
  love.graphics.setBlendMode("alpha")

  -- Moon crescent body (drawn cleanly by masking or layered circles)
  love.graphics.setColor(0.92, 0.95, 1.0, 0.95)
  love.graphics.circle("fill", moonX, moonY, moonR)
  -- Shadow circle to form crisp crescent
  local skyR = 0.06 + (moonY / horizonY) * 0.12
  local skyG = 0.14 + (moonY / horizonY) * 0.28
  local skyB = 0.26 + (moonY / horizonY) * 0.38
  love.graphics.setColor(skyR, skyG, skyB, 1.0)
  love.graphics.circle("fill", moonX + moonR * 0.42, moonY - moonR * 0.15, moonR * 0.90)

  -- 4) Layered Snowy Mountains (Far background, Midground, Foreground Ridges)
  -- A. Distant Mountain Ridge (frosty pale blue)
  love.graphics.setColor(0.18, 0.32, 0.52, 0.70)
  love.graphics.polygon("fill",
    0, horizonY,
    0, horizonY - 140 * S,
    w * 0.15, horizonY - 190 * S,
    w * 0.28, horizonY - 150 * S,
    w * 0.46, horizonY - 260 * S,
    w * 0.60, horizonY - 170 * S,
    w * 0.76, horizonY - 220 * S,
    w * 0.88, horizonY - 160 * S,
    w, horizonY - 200 * S,
    w, horizonY
  )

  -- B. Main Snowy Mountain Range (authentic sharp crests & shaded facets)
  -- Shaded side (dark slate navy)
  love.graphics.setColor(0.10, 0.22, 0.38, 0.95)
  love.graphics.polygon("fill",
    0, horizonY,
    0, horizonY - 100 * S,
    w * 0.12, horizonY - 150 * S,
    w * 0.25, horizonY - 110 * S,
    w * 0.45, horizonY - 220 * S,
    w * 0.55, horizonY - 140 * S,
    w * 0.70, horizonY - 180 * S,
    w * 0.85, horizonY - 120 * S,
    w, horizonY - 160 * S,
    w, horizonY
  )

  -- Lit snowy facets (crisp pure white / icy cyan peaks)
  love.graphics.setColor(0.85, 0.92, 1.0, 0.90)
  -- Center majestic peak
  love.graphics.polygon("fill",
    w * 0.45, horizonY - 220 * S,
    w * 0.41, horizonY - 160 * S,
    w * 0.45, horizonY - 145 * S,
    w * 0.50, horizonY - 170 * S
  )
  -- Left peak snow
  love.graphics.polygon("fill",
    w * 0.12, horizonY - 150 * S,
    w * 0.08, horizonY - 115 * S,
    w * 0.13, horizonY - 105 * S,
    w * 0.18, horizonY - 125 * S
  )
  -- Right peak snow
  love.graphics.polygon("fill",
    w * 0.70, horizonY - 180 * S,
    w * 0.66, horizonY - 135 * S,
    w * 0.71, horizonY - 120 * S,
    w * 0.76, horizonY - 145 * S
  )

  -- C. Snow-covered Foothills and Evergreen Pine Silhouettes
  love.graphics.setColor(0.08, 0.16, 0.28, 1.0)
  love.graphics.polygon("fill",
    0, horizonY,
    0, horizonY - 45 * S,
    w * 0.18, horizonY - 65 * S,
    w * 0.38, horizonY - 40 * S,
    w * 0.62, horizonY - 55 * S,
    w * 0.82, horizonY - 35 * S,
    w, horizonY - 50 * S,
    w, horizonY
  )

  -- Snow caps on rolling hills
  love.graphics.setColor(0.80, 0.88, 0.98, 0.85)
  love.graphics.setLineWidth(3 * S)
  love.graphics.line(
    0, horizonY - 45 * S,
    w * 0.18, horizonY - 65 * S,
    w * 0.38, horizonY - 40 * S,
    w * 0.62, horizonY - 55 * S,
    w * 0.82, horizonY - 35 * S,
    w, horizonY - 50 * S
  )

  -- Pine trees along the tree line
  local treeXs = { 0.03, 0.06, 0.09, 0.14, 0.88, 0.92, 0.96 }
  for _, txRatio in ipairs(treeXs) do
    local tx = w * txRatio
    local ty = horizonY - 35 * S
    local treeH = 32 * S
    local treeW = 14 * S
    -- Dark pine silhouette
    love.graphics.setColor(0.05, 0.12, 0.20, 1.0)
    love.graphics.polygon("fill",
      tx, ty - treeH,
      tx - treeW * 0.5, ty,
      tx + treeW * 0.5, ty
    )
    -- Snow dusting on pine boughs
    love.graphics.setColor(0.85, 0.92, 1.0, 0.75)
    love.graphics.polygon("fill",
      tx, ty - treeH,
      tx - treeW * 0.3, ty - treeH * 0.5,
      tx + treeW * 0.3, ty - treeH * 0.5
    )
  end

  -- 5) Frozen Lake / Icy Reflective Floor (from horizonY down to bottom)
  local floorH = h - horizonY
  local floorSteps = 16
  for i = 0, floorSteps - 1 do
    local t1 = i / floorSteps
    local t2 = (i + 1) / floorSteps
    local y1 = horizonY + t1 * floorH
    local y2 = horizonY + t2 * floorH

    -- Gradient: frosty ice-blue #356e9c at shore to deep lake blue #14375e at bottom
    local r = 0.21 - t1 * 0.13
    local g = 0.43 - t1 * 0.21
    local b = 0.61 - t1 * 0.24
    love.graphics.setColor(r, g, b, 1.0)
    love.graphics.rectangle("fill", 0, y1, w, y2 - y1 + 1)
  end

  -- 6) Concentric Water Ripple Rings from bottom-right Xbox Guide Button
  local guideX = w - 110 * S
  local guideY = h - 75 * S
  love.graphics.setBlendMode("add")
  for r = 0, 4 do
    local phase = ((time * 30 + r * 36) % 180) * S
    local rippleAlpha = math.max(0, (1.0 - (phase / (180 * S)))) * 0.22
    love.graphics.setColor(0.60, 0.85, 1.0, rippleAlpha)
    love.graphics.setLineWidth(1.5 * S)
    -- Elliptical ripple (compressed on Y for 3D floor perspective)
    love.graphics.ellipse("line", guideX, guideY + 12 * S, phase * 1.6, phase * 0.45)
  end
  love.graphics.setBlendMode("alpha")
end

function M.drawPlanetAndRings()
  -- NXE centerpiece is the dynamic 3D channel carousel & reflective floor
end

-------------------------------------------------------------------------------
-- Helper: Draw an authentic 3D glossy Xbox 360 NXE card with floor reflection
-------------------------------------------------------------------------------
local function drawNXECard(item, cx, cy, cw, ch, isSelected, scale, depth)
  local S = Layout.scale()
  local r = 10 * S * scale

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)

  ---------------------------------------------------------------------------
  -- A) REAL-TIME FLOOR REFLECTION (mirrored upside down below card)
  ---------------------------------------------------------------------------
  local floorGap = 4 * S
  love.graphics.push()
  love.graphics.translate(0, ch * 2 + floorGap)
  love.graphics.scale(1, -0.65) -- vertically mirrored and compressed

  local reflAlpha = isSelected and 0.32 or (0.20 * (0.85 ^ depth))
  
  if isSelected then
    -- Reflection of dark glossy card
    love.graphics.setColor(0.04, 0.08, 0.12, reflAlpha)
    love.graphics.rectangle("fill", 0, 0, cw, ch, r, r)
  else
    -- Reflection of lime-green card
    love.graphics.setColor(0.40, 0.75, 0.05, reflAlpha * 0.85)
    love.graphics.rectangle("fill", 0, 0, cw, ch, r, r)
  end
  love.graphics.pop()

  ---------------------------------------------------------------------------
  -- B) MAIN CARD BODY
  ---------------------------------------------------------------------------
  if isSelected then
    -- Active / Focused Card: Deep glossy black/slate chassis with Xbox 360 green badge
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 6 * S, 6 * S, cw, ch, r, r)

    -- Card background
    love.graphics.setColor(0.07, 0.08, 0.10, 0.98)
    love.graphics.rectangle("fill", 0, 0, cw, ch, r, r)

    -- Fine outline highlight
    love.graphics.setColor(0.25, 0.35, 0.45, 0.70)
    love.graphics.setLineWidth(1.4 * S)
    love.graphics.rectangle("line", 0, 0, cw, ch, r, r)

    -- Top half specular glossy sheen
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", 2 * S, 2 * S, cw - 4 * S, ch * 0.48, r, r)

    -- Item Icon / Artwork (Centered)
    local iconImg = item.icon and State.iconCache[item.icon]
    if iconImg then
      local iw, ih = iconImg:getDimensions()
      local targetS = (100 * S) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, 1.0)
      love.graphics.draw(iconImg, (cw - iw * targetS) / 2, (ch * 0.45 - (ih * targetS) / 2), 0, targetS, targetS)
    else
      -- Stylized Xbox game logo / cover badge if no icon
      love.graphics.setColor(0.18, 0.22, 0.28, 0.9)
      love.graphics.rectangle("fill", cw * 0.15, ch * 0.12, cw * 0.70, ch * 0.50, 6 * S, 6 * S)
      love.graphics.setFont(State.bigFont)
      love.graphics.setColor(1, 1, 1, 0.95)
      local initial = item.name:sub(1, 1):upper()
      love.graphics.print(initial, (cw - State.bigFont:getWidth(initial)) / 2, ch * 0.20)
    end

    -- Bottom Bar: Item Title
    love.graphics.setFont(State.smallFont)
    love.graphics.setColor(1, 1, 1, 1.0)
    local titleText = item.name
    love.graphics.print(titleText, 18 * S, ch - 38 * S)

    -- Bottom Right: Xbox 360 Green DVD Disc Badge
    local badgeW = 44 * S
    local badgeH = 34 * S
    local badgeX = cw - badgeW - 12 * S
    local badgeY = ch - badgeH - 12 * S

    -- Lime green rounded badge
    love.graphics.setColor(0.48, 0.82, 0.05, 1.0)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 6 * S, 6 * S)

    -- Silver disc icon inside badge
    local discX = badgeX + badgeW * 0.5
    local discY = badgeY + badgeH * 0.5
    local discR = 11 * S
    love.graphics.setColor(0.95, 0.95, 0.95, 0.95)
    love.graphics.circle("fill", discX, discY, discR)
    love.graphics.setColor(0.48, 0.82, 0.05, 1.0)
    love.graphics.circle("fill", discX, discY, discR * 0.38)
    love.graphics.setColor(0.95, 0.95, 0.95, 0.95)
    love.graphics.circle("fill", discX, discY, discR * 0.16)

  else
    -- Trailing / Perspective Cards: Authentic Xbox 360 Lime Green Glossy Gradient
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 4 * S, 4 * S, cw, ch, r, r)

    -- Solid smooth lime green chassis (#5ea802)
    love.graphics.setColor(0.38, 0.72, 0.05, 0.96)
    love.graphics.rectangle("fill", 0, 0, cw, ch, r, r)

    -- Fine outline highlight
    love.graphics.setColor(0.65, 0.95, 0.15, 0.70)
    love.graphics.setLineWidth(1.2 * S)
    love.graphics.rectangle("line", 0, 0, cw, ch, r, r)

    -- Specular gloss curved highlight across top half
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.rectangle("fill", 2 * S, 2 * S, cw - 4 * S, ch * 0.44, r * 0.8, r * 0.8)

    -- Card Icon: Draw actual icon if present, otherwise clean white controller silhouette
    local iconImg = item.icon and State.iconCache[item.icon]
    if iconImg then
      local iw, ih = iconImg:getDimensions()
      local targetS = (56 * S) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, 1.0)
      love.graphics.draw(iconImg, (cw - iw * targetS) / 2, (ch * 0.42 - (ih * targetS) / 2), 0, targetS, targetS)
    else
      local iconX = cw * 0.5
      local iconY = ch * 0.42
      love.graphics.setColor(1, 1, 1, 0.95)
      love.graphics.circle("fill", iconX - 14 * S, iconY, 10 * S)
      love.graphics.circle("fill", iconX + 14 * S, iconY, 10 * S)
      love.graphics.rectangle("fill", iconX - 14 * S, iconY - 7 * S, 28 * S, 14 * S, 3 * S, 3 * S)
      love.graphics.setColor(0.35, 0.68, 0.04, 1.0)
      love.graphics.circle("fill", iconX - 14 * S, iconY, 3.5 * S)
      love.graphics.circle("fill", iconX + 14 * S, iconY, 3.5 * S)
    end

    -- Item Label at bottom
    love.graphics.setFont(State.smallFont)
    love.graphics.setColor(1, 1, 1, 0.95)
    local shortName = item.name
    if #shortName > 12 then shortName = shortName:sub(1, 10) .. ".." end
    local tw = State.smallFont:getWidth(shortName)
    love.graphics.print(shortName, (cw - tw) / 2, ch - 28 * S)
  end

  love.graphics.pop()
end

-------------------------------------------------------------------------------
-- Main Menu / NXE 3D Channel Drawer
-------------------------------------------------------------------------------
function M.drawMenu()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local categories = MenuData.categories
  local activeCatIdx = 1

  for i, c in ipairs(categories) do
    if c.id == State.currentMenuLevel then
      activeCatIdx = i
      break
    end
  end

  -- Damped spring animation for smooth scrolling
  catAnim  = catAnim  + (activeCatIdx - catAnim) * 0.22
  local targetItem = MenuLogic.activeIndex() or 1
  itemAnim = itemAnim + (targetItem - itemAnim) * 0.22

  ---------------------------------------------------------------------------
  -- 1) LEFT VERTICAL CATEGORY COLUMN (Our exact categories: GAMES, BROWSE, MEDIA, SETTINGS)
  ---------------------------------------------------------------------------
  -- Centering calculations:
  local activeW = 320 * S
  local activeH = 215 * S
  local totalCarouselW = activeW + 16 * S + 3.5 * (100 * S) -- span of active card + trailing cards
  local activeX = math.max(120 * S, (w - totalCarouselW) * 0.46)
  local activeY = (h - activeH) * 0.48
  local cardSpacing = 95 * S

  local catColX = activeX
  local catBaseY = activeY - 45 * S
  local catRowH  = 26 * S

  for i, cat in ipairs(categories) do
    local offset = i - catAnim
    local cy = catBaseY + offset * catRowH
    local isCur = (i == activeCatIdx)
    local title = cat.name:upper()

    if isCur then
      -- Active Category: Prominent, bold, bright white font sitting directly above the cards
      love.graphics.setFont(State.bigFont)
      love.graphics.setColor(1, 1, 1, 0.25)
      love.graphics.print(title, catColX + 1, cy + 1)
      love.graphics.setColor(1, 1, 1, 1.0)
      love.graphics.print(title, catColX, cy)
    else
      -- Inactive Categories: Stacked above, soft opacity fading vertically
      local alpha = math.max(0.0, 0.45 - math.abs(offset) * 0.12)
      if alpha > 0.05 then
        love.graphics.setFont(State.smallFont)
        love.graphics.setColor(0.85, 0.92, 1.0, alpha)
        love.graphics.print(title, catColX, cy + 3 * S)
      end
    end
  end

  ---------------------------------------------------------------------------
  -- 2) HORIZONTAL 3D CHANNEL CAROUSEL (Center to Right)
  ---------------------------------------------------------------------------
  local activeCat = categories[activeCatIdx]
  local items = activeCat and Shortcuts.mergedItems(activeCat.id) or {}
  local totalItems = #items

  if totalItems > 0 then
    -- A) Draw Leading Cards (cards before the active one sliding out to the left)
    for j = 1, totalItems do
      local relPos = j - itemAnim

      if relPos < -0.05 and relPos > -2.5 then
        -- Sliding out to the left
        local cx = activeX + relPos * (activeW * 0.85)
        local alpha = math.max(0.0, 1.0 + relPos * 0.8)
        love.graphics.setColor(1, 1, 1, alpha)
        drawNXECard(items[j], cx, activeY, activeW, activeH, true, 1.0, 0)
      elseif math.abs(relPos) <= 0.05 or (j == targetItem and math.abs(relPos) < 0.6) then
        -- Active Card
        local cx = activeX + relPos * 40 * S
        drawNXECard(items[j], cx, activeY, activeW, activeH, true, 1.0, 0)
      elseif relPos > 0.05 and relPos <= 4.5 then
        -- Trailing Cards receding to the right in 3D perspective
        local depth = relPos
        local cardScale = math.max(0.70, 0.92 ^ depth)
        local cx = activeX + activeW + 16 * S + (depth - 1) * cardSpacing
        local cy = activeY + (1.0 - cardScale) * activeH * 0.5
        local cw = 165 * S
        local ch = activeH

        drawNXECard(items[j], cx, cy, cw, ch, false, cardScale, depth)
      end
    end

    -- B) Item index indicator below active card (e.g. "1 of 8")
    local countStr = string.format("%d of %d", targetItem, totalItems)
    love.graphics.setFont(State.smallFont)
    local countY = activeY + activeH + 16 * S

    -- Floor reflection of counter
    love.graphics.setColor(0.60, 0.80, 1.0, 0.20)
    love.graphics.push()
    love.graphics.translate(activeX, countY + 16 * S)
    love.graphics.scale(1, -0.7)
    love.graphics.print(countStr, 0, 0)
    love.graphics.pop()

    -- Real counter text
    love.graphics.setColor(0.85, 0.92, 1.0, 0.90)
    love.graphics.print(countStr, activeX, countY)
  end

  ---------------------------------------------------------------------------
  -- 3) TOP-RIGHT GAMERTAG / PROFILE HUD (Cleanly below custom titlebar)
  ---------------------------------------------------------------------------
  local hudX = w - 240 * S
  local hudY = 56 * S
  local gamertag = os.getenv("USERNAME") or "Player 1"

  -- Gamertag text
  love.graphics.setFont(State.bigFont)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.print(gamertag, hudX, hudY)

  -- Vector Mail & Friends icons
  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(0.75, 0.88, 1.0, 0.85)
  love.graphics.print("0", hudX, hudY + 28 * S)
  
  -- Vector envelope
  local envX = hudX + 14 * S
  local envY = hudY + 32 * S
  love.graphics.setLineWidth(1.2 * S)
  love.graphics.rectangle("line", envX, envY, 14 * S, 10 * S, 2 * S, 2 * S)
  love.graphics.line(envX, envY, envX + 7 * S, envY + 5 * S)
  love.graphics.line(envX + 14 * S, envY, envX + 7 * S, envY + 5 * S)

  -- Vector friend icon
  love.graphics.print("0", hudX + 50 * S, hudY + 28 * S)
  local frX = hudX + 64 * S
  local frY = hudY + 31 * S
  love.graphics.circle("fill", frX + 5 * S, frY + 3 * S, 3 * S)
  love.graphics.arc("fill", frX + 5 * S, frY + 10 * S, 5 * S, -math.pi, 0)

  -- Gamerpic Square Box (Fits cleanly inside content window below titlebar)
  local picSize = 38 * S
  local picX = w - 55 * S
  local picY = 52 * S
  love.graphics.setColor(0.08, 0.14, 0.22, 0.95)
  love.graphics.rectangle("fill", picX, picY, picSize, picSize, 6 * S, 6 * S)
  love.graphics.setColor(0.48, 0.82, 0.05, 0.9)
  love.graphics.setLineWidth(1.5 * S)
  love.graphics.rectangle("line", picX, picY, picSize, picSize, 6 * S, 6 * S)

  -- Avatar silhouette inside gamerpic
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.circle("fill", picX + picSize * 0.5, picY + picSize * 0.38, 7 * S)
  love.graphics.rectangle("fill", picX + picSize * 0.25, picY + picSize * 0.60, picSize * 0.5, picSize * 0.35, 4 * S, 4 * S)

  ---------------------------------------------------------------------------
  -- 4) BOTTOM-RIGHT 3D XBOX GUIDE BUTTON (Emits ripples across ice)
  ---------------------------------------------------------------------------
  local orbX = w - 90 * S
  local orbY = h - 65 * S
  local orbR = 22 * S

  -- Chrome outer bevel ring
  love.graphics.setColor(0.75, 0.80, 0.88, 0.95)
  love.graphics.circle("fill", orbX, orbY, orbR)
  love.graphics.setColor(0.35, 0.40, 0.48, 1.0)
  love.graphics.circle("fill", orbX, orbY, orbR - 2.5 * S)

  -- Inner dark core
  love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
  love.graphics.circle("fill", orbX, orbY, orbR - 5 * S)

  -- Silver quadrant cross lines
  love.graphics.setColor(0.70, 0.75, 0.82, 1.0)
  love.graphics.setLineWidth(1.8 * S)
  love.graphics.line(orbX - (orbR - 5 * S), orbY, orbX + (orbR - 5 * S), orbY)
  love.graphics.line(orbX, orbY - (orbR - 5 * S), orbX, orbY + (orbR - 5 * S))

  -- Illuminated glowing Xbox lime green LED quadrant (Top-Left)
  love.graphics.setColor(0.50, 0.95, 0.05, 0.95)
  love.graphics.arc("fill", orbX, orbY, orbR - 6 * S, -math.pi, -math.pi * 0.5)

  -- Center dome specular highlight
  love.graphics.setColor(1, 1, 1, 0.55)
  love.graphics.circle("fill", orbX - 4 * S, orbY - 4 * S, 6 * S)
end

-------------------------------------------------------------------------------
-- Mouse Click Handler for NXE Layout
-------------------------------------------------------------------------------
function M.handleClick(mx, my)
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local categories = MenuData.categories

  local activeW = 320 * S
  local activeH = 215 * S
  local totalCarouselW = activeW + 16 * S + 3.5 * (100 * S)
  local activeX = math.max(120 * S, (w - totalCarouselW) * 0.46)
  local activeY = (h - activeH) * 0.48
  local cardSpacing = 95 * S

  local catColX = activeX
  local catBaseY = activeY - 45 * S
  local catRowH  = 26 * S

  -- 1) Clicking on any category in the left column switches to it
  for i, cat in ipairs(categories) do
    local cy = catBaseY + (i - catAnim) * catRowH
    if mx >= catColX and mx <= catColX + 220 * S and my >= cy and my <= cy + catRowH then
      Audio.play("swoosh")
      State.currentMenuLevel = cat.id
      State.selected = i
      State.subSelected = 1
      return true
    end
  end

  -- 2) Clicking on the active card or trailing cards
  local items = Shortcuts.mergedItems(State.currentMenuLevel)
  local totalItems = #items
  local targetItem = MenuLogic.activeIndex() or 1

  -- Click on active card -> activate item!
  if mx >= activeX and mx <= activeX + activeW and my >= activeY and my <= activeY + activeH then
    MenuLogic.activateItem(targetItem)
    return true
  end

  -- Click on trailing cards -> select that card
  for j = 1, totalItems do
    if j ~= targetItem then
      local relPos = j - itemAnim
      if relPos > 0.05 and relPos <= 4.5 then
        local depth = relPos
        local cardScale = math.max(0.70, 0.92 ^ depth)
        local cx = activeX + activeW + 16 * S + (depth - 1) * cardSpacing
        local cy = activeY + (1.0 - cardScale) * activeH * 0.5
        local cw = 165 * S * cardScale
        local ch = activeH * cardScale
        if mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch then
          State.subSelected = j
          Audio.play("tick")
          return true
        end
      end
    end
  end

  return false
end

return M

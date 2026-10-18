-- ============================================================================
-- XBOX 360 "BLADES" (2005) LAYOUT ENGINE
-- Inspired by the legendary 2005 Xbox 360 dashboard interface.
--
-- Features:
--   - Horizontal sliding colored blades (Marketplace, Games, Media, System)
--   - Authentic metallic spine tabs with angle tilts and drop shadows
--   - Horizontal camera stack sliding with kinetic damped spring easing
--   - Glossy rectangular item cards/tiles inside the active blade pane
--   - Right-side Xbox 360 style Gamertag / HUD panel
-- ============================================================================

local State     = require("core.state")
local Themes    = require("core.themes")
local Layout    = require("core.layout")
local MenuData  = require("core.menu_data")
local Shortcuts = require("core.shortcuts")
local MenuLogic = require("core.menu")

local M = {}

M.id = "BLADES"
M.name = "Xbox 360 Blades"

-- Smooth blade stack animation position
local bladeAnim = 1.0
local itemAnim  = 1.0

-- Distinct authentic blade tab colors (Xbox 360 style)
local BLADE_COLORS = {
  { r = 0.95, g = 0.45, b = 0.10 }, -- Marketplace / Games (Orange)
  { r = 0.15, g = 0.75, b = 0.25 }, -- Games (Xbox Green)
  { r = 0.15, g = 0.55, b = 0.95 }, -- Media (Blue)
  { r = 0.65, g = 0.35, b = 0.85 }, -- System / Settings (Purple)
}

-------------------------------------------------------------------------------
-- Background: Classic 360 brushed metal sphere curves & radial glow
-------------------------------------------------------------------------------
function M.drawBackground(w, h)
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]
  local S = Layout.scale()

  -- Base radial background
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(0.08, 0.08, 0.10, 1.0)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Subtle circular ambient glow on right edge
  love.graphics.setBlendMode("add")
  love.graphics.setColor(glowR, glowG, glowB, 0.14)
  love.graphics.circle("fill", w * 0.85, h * 0.5, 360 * S)

  -- Brushed curved rings
  love.graphics.setColor(1, 1, 1, 0.04)
  love.graphics.setLineWidth(2 * S)
  for r = 1, 4 do
    love.graphics.circle("line", w * 0.85, h * 0.5, (220 + r * 70) * S)
  end
  love.graphics.setBlendMode("alpha")
end

function M.drawPlanetAndRings()
  -- Blades layout uses the blade stack as its centerpiece
end

-------------------------------------------------------------------------------
-- Draw Xbox 360 Blades Stack + Active Content Pane
-------------------------------------------------------------------------------
function M.drawMenu()
  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  local categories = MenuData.categories
  local activeCatIdx = 1

  for i, c in ipairs(categories) do
    if c.id == State.currentMenuLevel then
      activeCatIdx = i
      break
    end
  end

  -- Damped spring animation for blade sliding
  bladeAnim = bladeAnim + (activeCatIdx - bladeAnim) * 0.20
  local targetItem = MenuLogic.activeIndex() or 1
  itemAnim = itemAnim + (targetItem - itemAnim) * 0.22

  local bladeW = 540 * S
  local bladeH = h * 0.82
  local bladeTop = h * 0.09
  local spineW = 52 * S

  ---------------------------------------------------------------------------
  -- 1) DRAW THE SLIDING BLADES STACK
  ---------------------------------------------------------------------------
  for i, cat in ipairs(categories) do
    local offset = i - bladeAnim
    local color = BLADE_COLORS[((i - 1) % #BLADE_COLORS) + 1]

    -- Blade base X coordinate: active blade is centered, inactive blades stack on left/right
    local bx = 0
    if i < activeCatIdx then
      bx = 40 * S + (i - 1) * spineW
    elseif i == activeCatIdx then
      bx = 40 * S + (i - 1) * spineW + (1.0 - math.abs(offset)) * 20 * S
    else
      bx = w - (bladeW * 0.5) + (i - activeCatIdx) * spineW
    end

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", bx + 10 * S, bladeTop + 10 * S, bladeW, bladeH, 12 * S, 12 * S)

    -- Blade Body
    local isFocused = (i == activeCatIdx)
    local fillAlpha = isFocused and 0.95 or 0.75
    love.graphics.setColor(color.r * 0.35, color.g * 0.35, color.b * 0.35, fillAlpha)
    love.graphics.rectangle("fill", bx, bladeTop, bladeW, bladeH, 12 * S, 12 * S)

    -- Metallic Spine / Tab Accent on left edge
    love.graphics.setColor(color.r, color.g, color.b, isFocused and 1.0 or 0.8)
    love.graphics.rectangle("fill", bx, bladeTop, spineW, bladeH, 12 * S, 12 * S)

    -- Top bevel gloss
    love.graphics.setColor(1, 1, 1, isFocused and 0.25 or 0.08)
    love.graphics.rectangle("fill", bx + 4 * S, bladeTop + 4 * S, bladeW - 8 * S, 32 * S, 8 * S, 8 * S)

    -- Spine Category Label (vertical-style header)
    love.graphics.push()
    love.graphics.translate(bx + spineW * 0.5, bladeTop + bladeH * 0.5)
    love.graphics.rotate(-math.pi / 2)
    love.graphics.setFont(State.bigFont)
    love.graphics.setColor(1, 1, 1, isFocused and 1.0 or 0.75)
    local lbl = cat.name
    love.graphics.print(lbl, -State.bigFont:getWidth(lbl) / 2, -State.bigFont:getHeight() / 2)
    love.graphics.pop()

    -- 2) ACTIVE BLADE TILES / CARDS
    if isFocused then
      local items = Shortcuts.mergedItems(cat.id)
      local contentX = bx + spineW + 20 * S
      local contentW = bladeW - spineW - 35 * S

      -- Header
      love.graphics.setFont(State.bigFont)
      love.graphics.setColor(color.r, color.g, color.b, 1.0)
      love.graphics.print(cat.name:upper(), contentX, bladeTop + 24 * S)

      -- Scrollable card list
      local cardH = 50 * S
      local cardSpacing = 12 * S
      local startY = bladeTop + 72 * S

      for j, item in ipairs(items) do
        local cy = startY + (j - 1) * (cardH + cardSpacing) - (itemAnim - 1) * (cardH + cardSpacing)
        
        -- Cull outside blade bounds
        if cy >= bladeTop + 60 * S and cy <= bladeTop + bladeH - 60 * S then
          local isCardSel = (j == targetItem)
          
          -- Card glow / background
          if isCardSel then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(color.r, color.g, color.b, 0.3)
            love.graphics.rectangle("fill", contentX - 4 * S, cy - 4 * S, contentW + 8 * S, cardH + 8 * S, 8 * S, 8 * S)
            love.graphics.setBlendMode("alpha")
          end

          love.graphics.setColor(0.12, 0.12, 0.16, isCardSel and 0.95 or 0.6)
          love.graphics.rectangle("fill", contentX, cy, contentW, cardH, 6 * S, 6 * S)
          love.graphics.setColor(color.r, color.g, color.b, isCardSel and 1.0 or 0.3)
          love.graphics.setLineWidth(1.2 * S)
          love.graphics.rectangle("line", contentX, cy, contentW, cardH, 6 * S, 6 * S)

          -- Item icon
          local iconImg = item.icon and State.iconCache[item.icon]
          if iconImg then
            local iw, ih = iconImg:getDimensions()
            local s = (30 * S) / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, isCardSel and 1.0 or 0.8)
            love.graphics.draw(iconImg, contentX + 10 * S, cy + (cardH - 30 * S) / 2, 0, s, s)
          end

          -- Item name
          love.graphics.setFont(State.smallFont)
          love.graphics.setColor(1, 1, 1, isCardSel and 1.0 or 0.75)
          love.graphics.print(item.name, contentX + 48 * S, cy + (cardH - State.smallFont:getHeight()) / 2)
        end
      end
    end
  end

  ---------------------------------------------------------------------------
  -- 2) XBOX 360 RIGHT-SIDE STATUS PANE
  ---------------------------------------------------------------------------
  local rightX = w * 0.75
  local rightY = bladeTop
  local rightW = w * 0.21
  local rightH = 140 * S

  love.graphics.setColor(0.06, 0.06, 0.09, 0.85)
  love.graphics.rectangle("fill", rightX, rightY, rightW, rightH, 10 * S, 10 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.35)
  love.graphics.rectangle("line", rightX, rightY, rightW, rightH, 10 * S, 10 * S)

  -- Gamertag / Profile status
  love.graphics.setFont(State.bigFont)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.print("Player 1", rightX + 16 * S, rightY + 16 * S)

  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(0.18, 0.85, 0.35, 1.0)
  love.graphics.print("● ONLINE", rightX + 16 * S, rightY + 48 * S)

  love.graphics.setColor(1, 1, 1, 0.6)
  local timeStr = os.date("%A, %b %d")
  love.graphics.print(timeStr, rightX + 16 * S, rightY + 80 * S)
end

return M

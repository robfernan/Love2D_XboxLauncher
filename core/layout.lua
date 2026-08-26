-- ============================================================================
-- RESPONSIVE LAYOUT
-- All UI geometry is expressed relative to a 1280x720 reference so the layout
-- looks identical at any window resolution (no dead space / cut-off). The user's
-- `uiScale` setting multiplies on top for accessibility.
--
-- Every draw function AND every hit-test must use these same constants so what
-- you see is exactly what's clickable.
-- ============================================================================

local Config = require("core.config")

local M = {}

M.REF_W, M.REF_H = 1280, 720

-- Current responsive scale factor (window-relative * user uiScale).
-- UNIFORM scaling: one factor derived from the SMALLER axis ratio, applied to
-- everything. This guarantees identical proportions at any resolution — no
-- stretching, no overflow — and the user's uiScale multiplies on top for
-- accessibility. The layout is centered, so letterboxing on non-16:9 windows
-- is expected and correct (same look as 1280x720, just larger/smaller).
function M.scale()
  local w, h = love.graphics.getDimensions()
  local base = math.min(w / M.REF_W, h / M.REF_H)
  if base < 0.5 then base = 0.5 end   -- floor so UI never shrinks below usable
  local user = Config.get("uiScale")
  if type(user) ~= "number" then user = 1.0 end
  return base * user
end

-- Menu item geometry (must match render.drawMenu).
-- `itemCount` is the number of items at the current level; pass it in so this
-- function stays pure and doesn't need to know about menu state.
-- Uniform sizing: every dimension scales by S, so proportions are identical at
-- any resolution. The list is vertically centered around cy.
function M.menuItemRect(idx, itemCount)
  local w, h = love.graphics.getDimensions()
  local S = M.scale()
  local cx, cy = w * 0.44, h * 0.5
  local itemW, itemH, spacing = 290 * S, 48 * S, 12 * S
  local y = cy - (itemCount * (itemH + spacing)) / 2 + (idx - 1) * (itemH + spacing)
  return cx, y, itemW, itemH
end

-- Title-bar button rects (must match render.drawTitleBar).
function M.titleBarButtons()
  local w = love.graphics.getWidth()
  local S = M.scale()
  local barH = 32 * S
  local btnSize = 20 * S
  local btnPad = 6 * S
  local closeX = w - btnPad - btnSize
  local minBtnX = closeX - btnSize - 8 * S
  local btnY0 = (barH - btnSize) / 2
  return {
    close    = { x = closeX,   y = btnY0, w = btnSize, h = btnSize },
    minimize = { x = minBtnX,  y = btnY0, w = btnSize, h = btnSize },
    barH     = barH,
  }
end

-- Bottom-left B/A hint-badge circles (must match render.drawHints).
function M.hintButtons()
  local h = love.graphics.getHeight()
  local S = M.scale()
  local r = 11 * S
  local btnY = h - 28 * S
  local startX = 40 * S
  return {
    back   = { cx = startX + r,        cy = btnY, r = r },
    select = { cx = startX + 110*S + r, cy = btnY, r = r },
  }
end

-- Hit-test helpers.
function M.pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function M.pointInCircle(px, py, c)
  local dx, dy = px - c.cx, py - c.cy
  return (dx * dx + dy * dy) <= (c.r * c.r)
end

return M

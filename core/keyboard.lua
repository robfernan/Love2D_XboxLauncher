-- ============================================================================
-- VIRTUAL ON-SCREEN KEYBOARD (OSK)
-- Authentic console-style virtual keyboard for gamepad & mouse input.
-- Allows full text entry for shortcut names, URLs, and commands without
-- needing a physical keyboard.
--
-- Features:
--   - Gamepad D-Pad & analog stick navigation with smooth highlighted cursor
--   - Fast shortcut buttons: (A) Type, (X) Backspace, (Y) Space, (Start) Done, (B) Cancel
--   - Mouse click support for each virtual key
--   - Blinking cursor text preview
-- ============================================================================

local State  = require("core.state")
local Layout = require("core.layout")
local Themes = require("core.themes")
local Audio  = require("core.audio")

local M = {}

M.active = false
M.text = ""
M.callback = nil
M.cursorRow = 2
M.cursorCol = 1

local ROWS = {
  { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
  { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
  { "A", "S", "D", "F", "G", "H", "J", "K", "L", "@" },
  { "Z", "X", "C", "V", "B", "N", "M", ".", "-", "/" },
  { { label = "SPACE", w = 3, val = " " }, { label = "BACK", w = 2, action = "back" }, { label = "CLEAR", w = 2, action = "clear" }, { label = "DONE", w = 3, action = "done" } }
}

function M.open(initialText, callback)
  M.active = true
  M.text = initialText or ""
  M.callback = callback
  M.cursorRow = 2
  M.cursorCol = 1
end

function M.isOpen()
  return M.active
end

function M.close()
  M.active = false
end

function M.confirm()
  local cb = M.callback
  local txt = M.text
  M.active = false
  if cb then cb(txt) end
end

local function applyKey(k)
  if type(k) == "table" then
    if k.action == "back" then
      if #M.text > 0 then
        M.text = M.text:sub(1, -2)
        Audio.play("back")
      end
    elseif k.action == "clear" then
      M.text = ""
      Audio.play("back")
    elseif k.action == "done" then
      Audio.play("select")
      M.confirm()
    elseif k.val then
      M.text = M.text .. k.val
      Audio.play("tick")
    end
  else
    M.text = M.text .. k
    Audio.play("tick")
  end
end

function M.keypressed(key)
  if not M.active then return false end

  if key == "escape" or key == "b" then
    M.close()
    return true
  elseif key == "return" or key == "kpenter" then
    local curRow = ROWS[M.cursorRow]
    local curKey = curRow and curRow[M.cursorCol]
    if curKey then applyKey(curKey) end
    return true
  elseif key == "backspace" then
    if #M.text > 0 then
      M.text = M.text:sub(1, -2)
      Audio.play("back")
    end
    return true
  end

  if key == "up" then
    M.cursorRow = math.max(1, M.cursorRow - 1)
    local maxCol = #ROWS[M.cursorRow]
    M.cursorCol = math.min(M.cursorCol, maxCol)
    Audio.play("tick")
    return true
  elseif key == "down" then
    M.cursorRow = math.min(#ROWS, M.cursorRow + 1)
    local maxCol = #ROWS[M.cursorRow]
    M.cursorCol = math.min(M.cursorCol, maxCol)
    Audio.play("tick")
    return true
  elseif key == "left" then
    local maxCol = #ROWS[M.cursorRow]
    M.cursorCol = ((M.cursorCol - 2 + maxCol) % maxCol) + 1
    Audio.play("tick")
    return true
  elseif key == "right" then
    local maxCol = #ROWS[M.cursorRow]
    M.cursorCol = (M.cursorCol % maxCol) + 1
    Audio.play("tick")
    return true
  end

  return true
end

function M.gamepadpressed(button)
  if not M.active then return false end

  if button == "b" then
    M.close()
    return true
  elseif button == "a" then
    local curRow = ROWS[M.cursorRow]
    local curKey = curRow and curRow[M.cursorCol]
    if curKey then applyKey(curKey) end
    return true
  elseif button == "x" then
    -- Shortcut: Backspace
    if #M.text > 0 then
      M.text = M.text:sub(1, -2)
      Audio.play("back")
    end
    return true
  elseif button == "y" then
    -- Shortcut: Space
    M.text = M.text .. " "
    Audio.play("tick")
    return true
  elseif button == "start" then
    Audio.play("select")
    M.confirm()
    return true
  elseif button == "dpup" then
    M.keypressed("up")
    return true
  elseif button == "dpdown" then
    M.keypressed("down")
    return true
  elseif button == "dpleft" then
    M.keypressed("left")
    return true
  elseif button == "dpright" then
    M.keypressed("right")
    return true
  end

  return false
end

function M.mousepressed(x, y, button)
  if not M.active or button ~= 1 then return false end

  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local kw = 640 * S
  local kh = 320 * S
  local kx = (w - kw) * 0.5
  local ky = (h - kh) * 0.5

  local textH = 40 * S
  local textY = ky + 18 * S
  local gridStartY = textY + textH + 16 * S
  local keyH = 34 * S
  local gap = 6 * S
  local baseUnitW = (kw - 48 * S - (9 * gap)) / 10

  for rIdx, row in ipairs(ROWS) do
    local ry = gridStartY + (rIdx - 1) * (keyH + gap)
    local curX = kx + 24 * S

    for cIdx, keyItem in ipairs(row) do
      local span = type(keyItem) == "table" and keyItem.w or 1
      local kw_span = span * baseUnitW + (span - 1) * gap

      if x >= curX and x <= curX + kw_span and y >= ry and y <= ry + keyH then
        M.cursorRow = rIdx
        M.cursorCol = cIdx
        applyKey(keyItem)
        return true
      end

      curX = curX + kw_span + gap
    end
  end

  -- Click outside keyboard dismisses it
  if x < kx or x > kx + kw or y < ky or y > ky + kh then
    M.close()
    return true
  end

  return true
end

function M.draw(w, h)
  if not M.active then return end

  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  -- Semi-transparent dark backdrop modal
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local kw = 640 * S
  local kh = 320 * S
  local kx = (w - kw) * 0.5
  local ky = (h - kh) * 0.5

  -- Keyboard chassis
  love.graphics.setColor(0.08, 0.10, 0.14, 0.96)
  love.graphics.rectangle("fill", kx, ky, kw, kh, 12 * S, 12 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.45)
  love.graphics.setLineWidth(1.8 * S)
  love.graphics.rectangle("line", kx, ky, kw, kh, 12 * S, 12 * S)

  -- Input text display field
  local textH = 40 * S
  local textY = ky + 18 * S
  love.graphics.setColor(0.04, 0.05, 0.07, 0.95)
  love.graphics.rectangle("fill", kx + 24 * S, textY, kw - 48 * S, textH, 6 * S, 6 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.6)
  love.graphics.rectangle("line", kx + 24 * S, textY, kw - 48 * S, textH, 6 * S, 6 * S)

  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(1, 1, 1, 1.0)
  local cursorBlink = (math.floor(State.timeacc * 2.5) % 2 == 0) and "|" or ""
  love.graphics.print(M.text .. cursorBlink, kx + 36 * S, textY + (textH - State.smallFont:getHeight()) * 0.5)

  -- Key grid
  local gridStartY = textY + textH + 16 * S
  local keyH = 34 * S
  local gap = 6 * S
  local baseUnitW = (kw - 48 * S - (9 * gap)) / 10

  for rIdx, row in ipairs(ROWS) do
    local ry = gridStartY + (rIdx - 1) * (keyH + gap)
    local curX = kx + 24 * S

    for cIdx, keyItem in ipairs(row) do
      local label = type(keyItem) == "table" and keyItem.label or keyItem
      local span = type(keyItem) == "table" and keyItem.w or 1
      local kw_span = span * baseUnitW + (span - 1) * gap
      local isCursor = (rIdx == M.cursorRow and cIdx == M.cursorCol)

      if isCursor then
        -- Highlighted key
        love.graphics.setColor(glowR, glowG, glowB, 0.85)
        love.graphics.rectangle("fill", curX, ry, kw_span, keyH, 4 * S, 4 * S)
        love.graphics.setColor(0, 0, 0, 1.0)
      else
        -- Normal key
        love.graphics.setColor(0.14, 0.17, 0.22, 0.9)
        love.graphics.rectangle("fill", curX, ry, kw_span, keyH, 4 * S, 4 * S)
        love.graphics.setColor(0.9, 0.95, 1.0, 0.85)
      end

      local tw = State.smallFont:getWidth(label)
      local th = State.smallFont:getHeight()
      love.graphics.print(label, curX + (kw_span - tw) * 0.5, ry + (keyH - th) * 0.5)

      curX = curX + kw_span + gap
    end
  end

  -- Bottom Controller Hints
  local hintY = ky + kh - 28 * S
  love.graphics.setColor(0.7, 0.85, 1.0, 0.8)
  local hintStr = "(A) Type   (X) Backspace   (Y) Space   (Start) Done   (B) Cancel"
  love.graphics.print(hintStr, kx + (kw - State.smallFont:getWidth(hintStr)) * 0.5, hintY)
end

return M

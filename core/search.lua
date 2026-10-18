-- ============================================================================
-- QUICK SEARCH / FILTER OVERLAY
-- Press Ctrl+F or Y on the dashboard to quickly search and launch any game,
-- application, or website across all categories in real-time.
--
-- Features:
--   - Real-time instant fuzzy/substring search
--   - Searches built-in items, custom shortcuts, and scanned Steam games
--   - Up/Down navigation, Enter/(A) launches instantly, Esc/(B) cancels
--   - Responsive glowing HUD interface matching the current theme
-- ============================================================================

local State     = require("core.state")
local MenuData  = require("core.menu_data")
local Shortcuts = require("core.shortcuts")
local Launcher  = require("core.launcher")
local Layout    = require("core.layout")
local Themes    = require("core.themes")
local Audio     = require("core.audio")

local M = {}

M.active = false
M.query = ""
M.results = {}
M.selectedIndex = 1

local function rebuildResults()
  M.results = {}
  local q = M.query:lower():gsub("^%s*(.-)%s*$", "%1")

  -- Collect all launchable items across all categories
  local all = {}
  for _, cat in ipairs(MenuData.categories) do
    if cat.id ~= "SETTINGS" then
      local items = Shortcuts.mergedItems(cat.id)
      for _, item in ipairs(items) do
        if item.url or item.cmd then
          table.insert(all, { item = item, category = cat.name })
        end
      end
    end
  end

  if #q == 0 then
    -- Show top 8 items if no query
    for i = 1, math.min(8, #all) do
      table.insert(M.results, all[i])
    end
  else
    for _, entry in ipairs(all) do
      if entry.item.name:lower():find(q, 1, true) then
        table.insert(M.results, entry)
      end
    end
  end

  M.selectedIndex = math.max(1, math.min(M.selectedIndex, #M.results))
end

function M.open()
  M.active = true
  M.query = ""
  M.selectedIndex = 1
  rebuildResults()
end

function M.isOpen()
  return M.active
end

function M.close()
  M.active = false
  M.query = ""
end

function M.activateSelected()
  local entry = M.results[M.selectedIndex]
  if entry and entry.item then
    Audio.play("select")
    M.close()
    Launcher.launch(entry.item)
  end
end

function M.keypressed(key)
  if not M.active then return false end

  if key == "escape" or key == "b" then
    M.close()
    return true
  elseif key == "return" or key == "kpenter" then
    M.activateSelected()
    return true
  elseif key == "up" then
    if #M.results > 0 then
      M.selectedIndex = ((M.selectedIndex - 2 + #M.results) % #M.results) + 1
      Audio.play("tick")
    end
    return true
  elseif key == "down" then
    if #M.results > 0 then
      M.selectedIndex = (M.selectedIndex % #M.results) + 1
      Audio.play("tick")
    end
    return true
  elseif key == "backspace" then
    if #M.query > 0 then
      M.query = M.query:sub(1, -2)
      rebuildResults()
      Audio.play("tick")
    end
    return true
  end

  -- Printable characters
  if key:match("^[%a%d%._/%\\:%- ]$") then
    M.query = M.query .. key
    rebuildResults()
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
  elseif button == "a" or button == "start" then
    M.activateSelected()
    return true
  elseif button == "dpup" then
    return M.keypressed("up")
  elseif button == "dpdown" then
    return M.keypressed("down")
  elseif button == "x" then
    return M.keypressed("backspace")
  end

  return false
end

function M.draw(w, h)
  if not M.active then return end

  local S = Layout.scale()
  local theme = Themes.current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  -- Semi-transparent backdrop
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local pw = 520 * S
  local ph = 400 * S
  local px = (w - pw) * 0.5
  local py = (h - ph) * 0.42

  -- Search Window Chassis
  love.graphics.setColor(0.08, 0.10, 0.14, 0.96)
  love.graphics.rectangle("fill", px, py, pw, ph, 10 * S, 10 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.5)
  love.graphics.setLineWidth(1.8 * S)
  love.graphics.rectangle("line", px, py, pw, ph, 10 * S, 10 * S)

  -- Header / Search Query Box
  local qh = 42 * S
  love.graphics.setColor(0.04, 0.05, 0.08, 0.95)
  love.graphics.rectangle("fill", px + 16 * S, py + 16 * S, pw - 32 * S, qh, 6 * S, 6 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.7)
  love.graphics.rectangle("line", px + 16 * S, py + 16 * S, pw - 32 * S, qh, 6 * S, 6 * S)

  love.graphics.setFont(State.smallFont)
  love.graphics.setColor(1, 1, 1, 1.0)
  local cursorBlink = (math.floor(State.timeacc * 2.5) % 2 == 0) and "|" or ""
  local searchPlaceholder = (#M.query == 0) and "Type to search games & apps..." or M.query
  love.graphics.setColor(1, 1, 1, (#M.query == 0) and 0.45 or 1.0)
  love.graphics.print(searchPlaceholder .. ((#M.query > 0) and cursorBlink or ""), px + 28 * S, py + 16 * S + (qh - State.smallFont:getHeight()) * 0.5)

  -- Results list
  local listStartY = py + 72 * S
  local rowH = 34 * S
  local maxVisible = math.min(8, #M.results)

  if #M.results == 0 then
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.print("No matching items found.", px + 28 * S, listStartY + 16 * S)
  else
    for i = 1, maxVisible do
      local entry = M.results[i]
      local ry = listStartY + (i - 1) * (rowH + 4 * S)
      local isSel = (i == M.selectedIndex)

      if isSel then
        love.graphics.setColor(glowR, glowG, glowB, 0.25)
        love.graphics.rectangle("fill", px + 16 * S, ry, pw - 32 * S, rowH, 4 * S, 4 * S)
        love.graphics.setColor(glowR, glowG, glowB, 0.9)
        love.graphics.rectangle("line", px + 16 * S, ry, pw - 32 * S, rowH, 4 * S, 4 * S)
      else
        love.graphics.setColor(0.12, 0.14, 0.18, 0.7)
        love.graphics.rectangle("fill", px + 16 * S, ry, pw - 32 * S, rowH, 4 * S, 4 * S)
      end

      -- Category tag
      love.graphics.setColor(glowR, glowG, glowB, 0.7)
      love.graphics.print("[" .. entry.category .. "]", px + 28 * S, ry + (rowH - State.smallFont:getHeight()) * 0.5)

      -- Item name
      love.graphics.setColor(1, 1, 1, isSel and 1.0 or 0.8)
      love.graphics.print(entry.item.name, px + 110 * S, ry + (rowH - State.smallFont:getHeight()) * 0.5)
    end
  end

  -- Bottom Footer Hints
  local footerY = py + ph - 26 * S
  love.graphics.setFont(State.tinyFont or State.smallFont)
  love.graphics.setColor(0.7, 0.85, 1.0, 0.75)
  local footerStr = "(A) / Enter: Launch   (B) / Esc: Close   Up/Down: Navigate"
  love.graphics.print(footerStr, px + (pw - State.smallFont:getWidth(footerStr)) * 0.5, footerY)
end

return M

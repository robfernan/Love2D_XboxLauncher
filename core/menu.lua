-- ============================================================================
-- MENU LOGIC
-- Navigation state machine + item activation. Both keyboard and mouse input
-- paths call into here so they can never drift out of sync.
-- ============================================================================

local State    = require("core.state")
local Menu     = require("core.menu_data")
local Settings = require("core.settings")
local Shortcuts = require("core.shortcuts")
local Launcher = require("core.launcher")
local Layout   = require("core.layout")

local M = {}

-------------------------------------------------------------------------------
-- Return the list of items visible at the current menu level.
-------------------------------------------------------------------------------
function M.activeItems()
  if State.currentMenuLevel == "MAIN" then
    local out = {}
    for _, cat in ipairs(Menu.categories) do
      table.insert(out, { name = cat.name })
    end
    return out
  end
  -- User shortcuts are merged in after the built-ins of their category.
  return Shortcuts.mergedItems(State.currentMenuLevel)
end

-------------------------------------------------------------------------------
-- Return the currently active (selected/hovered) 1-based index.
-- Mouse hover takes priority over keyboard selection when present.
-------------------------------------------------------------------------------
function M.activeIndex()
  if State.hoverIndex > 0 then return State.hoverIndex end
  if State.currentMenuLevel == "MAIN" then
    return State.selected
  else
    return State.subSelected
  end
end

-------------------------------------------------------------------------------
-- Perform the action for a given item at the current level.
-------------------------------------------------------------------------------
function M.activateItem(idx)
  local items = M.activeItems()
  local item = items[idx]
  if not item then return end

  -- MAIN level: enter the category.
  if State.currentMenuLevel == "MAIN" then
    local cat = Menu.categories[idx]
    if cat then
      State.currentMenuLevel = cat.id
      State.subSelected = 1
      State.selected = idx
      State.hoverIndex = 0
      State.selectionAnim = 1
    end
    return
  end

  -- Sub-menu: run the item's action.
  local action = item.action
  if action == "CYCLE_THEME" then
    Settings.cycleTheme(1)
  elseif action == "CYCLE_RES" then
    Settings.cycleResolution(1)
  elseif action == "TOGGLE_FS" then
    Settings.toggleFullscreen()
  elseif action == "CYCLE_WINMODE" then
    Settings.applyWindowMode(Settings.winModeIndex + 1)
  elseif action == "CYCLE_SCALE" then
    Settings.cycleScale(1)
  elseif action == "ADD_SHORTCUT" then
    -- Open the add-shortcut wizard (see core/wizard).
    local Wizard = require("core.wizard")
    Wizard.open()
  elseif action == "REMOVE_SHORTCUT" and item.shortcutId then
    -- Explicit remove affordance (e.g. X key on a user shortcut).
    Shortcuts.remove(item.shortcutId)
  else
    -- Launchable shortcut: url in browser, cmd as a detached process.
    Launcher.launch(item)
  end
end

-------------------------------------------------------------------------------
-- Go back one level (B / Escape / mouse B-badge). No-op at MAIN — the app can
-- only be quit via the title-bar X button.
-------------------------------------------------------------------------------
function M.goBack()
  if State.currentMenuLevel ~= "MAIN" then
    State.currentMenuLevel = "MAIN"
    State.hoverIndex = 0
    State.selectionAnim = State.selected
  end
end

-------------------------------------------------------------------------------
-- Keyboard navigation (up/down). Clears hover so keyboard takes over.
-------------------------------------------------------------------------------
-- Wrap-around navigation (Xbox-style): moving past either edge wraps to the
-- other side instead of clamping.
local function wrapIndex(idx, delta, count)
  return ((idx - 1 + delta) % count + 1)
end

function M.moveSelection(delta)
  local items = M.activeItems()
  local maxItems = #items
  if maxItems == 0 then return end
  State.hoverIndex = 0
  if State.currentMenuLevel == "MAIN" then
    State.selected = wrapIndex(State.selected, delta, maxItems)
  else
    State.subSelected = wrapIndex(State.subSelected, delta, maxItems)
  end
end

-------------------------------------------------------------------------------
-- Left/Right cycles the currently highlighted Settings option.
-------------------------------------------------------------------------------
function M.cycleSettingsOption(delta)
  if State.currentMenuLevel ~= "SETTINGS" then return end
  local items = M.activeItems()
  local idx = M.activeIndex()
  local item = items[idx]
  if not item or not item.action then return end

  if item.action == "CYCLE_THEME" then
    Settings.cycleTheme(delta)
  elseif item.action == "CYCLE_RES" then
    Settings.cycleResolution(delta)
  elseif item.action == "TOGGLE_FS" then
    Settings.toggleFullscreen()
  elseif item.action == "CYCLE_WINMODE" then
    Settings.applyWindowMode(Settings.winModeIndex + delta)
  elseif item.action == "CYCLE_SCALE" then
    Settings.cycleScale(delta)
  end
end

-------------------------------------------------------------------------------
-- Update hover index based on mouse position (called from love.mousemoved).
-------------------------------------------------------------------------------
function M.updateHover(mx, my)
  local items = M.activeItems()
  local count = #items
  local found = 0
  for i = 1, count do
    local ix, iy, iw, ih = Layout.menuItemRect(i, count)
    if mx >= ix and mx <= ix + iw and my >= iy and my <= iy + ih then
      found = i
      break
    end
  end
  State.hoverIndex = found
end

-------------------------------------------------------------------------------
-- Handle a click at (mx,my). Returns true if the click was consumed.
-- Priority: B-badge > A-badge > menu item under cursor.
-------------------------------------------------------------------------------
function M.handleClick(mx, my)
  local hints = Layout.hintButtons()
  if Layout.pointInCircle(mx, my, hints.back) then
    M.goBack()
    return true
  end
  if Layout.pointInCircle(mx, my, hints.select) then
    M.activateItem(M.activeIndex())
    return true
  end

  local items = M.activeItems()
  local count = #items
  for i = 1, count do
    local ix, iy, iw, ih = Layout.menuItemRect(i, count)
    if mx >= ix and mx <= ix + iw and my >= iy and my <= iy + ih then
      M.activateItem(i)
      return true
    end
  end
  return false
end

return M

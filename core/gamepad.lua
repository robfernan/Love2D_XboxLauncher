-- ============================================================================
-- GAMEPAD / CONTROLLER INPUT MODULE
-- Universal controller handler supporting standard Gamepad API (XInput,
-- DualShock/DualSense PlayStation, Nintendo Switch, generic USB controllers).
--
-- Automatically detects controller type and maps:
--   - D-Pad & Left Stick: Navigate menus & options
--   - Face Bottom (Xbox A / PS Cross): Select / Activate / Confirm
--   - Face Right  (Xbox B / PS Circle): Back / Cancel
--   - Face West   (Xbox X / PS Square): Remove/Edit Shortcut
--   - Bumpers (LB / RB, L1 / R1): Fast cycle categories / tabs
--   - Left / Right (D-Pad / Stick): Cycle Settings values
-- ============================================================================

local State     = require("core.state")
local Menu      = require("core.menu")
local Wizard    = require("core.wizard")
local MenuData  = require("core.menu_data")
local Shortcuts = require("core.shortcuts")

local M = {}

-- Controller type detection: "xbox", "playstation", "nintendo", "generic"
M.controllerType = "xbox"

-- Analog stick navigation debounce & deadzone
local STICK_DEADZONE = 0.5
local lastStickX = 0
local lastStickY = 0
local stickRepeatTimer = 0
local STICK_REPEAT_DELAY = 0.25

-------------------------------------------------------------------------------
-- Detect controller flavor from joystick name or OS hint
-------------------------------------------------------------------------------
function M.detectControllerType(joystick)
  if not joystick then
    M.controllerType = "xbox"
    return
  end

  local name = (joystick:getName() or ""):lower()
  if name:find("playstation") or name:find("ps4") or name:find("ps5") or name:find("dualshock") or name:find("dualsense") or name:find("wireless controller") then
    M.controllerType = "playstation"
  elseif name:find("nintendo") or name:find("switch") or name:find("pro controller") then
    M.controllerType = "nintendo"
  else
    M.controllerType = "xbox"
  end
end

-------------------------------------------------------------------------------
-- Cycle categories using Shoulder Bumpers (LB/RB or L1/R1)
-------------------------------------------------------------------------------
function M.cycleCategory(direction)
  if Wizard.isOpen() then return end

  local cats = MenuData.categories
  if #cats == 0 then return end

  local currentIdx = 1
  for i, c in ipairs(cats) do
    if c.id == State.currentMenuLevel then
      currentIdx = i
      break
    end
  end

  local nextIdx = ((currentIdx - 1 + direction) % #cats) + 1
  local targetCat = cats[nextIdx]
  if targetCat then
    require("core.audio").play("swoosh")
    State.currentMenuLevel = targetCat.id
    State.subSelected = 1
    State.hoverIndex = 0
    State.selectionAnim = 1
  end
end

-------------------------------------------------------------------------------
-- Gamepad button press handler (called from love.gamepadpressed)
-------------------------------------------------------------------------------
function M.gamepadpressed(joystick, button)
  M.detectControllerType(joystick)

  -- 1) Wizard has priority if open
  if Wizard.isOpen() then
    if button == "dpup" then
      Wizard.keypressed("up")
    elseif button == "dpdown" then
      Wizard.keypressed("down")
    elseif button == "dpleft" then
      Wizard.keypressed("left")
    elseif button == "dpright" then
      Wizard.keypressed("right")
    elseif button == "a" then
      -- If on Type or Category, A cycles it. If on text field, toggles editing.
      local field = Wizard.form and require("core.wizard").fieldIndex
      if field == 2 or field == 4 then
        Wizard.keypressed("right")
      else
        Wizard.keypressed("a")
      end
    elseif button == "b" then
      Wizard.keypressed("escape")
    elseif button == "start" or button == "x" then
      Wizard.confirm()
    end
    return
  end

  -- 2) Dashboard navigation
  if button == "dpdown" then
    Menu.moveSelection(1)
  elseif button == "dpup" then
    Menu.moveSelection(-1)
  elseif button == "dpleft" then
    if State.activeLayout == "XMB" or State.activeLayout == "BLADES" then
      M.cycleCategory(-1)
    elseif State.currentMenuLevel == "SETTINGS" then
      Menu.cycleSettingsOption(-1)
    else
      M.cycleCategory(-1)
    end
  elseif button == "dpright" then
    if State.activeLayout == "XMB" or State.activeLayout == "BLADES" then
      M.cycleCategory(1)
    elseif State.currentMenuLevel == "SETTINGS" then
      Menu.cycleSettingsOption(1)
    else
      M.cycleCategory(1)
    end
  -- Bumpers (LB / RB or L1 / R1) cycle top-level categories
  elseif button == "leftshoulder" then
    M.cycleCategory(-1)
  elseif button == "rightshoulder" then
    M.cycleCategory(1)
  -- A (Cross on PlayStation) = Select / Confirm
  elseif button == "a" then
    Menu.activateItem(Menu.activeIndex())
  -- B (Circle on PlayStation) = Back
  elseif button == "b" then
    Menu.goBack()
  -- X (Square on PlayStation) = Delete/Action on custom shortcut
  elseif button == "x" then
    local items = Menu.activeItems()
    local idx = Menu.activeIndex()
    local item = items and items[idx]
    if item and item.shortcutId then
      Shortcuts.remove(item.shortcutId)
    end
  -- Y (Triangle on PlayStation) = Edit custom shortcut
  elseif button == "y" then
    local items = Menu.activeItems()
    local idx = Menu.activeIndex()
    local item = items and items[idx]
    if item and item.shortcutId then
      local allShortcuts = Shortcuts.all()
      for _, s in ipairs(allShortcuts) do
        if s.id == item.shortcutId then
          Wizard.openForEdit(s)
          break
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Analog stick handling (called from love.update(dt))
-------------------------------------------------------------------------------
function M.update(dt)
  local joysticks = love.joystick.getJoysticks()
  if #joysticks == 0 then return end

  local joy = joysticks[1]
  if not joy:isGamepad() then return end

  M.detectControllerType(joy)

  local axisX = joy:getGamepadAxis("leftx") or 0
  local axisY = joy:getGamepadAxis("lefty") or 0

  -- Threshold check
  local moveX = 0
  local moveY = 0

  if math.abs(axisX) > STICK_DEADZONE then
    moveX = (axisX > 0) and 1 or -1
  end
  if math.abs(axisY) > STICK_DEADZONE then
    moveY = (axisY > 0) and 1 or -1
  end

  -- Handle stick repeat
  if moveX ~= 0 or moveY ~= 0 then
    stickRepeatTimer = stickRepeatTimer - dt
    if (moveX ~= lastStickX or moveY ~= lastStickY) or stickRepeatTimer <= 0 then
      if moveY ~= 0 then
        if Wizard.isOpen() then
          Wizard.keypressed(moveY > 0 and "down" or "up")
        else
          Menu.moveSelection(moveY)
        end
      end

      if moveX ~= 0 then
        if Wizard.isOpen() then
          Wizard.keypressed(moveX > 0 and "right" or "left")
        elseif State.currentMenuLevel == "SETTINGS" then
          Menu.cycleSettingsOption(moveX)
        else
          M.cycleCategory(moveX)
        end
      end

      stickRepeatTimer = STICK_REPEAT_DELAY
    end
  else
    stickRepeatTimer = 0
  end

  lastStickX = moveX
  lastStickY = moveY
end

-------------------------------------------------------------------------------
-- Get button labels and colors based on controller type
-------------------------------------------------------------------------------
function M.getPromptIcons()
  if M.controllerType == "playstation" then
    return {
      confirm = { label = "✕", name = "Cross",  color = {0.2, 0.6, 1.0} },
      cancel  = { label = "◯", name = "Circle", color = {1.0, 0.25, 0.25} },
      action  = { label = "□", name = "Square", color = {0.9, 0.4, 0.8} },
      bumpers = "L1 / R1",
    }
  else
    -- Xbox / Nintendo / Default
    return {
      confirm = { label = "A", name = "A", color = {0.18, 0.85, 0.35} },
      cancel  = { label = "B", name = "B", color = {1.0, 0.2, 0.2} },
      action  = { label = "X", name = "X", color = {0.2, 0.55, 1.0} },
      bumpers = "LB / RB",
    }
  end
end

return M

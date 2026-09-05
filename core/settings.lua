-- ============================================================================
-- SETTINGS ACTIONS
-- Resolution presets, window modes, UI scale presets, and the live-apply +
-- persist logic for each. Settings menu items call these; labels are kept in
-- sync so the user always sees the current value.
-- ============================================================================

local Config = require("core.config")
local State  = require("core.state")
local Menu   = require("core.menu_data")

local M = {}

-- Resolution presets (cycled by Settings > Resolution).
M.resPresets = {
  { w = 1280, h = 720 },
  { w = 1600, h = 900 },
  { w = 1920, h = 1080 },
  { w = 2560, h = 1440 },
}
M.resIndex = 1

-- Window mode cycle: borderless -> windowed(resizable) -> fullscreen(desktop).
M.winModes = {
  { name = "Borderless", borderless = true,  resizable = false, fullscreen = false },
  { name = "Windowed",   borderless = false, resizable = true,  fullscreen = false },
  { name = "Fullscreen", borderless = true,  resizable = false, fullscreen = true  },
}
M.winModeIndex = 1

-- UI scale presets (cycled by Settings > UI Scale).
M.scalePresets = { 0.75, 1.0, 1.25, 1.5 }
M.scaleIndex = 2

-------------------------------------------------------------------------------
-- Internal helper: update a single Settings item's label in menu_data.
-------------------------------------------------------------------------------
local function setSettingsLabel(action, newName)
  local cat = Menu.findCategory("SETTINGS")
  if not cat or not cat.items then return end
  for _, it in ipairs(cat.items) do
    if it.action == action then
      it.name = newName
      break
    end
  end
end

-------------------------------------------------------------------------------
-- Public actions
-------------------------------------------------------------------------------

function M.cycleTheme(delta)
  local Themes = require("core.themes")
  State.activeTheme = ((State.activeTheme - 1 + delta) % Themes.count() + 1)
  Config.set("theme.index", State.activeTheme)
  setSettingsLabel("CYCLE_THEME", "Theme: " .. Themes.current().name)
end

function M.applyWindowMode(idx)
  M.winModeIndex = ((idx - 1) % #M.winModes + 1)
  local m = M.winModes[M.winModeIndex]
  Config.set("window.borderless", m.borderless)
  Config.set("window.resizable", m.resizable)
  Config.set("window.fullscreen", m.fullscreen)
  love.window.setMode(
    Config.get("window.width") or 1280,
    Config.get("window.height") or 720,
    { borderless = m.borderless, resizable = m.resizable, fullscreen = m.fullscreen, vsync = true }
  )
  setSettingsLabel("CYCLE_WINMODE", "Window: " .. m.name)
end

function M.cycleResolution(delta)
  M.resIndex = ((M.resIndex - 1 + delta) % #M.resPresets + 1)
  local p = M.resPresets[M.resIndex]
  Config.set("window.width", p.w)
  Config.set("window.height", p.h)
  M.applyWindowMode(M.winModeIndex)   -- re-apply current mode at new size
  setSettingsLabel("CYCLE_RES", string.format("Resolution: %dx%d", p.w, p.h))
end

function M.toggleFullscreen()
  local isFs = Config.get("window.fullscreen")
  if type(isFs) ~= "boolean" then isFs = false end
  M.applyWindowMode(isFs and 1 or 3)   -- off -> Borderless(1), on -> Fullscreen(3)
  local nowOn = (Config.get("window.fullscreen") == true)
  setSettingsLabel("TOGGLE_FS", nowOn and "Fullscreen: On" or "Fullscreen: Off")
end

function M.cycleScale(delta)
  M.scaleIndex = ((M.scaleIndex - 1 + delta) % #M.scalePresets + 1)
  local s = M.scalePresets[M.scaleIndex]
  Config.set("uiScale", s)
  setSettingsLabel("CYCLE_SCALE", string.format("UI Scale: %d%%", math.floor(s * 100)))
end

-- Sync internal indices to saved config values (called once in love.load).
function M.syncFromConfig()
  -- Restore the active theme from config so it persists across restarts.
  local Themes = require("core.themes")
  local savedTheme = Config.get("theme.index")
  if type(savedTheme) == "number" and savedTheme >= 1 and savedTheme <= Themes.count() then
    State.activeTheme = savedTheme
  end

  local winW = Config.get("window.width") or 1280
  local winH = Config.get("window.height") or 720
  for i, p in ipairs(M.resPresets) do
    if p.w == winW and p.h == winH then M.resIndex = i break end
  end

  local borderless = Config.get("window.borderless")
  local fullscreen = Config.get("window.fullscreen")
  if type(borderless) ~= "boolean" then borderless = true end
  if type(fullscreen) ~= "boolean" then fullscreen = false end
  if fullscreen then
    M.winModeIndex = 3
  elseif borderless then
    M.winModeIndex = 1
  else
    M.winModeIndex = 2
  end

  local savedScale = Config.get("uiScale")
  if type(savedScale) == "number" then
    for i, s in ipairs(M.scalePresets) do
      if math.abs(s - savedScale) < 0.01 then M.scaleIndex = i break end
    end
  end

  -- Refresh all Settings labels to reflect the loaded values.
  local Themes = require("core.themes")
  setSettingsLabel("CYCLE_THEME", "Theme: " .. Themes.current().name)
  local p = M.resPresets[M.resIndex]
  if p then setSettingsLabel("CYCLE_RES", string.format("Resolution: %dx%d", p.w, p.h)) end
  setSettingsLabel("TOGGLE_FS", (Config.get("window.fullscreen") == true) and "Fullscreen: On" or "Fullscreen: Off")
  local m = M.winModes[M.winModeIndex]
  if m then setSettingsLabel("CYCLE_WINMODE", "Window: " .. m.name) end
  local s = M.scalePresets[M.scaleIndex]
  if s then setSettingsLabel("CYCLE_SCALE", string.format("UI Scale: %d%%", math.floor(s * 100))) end
end

return M


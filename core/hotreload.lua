-- ============================================================================
-- LIVE HOT RELOADER (Development Utility)
-- Automatically watches all Lua scripts and GLSL shaders on disk. When any
-- file is modified and saved, it safely recompiles and hot-reloads the module
-- or shader in-place without restarting the application or losing runtime state.
--
-- Features:
--   - Auto-checks file modification timestamps (love.filesystem.getInfo)
--   - Hot-reloads core modules in package.loaded
--   - Hot-recompiles GLSL shaders live on file edit
--   - Manual reload trigger: Press F5 anytime
-- ============================================================================

local State = require("core.state")

local M = {}

M.enabled = true
M.lastCheck = 0
M.CHECK_INTERVAL = 0.5 -- Check every 500ms

-- Table mapping filepath -> last modified timestamp
local fileTimestamps = {}

-- Trackable source files
local WATCH_FILES = {
  "main.lua",
  "conf.lua",
  "core/state.lua",
  "core/config.lua",
  "core/themes.lua",
  "core/menu_data.lua",
  "core/shortcuts.lua",
  "core/launcher.lua",
  "core/wizard.lua",
  "core/layout.lua",
  "core/render.lua",
  "core/gamepad.lua",
  "core/audio.lua",
  "core/settings.lua",
  "shaders/blur.glsl",
}

-------------------------------------------------------------------------------
-- Scan files and initialize timestamps
-------------------------------------------------------------------------------
function M.init()
  for _, file in ipairs(WATCH_FILES) do
    local info = love.filesystem.getInfo(file)
    if info and info.modtime then
      fileTimestamps[file] = info.modtime
    end
  end
end

-------------------------------------------------------------------------------
-- Reload a specific Lua module safely using pcall
-------------------------------------------------------------------------------
local function reloadModule(modName)
  package.loaded[modName] = nil
  local ok, res = pcall(require, modName)
  if ok then
    print("[HOT RELOAD] Successfully reloaded module: " .. modName)
  else
    print("[HOT RELOAD ERROR] Failed to reload " .. modName .. ": " .. tostring(res))
  end
end

-------------------------------------------------------------------------------
-- Reload GLSL shader live
-------------------------------------------------------------------------------
local function reloadShader()
  local ok, src = pcall(function() return love.filesystem.read("shaders/blur.glsl") end)
  if ok and type(src) == "string" then
    local shaderOk, newShader = pcall(love.graphics.newShader, src)
    if shaderOk and newShader then
      State.blurShader = newShader
      print("[HOT RELOAD] Successfully recompiled shaders/blur.glsl")
    else
      print("[HOT RELOAD SHADER ERROR] Shader compile failed: " .. tostring(newShader))
    end
  end
end

-------------------------------------------------------------------------------
-- Reload all active core modules and shaders
-------------------------------------------------------------------------------
function M.reloadAll()
  print("[HOT RELOAD] Reloading all modules...")
  local modules = {
    "core.themes",
    "core.layout",
    "core.menu_data",
    "core.shortcuts",
    "core.launcher",
    "core.settings",
    "core.menu",
    "core.gamepad",
    "core.audio",
    "core.wizard",
    "core.render",
  }

  for _, mod in ipairs(modules) do
    reloadModule(mod)
  end

  reloadShader()
end

-------------------------------------------------------------------------------
-- Check watched files every frame (called from love.update)
-------------------------------------------------------------------------------
function M.update(dt)
  if not M.enabled then return end

  M.lastCheck = M.lastCheck + dt
  if M.lastCheck < M.CHECK_INTERVAL then return end
  M.lastCheck = 0

  for _, file in ipairs(WATCH_FILES) do
    local info = love.filesystem.getInfo(file)
    if info and info.modtime then
      local prev = fileTimestamps[file]
      if prev and info.modtime > prev then
        fileTimestamps[file] = info.modtime
        print("[HOT RELOAD] Detected file change: " .. file)

        if file:match("%.glsl$") then
          reloadShader()
        else
          -- Map file to module name
          local modName = file:gsub("%.lua$", ""):gsub("/", ".")
          if modName == "main" or modName == "conf" then
            M.reloadAll()
          else
            reloadModule(modName)
            -- If layout changed, also reload render so scale & geometry sync
            if modName == "core.layout" then
              reloadModule("core.render")
            end
          end
        end
      elseif not prev then
        fileTimestamps[file] = info.modtime
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Keypress handler for manual reload (F5)
-------------------------------------------------------------------------------
function M.keypressed(key)
  if key == "f5" or (key == "r" and love.keyboard.isDown("lctrl", "rctrl")) then
    M.reloadAll()
    return true
  end
  return false
end

return M

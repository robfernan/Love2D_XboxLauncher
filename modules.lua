-- ============================================================================
-- LÖVE MODULE SYSTEM (optional)
-- A minimal, robust module loader so we can split the project into files.
-- Supports both `require("core.config")` and `require "core/config"` styles,
-- and caches loaded modules.
--
-- IMPORTANT: This file is OPTIONAL. LÖVE 11+ already provides a working
-- `require` that resolves dotted names to .lua files in the project's virtual
-- filesystem (and honors love.filesystem.addPath). You only need this loader
-- if you want custom resolution rules or are on an older LÖVE build.
--
-- To activate, call from main.lua BEFORE requiring any module:
--   dofile("modules.lua")
-- Do NOT `require` this file — it is a bootstrap script, not a module.
-- ============================================================================

local modules = {}

local function findFile(name)
  -- Normalize dotted and slashed names to a slash path.
  local path = name:gsub("%.", "/"):gsub("\\", "/")
  local candidate = path .. ".lua"
  if love.filesystem.exists(candidate) then
    return candidate
  end
  local initPath = path .. "/init.lua"
  if love.filesystem.exists(initPath) then
    return initPath
  end
  return nil
}

-- Replace the global require with a LÖVE-virtual-FS-aware version.
local originalRequire = _G.require
_G.require = function(name)
  -- Already loaded? Return cached.
  if modules[name] ~= nil then
    return modules[name]
  end

  local file = findFile(name)
  if not file then
    -- Fall back to the native require (handles builtins like "love").
    if originalRequire and type(originalRequire) == "function" then
      local ok, result = pcall(originalRequire, name)
      if ok then return result end
    end
    error("Module not found: " .. tostring(name), 2)
  end

  -- Load the chunk from LÖVE's virtual filesystem (NOT loadfile, which reads
  -- the OS path and breaks for .love archives / added paths).
  local source = love.filesystem.read(file)
  if not source then
    error("Failed to read module " .. name .. ": file is empty or unreadable", 2)
  end

  local chunk, compileErr = load(source, "@" .. file)
  if not chunk then
    error("Failed to compile module " .. name .. ": " .. tostring(compileErr), 2)
  end

  -- Execute. If the file returns a table, cache that; otherwise cache an empty
  -- module table (so side-effect-only modules still register as loaded).
  local results = { chunk() }
  if type(results[1]) == "table" then
    modules[name] = results[1]
    return results[1]
  end

  local mod = {}
  modules[name] = mod
  return mod
end

return {
  reset = function()
    for k in pairs(modules) do modules[k] = nil end
  end,
  loaded = function()
    return modules
  end,
}

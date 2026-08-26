-- ============================================================================
-- CONFIG SYSTEM
-- Loads and saves persistent user settings to userdata/config.json.
-- All access is defensive: a missing or corrupt config file falls back to
-- sane defaults, so the launcher always boots.
--
-- Usage (from main.lua):
--   local Config = require("core.config")
--   Config.load()                       -- call once in love.load()
--   Config.get("theme.index")           -> 4
--   Config.set("theme.index", 2)        -- marks dirty; saved on save()/quit
--   Config.save()                       -- force write to disk
-- ============================================================================

local json = require("core.json")

local M = {}

-- Defaults: the single source of truth for every setting.
local DEFAULTS = {
  theme = { index = 4 },                 -- active color theme (1..N)
  uiScale = 1.0,                         -- global UI scale factor (0.75 .. 2.0)
  window = {
    width = 1280,
    height = 720,
    borderless = true,
    resizable = false,
    fullscreen = false,                  -- "desktop" fullscreen when true
    x = nil,                             -- remembered window position (optional)
    y = nil,
  },
}

local data = {}
local dirty = false
local configPath = "config.json"   -- relative to save directory

-------------------------------------------------------------------------------
-- Deep-merge a source table onto a destination table. Source wins on conflict;
-- used so partial user configs still get every default key present.
-------------------------------------------------------------------------------
local function deepMerge(dest, src)
  for k, v in pairs(src or {}) do
    if type(v) == "table" and type(dest[k]) == "table" then
      deepMerge(dest[k], v)
    else
      dest[k] = v
    end
  end
end

-------------------------------------------------------------------------------
-- Split a dotted path like "theme.index" into its segments.
-------------------------------------------------------------------------------
local function splitPath(path)
  local parts = {}
  for part in string.gmatch(tostring(path), "[^%.]+") do
    table.insert(parts, part)
  end
  return parts
end

-------------------------------------------------------------------------------
-- Walk to the parent node of a dotted path, creating intermediate tables when
-- `create` is true. Returns (parentTable, lastKey).
-------------------------------------------------------------------------------
local function walkToParent(path, create)
  local parts = splitPath(path)
  if #parts == 0 then return nil, nil end

  local node = data
  for i = 1, #parts - 1 do
    if type(node[parts[i]]) ~= "table" then
      if not create then return nil, nil end
      node[parts[i]] = {}
    end
    node = node[parts[i]]
  end
  return node, parts[#parts]
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.load()
  data = {}
  deepMerge(data, DEFAULTS)   -- start from full defaults

  -- Use getInfo (LÖVE 12+) with an exists fallback for LÖVE 11.
  local function fileExists(p)
    if love.filesystem.getInfo then
      return love.filesystem.getInfo(p) ~= nil
    elseif love.filesystem.exists then
      return love.filesystem.exists(p)
    end
    return false
  end

  local ok, text = pcall(function()
    if fileExists(configPath) then
      return love.filesystem.read(configPath)
    end
    return nil
  end)

  if ok and type(text) == "string" and #text > 0 then
    local decoded = json.decode(text)
    if type(decoded) == "table" then
      deepMerge(data, decoded)   -- user values override defaults
    else
      print("[config] config.json present but invalid; using defaults.")
    end
  end

  dirty = false
  return data
end

function M.get(path)
  local parent, key = walkToParent(path, false)
  if not parent then return nil end
  return parent[key]
end

function M.set(path, value)
  local parent, key = walkToParent(path, true)
  if not parent or not key then return end
  parent[key] = value
  dirty = true
end

function M.save()
  if not dirty then return true end
  local ok, err = pcall(function()
    love.filesystem.write(configPath, json.encode(data))
  end)
  if ok then
    dirty = false
    return true
  end
  print("[config] failed to save config.json: " .. tostring(err))
  return false
end

function M.isDirty()
  return dirty
end

-- Reset a single setting back to its default value.
function M.reset(path)
  local parts = splitPath(path)
  if #parts == 0 then return end
  local node = DEFAULTS
  for i = 1, #parts - 1 do
    if type(node[parts[i]]) ~= "table" then return end
    node = node[parts[i]]
  end
  M.set(path, node[parts[#parts]])
end

return M

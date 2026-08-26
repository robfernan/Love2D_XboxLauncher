-- ============================================================================
-- SHORTCUT MANAGER
-- The "package manager" half of the launcher. Lets the user add their own
-- shortcuts (local apps or websites) into any category, remove them, and
-- reorder them — all persisted to config.json under `shortcuts`.
--
-- Data model (config path "shortcuts"): an array of:
--   { id = <n>, name = "...", category = "GAMES"|"BROWSE"|"MEDIA"|...,
--     url  = "https://..." , cmd = "C:\\Games\\game.exe", icon = "icons/x.png" }
-- (url and cmd are mutually exclusive; exactly one is set per shortcut.)
--
-- Built-in items live in core/menu_data. User shortcuts are appended after the
-- built-ins of their category, so navigation order is: built-ins first, then
-- whatever the user added. Removal only ever touches user shortcuts — the
-- built-in tree stays pristine.
-- ============================================================================

local Config = require("core.config")
local Menu   = require("core.menu_data")

local M = {}

-- Categories that accept user shortcuts (SETTINGS is reserved for app options).
M.CATEGORY_IDS = { "GAMES", "BROWSE", "MEDIA" }

-------------------------------------------------------------------------------
-- Persistence helpers. Config stores the array under a single key so we can
-- read/replace it atomically without touching other settings.
-------------------------------------------------------------------------------

local function loadList()
  local list = Config.get("shortcuts")
  if type(list) ~= "table" then return {} end
  -- Defensive: keep only well-formed entries.
  local out = {}
  for _, s in ipairs(list) do
    if type(s) == "table" and type(s.name) == "string" and #s.name > 0
       and type(s.category) == "string" then
      table.insert(out, {
        id       = (type(s.id) == "number") and s.id or (#out + 1),
        name     = s.name,
        category = s.category,
        url      = (type(s.url) == "string") and s.url or nil,
        cmd      = (type(s.cmd) == "string" and #s.cmd > 0) and s.cmd or nil,
        icon     = (type(s.icon) == "string") and s.icon or nil,
      })
    end
  end
  return out
end

local function saveList(list)
  Config.set("shortcuts", list)
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- All user shortcuts (fresh copy from config).
function M.all()
  return loadList()
end

-- User shortcuts for one category, in stored order.
function M.forCategory(catId)
  local out = {}
  for _, s in ipairs(loadList()) do
    if s.category == catId then table.insert(out, s) end
  end
  return out
end

-- True if a user shortcut with this id exists.
function M.exists(id)
  for _, s in ipairs(loadList()) do
    if s.id == id then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- Add a new shortcut. `spec` = { name, category, url?, cmd?, icon? }.
-- Returns the created shortcut table (with assigned id) or nil on bad input.
-------------------------------------------------------------------------------
function M.add(spec)
  if type(spec) ~= "table" then return nil end
  local name = spec.name
  if type(name) ~= "string" then name = tostring(name) end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")   -- trim
  if #name == 0 then return nil end

  local category = spec.category
  if type(category) ~= "string" or not Menu.findCategory(category) then
    return nil
  end

  local url, cmd = nil, nil
  if type(spec.url) == "string" and #spec.url > 0 then
    url = spec.url
  elseif type(spec.cmd) == "string" and #spec.cmd > 0 then
    cmd = spec.cmd
  else
    return nil   -- need at least one of url / cmd
  end

  local list = loadList()
  local newId = 1
  for _, s in ipairs(list) do
    if (s.id or 0) >= newId then newId = (s.id or 0) + 1 end
  end

  local entry = {
    id       = newId,
    name     = name,
    category = category,
    url      = url,
    cmd      = cmd,
    icon     = (type(spec.icon) == "string" and #spec.icon > 0) and spec.icon or nil,
  }
  table.insert(list, entry)
  saveList(list)
  return entry
end

-------------------------------------------------------------------------------
-- Remove a shortcut by id. Returns true if something was removed.
-------------------------------------------------------------------------------
function M.remove(id)
  local list = loadList()
  for i = #list, 1, -1 do
    if list[i].id == id then
      table.remove(list, i)
      saveList(list)
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------
-- Move a shortcut up/down within its category. `delta` = +1 (down) / -1 (up).
-- Returns the new position (1-based within the category) or nil if no-op.
-------------------------------------------------------------------------------
function M.move(id, delta)
  local list = loadList()

  -- Find the entry and its index in the full list.
  local idx, target = nil, nil
  for i, s in ipairs(list) do
    if s.id == id then idx, target = i, s break end
  end
  if not idx then return nil end

  -- Walk to the neighbor in the same category in the requested direction.
  local j = idx + delta
  while j >= 1 and j <= #list do
    if list[j].category == target.category then
      table.remove(list, idx)
      table.insert(list, j > idx and (j - 1) or j, target)
      saveList(list)
      -- Report new position within the category.
      local pos = 0
      for _, s in ipairs(loadList()) do
        if s.category == target.category then
          pos = pos + 1
          if s.id == id then return pos end
        end
      end
      return nil
    end
    j = j + delta
  end
  return nil   -- already at the edge of its category
end

-------------------------------------------------------------------------------
-- Merge user shortcuts into a category's item list (built-ins first, then
-- user entries). Returns a NEW array; does not mutate menu_data.
-------------------------------------------------------------------------------
function M.mergedItems(catId)
  local cat = Menu.findCategory(catId)
  local out = {}
  if cat and cat.items then
    for _, it in ipairs(cat.items) do table.insert(out, it) end
  end
  for _, s in ipairs(M.forCategory(catId)) do
    table.insert(out, { name = s.name, url = s.url, cmd = s.cmd, icon = s.icon, shortcutId = s.id })
  end
  return out
end

return M

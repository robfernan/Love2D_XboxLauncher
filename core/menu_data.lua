-- ============================================================================
-- MENU DATA
-- The built-in category/item tree. Loaded from `userdata/categories.json` so
-- users can add or edit categories and items without touching Lua. If the
-- file is missing, corrupt, or empty we fall back to a shipped default set
-- (GAMES / BROWSE / MEDIA / SETTINGS) that mirrors what the launcher has
-- always shown — the app always boots with at least one usable category.
--
-- Each item may have:
--   name    — display label (Settings items carry live-updated names)
--   url     — opened via love.system.openURL when activated
--   cmd     — local program path, launched detached (see core/launcher)
--   action  — one of CYCLE_THEME / CYCLE_RES / TOGGLE_FS / CYCLE_WINMODE /
--             CYCLE_SCALE / ADD_SHORTCUT / REMOVE_SHORTCUT
--   icon    — optional path to a PNG in icons/ (loaded into State.iconCache)
-- ============================================================================

local json = require("core.json")

local M = {}

-------------------------------------------------------------------------------
-- Built-in fallback categories. Used when userdata/categories.json is absent,
-- empty, or malformed so the launcher always has something to show.
-------------------------------------------------------------------------------
local FALLBACK_CATEGORIES = {
  { name = "GAMES", id = "GAMES", items = {
    { name = "Steam",      url = "https://store.steampowered.com", icon = "icons/steam_icon.png" },
    { name = "Epic Games", url = "https://epicgames.com",          icon = "icons/epicgames_icon.png" },
    { name = "Itch.io",    url = "https://itch.io",                icon = "icons/itchio_icon.png" },
    { name = "GOG",        url = "https://gog.com",                icon = "icons/gog_icon.png" },
  }},
  { name = "BROWSE", id = "BROWSE", items = {
    { name = "GitHub",     url = "https://github.com",             icon = "icons/github_icon.png" },
    { name = "YouTube",    url = "https://youtube.com",            icon = "icons/youtube_icon.png" },
    { name = "Pinterest",  url = "https://pinterest.com",          icon = "icons/pinterest_icon.png" },
  }},
  { name = "MEDIA", id = "MEDIA", items = {
    { name = "Netflix",     url = "https://netflix.com",           icon = "icons/netflix_icon.png" },
    { name = "Spotify",     url = "https://spotify.com",           icon = "icons/spotify_icon.png" },
    { name = "Twitch",      url = "https://twitch.tv",             icon = "icons/twitch_icon.png" },
    { name = "Crunchyroll", url = "https://crunchyroll.com",       icon = "icons/crunchyroll_icon.png" },
  }},
  { name = "SETTINGS", id = "SETTINGS", items = {
    { name = "Layout: Xbox Original",action = "CYCLE_LAYOUT",  icon = "icons/theme_icon.png" },
    { name = "Theme: Purple",        action = "CYCLE_THEME",   icon = "icons/theme_icon.png" },
    { name = "Resolution: 1280x720", action = "CYCLE_RES",     icon = "icons/settings_icon.png" },
    { name = "Window: Borderless",   action = "CYCLE_WINMODE", icon = "icons/internet_icon.png" },
    { name = "UI Scale: 100%",       action = "CYCLE_SCALE",   icon = "icons/tool_icon.png" },
    { name = "+ Add Shortcut...",    action = "ADD_SHORTCUT",  icon = "icons/profile_icon.png" },
  }},
}

-------------------------------------------------------------------------------
-- Sanitize a single item from JSON. Returns the cleaned table or nil if it is
-- not usable (missing name, no url/cmd/action).
-------------------------------------------------------------------------------
local function sanitizeItem(t)
  if type(t) ~= "table" then return nil end
  local name = t.name
  if type(name) ~= "string" or #name == 0 then return nil end

  local out = { name = name }

  -- url / cmd are optional but at least one of them (or an action) must exist.
  if type(t.url) == "string" and #t.url > 0 then out.url = t.url end
  if type(t.cmd) == "string" and #t.cmd > 0 then out.cmd = t.cmd end
  if type(t.action) == "string" and #t.action > 0 then out.action = t.action end
  if type(t.icon) == "string" and #t.icon > 0 then out.icon = t.icon end

  -- A category item with no way to be activated is useless — drop it.
  if not out.url and not out.cmd and not out.action then return nil end
  return out
end

-------------------------------------------------------------------------------
-- Sanitize a single category from JSON. Returns the cleaned table or nil.
-- `id` defaults to upper-cased name so users can omit it in their own files.
-------------------------------------------------------------------------------
local function sanitizeCategory(t)
  if type(t) ~= "table" then return nil end
  local name = t.name
  if type(name) ~= "string" or #name == 0 then return nil end

  local id = t.id
  if type(id) ~= "string" or #id == 0 then
    id = name:upper():gsub("%s+", "_")
  end

  local out = { name = name, id = id }

  -- Items are optional — a category with no items is still valid (e.g. an
  -- empty user-created category the wizard just made).
  if type(t.items) == "table" then
    local cleanItems = {}
    for _, it in ipairs(t.items) do
      local c = sanitizeItem(it)
      if c then table.insert(cleanItems, c) end
    end
    out.items = cleanItems
  else
    out.items = {}
  end

  return out
end

-------------------------------------------------------------------------------
-- Load categories from userdata/categories.json (relative to the save dir).
-- Falls back to FALLBACK_CATEGORIES on any failure. Returns the loaded list.
-------------------------------------------------------------------------------
local function loadCategories()
  local ok, text = pcall(function()
    if love.filesystem.getInfo then
      if love.filesystem.getInfo("categories.json") == nil then return nil end
    elseif love.filesystem.exists then
      if not love.filesystem.exists("categories.json") then return nil end
    end
    return love.filesystem.read("categories.json")
  end)

  local out = {}
  if ok and type(text) == "string" and #text > 0 then
    local decOk, decoded = pcall(json.decode, text)
    if decOk and type(decoded) == "table" then
      -- Accept either { categories = [...] } or a bare array.
      local raw = nil
      if type(decoded.categories) == "table" then
        raw = decoded.categories
      elseif #decoded > 0 then
        raw = decoded
      end
      if type(raw) == "table" then
        for _, c in ipairs(raw) do
          local clean = sanitizeCategory(c)
          if clean then table.insert(out, clean) end
        end
      end
    else
      print("[menu_data] categories.json present but invalid; using built-in defaults.")
    end
  end

  -- Fall back to the shipped defaults if we ended up with nothing usable.
  if #out == 0 then
    for _, c in ipairs(FALLBACK_CATEGORIES) do table.insert(out, c) end
  end

  return out
end

-- Load once at require time so every module that touches MenuData sees a stable
-- list. If the user edits categories.json they can call M.reload() to pick it
-- up (the first-run wizard does this after writing its own file).
M.categories = loadCategories()

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Find a category by id. Returns the category table or nil.
function M.findCategory(id)
  for _, cat in ipairs(M.categories) do
    if cat.id == id then return cat end
  end
  return nil
end

-- Re-read categories.json from disk and replace M.categories. Returns the new
-- list (always non-empty). Call this after writing a fresh file so the running
-- app reflects the change without a restart.
function M.reload()
  local fresh = loadCategories()
  M.categories = fresh
  return fresh
end

return M

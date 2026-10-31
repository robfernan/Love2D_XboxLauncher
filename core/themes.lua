-- ============================================================================
-- COLOR THEMES
-- Theme profiles are loaded from `userdata/themes.json` so users can add or
-- edit color schemes without touching Lua. If the file is missing, corrupt,
-- or empty we fall back to a built-in preset list (Neon Green / Cyber Blue /
-- Neon Red / Neon Purple) that ships with the project — the launcher always
-- boots with at least one usable theme.
--
-- Each theme defines:
--   name  — display label used in Settings and the wizard
--   color — primary accent (menu buttons, connector line)
--   bg    — background clear color
--   glow  — glow / highlight / selection orb color
-- ============================================================================

local State = require("core.state")
local json  = require("core.json")

local M = {}

-------------------------------------------------------------------------------
-- Built-in fallback presets. Used when userdata/themes.json is absent, empty,
-- or malformed so the app never boots with zero themes.
-------------------------------------------------------------------------------
local FALLBACK_THEMES = {
  { name = "Neon Green",  color = {0.18, 1.00, 0.38}, bg = {0.02, 0.05, 0.03}, glow = {0.20, 1.00, 0.45} },
  { name = "Cyber Blue",  color = {0.18, 0.75, 1.00}, bg = {0.01, 0.03, 0.06}, glow = {0.25, 0.85, 1.00} },
  { name = "Neon Red",    color = {1.00, 0.25, 0.25}, bg = {0.06, 0.01, 0.01}, glow = {1.00, 0.30, 0.30} },
  { name = "Neon Purple", color = {0.95, 0.20, 1.00}, bg = {0.04, 0.00, 0.05}, glow = {1.00, 0.35, 1.00} },
}

-------------------------------------------------------------------------------
-- Validate a single theme entry from JSON. Returns the sanitized table or nil.
-- We require name + color; bg and glow default to sensible values if missing.
-------------------------------------------------------------------------------
local function sanitizeTheme(t)
  if type(t) ~= "table" then return nil end
  local name = t.name
  if type(name) ~= "string" or #name == 0 then return nil end

  local function rgb(v, fallback)
    if type(v) ~= "table" then return { fallback[1], fallback[2], fallback[3] } end
    local r, g, b = v[1], v[2], v[3]
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
      return { fallback[1], fallback[2], fallback[3] }
    end
    -- Clamp to 0..1 so a bad JSON value can't blow out the renderer.
    local function clamp(x) if x < 0 then return 0 elseif x > 1 then return 1 else return x end end
    return { clamp(r), clamp(g), clamp(b) }
  end

  local color = rgb(t.color, { 0.5, 0.5, 1.0 })
  local bg    = rgb(t.bg,    { 0.02, 0.02, 0.04 })
  local glow  = rgb(t.glow,  color)

  return { name = name, color = color, bg = bg, glow = glow }
end

-------------------------------------------------------------------------------
-- Load themes from userdata/themes.json (relative to the save directory).
-- Falls back to FALLBACK_THEMES on any failure. Returns the loaded list so
-- callers can inspect it if they want.
-------------------------------------------------------------------------------
local function loadThemes()
  local out = {}
  local ok, text = pcall(function()
    -- LÖVE 12+ has getInfo; LÖVE 11 uses exists.
    if love.filesystem.getInfo then
      if love.filesystem.getInfo("themes.json") == nil then return nil end
    elseif love.filesystem.exists then
      if not love.filesystem.exists("themes.json") then return nil end
    else
      -- No existence check available — just try to read.
    end
    return love.filesystem.read("themes.json")
  end)

  if ok and type(text) == "string" and #text > 0 then
    local decOk, decoded = pcall(json.decode, text)
    if decOk and type(decoded) == "table" then
      -- Accept either { themes = [...] } or a bare array.
      local raw = nil
      if type(decoded.themes) == "table" then
        raw = decoded.themes
      elseif #decoded > 0 then
        raw = decoded
      end
      if type(raw) == "table" then
        for _, t in ipairs(raw) do
          local clean = sanitizeTheme(t)
          if clean then table.insert(out, clean) end
        end
      end
    else
      print("[themes] themes.json present but invalid; using built-in presets.")
    end
  end

  -- Fall back to the shipped presets if we ended up with nothing usable.
  if #out == 0 then
    for _, t in ipairs(FALLBACK_THEMES) do table.insert(out, t) end
  end

  return out
end

-- Load once at require time so every module that touches Themes sees a stable
-- list. If the user edits themes.json they can call M.reload() to pick it up.
M.colors = loadThemes()

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.count()
  return #M.colors
end

-- Return the currently active theme table (clamped to valid range).
function M.current()
  local idx = State.activeTheme
  if type(idx) ~= "number" or idx < 1 then idx = 1 end
  if idx > M.count() then idx = M.count() end
  return M.colors[idx]
end

-- Re-read themes.json from disk. Returns the new list (always non-empty).
function M.reload()
  local fresh = loadThemes()
  M.colors = fresh
  -- Clamp State.activeTheme so it stays in range after a reload that may have
  -- shrunk the theme set.
  if type(State.activeTheme) == "number" and State.activeTheme > #fresh then
    State.activeTheme = #fresh
  end
  return fresh
end

return M

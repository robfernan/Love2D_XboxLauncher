-- ============================================================================
-- CROSS-PLATFORM STEAM GAME SCANNER (Zero native dependencies)
-- Works on:
--   - Windows : C:\Program Files (x86)\Steam (and all library folders)
--   - Linux / Steam Deck : ~/.steam/steam or ~/.local/share/Steam
--   - macOS   : ~/Library/Application Support/Steam
--
-- Automatically parses libraryfolders.vdf and appmanifest_*.acf in pure Lua.
-- Discovers installed games and creates direct launch shortcuts (steam://run/<id>).
-- ============================================================================

local M = {}

M.discoveredGames = {}

-------------------------------------------------------------------------------
-- Platform default Steam paths
-------------------------------------------------------------------------------
local function getDefaultSteamPaths()
  local sys = love.system.getOS()
  local paths = {}

  if sys == "Windows" then
    table.insert(paths, "C:/Program Files (x86)/Steam")
    table.insert(paths, "C:/Program Files/Steam")
    table.insert(paths, "D:/Steam")
    table.insert(paths, "E:/Steam")
  elseif sys == "Linux" then
    local home = os.getenv("HOME") or "~"
    table.insert(paths, home .. "/.steam/steam")
    table.insert(paths, home .. "/.local/share/Steam")
  elseif sys == "OS X" or sys == "macOS" then
    local home = os.getenv("HOME") or "~"
    table.insert(paths, home .. "/Library/Application Support/Steam")
  end

  return paths
end

-------------------------------------------------------------------------------
-- Parse appmanifest_*.acf to extract appid and name
-------------------------------------------------------------------------------
local function parseManifest(content)
  if not content then return nil end
  local appid = content:match('"appid"%s+"(%d+)"')
  local name  = content:match('"name"%s+"([^"]+)"')
  if appid and name then
    return {
      appid = appid,
      name = name,
      url = "steam://rungameid/" .. appid,
      icon = "icons/steam_icon.png",
    }
  end
  return nil
end

-------------------------------------------------------------------------------
-- Scan a single steamapps directory using OS commands (pcall guarded)
-------------------------------------------------------------------------------
local function scanSteamappsDir(steamappsPath)
  local games = {}
  local sys = love.system.getOS()
  local listCmd = nil

  if sys == "Windows" then
    listCmd = 'cmd /c dir /b "' .. steamappsPath:gsub("/", "\\") .. '\\appmanifest_*.acf" 2>nul'
  else
    listCmd = 'ls -1 "' .. steamappsPath .. '"/appmanifest_*.acf 2>/dev/null'
  end

  local p = io.popen(listCmd)
  if not p then return games end

  for file in p:lines() do
    file = file:gsub("\r", ""):gsub("\n", "")
    local fullPath = steamappsPath .. "/" .. file
    if sys == "Windows" then
      fullPath = steamappsPath:gsub("\\", "/") .. "/" .. file
    end

    local f = io.open(fullPath, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local parsed = parseManifest(content)
      -- Exclude Steamworks Common Redistributables or Proton tools
      if parsed and not parsed.name:find("Steamworks") and not parsed.name:find("Proton") and not parsed.name:find("Steam Linux Runtime") then
        table.insert(games, parsed)
      end
    end
  end
  p:close()

  return games
end

-------------------------------------------------------------------------------
-- Parse libraryfolders.vdf to find secondary Steam library drives
-------------------------------------------------------------------------------
local function getLibraryFolders(steamRoot)
  local folders = { steamRoot .. "/steamapps" }
  local vdfPath = steamRoot .. "/steamapps/libraryfolders.vdf"
  local f = io.open(vdfPath, "r")
  if not f then return folders end

  local content = f:read("*a")
  f:close()

  for path in content:gmatch('"path"%s+"([^"]+)"') do
    path = path:gsub("\\\\", "/"):gsub("\\", "/")
    local full = path .. "/steamapps"
    local alreadyHave = false
    for _, existing in ipairs(folders) do
      if existing:lower() == full:lower() then alreadyHave = true break end
    end
    if not alreadyHave then
      table.insert(folders, full)
    end
  end

  return folders
end

-------------------------------------------------------------------------------
-- Scan all installed Steam games
-------------------------------------------------------------------------------
function M.scan()
  M.discoveredGames = {}
  local steamRoots = getDefaultSteamPaths()

  for _, root in ipairs(steamRoots) do
    local testVdf = io.open(root .. "/steamapps/libraryfolders.vdf", "r")
    if testVdf then
      testVdf:close()
      local libraryDirs = getLibraryFolders(root)
      for _, lib in ipairs(libraryDirs) do
        local found = scanSteamappsDir(lib)
        for _, g in ipairs(found) do
          table.insert(M.discoveredGames, g)
        end
      end
      break -- Found primary steam root
    end
  end

  print(string.format("[STEAM SCANNER] Discovered %d installed games.", #M.discoveredGames))
  return M.discoveredGames
end

return M

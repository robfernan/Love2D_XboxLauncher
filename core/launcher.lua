-- ============================================================================
-- LAUNCHER
-- Turns a shortcut item into an actual process or browser tab. This is the
-- "launch apps from here" half of the launcher: items may carry either
--   url — opened in the default browser via love.system.openURL, or
--   cmd — a local program path (e.g. C:\Games\game.exe), spawned detached so
--         it keeps running after this app exits and never blocks the UI.
--
-- Spawning is platform-aware:
--   Windows : `start "" "path"` via os.execute (detached, no console flash)
--   macOS   : `open -a` / `open`
--   Linux   : `setsid ... &`
-- ============================================================================

local M = {}

-------------------------------------------------------------------------------
-- Launch a shortcut item. Returns true on success, false otherwise.
-------------------------------------------------------------------------------
function M.launch(item)
  if not item then return false end

  -- 1) URL shortcuts: hand off to the default browser.
  if type(item.url) == "string" and #item.url > 0 then
    local ok = pcall(love.system.openURL, item.url)
    return ok
  end

  -- 2) Local program shortcuts: spawn detached per platform.
  if type(item.cmd) == "string" and #item.cmd > 0 then
    local sys = love.system.getOS()
    local cmd = M.buildCommand(sys, item.cmd)
    if not cmd then return false end

    -- os.execute returns (success, how, code). We only care about success.
    local ok = pcall(os.execute, cmd)
    return ok and true or false
  end

  return false
end

-------------------------------------------------------------------------------
-- Build the platform-specific detached-spawn command line for a program path.
-- The path is quoted so spaces in install locations work (e.g. "Program Files").
-------------------------------------------------------------------------------
function M.buildCommand(sys, path)
  local q = '"' .. path:gsub('"', '\\"') .. '"'
  if sys == "Windows" then
    -- `start` launches the program in its own process; the empty title arg
    -- prevents the first quoted argument from being treated as a window title.
    return 'start "" ' .. q
  elseif sys == "macOS" then
    return "open -a " .. q
  else
    -- Linux: setsid detaches into its own session so it survives our exit.
    return "setsid " .. q .. " >/dev/null 2>&1 &"
  end
end

-------------------------------------------------------------------------------
-- True if the item is a launchable shortcut (url or cmd). Used by the UI to
-- decide whether an item can be removed / what hint text to show.
-------------------------------------------------------------------------------
function M.isLaunchable(item)
  return (type(item.url) == "string" and #item.url > 0)
      or (type(item.cmd) == "string" and #item.cmd > 0)
end

return M

-- ============================================================================
-- COLOR THEMES
-- Four built-in profiles. Each theme defines:
--   color  — primary accent (menu buttons, connector line)
--   bg     — background clear color
--   glow   — glow / highlight / selection orb color
-- ============================================================================

local State = require("core.state")

local M = {}

M.colors = {
  { name = "Green",  color = {0.18, 1.00, 0.38}, bg = {0.02, 0.05, 0.03}, glow = {0.20, 1.00, 0.45} },
  { name = "Blue",   color = {0.18, 0.75, 1.00}, bg = {0.01, 0.03, 0.06}, glow = {0.25, 0.85, 1.00} },
  { name = "Red",    color = {1.00, 0.25, 0.25}, bg = {0.06, 0.01, 0.01}, glow = {1.00, 0.30, 0.30} },
  { name = "Purple", color = {0.95, 0.20, 1.00}, bg = {0.04, 0.00, 0.05}, glow = {1.00, 0.35, 1.00} },
}

function M.count()
  return #M.colors
end

-- Return the currently active theme table (clamped to valid range).
function M.current()
  local idx = State.activeTheme
  if idx < 1 or idx > M.count() then idx = M.count() end
  return M.colors[idx]
end

return M

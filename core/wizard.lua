-- ============================================================================
-- ADD-SHORTCUT WIZARD
-- A small in-app form for creating a custom shortcut. It overlays the main UI
-- and is driven by the same keyboard/mouse input as the rest of the launcher:
--
--   Up/Down  — move between fields
--   Left/Right or A on a field — cycle / edit that field's value
--   Enter    — confirm (create the shortcut) when all required fields are set
--   B/Esc    — cancel and return to the menu
--
-- Fields: Name, Type (App / Website), Target (path or URL), Category.
-- The form is intentionally minimal so it stays consistent with the launcher's
-- look; no text-box cursor needed because values cycle through sensible presets
-- plus a free-form "type here" mode toggled by A on the Name/Target fields.
-- ============================================================================

local State     = require("core.state")
local Shortcuts = require("core.shortcuts")
local Layout    = require("core.layout")

local M = {}

-- Wizard is closed until open() is called.
M.open_ = false

-- Field definitions (order matters — it's the navigation order).
local FIELDS = {
  { key = "name",     label = "NAME" },
  { key = "type",     label = "TYPE" },
  { key = "target",   label = "TARGET" },
  { key = "category", label = "CATEGORY" },
}

-- Preset value lists for the cycling fields.
local TYPE_VALUES    = { "App", "Website" }
local CATEGORY_VALUES = Shortcuts.CATEGORY_IDS   -- GAMES / BROWSE / MEDIA

-- Current form state (reset on each open).
M.form = {}
M.fieldIndex = 1          -- which field is highlighted (1..#FIELDS)
M.editingText = false     -- true while typing into Name/Target via keyboard

-------------------------------------------------------------------------------
-- Open the wizard with a fresh form.
-------------------------------------------------------------------------------
function M.open()
  M.open_ = true
  M.form = {
    name     = "My App",
    type     = TYPE_VALUES[1],
    target   = "",        -- e.g. C:\Games\game.exe or https://example.com
    category = CATEGORY_VALUES[1],
  }
  M.fieldIndex = 1
  M.editingText = false
end

function M.isOpen()
  return M.open_
end

-------------------------------------------------------------------------------
-- Close the wizard (cancel). Returns to whatever menu was showing.
-------------------------------------------------------------------------------
function M.close()
  M.open_ = false
  M.editingText = false
end

-------------------------------------------------------------------------------
-- True if the form is complete enough to create a shortcut.
-------------------------------------------------------------------------------
local function isValid()
  local f = M.form
  if type(f.name) ~= "string" or #f.name == 0 then return false end
  if type(f.target) ~= "string" or #f.target == 0 then return false end
  if f.type == "Website" and not f.target:match("^https?://") then
    -- Be forgiving: auto-prefix a bare domain.
    f.target = "https://" .. f.target
  end
  return true
end

-------------------------------------------------------------------------------
-- Create the shortcut from the current form and close the wizard.
-------------------------------------------------------------------------------
function M.confirm()
  if not isValid() then return false end
  local f = M.form
  local spec = {
    name     = f.name,
    category = f.category,
    type     = f.type,
  }
  if f.type == "Website" then
    spec.url = f.target
  else
    spec.cmd = f.target
  end
  local created = Shortcuts.add(spec)
  M.close()
  return created ~= nil
end

-------------------------------------------------------------------------------
-- Input handling. Returns true if the wizard consumed the key.
-------------------------------------------------------------------------------
function M.keypressed(key)
  if not M.open_ then return false end

  -- Cancel.
  if key == "b" or key == "escape" then
    M.close()
    return true
  end

  -- Confirm.
  if key == "return" or key == "kpenter" then
    M.confirm()
    return true
  end

  -- Move between fields.
  if key == "down" then
    M.fieldIndex = math.min(#FIELDS, M.fieldIndex + 1)
    M.editingText = false
    return true
  end
  if key == "up" then
    M.fieldIndex = math.max(1, M.fieldIndex - 1)
    M.editingText = false
    return true
  end

  local field = FIELDS[M.fieldIndex]

  -- Cycle preset fields (Type / Category).
  if key == "left" or key == "right" then
    local delta = (key == "right") and 1 or -1
    if field.key == "type" then
      local i = 1
      for n, v in ipairs(TYPE_VALUES) do if v == M.form.type then i = n break end end
      M.form.type = TYPE_VALUES[((i - 1 + delta) % #TYPE_VALUES + 1)]
    elseif field.key == "category" then
      local i = 1
      for n, v in ipairs(CATEGORY_VALUES) do if v == M.form.category then i = n break end end
      M.form.category = CATEGORY_VALUES[((i - 1 + delta) % #CATEGORY_VALUES + 1)]
    end
    return true
  end

  -- A toggles free-text entry on Name / Target.
  if key == "a" and (field.key == "name" or field.key == "target") then
    M.editingText = not M.editingText
    return true
  end

  -- While editing text, printable keys append to the active string field.
  if M.editingText and (field.key == "name" or field.key == "target") then
    local isPrintable = key:match("[%a%d%._/%\\:%-]") ~= nil
    if isPrintable then
      M.form[field.key] = M.form[field.key] .. key
      return true
    elseif key == "backspace" and #M.form[field.key] > 0 then
      M.form[field.key] = M.form[field.key]:sub(1, -2)
      return true
    end
  end

  return false
end

-------------------------------------------------------------------------------
-- Render the wizard overlay. Called from love.draw when isOpen().
-------------------------------------------------------------------------------
function M.render()
  if not M.open_ then return end

  local w, h = love.graphics.getDimensions()
  local S = Layout.scale()
  local theme = require("core.themes").current()
  local glowR, glowG, glowB = theme.glow[1], theme.glow[2], theme.glow[3]

  -- Dim the background.
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Centered panel.
  local panelW = 420 * S
  local rowH   = 34 * S
  local pad    = 24 * S
  local headerH = 48 * S
  local panelH = headerH + (#FIELDS * rowH) + (pad * 2) + 56 * S
  local px = (w - panelW) / 2
  local py = (h - panelH) / 2

  -- Panel body.
  love.graphics.setColor(0.04, 0.02, 0.08, 0.97)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 6 * S, 6 * S)
  love.graphics.setColor(glowR, glowG, glowB, 0.5)
  love.graphics.setLineWidth(1.5 * S)
  love.graphics.rectangle("line", px, py, panelW, panelH, 6 * S, 6 * S)

  -- Header.
  local font = State.bigFont or love.graphics.newFont(20)
  love.graphics.setFont(font)
  love.graphics.setColor(glowR, glowG, glowB, 1)
  local title = "ADD SHORTCUT"
  love.graphics.print(title, px + (panelW - font:getWidth(title)) / 2, py + 14 * S)

  -- Fields.
  local smallFont = State.smallFont or love.graphics.newFont(14)
  love.graphics.setFont(smallFont)
  for i, field in ipairs(FIELDS) do
    local y = py + headerH + (i - 1) * rowH
    local isActive = (i == M.fieldIndex)

    -- Row highlight.
    if isActive then
      love.graphics.setColor(glowR, glowG, glowB, 0.12)
      love.graphics.rectangle("fill", px + pad * 0.5, y - 4 * S, panelW - pad, rowH, 3 * S, 3 * S)
    end

    -- Label (left).
    love.graphics.setColor(1, 1, 1, isActive and 1 or 0.6)
    love.graphics.print(field.label, px + pad, y + (rowH - smallFont:getHeight()) / 2)

    -- Value (right-aligned).
    local value = M.form[field.key] or ""
    if field.key == "type" then
      value = value .. (isActive and ((M.fieldIndex == 2) and "  < >" or "") or "")
    end
    love.graphics.setColor(1, 1, 1, isActive and 1 or 0.85)
    local vw = smallFont:getWidth(value)
    love.graphics.print(value, px + panelW - pad - vw, y + (rowH - smallFont:getHeight()) / 2)

    -- Editing cursor hint.
    if isActive and M.editingText then
      love.graphics.setColor(glowR, glowG, glowB, 0.9)
      local caretX = px + panelW - pad - vw - 8 * S
      love.graphics.line(caretX, y + 6 * S, caretX, y + rowH - 6 * S)
    end
  end

  -- Footer hints.
  local hintY = py + headerH + (#FIELDS * rowH) + 12 * S
  love.graphics.setColor(0.7, 0.7, 0.8, 0.9)
  local hints = "A: edit/cycle   Enter: create   B/Esc: cancel"
  love.graphics.print(hints, px + (panelW - smallFont:getWidth(hints)) / 2, hintY)
end

return M

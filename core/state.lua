-- ============================================================================
-- SHARED APPLICATION STATE
-- Single source of truth for all mutable runtime state. Every other module
-- (menu, settings, render, input) reads/writes through this table so there is
-- exactly one place to look when debugging "why is the selection wrong?".
-- ============================================================================

local M = {}

-- Animation / time accumulators
M.timeacc = 0
M.menuPulse = 0
M.selectionAnim = 1.0

-- Navigation state machine
M.currentMenuLevel = "MAIN"   -- "MAIN" or a category id (GAMES/BROWSE/MEDIA/SETTINGS)
M.selected = 1                -- keyboard selection at MAIN level
M.subSelected = 1             -- keyboard selection inside a sub-menu
M.hoverIndex = 0              -- mouse hover index (0 = none); overrides keyboard when > 0

-- Active theme index (1..#themeColors). Initialized from Config in love.load().
M.activeTheme = 4

-- Window dragging state
M.isDragging = false
M.dragX, M.dragY = 0, 0

-- Mouse position cache (updated on mousemoved/pressed)
M.mouseX, M.mouseY = 0, 0

-- Press origin for click-vs-drag discrimination
M.pressX, M.pressY = 0, 0
M.DRAG_THRESHOLD = 6          -- px of movement before a press counts as a drag

-- Icon cache: path -> love.Image
M.iconCache = {}

-- Fonts (assigned in love.load)
M.bigFont, M.smallFont, M.tinyFont = nil, nil, nil

-- Render canvases + bloom shader (assigned in love.load / love.resize)
M.bgCanvas, M.planetCanvas = nil, nil
M.bloomA, M.bloomB = nil
M.blurShader = nil

return M

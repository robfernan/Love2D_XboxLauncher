-- ============================================================================
-- MENU DATA
-- The built-in category/item tree. User shortcuts (future Shortcut Manager)
-- will be merged into this structure at load time.
--
-- Each item may have:
--   name    — display label (Settings items carry live-updated names)
--   url     — opened via love.system.openURL when activated
--   action  — one of CYCLE_THEME / CYCLE_RES / TOGGLE_FS / CYCLE_WINMODE / CYCLE_SCALE
--   icon    — optional path to a PNG in icons/ (loaded into State.iconCache)
-- ============================================================================

local M = {}

M.categories = {
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
    { name = "Netflix",    url = "https://netflix.com",            icon = "icons/netflix_icon.png" },
    { name = "Spotify",    url = "https://spotify.com",            icon = "icons/spotify_icon.png" },
    { name = "Twitch",     url = "https://twitch.tv",              icon = "icons/twitch_icon.png" },
    { name = "Crunchyroll",url = "https://crunchyroll.com",        icon = "icons/crunchyroll_icon.png" },
  }},
  { name = "SETTINGS", id = "SETTINGS", items = {
    { name = "Theme: Purple",        action = "CYCLE_THEME",   icon = "icons/theme_icon.png" },
    { name = "Resolution: 1280x720", action = "CYCLE_RES",     icon = "icons/settings_icon.png" },
    { name = "Fullscreen: Off",      action = "TOGGLE_FS",     icon = "icons/video_icon.png" },
    { name = "Window: Borderless",   action = "CYCLE_WINMODE", icon = "icons/internet_icon.png" },
    { name = "UI Scale: 100%",       action = "CYCLE_SCALE",   icon = "icons/tool_icon.png" },
  }},
}

-- Find a category by id. Returns the category table or nil.
function M.findCategory(id)
  for _, cat in ipairs(M.categories) do
    if cat.id == id then return cat end
  end
  return nil
end

return M

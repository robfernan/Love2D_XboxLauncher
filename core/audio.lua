-- ============================================================================
-- PROCEDURAL SYNTHESIZED SOUND EFFECTS (love.audio + love.sound)
-- Pure procedural audio without external audio files!
-- Works 100% out-of-the-box on:
--   - Windows, macOS, Linux (native desktop)
--   - Web / HTML5 (love.js on itch.io)
-- ============================================================================

local M = {}

M.soundCache = {}
M.enabled = true

-------------------------------------------------------------------------------
-- Helper: Generate a short SoundData waveform and wrap it in a Source
-------------------------------------------------------------------------------
local function generateTone(duration, sampleRate, waveFn)
  local samples = math.floor(duration * sampleRate)
  local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

  for i = 0, samples - 1 do
    local t = i / sampleRate
    local val = waveFn(t, duration)
    -- Clamp [-1, 1]
    if val > 1 then val = 1 elseif val < -1 then val = -1 end
    soundData:setSample(i, val)
  end

  return love.audio.newSource(soundData, "static")
end

-------------------------------------------------------------------------------
-- Pre-bake audio clips
-------------------------------------------------------------------------------
function M.init()
  if not love.audio or not love.sound then return end

  -- 1) Navigation Tick: Soft high-tech mechanical blip
  pcall(function()
    M.soundCache["tick"] = generateTone(0.045, 22050, function(t, d)
      local freq = 750 + (1 - t / d) * 350
      local env = math.exp(-t * 90)
      return math.sin(2 * math.pi * freq * t) * env * 0.25
    end)
  end)

  -- 2) Swoosh / Tab Switch: Metallic blade whoosh
  pcall(function()
    M.soundCache["swoosh"] = generateTone(0.12, 22050, function(t, d)
      local freq = 220 + math.sin(t / d * math.pi) * 280
      local noise = (math.random() * 2 - 1) * 0.15
      local env = math.sin(t / d * math.pi)
      return (math.sin(2 * math.pi * freq * t) * 0.8 + noise) * env * 0.3
    end)
  end)

  -- 3) Select / Launch: Deep resonant power chime
  pcall(function()
    M.soundCache["select"] = generateTone(0.16, 22050, function(t, d)
      local freq1 = 440
      local freq2 = 880
      local env = math.exp(-t * 18)
      return (math.sin(2 * math.pi * freq1 * t) * 0.6 + math.sin(2 * math.pi * freq2 * t) * 0.4) * env * 0.35
    end)
  end)

  -- 4) Back / Cancel: Descending soft click
  pcall(function()
    M.soundCache["back"] = generateTone(0.06, 22050, function(t, d)
      local freq = 480 - (t / d) * 220
      local env = math.exp(-t * 50)
      return math.sin(2 * math.pi * freq * t) * env * 0.25
    end)
  end)
end

-------------------------------------------------------------------------------
-- Play sound by name
-------------------------------------------------------------------------------
function M.play(name)
  if not M.enabled then return end
  local src = M.soundCache[name]
  if src then
    src:stop()
    src:play()
  end
end

return M

-- ============================================================================
-- JSON Encoder/Decoder
-- A lightweight, dependency-free JSON library for LÖVE.
-- Supports: objects, arrays, strings, numbers, booleans, nil.
-- ============================================================================

local json = {}

-------------------------------------------------------------------------------
-- ENCODER
-------------------------------------------------------------------------------

local function escapeString(s)
  return (s:gsub('[%c"\\]', function(c)
    if c == '\n' then return '\\n'
    elseif c == '\r' then return '\\r'
    elseif c == '\t' then return '\\t'
    elseif c == '"' then return '\\"'
    elseif c == '\\' then return '\\\\'
    else return string.format('\\u%04x', c:byte()) end
  end))
end

local encodeValue

local function encodeObject(t)
  local parts = {}
  for k, v in pairs(t) do
    table.insert(parts, '"' .. escapeString(tostring(k)) .. '":' .. encodeValue(v))
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

local function encodeArray(t)
  local parts = {}
  for i = 1, #t do
    table.insert(parts, encodeValue(t[i]))
  end
  return '[' .. table.concat(parts, ',') .. ']'
end

function encodeValue(v)
  local tv = type(v)
  if v == nil then
    return 'null'
  elseif tv == 'boolean' then
    return v and 'true' or 'false'
  elseif tv == 'number' then
    if v ~= v then return 'null' end -- NaN
    if v == math.huge then return '1e999' end
    if v == -math.huge then return '-1e999' end
    -- Integer?
    if v == math.floor(v) and math.abs(v) < 1e15 then
      return string.format('%d', v)
    end
    return string.format('%.17g', v)
  elseif tv == 'string' then
    return '"' .. escapeString(v) .. '"'
  elseif tv == 'table' then
    -- Distinguish array vs object
    local isArray = true
    local count = 0
    for k in pairs(v) do
      count = count + 1
      if type(k) ~= 'number' then
        isArray = false
        break
      end
    end
    if count == 0 then
      return '{}'
    end
    if isArray then
      -- Ensure contiguous 1..n
      for i = 1, count do
        if v[i] == nil then isArray = false break end
      end
    end
    if isArray then
      return encodeArray(v)
    else
      return encodeObject(v)
    end
  else
    error('Cannot encode type: ' .. tv)
  end
end

function json.encode(value)
  return encodeValue(value)
end

-------------------------------------------------------------------------------
-- DECODER
-------------------------------------------------------------------------------

local function skipWhitespace(s, i)
  local n = #s
  while i <= n do
    local c = s:sub(i, i)
    if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
      i = i + 1
    else
      break
    end
  end
  return i
end

-- NOTE: The parser functions below are all LOCAL (forward-declared then
-- assigned) so mutual recursion works without polluting the global namespace.
-- `local f; function f() ... end` assigns to the local — this is safe and
-- preferred over bare chunk-level `function name()` which creates true globals.
local parseString, parseNumber, parseArray, parseObject, parseValue

local function errorAt(msg, s, i)
  local line = 1
  local col = 1
  for j = 1, math.min(i - 1, #s) do
    if s:sub(j, j) == '\n' then line = line + 1 col = 1 else col = col + 1 end
  end
  error('JSON parse error at line ' .. line .. ', col ' .. col .. ': ' .. msg, 0)
end

parseString = function(s, i)
  -- i points at opening quote
  if s:sub(i, i) ~= '"' then errorAt('expected string', s, i) end
  i = i + 1
  local buf = {}
  local n = #s
  while i <= n do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(buf), i + 1
    elseif c == '\\' then
      i = i + 1
      local esc = s:sub(i, i)
      if esc == 'n' then table.insert(buf, '\n')
      elseif esc == 'r' then table.insert(buf, '\r')
      elseif esc == 't' then table.insert(buf, '\t')
      elseif esc == 'b' then table.insert(buf, '\b')
      elseif esc == 'f' then table.insert(buf, '\f')
      elseif esc == '"' then table.insert(buf, '"')
      elseif esc == '\\' then table.insert(buf, '\\')
      elseif esc == '/' then table.insert(buf, '/')
      elseif esc == 'u' then
        -- Unicode escape
        local hex = s:sub(i + 1, i + 4)
        local code = tonumber(hex, 16)
        if code then
          if code < 128 then
            table.insert(buf, string.char(code))
          else
            -- Basic UTF-8 encoding
            if code < 2048 then
              table.insert(buf, string.char(192 + math.floor(code / 64), 128 + code % 64))
            else
              table.insert(buf, string.char(224 + math.floor(code / 4096),
                128 + math.floor(code / 64) % 64, 128 + code % 64))
            end
          end
          i = i + 4
        else
          errorAt('invalid unicode escape', s, i)
        end
      else
        errorAt('invalid escape', s, i)
      end
      i = i + 1
    else
      table.insert(buf, c)
      i = i + 1
    end
  end
  errorAt('unterminated string', s, i)
end

parseNumber = function(s, i)
  local start = i
  local n = #s
  -- Optional leading sign.
  if s:sub(i, i) == '-' then i = i + 1 end
  -- Consume a valid number character set. Use an explicit alternation rather
  -- than a bracket class ending in '-': `[%d%.eE+-]` is parsed by Lua as the
  -- range '+'..'~' (matching ':' and more), which over-consumed and broke parsing.
  local okChar = function(c)
    return c:match('%d') ~= nil or c == '.' or c == 'e' or c == 'E'
         or c == '+' or c == '-'
  end
  while i <= n and okChar(s:sub(i, i)) do
    i = i + 1
  end
  local numStr = s:sub(start, i - 1)
  local num = tonumber(numStr)
  if not num then errorAt('invalid number', s, start) end
  return num, i
end

parseArray = function(s, i)
  if s:sub(i, i) ~= '[' then errorAt('expected [', s, i) end
  i = i + 1
  local arr = {}
  i = skipWhitespace(s, i)
  if s:sub(i, i) == ']' then
    return arr, i + 1
  end
  while true do
    local val, ni = parseValue(s, i)
    table.insert(arr, val)
    i = skipWhitespace(s, ni)
    local c = s:sub(i, i)
    if c == ',' then
      i = skipWhitespace(s, i + 1)
    elseif c == ']' then
      return arr, i + 1
    else
      errorAt('expected , or ]', s, i)
    end
  end
end

parseObject = function(s, i)
  if s:sub(i, i) ~= '{' then errorAt('expected {', s, i) end
  i = i + 1
  local obj = {}
  i = skipWhitespace(s, i)
  if s:sub(i, i) == '}' then
    return obj, i + 1
  end
  while true do
    i = skipWhitespace(s, i)
    local key, ni = parseString(s, i)
    i = skipWhitespace(s, ni)
    if s:sub(i, i) ~= ':' then errorAt('expected :', s, i) end
    i = skipWhitespace(s, i + 1)
    local val, ni2 = parseValue(s, i)
    obj[key] = val
    i = skipWhitespace(s, ni2)
    local c = s:sub(i, i)
    if c == ',' then
      i = i + 1
    elseif c == '}' then
      return obj, i + 1
    else
      errorAt('expected , or }', s, i)
    end
  end
end

parseValue = function(s, i)
  i = skipWhitespace(s, i)
  local c = s:sub(i, i)
  if c == '"' then
    return parseString(s, i)
  elseif c == '{' then
    return parseObject(s, i)
  elseif c == '[' then
    return parseArray(s, i)
  elseif c == 't' then
    if s:sub(i, i + 3) == 'true' then return true, i + 4 end
    errorAt('invalid literal', s, i)
  elseif c == 'f' then
    if s:sub(i, i + 4) == 'false' then return false, i + 5 end
    errorAt('invalid literal', s, i)
  elseif c == 'n' then
    if s:sub(i, i + 3) == 'null' then return nil, i + 4 end
    errorAt('invalid literal', s, i)
  else
    return parseNumber(s, i)
  end
end

function json.decode(str)
  if type(str) ~= 'string' or #str == 0 then
    return nil
  end
  local ok, result = pcall(function()
    local val, _ = parseValue(str, 1)
    return val
  end)
  if not ok then
    print("[json] decode error: " .. tostring(result))
    return nil
  end
  return result
end

return json

local json = {}

local function is_array(tbl)
  local max = 0
  local count = 0
  for k, _ in pairs(tbl) do
    if type(k) ~= "number" then
      return false
    end
    if k > max then
      max = k
    end
    count = count + 1
  end
  return max == count
end

local function escape_str(s)
  return s
    :gsub("\\", "\\\\")
    :gsub("\"", "\\\"")
    :gsub("\b", "\\b")
    :gsub("\f", "\\f")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

local function encode_value(value)
  local t = type(value)
  if t == "nil" then
    return "null"
  elseif t == "number" then
    return tostring(value)
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "string" then
    return "\"" .. escape_str(value) .. "\""
  elseif t == "table" then
    if is_array(value) then
      local out = {}
      for i = 1, #value do
        out[#out + 1] = encode_value(value[i])
      end
      return "[" .. table.concat(out, ",") .. "]"
    else
      local out = {}
      for k, v in pairs(value) do
        out[#out + 1] = "\"" .. escape_str(tostring(k)) .. "\":" .. encode_value(v)
      end
      return "{" .. table.concat(out, ",") .. "}"
    end
  end
  error("Unsupported type for JSON encode: " .. t)
end

function json.encode(value)
  return encode_value(value)
end

local function decode_error(msg, idx)
  error("JSON decode error at " .. tostring(idx) .. ": " .. msg)
end

local function skip_ws(str, idx)
  local len = #str
  while idx <= len do
    local c = str:sub(idx, idx)
    if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then
      break
    end
    idx = idx + 1
  end
  return idx
end

local function decode_string(str, idx)
  local out = {}
  idx = idx + 1
  while idx <= #str do
    local c = str:sub(idx, idx)
    if c == "\"" then
      return table.concat(out), idx + 1
    elseif c == "\\" then
      local n = str:sub(idx + 1, idx + 1)
      if n == "\"" or n == "\\" or n == "/" then
        out[#out + 1] = n
      elseif n == "b" then
        out[#out + 1] = "\b"
      elseif n == "f" then
        out[#out + 1] = "\f"
      elseif n == "n" then
        out[#out + 1] = "\n"
      elseif n == "r" then
        out[#out + 1] = "\r"
      elseif n == "t" then
        out[#out + 1] = "\t"
      else
        decode_error("invalid escape", idx)
      end
      idx = idx + 2
    else
      out[#out + 1] = c
      idx = idx + 1
    end
  end
  decode_error("unterminated string", idx)
end

local function decode_number(str, idx)
  local start = idx
  local len = #str
  while idx <= len do
    local c = str:sub(idx, idx)
    if c:match("[0-9%+%-%.eE]") then
      idx = idx + 1
    else
      break
    end
  end
  local num = tonumber(str:sub(start, idx - 1))
  if not num then
    decode_error("invalid number", start)
  end
  return num, idx
end

local function decode_value(str, idx)
  idx = skip_ws(str, idx)
  local c = str:sub(idx, idx)
  if c == "\"" then
    return decode_string(str, idx)
  elseif c == "{" then
    local obj = {}
    idx = idx + 1
    idx = skip_ws(str, idx)
    if str:sub(idx, idx) == "}" then
      return obj, idx + 1
    end
    while idx <= #str do
      local key
      key, idx = decode_string(str, idx)
      idx = skip_ws(str, idx)
      if str:sub(idx, idx) ~= ":" then
        decode_error("expected ':'", idx)
      end
      idx = idx + 1
      local val
      val, idx = decode_value(str, idx)
      obj[key] = val
      idx = skip_ws(str, idx)
      local ch = str:sub(idx, idx)
      if ch == "}" then
        return obj, idx + 1
      elseif ch ~= "," then
        decode_error("expected ',' or '}'", idx)
      end
      idx = idx + 1
      idx = skip_ws(str, idx)
    end
    decode_error("unterminated object", idx)
  elseif c == "[" then
    local arr = {}
    idx = idx + 1
    idx = skip_ws(str, idx)
    if str:sub(idx, idx) == "]" then
      return arr, idx + 1
    end
    local i = 1
    while idx <= #str do
      local val
      val, idx = decode_value(str, idx)
      arr[i] = val
      i = i + 1
      idx = skip_ws(str, idx)
      local ch = str:sub(idx, idx)
      if ch == "]" then
        return arr, idx + 1
      elseif ch ~= "," then
        decode_error("expected ',' or ']'", idx)
      end
      idx = idx + 1
      idx = skip_ws(str, idx)
    end
    decode_error("unterminated array", idx)
  elseif c == "t" and str:sub(idx, idx + 3) == "true" then
    return true, idx + 4
  elseif c == "f" and str:sub(idx, idx + 4) == "false" then
    return false, idx + 5
  elseif c == "n" and str:sub(idx, idx + 3) == "null" then
    return nil, idx + 4
  else
    return decode_number(str, idx)
  end
end

function json.decode(str)
  local val, idx = decode_value(str, 1)
  idx = skip_ws(str, idx)
  if idx <= #str then
    decode_error("trailing characters", idx)
  end
  return val
end

return json

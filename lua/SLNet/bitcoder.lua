local ffi = require "ffi"
local bitcoder = {}

local function get_type(x) return tostring(x) end

local function set_value(val, type)
  local size = ffi.sizeof(type)
  local r = ffi.new(type..'[1]', val)
  return ffi.string(ffi.cast('const char*', r), ffi.sizeof(type))
end
local function get_value(src, type)
  local size = ffi.sizeof(type)
  local r = ffi.new('char[?]', size, src:byte(1, size))
  return ffi.cast(type..'*', r)[0]
end

function bitcoder.encode(s_type, s_value)
  if s_type == 'bool' then s_value = s_value == true and 1 or 0 end
  return set_value(type(s_value) == 'number'
  and s_value or 0, get_type(s_type) or 'unsigned char')
end
function bitcoder.decode(s_type, s_value)
  return get_value(type(s_value) == 'string'
  and s_value or '\0', get_type(s_type) or 'unsigned char')
end

return bitcoder

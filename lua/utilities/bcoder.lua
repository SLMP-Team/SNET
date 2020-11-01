local ffi = require("ffi")
local bcoder = {}

-- Types Definition
BS_INT8 = "signed char"
BS_INT16 = "signed short"
BS_INT32 = "signed long"
BS_UINT8 = "unsigned char"
BS_UINT16 = "unsigned short"
BS_UINT32 = "unsigned long"
BS_FLOAT = "float"
BS_BOOLEAN = "bool"
BS_STRING = "string"

local function set_value(v_type, v)
  local ptr = ffi.new(v_type .. "[1]", v)
  return ffi.string(ffi.cast("const char *", ptr), ffi.sizeof(v_type))
end

function bcoder.encode(v_type, v)
  if type(v_type) ~= "string" then return "\0" end
  return set_value(v_type, v)
end

local function get_value(v_type, v)
  local v_size = ffi.sizeof(v_type)
  local ptr = ffi.new("char[?]", v_size, v:byte(1, v_size))
  return ffi.cast(v_type .. "*", ptr)[0]
end

function bcoder.decode(v_type, v)
  if type(v_type) ~= "string" then return false end
  return get_value(v_type, v)
end

return bcoder

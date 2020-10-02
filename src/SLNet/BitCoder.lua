local bit = require 'bit'
local BitCoder = {}

BitCoder.ByteEmpty = '\0'

BitCoder.UINT8 = 0; BitCoder.UINT16 = 1; BitCoder.UINT32 = 2;
BitCoder.INT8 = 3; BitCoder.INT16 = 4; BitCoder.INT32 = 5;
BitCoder.FLOAT = 6; BitCoder.BOOL = 7; BitCoder.STRING = 8;

local function fuckLua(x)
  local y = 0x7FFFFFFF
  if x >= 0 then
    return x
  end
  local z = y - x
  return y + z
end

local function fuckLuaN(x)
  local y = 0x7FFFFFFF
  if x <= y then
    return x
  end
  local z = x - (y + 1)
  return -(y + 1) + z
end

function BitCoder:decode(srcType, src) -- for example, BitCoder:encode(UINT8, 'A') (result = 128(int))
  if srcType == BitCoder.UINT8 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 1 then return 0 end
    return string.byte(src)
  elseif srcType == BitCoder.UINT16 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 2 then return 0 end
    local b1, b2 = string.byte(src, 1, 2)
    return bit.bor(bit.lshift(b1, 8), b2)
  elseif srcType == BitCoder.UINT32 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 4 then return 0 end
    local b1, b2, b3, b4 = string.byte(src, 1, 4)
    b1 = bit.bor(bit.lshift(b1, 24), bit.lshift(b2, 16), bit.lshift(b3, 8), b4)
    return fuckLua(b1)
  elseif srcType == BitCoder.INT8 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 1 then return 0 end
    src = string.byte(src)
    if src > 0xFF then return 0 end
    return (src - bit.band(src, 128) * 2)
  elseif srcType == BitCoder.INT16 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 2 then return 0 end
    local b1, b2 = string.byte(src, 1, 2)
    src = bit.bor(bit.lshift(b1, 8), b2)
    if src > 0xFFFF then return 0 end
    return (src - bit.band(src, 32768) * 2)
  elseif srcType == BitCoder.INT32 then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 4 then return 0 end
    local b1, b2, b3, b4 = string.byte(src, 1, 4)
    src = bit.bor(bit.lshift(b1, 24), bit.lshift(b2, 16), bit.lshift(b3, 8), b4)
    if src > 0xFFFFFFFF then return 0 end
    return fuckLuaN(src - bit.band(src, 2147483648) * 2)
  elseif srcType == BitCoder.BOOL then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src ~= 1 then return false end
    return string.byte(src) == 1
  elseif srcType == BitCoder.FLOAT then
    src = type(src) == 'string' and src or BitCoder.ByteEmpty
    if #src == 0 then return 0.0 end
    local sign, mantissa = 1, string.byte(src, 3) % 128
    for i = 2, 1, -1 do mantissa = mantissa * 256 + string.byte(src, i) end
    if string.byte(src, 4) > 127 then sign = -1 end
    local exponent = (string.byte(src, 4) % 128) * 2 + math.floor(string.byte(src, 3) / 128)
    if exponent == 0 then return 0.0 end
    mantissa = (math.ldexp(mantissa, -23) + 1) * sign
    return math.ldexp(mantissa, exponent - 127)
  end
  return src
end

function BitCoder:encode(srcType, src) -- for example, BitCoder:encode(UINT8, 128)
  if srcType == BitCoder.UINT8 then
    src = type(src) == 'number' and src or 0
    if src < 0 or src > 0xFF then
      return BitCoder.ByteEmpty
    end
    return string.char(bit.band(src, 0xFF))
  elseif srcType == BitCoder.UINT16 then
    src = type(src) == 'number' and src or 0
    if src < 0 or src > 0xFFFF then
      return BitCoder.ByteEmpty
    end
    return string.char(
      bit.band(bit.rshift(src, 8), 0xFF),
      bit.band(bit.rshift(src, 0), 0xFF)
    )
  elseif srcType == BitCoder.UINT32 then
    rc = type(src) == 'number' and src or 0
    if src < 0 or src > 0xFFFFFFFF then
      return BitCoder.ByteEmpty
    end
    return string.char(
      bit.band(bit.rshift(src, 24), 0xFF),
      bit.band(bit.rshift(src, 16), 0xFF),
      bit.band(bit.rshift(src, 8), 0xFF),
      bit.band(bit.rshift(src, 0), 0xFF)
    )
  elseif srcType == BitCoder.INT8 then
    src = type(src) == 'number' and src or 0
    local tpPart = 0xFF / 2
    if src < -tpPart or src >= tpPart then
      return BitCoder.ByteEmpty
    end
    src = bit.band(src, 0xFF)
    return string.char(bit.band(src, 0xFF))
  elseif srcType == BitCoder.INT16 then
    src = type(src) == 'number' and src or 0
    local tpPart = 0xFFFF / 2
    if src < -tpPart or src >= tpPart then
      return BitCoder.ByteEmpty
    end
    src = bit.band(src, 0xFFFF)
    return string.char(
      bit.band(bit.rshift(src, 8), 0xFF),
      bit.band(bit.rshift(src, 0), 0xFF)
    )
  elseif srcType == BitCoder.INT32 then
    src = type(src) == 'number' and src or 0
    local tpPart = 0xFFFFFFFF / 2
    if src < -tpPart or src >= tpPart then
      return BitCoder.ByteEmpty
    end
    src = bit.band(src, 0xFFFFFFFF)
    return string.char(
      bit.band(bit.rshift(src, 24), 0xFF),
      bit.band(bit.rshift(src, 16), 0xFF),
      bit.band(bit.rshift(src, 8), 0xFF),
      bit.band(bit.rshift(src, 0), 0xFF)
    )
  elseif srcType == BitCoder.FLOAT then
    local function grabByte(v)
      return math.floor(v / 256), string.char(math.floor(v) % 256)
    end
    src = type(src) == 'number' and src or 0.0
    local minusSign = false
    if src < 0 then
      minusSign = true
      src = -src
    end
    local mantissa, exponent = math.frexp(src)
    if src == 0 then
      mantissa = 0
      exponent = 0
    else
      mantissa = (mantissa * 2 - 1) * 8388608
      exponent = exponent + 126
    end
    local v, byte = ''
    src, byte = grabByte(mantissa); v = v..byte
    src, byte = grabByte(src); v = v..byte
    src, byte = grabByte(exponent * 128 + src); v = v..byte
    src, byte = grabByte((sign == true and 1 or 0) * 128 + src); v = v..byte
    return v
  elseif srcType == BitCoder.BOOL then
    src = type(src) == 'boolean' and src or false
    return BitCoder:encode(BitCoder.UINT8, src == true and 1 or 0)
  elseif srcType == BitCoder.STRING then
    return tostring(srv)
  end
  return BitCoder.ByteEmpty
end

return BitCoder
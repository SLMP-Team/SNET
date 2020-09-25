local sizes = {
  [UINT8] = 1, [UINT16] = 2, [UINT32] = 4,
  [INT8] = 1, [INT16] = 2, [INT32] = 4,
  [FLOAT] = 4, [BOOL] = 1
}
local function get_size(srcType)
  return sizes[srcType] or 0
end

local BSClass =
{
  WritePointer = 1,
  ReadPointer = 1,
  BytesData = '',
  __tostring = function()
    return 'BitStream'
  end
}

function BSClass:getReadPointer() return self.ReadPointer end
function BSClass:getWritePointer() return self.WritePointer end
function BSClass:export() return self.BytesData end
function BSClass:import(bytes)
  bytes = type(bytes) == 'string' and bytes or '\0'
  local wpointer = self.WritePointer
  local saveData = string.sub(self.BytesData, wpointer, #self.BytesData)
  self.BytesData = string.sub(self.BytesData, 0, wpointer - 1)
  self.BytesData = self.BytesData .. bytes .. saveData
  return self
end
function BSClass:write(srcType, src)
  local wpointer = self.WritePointer
  local saveData = string.sub(self.BytesData, wpointer, #self.BytesData)
  self.BytesData = string.sub(self.BytesData, 0, wpointer - 1)
  if srcType >= UINT8 and srcType <= FLOAT then
    src = type(src) == 'number' and src or 0
    self.BytesData = self.BytesData
    .. BitCoder:encode(srcType, src)
    self.WritePointer = self.WritePointer + get_size(srcType)
  elseif srcType == BOOL then
    src = type(src) == 'boolean' and src or false
    self.BytesData = self.BytesData
    .. BitCoder:encode(srcType, src)
    self.WritePointer = self.WritePointer + get_size(srcType)
  elseif srcType == STRING then
    src = type(src) == 'string' and src or '\0'
    self.BytesData = self.BytesData .. src
    self.WritePointer = self.WritePointer + #src
  end
  self.BytesData = self.BytesData .. saveData
  return self
end
function BSClass:read(srcType, src)
  local part, rpointer = '', self.ReadPointer
  if srcType >= UINT8 and srcType <= BOOL then
    self.ReadPointer = self.ReadPointer + get_size(srcType)
    part = string.sub(self.BytesData, rpointer, self.ReadPointer - 1)
  elseif srcType == STRING then
    self.ReadPointer = self.ReadPointer + tonumber(src)
    part = string.sub(self.BytesData, rpointer, self.ReadPointer - 1)
  end; return BitCoder:decode(srcType, part)
end
function BSClass:setReadPointer(pos)
  pos = type(pos) == 'number' and pos or 1
  if pos < 1 then pos = 1 end
  self.ReadPointer = pos
  return self
end
function BSClass:setWritePointer(pos)
  pos = type(pos) == 'number' and pos or 1
  if pos < 1 then pos = 1 end
  self.WritePointer = pos
  return self
end

BSClass.__index = BSClass

local BitStream = {}
function BitStream:new(bytes)
  local temp = {}
  if bytes then
    bytes = type(bytes) == 'string' and bytes or '\0'
    temp.BytesData = bytes
  end
  setmetatable(temp, BSClass)
  return temp
end

return BitStream
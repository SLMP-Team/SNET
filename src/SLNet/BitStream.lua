local BitStream = {}

BitStream.UINT8 = 0; BitStream.UINT16 = 1; BitStream.UINT32 = 2;
BitStream.INT8 = 3; BitStream.INT16 = 4; BitStream.INT32 = 5;
BitStream.FLOAT = 6; BitStream.BOOL = 7; BitStream.STRING = 8;

function BitStream:new(bytes)
  local bitStream =
  {
    WritePointer = 1,
    ReadPointer = 1,
    BytesData = '',
    BSCheckPoint = true
  }

  if type(bytes) == 'string' then
    bitStream.BytesData = bytes
    bitStream.ReadPointer = #bytes + 1
    bitStream.WritePointer = #bytes + 1
  end

  function bitStream:import(bytes)
    bytes = type(bytes) == 'string' and bytes or '\0'

    local wpointer = bitStream.WritePointer
    local saveData = string.sub(bitStream.BytesData, wpointer, #bitStream.BytesData)
    bitStream.BytesData = string.sub(bitStream.BytesData, 0, wpointer - 1)
    bitStream.BytesData = bitStream.BytesData .. bytes .. saveData

    return bitStream
  end
  function bitStream:export()
    return bitStream.BytesData
  end

  function bitStream:setReadPointer(pos)
    pos = type(pos) == 'number' and pos or 1
    if pos < 1 then pos = 1 end
    bitStream.ReadPointer = pos
    return bitStream
  end
  function bitStream:setWritePointer(pos)
    pos = type(pos) == 'number' and pos or 1
    if pos < 1 then pos = 1 end
    bitStream.WritePointer = pos
    return bitStream
  end

  function bitStream.getReadPointer()
    return bitStream.ReadPointer
  end
  function bitStream.getWritePointer()
    return bitStream.WritePointer
  end

  function bitStream:write(srcType, src)
    local wpointer = bitStream.WritePointer
    local saveData = string.sub(bitStream.BytesData, wpointer, #bitStream.BytesData)
    bitStream.BytesData = string.sub(bitStream.BytesData, 0, wpointer - 1)

    if srcType == BitStream.UINT8 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.UINT8, src)
      bitStream.WritePointer = bitStream.WritePointer + 1
    elseif srcType == BitStream.UINT16 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.UINT16, src)
      bitStream.WritePointer = bitStream.WritePointer + 2
    elseif srcType == BitStream.UINT32 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.UINT32, src)
      bitStream.WritePointer = bitStream.WritePointer + 4
    elseif srcType == BitStream.INT8 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.INT8, src)
      bitStream.WritePointer = bitStream.WritePointer + 1
    elseif srcType == BitStream.INT16 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.INT16, src)
      bitStream.WritePointer = bitStream.WritePointer + 2
    elseif srcType == BitStream.INT32 then
      src = type(src) == 'number' and src or 0
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.INT32, src)
      bitStream.WritePointer = bitStream.WritePointer + 4
    elseif srcType == BitStream.FLOAT then
      src = type(src) == 'number' and src or 0.0
      local res = BitCoder:encode(BitStream.FLOAT, src)
      bitStream.BytesData = bitStream.BytesData .. res
      bitStream.WritePointer = bitStream.WritePointer + #res
    elseif srcType == BitStream.BOOL then
      src = type(src) == 'boolean' and src or false
      bitStream.BytesData = bitStream.BytesData
      .. BitCoder:encode(BitStream.BOOL, src)
      bitStream.WritePointer = bitStream.WritePointer + 1
    elseif srcType == BitStream.STRING then
      src = type(src) == 'string' and src or '\0'
      bitStream.BytesData = bitStream.BytesData .. src
      bitStream.WritePointer = bitStream.WritePointer + #src
    end

    bitStream.BytesData = bitStream.BytesData .. saveData
    return bitStream
  end

  function bitStream:read(srcType, src) -- for example, bitStream:read(BitStream.STRING, 15(string len))
    local rpointer = bitStream.ReadPointer

    if srcType == BitStream.UINT8 then
      bitStream.ReadPointer = bitStream.ReadPointer + 1
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.UINT8, part)
    elseif srcType == BitStream.UINT16 then
      bitStream.ReadPointer = bitStream.ReadPointer + 2
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.UINT16, part)
    elseif srcType == BitStream.UINT32 then
      bitStream.ReadPointer = bitStream.ReadPointer + 4
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.UINT32, part)
    elseif srcType == BitStream.INT8 then
      bitStream.ReadPointer = bitStream.ReadPointer + 1
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.INT8, part)
    elseif srcType == BitStream.INT16 then
      bitStream.ReadPointer = bitStream.ReadPointer + 2
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.INT16, part)
    elseif srcType == BitStream.INT32 then
      bitStream.ReadPointer = bitStream.ReadPointer + 4
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.INT32, part)
    elseif srcType == BitStream.FLOAT then
      bitStream.ReadPointer = bitStream.ReadPointer + 4
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.FLOAT, part)
    elseif srcType == BitStream.BOOL then
      bitStream.ReadPointer = bitStream.ReadPointer + 1
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.BOOL, part)
    elseif srcType == BitStream.STRING then
      src = type(src) == 'number' and src or 1
      bitStream.ReadPointer = bitStream.ReadPointer + src
      local part = string.sub(bitStream.BytesData, rpointer, bitStream.ReadPointer - 1)
      return BitCoder:decode(BitStream.STRING, part)
    end

    return 0
  end

  return bitStream
end

return BitStream
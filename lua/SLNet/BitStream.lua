local bitstream = {}

local ffi = require("ffi")
local bitcoder = require("slnet.bitcoder")

local bitstream_class = {
  data = "",
  write_ptr = 1,
  read_ptr = 1
}

function bitstream_class:write(data_type, data)
  data_type = type(data_type) == 'string' and data_type or 'unsigned char'
  local saved_data = self.data:sub(self.write_ptr, #self.data)
  if data_type == 'string' then self.data = self.data:sub(1, self.write_ptr - 1) .. data
  else self.data = self.data:sub(1, self.write_ptr - 1) .. bitcoder.encode(data_type, data) end
  self.write_ptr = self.write_ptr + (data_type == 'string' and #data or ffi.sizeof(data_type))
  self.data = self.data .. saved_data
  return self
end
function bitstream_class:read(data_type, data_len)
  data_type = type(data_type) == 'string' and data_type or 'unsigned char'
  data_len = (type(data_len) == 'number' and data_len or ffi.sizeof(data_type)) - 1
  local got_data = self.data:sub(self.read_ptr, self.read_ptr + data_len)
  if data_type ~= 'string' then
    got_data = bitcoder.decode(data_type, got_data)
  end
  self.read_ptr = self.read_ptr + data_len + 1
  return got_data
end

function bitstream.new(src_data)
  local new_bitstream = {}
  setmetatable(new_bitstream, {
    __index = bitstream_class,
    __tostring = function()
      return 'BitStream'
    end
  })
  new_bitstream.data = src_data
  return new_bitstream
end

return bitstream
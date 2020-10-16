local inclass_data = {}
local ffi = require("ffi")
local socket = require("socket")
local bitstream_m = require("slnet.bitstream")

local function ipairs_back(t)
  local i = #t + 1
  return function()
    i = i - 1
    if i > 0 then
      return i, t[i]
    end
  end
end

function inclass_data:connect(address, port)
  if self.status ~= SLNET_DISCONNECTED then
    return false
  end

  address = type(address) == 'string' and address or '*'
  port = type(port) == 'number' and port or 0

  self.status = SLNET_CONNECTING
  self.conn_timeout = os.time()

  self.socket:settimeout(0)
  self.socket:setpeername(address, port)

  self.address = address
  self.port = port

  self.last_update = nil

  self:send_packet(SLNET_CONNECT_PCK, nil, SLNET_NO_PRIORITY)
  return true
end

function inclass_data:disconnect()
  if self.status == SLNET_DISCONNECTED then
    return false
  end

  self:send_packet(SLNET_DISCONNECT_PCK, nil, SLNET_NO_PRIORITY)
  self.status = SLNET_DISCONNECTED

  self.socket:close()
  self.socket = socket.udp()

  self.address = ''
  self.port = 0

  return true
end

function inclass_data:send_packet(packet_id, bitstream, priority)
  if self.status == SLNET_DISCONNECTED then
    return false
  end

  packet_id = type(packet_id) == 'number' and packet_id or 0
  bitstream = tostring(bitstream) == 'BitStream' and bitstream or bitstream_m.new()
  priority = type(priority) == 'number' and priority or SLNET_SYSTEM_PRIORITY

  table.insert(self.send_packet_queue, {
    packet_id = packet_id,
    bitstream = bitstream,
    priority = priority
  })

  return true
end

function inclass_data:check_updates()
  if os.time() ~= self.last_send_receive_time then
    self.last_send_receive_time = os.time()
    self.send_per_second = 0
    self.receive_per_second = 0
  end
  if self.status ~= SLNET_DISCONNECTED then
    self:check_timeout()
    self:process_send_queue()
    self:process_confirmation()
    self:delete_confirms()
    self:process_receive()
  end
end

function inclass_data:check_timeout()
  if os.time() - self.last_check_time > self.check_try_time then
    self.last_check_time = os.time()
    self:send_packet(SLNET_CHECKING_PCK, nil, SLNET_NO_PRIORITY)
  end
  if self.status == SLNET_CONNECTING and os.time() - self.conn_timeout > self.max_connection_time then
    if type(self.on_any_event) == 'function' then
      self.on_any_event('connection timeout', {})
    end
    self:disconnect()
  elseif self.last_update and os.time() - self.last_update > self.connection_timeout then
    self.last_update = nil
    if type(self.on_any_event) == 'function' then
      self.on_any_event('disconnection', {})
    end
    self:disconnect()
  end
end

function inclass_data:process_receive()
  if self.max_receive_per_second == -1 or self.receive_per_second < self.max_receive_per_second then
    local data = self.socket:receive()
    if data and data:sub(1, #self.packets_prefix) == self.packets_prefix then
      self.receive_per_second = self.receive_per_second + 1
      local clear_data = data:sub(#self.packets_prefix + 1, #data)
      local bitstream = bitstream_m.new(clear_data)

      local u_packet_id = bitstream:read('unsigned long')
      local packet_id = bitstream:read('unsigned short')
      local priority = bitstream:read('bool')

      local was_packet = false
      for i, v in ipairs(self.last_received) do
        if v == u_packet_id then
          was_packet = true
          break
        end
      end

      if not was_packet then
        table.insert(self.last_received, u_packet_id)
        clear_data = bitstream.data:sub(bitstream.read_ptr, #bitstream.data)
        bitstream = bitstream_m.new(clear_data)

        if priority then
          local conf_bs = BitStream()
          conf_bs:write('unsigned long', u_packet_id)
          self:send_packet(SLNET_CONFIRMATION_PCK, conf_bs, SLNET_NO_PRIORITY)
        end

        if packet_id == SLNET_CONFIRMATION_PCK then
          local u_pck = bitstream:read('unsigned long')
          for ii, vv in ipairs(self.send_confirm_queue) do
            if vv.u_packet_id == u_pck then
              table.remove(self.send_confirm_queue, ii)
            end
          end
          if type(self.on_any_event) == 'function' then
            self.on_any_event('confirmation', {
              u_packet_id = u_pck
            })
          end
        elseif packet_id == SLNET_CONNECT_ERR_PCK then
          local reason = bitstream:read('unsigned char')
          if type(self.on_any_event) == 'function' then
            if reason == 1 then
              self.on_any_event('no connection slots', {})
            end
          end
          self:disconnect()
        elseif packet_id == SLNET_CONNECT_PCK then
          if type(self.on_any_event) == 'function' then
            self.on_any_event('connection', {})
          end
          self.status = SLNET_CONNECTED
        elseif packet_id == SLNET_DISCONNECT_PCK then
          if type(self.on_any_event) == 'function' then
            self.on_any_event('disconnection', {})
          end
          self:disconnect()
        elseif packet_id == SLNET_CHECKING_PCK then
          self.last_update = os.time()
          if type(self.on_any_event) == 'function' then
            self.on_any_event('update', {})
          end
        elseif type(self.on_receive_packet) == 'function' and self.status == SLNET_CONNECTED then
          self.on_receive_packet(packet_id, bitstream, priority, self.address, self.port)
        end

      end

      for i = #self.last_received, 1, -1 do
        local this = self.last_received[i]
        if u_packet_id - this >= 50 or this - u_packet_id >= 50 then
          table.remove(self.last_received, i)
        end
      end

    end
  end
end

function inclass_data:process_send_queue()
  local sent_msgs = {}
  for i, v in ipairs(self.send_packet_queue) do
    if self.max_send_per_second ~= -1 and self.send_per_second >= self.max_send_per_second then break end
    self.send_per_second = self.send_per_second + 1

    local send_data = self.packets_prefix
    local bitstream = bitstream_m.new(v.bitstream.data)

    bitstream.write_ptr = 1 -- reset pointer to zero (one in lua)
    bitstream:write('unsigned long', self.last_packet_id) -- Packet Unique ID
    bitstream:write('unsigned short', v.packet_id) -- Packet System ID
    bitstream:write('bool', v.priority ~= SLNET_NO_PRIORITY)

    if v.priority ~= SLNET_NO_PRIORITY then
      table.insert(self.send_confirm_queue, {
        priority = v.priority,
        times = 0,
        u_packet_id = self.last_packet_id,
        packet_id = v.packet_id,
        bitstream = v.bitstream,
        last_send = os.clock()
      })
    end

    self.last_packet_id = self.last_packet_id + 1
    if self.last_packet_id > 4294967295 then
      self.last_packet_id = 0
    end

    send_data = send_data .. bitstream.data
    if self.status ~= SLNET_DISCONNECTED then
      self.socket:send(send_data)
    end
    table.insert(sent_msgs, i)
  end
  for i, v in ipairs_back(sent_msgs) do
    table.remove(self.send_packet_queue, v)
  end
end

function inclass_data:process_confirmation()
  for i, v in ipairs(self.send_confirm_queue) do
    if self.max_send_per_second ~= -1 and self.send_per_second >= self.max_send_per_second then break end
    if os.clock() - v.last_send > 1.0 then
      self.send_per_second = self.send_per_second + 1
      self.send_confirm_queue[i].times = v.times + 1
      self.send_confirm_queue[i].last_send = os.clock()

      local send_data = self.packets_prefix
      local bitstream = bitstream_m.new(v.bitstream.data)

      bitstream.write_ptr = 1 -- reset pointer to zero (one in lua)
      bitstream:write('unsigned long', v.u_packet_id) -- Packet Unique ID
      bitstream:write('unsigned short', v.packet_id) -- Packet System ID
      bitstream:write('bool', v.priority ~= SLNET_NO_PRIORITY)

      send_data = send_data .. bitstream.data
      if self.status ~= SLNET_DISCONNECTED then
        self.socket:send(send_data)
      end
    end
  end
end

function inclass_data:delete_confirms()
  for i = #self.send_confirm_queue, 1, -1 do
    local this = self.send_confirm_queue[i]
    if this.priority == SLNET_SYSTEM_PRIORITY and self.status ~= SLNET_CONNECTED then
      table.remove(self.send_confirm_queue, i)
    elseif this.priority == SLNET_HIGH_PRIORITY and this.times >= 100 then
      table.remove(self.send_confirm_queue, i)
    elseif this.priority == SLNET_MEDIUM_PRIORITY and this.times >= 50 then
      table.remove(self.send_confirm_queue, i)
    elseif this.priority == SLNET_LOW_PRIORITY and this.times >= 10 then
      table.remove(self.send_confirm_queue, i)
    end
  end
end

return inclass_data
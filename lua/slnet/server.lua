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

function inclass_data:disconnect(address, port)
  for i, v in ipairs_back(self.connected_clients) do
    if v.address == address and v.port == port then
      self:send_packet(SLNET_DISCONNECT_PCK, nil,
      SLNET_NO_PRIORITY, address, port)
      local full_address = address .. ':' .. port
      self.last_received[full_address] = nil
      if type(self.on_any_event) == 'function' then
        self.on_any_event('disconnection', {
          address = address,
          port = port
        })
      end
      table.remove(self.connected_clients, i)
      break
    end
  end
end

function inclass_data:bind(address, port)
  if self.status ~= SLNET_DISCONNECTED then
    return false
  end

  address = type(address) == 'string' and address or '*'
  port = type(port) == 'number' and port or 0

  self.status = SLNET_CONNECTED

  self.socket:settimeout(0)
  self.socket:setsockname(address, port)

  self.address = address
  self.port = port

  return true
end

function inclass_data:unbind()
  if self.status == SLNET_DISCONNECTED then
    return false
  end

  self.status = SLNET_DISCONNECTED

  self.socket:close()
  self.socket = socket.udp()

  self.address = '*'
  self.port = 0

  return true
end

function inclass_data:send_packet(packet_id, bitstream, priority, address, port)
  if self.status == SLNET_DISCONNECTED then
    return false
  end

  packet_id = type(packet_id) == 'number' and packet_id or 0
  bitstream = tostring(bitstream) == 'BitStream' and bitstream or bitstream_m.new()
  priority = type(priority) == 'number' and priority or SLNET_SYSTEM_PRIORITY
  address = type(address) == 'string' and address or '*'
  port = type(port) == 'number' and port or 0

  table.insert(self.send_packet_queue, {
    packet_id = packet_id,
    bitstream = bitstream,
    priority = priority,
    address = address,
    port = port
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
    self:check_clients()
    self:process_send_queue()
    self:process_confirmation()
    self:delete_confirms()
    self:process_receive()
  end
end

function inclass_data:check_clients() -- connection timeout kick
  for i, v in ipairs_back(self.connected_clients) do
    if os.time() - v.timeout > self.connection_timeout then
      self:disconnect(v.address, v.port)
    end
  end
end

function inclass_data:process_receive()
  if self.max_receive_per_second == -1 or self.receive_per_second < self.max_receive_per_second then
    local data, address, port = self.socket:receivefrom()
    if data and data:sub(1, #self.packets_prefix) == self.packets_prefix then
      self.receive_per_second = self.receive_per_second + 1
      local clear_data = data:sub(#self.packets_prefix + 1, #data)
      local bitstream = bitstream_m.new(clear_data)

      local u_packet_id = bitstream:read('unsigned long')
      local packet_id = bitstream:read('unsigned short')
      local priority = bitstream:read('bool')

      local was_packet = false
      local full_address = tostring(address)..':'..tostring(port)

      if self.last_received[full_address] then
        for i, v in ipairs(self.last_received[full_address]) do
          if v == u_packet_id then
            was_packet = true
            break
          end
        end
      end

      if not was_packet then
        if not self.last_received[full_address] then
          self.last_received[full_address] = {}
        end
        table.insert(self.last_received[full_address], u_packet_id)
        clear_data = bitstream.data:sub(bitstream.read_ptr, #bitstream.data)
        bitstream = bitstream_m.new(clear_data)

        if priority then
          local conf_bs = BitStream()
          conf_bs:write('unsigned long', u_packet_id)
          self:send_packet(SLNET_CONFIRMATION_PCK, conf_bs,
          SLNET_NO_PRIORITY, address, port)
        end

        if packet_id == SLNET_CONNECT_PCK then
          local is_conn = false
          for i, v in ipairs(self.connected_clients) do
            if v.address == address and v.port == port then
              is_conn = true
              break
            end
          end
          if not is_conn then
            if self.max_clients_connected ~= -1 and #self.connected_clients >= self.max_clients_connected then
              local bs_conf = bitstream_m.new()
              bs_conf:write('unsigned char', 1) -- no free slots
              self:send_packet(SLNET_CONNECT_ERR_PCK,
              bs_conf, SLNET_NO_PRIORITY, address, port)
              if type(self.on_any_event) == 'function' then
                self.on_any_event('connection attempt', {
                  address = address,
                  port = port,
                  reason = 1
                })
              end
            else
              table.insert(self.connected_clients, {
                address = address,
                port = port,
                timeout = os.time(),
                last_packet = 0
              })
              self:send_packet(SLNET_CONNECT_PCK, nil,
              SLNET_SYSTEM_PRIORITY, address, port)
              if type(self.on_any_event) == 'function' then
                self.on_any_event('connection', {
                  address = address,
                  port = port
                })
              end
            end
          end
        elseif packet_id == SLNET_DISCONNECT_PCK then
          for i, v in ipairs(self.connected_clients) do
            if v.address == address and v.port == port then
              self:send_packet(SLNET_DISCONNECT_PCK, nil,
              SLNET_NO_PRIORITY, address, port)
              table.remove(self.connected_clients, i)
              if type(self.on_any_event) == 'function' then
                self.on_any_event('disconnection', {
                  address = address,
                  port = port
                })
              end
              break
            end
          end
        elseif packet_id == SLNET_CHECKING_PCK then
          for i, v in ipairs(self.connected_clients) do
            if v.address == address and v.port == port then
              self:send_packet(SLNET_CHECKING_PCK, nil,
              SLNET_NO_PRIORITY, address, port)
              self.connected_clients[i].timeout = os.time()
              if type(self.on_any_event) == 'function' then
                self.on_any_event('update', {
                  address = address,
                  port = port
                })
              end
              break
            end
          end
        elseif packet_id == SLNET_CONFIRMATION_PCK then
          for i, v in ipairs(self.connected_clients) do
            if v.address == address and v.port == port then
              local u_pck = bitstream:read('unsigned long')
              for ii, vv in ipairs(self.send_confirm_queue) do
                if vv.u_packet_id == u_pck then
                  table.remove(self.send_confirm_queue, ii)
                end
              end
              if type(self.on_any_event) == 'function' then
                self.on_any_event('confirmation', {
                  address = address,
                  port = port,
                  u_packet_id = u_pck
                })
              end
              break
            end
          end
        elseif type(self.on_receive_packet) == 'function' then
          for i, v in ipairs(self.connected_clients) do
            if v.address == address and v.port == port then
              if self.min_packets_interval == -1 or os.clock() - v.last_packet >= self.min_packets_interval then
                self.connected_clients[i].last_packet = os.clock()
                self.on_receive_packet(packet_id, bitstream, priority, address, port)
              end
              break
            end
          end
        end

      end

      if self.last_received[full_address] then
        for i = #self.last_received[full_address], 1, -1 do
          local this = self.last_received[full_address][i]
          if u_packet_id - this >= 50 or this - u_packet_id >= 50 then
            table.remove(self.last_received[full_address], i)
          end
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
        last_send = os.clock(),
        address = v.address,
        port = v.port
      })
    end

    self.last_packet_id = self.last_packet_id + 1
    if self.last_packet_id > 4294967295 then
      self.last_packet_id = 0
    end

    send_data = send_data .. bitstream.data
    if self.status ~= SLNET_DISCONNECTED then
      self.socket:sendto(send_data, v.address, v.port)
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
        self.socket:sendto(send_data, v.address, v.port)
      end
    end
  end
end

function inclass_data:delete_confirms()
  for i = #self.send_confirm_queue, 1, -1 do
    local this = self.send_confirm_queue[i]
    local is_conn = false
    for i, v in ipairs(self.connected_clients) do
      if v.address == this.address and v.port == this.port then
        is_conn = true
        break
      end
    end
    if this.priority == SLNET_SYSTEM_PRIORITY and not is_conn then
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
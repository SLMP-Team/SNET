local slnet = {}
local bitstream = require("slnet.bitstream")
local socket = require("socket")

local client_class = require("slnet.client")
local server_class = require("slnet.server")

local slnet_class = {
  address = "*",
  port = 0,
  status = SLNET_DISCONNECTED,
  last_packet_id = 0,
  last_received = {},
  max_receive_per_second = -1,
  max_send_per_second = -1,
  send_per_second = 0,
  receive_per_second = 0,
  last_send_receive_time = 0,
  connection_timeout = 120,
  send_packet_queue = {},
  send_confirm_queue = {},
  packets_prefix = 'SLNET'
}

-- create handle for client / server
local function new_handle(is_client, class_name)
  local new_handle = {}
  setmetatable(new_handle, {
    __index = slnet_class,
    __tostring = function()
      return class_name
    end
  })
  new_handle.is_client = is_client
  new_handle.socket = socket.udp()
  return new_handle
end

function slnet.client()
  local handle = new_handle(true, "SLNet Client")
  handle.max_connection_time = 10 -- 10 seconds timeout
  handle.check_try_time = 10 -- every 10 seconds try
  handle.last_check_time = 0
  for k, v in pairs(client_class) do handle[k] = v end
  return handle
end

function slnet.server()
  local handle = new_handle(false, "SLNet Server")
  handle.max_clients_connected = -1 -- clients no limit
  handle.connected_clients = {} -- all connected clients
  handle.min_packets_interval = -1 -- no packets min limit
  for k, v in pairs(server_class) do handle[k] = v end
  return handle
end

return slnet
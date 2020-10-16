-- SL:NET Module by Pakulichev, based on Lua
-- Works with LuaJIT using LuaSocket library
-- GitHub: https://github.com/SLMP-Team/SLNet

local slnet = {}

-- SL:NET Handle Statuses
SLNET_DISCONNECTED = 0
SLNET_CONNECTING = 1
SLNET_CONNECTED = 2

-- SL:NET Priority Statuses
SLNET_SYSTEM_PRIORITY = 0 -- until receiving / disconnecting
SLNET_HIGH_PRIORITY = 1 -- 100 tries of sending packet
SLNET_MEDIUM_PRIORITY = 2 -- 50 tries of sending packet
SLNET_LOW_PRIORITY = 3 -- 10 tries of sending packet
SLNET_NO_PRIORITY = 4 -- without packet receiving check

-- SL:NET Service Packets
local from_max = 0xFFFF
SLNET_CONNECT_PCK = from_max - 1
SLNET_DISCONNECT_PCK = from_max - 2
SLNET_CONFIRMATION_PCK = from_max - 3
SLNET_CHECKING_PCK = from_max - 4
SLNET_CONNECT_ERR_PCK = from_max - 5

local network = require("slnet.init") -- init SL:NET
local bitstream = require("slnet.bitstream") -- SL:NET BitStream

slnet.client = network.client -- create client handle
slnet.server = network.server -- create server handle

BitStream = bitstream.new -- new SL:NET BitStream native

return slnet

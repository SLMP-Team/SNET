require 'SLNet'

local pcks = {
  CONNECTION_PACKET = 1,
  MESSAGE_PACKET = 2,
  DICONNECTION_PACKET = 3,
  CONFIRM_PACKET = 4
}

local chat_name = ''
local chat_status = 0
local conn_timeout = 0
local chck_timeout = os.time()
local clients = {}

function packet_handler(pck_id, bitstream, address, port)
  print(pck_id, bitstream, address, port)
  if pck_id == pcks['CONNECTION_PACKET'] then
    if chat_status == 1 then
      local nickname = bitstream:read(STRING, bitstream:read(UINT8))
      for i, v in ipairs(clients) do
        if address == v.address and port == v.port then
          local new_bitstream = BitStream:new()
          new_bitstream:write(BOOL, false):write(UINT8, 1) -- client already connected
          SLNetSend(net_handle, pcks['CONNECTION_PACKET'], new_bitstream, address, port, 0)
          return
        end
        if nickname == v.nickname then
          local new_bitstream = BitStream:new()
          new_bitstream:write(BOOL, false):write(UINT8, 2) -- nickname already in use
          SLNetSend(net_handle, pcks['CONNECTION_PACKET'], new_bitstream, address, port, 0)
          return
        end
      end
      local new_bitstream = BitStream:new()
      new_bitstream:write(BOOL, true):write(UINT8, #chat_name):write(STRING, chat_name)
      SLNetSend(net_handle, pcks['CONNECTION_PACKET'], new_bitstream, address, port, 0)
      table.insert(clients, {
        address = address,
        port = port,
        nickname = nickname,
        timeout = os.time()
      })
    elseif chat_status == 2 then
      local status = bitstream:read(BOOL)
      if status then
        local name = bitstream:read(STRING, bitstream:read(UINT8))
        conn_timeout = 0
        sampAddChatMessage('Chat Connected to '..name..' !', 0xFFFFFFFF)
        return
      end
      net_handle = SLNetInit()
      net_handle:setPrefix('CHAT')
      net_handle:setHook(packet_handler)
      conn_timeout = 0
      chat_status = 0
      local err_code = bitstream:read(UINT8)
      if err_code == 1 then
        sampAddChatMessage('Connection Failed: You`re Already Connected, Reload Script!', 0xFFFFFFFF)
      elseif err_code == 2 then
        sampAddChatMessage('Connection Failed: Your Nickname Is Already In Use, Try Another!', 0xFFFFFFFF)
      end
    end
  elseif pck_id == pcks['MESSAGE_PACKET'] then
    if chat_status == 1 then
      for i, v in ipairs(clients) do
        if address == v.address and port == v.port then
          local message = bitstream:read(STRING, bitstream:read(UINT8))
          local new_bitstream = BitStream:new()
          new_bitstream:write(UINT8, #v.nickname):write(STRING, v.nickname)
          new_bitstream:write(UINT8, #message):write(STRING, message)
          for ii, vv in ipairs(clients) do
            SLNetSend(net_handle, pcks['MESSAGE_PACKET'], new_bitstream, vv.address, vv.port, 5)
          end
          sampAddChatMessage('[CH] ' .. v.nickname .. ': ' .. message, 0xFFFFFFFF)
          return
        end
      end
    elseif chat_status == 2 then
      local nickname = bitstream:read(STRING, bitstream:read(UINT8))
      local message = bitstream:read(STRING, bitstream:read(UINT8))
      sampAddChatMessage('[CH] ' .. nickname .. ': ' .. message, 0xFFFFFFFF)
    end
  elseif pck_id == pcks['DICONNECTION_PACKET'] then
    if chat_status == 1 then
      for i, v in ipairs(clients) do
        if address == v.address and port == v.port then
          for ii = #clients, 1, -1 do
            if i == ii then
              table.remove(clients, ii)
            end
          end
          return
        end
      end
    end
    net_handle = SLNetInit()
    net_handle:setPrefix('CHAT')
    net_handle:setHook(packet_handler)
    conn_timeout = 0
    chat_status = 0
    sampAddChatMessage('Chat Host Closed the Connection!', 0xFFFFFFFF)
  elseif pck_id == pcks['CONFIRM_PACKET'] then
    if chat_status == 1 then
      for i, v in ipairs(clients) do
        if address == v.address and port == v.port then
          clients[i].timeout = os.time()
        end
      end
    end
  end
end

net_handle = SLNetInit()
net_handle:setPrefix('CHAT')
net_handle:setHook(packet_handler)

function main()
  repeat
    wait(0)
  until isSampAvailable()

  sampRegisterChatCommand('chat.host', function(args)
    if #args < 1 or #args > 127 then
      sampAddChatMessage('/chat.host [chat name]{len: 1 - 127}', 0xFFFFFFFF)
      return
    end
    if chat_status ~= 0 then
      sampAddChatMessage('Unable to Host Chat Right Now!', 0xFFFFFFFF)
      return
    end
    net_handle:bind('*', 5411)
    chat_status = 1
    sampAddChatMessage('Chat Successfully Hosted on Port 5411!', 0xFFFFFFFF)
    chat_name = args
  end)

  sampRegisterChatCommand('chat.connect', function(args)
    local address = args:match('^(%S+)$')
    if not address then
      sampAddChatMessage('/chat.connect [chat address]', 0xFFFFFFFF)
      return
    end
    if chat_status ~= 0 then
      sampAddChatMessage('Unable to Connect Chat Right Now!', 0xFFFFFFFF)
      return
    end
    net_handle:connect(address, 5411)
    chat_status = 2
    sampAddChatMessage('Connecting to Chat with Address ' .. address .. ':5411...', 0xFFFFFFFF)
    local bitstream = BitStream:new()
    local nickname = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    bitstream:write(UINT8, #nickname):write(STRING, nickname)
    SLNetSend(net_handle, pcks['CONNECTION_PACKET'], bitstream, 0)
    conn_timeout = os.time()
  end)

  sampRegisterChatCommand('ch', function(args)
    if #args < 1 or #args > 127 then
      sampAddChatMessage('/ch [chat message]{len: 1 - 127}', 0xFFFFFFFF)
      return
    end
    if chat_status == 0 then
      sampAddChatMessage('You Are Not Connected to Chat!', 0xFFFFFFFF)
      return
    end
    if chat_status == 1 then
      local nickname = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
      local bitstream = BitStream:new()
      bitstream:write(UINT8, #nickname):write(STRING, nickname)
      bitstream:write(UINT8, #args):write(STRING, args)
      for i, v in ipairs(clients) do
        SLNetSend(net_handle, pcks['MESSAGE_PACKET'], bitstream, v.address, v.port, 5)
      end
      sampAddChatMessage('[CH] ' .. nickname .. ': ' .. args, 0xFFFFFFFF)
      return
    end
    local bitstream = BitStream:new()
    bitstream:write(UINT8, #args):write(STRING, args)
    SLNetSend(net_handle, pcks['MESSAGE_PACKET'], bitstream, 5)
  end)

  while true do
    wait(0)
    net_handle:loop()
    if os.time() - chck_timeout > 10 then
      chck_timeout = os.time()
      if chat_status == 2 then
        SLNetSend(net_handle, pcks['CONFIRM_PACKET'], nil, 0)
      elseif chat_status == 1 then
        for i = #clients, 1, -1 do
          local v = clients[i]
          if os.time() - v.timeout > 30 then
            SLNetSend(net_handle, pcks['DICONNECTION_PACKET'], nil, v.address, v.port, 5)
            table.remove(clients, i)
          end
        end
      end
    end
    if conn_timeout ~= 0 and os.time() - conn_timeout > 5 then
      net_handle = SLNetInit()
      net_handle:setPrefix('CHAT')
      net_handle:setHook(packet_handler)
      conn_timeout = 0
      chat_status = 0
      sampAddChatMessage('Connection Failed: Chat Host didn`t Respond on Request!', 0xFFFFFFFF)
    end
  end
end

function onScriptTerminate(script)
  if script == thisScript() then
    if chat_status == 0 then
      return
    end
    if chat_status == 1 then
      for i, v in ipairs(clients) do
        SLNetSend(net_handle, pcks['DICONNECTION_PACKET'], nil, v.address, v.port, 0)
      end
      return
    end
    SLNetSend(net_handle, pcks['DICONNECTION_PACKET'], nil, 0)
  end
end
require 'SLNet'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local ImVec2, ImVec4 = imgui.ImVec2, imgui.ImVec4

local game_window = imgui.new.bool(false)
local game_address = imgui.new.char[40]('127.0.0.1')
local game_status = 0
local players = {}

local player_pos = {0, 0}
local last_movement = os.clock()
local last_timeout = os.time()

local pcks = {
  CONNECTION_PACKET = 1,
  PLAYER_JOIN = 2,
  PLAYER_MOVEMENT = 3,
  PLAYER_LEFT = 4
}

function packet_handler_client(pck_id, bitstream)
  if pck_id == pcks.CONNECTION_PACKET then
    local pos = {
      bitstream:read(FLOAT),
      bitstream:read(FLOAT)
    }
    player_pos = {pos[1], pos[2]}
  elseif pck_id == pcks.PLAYER_JOIN then
    local nickname = bitstream:read(STRING, bitstream:read(UINT8))
    local pos = {
      bitstream:read(FLOAT),
      bitstream:read(FLOAT)
    }
    table.insert(players, {
      nickname = nickname,
      pos = pos
    })
  elseif pck_id == pcks.PLAYER_MOVEMENT then
    local nickname = bitstream:read(STRING, bitstream:read(UINT8))
    local pos = {
      bitstream:read(FLOAT),
      bitstream:read(FLOAT)
    }
    for i, v in ipairs(players) do
      if v.nickname == nickname then
        players[i].pos = pos
        break
      end
    end
  elseif pck_id == pcks.PLAYER_LEFT then
    local nickname = bitstream:read(STRING, bitstream:read(UINT8))
    for i = #players, 1, -1 do
      if players[i].nickname == nickname then
        table.remove(players, i)
        break
      end
    end
  end
end
function packet_handler_server(pck_id, bitstream, address, port)
  print(pck_id, bitstream, address, port)
  if net_status == 2 then
    return packet_handler_client(pck_id, bitstream)
  end
  if pck_id == pcks.CONNECTION_PACKET then
    for i, v in ipairs(players) do
      if address == v.address and port == v.port then
        return
      end
    end
    table.insert(players, {
      address = address,
      port = port,
      nickname = bitstream:read(STRING, bitstream:read(UINT8)),
      pos = {math.random(40, 560), math.random(40, 560)},
      timeout = os.time()
    })
    local new_bitstream = BitStream:new()
    new_bitstream:write(FLOAT, players[#players].pos[1]):write(FLOAT, players[#players].pos[2])
    SLNetSend(net_handle, pcks.CONNECTION_PACKET, new_bitstream, address, port, 5)
    new_bitstream = BitStream:new()
    local my_nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    new_bitstream:write(UINT8, #my_nick):write(STRING, my_nick)
    new_bitstream:write(FLOAT, player_pos[1]):write(FLOAT, player_pos[2])
    SLNetSend(net_handle, pcks.PLAYER_JOIN, new_bitstream, address, port, 5)
    for i, v in ipairs(players) do
      if i ~= #players then
        new_bitstream = BitStream:new()
        new_bitstream:write(UINT8, #players[#players].nickname):write(STRING, players[#players].nickname)
        new_bitstream:write(FLOAT, players[#players].pos[1]):write(FLOAT, players[#players].pos[2])
        SLNetSend(net_handle, pcks.PLAYER_JOIN, new_bitstream, v.address, v.port, 5)
        new_bitstream = BitStream:new()
        new_bitstream:write(UINT8, #players[i].nickname):write(STRING, players[i].nickname)
        new_bitstream:write(FLOAT, players[i].pos[1]):write(FLOAT, players[i].pos[2])
        SLNetSend(net_handle, pcks.PLAYER_JOIN, new_bitstream, address, port, 5)
      end
    end
  elseif pck_id == pcks.PLAYER_MOVEMENT then
    for i, v in ipairs(players) do
      if address == v.address and port == v.port then
        local pos = {
          bitstream:read(FLOAT),
          bitstream:read(FLOAT)
        }
        v.pos = pos
        v.timeout = os.time()
        local new_bitstream = BitStream:new()
        new_bitstream:write(UINT8, #v.nickname):write(STRING, v.nickname)
        new_bitstream:write(FLOAT, pos[1]):write(FLOAT, pos[2])
        for ii, vv in ipairs(players) do
          if ii ~= i then
            SLNetSend(net_handle, pcks.PLAYER_MOVEMENT, new_bitstream, vv.address, vv.port, 0)
          end
        end
        return
      end
    end
  end
end

local function conv_col(x, y, z, w)
  return imgui.ColorConvertFloat4ToU32(ImVec4(x, y, z, w))
end

local function sl_init()
  net_status = 0
  net_handle = SLNetInit()
  net_handle:setPrefix('GAME')
  net_handle:setHook(packet_handler_server)
end sl_init()

imgui.OnFrame(function() return game_window[0] and not isGamePaused() end, function(self)
  self.HideCursor = false
  self.LockPlayer = true

  local sX, sY = getScreenResolution()

  imgui.SetNextWindowPos(ImVec2(sX / 2, sY / 2), imgui.Cond.FirstUseEver, ImVec2(0.5, 0.5))
  imgui.SetNextWindowSize(ImVec2(600, 620), imgui.Cond.Always)

  imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, ImVec2(0, 0))
  imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 0.0)
  imgui.Begin('SLGame', game_window, imgui.WindowFlags.NoResize)

  local c_pos = imgui.GetCursorScreenPos()
  imgui.GetWindowDrawList():AddRectFilled(ImVec2(c_pos.x, c_pos.y), ImVec2(c_pos.x + 10, c_pos.y + 600), imgui.ColorConvertFloat4ToU32(ImVec4(0.3, 0.3, 0.3, 1)))
  imgui.GetWindowDrawList():AddRectFilled(ImVec2(c_pos.x + 590, c_pos.y), ImVec2(c_pos.x + 600, c_pos.y + 600), imgui.ColorConvertFloat4ToU32(ImVec4(0.3, 0.3, 0.3, 1)))
  imgui.GetWindowDrawList():AddRectFilled(ImVec2(c_pos.x + 10, c_pos.y), ImVec2(c_pos.x + 590, c_pos.y + 10), imgui.ColorConvertFloat4ToU32(ImVec4(0.3, 0.3, 0.3, 1)))
  imgui.GetWindowDrawList():AddRectFilled(ImVec2(c_pos.x + 10, c_pos.y + 590), ImVec2(c_pos.x + 590, c_pos.y + 600), imgui.ColorConvertFloat4ToU32(ImVec4(0.3, 0.3, 0.3, 1)))
  imgui.GetWindowDrawList():AddRectFilledMultiColor(ImVec2(c_pos.x + 10, c_pos.y + 10), ImVec2(c_pos.x + 590, c_pos.y + 590),
  conv_col(0.5, 0.5, 0.5, 1), conv_col(0.6, 0.6, 0.6, 1), conv_col(0.6, 0.6, 0.6, 1), conv_col(0.5, 0.5, 0.5, 1))

  if game_status == 0 then
    imgui.SetCursorPos(ImVec2(300 - imgui.CalcTextSize('Welcome to SLGame!').x / 2, 200))
    imgui.Text('Welcome to SLGame!')
    imgui.SetCursorPos(ImVec2(300 - imgui.CalcTextSize('Welcome to SLGame!').x / 2, 230))
    if imgui.Button('Create a Game', ImVec2(imgui.CalcTextSize('Welcome to SLGame!').x, 0)) then
      game_status = 1
      net_status = 1
      player_pos = {
        math.random(20, 580),
        math.random(20, 580),
      }
      net_handle:bind('*', 4343)
    end
    imgui.SetCursorPos(ImVec2(300 - imgui.CalcTextSize('Welcome to SLGame!').x / 2, 255))
    if imgui.Button('Connect to Game', ImVec2(imgui.CalcTextSize('Welcome to SLGame!').x, 0)) then
      game_status = 1
      net_status = 2
      net_handle:connect(ffi.string(game_address), 4343)
      local my_nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
      local bitstream = BitStream:new()
      bitstream:write(UINT8, #my_nick):write(STRING, my_nick)
      SLNetSend(net_handle, pcks['CONNECTION_PACKET'], bitstream, 0)
      player_pos = {-1000, -1000}
      sampAddChatMessage('Connecting to SLGame Server...', 0xFFFFFFFF)
    end
    imgui.SetCursorPos(ImVec2(300 - imgui.CalcTextSize('Welcome to SLGame!').x / 2, 280))
    imgui.PushItemWidth(imgui.CalcTextSize('Welcome to SLGame!').x)
    imgui.InputText('##Address', game_address, ffi.sizeof(game_address) - 1)
    imgui.PopItemWidth()
  end

  if game_status ~= 0 then
    for i, v in ipairs(players) do
      imgui.SetCursorPos(ImVec2(v.pos[1] - imgui.CalcTextSize(v.nickname).x / 2, v.pos[2] - 5))
      imgui.Text(v.nickname)
      imgui.GetWindowDrawList():AddCircleFilled(ImVec2(c_pos.x + v.pos[1], c_pos.y + v.pos[2]), 10, conv_col(1, 0, 1, 1))
    end
    local my_nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    imgui.SetCursorPos(ImVec2(player_pos[1] - imgui.CalcTextSize(my_nick).x / 2, player_pos[2] - 5))
    imgui.Text(my_nick)
    imgui.GetWindowDrawList():AddCircleFilled(ImVec2(c_pos.x + player_pos[1], c_pos.y + player_pos[2]), 10, conv_col(1, 1, 0, 1))
  end

  imgui.End()
  imgui.PopStyleVar(2)
end)

function main()
  repeat
    wait(0)
  until isSampAvailable()
  sampRegisterChatCommand('slgame', function()
    game_window[0] = not game_window[0]
  end)
  while true do
    wait(0)
    net_handle:loop()

    if game_status ~= 0 then
      if os.clock() - last_movement > 0.1 then
        last_movement = os.clock()
        if net_status == 1 then
          local bitstream = BitStream:new()
          local my_nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
          bitstream:write(UINT8, #my_nick):write(STRING, my_nick)
          bitstream:write(FLOAT, player_pos[1]):write(FLOAT, player_pos[2])
          for i, v in ipairs(players) do
            SLNetSend(net_handle, pcks['PLAYER_MOVEMENT'], bitstream, v.address, v.port, 0)
          end
        elseif net_status == 2 then
          local bitstream = BitStream:new()
          bitstream:write(FLOAT, player_pos[1]):write(FLOAT, player_pos[2])
          SLNetSend(net_handle, pcks['PLAYER_MOVEMENT'], bitstream, 0)
        end
      end
    end

    if os.time() - last_timeout > 5 and net_status == 1 then
      last_timeout = os.time()
      for i = #players, 1, -1 do
        local player = players[i]
        print(player.timeout)
        if os.time() - player.timeout > 5 then
          local bitstream = BitStream:new()
          bitstream:write(UINT8, #player.nickname):write(STRING, player.nickname)
          for ii, vv in ipairs(players) do
            SLNetSend(net_handle, pcks['PLAYER_LEFT'], bitstream, vv.address, vv.port, 5)
          end
          table.remove(players, i)
        end
      end
    end

    if game_window[0] and game_status ~= 0 then
      local speed = 0.1
      if isKeyDown(0x10) then
        speed = 0.5
      end

      if isKeyDown(0x57) or isKeyDown(0x26) then
        player_pos[2] = player_pos[2] - speed
        if player_pos[2] < 30 then
          player_pos[2] = 30
        end
      elseif isKeyDown(0x53) or isKeyDown(0x28) then
        player_pos[2] = player_pos[2] + speed
        if player_pos[2] > 580 then
          player_pos[2] = 580
        end
      end

      if isKeyDown(0x41) or isKeyDown(0x25) then
        player_pos[1] = player_pos[1] - speed
        if player_pos[1] < 20 then
          player_pos[1] = 20
        end
      elseif isKeyDown(0x44) or isKeyDown(0x27) then
        player_pos[1] = player_pos[1] + speed
        if player_pos[1] > 580 then
          player_pos[1] = 580
        end
      end

    end
  end
end
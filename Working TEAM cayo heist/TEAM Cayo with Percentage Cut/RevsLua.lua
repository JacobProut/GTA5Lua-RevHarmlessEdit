--[[
  Rev-Harmless's Scripts
  Description: Harmless's Scripts is a collection of scripts made by Harmless. Edited and Updated features by Rev
  Version: 1.0
]]--


--[Message on Load]--
gui.show_message("Rev-Harmless's' Edit'", "Rev-Harmless's Scripts loaded successfully!")
--[End of Message on Load]--


--[Menu Tabs Section]--
RHSTab = gui.get_tab("Rev-Harmless's' Edited' Scripts")
UserTab = RHSTab:add_tab("User Settings")
VehicleSettingsTab = RHSTab:add_tab("Vehicle Settings")
VehicleMovementTab = VehicleSettingsTab:add_tab("Vehicle Movement")
DriftTab = VehicleSettingsTab:add_tab("Drift Settings")
RHSEnemy = RHSTab:add_tab("Enemy Options")
ESPTab = RHSEnemy:add_tab("NPC ESP")
TeleportTab = RHSTab:add_tab("Teleport Options")
HeistTab = RHSTab:add_tab("Heist Editor")
ComputerTab = RHSTab:add_tab("Computer Section")
--[End of Menu Tabs Section]--



--[Json Information]--
function json()
  local json = { _version = "0.1.2" }
  --encode
  local encode

  local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
  }

  local escape_char_map_inv = { [ "/" ] = "/" }
  for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
  end

  local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
  end

  local function encode_nil(val)
    return "null"
  end

  local function encode_table(val, stack)
    local res = {}
    stack = stack or {}
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
      local n = 0
      for k in pairs(val) do
        if type(k) ~= "number" then
          error("invalid table: mixed or invalid key types")
        end
        n = n + 1
      end
      if n ~= #val then
        error("invalid table: sparse array")
      end
      for i, v in ipairs(val) do
        table.insert(res, encode(v, stack))
      end
      stack[val] = nil
      return "[" .. table.concat(res, ",") .. "]"
    else
      for k, v in pairs(val) do
        if type(k) ~= "string" then
          error("invalid table: mixed or invalid key types")
        end
        table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
      end
      stack[val] = nil
      return "{" .. table.concat(res, ",") .. "}"
    end
  end

  local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
  end

  local function encode_number(val)
    if val ~= val or val <= -math.huge or val >= math.huge then
      error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
  end

  local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
  }

  encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
      return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
  end

  function json.encode(val)
    return ( encode(val) )
  end


  --decode
  local parse

  local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
      res[ select(i, ...) ] = true
    end
    return res
  end

  local space_chars   = create_set(" ", "\t", "\r", "\n")
  local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
  local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
  local literals      = create_set("true", "false", "null")

  local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
  }

  local function next_char(str, idx, set, negate)
    for i = idx, #str do
      if set[str:sub(i, i)] ~= negate then
        return i
      end
    end
    return #str + 1
  end

  local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
      col_count = col_count + 1
      if str:sub(i, i) == "\n" then
        line_count = line_count + 1
        col_count = 1
      end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
  end

  local function codepoint_to_utf8(n)
    local f = math.floor
    if n <= 0x7f then
      return string.char(n)
    elseif n <= 0x7ff then
      return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
      return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
      return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                        f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error( string.format("invalid unicode codepoint '%x'", n) )
  end

  local function parse_unicode_escape(s)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
    if n2 then
      return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
      return codepoint_to_utf8(n1)
    end
  end

  local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
      local x = str:byte(j)
      if x < 32 then
        decode_error(str, j, "control character in string")
      elseif x == 92 then -- `\`: Escape
        res = res .. str:sub(k, j - 1)
        j = j + 1
        local c = str:sub(j, j)
        if c == "u" then
          local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                  or str:match("^%x%x%x%x", j + 1)
                  or decode_error(str, j - 1, "invalid unicode escape in string")
          res = res .. parse_unicode_escape(hex)
          j = j + #hex
        else
          if not escape_chars[c] then
            decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
          end
          res = res .. escape_char_map_inv[c]
        end
        k = j + 1
      elseif x == 34 then -- `"`: End of string
        res = res .. str:sub(k, j - 1)
        return res, j + 1
      end
      j = j + 1
    end
    decode_error(str, i, "expected closing quote for string")
  end

  local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
      decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
  end

  local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
      decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
  end

  local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
      local x
      i = next_char(str, i, space_chars, true)
      -- Empty / end of array?
      if str:sub(i, i) == "]" then
        i = i + 1
        break
      end
      -- Read token
      x, i = parse(str, i)
      res[n] = x
      n = n + 1
      -- Next token
      i = next_char(str, i, space_chars, true)
      local chr = str:sub(i, i)
      i = i + 1
      if chr == "]" then break end
      if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
  end

  local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
      local key, val
      i = next_char(str, i, space_chars, true)
      -- Empty / end of object?
      if str:sub(i, i) == "}" then
        i = i + 1
        break
      end
      -- Read key
      if str:sub(i, i) ~= '"' then
        decode_error(str, i, "expected string for key")
      end
      key, i = parse(str, i)
      -- Read ':' delimiter
      i = next_char(str, i, space_chars, true)
      if str:sub(i, i) ~= ":" then
        decode_error(str, i, "expected ':' after key")
      end
      i = next_char(str, i + 1, space_chars, true)
      -- Read value
      val, i = parse(str, i)
      -- Set
      res[key] = val
      -- Next token
      i = next_char(str, i, space_chars, true)
      local chr = str:sub(i, i)
      i = i + 1
      if chr == "}" then break end
      if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
  end

  local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
  }

  parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
      return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
  end

  function json.decode(str)
    if type(str) ~= "string" then
      error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
      decode_error(str, idx, "trailing garbage")
    end
    return res
  end

  return json
end

json = json()
--[End of Json Information]--



--[Default Config]--
local default_config = {
  npcEspCB = false,
  npcEspShowEnemiesCB = false,
  npcEspBoxCB = true,
  npCEspTracerCB = false,
  npcEspDistance = 50,
  npcEspColor = {1.0, 0.0, 0.0, 1.0},


  --Testing for npc health with esp code--
  npcEspHealthCB = false;
  ----------------------------------------

  --Testing for npc Armor with esp code--
  npcEspArmorCB = false;
  ---------------------------------------
  --Added Esp ColorByDistance ComboBox--
  npcEspColorByDistanceCB = false; 
--------------------------------------

  --User Movement Section--
  walkCB = false,
  walkSpeed = 1.2,
  swimCB = false,
  swimSpeed = 1.2, 
  -------------------------

  --Vehicle Speed Section--
  maxSpeedCB = false,
  speedLimit = 1000,
  forwardSpeedCB = false,
  speedBoost = 100,
  -------------------------

  --Drift Section--
  shiftDriftCB = false,
  driftAmount = 1,
  driftTyresCB = false,
  -----------------

  --Vehicle Flip--
  autoFlipVehicleCB = false,
  ----------------

  --Tool Tip Section--
  toolTipV2CB = true,
  toolTipCB = false,
  --------------------
}
--[End of Default Config]--








--[[

  RHS Config Functions

]]--  
function writeToFile(filename, data)
  local file, err = io.open(filename, "w")
  if file == nil then
    log.warning("Failed to write to " .. filename)
    gui.show_error("Rev-Harmless's Scripts", "Failed to write to " .. filename)
    return false
  end
  file:write(json.encode(data))
  file:close()
  return true
end

function readFromFile(filename)
  local file, err = io.open(filename, "r")
  if file == nil then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return json.decode(content)
end

function checkAndCreateConfig(default_config)
  local config = readFromFile("RHSConfig.json")
  if config == nil then
    log.warning("Config file not found, creating a default config")
    gui.show_warning("Rev-Harmless's Scripts", "Config file not found, creating a default config")
    if not writeToFile("RHSConfig.json", default_config) then
      return false
    end
    config = default_config
  end

  for key, defaultValue in pairs(default_config) do
    if config[key] == nil then
      config[key] = defaultValue
    end
  end

  if not writeToFile("RHSConfig.json", config) then
    return false
  end
  return true
end

function readAndDecodeConfig()
  while not checkAndCreateConfig(default_config) do
    -- Wait for the file to be created
    os.execute("sleep " .. tonumber(1))
    log.debug("Waiting for RHSConfig.json to be created")
  end
  return readFromFile("RHSConfig.json")
end

function saveToConfig(item_tag, value)
  local t = readAndDecodeConfig()
  if t then
    t[item_tag] = value
    if not writeToFile("RHSConfig.json", t) then
      log.debug("Failed to encode JSON to RHSConfig.json")
    end
  end
end

function readFromConfig(item_tag)
  local t = readAndDecodeConfig()
  if t then
    return t[item_tag]
  else
    log.debug("Failed to decode JSON from RHSConfig.json")
  end
end

function resetConfig(default_config)
  writeToFile("RHSConfig.json", default_config)
end
--[End of Config Files]--



--[Main Tab Section]--
RHSTab:add_imgui(function()
  ImGui.Text("Version: 1.5")
  ImGui.Text("Harmless's 'Github:")
  ImGui.SameLine(); ImGui.TextColored(0.8, 0.9, 1, 1, "YimMenu-Lua/Harmless-Scripts")
  if ImGui.IsItemHovered() and ImGui.IsItemClicked(0) then
    ImGui.SetClipboardText("https://github.com/YimMenu-Lua/Harmless-Scripts")
    HSNotification("Copied to clipboard!")
    HSConsoleLogInfo("Copied https://github.com/YimMenu-Lua/Harmless-Scripts to clipboard!")
  end
  HSshowTooltip("Click to copy to clipboard")
  
  ImGui.Text("Rev's Github:")
  ImGui.SameLine(); ImGui.TextColored(0.8, 0.9, 1, 1, "https://github.com/JacobProut/GTA5Lua-RevHarmlessEdit")

  ImGui.Text("Alestarov's Github'")
  ImGui.SameLine(); ImGui.TextColored(0.8, 0.9, 1, 1, "https://github.com/YimMenu-Lua/Alestarov-Menu")

  ImGui.Separator()
  if ImGui.Button("Changelog") then
    ImGui.OpenPopup("  Version 1.5")
  end
  if ImGui.BeginPopupModal("  Version 1.5", true, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize) then
    local centerX, centerY = GetScreenCenter()
    ImGui.SetWindowPos(centerX - 300, centerY - 200)
    ImGui.SetWindowSize(300, 200)
    ImGui.Text("Version: 1.5 Rev-Harmless Edit")
    ImGui.TextWrapped("Colored Npc Esp, Npc Health Bar, Added Heist Editor, Added Computer System network. Heist and computer system code was taken from @Alestarov")
    ImGui.EndPopup()
  end
  ImGui.Separator()
end)
--[End of Main Tab Section]--



--[Enemy Tab Section]--
RHSEnemy:add_imgui(function()
  ImGui.Text("Welcome to the Enemy Gui Page")
  ImGui.Text("More will be added to this Page EVENTUALLY!")
end)

--[End of Enemy Tab Section]--


--[ESP SECTION]--
ESPTab:add_imgui(function()
  npcEspTab()
  npcEspUpcomingFeatures()
end)

local npcEspCB = readFromConfig("npcEspCB")
local npcEspShowEnemiesCB = readFromConfig("npcEspShowEnemiesCB")
local npcEspBoxCB = readFromConfig("npcEspBoxCB")
local npcEspTracerCB = readFromConfig("npcEspTracerCB")
local npcEspDistance = readFromConfig("npcEspDistance")
local npcEspColor = readFromConfig("npcEspColor")

-- Added Esp ColorByDistance ComboBox --
local npcEspColorByDistanceCB = readFromConfig("npcEspColorByDistanceCB")
-----------------------------------------

-- Health Added Code --
local npcEspHealthCB = readFromConfig("npcEspHealthCB")
----------------------

-- Armor Added Code --
local npcEspArmorCB = readFromConfig("npcEspArmorCB")
----------------------


function npcEspTab()
  npcEspCB, npcEspToggled = HSCheckbox("NPC ESP", npcEspCB, "npcEspCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Toggle On/Off NPC ESP")
  end

  npcEspShowEnemiesCB, npcEspShowEnemiesCBToggled = HSCheckbox("Show Only Enemies", npcEspShowEnemiesCB, "npcEspShowEnemiesCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Only show enemies and not Peds!")
  end

  npcEspBoxCB, npcEspBoxCBToggled = HSCheckbox("NPC ESP Box", npcEspBoxCB, "npcEspBoxCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Toggle On/Off Boxes around NPC's")
  end

   -- Health Added Code --
  ImGui.Indent();  
  npcEspHealthCB, npcEspHealthToggled = HSCheckbox("Toggle NPC Health", npcEspHealthCB, "npcEspHealthCB")
  ImGui.Unindent()
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Toggling this will show you Health for NPC's|Requires NPC ESP Box Enabled!")
  end
  ----------------------

  npcEspTracerCB, npcEspTracerCBToggled = HSCheckbox("NPC ESP Tracer", npcEspTracerCB, "npcEspTracerCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This will draw a line from the NPC to the player")
  end

  npcEspDistance, npcEspDistanceUsed = HSSliderFloat("ESP Max Distance", npcEspDistance, 0, 150, "%.0f", ImGuiSliderFlags.Logarithmic, "npcEspDistance")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This will set how far away the NPC ESP will work")
  end

  npcEspColor, npcEspColorUsed = HSColorEdit4("ESP Color", npcEspColor, "npcEspColor")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Change the color of NPC ESP")
  end

  npcEspColorByDistanceCB, npcEspColorByDistanceToggled = HSCheckbox("ESP Color Change By Distance*", npcEspColorByDistanceCB, "npcEspColorByDistanceCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Color changes based on distance! <50:Red, >50<100:Yellow, <100:Cyan")
  end
  
  ImGui.Text("*Max distance has to be 100+ to work")
end

-- [NPC Upcoming Features] --
function npcEspUpcomingFeatures()
  ImGui.Separator()
  ImGui.Text("Features below are Coming Soon!")

  -- Armor Added Code --
  npcEspArmorCB, npcEspArmorToggled = HSCheckbox("Toggle Armor", npcEspArmorCB, "npcEspArmorCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Toggling this will show you Armor for NPC's")
  end
  ----------------------
end
-- [End of NPC Upcoming Features] --


function calculate_distance(x1, y1, z1, x2, y2, z2)
  return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

-- Function to calculate the color based on distance --
function calculate_color(distance)
    local redDistance = 50
    local yellowDistance = 75
    local cyanDistance = 100

    local redColor = {1, 0, 0, 1}  -- Red
    local yellowColor = {1, 1, 0, 1}  -- Yellow
    local cyanColor = {0, 1, 1, 1}  -- Cyan

    local color

    if distance <= redDistance then
        color = redColor
    elseif distance <= yellowDistance then
        local t = (distance - redDistance) / (yellowDistance - redDistance)
        color = {
            redColor[1] + (yellowColor[1] - redColor[1]) * t,
            redColor[2] + (yellowColor[2] - redColor[2]) * t,
            redColor[3] + (yellowColor[3] - redColor[3]) * t,
            1
        }
    elseif distance <= cyanDistance then
        local t = (distance - yellowDistance) / (cyanDistance - yellowDistance)
        color = {
            yellowColor[1] + (cyanColor[1] - yellowColor[1]) * t,
            yellowColor[2] + (cyanColor[2] - yellowColor[2]) * t,
            yellowColor[3] + (cyanColor[3] - yellowColor[3]) * t,
            1
        }
    else
        color = cyanColor
    end

    return color
end

-- Function to draw Colored Rectangle based on "distance" --
function draw_rect(x, y, width, height, color)
    GRAPHICS.DRAW_RECT(x, y, width, height, math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), math.floor(color[4] * 255), false)
end

-- Function to draw Red Rectangle --
function draw_redrect(x, y, width, height)
  GRAPHICS.DRAW_RECT(x, y, width, height, math.floor(npcEspColor[1] * 255), math.floor(npcEspColor[2] * 255), math.floor(npcEspColor[3] * 255), math.floor(npcEspColor[4] * 255), false)
end

-- Function to calculate the health percentage --
function calculate_health_percentage(currentHealth, maxHealth)
    return currentHealth / maxHealth 
end

-- Function to draw Health Line under NPC --
function draw_health_line(x, y, width, healthPercentage, color)
    local lineLength = width * healthPercentage -- Scale the length based on health percentage (0 to 1)
    local lineWidth = 0.005  -- Width of the health bar line
    
    -- Shift the start point of the line to align with the left edge of the box
    local startX = x - (lineLength / 25)

     -- Change the color to yellow if health percentage is below a threshold
    if healthPercentage < 1.0 and healthPercentage >= 0.7 then
        color = {1, 1, 0, 1}  -- Yellow color
    elseif healthPercentage <= 0.7 then
        color = {1, 0, 0, 1}  -- Red color
    end
    
    

    -- Draw the health bar line
    GRAPHICS.DRAW_LINE(startX, y, startX + lineLength, y, math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), math.floor(color[4] * 255))
    
    -- Draw a rectangle to represent the health bar
    GRAPHICS.DRAW_RECT(startX, y - lineWidth / 2, lineLength, lineWidth, math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), math.floor(color[4] * 255), false)
end

-- Register looped script for NPC ESP --
script.register_looped("HS NPC ESP Loop", function(npcEspLoop)
    if npcEspCB then
        local player = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(player, true)
        local allPeds = entities.get_all_peds_as_handles()
        for i, ped in ipairs(allPeds) do
            if ENTITY.DOES_ENTITY_EXIST(ped) and not PED.IS_PED_A_PLAYER(ped) and PED.IS_PED_HUMAN(ped) and not PED.IS_PED_DEAD_OR_DYING(ped, true) then
                local pedCoords = ENTITY.GET_ENTITY_COORDS(ped, true)
                local distance = SYSTEM.VDIST(playerCoords.x, playerCoords.y, playerCoords.z, pedCoords.x, pedCoords.y, pedCoords.z)
                if distance <= npcEspDistance then
                    local pedEnemy = PED.IS_PED_IN_COMBAT(ped, player)
                    local success, screenX, screenY = GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(pedCoords.x, pedCoords.y, pedCoords.z, 0.0, 0.0)
                    if success then
                        if npcEspBoxCB and (not npcEspShowEnemiesCB or pedEnemy) then
                            local camCoords = CAM.GET_GAMEPLAY_CAM_COORD()
                            local distanceToCam = calculate_distance(pedCoords.x, pedCoords.y, pedCoords.z, camCoords.x, camCoords.y, camCoords.z)

                            -- Size of the box based on the distance to the camera
                            local boxSize = 2 * (1 / distanceToCam)

                            -- Minimum box thickness
                            local minThickness = 0.001

                            -- Thickness of the outline based on the distance to the camera, with a lower limit
                            local thickness = math.max(minThickness, 0.0015 * (1 / distanceToCam))

                            -- Call the functions to draw the box
                            draw_redrect(screenX, screenY - boxSize / 2  + 0.001, boxSize / 4, thickness) -- Top
                            draw_redrect(screenX, screenY + boxSize / 2  - 0.001, boxSize / 4, thickness) -- Bottom
                            draw_redrect(screenX - boxSize / 8, screenY, thickness, boxSize - 2 * thickness) -- Left
                            draw_redrect(screenX + boxSize / 8, screenY, thickness, boxSize - 2 * thickness) -- Right

                            if npcEspHealthCB then
                               local maxHealth = ENTITY.GET_ENTITY_MAX_HEALTH(ped)
                               local currentHealth = ENTITY.GET_ENTITY_HEALTH(ped)
                               --local healthPercentage = currentHealth / maxHealth
                               local healthPercentage = calculate_health_percentage(currentHealth, maxHealth)
                               local healthLineY = screenY + boxSize / 2 + thickness + 0.005 
                               draw_health_line(screenX, healthLineY, boxSize / 4, healthPercentage, {0, 1, 0, 1}) -- Green line
                            end
                        end

                        if npcEspTracerCB and (not npcEspShowEnemiesCB or pedEnemy) then
                            GRAPHICS.DRAW_LINE(playerCoords.x, playerCoords.y, playerCoords.z, pedCoords.x, pedCoords.y, pedCoords.z, math.floor(npcEspColor[1] * 255), math.floor(npcEspColor[2] * 255), math.floor(npcEspColor[3] * 255), math.floor(npcEspColor[4] * 255))
                        end

                        if npcEspColorByDistanceCB and (npcEspBoxCB or npcEspTracerCB) and (not npcEspShowEnemiesCB or pedEnemy) then
                            local color = calculate_color(distance)
                            if npcEspTracerCB then
                                GRAPHICS.DRAW_LINE(playerCoords.x, playerCoords.y, playerCoords.z, pedCoords.x, pedCoords.y, pedCoords.z, math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), math.floor(color[4] * 255))
                            end
                            if npcEspBoxCB then
                                local camCoords = CAM.GET_GAMEPLAY_CAM_COORD()
                                local distanceToCam = calculate_distance(pedCoords.x, pedCoords.y, pedCoords.z, camCoords.x, camCoords.y, camCoords.z)
                                local boxSize = 2 * (1 / distanceToCam)
                                local minThickness = 0.001
                                local thickness = math.max(minThickness, 0.0015 * (1 / distanceToCam))
                                draw_rect(screenX, screenY - boxSize / 2 + 0.001, boxSize / 4, thickness, color) -- Top
                                draw_rect(screenX, screenY + boxSize / 2 - 0.001, boxSize / 4, thickness, color) -- Bottom
                                draw_rect(screenX - boxSize / 8, screenY, thickness, boxSize - 2 * thickness, color) -- Left
                                draw_rect(screenX + boxSize / 8, screenY, thickness, boxSize - 2 * thickness, color) -- Right
                            end
                        end
                    end
                end
            end
        end
    end
end)
--[End of ESP]--


--[Start of 'User' Tab]--
UserTab:add_imgui(function()
  playerSpeedTab()
end)

--[Player Movement Speed]--
local walkCB = readFromConfig("walkCB")
local walkSpeed = readFromConfig("walkSpeed")
local swimCB = readFromConfig("swimCB")
local swimSpeed = readFromConfig("swimSpeed")

function playerSpeedTab()
ImGui.Text("User Movement Section")
  walkCB, walkCBUsed = HSCheckbox("Walk/Run Speed Multiplier", walkCB, "walkCB")
  walkSpeed, walkSpeedUsed = HSSliderFloat("Walk speed multiplier", walkSpeed, 1, 1.49, "%.1f", ImGuiSliderFlags.Logarithmic, "walkSpeed")
  swimCB, swimCBUsed = HSCheckbox("Swim Speed Multiplier", swimCB, "swimCB")
  swimSpeed, swimSpeedUsed = HSSliderFloat("Swim speed multiplier", swimSpeed, 1, 1.49, "%.1f", ImGuiSliderFlags.Logarithmic, "swimSpeed")
  --Added To split sections--
  ImGui.Separator()
  ---------------------------
end

script.run_in_fiber(function(playerSpeedMultiplier)
  while true do
    if walkCB then
      PLAYER.SET_RUN_SPRINT_MULTIPLIER_FOR_PLAYER(PLAYER.PLAYER_ID(), walkSpeed)
    else
      PLAYER.SET_RUN_SPRINT_MULTIPLIER_FOR_PLAYER(PLAYER.PLAYER_ID(), 1.0)
    end
    if swimCB then
      PLAYER.SET_SWIM_MULTIPLIER_FOR_PLAYER(PLAYER.PLAYER_ID(), swimSpeed)
    else
      PLAYER.SET_SWIM_MULTIPLIER_FOR_PLAYER(PLAYER.PLAYER_ID(), 1.0)
    end
    playerSpeedMultiplier:yield()
  end
end)
--[End of Player Movement Speed]--

--[End of User Tab]--



--[Vehicle Tabs]--

--[Vehicle Settings Tab]--
VehicleSettingsTab:add_imgui(function()
 autoFlipVehicleTab()
 ImGui.Button("Bring PV")
 if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Bring Personal Vehicle to player/automatically hop in")
    end
    if ImGui.IsItemClicked() then
    command.call("bringpv",{})
  end
  ImGui.SameLine()

  ImGui.Button("Repair PV")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Repair current Personal Vehicle")
    end
    if ImGui.IsItemClicked() then
    command.call("repairpv", {})
  end
  ImGui.SameLine()

  ImGui.Button("TP into PV")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Teleport into Personal Vehicle")
    end
    if ImGui.IsItemClicked() then 
    command.call("pvtp",{})
  end
  ImGui.Separator()

  ImGui.Text("Coming Soon?")
  ImGui.Button("Return PV to Storage")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Return Personal Vehicle to Storage")
    end
    if ImGui.IsItemClicked() then
    command.call("returnpv", {})
  end

 --NEED TO GET WORKING | ROCKET BOOST--
  ImGui.Checkbox("Activate Rocket Ability", rocketBoostEnabled)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Activate the rocket ability for your vehicle")
    end
    if ImGui.IsItemClicked(0) then
        --ToggleRocketAbility()
    end
----------------------------------------
end)

--[[Auto Flip Vehicle -> Vehicle Settings]]--
local autoFlipVehicleCB = readFromConfig("autoFlipVehicleCB")
function autoFlipVehicleTab()
  autoFlipVehicleCB, autoFlipVehicleToggled = HSCheckbox("Auto Flip Vehicle", autoFlipVehicleCB, "autoFlipVehicleCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This will automatically flip your vehicle upright if it is upside down")
    end
end

script.register_looped("HS Auto Flip Vehicle Loop", function(flipLoop)
  if autoFlipVehicleCB then
    local players = PLAYER.PLAYER_PED_ID()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(players, false)
    if vehicle ~= 0 then
      if ENTITY.IS_ENTITY_UPSIDEDOWN(vehicle) then
        local getrot = ENTITY.GET_ENTITY_ROTATION(vehicle, 1)
        local forwardVector = ENTITY.GET_ENTITY_FORWARD_VECTOR(vehicle)
        ENTITY.SET_ENTITY_ROTATION(vehicle, forwardVector.x, forwardVector.y, getrot.z, 1, true)
      end
    end
    flipLoop:sleep(1000)
  end
end)
--[End of Auto Flip Vehicle]--




--[End of Vehicle Settings Tab]


--[Vehicle Movement Tab]--
VehicleMovementTab:add_imgui(function()
    setVehicleMaxSpeed()
    setVehicleForwardSpeed()
    ImGui.Separator();ImGui.Spacing()
end)

--[Vehicle Max Speed]--
local maxSpeedCB = readFromConfig("maxSpeedCB")
local speedLimit = readFromConfig("speedLimit")
function setVehicleMaxSpeed()
  ImGui.Text("Vehicle Movement Speed")
  maxSpeedCB, maxSpeedToggled = HSCheckbox("Set Vehicle Max Speed", maxSpeedCB, "maxSpeedCB")
   if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This will set your vehicle's max speed to the speed you set")
    end
  speedLimit, speedLimitUsed = HSSliderInt("Speed Limit", speedLimit, 1, 1000, "speedLimit")
end

script.register_looped("HS Set Vehicle Max Speed Loop", function(setVehicleMaxSpeed)
  if maxSpeedCB then
    local speed = speedLimit
    local CurrentVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
    VEHICLE.SET_VEHICLE_MAX_SPEED(CurrentVeh, speed)
  else
    local CurrentVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
    VEHICLE.SET_VEHICLE_MAX_SPEED(CurrentVeh, 0.0)
  end
end)
--[End of Vehicle Max Speed]--

--[Vehicle Foward Speed]--
local forwardSpeedCB = readFromConfig("forwardSpeedCB")
local speedBoost = readFromConfig("speedBoost")
function setVehicleForwardSpeed()
  forwardSpeedCB, forwardSpeedToggled = HSCheckbox("Set Vehicle Forward Speed", forwardSpeedCB, "forwardSpeedCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("When enabled, press \"W\" to go forward at the speed you set")
    end
  speedBoost, speedBoostUsed = HSSliderInt("Boosted Speed", speedBoost, 1, 1000, "speedBoost")
end

script.register_looped("HS Set Vehicle Forward Speed Loop", function(setVehicleForwardSpeed)
  if forwardSpeedCB and PAD.IS_CONTROL_PRESSED(0, 71) and PED.IS_PED_IN_VEHICLE(PLAYER.PLAYER_PED_ID(), PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true), false) then
    local speed = speedBoost
    local CurrentVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
    VEHICLE.SET_VEHICLE_FORWARD_SPEED(CurrentVeh, speed)
  end
end)
--[End of Vehicle Foward Speed]--

--[End of Vehicle Movement Tab]--



--[Drift Tab]--
DriftTab:add_imgui(function()
  shiftDriftTab()
end)
local shiftDriftCB = readFromConfig("shiftDriftCB")
local driftAmount = readFromConfig("driftAmount")
local driftTyresCB = readFromConfig("driftTyresCB")
function shiftDriftTab()
ImGui.Text("Enable Shift-Drift to get access to Low Grip Tires")
  shiftDriftCB, shiftDriftToggled = HSCheckbox("Shift Drift", shiftDriftCB, "shiftDriftCB")
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Enable Shift Drifting")
    end
  if shiftDriftToggled then
    if not shiftDriftCB then
      driftTyresCB = false
      saveToConfig("driftTyresCB", false)
    end
  end
  HSshowTooltip("Press \"Shift\" to drift")
  if shiftDriftCB then
    driftTyresCB, driftTyresToggled = HSCheckbox("Use Low Grip Tires", driftTyresCB, "driftTyresCB")
    if ImGui.IsItemHovered() then
    ImGui.SetTooltip("This will use GTAV's Low Grip Tires for drifting instead")
    end
  end
  if not driftTyresCB then
    driftAmount, driftAmountUsed = HSSliderInt("Drift Amount", driftAmount, 0, 3, "driftAmount")
    if ImGui.IsItemHovered() then
    ImGui.SetTooltip("0 = Loosest Drift\n1 = Loose Drift (Recommended)\n2 = Stiff Drift\n3 = Stiffest Drift")
    end
  end
end

script.register_looped("HS Shift Drift Loop", function(driftLoop)
  local CurrentVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
  if driftTyresCB and PAD.IS_CONTROL_PRESSED(0, 21) then
    VEHICLE.SET_DRIFT_TYRES(CurrentVeh, true)
  else 
    VEHICLE.SET_DRIFT_TYRES(CurrentVeh, false)
  end
  if shiftDriftCB and PAD.IS_CONTROL_PRESSED(0, 21) and not driftTyresCB then
    VEHICLE.SET_VEHICLE_REDUCE_GRIP(CurrentVeh, true)
    VEHICLE.SET_VEHICLE_REDUCE_GRIP_LEVEL(CurrentVeh, driftAmount)
  else
    VEHICLE.SET_VEHICLE_REDUCE_GRIP(CurrentVeh, false)
  end
end)
--[End of Drift Tab]--



--[End of Vehicle Tabs]--

--[Teleport Options Tab]--
TeleportTab:add_imgui(function()
    quickTeleportTab()
  ImGui.Separator();ImGui.Spacing()
end)

--[Quick Teleport -> Teleport Options]--


local teleportLocations = {}
local drawMarker = readFromConfig("drawMarker")

function quickTeleportTab()
  local player = PLAYER.PLAYER_PED_ID()
  local currentCoords = ENTITY.GET_ENTITY_COORDS(player, true)
  
  ImGui.BulletText("Quick Teleport")

  if ImGui.Button("Save Current Location") then
    local heading = ENTITY.GET_ENTITY_HEADING(player)
    teleportLocations[1] = {currentCoords.x, currentCoords.y, currentCoords.z, heading}
    HSNotification("Saved current location!")
    HSConsoleLogDebug("Saved current location")
    HSConsoleLogDebug("Saved location: x = " .. currentCoords.x .. ", y = " .. currentCoords.y .. ", z = " .. currentCoords.z .. ", heading = " .. heading)
  end

  if teleportLocations[1] ~= nil then
    local savedLocation = teleportLocations[1]
    ImGui.Text(string.format("Current location: X=%.2f, Y=%.2f, Z=%.2f", savedLocation[1], savedLocation[2], savedLocation[3]))
    
    local dx = savedLocation[1] - currentCoords.x
    local dy = savedLocation[2] - currentCoords.y
    local dz = savedLocation[3] - currentCoords.z
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
    ImGui.Text(string.format("Distance to saved location: %.0f meters", distance))
    
    if ImGui.Button("Teleport to Saved Location") then
      PED.SET_PED_COORDS_KEEP_VEHICLE(player, savedLocation[1], savedLocation[2], savedLocation[3])
      ENTITY.SET_ENTITY_HEADING(player, savedLocation[4])
      HSNotification("Teleported to saved location!")
      HSConsoleLogDebug("Teleported to saved location")
    end

    ImGui.Separator()
    drawMarker, drawMarkerToggled = HSCheckbox("Draw Marker", drawMarker, "drawMarker")
  end
end

script.register_looped("HS Draw Marker Loop", function(drawMarkerLoop)
  if drawMarker then
    local player = PLAYER.PLAYER_PED_ID()
    local savedLocation = teleportLocations[1]
    if savedLocation ~= nil then
      GRAPHICS.DRAW_MARKER_EX(1, savedLocation[1], savedLocation[2], savedLocation[3], 0, 0, 0, 0, 0, 0, 2.0, 2.0, savedLocation[3] + 1500.0, 255, 255, 255, 100, false, false, 2, false, "", "", false, true, true)
    end
  end
end)


--[End of Teleport Options Tab]--

--[Start of Heist Tab]--
-- Heist Section was Taken from @Alestarov --
-- Reworked and added some code --

CayoH = HeistTab:add_tab("Cayo Perico Heist")

CayoH:add_text("---[Difficulty Modes]---")

CayoH:add_button("Setup Normal", function()
    PlayerIndex = globals.get_int(1574918)
    if PlayerIndex == 0 then
        mpx = "MP0_"
    else
        mpx = "MP1_"
    end
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 126823, true)
end)

CayoH:add_sameline()

CayoH:add_button("Setup Hard", function()
    PlayerIndex = globals.get_int(1574918)
    if PlayerIndex == 0 then
        mpx = "MP0_"
    else
        mpx = "MP1_"
    end
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 131055, true)
end)

CayoH:add_separator()

CayoH:add_text("---[Heist Robbery Item(s)]---")

CayoH:add_button("Setup SOLO Pink Diamond", function()
    PlayerIndex = globals.get_int(1574918)
	if PlayerIndex == 0 then
		mpx = "MP0_"
	else
		mpx = "MP1_"
	end
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_GEN"), 131071, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ENTR"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ABIL"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEAPONS"), 5, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEP_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_ARM_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_HEL_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TARGET"), 3, true) -- Change this to 3 for Pink Diamond
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TROJAN"), 2, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_APPROACH"), -1, true)

        -- Island Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I"), 0, true)

        -- Compound Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT"), -1, true) -- Set all paintings
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 126823, true)

        -- These are what is set when you find loot throughout the island/compound
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C_SCOPED"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C_SCOPED"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT_SCOPED"), -1, true) -- Set all paintings scoped
       
        STATS.STAT_SET_INT(joaat(mpx .. "H4_MISSIONS"), 65535, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PLAYTHROUGH_STATUS"), 32, true)

         gui.show_message("[Cayo Heist]", "SOLO Pink Diamond Mode has been set up")
        gui.show_message("[Cayo Heist]", "Reset the board to see the changes")
end)

CayoH:add_button("Setup TEAM Pink Diamond", function()
    PlayerIndex = globals.get_int(1574918)
	if PlayerIndex == 0 then
		mpx = "MP0_"
	else
		mpx = "MP1_"
	end
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_GEN"), 131071, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ENTR"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ABIL"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEAPONS"), 5, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEP_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_ARM_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_HEL_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TARGET"), 3, true) -- Change this to 3 for Pink Diamond
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TROJAN"), 2, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_APPROACH"), -1, true)

        -- Island Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I"), -1, true) -- Set all gold

        -- Compound Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C"), 0, true) -- Set all gold (COMPOUND?)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT"), 0, true) -- paintings
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 126823, true)

        -- These are what is set when you find loot throughout the island/compound
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C_SCOPED"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I_SCOPED"), -1, true) -- Set all gold scoped
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C_SCOPED"), 0, true) -- Set all gold scoped(COMPOUND?)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT_SCOPED"), 0, true)  -- paintings scoped

        STATS.STAT_SET_INT(joaat(mpx .. "H4_MISSIONS"), 65535, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PLAYTHROUGH_STATUS"), 32, true)

        gui.show_message("[Cayo Heist]", "Team Pink Diamond Mode has been set up")
        gui.show_message("[Cayo Heist]", "Reset the board to see the changes")
end)


CayoH:add_text("--------------------")

CayoH:add_button("Setup SOLO Panther", function()
    PlayerIndex = globals.get_int(1574918)
	if PlayerIndex == 0 then
		mpx = "MP0_"
	else
		mpx = "MP1_"
	end
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_GEN"), 131071, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ENTR"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ABIL"), 63, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEAPONS"), 5, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_WEP_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_ARM_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_HEL_DISRP"), 3, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TARGET"), 5, true) --Primary Target Values: 0. Tequila, 1. Necklace, 2. Bonds, 3. Diamond, 4. Medrazo Files, 5. Panther
		STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_TROJAN"), 2, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_APPROACH"), -1, true)

        -- Island Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I"), 0, true)

        -- Compound Loot // -1 shows all, 0 shows none
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT"), -1, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 126823, true)

        -- These are what is set when you find loot throughout the island/compound
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_CASH_C_SCOPED"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_WEED_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_COKE_C_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_I_SCOPED"), 0, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_GOLD_C_SCOPED"), 0, true)
		STATS.STAT_SET_INT(joaat(mpx .. "H4LOOT_PAINT_SCOPED"), -1, true)

        STATS.STAT_SET_INT(joaat(mpx .. "H4_MISSIONS"), 65535, true)
        STATS.STAT_SET_INT(joaat(mpx .. "H4_PLAYTHROUGH_STATUS"), 32, true)       

        gui.show_message("[Cayo Heist]", "SOLO Panther Mode has been set up")
        gui.show_message("[Cayo Heist]", "Reset the board to see the changes")
end)

CayoH:add_text("(2Mil Heist DONT ABUSE OR YOU'LL GET BANNED)")
CayoH:add_text("Setup Panther is OP - Use at your own RISK")

CayoH:add_separator()

CayoH:add_text("---[Reset Cayo Settings]---")

CayoH:add_button("Reset", function()
    PlayerIndex = globals.get_int(1574918)
    if PlayerIndex == 0 then
        mpx = "MP0_"
    else
        mpx = "MP1_"
    end
         STATS.STAT_SET_INT(joaat(mpx .. "H4_MISSIONS"), 0, true)
         STATS.STAT_SET_INT(joaat(mpx .. "H4_PROGRESS"), 0, true)
         STATS.STAT_SET_INT(joaat(mpx .. "H4_PLAYTHROUGH_STATUS"), 0, true)
         STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_APPROACH"), 0, true)
         STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_ENTR"), 0, true)
         STATS.STAT_SET_INT(joaat(mpx .. "H4CNF_BS_GEN"), 0, true)       
end)

CayoH:add_separator()

CayoH:add_text("---[Cut Percentages]---")
CPCg1 = 1971648 + 831 + 56 + 1 -- cayo perico player 1 cut global
CPCg2 = 1971648 + 831 + 56 + 2 -- cayo perico player 2 cut global
CPCg3 = 1971648 + 831 + 56 + 3 -- cayo perico player 3 cut global
CPCg4 = 1971648 + 831 + 56 + 4 -- cayo perico player 4 cut global

local cayocut1 = CayoH:add_input_int("Cut 1")
local cayocut2 = CayoH:add_input_int("Cut 2")
local cayocut3 = CayoH:add_input_int("Cut 3")
local cayocut4 = CayoH:add_input_int("Cut 4")

CayoH:add_button("Set",
function ()
	globals.set_int(CPCg1, cayocut1:get_value())
	globals.set_int(CPCg2, cayocut2:get_value())
	globals.set_int(CPCg3, cayocut3:get_value())
	globals.set_int(CPCg4, cayocut4:get_value())
end)

CayoH:add_separator()

CayoH:add_text("---[Remove Camera/Hoplites Section]---")

CayoH:add_button("Remove all cameras", function()
    for _, ent in pairs(entities.get_all_objects_as_handles()) do
        for __, cam in pairs(CamList) do
            if ENTITY.GET_ENTITY_MODEL(ent) == cam then
                ENTITY.SET_ENTITY_AS_MISSION_ENTITY(ent,true,true) --Credit to @nord123#9579
                ENTITY.DELETE_ENTITY(ent)               
            end
        end
    end
end)
CamList = {   --heist control
    joaat("prop_cctv_cam_01a"),
    joaat("prop_cctv_cam_01b"),
    joaat("prop_cctv_cam_02a"),
    joaat("prop_cctv_cam_03a"),
    joaat("prop_cctv_cam_04a"),
    joaat("prop_cctv_cam_04c"),
    joaat("prop_cctv_cam_05a"),
    joaat("prop_cctv_cam_06a"),
    joaat("prop_cctv_cam_07a"),
    joaat("prop_cs_cctv"),
    joaat("p_cctv_s"),
    joaat("hei_prop_bank_cctv_01"),
    joaat("hei_prop_bank_cctv_02"),
    joaat("ch_prop_ch_cctv_cam_02a"),
    joaat("xm_prop_x17_server_farm_cctv_01"),
}

CayoH:add_sameline()

CayoH:add_button("Remove Perico hoplites", function()
    for _, ent in pairs(entities.get_all_peds_as_handles()) do
        if ENTITY.GET_ENTITY_MODEL(ent) == 193469166 then
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(ent,true,true)
            ENTITY.DELETE_ENTITY(ent)
        end
    end
end)

CayoH:add_separator()

CayoH:add_text("---[Quick Teleports]---")

CayoH:add_text("Start with Entrance")
CayoH:add_button("TP to the entrance", function()
            PED.SET_PED_COORDS_KEEP_VEHICLE(PLAYER.PLAYER_PED_ID(), 5048.157, -5821.616, -12.726)
        end)

CayoH:add_text("After opening entrance, teleport to storage")
CayoH:add_button("TP into the storage", function()
            PED.SET_PED_COORDS_KEEP_VEHICLE(PLAYER.PLAYER_PED_ID(), 5007.505, -5755.067, 15.484)
        end)

CayoH:add_text("Teleport to Front gate Exit")
CayoH:add_button("TP to the way out", function()
            PED.SET_PED_COORDS_KEEP_VEHICLE(PLAYER.PLAYER_PED_ID(), 4990.359, -5717.899, 19.880)
        end)

CayoH:add_text("Teleport out into the Ocean to complete!")
CayoH:add_button("TP out to the sea", function()
            PED.SET_PED_COORDS_KEEP_VEHICLE(PLAYER.PLAYER_PED_ID(), 4200.177, -5625.261, -2.69)
        end)


--[End of Heist Tab]--

--[Start of Computer Tab]--
-- Computer Section was Taken from @Alestarov --
ComputerTab:add_text("Works properly in session by invitations. in an open session does not work well")

ComputerTab:add_button("Show Master Control Computer", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("apparcadebusinesshub")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("apparcadebusinesshub")
        else
                gui.show_message("Don't forget to register as CEO/Leader")
                run_script("apparcadebusinesshub")
        end
    end
 end)

 ComputerTab:add_button("Show Nightclub Computer", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("appbusinesshub")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("appbusinesshub")
        else
                gui.show_message("Don't forget to register as CEO/Leader")
                run_script("appbusinesshub")
        end
    end
end)

ComputerTab:add_button("Show Office Computer", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("appfixersecurity")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            globals.set_int(1895156+playerIndex*609+10+429+1,0)
            gui.show_message("prompt","Converted to CEO")
            run_script("appfixersecurity")
            else
            gui.show_message("Don't forget to register as CEO/Leader","It may also be a script detection error, known problem, no feedback required")
            run_script("appfixersecurity")
        end
    end
end)

ComputerTab:add_button("Show Bunker Computer", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("appbunkerbusiness")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("appbunkerbusiness")
            else
                gui.show_message("Don't forget to register as CEO/Leader","It may also be a script detection error, known problem, no feedback required")
                run_script("appbunkerbusiness")
            end
    end
end)

ComputerTab:add_button("Show Hangar Computer", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("appsmuggler")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("appsmuggler")
            else
                gui.show_message("Don't forget to register as CEO/Leader","It may also be a script detection error, known problem, no feedback required")
                run_script("appsmuggler")
            end
    end
end)

ComputerTab:add_button("Show the Terrorist Dashboard", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("apphackertruck")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("apphackertruck")
        else
            gui.show_message("Don't forget to register as CEO/Leader","It may also be a script detection error, known problem, no feedback required")
            run_script("apphackertruck")
        end
    end
end)

ComputerTab:add_button("Show Avengers Panel", function()
    local playerIndex = globals.get_int(1574918)
    if globals.get_int(1895156+playerIndex*609+10+429+1) == 0 then
        run_script("appAvengerOperations")
    else
        if globals.get_int(1895156+playerIndex*609+10+429+1) == 1 then
            run_script("appAvengerOperations")
        else
            gui.show_message("Don't forget to register as CEO/Leader","It may also be a script detection error, known problem, no feedback required")
            run_script("appAvengerOperations")
        end
    end
end)
--[End of Computer Tab]--


--!!!!!!!!!!NEED TO FIX!!!!!!!!!--
--[ToolTips for hovered text in menus]--

hoverStartTimes = {}
showTooltips = {}
toolTipDelay = 0.2 -- seconds (200ms)

local commonFlags = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse | ImGuiWindowFlags.NoInputs
local fullScreenFlags = ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoBackground | commonFlags
local toolTipFlags = ImGuiWindowFlags.AlwaysAutoResize | commonFlags
local commonChildFlags = ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoBackground | commonFlags

local function GetFullScreenResolution(screenWidth, screenHeight, offsetY)
  ImGui.Begin("", fullScreenFlags)
  ImGui.SetNextWindowPos(screenWidth / 2, screenHeight - offsetY, ImGuiCond.Always, 0.5, 1.0)
end

local function displayToolTipWindow(textWidth, totalHeight)
  ImGui.BeginChild("Message Window (Tooltip text)", textWidth, totalHeight, false, commonChildFlags)
end

local function displayHotkeyInfo()
  ImGui.SameLine(); ImGui.Dummy(10, 1)
  ImGui.SameLine(); ImGui.BeginGroup()
  ImGui.Text("Set Hotkey: F12 (WIP)")
  ImGui.Text("Current Hotkey: None (WIP)")
  ImGui.EndGroup()
  ImGui.End()
end


function HSshowTooltip(message, specialMessage, smColor)
  if ImGui.IsItemHovered() then
    hoverStartTimes[message] = hoverStartTimes[message] or os.clock()
    if os.clock() - hoverStartTimes[message] >= toolTipDelay then
      showTooltips[message] = true
      hoverStartTimes[message] = nil
    end
  else
    hoverStartTimes[message] = nil
    showTooltips[message] = false
  end
  if showTooltips[message] then
    if toolTipCB and not toolTipV2CB then
      if specialMessage then
        message = message .. "\n\n Note: " .. specialMessage
        ImGui.SetTooltip(message)
      else
        ImGui.SetTooltip(message)
      end
    elseif toolTipV2CB and not toolTipCB then
      local screenWidth, screenHeight = GRAPHICS.GET_ACTUAL_SCREEN_RESOLUTION(0,0)
      GetFullScreenResolution(screenWidth, screenHeight, 100)
      if ImGui.Begin("ToolTip Base", toolTipFlags) then
        local textWidth = 300
        local _, messageHeight = ImGui.CalcTextSize(message, false, textWidth)
        if specialMessage and smColor then
          local _, specialMessageHeight = ImGui.CalcTextSize(specialMessage, false, textWidth)
          local totalHeight = messageHeight + (specialMessageHeight + 10)
          displayToolTipWindow(textWidth, totalHeight)
          ImGui.TextWrapped(message)
          ImGui.PushStyleColor(ImGuiCol.Text, smColor[1], smColor[2], smColor[3], smColor[4])
          ImGui.TextWrapped(specialMessage)
          ImGui.PopStyleColor()
        elseif not specialMessage and not smColor then
          displayToolTipWindow(textWidth, messageHeight)
          ImGui.TextWrapped(message)
        end
        ImGui.EndChild()
        displayHotkeyInfo()
      end
      ImGui.End()
    end
  end
end

--[End of ToolTips for hovered text in menus]--



--[ImGui Functions]--
function HSCheckbox(label, bool_variable, item_tag)
  local newBool, toggled = ImGui.Checkbox(label, bool_variable)
  if toggled then
    bool_variable = newBool
    saveToConfig(item_tag, bool_variable)
  end
  return bool_variable, toggled
end

function HSColorEdit4(label, color_variable, item_tag)
  local newColor, used = ImGui.ColorEdit4(label, color_variable)
  if used then
    color_variable = newColor
    saveToConfig(item_tag, color_variable)
  end
  return color_variable, used
end

function HSSliderFloat(label, float_variable, min, max, format, flags, item_tag)
  local newFloat, used = ImGui.SliderFloat(label, float_variable, min, max, format, flags)
  if used then
    float_variable = newFloat
    saveToConfig(item_tag, float_variable)
  end
  return float_variable, used
end

function HSSliderFloat(label, float_variable, min, max, format, flags, item_tag)
  local newFloat, used = ImGui.SliderFloat(label, float_variable, min, max, format, flags)
  if used then
    float_variable = newFloat
    saveToConfig(item_tag, float_variable)
  end
  return float_variable, used
end

function HSSliderInt(label, int_variable, min, max, item_tag)
  local newInt, used = ImGui.SliderInt(label, int_variable, min, max)
  if used then
    int_variable = newInt
    saveToConfig(item_tag, int_variable)
  end
  return int_variable, used
end

function HSCombobox(label, current_item, items, items_count, popup_max_height_in_items, item_tag)
  local newInt, used = ImGui.Combo(label, current_item, items, items_count, popup_max_height_in_items)
  if used then
    current_item = newInt
    saveToConfig(item_tag, current_item)
  end
  return current_item, used
end

--[End of ImGui Functions]--



--[Console log Functions]--
function HSConsoleLogInfo(message) -- Info
  if HSConsoleLogInfoCB then
    log.info(message)
  end
end
function HSConsoleLogWarn(message) -- Warning
  if HSConsoleLogWarnCB then
    log.warning(message)
  end
end
function HSConsoleLogDebug(message) -- Debug
  if HSConsoleLogDebugCB then
    log.debug(message)
  end
end
--[End of Console Log]--



--[Notification Functions]--
function HSNotification(message)
  if notifyCB then
    gui.show_message("Rev-Harmless's Scripts", message)
  end
end
--[End of Notifications]--



--[Utility Functions]--
function GetScreenCenter()
  local screenWidth, screenHeight = GetScreenResolution()
  local centerX = screenWidth / 2
  local centerY = screenHeight / 2
  return centerX, centerY
end

function GetScreenResolution()
  local screenWidth, screenHeight = GRAPHICS.GET_ACTUAL_SCREEN_RESOLUTION(0,0)
  return screenWidth, screenHeight
end
--[End of Utility Functions]--


function run_script(name) --start script thread
    script.run_in_fiber(function (runscript)
        SCRIPT.REQUEST_SCRIPT(name)  
        repeat runscript:yield() until SCRIPT.HAS_SCRIPT_LOADED(name)
        SYSTEM.START_NEW_SCRIPT(name, 5000)
        SCRIPT.SET_SCRIPT_AS_NO_LONGER_NEEDED(name)
    end)
end
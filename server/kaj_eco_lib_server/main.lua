local M = {}
local money = {}
local config = {}
local folderOfThisFile = "Resources/Server/kaj_eco_lib_server/"
local json = require('Resources.Server.kaj_eco_lib_server.json')
local secondCount = 60


function clientRequestMoney(client)
    MP.TriggerClientEvent(client, "recieveMoneyValue", getPlayerMoney(client))
end

function getPlayerMoney(player)
    local discordID = GetPlayerDiscordID(player)
    if money[discordID] == nil then
        money[discordID] = config.startingBalance
    end
    return money[discordID]
end

function loadMoney()
    local file = io.open(folderOfThisFile.."DB/data.json", "r")
    content = file:read("*a")
    if content and content ~= "" then
        money = json.decode(content)
        file:close()
    end
end

function saveMoney()
    local file = assert(io.open(folderOfThisFile.."DB/data.json", "w"))
    file:write(json.encode(money))
    file:close()
    updateMoneyForAllPlayers()
end

function changeMoney(user, amount)
    local discordID = GetPlayerDiscordID(user)
    if money[discordID] == nil then
        money[discordID] = 0
    end
    money[discordID] = money[discordID] + amount
    if money[discordID] < 0 and config.balanceCanBeNegative == false then
        money[discordID] = 0
    end
end

function loadConfig()
    local file = io.open(folderOfThisFile.."config.json", "rb")
    content = file:read("*a")
    config = json.decode(content)
    file:close()
end

function updateMoneyForAllPlayers()
    if config.clientModInstalled == true and MP.GetPlayers() ~= nil then
        for id, name in pairs(MP.GetPlayers()) do
            MP.TriggerClientEvent(id, "recieveMoneyValue", getPlayerMoney(id))
        end
    end
end

function getPlayerIDFromName(player)
    for id,name in pairs(MP.GetPlayers()) do
        if name == player then
            return id
        end
    end
end

function giveMoneyThread()
    secondCount = secondCount - 1
    p = MP.GetPlayers()
    if next(p) ~= nil and secondCount <= 0 then
      secondCount = 60
      for id, name in pairs(MP.GetPlayers()) do
          changeMoney(id, config.moneyPerMinute)
      end
      saveMoney()
    end
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function abs(number)
    if number < 0 then
      number = number*-1
      return number
    else
        return number
    end
end

function onChatMessage(id, name, message)
    print(name..":"..message)
    if message:find("^ /") ~= nil then
        if message == ' /balance' then
            MP.SendChatMessage(id, "Balance: "..config.currencySymbol..tostring(getPlayerMoney(id)))
        end
        if message == ' /top' then
            MP.SendChatMessage(id, "This is coming soon!")
        end
        if message:find("^ /pay") ~= nil and config.clientsCanPayOthers == true then
            message = string.sub(message, 7)
            local cmdArgs = split(message, " ")
            local player = getPlayerIDFromName(cmdArgs[1])
            local amount = abs(tonumber(cmdArgs[2]))
            if player == nil then
              MP.SendChatMessage(id, "Could not find player to send money to.")
            elseif getPlayerMoney(id) >= amount then
                changeMoney(id, -amount)
                changeMoney(player, amount)
                saveMoney()
                MP.SendChatMessage(id, "You sent "..config.currencySymbol..tostring(amount).." to "..cmdArgs[1])
                MP.SendChatMessage(player, MP.GetPlayerName(id).." sent you "..config.currencySymbol..tostring(amount))
            end
        end
        return 1
    end
end

function onInit()
    MP.RegisterEvent("clientRequestMoney", "clientRequestMoney") -- used by the client to request their money value
    MP.RegisterEvent("onChatMessage", "onChatMessage") -- used buy the server to register commands
    MP.RegisterEvent("changeMoney", "changeMoney") -- used by other plugins to change money of players. Pass in a server ID and amount (can be negative)
    MP.RegisterEvent("loadMoney", "loadMoney") -- trigger to load money from disk
    MP.RegisterEvent("saveMoney", "saveMoney") -- trigger to save money to disk (will send to players if using client sided mod)
    loadMoney()
    loadConfig()
    if config.moneyPerMinute > 0 then
        MP.RegisterEvent("giveMoneyThread", "giveMoneyThread")
        MP.CancelEventTimer("giveMoneyThread") -- Cancel first in case of lua state reload
        MP.CreateEventTimer("giveMoneyThread", 1000)
    end
    print("-----------------------------------------")
    print("loaded kaj eco library v"..config.version)
    print("-----------------------------------------")
end

return M
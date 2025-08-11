local Framework = nil

CreateThread(function()
    if Config.Framework == 'qb' then
        Framework = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == 'esx' then
        TriggerEvent('esx:getSharedObject', function(obj) Framework = obj end)
    end
    while Framework == nil do
        Wait(100)
    end
end)

local function getPlayer(source)
    if Config.Framework == 'qb' then
        return Framework.Functions.GetPlayer(source)
    elseif Config.Framework == 'esx' then
        return Framework.GetPlayerFromId(source)
    end
    return nil
end

local function handlePayment(source, cost)
    local Player = getPlayer(source)
    if not Player then return false end

    local moneyType = 'cash'
    local hasEnoughMoney = false

    if Config.Framework == 'qb' then
        local cash = Player.Functions.GetMoney('cash')
        local bank = Player.Functions.GetMoney('bank')
        if cash >= cost then
            hasEnoughMoney = Player.Functions.RemoveMoney('cash', cost, "grandma-service")
            moneyType = 'cash'
        elseif bank >= cost then
            hasEnoughMoney = Player.Functions.RemoveMoney('bank', cost, "grandma-service")
            moneyType = 'bank'
        end
    elseif Config.Framework == 'esx' then
        local cash = Player.getMoney()
        local bank = Player.getAccount('bank').money
        if cash >= cost then
            Player.removeMoney(cost)
            hasEnoughMoney = true
            moneyType = 'cash'
        elseif bank >= cost then
            Player.removeAccountMoney('bank', cost)
            hasEnoughMoney = true
            moneyType = 'bank'
        end
    end

    if hasEnoughMoney then
        return true, moneyType
    else
        return false, nil
    end
end

RegisterServerEvent('lf-grandma:heal', function()
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    local success, moneyType = handlePayment(src, Config.HealCost)

    if success then
        TriggerClientEvent('lf-grandma:client:playAnimation', -1, 'heal')
        TriggerClientEvent('lf-grandma:client:healEffect', src)
        sendNotification(src, 'success', 'Grandma is healing you for $'..Config.HealCost..' ('..moneyType..').')
        logToDiscord(src, 'Healed themselves.')
    else
        sendNotification(src, 'error', 'You do not have enough money. Grandma needs $'..Config.HealCost..'.')
    end
end)

RegisterServerEvent('lf-grandma:revive', function()
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    local success, moneyType = handlePayment(src, Config.ReviveCost)

    if success then
        TriggerClientEvent('lf-grandma:client:playAnimation', -1, 'revive')
        TriggerClientEvent('lf-grandma:client:reviveEffect', src)
        sendNotification(src, 'success', 'Grandma is reviving you for $'..Config.ReviveCost..' ('..moneyType..').')
        logToDiscord(src, 'Revived themselves.')
    else
        sendNotification(src, 'error', 'You do not have enough money. Grandma needs $'..Config.ReviveCost..'.')
    end
end)

RegisterServerEvent('lf-grandma:reviveOther', function(targetId)
    local src = source
    local targetPlayer = getPlayer(targetId)

    if not targetPlayer then
        sendNotification(src, 'error', 'That player ID was not found.')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not DoesEntityExist(targetPed) then
        sendNotification(src, 'error', 'Could not find that player.')
        return
    end
    
    
    local targetCoords = GetEntityCoords(targetPed)
    local grandmaCoords = Config.Coords.xyz
    local distance = #(targetCoords - grandmaCoords)

    if distance > Config.ReviveZoneRadius then
        sendNotification(src, 'error', 'The downed player is too far from Grandma. They must be within '..Config.ReviveZoneRadius..'m.')
        return
    end

    local success, moneyType = handlePayment(src, Config.ReviveCost)
    if success then
        TriggerClientEvent('lf-grandma:client:playAnimation', -1, 'revive')
        TriggerClientEvent('lf-grandma:client:reviveEffect', targetId)
        sendNotification(src, 'success', 'You revived player '..targetId..' for $'..Config.ReviveCost..' ('..moneyType..').')
        sendNotification(targetId, 'success', 'You were revived thanks to a kind stranger and Grandma!')
        logToDiscord(src, 'Revived player ID: '..targetId)
    else
        sendNotification(src, 'error', 'You do not have enough money. Grandma needs $'..Config.ReviveCost..'.')
    end
end)

function sendNotification(source, type, message)
    if Config.Notify == 'ox' then
        TriggerClientEvent('ox_lib:notify', source, {type = type, description = message})
    elseif Config.Notify == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    end
end

function logToDiscord(source, action)
    if not Config.Webhook or Config.Webhook == 'YOUR_URL_HERE' then return end

    local player = getPlayer(source)
    if not player then return end

    local name = "Unknown"
    if Config.Framework == 'qb' then
        name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    elseif Config.Framework == 'esx' then
        name = player.getName()
    end

    local embed = {
        {
            title = "Grandma Service Log",
            description = action .. "\n**Action performed by:** " .. name .. " (ID: " .. source .. ")",
            color = 16148910,
            footer = {text = "Grandma Services | " .. os.date("%x %X")}
        }
    }

    PerformHttpRequest(Config.Webhook, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), {['Content-Type'] = 'application/json'})
end
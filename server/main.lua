-- =====================================================================
--  lf-grandma | Server
-- ---------------------------------------------------------------------
--  All gameplay decisions live here. The client only ever *asks* for a
--  service; the server independently re-checks distance, death state,
--  cooldowns and payment before granting it. Nothing the client sends
--  is trusted.
-- =====================================================================

local cooldowns = {} -- cooldowns[src][serviceKey] = os.time() when allowed again

-- --- notifications ----------------------------------------------------

local notifyKind
local function resolveNotify()
    if notifyKind then return notifyKind end
    if Config.Notify ~= 'auto' then
        notifyKind = Config.Notify
    elseif GetResourceState('ox_lib') ~= 'missing' then
        notifyKind = 'ox'
    elseif Bridge.Framework() == 'esx' then
        notifyKind = 'esx'
    else
        notifyKind = 'qb'
    end
    return notifyKind
end

local function notify(src, kind, message)
    local sys = resolveNotify()
    if sys == 'ox' then
        TriggerClientEvent('ox_lib:notify', src, { type = kind, description = message })
    elseif sys == 'esx' then
        TriggerClientEvent('esx:showNotification', src, message)
    else
        TriggerClientEvent('QBCore:Notify', src, message, kind)
    end
end

-- --- discord logging --------------------------------------------------

local function logToDiscord(title, description, color)
    if not Config.Webhook or Config.Webhook == '' or Config.Webhook == 'YOUR_URL_HERE' then
        return
    end
    local embed = { {
        title       = title,
        description = description,
        color       = color or Config.LogColor,
        footer      = { text = ('%s | %s'):format(Config.LogName, os.date('%x %X')) },
    } }
    PerformHttpRequest(Config.Webhook, function() end, 'POST',
        json.encode({ username = Config.LogName, embeds = embed }),
        { ['Content-Type'] = 'application/json' })
end

local function logService(src, action, cost, moneyType)
    logToDiscord('Grandma Service',
        ('**%s** (ID: %s)\n%s\nPaid **$%s** (%s)'):format(
            Bridge.GetName(src), src, action, cost, moneyType or 'free'),
        Config.LogColor)
end

local function logSuspicious(src, reason)
    if not Config.LogSuspicious then return end
    logToDiscord('⚠️ Grandma — Rejected Request',
        ('**%s** (ID: %s)\nReason: %s'):format(Bridge.GetName(src), src, reason),
        15158332) -- red
    if Config.Debug then
        print(('[lf-grandma] rejected src=%s reason=%s'):format(src, reason))
    end
end

-- --- helpers ----------------------------------------------------------

local function getPedCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function onCooldown(src, key, seconds)
    if not seconds or seconds <= 0 then return false end
    local now = os.time()
    local ready = cooldowns[src] and cooldowns[src][key]
    if ready and now < ready then
        return true, ready - now
    end
    return false
end

local function startCooldown(src, key, seconds)
    if not seconds or seconds <= 0 then return end
    cooldowns[src] = cooldowns[src] or {}
    cooldowns[src][key] = os.time() + seconds
end

-- Verify items present, then charge money atomically, then consume items.
-- Returns ok, moneyTypeOrReason.
local function charge(src, service)
    local okItems, missing = Bridge.HasItems(src, service.items)
    if not okItems then
        return false, ('You need %sx %s.'):format(missing.amount or 1, missing.name)
    end
    local okMoney, moneyType = Bridge.RemoveMoney(src, service.cost or 0, 'grandma-service')
    if not okMoney then
        return false, ('You need $%s.'):format(service.cost)
    end
    Bridge.RemoveItems(src, service.items)
    return true, moneyType
end

-- Shared front-of-house checks for every service.
-- Returns service, nearestLocation on success; nil, reason on failure.
local function preflight(src, serviceKey)
    local service = Config.Services[serviceKey]
    if not service or not service.enabled then
        return nil, 'This service is disabled.'
    end
    if not Bridge.GetPlayer(src) then
        return nil, 'Your character is not loaded.'
    end

    local onCd, remaining = onCooldown(src, serviceKey, service.cooldown)
    if onCd then
        return nil, ('Grandma needs a moment — try again in %ss.'):format(remaining)
    end

    local coords = getPedCoords(src)
    if not coords then
        return nil, 'Could not verify your position.'
    end
    local near = Locations.IsNear(coords, Config.InteractionDistance)
    if not near then
        return nil, 'You are not close enough to Grandma.', true -- suspicious
    end

    local nearest = Locations.Nearest(coords)
    return service, nearest
end

-- --- service: heal ----------------------------------------------------

RegisterNetEvent('lf-grandma:server:heal', function()
    local src = source
    local service, nearestOrReason, suspicious = preflight(src, 'heal')
    if not service then
        notify(src, 'error', nearestOrReason)
        if suspicious then logSuspicious(src, nearestOrReason) end
        return
    end

    if Bridge.IsDead(src) then
        notify(src, 'error', 'You are down — you need a revive, not a heal.')
        return
    end

    local ok, result = charge(src, service)
    if not ok then
        notify(src, 'error', result)
        return
    end

    startCooldown(src, 'heal', service.cooldown)
    if service.restoreNeeds then Bridge.RestoreNeeds(src) end

    TriggerClientEvent('lf-grandma:client:playAnimation', -1, nearestOrReason.id, 'heal')
    TriggerClientEvent('lf-grandma:client:heal', src)
    notify(src, 'success', ('Grandma patched you up for $%s (%s).'):format(service.cost, result))
    logService(src, 'Healed themselves.', service.cost, result)
end)

-- --- service: revive self ---------------------------------------------

RegisterNetEvent('lf-grandma:server:revive', function()
    local src = source
    local service, nearestOrReason, suspicious = preflight(src, 'revive')
    if not service then
        notify(src, 'error', nearestOrReason)
        if suspicious then logSuspicious(src, nearestOrReason) end
        return
    end

    if not Bridge.IsDead(src) then
        notify(src, 'error', 'You are not down — try Heal Me instead.')
        return
    end

    local ok, result = charge(src, service)
    if not ok then
        notify(src, 'error', result)
        return
    end

    startCooldown(src, 'revive', service.cooldown)
    Bridge.ClearDeathState(src)

    TriggerClientEvent('lf-grandma:client:playAnimation', -1, nearestOrReason.id, 'revive')
    TriggerClientEvent('lf-grandma:client:revive', src)
    notify(src, 'success', ('Grandma brought you back for $%s (%s).'):format(service.cost, result))
    logService(src, 'Revived themselves.', service.cost, result)
end)

-- --- service: revive another player -----------------------------------

RegisterNetEvent('lf-grandma:server:reviveOther', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    local service, nearestOrReason, suspicious = preflight(src, 'reviveOther')
    if not service then
        notify(src, 'error', nearestOrReason)
        if suspicious then logSuspicious(src, nearestOrReason) end
        return
    end

    if not targetId or targetId == src then
        notify(src, 'error', 'Pick another player — use Revive Me for yourself.')
        return
    end
    if not Bridge.GetPlayer(targetId) then
        notify(src, 'error', 'That player ID is not online.')
        return
    end
    if not Bridge.IsDead(targetId) then
        notify(src, 'error', 'That player is not down.')
        return
    end

    local targetCoords = getPedCoords(targetId)
    if not targetCoords or not Locations.IsNear(targetCoords, Config.ReviveZoneRadius) then
        notify(src, 'error', ('The downed player must be within %sm of Grandma.'):format(Config.ReviveZoneRadius))
        logSuspicious(src, 'reviveOther: target out of zone')
        return
    end

    local ok, result = charge(src, service)
    if not ok then
        notify(src, 'error', result)
        return
    end

    startCooldown(src, 'reviveOther', service.cooldown)
    Bridge.ClearDeathState(targetId)

    TriggerClientEvent('lf-grandma:client:playAnimation', -1, nearestOrReason.id, 'revive')
    TriggerClientEvent('lf-grandma:client:revive', targetId)
    notify(src, 'success', ('You paid $%s (%s) to revive player %s.'):format(service.cost, result, targetId))
    notify(targetId, 'success', 'A kind stranger paid Grandma to bring you back!')
    logService(src, ('Revived player %s.'):format(targetId), service.cost, result)
end)

-- --- location sync ----------------------------------------------------

RegisterNetEvent('lf-grandma:server:requestLocations', function()
    TriggerClientEvent('lf-grandma:client:syncLocations', source, Locations.GetAll())
end)

local function broadcastLocations()
    TriggerClientEvent('lf-grandma:client:syncLocations', -1, Locations.GetAll())
end

-- --- creator (admin only) ---------------------------------------------

RegisterNetEvent('lf-grandma:server:createLocation', function(data)
    local src = source
    if not Config.Creator.enabled or not Bridge.IsAdmin(src) then
        logSuspicious(src, 'createLocation without permission')
        return
    end
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return end

    local entry = Locations.Add(data)
    broadcastLocations()
    notify(src, 'success', ('Created Grandma "%s" (%s).'):format(entry.label, entry.id))
    logToDiscord('Grandma — Location Created',
        ('**%s** (ID: %s) created "%s" [%s] at %s, %s, %s'):format(
            Bridge.GetName(src), src, entry.label, entry.id,
            math.floor(entry.coords.x), math.floor(entry.coords.y), math.floor(entry.coords.z)),
        3066993) -- green
end)

RegisterNetEvent('lf-grandma:server:deleteLocation', function(id)
    local src = source
    if not Config.Creator.enabled or not Bridge.IsAdmin(src) then
        logSuspicious(src, 'deleteLocation without permission')
        return
    end

    local ok, msg = Locations.Remove(id)
    notify(src, ok and 'success' or 'error', msg)
    if ok then
        broadcastLocations()
        logToDiscord('Grandma — Location Deleted',
            ('**%s** (ID: %s) deleted location %s'):format(Bridge.GetName(src), src, id),
            15105570) -- orange
    end
end)

-- creator permission check (used by the client before opening the menu)
lib.callback.register('lf-grandma:isAdmin', function(source)
    return Config.Creator.enabled and Bridge.IsAdmin(source)
end)

-- clean up cooldowns on disconnect
AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

-- =====================================================================
--  lf-grandma | Client
-- ---------------------------------------------------------------------
--  Spawns/repaints Grannies from the server's location list, wires up
--  targeting + the menu, plays effects, and keeps a replicated death
--  flag the server reads for its anti-exploit checks.
--
--  ox_lib is a hard dependency, so menus / inputs / progress / notify
--  all go through lib.* — no qb-menu / qb-input needed.
-- =====================================================================

local spawned = {}     -- id -> { ped, blip, scenario }
local locations = {}   -- last synced location list

-- --- system resolution ------------------------------------------------

local function has(resource) return GetResourceState(resource) ~= 'missing' end

local TARGET = (Config.Target == 'auto') and (has('ox_target') and 'ox' or 'qb') or Config.Target
local NOTIFY = (Config.Notify == 'auto') and (has('ox_lib') and 'ox' or (Config.Framework == 'esx' and 'esx' or 'qb')) or Config.Notify
local PROGRESS = (Config.ProgressType == 'auto') and (has('ox_lib') and 'ox' or 'qb') or Config.ProgressType

-- --- ui helpers -------------------------------------------------------

local function notify(kind, message)
    if NOTIFY == 'ox' then
        lib.notify({ type = kind, description = message })
    elseif NOTIFY == 'esx' then
        TriggerEvent('esx:showNotification', message)
    else
        TriggerEvent('QBCore:Notify', message, kind)
    end
end

local function progress(label, duration, useWhileDead)
    if PROGRESS == 'qb' then
        exports['qb-core']:GetCoreObject().Functions.Progressbar(
            'grandma_action', label, duration, useWhileDead, false,
            { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
            {}, {}, {}, function() end, function() end)
        Wait(duration) -- keep callers ordered: effect applies after the bar
        return
    end
    return lib.progressCircle({
        duration = duration,
        label = label,
        useWhileDead = useWhileDead,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
    })
end

local function priceText(service)
    local parts = {}
    if (service.cost or 0) > 0 then parts[#parts + 1] = '$' .. service.cost end
    for _, item in ipairs(service.items or {}) do
        parts[#parts + 1] = ('%sx %s'):format(item.amount or 1, item.name)
    end
    return #parts > 0 and table.concat(parts, ' + ') or 'Free'
end

-- --- death state (replicated to the server) ---------------------------

CreateThread(function()
    local last
    while true do
        local dead = IsEntityDead(PlayerPedId())
        if dead ~= last then
            LocalPlayer.state:set('lf_isDead', dead, true)
            last = dead
        end
        Wait(1000)
    end
end)

-- --- menu -------------------------------------------------------------

local function openMenu()
    local dead = IsEntityDead(PlayerPedId())
    local options = {}

    local heal = Config.Services.heal
    local revive = Config.Services.revive
    local reviveOther = Config.Services.reviveOther

    if not dead and heal.enabled then
        options[#options + 1] = {
            title = 'Heal Me',
            description = priceText(heal),
            icon = 'hand-holding-heart',
            onSelect = function() TriggerServerEvent('lf-grandma:server:heal') end,
        }
    end

    if dead and revive.enabled then
        options[#options + 1] = {
            title = 'Revive Me',
            description = priceText(revive),
            icon = 'heart-pulse',
            onSelect = function() TriggerServerEvent('lf-grandma:server:revive') end,
        }
    end

    if reviveOther.enabled then
        options[#options + 1] = {
            title = 'Revive Another Player',
            description = priceText(reviveOther),
            icon = 'user-plus',
            onSelect = function()
                local input = lib.inputDialog('Revive Player', {
                    { type = 'number', label = 'Player ID', description = 'Server ID of the downed player', required = true, min = 1 },
                })
                if input and input[1] then
                    TriggerServerEvent('lf-grandma:server:reviveOther', tonumber(input[1]))
                end
            end,
        }
    end

    if #options == 0 then
        notify('inform', 'Grandma has nothing for you right now.')
        return
    end

    lib.registerContext({ id = 'grandma_menu', title = "Grandma's Services", options = options })
    lib.showContext('grandma_menu')
end

-- --- ped + blip + target spawning -------------------------------------

local function addTarget(ped)
    if TARGET == 'ox' then
        exports.ox_target:addLocalEntity(ped, { {
            name = 'grandma_interaction',
            icon = 'fas fa-heart',
            label = 'Talk to Grandma',
            distance = 2.5,
            onSelect = openMenu,
        } })
    else
        exports['qb-target']:AddTargetEntity(ped, {
            options = { {
                type = 'client', icon = 'fas fa-heart', label = 'Talk to Grandma',
                action = openMenu,
            } },
            distance = 2.5,
        })
    end
end

local function removeTarget(ped)
    if not DoesEntityExist(ped) then return end
    if TARGET == 'ox' then
        exports.ox_target:removeLocalEntity(ped)
    else
        exports['qb-target']:RemoveTargetEntity(ped)
    end
end

local function makeBlip(entry)
    local cfg = entry.blip
    if cfg == nil then cfg = Config.Blip end -- nil = use global; false = explicitly off
    if not cfg or cfg.enabled == false then return nil end
    local c = entry.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite or 153)
    SetBlipColour(blip, cfg.color or 1)
    SetBlipScale(blip, cfg.scale or 0.8)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or entry.label or 'Grandma')
    EndTextCommandSetBlipName(blip)
    return blip
end

local function spawnGranny(entry)
    local model = entry.model
    local hash = type(model) == 'number' and model or joaat(model)

    if not IsModelValid(hash) or not IsModelInCdimage(hash) then
        if Config.Debug then print(('[lf-grandma] invalid ped model: %s'):format(tostring(model))) end
        return
    end

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10); timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then
        if Config.Debug then print(('[lf-grandma] model failed to load: %s'):format(tostring(model))) end
        return
    end

    local c = entry.coords
    local ped = CreatePed(0, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if entry.scenario then
        TaskStartScenarioAtPosition(ped, entry.scenario, c.x, c.y, c.z - 1.0, c.w, 0, true, false)
    end

    addTarget(ped)

    spawned[entry.id] = { ped = ped, blip = makeBlip(entry), scenario = entry.scenario }
end

local function clearGranny(id)
    local data = spawned[id]
    if not data then return end
    if data.ped and DoesEntityExist(data.ped) then
        removeTarget(data.ped)
        DeleteEntity(data.ped)
    end
    if data.blip and DoesBlipExist(data.blip) then
        RemoveBlip(data.blip)
    end
    spawned[id] = nil
end

local function syncLocations(list)
    locations = list or {}

    -- remove grannies that no longer exist
    local wanted = {}
    for _, entry in ipairs(locations) do wanted[entry.id] = true end
    for id in pairs(spawned) do
        if not wanted[id] then clearGranny(id) end
    end

    -- add new ones
    for _, entry in ipairs(locations) do
        if not spawned[entry.id] then spawnGranny(entry) end
    end
end

RegisterNetEvent('lf-grandma:client:syncLocations', syncLocations)

-- --- effects ----------------------------------------------------------

RegisterNetEvent('lf-grandma:client:playAnimation', function(locId, animType)
    local data = spawned[locId]
    local cfg = Config.Animations[animType]
    if not data or not DoesEntityExist(data.ped) or not cfg then return end
    local ped = data.ped

    RequestAnimDict(cfg.dict)
    local timeout = 0
    while not HasAnimDictLoaded(cfg.dict) and timeout < 3000 do
        Wait(10); timeout = timeout + 10
    end
    if not HasAnimDictLoaded(cfg.dict) then return end

    ClearPedTasks(ped)
    TaskPlayAnim(ped, cfg.dict, cfg.anim, 8.0, -8.0, cfg.duration, 1, 0, false, false, false)

    SetTimeout(cfg.duration, function()
        if DoesEntityExist(ped) then
            ClearPedTasks(ped)
            if data.scenario then
                for _, entry in ipairs(locations) do
                    if entry.id == locId then
                        TaskStartScenarioAtPosition(ped, data.scenario, entry.coords.x, entry.coords.y, entry.coords.z - 1.0, entry.coords.w, 0, true, false)
                        break
                    end
                end
            end
        end
    end)
end)

RegisterNetEvent('lf-grandma:client:heal', function()
    progress('Grandma is patching you up...', Config.Animations.heal.duration, false)
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    notify('success', 'You have been healed.')
end)

RegisterNetEvent('lf-grandma:client:revive', function()
    local ped = PlayerPedId()
    progress('Grandma is bringing you back...', Config.Animations.revive.duration, true)

    DoScreenFadeOut(1000)
    Wait(1200)

    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedTasksImmediately(ped)
    SetPlayerControl(PlayerId(), true, 0)
    LocalPlayer.state:set('lf_isDead', false, true)

    Wait(300)
    DoScreenFadeIn(1000)
    notify('success', 'You have been revived.')
end)

-- --- boot -------------------------------------------------------------

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('lf-grandma:server:requestLocations')
    end
end)

CreateThread(function()
    Wait(500)
    TriggerServerEvent('lf-grandma:server:requestLocations')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do clearGranny(id) end
end)

-- expose for the creator module
exports('getLocations', function() return locations end)

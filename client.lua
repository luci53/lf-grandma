local Framework = nil
local grandmaPed = nil 

CreateThread(function()
    if Config.Framework == 'qb' then
        Framework = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == 'esx' then
        TriggerEvent('esx:getSharedObject', function(obj) Framework = obj end)
    end

    while Framework == nil do
        Wait(100)
    end

    if Config.Debug then
        print("Framework initialized:", Config.Framework)
        print("Target system:", Config.Target)
    end

    setupGrandmaPed()
end)

function setupGrandmaPed()
    RequestModel(`cs_mrs_thornhill`)
    while not HasModelLoaded(`cs_mrs_thornhill`) do Wait(0) end

    grandmaPed = CreatePed(0, `cs_mrs_thornhill`, Config.Coords.x, Config.Coords.y, Config.Coords.z - 1, Config.Coords.w, false, true)
    FreezeEntityPosition(grandmaPed, true)
    SetEntityInvincible(grandmaPed, true)
    SetBlockingOfNonTemporaryEvents(grandmaPed, true)
    TaskStartScenarioAtPosition(grandmaPed, "WORLD_HUMAN_PICNIC", Config.Coords.x, Config.Coords.y, Config.Coords.z - 1, Config.Coords.w, 0, true, false)

    setupTargetInteraction()
end

function setupTargetInteraction()
    if not DoesEntityExist(grandmaPed) then return end

    if Config.Target == 'ox' then
        exports.ox_target:addLocalEntity(grandmaPed, {
            {
                name = 'grandma_interaction',
                icon = 'fas fa-heart',
                label = 'Talk to Grandma',
                distance = 2.5,
                onSelect = function() openGrandmaMenu() end
            }
        })
    elseif Config.Target == 'qb' then
        exports['qb-target']:AddTargetEntity(grandmaPed, {
            options = {
                {
                    type = "client",
                    action = function() openGrandmaMenu() end,
                    icon = "fas fa-heart",
                    label = "Talk to Grandma"
                }
            },
            distance = 2.5
        })
    end
end

function playGrandmaAnimation(animType)
    if not DoesEntityExist(grandmaPed) or not Config.Animations[animType] then return end

    local animConfig = Config.Animations[animType]

    RequestAnimDict(animConfig.dict)
    while not HasAnimDictLoaded(animConfig.dict) do
        Wait(100)
    end

    TaskPlayAnim(grandmaPed, animConfig.dict, animConfig.anim, 8.0, -8.0, animConfig.duration, 1, 0, false, false, false)

    CreateThread(function()
        Wait(animConfig.duration)
        if DoesEntityExist(grandmaPed) then
            ClearPedTasks(grandmaPed)
            TaskStartScenarioAtPosition(grandmaPed, "WORLD_HUMAN_PICNIC", Config.Coords.x, Config.Coords.y, Config.Coords.z - 1, Config.Coords.w, 0, true, false)
        end
    end)
end

function openGrandmaMenu()
    local playerPed = PlayerPedId()
    local isDead = IsEntityDead(playerPed)

    if Config.Target == 'ox' then
        local menuOptions = {}

        if not isDead then
            table.insert(menuOptions, {
                title = 'Heal Me',
                description = '$'..Config.HealCost..' (cash/bank)',
                icon = 'fas fa-hand-holding-heart',
                onSelect = function()
                    TriggerServerEvent('lf-grandma:heal')
                end
            })
        else
            table.insert(menuOptions, {
                title = 'Revive Me',
                description = '$'..Config.ReviveCost..' (cash/bank)',
                icon = 'fas fa-heartbeat',
                onSelect = function()
                    TriggerServerEvent('lf-grandma:revive')
                end
            })
        end

        table.insert(menuOptions, {
            title = 'Revive Another Player',
            description = '$'..Config.ReviveCost..' (cash/bank)',
            icon = 'fas fa-user-plus',
            onSelect = function()
                local input = lib.inputDialog('Revive Player', {{type='number', label='Player ID', description='Enter the server ID of the player you want to revive.'}})
                if input and input[1] then
                    TriggerServerEvent('lf-grandma:reviveOther', tonumber(input[1]))
                end
            end
        })

        lib.registerContext({
            id = 'grandma_menu',
            title = 'Grandma\'s Healing Services',
            options = menuOptions
        })
        lib.showContext('grandma_menu')

    elseif Config.Target == 'qb' then
        local qbMenu = {
            {
                header = "Grandma's Healing Services",
                isMenuHeader = true
            }
        }

        if not isDead then
            table.insert(qbMenu, {
                header = "Heal Me",
                txt = "$" .. Config.HealCost .. " (cash/bank)",
                params = {
                    event = 'lf-grandma:heal',
                    isServer = true,
                }
            })
        else
            table.insert(qbMenu, {
                header = "Revive Me",
                txt = "$" .. Config.ReviveCost .. " (cash/bank)",
                params = {
                    event = 'lf-grandma:revive',
                    isServer = true,
                }
            })
        end

        table.insert(qbMenu, {
            header = "Revive Another Player",
            txt = "$" .. Config.ReviveCost .. " (cash/bank)",
            params = {
                event = 'lf-grandma:reviveOtherInput',
                isServer = false,
            }
        })

        exports['qb-menu']:openMenu(qbMenu)
    end
end

RegisterNetEvent('lf-grandma:client:playAnimation', function(animType)
    playGrandmaAnimation(animType)
end)

RegisterNetEvent('lf-grandma:client:healEffect', function()
    progressBar('Grandma is patching you up...', Config.Animations.heal.duration, false)
    notify('success', 'You have been healed!')
end)

RegisterNetEvent('lf-grandma:client:reviveEffect', function()
    progressBar('Grandma is bringing you back...', Config.Animations.revive.duration, true)
    DoScreenFadeOut(1500)
    Wait(2000)
    local coords = GetEntityCoords(PlayerPedId())
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()), true, false)
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
    TriggerEvent('esx_status:set', 'hunger', 1000000)
    TriggerEvent('esx_status:set', 'thirst', 1000000)
    Wait(500)
    DoScreenFadeIn(1500)
    notify('success', 'You have been revived!')
end)


RegisterNetEvent('lf-grandma:reviveOtherInput', function()
    local input = exports['qb-input']:ShowInput({
        header = "Revive Player",
        submitText = "Revive",
        inputs = {
            {
                text = "Server ID of the player",
                name = "playerId",
                type = "number",
                isRequired = true
            }
        }
    })
    if input and input.playerId then
        TriggerServerEvent('lf-grandma:reviveOther', tonumber(input.playerId))
    end
end)

function progressBar(label, duration, useWhileDead)
    if Config.ProgressType == 'ox' then
        lib.progressCircle({duration = duration, label = label, useWhileDead = useWhileDead})
    elseif Config.ProgressType == 'qb' then
        exports['qb-core']:GetCoreObject().Functions.Progressbar("grandma_action", label, duration, false, useWhileDead, {
            disableMovement = true, disableCarMovement = true
        })
    end
end

function notify(type, message)
    if Config.Notify == 'ox' then
        lib.notify({type = type, description = message})
    elseif Config.Notify == 'qb' then
        exports['qb-core']:GetCoreObject().Functions.Notify(message, type)
    end
end
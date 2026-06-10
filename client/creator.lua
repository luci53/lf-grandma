-- =====================================================================
--  lf-grandma | In-game Granny creator (admin tool)
-- ---------------------------------------------------------------------
--  /grandma opens an ox_lib menu to place, list and delete Grannies at
--  runtime. Permission is confirmed by the server via lib.callback, and
--  every create/delete is re-authorised server-side as well.
-- =====================================================================

if not Config.Creator.enabled then return end

local function notify(kind, message)
    if Config.Notify == 'qb' then
        TriggerEvent('QBCore:Notify', message, kind)
    elseif Config.Notify == 'esx' then
        TriggerEvent('esx:showNotification', message)
    else
        lib.notify({ type = kind, description = message })
    end
end

local function modelOptions()
    local opts = {}
    for _, m in ipairs(Config.Creator.models) do
        opts[#opts + 1] = { value = m.model, label = m.label }
    end
    return opts
end

local function scenarioOptions()
    local opts = { { value = '', label = 'None' } }
    for _, s in ipairs(Config.Creator.scenarios) do
        opts[#opts + 1] = { value = s, label = s }
    end
    return opts
end

local function createHere()
    local input = lib.inputDialog('Create Grandma', {
        { type = 'input',  label = 'Label', default = 'Grandma', required = true, max = 32 },
        { type = 'select', label = 'Ped model', options = modelOptions(), default = Config.Creator.models[1].model },
        { type = 'input',  label = 'Custom model (optional)', description = 'Overrides the dropdown if filled in' },
        { type = 'select', label = 'Idle scenario', options = scenarioOptions(), default = Config.Creator.scenarios[1] },
    })
    if not input then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = (input[3] and input[3] ~= '') and input[3] or input[2]

    TriggerServerEvent('lf-grandma:server:createLocation', {
        label    = input[1],
        model    = model,
        scenario = (input[4] ~= '' and input[4]) or nil,
        coords   = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) },
    })
end

local function nearestLocation()
    local list = exports['lf-grandma']:getLocations()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, entry in ipairs(list or {}) do
        local c = entry.coords
        local dist = #(coords - vector3(c.x, c.y, c.z))
        if not bestDist or dist < bestDist then best, bestDist = entry, dist end
    end
    return best, bestDist
end

local function deleteNearest()
    local nearest, dist = nearestLocation()
    if not nearest then
        notify('error', 'No Grannies exist.')
        return
    end
    if nearest.readonly then
        notify('error', ('Nearest is a default location ("%s") — edit config.lua to remove it.'):format(nearest.label))
        return
    end

    local confirm = lib.alertDialog({
        header = 'Delete Grandma',
        content = ('Delete **%s** (%s), %.1fm away?'):format(nearest.label, nearest.id, dist or 0),
        centered = true, cancel = true,
    })
    if confirm == 'confirm' then
        TriggerServerEvent('lf-grandma:server:deleteLocation', nearest.id)
    end
end

local function listLocations()
    local list = exports['lf-grandma']:getLocations()
    local coords = GetEntityCoords(PlayerPedId())
    local options = {}

    for _, entry in ipairs(list or {}) do
        local c = entry.coords
        local dist = #(coords - vector3(c.x, c.y, c.z))
        options[#options + 1] = {
            title = entry.label,
            description = ('%s • %.0fm • %s'):format(entry.id, dist, entry.readonly and 'default (config)' or 'custom'),
            icon = entry.readonly and 'lock' or 'trash',
            onSelect = function()
                if entry.readonly then
                    notify('inform', 'Default location — remove it in config.lua.')
                else
                    TriggerServerEvent('lf-grandma:server:deleteLocation', entry.id)
                end
            end,
        }
    end

    if #options == 0 then
        notify('inform', 'No Grannies exist yet.')
        return
    end

    lib.registerContext({ id = 'grandma_creator_list', title = 'Granny Locations', menu = 'grandma_creator', options = options })
    lib.showContext('grandma_creator_list')
end

local function openCreator()
    lib.registerContext({
        id = 'grandma_creator',
        title = 'Grandma — Admin',
        options = {
            { title = 'Create Grandma Here', description = 'Place a new Granny at your position', icon = 'plus', onSelect = createHere },
            { title = 'Delete Nearest', description = 'Remove the closest custom Granny', icon = 'trash', onSelect = deleteNearest },
            { title = 'List Locations', description = 'Browse and manage every Granny', icon = 'list', onSelect = listLocations },
        },
    })
    lib.showContext('grandma_creator')
end

RegisterCommand(Config.Creator.command, function()
    local isAdmin = lib.callback.await('lf-grandma:isAdmin', false)
    if not isAdmin then
        notify('error', 'You do not have permission to do that.')
        return
    end
    openCreator()
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Creator.command, 'Open the Grandma admin creator')

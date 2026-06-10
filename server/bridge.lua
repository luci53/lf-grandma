-- =====================================================================
--  lf-grandma | Server-side framework bridge
-- ---------------------------------------------------------------------
--  One place that knows the differences between QBox / QBCore / ESX and
--  the various inventory systems. The rest of the server talks to this
--  table only, so adding a framework means editing this file alone.
-- =====================================================================

Bridge = {}

local Core              ---@type table?  resolved core object
local frameworkName     ---@type string  'qbx' | 'qb' | 'esx'
local inventoryName     ---@type string  'ox' | 'qb' | 'esx'

local function has(resource)
    return GetResourceState(resource) ~= 'missing'
end

-- --- Detection --------------------------------------------------------

local function resolveFramework()
    local choice = Config.Framework
    if choice == 'auto' then
        if has('qbx_core') then return 'qbx' end
        if has('qb-core') then return 'qb' end
        if has('es_extended') then return 'esx' end
        error('[lf-grandma] No supported framework found (qbx_core / qb-core / es_extended).')
    end
    return choice
end

local function resolveInventory()
    local choice = Config.Inventory
    if choice == 'auto' then
        if has('ox_inventory') then return 'ox' end
        return frameworkName == 'esx' and 'esx' or 'qb'
    end
    return choice
end

CreateThread(function()
    frameworkName = resolveFramework()

    if frameworkName == 'qbx' then
        Core = exports.qbx_core
    elseif frameworkName == 'qb' then
        Core = exports['qb-core']:GetCoreObject()
    elseif frameworkName == 'esx' then
        Core = exports.es_extended:getSharedObject()
    end

    inventoryName = resolveInventory()

    if Config.Debug then
        print(('[lf-grandma] framework=%s inventory=%s'):format(frameworkName, inventoryName))
    end
end)

function Bridge.Ready()
    return Core ~= nil
end

function Bridge.Framework()
    return frameworkName
end

-- --- Players ----------------------------------------------------------

---@return table? player framework player object, or nil if not loaded
function Bridge.GetPlayer(source)
    if not Core then return nil end
    if frameworkName == 'qbx' then
        return Core:GetPlayer(source)
    elseif frameworkName == 'qb' then
        return Core.Functions.GetPlayer(source)
    elseif frameworkName == 'esx' then
        return Core.GetPlayerFromId(source)
    end
end

function Bridge.GetName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return ('Player %s'):format(source) end
    if frameworkName == 'esx' then
        return player.getName()
    end
    local info = player.PlayerData and player.PlayerData.charinfo
    if info then
        return ('%s %s'):format(info.firstname or '?', info.lastname or '?')
    end
    return ('Player %s'):format(source)
end

-- --- Money ------------------------------------------------------------

-- Returns true and the account used ('cash'/'bank') if `amount` was
-- successfully removed; false otherwise. Never partially charges.
function Bridge.RemoveMoney(source, amount, reason)
    if amount <= 0 then return true, 'free' end
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    if frameworkName == 'esx' then
        local cash = player.getMoney()
        local bank = player.getAccount('bank') and player.getAccount('bank').money or 0
        if cash >= amount then
            player.removeMoney(amount)
            return true, 'cash'
        elseif bank >= amount then
            player.removeAccountMoney('bank', amount)
            return true, 'bank'
        end
        return false
    end

    -- qb / qbx share the same Functions interface
    local cash = player.Functions.GetMoney('cash') or 0
    local bank = player.Functions.GetMoney('bank') or 0
    if cash >= amount then
        return player.Functions.RemoveMoney('cash', amount, reason) and true or false, 'cash'
    elseif bank >= amount then
        return player.Functions.RemoveMoney('bank', amount, reason) and true or false, 'bank'
    end
    return false
end

-- --- Items ------------------------------------------------------------

local function getItemCount(source, name)
    if inventoryName == 'ox' then
        return exports.ox_inventory:Search(source, 'count', name) or 0
    end
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end
    if frameworkName == 'esx' then
        local item = player.getInventoryItem(name)
        return item and item.count or 0
    end
    local item = player.Functions.GetItemByName(name)
    return item and item.amount or 0
end

local function removeItem(source, name, count)
    if inventoryName == 'ox' then
        return exports.ox_inventory:RemoveItem(source, name, count)
    end
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    if frameworkName == 'esx' then
        player.removeInventoryItem(name, count)
        return true
    end
    return player.Functions.RemoveItem(name, count) and true or false
end

-- Verifies the player has *all* required items, then removes them.
-- Returns false without removing anything if any item is missing.
function Bridge.HasItems(source, items)
    if not items or #items == 0 then return true end
    for _, item in ipairs(items) do
        if getItemCount(source, item.name) < (item.amount or 1) then
            return false, item
        end
    end
    return true
end

function Bridge.RemoveItems(source, items)
    if not items or #items == 0 then return true end
    if not Bridge.HasItems(source, items) then return false end
    for _, item in ipairs(items) do
        removeItem(source, item.name, item.amount or 1)
    end
    return true
end

-- --- Needs ------------------------------------------------------------

function Bridge.RestoreNeeds(source)
    if frameworkName == 'esx' then
        TriggerClientEvent('esx_status:set', source, 'hunger', 1000000)
        TriggerClientEvent('esx_status:set', source, 'thirst', 1000000)
        return
    end
    local player = Bridge.GetPlayer(source)
    if not player then return end
    if player.Functions and player.Functions.SetMetaData then
        player.Functions.SetMetaData('hunger', 100)
        player.Functions.SetMetaData('thirst', 100)
    end
    -- qb-hud / qbx_hud listen for this; harmless if absent
    TriggerClientEvent('hud:client:UpdateNeeds', source, 100, 100)
end

-- --- Death state ------------------------------------------------------

-- Server-trusted death check used by the anti-exploit validation.
-- On qb/qbx the framework metadata is authoritative; the replicated
-- client statebag is the fallback (and the only signal on ESX).
function Bridge.IsDead(source)
    if frameworkName == 'qb' or frameworkName == 'qbx' then
        local player = Bridge.GetPlayer(source)
        local md = player and player.PlayerData and player.PlayerData.metadata
        if md and (md.isdead or md.inlaststand) then return true end
    end
    local state = Player(source).state
    return state ~= nil and state.lf_isDead == true
end

-- Tell the framework the player is alive again (clears revive metadata).
function Bridge.ClearDeathState(source)
    if frameworkName == 'esx' then return end
    local player = Bridge.GetPlayer(source)
    if not player or not (player.Functions and player.Functions.SetMetaData) then return end
    player.Functions.SetMetaData('isdead', false)
    player.Functions.SetMetaData('inlaststand', false)
end

-- --- Permissions ------------------------------------------------------

function Bridge.IsAdmin(source)
    -- ace permission always wins
    if Config.Creator.acePermission ~= '' and IsPlayerAceAllowed(source, Config.Creator.acePermission) then
        return true
    end

    local groups = Config.Creator.adminGroups or {}

    if frameworkName == 'esx' then
        local player = Bridge.GetPlayer(source)
        if not player then return false end
        local group = player.getGroup()
        for _, g in ipairs(groups) do
            if group == g then return true end
        end
        return false
    end

    -- qb / qbx expose HasPermission(source, permission)
    for _, g in ipairs(groups) do
        local ok, allowed = pcall(function()
            if frameworkName == 'qbx' then
                return Core:HasPermission(source, g)
            end
            return Core.Functions.HasPermission(source, g)
        end)
        if ok and allowed then return true end
    end
    return false
end

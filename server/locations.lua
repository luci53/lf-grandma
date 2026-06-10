-- =====================================================================
--  lf-grandma | Location store
-- ---------------------------------------------------------------------
--  Config.Locations are the immutable defaults shipped with the script.
--  Admins add extra Grannies in-game through the creator; those are the
--  only ones persisted to locations.json and the only ones that can be
--  deleted at runtime. To change a default, edit config.lua.
-- =====================================================================

Locations = {}

local STORE_FILE = 'locations.json'
local custom = {}   -- runtime + persisted admin-created locations
local nextId  = 1

-- --- helpers ----------------------------------------------------------

-- vector4 / vector3 / table -> plain { x, y, z, w } (JSON friendly)
local function toCoordsTable(coords)
    return {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        w = (coords.w or coords.heading or 0.0) + 0.0,
    }
end

local function normalizeDefault(entry, index)
    return {
        id       = 'cfg_' .. index,
        label    = entry.label or 'Grandma',
        model    = entry.model or 'cs_mrs_thornhill',
        coords   = toCoordsTable(entry.coords),
        scenario = entry.scenario,
        blip     = entry.blip,
        readonly = true,
    }
end

-- --- persistence ------------------------------------------------------

local function load()
    local raw = LoadResourceFile(GetCurrentResourceName(), STORE_FILE)
    if not raw or raw == '' then return end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print('[lf-grandma] WARNING: locations.json is corrupt, ignoring it.')
        return
    end

    custom = data.locations or {}
    nextId = data.nextId or (#custom + 1)
end

local function save()
    local data = json.encode({ nextId = nextId, locations = custom }, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), STORE_FILE, data, -1)
end

-- --- public API -------------------------------------------------------

-- All locations (defaults + custom), normalized for syncing to clients.
function Locations.GetAll()
    local all = {}
    for index, entry in ipairs(Config.Locations or {}) do
        all[#all + 1] = normalizeDefault(entry, index)
    end
    for _, entry in ipairs(custom) do
        all[#all + 1] = entry
    end
    return all
end

function Locations.Add(data)
    local entry = {
        id       = 'loc_' .. nextId,
        label    = data.label or 'Grandma',
        model    = data.model or 'cs_mrs_thornhill',
        coords   = toCoordsTable(data.coords),
        scenario = data.scenario,
        blip     = data.blip,
        readonly = false,
    }
    nextId = nextId + 1
    custom[#custom + 1] = entry
    save()
    return entry
end

-- Returns ok, message. Default (config) locations cannot be removed here.
function Locations.Remove(id)
    for i, entry in ipairs(custom) do
        if entry.id == id then
            table.remove(custom, i)
            save()
            return true, 'Location removed.'
        end
    end
    if tostring(id):find('^cfg_') then
        return false, 'That is a default location — remove it from config.lua instead.'
    end
    return false, 'Location not found.'
end

-- Nearest location to a coord set, with its distance.
function Locations.Nearest(coords)
    local best, bestDist
    for _, entry in ipairs(Locations.GetAll()) do
        local c = entry.coords
        local dist = #(coords - vector3(c.x, c.y, c.z))
        if not bestDist or dist < bestDist then
            best, bestDist = entry, dist
        end
    end
    return best, bestDist
end

-- Is `coords` within `radius` of ANY Granny? (server-side anti-exploit)
function Locations.IsNear(coords, radius)
    local _, dist = Locations.Nearest(coords)
    return dist ~= nil and dist <= radius, dist
end

load()

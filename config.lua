-- =====================================================================
--  lf-grandma | Configuration
-- ---------------------------------------------------------------------
--  Every option is documented. Anything you don't set falls back to a
--  sensible default, so you can delete sections you don't care about.
-- =====================================================================

Config = {}

-- ---------------------------------------------------------------------
--  Framework & dependencies
-- ---------------------------------------------------------------------
-- 'auto' detects qbx_core > qb-core > es_extended automatically.
-- Force a specific one with 'qbx', 'qb' or 'esx' if you run several.
Config.Framework = 'auto'

-- Targeting system: 'auto' | 'ox' | 'qb'
Config.Target = 'auto'

-- Notification system: 'auto' | 'ox' | 'qb' | 'esx'
Config.Notify = 'auto'

-- Progress bar system: 'auto' | 'ox' | 'qb'
Config.ProgressType = 'auto'

-- Inventory used for item costs: 'auto' | 'ox' | 'qb' | 'esx'
-- 'auto' uses ox_inventory if present, otherwise the framework default.
Config.Inventory = 'auto'

-- ---------------------------------------------------------------------
--  Debug
-- ---------------------------------------------------------------------
Config.Debug = false -- set true only while testing; spams the console

-- ---------------------------------------------------------------------
--  Services
-- ---------------------------------------------------------------------
--  Each service can require money, items, or both. Payment is atomic:
--  the player is only charged if they can afford the FULL price.
--
--    cost      -> cash/bank charge (0 disables the money cost)
--    items     -> list of { name = 'item', amount = 1 } consumed on use
--    cooldown  -> per-player cooldown in seconds (0 disables)
-- ---------------------------------------------------------------------
Config.Services = {
    heal = {
        enabled      = true,
        cost         = 100,
        items        = {}, -- e.g. { { name = 'bandage', amount = 1 } }
        cooldown     = 30,
        restoreNeeds = true, -- top up hunger/thirst when healing
    },

    revive = { -- reviving yourself
        enabled  = true,
        cost     = 150,
        items    = {},
        cooldown = 60,
    },

    reviveOther = { -- reviving another downed player nearby
        enabled  = true,
        cost     = 150,
        items    = {},
        cooldown = 60,
    },
}

-- ---------------------------------------------------------------------
--  Anti-exploit
-- ---------------------------------------------------------------------
-- Max distance (m) a player may be from a Granny to use any service.
-- The server verifies this with its own copy of the ped coordinates,
-- so spoofed client events are rejected.
Config.InteractionDistance = 3.5

-- Max distance (m) a downed player may be from a Granny to be revived
-- by someone else.
Config.ReviveZoneRadius = 7.0

-- Reject and log attempts that fail server-side validation
-- (wrong distance, not actually dead, spamming, etc.).
Config.LogSuspicious = true

-- ---------------------------------------------------------------------
--  Granny locations
-- ---------------------------------------------------------------------
-- These are the *default* spawns shipped with the script. Admins can
-- add/remove more in-game with the creator (see Config.Creator); those
-- live in locations.json and are merged with this list at runtime.
--
--   label    -> name shown in the target/eye and logs
--   model    -> ped model (string or hash)
--   coords   -> vector4(x, y, z, heading)   (z is the GROUND level)
--   scenario -> idle scenario the ped plays  (false = none)
--   blip     -> per-location blip override, or nil to use Config.Blip
-- ---------------------------------------------------------------------
Config.Locations = {
    {
        label    = "Grandma",
        model    = "cs_mrs_thornhill",
        coords   = vector4(2432.6, 4968.10, 48.30, 136.91),
        scenario = "WORLD_HUMAN_PICNIC",
        -- blip  = { sprite = 153, color = 1, scale = 0.8 },
    },
}

-- ---------------------------------------------------------------------
--  Map blips (global default; override per-location with `blip`)
-- ---------------------------------------------------------------------
Config.Blip = {
    enabled = true,
    sprite  = 153,        -- https://docs.fivem.net/docs/game-references/blips/
    color   = 1,
    scale   = 0.8,
    label   = "Grandma",
    shortRange = true,
}

-- ---------------------------------------------------------------------
--  In-game Granny creator (admin tool)
-- ---------------------------------------------------------------------
Config.Creator = {
    enabled       = true,
    command       = "grandma",            -- /grandma opens the admin menu
    acePermission = "lf-grandma.admin",   -- ace permission that always grants access
    -- Framework groups that may use the creator (in addition to the ace perm).
    adminGroups   = { "admin", "superadmin", "god" },

    -- Ped models offered in the creator (players can also type a custom one).
    models = {
        { label = "Mrs Thornhill", model = "cs_mrs_thornhill" },
        { label = "Maude",          model = "ig_maude" },
        { label = "Old Woman 1",    model = "a_f_o_genstreet_01" },
        { label = "Old Woman 2",    model = "a_f_o_salton_01" },
        { label = "Beverly Hills",  model = "a_f_m_bevhills_02" },
    },

    -- Idle scenarios offered in the creator.
    scenarios = {
        "WORLD_HUMAN_PICNIC",
        "WORLD_HUMAN_AA_COFFEE",
        "WORLD_HUMAN_SMOKING",
        "WORLD_HUMAN_STAND_IMPATIENT",
        "WORLD_HUMAN_GUARD_STAND",
    },
}

-- ---------------------------------------------------------------------
--  Animations  (https://alexguirre.github.io/animations-list/)
-- ---------------------------------------------------------------------
Config.Animations = {
    heal = {
        dict     = 'amb@medic@standing@kneel@base',
        anim     = 'base',
        duration = 5000, -- ms
    },
    revive = {
        dict     = 'missfinale_c2mcs_1',
        anim     = 'fin_c2_mcs_1_camman',
        duration = 7000, -- ms
    },
}

-- ---------------------------------------------------------------------
--  Logging
-- ---------------------------------------------------------------------
Config.Webhook  = ''                 -- Discord webhook URL ('' disables logging)
Config.LogName  = 'Grandma Services' -- bot name shown in Discord
Config.LogColor = 16148910           -- embed colour (decimal)

Config = {}

Config.Framework = 'qb'  -- or 'esx', 'core'
Config.Target = 'ox'     -- or 'ox', 'qb'

Config.HealCost = 100
Config.ReviveCost = 150

Config.Debug = true  -- Change this to false in production for no debug prints

Config.Coords = vector4(2432.6, 4968.10, 48.30, 136.91)

Config.ReviveZoneRadius = 7.0 -- in meters

Config.Notify = 'ox' -- Can be 'ox' or 'qb'
Config.ProgressType = 'ox' -- Can be 'ox' or 'qb'

Config.Webhook = 'YOUR_URL_HERE' -- Replace with your webhook URL

Config.Animations = {
    heal = {
        dict = 'amb@medic@standing@kneel@base',
        anim = 'base',
        duration = 5000 -- in milliseconds
    },
    revive = {
        dict = 'missfinale_c2mcs_1',
        anim = 'fin_c2_mcs_1_camman',
        duration = 7000 -- in milliseconds
    }
}
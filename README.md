# lf-grandma | Healing & Revive NPC

Welcome to `lf-grandma`, a highly configurable FiveM script that adds an immersive NPC who provides healing and revival services to players for a fee. This script is designed to be a lightweight and feature-rich alternative for illegal or remote medical services on your server.

Grandma doesn't ask questions. For the right price, she'll patch you up or bring you back from the brink, complete with animations and server-side checks to ensure fair play.

## Features

* **Interactive NPC:** A persistent "Grandma" NPC at a location of your choice.
* **Dynamic Menus:** The interaction menu intelligently shows "Heal" for living players and "Revive" for dead players.
* **Multi-Framework Support:** Works out-of-the-box with `QBCore` and `ESX`.
* **Multi-Target Support:** Supports `ox_target` and `qb-target` for interactions.
* **Zone-Checked Revives:** Prevents players from reviving others who are not within a configurable radius of Grandma.
* **Immersive Animations:** Grandma plays a configurable animation when healing or reviving someone, visible to all nearby players.
* **Discord Logging:** Integrated Discord webhook to log all services performed by Grandma.
* **Highly Configurable:** Easily change costs, coordinates, animations, notifications, and more via the `config.lua` file.

## Dependencies

Before installing, ensure you have the following resources installed and started on your server:

* **Framework:**
    * [qb-core](https://github.com/qbcore-framework/qb-core) OR [es_extended](https://github.com/esx-framework/esx_core)
* **Library:**
    * [ox_lib](https://github.com/CommunityOx/ox_lib) (Required for notifications, progress bars, and menus)
* **Targeting System:**
    * [ox_target](https://github.com/CommunityOx/ox_target) OR [qb-target](https://github.com/qbcore-framework/qb-target)
* **For QBCore Users:**
    * [qb-menu](https://github.com/qbcore-framework/qb-menu)
    * [qb-input](https://github.com/qbcore-framework/qb-input)

## Installation

1.  Download the `lf-grandma` script.
2.  Extract the folder and place it in your server's `resources` directory.
3.  Ensure all the dependencies listed above are installed correctly.
4.  Open the `config.lua` file and adjust the settings to match your server's framework and your preferences.
5.  Add `ensure lf-grandma` to your `server.cfg` or `resources.cfg` file. Make sure it is started *after* its dependencies.
6.  Restart your server.

## Configuration

All settings are located in the `config.lua` file.

```lua
-- File: config.lua

Config = {}

-- Framework and Target Settings
Config.Framework = 'qb'  -- Framework: 'qb' or 'esx'
Config.Target = 'ox'     -- Targeting System: 'ox' or 'qb'

-- Cost Settings
Config.HealCost = 100    -- Cost to heal a player
Config.ReviveCost = 150  -- Cost to revive a player or another player

-- General Settings
Config.Debug = true      -- Enable debug prints in console. Set to false for production.
Config.Coords = vector4(2432.6, 4968.10, 48.30, 136.91) -- Grandma's location (x, y, z, heading)
Config.ReviveZoneRadius = 7.0 -- Max distance (in meters) a downed player can be from Grandma to be revived by others

-- UI Settings
Config.Notify = 'ox' -- Notification system: 'ox' or 'qb'
Config.ProgressType = 'ox' -- Progress bar system: 'ox' or 'qb'

-- Logging
Config.Webhook = 'YOUR_URL_HERE' -- Your Discord webhook URL for logging

-- Animations
-- You can find more animations at [https://alexguirre.github.io/animations-list/](https://alexguirre.github.io/animations-list/)
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
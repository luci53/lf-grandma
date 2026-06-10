# lf-grandma — Healing & Revive NPC

![version](https://img.shields.io/github/v/release/luci53/lf-grandma?sort=semver)
![license](https://img.shields.io/github/license/luci53/lf-grandma)
![frameworks](https://img.shields.io/badge/framework-QBox%20%7C%20QBCore%20%7C%20ESX-blue)

A lightweight, highly configurable FiveM NPC who heals and revives players for
a fee. Grandma doesn't ask questions — for the right price she'll patch you up
or bring you back, with animations, blips and server-validated fair play.

> **Heads up:** v2 is a rewrite with a new config layout. If you're upgrading
> from v1, see the [CHANGELOG](CHANGELOG.md) — `Config.HealCost` /
> `Config.ReviveCost` are now `Config.Services`.

## Features

- **Multi-framework** — QBox (`qbx_core`), QBCore and ESX, auto-detected.
- **In-game Granny creator** — place, list and delete Grannies live with
  `/grandma`. Admin-placed locations persist across restarts.
- **Multiple locations & blips** — run as many Grannies as you like, each with
  its own model, idle scenario and map blip.
- **Heal that actually heals** — restores health and clears blood/visible
  damage. Revive resurrects downed players (yourself or others nearby).
- **Flexible pricing** — charge cash, items, or both per service, plus optional
  hunger/thirst top-up on heal.
- **Anti-exploit by design** — the server independently re-checks proximity,
  death state and payment. The client is never trusted.
- **Per-player cooldowns** and optional Discord logging (including rejected,
  suspicious requests).

## Dependencies

| Resource | Required | Notes |
| --- | --- | --- |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ | Menus, inputs, progress, notifications, callbacks |
| A framework | ✅ | [qbx_core](https://github.com/Qbox-project/qbx_core) **or** [qb-core](https://github.com/qbcore-framework/qb-core) **or** [es_extended](https://github.com/esx-framework/esx_core) |
| A targeting system | ✅ | [ox_target](https://github.com/communityox/ox_target) **or** [qb-target](https://github.com/qbcore-framework/qb-target) |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ⛔ optional | Only if you charge items and use ox_inventory |

> `qb-menu` and `qb-input` are **no longer required** — everything uses `ox_lib`.

## Installation

1. Download/clone this resource into your server's `resources` folder.
2. Make sure the dependencies above are installed and started **before** it.
3. Edit `config.lua` to taste (see below).
4. Add `ensure lf-grandma` to your `server.cfg` (after its dependencies).
5. Restart your server.

## Configuration

Everything lives in [`config.lua`](config.lua) and is fully commented. Highlights:

```lua
Config.Framework = 'auto'   -- or 'qbx' | 'qb' | 'esx'
Config.Target    = 'auto'   -- or 'ox' | 'qb'

Config.Services = {
    heal = { enabled = true, cost = 100, items = {}, cooldown = 30, restoreNeeds = true },
    revive = { enabled = true, cost = 150, items = {}, cooldown = 60 },
    reviveOther = { enabled = true, cost = 150, items = {}, cooldown = 60 },
}

Config.InteractionDistance = 3.5   -- server-enforced range to use any service
Config.ReviveZoneRadius    = 7.0   -- how close a downed player must be to be revived
```

### Charging items

Add items to any service's `items` list — they're consumed only if the player
can pay the **full** price (money + items):

```lua
heal = { cost = 50, items = { { name = 'bandage', amount = 1 } } },
```

### Locations & blips

`Config.Locations` holds the **default** Grannies shipped with the script.
Each entry takes a `label`, `model`, `coords = vector4(x, y, z, heading)`, an
optional `scenario`, and an optional per-location `blip`. The global blip style
is `Config.Blip`.

## The Granny creator

Admins can manage Grannies in-game — no config editing or restart needed.

1. Stand where you want her.
2. Run `/grandma` (command name configurable).
3. **Create Grandma Here** → pick a label, model and idle scenario.

Admin-created Grannies are saved to `locations.json` and sync to every player
instantly. **List Locations** and **Delete Nearest** manage them. Default
(config) locations are read-only here — edit `config.lua` to change those.

**Who counts as admin?** Anyone with the `lf-grandma.admin` ace permission, or a
framework group in `Config.Creator.adminGroups` (`admin`/`superadmin`/`god` by
default). To grant the ace permission, add to your `server.cfg`:

```cfg
add_ace group.admin lf-grandma.admin allow
```

## How the anti-exploit works

Network events can be spoofed, so the server treats every request as untrusted
and re-validates it before doing anything:

- **Proximity** — the server reads the player's position with its own
  `GetEntityCoords` and confirms they're within `InteractionDistance` of a real
  Granny. You can't heal from across the map.
- **Death state** — the client publishes a *replicated* statebag flag; the
  server reads it to confirm a player is genuinely down before reviving (and not
  down before healing). For `reviveOther`, the target must be dead **and** in
  the revive zone.
- **Payment** — money and items are checked together and charged atomically; a
  player who can't afford the full price pays nothing.
- **Cooldowns** — per player, per service.
- **Logging** — successful services and rejected/suspicious attempts can be sent
  to a Discord webhook (`Config.Webhook`, `Config.LogSuspicious`).

## Releases

Tagging a commit `vX.Y.Z` triggers the GitHub Actions workflow in
[`.github/workflows/release.yml`](.github/workflows/release.yml), which builds a
versioned zip and publishes a release with auto-generated notes.

## License

[MIT](LICENSE) © Lucifer (luci53)

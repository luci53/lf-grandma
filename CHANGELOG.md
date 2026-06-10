# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-06-10

> **Breaking:** `Config.HealCost` / `Config.ReviveCost` were replaced by the
> richer `Config.Services` table, and the script was restructured into
> `client/` and `server/` folders. Review your `config.lua` after updating.

### Added
- **QBox (`qbx_core`) support** alongside QBCore and ESX, with `'auto'`
  framework, target, notify, progress and inventory detection.
- **In-game Granny creator** (`/grandma`): place, list and delete Grannies at
  runtime. Custom locations persist to `locations.json` and sync live to every
  player. Access is gated by an ace permission or framework admin group.
- **Multiple Granny locations** via `Config.Locations`, each with its own model,
  idle scenario and optional blip.
- **Map blips** — global `Config.Blip` default with per-location overrides.
- **Item costs** and a configurable cash cost per service (`Config.Services`),
  with `ox_inventory` support (auto-detected).
- Optional **hunger/thirst restoration** on heal.
- **Per-player, per-service cooldowns**.
- **Server-side anti-exploit**: proximity, death-state (replicated statebag)
  and atomic payment validation. Rejected attempts can be logged to Discord.
- MIT `LICENSE`, this `CHANGELOG`, and an automated GitHub release workflow.

### Changed
- Rewrote the resource into modular `client/` and `server/` files behind a
  single framework bridge.
- Menus, inputs, progress bars and notifications now go through `ox_lib`
  uniformly — **drops the `qb-menu` / `qb-input` dependency**.

### Fixed
- **Heal now actually restores health** and clears blood/visible damage.
  Previously it charged the player and played a progress bar without healing.
- Reviving another player now verifies the target is genuinely down (and within
  the revive zone) before charging.
- Heal/revive can no longer be triggered from anywhere on the map — the server
  validates proximity against its own copy of the Granny coordinates.

### Security
- The client is never trusted for payment, position or death state; every
  action is independently re-validated on the server.

## [1.0.0]

### Added
- Initial release: healing/revive NPC for QBCore and ESX with ox/qb targeting,
  immersive animations, zone-checked revives and Discord logging.

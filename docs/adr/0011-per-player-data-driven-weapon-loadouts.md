# ADR 0011: Per-player data-driven weapon loadouts

- Status: Accepted for the v0.0.6 development candidate
- Date: 2026-10-17
- Scope: Weapon Variety; no weapon evolution, economy or networking

## Context

The accepted prototype owns one mutable pistol controller directly on each player.
Weapon Variety needs three substantially different weapons, switching and retained
ammo state without adding weapon-ID branches to the player, items, enemies or run
authority. Existing item modifiers and source-aware damage must continue to work.

## Decision

Each `CombatPlayer` owns a `WeaponLoadout`. The loadout owns one
`WeaponController` for every injected `WeaponDefinition`, an equipped slot index
and aggregate state/event signals. Controllers retain independent magazine,
reserve, reload and cooldown state. The loadout advances all controller timers
while combat authority is active; pausing or disabling the player freezes all of
them. Restart creates a new player actor and a clean loadout.

`WeaponDefinition` supplies semiautomatic/automatic fire mode, base shot count and
authored horizontal spread in addition to the existing damage, timing, ammo, range
and tags. `WeaponController` applies the player's generic item-derived stats to
that base data, creates one attributed context per shot and uses a fixed authored
ray pattern. Switching consumes no run RNG.

The player input layer selects slots and interprets the generic fire mode. It does
not identify the Service Pistol, Relay SMG or Scatterline Shotgun. Item effects
continue to listen to generic weapon/shot/kill events. Damage contexts retain the
owning player, entity, weapon ID, damage type and tags for every archetype.

The initial three-weapon catalog is authored by the Combat Sandbox composition
root and injected into player actors. This preserves per-player ownership and lets
future authority create a distinct loadout for every participant without a global
player or networking implementation.

## Consequences

New hitscan archetypes expressible through the current definition can be added as
content. Projectile weapons, alternate fire, per-shell reloads, recoil, weapon
pickup/economy rules and weapon evolution require later reviewed primitives. The
prototype uses simple box view models and fixed ray spread; production feel and
presentation remain deferred.

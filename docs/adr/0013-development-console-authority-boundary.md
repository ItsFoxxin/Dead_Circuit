# ADR 0013: Development console authority boundary

- Status: Accepted
- Date: 2026-10-21

## Context

Weapon, item, enemy and run testing benefits from fast in-game setup. An arbitrary
code console or global-player shortcut would bypass the existing ownership model,
make release exposure difficult to audit and encourage tests that do not use the
real gameplay paths.

## Decision

Provide a bounded, typed command runner under `game/dev/` and a development-build
overlay that receives an injected `RoomRunSession`. Commands resolve an explicit
player ID from the session roster and invoke normal health, weapon, item, enemy
death and run-restart APIs. Console-originated damage uses `DamageContext`; enemy
removal retains the selected player's ownership while developer damage opts out
of item trigger and healing chains.

`RoomBootstrap` instantiates the overlay only when neither the Godot release
feature nor generated release build metadata is present. The console supports a
fixed command vocabulary and cannot evaluate GDScript or access files or the
network. Authoritative random choices remain on `RunRandom`; item grants are
explicit test setup and consume no random draws.

## Consequences

- Development artifacts can create precise combat states without adding a global
  player or changing content definitions.
- Console tests exercise the same reusable APIs and source attribution used by
  gameplay.
- Release builds have no mounted console UI or command input path.
- Each new command requires a deliberate typed implementation and focused test.

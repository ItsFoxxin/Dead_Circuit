# ADR 0003: Local combat authority, hitscan and session lifetime

- Status: Accepted
- Date: 2026-10-15
- Scope: v0.0.1 candidate

## Decision

Use a scene-owned CombatSession to coordinate explicit player instances, enemy
instances, and WaveManager. The prototype creates one local player with an ID;
enemies select from an injected list of living players. There is no global player
singleton, networking, RPC, or separate multiplayer implementation.

Use DamageableBody and HealthComponent for both sides. DamageContext retains
source player ID (-1 for non-player sources), source entity identity, source
weapon/attack ID, amount, type, and copied tags. WeaponController owns ammo and
timers per player, using a shared read-only WeaponDefinition. Hitscan uses the
physics world and the common damage interface rather than enemy-specific calls.

Weapon/enemy/wave Resources and the greybox room are content. The bootstrap scene
is the composition root: it injects the content sandbox into a generic bootstrap
script. Mechanics never preload particular weapon/enemy/room content. Godot's
NavigationAgent3D follows an authored navigation mesh in the open arena. No run
RNG is needed: waves and spawn-point selection are fixed ordered content.

Restart destroys the session's actor subtree and creates fresh player, health,
weapon and enemies. It resets wave bookkeeping and increments a session token;
old death callbacks and deferred wave advancement cannot affect the new attempt.
Death or completion disables combat and exposes a restart control. No run,
reward, item, modifier, progression, or procedural generation systems are added.

Extend ADR 0002's fail-closed validator with explicit WeaponDefinition,
EnemyDefinition, WaveDefinition and room/enemy scene validation. Unknown files
remain errors. Validate IDs, numeric bounds, scene dependencies and arena spawn/
navigation structure. Prototype content must configure exactly five increasing
waves; the reusable manager itself supports an injected ordered wave list.

## Consequences

Gameplay commands and state mutations have explicit local owners that can later
move behind server authority. This is not a networking abstraction or a promise
of deterministic physics. Existing deterministic fixtures and all Phase 0 gates
remain. Automated physics/input/integration tests verify mechanics; feel, visual
aiming and completing the Windows artifact still require human playtesting.

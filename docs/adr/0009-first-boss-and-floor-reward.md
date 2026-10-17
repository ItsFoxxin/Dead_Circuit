# ADR 0009: First boss encounter and per-player floor reward

- Status: Accepted; v0.0.5 owner acceptance passed on 2026-10-17
- Date: 2026-10-16
- Scope: First Boss, extending ADR 0008 without procedural floors or networking

## Decision

BossDefinition extends the existing enemy configuration with a display name and
windup/recovery durations. BossEnemy reuses MeleeEnemy navigation, target candidates,
health, death and attributed enemy events. It adds explicit chase, windup, recovery
and dead states. A stationary, visibly telegraphed radial melee attack rechecks range
and solid-world occlusion at impact. Players can move out during windup; pause
freezes its timers and death/teardown cancels it. No independent RNG is needed.

An optional boss scene is authored on a boss RoomDefinition. A boss spawn marker
belongs to its arena content. Keep the existing
staging-only route for regression coverage; a separate authored first-boss route
becomes the dev candidate's launch content. No core boss or room IDs are hardcoded.

CombatSession registers encounter enemies through the same reusable spawn/damage/
kill path as zombies, optionally outside wave bookkeeping. RoomRunSession owns the
boss lifetime and locks its exit until an actual attributed death. Attempt, room
and combat generations reject stale callbacks. Unexpected removal is not victory.
Boss damage and kills retain source context, so existing item effects apply normally.

The owner's v0.0.5 pacing correction supersedes per-wave items for the new route:
five waves grant no items; one treasure room grants one choice; the boss grants
one further choice. Reuse the existing unowned-item offer/selection path and wait
for every living participant. Keep target player ID and the kill's source context
in the boss reward signal. Set the defeat guard before callbacks. Historical
standalone/v0.0.4 content keeps its accepted per-wave behavior for regression tests.

After a combat or boss room clears, roll once through the authoritative RunRandom
for a small shared health/ammo pickup. ClearDropDefinition supplies the probability
and amounts (initially 25%, 10 HP or 12 reserve ammo). A second bounded choice picks
the supply type only on success. Zero probability consumes no RNG. Start/treasure
rooms and individual wave clears do not roll supplies. Collection requires a living
participant, proximity, current room/attempt/combat generation and unpaused active
authority. Consume once, clamp healing and retain collector/room attribution.
Uncollected supplies expire on room transition; full-health players do not waste HP.
This is limited room-clear supplies, not a general loot/progression system.

Leaving the cleared boss room completes this one-floor prototype. Restart resets
boss actors, attack timers, rewards, room progress, player state and authoritative RNG.

## Boundaries and verification

Only one primitive boss and one telegraphed attack are needed. Adds are omitted;
boss selection, multi-phase cinematics, additional floors, final
presentation and networking remain deferred. Reuse the existing player, pistol,
items, five waves, navigation and harness. Add tests for windup/escape/occlusion,
ownership, pause/cancellation, kill effects, reward bounds/idempotence, locked exit,
completion/restart and whole-route process determinism without weakening old probes.

On 2026-10-16 the owner approved v0.0.4 for main/release and v0.0.5 for dev.
On 2026-10-17 the owner accepted v0.0.5 and authorized main promotion/release.
The v0.0.6 planning work does not alter this decision.

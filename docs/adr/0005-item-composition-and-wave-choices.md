# ADR 0005: Per-player item composition and bounded secondary effects

- Status: Accepted
- Date: 2026-10-16
- Scope: v0.0.2 candidate

## Decision

Use read-only ItemDefinition Resources containing stat modifiers and event triggers
with tag conditions and reusable effects. Each actor owns a PlayerItemBuild with
an explicit player ID. Never mutate the shared item or weapon configuration.
All prototype items declare unique stacking; duplicate acquisition is rejected.

Derived weapon stats apply all additions before all multipliers. Within each
phase, sort owned items by stable ID, then use authored modifier order. Acquisition
order cannot change the result. The initial stats are weapon damage, fire rate,
shot count and per-shot damage scale. Explosion damage and healing use their own
configured fixed amounts and are not multiplied again by weapon modifiers.

Keep hitscan. A trigger pull consumes one magazine round and one cooldown,
regardless of shot count, and resolves each ray independently with a new attributed
DamageContext. Rays have fixed horizontal spacing of 1.2 degrees, centered on aim.
There is no random spread or physical-projectile conversion.

Use synchronous session-local WEAPON_FIRED, SHOT_CREATED and ENEMY_KILLED events.
Kill events carry the victim ID/location and source context; only the matching
player build reacts. Conditions require all required tags and reject any excluded
tag. The session observes enemy death and dispatches events through the reusable
pipeline; enemies and weapons know no specific item IDs.

Primary weapon hitscan kills may request explosions through authored triggers.
Explosions retain player, entity and weapon attribution, add secondary/explosion
tags and increment effect_depth. They use normal damage interfaces against injected
enemy targets, with radius and solid-world occlusion checks. Secondary damage
cannot spawn further explosions, even if an item's tag condition is malformed.
Owned secondary weapon kills may trigger healing. Healing clamps at maximum and
cannot resurrect a dead player. Each death still emits only once.

After non-final wave clears, WaveManager may enter WAITING_FOR_REWARD. CombatSession
offers each living player the first three distinct unowned definitions in authored
catalog order (fewer if fewer remain). There is no RNG or seeded run implementation.
Selection commands must match player, session token, wave and an offered ID, and
grant exactly one item. All pending players must select before the next wave.
An exhausted catalog advances without an offer. The final wave completes directly.

Restart recreates actors/builds/effect runners and the damage-target registry,
clears pending offers and advances the session token. Old buttons/deferred callbacks
cannot grant items or advance the new attempt. UI selection consumes its activation
without firing; focused keyboard selection does not invoke restart.

## Consequences

Split Chamber and Volatile Rounds compose solely through shot-count modification
and generic eligible kills. There is no pair-specific code or content dependency in
game/. The five-item pool and primitive choice/build display are sufficient to test
composition. This introduces no networking, full run RNG, procedural generation,
save data, item unlocks or later-milestone systems. Fixed offers and unique-only
stacking are explicit prototype policies; future changes require tests/docs.

Automated integration tests prove real multishot hits, source-aware blast damage,
non-recursion, healing and wave tracking. Subjective build interest and the Windows
artifact's complete choice/combat/restart loop still require manual acceptance.

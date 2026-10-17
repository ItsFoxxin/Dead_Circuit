# Dead Circuit — Item System

## Objective

The item system is one of Dead Circuit's defining systems.

It must support large numbers of independent effects that naturally combine into emergent builds.

The system must avoid explicitly coding every possible synergy.

## Fundamental Rule

> Items modify reusable game mechanics. Items do not directly implement combinations with other specific items.

Bad:

```text
if player owns Split Chamber and Volatile Rounds:
    run special SplitVolatile behavior
```

Good:

```text
Split Chamber
→ modifies projectile count

Volatile Rounds
→ reacts to eligible enemy kills
```

Their interaction emerges naturally.

## Item Definition

Conceptually, an item may contain:

```text
id
name
description
rarity
tags

modifiers
triggers
conditions
effects
```

Exact Godot Resource structure may evolve.

## Modifier

A modifier changes an existing value or property.

Examples:

- damage × 1.25
- fire rate × 1.15
- projectile count + 1
- magazine size + 4
- movement speed × 1.10

Modifier ordering must eventually have clearly defined semantics.

## Trigger

A trigger defines when an effect may activate.

Examples:

```text
WEAPON_FIRED
PROJECTILE_CREATED
PROJECTILE_HIT
ENEMY_DAMAGED
ENEMY_KILLED
PLAYER_DAMAGED
PLAYER_HEALED
WEAPON_RELOADED
ROOM_ENTERED
ROOM_CLEARED
BOSS_KILLED
```

Additional triggers can be introduced as reusable gameplay primitives.

## Condition

A condition determines whether an effect is allowed to run.

Examples:

```text
damage source has PROJECTILE tag

target is burning

player is below 50% HP

kill was critical

weapon has SHOTGUN tag
```

## Effect

An effect performs reusable gameplay behavior.

Potential effect primitives include:

```text
ModifyStat
SpawnProjectile
SpawnExplosion
ApplyStatus
Heal
DealDamage
AddShield
ChainTarget
Knockback
SpawnEntity
GrantCurrency
ModifyAmmo
ModifyCooldown
```

Specific item definitions should reuse these primitives when possible.

## Example: Split Chamber

```text
Name:
Split Chamber

Modifiers:
projectile_count +1
projectile_damage ×0.85
```

It does not know what Volatile Rounds is.

## Example: Volatile Rounds

```text
Name:
Volatile Rounds

Trigger:
ENEMY_KILLED

Condition:
damage source contains PROJECTILE tag

Effect:
spawn explosion at killed enemy position
```

It does not know what Split Chamber is.

## Expected Interaction

If Split Chamber causes more projectiles to create more kills, Volatile Rounds naturally receives more eligible kill events.

No combination-specific implementation is necessary.

## Effect Ownership

Effects must retain the appropriate player/source information.

For example:

```text
Player 2 projectile
        ↓
kills enemy
        ↓
Volatile Rounds triggers
        ↓
explosion belongs to Player 2
        ↓
explosion kills another enemy
        ↓
Player 2 receives appropriate kill/effect ownership
```

Do not discard source ownership.

## Stacking

Item definitions must eventually declare stacking behavior when necessary.

Possible patterns:

- additive
- multiplicative
- capped
- unique/non-stacking
- additional trigger instances

Do not assume every item stacks identically.

## Future Scale

The architecture should eventually support hundreds of items without requiring hundreds of specialized core-system modifications.

Content volume should scale primarily through definitions rather than code complexity.

## Content production boundary

Concrete items may be produced independently only when existing modifiers,
triggers, conditions, effects, tags and ownership rules fully express them. A
content task must stop and report `NEW PRIMITIVE REQUIRED` when it needs a new
reusable capability; it must not hide that capability in one item's script or add
pair-specific logic. Codex owns the shared primitive and schema work. FoxForge may
resume the concrete definition after that work lands.

The cumulative item-growth targets, content-authoring responsibility, escalation
template and focused Git workflow are defined in
[CONTENT_WORKFLOW.md](CONTENT_WORKFLOW.md). The targets are planning guidance, not
release gates. The accepted v0.0.2–v0.0.5 five-item history remains unchanged.

## v0.0.2 implemented contracts

The candidate implements ItemDefinition, StatModifier, ItemTrigger, ItemCondition
and ItemEffect as typed Resources under game/items/. Specific definitions live in
content/items/. Each CombatPlayer has its own PlayerItemBuild and effect runner;
there is no global inventory. Definitions are shared read-only configuration.
See [ADR 0005](adr/0005-item-composition-and-wave-choices.md).

| Item | Prototype behavior |
| --- | --- |
| Heavy Lead | Weapon damage x1.30; fire rate x0.90 |
| Split Chamber | +1 independently resolved hitscan ray; per-ray damage x0.85 |
| Volatile Rounds | Eligible primary hitscan kills explode for 45 damage within 3.5 m |
| Rapid Mechanism | Fire rate x1.25 |
| Vampiric Ammo | Owned weapon kills heal 5 HP, including owned explosion kills |

All five are unique/non-repeatable within an attempt. Duplicate grants fail.
Modifiers apply additions first, then multipliers, ordered by stable item ID and
authored modifier index. Base weapon Resources never change. Weapon damage and
per-shot scaling do not also multiply the fixed explosion or healing amounts.

A successful trigger pull spends one magazine round and starts one derived-rate
cooldown. Each ray gets an independent DamageContext and physics query, including
misses. Split Chamber produces two 25.5-damage rays from the base pistol, at fixed
yaw offsets of -0.6 and +0.6 degrees. Heavy Lead increases that to 33.15 per ray.
No physical projectiles or gameplay randomness are introduced.

Events currently implemented are WEAPON_FIRED, SHOT_CREATED and ENEMY_KILLED.
Triggers match the event and tag conditions; only a build matching the context's
source player can react. Primary weapon contexts include weapon/hitscan tags.
Volatile Rounds requires both and excludes secondary damage. An additional runner
guard prevents explosions from effect_depth > 0, so blast kills never create more
blasts. Secondary contexts copy player/entity/weapon attribution, preserve tags,
add secondary/explosion and increment depth. Blasts use HealthComponent through
the shared damage interface, affect enemies only, and are blocked by solid-world
geometry. A short primitive sphere supplies development feedback.

Vampiric Ammo requires the weapon tag, so eligible secondary kills also heal their
source player. Healing clamps to maximum health and cannot resurrect. Repeated
damage to an already dead entity produces no additional kill or heal.

## v0.0.2 prototype choices and build visibility

After waves 1–4, combat progression waits for item selection. The authored catalog
order is Split Chamber, Volatile Rounds, Heavy Lead, Rapid Mechanism, Vampiric Ammo.
Offer the first three distinct unowned items, or all remaining items if fewer than
three remain. This fixed, testable policy deliberately uses no RNG. Choose Split
Chamber after wave one and Volatile Rounds after wave two for the key synergy test.
This describes the accepted v0.0.2 artifact. On the v0.0.3 dev
v0.0.3 candidate, seeded sampling supersedes this offer policy; see
[SEEDED_RUNS.md](SEEDED_RUNS.md). Item composition and ownership rules are unchanged.

The authority validates player ID, session token, cleared wave and offered item ID.
One valid selection grants one item before the next wave; stale, invalid and double
commands fail. Multiple player builds can choose independently, with progression
waiting for all pending choices. The current playable session still has one local
player and no networking. Final completion offers no item. A text HUD shows owned
items, shot count/damage and fire rate. Restart clears items, modified values,
offers, effects and session actors along with existing combat state.

## v0.0.2 Windows artifact acceptance — PASSED

The project owner confirmed the v0.0.2 Windows development artifact is good and
approved promotion to main on 2026-10-16. Manual acceptance **PASSED** for the Item /
Synergy Proof milestone. The earlier v0.0.1 acceptance remains complete. This does
not finalize movement/combat feel, item balance, visuals, UI or effects. No tag or
release is created by this closeout. The milestone's manual checklist is retained:

1. Launch, clear wave one and confirm three distinct choices appear with combat stopped.
2. Select Split Chamber by mouse or keyboard; confirm two shots per pull, one round
   consumed, the build list and derived values, then normal combat resumes.
3. Clear wave two and select Volatile Rounds. Kill a zombie near others; confirm
   attributed explosions affect nearby enemies and do not chain recursively.
4. Try Heavy Lead/Rapid Mechanism and Vampiric Ammo combinations across attempts;
   confirm visible stat changes, owned healing and maximum-HP clamping.
5. Complete wave five through all four reward pauses, including the final two-item
   offer. Confirm completion and no final reward screen.
6. Restart after completion and death; verify empty build, base stats, fresh ammo,
   wave one, correct counts and no stale effects/offers. Also exercise pause/resume.

Balance, production effects/UI and subjective build interest remain manual feedback.
The separate v0.0.3 seeded-run candidate is not part of this acceptance record.

## v0.0.5 dev candidate pacing

The owner requested fewer build items: one Treasure Room choice and one boss
choice per floor, with no per-wave upgrades in the new First Boss launch route.
Reuse the existing unique-item definitions, seeded offers, ownership and selection
guards. Small seeded room-clear supplies restore health/ammo and are not build
items. Older sandbox/staging fixtures preserve their historical behavior. See
FIRST_BOSS.md and ADR 0009. The owner accepted v0.0.5 for main/release on
2026-10-17; v0.0.6 Weapon Variety is the next authorized dev milestone.

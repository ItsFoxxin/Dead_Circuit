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

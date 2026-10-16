# Dead Circuit — Architecture

## Objective

Dead Circuit should be modular enough that new items, weapons, enemies, rooms, bosses, and effects can be added without repeatedly rewriting core systems.

The architecture prioritizes:

- composability
- explicit ownership
- data-driven content
- deterministic generation
- testability
- future multiplayer compatibility

## Engine

Godot 4.7.x stable.

Primary gameplay language:

Typed GDScript.

## Primary Separation

The most important repository boundary is:

```text
game/
    reusable mechanics

content/
    specific game content
```

### `game/`

Contains reusable systems.

Examples:

```text
Projectile
DamageSystem
HealthComponent
HomingBehavior
ExplosionEffect
RunManager
RoomGenerator
WeaponController
ItemModifierSystem
```

### `content/`

Contains definitions using those mechanics.

Examples:

```text
Split Chamber
Volatile Rounds
Service Pistol
Screamer Boss
Combat Room 03
Floor 1 Loot Pool
```

Adding new content should require little or no modification to core systems when the needed behavior already exists.

## Planned Directory Structure

```text
game/
├── core/
│   ├── events/
│   ├── rng/
│   ├── state/
│   └── utilities/
│
├── player/
├── combat/
├── weapons/
├── items/
├── enemies/
├── rooms/
├── run/
├── economy/
├── perks/
├── upgrades/
├── multiplayer/
└── ui/

content/
├── items/
├── weapons/
├── enemies/
├── bosses/
├── rooms/
└── loot_tables/
```

Directories may evolve, but responsibility boundaries should remain clear.

## System Communication

Avoid systems directly manipulating unrelated systems.

Prefer:

- signals
- events
- defined service interfaces
- data resources
- explicit state objects

Example:

```text
Projectile hits enemy
        ↓
Damage system processes hit
        ↓
Damage event generated
        ↓
Enemy health changes
        ↓
Enemy dies
        ↓
EnemyKilled event generated
        ↓
Item effects may react
```

The weapon should not need to know that an item called "Volatile Rounds" exists.

## Damage Context

Damage should carry contextual information sufficient for future effects and multiplayer ownership.

Conceptual structure:

```text
DamageContext

amount
source_player_id
source_entity
source_weapon_id
damage_type
critical
tags
```

Exact implementation may evolve.

Source information must not be discarded prematurely.

## Player State

Do not design gameplay around one global player.

Conceptually:

```text
RunState
├── PlayerState
├── PlayerState
├── ...
├── current_floor
├── room_state
└── seed
```

Single-player contains one PlayerState.

Multiplayer may contain up to four.

## Randomness

All gameplay-critical run randomness must originate from the authoritative run RNG.

Examples:

- rooms
- items
- rewards
- shops
- boss selection
- encounter generation

Independent visual randomness may use separate non-authoritative randomness.

## Content Definitions

Prefer Godot Resources or another explicit data-driven representation for content definitions.

Definitions should contain configuration.

Reusable behavior belongs in systems.

## Scene Philosophy

Godot scenes should represent reusable gameplay objects or environments.

Examples:

```text
player.tscn
zombie.tscn
projectile.tscn
combat_room_01.tscn
boss_room_01.tscn
```

Avoid enormous monolithic scenes where unrelated systems become tightly coupled.

## Performance Philosophy

Do not prematurely optimize.

Early priorities:

1. correct architecture
2. testability
3. playable iteration
4. profiling
5. optimization based on measured bottlenecks

Large horde counts will eventually require performance work, but optimization decisions should be driven by profiling.

## Dependency Direction

Core gameplay systems must not depend on specific content.

Preferred:

```text
content → reusable systems
```

Avoid:

```text
core system → specific item
```

## Major Architecture Constraints

The following require deliberate review before changing:

- Godot engine choice
- typed GDScript default
- `game/` versus `content/` separation
- seeded authoritative run RNG
- future server-authoritative multiplayer target
- composable item/effect system

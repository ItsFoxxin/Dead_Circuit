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

## v0.0.1 implementation boundary

The entry scene is the composition root and injects the authored sandbox content.
CombatSession owns the lifetime of explicit player/enemy instances and WaveManager.
CombatPlayer and MeleeEnemy share DamageableBody/HealthComponent; WeaponController
uses source-aware DamageContext and shared read-only configuration Resources.
Enemies receive a list of valid player candidates, not a global player singleton.
Concrete definitions, the five-wave configuration, enemy scene and greybox arena
live in content/. No item, procedural run, or networking system is introduced.
See [ADR 0003](adr/0003-combat-sandbox-authority-and-content.md).

## v0.0.2 item boundary

PlayerItemBuild owns per-player acquisition state and derives weapon values from
immutable definitions. Item triggers consume source-aware local combat events and
request reusable healing/explosion effects; core mechanics reference no item IDs.
CombatSession coordinates per-player offers and the wave reward gate. The concrete
five-item catalog is injected by content/rooms/combat_sandbox.tscn. Fixed offers
use no gameplay randomness. Secondary damage is attributed and bounded; restart
recreates builds and rejects stale selection commands. See
[ADR 0005](adr/0005-item-composition-and-wave-choices.md).

## v0.0.3 seeded authority boundary

CombatSession owns RunRandom under game/core/rng/ and injects it into authoritative
item offers. The same sequence rolls authored enemy spawn-marker permutations.
Eligible items are ordered by stable ID and offers by player ID before sampling;
no player, UI, physics callback or effect owns independent gameplay randomness.
Replay resets the seed alongside combat/build state; an explicit changed seed
uses the same reset path. This supersedes the fixed spawn/offer policies above.
Content still supplies the arena, item catalog and five-wave definition. There is
no room-transition framework, procedural graph, saved run or networking. See
[ADR 0006](adr/0006-authoritative-seeded-run-choices.md).

## v0.0.4 room lifetime boundary

RoomRunSession owns the authoritative RNG and RoomProgress for an authored route,
injecting the same sequence into its persistent CombatSession. Room changes replace
arena/encounter state while retaining explicit player actors, health, weapons and
builds. Full restart recreates actors and resets the route/RNG. The standalone
CombatSession retains its original independent lifetime for focused tests.
RoomDefinition/RunDefinition Resources compose concrete content without core room
IDs. Exit authority validates player identity, proximity, locks and generation
tokens. Treasure reuses the existing per-player offer path; boss is a staging role
only. This supersedes the single-arena boundary above without changing item,
ownership or determinism contracts. See [ADR 0008](adr/0008-authored-rooms-and-persistent-run-actors.md)
and [ROOM_FRAMEWORK.md](ROOM_FRAMEWORK.md). Procedural graphs, boss encounters and
networking remain unimplemented.

# Dead Circuit — Multiplayer Architecture Target

## Status

Multiplayer is a future feature.

Do not implement full networking during the earliest prototype milestones.

However, core gameplay architecture must remain compatible with the multiplayer target.

## Target

1–4 player cooperative multiplayer.

## Authority Model

Server authoritative.

The authoritative simulation owns gameplay-critical state.

Examples:

- enemy state
- damage
- kills
- run RNG
- room generation
- rewards
- item rolls
- boss state
- currency
- progression

Clients provide input and presentation.

## Single-Player

Single-player should use the same underlying gameplay authority pathways where practical.

Conceptually:

```text
Single player
    ↓
local authority
    ↓
gameplay systems
```

Future multiplayer:

```text
Client
    ↓
network
    ↓
server authority
    ↓
same gameplay systems
```

Avoid separate single-player and multiplayer implementations of core gameplay.

## Player State

Do not assume one global player.

Conceptually:

```text
RunState
├── PlayerState 1
├── PlayerState 2
├── PlayerState 3
├── PlayerState 4
├── floor state
├── room state
└── run seed
```

Single-player simply contains one player.

## Ownership

The following should retain player/source ownership where applicable:

- projectiles
- damage
- kills
- weapons
- item effects
- status effects
- currency rewards
- healing
- explosions
- deployable entities

## Damage

Damage context should include enough information to attribute gameplay effects to the correct player and source.

Conceptually:

```text
DamageContext

source_player_id
source_entity
source_weapon_id
damage_type
amount
critical
tags
```

## Randomness

The authoritative run system owns gameplay-critical RNG.

A shared seed assists reproducibility but is not a replacement for server authority.

Clients should not independently decide critical random outcomes.

## Cooperative Build Design

Different players should be able to develop independent builds during the same run.

Example:

```text
Player 1
shotgun/explosion build

Player 2
critical/chain build

Player 3
support/control build

Player 4
movement/close-range build
```

Multiplayer should benefit from build interaction rather than forcing identical progression.

## Revive Model

Future multiplayer should support a down/revive state rather than immediately removing players from the run.

Potential future effects may interact with:

- revive speed
- bleedout time
- self-revive
- revive explosions
- temporary shields
- ammunition restoration

Specific implementation is deferred.

## Early Multiplayer Validation

Target milestone:

`v0.1.5`

Potential test:

- two players
- local/LAN networking
- one combat room
- authoritative enemies
- synchronized damage
- separate item ownership
- one basic revive interaction

The purpose is to validate architecture before the project becomes large.

## Deferred Networking Problems

Do not solve these during initial single-player development unless required:

- public matchmaking
- NAT traversal
- host migration
- anti-cheat
- reconnect persistence
- dedicated public servers
- Steam networking
- production lobby systems

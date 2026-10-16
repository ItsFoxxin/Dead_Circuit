# Dead Circuit — Vision

## High-Level Concept

Dead Circuit is a first-person roguelike horde shooter where players survive increasingly dangerous combat encounters while constructing increasingly powerful and potentially broken builds.

Runs combine:

- first-person gunplay
- escalating enemy hordes
- procedural room progression
- build-defining items
- weapon evolution
- perks
- boss encounters
- risk/reward decisions
- exploration
- secrets
- replayable seeded runs

## Player Fantasy

A run should begin with the player feeling vulnerable.

A successful run should gradually transform the player into something capable of overwhelming situations that would have been impossible at the beginning.

The intended progression is:

```text
VULNERABLE
    ↓
CAPABLE
    ↓
POWERFUL
    ↓
ABSURD
    ↓
BROKEN
```

Strong synergies are desirable.

A run becoming dramatically overpowered is not inherently a balance failure.

## Core Pillars

### 1. Horde Fantasy

Combat should create pressure through enemy numbers, positioning, special enemies, elites, and bosses.

Difficulty should rely heavily on simultaneous threats rather than simply increasing enemy health.

### 2. Build Fantasy

Every run should create a different build.

Items and upgrades should meaningfully alter how the player fights rather than only increasing numerical stats.

### 3. Power Fantasy

Players should sometimes create combinations that feel outrageous.

The game should provide enough enemy escalation to challenge powerful builds without constantly suppressing player power.

### 4. Decision Pressure

Powerful choices should compete with:

- health
- currency
- opportunity
- alternate routes
- limited resources
- build compatibility
- risk
- exploration

Interesting decisions are more important than perfectly equal choices.

## Run Structure

A run is composed of multiple floors.

Each floor contains a generated graph of rooms such as:

- combat rooms
- treasure rooms
- shops
- challenge rooms
- events
- secret rooms
- boss rooms
- future special room types

A floor ends with a boss encounter.

Later floors introduce:

- stronger normal enemies
- elite enemies
- new encounter combinations
- increasingly dangerous bosses
- more complicated environmental mechanics

## Progression Layers

Dead Circuit intends to use multiple progression systems that serve different purposes.

### Items

Modify the player's overall build.

Examples:

- additional projectiles
- homing
- piercing
- chain effects
- explosions
- status effects
- movement interactions
- on-kill effects
- defensive mechanics

### Weapons

Define the player's primary combat tool.

### Weapon Evolution

Weapon-specific progression changes what a specific weapon is capable of doing.

This is distinct from general item progression.

### Perks

Provide comparatively stable improvements to fundamental player capabilities.

Examples include:

- health
- reload
- mobility
- critical effectiveness
- revive behavior
- ammunition efficiency

### Deals / High-Risk Rewards

Later versions may contain systems where players sacrifice something valuable for unusually powerful rewards.

These should create meaningful run-defining decisions.

## Boss Philosophy

Early bosses may resemble enhanced elite enemies.

Later bosses should increasingly test:

- movement
- positioning
- damage output
- target prioritization
- crowd control
- build flexibility
- environmental awareness

Bosses should not be defined only by large health pools.

## Multiplayer Vision

Future target:

**1–4 player cooperative multiplayer**

Players should be able to develop dramatically different builds during the same run.

Multiplayer should emphasize build interaction rather than forcing every player into identical progression.

See `MULTIPLAYER.md`.

## What Dead Circuit Is Not

Dead Circuit is not:

- a Minecraft mod
- a Call of Duty mod
- a Binding of Isaac mod
- a direct recreation of another game
- a passthrough project combining existing executables

It is a standalone original game inspired by design principles found in multiple genres.

## Initial Success Criterion

Before large-scale development continues, the game must answer:

> Is surviving first-person zombie-style hordes while constructing a roguelike build fun enough that the player immediately wants another run?

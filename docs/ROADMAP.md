# Dead Circuit — Early Roadmap

## Development Philosophy

Every early version should introduce a permanent system while leaving the game in a testable state.

Prototype work should become the foundation of the real game wherever practical.

## v0.0.0 — Development Foundation

Status: Complete. The foundation at `13c00c2` passed local and native Windows/Linux
CI validation and exports. Its Windows CI artifact was manually launched successfully.
Phase 0 is closed; the next implementation milestone is the v0.0.1 candidate.

Goal:

Create a reliable development harness before gameplay implementation.

Requirements:

- Godot project initializes successfully
- project structure established
- typed GDScript conventions established
- automated tests available
- lint/format validation available
- headless project validation
- initial export configuration
- GitHub Actions CI
- development build artifact generation

## v0.0.1 — Combat Sandbox

Goal:

Prove basic FPS combat works.

Features:

- first-person movement
- mouse look
- player health
- player death/restart
- one pistol
- ammunition
- reload
- one zombie enemy
- basic pursuit
- basic attack
- damage/death
- simple spawning
- five waves
- minimal HUD

Success criteria:

The player can launch the game, survive waves, kill enemies, die, and restart without broken state.

## v0.0.2 — Item / Synergy Proof

Goal:

Prove that independent item effects compose correctly.

Initial items may include:

- damage increase
- fire-rate increase
- Split Chamber
- Volatile Rounds
- basic healing/lifesteal effect

Critical requirement:

Split Chamber and Volatile Rounds must interact without combination-specific code.

## v0.0.3 — Seeded Runs

Goal:

Introduce authoritative deterministic run RNG.

Initial seed usage:

- upgrade choices
- encounter rolls
- future procedural systems

Same seed should reproduce authoritative random choices where expected.

## v0.0.4 — Room Framework

Goal:

Move from one arena into persistent room-based run state.

Initial room types:

- start
- combat
- treasure
- boss

Procedural graph generation is not required yet.

## v0.0.5 — First Boss

Goal:

Introduce boss framework.

First boss should test:

- boss health/state
- boss attacks
- enemy adds if applicable
- boss reward
- floor completion

Complex cinematic behavior is out of scope.

## v0.1.0 — First Complete Vertical Slice

Goal:

Complete a short run that can be replayed.

Target content:

- 1 floor
- 3 weapons
- 2 normal enemy types
- 1 boss
- 10–15 items
- approximately 5 room types
- shop
- seeded variation

Target run length:

Approximately 10–20 minutes.

Primary question:

> Does finishing or losing a run make the player want to immediately start another?

This is the first major go/no-go design gate.

## v0.1.5 — Multiplayer Architecture Test

Only begin after the solo core loop is functional.

Goal:

Validate architecture with a minimal two-player test.

Possible scope:

- two players
- one room
- synchronized enemies
- authoritative damage
- separate item ownership
- basic revive
- no matchmaking
- no production networking features

This is an architecture validation milestone, not a multiplayer release.

## v0.2.x — Roguelike Foundation

Planned systems:

- procedural room graph
- room pools
- item pools
- secrets
- deeper routing decisions
- floor generation

## v0.3.x — Horde Shooter Progression

Planned systems:

- points/economy
- additional weapons
- random weapon acquisition
- perks
- weapon evolution
- expanded enemy pressure

## v0.4.x — Risk / Deal Systems

Planned systems:

- high-risk reward paths
- alternate reward pools
- major run-defining sacrifices
- deeper boss rewards

## Deferred Until Core Loop Is Proven

Do not prioritize:

- final art
- story/lore
- full multiplayer
- Steam integration
- achievements
- character roster
- extensive meta-progression
- large weapon library
- large item library
- production audio
- cinematic sequences
- online matchmaking
- dedicated public infrastructure

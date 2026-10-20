# Dead Circuit — Early Roadmap

## Development Philosophy

Every early version should introduce a permanent system while leaving the game in a testable state.

Prototype work should become the foundation of the real game wherever practical.

## v0.0.0 — Development Foundation

Status: Complete. The foundation at `13c00c2` passed local and native Windows/Linux
CI validation and exports. Its Windows CI artifact was manually launched successfully.
Phase 0 is closed.

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

Status: Complete and accepted (`0.0.1`) on main. Windows development artifact manual
acceptance **PASSED** on 2026-10-16, as confirmed by the project owner.
Automated coverage includes health,
attributed hitscan damage, ammo/reload, wave progression, navigation/melee, input/
collision, death, completion, and session reset. The Phase 0 harness and native
development exports remain required. See [COMBAT_SANDBOX.md](COMBAT_SANDBOX.md).

Movement and combat feel are accepted as an early prototype foundation only.
Movement, weapon feel, balance, visuals, AI and combat polish are not finalized.
PR #7 merged at `dc4299a`. The v0.0.1 GitHub pre-release was published manually.
Approved-tag release automation is separate infrastructure; it adds no gameplay
and preserves that historical pre-release. See DEVELOPMENT.md and ADR 0004.

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

Status: Complete and accepted (`0.0.2`). The project owner confirmed Windows
manual acceptance **PASSED** on 2026-10-16 and approved promotion to main.
Per-player item builds, ordered modifiers, source-aware triggers/effects, five
prototype items, post-wave choices and build visibility are implemented. Automated
tests cover composition, attribution, non-recursive explosions, healing, selection
and reset. See [ITEM_SYSTEM.md](ITEM_SYSTEM.md) for exact rules and the manual gate.
The [v0.0.2 pre-release](https://github.com/ItsFoxxin/Dead_Circuit/releases/tag/v0.0.2)
contains verified Windows/Linux game ZIPs and update notes. Movement, combat feel,
item balance and visuals remain prototype quality. Later milestone gameplay is
not included in that release.

Goal:

Prove that independent item effects compose correctly.

Implemented prototype items:

- Heavy Lead
- Rapid Mechanism
- Split Chamber
- Volatile Rounds
- Vampiric Ammo

Critical requirement:

Split Chamber and Volatile Rounds must interact without combination-specific code.

## v0.0.3 — Seeded Runs

Status: Complete and accepted (`0.0.3`). Owner acceptance **PASSED** on 2026-10-16;
main promotion and release are explicitly approved.
Session-owned seeded RNG drives distinct item offers and enemy spawn-marker rolls.
Seed display, validated input and replay reset are implemented. See
[SEEDED_RUNS.md](SEEDED_RUNS.md) and ADR 0006 for contracts and the acceptance
record. v0.0.4 Room Framework was subsequently accepted.

Goal:

Introduce authoritative deterministic run RNG.

Initial seed usage:

- upgrade choices
- encounter rolls
- future procedural systems

Same seed should reproduce authoritative random choices where expected.

## v0.0.4 — Room Framework

Status: Complete and accepted (`0.0.4`). The owner approved main promotion
and release on 2026-10-16. The authored start → five-wave combat → treasure →
boss-staging route preserves player state and seeded authority between rooms
and resets the entire run on Replay. Movement/combat and presentation remain
prototype quality. See [ROOM_FRAMEWORK.md](ROOM_FRAMEWORK.md) and ADR 0008.
v0.0.5 First Boss was subsequently accepted and released; v0.0.6 Weapon Variety
is the active development candidate.

Goal:

Move from one arena into persistent room-based run state.

Initial room types:

- start
- combat
- treasure
- boss

Procedural graph generation is not required yet.

## v0.0.5 — First Boss

Status: Complete and accepted (`0.0.5`). The owner approved dev promotion on
2026-10-16, then confirmed manual acceptance and authorized main promotion/release
on 2026-10-17.
Adds one pursuing telegraphed-slam boss, attributed damage/death, boss item choice
and one-floor completion/restart. The owner requested one Treasure item plus one
boss item, no wave items, and occasional small room-clear supplies. Exit panels
are flush to the wall and room/EXIT text faces the camera. See
[FIRST_BOSS.md](FIRST_BOSS.md) and ADR 0009. v0.0.6 is now implemented as a dev
candidate and remains a separate acceptance boundary.

Goal:

Introduce boss framework.

First boss should test:

- boss health/state
- boss attacks
- enemy adds if applicable
- boss reward
- floor completion

Complex cinematic behavior is out of scope.

## v0.0.6 — Weapon Variety

Status: Development candidate implemented (`0.0.6`); automated and native build
gates must pass on `dev`, followed by owner Windows artifact acceptance before
main promotion or release. See [WEAPON_VARIETY.md](WEAPON_VARIETY.md) and ADR 0011.

Goal:

Prove that substantially different weapons use one reusable weapon/item
architecture without weapon-specific hacks in player, item, enemy or run systems.

Target content:

- retain the Service Pistol
- add approximately two original weapons, targeting three total
- use an automatic/SMG-style archetype and a shotgun/multi-pellet archetype unless
  implementation evidence supports a comparably scoped alternative
- add weapon switching and preserve independent weapon/ammo state
- define fire rate, magazine/reserve behavior and shot behavior in data
- keep Heavy Lead, Rapid Mechanism, Split Chamber, Volatile Rounds and Vampiric
  Ammo compatible through shared mechanics

Required automated proof includes switching, independent ammo and reload state,
firing semantics, ownership attribution and representative combinations of all
five existing items across the three archetypes. Items may use legitimate weapon
tags/categories, but must not depend on specific weapon IDs merely to work.

Acceptance question:

> Can Dead Circuit support substantially different weapons through one reusable weapon/item architecture?

Production animation, audio, recoil polish and a large weapon library are out of
scope.

## v0.0.7 — Enemy Variety

Status: Planned after accepted v0.0.6.

Goal:

Create different combat pressure through enemy composition instead of only larger
enemy counts.

Target content and system proof:

- retain the Basic Zombie
- add at least one second normal enemy archetype, initially a faster lower-health
  runner unless a similarly bounded alternative better proves the architecture
- configure mixed encounter groups through data
- reuse health, damage, navigation, attributed death and encounter bookkeeping
- choose targets from explicit valid-player candidates
- add no hard-coded enemy-pair behavior

Required tests cover health/damage, target selection, behavior/state transitions,
source-aware death and mixed encounter tracking/reset.

Acceptance question:

> Do different enemy combinations force the player to move and fight differently?

Advanced AI, production animation, complex special-enemy systems and a large
roster are out of scope.

## v0.0.8 — Shop / Economy Prototype

Status: Planned after accepted v0.0.7.

Goal:

Introduce the minimum limited-resource economy needed for meaningful spending
decisions during a run.

Target content and system proof:

- keep currency/resource state with the appropriate player or run owner
- keep future players' balances conceptually independent
- generate applicable shop inventory from the authoritative seeded run RNG
- validate offer, buyer, ownership, price, room/session generation and purchase
- prevent negative currency and duplicate/stale purchases
- apply rewards through existing item, health, ammunition and weapon systems
- persist valid shop/economy state for the run and clear it on full restart
- offer a small useful mix such as an item, healing, ammunition or weapon-related
  choice; add rerolls only when the scoped design needs them

Required tests cover spending, insufficient funds, nonnegative balances, purchase
ownership, seeded offers, persistence and reset.

Acceptance question:

> Does limited spending create meaningful decisions during the run?

The complete future horde-shooter points/progression economy and finalized balance
are out of scope.

## v0.0.9 — Vertical Slice Assembly

Status: Planned after accepted v0.0.8.

Goal:

Combine the permanent systems from v0.0.0–v0.0.8 into one coherent short floor.
Focus on integration, pacing, content expansion and regression hardening rather
than another large architecture system.

Target floor flow:

```text
Start
  → Combat
  → Treasure / reward decision
  → Combat
  → Shop
  → additional encounter / challenge
  → Boss
  → Floor Complete
```

Exact routing may use the established room framework. By milestone completion the
candidate should contain three usable weapons, at least two normal enemy types,
one boss, approximately five meaningful room types, the shop, seeded variation,
a significantly expanded item pool, coherent 10–20 minute pacing and a clean
death/completion/replay lifecycle. Multiple runs should differ noticeably without
state leaking between attempts.

Required tests cover the complete seeded route, room transitions, item/weapon/
economy persistence, boss completion and full replay reset.

Acceptance question:

> Can all current systems coexist for a full 10–20 minute run without architectural or state-management failures?

Production art/audio and broad polish are out of scope.

## Item content growth through v0.1.0

The accepted v0.0.2–v0.0.5 milestones retain their actual five-item catalog. From
v0.0.6 onward, use small reviewed content pull requests to grow toward these
cumulative planning targets:

| Milestone | Approximate cumulative target |
| --- | ---: |
| v0.0.6 | 10–12 items |
| v0.0.7 | 12–15 items |
| v0.0.8 | 15–18 items |
| v0.0.9 | 18–25 items when safe and useful |
| v0.1.0 | a curated 15–20+ practical minimum |

These are not numerical release gates. Quality, distinct decisions, composability,
ownership and test coverage take priority, and weaker items may be deferred or
removed before v0.1.0. See [CONTENT_WORKFLOW.md](CONTENT_WORKFLOW.md) for the
Codex/FoxForge boundary, item design mix, escalation rule and pull-request policy.

## v0.1.0 — First Complete Vertical Slice

Status: Planned design-validation milestone after accepted v0.0.9. It should
consolidate and tune proven systems instead of introducing a giant new architecture.

Goal:

Complete a short run that can be replayed.

Target content:

- 1 floor
- 3 weapons
- at least 2 normal enemy types
- 1 boss
- approximately 15–20+ curated items when practical; 10–15 remains a floor if
  development capacity or quality requires a smaller pool
- approximately 5 room types
- shop
- seeded variation
- complete death, completion, restart and replay lifecycle

Target run length:

Approximately 10–20 minutes.

Primary question:

> Does finishing or losing a run make the player want to immediately start another?

This is the first major go/no-go design gate.

Secondary questions:

- Do builds diverge meaningfully?
- Do weapon choices matter?
- Do enemy combinations alter positioning?
- Are item choices exciting?
- Does the shop create opportunity cost?
- Does the boss provide a satisfying run endpoint?
- Does seeded variation create replay value?
- Do powerful combinations begin the intended break-the-run fantasy?

Production art, audio and polish are not required for this design gate.

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

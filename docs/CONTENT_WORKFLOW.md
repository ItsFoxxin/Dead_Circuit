# Dead Circuit — Content Production Workflow

## Purpose

This document defines how Codex and FoxForge can expand Dead Circuit through
v0.1.0 without weakening the architecture or accumulating one-off gameplay code.
It supplements AGENTS.md, ARCHITECTURE.md, ITEM_SYSTEM.md, TESTING.md and the
milestone sequence in ROADMAP.md. The lasting responsibility and escalation
decision is recorded in [ADR 0010](adr/0010-bounded-content-production.md).

Every content change must preserve these boundaries:

- reusable mechanics and schemas belong under `game/`
- concrete weapons, enemies, items, rooms and loot definitions belong under
  `content/`
- authoritative random choices use the injected run RNG
- player/source ownership survives damage and effect chains
- player-owned state remains separate per player
- core systems do not reference specific content IDs without an explicit design
  reason
- item synergies emerge through shared modifiers, events, conditions and effects

## Responsibility boundary

Codex owns work that changes the reusable language of the game:

- architecture and new reusable systems
- effect, condition, trigger and shot-behavior primitives
- schemas, validators and core event contracts
- run-state and gameplay-authority design
- multiplayer-future ownership rules
- major refactors, migrations and cross-system integration
- difficult regressions spanning multiple systems

FoxForge owns bounded content work when existing systems can express it:

- one concrete passive item or a small coherent item group
- concrete data definitions and Resources
- descriptions, tags and catalog entries
- focused content tests and validation fixtures
- small content-only pull requests

Neither role may bypass AGENTS.md, architectural boundaries, tests, content
validation or CI. FoxForge does not independently redesign foundational systems.

## Existing-primitives rule

FoxForge may implement an item independently only when existing reusable
primitives fully describe it. These may include an existing:

- stat modifier
- trigger, condition or effect
- damage type or tag
- health behavior
- hitscan or projectile behavior
- player-owned state or run-owned state

For example, a passive item that raises damage through the existing modifier,
reduces magazine capacity through the existing modifier, includes tests and passes
content validation is appropriately bounded.

If the item needs a genuinely new reusable mechanic, FoxForge must stop before
adding a special case and report:

```text
NEW PRIMITIVE REQUIRED

Desired behavior:
Missing reusable capability:
Why existing primitives are insufficient:
Suggested tests and acceptance behavior:
```

Examples include chain lightning, homing, armor conversion, overhealth, a new
status-effect architecture, a new damage classification, persistent summons or an
unusual projectile lifecycle. Codex designs, implements and validates the reusable
primitive. FoxForge may resume concrete content production after that primitive
lands on `dev`.

## Item composition rules

Do not add pair-specific combination code. Split Chamber changes shared shot
behavior; Volatile Rounds reacts to eligible kill events. Their interaction works
because both use the common combat pipeline. There must be no equivalent of:

```text
if split_chamber and volatile_rounds:
    special_combination_behavior()
```

unless a future milestone deliberately introduces unique combinations as a
reusable game system. Definitions remain data-driven and per-player item state
remains owned by that player. Secondary effects keep the original source player,
entity and weapon attribution.

As the pool grows, use a deliberate mix rather than only numerical upgrades:

1. simple stat tradeoffs
2. event-triggered effects
3. conditional bonuses
4. survivability changes
5. projectile or shot-behavior changes
6. kill-triggered effects
7. movement/combat interactions supported by existing primitives
8. economy/resource interactions after the economy exists
9. weapon-category interactions after tags/categories exist
10. unusual build-defining items that still compose through shared mechanics

## Item growth plan

The accepted v0.0.2–v0.0.5 history contains the original five-item prototype
catalog. Earlier milestones are not being rewritten to claim content they did not
ship. From v0.0.6 forward, item content should grow in small reviewed pull requests
instead of arriving as one v0.0.9 content dump.

| Milestone | Cumulative planning target | Purpose |
| --- | ---: | --- |
| v0.0.2–v0.0.5 | 5 implemented | Accepted composition proof and retained baseline |
| v0.0.6 | approximately 10–12 | Exercise the original effects across three weapon archetypes |
| v0.0.7 | approximately 12–15 | Add conditional and enemy-pressure interactions |
| v0.0.8 | approximately 15–18 | Add bounded economy/resource interactions |
| v0.0.9 | approximately 18–25, if safe and useful | Provide meaningful full-floor variation |
| v0.1.0 | curated 15–20+ practical minimum | Retain the strongest tested pool for design validation |

These are planning targets, not numerical release gates. A smaller, distinct and
well-tested pool is better than filler or fragile content. Items may be removed or
deferred before v0.1.0 when they duplicate another choice, obscure the design test
or require unsafe scope. Quality, composability, ownership, reset behavior and
meaningful decisions determine acceptance.

## Git and review workflow

Start each content task from the latest `origin/dev`:

```text
dev
  ↓
foxforge/item-<item-name>
  ↓
small focused pull request targeting dev
  ↓
automated CI
  ↓
review and focused playtest when appropriate
  ↓
dev
```

Use one item or a very small coherent group per pull request. Do not keep long-lived
FoxForge branches or combine unrelated content. Delete the task branch after merge.
This keeps review, regression isolation and rollback practical.

System work follows the same task-branch and pull-request flow under a
`codex/<short-task-name>` branch.

## Milestone and release workflow

For every gameplay milestone from v0.0.5 through v0.1.0:

1. define the exact scope and acceptance target
2. create task branches from the current `dev`
3. implement only that milestone
4. add targeted automated tests and content validation
5. keep the complete regression suite green
6. integrate reviewed task pull requests into `dev`
7. generate Windows and Linux development artifacts
8. manually playtest the accepted artifact where gameplay feel matters
9. fix blocking milestone issues and record acceptance
10. promote accepted `dev` to `main`
11. create the explicitly approved version tag
12. let the release workflow publish the GitHub pre-release
13. return integration work to `dev` for the next milestone

Do not begin the next milestone before the current milestone reaches its accepted
promotion boundary unless the owner explicitly authorizes overlapping work. All
v0.x releases remain permanent pre-releases. v1.0.0 is the first stable release
unless project policy changes.

## Verification expectations

Content-only changes still need focused automated evidence where useful. Item tests
cover modifier math, trigger conditions, attribution, reset, stacking and relevant
cross-item composition. The validator must reject invalid IDs, references, values,
tags and schemas. A content pull request also keeps formatting, lint, import,
determinism, gameplay smoke and existing regression gates green.

New reusable systems require the broader coverage listed in TESTING.md and their
roadmap milestone. Generated artifacts and green CI demonstrate automated and
native startup checks; subjective playability remains a separate manual gate.

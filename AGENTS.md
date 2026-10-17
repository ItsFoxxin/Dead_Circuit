# Dead Circuit — Agent Instructions

Dead Circuit is a standalone first-person roguelike horde shooter built with Godot.

These instructions define the engineering constraints that automated coding agents must follow when modifying this repository.

## Project Stack

- Engine: Godot 4.7.x stable
- Primary language: typed GDScript
- Target platforms initially: Windows and Linux
- Version control: Git
- Primary development branch: `dev`
- Stable/release branch: `main`

Do not change the engine, primary language, directory architecture, or major architectural contracts without updating the relevant documentation and explicitly documenting the reason.

## Required Reading

Before making architectural changes, read:

- `docs/VISION.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`

Before modifying specialized systems, also read the relevant document:

- Items/effects: `docs/ITEM_SYSTEM.md`
- Multiplayer-sensitive architecture: `docs/MULTIPLAYER.md`
- Tests/validation: `docs/TESTING.md`
- Core run behavior: `docs/GAMEPLAY_LOOP.md`

Documentation is the source of truth for intended architecture.

## Directory Responsibilities

Reusable gameplay mechanics belong in:

`game/`

Specific game content belongs in:

`content/`

Examples:

Reusable projectile behavior belongs in `game/`.

The definition for a specific item named "Split Chamber" belongs in `content/`.

Do not place content-specific behavior inside core systems when the same result can be represented through reusable mechanics.

## Architectural Rules

1. Prefer modular systems over feature-specific implementations.
2. Do not hard-code item combinations.
3. Items should compose through modifiers, triggers, conditions, and effects.
4. Gameplay-critical randomness must use the authoritative seeded run RNG.
5. Do not create gameplay systems that assume exactly one player exists.
6. Player-owned objects and effects must retain source ownership when relevant.

This includes:

- damage
- kills
- projectiles
- weapons
- item effects
- currency changes
- status effects

7. Future multiplayer target is 1–4 player server-authoritative cooperative multiplayer.

Do not prematurely implement networking.

Do not introduce architecture that would require core gameplay systems to be rewritten to support multiplayer later.

8. Avoid direct dependencies between unrelated gameplay systems.

Prefer signals, explicit interfaces, data resources, or defined events.

9. Use typed GDScript for production gameplay code.

10. Prefer data-driven definitions for:

- items
- weapons
- enemies
- bosses
- rooms
- loot tables
- wave configurations

11. Do not silently remove working functionality to simplify implementation.
12. Do not introduce large dependencies without a documented reason.
13. Keep individual systems small enough to test independently.

## Determinism

A run must have an authoritative seed.

Systems that affect run generation must derive randomness from the run RNG rather than independent unseeded random generators.

This includes, when applicable:

- room generation
- item rolls
- loot
- shops
- bosses
- encounter selection
- procedural rewards

Perfect deterministic physics simulation across machines is not required.

The authoritative game state remains the source of truth.

## Multiplayer Compatibility

Single-player should use the same gameplay authority model intended for multiplayer where practical.

Do not use a global singleton representing "the player" for player-owned gameplay state.

Prefer explicit player identifiers and `PlayerState`-style abstractions.

See `docs/MULTIPLAYER.md`.

## Testing

A feature is not complete merely because it compiles.

Before declaring work complete:

1. Run applicable automated tests.
2. Run formatting/lint validation.
3. Confirm Godot can import the project.
4. Run content validation where relevant.
5. Run applicable smoke tests.
6. Verify deterministic behavior when the change affects seeded systems.

When fixing a reproducible bug, add a regression test when practical.

See `docs/TESTING.md`.

## Documentation

Update documentation when an architectural contract changes.

Do not update documentation merely to describe temporary implementation details.

For significant architectural decisions, add an ADR under:

`docs/adr/`

## Scope Discipline

Implement only the scope required by the current milestone unless necessary infrastructure is explicitly justified.

Do not expand a task into unrelated systems.

Early development prioritizes:

- correctness
- modularity
- testability
- iteration speed

over:

- final art
- graphical polish
- production content volume
- premature optimization

## Branch Workflow

Permanent branches:

- `main` — accepted/released milestones only
- `dev` — active integration branch for the next milestone

Task branches must be created from the latest `origin/dev`.

Allowed task namespaces:

- `codex/<short-task-name>` — major systems, architecture, large refactors
- `foxforge/<short-task-name>` — small scoped local-agent tasks
- `dependabot/*` — automated dependency updates

All Codex and FoxForge task branches must target `dev` through a pull request.

Never:

- develop directly on `main`
- develop directly on `dev`
- merge a task branch directly to `main`
- reuse an old task branch for unrelated work

After a task PR is merged into `dev`, its branch should be deleted.

Promotion flow:

```text
task branch → dev → manual acceptance/playtest → main → release
```

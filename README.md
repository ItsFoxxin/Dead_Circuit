# Dead Circuit

**Dead Circuit** is a first-person roguelike horde shooter built around procedural runs, evolving weapons, escalating bosses, and increasingly broken item synergies.

A run begins with limited resources and a basic build.

As the player progresses, items, weapons, perks, upgrades, encounters, and high-risk choices combine into increasingly powerful builds capable of handling increasingly dangerous hordes and bosses.

The design takes inspiration from the escalating survival pressure of wave-based horde shooters and the build-driven run structure of modern roguelikes while developing its own systems, world, content, and identity.

## Current Status

Phase 0 (`v0.0.0 — Development Foundation`) is complete: a minimal Godot
launch surface, typed GDScript, automated validation, and development exports.
The completed and accepted **v0.0.1 — Combat Sandbox** introduced first-person
movement, one hitscan pistol, pursuing melee zombies, five waves, HUD, death and
clean restart. Windows development artifact manual acceptance **PASSED** on
2026-10-16. Movement and combat are accepted as an early prototype foundation;
feel, balance, visuals, AI and polish are not finalized.
See [Combat Sandbox](docs/COMBAT_SANDBOX.md) for controls and the acceptance record.

**v0.0.2 — Item / Synergy Proof is complete and accepted**:
five unique items, per-player builds, composable modifiers and kill effects,
between-wave choices and build visibility. The project owner confirmed manual
Windows acceptance on 2026-10-16 and approved promotion to main. See
[Item System](docs/ITEM_SYSTEM.md) for rules and the acceptance record.
The [v0.0.2 release](https://github.com/ItsFoxxin/Dead_Circuit/releases/tag/v0.0.2)
provides Windows/Linux game ZIPs, update notes, checksums and build provenance.
The historical v0.0.1 release is preserved.

**v0.0.3 — Seeded Runs is complete and accepted**: an
authoritative session RNG, reproducible spawn rolls and item offers, a visible
seed and explicit replay/change-seed controls. The owner accepted it on 2026-10-16
and authorized main promotion and release. See [Seeded Runs](docs/SEEDED_RUNS.md).

**[Download accepted game releases for Windows/Linux](https://github.com/ItsFoxxin/Dead_Circuit/releases).**
Choose a game ZIP under Assets; Source code archives are for development.

**v0.0.4 — Room Framework is complete and accepted**. The owner approved
main promotion and release on 2026-10-16. It adds an authored start/combat/
treasure/boss-staging route, persistent player state and whole-run restart.
See [Room Framework](docs/ROOM_FRAMEWORK.md) and the
[v0.0.4 release](https://github.com/ItsFoxxin/Dead_Circuit/releases/tag/v0.0.4)
for the downloadable build once publication completes.

**v0.0.5 — First Boss** is complete and accepted, with a telegraphed boss,
boss reward, floor completion and the requested item pacing / exit-sign fixes.
The project owner approved it for main and release on 2026-10-17; see
[First Boss](docs/FIRST_BOSS.md).

**v0.0.6 — Weapon Variety** is the active development candidate. It retains the
Service Pistol and adds the automatic Relay SMG, multi-pellet Scatterline Shotgun,
1/2/3 switching and independent weapon state through one reusable per-player
loadout. All five existing items remain compatible through shared modifiers and
source-aware events. Windows artifact manual acceptance is pending; see
[Weapon Variety](docs/WEAPON_VARIETY.md). The documented path through the first
complete vertical slice is in the [Roadmap](docs/ROADMAP.md), with bounded Codex
and FoxForge responsibilities in the
[Content Production Workflow](docs/CONTENT_WORKFLOW.md).

Development builds include a bounded testing console opened with backtick or F10.
It can inspect and set up player, item, weapon, health, enemy and run state without
being mounted in release builds. See the [Development Console](docs/DEVELOPER_CONSOLE.md).

A focused faction-item expansion is under review for the next playable development
test. It keeps the five established item IDs and mechanics while giving them new
player-facing identities, adds five lore factions as unrestricted metadata, and
expands the authored pool to 15 items. New generic effects cover hit counters,
timed buffs, lethal protection, fragments, chain damage, bounded seeded repeats,
extra rays, health costs and an owned companion. This work does not change the
project version or mark v0.0.6 accepted; see [Item System](docs/ITEM_SYSTEM.md).

For setup, validation, tests, and exports, see [Development](docs/DEVELOPMENT.md).

Current development priority:

> Prove that first-person horde combat combined with composable roguelike item synergies creates a replayable core loop.

See:

`docs/ROADMAP.md`

## Core Pillars

### Horde Fantasy

Large enemy counts, escalating pressure, aggressive combat, and increasingly dangerous encounters.

### Build Fantasy

Every run should develop differently through composable items, weapon evolution, perks, and other progression systems.

### Power Fantasy

Strong runs are intentionally allowed to become extremely powerful.

The goal is not to perfectly balance away broken builds.

The player should sometimes successfully break the run.

### Decision Pressure

Power competes with limited resources, health, exploration, alternate routes, upgrades, risk, and opportunity cost.

## Technology

- Godot 4.7.x
- Typed GDScript
- Git / GitHub
- Automated CI
- Data-driven content architecture

## Planned Multiplayer

Dead Circuit is initially being developed as a single-player game.

The architecture is intended to support future 1–4 player server-authoritative cooperative multiplayer.

Networking itself will not be implemented until the core gameplay loop is proven.

## Repository Structure

```text
game/       reusable gameplay systems
content/    specific gameplay content
docs/       project design and architecture
tests/      automated verification
tools/      project validation and development tooling
.github/    CI/CD and GitHub configuration
```

## Development Branches

```text
main
  stable milestones and releases

dev
  integrated active development

codex/*
  reusable systems, architecture and major integration tasks

foxforge/*
  bounded content tasks using established mechanics

dependabot/*
  automated dependency updates
```

All task branches start from current `dev` and return to `dev` through a focused
pull request. Accepted milestones promote from `dev` to `main`, then receive an
approved version tag and release.

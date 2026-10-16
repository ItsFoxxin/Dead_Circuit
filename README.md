# Dead Circuit

**Dead Circuit** is a first-person roguelike horde shooter built around procedural runs, evolving weapons, escalating bosses, and increasingly broken item synergies.

A run begins with limited resources and a basic build.

As the player progresses, items, weapons, perks, upgrades, encounters, and high-risk choices combine into increasingly powerful builds capable of handling increasingly dangerous hordes and bosses.

The design takes inspiration from the escalating survival pressure of wave-based horde shooters and the build-driven run structure of modern roguelikes while developing its own systems, world, content, and identity.

## Current Status

Dead Circuit has a Phase 0 (`v0.0.0`) development foundation: a minimal Godot
launch surface, typed GDScript, automated validation, and development exports.
The Combat Sandbox has not been implemented.

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

feature/*
fix/*
chore/*
  temporary working branches
```

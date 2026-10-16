# Dead Circuit — Testing and Verification

## Philosophy

A feature is not complete merely because it compiles or visually appears to work.

Dead Circuit should build automated verification alongside gameplay systems.

The goal is to detect regressions before they become difficult to isolate.

## Executable Development Harness

Run `python tools/dev.py validate` using the development venv after bootstrap.
See [DEVELOPMENT.md](DEVELOPMENT.md) for installation and individual commands.
GUT suites retain build metadata, content validation, scene lifecycle, independent
instance state, launch, and seeded fixtures. v0.0.1 adds health/context, weapon
ammo/cooldown/reload, wave bookkeeping and stale-callback rejection; integration
tests exercise actual physics hitscan, wall occlusion, melee, multiple target
candidates, and navigation pursuit. Gameplay tests exercise synthetic local input,
gravity/grounding/wall collision, sprint, mouse-look limits, five-wave completion,
death, pause, restart and discarded actor/timer state. Independent headless
processes also compare fixture RNG sequences. These fixtures do not implement
the authoritative gameplay RNG scheduled for v0.0.3.

Python harness regression tests verify failure detection for zero-exit engine
errors, missing smoke markers, nonzero exits, and absent/empty/failed/pending
JUnit reports. Content validation now verifies the explicit prototype schemas,
IDs, numeric bounds, and scene dependencies/arena structure. Tests cover invalid
numeric values, duplicate IDs, wrong wave counts, and unregistered content.

CI runs validation before native Windows/Linux test suites, then permits dev
build exports. Each native exported executable must reach the launch marker and
exit cleanly before its artifact is uploaded. Logs, JUnit XML, JSON summaries,
build metadata and checksum files are preserved in Actions artifacts.

The main launch smoke still requires build provenance and its success marker;
it now waits for navigation synchronization, an initialized player and wave one
with the configured enemy count. No gate or engine warning severity is reduced.
Async scene fixtures use queued teardown so they are not freed inside startup
signal emission. Time-based physics tests use broad tolerances, not exact frames.

v0.0.2 adds per-player ownership, unique acquisition, base-definition immutability,
ordered stat composition, fixed offers, independent multishot physics, attributed
explosions with world occlusion, non-recursion and owned/clamped healing. Gameplay
tests verify between-wave gating, single/invalid/stale selection, real keyboard
selection, separate player choices and build/offer reset. The five-wave regression
also selects rewards and verifies fresh base stats after completion restart.
Content validation covers nested modifier/condition/trigger/effect schemas and
the authored five-item catalog. Determinism tests verify acquisition-order-independent
stats and fixed offers alongside the unchanged seeded fixtures.

The gameplay-oriented requirements below remain mandatory when their systems
are introduced. Authoritative seeded gameplay remains deferred to v0.0.3.
Synthetic input and automated completion do not replace a real keyboard/mouse
playthrough. v0.0.1's passed record is in COMBAT_SANDBOX.md; v0.0.2's Windows
manual acceptance passed on 2026-10-16, recorded in ITEM_SYSTEM.md.

## Validation Layers (contracts)

### Formatting

Typed GDScript should follow project formatting rules.

### Linting

Static issues should fail CI where appropriate.

### Project Import

Godot must be able to import the project successfully in headless CI.

### Unit Tests

Use unit tests for isolated reusable behavior.

Examples:

- damage calculations
- modifier calculations
- item stacking
- RNG helpers

### Integration Tests

Verify interactions between systems.

Examples:

- projectile damages enemy
- enemy death emits expected event
- item effect responds to kill
- room completion triggers reward

### Determinism Tests

Seeded systems must reproduce expected authoritative random decisions.

Example:

```text
Seed: 12345

Expected first three item rolls:
A
B
C
```

The exact test design may evolve as generation becomes more complex.

### Gameplay Smoke Tests

Critical gameplay paths should have automated or semi-automated checks where practical.

Examples:

- project launches
- run initializes
- combat room loads
- player can spawn
- run can restart

### Content Validation

Content definitions should be validated automatically.

Future checks may include:

- unique item IDs
- unique weapon IDs
- valid references
- valid effect names
- valid loot-table entries
- valid room exits
- required boss properties
- sane numeric ranges

## Initial Required Tests

### Damage Math

Example:

```text
base damage = 20
modifier = +30%

expected damage = 26
```

### Projectile Count

Example:

```text
base projectile count = 1
Split Chamber = +1
second compatible stack = +1

expected count = 3
```

### Event Propagation

When an eligible enemy is killed:

```text
ENEMY_KILLED
```

must contain correct source ownership.

An effect such as Volatile Rounds should activate exactly as intended.

### Run Reset

Starting a new run must reset:

- run items
- temporary player stats
- currency
- room state
- wave state
- boss state
- temporary effects

State must not leak between runs.

### Seed Reproduction

The same authoritative seed should reproduce expected random selections controlled by the run RNG.

## CI Expectations

Feature pull requests should eventually perform:

```text
format check
lint
Godot project import
unit tests
integration tests
determinism tests
content validation
smoke validation
```

`dev` should additionally produce development build artifacts.

`main` should require all release-gate checks before merge.

## Regression Tests

When a reproducible bug is fixed, add a test reproducing the failure when practical.

The test should fail before the fix and pass afterward.

## Release verification

release.yml adds approval and packaging around the existing foundation.yml gates;
it does not replace or reduce any test, engine warning level, or smoke requirement.
Tag format, both version files and origin/main ancestry are checked before the full
validation → native tests → fresh native release exports sequence. Failed native
Windows or Linux startup, missing packages/checksums, inconsistent provenance and
corrupted archives prevent publication. Only the final job can write a release.

Python harness coverage additionally tests semantic-tag/pre-release policy, annotated
tags and main-history rejection in temporary local Git repositories, version
mismatches, checksum corruption, missing native smoke/platforms, cross-run packages,
ZIP member safety and Linux execute bits. Mocked GitHub tests cover existing-release
refusal, remote-tag movement, preserving generated notes, upload failure, draft-only
cleanup, incomplete assets, and pre-release/stable publication policy. Workflow
structure tests preserve permissions, dependencies and ordinary dev/PR triggers.

Use the documented release-dry-run Actions input to exercise native builds and
packaging without a tag or release. Only this unpublished rehearsal bypasses tag/
main ancestry; a tag push must satisfy those checks. Passing mocks/dry runs is not
a claim that a live release was published. The first real publication remains a
deliberate accepted-milestone tag. Never modify the manual v0.0.1 release as a test.

## Manual Playtesting

Automated testing does not replace playtesting.

Important subjective questions include:

- Is shooting satisfying?
- Are item choices meaningful?
- Do builds feel different?
- Does combat pacing create pressure?
- Are powerful builds enjoyable?
- Does losing encourage another run?

These cannot be completely automated.

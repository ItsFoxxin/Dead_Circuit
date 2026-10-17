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
processes also compare fixture RNG sequences, retained alongside the v0.0.3
authoritative gameplay RNG tests.

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
it waits for navigation synchronization, an initialized player and run authority
in the safe Start Room with wave zero and no RNG draws. The standalone sandbox
startup regression still requires wave one with its configured enemy count.
No gate or engine warning severity is reduced.
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

v0.0.3 adds production RunRandom bounds, reset, instance isolation, seed parsing,
different-seed variation and pinned-engine compatibility. Real-session tests
exercise five-wave replay, spawn placement, changed-seed combat reset, rejected
command/pause/HUD RNG isolation, stable player-ID offer order, and keyboard seed
controls. The determinism command keeps both original fixture probes and adds two
independent full sandbox processes with different item preload orders. Their
five-wave spawn/offer/build records must match, contain valid distinct/unowned
choices, and consume the expected bounded choices.
Harness regression tests reject divergent, empty or malformed records; reports
include the actual authoritative rolls in determinism.json. Content validation
also rejects out-of-range authored sandbox seeds. No CI gate is reduced.

v0.0.4 adds room schema/order and exit-generation tests, persistent player state,
reload timers, explicit participant authority, locked combat and treasure exits,
multiple player choices, exhausted treasure, staging/completion and full death/
completion/transition restart. Two extra independent processes exercise the
production four-room route and whole-run reset, preserving the original fixture
and sandbox probes. Python tests reject incomplete/divergent routes and leaked
build/ammo/RNG state. Content validation requires authored room references, exit
markers, route order and the room HUD. See ROOM_FRAMEWORK.md for the owner acceptance record and
regression checklist; local automation alone does not approve a milestone.

The v0.0.5 suite additionally tests boss windup/escape/occlusion, pursuit,
source attribution and kill effects, pause/cancellation, gated boss item choices,
two-item floor pacing, seeded supply rolls, one-time nearby authorized collection,
floor completion and stale/restarted state. Two further independent processes
exercise the real boss route, both offers, room-clear drops and full reset without
changing older fixture expectations. Signage regressions calculate wall/panel
alignment and require camera-facing labels. See FIRST_BOSS.md for manual checks.

The gameplay-oriented requirements below remain mandatory when their systems
are introduced. Reproduction applies to authoritative choices with the same seed,
content/engine version, player roster and item selections, not physics or aim.
Synthetic input and automated completion do not replace a real keyboard/mouse
playthrough. v0.0.1's passed record is in COMBAT_SANDBOX.md; v0.0.2's Windows
manual acceptance passed on 2026-10-16, recorded in ITEM_SYSTEM.md.
v0.0.3 owner acceptance passed on 2026-10-16, recorded in SEEDED_RUNS.md.
Automated passes alone do not establish manual acceptance for later candidates.

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

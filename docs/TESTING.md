# Dead Circuit — Testing and Verification

## Philosophy

A feature is not complete merely because it compiles or visually appears to work.

Dead Circuit should build automated verification alongside gameplay systems.

The goal is to detect regressions before they become difficult to isolate.

## Executable Phase 0 Harness

Run `python tools/dev.py validate` using the development venv after bootstrap.
See [DEVELOPMENT.md](DEVELOPMENT.md) for installation and individual commands.
GUT suites cover build metadata and content validation (unit), scene lifecycle
and instance isolation (integration), a main-scene launch path (future gameplay
test location), and seeded test fixtures (determinism). Independent headless
processes also compare fixture RNG sequences. These fixtures do not implement
the authoritative gameplay RNG scheduled for v0.0.3.

Python harness regression tests verify failure detection for zero-exit engine
errors, missing smoke markers, nonzero exits, and absent/empty/failed/pending
JUnit reports. Content validation reports zero schemas/definitions in Phase 0
and rejects unregistered content. It does not yet validate gameplay semantics.

CI runs validation before native Windows/Linux test suites, then permits dev
build exports. Each native exported executable must reach the launch marker and
exit cleanly before its artifact is uploaded. Logs, JUnit XML, JSON summaries,
build metadata and checksum files are preserved in Actions artifacts.

The gameplay-oriented required tests below remain mandatory when their systems
are introduced. Phase 0 does not add combat or run behavior to satisfy examples.

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

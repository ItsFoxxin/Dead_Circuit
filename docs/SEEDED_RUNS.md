# Dead Circuit — v0.0.3 Seeded Runs

Status: Complete and accepted (`0.0.3`). The project owner confirmed acceptance
on 2026-10-16 and explicitly authorized promotion to main and a release.
This acceptance is separate from v0.0.2. Seeded runs retain prototype movement,
combat, item balance and presentation; those aspects are not finalized.

## Implemented boundary

CombatSession owns a RunRandom and resets it at the start of each attempt. The
initial consumers are enemy spawn-marker permutations and randomized item offers.
The five authored wave counts, zombie/pistol definitions, greybox arena and item
effects are retained. Encounter variation currently means spawn placement only;
it does not introduce encounter types, adaptive difficulty or procedural rooms.

Each wave uses a seeded permutation of all twelve authored markers, with no
repeated marker within the prototype wave. Offers contain up to three distinct
unowned items, sampled from a stable-ID-sorted pool. All living players' offers
are generated in ascending player ID order before selections are accepted.
Selections still validate ownership, session, wave and offered ID, grant once,
and wait for all pending players. Player builds remain separate from run RNG.

The same seed reproduces these authoritative rolls when engine/content/algorithm,
player roster and item choices match. Kill order, pause, elapsed frames, HUD updates
and rejected commands do not draw from this sequence. Physics, movement, aim,
damage timing and combat results are not deterministic across machines. Changing
item choices can change later eligible pools and roll consumption. There is no
cross-version compatibility promise, run save/load or input replay.

See [ADR 0006](adr/0006-authoritative-seeded-run-choices.md) for the exact policy.

## Controls and seed input

Existing movement, shooting, reload, selection and pause controls remain.
The HUD always displays the active seed. The authored default is **12345** on
every fresh launch; it does not silently randomize. Accept decimal integer seeds
from **0** through **2147483647**.

- **Replay seed [Enter]** on pause, death or completion resets health, ammo,
  actors, waves, items, pending offers, effects and RNG to the current seed.
- Enter another number in the seed field and use **Start seed** (or Enter while
  the field/button has focus) to reset the entire attempt using that seed.
- Invalid text disables Start seed and cannot start an attempt. Item selection
  still consumes Enter as a choice; it cannot accidentally invoke restart.

For a specific launch, using the pinned editor or a local Windows export:

```powershell
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --seed=42
& .\build\windows\DeadCircuit.exe -- --seed=42
```

Use the same `-- --seed=42` user arguments on Linux. Duplicate, missing, malformed
or out-of-range `--seed=` arguments fail startup. An omitted override uses the
authored default. Headless `--smoke` also reports the active seed.

## Automated verification

The existing complete validation command additionally covers production RNG
bounds/reset/isolation, parsing, engine fixture compatibility, canonical offer
order, real five-wave replay, actual spawn placement, changed-seed reset, stale
commands, independent player ordering, and keyboard seed controls. Content
validation rejects out-of-range sandbox defaults. No existing gate is disabled.

Determinism runs the original two engine-fixture processes and two full sandbox
processes with different item preload orders. Both full runs must produce matching
five-wave spawn/offer/build records, valid distinct/unowned choices and expected
RNG consumption. Records are saved
in `reports/determinism.json`, with per-process logs and all existing JUnit reports.

With seed 12345, the first spawn order is `[8,5,1,10,9,0,11,6,4,3,2,7]` and the
first offer is Rapid Mechanism, Heavy Lead, Vampiric Ammo. A reproducible path is
Rapid Mechanism after wave one, Volatile Rounds after wave two, then Split Chamber
after wave three for the synergy check. These are pinned development fixtures,
not balance or final-content promises.

## Manual acceptance — PASSED

The project owner accepted v0.0.3 on 2026-10-16 and approved main promotion and
release. The manual acceptance target is retained below for repeat testing:

1. Launch and confirm seed 12345, combat/HUD and the first reward pause work.
2. Note offers and choose a repeatable item path through all five waves.
3. Replay after completion using the same seed and item path; compare spawn
   placements and offers. Combat timing need not match.
4. Intentionally die, replay again and confirm fresh health/ammo/items/waves and
   the same initial rolls, with no stale effects or selection commands.
5. Pause and enter seed 42; use Start seed and confirm a full reset and changed
   initial placements. Replay 42 and confirm its initial sequence repeats.
6. Test seed 0, invalid text, mouse/keyboard activation and pause/resume. Verify
   that changing the seed field alone does not change the active attempt.
7. Retest existing item effects, five-wave completion and normal restart input.

Local exports and automated tests do not replace this keyboard/mouse playthrough
or native Linux execution. Dev CI continues to require native builds and startup.
Movement/combat remain prototype quality; no polish or v0.0.4 Room Framework is
included in this milestone. Native Linux smoke is automated, not a manual Linux
gameplay acceptance claim. The owner authorized v0.0.4 to follow onto dev for testing.

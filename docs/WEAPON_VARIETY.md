# Dead Circuit — Weapon Variety

v0.0.6 is the active development candidate. It tests whether distinct weapon
archetypes can share one source-aware weapon, item and damage architecture.

## Included weapons

| Slot | Weapon | Prototype role |
| ---: | --- | --- |
| 1 | Service Pistol | Semiautomatic baseline; 30 damage, 12-round magazine |
| 2 | Relay SMG | Automatic pressure; 12 damage, 36-round magazine, 12 shots/s |
| 3 | Scatterline Shotgun | Seven-pellet semiautomatic burst; 6-round magazine |

Press **1**, **2** or **3** to equip a weapon. Each weapon retains its own
magazine, reserve ammunition, reload progress and fire cooldown when another slot
is equipped. Room transitions preserve the complete per-player loadout. Death or
Replay creates a new player loadout and resets every weapon.

Weapon definitions provide damage, fire rate, fire mode, magazine/reserve values,
reload time, range, base shot count, spread, tags and the primitive view model.
The player, items, enemies and run systems contain no checks for these weapon IDs.

## Shared item behavior

Heavy Lead, Rapid Mechanism, Split Chamber, Volatile Rounds and Vampiric Ammo use
the same modifiers, combat events, source ownership and damage contexts for all
three weapons. Split Chamber adds one shot to the weapon's authored base count,
so it adds a second pistol/SMG ray and an eighth shotgun pellet. One trigger pull
still consumes one magazine round.

## Architecture boundary

`WeaponLoadout` belongs to each `CombatPlayer` and owns one mutable
`WeaponController` per definition. `CombatSession` injects the authored weapon
catalog into each player actor. The equipped controller remains available through
the existing player weapon surface, while loadout state is never global.

Hits remain deterministic authored ray patterns. Physics results are not promised
to reproduce across machines. Weapon switching consumes no run RNG.

See ADR 0011 for the decision and [TESTING.md](TESTING.md) for automated coverage.

## Manual acceptance checklist

Manual Windows artifact acceptance is pending. Verify:

- slots 1, 2 and 3 equip the expected weapon and update the HUD/view model
- the pistol fires once per click
- the Relay SMG continues firing while the button is held
- the Scatterline Shotgun creates a visibly wider multi-pellet hit pattern
- each weapon reloads from its own reserve and retains state after switching
- item choices affect the equipped weapon without disabling another slot
- room changes preserve all weapon states
- death and completion Replay reset all three weapons to a clean attempt
- pause/resume, five waves, boss completion and existing room flow still work

Weapon feel, production models, recoil, animation, audio and balance remain
prototype quality and are outside v0.0.6 acceptance.

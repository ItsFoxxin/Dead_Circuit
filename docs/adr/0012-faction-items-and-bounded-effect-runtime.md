# ADR 0012: Faction items and bounded effect runtime

- Status: Accepted for the faction-item development candidate
- Date: 2026-10-21
- Scope: Item identity and reusable item effects; no allegiance or progression system

## Context

The five-item prototype proved modifier and kill-trigger composition. Expanding
to 15 items requires hit counters, timed modifiers, lethal protection, health
costs, chains, fragments, probabilistic extra rays, controlled effect repetition
and a companion. Implementing each as a named item script would couple content to
core combat and make ownership, determinism and recursion rules inconsistent.
Faction identity also needs to appear in content and UI without becoming a build
restriction.

## Decision

`ItemFaction` is immutable descriptive metadata referenced by each
`ItemDefinition`. Faction metadata contains identity and lore; acquisition,
offers and effect execution do not branch on faction. The five established items
retain their stable IDs and mechanics while receiving new display names.

`DamageContext` adds an originating attack ID, primary/secondary state, effect
depth and independent trigger/healing eligibility. Weapon controllers allocate a
monotonic attack ID per owner and copy it to every ray. Derived damage uses
`secondary()` so player, entity and weapon attribution survives through chains,
fragments, explosions and repeats.

Reusable `ItemEffect` kinds express hit-count healing, timed stats, lethal guards,
health-cost buffs, chain damage, fragment bursts, approved repeats, extra rays
and companions. Concrete values and trigger conditions remain in `content/items`.
Runtime counters, stacks and timers live in each player's `PlayerItemBuild` and
`ItemEffectRunner`; no global item state or event bus is introduced.

All item probability consumes the `RunRandom` injected by the owning combat/run
authority. Extra-ray rolls occur once per primary weapon attack. Recursive Fault
can repeat only an effect definition explicitly marked eligible. Repeated and
other secondary contexts carry depth/eligibility metadata, and the runner enforces
a hard depth bound. Healing, defensive guards, passive modifiers and resource
costs are never repeatable.

Health costs use `HealthComponent.spend`, clamp at 1 HP and emit no damage event.
Damage-reactive effects require positive applied HP damage. Lethal protection is
owned by the player's health component and is recreated on full run restart.

Autonomous companions are per-player effect-runner children with an injected
target roster. Sentinel Node derives the owner's generic `damage` stat once per
attack, which makes Titan-Core Rounds apply once. It does not derive weapon fire
rate, shot count or ammunition, and companion contexts opt out of weapon-hit
counters and kill healing. Room changes preserve the player-owned companion;
whole-run restart recreates the player and removes it.

## Consequences

Items compose through shared events and metadata without named pair checks. The
same attack can count distinct targets while repeated hits on one target count
once for per-attack policies. Chains choose nearest unique living targets with a
stable instance-ID tie break. Fragments and electrical damage preserve ownership
without recursively producing more fragments, chains or replication.

The effect-kind enum and context fields become part of the content schema and must
remain validated. Current spatial effects scan the small authoritative target
roster; pooling or a broader spatial index can be added after profiling larger
hordes. Companion and effect visuals are placeholders. Armor is not implemented;
a future armor system must distinguish absorbed damage from positive HP damage.
Faction allegiance, faction-gated offers, character selection, permanent
progression and production presentation remain out of scope.

# ADR 0006: Session-owned seeded choices and explicit replay

- Status: Accepted; v0.0.3 owner acceptance passed on 2026-10-16
- Date: 2026-10-16
- Supersedes: ADR 0003's ordered spawn selection and ADR 0005's fixed offer policy

## Decision

CombatSession owns one RunRandom instance under game/core/rng/. It wraps the pinned
Godot RandomNumberGenerator, explicitly initializes its seed and exposes bounded
index choices and sampling without replacement. Never use global random functions,
Array.shuffle(), clock time, instance IDs, session tokens or player input timing to
make authoritative choices. Consumers receive the session RNG explicitly. This is
local gameplay authority, not a networking or global-player singleton.

Use one sequence, with explicit consumption order:

1. At each wave start, roll a complete permutation of the authored enemy spawn
   marker indices, then spawn the configured count in that order. Reuse the order
   cyclically only if an injected wave exceeds the number of markers. The prototype
   still has twelve markers and unchanged counts 3, 5, 7, 9, 12 and one enemy type.
2. At non-final wave clears, generate offers in ascending numeric player ID order.
   Filter null, duplicate and owned item IDs, sort the eligible pool by stable item
   ID, then sample up to three distinct choices with equal per-item probability.
   Offer order is also seeded. Roll every player's offer before accepting choices.
3. Valid choices change the player's build, then the existing reward gate advances
   the wave. Validation, rejected/stale commands, damage, kills, HUD updates and
   pause/resume consume no random choices. Empty/singleton pools consume none.

The RNG's draw_count counts bounded choices with more than one candidate, not
internal engine generator steps. No substreams, encounter director or random
content catalog is needed yet. The existing spawn roll is the initial encounter
consumer; enemy composition/counts, weapon spread and physics stay unchanged.
Future procedural systems must receive this authority, rather than invent an RNG.
Item ID ordering explicitly compares String text, including the existing build
modifier ordering. Comparing interned StringName identities in a custom comparator
can depend on allocation/load order and cannot define canonical seeded pools.

Restart resets the sequence and all existing combat/item state to the current
seed. Changing seed explicitly starts a fresh attempt through that same reset
path. Use nonnegative decimal seeds from 0 through 2147483647; zero is valid.
The content sandbox defaults to 12345, deliberately making development launches
repeatable. A validated --seed=<number> startup override and pause/death/completion
seed controls allow other attempts. Reject malformed, duplicate or out-of-range
startup arguments rather than silently substituting a seed. No automatic
time-based seed generation is introduced.

## Consequences

The same seed, content/algorithm version, player roster and item selections reproduce
the authoritative rolls with the pinned engine. Catalog reordering and player
container insertion order cannot change those rolls. Different selections may
change later eligible pools and sequence consumption. This is not deterministic
physics, an input replay system, a saved-run format, cross-version RNG compatibility
or a promise of equal combat outcomes. Godot's RNG algorithm is an implementation
detail; deliberate engine/content changes require fixture review.

Keep the original engine fixture and add production RNG tests, real-session replay,
separate-player ordering and independent-process five-wave probes with different
item preload orders. Existing CI
uses the extended harness without workflow or gate changes. v0.0.3's separate
owner acceptance passed on 2026-10-16, authorizing main promotion and release.
No networking, room transitions, procedural maps, new items or v0.0.4 systems are
introduced. All manual acceptance remains explicit.

## References

- https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html
- https://github.com/godotengine/godot/blob/4.7-stable/core/string/string_name.h

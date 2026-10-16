# v0.0.4 — Room Framework

Status: Complete and accepted. On 2026-10-16 the owner instructed both
milestones to move up one step: v0.0.4 to main/release and v0.0.5 to dev.
This records owner milestone approval; the checklist below remains the reference
for the accepted scope and further regression testing. It does not finalize
movement/combat feel, balance, AI or presentation. v0.0.6 has not started.

## Playable route

The launch scene now creates an authored four-room run:

1. Start: safe entry with normal movement/look/weapon controls.
2. Combat: the existing five waves, increasing enemy counts and between-wave item
   choices. Its exit stays locked until wave five is cleared.
3. Treasure: one existing per-player item choice; the exit unlocks once every
   pending participant chooses. An exhausted catalog creates no extra choice.
4. Boss staging: a labeled empty room. Its exit displays ROOM FRAMEWORK COMPLETE.
   Actual boss behavior, boss rewards and floor completion remain v0.0.5 work.

Approach the green EXIT marker and press **E** to advance. Combat, reload, sprint,
pause/resume, seed input and Replay controls are unchanged. There is no backtracking
or random graph. These rooms intentionally reuse temporary greybox geometry.

## State and authority

RoomDefinition and RunDefinition Resources live under content/rooms/. Reusable
RoomProgress and RoomRunSession live under game/run/, with room mechanics under
game/rooms/. The run authority owns a single CombatSession and RunRandom for the
attempt. CombatPlayer instances retain health, magazine/reserve, reload/cooldown,
items and explicit ownership across rooms. No player/RNG singleton is introduced.

Room entry replaces geometry and encounter enemies, clears transient effects and
wave bookkeeping, repositions players and waits for the new navigation region to
synchronize. Stale encounter callbacks and offers are invalidated. Exit requests
check player participation, life, proximity, room/attempt generations, locks,
pause and terminal states. A transition locks immediately; duplicate input cannot
skip rooms. Any valid living participant may advance the shared route; networking
and a multiplayer readiness protocol are not implemented.

Death or completion Replay resets the entire route, player actors, health, ammo,
items, offers, temporary effects, enemies, wave state and seeded RNG. A changed
seed also starts at the first room. The standalone Combat Sandbox remains usable
for existing combat regression coverage. See ADR 0008.

## Verification

Automated tests cover room schemas/order, lock/generation rules, real E input,
persistent health/ammo/items/source IDs, new navigation startup, multiple explicit
players, five-wave clearing, treasure exhaustion and independent choices, boss
staging, completion/death/transition restart, and changed seeds. The launch smoke
requires a live initialized player, run authority, zero-wave safe start, valid
navigation/exit and build provenance.

The existing RNG fixtures and standalone sandbox probes remain. Two additional
processes run the complete room route with different item preload orders, compare
all five combat waves and the final build/RNG consumption, then verify a clean
whole-run restart. Reports remain in reports/ and the existing CI artifact paths.

## Owner acceptance — approved 2026-10-16

Use the Windows dev artifact after CI validation (or a local development build):

1. Launch, move/look/sprint, reload, pause/resume and confirm the Start Room HUD.
2. Approach EXIT and press E; confirm combat begins once and the exit stays locked.
3. Complete all five waves and choices; confirm HP/ammo/build survive the next exit.
4. Choose the treasure item, enter Boss Staging and confirm its explicit placeholder
   message. Exit to ROOM FRAMEWORK COMPLETE; no boss victory should be implied.
5. Replay after completion; confirm Start Room, full base HP/ammo, empty build,
   wave zero and no old enemies, effects or offers.
6. Intentionally die in Combat, replay and repeat the route without stale state.
7. Change the seed while paused; confirm a full route reset, then replay that seed.
8. Retest mouse/keyboard item choices and rapid E input near each exit.

Headless tests and exports do not claim subjective playtest acceptance or native
Linux execution on this Windows host. Movement, combat, content and presentation
remain prototype quality. No v0.0.5 boss, procedural graph, economy, new item,
weapon, networking, progression or final polish is included.

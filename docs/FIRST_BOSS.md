# v0.0.5 — First Boss

Status: Implemented dev candidate, manual acceptance pending. On 2026-10-16
the owner accepted v0.0.4 for main/release and authorized v0.0.5 to move to dev.
v0.0.5 is not approved for main, a tag or release. v0.0.6 has not started.

## Playable boundary

The dev launch route is Start → five-wave Combat → Treasure → First Boss.
The original staging-only route and standalone sandbox remain regression fixtures.
Player health, ammo, build and source ID persist across rooms as before.

The Prototype Brute uses the existing navigation, target roster, health/damage and
kill-event path. It pursues a living target, stops inside 4 m and shows a red ground
disc for a 1.1-second slam windup. Move out before impact to avoid 30 damage.
Impact checks each living participant's current position and world occlusion.
Recovery lasts 0.8 seconds, followed by a 1.4-second attack cooldown. Pause freezes
timers; death, restart and room teardown cancel attacks. HP, name and attack state
appear on the development HUD. The 500-HP capsule and all numbers are temporary
test content, not finalized boss balance or presentation. There are no adds.

Boss defeat locks progression while players choose their reward. Once choices
finish, approach EXIT and press E for FLOOR COMPLETE. Replay after completion or
death resets the complete route, boss, players, rewards, supplies and RNG.

## Item and supply pacing

The owner corrected the v0.0.5 pacing: upgrades every wave made builds too easy.
For this new floor:

- All five waves run without item choices.
- The single Treasure Room offers up to three distinct unowned items; choose one.
- Boss defeat offers another unowned item choice to each living participant.
- Each participant gains two build items per floor with the authored five-item pool.
- The boss exit waits for every pending participant; repeated/stale selections fail.

After the Combat Room or boss room is fully cleared, make one authoritative seeded
25% roll for a small supply pickup. A successful roll chooses either 10 HP or 12
reserve ammo. There are no rolls after individual waves or in Start/Treasure.
Walk into a pickup near the room center to collect it. It credits one authorized,
nearby living collector once, retains player/room attribution, and consumes no RNG
on collection. HP clamps to maximum; full-health players leave healing available.
Pause/death/old-room claims fail. Uncollected supplies expire when leaving the room.

The original v0.0.1–v0.0.4 content retains its historical wave-reward rules for
regression coverage. These rules are superseded only for the new launch route.
No general loot generator, new item, shop, currency or meta-progression is added.
See ADR 0009 and GAMEPLAY_LOOP.md.

## Exit signage correction

The green panel's back surface now meets the north wall's inside surface, instead
of floating inside the arena. EXIT and room-role Label3D text billboards toward
the camera; the EXIT label sits in front of the panel. This addresses the owner's
v0.0.4 screenshot feedback in the v0.0.5 dev candidate; the v0.0.4 release retains its original signs.
Regression tests calculate panel/wall surface alignment and check every authored
room's signage configuration. Actual readability still needs the manual camera check.

## Verification and pending manual acceptance

The existing full validate command covers the new boss configuration, pursuit,
windup, escape, occlusion, cooldown, pause, death and attributed kill effects.
Gameplay tests cover gated boss choices, two-item pacing, per-player rewards,
supplies, floor completion, stale callbacks and restart. Two additional processes
run the production boss route with different preload orders, comparing offers,
drop rolls, ownership, RNG consumption and clean restart. Previous probes remain.
Content validation includes boss scenes/spawns, supply bounds and reward pacing.

Before accepting the Windows candidate:

1. View the panel and both signs from the front and oblique angles in several rooms.
2. Complete five waves; confirm no upgrade prompt appears between them.
3. Choose exactly one Treasure item, then enter First Boss with that build intact.
4. Verify pursuit, the red windup disc, moving out of the slam, damage and cooldown.
5. Pause during windup, resume and verify a single attack with no timer jump.
6. Kill the boss; choose one further item, then exit to FLOOR COMPLETE.
7. Check occasional room-clear supplies, clamped HP, ammo and one-time collection.
8. Replay after completion and death; confirm fresh health/ammo, zero items, no
   boss/supply leftovers and repeatable authoritative rolls for the same choices.

Local tests and exports are not manual acceptance or native Linux execution on
this Windows host. Existing CI is preserved and runs on dev promotion. No additional floor, procedural map, advanced AI, production audio,
final art/animation or networking is implemented.

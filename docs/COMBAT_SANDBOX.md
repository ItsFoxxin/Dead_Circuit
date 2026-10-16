# v0.0.1 — Combat Sandbox

Phase 0 is complete as **v0.0.0 — Development Foundation**. The current
main implementation is the completed and accepted v0.0.1 milestone. Windows
development artifact manual acceptance **PASSED** on 2026-10-16, as confirmed by
the project owner. PR #7 is merged and the v0.0.1 pre-release was published manually. The next
candidate on dev is v0.0.2 — Item / Synergy Proof, pending its own manual acceptance.
This document records the accepted v0.0.1 baseline; see ITEM_SYSTEM.md for current
item choices, build rules and the v0.0.2 Windows playtest checklist.

## Play

Launch the Windows/Linux development executable, or Run Project in Godot 4.7.2.

| Input | Behavior |
| --- | --- |
| WASD | Ground movement |
| Mouse | Look; vertical angle is clamped |
| Left mouse button | Fire a semi-automatic pistol shot |
| Left Shift | Sprint |
| R | Reload from reserve |
| Esc | Pause combat and release mouse; Esc or click resumes |
| Enter or Restart button | New attempt after death or completion |

The paused screen also offers Restart. Resuming with a click consumes that click
instead of firing. There is no jumping or advanced movement. The HUD shows HP,
magazine/capacity, reserve, reload state, wave and remaining enemies. Death displays
YOU DIED; clearing wave five displays COMBAT SANDBOX COMPLETE. Combat stops in
either terminal state; restart creates fresh actors and resets state.

## Prototype configuration

| Content | Initial values |
| --- | --- |
| Local player | 100 HP; walk 5 m/s; sprint 8 m/s |
| Service Pistol | 30 damage; up to 4 shots/s; 12-round magazine; 240 reserve; 1.1 s reload |
| Basic zombie | 60 HP; 2.7 m/s; 15 melee damage; 1.5 m range; 1 s cooldown |
| Waves | 3, 5, 7, 9, 12 zombies |
| Arena | 40 m square; colliding floor/walls; twelve authored spawn points; navigation mesh |

These are development values, not a balance commitment. Spawn order is fixed;
the prototype uses no gameplay randomness. There are no rewards or ammo pickups.
If ammunition is exhausted, use the paused Restart control or restart after death.

## Architecture and verification

Reusable mechanics are in game/combat, game/player, game/weapons, game/enemies,
game/run, game/rooms and game/ui. The scene at content/rooms/combat_sandbox.tscn
supplies the actual arena, zombie scene, pistol and wave Resources. Actor ownership
and DamageContext attribution are explicit. No weapon/player depends on the
basic-zombie content. The bootstrap's content reference is an intentional
composition boundary, not a gameplay-system dependency.

Health clamps damage and emits death once. Hitscan and melee use the same damage
interface. Weapon state belongs to its owner. Enemies query living target candidates
and use NavigationAgent3D after map synchronization. WaveManager tracks pending
spawns and live IDs; duplicate/removal callbacks are idempotent. Restart increments
a session token, removes the previous actor subtree, clears player/enemy collections,
and creates new health/ammo/timer/position state. Stale deferred callbacks are ignored.

Run the existing `python tools/dev.py validate` and `export --platform all` commands
from DEVELOPMENT.md. All Phase 0 formatting, lint, import, deterministic fixtures,
content, smoke, reporting and native export gates remain in place. The main smoke
now initializes the combat scene, explicit player, navigation and first wave.
Automated tests cover the gameplay contracts, including real physics queries and
synthetic movement input. These checks do not claim a human playthrough.

## Windows artifact acceptance — PASSED

The project owner confirmed manual acceptance of the v0.0.1 Windows development
artifact on 2026-10-16. The Combat Sandbox is accepted for its intended milestone
scope. The accepted manual scope is:

- [x] WASD movement works.
- [x] Sprint works.
- [x] Mouse look works.
- [x] Collision is usable.
- [x] Pistol firing works.
- [x] Ammunition and reload work.
- [x] Zombies pursue and attack.
- [x] Player health/death work.
- [x] All five waves function.
- [x] Completion state works.
- [x] Death restart works.
- [x] Completion restart works.
- [x] Pause/resume works.
- [x] No obvious stale-state issues were observed.

Movement and combat feel are accepted only as an early prototype foundation.
This acceptance does not finalize movement, weapon feel, balance, visuals, AI,
or combat polish. Automated checks remain separate evidence from this manual pass.

## Limitations and next gate

The current arena is open and primitive; navigation has no internal obstacles,
crowd avoidance or advanced tactics. Enemies have capsule visuals. The pistol has
no production audio, animation, recoil or final model. Movement/combat polish and
balance remain future work beyond this accepted prototype. The local session
currently instantiates one controllable
player while preserving explicit identity and multiple-target selection. Networking,
items, modifiers, procedural rooms, bosses, rewards and progression are absent.

Development exports are unsigned. Actions artifacts expire after 14 days and Linux
ZIP downloads may need `chmod +x DeadCircuit.x86_64`. The manual v0.0.1 pre-release
is preserved; future release approval follows DEVELOPMENT.md. The next gameplay milestone is
v0.0.2 — Item / Synergy Proof. Its candidate extends this baseline with items;
the v0.0.1 acceptance record does not approve the new item milestone.

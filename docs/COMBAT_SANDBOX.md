# v0.0.1 Combat Sandbox candidate

Phase 0 is complete as **v0.0.0 — Development Foundation** on main. The current
dev implementation is the v0.0.1 candidate. It is awaiting manual acceptance;
there is no release tag. v0.0.2 has not begun.

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

## Windows artifact acceptance — pending

Use the artifact matching the candidate's commit SHA and record the build ID,
tester, date, and any issue found. The Phase 0 artifact's successful manual launch
does not verify this new gameplay build.

1. Launch and confirm HUD, arena, pistol and pursuing zombies are visible.
2. Move in all directions, sprint, aim vertically/horizontally, and collide with walls.
3. Fire at zombies: ammunition decreases, damage applies, and a second body hit kills.
4. Empty a magazine; confirm further shots do not fire. Reload and check reserve transfer.
5. Take melee damage; verify attack cooldown and HP updates.
6. Survive all five waves; verify advancement waits for the last enemy to die.
7. Verify COMBAT SANDBOX COMPLETE and inactive combat; restart.
8. Confirm full health/ammo, spawn position, first wave and fresh enemies.
9. Intentionally die; verify YOU DIED, stopped combat and a working restart.
10. Repeat restart after death/completion/pause; confirm no extra enemies or stale timers.

Also check cursor capture/release, HUD legibility at the intended window size,
and whether movement, aiming, firing and combat pressure feel usable.

## Limitations and next gate

The current arena is open and primitive; navigation has no internal obstacles,
crowd avoidance or advanced tactics. Enemies have capsule visuals. The pistol has
no production audio, animation, recoil or final model. Combat feel and difficulty
need manual feedback. The local session currently instantiates one controllable
player while preserving explicit identity and multiple-target selection. Networking,
items, modifiers, procedural rooms, bosses, rewards and progression are absent.

Development exports are unsigned. Actions artifacts expire after 14 days and Linux
ZIP downloads may need `chmod +x DeadCircuit.x86_64`. After the acceptance checklist
and milestone approval, the next planned work is v0.0.2 — Item / Synergy Proof.

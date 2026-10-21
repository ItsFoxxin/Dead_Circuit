# Development Console

The v0.0.6 development build includes an in-game console for focused gameplay
testing. Press backtick (`` ` ``) or **F10** to open it. Opening the console pauses
an active combat session; closing it restores the prior active state. Use the Up
and Down arrow keys to recall recent commands.

The console is mounted only when the game is running as a development build. A
Godot release export or build whose metadata declares `build_type=release` does
not instantiate it. It is a developer aid and does not replace automated tests or
manual acceptance.

## Commands

| Command | Effect |
| --- | --- |
| `help` | List commands. |
| `status [player_id]` | Show health, weapon, ammo, items, room, wave, enemies, seed and state. |
| `items` | List authored item IDs. |
| `give_item <item_id> [player_id]` | Grant one unowned item through `PlayerItemBuild`. |
| `give_all_items [player_id]` | Grant every currently unowned authored item. |
| `weapons` | List authored weapon slots and IDs. |
| `weapon <slot_or_id> [player_id]` | Equip a player-owned weapon. Slots are one-based. |
| `heal [amount] [player_id]` | Heal by an amount, or to maximum when omitted. |
| `damage <amount> [player_id]` | Apply non-triggering developer damage. |
| `ammo [player_id]` | Refill every weapon's magazine and reserve. |
| `kill_enemies [player_id]` | Remove active enemies through attributed damage and normal death bookkeeping. |
| `restart` | Restart the complete authored run with the current seed. |
| `seed <value>` | Restart the run with a seed from 0 through 2147483647. |
| `clear` | Clear console output. |

Commands default to the configured local participant only when `player_id` is
omitted. The command implementation still resolves that explicit ID against the
session roster. It does not use a global player reference. Damage records retain
the selected player and entity ownership where relevant. Developer damage does
not activate item trigger chains or healing effects.

The console intentionally does not expose arbitrary scripts, files, network
access, scene loading, or direct internal property mutation. New commands should
remain bounded, typed, testable and routed through an existing authority API.

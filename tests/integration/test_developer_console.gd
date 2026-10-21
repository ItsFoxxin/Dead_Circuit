extends GutTest

const RunScene: PackedScene = preload("res://content/rooms/first_boss_run.tscn")
const ConsoleScene: PackedScene = preload("res://game/dev/developer_console.tscn")

var run: RoomRunSession
var runner: DeveloperCommandRunner


func before_each() -> void:
	run = RunScene.instantiate() as RoomRunSession
	run.interactive = false
	add_child_autoqfree(run)
	await run.run_started
	runner = DeveloperCommandRunner.new()
	runner.configure(run)


func test_commands_mutate_explicit_player_through_reusable_systems() -> void:
	var player: CombatPlayer = run.combat.local_player
	assert_string_contains(runner.execute("status 1"), "player=1")
	assert_string_contains(runner.execute("status 404"), "not active")
	assert_string_contains(runner.execute("items"), str(run.combat.item_catalog[0].id))
	assert_string_contains(
		runner.execute("give_item %s 1" % run.combat.item_catalog[0].id), "Granted"
	)
	assert_eq(player.items.definitions().size(), 1)
	assert_string_contains(
		runner.execute("give_item %s 1" % run.combat.item_catalog[0].id), "already owns"
	)

	assert_not_null(player.weapon.try_fire())
	assert_true(player.weapon.begin_reload())
	assert_string_contains(runner.execute("ammo 1"), "Refilled")
	assert_eq(player.weapon.magazine, player.weapon.definition.magazine_capacity)
	assert_eq(player.weapon.reserve, player.weapon.definition.starting_reserve)
	assert_false(player.weapon.reloading)

	assert_string_contains(runner.execute("weapon 2 1"), "relay_smg")
	assert_eq(player.weapons.equipped_index, 1)
	assert_string_contains(runner.execute("damage 40 1"), "40.0")
	assert_eq(player.health.current, 60.0)
	assert_string_contains(runner.execute("heal 15 1"), "15.0")
	assert_eq(player.health.current, 75.0)


func test_enemy_removal_uses_attributed_damage_and_normal_cleanup() -> void:
	var player: CombatPlayer = run.combat.local_player
	var enemy: MeleeEnemy = run.combat.spawn_enemy(
		run.combat.enemy_scene, player.global_position + Vector3(0.0, 0.0, -4.0)
	)
	assert_not_null(enemy)
	var removal_contexts: Array[DamageContext] = []
	enemy.removed_from_combat.connect(
		func(_entity_id: int, context: DamageContext) -> void: removal_contexts.append(context)
	)
	assert_string_contains(runner.execute("kill_enemies 1"), "Removed 1")
	assert_true(enemy.health.is_dead)
	assert_eq(removal_contexts.size(), 1)
	var removal_context: DamageContext = removal_contexts[0]
	assert_eq(removal_context.source_player_id, 1)
	assert_eq(removal_context.source_entity_id, player.get_instance_id())
	assert_eq(removal_context.source_weapon_id, &"developer_console")
	assert_false(removal_context.trigger_eligible)
	assert_eq(run.combat.enemies.size(), 0)


func test_seed_command_restarts_the_complete_run_without_stale_state() -> void:
	var original_player: CombatPlayer = run.combat.local_player
	var original_player_id: int = original_player.get_instance_id()
	assert_string_contains(runner.execute("give_all_items 1"), "Granted")
	assert_string_contains(runner.execute("seed 777"), "seed 777")
	await run.run_started
	assert_eq(run.run_seed, 777)
	assert_eq(run.run_random.seed, 777)
	assert_ne(run.combat.local_player.get_instance_id(), original_player_id)
	assert_true(run.combat.local_player.items.definitions().is_empty())
	assert_eq(run.progress.room_index, 0)


func test_overlay_pauses_and_restores_active_combat_and_supports_clear() -> void:
	var console: DeveloperConsole = ConsoleScene.instantiate() as DeveloperConsole
	add_child_autoqfree(console)
	console.configure(run)
	console.set_open(true)
	assert_true(console.is_open)
	assert_true(run.combat.paused)
	assert_string_contains(console.execute_command("help"), "give_item")
	assert_eq(console.execute_command("clear"), "")
	assert_eq(console.output.text, "")
	assert_string_contains(console.execute_command("seed 888"), "seed 888")
	await run.run_started
	assert_true(console.is_open)
	assert_true(run.combat.paused, "Restarted combat stays paused behind the open console")
	console.set_open(false)
	assert_false(run.combat.paused)

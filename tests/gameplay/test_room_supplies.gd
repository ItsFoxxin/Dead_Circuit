extends GutTest

const RunScene: PackedScene = preload("res://content/rooms/first_boss_run.tscn")
const Driver = preload("res://tests/fixtures/room_test_driver.gd")

var run: RoomRunSession


func before_each() -> void:
	run = RunScene.instantiate() as RoomRunSession
	run.interactive = false
	run.clear_drops = run.clear_drops.duplicate() as ClearDropDefinition
	run.clear_drops.chance_percent = 100
	add_child_autoqfree(run)
	await run.run_started
	assert_true(await Driver.exit_room(run))


func test_five_waves_offer_no_items_and_roll_only_once_after_the_room_is_clear() -> void:
	watch_signals(run)
	await _clear_combat()
	assert_signal_emit_count(run, "drop_rolled", 1)
	assert_not_null(run.supply)
	assert_eq(run.combat.local_player.items.definitions().size(), 0)
	var draws: int = run.run_random.draw_count
	var drop_id: int = run.supply.get_instance_id()
	run._on_room_cleared()
	run._on_room_cleared()
	assert_eq(run.run_random.draw_count, draws)
	assert_eq(run.supply.get_instance_id(), drop_id)
	assert_signal_emit_count(run, "drop_rolled", 1)


func test_pause_at_wave_boundary_still_tracks_frozen_spawns_then_resumes() -> void:
	for enemy: MeleeEnemy in run.combat.enemies.values():
		enemy.receive_damage(DamageContext.new(1000.0))
	run.combat.set_paused(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(run.combat.waves.wave_number, 2)
	assert_eq(run.combat.waves.pending_spawns, 0)
	assert_eq(run.combat.enemies.size(), 5)
	assert_eq(run.combat.waves.remaining(), 5)
	for enemy: MeleeEnemy in run.combat.enemies.values():
		assert_false(enemy.combat_enabled)
	run.combat.set_paused(false)
	for enemy: MeleeEnemy in run.combat.enemies.values():
		assert_true(enemy.combat_enabled)


func test_health_pickup_clamps_rejects_pause_and_is_consumed_once() -> void:
	await _clear_combat()
	var drop: RoomSupplyPickup = run.supply
	drop.kind = ClearDropDefinition.Kind.HEALTH
	var player: CombatPlayer = run.combat.local_player
	player.global_position = drop.global_position - Vector3.UP * 0.5
	assert_false(drop.collect(player), "Full-health player does not waste healing")
	player.receive_damage(DamageContext.new(5.0))
	run.combat.set_paused(true)
	assert_false(drop.collect(player))
	run.combat.set_paused(false)
	watch_signals(drop)
	assert_true(drop.collect(player))
	assert_eq(player.health.current, 100.0)
	assert_false(drop.collect(player))
	assert_signal_emit_count(drop, "collected", 1)
	var parameters: Array = get_signal_parameters(drop, "collected")
	var player_id: int = parameters[0]
	var amount: float = parameters[2]
	var source_room: StringName = parameters[3]
	assert_eq(player_id, 1)
	assert_eq(amount, 5.0)
	assert_eq(source_room, &"prototype_combat")


func test_ammo_pickup_requires_proximity_and_credits_only_its_collector() -> void:
	await _clear_combat()
	var drop: RoomSupplyPickup = run.supply
	drop.kind = ClearDropDefinition.Kind.AMMUNITION
	assert_false(drop.collect(run.combat.local_player), "Remote pickup claims are rejected")
	var other: CombatPlayer = run.combat.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	run.combat.actors.add_child(other)
	other.weapon.configure(run.combat.weapon_definition, 22, other.items)
	run.combat.players.append(other)
	other.global_position = drop.global_position - Vector3.UP * 0.5
	watch_signals(drop)
	assert_true(drop.collect(other))
	assert_eq(other.weapon.reserve, 252)
	assert_eq(run.combat.local_player.weapon.reserve, 240)
	var parameters: Array = get_signal_parameters(drop, "collected")
	var player_id: int = parameters[0]
	assert_eq(player_id, 22)


func test_restart_discards_unclaimed_supply_and_resets_drop_and_seed_state() -> void:
	await _clear_combat()
	var old: RoomSupplyPickup = run.supply
	var authority: Callable = old.can_collect
	run.restart_run()
	var authorized: bool = authority.call(run.combat.local_player)
	assert_false(authorized)
	await run.run_started
	assert_false(is_instance_valid(old))
	assert_null(run.supply)
	assert_eq(run.last_drop_kind, ClearDropDefinition.Kind.NONE)
	assert_eq(run.run_random.draw_count, 0)
	assert_eq(run.combat.local_player.weapon.reserve, 240)
	assert_true(run.combat.local_player.items.definitions().is_empty())


func test_walking_into_supply_triggers_area_collection_without_a_manual_command() -> void:
	await _clear_combat()
	var drop: RoomSupplyPickup = run.supply
	drop.kind = ClearDropDefinition.Kind.AMMUNITION
	var player: CombatPlayer = run.combat.local_player
	player.set_physics_process(false)
	player.global_position = drop.global_position - Vector3.UP * 0.5
	await wait_seconds(0.2)
	assert_eq(player.weapon.reserve, 252)
	assert_false(is_instance_valid(drop))


func test_restart_from_drop_callback_cannot_spawn_a_supply_in_the_new_attempt() -> void:
	run.drop_rolled.connect(
		func(_kind: ClearDropDefinition.Kind) -> void: run.restart_run(), CONNECT_ONE_SHOT
	)
	for number: int in range(1, 6):
		for enemy: MeleeEnemy in run.combat.enemies.values():
			enemy.receive_damage(DamageContext.new(1000.0))
		if number < 5:
			await get_tree().process_frame
			await get_tree().process_frame
	await run.run_started
	await get_tree().process_frame
	assert_null(run.supply)
	assert_eq(run.last_drop_kind, ClearDropDefinition.Kind.NONE)
	assert_eq(run.run_random.draw_count, 0)
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)


func _clear_combat() -> void:
	for number: int in range(1, 6):
		assert_eq(run.combat.waves.wave_number, number)
		for enemy: MeleeEnemy in run.combat.enemies.values():
			enemy.receive_damage(DamageContext.new(1000.0))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(run.combat.item_offers.is_empty())
		assert_eq(run.combat.state, CombatSession.State.ACTIVE)
		assert_true(run.combat.local_player.items.definitions().is_empty())
	await get_tree().process_frame

extends GutTest

const RunScene: PackedScene = preload("res://content/rooms/first_boss_run.tscn")
const Driver = preload("res://tests/fixtures/room_test_driver.gd")

var run: RoomRunSession


func before_each() -> void:
	run = RunScene.instantiate() as RoomRunSession
	run.interactive = false
	add_child_autoqfree(run)
	await run.run_started
	assert_true(await Driver.enter_boss(run))
	run.boss.set_physics_process(false)
	run.combat.local_player.set_physics_process(false)


func test_boss_initializes_locks_exit_and_exposes_health_state_to_hud() -> void:
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.BOSS)
	assert_eq(run.progress.state, RoomProgress.State.LOCKED)
	assert_eq(run.combat.enemies.size(), 1)
	assert_eq(run.combat.waves.wave_number, 0)
	assert_string_contains(run.combat.hud.status.text, "Enemies 1")
	assert_eq(run.boss.health.current, 500.0)
	assert_eq(run.boss.phase, BossEnemy.Phase.CHASING)
	assert_true(run.boss_status.visible)
	assert_string_contains(run.boss_status.text, "Prototype Brute")
	assert_string_contains(run.boss_status.text, "500 / 500")
	assert_between(run.run_random.draw_count, 59, 60)
	assert_false(run.request_exit(1, run.progress.attempt_token, run.progress.room_token))
	assert_eq(
		run.combat.local_player.items.definitions().size(),
		1,
		"Only the treasure room grants an item"
	)


func test_valid_death_rewards_once_preserves_source_and_unlocks_floor_completion() -> void:
	var player: CombatPlayer = run.combat.local_player
	player.receive_damage(DamageContext.new(60.0))
	var reserve: int = player.weapon.reserve
	var victim: BossEnemy = run.boss
	var id: int = victim.get_instance_id()
	var attempt: int = run.progress.attempt_token
	var room: int = run.progress.room_token
	var token: int = run.combat.waves.session_token
	watch_signals(run)
	var context: DamageContext = _kill_context(player)
	victim.receive_damage(context)
	victim.receive_damage(context)
	run._on_boss_removed(id, context, attempt, room, token)
	assert_signal_emit_count(run, "boss_defeated", 1)
	assert_signal_emit_count(run, "reward_granted", 0)
	assert_eq(run.progress.state, RoomProgress.State.LOCKED)
	assert_eq(run.combat.state, CombatSession.State.SELECTING_ITEM)
	var offer: ItemOffer = run.combat.item_offers[1]
	assert_eq(offer.choices.size(), 3)
	assert_true(run.combat.select_item(1, offer.choices[0].id, offer.session_token, 0))
	assert_false(run.combat.select_item(1, offer.choices[0].id, offer.session_token, 0))
	assert_signal_emit_count(run, "reward_granted", 1)
	var arguments: Array = get_signal_parameters(run, "reward_granted")
	var rewarded_player: int = arguments[0]
	var granted_id: StringName = arguments[1]
	assert_eq(rewarded_player, 1)
	assert_eq(granted_id, offer.choices[0].id)
	var source: DamageContext = arguments[2]
	assert_eq(source.source_player_id, 1)
	assert_eq(source.source_weapon_id, &"pistol")
	assert_eq(source.source_entity_id, player.get_instance_id())
	assert_between(
		player.health.current,
		40.0,
		45.0,
		"No guaranteed health reward; owned kill effects still apply"
	)
	assert_eq(player.weapon.reserve, reserve, "Supplies must be collected physically")
	assert_eq(player.items.definitions().size(), 2)
	assert_eq(run.rewarded_players, [1])
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_false(run.boss_status.visible)
	assert_true(run.combat.enemies.is_empty())
	assert_true(await Driver.exit_room(run))
	assert_eq(run.progress.state, RoomProgress.State.COMPLETED)
	assert_eq(run.combat.state, CombatSession.State.COMPLETED)
	assert_eq(run.combat.hud.message.text, "FLOOR COMPLETE")
	assert_null(player.shoot())


func test_unexpected_removal_and_forged_or_stale_death_cannot_reward_or_clear() -> void:
	var context: DamageContext = _kill_context(run.combat.local_player)
	var id: int = run.boss.get_instance_id()
	run._on_boss_removed(
		id,
		context,
		run.progress.attempt_token,
		run.progress.room_token,
		run.combat.waves.session_token
	)
	assert_false(run.boss_rewarded, "A living boss cannot report a victory")
	run.boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(run.progress.state, RoomProgress.State.LOCKED)
	assert_false(run.boss_rewarded)
	run.restart_run()
	await run.run_started
	run._on_boss_removed(
		id, context, run.progress.attempt_token - 1, 4, run.combat.waves.session_token - 1
	)
	assert_false(run.boss_rewarded)
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(run.combat.local_player.weapon.reserve, 240)


func test_completion_restart_clears_boss_reward_health_ammo_and_build() -> void:
	run.boss.receive_damage(_kill_context(run.combat.local_player))
	_choose_boss_items()
	assert_true(await Driver.exit_room(run))
	run.combat.hud.restart_button.pressed.emit()
	await run.run_started
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_null(run.boss)
	assert_false(run.boss_rewarded)
	assert_true(run.rewarded_players.is_empty())
	assert_eq(run.combat.local_player.health.current, 100.0)
	assert_eq(run.combat.local_player.weapon.magazine, 12)
	assert_eq(run.combat.local_player.weapon.reserve, 240)
	assert_true(run.combat.local_player.items.definitions().is_empty())
	assert_true(run.combat.enemies.is_empty())
	assert_eq(run.run_random.draw_count, 0)
	assert_false(run.boss_status.visible)


func test_player_death_during_windup_cancels_boss_and_restart_has_no_old_attack() -> void:
	var old: BossEnemy = run.boss
	var player: CombatPlayer = run.combat.local_player
	player.global_position = old.global_position + Vector3(0, 0, 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(old.try_melee(player))
	player.receive_damage(DamageContext.new(1000.0))
	assert_eq(run.combat.state, CombatSession.State.DEAD)
	assert_false(old.combat_enabled)
	assert_false(old.telegraph.visible)
	run.restart_run()
	await run.run_started
	await get_tree().process_frame
	assert_false(is_instance_valid(old))
	assert_eq(run.combat.local_player.health.current, 100.0)
	assert_false(run.boss_rewarded)
	assert_true(run.combat.enemies.is_empty())


func test_boss_choices_are_independent_per_living_player_and_wait_for_every_choice() -> void:
	var second: CombatPlayer = run.combat.player_scene.instantiate() as CombatPlayer
	second.player_id = 22
	run.combat.actors.add_child(second)
	second.set_physics_process(false)
	second.configure_weapons(run.combat.weapon_definitions)
	second.receive_damage(DamageContext.new(10.0))
	run.combat.players.append(second)
	run.combat.players.append(second)
	watch_signals(run)
	run.boss.receive_damage(_kill_context(run.combat.local_player))
	assert_eq(run.combat.item_offers.size(), 2)
	var first: ItemOffer = run.combat.item_offers[1]
	assert_true(run.combat.select_item(1, first.choices[0].id, first.session_token, 0))
	assert_eq(run.progress.state, RoomProgress.State.LOCKED)
	var second_offer: ItemOffer = run.combat.item_offers[22]
	assert_true(
		run.combat.select_item(22, second_offer.choices[0].id, second_offer.session_token, 0)
	)
	assert_eq(run.combat.local_player.health.current, 100.0)
	assert_eq(second.health.current, 90.0)
	assert_eq(second.weapon.reserve, 240)
	assert_eq(second.items.definitions().size(), 1)
	assert_eq(run.rewarded_players, [1, 22])
	assert_signal_emit_count(run, "reward_granted", 2)
	assert_eq(second.weapon.source_player_id, 22)


func test_restart_from_reward_callback_cannot_unlock_or_grant_into_new_run() -> void:
	run.reward_granted.connect(
		func(_id: int, _item: StringName, _context: DamageContext) -> void: run.restart_run(),
		CONNECT_ONE_SHOT
	)
	run.boss.receive_damage(_kill_context(run.combat.local_player))
	_choose_boss_items()
	await run.run_started
	assert_false(run.boss_rewarded)
	assert_true(run.rewarded_players.is_empty())
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(run.combat.local_player.weapon.reserve, 240)


func _choose_boss_items() -> void:
	var offers: Array[ItemOffer] = run.combat.item_offers.values()
	for offer: ItemOffer in offers:
		run.combat.select_item(offer.player_id, offer.choices[0].id, offer.session_token, 0)


func _kill_context(player: CombatPlayer) -> DamageContext:
	return DamageContext.new(
		1000.0,
		player.player_id,
		&"pistol",
		&"ballistic",
		["weapon", "hitscan"],
		player.get_instance_id()
	)

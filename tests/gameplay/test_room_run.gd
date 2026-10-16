extends GutTest

const RunScene: PackedScene = preload("res://content/rooms/room_run.tscn")

var run: RoomRunSession


func before_each() -> void:
	run = RunScene.instantiate() as RoomRunSession
	run.interactive = false
	add_child_autoqfree(run)
	await run.run_started


func test_start_room_is_safe_walkable_and_does_not_consume_rng() -> void:
	assert_eq(run.progress.room_index, 0)
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(run.combat.waves.state, WaveManager.State.IDLE)
	assert_eq(run.combat.enemies.size(), 0)
	assert_eq(run.run_random.draw_count, 0)
	assert_true(run.combat.local_player.combat_enabled)
	assert_not_null(run.combat.local_player.shoot())
	assert_eq(run.combat.local_player.weapon.magazine, 11)
	assert_true(run.combat.local_player.weapon.begin_reload())
	run.combat.set_paused(true)
	run.combat.set_paused(false)
	assert_true(run.combat.local_player.weapon.enabled)
	assert_string_contains(run.room_status.text, "Start Room")


func test_exit_requires_living_participant_proximity_and_current_tokens() -> void:
	var attempt: int = run.progress.attempt_token
	var room: int = run.progress.room_token
	assert_false(run.request_exit(999, attempt, room))
	assert_false(run.request_exit(1, attempt, room))
	_approach_exit()
	assert_false(run.request_exit(1, attempt - 1, room))
	assert_false(run.request_exit(1, attempt, room - 1))
	run.combat.set_paused(true)
	assert_false(run.request_exit(1, attempt, room))
	run.combat.set_paused(false)
	assert_true(run.request_exit(1, attempt, room))
	assert_false(run.request_exit(1, attempt, room))
	await run.room_entered
	assert_eq(run.progress.room_index, 1)
	assert_eq(run.combat.waves.wave_number, 1)
	assert_eq(run.combat.enemies.size(), 3)
	assert_eq(run.run_random.draw_count, 11)
	_approach_exit()
	assert_false(
		run.request_exit(1, attempt, run.progress.room_token), "Combat exit remains locked"
	)


func test_e_input_enters_next_room() -> void:
	run.interactive = true
	_approach_exit()
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await run.room_entered
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.COMBAT)


func test_combat_clear_preserves_player_health_ammo_items_and_rng_into_treasure() -> void:
	await _exit_room()
	var player: CombatPlayer = run.combat.local_player
	var id: int = player.get_instance_id()
	player.receive_damage(DamageContext.new(25.0))
	player.weapon.try_fire()
	await _clear_combat()
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_true(player.combat_enabled, "Movement resumes to reach the room exit")
	assert_true(player.weapon.enabled)
	assert_eq(player.items.definitions().size(), 4)
	var health: float = player.health.current
	var magazine: int = player.weapon.magazine
	var reserve: int = player.weapon.reserve
	var draws: int = run.run_random.draw_count
	var previous_token: int = run.combat.waves.session_token
	await _exit_room()
	assert_eq(run.combat.local_player.get_instance_id(), id)
	assert_eq(player.health.current, health)
	assert_eq(player.weapon.magazine, magazine)
	assert_eq(player.weapon.reserve, reserve)
	assert_eq(player.items.definitions().size(), 4)
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.TREASURE)
	assert_eq(run.combat.state, CombatSession.State.SELECTING_ITEM)
	assert_eq(run.combat.waves.wave_number, 0)
	assert_eq(run.combat.enemies.size(), 0)
	assert_eq(run.combat.damage_targets.size(), 0)
	assert_gt(run.combat.waves.session_token, previous_token)
	assert_eq(run.run_random.draw_count, draws, "Only one unowned item remains")


func test_treasure_grants_once_and_boss_is_staging_before_framework_completion() -> void:
	await _exit_room()
	await _clear_combat()
	await _exit_room()
	var offer: ItemOffer = run.combat.item_offers[1]
	assert_eq(offer.choices.size(), 1)
	assert_true(run.combat.select_item(1, offer.choices[0].id, offer.session_token, 0))
	assert_false(run.combat.select_item(1, offer.choices[0].id, offer.session_token, 0))
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(run.combat.local_player.items.definitions().size(), 5)
	await _exit_room()
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.BOSS)
	assert_eq(run.combat.enemies.size(), 0)
	assert_string_contains(run.exit_hint.text, "deferred to v0.0.5")
	await _exit_room()
	assert_eq(run.progress.state, RoomProgress.State.COMPLETED)
	assert_eq(run.combat.state, CombatSession.State.COMPLETED)
	assert_eq(run.combat.hud.message.text, "ROOM FRAMEWORK COMPLETE")
	assert_null(run.combat.local_player.shoot())


func test_death_restart_resets_every_room_and_rejects_previous_commands() -> void:
	await _exit_room()
	var previous: CombatPlayer = run.combat.local_player
	var attempt: int = run.progress.attempt_token
	var room: int = run.progress.room_token
	previous.weapon.try_fire()
	previous.items.acquire(run.combat.item_catalog[0])
	previous.receive_damage(DamageContext.new(1000.0))
	assert_eq(run.combat.state, CombatSession.State.DEAD)
	_approach_exit()
	assert_false(run.request_exit(1, attempt, room))
	run.combat.hud.restart_button.pressed.emit()
	await run.run_started
	assert_eq(run.progress.room_index, 0)
	assert_gt(run.progress.attempt_token, attempt)
	assert_eq(run.run_random.draw_count, 0)
	assert_eq(run.combat.local_player.health.current, 100.0)
	assert_eq(run.combat.local_player.weapon.magazine, 12)
	assert_eq(run.combat.local_player.weapon.reserve, 240)
	assert_true(run.combat.local_player.items.definitions().is_empty())
	assert_eq(run.combat.waves.wave_number, 0)
	assert_true(run.combat.enemies.is_empty())
	assert_true(run.combat.item_offers.is_empty())
	assert_false(is_instance_valid(previous))
	assert_false(run.request_exit(1, attempt, room))


func test_restart_during_transition_cancels_old_room_start() -> void:
	_approach_exit()
	assert_true(run.request_exit(1, run.progress.attempt_token, run.progress.room_token))
	run.restart_run()
	await run.run_started
	await get_tree().process_frame
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(run.combat.waves.wave_number, 0)
	assert_true(run.combat.enemies.is_empty())
	assert_eq(run.run_random.draw_count, 0)


func test_multiple_player_actors_and_builds_survive_room_transition() -> void:
	var other: CombatPlayer = run.combat.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	run.combat.actors.add_child(other)
	other.weapon.configure(run.combat.weapon_definition, 22, other.items)
	other.items.acquire(run.combat.item_catalog[0])
	other.receive_damage(DamageContext.new(15.0))
	run.combat.players.append(other)
	other.global_position = run.combat.arena.exit_marker.global_position + Vector3(0, 0.05, 1)
	assert_true(run.request_exit(22, run.progress.attempt_token, run.progress.room_token))
	await run.room_entered
	assert_eq(run.combat.players.size(), 2)
	assert_eq(other.health.current, 85.0)
	assert_true(other.items.owns(run.combat.item_catalog[0].id))
	assert_true(run.combat.local_player.items.definitions().is_empty())
	assert_eq(other.weapon.source_player_id, 22)
	var enemy: MeleeEnemy = run.combat.enemies.values()[0]
	assert_eq(enemy.players.size(), 2)


func test_changed_seed_restarts_the_whole_route() -> void:
	await _exit_room()
	assert_true(run.combat.restart_with_seed(42))
	await run.run_started
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(run.run_random.seed, 42)
	assert_eq(run.run_random.draw_count, 0)
	await _exit_room()
	assert_eq(run.run_random.draw_count, 11)
	assert_ne(run.combat.enemy_spawn_order, [8, 5, 1, 10, 9, 0, 11, 6, 4, 3, 2, 7])


func test_completion_restart_returns_to_clean_start_room() -> void:
	await _exit_room()
	await _clear_combat()
	await _exit_room()
	var offer: ItemOffer = run.combat.item_offers[1]
	run.combat.select_item(1, offer.choices[0].id, offer.session_token, 0)
	await _exit_room()
	await _exit_room()
	var old_player: CombatPlayer = run.combat.local_player
	var attempt: int = run.progress.attempt_token
	run.combat.hud.restart_button.pressed.emit()
	await run.run_started
	assert_eq(run.progress.room_index, 0)
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_gt(run.progress.attempt_token, attempt)
	assert_eq(run.progress.cleared.size(), 1)
	assert_eq(run.combat.local_player.health.current, 100.0)
	assert_eq(run.combat.local_player.weapon.magazine, 12)
	assert_eq(run.combat.local_player.weapon.reserve, 240)
	assert_true(run.combat.local_player.items.definitions().is_empty())
	assert_true(run.combat.item_offers.is_empty())
	assert_eq(run.run_random.draw_count, 0)
	assert_false(is_instance_valid(old_player))
	assert_true(run.combat.local_player.weapon.enabled)


func test_treasure_waits_for_each_explicit_player_choice() -> void:
	await _exit_room()
	await _clear_combat()
	var other: CombatPlayer = run.combat.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	run.combat.actors.add_child(other)
	other.weapon.configure(run.combat.weapon_definition, 22, other.items)
	run.combat.players.append(other)
	await _exit_room()
	assert_eq(run.combat.item_offers.size(), 2)
	var first: ItemOffer = run.combat.item_offers[1]
	assert_true(run.combat.select_item(1, first.choices[0].id, first.session_token, 0))
	assert_eq(run.progress.state, RoomProgress.State.LOCKED)
	assert_false(run.combat.local_player.combat_enabled)
	assert_eq(other.items.definitions().size(), 0)
	var second: ItemOffer = run.combat.item_offers[22]
	assert_true(run.combat.select_item(22, second.choices[0].id, second.session_token, 0))
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(other.items.definitions().size(), 1)
	assert_true(run.combat.local_player.combat_enabled)


func test_exhausted_build_unlocks_treasure_without_an_offer() -> void:
	await _exit_room()
	await _clear_combat()
	for item: ItemDefinition in run.combat.item_catalog:
		run.combat.local_player.items.acquire(item)
	var draws: int = run.run_random.draw_count
	await _exit_room()
	assert_eq(run.progress.current_room().kind, RoomDefinition.Kind.TREASURE)
	assert_eq(run.progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(run.combat.state, CombatSession.State.ACTIVE)
	assert_true(run.combat.item_offers.is_empty())
	assert_eq(run.run_random.draw_count, draws)


func test_reload_and_fire_cooldown_are_not_reset_by_room_entry() -> void:
	var weapon: WeaponController = run.combat.local_player.weapon
	assert_not_null(weapon.try_fire())
	assert_true(weapon.begin_reload())
	await _exit_room()
	assert_true(weapon.reloading)
	assert_eq(weapon.magazine, 11)
	assert_eq(weapon.reserve, 240)
	assert_null(weapon.try_fire())
	weapon.advance(5.0)
	assert_eq(weapon.magazine, 12)
	assert_eq(weapon.reserve, 239)


func _approach_exit() -> void:
	run.combat.local_player.global_position = (
		run.combat.arena.exit_marker.global_position + Vector3(0, 0.05, 1)
	)


func _exit_room() -> void:
	_approach_exit()
	assert_true(run.request_exit(1, run.progress.attempt_token, run.progress.room_token))
	if run.progress.state != RoomProgress.State.COMPLETED:
		await run.room_entered


func _clear_combat() -> void:
	for number: int in range(1, 6):
		assert_eq(run.combat.waves.wave_number, number)
		for enemy: MeleeEnemy in run.combat.enemies.values():
			enemy.receive_damage(DamageContext.new(1000.0))
		await get_tree().process_frame
		await get_tree().process_frame
		if number < 5:
			var offers: Array[ItemOffer] = run.combat.item_offers.values()
			for offer: ItemOffer in offers:
				assert_true(
					run.combat.select_item(
						offer.player_id, offer.choices[0].id, offer.session_token, number
					)
				)

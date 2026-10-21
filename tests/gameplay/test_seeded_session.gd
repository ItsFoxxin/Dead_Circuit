extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")

var session: CombatSession


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	add_child_autoqfree(session)
	await session.session_started


func test_replay_resets_seeded_encounter_and_reward_sequence() -> void:
	var first: Array[Dictionary] = await _complete_attempt()
	session.restart_session()
	await session.session_started
	assert_eq(session.run_random.draw_count, 11)
	var second: Array[Dictionary] = await _complete_attempt()
	assert_eq(first, second)
	assert_eq(session.state, CombatSession.State.COMPLETED)
	assert_eq(session.run_seed, 12345)


func test_seeded_encounter_places_each_enemy_at_its_rolled_marker() -> void:
	var enemies: Array[MeleeEnemy] = session.enemies.values()
	for index: int in range(enemies.size()):
		assert_eq(
			enemies[index].global_position,
			session.arena.enemy_spawn(session.enemy_spawn_order[index])
		)
	assert_eq(session.enemy_spawn_order, [8, 5, 1, 10, 9, 0, 11, 6, 4, 3, 2, 7])
	await _clear_wave()
	var ids: Array[StringName] = []
	for item: ItemDefinition in session.item_offers[session.local_player_id].choices:
		ids.append(item.id)
	assert_eq(ids, [&"emergency_reboot", &"split_chamber", &"arc_conductor"])


func test_new_seed_discards_old_combat_and_reward_state() -> void:
	var old_spawns: Array[int] = session.enemy_spawn_order.duplicate()
	session.local_player.receive_damage(DamageContext.new(20.0))
	session.local_player.weapon.try_fire()
	await _clear_wave()
	var offer: ItemOffer = session.item_offers[session.local_player_id]
	assert_true(session.restart_with_seed(42))
	await session.session_started
	assert_eq(session.run_random.seed, 42)
	assert_eq(session.run_random.draw_count, 11)
	assert_ne(session.enemy_spawn_order, old_spawns)
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.enemies.size(), 3)
	assert_eq(session.local_player.health.current, 100.0)
	assert_eq(session.local_player.weapon.magazine, 12)
	assert_true(session.local_player.items.definitions().is_empty())
	assert_true(session.item_offers.is_empty())
	var draws: int = session.run_random.draw_count
	assert_false(session.select_item(offer.player_id, offer.choices[0].id, offer.session_token, 1))
	assert_eq(session.run_random.draw_count, draws)
	assert_string_contains(session.hud.status.text, "Seed 42")


func test_invalid_commands_pause_and_hud_refresh_cannot_advance_rng() -> void:
	var token: int = session.waves.session_token
	var draws: int = session.run_random.draw_count
	session.set_paused(true)
	session.hud.refresh(session.local_player, session.waves, "PAUSED", session.run_seed)
	session.set_paused(false)
	assert_false(session.restart_with_seed(-1))
	assert_false(session.restart_with_seed(RunRandom.MAX_SEED + 1))
	assert_eq(session.waves.session_token, token)
	assert_eq(session.run_random.draw_count, draws)
	await _clear_wave()
	draws = session.run_random.draw_count
	assert_false(session.select_item(999, &"bad", token, 1))
	assert_false(session.select_item(session.local_player_id, &"bad", token, 1))
	assert_eq(session.run_random.draw_count, draws)


func test_player_container_order_does_not_change_owned_offers() -> void:
	var first: Dictionary[int, Array] = await _two_player_offers(false)
	session.restart_session()
	await session.session_started
	var second: Dictionary[int, Array] = await _two_player_offers(true)
	assert_eq(first, second)
	assert_eq(session.item_offers[22].player_id, 22)


func test_seed_editor_rejects_invalid_text_and_enter_starts_requested_seed() -> void:
	session.interactive = true
	session.set_paused(true)
	assert_true(session.hud.seed_controls.visible)
	session.hud.seed_input.text = "invalid"
	session.hud.seed_input.text_changed.emit("invalid")
	assert_true(session.hud.seed_button.disabled)
	var token: int = session.waves.session_token
	session.hud.seed_input.text_submitted.emit("invalid")
	assert_eq(session.waves.session_token, token)
	session.hud.seed_input.text = "42"
	session.hud.seed_input.text_changed.emit("42")
	assert_false(session.hud.seed_button.disabled)
	session.hud.seed_input.grab_focus()
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await session.session_started
	assert_eq(session.run_seed, 42)
	assert_eq(session.waves.session_token, token + 1)
	assert_eq(session.run_random.draw_count, 11)
	assert_false(session.hud.seed_controls.visible)


func test_seed_button_keyboard_activation_uses_entered_seed() -> void:
	session.interactive = true
	session.set_paused(true)
	session.hud.seed_input.text = "77"
	session.hud.seed_input.text_changed.emit("77")
	session.hud.seed_button.grab_focus()
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await session.session_started
	assert_eq(session.run_seed, 77)
	assert_string_contains(session.hud.status.text, "Seed 77")


func test_editing_seed_does_not_change_attempt_and_replay_discards_unapplied_text() -> void:
	session.set_paused(true)
	session.hud.seed_input.text = "42"
	session.hud.seed_input.text_changed.emit("42")
	session.hud.refresh(session.local_player, session.waves, "PAUSED", session.run_seed)
	assert_eq(session.hud.seed_input.text, "42", "Refresh must not overwrite ongoing edits")
	assert_eq(session.run_random.seed, 12345)
	assert_eq(session.run_random.draw_count, 11)
	session.hud.restart_button.pressed.emit()
	await session.session_started
	assert_eq(session.run_seed, 12345)
	session.set_paused(true)
	assert_eq(session.hud.seed_input.text, "12345")


func _two_player_offers(reverse: bool) -> Dictionary[int, Array]:
	var other: CombatPlayer = session.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	other.local_input_enabled = false
	session.actors.add_child(other)
	other.configure_weapons(session.weapon_definitions)
	session.players.append(other)
	if reverse:
		session.players.reverse()
	await _clear_wave()
	var result: Dictionary[int, Array] = {}
	for id: int in session.item_offers:
		var ids: Array[StringName] = []
		for item: ItemDefinition in session.item_offers[id].choices:
			ids.append(item.id)
		result[id] = ids
	return result


func _complete_attempt() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number: int in range(1, 6):
		var record: Dictionary = {"wave": number, "spawns": session.enemy_spawn_order.duplicate()}
		await _clear_wave()
		var choices: Array[StringName] = []
		if number < 5:
			var offer: ItemOffer = session.item_offers[session.local_player_id]
			for item: ItemDefinition in offer.choices:
				choices.append(item.id)
			session.select_item(offer.player_id, offer.choices[0].id, offer.session_token, number)
		record["choices"] = choices
		record["draws"] = session.run_random.draw_count
		result.append(record)
	return result


func _clear_wave() -> void:
	for enemy: MeleeEnemy in session.enemies.values():
		enemy.receive_damage(DamageContext.new(1000.0))
	await get_tree().process_frame
	await get_tree().process_frame

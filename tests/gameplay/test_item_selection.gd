extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")

var session: CombatSession


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	add_child_autoqfree(session)
	await session.session_started


func test_wave_waits_for_one_valid_choice_and_applies_it_before_next_wave() -> void:
	await _clear_wave()
	assert_eq(session.state, CombatSession.State.SELECTING_ITEM)
	assert_eq(session.waves.state, WaveManager.State.WAITING_FOR_REWARD)
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.enemies.size(), 0)
	assert_null(session.local_player.shoot())
	assert_false(session.local_player.weapon.begin_reload())
	assert_eq(session.hud.message.text, "CHOOSE ONE")
	assert_eq(session.hud.choices.get_child_count(), 3)
	assert_false(session.hud.restart_button.visible)
	session.set_paused(false)
	await get_tree().process_frame
	assert_eq(session.waves.wave_number, 1)
	var offer: ItemOffer = session.item_offers[session.local_player_id]
	assert_false(session.select_item(offer.player_id, &"bad", offer.session_token, 1))
	assert_false(session.select_item(999, offer.choices[0].id, offer.session_token, 1))
	var selected: ItemDefinition = offer.choices[1]
	assert_true(session.select_item(offer.player_id, selected.id, offer.session_token, 1))
	assert_true(session.local_player.items.owns(selected.id))
	assert_eq(session.waves.wave_number, 2)
	assert_eq(session.enemies.size(), 5)
	assert_true(session.local_player.combat_enabled)
	assert_true(session.local_player.suppress_fire_until_release)
	assert_false(session.select_item(offer.player_id, offer.choices[0].id, offer.session_token, 1))
	assert_eq(session.local_player.items.definitions().size(), 1)
	assert_string_contains(session.hud.build_text.text, selected.display_name)


func test_gui_button_grants_once_and_stale_choice_cannot_affect_restart() -> void:
	await _clear_wave()
	var offer: ItemOffer = session.item_offers[session.local_player_id]
	var selected_id: StringName = offer.choices[0].id
	var button: Button = session.hud.choices.get_child(0) as Button
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(session.local_player.items.definitions().size(), 1)
	assert_true(session.local_player.items.owns(selected_id))
	session.restart_session()
	await session.session_started
	assert_false(session.select_item(offer.player_id, offer.choices[0].id, offer.session_token, 1))
	assert_true(session.local_player.items.definitions().is_empty())
	assert_eq(session.local_player.weapon.combat_stats().shot_count, 1)
	assert_eq(session.local_player.weapon.combat_stats().damage, 30.0)
	assert_true(session.item_offers.is_empty())
	assert_false(session.hud.choices.visible)
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.waves.remaining(), 3)


func test_restart_during_selection_discards_the_pending_offer_and_build() -> void:
	session.local_player.items.acquire(session.item_catalog[2])
	await _clear_wave()
	var token: int = session.waves.session_token
	session.restart_session()
	await session.session_started
	assert_gt(session.waves.session_token, token)
	assert_true(session.local_player.items.definitions().is_empty())
	assert_eq(session.local_player.weapon.combat_stats().fire_rate, 4.0)
	assert_true(session.item_offers.is_empty())
	assert_eq(session.damage_targets.size(), 3)


func test_enter_selects_focused_item_without_triggering_restart() -> void:
	session.interactive = true
	await _clear_wave()
	var token: int = session.waves.session_token
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await get_tree().process_frame
	assert_eq(session.waves.session_token, token)
	assert_eq(session.waves.wave_number, 2)
	assert_eq(session.local_player.items.definitions().size(), 1)
	assert_eq(session.local_player.weapon.magazine, 12)


func test_independent_players_choose_separately_before_shared_wave_advances() -> void:
	var other: CombatPlayer = session.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	session.actors.add_child(other)
	other.configure_weapons(session.weapon_definitions)
	session.players.append(other)
	await _clear_wave()
	var first: ItemOffer = session.item_offers[session.local_player_id]
	var second: ItemOffer = session.item_offers[22]
	assert_true(session.select_item(first.player_id, first.choices[0].id, first.session_token, 1))
	assert_eq(session.state, CombatSession.State.SELECTING_ITEM)
	assert_eq(session.waves.wave_number, 1)
	var other_id: StringName = second.choices[0].id
	if other_id == first.choices[0].id:
		other_id = second.choices[1].id
	assert_true(session.select_item(22, other_id, second.session_token, 1))
	assert_eq(session.waves.wave_number, 2)
	assert_ne(session.local_player.items.definitions()[0].id, other.items.definitions()[0].id)


func _clear_wave() -> void:
	for enemy: MeleeEnemy in session.enemies.values():
		enemy.receive_damage(DamageContext.new(1000.0))
	await get_tree().process_frame
	await get_tree().process_frame

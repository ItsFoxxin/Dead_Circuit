extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")

var session: CombatSession


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	add_child_autoqfree(session)
	await session.session_started


func test_restart_discards_damaged_player_ammo_enemies_and_timers() -> void:
	var previous: CombatPlayer = session.local_player
	var previous_id: int = previous.get_instance_id()
	var token: int = session.waves.session_token
	previous.receive_damage(DamageContext.new(35.0))
	previous.weapon.try_fire()
	previous.weapon.begin_reload()
	previous.switch_weapon(1)
	previous.weapon.try_fire()
	previous.switch_weapon(2)
	previous.weapon.try_fire()
	previous.global_position.x += 3.0
	previous.camera.rotation.x = 0.5
	var enemy: MeleeEnemy = session.enemies.values()[0]
	enemy.receive_damage(DamageContext.new(1000.0, 1, &"prototype_pistol"))
	session.restart_session()
	await session.session_started
	assert_ne(session.local_player.get_instance_id(), previous_id)
	assert_eq(session.local_player.health.current, 100.0)
	assert_false(session.local_player.health.is_dead)
	assert_eq(session.local_player.weapon.magazine, 12)
	assert_eq(session.local_player.weapon.reserve, 240)
	assert_false(session.local_player.weapon.reloading)
	assert_eq(session.local_player.weapon.fire_remaining, 0.0)
	assert_eq(session.local_player.weapon.reload_remaining, 0.0)
	assert_eq(session.local_player.weapons.equipped_index, 0)
	assert_eq(session.local_player.weapons.controllers.size(), 3)
	for controller: WeaponController in session.local_player.weapons.controllers:
		assert_eq(controller.magazine, controller.definition.magazine_capacity)
		assert_eq(controller.reserve, controller.definition.starting_reserve)
		assert_false(controller.reloading)
	assert_eq(session.local_player.camera.rotation.x, 0.0)
	assert_almost_eq(
		session.local_player.global_position.x, session.arena.player_spawn.global_position.x, 0.01
	)
	assert_eq(session.enemies.size(), 3)
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.waves.remaining(), 3)
	assert_eq(session.players.size(), 1)
	var current_id: int = session.enemies.keys()[0]
	session.waves.remove_enemy(current_id, token)
	assert_eq(session.waves.remaining(), 3)
	await get_tree().process_frame
	assert_false(is_instance_valid(previous))


func test_death_stops_combat_and_hud_restart_works() -> void:
	var player: CombatPlayer = session.local_player
	player.receive_damage(DamageContext.new(1000.0))
	assert_eq(session.state, CombatSession.State.DEAD)
	assert_eq(session.hud.message.text, "YOU DIED")
	assert_null(player.shoot())
	for enemy: MeleeEnemy in session.enemies.values():
		assert_false(enemy.combat_enabled)
	session.hud.restart_button.pressed.emit()
	await session.session_started
	assert_eq(session.state, CombatSession.State.ACTIVE)
	assert_eq(session.local_player.health.current, 100.0)
	assert_eq(session.hud.message.text, "")


func test_five_waves_complete_and_can_restart() -> void:
	for number: int in range(1, 6):
		assert_eq(session.waves.wave_number, number)
		var current_enemies: Array[MeleeEnemy] = session.enemies.values()
		for enemy: MeleeEnemy in current_enemies:
			enemy.receive_damage(DamageContext.new(1000.0, 1, &"prototype_pistol"))
		await get_tree().process_frame
		if number < 5:
			assert_eq(session.state, CombatSession.State.SELECTING_ITEM)
			var offer: ItemOffer = session.item_offers[session.local_player_id]
			assert_true(
				session.select_item(
					offer.player_id, offer.choices[0].id, offer.session_token, number
				)
			)
	assert_eq(session.state, CombatSession.State.COMPLETED)
	assert_eq(session.waves.remaining(), 0)
	assert_eq(session.enemies.size(), 0)
	assert_eq(session.hud.message.text, "COMBAT SANDBOX COMPLETE")
	assert_false(session.local_player.weapon.enabled)
	session.restart_session()
	await session.session_started
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.enemies.size(), 3)
	assert_true(session.local_player.items.definitions().is_empty())
	assert_eq(session.local_player.weapon.combat_stats().shot_count, 1)


func test_restart_cancels_pending_wave_advance() -> void:
	for enemy: MeleeEnemy in session.enemies.values():
		enemy.receive_damage(DamageContext.new(1000.0))
	session.restart_session()
	await session.session_started
	await get_tree().process_frame
	assert_eq(session.waves.wave_number, 1)
	assert_eq(session.waves.remaining(), 3)


func test_pause_freezes_combat_and_resumes_same_attempt() -> void:
	var token: int = session.waves.session_token
	session.set_paused(true)
	assert_null(session.local_player.shoot())
	for enemy: MeleeEnemy in session.enemies.values():
		assert_false(enemy.combat_enabled)
	session.set_paused(false)
	assert_true(session.local_player.combat_enabled)
	assert_eq(session.waves.session_token, token)


func test_pause_click_reaches_gui_before_empty_space_resume() -> void:
	session.interactive = true
	session.set_paused(true)
	var click: InputEventAction = InputEventAction.new()
	click.action = &"fire"
	click.pressed = true
	session._input(click)
	assert_true(session.paused, "GUI must get first chance to receive the click")
	var token: int = session.waves.session_token
	session.hud.restart_button.pressed.emit()
	await session.session_started
	assert_gt(session.waves.session_token, token)
	session.set_paused(true)
	session._unhandled_input(click)
	assert_false(session.paused)
	assert_true(session.local_player.suppress_fire_until_release)
	assert_eq(session.local_player.weapon.magazine, 12)

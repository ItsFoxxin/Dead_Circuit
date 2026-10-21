extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")

var session: CombatSession


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	add_child_autoqfree(session)
	await session.session_started
	for enemy: MeleeEnemy in session.enemies.values():
		enemy.set_physics_process(false)


func test_hitscan_to_health_to_death_updates_wave_tracking() -> void:
	var player: CombatPlayer = session.local_player
	var enemy: MeleeEnemy = session.enemies.values()[0]
	enemy.global_position = player.global_position + Vector3(0, 0, -4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var context: DamageContext = player.shoot()
	assert_not_null(context)
	assert_eq(enemy.health.current, 30.0)
	assert_eq(context.source_player_id, player.player_id)
	assert_eq(context.source_entity_id, player.get_instance_id())
	assert_eq(session.waves.remaining(), 3)
	player.weapon.advance(1.0)
	player.shoot()
	assert_true(enemy.health.is_dead)
	assert_false(enemy.combat_enabled)
	assert_eq(session.waves.remaining(), 2)
	assert_eq(session.enemies.size(), 2)
	assert_string_contains(session.hud.status.text, "Enemies 2")


func test_wall_blocks_hitscan() -> void:
	var player: CombatPlayer = session.local_player
	var enemy: MeleeEnemy = session.enemies.values()[0]
	player.global_position = Vector3(0, 0.05, -17)
	enemy.global_position = Vector3(0, 0.05, -24)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.shoot()
	assert_eq(enemy.health.current, enemy.health.maximum)
	assert_eq(player.weapon.magazine, 11)


func test_each_authored_hitscan_ray_creates_a_short_lived_tracer() -> void:
	var player: CombatPlayer = session.local_player
	player.camera.rotation.x = 1.2
	var expected_total: int = 0
	for index: int in range(player.weapons.controllers.size()):
		if index > 0:
			assert_true(player.switch_weapon(index))
		var expected_for_weapon: int = player.weapon.definition.base_shot_count
		expected_total += expected_for_weapon
		assert_not_null(player.shoot())
		var tracers: Array[BulletTracer] = []
		for child: Node in session.actors.get_children():
			if child is BulletTracer:
				tracers.append(child as BulletTracer)
		assert_eq(tracers.size(), expected_total)
		var latest: BulletTracer = tracers.back()
		assert_eq(latest.source_player_id, player.player_id)
		assert_eq(latest.source_weapon_id, player.weapon.definition.id)
		assert_gt(latest.ray_origin.distance_to(latest.ray_endpoint), 1.0)


func test_enemy_melee_uses_health_interface_and_cooldown() -> void:
	var player: CombatPlayer = session.local_player
	var enemy: MeleeEnemy = session.enemies.values()[0]
	enemy.global_position = player.global_position + Vector3(1.1, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	watch_signals(player.health)
	assert_true(enemy.try_melee(player))
	assert_eq(player.health.current, 85.0)
	assert_false(enemy.try_melee(player))
	assert_eq(player.health.current, 85.0)
	assert_signal_emit_count(player.health, "damaged", 1)
	var parameters: Array = get_signal_parameters(player.health, "damaged")
	var context: DamageContext = parameters[0]
	assert_eq(context.source_player_id, -1)
	assert_eq(context.source_entity_id, enemy.get_instance_id())
	assert_eq(context.source_weapon_id, &"melee")
	assert_eq(context.damage_type, &"melee")


func test_target_selection_handles_multiple_players_and_skips_dead() -> void:
	var enemy: MeleeEnemy = session.enemies.values()[0]
	var second: CombatPlayer = session.player_scene.instantiate() as CombatPlayer
	second.player_id = 22
	second.local_input_enabled = false
	session.actors.add_child(second)
	second.configure_weapons(session.weapon_definitions)
	second.global_position = enemy.global_position + Vector3(1, 0, 0)
	enemy.players.append(second)
	assert_false(second.camera.current)
	assert_true(session.local_player.camera.current)
	assert_eq(enemy.acquire_target(), second)
	second.receive_damage(DamageContext.new(1000.0))
	assert_eq(enemy.acquire_target(), session.local_player)


func test_navigation_pursues_a_living_player() -> void:
	var enemy: MeleeEnemy = session.enemies.values()[0]
	var initial: float = enemy.global_position.distance_to(session.local_player.global_position)
	enemy.set_physics_process(true)
	await wait_seconds(1.0)
	var final_distance: float = enemy.global_position.distance_to(
		session.local_player.global_position
	)
	assert_lt(final_distance, initial - 1.0)
	assert_gt(enemy.navigation.get_current_navigation_path().size(), 0)
	assert_true(session.local_player.is_on_floor())


func test_out_of_range_or_dead_enemy_cannot_attack() -> void:
	var enemy: MeleeEnemy = session.enemies.values()[0]
	assert_false(enemy.try_melee(session.local_player))
	enemy.receive_damage(DamageContext.new(1000.0))
	assert_false(enemy.try_melee(session.local_player))
	assert_eq(session.local_player.health.current, 100.0)

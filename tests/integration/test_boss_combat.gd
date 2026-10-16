extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")
const BossScene: PackedScene = preload("res://content/bosses/prototype_brute.tscn")

var session: CombatSession
var boss: BossEnemy
var player: CombatPlayer


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	session.encounter_enabled = false
	add_child_autoqfree(session)
	await session.session_started
	player = session.local_player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 4)
	boss = session.spawn_enemy(BossScene, Vector3(0, 0.05, 1)) as BossEnemy
	boss.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_windup_is_visible_and_damage_preserves_boss_source() -> void:
	watch_signals(player.health)
	assert_true(boss.try_melee(player))
	assert_eq(boss.phase, BossEnemy.Phase.WINDUP)
	assert_true(boss.telegraph.visible)
	assert_eq(player.health.current, 100.0)
	boss.advance_attack(0.5)
	assert_eq(player.health.current, 100.0)
	boss.advance_attack(1.0)
	assert_eq(player.health.current, 70.0)
	assert_eq(boss.phase, BossEnemy.Phase.RECOVERING)
	assert_false(boss.telegraph.visible)
	var arguments: Array = get_signal_parameters(player.health, "damaged")
	var context: DamageContext = arguments[0]
	assert_eq(context.source_player_id, -1)
	assert_eq(context.source_entity_id, boss.get_instance_id())
	assert_eq(context.source_weapon_id, boss.definition.id)
	assert_eq(context.tags, PackedStringArray(["boss", "melee", "slam"]))
	boss.advance_attack(5.0)
	assert_eq(boss.phase, BossEnemy.Phase.CHASING)
	assert_false(boss.try_melee(player), "Recovery ends in the normal attack cooldown")
	assert_signal_emit_count(player.health, "damaged", 1)


func test_player_can_escape_the_telegraphed_radius() -> void:
	assert_true(boss.try_melee(player))
	player.global_position.z = 10
	await get_tree().physics_frame
	await get_tree().physics_frame
	boss.advance_attack(2.0)
	assert_eq(player.health.current, 100.0)
	assert_eq(boss.phase, BossEnemy.Phase.RECOVERING)


func test_solid_world_occludes_the_slam_at_impact() -> void:
	assert_true(boss.try_melee(player))
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	collision.shape = box
	wall.add_child(collision)
	session.add_child(wall)
	wall.global_position = Vector3(0, 1, 2.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	boss.advance_attack(2.0)
	assert_eq(player.health.current, 100.0)


func test_pause_freezes_attack_then_resume_finishes_it_once() -> void:
	assert_true(boss.try_melee(player))
	var remaining: float = boss.phase_remaining
	session.set_paused(true)
	boss.advance_attack(5.0)
	assert_eq(boss.phase_remaining, remaining)
	assert_eq(player.health.current, 100.0)
	session.set_paused(false)
	boss.advance_attack(2.0)
	assert_eq(player.health.current, 70.0)
	boss.advance_attack(0.1)
	assert_eq(player.health.current, 70.0)


func test_death_cancels_pending_damage_and_uses_normal_kill_effects() -> void:
	player.receive_damage(DamageContext.new(30.0))
	for item: ItemDefinition in session.item_catalog:
		player.items.acquire(item)
	assert_true(boss.try_melee(player))
	watch_signals(boss)
	var kill: DamageContext = DamageContext.new(
		1000, 1, &"pistol", &"ballistic", ["weapon", "hitscan"], player.get_instance_id()
	)
	boss.receive_damage(kill)
	boss.receive_damage(kill)
	boss.advance_attack(5.0)
	assert_eq(boss.phase, BossEnemy.Phase.DEAD)
	assert_eq(
		player.health.current,
		75.0,
		"Owned kill healing applies to a boss without item-specific code"
	)
	assert_signal_emit_count(boss, "removed_from_combat", 1)
	assert_true(session.enemies.is_empty())
	assert_true(session.damage_targets.is_empty())
	assert_eq(session.waves.wave_number, 0)


func test_radial_slam_checks_each_living_player_with_explicit_ownership() -> void:
	var second: CombatPlayer = session.player_scene.instantiate() as CombatPlayer
	second.player_id = 22
	session.actors.add_child(second)
	second.set_physics_process(false)
	second.global_position = Vector3(2, 0.05, 1)
	boss.players.append(second)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(boss.try_melee(player))
	boss.advance_attack(2.0)
	assert_eq(player.health.current, 70.0)
	assert_eq(second.health.current, 70.0)


func test_boss_uses_navigation_then_stops_to_telegraph_instead_of_sliding_attack() -> void:
	boss.global_position = Vector3(0, 0.05, -8)
	var before: float = boss.global_position.distance_to(player.global_position)
	boss.set_physics_process(true)
	await wait_seconds(0.7)
	assert_lt(boss.global_position.distance_to(player.global_position), before - 0.3)
	player.global_position = boss.global_position + Vector3(0, 0, 3)
	assert_true(boss.try_melee(player))
	var position: Vector3 = boss.global_position
	await wait_seconds(0.25)
	assert_eq(boss.phase, BossEnemy.Phase.WINDUP)
	assert_true(boss.telegraph.visible)
	assert_lt(
		Vector2(boss.global_position.x - position.x, boss.global_position.z - position.z).length(),
		0.15
	)
	assert_eq(player.health.current, 100.0)

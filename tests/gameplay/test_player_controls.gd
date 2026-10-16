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


func after_each() -> void:
	for action: StringName in [
		&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"fire"
	]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_ground_movement_sprint_and_diagonal_speed() -> void:
	var player: CombatPlayer = session.local_player
	assert_almost_eq(
		player.movement_velocity(Vector2.ONE, false).length(), player.walk_speed, 0.001
	)
	assert_almost_eq(
		player.movement_velocity(Vector2.UP, true).length(), player.sprint_speed, 0.001
	)
	player.local_input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("move_forward")
	var start: Vector3 = player.global_position
	await wait_seconds(0.4)
	var walk_distance: float = start.z - player.global_position.z
	assert_gt(walk_distance, 1.0)
	start = player.global_position
	Input.action_press("sprint")
	await wait_seconds(0.4)
	var sprint_distance: float = start.z - player.global_position.z
	assert_gt(sprint_distance, walk_distance * 1.3)
	assert_true(player.is_on_floor())


func test_mouse_look_is_clamped_and_dead_player_ignores_input() -> void:
	var player: CombatPlayer = session.local_player
	player.local_input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 10000)
	player._unhandled_input(motion)
	assert_lt(player.rotation.y, 0.0)
	assert_almost_eq(player.camera.rotation.x, -1.4, 0.001)
	player.receive_damage(DamageContext.new(1000.0))
	var yaw: float = player.rotation.y
	player._unhandled_input(motion)
	assert_eq(player.rotation.y, yaw)
	assert_null(player.shoot())


func test_boundary_wall_stops_player_collision() -> void:
	var player: CombatPlayer = session.local_player
	player.global_position = Vector3(0, 0.05, -18)
	player.local_input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await wait_seconds(0.7)
	assert_gt(player.global_position.z, -19.3)
	assert_lt(player.global_position.z, -18.5)

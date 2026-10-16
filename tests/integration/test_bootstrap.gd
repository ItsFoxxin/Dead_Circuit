extends GutTest

const BootstrapScene: PackedScene = preload("res://game/core/bootstrap.tscn")


func test_bootstrap_initializes_combat_sandbox_and_visible_hud() -> void:
	var scene: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	add_child_autoqfree(scene)
	await scene.session.session_started
	assert_true(scene.is_node_ready())
	assert_string_contains(scene.session.hud.status.text, "HP 100")
	assert_eq(scene.session.waves.wave_number, 1)


func test_bootstrap_instances_do_not_share_presentation_state() -> void:
	var first: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	var second: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	var first_world: SubViewport = SubViewport.new()
	var second_world: SubViewport = SubViewport.new()
	first_world.own_world_3d = true
	second_world.own_world_3d = true
	add_child_autoqfree(first_world)
	add_child_autoqfree(second_world)
	first_world.add_child(first)
	await first.session.session_started
	second_world.add_child(second)
	await second.session.session_started
	first.session.local_player.receive_damage(DamageContext.new(20.0))
	assert_eq(first.session.local_player.health.current, 80.0)
	assert_eq(second.session.local_player.health.current, 100.0)
	assert_ne(first.session.hud.status.text, second.session.hud.status.text)

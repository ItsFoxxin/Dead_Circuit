extends GutTest
## Future gameplay smoke suites can use scene lifecycle and input helpers here.


func test_main_scene_remains_loadable() -> void:
	var path: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed)
	var instance: RoomBootstrap = packed.instantiate() as RoomBootstrap
	add_child_autoqfree(instance)
	await instance.run.run_started
	assert_true(instance.is_inside_tree())
	assert_not_null(instance.run.combat.local_player)
	assert_eq(instance.run.progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(instance.run.combat.waves.remaining(), 0)
	assert_eq(instance.run.run_random.draw_count, 0)

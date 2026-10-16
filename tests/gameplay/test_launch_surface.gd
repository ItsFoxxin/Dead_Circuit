extends GutTest
## Future gameplay smoke suites can use scene lifecycle and input helpers here.


func test_main_scene_remains_loadable() -> void:
	var path: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed)
	var instance: Bootstrap = packed.instantiate() as Bootstrap
	add_child_autoqfree(instance)
	await instance.session.session_started
	assert_true(instance.is_inside_tree())
	assert_not_null(instance.session.local_player)
	assert_eq(instance.session.waves.remaining(), 3)

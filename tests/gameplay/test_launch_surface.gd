extends GutTest
## Future gameplay smoke suites can use scene lifecycle and input helpers here.


func test_main_scene_remains_loadable() -> void:
	var path: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed)
	var instance: Node = packed.instantiate()
	add_child_autofree(instance)
	await get_tree().process_frame
	assert_true(instance.is_inside_tree())

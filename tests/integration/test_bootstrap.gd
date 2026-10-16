extends GutTest

const BootstrapScene: PackedScene = preload("res://game/core/bootstrap.tscn")


func test_bootstrap_initializes_visible_status() -> void:
	var scene: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	add_child_autofree(scene)
	assert_true(scene.is_node_ready())
	assert_string_contains(scene.status_label.text, "Development foundation ready")


func test_bootstrap_instances_do_not_share_presentation_state() -> void:
	var first: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	var second: Bootstrap = BootstrapScene.instantiate() as Bootstrap
	add_child_autofree(first)
	add_child_autofree(second)
	first.status_label.text = "Changed instance"
	assert_ne(first.status_label.text, second.status_label.text)

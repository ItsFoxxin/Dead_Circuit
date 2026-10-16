extends GutTest


func test_exit_panel_back_surface_is_flush_with_north_wall_inside_surface() -> void:
	var scene: PackedScene = load("res://content/rooms/greybox_room.tscn") as PackedScene
	var arena: CombatArena = scene.instantiate() as CombatArena
	var wall: StaticBody3D = arena.get_node("NorthWall") as StaticBody3D
	var wall_collision: CollisionShape3D = wall.get_node("Collision") as CollisionShape3D
	var wall_shape: BoxShape3D = wall_collision.shape as BoxShape3D
	var exit: Marker3D = arena.get_node("Exit") as Marker3D
	var frame: MeshInstance3D = exit.get_node("Frame") as MeshInstance3D
	var mesh: BoxMesh = frame.mesh as BoxMesh
	var wall_face: float = wall.position.z + wall_collision.position.z + wall_shape.size.z / 2.0
	var panel_back: float = exit.position.z + frame.position.z - mesh.size.z / 2.0
	assert_almost_eq(panel_back, wall_face, 0.001, "The exit must not float inside the arena")
	arena.free()


func test_exit_and_role_text_face_camera_in_each_authored_room() -> void:
	for name: String in ["start", "combat", "treasure", "boss", "first_boss"]:
		var scene: PackedScene = load("res://content/rooms/%s_room.tscn" % name) as PackedScene
		var arena: CombatArena = scene.instantiate() as CombatArena
		var exit_label: Label3D = arena.get_node("Exit/Label") as Label3D
		var role_label: Label3D = arena.get_node("RoomRole") as Label3D
		assert_eq(exit_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
		assert_eq(role_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
		assert_gt(exit_label.position.z, 0.0, "Text is in front of the panel")
		arena.free()

extends GutTest

const Route: RunDefinition = preload("res://content/rooms/prototype_run.tres")


func test_authored_route_has_four_distinct_roles_and_five_combat_waves() -> void:
	assert_true(Route.validation_errors().is_empty())
	assert_eq(Route.rooms.size(), 4)
	for index: int in range(4):
		assert_eq(int(Route.rooms[index].kind), index)
	assert_eq(Route.rooms[1].waves.counts, [3, 5, 7, 9, 12])
	assert_null(Route.rooms[3].waves, "Boss is staging, not a v0.0.5 encounter")


func test_room_rejects_missing_identity_scene_and_invalid_role() -> void:
	var room: RoomDefinition = RoomDefinition.new()
	assert_eq(room.validation_errors().size(), 2)
	room.kind = 999 as RoomDefinition.Kind
	assert_gt(room.validation_errors().size(), 2)


func test_combat_requires_waves_and_safe_rooms_do_not_hide_encounters() -> void:
	var combat: RoomDefinition = Route.rooms[1].duplicate() as RoomDefinition
	combat.waves = null
	assert_eq(combat.validation_errors().size(), 1)
	var safe: RoomDefinition = Route.rooms[0].duplicate() as RoomDefinition
	safe.waves = Route.rooms[1].waves
	assert_eq(safe.validation_errors().size(), 1)


func test_route_rejects_empty_null_and_duplicate_room_entries() -> void:
	assert_false(RunDefinition.new().validation_errors().is_empty())
	var run: RunDefinition = RunDefinition.new()
	run.id = &"invalid_route"
	run.rooms = [null, Route.rooms[0], Route.rooms[0]]
	assert_eq(run.validation_errors().size(), 2)

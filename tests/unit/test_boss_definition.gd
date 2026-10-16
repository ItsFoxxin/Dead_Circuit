extends GutTest

const Definition: BossDefinition = preload("res://content/bosses/prototype_brute.tres")
const Room: RoomDefinition = preload("res://content/rooms/first_boss_room.tres")


func test_boss_configuration_is_valid_and_separate_from_shared_enemy_stats() -> void:
	assert_true(Definition.validation_errors().is_empty())
	assert_gt(Definition.windup_seconds, 0.5)
	assert_true(Room.validation_errors().is_empty())
	assert_eq(Room.kind, RoomDefinition.Kind.BOSS)
	assert_not_null(Room.boss_scene)


func test_boss_rejects_invalid_timing_name_and_base_enemy_values() -> void:
	var invalid: BossDefinition = Definition.duplicate() as BossDefinition
	invalid.display_name = " "
	invalid.windup_seconds = NAN
	invalid.recovery_seconds = 0.0
	invalid.maximum_health = -1.0
	assert_eq(invalid.validation_errors().size(), 4)
	assert_eq(Definition.maximum_health, 500.0)


func test_boss_scene_can_only_be_used_in_a_boss_room() -> void:
	var invalid: RoomDefinition = Room.duplicate() as RoomDefinition
	invalid.kind = RoomDefinition.Kind.START
	assert_false(invalid.validation_errors().is_empty())

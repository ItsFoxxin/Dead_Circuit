extends GutTest

const Route: RunDefinition = preload("res://content/rooms/prototype_run.tres")

var progress: RoomProgress


func before_each() -> void:
	progress = RoomProgress.new()
	progress.reset(Route)


func test_entry_requires_configuration_and_current_generations() -> void:
	assert_false(RoomProgress.new().advance(0, 0))
	assert_false(progress.advance(0, 0))
	assert_true(progress.advance(progress.attempt_token, 0))
	assert_eq(progress.current_room().kind, RoomDefinition.Kind.START)
	assert_eq(progress.state, RoomProgress.State.TRANSITIONING)
	assert_false(progress.advance(progress.attempt_token, progress.room_token))
	assert_false(progress.ready_room(progress.attempt_token - 1, progress.room_token, false))
	assert_true(progress.ready_room(progress.attempt_token, progress.room_token, false))
	assert_eq(progress.state, RoomProgress.State.UNLOCKED)
	assert_eq(progress.cleared, [&"prototype_start"])


func test_combat_lock_clear_and_duplicate_commands() -> void:
	_enter(false)
	_enter(true)
	assert_eq(progress.current_room().kind, RoomDefinition.Kind.COMBAT)
	assert_false(progress.advance(progress.attempt_token, progress.room_token))
	assert_false(progress.clear_room(progress.attempt_token, progress.room_token - 1))
	assert_true(progress.clear_room(progress.attempt_token, progress.room_token))
	assert_false(progress.clear_room(progress.attempt_token, progress.room_token))
	var room: int = progress.room_token
	assert_true(progress.advance(progress.attempt_token, room))
	assert_false(progress.advance(progress.attempt_token, room))
	assert_eq(progress.current_room().kind, RoomDefinition.Kind.TREASURE)


func test_all_authored_rooms_complete_once_and_reset_invalidates_old_attempt() -> void:
	for index: int in range(Route.rooms.size()):
		_enter(false)
	assert_eq(progress.cleared.size(), 4)
	assert_true(progress.advance(progress.attempt_token, progress.room_token))
	assert_eq(progress.state, RoomProgress.State.COMPLETED)
	assert_false(progress.advance(progress.attempt_token, progress.room_token))
	var attempt: int = progress.attempt_token
	progress.reset(Route)
	assert_gt(progress.attempt_token, attempt)
	assert_eq(progress.room_index, -1)
	assert_true(progress.cleared.is_empty())
	assert_false(progress.advance(attempt, 0))


func _enter(locked: bool) -> void:
	assert_true(progress.advance(progress.attempt_token, progress.room_token))
	assert_true(progress.ready_room(progress.attempt_token, progress.room_token, locked))

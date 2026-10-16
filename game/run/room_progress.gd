class_name RoomProgress
extends RefCounted
## Pure run-local progression; stale commands cannot unlock or skip a new room.

enum State { TRANSITIONING, LOCKED, UNLOCKED, COMPLETED }

var definition: RunDefinition
var state: State = State.UNLOCKED
var room_index: int = -1
var attempt_token: int = 0
var room_token: int = 0
var cleared: Array[StringName] = []


func reset(value: RunDefinition) -> void:
	definition = value
	state = State.UNLOCKED
	room_index = -1
	attempt_token += 1
	room_token = 0
	cleared.clear()


func advance(attempt: int, room: int) -> bool:
	if definition == null or definition.rooms.is_empty():
		return false
	if attempt != attempt_token or room != room_token or state != State.UNLOCKED:
		return false
	room_token += 1
	if room_index + 1 == definition.rooms.size():
		state = State.COMPLETED
		return true
	room_index += 1
	state = State.TRANSITIONING
	return true


func current_room() -> RoomDefinition:
	return definition.rooms[room_index] if room_index >= 0 else null


func ready_room(attempt: int, room: int, locked: bool) -> bool:
	if attempt != attempt_token or room != room_token or state != State.TRANSITIONING:
		return false
	state = State.LOCKED if locked else State.UNLOCKED
	if not locked:
		cleared.append(current_room().id)
	return true


func clear_room(attempt: int, room: int) -> bool:
	if attempt != attempt_token or room != room_token or state != State.LOCKED:
		return false
	state = State.UNLOCKED
	cleared.append(current_room().id)
	return true

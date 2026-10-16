class_name RunDefinition
extends Resource
## Authored room order. A procedural graph is intentionally not part of this contract.

@export var id: StringName
@export var rooms: Array[RoomDefinition] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	if id.is_empty() or rooms.is_empty():
		errors.append("Run requires an ID and rooms")
	for room: RoomDefinition in rooms:
		if room == null:
			errors.append("Run contains a null room")
			continue
		errors.append_array(room.validation_errors())
		if seen.has(room.id):
			errors.append("Duplicate room ID in run: " + str(room.id))
		seen[room.id] = true
	return errors

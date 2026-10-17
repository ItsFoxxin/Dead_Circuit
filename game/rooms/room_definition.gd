class_name RoomDefinition
extends Resource

enum Kind { START, COMBAT, TREASURE, BOSS }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.START
@export var scene: PackedScene
@export var waves: WaveDefinition
@export var boss_scene: PackedScene


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty() or display_name.strip_edges().is_empty():
		errors.append("Room requires an ID and display name")
	if kind < Kind.START or kind > Kind.BOSS:
		errors.append("Unknown room kind: " + str(id))
	if scene == null:
		errors.append("Room requires a scene: " + str(id))
	if kind == Kind.COMBAT:
		if waves == null:
			errors.append("Combat room requires waves: " + str(id))
		else:
			errors.append_array(waves.validation_errors())
	elif waves != null:
		errors.append("Only combat rooms configure waves in this milestone: " + str(id))
	if boss_scene != null:
		if kind != Kind.BOSS:
			errors.append("Boss encounter requires a boss room: " + str(id))
	return errors

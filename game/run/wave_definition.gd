class_name WaveDefinition
extends Resource

@export var id: StringName
@export var counts: Array[int] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("Waves require id")
	if counts.is_empty():
		errors.append("At least one wave is required")
	for count: int in counts:
		if count <= 0 or count > 100:
			errors.append("Prototype wave counts must be between 1 and 100")
	return errors

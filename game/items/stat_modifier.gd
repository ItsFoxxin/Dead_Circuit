class_name StatModifier
extends Resource

enum Operation { ADD, MULTIPLY }

const STATS: PackedStringArray = ["damage", "fire_rate", "shot_count", "shot_damage_scale"]

@export var stat: StringName = &"damage"
@export var operation: Operation = Operation.MULTIPLY
@export var value: float = 1.0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not str(stat) in STATS or operation not in Operation.values():
		errors.append("Unknown stat or modifier operation")
	if not is_finite(value) or (operation == Operation.MULTIPLY and value <= 0.0):
		errors.append("Modifier must be finite; multipliers must be positive")
	if stat == &"shot_count" and (value != floorf(value) or value < 0.0):
		errors.append("Shot count modifiers must be nonnegative integers")
	return errors

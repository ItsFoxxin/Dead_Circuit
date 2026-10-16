class_name ItemEffect
extends Resource

enum Kind { HEAL, EXPLOSION }

@export var kind: Kind = Kind.HEAL
@export var amount: float = 5.0
@export var radius: float = 3.5


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if kind not in Kind.values() or not is_finite(amount) or amount <= 0.0:
		errors.append("Effect requires a known kind and positive finite amount")
	if not is_finite(radius) or radius <= 0.0:
		errors.append("Effect radius must be finite and positive")
	return errors

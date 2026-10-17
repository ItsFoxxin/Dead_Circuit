class_name ClearDropDefinition
extends Resource
## One seeded room-clear roll; contents are small supplies rather than build items.

enum Kind { NONE = -1, HEALTH = 0, AMMUNITION = 1 }

@export var id: StringName
@export_range(0, 100, 1) var chance_percent: int = 25
@export var health_amount: float = 10.0
@export var ammunition: int = 12


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty() or chance_percent < 0 or chance_percent > 100:
		errors.append("Clear drop requires an ID and a percentage from zero to one hundred")
	if not is_finite(health_amount) or health_amount <= 0.0 or ammunition <= 0:
		errors.append("Clear supplies must be finite and positive")
	return errors


func roll(random: RunRandom) -> Kind:
	if chance_percent == 0:
		return Kind.NONE
	if chance_percent < 100 and random.choose_index(100) >= chance_percent:
		return Kind.NONE
	return Kind.HEALTH if random.choose_index(2) == 0 else Kind.AMMUNITION

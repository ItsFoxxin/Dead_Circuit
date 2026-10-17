class_name BossDefinition
extends EnemyDefinition
## Shared enemy stats plus readable, avoidable attack timing.

@export var display_name: String = "Boss"
@export var windup_seconds: float = 1.1
@export var recovery_seconds: float = 0.8


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if display_name.strip_edges().is_empty():
		errors.append("Boss requires a display name")
	for value: float in [windup_seconds, recovery_seconds]:
		if not is_finite(value) or value <= 0.0:
			errors.append("Boss timing must be finite and positive")
	return errors

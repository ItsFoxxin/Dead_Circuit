class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var maximum_health: float = 60.0
@export var move_speed: float = 2.7
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("Enemy requires id")
	for value: float in [maximum_health, move_speed, attack_damage, attack_range, attack_cooldown]:
		if not is_finite(value) or value <= 0.0:
			errors.append("Enemy numbers must be finite and positive")
	return errors

class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var damage: float = 30.0
@export var shots_per_second: float = 4.0
@export var magazine_capacity: int = 12
@export var starting_reserve: int = 240
@export var reload_seconds: float = 1.1
@export var range_metres: float = 60.0
@export var damage_tags: PackedStringArray = ["hitscan"]


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty() or display_name.is_empty():
		errors.append("Weapon requires id and display_name")
	for value: float in [damage, shots_per_second, reload_seconds, range_metres]:
		if not is_finite(value) or value <= 0.0:
			errors.append("Weapon numbers must be finite and positive")
	if magazine_capacity <= 0 or starting_reserve < 0:
		errors.append("Weapon ammo bounds are invalid")
	return errors

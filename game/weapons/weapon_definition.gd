class_name WeaponDefinition
extends Resource

enum FireMode { SEMI_AUTOMATIC, AUTOMATIC }

@export var id: StringName
@export var display_name: String
@export var damage: float = 30.0
@export var shots_per_second: float = 4.0
@export var magazine_capacity: int = 12
@export var starting_reserve: int = 240
@export var reload_seconds: float = 1.1
@export var range_metres: float = 60.0
@export var fire_mode: FireMode = FireMode.SEMI_AUTOMATIC
@export var base_shot_count: int = 1
@export var spread_degrees: float = 1.2
@export var damage_tags: PackedStringArray = ["hitscan"]
@export var view_size: Vector3 = Vector3(0.12, 0.15, 0.42)
@export var view_color: Color = Color(0.18, 0.2, 0.25, 1.0)
@export var tracer_color: Color = Color(1.0, 0.72, 0.24, 1.0)
@export var tracer_width: float = 0.012
@export var tracer_lifetime: float = 0.08


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty() or display_name.is_empty():
		errors.append("Weapon requires id and display_name")
	for value: float in [damage, shots_per_second, reload_seconds, range_metres]:
		if not is_finite(value) or value <= 0.0:
			errors.append("Weapon numbers must be finite and positive")
	if magazine_capacity <= 0 or starting_reserve < 0:
		errors.append("Weapon ammo bounds are invalid")
	if fire_mode not in FireMode.values() or base_shot_count <= 0:
		errors.append("Weapon firing configuration is invalid")
	if not is_finite(spread_degrees) or spread_degrees < 0.0 or spread_degrees > 45.0:
		errors.append("Weapon spread must be finite and from 0 to 45 degrees")
	if (
		not is_finite(view_size.x)
		or not is_finite(view_size.y)
		or not is_finite(view_size.z)
		or view_size.x <= 0.0
		or view_size.y <= 0.0
		or view_size.z <= 0.0
	):
		errors.append("Weapon view size must be finite and positive")
	if not is_finite(tracer_width) or tracer_width <= 0.0:
		errors.append("Weapon tracer width must be finite and positive")
	if not is_finite(tracer_lifetime) or tracer_lifetime <= 0.0:
		errors.append("Weapon tracer lifetime must be finite and positive")
	return errors

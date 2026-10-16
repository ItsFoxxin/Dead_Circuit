class_name CombatPlayer
extends DamageableBody

@export var player_id: int = -1
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.0025
var local_input_enabled: bool = false
var combat_enabled: bool = true
var suppress_fire_until_release: bool = false

@onready var camera: Camera3D = $Camera
@onready var weapon: WeaponController = $Weapon


func _ready() -> void:
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if not local_input_enabled or not combat_enabled:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		apply_look(motion.relative)


func apply_look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	camera.rotation.x = clampf(camera.rotation.x - relative.y * mouse_sensitivity, -1.4, 1.4)


func movement_velocity(axis: Vector2, sprinting: bool) -> Vector3:
	var direction: Vector3 = basis * Vector3(axis.x, 0.0, axis.y)
	return direction.limit_length(1.0) * (sprint_speed if sprinting else walk_speed)


func _physics_process(delta: float) -> void:
	if not combat_enabled or health.is_dead:
		return
	weapon.advance(delta)
	var axis: Vector2 = Vector2.ZERO
	var sprinting: bool = false
	if local_input_enabled:
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprinting = Input.is_action_pressed("sprint")
		if Input.is_action_just_pressed("reload"):
			weapon.begin_reload()
		if not Input.is_action_pressed("fire"):
			suppress_fire_until_release = false
		if Input.is_action_just_pressed("fire") and not suppress_fire_until_release:
			shoot()
	var planar: Vector3 = movement_velocity(axis, sprinting)
	velocity.x = planar.x
	velocity.z = planar.z
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func shoot() -> DamageContext:
	if not combat_enabled or health.is_dead:
		return null
	return weapon.fire_hitscan(
		get_world_3d(), camera.global_position, -camera.global_basis.z, get_rid(), get_instance_id()
	)


func disable_combat() -> void:
	combat_enabled = false
	weapon.enabled = false
	velocity = Vector3.ZERO


func _on_died(_context: DamageContext) -> void:
	disable_combat()

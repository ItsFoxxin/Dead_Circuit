class_name CombatPlayer
extends DamageableBody

@export var player_id: int = -1
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.0025
var local_input_enabled: bool = false
var combat_enabled: bool = true
var suppress_fire_until_release: bool = false
var items: PlayerItemBuild = PlayerItemBuild.new()
var item_effects: ItemEffectRunner
var weapon: WeaponController:
	get:
		return weapons.current()

@onready var camera: Camera3D = $Camera
@onready var weapons: WeaponLoadout = $Weapons
@onready var weapon_body: MeshInstance3D = $Camera/WeaponBody


func _ready() -> void:
	health.died.connect(_on_died)
	items.player_id = player_id
	item_effects = ItemEffectRunner.new()
	item_effects.player_id = player_id
	item_effects.health = health
	add_child(item_effects)
	items.effect_requested.connect(item_effects.apply)
	weapons.fired.connect(_on_weapon_fired)
	weapons.shot_created.connect(_on_shot_created)
	weapons.equipped_changed.connect(_on_weapon_equipped)


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
	weapons.advance(delta)
	var axis: Vector2 = Vector2.ZERO
	var sprinting: bool = false
	if local_input_enabled:
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprinting = Input.is_action_pressed("sprint")
		for index: int in range(3):
			if Input.is_action_just_pressed(StringName("weapon_%d" % (index + 1))):
				switch_weapon(index)
		if Input.is_action_just_pressed("reload"):
			weapon.begin_reload()
		if not Input.is_action_pressed("fire"):
			suppress_fire_until_release = false
		var wants_fire: bool = Input.is_action_just_pressed("fire")
		if weapon.definition.fire_mode == WeaponDefinition.FireMode.AUTOMATIC:
			wants_fire = Input.is_action_pressed("fire")
		if wants_fire and not suppress_fire_until_release:
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


func configure_weapons(definitions: Array[WeaponDefinition]) -> void:
	weapons.configure(definitions, player_id, items)
	_update_weapon_visual()


func switch_weapon(index: int) -> bool:
	if not combat_enabled or health.is_dead or not weapons.equip(index):
		return false
	_update_weapon_visual()
	return true


func disable_combat() -> void:
	combat_enabled = false
	weapons.enabled = false
	velocity = Vector3.ZERO


func _on_died(_context: DamageContext) -> void:
	disable_combat()


func _on_weapon_fired(context: DamageContext) -> void:
	items.handle_event(
		CombatEvent.new(CombatEvent.Kind.WEAPON_FIRED, context, camera.global_position)
	)


func _on_shot_created(context: DamageContext, origin: Vector3) -> void:
	items.handle_event(CombatEvent.new(CombatEvent.Kind.SHOT_CREATED, context, origin))


func _on_weapon_equipped(_previous_index: int, _current_index: int) -> void:
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	if weapon == null or weapon.definition == null or not is_instance_valid(weapon_body):
		return
	var mesh: BoxMesh = weapon_body.mesh.duplicate() as BoxMesh
	mesh.size = weapon.definition.view_size
	weapon_body.mesh = mesh
	var material: StandardMaterial3D = weapon_body.material_override.duplicate()
	material.albedo_color = weapon.definition.view_color
	weapon_body.material_override = material

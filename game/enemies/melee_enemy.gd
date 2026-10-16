class_name MeleeEnemy
extends DamageableBody

signal removed_from_combat(entity_id: int, context: DamageContext)

@export var definition: EnemyDefinition
var players: Array[CombatPlayer] = []
var combat_enabled: bool = true
var attack_remaining: float = 0.0
var path_remaining: float = 0.0
var target: CombatPlayer

@onready var navigation: NavigationAgent3D = $Navigation


func _ready() -> void:
	health.maximum = definition.maximum_health
	health.reset()
	health.died.connect(_on_died)


func acquire_target() -> CombatPlayer:
	var nearest: CombatPlayer
	var distance: float = INF
	for player: CombatPlayer in players:
		if not is_instance_valid(player) or player.health.is_dead or not player.combat_enabled:
			continue
		var candidate: float = global_position.distance_squared_to(player.global_position)
		if candidate < distance:
			distance = candidate
			nearest = player
	return nearest


func _physics_process(delta: float) -> void:
	if not combat_enabled or health.is_dead:
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
	path_remaining -= delta
	if path_remaining <= 0.0:
		target = acquire_target()
		path_remaining = 0.2
		if is_instance_valid(target):
			navigation.target_position = target.global_position
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(target) and not target.health.is_dead:
		if (
			not try_melee(target)
			and global_position.distance_to(target.global_position) > definition.attack_range
		):
			_follow_path()
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _follow_path() -> void:
	if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) == 0:
		return
	if navigation.is_navigation_finished():
		return
	var direction: Vector3 = navigation.get_next_path_position() - global_position
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * definition.move_speed
	velocity.z = direction.z * definition.move_speed
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func try_melee(player: CombatPlayer) -> bool:
	if not combat_enabled or health.is_dead or player.health.is_dead or not player.combat_enabled:
		return false
	if (
		attack_remaining > 0.0
		or global_position.distance_to(player.global_position) > definition.attack_range
	):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP, player.global_position + Vector3.UP, 3, [get_rid()]
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.get("collider") != player:
		return false
	attack_remaining = definition.attack_cooldown
	player.receive_damage(
		DamageContext.new(
			definition.attack_damage, -1, &"melee", &"melee", ["melee"], get_instance_id()
		)
	)
	return true


func disable_combat() -> void:
	combat_enabled = false
	velocity = Vector3.ZERO


func _on_died(context: DamageContext) -> void:
	disable_combat()
	collision_layer = 0
	removed_from_combat.emit(get_instance_id(), context)
	queue_free()

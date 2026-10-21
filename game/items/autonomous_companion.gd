class_name AutonomousCompanion
extends Node3D
## Generic player-owned companion attack loop; concrete values come from item data.

var owner_player: CombatPlayer
var effect: ItemEffect
var build: PlayerItemBuild
var targets: Array[DamageableBody] = []
var cooldown: float = 0.0
var attack_sequence: int = 0


func configure(
	player: CombatPlayer,
	configuration: ItemEffect,
	item_build: PlayerItemBuild,
	damage_targets: Array[DamageableBody]
) -> void:
	owner_player = player
	effect = configuration
	build = item_build
	targets = damage_targets
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var body: SphereMesh = SphereMesh.new()
	body.radius = 0.18
	body.height = 0.36
	mesh.mesh = body
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.75, 1.0, 1.0)
	mesh.material_override = material
	add_child(mesh)


func _physics_process(delta: float) -> void:
	if (
		not is_instance_valid(owner_player)
		or owner_player.health.is_dead
		or not owner_player.combat_enabled
	):
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var target: DamageableBody = _nearest_target()
	if target == null:
		return
	attack_sequence += 1
	cooldown = 1.0 / effect.attacks_per_second
	var damage: DamageContext = DamageContext.new(
		build.derive(&"damage", effect.amount),
		owner_player.player_id,
		&"",
		&"companion",
		["companion", "secondary"],
		owner_player.get_instance_id(),
		attack_sequence
	)
	damage.is_primary = false
	damage.trigger_eligible = false
	damage.healing_eligible = false
	damage.effect_depth = 1
	target.receive_damage(damage)


func _nearest_target() -> DamageableBody:
	var nearest: DamageableBody
	var nearest_distance: float = effect.radius * effect.radius
	for target: DamageableBody in targets:
		if not is_instance_valid(target) or target.health.is_dead:
			continue
		var distance: float = global_position.distance_squared_to(target.global_position)
		if distance <= nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest

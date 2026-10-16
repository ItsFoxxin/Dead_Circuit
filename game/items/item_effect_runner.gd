class_name ItemEffectRunner
extends Node3D
## Per-owner effects use injected targets and shared damage/health interfaces.

signal exploded(context: DamageContext, position: Vector3, radius: float)

var player_id: int = -1
var health: HealthComponent
var targets: Array[DamageableBody] = []


func apply(effect: ItemEffect, event: CombatEvent) -> void:
	if (
		not is_instance_valid(health)
		or health.is_dead
		or event.context.source_player_id != player_id
	):
		return
	match effect.kind:
		ItemEffect.Kind.HEAL:
			health.heal(effect.amount)
		ItemEffect.Kind.EXPLOSION:
			# All secondary damage may heal, but cannot create more explosions.
			if event.context.effect_depth == 0:
				_explode(effect, event)


func _explode(effect: ItemEffect, event: CombatEvent) -> void:
	var damage: DamageContext = event.context.secondary(effect.amount, &"explosive", ["explosion"])
	exploded.emit(damage, event.position, effect.radius)
	var pulse: ExplosionPulse = ExplosionPulse.new()
	add_child(pulse)
	pulse.show_at(event.position + Vector3.UP, effect.radius)
	# Snapshot: nested death signals may remove targets from the shared registry.
	for target: DamageableBody in targets.duplicate():
		if not is_instance_valid(target) or target.health.is_dead:
			continue
		if (
			target.global_position.distance_squared_to(event.position)
			> effect.radius * effect.radius
		):
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			event.position + Vector3.UP, target.global_position + Vector3.UP, 1
		)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			target.receive_damage(damage)

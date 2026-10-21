class_name ItemEffectRunner
extends Node3D
## Per-owner effects use injected targets, authority RNG and shared combat interfaces.

signal exploded(context: DamageContext, position: Vector3, radius: float)
signal chained(context: DamageContext, targets: Array[int])
signal fragmented(context: DamageContext, targets: Array[int])

const MAX_EFFECT_DEPTH: int = 3

var player_id: int = -1
var owner_player: CombatPlayer
var health: HealthComponent
var build: PlayerItemBuild
var run_random: RunRandom
var targets: Array[DamageableBody] = []:
	set(value):
		targets = value
		for companion: AutonomousCompanion in _companions:
			companion.targets = targets
var _counters: Dictionary[int, int] = {}
var _seen_hits: Dictionary[int, Dictionary] = {}
var _recursive_repeat_chance: float = 0.0
var _companions: Array[AutonomousCompanion] = []


func apply(effect: ItemEffect, event: CombatEvent) -> void:
	if (
		not is_instance_valid(health)
		or health.is_dead
		or event == null
		or event.context == null
		or (
			event.kind != CombatEvent.Kind.PLAYER_DAMAGED
			and event.context.source_player_id != player_id
		)
	):
		return
	match effect.kind:
		ItemEffect.Kind.HEAL:
			if event.context.healing_eligible:
				health.heal(effect.amount)
		ItemEffect.Kind.EXPLOSION:
			if event.context.effect_depth == 0:
				_explode(effect, event)
				_repeat_if_eligible(effect, event)
		ItemEffect.Kind.HIT_COUNTER_HEAL:
			_count_hit_healing(effect, event)
		ItemEffect.Kind.TIMED_STAT:
			if (
				event.context.trigger_eligible
				and (event.kind != CombatEvent.Kind.PLAYER_DAMAGED or event.applied_amount > 0.0)
			):
				build.activate_timed(effect, event)
		ItemEffect.Kind.FRAGMENT_BURST:
			_fragment(effect, event)
		ItemEffect.Kind.LETHAL_GUARD:
			health.grant_lethal_protection(effect.threshold, effect.duration)
		ItemEffect.Kind.HEALTH_COST_TIMED_STAT:
			if health.spend(effect.resource_cost, 1.0) > 0.0:
				build.activate_timed(effect, event)
		ItemEffect.Kind.CHAIN_DAMAGE:
			_count_chain(effect, event)
		ItemEffect.Kind.RECURSIVE_REPEAT:
			_recursive_repeat_chance = maxf(_recursive_repeat_chance, effect.chance)
		ItemEffect.Kind.EXTRA_RAY:
			pass
		ItemEffect.Kind.COMPANION:
			_spawn_companion(effect)


func clear_transient_visuals() -> void:
	for child: Node in get_children():
		if child is ExplosionPulse:
			child.queue_free()


func _count_hit_healing(effect: ItemEffect, event: CombatEvent) -> void:
	if not _qualifying_hit(event):
		return
	var key: int = effect.get_instance_id()
	var attack_key: String = _attack_key(event.context)
	var seen: Dictionary = _seen_hits[key] if _seen_hits.has(key) else {}
	var target_key: String = "%s:%d" % [attack_key, event.target_entity_id]
	if seen.has(target_key):
		return
	seen[target_key] = true
	_seen_hits[key] = seen
	var count: int = _counters[key] if _counters.has(key) else 0
	_counters[key] = count + 1
	if _counters[key] >= effect.threshold:
		_counters[key] -= effect.threshold
		health.heal(effect.amount)
	_prune_seen(seen, attack_key)


func _count_chain(effect: ItemEffect, event: CombatEvent) -> void:
	if not _qualifying_hit(event):
		return
	var key: int = effect.get_instance_id()
	var count: int = _counters[key] if _counters.has(key) else 0
	_counters[key] = count + 1
	if _counters[key] < effect.threshold:
		return
	_counters[key] -= effect.threshold
	_chain(effect, event)
	_repeat_if_eligible(effect, event)


func _explode(effect: ItemEffect, event: CombatEvent) -> void:
	var damage: DamageContext = event.context.secondary(
		effect.amount, &"explosive", ["explosion"], true, true
	)
	exploded.emit(damage, event.position, effect.radius)
	var pulse: ExplosionPulse = ExplosionPulse.new()
	add_child(pulse)
	pulse.show_at(event.position + Vector3.UP, effect.radius)
	for target: DamageableBody in _targets_in_range(event.position, effect.radius):
		if _has_line_of_sight(event.position, target):
			_apply_damage(target, damage, event.position)


func _fragment(effect: ItemEffect, event: CombatEvent) -> void:
	if event.context.effect_depth >= MAX_EFFECT_DEPTH:
		return
	var fragment_damage: DamageContext = event.context.secondary(
		event.context.amount * effect.damage_scale, &"fragment", ["fragment"], false, false
	)
	var hit_ids: Array[int] = []
	for target: DamageableBody in _targets_in_range(event.position, effect.radius):
		if (
			target.get_instance_id() == event.target_entity_id
			or hit_ids.size() >= effect.target_count
		):
			continue
		if _has_line_of_sight(event.position, target):
			_apply_damage(target, fragment_damage, event.position)
			hit_ids.append(target.get_instance_id())
	fragmented.emit(fragment_damage, hit_ids)


func _chain(effect: ItemEffect, event: CombatEvent) -> void:
	if event.context.effect_depth >= MAX_EFFECT_DEPTH:
		return
	var chain_damage: DamageContext = event.context.secondary(
		event.context.amount * effect.damage_scale,
		&"electrical",
		["electrical", "chain"],
		false,
		false
	)
	var hit_ids: Array[int] = []
	for target: DamageableBody in _targets_in_range(event.position, effect.radius):
		if (
			target.get_instance_id() == event.target_entity_id
			or hit_ids.size() >= effect.target_count
		):
			continue
		_apply_damage(target, chain_damage, event.position)
		hit_ids.append(target.get_instance_id())
	chained.emit(chain_damage, hit_ids)


func _apply_damage(target: DamageableBody, context: DamageContext, position: Vector3) -> void:
	var applied: float = target.receive_damage(context)
	if applied > 0.0:
		build.handle_event(
			CombatEvent.new(
				CombatEvent.Kind.TARGET_DAMAGED,
				context,
				position,
				target.get_instance_id(),
				applied
			)
		)


func _spawn_companion(effect: ItemEffect) -> void:
	var companion: AutonomousCompanion = AutonomousCompanion.new()
	companion.name = "AutonomousCompanion"
	companion.configure(owner_player, effect, build, targets)
	add_child(companion)
	companion.position = Vector3(1.2, 1.5, 0.4)
	_companions.append(companion)


func _repeat_if_eligible(effect: ItemEffect, event: CombatEvent) -> void:
	if (
		not effect.recursive_repeat_eligible
		or _recursive_repeat_chance <= 0.0
		or run_random == null
		or event.context.tags.has("recursive_repeat")
		or not run_random.chance(_recursive_repeat_chance)
	):
		return
	var repeated: DamageContext = event.context.secondary(
		event.context.amount,
		event.context.damage_type,
		["recursive_repeat"],
		event.context.trigger_eligible,
		event.context.healing_eligible
	)
	var repeated_event: CombatEvent = CombatEvent.new(
		event.kind, repeated, event.position, event.target_entity_id, event.applied_amount
	)
	if effect.kind == ItemEffect.Kind.EXPLOSION:
		_explode(effect, repeated_event)
	elif effect.kind == ItemEffect.Kind.CHAIN_DAMAGE:
		_chain(effect, repeated_event)


func _targets_in_range(position: Vector3, radius: float) -> Array[DamageableBody]:
	var result: Array[DamageableBody] = []
	for target: DamageableBody in targets.duplicate():
		if (
			is_instance_valid(target)
			and not target.health.is_dead
			and target.global_position.distance_squared_to(position) <= radius * radius
		):
			result.append(target)
	result.sort_custom(
		func(first: DamageableBody, second: DamageableBody) -> bool:
			var first_distance: float = first.global_position.distance_squared_to(position)
			var second_distance: float = second.global_position.distance_squared_to(position)
			if is_equal_approx(first_distance, second_distance):
				return first.get_instance_id() < second.get_instance_id()
			return first_distance < second_distance
	)
	return result


func _has_line_of_sight(position: Vector3, target: DamageableBody) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		position + Vector3.UP, target.global_position + Vector3.UP, 1
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _qualifying_hit(event: CombatEvent) -> bool:
	return (
		event.kind == CombatEvent.Kind.TARGET_DAMAGED
		and event.applied_amount > 0.0
		and event.target_entity_id != 0
		and event.context.trigger_eligible
	)


func _attack_key(context: DamageContext) -> String:
	return "%d:%s:%d" % [context.source_player_id, context.source_weapon_id, context.attack_id]


func _prune_seen(seen: Dictionary, current_attack: String) -> void:
	for key: Variant in seen.keys():
		if not str(key).begins_with(current_attack + ":"):
			seen.erase(key)

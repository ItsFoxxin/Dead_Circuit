class_name PlayerItemBuild
extends RefCounted

signal changed
signal effect_requested(effect: ItemEffect, event: CombatEvent)

var player_id: int = -1
var run_random: RunRandom
var _owned: Dictionary[StringName, ItemDefinition] = {}
var _timed_effects: Dictionary[int, ItemEffect] = {}
var _timed_remaining: Dictionary[int, float] = {}
var _timed_stacks: Dictionary[int, int] = {}
var _timed_attack_keys: Dictionary[int, String] = {}


func acquire(definition: ItemDefinition) -> bool:
	if (
		definition == null
		or _owned.has(definition.id)
		or not definition.validation_errors().is_empty()
	):
		return false
	_owned[definition.id] = definition
	changed.emit()
	var context: DamageContext = DamageContext.new(
		1.0, player_id, &"", &"item", ["item_acquired"], 0
	)
	_dispatch_definition(
		definition, CombatEvent.new(CombatEvent.Kind.ITEM_ACQUIRED, context, Vector3.ZERO)
	)
	return true


func owns(id: StringName) -> bool:
	return _owned.has(id)


func definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var ids: Array[StringName] = _owned.keys()
	ids.sort_custom(
		func(first: StringName, second: StringName) -> bool: return str(first) < str(second)
	)
	for id: StringName in ids:
		result.append(_owned[id])
	return result


func derive(stat: StringName, base: float) -> float:
	var result: float = base
	# Additions, then multipliers; stable item ID, then authored modifier order.
	var ordered: Array[ItemDefinition] = definitions()
	for operation: StatModifier.Operation in [
		StatModifier.Operation.ADD, StatModifier.Operation.MULTIPLY
	]:
		for item: ItemDefinition in ordered:
			for modifier: StatModifier in item.modifiers:
				if modifier.stat == stat and modifier.operation == operation:
					if operation == StatModifier.Operation.ADD:
						result += modifier.value
					else:
						result *= modifier.value
	var effect_keys: Array[int] = _timed_effects.keys()
	effect_keys.sort()
	for key: int in effect_keys:
		var effect: ItemEffect = _timed_effects[key]
		var remaining: float = _timed_remaining[key] if _timed_remaining.has(key) else 0.0
		if effect.stat != stat or remaining <= 0.0:
			continue
		var stacks: int = _timed_stacks[key] if _timed_stacks.has(key) else 1
		if effect.accumulates:
			result *= 1.0 + effect.amount * stacks
		elif effect.operation == StatModifier.Operation.ADD:
			result += effect.amount
		else:
			result *= effect.amount
	return result


func advance(delta: float) -> void:
	var changed_runtime: bool = false
	for key: int in _timed_remaining.keys():
		var remaining: float = maxf(0.0, _timed_remaining[key] - maxf(0.0, delta))
		_timed_remaining[key] = remaining
		if remaining == 0.0:
			_timed_effects.erase(key)
			_timed_remaining.erase(key)
			_timed_stacks.erase(key)
			_timed_attack_keys.erase(key)
			changed_runtime = true
	if changed_runtime:
		changed.emit()


func activate_timed(effect: ItemEffect, event: CombatEvent) -> void:
	var key: int = effect.get_instance_id()
	if effect.max_stacks > 1:
		var attack_key: String = _attack_key(event.context)
		var previous_attack: String = _timed_attack_keys[key] if _timed_attack_keys.has(key) else ""
		if previous_attack != attack_key:
			var current_stacks: int = _timed_stacks[key] if _timed_stacks.has(key) else 0
			_timed_stacks[key] = mini(effect.max_stacks, current_stacks + 1)
			_timed_attack_keys[key] = attack_key
	else:
		_timed_stacks[key] = 1
	_timed_effects[key] = effect
	_timed_remaining[key] = effect.duration
	changed.emit()


func timed_stacks(effect: ItemEffect) -> int:
	var key: int = effect.get_instance_id()
	return _timed_stacks[key] if _timed_stacks.has(key) else 0


func extra_ray_scales(context: DamageContext) -> Array[float]:
	var result: Array[float] = []
	if context == null or run_random == null or not context.is_primary:
		return result
	var event: CombatEvent = CombatEvent.new(CombatEvent.Kind.WEAPON_FIRED, context, Vector3.ZERO)
	for item: ItemDefinition in definitions():
		for trigger: ItemTrigger in item.triggers:
			if not trigger.matches(event):
				continue
			for effect: ItemEffect in trigger.effects:
				if effect.kind == ItemEffect.Kind.EXTRA_RAY and run_random.chance(effect.chance):
					result.append(effect.damage_scale)
	return result


func handle_event(event: CombatEvent) -> void:
	if event == null or event.context == null:
		return
	if (
		event.kind != CombatEvent.Kind.PLAYER_DAMAGED
		and event.context.source_player_id != player_id
	):
		return
	for item: ItemDefinition in definitions():
		_dispatch_definition(item, event)


func _dispatch_definition(definition: ItemDefinition, event: CombatEvent) -> void:
	for trigger: ItemTrigger in definition.triggers:
		if trigger.matches(event):
			for effect: ItemEffect in trigger.effects:
				effect_requested.emit(effect, event)


func _attack_key(context: DamageContext) -> String:
	return "%d:%s:%d" % [context.source_player_id, context.source_weapon_id, context.attack_id]

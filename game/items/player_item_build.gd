class_name PlayerItemBuild
extends RefCounted

signal changed
signal effect_requested(effect: ItemEffect, event: CombatEvent)

var player_id: int = -1
var _owned: Dictionary[StringName, ItemDefinition] = {}


func acquire(definition: ItemDefinition) -> bool:
	if (
		definition == null
		or _owned.has(definition.id)
		or not definition.validation_errors().is_empty()
	):
		return false
	_owned[definition.id] = definition
	changed.emit()
	return true


func owns(id: StringName) -> bool:
	return _owned.has(id)


func definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var ids: Array[StringName] = _owned.keys()
	ids.sort()
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
	return result


func handle_event(event: CombatEvent) -> void:
	if event == null or event.context == null or event.context.source_player_id != player_id:
		return
	for item: ItemDefinition in definitions():
		for trigger: ItemTrigger in item.triggers:
			if trigger.matches(event):
				for effect: ItemEffect in trigger.effects:
					effect_requested.emit(effect, event)

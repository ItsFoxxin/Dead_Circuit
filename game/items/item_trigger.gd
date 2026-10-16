class_name ItemTrigger
extends Resource

@export var event: CombatEvent.Kind = CombatEvent.Kind.ENEMY_KILLED
@export var condition: ItemCondition
@export var effects: Array[ItemEffect] = []


func matches(combat_event: CombatEvent) -> bool:
	return (
		combat_event.kind == event and condition != null and condition.matches(combat_event.context)
	)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if event not in CombatEvent.Kind.values() or condition == null or effects.is_empty():
		errors.append("Trigger requires a known event, condition and effects")
	if condition != null:
		errors.append_array(condition.validation_errors())
	for effect: ItemEffect in effects:
		if effect == null:
			errors.append("Null effect")
		else:
			errors.append_array(effect.validation_errors())
	return errors

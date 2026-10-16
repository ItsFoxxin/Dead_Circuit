class_name CombatEvent
extends RefCounted
## Small, synchronous, session-local events; no global event bus.

enum Kind { WEAPON_FIRED, SHOT_CREATED, ENEMY_KILLED }

var kind: Kind
var context: DamageContext
var position: Vector3
var target_entity_id: int


func _init(event_kind: Kind, damage: DamageContext, location: Vector3, target_id: int = 0) -> void:
	kind = event_kind
	context = damage
	position = location
	target_entity_id = target_id

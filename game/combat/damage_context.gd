class_name DamageContext
extends RefCounted
## A hit retains attribution even after its originating node has been freed.

var amount: float
var source_player_id: int
var source_entity_id: int
var source_weapon_id: StringName
var damage_type: StringName
var tags: PackedStringArray
var effect_depth: int = 0
var attack_id: int = 0
var is_primary: bool = true
var trigger_eligible: bool = true
var healing_eligible: bool = true


func _init(
	value: float = 0.0,
	player_id: int = -1,
	weapon_id: StringName = &"",
	type: StringName = &"ballistic",
	damage_tags: PackedStringArray = [],
	entity_id: int = 0,
	originating_attack_id: int = 0
) -> void:
	amount = value
	source_player_id = player_id
	source_entity_id = entity_id
	source_weapon_id = weapon_id
	damage_type = type
	tags = damage_tags.duplicate()
	attack_id = originating_attack_id


func secondary(
	value: float,
	type: StringName,
	extra_tags: PackedStringArray,
	allows_triggers: bool = false,
	allows_healing: bool = true
) -> DamageContext:
	var result: DamageContext = DamageContext.new(
		value, source_player_id, source_weapon_id, type, tags, source_entity_id, attack_id
	)
	result.effect_depth = effect_depth + 1
	result.is_primary = false
	result.trigger_eligible = allows_triggers
	result.healing_eligible = allows_healing
	result.tags.append("secondary")
	result.tags.append_array(extra_tags)
	return result

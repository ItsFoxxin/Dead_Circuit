class_name DamageContext
extends RefCounted
## A hit retains attribution even after its originating node has been freed.

var amount: float
var source_player_id: int
var source_entity_id: int
var source_weapon_id: StringName
var damage_type: StringName
var tags: PackedStringArray


func _init(
	value: float = 0.0,
	player_id: int = -1,
	weapon_id: StringName = &"",
	type: StringName = &"ballistic",
	damage_tags: PackedStringArray = [],
	entity_id: int = 0
) -> void:
	amount = value
	source_player_id = player_id
	source_entity_id = entity_id
	source_weapon_id = weapon_id
	damage_type = type
	tags = damage_tags.duplicate()

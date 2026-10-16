class_name ItemOffer
extends RefCounted
## Fixed authored order, no random rolls. A command must match this exact offer.

var choices: Array[ItemDefinition] = []
var player_id: int
var session_token: int
var wave_number: int
var consumed: bool = false


func _init(catalog: Array[ItemDefinition], build: PlayerItemBuild, token: int, wave: int) -> void:
	player_id = build.player_id
	session_token = token
	wave_number = wave
	var seen: Dictionary[StringName, bool] = {}
	for item: ItemDefinition in catalog:
		if item != null and not build.owns(item.id) and not seen.has(item.id):
			choices.append(item)
			seen[item.id] = true
		if choices.size() == 3:
			break


func select(id: StringName, build: PlayerItemBuild, token: int, wave: int) -> bool:
	if consumed or token != session_token or wave != wave_number or build.player_id != player_id:
		return false
	for item: ItemDefinition in choices:
		if item.id == id:
			if build.owns(id):
				return false
			consumed = true
			return build.acquire(item)
	return false

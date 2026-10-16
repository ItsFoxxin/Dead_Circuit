class_name ItemOffer
extends RefCounted
## Authority rolls distinct eligible choices; commands must match this exact offer.

var choices: Array[ItemDefinition] = []
var player_id: int
var session_token: int
var wave_number: int
var consumed: bool = false


func _init(
	catalog: Array[ItemDefinition], build: PlayerItemBuild, token: int, wave: int, random: RunRandom
) -> void:
	player_id = build.player_id
	session_token = token
	wave_number = wave
	var seen: Dictionary[StringName, bool] = {}
	var pool: Array[ItemDefinition] = []
	for item: ItemDefinition in catalog:
		if item != null and not build.owns(item.id) and not seen.has(item.id):
			pool.append(item)
			seen[item.id] = true
	pool.sort_custom(
		func(first: ItemDefinition, second: ItemDefinition) -> bool:
			return str(first.id) < str(second.id)
	)
	for index: int in random.sample_indices(pool.size(), 3):
		choices.append(pool[index])


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

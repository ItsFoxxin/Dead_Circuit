class_name RunRandom
extends RefCounted
## One session-owned authoritative sequence. Presentation and physics never draw here.

const MAX_SEED: int = 2147483647

var seed: int = 0
var draw_count: int = 0
var _generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(initial_seed: int = 12345) -> void:
	reset(initial_seed)


func reset(value: int) -> void:
	seed = value
	_generator.seed = value
	draw_count = 0


func choose_index(size: int) -> int:
	if size <= 0:
		return -1
	if size == 1:
		return 0
	draw_count += 1
	return _generator.randi_range(0, size - 1)


func sample_indices(size: int, count: int) -> Array[int]:
	var pool: Array[int] = []
	var result: Array[int] = []
	for index: int in range(size):
		pool.append(index)
	for index: int in range(clampi(count, 0, pool.size())):
		var selected: int = choose_index(pool.size())
		result.append(pool[selected])
		pool.remove_at(selected)
	return result


static func parse_seed(text: String) -> int:
	var value: String = text.strip_edges()
	if value.length() > 10 or not value.is_valid_int():
		return -1
	var parsed: int = value.to_int()
	return parsed if parsed >= 0 and parsed <= MAX_SEED else -1


static func seed_from_arguments(arguments: PackedStringArray, fallback: int) -> int:
	var result: int = fallback
	var found: bool = false
	for argument: String in arguments:
		if argument == "--seed":
			return -1
		if argument.begins_with("--seed="):
			if found:
				return -1
			found = true
			result = parse_seed(argument.trim_prefix("--seed="))
	return result if result >= 0 and result <= MAX_SEED else -1

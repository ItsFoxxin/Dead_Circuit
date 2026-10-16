extends SceneTree
## Test-only fixture. Does not implement the future authoritative run RNG.


func _initialize() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var choices: Array[int] = []
	for index: int in range(16):
		choices.append(rng.randi_range(0, 999))
	print("DETERMINISM_PROBE=" + JSON.stringify(choices))
	quit(0)

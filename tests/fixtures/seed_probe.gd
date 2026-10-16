extends SceneTree
## Preserve the original engine fixture; run_probe.gd also checks actual gameplay rolls.


func _initialize() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var choices: Array[int] = []
	for index: int in range(16):
		choices.append(rng.randi_range(0, 999))
	print("DETERMINISM_PROBE=" + JSON.stringify(choices))
	quit(0)

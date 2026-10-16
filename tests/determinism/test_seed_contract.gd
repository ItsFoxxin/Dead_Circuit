extends GutTest
## Exercises seeded test fixtures only; gameplay RNG remains a later milestone.


func test_equal_seeds_reproduce_choices() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 12345
	second.seed = 12345
	for index: int in range(64):
		assert_eq(first.randi(), second.randi(), "Seed diverged at draw %d" % index)


func test_rng_state_can_be_replayed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var saved_state: int = rng.state
	var expected: int = rng.randi()
	rng.state = saved_state
	assert_eq(rng.randi(), expected)


func test_pinned_engine_fixture_matches_expected_choices() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var expected: Array[int] = [956, 747, 241, 820, 406, 269, 141, 88]
	for choice: int in expected:
		assert_eq(rng.randi_range(0, 999), choice)

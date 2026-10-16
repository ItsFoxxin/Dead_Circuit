extends GutTest


func test_equal_seeds_replay_production_draws_and_reset_draw_count() -> void:
	var first: RunRandom = RunRandom.new(12345)
	var second: RunRandom = RunRandom.new(12345)
	var expected: Array[int] = []
	for index: int in range(64):
		var choice: int = first.choose_index(1000)
		expected.append(choice)
		assert_eq(choice, second.choose_index(1000))
	assert_eq(first.seed, 12345)
	assert_eq(first.draw_count, 64)
	first.reset(12345)
	assert_eq(first.draw_count, 0)
	for choice: int in expected:
		assert_eq(first.choose_index(1000), choice)


func test_different_seeds_change_choices_and_instances_do_not_share_state() -> void:
	var first: RunRandom = RunRandom.new(42)
	var second: RunRandom = RunRandom.new(43)
	var untouched: RunRandom = RunRandom.new(43)
	var same: bool = true
	for index: int in range(32):
		if first.choose_index(1000) != second.choose_index(1000):
			same = false
	assert_false(same)
	second.reset(43)
	assert_eq(second.sample_indices(12, 12), untouched.sample_indices(12, 12))


func test_production_rng_preserves_the_pinned_engine_fixture() -> void:
	var random: RunRandom = RunRandom.new(12345)
	var expected: Array[int] = [956, 747, 241, 820, 406, 269, 141, 88]
	for choice: int in expected:
		assert_eq(random.choose_index(1000), choice)

extends GutTest


func test_sampling_is_bounded_without_replacement() -> void:
	var random: RunRandom = RunRandom.new(12345)
	var indices: Array[int] = random.sample_indices(12, 99)
	assert_eq(indices.size(), 12)
	indices.sort()
	for index: int in range(12):
		assert_eq(indices[index], index)
	assert_eq(random.draw_count, 11, "The final singleton requires no random choice")


func test_empty_singleton_and_negative_requests_do_not_draw() -> void:
	var random: RunRandom = RunRandom.new(0)
	assert_eq(random.choose_index(0), -1)
	assert_eq(random.choose_index(1), 0)
	assert_eq(random.sample_indices(0, 3).size(), 0)
	assert_eq(random.sample_indices(5, -1).size(), 0)
	assert_eq(random.sample_indices(-1, 5).size(), 0)
	assert_eq(random.draw_count, 0)


func test_seed_parser_rejects_malformed_and_overflowing_input() -> void:
	for invalid: String in ["", "abc", "1.5", "1e3", "-1", "2147483648", "99999999999999999999"]:
		assert_eq(RunRandom.parse_seed(invalid), -1, invalid)
	assert_eq(RunRandom.parse_seed("0"), 0)
	assert_eq(RunRandom.parse_seed(" 42 "), 42)
	assert_eq(RunRandom.parse_seed("2147483647"), RunRandom.MAX_SEED)


func test_command_line_uses_explicit_seed_or_authored_default_and_rejects_ambiguity() -> void:
	assert_eq(RunRandom.seed_from_arguments(["--smoke"], 12345), 12345)
	assert_eq(RunRandom.seed_from_arguments(["--seed=42", "--smoke"], 12345), 42)
	assert_eq(RunRandom.seed_from_arguments(["--seed=0"], 12345), 0)
	assert_eq(RunRandom.seed_from_arguments(["--seed=bad"], 12345), -1)
	assert_eq(RunRandom.seed_from_arguments(["--seed"], 12345), -1)
	assert_eq(RunRandom.seed_from_arguments(["--seed=1", "--seed=2"], 12345), -1)
	assert_eq(RunRandom.seed_from_arguments([], -5), -1)

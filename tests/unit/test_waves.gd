extends GutTest

var waves: WaveManager


func before_each() -> void:
	var definition: WaveDefinition = WaveDefinition.new()
	definition.id = &"test_waves"
	definition.counts = [1, 2, 3, 4, 5]
	waves = WaveManager.new()
	waves.definition = definition
	add_child_autofree(waves)
	waves.reset()


func test_wave_one_begins_with_pending_spawns() -> void:
	watch_signals(waves)
	waves.start()
	assert_eq(waves.wave_number, 1)
	assert_eq(waves.remaining(), 1)
	assert_signal_emitted_with_parameters(waves, "wave_started", [1, 1])
	waves.start()
	assert_eq(waves.wave_number, 1)


func test_live_or_unspawned_enemies_prevent_advancement() -> void:
	waves.start()
	await get_tree().process_frame
	assert_eq(waves.wave_number, 1)
	waves.register_enemy(10, waves.session_token)
	waves.register_enemy(10, waves.session_token)
	assert_eq(waves.remaining(), 1)
	await get_tree().process_frame
	assert_eq(waves.wave_number, 1)
	waves.remove_enemy(99, waves.session_token)
	assert_eq(waves.remaining(), 1)


func test_clear_advances_and_fifth_wave_completes_once() -> void:
	watch_signals(waves)
	waves.start()
	for number: int in range(1, 6):
		assert_eq(waves.wave_number, number)
		for index: int in range(number):
			waves.register_enemy(number * 100 + index, waves.session_token)
		for index: int in range(number):
			waves.remove_enemy(number * 100 + index, waves.session_token)
		await get_tree().process_frame
	assert_eq(waves.state, WaveManager.State.COMPLETED)
	assert_eq(waves.remaining(), 0)
	assert_signal_emit_count(waves, "completed", 1)
	waves.remove_enemy(500, waves.session_token)
	assert_signal_emit_count(waves, "completed", 1)


func test_reset_rejects_stale_callbacks_and_deferred_advance() -> void:
	waves.start()
	var previous: int = waves.session_token
	waves.register_enemy(1, previous)
	waves.remove_enemy(1, previous)
	waves.reset()
	waves.start()
	waves.register_enemy(2, waves.session_token)
	waves.remove_enemy(2, previous)
	await get_tree().process_frame
	assert_eq(waves.wave_number, 1)
	assert_eq(waves.remaining(), 1)

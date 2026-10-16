extends GutTest

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	add_child_autofree(health)


func test_damage_reduces_health_and_retains_context() -> void:
	var context: DamageContext = DamageContext.new(
		20.0, 7, &"test_pistol", &"ballistic", ["hitscan"], 99
	)
	watch_signals(health)
	assert_eq(health.take_damage(context), 20.0)
	assert_eq(health.current, 80.0)
	assert_signal_emitted_with_parameters(health, "damaged", [context, 20.0])
	assert_eq(context.source_player_id, 7)
	assert_eq(context.source_weapon_id, &"test_pistol")
	assert_eq(context.source_entity_id, 99)
	assert_eq(context.damage_type, &"ballistic")
	assert_eq(context.amount, 20.0)
	assert_eq(context.tags, PackedStringArray(["hitscan"]))


func test_invalid_damage_cannot_heal_or_corrupt_health() -> void:
	for amount: float in [-5.0, 0.0, NAN, INF]:
		assert_eq(health.take_damage(DamageContext.new(amount)), 0.0)
	assert_eq(health.current, health.maximum)
	assert_false(health.is_dead)


func test_overkill_clamps_and_death_occurs_once() -> void:
	watch_signals(health)
	assert_eq(health.take_damage(DamageContext.new(500.0)), 100.0)
	assert_eq(health.current, 0.0)
	assert_true(health.is_dead)
	assert_eq(health.take_damage(DamageContext.new(20.0)), 0.0)
	assert_signal_emit_count(health, "died", 1)
	assert_signal_emit_count(health, "damaged", 1)


func test_reset_starts_a_new_life() -> void:
	health.take_damage(DamageContext.new(500.0))
	health.reset()
	assert_eq(health.current, 100.0)
	assert_false(health.is_dead)
	assert_eq(health.take_damage(DamageContext.new(10.0)), 10.0)


func test_damage_tags_are_copied_from_source() -> void:
	var original: PackedStringArray = ["hitscan"]
	var context: DamageContext = DamageContext.new(10.0, 2, &"pistol", &"ballistic", original)
	original.append("modified")
	assert_eq(context.tags.size(), 1)

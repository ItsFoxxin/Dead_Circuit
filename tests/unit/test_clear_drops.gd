extends GutTest

const Supplies: ClearDropDefinition = preload("res://content/loot_tables/room_supplies.tres")


func test_authored_supplies_are_small_and_validate_probability_bounds() -> void:
	assert_true(Supplies.validation_errors().is_empty())
	assert_eq(Supplies.chance_percent, 25)
	assert_eq(Supplies.health_amount, 10.0)
	assert_eq(Supplies.ammunition, 12)
	var invalid: ClearDropDefinition = Supplies.duplicate() as ClearDropDefinition
	invalid.chance_percent = 101
	invalid.health_amount = NAN
	invalid.ammunition = 0
	assert_eq(invalid.validation_errors().size(), 2)


func test_zero_chance_does_not_consume_authoritative_rng() -> void:
	var drop: ClearDropDefinition = Supplies.duplicate() as ClearDropDefinition
	drop.chance_percent = 0
	var random: RunRandom = RunRandom.new(12345)
	assert_eq(drop.roll(random), ClearDropDefinition.Kind.NONE)
	assert_eq(random.draw_count, 0)


func test_same_seed_reproduces_drop_presence_and_kind() -> void:
	var first: RunRandom = RunRandom.new(42)
	var second: RunRandom = RunRandom.new(42)
	var health: bool = false
	var ammo: bool = false
	var none: bool = false
	for index: int in range(100):
		var kind: ClearDropDefinition.Kind = Supplies.roll(first)
		assert_eq(kind, Supplies.roll(second))
		health = health or kind == ClearDropDefinition.Kind.HEALTH
		ammo = ammo or kind == ClearDropDefinition.Kind.AMMUNITION
		none = none or kind == ClearDropDefinition.Kind.NONE
	assert_true(health and ammo and none)
	assert_eq(first.draw_count, second.draw_count)

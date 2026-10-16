extends GutTest


func test_add_then_multiply_is_independent_of_acquisition_order() -> void:
	var add: ItemDefinition = _item(&"z_add", StatModifier.Operation.ADD, 10.0)
	var multiply: ItemDefinition = _item(&"a_multiply", StatModifier.Operation.MULTIPLY, 2.0)
	var first: PlayerItemBuild = PlayerItemBuild.new()
	var second: PlayerItemBuild = PlayerItemBuild.new()
	first.acquire(add)
	first.acquire(multiply)
	second.acquire(multiply)
	second.acquire(add)
	assert_eq(first.derive(&"damage", 30.0), 80.0)
	assert_eq(first.derive(&"damage", 30.0), second.derive(&"damage", 30.0))
	assert_eq(first.definitions()[0].id, &"a_multiply")


func test_fixed_offers_are_reproducible_and_do_not_use_rng() -> void:
	var catalog: Array[ItemDefinition] = [
		_item(&"a", StatModifier.Operation.ADD, 1.0),
		_item(&"b", StatModifier.Operation.ADD, 2.0),
		_item(&"c", StatModifier.Operation.ADD, 3.0),
		_item(&"d", StatModifier.Operation.ADD, 4.0)
	]
	var build: PlayerItemBuild = PlayerItemBuild.new()
	build.acquire(catalog[0])
	var first: ItemOffer = ItemOffer.new(catalog, build, 10, 1)
	var second: ItemOffer = ItemOffer.new(catalog, build, 99, 4)
	for index: int in range(3):
		assert_eq(first.choices[index].id, second.choices[index].id)


func _item(id: StringName, operation: StatModifier.Operation, value: float) -> ItemDefinition:
	var item: ItemDefinition = ItemDefinition.new()
	item.id = id
	item.display_name = str(id)
	item.description = "Test definition"
	var modifier: StatModifier = StatModifier.new()
	modifier.operation = operation
	modifier.value = value
	item.modifiers = [modifier]
	return item

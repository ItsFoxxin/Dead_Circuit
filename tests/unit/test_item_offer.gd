extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")

var catalog: Array[ItemDefinition]
var build: PlayerItemBuild


func before_each() -> void:
	var session: CombatSession = Sandbox.instantiate() as CombatSession
	catalog = session.item_catalog.duplicate()
	session.free()
	build = PlayerItemBuild.new()
	build.player_id = 7


func test_three_distinct_choices_exclude_owned_and_duplicate_catalog_entries() -> void:
	build.acquire(catalog[0])
	catalog.insert(1, catalog[1])
	var offer: ItemOffer = ItemOffer.new(catalog, build, 10, 1)
	assert_eq(offer.choices.size(), 3)
	assert_false(offer.choices.has(catalog[0]))
	assert_ne(offer.choices[0].id, offer.choices[1].id)
	assert_ne(offer.choices[1].id, offer.choices[2].id)
	assert_ne(offer.choices[0].id, offer.choices[2].id)


func test_selection_requires_matching_player_session_wave_and_offered_id() -> void:
	var offer: ItemOffer = ItemOffer.new(catalog, build, 10, 2)
	var other: PlayerItemBuild = PlayerItemBuild.new()
	other.player_id = 8
	var id: StringName = offer.choices[0].id
	assert_false(offer.select(id, build, 9, 2))
	assert_false(offer.select(id, build, 10, 1))
	assert_false(offer.select(id, other, 10, 2))
	assert_false(offer.select(&"not_offered", build, 10, 2))
	assert_true(build.definitions().is_empty())
	assert_false(offer.consumed)
	assert_true(offer.select(id, build, 10, 2))
	assert_false(offer.select(offer.choices[1].id, build, 10, 2))
	assert_eq(build.definitions().size(), 1)
	assert_true(other.definitions().is_empty())


func test_short_and_exhausted_pools_offer_only_eligible_items() -> void:
	for index: int in range(3):
		build.acquire(catalog[index])
	assert_eq(ItemOffer.new(catalog, build, 1, 4).choices.size(), 2)
	for item: ItemDefinition in catalog:
		build.acquire(item)
	assert_true(ItemOffer.new(catalog, build, 1, 4).choices.is_empty())

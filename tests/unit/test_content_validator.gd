extends GutTest

const Validator = preload("res://tools/content_validator.gd")
const ROOT: String = "user://content_validator_test"


func before_each() -> void:
	for directory: String in Validator.CONTENT_DIRECTORIES:
		DirAccess.make_dir_recursive_absolute(ROOT.path_join(directory))


func after_each() -> void:
	for directory: String in Validator.CONTENT_DIRECTORIES:
		var path: String = ROOT.path_join(directory)
		if DirAccess.dir_exists_absolute(path):
			for file: String in DirAccess.get_files_at(path):
				DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(ROOT.path_join(directory))
	DirAccess.remove_absolute(ROOT)


func test_empty_content_tree_is_valid() -> void:
	assert_eq(Validator.new().validate(ROOT).size(), 0)


func test_unregistered_content_fails_closed() -> void:
	var file: FileAccess = FileAccess.open(
		ROOT.path_join("items/unregistered.json"), FileAccess.WRITE
	)
	file.store_string("{}")
	file.close()
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "No registered content schema")


func test_missing_content_directory_is_reported() -> void:
	DirAccess.remove_absolute(ROOT.path_join("bosses"))
	assert_eq(Validator.new().validate(ROOT).size(), 1)


func test_invalid_weapon_numbers_are_rejected() -> void:
	var definition: WeaponDefinition = WeaponDefinition.new()
	definition.id = &"invalid_weapon"
	definition.display_name = "Invalid"
	definition.magazine_capacity = 0
	definition.damage = NAN
	ResourceSaver.save(definition, ROOT.path_join("weapons/invalid.tres"))
	assert_gt(Validator.new().validate(ROOT).size(), 0)


func test_duplicate_ids_are_rejected() -> void:
	var definition: WeaponDefinition = WeaponDefinition.new()
	definition.id = &"duplicate"
	definition.display_name = "Duplicate"
	ResourceSaver.save(definition, ROOT.path_join("weapons/first.tres"))
	ResourceSaver.save(definition, ROOT.path_join("weapons/second.tres"))
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "Duplicate content id")


func test_prototype_wave_schema_rejects_wrong_count() -> void:
	var definition: WaveDefinition = WaveDefinition.new()
	definition.id = &"bad_waves"
	definition.counts = [1, 2]
	ResourceSaver.save(definition, ROOT.path_join("rooms/invalid.tres"))
	assert_gt(Validator.new().validate(ROOT).size(), 0)


func test_item_schema_rejects_invalid_nested_effects_and_stacking() -> void:
	var item: ItemDefinition = ItemDefinition.new()
	item.id = &"invalid_item"
	item.display_name = "Invalid"
	item.description = "Bad trigger"
	item.stacking = &"accidental_stacking"
	var trigger: ItemTrigger = ItemTrigger.new()
	trigger.condition = ItemCondition.new()
	trigger.condition.required_tags = ["weapon"]
	trigger.condition.excluded_tags = ["weapon"]
	var effect: ItemEffect = ItemEffect.new()
	effect.amount = NAN
	effect.radius = -1.0
	trigger.effects = [effect]
	item.triggers = [trigger]
	ResourceSaver.save(item, ROOT.path_join("items/invalid.tres"))
	assert_gt(Validator.new().validate(ROOT).size(), 3)


func test_authored_item_schema_and_catalog_are_valid() -> void:
	var validator: ContentValidator = Validator.new()
	assert_eq(validator.validate().size(), 0)
	assert_eq(validator.definition_count, 19)


func test_authored_sandbox_seed_must_fit_supported_input_range() -> void:
	var packed: PackedScene = load("res://content/rooms/combat_sandbox.tscn") as PackedScene
	var session: CombatSession = packed.instantiate() as CombatSession
	session.run_seed = -1
	var invalid: PackedScene = PackedScene.new()
	assert_eq(invalid.pack(session), OK)
	assert_eq(ResourceSaver.save(invalid, ROOT.path_join("rooms/invalid_seed.tscn")), OK)
	session.free()
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "Sandbox seed")


func test_room_definition_requires_a_real_exit_marker() -> void:
	var room: RoomDefinition = RoomDefinition.new()
	room.id = &"missing_exit"
	room.display_name = "Missing exit"
	room.scene = load("res://content/rooms/greybox_arena.tscn") as PackedScene
	assert_eq(ResourceSaver.save(room, ROOT.path_join("rooms/invalid_room.tres")), OK)
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "exit marker")


func test_route_order_is_validated_without_changing_reusable_definition() -> void:
	var authored: RunDefinition = load("res://content/rooms/prototype_run.tres") as RunDefinition
	var invalid: RunDefinition = RunDefinition.new()
	invalid.id = &"wrong_order"
	invalid.rooms = [authored.rooms[1], authored.rooms[0], authored.rooms[2], authored.rooms[3]]
	assert_true(invalid.validation_errors().is_empty(), "Order is content policy")
	assert_eq(ResourceSaver.save(invalid, ROOT.path_join("rooms/invalid_route.tres")), OK)
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "start, combat, treasure, boss order")


func test_invalid_drop_configuration_is_rejected() -> void:
	var drop: ClearDropDefinition = ClearDropDefinition.new()
	drop.id = &"invalid_drop"
	drop.chance_percent = 101
	ResourceSaver.save(drop, ROOT.path_join("loot_tables/invalid.tres"))
	assert_false(Validator.new().validate(ROOT).is_empty())


func test_boss_room_requires_a_spawn_marker_and_a_boss_scene() -> void:
	var room: RoomDefinition = (
		load("res://content/rooms/first_boss_room.tres").duplicate() as RoomDefinition
	)
	room.id = &"invalid_boss_room"
	room.scene = load("res://content/rooms/greybox_room.tscn") as PackedScene
	room.boss_scene = load("res://content/enemies/basic_zombie.tscn") as PackedScene
	ResourceSaver.save(room, ROOT.path_join("rooms/invalid_boss.tres"))
	assert_eq(Validator.new().validate(ROOT).size(), 2)

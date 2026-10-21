extends GutTest

const Pistol: WeaponDefinition = preload("res://content/weapons/prototype_pistol.tres")
const Smg: WeaponDefinition = preload("res://content/weapons/relay_smg.tres")
const Shotgun: WeaponDefinition = preload("res://content/weapons/scatterline_shotgun.tres")

var loadout: WeaponLoadout


func before_each() -> void:
	loadout = WeaponLoadout.new()
	add_child_autofree(loadout)
	loadout.configure([Pistol, Smg, Shotgun], 7)


func test_authored_weapons_have_distinct_data_driven_firing_semantics() -> void:
	assert_eq(Pistol.fire_mode, WeaponDefinition.FireMode.SEMI_AUTOMATIC)
	assert_eq(Pistol.base_shot_count, 1)
	assert_eq(Smg.fire_mode, WeaponDefinition.FireMode.AUTOMATIC)
	assert_gt(Smg.shots_per_second, Pistol.shots_per_second)
	assert_eq(Shotgun.base_shot_count, 7)
	assert_gt(Shotgun.spread_degrees, Pistol.spread_degrees)
	for definition: WeaponDefinition in [Pistol, Smg, Shotgun]:
		assert_true(definition.validation_errors().is_empty())
		assert_gt(definition.tracer_width, 0.0)
		assert_gt(definition.tracer_lifetime, 0.0)


func test_switching_preserves_independent_ammo_reload_and_cooldown_state() -> void:
	var pistol: WeaponController = loadout.current()
	assert_not_null(pistol.try_fire())
	assert_true(pistol.begin_reload())
	assert_true(loadout.equip(1))
	var smg: WeaponController = loadout.current()
	assert_eq(smg.magazine, Smg.magazine_capacity)
	assert_not_null(smg.try_fire())
	assert_true(loadout.equip(2))
	var shotgun: WeaponController = loadout.current()
	assert_not_null(shotgun.try_fire())
	loadout.advance(Pistol.reload_seconds)
	assert_true(loadout.equip(0))
	assert_eq(pistol.magazine, Pistol.magazine_capacity)
	assert_eq(pistol.reserve, Pistol.starting_reserve - 1)
	assert_false(pistol.reloading)
	assert_eq(pistol.fire_remaining, 0.0)
	assert_eq(smg.magazine, Smg.magazine_capacity - 1)
	assert_eq(shotgun.magazine, Shotgun.magazine_capacity - 1)


func test_all_weapon_controllers_retain_player_and_weapon_ownership() -> void:
	for index: int in range(loadout.controllers.size()):
		loadout.equip(index)
		var context: DamageContext = loadout.current().try_fire(99)
		assert_eq(context.source_player_id, 7)
		assert_eq(context.source_entity_id, 99)
		assert_eq(context.source_weapon_id, loadout.current().definition.id)
		assert_true(context.tags.has("weapon"))


func test_reset_restores_every_weapon_and_equips_first_slot() -> void:
	for controller: WeaponController in loadout.controllers:
		controller.try_fire()
		controller.begin_reload()
	loadout.equip(2)
	loadout.reset()
	assert_eq(loadout.equipped_index, 0)
	for controller: WeaponController in loadout.controllers:
		assert_eq(controller.magazine, controller.definition.magazine_capacity)
		assert_eq(controller.reserve, controller.definition.starting_reserve)
		assert_false(controller.reloading)
		assert_eq(controller.fire_remaining, 0.0)


func test_invalid_firing_configuration_is_rejected() -> void:
	var invalid: WeaponDefinition = WeaponDefinition.new()
	invalid.id = &"invalid"
	invalid.display_name = "Invalid"
	invalid.base_shot_count = 0
	invalid.spread_degrees = 90.0
	invalid.tracer_width = 0.0
	invalid.tracer_lifetime = 0.0
	assert_gt(invalid.validation_errors().size(), 1)

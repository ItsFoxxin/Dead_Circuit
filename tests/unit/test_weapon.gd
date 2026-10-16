extends GutTest

var weapon: WeaponController


func before_each() -> void:
	var definition: WeaponDefinition = WeaponDefinition.new()
	definition.id = &"test_pistol"
	definition.display_name = "Test Pistol"
	definition.magazine_capacity = 3
	definition.starting_reserve = 5
	definition.reload_seconds = 1.0
	weapon = WeaponController.new()
	weapon.configure(definition, 7)
	add_child_autofree(weapon)


func test_firing_consumes_ammo_and_preserves_attribution() -> void:
	var context: DamageContext = weapon.try_fire(99)
	assert_not_null(context)
	assert_eq(weapon.magazine, 2)
	assert_eq(weapon.reserve, 5)
	assert_eq(context.source_player_id, 7)
	assert_eq(context.source_weapon_id, &"test_pistol")
	assert_eq(context.source_entity_id, 99)
	assert_eq(context.amount, weapon.definition.damage)


func test_empty_weapon_and_fire_cooldown_prevent_shots() -> void:
	for index: int in range(3):
		assert_not_null(weapon.try_fire())
		assert_null(weapon.try_fire())
		weapon.advance(1.0)
	assert_eq(weapon.magazine, 0)
	assert_null(weapon.try_fire())
	assert_eq(weapon.reserve, 5)


func test_reload_transfers_only_missing_ammo() -> void:
	weapon.try_fire()
	assert_true(weapon.begin_reload())
	assert_null(weapon.try_fire())
	weapon.advance(0.5)
	assert_eq(weapon.magazine, 2)
	weapon.advance(0.5)
	assert_eq(weapon.magazine, 3)
	assert_eq(weapon.reserve, 4)
	assert_false(weapon.reloading)
	weapon.advance(10.0)
	assert_eq(weapon.magazine, 3)
	assert_false(weapon.begin_reload())


func test_reload_with_insufficient_reserve_respects_capacity() -> void:
	weapon.magazine = 0
	weapon.reserve = 2
	assert_true(weapon.begin_reload())
	weapon.advance(1.0)
	assert_eq(weapon.magazine, 2)
	assert_eq(weapon.reserve, 0)
	assert_false(weapon.begin_reload())


func test_disable_freezes_timers_and_reset_restores_all_state() -> void:
	weapon.try_fire()
	weapon.begin_reload()
	weapon.enabled = false
	weapon.advance(5.0)
	assert_eq(weapon.reload_remaining, 1.0)
	assert_null(weapon.try_fire())
	weapon.reset()
	assert_eq(weapon.magazine, 3)
	assert_eq(weapon.reserve, 5)
	assert_eq(weapon.reload_remaining, 0.0)
	assert_eq(weapon.fire_remaining, 0.0)
	assert_false(weapon.reloading)
	assert_true(weapon.enabled)


func test_two_owners_do_not_share_ammunition() -> void:
	var other: WeaponController = WeaponController.new()
	other.configure(weapon.definition, 8)
	add_child_autofree(other)
	weapon.try_fire()
	assert_eq(other.magazine, 3)
	assert_eq(other.try_fire().source_player_id, 8)

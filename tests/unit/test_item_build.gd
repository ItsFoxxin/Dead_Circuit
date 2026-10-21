extends GutTest

const Heavy: ItemDefinition = preload("res://content/items/heavy_lead.tres")
const Split: ItemDefinition = preload("res://content/items/split_chamber.tres")
const Rapid: ItemDefinition = preload("res://content/items/rapid_mechanism.tres")
const Vampiric: ItemDefinition = preload("res://content/items/vampiric_ammo.tres")
const TestFaction: ItemFaction = preload("res://content/factions/iron_doctrine.tres")

var build: PlayerItemBuild
var weapon: WeaponController


func before_each() -> void:
	build = PlayerItemBuild.new()
	build.player_id = 7
	weapon = WeaponController.new()
	var base: WeaponDefinition = WeaponDefinition.new()
	base.id = &"test_weapon"
	base.display_name = "Test"
	weapon.configure(base, 7, build)
	add_child_autofree(weapon)


func test_ownership_is_independent_and_duplicates_are_rejected() -> void:
	var other: PlayerItemBuild = PlayerItemBuild.new()
	other.player_id = 8
	assert_true(build.acquire(Heavy))
	assert_false(build.acquire(Heavy))
	assert_true(other.acquire(Rapid))
	assert_false(other.owns(Heavy.id))
	assert_false(build.owns(Rapid.id))
	assert_eq(build.definitions().size(), 1)


func test_damage_rate_and_multishot_compose_without_mutating_base() -> void:
	build.acquire(Heavy)
	build.acquire(Split)
	build.acquire(Rapid)
	var stats: WeaponStats = weapon.combat_stats()
	assert_almost_eq(stats.damage, 39.0, 0.0001)
	assert_almost_eq(stats.fire_rate, 4.5, 0.0001)
	assert_eq(stats.shot_count, 2)
	assert_almost_eq(stats.shot_damage_scale, 0.85, 0.0001)
	assert_eq(weapon.definition.damage, 30.0)
	assert_eq(weapon.definition.shots_per_second, 4.0)
	assert_eq(weapon.definition.magazine_capacity, 12)
	var context: DamageContext = weapon.try_fire(99)
	assert_almost_eq(context.amount, 33.15, 0.0001)
	assert_almost_eq(weapon.fire_remaining, 1.0 / 4.5, 0.0001)
	assert_eq(weapon.magazine, 11)


func test_each_modifier_applies_its_declared_stat_only() -> void:
	build.acquire(Rapid)
	assert_eq(weapon.combat_stats().fire_rate, 5.0)
	assert_eq(weapon.combat_stats().damage, 30.0)
	build.acquire(Split)
	assert_eq(weapon.combat_stats().shot_count, 2)
	assert_almost_eq(weapon.try_fire().amount, 25.5, 0.0001)


func test_kill_triggers_filter_owner_event_and_damage_tags() -> void:
	build.acquire(Vampiric)
	watch_signals(build)
	var context: DamageContext = DamageContext.new(30.0, 8, &"test", &"ballistic", ["weapon"])
	build.handle_event(CombatEvent.new(CombatEvent.Kind.ENEMY_KILLED, context, Vector3.ZERO))
	assert_signal_not_emitted(build, "effect_requested")
	context.source_player_id = 7
	build.handle_event(CombatEvent.new(CombatEvent.Kind.WEAPON_FIRED, context, Vector3.ZERO))
	assert_signal_not_emitted(build, "effect_requested")
	context.tags.clear()
	build.handle_event(CombatEvent.new(CombatEvent.Kind.ENEMY_KILLED, context, Vector3.ZERO))
	assert_signal_not_emitted(build, "effect_requested")
	context.tags.append("weapon")
	build.handle_event(CombatEvent.new(CombatEvent.Kind.ENEMY_KILLED, context, Vector3.ZERO))
	assert_signal_emit_count(build, "effect_requested", 1)


func test_secondary_damage_copies_all_attribution_without_mutating_parent() -> void:
	var original: DamageContext = DamageContext.new(25.5, 7, &"test", &"ballistic", ["weapon"], 99)
	var child: DamageContext = original.secondary(45.0, &"explosive", ["explosion"])
	assert_eq(child.source_player_id, 7)
	assert_eq(child.source_entity_id, 99)
	assert_eq(child.source_weapon_id, &"test")
	assert_eq(child.amount, 45.0)
	assert_eq(child.damage_type, &"explosive")
	assert_eq(child.effect_depth, 1)
	assert_true(child.tags.has("weapon"))
	assert_true(child.tags.has("secondary"))
	assert_true(child.tags.has("explosion"))
	assert_eq(original.effect_depth, 0)
	assert_eq(original.tags, PackedStringArray(["weapon"]))


func test_invalid_definitions_and_modifier_values_cannot_be_acquired() -> void:
	var item: ItemDefinition = ItemDefinition.new()
	item.id = &"bad"
	item.display_name = "Bad"
	item.description = "Invalid stat"
	item.flavor_text = "Invalid on purpose."
	item.faction = TestFaction
	var modifier: StatModifier = StatModifier.new()
	modifier.stat = &"unknown"
	item.modifiers = [modifier]
	assert_false(build.acquire(item))
	modifier.stat = &"shot_count"
	modifier.value = 1.5
	assert_false(build.acquire(item))
	modifier.stat = &"damage"
	modifier.value = NAN
	assert_false(build.acquire(item))
	assert_true(build.definitions().is_empty())


func test_healing_clamps_and_does_not_resurrect() -> void:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	health.take_damage(DamageContext.new(3.0))
	assert_eq(health.heal(5.0), 3.0)
	assert_eq(health.current, 100.0)
	assert_eq(health.heal(-5.0), 0.0)
	assert_eq(health.heal(INF), 0.0)
	health.take_damage(DamageContext.new(100.0))
	assert_eq(health.heal(100.0), 0.0)
	assert_true(health.is_dead)

extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")
const Split: ItemDefinition = preload("res://content/items/split_chamber.tres")
const Volatile: ItemDefinition = preload("res://content/items/volatile_rounds.tres")
const Vampiric: ItemDefinition = preload("res://content/items/vampiric_ammo.tres")

var session: CombatSession
var player: CombatPlayer
var victims: Array[MeleeEnemy]


func before_each() -> void:
	session = Sandbox.instantiate() as CombatSession
	session.interactive = false
	add_child_autoqfree(session)
	await session.session_started
	player = session.local_player
	player.set_physics_process(false)
	victims = session.enemies.values()
	for index: int in range(victims.size()):
		victims[index].set_physics_process(false)
		victims[index].global_position = player.global_position + Vector3(index * 2.5, 0, -5)
		victims[index].health.current = 20.0 if index == 0 else 40.0
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_split_and_kill_explosion_compose_through_normal_damage_events() -> void:
	player.items.acquire(Split)
	player.items.acquire(Volatile)
	watch_signals(player.weapon)
	watch_signals(player.item_effects)
	watch_signals(victims[1].health)
	player.shoot()
	assert_signal_emit_count(player.weapon, "fired", 1)
	assert_signal_emit_count(player.weapon, "shot_created", 2)
	assert_eq(player.weapon.magazine, 11)
	assert_true(victims[0].health.is_dead)
	assert_true(victims[1].health.is_dead)
	assert_eq(victims[2].health.current, 40.0, "No recursive blast from the second victim")
	assert_eq(session.waves.remaining(), 1)
	assert_signal_emit_count(player.item_effects, "exploded", 1)
	var parameters: Array = get_signal_parameters(victims[1].health, "damaged")
	var damage: DamageContext = parameters[0]
	assert_eq(damage.source_player_id, player.player_id)
	assert_eq(damage.source_entity_id, player.get_instance_id())
	assert_eq(damage.source_weapon_id, session.weapon_definition.id)
	assert_eq(damage.amount, 45.0)
	assert_eq(damage.effect_depth, 1)
	assert_true(damage.tags.has("explosion"))
	assert_true(damage.tags.has("weapon"))


func test_explosion_works_without_multishot_and_secondary_kills_can_heal() -> void:
	player.items.acquire(Volatile)
	player.items.acquire(Vampiric)
	player.health.take_damage(DamageContext.new(8.0))
	player.shoot()
	assert_true(victims[1].health.is_dead)
	assert_eq(player.health.current, 100.0, "Both eligible kills heal, clamped to maximum")
	assert_eq(player.weapon.combat_stats().shot_count, 1)


func test_multishot_resolves_each_ray_independently_with_one_round_per_pull() -> void:
	player.items.acquire(Split)
	victims[1].global_position = player.global_position + Vector3(0, 0, -8)
	victims[1].health.current = 60.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.shoot()
	assert_true(victims[0].health.is_dead)
	assert_almost_eq(victims[1].health.current, 34.5, 0.0001)
	assert_eq(player.weapon.magazine, 11)
	assert_eq(player.weapon.reserve, 240)
	assert_eq(session.waves.remaining(), 2)


func test_generic_weapon_and_shot_triggers_are_distinct_and_owned() -> void:
	var item: ItemDefinition = ItemDefinition.new()
	item.id = &"test_event_healing"
	item.display_name = "Event fixture"
	item.description = "Heal on weapon and shot events"
	for kind: CombatEvent.Kind in [CombatEvent.Kind.WEAPON_FIRED, CombatEvent.Kind.SHOT_CREATED]:
		var trigger: ItemTrigger = ItemTrigger.new()
		trigger.event = kind
		trigger.condition = ItemCondition.new()
		trigger.condition.required_tags = ["weapon"]
		var effect: ItemEffect = ItemEffect.new()
		effect.amount = 2.0 if kind == CombatEvent.Kind.WEAPON_FIRED else 1.0
		trigger.effects = [effect]
		item.triggers.append(trigger)
	assert_true(player.items.acquire(item))
	player.items.acquire(Split)
	player.health.take_damage(DamageContext.new(10.0))
	player.camera.rotation.x = 1.0
	player.shoot()
	assert_eq(player.health.current, 94.0)


func test_non_weapon_kill_does_not_explode_or_heal() -> void:
	player.items.acquire(Volatile)
	player.items.acquire(Vampiric)
	player.health.take_damage(DamageContext.new(20.0))
	watch_signals(player.item_effects)
	victims[0].receive_damage(
		DamageContext.new(100.0, player.player_id, &"melee", &"melee", ["melee"])
	)
	assert_signal_not_emitted(player.item_effects, "exploded")
	assert_eq(victims[1].health.current, 40.0)
	assert_eq(player.health.current, 80.0)


func test_secondary_depth_blocks_explosion_even_if_tags_are_malformed() -> void:
	player.items.acquire(Volatile)
	watch_signals(player.item_effects)
	var damage: DamageContext = DamageContext.new(
		100.0, player.player_id, &"test", &"ballistic", ["hitscan", "weapon"]
	)
	damage.effect_depth = 1
	victims[0].receive_damage(damage)
	assert_signal_not_emitted(player.item_effects, "exploded")
	assert_eq(victims[1].health.current, 40.0)


func test_source_ownership_heals_only_the_correct_player() -> void:
	var other: CombatPlayer = session.player_scene.instantiate() as CombatPlayer
	other.player_id = 22
	session.actors.add_child(other)
	other.set_physics_process(false)
	other.global_position = Vector3(10, 0, 10)
	other.configure_weapons(session.weapon_definitions)
	other.item_effects.targets = session.damage_targets
	session.players.append(other)
	player.items.acquire(Vampiric)
	other.items.acquire(Vampiric)
	player.health.take_damage(DamageContext.new(20.0))
	other.health.take_damage(DamageContext.new(20.0))
	victims[0].receive_damage(
		DamageContext.new(100.0, 22, &"other_weapon", &"ballistic", ["weapon"])
	)
	assert_eq(player.health.current, 80.0)
	assert_eq(other.health.current, 85.0)
	assert_false(player.items.owns(Volatile.id))


func test_solid_arena_geometry_blocks_explosion_damage() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.2, 3, 2)
	collision.shape = shape
	wall.add_child(collision)
	session.actors.add_child(wall)
	wall.global_position = victims[0].global_position + Vector3(1.25, 1, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.items.acquire(Volatile)
	player.shoot()
	assert_true(victims[0].health.is_dead)
	assert_eq(victims[1].health.current, 40.0)

extends GutTest

const Sandbox: PackedScene = preload("res://content/rooms/combat_sandbox.tscn")
const Arc: ItemDefinition = preload("res://content/items/arc_conductor.tres")
const Bifurcation: ItemDefinition = preload("res://content/items/split_chamber.tres")
const Fragmentation: ItemDefinition = preload("res://content/items/fragmentation_core.tres")
const Heavy: ItemDefinition = preload("res://content/items/heavy_lead.tres")
const Recursive: ItemDefinition = preload("res://content/items/recursive_fault.tres")
const Replicator: ItemDefinition = preload("res://content/items/unstable_replicator.tres")
const Sentinel: ItemDefinition = preload("res://content/items/sentinel_node.tres")

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
		victims[index].global_position = player.global_position + Vector3(20 + index * 3, 0, 0)
		victims[index].health.current = 100.0


func test_arc_conductor_targets_unique_enemies_and_recursive_fault_repeats_once() -> void:
	var primary: MeleeEnemy = victims[0]
	primary.global_position = player.global_position + Vector3(0, 0, -5)
	for index: int in range(1, victims.size()):
		victims[index].global_position = primary.global_position + Vector3(index, 0, 0)
	var fourth: MeleeEnemy = await _spawn_victim(primary.global_position + Vector3(-1, 0, 0))
	player.items.run_random = RunRandom.new(_seed_for_success(0.12))
	player.item_effects.run_random = player.items.run_random
	assert_true(player.items.acquire(Recursive))
	assert_true(player.items.acquire(Arc))
	watch_signals(player.item_effects)
	for attack: int in range(1, 7):
		var context: DamageContext = _weapon_context(40.0, attack)
		player.items.handle_event(
			CombatEvent.new(
				CombatEvent.Kind.TARGET_DAMAGED,
				context,
				primary.global_position,
				primary.get_instance_id(),
				40.0
			)
		)
	assert_signal_emit_count(player.item_effects, "chained", 2)
	var first: Array = get_signal_parameters(player.item_effects, "chained", 0)
	var chain_context: DamageContext = first[0]
	var target_ids: Array[int] = first[1]
	assert_eq(target_ids.size(), 3)
	assert_eq(target_ids.size(), _unique_count(target_ids))
	assert_false(target_ids.has(primary.get_instance_id()))
	assert_true(target_ids.has(fourth.get_instance_id()) or target_ids.size() == 3)
	assert_eq(chain_context.amount, 10.0)
	assert_eq(chain_context.source_player_id, player.player_id)
	assert_eq(chain_context.source_entity_id, player.get_instance_id())
	assert_eq(chain_context.source_weapon_id, &"pistol")
	assert_eq(chain_context.damage_type, &"electrical")
	assert_false(chain_context.trigger_eligible)
	assert_false(chain_context.healing_eligible)
	var repeated: Array = get_signal_parameters(player.item_effects, "chained", 1)
	var repeated_context: DamageContext = repeated[0]
	assert_true(repeated_context.tags.has("recursive_repeat"))
	assert_eq(repeated_context.effect_depth, 2)


func test_fragmentation_uses_explosion_damage_and_never_recurses() -> void:
	var origin: MeleeEnemy = victims[0]
	origin.global_position = player.global_position + Vector3(0, 0, -5)
	origin.health.current = 0.0
	origin.health.is_dead = true
	for index: int in range(1, victims.size()):
		victims[index].global_position = origin.global_position + Vector3(index, 0, 0)
	var fourth: MeleeEnemy = await _spawn_victim(origin.global_position + Vector3(-1, 0, 0))
	var fifth: MeleeEnemy = await _spawn_victim(origin.global_position + Vector3(0, 0, 6))
	assert_true(player.items.acquire(Fragmentation))
	watch_signals(player.item_effects)
	var explosion: DamageContext = _weapon_context(45.0, 7).secondary(
		45.0, &"explosive", ["explosion"], true, true
	)
	player.items.handle_event(
		CombatEvent.new(
			CombatEvent.Kind.ENEMY_KILLED,
			explosion,
			origin.global_position,
			origin.get_instance_id(),
			45.0
		)
	)
	assert_signal_emit_count(player.item_effects, "fragmented", 1)
	var parameters: Array = get_signal_parameters(player.item_effects, "fragmented")
	var fragment: DamageContext = parameters[0]
	var hit_ids: Array[int] = parameters[1]
	assert_eq(hit_ids.size(), 3)
	assert_eq(hit_ids.size(), _unique_count(hit_ids))
	assert_false(hit_ids.has(origin.get_instance_id()))
	assert_false(hit_ids.has(fifth.get_instance_id()))
	assert_eq(fragment.amount, 9.0)
	assert_eq(fragment.source_player_id, player.player_id)
	assert_eq(fragment.source_entity_id, player.get_instance_id())
	assert_eq(fragment.source_weapon_id, &"pistol")
	assert_true(fragment.tags.has("fragment"))
	assert_false(fragment.trigger_eligible)
	assert_false(fragment.healing_eligible)
	player.items.handle_event(
		CombatEvent.new(
			CombatEvent.Kind.ENEMY_KILLED,
			fragment,
			fourth.global_position,
			fourth.get_instance_id(),
			fragment.amount
		)
	)
	assert_signal_emit_count(player.item_effects, "fragmented", 1)


func test_sentinel_uses_damage_modifier_once_and_preserves_owner() -> void:
	var target: MeleeEnemy = victims[0]
	target.global_position = player.global_position + Vector3(0, 0, -4)
	assert_true(player.items.acquire(Heavy))
	assert_true(player.items.acquire(Sentinel))
	var companion: AutonomousCompanion = (
		player.item_effects.get_node("AutonomousCompanion") as AutonomousCompanion
	)
	watch_signals(target.health)
	companion.cooldown = 0.0
	companion._physics_process(0.0)
	assert_almost_eq(target.health.current, 89.6, 0.0001)
	assert_signal_emit_count(target.health, "damaged", 1)
	var parameters: Array = get_signal_parameters(target.health, "damaged")
	var context: DamageContext = parameters[0]
	assert_almost_eq(context.amount, 10.4, 0.0001)
	assert_eq(context.source_player_id, player.player_id)
	assert_eq(context.source_entity_id, player.get_instance_id())
	assert_eq(context.source_weapon_id, &"")
	assert_eq(context.damage_type, &"companion")
	assert_false(context.is_primary)
	assert_false(context.trigger_eligible)
	assert_false(context.healing_eligible)


func test_replicator_combines_with_bifurcation_without_extra_ammunition() -> void:
	player.items.run_random = RunRandom.new(_seed_for_success(0.15))
	player.item_effects.run_random = player.items.run_random
	assert_true(player.items.acquire(Bifurcation))
	assert_true(player.items.acquire(Replicator))
	var shots: Array[DamageContext] = []
	player.weapon.shot_created.connect(
		func(context: DamageContext, _origin: Vector3) -> void: shots.append(context)
	)
	player.camera.rotation.x = 1.2
	assert_not_null(player.shoot())
	assert_eq(player.weapon.magazine, 11)
	assert_eq(shots.size(), 3)
	assert_eq(shots[0].attack_id, shots[2].attack_id)
	assert_almost_eq(shots[0].amount, 25.5, 0.0001)
	assert_almost_eq(shots[2].amount, 12.75, 0.0001)
	assert_true(shots[2].tags.has("replicated"))
	assert_false(shots[2].is_primary)
	assert_eq(shots[2].effect_depth, 1)


func _spawn_victim(position: Vector3) -> MeleeEnemy:
	var enemy: MeleeEnemy = session.spawn_enemy(session.enemy_scene, position)
	enemy.set_physics_process(false)
	enemy.health.current = 100.0
	await get_tree().physics_frame
	return enemy


func _weapon_context(amount: float, attack_id: int) -> DamageContext:
	return DamageContext.new(
		amount,
		player.player_id,
		&"pistol",
		&"ballistic",
		["hitscan", "weapon"],
		player.get_instance_id(),
		attack_id
	)


func _seed_for_success(chance: float) -> int:
	for seed: int in range(1, 10000):
		if RunRandom.new(seed).chance(chance):
			return seed
	fail_test("No deterministic success seed found")
	return 1


func _unique_count(values: Array[int]) -> int:
	var unique: Dictionary[int, bool] = {}
	for value: int in values:
		unique[value] = true
	return unique.size()

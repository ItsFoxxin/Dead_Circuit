extends GutTest

const Hemophage: ItemDefinition = preload("res://content/items/hemophage_implant.tres")
const Emergency: ItemDefinition = preload("res://content/items/emergency_reboot.tres")
const Kinetic: ItemDefinition = preload("res://content/items/kinetic_escalator.tres")
const Martyr: ItemDefinition = preload("res://content/items/martyrs_relay.tres")
const Neural: ItemDefinition = preload("res://content/items/neural_feedback.tres")
const Replicator: ItemDefinition = preload("res://content/items/unstable_replicator.tres")

var build: PlayerItemBuild
var health: HealthComponent
var runner: ItemEffectRunner


func before_each() -> void:
	build = PlayerItemBuild.new()
	build.player_id = 7
	build.run_random = RunRandom.new(12345)
	health = HealthComponent.new()
	add_child_autofree(health)
	runner = ItemEffectRunner.new()
	runner.player_id = 7
	runner.health = health
	runner.build = build
	runner.run_random = build.run_random
	add_child_autofree(runner)
	build.effect_requested.connect(runner.apply)


func test_hit_counter_counts_each_target_once_per_originating_attack() -> void:
	assert_true(build.acquire(Hemophage))
	health.take_damage(DamageContext.new(20.0))
	for target: int in range(1, 9):
		_emit_hit(1, target)
	assert_eq(health.current, 80.0)
	_emit_hit(1, 8)
	assert_eq(health.current, 80.0, "A repeated attack-target pair cannot double count")
	_emit_hit(1, 9)
	assert_eq(health.current, 82.0)


func test_kinetic_stacks_once_per_attack_and_expires() -> void:
	assert_true(build.acquire(Kinetic))
	_emit_hit(1, 10)
	_emit_hit(1, 11)
	assert_almost_eq(build.derive(&"damage", 100.0), 102.0, 0.0001)
	_emit_hit(2, 10)
	assert_almost_eq(build.derive(&"damage", 100.0), 104.0, 0.0001)
	build.advance(3.01)
	assert_almost_eq(build.derive(&"damage", 100.0), 100.0, 0.0001)


func test_neural_feedback_refreshes_without_stacking_and_cost_does_not_trigger_it() -> void:
	assert_true(build.acquire(Neural))
	assert_true(build.acquire(Martyr))
	var enemy_damage: DamageContext = DamageContext.new(5.0, -1, &"", &"melee", ["melee"])
	build.handle_event(
		CombatEvent.new(CombatEvent.Kind.PLAYER_DAMAGED, enemy_damage, Vector3.ZERO, 7, 0.0)
	)
	assert_almost_eq(build.derive(&"fire_rate", 10.0), 10.0, 0.0001)
	build.handle_event(
		CombatEvent.new(CombatEvent.Kind.PLAYER_DAMAGED, enemy_damage, Vector3.ZERO, 7, 5.0)
	)
	assert_almost_eq(build.derive(&"fire_rate", 10.0), 12.0, 0.0001)
	build.handle_event(
		CombatEvent.new(CombatEvent.Kind.PLAYER_DAMAGED, enemy_damage, Vector3.ZERO, 7, 5.0)
	)
	assert_almost_eq(build.derive(&"fire_rate", 10.0), 12.0, 0.0001)
	var ability: DamageContext = DamageContext.new(
		1.0, 7, &"pistol", &"ability", ["active_ability"]
	)
	build.handle_event(CombatEvent.new(CombatEvent.Kind.ACTIVE_ABILITY, ability, Vector3.ZERO))
	assert_eq(health.current, 90.0)
	assert_almost_eq(build.derive(&"damage", 100.0), 130.0, 0.0001)
	build.advance(4.01)
	assert_almost_eq(build.derive(&"fire_rate", 10.0), 10.0, 0.0001)
	assert_almost_eq(build.derive(&"damage", 100.0), 130.0, 0.0001)
	build.advance(2.01)
	assert_almost_eq(build.derive(&"damage", 100.0), 100.0, 0.0001)


func test_emergency_reboot_prevents_one_death_and_invulnerability_expires() -> void:
	assert_true(build.acquire(Emergency))
	watch_signals(health)
	var lethal: DamageContext = DamageContext.new(200.0)
	assert_eq(health.take_damage(lethal), 99.0)
	assert_eq(health.current, 1.0)
	assert_false(health.is_dead)
	assert_eq(health.lethal_protections, 0)
	assert_eq(health.take_damage(lethal), 0.0)
	assert_signal_emit_count(health, "lethal_prevented", 1)
	health.advance(3.01)
	assert_eq(health.take_damage(lethal), 1.0)
	assert_true(health.is_dead)


func test_health_spending_clamps_at_one_and_emits_no_damage_event() -> void:
	watch_signals(health)
	assert_eq(health.spend(150.0), 99.0)
	assert_eq(health.current, 1.0)
	assert_signal_not_emitted(health, "damaged")
	assert_eq(health.spend(10.0), 0.0)


func test_seeded_extra_ray_generation_reproduces_without_recursion() -> void:
	var first: Array[int] = _replication_sequence(31415)
	var second: Array[int] = _replication_sequence(31415)
	assert_eq(first, second)
	assert_true(first.has(1), "The deterministic sample should include at least one extra ray")
	assert_true(first.has(0), "The deterministic sample should include ordinary attacks")


func test_secondary_context_preserves_attack_and_explicit_eligibility() -> void:
	var primary: DamageContext = DamageContext.new(
		30.0, 7, &"pistol", &"ballistic", ["weapon"], 99, 42
	)
	var secondary: DamageContext = primary.secondary(12.0, &"electrical", ["chain"], false, false)
	assert_eq(secondary.attack_id, 42)
	assert_false(secondary.is_primary)
	assert_false(secondary.trigger_eligible)
	assert_false(secondary.healing_eligible)
	assert_eq(secondary.source_player_id, 7)
	assert_eq(secondary.source_entity_id, 99)
	assert_eq(secondary.source_weapon_id, &"pistol")


func _emit_hit(attack_id: int, target_id: int) -> void:
	var context: DamageContext = DamageContext.new(
		10.0, 7, &"pistol", &"ballistic", ["hitscan", "weapon"], 99, attack_id
	)
	build.handle_event(
		CombatEvent.new(CombatEvent.Kind.TARGET_DAMAGED, context, Vector3.ZERO, target_id, 10.0)
	)


func _replication_sequence(seed: int) -> Array[int]:
	var test_build: PlayerItemBuild = PlayerItemBuild.new()
	test_build.player_id = 7
	test_build.run_random = RunRandom.new(seed)
	assert_true(test_build.acquire(Replicator))
	var result: Array[int] = []
	for attack_id: int in range(80):
		var context: DamageContext = DamageContext.new(
			10.0, 7, &"pistol", &"ballistic", ["hitscan", "weapon"], 99, attack_id
		)
		result.append(test_build.extra_ray_scales(context).size())
	return result

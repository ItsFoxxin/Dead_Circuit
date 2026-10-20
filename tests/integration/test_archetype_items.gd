extends GutTest

const PlayerScene: PackedScene = preload("res://game/player/player.tscn")
const EnemyScene: PackedScene = preload("res://content/enemies/basic_zombie.tscn")
const Pistol: WeaponDefinition = preload("res://content/weapons/prototype_pistol.tres")
const Smg: WeaponDefinition = preload("res://content/weapons/relay_smg.tres")
const Shotgun: WeaponDefinition = preload("res://content/weapons/scatterline_shotgun.tres")
const Heavy: ItemDefinition = preload("res://content/items/heavy_lead.tres")
const Rapid: ItemDefinition = preload("res://content/items/rapid_mechanism.tres")
const Split: ItemDefinition = preload("res://content/items/split_chamber.tres")
const Volatile: ItemDefinition = preload("res://content/items/volatile_rounds.tres")
const Vampiric: ItemDefinition = preload("res://content/items/vampiric_ammo.tres")

var world: Node3D
var player: CombatPlayer
var targets: Array[DamageableBody] = []
var explosion_count: int = 0
var last_damage: DamageContext


func before_each() -> void:
	targets.clear()
	world = Node3D.new()
	add_child(world)
	player = PlayerScene.instantiate() as CombatPlayer
	player.player_id = 1
	world.add_child(player)
	player.configure_weapons([Pistol, Smg, Shotgun])
	player.item_effects.targets = targets
	player.item_effects.exploded.connect(_on_exploded)
	player.local_input_enabled = false
	player.set_physics_process(false)
	await get_tree().physics_frame


func after_each() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame


func test_all_weapon_archetypes_share_item_stats_without_weapon_id_rules() -> void:
	player.items.acquire(Heavy)
	player.items.acquire(Rapid)
	player.items.acquire(Split)
	for controller: WeaponController in player.weapons.controllers:
		var stats: WeaponStats = controller.combat_stats()
		assert_almost_eq(stats.damage, controller.definition.damage * 1.3, 0.0001)
		assert_almost_eq(
			stats.fire_rate, controller.definition.shots_per_second * 0.9 * 1.25, 0.0001
		)
		assert_eq(stats.shot_count, controller.definition.base_shot_count + 1)
		assert_almost_eq(stats.shot_damage_scale, 0.85, 0.0001)


func test_all_weapon_archetypes_trigger_owned_kill_effects() -> void:
	player.items.acquire(Volatile)
	player.items.acquire(Vampiric)
	player.health.take_damage(DamageContext.new(40.0))
	explosion_count = 0
	for index: int in range(player.weapons.controllers.size()):
		var enemy: MeleeEnemy = await _spawn_target()
		if index != player.weapons.equipped_index:
			assert_true(player.switch_weapon(index))
		last_damage = null
		assert_not_null(player.shoot())
		assert_true(enemy.health.is_dead)
		assert_not_null(last_damage)
		assert_eq(last_damage.source_weapon_id, player.weapon.definition.id)
		assert_eq(last_damage.source_player_id, player.player_id)
		player.weapon.advance(1.0)
		await get_tree().process_frame
	assert_eq(player.health.current, 75.0)
	assert_eq(explosion_count, 3)


func _spawn_target() -> MeleeEnemy:
	var enemy: MeleeEnemy = EnemyScene.instantiate() as MeleeEnemy
	enemy.players.append(player)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + Vector3(0, 0, -5)
	enemy.health.current = 1.0
	targets.append(enemy)
	enemy.health.damaged.connect(_on_target_damaged)
	enemy.removed_from_combat.connect(_on_enemy_removed.bind(enemy))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return enemy


func _on_enemy_removed(entity_id: int, context: DamageContext, enemy: MeleeEnemy) -> void:
	player.items.handle_event(
		CombatEvent.new(CombatEvent.Kind.ENEMY_KILLED, context, enemy.global_position, entity_id)
	)
	targets.erase(enemy)


func _on_target_damaged(context: DamageContext, _applied: float) -> void:
	last_damage = context


func _on_exploded(_context: DamageContext, _position: Vector3, _radius: float) -> void:
	explosion_count += 1

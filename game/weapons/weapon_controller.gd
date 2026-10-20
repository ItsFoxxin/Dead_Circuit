class_name WeaponController
extends Node
## Mutable ammunition/timers belong to this owner, never the shared definition.

signal changed
signal fired(context: DamageContext)
signal shot_created(context: DamageContext, origin: Vector3)

var definition: WeaponDefinition
var items: PlayerItemBuild
var source_player_id: int = -1
var magazine: int = 0
var reserve: int = 0
var fire_remaining: float = 0.0
var reload_remaining: float = 0.0
var reloading: bool = false
var enabled: bool = true


func configure(config: WeaponDefinition, player_id: int, build: PlayerItemBuild = null) -> void:
	definition = config
	items = build
	source_player_id = player_id
	reset()


func reset() -> void:
	magazine = definition.magazine_capacity
	reserve = definition.starting_reserve
	fire_remaining = 0.0
	reload_remaining = 0.0
	reloading = false
	enabled = true
	changed.emit()


func advance(delta: float) -> void:
	if not enabled:
		return
	fire_remaining = maxf(0.0, fire_remaining - delta)
	if reloading:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining == 0.0:
			var transferred: int = mini(definition.magazine_capacity - magazine, reserve)
			magazine += transferred
			reserve -= transferred
			reloading = false
			changed.emit()


func begin_reload() -> bool:
	if not enabled or reloading or reserve == 0 or magazine == definition.magazine_capacity:
		return false
	reloading = true
	reload_remaining = definition.reload_seconds
	changed.emit()
	return true


func try_fire(entity_id: int = 0) -> DamageContext:
	if not enabled or reloading or magazine <= 0 or fire_remaining > 0.0:
		return null
	magazine -= 1
	var stats: WeaponStats = combat_stats()
	fire_remaining = 1.0 / stats.fire_rate
	var context: DamageContext = DamageContext.new(
		stats.damage * stats.shot_damage_scale,
		source_player_id,
		definition.id,
		&"ballistic",
		definition.damage_tags,
		entity_id
	)
	if not context.tags.has("weapon"):
		context.tags.append("weapon")
	changed.emit()
	fired.emit(context)
	return context


func fire_hitscan(
	world: World3D, origin: Vector3, direction: Vector3, excluded: RID, entity_id: int = 0
) -> DamageContext:
	var count: int = combat_stats().shot_count
	var context: DamageContext = try_fire(entity_id)
	if context == null:
		return null
	for index: int in range(count):
		var shot: DamageContext = DamageContext.new(
			context.amount,
			source_player_id,
			definition.id,
			context.damage_type,
			context.tags,
			entity_id
		)
		shot_created.emit(shot, origin)
		var angle: float = 0.0
		if count > 1:
			var fraction: float = float(index) / float(count - 1)
			angle = deg_to_rad(
				lerpf(-definition.spread_degrees, definition.spread_degrees, fraction)
			)
		var ray: Vector3 = direction.normalized().rotated(Vector3.UP, angle)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + ray * definition.range_metres, 7, [excluded]
		)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		var collider: Variant = hit.get("collider")
		if collider is DamageableBody:
			var body: DamageableBody = collider
			body.receive_damage(shot)
	return context


func combat_stats() -> WeaponStats:
	var stats: WeaponStats = WeaponStats.new()
	stats.damage = definition.damage
	stats.fire_rate = definition.shots_per_second
	if items != null:
		stats.damage = maxf(0.001, items.derive(&"damage", stats.damage))
		stats.fire_rate = maxf(0.001, items.derive(&"fire_rate", stats.fire_rate))
	stats.shot_count = definition.base_shot_count
	if items != null:
		stats.shot_count = maxi(
			1, roundi(items.derive(&"shot_count", float(definition.base_shot_count)))
		)
		stats.shot_damage_scale = maxf(0.001, items.derive(&"shot_damage_scale", 1.0))
	return stats

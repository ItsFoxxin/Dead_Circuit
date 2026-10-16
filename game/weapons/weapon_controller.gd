class_name WeaponController
extends Node
## Mutable ammunition/timers belong to this owner, never the shared definition.

signal changed
signal fired(context: DamageContext)

var definition: WeaponDefinition
var source_player_id: int = -1
var magazine: int = 0
var reserve: int = 0
var fire_remaining: float = 0.0
var reload_remaining: float = 0.0
var reloading: bool = false
var enabled: bool = true


func configure(config: WeaponDefinition, player_id: int) -> void:
	definition = config
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
	fire_remaining = 1.0 / definition.shots_per_second
	var context: DamageContext = DamageContext.new(
		definition.damage,
		source_player_id,
		definition.id,
		&"ballistic",
		definition.damage_tags,
		entity_id
	)
	changed.emit()
	fired.emit(context)
	return context


func fire_hitscan(
	world: World3D, origin: Vector3, direction: Vector3, excluded: RID, entity_id: int = 0
) -> DamageContext:
	var context: DamageContext = try_fire(entity_id)
	if context == null:
		return null
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction.normalized() * definition.range_metres, 7, [excluded]
	)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Variant = hit.get("collider")
	if collider is DamageableBody:
		var body: DamageableBody = collider
		body.receive_damage(context)
	return context

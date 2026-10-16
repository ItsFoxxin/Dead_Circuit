class_name RoomSupplyPickup
extends Area3D
## A room-scoped supply can be claimed once by a living authorized participant.

signal collected(player_id: int, kind: ClearDropDefinition.Kind, amount: float, room_id: StringName)

var definition: ClearDropDefinition
var kind: ClearDropDefinition.Kind = ClearDropDefinition.Kind.HEALTH
var room_id: StringName
var can_collect: Callable
var consumed: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.9
	collider.shape = shape
	add_child(collider)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	visual.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = (
		Color(0.95, 0.2, 0.2) if kind == ClearDropDefinition.Kind.HEALTH else Color(0.2, 0.6, 1.0)
	)
	visual.material_override = material
	add_child(visual)
	var label: Label3D = Label3D.new()
	label.position.y = 0.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = (
		"HP +%d" % definition.health_amount
		if kind == ClearDropDefinition.Kind.HEALTH
		else "Ammo +%d" % definition.ammunition
	)
	add_child(label)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is CombatPlayer:
		collect(body as CombatPlayer)


func collect(player: CombatPlayer) -> bool:
	if (
		consumed
		or not is_instance_valid(player)
		or player.health.is_dead
		or not player.combat_enabled
		or not can_collect.is_valid()
		or not can_collect.call(player)
		or global_position.distance_to(player.global_position + Vector3.UP * 0.5) > 1.8
	):
		return false
	if kind == ClearDropDefinition.Kind.HEALTH and player.health.current >= player.health.maximum:
		return false
	consumed = true
	var amount: float = definition.ammunition
	if kind == ClearDropDefinition.Kind.HEALTH:
		amount = player.health.heal(definition.health_amount)
	else:
		player.weapon.reserve += definition.ammunition
		player.weapon.changed.emit()
	collected.emit(player.player_id, kind, amount, room_id)
	queue_free()
	return true

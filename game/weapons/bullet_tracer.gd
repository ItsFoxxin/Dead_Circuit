class_name BulletTracer
extends MeshInstance3D
## Short-lived visual for an authoritative hitscan ray. It has no collision or damage.

const CAMERA_CLEARANCE_METRES: float = 0.65

var source_player_id: int = -1
var source_weapon_id: StringName
var ray_origin: Vector3
var ray_endpoint: Vector3


func configure(
	context: DamageContext,
	origin: Vector3,
	endpoint: Vector3,
	color: Color,
	width: float,
	lifetime: float
) -> void:
	source_player_id = context.source_player_id
	source_weapon_id = context.source_weapon_id
	ray_origin = origin
	ray_endpoint = endpoint
	add_to_group("bullet_tracers")

	var full_segment: Vector3 = endpoint - origin
	var full_length: float = full_segment.length()
	if full_length <= 0.001:
		queue_free()
		return
	var direction: Vector3 = full_segment / full_length
	var clearance: float = minf(CAMERA_CLEARANCE_METRES, full_length * 0.25)
	var visual_origin: Vector3 = origin + direction * clearance
	var visible_length: float = visual_origin.distance_to(endpoint)

	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = visible_length
	cylinder.top_radius = width
	cylinder.bottom_radius = width
	cylinder.radial_segments = 6
	cylinder.rings = 1
	mesh = cylinder

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_position = (visual_origin + endpoint) * 0.5
	global_basis = Basis(Quaternion(Vector3.UP, direction))

	get_tree().create_timer(lifetime).timeout.connect(queue_free)

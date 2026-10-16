class_name ExplosionPulse
extends MeshInstance3D
## Short primitive development feedback; no gameplay state or production FX.

var remaining: float = 0.2


func show_at(location: Vector3, radius: float) -> void:
	top_level = true
	global_position = location
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.45, 0.1, 0.2)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()

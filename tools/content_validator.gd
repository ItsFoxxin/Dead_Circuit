class_name ContentValidator
extends RefCounted
## Schema implementations will be registered here as content types are introduced.

const CONTENT_DIRECTORIES: PackedStringArray = [
	"items", "weapons", "enemies", "bosses", "rooms", "loot_tables"
]
var definition_count: int = 0
var ids: Dictionary[StringName, String] = {}


func validate(root_path: String = "res://content") -> PackedStringArray:
	var errors: PackedStringArray = []
	definition_count = 0
	ids.clear()
	for directory: String in CONTENT_DIRECTORIES:
		var path: String = root_path.path_join(directory)
		if not DirAccess.dir_exists_absolute(path):
			errors.append("Missing content directory: " + path)
	if DirAccess.dir_exists_absolute(root_path):
		_scan(root_path, errors)
	return errors


func _scan(path: String, errors: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		errors.append("Cannot open content directory: " + path)
		return
	var entries: PackedStringArray = directory.get_files()
	entries.sort()
	for entry: String in entries:
		if entry == ".gitkeep":
			continue
		var file_path: String = path.path_join(entry)
		if entry.get_extension() == "tres":
			_validate_definition(file_path, errors)
		elif entry.get_extension() == "tscn":
			_validate_scene(file_path, errors)
		else:
			errors.append("No registered content schema for: " + file_path)
	var children: PackedStringArray = directory.get_directories()
	children.sort()
	for child: String in children:
		_scan(path.path_join(child), errors)


func _validate_definition(path: String, errors: PackedStringArray) -> void:
	var resource: Resource = load(path)
	var id: StringName
	if resource is WeaponDefinition and "/weapons/" in path:
		var weapon: WeaponDefinition = resource
		id = weapon.id
		errors.append_array(weapon.validation_errors())
	elif resource is EnemyDefinition and "/enemies/" in path:
		var enemy: EnemyDefinition = resource
		id = enemy.id
		errors.append_array(enemy.validation_errors())
	elif resource is WaveDefinition and "/rooms/" in path:
		var waves: WaveDefinition = resource
		id = waves.id
		errors.append_array(waves.validation_errors())
		if waves.counts.size() != 5:
			errors.append("Combat Sandbox content requires exactly five waves: " + path)
		for index: int in range(1, waves.counts.size()):
			if waves.counts[index] <= waves.counts[index - 1]:
				errors.append("Prototype waves must increase: " + path)
	else:
		errors.append("No registered content schema for: " + path)
		return
	if ids.has(id):
		errors.append("Duplicate content id %s: %s and %s" % [id, ids[id], path])
	ids[id] = path
	definition_count += 1


func _validate_scene(path: String, errors: PackedStringArray) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		errors.append("Cannot load content scene: " + path)
		return
	var root: Node = packed.instantiate()
	if root is MeleeEnemy and "/enemies/" in path:
		var enemy: MeleeEnemy = root
		if enemy.definition == null or not root.get_node_or_null("Health") is HealthComponent:
			errors.append("Enemy scene requires definition and health: " + path)
		if not root.get_node_or_null("Navigation") is NavigationAgent3D:
			errors.append("Enemy scene requires navigation: " + path)
	elif root is CombatArena and "/rooms/" in path:
		_validate_arena(root, path, errors)
	elif root is CombatSession and "/rooms/" in path:
		var session: CombatSession = root
		if session.player_scene == null or session.enemy_scene == null:
			errors.append("Sandbox requires actor scene references: " + path)
		if session.weapon_definition == null or session.wave_definition == null:
			errors.append("Sandbox requires weapon and wave definitions: " + path)
		if not session.get_node_or_null("Arena") is CombatArena:
			errors.append("Sandbox requires an authored combat arena: " + path)
	else:
		errors.append("No registered content schema for: " + path)
	root.free()


func _validate_arena(root: Node, path: String, errors: PackedStringArray) -> void:
	var region: NavigationRegion3D = root.get_node_or_null("NavigationRegion") as NavigationRegion3D
	if region == null or region.navigation_mesh == null:
		errors.append("Arena requires navigation mesh: " + path)
	elif region.navigation_mesh.get_polygon_count() == 0:
		errors.append("Arena navigation mesh is empty: " + path)
	if not root.get_node_or_null("PlayerSpawn") is Marker3D:
		errors.append("Arena requires a player spawn: " + path)
	var spawns: Node = root.get_node_or_null("EnemySpawns")
	if spawns == null or spawns.get_child_count() < 12:
		errors.append("Prototype arena requires twelve enemy spawn points: " + path)
	for boundary: String in ["Floor", "NorthWall", "SouthWall", "EastWall", "WestWall"]:
		if not root.get_node_or_null(boundary) is StaticBody3D:
			errors.append("Arena missing collision boundary %s: %s" % [boundary, path])

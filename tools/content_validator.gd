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
	elif resource is BossDefinition and "/bosses/" in path:
		var boss: BossDefinition = resource
		id = boss.id
		errors.append_array(boss.validation_errors())
	elif resource is ClearDropDefinition and "/loot_tables/" in path:
		var drop: ClearDropDefinition = resource
		id = drop.id
		errors.append_array(drop.validation_errors())
	elif resource is EnemyDefinition and not resource is BossDefinition and "/enemies/" in path:
		var enemy: EnemyDefinition = resource
		id = enemy.id
		errors.append_array(enemy.validation_errors())
	elif resource is ItemDefinition and "/items/" in path:
		var item: ItemDefinition = resource
		id = item.id
		errors.append_array(item.validation_errors())
	elif resource is RoomDefinition and "/rooms/" in path:
		var room: RoomDefinition = resource
		id = room.id
		errors.append_array(room.validation_errors())
		if room.scene != null:
			var scene: Node = room.scene.instantiate()
			if not scene is CombatArena:
				errors.append("Room scene requires a CombatArena root: " + path)
			elif not scene.get_node_or_null("Exit") is Marker3D:
				errors.append("Room scene requires an exit marker: " + path)
			if room.boss_scene != null and not scene.get_node_or_null("BossSpawn") is Marker3D:
				errors.append("Boss room requires a boss spawn: " + path)
			scene.free()
		if room.boss_scene != null:
			var actor: Node = room.boss_scene.instantiate()
			if not actor is BossEnemy:
				errors.append("Boss room requires a BossEnemy scene: " + path)
			actor.free()
	elif resource is RunDefinition and "/rooms/" in path:
		var run: RunDefinition = resource
		id = run.id
		errors.append_array(run.validation_errors())
		var kinds: Array[int] = []
		for room: RoomDefinition in run.rooms:
			if room != null:
				kinds.append(room.kind)
				if not room.resource_path.begins_with("res://content/rooms/"):
					errors.append("Run must reference authored room definitions: " + path)
		if kinds != [0, 1, 2, 3]:
			errors.append("Prototype route requires start, combat, treasure, boss order: " + path)
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
	if root is BossEnemy and "/bosses/" in path:
		var boss: BossEnemy = root
		if not boss.definition is BossDefinition:
			errors.append("Boss scene requires a BossDefinition: " + path)
		if not root.get_node_or_null("Health") is HealthComponent:
			errors.append("Boss scene requires health: " + path)
		if not root.get_node_or_null("Navigation") is NavigationAgent3D:
			errors.append("Boss scene requires navigation: " + path)
		if not root.get_node_or_null("Telegraph") is MeshInstance3D:
			errors.append("Boss scene requires an attack telegraph: " + path)
	elif root is MeleeEnemy and not root is BossEnemy and "/enemies/" in path:
		var enemy: MeleeEnemy = root
		if enemy.definition == null or not root.get_node_or_null("Health") is HealthComponent:
			errors.append("Enemy scene requires definition and health: " + path)
		if not root.get_node_or_null("Navigation") is NavigationAgent3D:
			errors.append("Enemy scene requires navigation: " + path)
	elif root is CombatArena and "/rooms/" in path:
		_validate_arena(root, path, errors)
	elif root is RoomRunSession and "/rooms/" in path:
		var run: RoomRunSession = root
		if run.definition == null or run.combat_scene == null:
			errors.append("Room run requires route and combat scene references: " + path)
		if run.run_seed < 0 or run.run_seed > RunRandom.MAX_SEED:
			errors.append("Room run seed must be from 0 to 2147483647: " + path)
		if not run.get_node_or_null("HUD/RoomStatus") is Label:
			errors.append("Room run requires status HUD: " + path)
		if not run.get_node_or_null("HUD/ExitHint") is Label:
			errors.append("Room run requires exit hint HUD: " + path)
		if run.clear_drops != null:
			errors.append_array(run.clear_drops.validation_errors())
			if not run.clear_drops.resource_path.begins_with("res://content/loot_tables/"):
				errors.append("Room supplies must reference an authored drop definition: " + path)
		_validate_room_run(run, path, errors)
	elif root is CombatSession and "/rooms/" in path:
		var session: CombatSession = root
		if session.player_scene == null or session.enemy_scene == null:
			errors.append("Sandbox requires actor scene references: " + path)
		if session.weapon_definition == null or session.wave_definition == null:
			errors.append("Sandbox requires weapon and wave definitions: " + path)
		if session.run_seed < 0 or session.run_seed > RunRandom.MAX_SEED:
			errors.append("Sandbox seed must be from 0 to 2147483647: " + path)
		if not session.get_node_or_null("Arena") is CombatArena:
			errors.append("Sandbox requires an authored combat arena: " + path)
		_validate_item_catalog(session.item_catalog, path, errors)
	else:
		errors.append("No registered content schema for: " + path)
	root.free()


func _validate_room_run(run: RoomRunSession, path: String, errors: PackedStringArray) -> void:
	if run.definition == null:
		return
	for room: RoomDefinition in run.definition.rooms:
		if room == null:
			continue
		if (
			run.clear_drops != null
			and room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS]
			and room.scene != null
		):
			var arena: Node = room.scene.instantiate()
			if not arena.get_node_or_null("SupplySpawn") is Marker3D:
				errors.append("Clear-supply rooms require an authored supply spawn: " + path)
			arena.free()
		if room.boss_scene == null:
			continue
		if run.wave_rewards_enabled:
			errors.append("First-boss route cannot grant per-wave items: " + path)
		if run.clear_drops == null:
			errors.append("First-boss route requires clear-supply configuration: " + path)
		if not run.get_node_or_null("HUD/BossStatus") is Label:
			errors.append("Boss route requires health/state HUD: " + path)


func _validate_item_catalog(
	catalog: Array[ItemDefinition], path: String, errors: PackedStringArray
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	if catalog.size() != 5:
		errors.append("Prototype sandbox requires five items: " + path)
	for item: ItemDefinition in catalog:
		if item == null:
			errors.append("Null catalog item: " + path)
		elif seen.has(item.id):
			errors.append("Duplicate catalog item: " + str(item.id))
		else:
			seen[item.id] = true
			errors.append_array(item.validation_errors())
			if not item.resource_path.begins_with("res://content/items/"):
				errors.append("Catalog must reference authored item definitions: " + path)


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

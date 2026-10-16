class_name ContentValidator
extends RefCounted
## Schema implementations will be registered here as content types are introduced.

const CONTENT_DIRECTORIES: PackedStringArray = [
	"items", "weapons", "enemies", "bosses", "rooms", "loot_tables"
]


func validate(root_path: String = "res://content") -> PackedStringArray:
	var errors: PackedStringArray = []
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
		# Fail closed: no gameplay content schemas exist in Phase 0.
		errors.append("No registered content schema for: " + path.path_join(entry))
	var children: PackedStringArray = directory.get_directories()
	children.sort()
	for child: String in children:
		_scan(path.path_join(child), errors)

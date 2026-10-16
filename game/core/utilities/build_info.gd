class_name BuildInfo
extends RefCounted
## Read-only build provenance, generated before validation and export.

const METADATA_PATH: String = "res://game/core/utilities/build_metadata.json"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func metadata() -> Dictionary:
	if not FileAccess.file_exists(METADATA_PATH):
		return {"version": version(), "build_type": "local", "commit_sha": "unknown"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METADATA_PATH))
	if parsed is Dictionary:
		return parsed
	return {}

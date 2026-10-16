extends GutTest

const Info = preload("res://game/core/utilities/build_info.gd")


func test_version_matches_project() -> void:
	assert_eq(Info.version(), str(ProjectSettings.get_setting("application/config/version")))


func test_build_provenance_is_present() -> void:
	var metadata: Dictionary = Info.metadata()
	for key: String in ["version", "commit_sha", "branch", "engine_version", "build_id"]:
		assert_true(metadata.has(key), "Missing provenance field: %s" % key)
	assert_eq(str(metadata.get("version")), Info.version())

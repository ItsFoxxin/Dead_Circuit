extends GutTest

const Validator = preload("res://tools/content_validator.gd")
const ROOT: String = "user://content_validator_test"


func before_each() -> void:
	for directory: String in Validator.CONTENT_DIRECTORIES:
		DirAccess.make_dir_recursive_absolute(ROOT.path_join(directory))


func after_each() -> void:
	var unexpected: String = ROOT.path_join("items/unregistered.json")
	if FileAccess.file_exists(unexpected):
		DirAccess.remove_absolute(unexpected)
	for directory: String in Validator.CONTENT_DIRECTORIES:
		DirAccess.remove_absolute(ROOT.path_join(directory))
	DirAccess.remove_absolute(ROOT)


func test_empty_content_tree_is_valid() -> void:
	assert_eq(Validator.new().validate(ROOT).size(), 0)


func test_unregistered_content_fails_closed() -> void:
	var file: FileAccess = FileAccess.open(
		ROOT.path_join("items/unregistered.json"), FileAccess.WRITE
	)
	file.store_string("{}")
	file.close()
	var errors: PackedStringArray = Validator.new().validate(ROOT)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "No registered content schema")


func test_missing_content_directory_is_reported() -> void:
	DirAccess.remove_absolute(ROOT.path_join("bosses"))
	assert_eq(Validator.new().validate(ROOT).size(), 1)

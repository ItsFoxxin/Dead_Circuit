extends SceneTree

const Validator = preload("res://tools/content_validator.gd")


func _initialize() -> void:
	var validator: ContentValidator = Validator.new()
	var errors: PackedStringArray = validator.validate()
	for message: String in errors:
		printerr(message)
	if errors.is_empty():
		print("CONTENT_VALIDATION_OK definitions=%d" % validator.definition_count)
	quit(0 if errors.is_empty() else 1)

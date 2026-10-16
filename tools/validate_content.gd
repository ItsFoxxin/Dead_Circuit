extends SceneTree

const Validator = preload("res://tools/content_validator.gd")


func _initialize() -> void:
	var errors: PackedStringArray = Validator.new().validate()
	for message: String in errors:
		printerr(message)
	if errors.is_empty():
		print("CONTENT_VALIDATION_OK schemas=0 definitions=0")
	quit(0 if errors.is_empty() else 1)

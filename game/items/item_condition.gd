class_name ItemCondition
extends Resource

@export var required_tags: PackedStringArray = []
@export var excluded_tags: PackedStringArray = []


func matches(context: DamageContext) -> bool:
	if context == null:
		return false
	for tag: String in required_tags:
		if not context.tags.has(tag):
			return false
	for tag: String in excluded_tags:
		if context.tags.has(tag):
			return false
	return true


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for tag: String in required_tags:
		if tag.is_empty() or excluded_tags.has(tag):
			errors.append("Condition has empty or contradictory tags")
	for tag: String in excluded_tags:
		if tag.is_empty():
			errors.append("Condition has empty excluded tag")
	return errors

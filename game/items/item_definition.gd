class_name ItemDefinition
extends Resource
## Read-only content. Acquisition state and derived values live on each player.

@export var id: StringName
@export var display_name: String
@export var description: String
@export_multiline var flavor_text: String
@export var faction: ItemFaction
@export var classification: StringName = &"prototype"
@export var tags: PackedStringArray = []
@export var stacking: StringName = &"unique"
@export var modifiers: Array[StatModifier] = []
@export var triggers: Array[ItemTrigger] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if (
		id.is_empty()
		or display_name.is_empty()
		or description.is_empty()
		or flavor_text.strip_edges().is_empty()
		or faction == null
		or classification.is_empty()
	):
		errors.append("Item requires id, name, description, flavor, faction and classification")
	if faction != null:
		errors.append_array(faction.validation_errors())
	if stacking != &"unique":
		errors.append("Only explicit unique item stacking is supported")
	if modifiers.is_empty() and triggers.is_empty():
		errors.append("Item requires modifiers or triggers")
	for modifier: StatModifier in modifiers:
		if modifier == null:
			errors.append("Null modifier")
		else:
			errors.append_array(modifier.validation_errors())
	for trigger: ItemTrigger in triggers:
		if trigger == null:
			errors.append("Null trigger")
		else:
			errors.append_array(trigger.validation_errors())
	return errors

class_name ItemFaction
extends Resource
## Descriptive item provenance. Factions never restrict acquisition or composition.

@export var id: StringName
@export var display_name: String
@export_multiline var philosophy: String
@export_multiline var specialty: String
@export_multiline var mechanical_identity: String


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if (
		id.is_empty()
		or display_name.strip_edges().is_empty()
		or philosophy.strip_edges().is_empty()
		or specialty.strip_edges().is_empty()
		or mechanical_identity.strip_edges().is_empty()
	):
		errors.append("Faction requires id, name, philosophy, specialty and mechanical identity")
	return errors

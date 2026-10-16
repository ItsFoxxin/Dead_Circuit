class_name Bootstrap
extends Control
## Phase 0 launch surface. No run, player, gameplay authority, or networking state.

const BuildInfo = preload("res://game/core/utilities/build_info.gd")

@onready var status_label: Label = %Status


func _ready() -> void:
	status_label.text = "Dead Circuit %s\nDevelopment foundation ready" % BuildInfo.version()
	if "--smoke" in OS.get_cmdline_user_args():
		var provenance: Dictionary = BuildInfo.metadata()
		if (
			not provenance.has("engine_version")
			or str(provenance.get("commit_sha", "")).length() != 40
		):
			printerr("ERROR: Missing build provenance in launch smoke")
			get_tree().quit(1)
			return
		print("DEAD_CIRCUIT_READY version=%s" % BuildInfo.version())
		get_tree().quit(0)

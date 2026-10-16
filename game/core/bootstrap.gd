class_name Bootstrap
extends Node
## Composition boundary. The entry scene supplies concrete sandbox content.

const BuildInfo = preload("res://game/core/utilities/build_info.gd")

@export var startup_scene: PackedScene
var session: CombatSession


func _ready() -> void:
	session = startup_scene.instantiate() as CombatSession
	add_child(session)
	if "--smoke" in OS.get_cmdline_user_args():
		await session.session_started
		var provenance: Dictionary = BuildInfo.metadata()
		if (
			not provenance.has("engine_version")
			or str(provenance.get("commit_sha", "")).length() != 40
			or session.local_player == null
			or session.waves.wave_number != 1
			or session.waves.remaining() != session.wave_definition.counts[0]
			or session.item_catalog.size() != 5
			or session.local_player.items.player_id != session.local_player.player_id
			or not session.local_player.items.definitions().is_empty()
		):
			printerr("ERROR: Combat sandbox smoke initialization failed")
			get_tree().quit(1)
			return
		print(
			(
				"DEAD_CIRCUIT_READY version=%s player=%d wave=1 enemies=%d"
				% [BuildInfo.version(), session.local_player.player_id, session.waves.remaining()]
			)
		)
		get_tree().quit(0)

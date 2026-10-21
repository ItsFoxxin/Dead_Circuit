class_name RoomBootstrap
extends Node
## New room-run composition boundary; the original combat bootstrap remains usable.

const BuildInfo = preload("res://game/core/utilities/build_info.gd")
const DeveloperConsoleScene: PackedScene = preload("res://game/dev/developer_console.tscn")

@export var startup_scene: PackedScene
var run: RoomRunSession
var developer_console: DeveloperConsole


func _ready() -> void:
	run = startup_scene.instantiate() as RoomRunSession
	run.run_seed = RunRandom.seed_from_arguments(OS.get_cmdline_user_args(), run.run_seed)
	if run.run_seed < 0:
		printerr("ERROR: Expected one --seed=<integer from 0 to 2147483647>")
		run.free()
		get_tree().quit(1)
		return
	add_child(run)
	if _development_console_enabled():
		developer_console = DeveloperConsoleScene.instantiate() as DeveloperConsole
		add_child(developer_console)
		developer_console.configure(run)
	if "--smoke" in OS.get_cmdline_user_args():
		await run.run_started
		var provenance: Dictionary = BuildInfo.metadata()
		if (
			not provenance.has("engine_version")
			or str(provenance.get("commit_sha", "")).length() != 40
			or run.combat.local_player == null
			or run.progress.current_room().kind != RoomDefinition.Kind.START
			or run.progress.state != RoomProgress.State.UNLOCKED
			or run.combat.waves.state != WaveManager.State.IDLE
			or run.combat.wave_definition.counts.size() != 5
			or run.run_random.seed != run.run_seed
			or run.run_random.draw_count != 0
			or run.combat.local_player.items.player_id != run.combat.local_player_id
			or run.combat.weapon_definitions.size() != 3
			or run.combat.local_player.weapons.controllers.size() != 3
			or run.combat.local_player.weapons.equipped_index != 0
			or run.combat.arena.exit_marker == null
		):
			printerr("ERROR: Room run smoke initialization failed")
			get_tree().quit(1)
			return
		print(
			(
				"DEAD_CIRCUIT_READY version=%s player=%d room=%s wave=0 seed=%d"
				% [
					BuildInfo.version(),
					run.combat.local_player_id,
					run.progress.current_room().id,
					run.run_seed
				]
			)
		)
		get_tree().quit(0)


func _development_console_enabled() -> bool:
	return (
		not OS.has_feature("release")
		and str(BuildInfo.metadata().get("build_type", "local")) != "release"
	)

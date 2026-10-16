class_name RoomRunSession
extends Node3D
## Run authority owns one persistent combat/player lifetime across authored rooms.

signal run_started
signal room_entered

@export var definition: RunDefinition
@export var combat_scene: PackedScene
@export var interactive: bool = true
@export_range(0, 2147483647, 1) var run_seed: int = 12345
@export var completion_text: String = "RUN COMPLETE"
@export var boss_staging_hint: String = ""

var combat: CombatSession
var progress: RoomProgress = RoomProgress.new()
var run_random: RunRandom = RunRandom.new()

@onready var room_status: Label = %RoomStatus
@onready var exit_hint: Label = %ExitHint


func _ready() -> void:
	if definition == null or not definition.validation_errors().is_empty():
		push_error("Room run requires a valid authored definition")
		return
	combat = combat_scene.instantiate() as CombatSession
	combat.managed_rooms = true
	combat.encounter_enabled = false
	combat.interactive = interactive
	combat.run_seed = run_seed
	combat.run_random = run_random
	combat.completion_text = completion_text
	combat.restart_requested.connect(restart_run)
	combat.session_started.connect(_on_attempt_started)
	combat.encounter_completed.connect(_on_room_cleared)
	combat.room_reward_completed.connect(_on_room_cleared)
	combat.state_changed.connect(_refresh_status)
	combat.room_ready.connect(_on_room_ready)
	progress.reset(definition)
	add_child(combat)


func restart_run() -> void:
	run_seed = combat.run_seed
	progress.reset(definition)
	combat.encounter_enabled = false
	combat.restart_session()
	_refresh_status()


func _on_attempt_started() -> void:
	_enter_next()


func _enter_next() -> void:
	if not progress.advance(progress.attempt_token, progress.room_token):
		return
	if progress.state == RoomProgress.State.COMPLETED:
		combat.finish_session(CombatSession.State.COMPLETED)
		_refresh_status()
		return
	var room: RoomDefinition = progress.current_room()
	combat.change_room(room.scene, room.waves)
	_refresh_status()


func _on_room_ready() -> void:
	var room: RoomDefinition = progress.current_room()
	var locked: bool = room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.TREASURE]
	if not progress.ready_room(progress.attempt_token, progress.room_token, locked):
		return
	if room.kind == RoomDefinition.Kind.TREASURE:
		combat.begin_room_reward()
	_refresh_status()
	room_entered.emit()
	if progress.room_index == 0:
		run_started.emit()


func _on_room_cleared() -> void:
	progress.clear_room(progress.attempt_token, progress.room_token)
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if interactive and event.is_action_pressed("interact"):
		request_exit(combat.local_player_id, progress.attempt_token, progress.room_token)
		get_viewport().set_input_as_handled()


func request_exit(player_id: int, attempt: int, room: int) -> bool:
	if (
		attempt != progress.attempt_token
		or room != progress.room_token
		or progress.state != RoomProgress.State.UNLOCKED
		or combat.state != CombatSession.State.ACTIVE
		or combat.paused
	):
		return false
	for player: CombatPlayer in combat.players:
		if player.player_id == player_id and not player.health.is_dead:
			if player.global_position.distance_to(combat.arena.exit_marker.global_position) <= 2.5:
				_enter_next()
				return true
	return false


func _refresh_status() -> void:
	if progress.room_index < 0:
		return
	var room: RoomDefinition = progress.current_room()
	room_status.text = (
		"Room %d / %d — %s" % [progress.room_index + 1, definition.rooms.size(), room.display_name]
	)
	if progress.state == RoomProgress.State.COMPLETED:
		exit_hint.text = "Use Replay to start a new run."
	elif combat.state == CombatSession.State.DEAD:
		exit_hint.text = "Attempt ended. Replay resets every room and player build."
	elif progress.state == RoomProgress.State.TRANSITIONING:
		exit_hint.text = "Entering room..."
	elif progress.state == RoomProgress.State.LOCKED:
		exit_hint.text = "Exit locked — clear combat / finish item choices."
	else:
		exit_hint.text = "Approach the EXIT marker and press E."
		if room.kind == RoomDefinition.Kind.BOSS and not boss_staging_hint.is_empty():
			exit_hint.text += " " + boss_staging_hint

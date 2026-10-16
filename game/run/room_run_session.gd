class_name RoomRunSession
extends Node3D
## Run authority owns one persistent combat/player lifetime across authored rooms.

signal run_started
signal room_entered
signal boss_defeated(context: DamageContext)
signal reward_granted(player_id: int, item_id: StringName, source: DamageContext)
signal drop_rolled(kind: ClearDropDefinition.Kind)

@export var definition: RunDefinition
@export var combat_scene: PackedScene
@export var interactive: bool = true
@export_range(0, 2147483647, 1) var run_seed: int = 12345
@export var completion_text: String = "RUN COMPLETE"
@export var boss_staging_hint: String = ""
@export var wave_rewards_enabled: bool = true
@export var clear_drops: ClearDropDefinition

var combat: CombatSession
var progress: RoomProgress = RoomProgress.new()
var run_random: RunRandom = RunRandom.new()
var boss: BossEnemy
var boss_rewarded: bool = false
var rewarded_players: Array[int] = []
var boss_kill_context: DamageContext
var supply: RoomSupplyPickup
var last_drop_kind: ClearDropDefinition.Kind = ClearDropDefinition.Kind.NONE

@onready var room_status: Label = %RoomStatus
@onready var exit_hint: Label = %ExitHint
@onready var boss_status: Label = get_node_or_null("HUD/BossStatus") as Label


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
	combat.offer_wave_rewards = wave_rewards_enabled
	combat.completion_text = completion_text
	combat.restart_requested.connect(restart_run)
	combat.session_started.connect(_on_attempt_started)
	combat.encounter_completed.connect(_on_room_cleared)
	combat.room_reward_completed.connect(_on_room_cleared)
	combat.state_changed.connect(_refresh_status)
	combat.room_ready.connect(_on_room_ready)
	combat.item_granted.connect(_on_item_granted)
	progress.reset(definition)
	_clear_encounter_state()
	add_child(combat)


func restart_run() -> void:
	run_seed = combat.run_seed
	progress.reset(definition)
	_clear_encounter_state()
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
	_clear_encounter_state()
	var room: RoomDefinition = progress.current_room()
	combat.change_room(room.scene, room.waves)
	_refresh_status()


func _on_room_ready() -> void:
	var room: RoomDefinition = progress.current_room()
	var locked: bool = (
		room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.TREASURE]
		or room.boss_scene != null
	)
	if not progress.ready_room(progress.attempt_token, progress.room_token, locked):
		return
	if room.kind == RoomDefinition.Kind.TREASURE:
		combat.begin_room_reward()
	elif room.boss_scene != null:
		_start_boss(room)
	_refresh_status()
	room_entered.emit()
	if progress.room_index == 0:
		run_started.emit()


func _on_room_cleared() -> void:
	var room: RoomDefinition = progress.current_room()
	if room.boss_scene != null and boss_kill_context == null:
		return
	if progress.clear_room(progress.attempt_token, progress.room_token):
		if room.boss_scene != null:
			boss_rewarded = true
		if (
			clear_drops != null
			and room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS]
		):
			last_drop_kind = clear_drops.roll(run_random)
			var attempt: int = progress.attempt_token
			var room_token: int = progress.room_token
			drop_rolled.emit(last_drop_kind)
			if last_drop_kind != ClearDropDefinition.Kind.NONE:
				_spawn_supply.call_deferred(attempt, room_token)
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
		if boss_rewarded:
			exit_hint.text = "Boss defeated. Reward granted. Approach EXIT and press E."
	if boss_status != null:
		boss_status.visible = is_instance_valid(boss) and not boss.health.is_dead
		if boss_status.visible:
			boss_status.text = (
				"%s — HP %d / %d — %s"
				% [
					boss.boss_definition.display_name,
					ceili(boss.health.current),
					ceili(boss.health.maximum),
					BossEnemy.Phase.keys()[boss.phase]
				]
			)


func _clear_encounter_state() -> void:
	boss = null
	boss_rewarded = false
	rewarded_players.clear()
	boss_kill_context = null
	last_drop_kind = ClearDropDefinition.Kind.NONE
	if is_instance_valid(supply):
		supply.queue_free()
	supply = null


func _start_boss(room: RoomDefinition) -> void:
	var spawn: Marker3D = combat.arena.get_node("BossSpawn") as Marker3D
	boss = combat.spawn_enemy(room.boss_scene, spawn.global_position) as BossEnemy
	boss.phase_changed.connect(_refresh_status)
	boss.health.changed.connect(_on_boss_health_changed)
	boss.removed_from_combat.connect(
		_on_boss_removed.bind(
			progress.attempt_token, progress.room_token, combat.waves.session_token
		)
	)


func _on_boss_health_changed(_current: float, _maximum: float) -> void:
	_refresh_status()


func _on_boss_removed(
	entity_id: int, context: DamageContext, attempt: int, room: int, combat_token: int
) -> void:
	if (
		attempt != progress.attempt_token
		or room != progress.room_token
		or combat_token != combat.waves.session_token
		or boss_kill_context != null
		or progress.state != RoomProgress.State.LOCKED
		or combat.state != CombatSession.State.ACTIVE
		or not is_instance_valid(boss)
		or entity_id != boss.get_instance_id()
		or not boss.health.is_dead
	):
		return
	boss_kill_context = context
	boss_defeated.emit(context)
	if attempt == progress.attempt_token and room == progress.room_token:
		combat.begin_room_reward()


func _on_item_granted(player_id: int, item_id: StringName) -> void:
	if boss_kill_context != null and not boss_rewarded and not rewarded_players.has(player_id):
		rewarded_players.append(player_id)
		reward_granted.emit(player_id, item_id, boss_kill_context)


func _spawn_supply(attempt: int, room: int) -> void:
	if attempt != progress.attempt_token or room != progress.room_token:
		return
	supply = RoomSupplyPickup.new()
	supply.definition = clear_drops
	supply.kind = last_drop_kind
	supply.room_id = progress.current_room().id
	supply.can_collect = _can_collect_supply.bind(attempt, room, combat.waves.session_token)
	var marker: Marker3D = combat.arena.get_node("SupplySpawn") as Marker3D
	supply.position = combat.actors.to_local(marker.global_position)
	combat.actors.add_child(supply)


func _can_collect_supply(player: CombatPlayer, attempt: int, room: int, token: int) -> bool:
	return (
		attempt == progress.attempt_token
		and room == progress.room_token
		and token == combat.waves.session_token
		and combat.state == CombatSession.State.ACTIVE
		and not combat.paused
		and progress.state == RoomProgress.State.UNLOCKED
		and combat.players.has(player)
	)

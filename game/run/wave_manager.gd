class_name WaveManager
extends Node
## Session-owned bookkeeping; tokens reject late callbacks from old sessions.

signal wave_started(number: int, count: int)
signal changed
signal completed
signal wave_cleared(number: int)

enum State { IDLE, ACTIVE, COMPLETED, STOPPED, WAITING_FOR_REWARD }

var wait_for_reward: bool = false
var definition: WaveDefinition
var state: State = State.IDLE
var wave_number: int = 0
var session_token: int = 0
var active_ids: Dictionary[int, bool] = {}
var pending_spawns: int = 0


func reset() -> void:
	session_token += 1
	state = State.IDLE
	wave_number = 0
	active_ids.clear()
	pending_spawns = 0
	changed.emit()


func start() -> void:
	if state == State.IDLE:
		state = State.ACTIVE
		_begin_wave()


func remaining() -> int:
	return active_ids.size() + pending_spawns


func register_enemy(entity_id: int, token: int) -> void:
	if token != session_token or state != State.ACTIVE or pending_spawns <= 0:
		return
	if active_ids.has(entity_id):
		return
	active_ids[entity_id] = true
	pending_spawns -= 1
	changed.emit()


func remove_enemy(entity_id: int, token: int) -> void:
	if token != session_token or state != State.ACTIVE or not active_ids.has(entity_id):
		return
	active_ids.erase(entity_id)
	changed.emit()
	if remaining() == 0:
		if wave_number == definition.counts.size():
			state = State.COMPLETED
			completed.emit()
		else:
			# Leave the current death signal stack before creating the next wave.
			call_deferred("_advance_if_clear", token, wave_number)


func stop() -> void:
	state = State.STOPPED
	pending_spawns = 0
	changed.emit()


func _advance_if_clear(token: int, cleared_wave: int) -> void:
	if token == session_token and state == State.ACTIVE and wave_number == cleared_wave:
		if remaining() == 0:
			if wait_for_reward:
				state = State.WAITING_FOR_REWARD
				wave_cleared.emit(wave_number)
				changed.emit()
			else:
				_begin_wave()


func continue_after_reward(token: int, cleared_wave: int) -> bool:
	if (
		token != session_token
		or state != State.WAITING_FOR_REWARD
		or wave_number != cleared_wave
		or remaining() != 0
	):
		return false
	state = State.ACTIVE
	_begin_wave()
	return true


func _begin_wave() -> void:
	wave_number += 1
	pending_spawns = definition.counts[wave_number - 1]
	wave_started.emit(wave_number, pending_spawns)
	changed.emit()

class_name CombatSession
extends Node3D
## Local gameplay authority and actor lifetime. No global player or networking.

signal session_started
signal state_changed
signal restart_requested
signal room_ready
signal encounter_completed
signal room_reward_completed
signal item_granted(player_id: int, id: StringName)

enum State { PREPARING, ACTIVE, DEAD, COMPLETED, SELECTING_ITEM }

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var weapon_definitions: Array[WeaponDefinition] = []
@export var wave_definition: WaveDefinition
@export var item_catalog: Array[ItemDefinition] = []
@export var local_player_id: int = 1
@export var interactive: bool = true
@export_range(0, 2147483647, 1) var run_seed: int = 12345
@export var offer_wave_rewards: bool = true
var managed_rooms: bool = false
var encounter_enabled: bool = true
var completion_text: String = "COMBAT SANDBOX COMPLETE"

var state: State = State.PREPARING
var paused: bool = false
var players: Array[CombatPlayer] = []
var enemies: Dictionary[int, MeleeEnemy] = {}
var local_player: CombatPlayer
var actors: Node3D
var damage_targets: Array[DamageableBody] = []
var item_offers: Dictionary[int, ItemOffer] = {}
var run_random: RunRandom = RunRandom.new()
var enemy_spawn_order: Array[int] = []
var weapon_definition: WeaponDefinition:
	get:
		return weapon_definitions[0] if not weapon_definitions.is_empty() else null

@onready var arena: CombatArena = $Arena
@onready var waves: WaveManager = $Waves
@onready var hud: CombatHUD = $HUD


func _ready() -> void:
	waves.definition = wave_definition
	waves.wave_started.connect(_spawn_wave)
	waves.changed.connect(_refresh_hud)
	waves.completed.connect(_on_completed)
	waves.wave_cleared.connect(_on_wave_cleared)
	hud.restart_requested.connect(
		func() -> void:
			if managed_rooms:
				restart_requested.emit()
			else:
				restart_session()
	)
	hud.item_selected.connect(select_item)
	hud.seed_requested.connect(restart_with_seed)
	restart_session()


func restart_session() -> void:
	state = State.PREPARING
	paused = false
	run_random.reset(run_seed)
	enemy_spawn_order.clear()
	item_offers.clear()
	damage_targets = []
	waves.wait_for_reward = offer_wave_rewards and not item_catalog.is_empty()
	waves.reset()
	var token: int = waves.session_token
	players.clear()
	enemies.clear()
	local_player = null
	if is_instance_valid(actors):
		remove_child(actors)
		actors.queue_free()
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	local_player = player_scene.instantiate() as CombatPlayer
	local_player.player_id = local_player_id
	actors.add_child(local_player)
	local_player.global_transform = arena.player_spawn.global_transform
	local_player.camera.make_current()
	local_player.configure_weapons(weapon_definitions)
	local_player.items.run_random = run_random
	local_player.item_effects.run_random = run_random
	local_player.item_effects.targets = damage_targets
	local_player.combat_enabled = false
	local_player.local_input_enabled = interactive
	players.append(local_player)
	local_player.health.changed.connect(_on_health_changed)
	local_player.health.died.connect(_on_player_died)
	local_player.weapons.changed.connect(_refresh_hud)
	local_player.items.changed.connect(_refresh_hud)
	_refresh_hud()
	if not await _synchronize_arena(token):
		return
	state = State.ACTIVE
	local_player.combat_enabled = true
	local_player.weapons.enabled = true
	if encounter_enabled:
		waves.start()
	_set_mouse_capture(true)
	_refresh_hud()
	state_changed.emit()
	session_started.emit()


func restart_with_seed(value: int) -> bool:
	if value < 0 or value > RunRandom.MAX_SEED:
		return false
	run_seed = value
	hud.restart_requested.emit()
	return true


func _input(event: InputEvent) -> void:
	if not interactive:
		return
	if (
		event.is_action_pressed("restart")
		and (state in [State.DEAD, State.COMPLETED] or paused)
		and not (hud.seed_input.has_focus() or hud.seed_button.has_focus())
	):
		hud.restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse") and state == State.ACTIVE:
		set_paused(not paused)


func _unhandled_input(event: InputEvent) -> void:
	# Let GUI buttons receive the click before treating empty-space clicks as resume.
	if interactive and paused and event.is_action_pressed("fire"):
		local_player.suppress_fire_until_release = true
		set_paused(false)
		get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	if state != State.ACTIVE:
		return
	paused = value
	for player: CombatPlayer in players:
		player.combat_enabled = not paused
		player.weapons.enabled = not paused
		player.velocity = Vector3.ZERO
	for enemy: MeleeEnemy in enemies.values():
		enemy.combat_enabled = not paused
		enemy.velocity = Vector3.ZERO
	_set_mouse_capture(not paused)
	_refresh_hud()


func _spawn_wave(_number: int, count: int) -> void:
	var spawn_count: int = arena.enemy_spawns.get_child_count()
	enemy_spawn_order = run_random.sample_indices(spawn_count, spawn_count)
	for index: int in range(count):
		spawn_enemy(enemy_scene, arena.enemy_spawn(enemy_spawn_order[index % spawn_count]), true)


func spawn_enemy(scene: PackedScene, position: Vector3, tracked_wave: bool = false) -> MeleeEnemy:
	if state != State.ACTIVE or scene == null:
		return null
	var token: int = waves.session_token
	var enemy: MeleeEnemy = scene.instantiate() as MeleeEnemy
	enemy.players = players.duplicate()
	actors.add_child(enemy)
	enemy.global_position = position
	enemy.combat_enabled = not paused
	var entity_id: int = enemy.get_instance_id()
	enemies[entity_id] = enemy
	damage_targets.append(enemy)
	enemy.removed_from_combat.connect(_on_enemy_removed.bind(token))
	enemy.tree_exiting.connect(_on_enemy_exited.bind(entity_id, token))
	if tracked_wave:
		waves.register_enemy(entity_id, token)
	_refresh_hud()
	return enemy


func _on_enemy_removed(entity_id: int, context: DamageContext, token: int) -> void:
	if token != waves.session_token:
		return
	var enemy: MeleeEnemy = enemies.get(entity_id)
	if enemy != null and state == State.ACTIVE:
		var event: CombatEvent = CombatEvent.new(
			CombatEvent.Kind.ENEMY_KILLED, context, enemy.global_position, entity_id
		)
		for player: CombatPlayer in players.duplicate():
			player.items.handle_event(event)
	_on_enemy_exited(entity_id, token)


func _on_enemy_exited(entity_id: int, token: int) -> void:
	if token == waves.session_token:
		damage_targets.erase(enemies.get(entity_id))
		enemies.erase(entity_id)
		waves.remove_enemy(entity_id, token)
		_refresh_hud()


func _on_health_changed(_current: float, _maximum: float) -> void:
	_refresh_hud()


func _on_player_died(_context: DamageContext) -> void:
	finish_session(State.DEAD)


func _on_completed() -> void:
	if managed_rooms:
		encounter_enabled = false
		_refresh_hud()
		encounter_completed.emit()
	else:
		finish_session(State.COMPLETED)


func _on_wave_cleared(number: int) -> void:
	if state != State.ACTIVE:
		return
	state = State.SELECTING_ITEM
	var ordered_players: Array[CombatPlayer] = players.duplicate()
	ordered_players.sort_custom(
		func(first: CombatPlayer, second: CombatPlayer) -> bool:
			return first.player_id < second.player_id
	)
	for player: CombatPlayer in ordered_players:
		player.disable_combat()
		if not player.health.is_dead and not item_offers.has(player.player_id):
			var offer: ItemOffer = ItemOffer.new(
				item_catalog, player.items, waves.session_token, number, run_random
			)
			if not offer.choices.is_empty():
				item_offers[player.player_id] = offer
	_set_mouse_capture(false)
	_refresh_hud()
	state_changed.emit()
	if item_offers.is_empty():
		_resume_after_items()


func select_item(player_id: int, id: StringName, token: int, number: int) -> bool:
	if state != State.SELECTING_ITEM or token != waves.session_token or number != waves.wave_number:
		return false
	var offer: ItemOffer = item_offers.get(player_id)
	if offer == null:
		return false
	for player: CombatPlayer in players:
		if player.player_id == player_id and offer.select(id, player.items, token, number):
			if token != waves.session_token:
				return true
			item_offers.erase(player_id)
			player.suppress_fire_until_release = true
			item_granted.emit(player_id, id)
			if token != waves.session_token:
				return true
			if item_offers.is_empty():
				_resume_after_items()
			return true
	return false


func _resume_after_items() -> void:
	var token: int = waves.session_token
	state = State.ACTIVE
	for player: CombatPlayer in players:
		if not player.health.is_dead:
			player.combat_enabled = true
			player.weapons.enabled = true
	if waves.state == WaveManager.State.WAITING_FOR_REWARD:
		waves.continue_after_reward(waves.session_token, waves.wave_number)
	else:
		room_reward_completed.emit()
	if token != waves.session_token or state != State.ACTIVE:
		return
	_set_mouse_capture(true)
	_refresh_hud()
	state_changed.emit()


func finish_session(result: State) -> void:
	state = result
	paused = false
	if result == State.DEAD:
		waves.stop()
	for player: CombatPlayer in players:
		player.disable_combat()
	for enemy: MeleeEnemy in enemies.values():
		enemy.disable_combat()
	_set_mouse_capture(false)
	_refresh_hud()
	state_changed.emit()


func _refresh_hud() -> void:
	if not is_instance_valid(local_player):
		return
	var message: String = ""
	if state == State.DEAD:
		message = "YOU DIED"
	elif state == State.COMPLETED:
		message = completion_text
	elif paused:
		message = "PAUSED — Click to resume"
	elif state == State.SELECTING_ITEM:
		message = "CHOOSE ONE"
	hud.refresh(
		local_player, waves, message, run_random.seed, maxi(enemies.size(), waves.remaining())
	)
	var offer: ItemOffer = item_offers.get(local_player_id)
	hud.show_offer(offer if state == State.SELECTING_ITEM else null)


func _set_mouse_capture(captured: bool) -> void:
	if interactive and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func change_room(scene: PackedScene, definition: WaveDefinition) -> void:
	state = State.PREPARING
	paused = false
	item_offers.clear()
	waves.reset()
	var token: int = waves.session_token
	for player: CombatPlayer in players:
		player.disable_combat()
		player.item_effects.clear_transient_visuals()
	for enemy: MeleeEnemy in enemies.values():
		enemy.disable_combat()
		enemy.queue_free()
	enemies.clear()
	damage_targets = []
	enemy_spawn_order.clear()
	remove_child(arena)
	arena.queue_free()
	arena = scene.instantiate() as CombatArena
	arena.name = "Arena"
	add_child(arena)
	encounter_enabled = definition != null
	if definition != null:
		waves.definition = definition
	for index: int in range(players.size()):
		var player: CombatPlayer = players[index]
		player.global_transform = arena.player_spawn.global_transform
		player.global_position.x += index * 1.5
		player.camera.rotation = Vector3.ZERO
		player.item_effects.targets = damage_targets
		player.suppress_fire_until_release = true
	_refresh_hud()
	if not await _synchronize_arena(token):
		return
	state = State.ACTIVE
	for player: CombatPlayer in players:
		player.combat_enabled = not player.health.is_dead
		player.weapons.enabled = not player.health.is_dead
	if encounter_enabled:
		waves.start()
	_set_mouse_capture(true)
	_refresh_hud()
	state_changed.emit()
	room_ready.emit()


func begin_room_reward() -> void:
	if state == State.ACTIVE and not encounter_enabled and waves.wave_number == 0:
		_on_wave_cleared(0)


func _synchronize_arena(token: int) -> bool:
	for iteration: int in range(60):
		await get_tree().physics_frame
		if token != waves.session_token:
			return false
		if NavigationServer3D.region_get_iteration_id(arena.navigation.get_rid()) > 0:
			return true
	push_error("Combat arena navigation did not initialize")
	return false

class_name CombatSession
extends Node3D
## Local gameplay authority and actor lifetime. No global player or networking.

signal session_started
signal state_changed

enum State { PREPARING, ACTIVE, DEAD, COMPLETED, SELECTING_ITEM }

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var weapon_definition: WeaponDefinition
@export var wave_definition: WaveDefinition
@export var item_catalog: Array[ItemDefinition] = []
@export var local_player_id: int = 1
@export var interactive: bool = true

var state: State = State.PREPARING
var paused: bool = false
var players: Array[CombatPlayer] = []
var enemies: Dictionary[int, MeleeEnemy] = {}
var local_player: CombatPlayer
var actors: Node3D
var damage_targets: Array[DamageableBody] = []
var item_offers: Dictionary[int, ItemOffer] = {}

@onready var arena: CombatArena = $Arena
@onready var waves: WaveManager = $Waves
@onready var hud: CombatHUD = $HUD


func _ready() -> void:
	waves.definition = wave_definition
	waves.wave_started.connect(_spawn_wave)
	waves.changed.connect(_refresh_hud)
	waves.completed.connect(_on_completed)
	waves.wave_cleared.connect(_on_wave_cleared)
	hud.restart_requested.connect(restart_session)
	hud.item_selected.connect(select_item)
	restart_session()


func restart_session() -> void:
	state = State.PREPARING
	paused = false
	item_offers.clear()
	damage_targets = []
	waves.wait_for_reward = not item_catalog.is_empty()
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
	local_player.weapon.configure(weapon_definition, local_player_id, local_player.items)
	local_player.item_effects.targets = damage_targets
	local_player.combat_enabled = false
	local_player.local_input_enabled = interactive
	players.append(local_player)
	local_player.health.changed.connect(_on_health_changed)
	local_player.health.died.connect(_on_player_died)
	local_player.weapon.changed.connect(_refresh_hud)
	local_player.items.changed.connect(_refresh_hud)
	_refresh_hud()
	for iteration: int in range(60):
		await get_tree().physics_frame
		if token != waves.session_token:
			return
		if NavigationServer3D.map_get_iteration_id(arena.navigation.get_navigation_map()) > 0:
			break
	if NavigationServer3D.map_get_iteration_id(arena.navigation.get_navigation_map()) == 0:
		push_error("Combat arena navigation did not initialize")
		return
	state = State.ACTIVE
	local_player.combat_enabled = true
	waves.start()
	_set_mouse_capture(true)
	_refresh_hud()
	state_changed.emit()
	session_started.emit()


func _input(event: InputEvent) -> void:
	if not interactive:
		return
	if event.is_action_pressed("restart") and (state in [State.DEAD, State.COMPLETED] or paused):
		restart_session()
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
		player.weapon.enabled = not paused
		player.velocity = Vector3.ZERO
	for enemy: MeleeEnemy in enemies.values():
		enemy.combat_enabled = not paused
		enemy.velocity = Vector3.ZERO
	_set_mouse_capture(not paused)
	_refresh_hud()


func _spawn_wave(_number: int, count: int) -> void:
	var token: int = waves.session_token
	for index: int in range(count):
		var enemy: MeleeEnemy = enemy_scene.instantiate() as MeleeEnemy
		enemy.players = players.duplicate()
		actors.add_child(enemy)
		enemy.global_position = arena.enemy_spawn(index)
		var entity_id: int = enemy.get_instance_id()
		enemies[entity_id] = enemy
		damage_targets.append(enemy)
		enemy.removed_from_combat.connect(_on_enemy_removed.bind(token))
		enemy.tree_exiting.connect(_on_enemy_exited.bind(entity_id, token))
		waves.register_enemy(entity_id, token)


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


func _on_health_changed(_current: float, _maximum: float) -> void:
	_refresh_hud()


func _on_player_died(_context: DamageContext) -> void:
	_finish(State.DEAD)


func _on_completed() -> void:
	_finish(State.COMPLETED)


func _on_wave_cleared(number: int) -> void:
	if state != State.ACTIVE:
		return
	state = State.SELECTING_ITEM
	for player: CombatPlayer in players:
		player.disable_combat()
		if not player.health.is_dead:
			var offer: ItemOffer = ItemOffer.new(
				item_catalog, player.items, waves.session_token, number
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
			item_offers.erase(player_id)
			player.suppress_fire_until_release = true
			if item_offers.is_empty():
				_resume_after_items()
			return true
	return false


func _resume_after_items() -> void:
	state = State.ACTIVE
	for player: CombatPlayer in players:
		if not player.health.is_dead:
			player.combat_enabled = true
			player.weapon.enabled = true
	waves.continue_after_reward(waves.session_token, waves.wave_number)
	_set_mouse_capture(true)
	_refresh_hud()
	state_changed.emit()


func _finish(result: State) -> void:
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
		message = "COMBAT SANDBOX COMPLETE"
	elif paused:
		message = "PAUSED — Click to resume"
	elif state == State.SELECTING_ITEM:
		message = "CHOOSE ONE"
	hud.refresh(local_player, waves, message)
	var offer: ItemOffer = item_offers.get(local_player_id)
	hud.show_offer(offer if state == State.SELECTING_ITEM else null)


func _set_mouse_capture(captured: bool) -> void:
	if interactive and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

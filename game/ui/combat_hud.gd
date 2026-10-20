class_name CombatHUD
extends CanvasLayer

signal restart_requested
signal item_selected(player_id: int, id: StringName, token: int, wave: int)
signal seed_requested(seed: int)

var _shown_offer: ItemOffer
var _shown_seed: int = -1

@onready var status: Label = %Status
@onready var message: Label = %Message
@onready var restart_button: Button = %Restart
@onready var choices: VBoxContainer = %Choices
@onready var build_text: Label = %Build
@onready var seed_input: LineEdit = %SeedInput
@onready var seed_controls: HBoxContainer = %SeedControls
@onready var seed_button: Button = %StartSeed


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	seed_button.pressed.connect(_request_seed.bind(""))
	seed_input.text_submitted.connect(_request_seed)
	seed_input.text_changed.connect(_validate_seed)


func refresh(
	player: CombatPlayer,
	waves: WaveManager,
	state_text: String,
	seed: int,
	active_enemies: int = -1
) -> void:
	status.text = (
		"HP %d / %d\n[%d] %s   Ammo %d / %d   Reserve %d%s\nWave %d / %d   Enemies %d\nSeed %d"
		% [
			player.health.current,
			player.health.maximum,
			player.weapons.equipped_index + 1,
			player.weapon.definition.display_name,
			player.weapon.magazine,
			player.weapon.definition.magazine_capacity,
			player.weapon.reserve,
			"   RELOADING" if player.weapon.reloading else "",
			waves.wave_number,
			waves.definition.counts.size(),
			waves.remaining() if active_enemies < 0 else active_enemies,
			seed
		]
	)
	message.text = state_text
	restart_button.visible = not state_text.is_empty() and state_text != "CHOOSE ONE"
	var opening_seed_controls: bool = not seed_controls.visible and restart_button.visible
	seed_controls.visible = restart_button.visible
	if seed != _shown_seed or opening_seed_controls:
		_shown_seed = seed
		seed_input.text = str(seed)
		_validate_seed(seed_input.text)
	var names: PackedStringArray = []
	for item: ItemDefinition in player.items.definitions():
		names.append(item.display_name)
	var stats: WeaponStats = player.weapon.combat_stats()
	build_text.text = (
		"BUILD\n%s\n\n%s\nShots %d x %.1f damage\nFire rate %.2f/s"
		% [
			"None" if names.is_empty() else "\n".join(names),
			player.weapon.definition.display_name,
			stats.shot_count,
			stats.damage * stats.shot_damage_scale,
			stats.fire_rate
		]
	)


func show_offer(offer: ItemOffer) -> void:
	if _shown_offer == offer:
		return
	_shown_offer = offer
	for child: Node in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	choices.visible = offer != null
	if offer == null:
		return
	for item: ItemDefinition in offer.choices:
		var button: Button = Button.new()
		button.text = item.display_name + "\n" + item.description
		button.custom_minimum_size.y = 62.0
		button.pressed.connect(_select.bind(offer, item.id))
		choices.add_child(button)
	if choices.get_child_count() > 0:
		var first: Button = choices.get_child(0) as Button
		first.grab_focus()


func _select(offer: ItemOffer, id: StringName) -> void:
	item_selected.emit(offer.player_id, id, offer.session_token, offer.wave_number)


func _validate_seed(text: String) -> void:
	seed_button.disabled = RunRandom.parse_seed(text) < 0


func _request_seed(_text: String) -> void:
	var seed: int = RunRandom.parse_seed(seed_input.text)
	if seed >= 0:
		seed_requested.emit(seed)

class_name CombatHUD
extends CanvasLayer

signal restart_requested

@onready var status: Label = %Status
@onready var message: Label = %Message
@onready var restart_button: Button = %Restart


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())


func refresh(player: CombatPlayer, waves: WaveManager, state_text: String) -> void:
	status.text = (
		"HP %d / %d\nAmmo %d / %d   Reserve %d%s\nWave %d / %d   Enemies %d"
		% [
			player.health.current,
			player.health.maximum,
			player.weapon.magazine,
			player.weapon.definition.magazine_capacity,
			player.weapon.reserve,
			"   RELOADING" if player.weapon.reloading else "",
			waves.wave_number,
			waves.definition.counts.size(),
			waves.remaining()
		]
	)
	message.text = state_text
	restart_button.visible = not state_text.is_empty()

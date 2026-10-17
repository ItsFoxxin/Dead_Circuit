class_name BossEnemy
extends MeleeEnemy
## A stationary windup slam uses the ordinary attributed damage/death path.

signal phase_changed

enum Phase { CHASING, WINDUP, RECOVERING, DEAD }

var phase: Phase = Phase.CHASING
var phase_remaining: float = 0.0
var boss_definition: BossDefinition

@onready var telegraph: MeshInstance3D = $Telegraph


func _ready() -> void:
	boss_definition = definition as BossDefinition
	if boss_definition == null:
		push_error("Boss requires a BossDefinition")
		return
	super._ready()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = definition.attack_range
	disc.bottom_radius = definition.attack_range
	disc.height = 0.035
	telegraph.mesh = disc
	telegraph.visible = false


func _physics_process(delta: float) -> void:
	if not combat_enabled or health.is_dead:
		return
	if phase == Phase.CHASING:
		super._physics_process(delta)
		return
	advance_attack(delta)
	if not combat_enabled or health.is_dead:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else 0.0
	move_and_slide()


func try_melee(player: CombatPlayer) -> bool:
	if not combat_enabled or health.is_dead:
		return false
	if phase != Phase.CHASING:
		return true
	if (
		attack_remaining > 0.0
		or not is_instance_valid(player)
		or player.health.is_dead
		or not player.combat_enabled
		or global_position.distance_to(player.global_position) > definition.attack_range
		or not has_line_of_sight_to(player, true)
	):
		return false
	_set_phase(Phase.WINDUP, boss_definition.windup_seconds)
	return true


func advance_attack(delta: float) -> void:
	if not combat_enabled or health.is_dead or phase == Phase.CHASING:
		return
	phase_remaining = maxf(0.0, phase_remaining - delta)
	if phase_remaining > 0.0:
		return
	if phase == Phase.WINDUP:
		_slam()
		if combat_enabled and not health.is_dead:
			_set_phase(Phase.RECOVERING, boss_definition.recovery_seconds)
	elif phase == Phase.RECOVERING:
		attack_remaining = definition.attack_cooldown
		_set_phase(Phase.CHASING, 0.0)


func disable_combat() -> void:
	super.disable_combat()
	_set_phase(Phase.DEAD if health.is_dead else Phase.CHASING, 0.0)


func _set_phase(value: Phase, duration: float) -> void:
	phase = value
	phase_remaining = duration
	telegraph.visible = phase == Phase.WINDUP
	phase_changed.emit()


func _slam() -> void:
	var candidates: Array[CombatPlayer] = []
	for player: CombatPlayer in players:
		if is_instance_valid(player):
			candidates.append(player)
	candidates.sort_custom(
		func(first: CombatPlayer, second: CombatPlayer) -> bool:
			return first.player_id < second.player_id
	)
	for player: CombatPlayer in candidates:
		if not combat_enabled or health.is_dead:
			return
		if not is_instance_valid(player) or player.health.is_dead or not player.combat_enabled:
			continue
		if (
			global_position.distance_to(player.global_position) <= definition.attack_range
			and has_line_of_sight_to(player, true)
		):
			player.receive_damage(
				DamageContext.new(
					definition.attack_damage,
					-1,
					definition.id,
					&"melee",
					["boss", "melee", "slam"],
					get_instance_id()
				)
			)

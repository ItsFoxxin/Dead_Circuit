class_name HealthComponent
extends Node

signal changed(current: float, maximum: float)
signal damaged(context: DamageContext, applied: float)
signal died(context: DamageContext)
signal lethal_prevented(context: DamageContext)

@export var maximum: float = 100.0
var current: float = 100.0
var is_dead: bool = false
var invulnerability_remaining: float = 0.0
var lethal_protections: int = 0
var lethal_invulnerability_seconds: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	current = maximum
	is_dead = false
	invulnerability_remaining = 0.0
	lethal_protections = 0
	lethal_invulnerability_seconds = 0.0
	changed.emit(current, maximum)


func advance(delta: float) -> void:
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - maxf(0.0, delta))


func grant_lethal_protection(charges: int, invulnerability_seconds: float) -> void:
	lethal_protections += maxi(0, charges)
	lethal_invulnerability_seconds = maxf(
		lethal_invulnerability_seconds, maxf(0.0, invulnerability_seconds)
	)


func spend(amount: float, minimum_remaining: float = 1.0) -> float:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var spent: float = minf(amount, maxf(0.0, current - minimum_remaining))
	current -= spent
	if spent > 0.0:
		changed.emit(current, maximum)
	return spent


func heal(amount: float) -> float:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var restored: float = minf(amount, maximum - current)
	current += restored
	changed.emit(current, maximum)
	return restored


func take_damage(context: DamageContext) -> float:
	if (
		is_dead
		or invulnerability_remaining > 0.0
		or context == null
		or not is_finite(context.amount)
		or context.amount <= 0.0
	):
		return 0.0
	var applied: float = minf(current, context.amount)
	var prevented: bool = applied >= current and lethal_protections > 0
	if prevented:
		lethal_protections -= 1
		applied = maxf(0.0, current - 1.0)
		current = 1.0
		invulnerability_remaining = lethal_invulnerability_seconds
	else:
		current = maxf(0.0, current - applied)
	# Set this before signals: callbacks may attempt to apply more damage.
	var lethal: bool = current == 0.0
	is_dead = lethal
	changed.emit(current, maximum)
	damaged.emit(context, applied)
	if prevented:
		lethal_prevented.emit(context)
	elif lethal:
		died.emit(context)
	return applied

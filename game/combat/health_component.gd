class_name HealthComponent
extends Node

signal changed(current: float, maximum: float)
signal damaged(context: DamageContext, applied: float)
signal died(context: DamageContext)

@export var maximum: float = 100.0
var current: float = 100.0
var is_dead: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	current = maximum
	is_dead = false
	changed.emit(current, maximum)


func heal(amount: float) -> float:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var restored: float = minf(amount, maximum - current)
	current += restored
	changed.emit(current, maximum)
	return restored


func take_damage(context: DamageContext) -> float:
	if is_dead or context == null or not is_finite(context.amount) or context.amount <= 0.0:
		return 0.0
	var applied: float = minf(current, context.amount)
	current = maxf(0.0, current - applied)
	# Set this before signals: callbacks may attempt to apply more damage.
	var lethal: bool = current == 0.0
	is_dead = lethal
	changed.emit(current, maximum)
	damaged.emit(context, applied)
	if lethal:
		died.emit(context)
	return applied

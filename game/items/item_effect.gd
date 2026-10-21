class_name ItemEffect
extends Resource

enum Kind {
	HEAL,
	EXPLOSION,
	HIT_COUNTER_HEAL,
	TIMED_STAT,
	FRAGMENT_BURST,
	LETHAL_GUARD,
	HEALTH_COST_TIMED_STAT,
	CHAIN_DAMAGE,
	RECURSIVE_REPEAT,
	EXTRA_RAY,
	COMPANION,
}

@export var kind: Kind = Kind.HEAL
@export var amount: float = 5.0
@export var radius: float = 3.5
@export var threshold: int = 1
@export var duration: float = 0.0
@export var stat: StringName
@export var operation: StatModifier.Operation = StatModifier.Operation.MULTIPLY
@export var max_stacks: int = 1
@export var accumulates: bool = false
@export var chance: float = 1.0
@export var damage_scale: float = 1.0
@export var target_count: int = 1
@export var resource_cost: float = 0.0
@export var attacks_per_second: float = 1.0
@export var recursive_repeat_eligible: bool = false


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if kind not in Kind.values():
		errors.append("Effect requires a known kind")
	if not is_finite(amount) or amount <= 0.0:
		errors.append("Effect amount must be finite and positive")
	if kind in [Kind.EXPLOSION, Kind.FRAGMENT_BURST, Kind.CHAIN_DAMAGE, Kind.COMPANION]:
		if not is_finite(radius) or radius <= 0.0:
			errors.append("Spatial effect radius must be finite and positive")
	if kind in [Kind.HIT_COUNTER_HEAL, Kind.CHAIN_DAMAGE] and threshold <= 0:
		errors.append("Counter effect threshold must be positive")
	if kind in [Kind.TIMED_STAT, Kind.HEALTH_COST_TIMED_STAT]:
		if stat.is_empty() or not str(stat) in StatModifier.STATS:
			errors.append("Timed modifier requires a known stat")
		if not is_finite(duration) or duration <= 0.0 or max_stacks <= 0:
			errors.append("Timed modifier requires positive duration and stack limit")
	if kind == Kind.LETHAL_GUARD and (threshold <= 0 or duration <= 0.0):
		errors.append("Lethal guard requires charges and invulnerability duration")
	if kind in [Kind.RECURSIVE_REPEAT, Kind.EXTRA_RAY]:
		if not is_finite(chance) or chance < 0.0 or chance > 1.0:
			errors.append("Probabilistic effect chance must be from zero to one")
	if kind in [Kind.FRAGMENT_BURST, Kind.CHAIN_DAMAGE, Kind.EXTRA_RAY]:
		if not is_finite(damage_scale) or damage_scale <= 0.0:
			errors.append("Derived damage scale must be finite and positive")
	if kind in [Kind.FRAGMENT_BURST, Kind.CHAIN_DAMAGE] and target_count <= 0:
		errors.append("Targeted effect requires a positive target count")
	if kind == Kind.HEALTH_COST_TIMED_STAT and resource_cost <= 0.0:
		errors.append("Health-cost effect requires a positive resource cost")
	if kind == Kind.COMPANION and attacks_per_second <= 0.0:
		errors.append("Companion attack rate must be positive")
	return errors

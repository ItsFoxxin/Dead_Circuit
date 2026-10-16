class_name DamageableBody
extends CharacterBody3D
## Shared combat interface; weapons and melee do not depend on enemy content.

@onready var health: HealthComponent = $Health


func receive_damage(context: DamageContext) -> float:
	return health.take_damage(context)

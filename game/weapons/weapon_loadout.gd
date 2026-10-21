class_name WeaponLoadout
extends Node
## Per-player weapon ownership. Each controller retains independent ammo and timers.

signal changed
signal equipped_changed(previous_index: int, current_index: int)
signal fired(context: DamageContext)
signal shot_created(context: DamageContext, origin: Vector3)
signal trace_created(
	context: DamageContext, origin: Vector3, endpoint: Vector3, config: WeaponDefinition
)
signal hit(context: DamageContext, target_entity_id: int, position: Vector3, applied: float)

var controllers: Array[WeaponController] = []
var equipped_index: int = 0
var enabled: bool = true:
	set(value):
		enabled = value
		for controller: WeaponController in controllers:
			controller.enabled = value


func _ready() -> void:
	for child: Node in get_children():
		if child is WeaponController:
			_register(child as WeaponController)


func configure(
	definitions: Array[WeaponDefinition], player_id: int, build: PlayerItemBuild = null
) -> void:
	for controller: WeaponController in controllers:
		remove_child(controller)
		controller.free()
	controllers.clear()
	equipped_index = 0
	for definition: WeaponDefinition in definitions:
		var controller: WeaponController = WeaponController.new()
		controller.name = str(definition.id).to_pascal_case()
		add_child(controller)
		_register(controller)
		controller.configure(definition, player_id, build)
	enabled = true
	changed.emit()


func current() -> WeaponController:
	if controllers.is_empty() or equipped_index < 0 or equipped_index >= controllers.size():
		return null
	return controllers[equipped_index]


func equip(index: int) -> bool:
	if index < 0 or index >= controllers.size() or index == equipped_index:
		return false
	var previous: int = equipped_index
	equipped_index = index
	equipped_changed.emit(previous, equipped_index)
	changed.emit()
	return true


func advance(delta: float) -> void:
	if not enabled:
		return
	for controller: WeaponController in controllers:
		controller.advance(delta)


func reset() -> void:
	equipped_index = 0
	for controller: WeaponController in controllers:
		controller.reset()
	enabled = true
	changed.emit()


func _register(controller: WeaponController) -> void:
	controllers.append(controller)
	controller.changed.connect(_on_controller_changed)
	controller.fired.connect(func(context: DamageContext) -> void: fired.emit(context))
	controller.shot_created.connect(
		func(context: DamageContext, origin: Vector3) -> void: shot_created.emit(context, origin)
	)
	controller.trace_created.connect(
		func(
			context: DamageContext, origin: Vector3, endpoint: Vector3, config: WeaponDefinition
		) -> void:
			trace_created.emit(context, origin, endpoint, config)
	)
	controller.hit.connect(
		func(
			context: DamageContext, target_entity_id: int, position: Vector3, applied: float
		) -> void:
			hit.emit(context, target_entity_id, position, applied)
	)


func _on_controller_changed() -> void:
	changed.emit()

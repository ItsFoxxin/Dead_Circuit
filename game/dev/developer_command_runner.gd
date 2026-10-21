class_name DeveloperCommandRunner
extends RefCounted
## Development-only command surface over explicit run and player authority.

var run: RoomRunSession


func configure(value: RoomRunSession) -> void:
	run = value


func execute(command_line: String) -> String:
	var parts: PackedStringArray = command_line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	if run == null or not is_instance_valid(run.combat):
		return "ERROR: combat session is not ready"
	var command: String = parts[0].to_lower()
	var result: String = ""
	match command:
		"help":
			result = _help()
		"status":
			result = _status(parts)
		"items":
			result = _items()
		"give_item":
			result = _give_item(parts)
		"give_all_items":
			result = _give_all_items(parts)
		"weapons":
			result = _weapons()
		"weapon":
			result = _weapon(parts)
		"heal":
			result = _heal(parts)
		"damage":
			result = _damage(parts)
		"ammo":
			result = _ammo(parts)
		"kill_enemies":
			result = _kill_enemies(parts)
		"restart":
			run.restart_run()
			result = "Restarting run with seed %d" % run.run_seed
		"seed":
			result = _seed(parts)
		_:
			result = "ERROR: unknown command '%s'; enter help" % parts[0]
	return result


func _help() -> String:
	return (
		"\n"
		. join(
			[
				"help",
				"status [player_id]",
				"items | give_item <item_id> [player_id] | give_all_items [player_id]",
				"weapons | weapon <slot_or_id> [player_id]",
				"heal [amount] [player_id] | damage <amount> [player_id]",
				"ammo [player_id] | kill_enemies [player_id]",
				"restart | seed <0..2147483647> | clear",
			]
		)
	)


func _status(parts: PackedStringArray) -> String:
	var player: CombatPlayer = _resolve_player(parts, 1)
	if player == null:
		return _player_error(parts, 1)
	var room_id: String = "none"
	if run.progress.room_index >= 0:
		room_id = str(run.progress.current_room().id)
	var owned: PackedStringArray = []
	for definition: ItemDefinition in player.items.definitions():
		owned.append(str(definition.id))
	var weapon: WeaponController = player.weapon
	return (
		(
			"player=%d hp=%d/%d weapon=%s ammo=%d/%d items=[%s] room=%s wave=%d enemies=%d "
			+ "seed=%d draws=%d state=%s"
		)
		% [
			player.player_id,
			ceili(player.health.current),
			ceili(player.health.maximum),
			weapon.definition.id,
			weapon.magazine,
			weapon.reserve,
			", ".join(owned),
			room_id,
			run.combat.waves.wave_number,
			run.combat.enemies.size(),
			run.run_random.seed,
			run.run_random.draw_count,
			CombatSession.State.keys()[run.combat.state],
		]
	)


func _items() -> String:
	var lines: PackedStringArray = ["Available items:"]
	for definition: ItemDefinition in run.combat.item_catalog:
		lines.append("  %s — %s" % [definition.id, definition.display_name])
	return "\n".join(lines)


func _give_item(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: give_item <item_id> [player_id]"
	var player: CombatPlayer = _resolve_player(parts, 2)
	if player == null:
		return _player_error(parts, 2)
	var requested: StringName = StringName(parts[1].to_lower())
	for definition: ItemDefinition in run.combat.item_catalog:
		if definition.id == requested:
			if not player.items.acquire(definition):
				return "ERROR: player %d already owns %s" % [player.player_id, requested]
			return "Granted %s to player %d" % [requested, player.player_id]
	return "ERROR: unknown item '%s'" % parts[1]


func _give_all_items(parts: PackedStringArray) -> String:
	var player: CombatPlayer = _resolve_player(parts, 1)
	if player == null:
		return _player_error(parts, 1)
	var granted: int = 0
	for definition: ItemDefinition in run.combat.item_catalog:
		if player.items.acquire(definition):
			granted += 1
	return "Granted %d item(s) to player %d" % [granted, player.player_id]


func _weapons() -> String:
	var lines: PackedStringArray = ["Available weapons:"]
	for index: int in range(run.combat.weapon_definitions.size()):
		var definition: WeaponDefinition = run.combat.weapon_definitions[index]
		lines.append("  %d — %s — %s" % [index + 1, definition.id, definition.display_name])
	return "\n".join(lines)


func _weapon(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: weapon <slot_or_id> [player_id]"
	var player: CombatPlayer = _resolve_player(parts, 2)
	if player == null:
		return _player_error(parts, 2)
	var index: int = -1
	if parts[1].is_valid_int():
		index = int(parts[1]) - 1
	else:
		var requested: StringName = StringName(parts[1].to_lower())
		for candidate: int in range(player.weapons.controllers.size()):
			if player.weapons.controllers[candidate].definition.id == requested:
				index = candidate
				break
	if not player.equip_weapon(index):
		return "ERROR: unknown weapon slot or id '%s'" % parts[1]
	return "Equipped %s for player %d" % [player.weapon.definition.id, player.player_id]


func _heal(parts: PackedStringArray) -> String:
	var player_index: int = 2 if parts.size() > 1 else 1
	var player: CombatPlayer = _resolve_player(parts, player_index)
	if player == null:
		return _player_error(parts, player_index)
	var amount: float = player.health.maximum
	if parts.size() > 1:
		if not parts[1].is_valid_float() or float(parts[1]) <= 0.0:
			return "ERROR: heal amount must be greater than zero"
		amount = float(parts[1])
	var applied: float = player.health.heal(amount)
	return (
		"Healed player %d by %.1f; hp %.1f/%.1f"
		% [player.player_id, applied, player.health.current, player.health.maximum]
	)


func _damage(parts: PackedStringArray) -> String:
	if parts.size() < 2 or not parts[1].is_valid_float() or float(parts[1]) <= 0.0:
		return "ERROR: usage: damage <positive_amount> [player_id]"
	var player: CombatPlayer = _resolve_player(parts, 2)
	if player == null:
		return _player_error(parts, 2)
	var context: DamageContext = DamageContext.new(
		float(parts[1]), -1, &"developer_console", &"developer", ["developer"]
	)
	context.trigger_eligible = false
	context.healing_eligible = false
	var applied: float = player.receive_damage(context)
	return (
		"Damaged player %d by %.1f; hp %.1f/%.1f"
		% [player.player_id, applied, player.health.current, player.health.maximum]
	)


func _ammo(parts: PackedStringArray) -> String:
	var player: CombatPlayer = _resolve_player(parts, 1)
	if player == null:
		return _player_error(parts, 1)
	player.weapons.refill_ammunition()
	return "Refilled all ammunition for player %d" % player.player_id


func _kill_enemies(parts: PackedStringArray) -> String:
	var player: CombatPlayer = _resolve_player(parts, 1)
	if player == null:
		return _player_error(parts, 1)
	var targets: Array[MeleeEnemy] = []
	for enemy: MeleeEnemy in run.combat.enemies.values():
		targets.append(enemy)
	var killed: int = 0
	for enemy: MeleeEnemy in targets:
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		var context: DamageContext = DamageContext.new(
			enemy.health.current + enemy.health.maximum,
			player.player_id,
			&"developer_console",
			&"developer",
			["developer"],
			player.get_instance_id()
		)
		context.trigger_eligible = false
		context.healing_eligible = false
		enemy.receive_damage(context)
		killed += 1
	return "Removed %d active enemy/enemies for player %d" % [killed, player.player_id]


func _seed(parts: PackedStringArray) -> String:
	if parts.size() != 2 or not parts[1].is_valid_int():
		return "ERROR: usage: seed <0..2147483647>"
	var value: int = int(parts[1])
	if not run.combat.restart_with_seed(value):
		return "ERROR: seed must be from 0 to 2147483647"
	return "Restarting run with seed %d" % value


func _resolve_player(parts: PackedStringArray, index: int) -> CombatPlayer:
	var player_id: int = run.combat.local_player_id
	if parts.size() > index:
		if not parts[index].is_valid_int():
			return null
		player_id = int(parts[index])
	for player: CombatPlayer in run.combat.players:
		if player.player_id == player_id:
			return player
	return null


func _player_error(parts: PackedStringArray, index: int) -> String:
	if parts.size() > index and not parts[index].is_valid_int():
		return "ERROR: player_id must be an integer"
	var player_id: int = run.combat.local_player_id
	if parts.size() > index:
		player_id = int(parts[index])
	return "ERROR: player %d is not active" % player_id

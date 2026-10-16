extends SceneTree
## Probe the actual session's encounter/offer authority in independent processes.

const SANDBOX_PATH: String = "res://content/rooms/combat_sandbox.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Change StringName allocation/load order in one process; results must still match.
	var held: Array[Resource] = []
	if "--reverse-item-load" in OS.get_cmdline_user_args():
		var paths: PackedStringArray = DirAccess.get_files_at("res://content/items")
		paths.sort()
		paths.reverse()
		for path: String in paths:
			if path.ends_with(".tres"):
				held.append(load("res://content/items/" + path))
	var sandbox: PackedScene = load(SANDBOX_PATH) as PackedScene
	var session: CombatSession = sandbox.instantiate() as CombatSession
	session.interactive = false
	session.run_seed = 12345
	root.add_child(session)
	await session.session_started
	var records: Array[Dictionary] = []
	for number: int in range(1, 6):
		var record: Dictionary = {
			"wave": number, "spawn_order": session.enemy_spawn_order.duplicate()
		}
		for enemy: MeleeEnemy in session.enemies.values():
			enemy.receive_damage(DamageContext.new(1000.0))
		await process_frame
		await process_frame
		var choices: PackedStringArray = []
		if number < 5:
			var offer: ItemOffer = session.item_offers[session.local_player_id]
			for item: ItemDefinition in offer.choices:
				choices.append(str(item.id))
			session.select_item(offer.player_id, offer.choices[0].id, offer.session_token, number)
		record["choices"] = choices
		var build_order: PackedStringArray = []
		for item: ItemDefinition in session.local_player.items.definitions():
			build_order.append(str(item.id))
		record["build_order"] = build_order
		record["draw_count"] = session.run_random.draw_count
		records.append(record)
	if session.state != CombatSession.State.COMPLETED:
		printerr("ERROR: Seeded run probe did not complete")
		quit(1)
		return
	print("RUN_CHOICES_PROBE=" + JSON.stringify(records))
	session.queue_free()
	await process_frame
	quit(0)

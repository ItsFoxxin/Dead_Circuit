extends SceneTree
## Exercise the production room route in independent processes, including restart.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var held: Array[Resource] = []
	if "--reverse-item-load" in OS.get_cmdline_user_args():
		var paths: PackedStringArray = DirAccess.get_files_at("res://content/items")
		paths.sort()
		paths.reverse()
		for path: String in paths:
			if path.ends_with(".tres"):
				held.append(load("res://content/items/" + path))
	var scene: PackedScene = load("res://content/rooms/room_run.tscn") as PackedScene
	var run: RoomRunSession = scene.instantiate() as RoomRunSession
	run.interactive = false
	run.run_seed = 12345
	root.add_child(run)
	await run.run_started
	var rooms: PackedStringArray = [str(run.progress.current_room().id)]
	await _exit_room(run)
	rooms.append(str(run.progress.current_room().id))
	var session: CombatSession = run.combat
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
		record["build_order"] = _build_ids(session.local_player)
		record["draw_count"] = run.run_random.draw_count
		records.append(record)
	await _exit_room(run)
	rooms.append(str(run.progress.current_room().id))
	var treasure: ItemOffer = session.item_offers[session.local_player_id]
	session.select_item(treasure.player_id, treasure.choices[0].id, treasure.session_token, 0)
	await _exit_room(run)
	rooms.append(str(run.progress.current_room().id))
	await _exit_room(run)
	var result: Dictionary = {
		"rooms": rooms,
		"waves": records,
		"completed": run.progress.state == RoomProgress.State.COMPLETED,
		"build": _build_ids(session.local_player),
		"draw_count": run.run_random.draw_count,
	}
	run.restart_run()
	await run.run_started
	result["restart"] = {
		"room": str(run.progress.current_room().id),
		"draw_count": run.run_random.draw_count,
		"items": session.local_player.items.definitions().size(),
		"health": session.local_player.health.current,
		"magazine": session.local_player.weapon.magazine,
		"reserve": session.local_player.weapon.reserve,
	}
	print("ROOM_RUN_PROBE=" + JSON.stringify(result))
	run.queue_free()
	await process_frame
	quit(0)


func _exit_room(run: RoomRunSession) -> void:
	run.combat.local_player.global_position = (
		run.combat.arena.exit_marker.global_position + Vector3(0, 0.05, 1)
	)
	if not run.request_exit(1, run.progress.attempt_token, run.progress.room_token):
		printerr("ERROR: Room route probe exit rejected")
		quit(1)
		return
	if run.progress.state != RoomProgress.State.COMPLETED:
		await run.room_entered


func _build_ids(player: CombatPlayer) -> PackedStringArray:
	var ids: PackedStringArray = []
	for item: ItemDefinition in player.items.definitions():
		ids.append(str(item.id))
	return ids

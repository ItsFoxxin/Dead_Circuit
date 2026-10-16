extends SceneTree
## The production first-boss route has exactly two item acquisition points.

const Driver = preload("res://tests/fixtures/room_test_driver.gd")


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
	var scene: PackedScene = load("res://content/rooms/first_boss_run.tscn") as PackedScene
	var run: RoomRunSession = scene.instantiate() as RoomRunSession
	run.interactive = false
	run.run_seed = RunRandom.seed_from_arguments(OS.get_cmdline_user_args(), run.run_seed)
	var rooms: PackedStringArray = []
	var rolls: Array[int] = []
	var offers: Array[Dictionary] = []
	var rewards: Array[Dictionary] = []
	run.room_entered.connect(func() -> void: rooms.append(str(run.progress.current_room().id)))
	run.drop_rolled.connect(func(kind: ClearDropDefinition.Kind) -> void: rolls.append(kind))
	run.reward_granted.connect(
		func(player_id: int, item_id: StringName, source: DamageContext) -> void:
			rewards.append(
				{
					"player": player_id,
					"item": str(item_id),
					"source_player": source.source_player_id,
					"weapon": str(source.source_weapon_id),
					"entity_matches":
					source.source_entity_id == run.combat.local_player.get_instance_id()
				}
			)
	)
	root.add_child(run)
	await run.run_started
	run.combat.state_changed.connect(
		func() -> void:
			if run.combat.state == CombatSession.State.SELECTING_ITEM:
				var offer: ItemOffer = run.combat.item_offers[1]
				var ids: PackedStringArray = []
				for item: ItemDefinition in offer.choices:
					ids.append(str(item.id))
				offers.append({"room": str(run.progress.current_room().id), "choices": ids})
	)
	if not await Driver.enter_boss(run):
		quit(1)
		return
	run.boss.set_physics_process(false)
	var result: Dictionary = {
		"rooms": rooms.duplicate(),
		"offers": offers,
		"drop_rolls": rolls,
		"boss_spawned": run.boss.health.current == 500.0,
		"exit_locked": run.progress.state == RoomProgress.State.LOCKED,
		"items_before_boss": run.combat.local_player.items.definitions().size(),
	}
	var context: DamageContext = DamageContext.new(
		1000,
		1,
		&"pistol",
		&"ballistic",
		["weapon", "hitscan"],
		run.combat.local_player.get_instance_id()
	)
	run.boss.receive_damage(context)
	result["awaited_boss_choice"] = (
		run.combat.state == CombatSession.State.SELECTING_ITEM
		and run.progress.state == RoomProgress.State.LOCKED
	)
	var boss_offer: ItemOffer = run.combat.item_offers[1]
	run.combat.select_item(1, boss_offer.choices[0].id, boss_offer.session_token, 0)
	result["draw_count"] = run.run_random.draw_count
	result["rewards"] = rewards
	var build: PackedStringArray = []
	for item: ItemDefinition in run.combat.local_player.items.definitions():
		build.append(str(item.id))
	result["build"] = build
	if not await Driver.exit_room(run):
		quit(1)
		return
	result["floor_complete"] = (
		run.progress.state == RoomProgress.State.COMPLETED
		and run.combat.hud.message.text == "FLOOR COMPLETE"
	)
	run.restart_run()
	await run.run_started
	result["restart"] = {
		"room": str(run.progress.current_room().id),
		"draw_count": run.run_random.draw_count,
		"items": run.combat.local_player.items.definitions().size(),
		"health": run.combat.local_player.health.current,
		"magazine": run.combat.local_player.weapon.magazine,
		"reserve": run.combat.local_player.weapon.reserve,
		"boss_clear": run.boss == null and not run.boss_rewarded,
		"supply_clear": run.supply == null,
	}
	print("BOSS_RUN_PROBE=" + JSON.stringify(result))
	run.queue_free()
	await process_frame
	quit(0)

extends RefCounted
## Shared fixture commands exercise real progression; they do not bypass run state.


static func exit_room(run: RoomRunSession) -> bool:
	run.combat.local_player.global_position = (
		run.combat.arena.exit_marker.global_position + Vector3(0, 0.05, 1)
	)
	if not run.request_exit(1, run.progress.attempt_token, run.progress.room_token):
		push_error("Fixture room exit rejected")
		return false
	if run.progress.state != RoomProgress.State.COMPLETED:
		await run.room_entered
	return true


static func enter_boss(run: RoomRunSession) -> bool:
	if not await exit_room(run):
		return false
	for number: int in range(1, 6):
		if run.combat.waves.wave_number != number:
			push_error("Fixture wave sequence diverged")
			return false
		for enemy: MeleeEnemy in run.combat.enemies.values():
			enemy.receive_damage(DamageContext.new(1000.0))
		await run.get_tree().process_frame
		await run.get_tree().process_frame
		if number < 5 and run.combat.offer_wave_rewards:
			var offers: Array[ItemOffer] = run.combat.item_offers.values()
			for offer: ItemOffer in offers:
				run.combat.select_item(
					offer.player_id, offer.choices[0].id, offer.session_token, number
				)
	if not await exit_room(run):
		return false
	var treasure: Array[ItemOffer] = run.combat.item_offers.values()
	for offer: ItemOffer in treasure:
		run.combat.select_item(offer.player_id, offer.choices[0].id, offer.session_token, 0)
	return await exit_room(run)

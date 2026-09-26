class_name ObstacleDecision


static func decide_obstacle_or_flank(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool = false) -> Dictionary:
	var attack_obs_result := {"type": "special", "action_name": "attack_obstacle", "target": null}

	if not valid_attack_targets.is_empty():
		var wp := merc.equipped_weapon
		var melee_reach := 1
		if wp != null and not wp.is_ranged and not wp.is_throwable:
			melee_reach = wp.melee_range
		for vt: MercenaryData in valid_attack_targets:
			if state.distance_to(merc, vt) <= melee_reach:
				return {"type": "attack", "action_name": "Attack",
						"target": TargetSelector.pick_target(merc, valid_attack_targets, state)}

	if state.battlefield == null:
		return attack_obs_result
	var merc_pos := state.get_position(merc)
	var merc_floor := state.get_floor(merc)
	var _bo: Dictionary = _blocking_obstacle(merc, state, merc_pos, merc_floor)
	if _bo["interact"] as bool:
		return {"type": "special", "action_name": "Interact", "target": null}
	var blocking_obs: Dictionary = _bo["obs"] as Dictionary
	if blocking_obs.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	var rounds_to_destroy := _obstacle_rounds_to_destroy(merc, blocking_obs)

	var nearest_enemy: MercenaryData = MovementDecider.nearest_enemy(merc, enemies, state)["merc"] as MercenaryData
	var flank_cell := Vector2i(-1, -1)
	if nearest_enemy != null:
		flank_cell = MovementDecider.find_flanking_cell(merc, nearest_enemy, state)
	if flank_cell == Vector2i(-1, -1):
		if rounds_to_destroy <= 3:
			EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, no flank -> destroy (quick)" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, no flank, too slow -> pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	var pace := maxi(1, int(MovementExecutor.turn_paces(merc, state, 0)["paces"]))
	var flank_dist := maxi(abs(flank_cell.x - merc_pos.x), abs(flank_cell.y - merc_pos.y))
	var rounds_to_flank := ceili(float(flank_dist) / float(pace))

	if rounds_to_destroy * 2 < rounds_to_flank:
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, flank~%d rounds -> destroy (much faster)" % [rounds_to_destroy, rounds_to_flank])
		return attack_obs_result
	if movement_blocked:
		if rounds_to_destroy <= 5:
			EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, movement blocked -> destroy" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, movement blocked, too slow -> pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, flank~%d rounds -> flank" % [rounds_to_destroy, rounds_to_flank])
	return {"type": "move", "action_name": "Move Close",
			"target": nearest_enemy, "flank_ally": null,
			"goal_cell": Vector3i(flank_cell.x, flank_cell.y, state.get_floor(merc))}


#The first obstacle beside the mover that blocks it; interact is true for a shut door it opens.
static func _blocking_obstacle(merc: MercenaryData, state: BattleState, merc_pos: Vector2i,
		merc_floor: int) -> Dictionary:
	var blocking_obs: Dictionary = {}
	for d8: Vector2i in PathCost.DIRS8:
		var obs_cell := Vector3i(merc_pos.x + d8.x, merc_pos.y + d8.y, merc_floor)
		var obs: Dictionary = state.battlefield.get_obs(Vector2i(obs_cell.x, obs_cell.y), merc_floor)
		if obs.is_empty() or obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp or d.health == 0:
			continue
		#A shut door is opened with Interact, never shot at.
		if PathCost.is_shut_door(state.battlefield, obs_cell):
			if state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
				state.pending_interact[merc] = obs_cell
				EncounterLogger.log_verbose("  obstacle choice: shut door at (%d,%d) -> interact" % [obs_cell.x, obs_cell.y])
				return {"obs": {}, "interact": true}
			continue
		#A locked door is a wall to the mover: it is picked or left alone, never shot at.
		if DungeonLocks.is_locked(obs):
			continue
		blocking_obs = obs
		break
	return {"obs": blocking_obs, "interact": false}


#Rounds the mover needs to break the obstacle in front of it with the weapon in hand.
static func _obstacle_rounds_to_destroy(merc: MercenaryData, blocking_obs: Dictionary) -> int:
	var obs_data: ObstacleData = blocking_obs.get("data") as ObstacleData
	var obs_hp: int
	if obs_data != null and obs_data.health > 1:
		obs_hp = obs_data.health
	elif obs_data != null and (obs_data.is_building or obs_data.obstacle_type == "Structure"):
		obs_hp = 20
	elif obs_data != null:
		obs_hp = ObstacleUtils.get_hp(obs_data)
	else:
		obs_hp = 3
	if blocking_obs.has("current_hp"):
		obs_hp = maxi(1, int(blocking_obs["current_hp"]))
	var wp2 := merc.equipped_weapon
	var acc_stat := clampf(float(merc.stats.get("melee_accuracy", 50)) / 100.0, 0.05, 1.0)
	if wp2 != null and wp2.is_ranged:
		acc_stat = clampf(float(merc.stats.get("ranged_accuracy", 50)) / 100.0, 0.05, 1.0)
	var dmg_avg := 1.0
	if wp2 != null:
		dmg_avg = maxf(1.0, WeaponEvaluator.parse_formula_for_avg(wp2.damage_formula_1))
	var expected_dmg := acc_stat * dmg_avg
	var rounds_to_destroy := ceili(float(obs_hp) / maxf(1.0, expected_dmg))
	return rounds_to_destroy

class_name MovementDecider

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")
const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


static func decide_move(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState) -> Dictionary:
	if enemies.is_empty():
		return {"action": "", "target": null}
	var reach := _get_weapon_melee_range(mover)
	var plan := plan_moves(mover, enemies, state)
	var picked := _pick_move(mover, enemies, allies, state, int(plan["paces"]))
	if str(picked["action"]) == "":
		return picked
	#Paces already banked are not spent walking past an enemy this merc can already hit.
	if int(plan["pool"]) > 0 and str(picked["action"]) == "Move Close":
		var in_reach := closest_enemy_within(mover, enemies, reach, state)
		if in_reach != null and picked["target"] != in_reach:
			return {"action": "", "target": null}
	picked["moves_allowed"] = int(plan["moves_allowed"])
	picked["reserve_ap"] = int(plan["reserve_ap"])
	return picked


#Moves a walk may buy this turn and the AP it holds back for an Attack the walk could set up.
static func plan_moves(mover: MercenaryData, enemies: Array, state: BattleState) -> Dictionary:
	var reach := _get_weapon_melee_range(mover)
	var free: Dictionary = MovementExecutor.turn_paces(mover, state, 0)
	var reserve := 0
	if not enemies.is_empty() and _min_enemy_distance(mover, enemies, state) <= int(free["paces"]) + reach:
		reserve = state.get_cost(mover, "Attack", _CONFIG.attack_base_ap)
	var plan: Dictionary = MovementExecutor.turn_paces(mover, state, reserve)
	if int(plan["paces"]) <= 0:
		plan = free
		reserve = 0
	var moves_allowed := int(plan["moves"])
	if int(plan["pool"]) <= 0:
		moves_allowed = maxi(1, moves_allowed)
	return {"paces": int(plan["paces"]), "pool": int(plan["pool"]), "moves_allowed": moves_allowed, "reserve_ap": reserve}


static func _pick_move(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState,
		plan_paces: int) -> Dictionary:
	var is_ranged := mover.equipped_weapon != null and mover.equipped_weapon.is_ranged
	var can_fly := PathTargeter.is_flying(mover)
	var reach := _get_weapon_melee_range(mover)
	var min_enemy_dist := _min_enemy_distance(mover, enemies, state)

	if min_enemy_dist > _WEIGHTS.safe_distance:
		if should_seek_cover(mover, enemies, state) and has_ranged_enemy(enemies):
			return {"action": "", "target": null}
		var weapon := mover.equipped_weapon
		if weapon != null and weapon.is_ranged and mover.ammo_loaded == 0:
			return {"action": "", "target": null}
		if _is_safe_to_reengage(mover):
			return {"action": "Move Close", "target": closest_enemy(mover, enemies, state)}
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("AP FALLBACK: %s too hurt to re-engage at %d paces, backing off" % [
				mover.merc_name, min_enemy_dist])
		return {"action": "Move Far", "target": closest_enemy(mover, enemies, state)}

	if is_ranged:
		var close_threat := closest_enemy_within(mover, enemies, 1, state)
		if close_threat != null:
			return {"action": "Move Far", "target": close_threat}

	if is_in_danger(mover):
		var threat := _closest_reachable_enemy(mover, enemies, state)
		if threat != null:
			return {"action": "Move Far", "target": threat}

	if can_fly and is_ranged and state.battlefield != null:
		for enemy: MercenaryData in enemies:
			if state.is_covered_from(enemy, mover, ConstStates.COVERED_FULL):
				return {"action": "Move Close", "target": enemy}

	if not can_fly and is_ranged and state.battlefield != null:
		for enemy: MercenaryData in enemies:
			if state.is_covered_from(enemy, mover, ConstStates.COVERED_FULL):
				var flank_cell: Vector2i = find_flanking_cell(mover, enemy, state)
				if flank_cell != Vector2i(-1, -1):
					return {"action": "Move Close", "target": enemy,
						"goal_cell": Vector3i(flank_cell.x, flank_cell.y, state.get_floor(mover))}

	if not is_ranged:
		if closest_enemy_within(mover, enemies, reach, state) == null:
			var flank := TargetSelector.find_flankable_target(mover, enemies, allies, state)
			if flank["target"] != null:
				return {"action": "Move Close", "target": flank["target"], "flank_ally": flank["ally"]}
			return {"action": "Move Close", "target": closest_enemy(mover, enemies, state)}

	var mover_pace := maxi(1, plan_paces)
	for ally: MercenaryData in allies:
		if is_in_danger(ally):
			for enemy: MercenaryData in enemies:
				if state.distance_to(ally, enemy) <= 1 and state.distance_to(mover, enemy) <= mover_pace:
					return {"action": "Move Close", "target": enemy}

	if is_ranged and mover.ammo_loaded > 0:
		var weapon_ref := mover.equipped_weapon
		if weapon_ref != null and weapon_ref.ranged_extended_range > 0:
			var all_out_of_range := true
			for enemy: MercenaryData in enemies:
				if state.distance_to(mover, enemy) <= weapon_ref.ranged_extended_range:
					all_out_of_range = false
					break
			if all_out_of_range:
				var closest := closest_enemy(mover, enemies, state)
				if closest != null:
					return {"action": "Move Close", "target": closest}

	return {"action": "", "target": null}


#Cheapest reachable cell within pace from which the target can be seen.
static func find_flanking_cell(mover: MercenaryData, target: MercenaryData, state: BattleState) -> Vector2i:
	if state.battlefield == null:
		return Vector2i(-1, -1)
	var pace: int = maxi(1, int(MovementExecutor.turn_paces(mover, state,
		state.get_cost(mover, "Attack", _CONFIG.attack_base_ap))["paces"]))
	var mover_size: int = maxi(1, int(mover.stats.get("size", 1)))
	var reach: Dictionary = PathTargeter.reachable_for(mover, state)
	var mover_floor := state.get_floor(mover)
	var best := Vector2i(-1, -1)
	var best_cost := 0
	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		if cost <= 0 or cost > pace or cell.z != mover_floor:
			continue
		if best != Vector2i(-1, -1) and cost >= best_cost:
			continue
		if state.is_position_occupied(Vector2i(cell.x, cell.y), mover, cell.z):
			continue
		if not (LineOfSight.check_from(state, cell, 0, mover_size, target)["visible"] as bool):
			continue
		best = Vector2i(cell.x, cell.y)
		best_cost = cost
	return best



static func should_seek_cover(merc: MercenaryData, enemies: Array, state: BattleState) -> bool:
	var seen := false
	for e: MercenaryData in enemies:
		if e.equipped_weapon == null or not e.equipped_weapon.is_ranged:
			continue
		if not state.is_covered_from(merc, e, ConstStates.COVERED_FULL):
			seen = true
			break
	if not seen:
		return false
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) < _WEIGHTS.danger_hp_ratio


static func is_in_danger(merc: MercenaryData) -> bool:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) <= _WEIGHTS.danger_hp_ratio


static func _get_weapon_melee_range(merc: MercenaryData) -> int:
	var weapon := merc.equipped_weapon
	if weapon != null and not weapon.is_ranged:
		return weapon.melee_range
	return 1


static func closest_enemy_within(
		mover: MercenaryData,
		enemies: Array,
		max_dist: int,
		state: BattleState) -> MercenaryData:
	return _nearest(mover, enemies, state, max_dist)["merc"] as MercenaryData


static func _closest_reachable_enemy(
		mover: MercenaryData,
		enemies: Array,
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		var enemy_pace := maxi(MovementExecutor.pace_per_move(enemy),
			int(MovementExecutor.turn_paces(enemy, state, 0)["paces"]))
		if d <= enemy_pace and d < best_dist:
			best_dist = d
			best = enemy
	return best


#Nearest enemy of enemies, or null when enemies is empty.
static func closest_enemy(
		mover: MercenaryData,
		enemies: Array,
		state: BattleState) -> MercenaryData:
	if enemies.is_empty():
		return null
	var best: MercenaryData = _nearest(mover, enemies, state)["merc"] as MercenaryData
	return best if best != null else enemies[0]


static func _min_enemy_distance(mover: MercenaryData, enemies: Array, state: BattleState) -> int:
	return int(_nearest(mover, enemies, state)["dist"])


#Closest enemy by grid distance and that distance: {"merc", "dist"}; max_dist below 0 means no cap.
static func _nearest(mover: MercenaryData, enemies: Array, state: BattleState,
		max_dist: int = -1) -> Dictionary:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if max_dist >= 0 and d > max_dist:
			continue
		if d < best_dist:
			best_dist = d
			best = enemy
	return {"merc": best, "dist": best_dist}


static func _is_safe_to_reengage(merc: MercenaryData) -> bool:
	var max_hp := float(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / maxf(1.0, max_hp) >= 0.3 or merc.current_ep >= 1


static func has_ranged_enemy(enemies: Array) -> bool:
	for enemy: MercenaryData in enemies:
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return true
	return false

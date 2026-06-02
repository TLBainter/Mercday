class_name MovementDecider

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")


static func decide_move(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState,
		_ctx: Dictionary = {}) -> Dictionary:
	return _decide_move_action(mover, enemies, allies, state)


static func _decide_move_action(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState) -> Dictionary:
	if enemies.is_empty():
		return {"action": "", "target": null}

	var is_ranged := mover.equipped_weapon != null and mover.equipped_weapon.is_ranged
	var can_fly := int(mover.stats.get("fly", 0)) > 0 and not ConstStates.has_state(mover, ConstStates.GROUNDED)
	var reach := _get_weapon_melee_range(mover)
	var min_enemy_dist := _min_enemy_distance(mover, enemies, state)

	if min_enemy_dist > _WEIGHTS.safe_distance:
		if _should_seek_cover(mover) and _has_ranged_enemy(enemies):
			return {"action": "", "target": null}
		var weapon := mover.equipped_weapon
		if weapon != null and weapon.is_ranged and mover.ammo_loaded == 0:
			return {"action": "", "target": null}
		if _is_safe_to_reengage(mover):
			return {"action": "Move Close", "target": _closest_enemy(mover, enemies, state)}
		return {"action": "", "target": null}

	if is_ranged:
		var close_threat := _closest_enemy_within(mover, enemies, 1, state)
		if close_threat != null:
			return {"action": "Move Far", "target": close_threat}

	if _is_in_danger(mover):
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
					return {"action": "Move Close", "target": enemy}

	if not is_ranged:
		if _closest_enemy_within(mover, enemies, reach, state) == null:
			var flank := TargetSelector.find_flankable_target(mover, enemies, allies, state)
			if flank["target"] != null:
				return {"action": "Move Close", "target": flank["target"], "flank_ally": flank["ally"]}
			return {"action": "Move Close", "target": _closest_enemy(mover, enemies, state)}

	var mover_pace := int(mover.stats.get("pace", 1))
	for ally: MercenaryData in allies:
		if _is_in_danger(ally):
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
				var closest := _closest_enemy(mover, enemies, state)
				if closest != null:
					return {"action": "Move Close", "target": closest}

	return {"action": "", "target": null}


static func find_flanking_cell(mover: MercenaryData, target: MercenaryData, state: BattleState) -> Vector2i:
	if state.battlefield == null:
		return Vector2i(-1, -1)
	var cover_info := state.get_cover_info(target)
	if cover_info.is_empty():
		return Vector2i(-1, -1)
	var obs_pos := Vector2i(
		int(cover_info.get("obstacle_pos_x", -999)),
		int(cover_info.get("obstacle_pos_y", -999)))
	if obs_pos == Vector2i(-999, -999):
		return Vector2i(-1, -1)

	var mover_pos := state.get_position(mover)
	var target_pos := state.get_position(target)
	var pace := maxi(1, int(mover.stats.get("pace", 1)))
	var field := state.battlefield

	var ally_passable: Dictionary = {}
	for key: MercenaryData in state.positions.keys():
		if key != mover and BattleState._is_alive(key):
			var kp: Vector2i = state.positions[key]
			if state.get_allies(mover).has(key) and not ConstStates.has_state(key, ConstStates.DEPOSED):
				ally_passable[kp] = true
	ally_passable.merge(field.get_nav_passable_cells())

	for dx: int in range(-pace, pace + 1):
		for dy: int in range(-pace, pace + 1):
			if maxi(abs(dx), abs(dy)) > pace:
				continue
			var candidate := Vector2i(mover_pos.x + dx, mover_pos.y + dy)
			if candidate.x < 0 or candidate.x >= field.width or candidate.y < 0 or candidate.y >= field.length:
				continue
			if candidate == mover_pos:
				continue
			if _obstacle_covers_target_from(candidate, target_pos, obs_pos):
				continue
			var path := Pathfinder.find_path(mover_pos, candidate, field, ally_passable)
			if path.is_empty():
				continue
			return candidate
	return Vector2i(-1, -1)


static func _obstacle_covers_target_from(att_pos: Vector2i, target_pos: Vector2i, obs_pos: Vector2i) -> bool:
	var to_obs := Vector2(float(obs_pos.x - att_pos.x), float(obs_pos.y - att_pos.y))
	var to_target := Vector2(float(target_pos.x - att_pos.x), float(target_pos.y - att_pos.y))
	if to_obs.dot(to_target) <= 0.0:
		return false
	return to_obs.length_squared() < to_target.length_squared()


static func _should_seek_cover(merc: MercenaryData) -> bool:
	if ConstStates.has_state(merc, ConstStates.COVERED_FULL):
		return false
	if ConstStates.has_state(merc, ConstStates.COVERED_PARTIAL):
		return false
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) < _WEIGHTS.danger_hp_ratio


static func _is_in_danger(merc: MercenaryData) -> bool:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) <= _WEIGHTS.danger_hp_ratio


static func _get_weapon_melee_range(merc: MercenaryData) -> int:
	var weapon := merc.equipped_weapon
	if weapon != null and not weapon.is_ranged:
		return weapon.melee_range
	return 1


static func _closest_enemy_within(
		mover: MercenaryData,
		enemies: Array,
		max_dist: int,
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := max_dist + 1
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d <= max_dist and d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _closest_reachable_enemy(
		mover: MercenaryData,
		enemies: Array,
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		var enemy_pace := int(enemy.stats.get("pace", 1))
		if d <= enemy_pace and d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _closest_enemy(
		mover: MercenaryData,
		enemies: Array,
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best if best != null else enemies[0]


static func _min_enemy_distance(mover: MercenaryData, enemies: Array, state: BattleState) -> int:
	var min_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d < min_dist:
			min_dist = d
	return min_dist


static func _is_safe_to_reengage(merc: MercenaryData) -> bool:
	var max_hp := float(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / maxf(1.0, max_hp) >= 0.3 or merc.current_ep >= 1


static func _has_ranged_enemy(enemies: Array) -> bool:
	for enemy: MercenaryData in enemies:
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return true
	return false

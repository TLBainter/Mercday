class_name MovementExecutor

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static var _turn_path_cache: Dictionary = {}
static var _blocked_path_goals: Dictionary = {}
static var _near_passable_cache: Dictionary = {}
static var last_move_heavy: bool = false


static func clear_caches() -> void:
	_turn_path_cache.clear()
	_blocked_path_goals.clear()
	_near_passable_cache.clear()
	last_move_heavy = false


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


static func get_weapon_enhance_bonus(merc: MercenaryData) -> int:
	var total: int = 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_enhance:"):
			var value_str: String = perk.effect_dsl.substr(len("weapon_enhance:"))
			total += value_str.to_int()
	return total


static func _get_dead_body_at(pos: Vector2i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if m.current_hp < 0 and state.positions[m] == pos:
			return m
	return null


static func _get_deposed_merc_at(pos: Vector2i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if BattleState._is_alive(m) and ConstStates.has_state(m, ConstStates.DEPOSED) and state.positions[m] == pos:
			return m
	return null


static func _get_standing_ally_at(pos: Vector2i, merc: MercenaryData, state: BattleState) -> MercenaryData:
	for ally: MercenaryData in state.get_allies(merc):
		if BattleState._is_alive(ally) \
				and not ConstStates.has_state(ally, ConstStates.DEPOSED) \
				and state.positions.get(ally) == pos:
			return ally
	return null


static func compute_attack_flaws(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> int:
	if state.battlefield == null:
		return 0
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return 0
	var dist := state.distance_to(attacker, target)
	var ignore_ext_range: bool = WeaponArmorPerkLibrary.has_weapon_passive(attacker, "weapon_passive:ignore_flaw_extended_range")
	if weapon.is_ranged and weapon.ranged_intended_range > 0:
		if dist > weapon.ranged_intended_range and not ignore_ext_range:
			return 1
	elif weapon.is_throwable:
		var merc_thrown_range := WeaponEvaluator.compute_thrown_range(attacker, weapon)
		var thrown_range_bonus: int = attacker.active_states.get("thrown_extended_range_bonus", 0)
		if weapon.range_thrown == "":
			var max_dist := int(merc_thrown_range / 2.0)
			if dist > max_dist:
				return 10
			return 1
		else:
			var effective_max := mini(weapon.thrown_extended_range, merc_thrown_range) + thrown_range_bonus
			if dist > effective_max:
				return 10
			if weapon.thrown_intended_range > 0 and not ignore_ext_range:
				var effective_intended := mini(weapon.thrown_intended_range, merc_thrown_range)
				if dist > effective_intended + thrown_range_bonus:
					return 1
	return 0


static func position_has_cover_from(
		pos: Vector2i,
		ranged_enemies: Array[MercenaryData],
		state: BattleState) -> bool:
	var field := state.battlefield
	for obs: Dictionary in field.get_adjacent_obstacles(pos):
		var obs_pos: Vector2i = obs["pos"]
		var cover_dir := Vector2i(signi(obs_pos.x - pos.x), signi(obs_pos.y - pos.y))
		for enemy: MercenaryData in ranged_enemies:
			var ep := state.get_position(enemy)
			var atk_dir := Vector2i(signi(ep.x - pos.x), signi(ep.y - pos.y))
			var covered := true
			if cover_dir.x != 0 and cover_dir.x != atk_dir.x:
				covered = false
			if cover_dir.y != 0 and cover_dir.y != atk_dir.y:
				covered = false
			if covered:
				return true
	return false


static func nearest_passable_to(pos: Vector2i, field: BattlefieldArea,
		p_fall_tolerance: float = 1.0, p_can_climb: bool = false,
		p_excluded: Dictionary = {}) -> Vector2i:
	var cardinals: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	]
	var all_dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var _is_passable := func(cell: Vector2i) -> bool:
		for cd: Vector2i in cardinals:
			var nb: Vector2i = cell + cd
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if Pathfinder.cell_pace_cost(nb, cell, field, {}, p_fall_tolerance, false, p_can_climb) >= 0:
				return true
		return false

	if _is_passable.call(pos) and not p_excluded.has(pos):
		return pos

	var visited: Dictionary = {pos: true}
	var queue: Array[Vector2i] = [pos]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in all_dirs:
			var nb: Vector2i = curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if _is_passable.call(nb) and not p_excluded.has(nb):
				return nb
			if maxi(abs(nb.x - pos.x), abs(nb.y - pos.y)) < 3:
				queue.append(nb)
	return pos


static func compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Vector2i:
	var from := state.get_position(merc)
	var to := state.get_position(move_target)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)
	var field := state.battlefield

	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return from

	var step := Vector2i(signi(dx), signi(dy))

	if action_name == "Move Far":
		if field == null:
			return from

		var _pre_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
		if _pre_goal != Vector2i(-1, -1):
			if state.is_position_occupied(_pre_goal, merc) or field.is_obstacle(_pre_goal):
				state.move_goals.erase(merc)

		var all_enemies_mf := state.get_enemies(merc)
		var allies_mf := state.get_allies(merc)
		var max_ally_dist: int = 20

		var retreat_dirs: Array[Vector2i] = [
			Vector2i(-step.x, -step.y),
			Vector2i(-step.x, 0), Vector2i(0, -step.y),
			Vector2i(-step.x, step.y), Vector2i(step.x, -step.y),
			Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
		]
		var candidates: Array[Vector2i] = []
		for rd: Vector2i in retreat_dirs:
			if rd == Vector2i.ZERO:
				continue
			candidates.append(field.clamp_position(from + rd * pace))
			if pace > 1:
				candidates.append(field.clamp_position(from + rd * (pace >> 1)))

		var _seen_mf: Dictionary = {}
		var unique_candidates: Array[Vector2i] = []
		for c: Vector2i in candidates:
			if c == from or _seen_mf.has(c):
				continue
			_seen_mf[c] = true
			unique_candidates.append(c)

		var _scored_mf: Array[Dictionary] = []
		for candidate: Vector2i in unique_candidates:
			if not allies_mf.is_empty():
				var closest_ally_d := 999999
				for ally: MercenaryData in allies_mf:
					var ally_pos := state.get_position(ally)
					var d := maxi(abs(candidate.x - ally_pos.x), abs(candidate.y - ally_pos.y))
					if d < closest_ally_d:
						closest_ally_d = d
				if closest_ally_d > max_ally_dist:
					continue

			var nearest_enemy_dist: float = INF
			for e: MercenaryData in all_enemies_mf:
				var ep := state.get_position(e)
				var d: float = float(maxi(absi(candidate.x - ep.x), absi(candidate.y - ep.y)))
				if d < nearest_enemy_dist:
					nearest_enemy_dist = d

			var cover_count: float = 0.0
			for obs: Dictionary in field.obstacles:
				if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
					continue
				var obs_data_mf: ObstacleData = obs.get("data") as ObstacleData
				if obs_data_mf != null and not obs_data_mf.covers:
					continue
				var op: Vector2i = obs["pos"] as Vector2i
				if maxi(absi(op.x - candidate.x), absi(op.y - candidate.y)) <= 2:
					cover_count += 1.0

			var edge_penalty: float = 0.0
			if candidate.x < 3 or candidate.x >= field.width - 3 \
					or candidate.y < 3 or candidate.y >= field.length - 3:
				edge_penalty = 2.0

			var los_bonus := 0.0
			if valid_targets.is_empty() and merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
				for enemy_mf: MercenaryData in enemies:
					if not state.is_covered_from_pos(enemy_mf, candidate):
						los_bonus = 1.5
						break

			var height_bonus := 0.0
			var merc_h := field.get_terrain_height(from)
			var candidate_h := field.get_terrain_height(candidate)
			height_bonus = clampf(float(candidate_h - merc_h) * 0.5, 0.0, 1.0)

			var last_from_penalty := 0.0
			var _esc_mf: Dictionary = state.escalation.get(merc, {}) as Dictionary
			var _last_from: Vector2i = _esc_mf.get("last_move_from", Vector2i(-1, -1)) as Vector2i
			if _last_from != Vector2i(-1, -1) and candidate == _last_from:
				last_from_penalty = 2.0

			var goal_bonus := 0.0
			var _stored_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
			if _stored_goal != Vector2i(-1, -1) and candidate == _stored_goal:
				goal_bonus = 1.5

			var score: float = nearest_enemy_dist * 1.0 + cover_count * 1.5 - edge_penalty + los_bonus + height_bonus - last_from_penalty + goal_bonus
			_scored_mf.append({"pos": candidate, "score": score})

		_scored_mf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))

		if _scored_mf.is_empty():
			return field.clamp_position(from - step * pace)

		var _hp_ratio_mf: float = clampf(float(merc.current_hp) / float(merc.stats.get("maximum_hit_points", 1)), 0.1, 1.0)
		var _best_break_fall_mf: float = maxf(
			clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
			clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
		var fall_tolerance_mf: float = clampf(_hp_ratio_mf + _best_break_fall_mf, 0.2, 2.0)
		var ally_passable_mf: Dictionary
		if state.turn_ally_passable.has(merc):
			ally_passable_mf = state.turn_ally_passable[merc] as Dictionary
		else:
			ally_passable_mf = {}
			for _ally_mf: MercenaryData in allies_mf:
				if BattleState._is_alive(_ally_mf) and not ConstStates.has_state(_ally_mf, ConstStates.DEPOSED):
					var _ap_mf: Vector2i = state.positions.get(_ally_mf, Vector2i(-1, -1))
					if _ap_mf != Vector2i(-1, -1):
						ally_passable_mf[_ap_mf] = true
			ally_passable_mf.merge(field.get_nav_passable_cells())

		var _chosen_mf := Vector2i(-1, -1)
		for entry: Dictionary in _scored_mf:
			var candidate: Vector2i = entry["pos"] as Vector2i
			if not Pathfinder.find_path(from, candidate, field, ally_passable_mf, fall_tolerance_mf).is_empty():
				_chosen_mf = candidate
				break
		if _chosen_mf == Vector2i(-1, -1):
			_chosen_mf = _scored_mf[0]["pos"] as Vector2i

		var _existing_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
		if _existing_goal != Vector2i(-1, -1) and _existing_goal != _chosen_mf:
			var _goal_entry_mf: Dictionary = {}
			for _e: Dictionary in _scored_mf:
				if (_e["pos"] as Vector2i) == _existing_goal:
					_goal_entry_mf = _e
					break
			var _best_score: float = float(_scored_mf[0]["score"])
			var _goal_score: float = float(_goal_entry_mf.get("score", -INF))
			if _best_score - _goal_score > 2.0:
				state.move_goals[merc] = _chosen_mf
		else:
			state.move_goals[merc] = _chosen_mf

		return _chosen_mf

	var stop_dist := _CONFIG.melee_range
	if stop_dist_override >= 0:
		stop_dist = stop_dist_override
	else:
		var weapon := merc.equipped_weapon
		if weapon != null:
			if not weapon.is_ranged:
				stop_dist = weapon.melee_range
			elif weapon.ranged_intended_range > 0:
				if action_name == "Move Close":
					stop_dist = _CONFIG.melee_range
				else:
					stop_dist = weapon.ranged_intended_range
		if state.get_allies(merc).has(move_target):
			stop_dist = 0

	if flank_ally != null:
		var ally_pos := state.get_position(flank_ally)
		var flank_step := Vector2i(signi(to.x - ally_pos.x), signi(to.y - ally_pos.y))
		if flank_step != Vector2i.ZERO:
			var flank_target := to + flank_step * stop_dist
			dx = flank_target.x - from.x
			dy = flank_target.y - from.y
			step = Vector2i(signi(dx), signi(dy))

	var dist_to_target: int
	if flank_ally == null and field != null:
		dist_to_target = state.distance_to(merc, move_target)
	else:
		dist_to_target = maxi(abs(dx), abs(dy))
	var max_steps := maxi(0, dist_to_target - stop_dist)
	var actual_steps := mini(pace, max_steps)
	if actual_steps == 0:
		return from
	if valid_targets.is_empty() and not enemies.is_empty() and field != null:
		var _perp := Vector2i(-step.y, step.x)
		for _fk_dir: Vector2i in [_perp, Vector2i(-_perp.x, -_perp.y)]:
			var _fk := field.clamp_position(to + _fk_dir)
			if _fk != from and _fk != to:
				return _fk
	var ranged_enemies: Array[MercenaryData] = []
	for e: MercenaryData in state.get_enemies(merc):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)
	if not ranged_enemies.is_empty():
		for s: int in range(actual_steps, 0, -1):
			var candidate := field.clamp_position(from + step * s)
			if position_has_cover_from(candidate, ranged_enemies, state):
				return candidate
	return field.clamp_position(from + step * actual_steps)


static func execute_move(
		merc: MercenaryData,
		action_name: String,
		move_target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		enhancements: int = 0,
		stop_dist_override: int = -1,
		seeking: bool = false,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Array[String]:
	if move_target == null:
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []

	var old_pos := state.get_position(merc)
	var goal := compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override, valid_targets, enemies)
	if goal == old_pos:
		return []
	var new_pos := goal
	var path_harms: Array[Dictionary] = []
	var body_traverse_lines: Array[String] = []
	var field := state.battlefield
	if field != null:
		var _hp_ratio: float = clampf(float(merc.current_hp) / float(merc.stats.get("maximum_hit_points", 1)), 0.1, 1.0)
		var _best_break_fall: float = maxf(
			clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
			clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
		var fall_tolerance: float = clampf(_hp_ratio + _best_break_fall, 0.2, 2.0)
		var can_climb: bool = int(merc.stats.get("size", 0)) > 0
		var jump_stat: int = int(merc.stats.get("jump", 0))
		var _raw_goal := goal
		var _npc_key: Array = [_raw_goal, int(fall_tolerance * 10), int(can_climb)]
		if _near_passable_cache.has(_npc_key):
			goal = _near_passable_cache[_npc_key] as Vector2i
		else:
			goal = nearest_passable_to(_raw_goal, field, fall_tolerance, can_climb)
			_near_passable_cache[_npc_key] = goal
		if _blocked_path_goals.has(goal):
			if (_blocked_path_goals[goal] as int) >= state.round_number:
				var _excl: Dictionary = {}
				for _bg: Vector2i in _blocked_path_goals:
					if (_blocked_path_goals[_bg] as int) >= state.round_number:
						_excl[_bg] = true
				var _alt := nearest_passable_to(_raw_goal, field, fall_tolerance, can_climb, _excl)
				if _alt != goal:
					goal = _alt
					state.move_goals[merc] = goal
				else:
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("MOVE BLOCKED: %s goal=(%d,%d) no alt" % [merc.merc_name, goal.x, goal.y])
					return []
			else:
				_blocked_path_goals.erase(goal)
		var ally_passable: Dictionary
		if state.turn_ally_passable.has(merc):
			ally_passable = state.turn_ally_passable[merc] as Dictionary
		else:
			ally_passable = {}
			for _ally: MercenaryData in state.get_allies(merc):
				if BattleState._is_alive(_ally) and not ConstStates.has_state(_ally, ConstStates.DEPOSED):
					var _ap: Vector2i = state.positions.get(_ally, Vector2i(-1, -1))
					if _ap != Vector2i(-1, -1):
						ally_passable[_ap] = true
			ally_passable.merge(field.get_nav_passable_cells())
		var path: Array[Vector2i] = []
		var path_start_idx := 0
		if not seeking:
			var _cached_tp = _turn_path_cache.get(merc)
			if _cached_tp != null:
				var _ctp := _cached_tp as Dictionary
				if (_ctp.get("goal") as Vector2i) == goal:
					var _cpath: Array[Vector2i] = _ctp.get("path", []) as Array[Vector2i]
					var _cidx: int = _ctp.get("idx", 0)
					for _cj in range(_cidx, _cpath.size()):
						if _cpath[_cj] == old_pos:
							path = _cpath
							path_start_idx = _cj
							break
		if path.is_empty():
			path = Pathfinder.find_path(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb)
			if path.is_empty():
				if seeking:
					var seek_path := Pathfinder.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
					if not seek_path.is_empty():
						path = seek_path
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("SEEK MOVE: partial path (%d,%d)->(%d,%d) advancing to (%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y,
								seek_path[-1].x, seek_path[-1].y])
					else:
						new_pos = old_pos
						_blocked_path_goals[goal] = state.round_number
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("SEEK MOVE BLOCKED: no reachable cell toward (%d,%d)" % [goal.x, goal.y])
				else:
					var toward_path := Pathfinder.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
					if not toward_path.is_empty():
						path = toward_path
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("MOVE PARTIAL: no exact path (%d,%d)->(%d,%d), advancing to (%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y,
								toward_path[-1].x, toward_path[-1].y])
					else:
						var _alt_path: Array[Vector2i] = []
						var _alt_best_dist := 999999
						var _dirs8: Array[Vector2i] = [
							Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
							Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
						for _ad: Vector2i in _dirs8:
							var _ag: Vector2i = _raw_goal + _ad
							if _ag.x < 0 or _ag.x >= field.width or _ag.y < 0 or _ag.y >= field.length:
								continue
							if _blocked_path_goals.has(_ag) and (_blocked_path_goals[_ag] as int) >= state.round_number:
								continue
							var _ap: Array[Vector2i] = Pathfinder.find_path_toward(old_pos, _ag, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
							if not _ap.is_empty():
								var _ad_dist := maxi(abs(_ap[-1].x - _raw_goal.x), abs(_ap[-1].y - _raw_goal.y))
								if _ad_dist < _alt_best_dist:
									_alt_best_dist = _ad_dist
									_alt_path = _ap
						if not _alt_path.is_empty():
							path = _alt_path
							if EncounterLogger.is_active():
								EncounterLogger.log_verbose("MOVE REROUTED: (%d,%d)->(%d,%d) blocked, advancing via (%d,%d)" % [
									old_pos.x, old_pos.y, goal.x, goal.y, _alt_path[-1].x, _alt_path[-1].y])
						else:
							new_pos = old_pos
							var _static_path := Pathfinder.find_path_toward(
								old_pos, _raw_goal, field, field.get_nav_passable_cells(),
								fall_tolerance, false, can_climb, jump_stat)
							_blocked_path_goals[goal] = state.round_number + (1000 if _static_path.is_empty() else 0)
							if _static_path.is_empty():
								merc.active_states["_move_blocked_round"] = state.round_number
							if EncounterLogger.is_active():
								EncounterLogger.log_verbose("MOVE BLOCKED: no path (%d,%d)->(%d,%d)" % [
									old_pos.x, old_pos.y, goal.x, goal.y])
			if not path.is_empty() and not seeking:
				_turn_path_cache[merc] = {"goal": goal, "path": path, "idx": 0}
		if not path.is_empty() and path.size() > path_start_idx + 1:
			var pace := maxi(1, int(merc.stats.get("pace", 1)))
			if ConstStates.has_state(merc, ConstStates.DEPOSED):
				pace = mini(pace, 1)
			var budget := pace
			var last := old_pos
			var traversed: Array[Vector2i] = [old_pos]
			var merc_size := int(merc.stats.get("size", 1))
			for i: int in range(path_start_idx + 1, path.size()):
				var from_cell: Vector2i = path[i - 1]
				var cell: Vector2i = path[i]
				var cost := Pathfinder.cell_pace_cost(from_cell, cell, field, {}, fall_tolerance, false, can_climb)
				if cost < 0:
					break
				var _cell_d := maxi(abs(cell.x - goal.x), abs(cell.y - goal.y))
				var _from_d := maxi(abs(from_cell.x - goal.x), abs(from_cell.y - goal.y))
				if _cell_d > _from_d:
					cost += 1
				var dead_body := _get_dead_body_at(from_cell, state)
				if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
					cost += 1
				var deposed_merc := _get_deposed_merc_at(from_cell, state)
				if deposed_merc != null and int(deposed_merc.stats.get("size", 1)) >= merc_size:
					cost += 1
				if budget - cost < 0:
					break
				budget -= cost
				if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
					body_traverse_lines.append("  %s moves through the body of %s." % [_cn(merc, state), dead_body.merc_name])
				if deposed_merc != null:
					body_traverse_lines.append("  %s steps over the prone %s." % [_cn(merc, state), deposed_merc.merc_name])
				var traversed_ally := _get_standing_ally_at(from_cell, merc, state)
				if traversed_ally != null:
					body_traverse_lines.append("  %s passes through %s's position." % [_cn(merc, state), traversed_ally.merc_name])
				last = cell
				traversed.append(cell)
				var path_obs: Dictionary = field.get_obstacle_at(cell)
				if not path_obs.is_empty():
					var d: ObstacleData = path_obs.get("data") as ObstacleData
					if d != null and d.passthrough and d.pt_enter_harm > 0:
						path_harms.append({"damage": d.pt_enter_harm, "type": d.pt_harm_type, "name": d.obstacle_name})
			for k: int in range(traversed.size() - 1, 0, -1):
				if not state.is_position_occupied(traversed[k], merc):
					last = traversed[k]
					break
			new_pos = last
			if _turn_path_cache.has(merc):
				var _cti: int = path_start_idx
				for _ctj in range(path_start_idx, path.size()):
					if path[_ctj] == new_pos:
						_cti = _ctj
						break
				(_turn_path_cache[merc] as Dictionary)["idx"] = _cti
			if EncounterLogger.is_active() and traversed.size() > 1:
				var parts: Array[String] = []
				for c: Vector2i in traversed:
					parts.append("(%d,%d)" % [c.x, c.y])
				EncounterLogger.log_verbose("MOVE PATH: %s  budget %d/%d used" % [
					" -> ".join(parts), pace - budget, pace])

	if new_pos == old_pos:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE STALLED: %s goal=(%d,%d) no viable path" % [merc.merc_name, goal.x, goal.y])
		_blocked_path_goals[goal] = state.round_number + 3
		return []

	if not seeking:
		var _hist: Array = state.position_history.get(merc, []) as Array
		if _hist.has(new_pos):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION BLOCKED: %s would return to recently visited (%d,%d)" % [
					merc.merc_name, new_pos.x, new_pos.y])
			var _flank_ok := false
			if field != null:
				var _enemy_pos: Vector2i = state.get_position(move_target)
				var _delta := Vector2i(_enemy_pos.x - old_pos.x, _enemy_pos.y - old_pos.y)
				var _len_f := maxf(1.0, Vector2(float(_delta.x), float(_delta.y)).length())
				var _perp := Vector2i(roundi(-float(_delta.y) / _len_f * 4.0), roundi(float(_delta.x) / _len_f * 4.0))
				var _ally_pass: Dictionary = state.turn_ally_passable.get(merc, {}) as Dictionary
				var _fall_tol: float = clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))) + maxf(
					clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
					clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0)), 0.2, 2.0)
				var _can_cl: bool = int(merc.stats.get("size", 0)) > 0
				var _jmp: int = int(merc.stats.get("jump", 0))
				last_move_heavy = true
				for _side: int in [1, -1]:
					var _fg := field.clamp_position(_enemy_pos + _perp * _side)
					var _fp := Pathfinder.find_path_toward(old_pos, _fg, field, _ally_pass, _fall_tol, false, _can_cl, _jmp)
					if _fp.is_empty():
						continue
					var _fb := maxi(1, int(merc.stats.get("pace", 1)))
					if ConstStates.has_state(merc, ConstStates.DEPOSED):
						_fb = mini(_fb, 1)
					var _fn := old_pos
					var _ft: Array[Vector2i] = [old_pos]
					for _fi: int in range(1, _fp.size()):
						var _fc := Pathfinder.cell_pace_cost(_fp[_fi - 1], _fp[_fi], field, {}, _fall_tol, false, _can_cl)
						if _fc < 0 or _fb - _fc < 0:
							break
						_fb -= _fc
						_ft.append(_fp[_fi])
						_fn = _fp[_fi]
					if _fn == old_pos or _hist.has(_fn):
						continue
					new_pos = _fn
					body_traverse_lines.clear()
					_flank_ok = true
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("OSCILLATION FLANK: %s flanking to (%d,%d)" % [merc.merc_name, new_pos.x, new_pos.y])
					break
			if not _flank_ok:
				_blocked_path_goals[goal] = state.round_number
				return []

	var move_cost := state.get_cost(merc, action_name, _CONFIG.move_base_ap)
	state.spend_ap(merc, move_cost)
	state.record_action(merc, action_name)

	var move_lines: Array[String] = []

	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, new_pos, state)
	for entry in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := compute_attack_flaws(reactor, merc, state)
		var weapon_enh := get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		move_lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			move_lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			move_lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			move_lines.append_array(CombatApplicator.apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			move_lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])

	var old_terrain_pos := old_pos
	state.escalation[merc]["last_move_from"] = old_pos
	state.set_position(merc, new_pos)
	merc.aim_active = false
	state.clear_cover(merc)

	var _goal_after_move: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
	if _goal_after_move != Vector2i(-1, -1) and new_pos == _goal_after_move:
		state.move_goals.erase(merc)

	if field != null:
		var old_h := state.get_height(merc)
		var new_h := int(round(field.get_terrain_height(new_pos)))
		state.set_height(merc, new_h)
		if new_h != old_h and EncounterLogger.is_active():
			EncounterLogger.log_verbose("HEIGHT SYNC: %s terrain elevation h%d -> h%d at (%d,%d)" % [
				merc.merc_name, old_h, new_h, new_pos.x, new_pos.y])

	if field != null:
		var terrain_drop := field.get_terrain_height(old_terrain_pos) - field.get_terrain_height(new_pos)
		if terrain_drop >= 1.0:
			move_lines.append_array(CombatApplicator.resolve_fall(merc, int(floor(terrain_drop)), state))

	move_lines.append_array(body_traverse_lines)
	for harm: Dictionary in path_harms:
		move_lines.append("  %s moves through %s." % [_cn(merc, state), harm["name"]])
		move_lines.append_array(CombatApplicator.apply_damage(merc, merc, harm["damage"], harm["type"], state))

	var arrow := "<-" if action_name == "Move Far" else "->"
	move_lines.append("  %s %s %s ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), arrow, _cn(move_target, state),
		old_pos.x, old_pos.y, new_pos.x, new_pos.y])

	var can_fly := int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED)
	if can_fly and state.battlefield != null:
		var pace := maxi(1, int(merc.stats.get("pace", 1)))
		var horiz_steps := maxi(abs(old_pos.x - new_pos.x), abs(old_pos.y - new_pos.y))
		var remaining_pace := maxi(0, pace - horiz_steps)
		if remaining_pace > 0:
			var current_h := state.get_height(merc)
			var target_h := current_h
			if action_name == "Move Close":
				var cover_info := state.get_cover_info(move_target)
				if not cover_info.is_empty():
					var obs_x: int = int(cover_info.get("obstacle_pos_x", 0))
					var obs_y: int = int(cover_info.get("obstacle_pos_y", 0))
					var obs_size: int = int(cover_info.get("obstacle_size", 0))
					var horiz_to_obs := maxi(abs(new_pos.x - obs_x), abs(new_pos.y - obs_y))
					target_h = obs_size + horiz_to_obs + 1
			var delta := mini(remaining_pace, maxi(0, target_h - current_h))
			if delta > 0:
				state.set_height(merc, current_h + delta)
				move_lines.append("  %s ascends to height %d." % [_cn(merc, state), state.get_height(merc)])

	return move_lines


static func execute_jump(
		merc: MercenaryData,
		jump_target_pos: Vector2i,
		action_name: String,
		state: BattleState,
		enhancements: int = 0) -> Array[String]:
	if jump_target_pos == Vector2i(-1, -1):
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []
	if state.is_position_occupied(jump_target_pos, merc):
		return []

	var lines: Array[String] = []
	var old_pos := state.get_position(merc)
	var field := state.battlefield

	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, jump_target_pos, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def: ActionData = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := compute_attack_flaws(reactor, merc, state)
		var weapon_enh := get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			lines.append_array(CombatApplicator.apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])

	state.spend_ap(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap))
	state.record_action(merc, action_name)
	state.set_position(merc, jump_target_pos)
	merc.aim_active = false
	state.clear_cover(merc)

	if field != null:
		var new_h := int(round(field.get_terrain_height(jump_target_pos)))
		state.set_height(merc, new_h)
		var terrain_drop := field.get_terrain_height(old_pos) - field.get_terrain_height(jump_target_pos)
		if terrain_drop >= 1.0:
			lines.append_array(CombatApplicator.resolve_fall(merc, int(floor(terrain_drop)), state))

	lines.append("  %s leaps! ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), old_pos.x, old_pos.y, jump_target_pos.x, jump_target_pos.y])

	return lines


static func execute_climb(
		merc: MercenaryData,
		decision: Dictionary,
		action_name: String,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var field := state.battlefield
	var is_continuing: bool = ConstStates.has_state(merc, ConstStates.CLIMBING)

	if not is_continuing:
		var target_pos: Vector2i = decision.get("climb_target_pos", Vector2i(-1, -1))
		if target_pos == Vector2i(-1, -1) or field == null:
			return []
		var merc_size := int(merc.stats.get("size", 0))
		if merc_size <= 0:
			return []
		var init_target_h := int(round(field.get_terrain_height(target_pos)))
		var merc_floor_h := int(round(field.get_terrain_height(state.get_position(merc))))
		if init_target_h <= merc_floor_h:
			var _obs := field.get_obstacle_at(target_pos)
			if not _obs.is_empty() and _obs.get("cell_type", "") == "wall":
				init_target_h = merc_floor_h + 2
		var grab_h := merc_size
		state.set_climbing_data(merc, {
			"wall_pos": target_pos,
			"current_h": grab_h,
			"target_h": init_target_h,
			"top_pos": target_pos,
		})
		ConstStates.apply_state(merc, ConstStates.CLIMBING)
		state.set_height(merc, grab_h)
		state.spend_ap(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap))
		state.record_action(merc, action_name)
		merc.aim_active = false
		state.clear_cover(merc)
		lines.append("  %s grabs the wall and begins climbing! (h%d/%d)" % [
			_cn(merc, state), grab_h, init_target_h])
		if grab_h >= init_target_h:
			_complete_climb(merc, state, lines)
		return lines

	var cd: Dictionary = state.get_climbing_data(merc)
	var current_h := int(cd.get("current_h", 0))
	var target_h := int(cd.get("target_h", 0))

	var has_climb_stat := int(merc.stats.get("climb", 0)) > 0
	var has_athletics: bool = merc.circumstance_flags.get(ConstCircumstances.ATHLETICS_VIGOR, false)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var climb_budget: int
	if has_climb_stat:
		climb_budget = pace
	elif has_athletics:
		climb_budget = 2
	else:
		climb_budget = 1
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		climb_budget = mini(climb_budget, 1)

	var new_h := mini(current_h + climb_budget, target_h)
	cd["current_h"] = new_h
	state.set_climbing_data(merc, cd)
	state.set_height(merc, new_h)

	state.spend_ap(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap))
	state.record_action(merc, action_name)
	merc.aim_active = false
	state.clear_cover(merc)

	if new_h >= target_h:
		_complete_climb(merc, state, lines)
	else:
		lines.append("  %s climbs to height %d/%d." % [_cn(merc, state), new_h, target_h])
	return lines


static func _complete_climb(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var cd: Dictionary = state.get_climbing_data(merc)
	var top_pos: Vector2i = cd.get("top_pos", state.get_position(merc)) as Vector2i
	var pit_pos := state.get_position(merc)
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	if state.battlefield != null:
		var _obs := state.battlefield.get_obstacle_at(top_pos)
		if not _obs.is_empty() and _obs.get("cell_type", "") == "wall":
			var wall_pos: Vector2i = cd.get("wall_pos", top_pos) as Vector2i
			var _dir := Vector2i(signi(wall_pos.x - pit_pos.x), signi(wall_pos.y - pit_pos.y))
			var _beyond := wall_pos + _dir
			if state.battlefield.get_nav_passable_cells().has(_beyond) and not state.is_position_occupied(_beyond, merc):
				top_pos = _beyond
	if not state.is_position_occupied(top_pos, merc):
		state.set_position(merc, top_pos)
	if state.battlefield != null:
		state.set_height(merc, int(round(state.battlefield.get_terrain_height(top_pos))))
	lines.append("  %s hauls themselves up!" % _cn(merc, state))


static func execute_move_to_pos(
		merc: MercenaryData,
		target_pos: Vector2i,
		state: BattleState,
		enhancements: int = 0) -> Array[String]:
	if state.battlefield == null:
		return []
	var old_pos := state.get_position(merc)
	if old_pos == target_pos:
		return []
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)
	var dx := target_pos.x - old_pos.x
	var dy := target_pos.y - old_pos.y
	var step := Vector2i(signi(dx), signi(dy))
	var dist := maxi(abs(dx), abs(dy))
	var steps := mini(pace, dist)
	var new_pos := state.battlefield.clamp_position(old_pos + step * steps)
	if new_pos == old_pos:
		return []
	while new_pos != old_pos and state.is_position_occupied(new_pos, merc):
		steps -= 1
		if steps <= 0:
			return []
		new_pos = state.battlefield.clamp_position(old_pos + step * steps)
	if state.is_position_occupied(new_pos, merc):
		return []
	var move_cost := state.get_cost(merc, "Move Close", _CONFIG.move_base_ap)
	state.spend_ap(merc, move_cost)
	state.record_action(merc, "Move Close")
	var move_lines: Array[String] = []
	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, new_pos, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def: ActionData = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := compute_attack_flaws(reactor, merc, state)
		var weapon_enh := get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		move_lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			move_lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			move_lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			move_lines.append_array(CombatApplicator.apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			move_lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])
	state.set_position(merc, new_pos)
	merc.aim_active = false
	state.clear_cover(merc)
	move_lines.append("  %s -> weapon ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), old_pos.x, old_pos.y, new_pos.x, new_pos.y])
	return move_lines

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


static func compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Vector2i:
	if action_name == "Move Far":
		return PathTargeter.best_retreat_cell(merc, enemies, state, move_target, valid_targets, state.get_floor(merc))
	return PathTargeter.best_approach_cell(merc, move_target, state, flank_ally, stop_dist_override, valid_targets, enemies, state.get_floor(merc))


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
	var _known_enemies: Dictionary = merc.last_known_enemy_positions.duplicate()
	var goal := compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override, valid_targets, enemies)
	if goal == Vector2i(-1, -1):
		var _mb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
		_mb[move_target] = true
		state.movement_blocked[merc] = _mb
		merc.active_states["_move_blocked_round"] = state.round_number
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE BLOCKED: %s no reachable cell near %s" % [merc.merc_name, move_target.merc_name])
		return []
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
		var can_climb: bool = true
		var jump_stat: int = int(merc.stats.get("jump", 0))
		var _raw_goal := goal
		var _npc_key: Array = [_raw_goal, int(fall_tolerance * 10), int(can_climb)]
		if _near_passable_cache.has(_npc_key):
			goal = _near_passable_cache[_npc_key] as Vector2i
		else:
			goal = PathHelper.nearest_passable_to(_raw_goal, field, fall_tolerance, can_climb)
			_near_passable_cache[_npc_key] = goal
		if _blocked_path_goals.has(goal):
			if (_blocked_path_goals[goal] as int) >= state.round_number:
				var _excl: Dictionary = {}
				for _bg: Vector2i in _blocked_path_goals:
					if (_blocked_path_goals[_bg] as int) >= state.round_number:
						_excl[_bg] = true
				var _alt: Vector2i = PathHelper.nearest_passable_to(_raw_goal, field, fall_tolerance, can_climb, _excl)
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
					var seek_path := PathHelper.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
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
					var toward_path := PathHelper.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
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
							var _ap: Array[Vector2i] = PathHelper.find_path_toward(old_pos, _ag, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
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
							var _static_path := PathHelper.find_path_toward(
								old_pos, _raw_goal, field, field.get_nav_passable_cells(),
								fall_tolerance, false, can_climb, jump_stat)
							_blocked_path_goals[goal] = state.round_number + (1000 if _static_path.is_empty() else 0)
							if _static_path.is_empty():
								merc.active_states["_move_blocked_round"] = state.round_number
								var _mb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
								_mb[move_target] = true
								state.movement_blocked[merc] = _mb
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
			var _start_flanked := PathTargeter.is_flanked_by_known(old_pos, _known_enemies)
			var _flanked_abort_fired := false
			var _flanked_abort_cell := Vector2i(-1, -1)
			for i: int in range(path_start_idx + 1, path.size()):
				var from_cell: Vector2i = path[i - 1]
				var cell: Vector2i = path[i]
				var cost := PathCost.cell_pace_cost(from_cell, cell, field, ally_passable, fall_tolerance, false, can_climb, state.get_floor(merc))
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
				if budget - cost < 0 and traversed.size() > 1:
					break
				budget -= cost
				if cell != goal and not _start_flanked and PathTargeter.is_flanked_by_known(cell, _known_enemies):
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("[MOVE] flanked-abort: %s at (%d,%d)" % [merc.merc_name, cell.x, cell.y])
					_flanked_abort_cell = cell
					_flanked_abort_fired = true
					break
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
			if _flanked_abort_fired and new_pos != old_pos:
				if (_blocked_path_goals.get(goal, 0) as int) < state.round_number + 3:
					_blocked_path_goals[goal] = state.round_number + 3
			if _flanked_abort_fired and new_pos == old_pos and _flanked_abort_cell != Vector2i(-1, -1):
				var _fa_tpos := state.get_position(move_target)
				if _fa_tpos != Vector2i(-1, -1):
					var _fa_dirs8: Array[Vector2i] = [
						Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
					for _fad: Vector2i in _fa_dirs8:
						var _fac: Vector2i = _fa_tpos + _fad
						if _fac.x < 0 or _fac.x >= field.width or _fac.y < 0 or _fac.y >= field.length:
							continue
						if (_blocked_path_goals.get(_fac, 0) as int) < state.round_number + 3:
							_blocked_path_goals[_fac] = state.round_number + 3
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
					" -> ".join(parts), mini(pace, pace - budget), pace])

	if new_pos == old_pos:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE STALLED: %s goal=(%d,%d) no viable path" % [merc.merc_name, goal.x, goal.y])
		var _stall_pace := maxi(1, int(merc.stats.get("pace", 1)))
		if ConstStates.has_state(merc, ConstStates.DEPOSED):
			_stall_pace = mini(_stall_pace, 1)
		var _perm_block := false
		if field != null:
			var _stall_ft: float = clampf(
				clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
				+ maxf(clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
					clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0)), 0.2, 2.0)
			var _stall_ap: Dictionary = state.turn_ally_passable.get(merc, {}) as Dictionary
			if _stall_ap.is_empty():
				_stall_ap = field.get_nav_passable_cells()
			var _stall_dirs: Array[Vector2i] = [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
			var _any_affordable := false
			for _sd: Vector2i in _stall_dirs:
				var _snb := old_pos + _sd
				if _snb.x < 0 or _snb.x >= field.width or _snb.y < 0 or _snb.y >= field.length:
					continue
				var _sc := PathCost.cell_pace_cost(old_pos, _snb, field, _stall_ap, _stall_ft, false, true, state.get_floor(merc))
				if _sc >= 0:
					_any_affordable = true
					break
			if not _any_affordable:
				_perm_block = true
		if _perm_block:
			merc.active_states["_move_blocked_round"] = state.round_number
			var _smb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
			_smb[move_target] = true
			state.movement_blocked[merc] = _smb
			_blocked_path_goals[goal] = state.round_number + 1000
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE BLOCKED: %s no affordable step from (%d,%d)" % [merc.merc_name, old_pos.x, old_pos.y])
		else:
			if (_blocked_path_goals.get(goal, 0) as int) < state.round_number + 3:
				_blocked_path_goals[goal] = state.round_number + 3
			if field != null and move_target != null:
				var _target_pos := state.get_position(move_target)
				if _target_pos != Vector2i(-1, -1):
					var _bf_ft: float = clampf(
						clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
						+ maxf(clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
							clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0)), 0.2, 2.0)
					var _bf_ap: Dictionary = state.turn_ally_passable.get(merc, {}) as Dictionary
					if _bf_ap.is_empty():
						_bf_ap = field.get_nav_passable_cells()
					var _mt_reach := PathTargeter.reachable_from(old_pos, field, _bf_ap, _bf_ft, false, true, 0, state.get_floor(merc))
					var _dirs8: Array[Vector2i] = [
						Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
					for _d: Vector2i in _dirs8:
						var _cand := _target_pos + _d
						if _cand.x < 0 or _cand.x >= field.width or _cand.y < 0 or _cand.y >= field.length:
							continue
						if _mt_reach.has(_cand):
							continue
						if (_blocked_path_goals.get(_cand, 0) as int) < state.round_number + 3:
							_blocked_path_goals[_cand] = state.round_number + 3
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
				var _can_cl: bool = true
				var _jmp: int = int(merc.stats.get("jump", 0))
				last_move_heavy = true
				for _side: int in [1, -1]:
					var _fg := field.clamp_position(_enemy_pos + _perp * _side)
					var _fp := PathHelper.find_path_toward(old_pos, _fg, field, _ally_pass, _fall_tol, false, _can_cl, _jmp)
					if _fp.is_empty():
						continue
					var _fb := maxi(1, int(merc.stats.get("pace", 1)))
					if ConstStates.has_state(merc, ConstStates.DEPOSED):
						_fb = mini(_fb, 1)
					var _fn := old_pos
					var _ft: Array[Vector2i] = [old_pos]
					for _fi: int in range(1, _fp.size()):
						var _fc := PathCost.cell_pace_cost(_fp[_fi - 1], _fp[_fi], field, {}, _fall_tol, false, _can_cl, state.get_floor(merc))
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
			_blocked_path_goals[goal] = state.round_number + 3

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
	if state.battlefield != null and state.battlefield.is_interior_map:
		var _sw_key := Vector3i(new_pos.x, new_pos.y, state.get_floor(merc))
		if state.battlefield.stairwell_connections.has(_sw_key):
			var _sw_dest: Vector3i = state.battlefield.stairwell_connections[_sw_key] as Vector3i
			state.set_floor(merc, _sw_dest.z)
			state.set_position(merc, Vector2i(_sw_dest.x, _sw_dest.y))
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
	if state.battlefield != null and state.battlefield.is_interior_map:
		var _sw_key := Vector3i(jump_target_pos.x, jump_target_pos.y, state.get_floor(merc))
		if state.battlefield.stairwell_connections.has(_sw_key):
			var _sw_dest: Vector3i = state.battlefield.stairwell_connections[_sw_key] as Vector3i
			state.set_floor(merc, _sw_dest.z)
			state.set_position(merc, Vector2i(_sw_dest.x, _sw_dest.y))
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
		var merc_size := maxi(1, int(merc.stats.get("size", 0)))
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
		if state.battlefield != null and state.battlefield.is_interior_map:
			var _sw_key := Vector3i(top_pos.x, top_pos.y, state.get_floor(merc))
			if state.battlefield.stairwell_connections.has(_sw_key):
				var _sw_dest: Vector3i = state.battlefield.stairwell_connections[_sw_key] as Vector3i
				state.set_floor(merc, _sw_dest.z)
				state.set_position(merc, Vector2i(_sw_dest.x, _sw_dest.y))
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
	if state.battlefield != null and state.battlefield.is_interior_map:
		var _sw_key := Vector3i(new_pos.x, new_pos.y, state.get_floor(merc))
		if state.battlefield.stairwell_connections.has(_sw_key):
			var _sw_dest: Vector3i = state.battlefield.stairwell_connections[_sw_key] as Vector3i
			state.set_floor(merc, _sw_dest.z)
			state.set_position(merc, Vector2i(_sw_dest.x, _sw_dest.y))
	merc.aim_active = false
	state.clear_cover(merc)
	move_lines.append("  %s -> weapon ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), old_pos.x, old_pos.y, new_pos.x, new_pos.y])
	return move_lines

class_name SpecialActionSystem


static func execute(action: Dictionary, merc: MercenaryData, state: BattleState, ctx: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var action_name: String = action.get("action_name", "")
	var enhancements: int = ctx.get("enhancements", 0)
	var target: MercenaryData = action.get("target")
	var target_obs: Dictionary = action.get("target_obs", {})
	match action_name:
		"get_up":
			var cost := state.get_cost(merc, "get_up", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "get_up")
			ConstStates.remove_state(merc, ConstStates.DEPOSED)
			lines.append("  %s gets up!" % _cn(merc, state))
		"seek_cover":
			var cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "seek_cover")
			_do_seek_cover(merc, state, lines)
		"break_free":
			var cost := state.get_cost(merc, "break_free", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "break_free")
			_do_break_free(merc, state, enhancements, lines)
		"aim":
			var cost := state.get_cost(merc, "Aim", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "Aim")
			merc.aim_active = true
			lines.append("  %s aims." % _cn(merc, state))
		"open_door":
			var cost := state.get_cost(merc, "open_door", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "open_door")
			_do_open_door(merc, state, lines)
		"shove":
			var cost := state.get_cost(merc, "shove", 3)
			state.spend_ap(merc, cost)
			state.record_action(merc, "shove")
			if target != null:
				lines.append_array(_do_shove(merc, target, state, enhancements))
			elif not target_obs.is_empty():
				_do_shove_obstacle(merc, target_obs, state, lines)
		"attack_obstacle":
			var atk_cost := state.get_cost(merc, "attack_obstacle", AutoBattle.ATTACK_BASE_AP)
			state.spend_ap(merc, atk_cost)
			state.record_action(merc, "attack_obstacle")
			lines.append_array(_do_attack_obstacle(merc, state, enhancements))
	return lines


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var merc_size: int = int(merc.stats.get("size", 1))

	var all_enemies := state.get_enemies(merc)
	var ranged_enemies: Array[MercenaryData] = []
	for e: MercenaryData in all_enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)

	var nearest_enemy: MercenaryData = null
	var nearest_dist: float = INF
	for e: MercenaryData in ranged_enemies:
		var d := float((state.get_position(e) - merc_pos).length())
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	var to_enemy := Vector2.ZERO
	if nearest_enemy != null:
		var ep := state.get_position(nearest_enemy)
		to_enemy = Vector2(float(ep.x - merc_pos.x), float(ep.y - merc_pos.y))

	var _hp_ratio_sc: float = clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
	var _best_break_fall_sc: float = maxf(
		clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
		clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
	var fall_tolerance_sc: float = clampf(_hp_ratio_sc + _best_break_fall_sc, 0.2, 2.0)

	var candidates: Array = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	for obs: Dictionary in state.battlefield.obstacles:
		if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
			continue
		var obs_data_sc: ObstacleData = obs.get("data") as ObstacleData
		if obs_data_sc != null and not obs_data_sc.covers:
			continue
		var loop_obs_pos: Vector2i = obs["pos"] as Vector2i
		var delta := loop_obs_pos - merc_pos
		var dist: int = maxi(absi(delta.x), absi(delta.y))
		if dist == 0 or dist > pace:
			continue
		if nearest_enemy != null:
			var to_cover := Vector2(float(delta.x), float(delta.y))
			if to_cover.dot(to_enemy) <= 0.0:
				continue
		var is_narrow_sc: bool = obs_data_sc != null and obs_data_sc.narrow
		var obs_size_sc: int = int(obs.get("size", 1))
		var is_full_sc: bool = not is_narrow_sc and obs_size_sc > merc_size
		candidates.append({"obs": obs, "is_full": is_full_sc, "dist": dist})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_full"] != b["is_full"]:
			return a["is_full"]
		return a["dist"] < b["dist"])

	if candidates.is_empty():
		lines.append("  %s finds no reachable cover (pace=%d)." % [_cn(merc, state), pace])
		return

	var field: BattlefieldArea = state.battlefield

	for entry: Dictionary in candidates:
		var obs: Dictionary = entry["obs"]
		var obs_pos: Vector2i = obs["pos"] as Vector2i
		var dist: int = entry["dist"]
		var obs_size: int = int(obs["size"])
		var obs_data: ObstacleData = obs.get("data") as ObstacleData
		var is_narrow: bool = obs_data != null and obs_data.narrow
		var cover_type: String = ConstStates.COVERED_PARTIAL if is_narrow \
			else (ConstStates.COVERED_FULL if obs_size > merc_size else ConstStates.COVERED_PARTIAL)
		var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"

		if dist > 1:
			var delta := obs_pos - merc_pos
			var preferred_pos := obs_pos - Vector2i(clampi(delta.x, -1, 1), clampi(delta.y, -1, 1))
			var new_pos := preferred_pos
			if state.is_position_occupied(new_pos, merc):
				new_pos = Vector2i(-1, -1)
				for d: Vector2i in dirs:
					var adj := obs_pos + d
					if adj == obs_pos:
						continue
					if adj.x < 0 or adj.x >= field.width \
							or adj.y < 0 or adj.y >= field.length:
						continue
					if field.is_obstacle(adj):
						continue
					if not state.is_position_occupied(adj, merc):
						new_pos = adj
						break
			if new_pos == Vector2i(-1, -1):
				continue
			var path := Pathfinder.find_path(merc_pos, new_pos, field, {}, fall_tolerance_sc)
			if path.is_empty():
				continue
			var _has_exit := false
			for _ed: Vector2i in dirs:
				var _en := new_pos + _ed
				if _en.x < 0 or _en.x >= field.width or _en.y < 0 or _en.y >= field.length:
					continue
				if field.is_obstacle(_en):
					continue
				var _ec := PathCost.cell_pace_cost(new_pos, _en, field, {}, fall_tolerance_sc, false, true)
				if _ec >= 0 and _ec <= pace:
					_has_exit = true
					break
			if not _has_exit:
				continue
			var move_cost := state.get_cost(merc, "Move Close", AutoBattle.MOVE_BASE_AP)
			state.spend_ap(merc, move_cost)
			state.record_action(merc, "Move Close")
			state.set_position(merc, new_pos)
			merc.aim_active = false
			state.clear_cover(merc)
			var seek_cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, seek_cost)
			state.record_action(merc, "seek_cover")
			state.set_cover(merc, obs_pos, obs_size, cover_type)
			lines.append("  %s moves to cover behind %s. (%s -> %s)" % [
				_cn(merc, state), obs_name,
				"(%d,%d)" % [merc_pos.x, merc_pos.y],
				"(%d,%d)" % [new_pos.x, new_pos.y]])
			return
		else:
			var seek_cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, seek_cost)
			state.record_action(merc, "seek_cover")
			state.set_cover(merc, obs_pos, obs_size, cover_type)
			lines.append("  %s takes cover behind %s." % [_cn(merc, state), obs_name])
			return

	lines.append("  %s finds no free adjacent cover cell (all occupied)." % _cn(merc, state))


static func _do_open_door(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(merc_pos):
		if obs.get("cell_type", "") == "door" and not obs.get("door_open", false):
			obs["door_open"] = true
			lines.append("  %s opens the Door." % _cn(merc, state))
			return
	lines.append("  %s finds no adjacent closed door!" % _cn(merc, state))


static func _do_attack_obstacle(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null:
		return lines
	var pos := state.get_position(merc)
	var target_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp or d.health == 0:
			continue
		target_obs = obs
		break
	if target_obs.is_empty():
		return lines
	var atk_result := AttackSystem.execute_attack(merc, enhancements, 0, null, false, state)
	if atk_result.get("weapon_broke", false):
		var _bn: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "weapon"
		lines.append("  %s's %s breaks apart!" % [_cn(merc, state), _bn])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FRAGILITY: %s destroyed" % _bn)
		merc.equipped_weapon = DataManager.fight_weapon
		merc.weapon_drawn = DataManager.fight_weapon != null
	var damage: int = atk_result.get("damage", 0)
	var result := ObstacleUtils.apply_damage(target_obs, damage, state, _cn(merc, state))
	lines.append_array(result["lines"] as Array)
	var drop_pos: Vector2i = result.get("drop_pos", Vector2i(-1, -1)) as Vector2i
	if drop_pos != Vector2i(-1, -1):
		merc.active_states["bfw_drop_pos"] = drop_pos
	return lines


static func _do_shove(
		shover: MercenaryData,
		shoved: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var atk_def := {
		"stat_keys": ["dexterity", "vigor"],
		"formula": "melee_accuracy",
		"circumstances": ["Attack", "Grace", "Athletics", "Power"],
		"enhancements": enhancements,
	}
	var atk_result := CheckSystem.make_check(shover, atk_def)
	var shover_successes: int = atk_result["successes"]
	var shoved_successes := 0
	if _should_accept_shove(shoved, shover, state):
		lines.append("  %s doesn't resist the shove!" % _cn(shoved, state))
	else:
		var def_def := {
			"stat_keys": ["dexterity", "vigor"],
			"formula": "melee_accuracy",
			"circumstances": ["Grace", "Athletics", "Power", "Resist"],
		}
		var def_result := CheckSystem.make_check(shoved, def_def)
		shoved_successes = def_result["successes"]
	lines.append("  %s shoves %s! [Shover: %d | Shoved: %d successes]" % [
		_cn(shover, state), _cn(shoved, state), shover_successes, shoved_successes])
	var shover_size := int(shover.stats.get("size", 1))
	var shoved_size := int(shoved.stats.get("size", 1))
	var shove_dist := maxi(0, (shover_size + shover_successes) - (shoved_size + shoved_successes))
	if shove_dist == 0:
		lines.append("  %s holds their ground!" % _cn(shoved, state))
		return lines
	lines.append_array(_do_forcible_move(shover, shoved, shove_dist, state))
	return lines


static func _do_shove_obstacle(
		shover: MercenaryData,
		obs_dict: Dictionary,
		state: BattleState,
		lines: Array[String]) -> void:
	var obs_data: ObstacleData = obs_dict.get("data") as ObstacleData
	if obs_data == null or not obs_data.moveable:
		lines.append("  %s cannot be moved." % (obs_data.obstacle_name if obs_data != null else "obstacle"))
		return
	var cells_occupied := 1
	var target_number: int = obs_data.size * cells_occupied
	var result := CheckSystem.make_check(shover, {
		"stat_keys": ["vigor", "raw_power"],
		"formula": "melee_accuracy",
		"circumstances": ["Attack", "Power"],
	})
	lines.append("  %s shoves %s! [%d successes, need >%d]" % [
		_cn(shover, state), obs_data.obstacle_name, result["successes"], target_number])
	if result["successes"] <= target_number:
		lines.append("  Shove failed  -  insufficient successes.")
		return
	var shove_distance: int = result["successes"] - target_number
	var obs_pos := obs_dict["pos"] as Vector2i
	var shover_pos := state.get_position(shover)
	var raw_dx := obs_pos.x - shover_pos.x
	var raw_dy := obs_pos.y - shover_pos.y
	var push_dir := Vector2i(signi(raw_dx), signi(raw_dy))
	if push_dir == Vector2i.ZERO:
		push_dir = Vector2i(1, 0)
	var current := obs_pos
	var moved := 0
	for _i: int in shove_distance:
		var next := state.battlefield.clamp_position(current + push_dir)
		if next == current:
			break
		var blocking_obs: Dictionary = state.battlefield.get_obstacle_at(next)
		if not blocking_obs.is_empty():
			var bd: ObstacleData = blocking_obs.get("data") as ObstacleData
			if bd == null or not bd.passthrough:
				break
		var occupant_found := false
		for m: MercenaryData in state.positions.keys():
			if state.get_position(m) == next:
				occupant_found = true
				break
		if occupant_found:
			break
		current = next
		moved += 1
	if moved == 0:
		lines.append("  %s cannot be moved!" % obs_data.obstacle_name)
		return
	obs_dict["pos"] = current
	lines.append("  %s shoved %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
		obs_data.obstacle_name, moved, "s" if moved != 1 else "",
		obs_pos.x, obs_pos.y, current.x, current.y])


static func _do_forcible_move(
		shover: MercenaryData,
		shoved: MercenaryData,
		paces: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if ConstStates.has_state(shoved, ConstStates.CLIMBING):
		lines.append("  %s is knocked off the wall!" % _cn(shoved, state))
		lines.append_array(CombatApplicator.fall_from_wall(shoved, state))
		return lines
	if state.battlefield == null:
		lines.append("  %s is forcibly moved %d Pace%s." % [
			_cn(shoved, state), paces, "s" if paces != 1 else ""])
		return lines
	var old_pos := state.get_position(shoved)
	var shover_pos := state.get_position(shover)
	var dx := old_pos.x - shover_pos.x
	var dy := old_pos.y - shover_pos.y
	var dir := Vector2i(signi(dx), signi(dy))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var current := old_pos
	var paces_moved := 0
	for _i: int in paces:
		var next := state.battlefield.clamp_position(current + dir)
		if next == current:
			break
		var obs: Dictionary = state.battlefield.get_obstacle_at(next)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				break
		var occupant_found := false
		for m: MercenaryData in state.positions.keys():
			if m != shoved and state.get_position(m) == next:
				occupant_found = true
				break
		if occupant_found:
			break
		current = next
		paces_moved += 1
	var paces_failed := paces - paces_moved
	if paces_failed > 0:
		lines.append("  %s slams into an obstacle and takes %d Strike!" % [
			_cn(shoved, state), paces_failed])
		lines.append_array(CombatApplicator.apply_damage(shover, shoved, paces_failed, "Strike", state))
	if paces_moved > 0:
		state.set_position(shoved, current)
		shoved.aim_active = false
		state.clear_cover(shoved)
		var terrain_drop := state.battlefield.get_terrain_height(old_pos) - state.battlefield.get_terrain_height(current)
		if terrain_drop >= 1.0:
			lines.append_array(CombatApplicator.resolve_fall(shoved, int(floor(terrain_drop)), state))
		lines.append("  %s is pushed %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
			_cn(shoved, state), paces_moved, "s" if paces_moved != 1 else "",
			old_pos.x, old_pos.y, current.x, current.y])
	else:
		lines.append("  %s cannot be moved!" % _cn(shoved, state))
	if paces_moved >= int(shoved.stats.get("size", 1)):
		if not ConstStates.has_state(shoved, ConstStates.DEPOSED):
			ConstStates.apply_state(shoved, ConstStates.DEPOSED)
			lines.append("  %s is knocked down and [b]Deposed[/b]!" % _cn(shoved, state))
	return lines


static func _should_accept_shove(
		shoved: MercenaryData,
		shover: MercenaryData,
		state: BattleState) -> bool:
	if state.battlefield == null:
		return ConstStates.has_state(shoved, ConstStates.FLANKED)

	var shover_size := int(shover.stats.get("size", 1))
	var shoved_size := int(shoved.stats.get("size", 1))

	if shover_size - shoved_size >= 4:
		return true

	var shoved_pos := state.get_position(shoved)
	var shover_pos := state.get_position(shover)
	var dx := shoved_pos.x - shover_pos.x
	var dy := shoved_pos.y - shover_pos.y
	var dir := Vector2i(signi(dx), signi(dy))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var current := shoved_pos
	var paces_moved := 0
	var slammed := false
	for _i: int in shover_size:
		var next := state.battlefield.clamp_position(current + dir)
		if next == current:
			slammed = true
			break
		var obs := state.battlefield.get_obstacle_at(next)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				slammed = true
				break
		var blocked := false
		for m: MercenaryData in state.positions.keys():
			if m != shoved and state.get_position(m) == next:
				slammed = true
				blocked = true
				break
		if blocked:
			break
		current = next
		paces_moved += 1
	var dest := current

	var terrain_drop := state.battlefield.get_terrain_height(shoved_pos) - state.battlefield.get_terrain_height(dest)
	if terrain_drop >= 1.0:
		return false

	if slammed and (shover_size - paces_moved) >= 1:
		return false

	var melee_near_dest := 0
	var ranged_total := 0
	for e: MercenaryData in state.get_enemies(shoved):
		var w: WeaponData = e.equipped_weapon
		if w != null and w.is_ranged:
			ranged_total += 1
		var e_pos := state.get_position(e)
		if maxi(abs(e_pos.x - dest.x), abs(e_pos.y - dest.y)) <= 1:
			if w == null or not w.is_ranged:
				melee_near_dest += 1

	if melee_near_dest >= 1:
		return false

	if ranged_total > 0 and melee_near_dest == 0 and shoved_size >= shover_size - 1:
		return true

	return false


static func _do_break_free(merc: MercenaryData, state: BattleState, enhancements: int, lines: Array[String]) -> void:
	var state_name := ""
	if ConstStates.has_state(merc, ConstStates.SUFFOCATING):
		state_name = ConstStates.SUFFOCATING
	elif ConstStates.has_state(merc, ConstStates.GRAPPLED):
		state_name = ConstStates.GRAPPLED
	elif ConstStates.has_state(merc, ConstStates.INHIBITED):
		state_name = ConstStates.INHIBITED
	if state_name == "":
		return
	var source: MercenaryData = ConstStates.get_source(merc, state_name)
	var source_vigor := 0
	if source != null:
		source_vigor = int(source.stats.get("vigor", 0))
	var check_def := {
		"stat_keys":          ["vigor"],
		"circumstances":      [],
		"knowledges":         [],
		"tools":              [],
		"formula":            "luck",
		"enhancements":       enhancements,
		"flat_threshold_bonus": float(-source_vigor * 10),
	}
	var result := CheckSystem.make_check(merc, check_def)
	if int(result["successes"]) > 0:
		ConstStates.remove_state(merc, state_name)
		if state_name == ConstStates.SUFFOCATING:
			ConstStates.remove_state(merc, ConstStates.GRAPPLED)
		if state_name == ConstStates.GRAPPLED or state_name == ConstStates.SUFFOCATING:
			merc.active_states.erase("whip_grappled_by")
		lines.append("  %s breaks free!" % _cn(merc, state))
	else:
		lines.append("  %s fails to break free!" % _cn(merc, state))
		if merc.active_states.has("whip_grappled_by"):
			var grappler := merc.active_states["whip_grappled_by"] as MercenaryData
			if grappler != null and BattleState._is_alive(grappler):
				lines.append_array(CombatApplicator.apply_damage(grappler, merc, 1, "Direct", state))
				lines.append("  Whip choke tightens  -  %s deals 1 Direct damage!" % _cn(grappler, state))


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first

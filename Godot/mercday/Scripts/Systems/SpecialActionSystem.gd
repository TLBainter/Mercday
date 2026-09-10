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
			if ConstStates.remove_state(merc, ConstStates.DEPOSED)["removed"]:
				StateInfliction.note_removed(merc, ConstStates.DEPOSED, state, "action")
			lines.append("  %s gets up!" % BattleState.colored_name(merc, state))
		"end_burning":
			var burn_cost := state.get_cost(merc, "Interact", 2)
			state.spend_ap(merc, burn_cost)
			state.record_action(merc, "Interact")
			lines.append("  %s tries to put out the flames!" % BattleState.colored_name(merc, state))
			lines.append_array(StateInfliction.attempt_interact(merc, ConstStates.BURNING, state))
		"aid_ally":
			var aid_state := str(action.get("state_name", ""))
			if target != null and not target.is_dead and aid_state != "" \
					and ConstStates.has_state(target, aid_state) \
					and state.distance_to(merc, target) <= 1:
				var aid_cost := state.get_cost(merc, "Interact", 2)
				state.spend_ap(merc, aid_cost)
				state.record_action(merc, "Interact")
				lines.append_array(StateInfliction.attempt_interact(target, aid_state, state, merc))
				RelationshipSystem.record_aid(merc, target)
		"seek_cover":
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
			lines.append("  %s aims." % BattleState.colored_name(merc, state))
		"Interact":
			_do_interact(merc, state, lines)
		"shove":
			var cost := state.get_cost(merc, "shove", 3)
			state.spend_ap(merc, cost)
			state.record_action(merc, "shove")
			if target != null:
				lines.append_array(ShoveResolver.shove(merc, target, state, enhancements))
			elif not target_obs.is_empty():
				ShoveResolver.shove_obstacle(merc, target_obs, state, lines)
		"attack_obstacle":
			var atk_cost := state.get_cost(merc, "attack_obstacle", AutoBattle.ATTACK_BASE_AP)
			state.spend_ap(merc, atk_cost)
			state.record_action(merc, "attack_obstacle")
			lines.append_array(_do_attack_obstacle(merc, state, enhancements))
	return lines


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var enemies := state.get_enemies(merc)
	var ranged := CoverSearch.ranged_enemies(enemies)
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var seek_cost := state.get_cost(merc, "seek_cover", 2)
	var dest := CoverSearch.find_cover_cell(merc, enemies, state)
	if dest == PathTargeter.NO_CELL:
		var cur := CoverSearch.cover_score(state.pos3(merc), merc_size, ranged, state)
		if int(cur["full"]) > 0 or int(cur["partial"]) > 0:
			lines.append("  %s is already in cover." % BattleState.colored_name(merc, state))
		else:
			lines.append("  %s finds no reachable cover (pace=%d)." % [BattleState.colored_name(merc, state), pace])
		return
	var move_cost := state.get_cost(merc, "Move Close", AutoBattle.MOVE_BASE_AP)
	if not state.can_afford(merc, move_cost + seek_cost):
		lines.append("  %s cannot afford to reach cover." % BattleState.colored_name(merc, state))
		return
	state.spend_ap(merc, move_cost)
	state.record_action(merc, "Move Close")
	state.set_pos3(merc, dest)
	merc.aim_active = false
	state.spend_ap(merc, seek_cost)
	state.record_action(merc, "seek_cover")
	var sc_final := CoverSearch.cover_score(dest, merc_size, ranged, state)
	lines.append("  %s moves to cover at (%d,%d) F%d: full from %d, partial from %d." % [
		BattleState.colored_name(merc, state), dest.x, dest.y, dest.z, int(sc_final["full"]), int(sc_final["partial"])])


static func _do_interact(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var cell := InteractTargetFacet.find_target(merc, state)
	if cell == PathTargeter.NO_CELL:
		return
	var obs: Dictionary = state.battlefield.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty():
		return
	InteractionSystem.perform(merc, obs, cell, state, lines)


static func _do_attack_obstacle(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null:
		return lines
	var pos := state.get_position(merc)
	var target_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos, state.get_floor(merc)):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp or d.health == 0:
			continue
		if PathCost.is_interactable_door(obs) and not OpenCloseState.is_open(obs):
			continue
		target_obs = obs
		break
	if target_obs.is_empty():
		return lines
	var atk_result := AttackSystem.execute_attack(merc, enhancements, 0, null, false, state)
	if atk_result.get("weapon_broke", false):
		var _bn: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "weapon"
		lines.append("  %s's %s breaks apart!" % [BattleState.colored_name(merc, state), _bn])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FRAGILITY: %s destroyed" % _bn)
		lines.append_array(WeaponActionExecutor.empty_main_hand(merc, state))
	var damage: int = atk_result.get("damage", 0)
	var result := ObstacleUtils.apply_damage(target_obs, damage, state, BattleState.colored_name(merc, state))
	lines.append_array(result["lines"] as Array)
	var drop_pos: Vector2i = result.get("drop_pos", Vector2i(-1, -1)) as Vector2i
	if drop_pos != Vector2i(-1, -1):
		merc.active_states["bfw_drop_pos"] = drop_pos
	return lines


#Break Free check: a vigor luck roll whose threshold rises with the source's vigor.
static func break_free_def(target: MercenaryData, state_name: String) -> Dictionary:
	var source: MercenaryData = ConstStates.get_source(target, state_name)
	var source_vigor := 0
	if source != null:
		source_vigor = int(source.stats.get("vigor", 0))
	return {
		"stat_keys": ["vigor"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"flat_threshold_bonus": float(-source_vigor * 10),
	}


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
	var check_def := break_free_def(merc, state_name)
	check_def["enhancements"] = enhancements
	var result := CheckSystem.make_check(merc, check_def)
	if int(result["successes"]) > 0 or bool(result.get("critical", false)):
		if ConstStates.remove_state(merc, state_name)["removed"]:
			StateInfliction.note_removed(merc, state_name, state, "action")
		if state_name == ConstStates.SUFFOCATING and ConstStates.has_state(merc, ConstStates.GRAPPLED):
			if ConstStates.remove_state(merc, ConstStates.GRAPPLED)["removed"]:
				StateInfliction.note_removed(merc, ConstStates.GRAPPLED, state, "action")
		lines.append("  %s breaks free!" % BattleState.colored_name(merc, state))
	else:
		lines.append("  %s fails to break free!" % BattleState.colored_name(merc, state))
		var grappler: MercenaryData = ConstStates.get_source(merc, ConstStates.GRAPPLED)
		if grappler != null and ActionDispatcher.is_whip_grappler(grappler, merc, state):
			lines.append_array(CombatApplicator.apply_damage(grappler, merc, 1, "Direct", state))
			lines.append("  %s is choked by the whip!" % BattleState.colored_name(merc, state))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("WHIP CHOKE: %s fails to escape %s" % [
					merc.merc_name, grappler.merc_name])



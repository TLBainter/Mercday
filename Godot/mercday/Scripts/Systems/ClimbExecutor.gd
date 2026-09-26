class_name ClimbExecutor extends RefCounted


#The gates ClimbAction.can_execute tests before it starts a climb: a body to grab with, a target
#the search still finds, and the Moves the first grab costs.
static func climb_startable(merc: MercenaryData, state: BattleState) -> bool:
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return false
	if int(merc.stats.get("size", 0)) <= 0 or ClimbAction.find_target(merc, state).is_empty():
		return false
	var grab: int = maxi(1, int(merc.stats.get("size", 1)))
	return MovementExecutor.can_fund_climb(merc, state, "Climb", grab * MovementExecutor.climb_pace_cost(merc))


#True when the pending climb route can run now, so a Move on the foot cell buys nothing.
static func climb_route_ready(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.climb_route(merc).is_empty():
		return false
	return climb_startable(merc, state)


#True when the unit stands on the foot of the roof post it scored and can start that climb now.
static func post_climb_ready(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or not RoofPostScore.at_post(merc, state):
		return false
	return climb_startable(merc, state)


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
		var link: Dictionary = decision.get("climb_link", {}) as Dictionary
		var going_down: bool = bool(decision.get("climb_down", false))
		var base_cell := Vector3i(state.get_position(merc).x, state.get_position(merc).y,
			state.get_floor(merc))
		var link_end := base_cell
		var init_target_h := 0
		if link.is_empty():
			#A climber sunk to the bottom of a pool starts that many paces below the surface.
			var merc_floor_h := int(round(field.surface_height(state.get_position(merc)))) - state.sunk_depth(merc)
			#Climb height counts paces above the climber's own cell surface.
			init_target_h = int(round(field.get_terrain_height(target_pos))) - merc_floor_h
			if init_target_h <= 0 and ClimbAction.wall_hop(field, target_pos):
				init_target_h = 2
		else:
			init_target_h = int(link["paces"])
			link_end = (link["to"] if going_down else link["top"]) as Vector3i
		var grab_h := merc_size
		var init_c := MovementExecutor.climb_pace_cost(merc)
		if not MovementExecutor._climb_fund(merc, state, action_name, grab_h * init_c):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("CLIMB REFUSED: %s reason=ap_short" % merc.merc_name)
			return []
		var init_pool := state.get_pace_pool(merc)
		state.set_pace_pool(merc, init_pool - grab_h * init_c)
		if link.is_empty():
			state.climbing_data[merc] = {
				"wall_pos": target_pos,
				"current_h": grab_h,
				"target_h": init_target_h,
				"top_pos": target_pos,
			}
		else:
			var link_cd: Dictionary = {
				"wall_pos": target_pos,
				"current_h": grab_h,
				"target_h": init_target_h,
				"top_pos": Vector2i(link_end.x, link_end.y),
				"top_floor": link_end.z,
				"link": true,
			}
			if going_down:
				link_cd["down"] = true
			state.climbing_data[merc] = link_cd
		ConstStates.apply_state(merc, ConstStates.CLIMBING, null, "", "engine:climb")
		if link.is_empty() or not going_down:
			state.set_height(merc, grab_h)
		else:
			#The climber swings straight onto the landing column and works down the height left.
			state.set_pos3(merc, link_end)
			state.set_height(merc, init_target_h - grab_h)
		merc.aim_active = false
		if going_down and not link.is_empty():
			lines.append("  %s swings over the edge and begins climbing down! (alt %d/%d)" % [
				BattleState.colored_name(merc, state), grab_h, init_target_h])
		else:
			lines.append("  %s grabs the wall and begins climbing! (alt %d/%d)" % [
				BattleState.colored_name(merc, state), grab_h, init_target_h])
		if not link.is_empty() and EncounterLogger.is_active():
			var low := link_end if going_down else base_cell
			var high := base_cell if going_down else link_end
			EncounterLogger.log_verbose("CLIMB ROOF: %s kind=%s dir=%s base=(%d,%d,F%d) top=(%d,%d,F%d) h=%d" % [
				merc.merc_name, String(link["kind"]), "down" if going_down else "up",
				low.x, low.y, low.z, high.x, high.y, high.z, init_target_h])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CLIMB: %s +%d height (%d/%d) pool %d -> %d" % [
				merc.merc_name, grab_h, grab_h, init_target_h, init_pool, state.get_pace_pool(merc)])
		if grab_h >= init_target_h:
			_complete_climb(merc, state, lines)
		return lines

	var cd: Dictionary = state.get_climbing_data(merc)
	var current_h := int(cd.get("current_h", 0))
	var target_h := int(cd.get("target_h", 0))

	var climb_c := MovementExecutor.climb_pace_cost(merc)
	var remaining := target_h - current_h
	if remaining > 0 and state.get_pace_pool(merc) < climb_c:
		if not MovementExecutor._climb_fund(merc, state, action_name, climb_c):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("CLIMB REFUSED: %s reason=ap_short" % merc.merc_name)
			return []
	var climb_pool := state.get_pace_pool(merc)
	var gained := mini(int(climb_pool / float(climb_c)), remaining)
	if gained > 0:
		state.set_pace_pool(merc, climb_pool - gained * climb_c)
	var new_h := current_h + maxi(0, gained)
	cd["current_h"] = new_h
	state.climbing_data[merc] = cd
	#A down climber holds the height still left under it.
	state.set_height(merc, target_h - new_h if cd.get("down", false) else new_h)
	merc.aim_active = false
	if gained > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("CLIMB: %s +%d height (%d/%d) pool %d -> %d" % [
			merc.merc_name, gained, new_h, target_h, climb_pool, state.get_pace_pool(merc)])

	if new_h >= target_h:
		_complete_climb(merc, state, lines)
	else:
		lines.append("  %s climbs to height %d/%d." % [BattleState.colored_name(merc, state), new_h, target_h])
	return lines


static func _complete_climb(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var cd: Dictionary = state.get_climbing_data(merc)
	if cd.get("link", false):
		_complete_link_climb(merc, state, cd, lines)
		return
	var top_pos: Vector2i = cd.get("top_pos", state.get_position(merc)) as Vector2i
	var pit_pos := state.get_position(merc)
	var merc_floor := state.get_floor(merc)
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	if state.battlefield != null:
		var _obs := state.battlefield.get_obs(top_pos, merc_floor)
		if not _obs.is_empty() and _obs.get("cell_type", "") == "wall":
			var wall_pos: Vector2i = cd.get("wall_pos", top_pos) as Vector2i
			var _dir := Vector2i(signi(wall_pos.x - pit_pos.x), signi(wall_pos.y - pit_pos.y))
			var _beyond := wall_pos + _dir
			if state.battlefield.get_nav_passable_cells().has(_beyond) and not state.is_position_occupied(_beyond, merc, merc_floor):
				top_pos = _beyond
	if not state.is_position_occupied(top_pos, merc, merc_floor):
		state.set_position(merc, top_pos)
	if state.battlefield != null:
		state.set_height(merc, 0)
	lines.append("  %s hauls themselves up!" % BattleState.colored_name(merc, state))
	var cav_field := state.battlefield
	if cav_field != null and cav_field.is_cavern:
		var was_wet: bool = state.is_sunk(merc) or cav_field.is_water(pit_pos)
		if was_wet and not cav_field.is_water(state.get_position(merc)):
			CavernRules.on_surface(merc, state, lines)


#End of a climb link: an up climber takes the top cell, a down climber is already on its landing.
static func _complete_link_climb(merc: MercenaryData, state: BattleState, cd: Dictionary,
		lines: Array[String]) -> void:
	var top_pos: Vector2i = cd.get("top_pos", state.get_position(merc)) as Vector2i
	var top_floor: int = int(cd.get("top_floor", state.get_floor(merc)))
	var going_down: bool = bool(cd.get("down", false))
	if not going_down and state.is_position_occupied(top_pos, merc, top_floor):
		var held: int = int(cd.get("hold", 0))
		if held >= MovementExecutor.CLIMB_HOLD_MAX:
			_abandon_climb(merc, state, lines, held)
			return
		cd["current_h"] = int(cd.get("target_h", 0))
		cd["hold"] = held + 1
		state.climbing_data[merc] = cd
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CLIMB HOLD: %s top occupied (%d/%d)" % [
				merc.merc_name, held + 1, MovementExecutor.CLIMB_HOLD_MAX])
		return
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	state.set_height(merc, 0)
	if going_down:
		lines.append("  %s reaches the ground." % BattleState.colored_name(merc, state))
		return
	state.set_pos3(merc, Vector3i(top_pos.x, top_pos.y, top_floor))
	lines.append("  %s hauls themselves up!" % BattleState.colored_name(merc, state))


#A climber held CLIMB_HOLD_MAX turns lets go at the base, forgets its goal and post, and picks again.
static func _abandon_climb(merc: MercenaryData, state: BattleState, lines: Array[String], held: int) -> void:
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	state.set_height(merc, 0)
	state.move_goals.erase(merc)
	state.move_targets.erase(merc)
	state.clear_climb_route(merc)
	state.roof_posts.erase(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CLIMB ABANDON: %s top occupied %d turns" % [merc.merc_name, held])
	lines.append("  %s drops back to the ground; the ledge is taken." % BattleState.colored_name(merc, state))

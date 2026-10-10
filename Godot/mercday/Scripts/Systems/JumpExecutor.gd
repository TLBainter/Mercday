class_name JumpExecutor extends RefCounted

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


static func execute_jump(
		merc: MercenaryData,
		jump_target_pos: Vector2i,
		jump_target_floor: int,
		action_name: String,
		state: BattleState,
		enhancements: int = 0,
		jump_why: String = "") -> Array[String]:
	if jump_target_pos == Vector2i(-1, -1):
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []
	var merc_floor := state.get_floor(merc)
	if state.is_position_occupied(jump_target_pos, merc, jump_target_floor):
		return []
	var _jsize := int(merc.stats.get("size", 1))
	var _jcell := Vector3i(jump_target_pos.x, jump_target_pos.y, jump_target_floor)
	var _jtop := false
	if state.battlefield != null:
		_jtop = PathHelper.is_top_standable(_jcell, state.battlefield, _jsize)
		var _jstand: bool = _jtop or PathHelper.is_standable(_jcell, state.battlefield, _jsize)
		var _jfrom := state.get_position(merc)
		var _jwall: bool = PathJump.leap_blocked(state.battlefield,
			Vector3i(_jfrom.x, _jfrom.y, merc_floor),
			Vector3i(jump_target_pos.x, jump_target_pos.y, merc_floor))
		if _jwall or not _jstand \
				or not PathCost.has_exit_neighbor(_jcell, state.battlefield, {}, 1.0, false, false, _jsize):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("JUMP REFUSED: %s (%d,%d) F%d why=%s" % [
					merc.merc_name, jump_target_pos.x, jump_target_pos.y, jump_target_floor,
					"wall" if _jwall else "no_landing"])
			return []

	var lines: Array[String] = []
	var old_pos := state.get_position(merc)
	var field := state.battlefield

	lines.append_array(MovementExecutor.advantage_attacks(merc, state, old_pos, jump_target_pos, enhancements))

	state.spend_ap(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap))
	state.record_action(merc, action_name)
	var _jold_h := state.get_height(merc)
	state.set_position(merc, jump_target_pos)
	if jump_target_floor != merc_floor:
		state.floors[merc] = jump_target_floor
		MovementExecutor.forget_turn_path(merc)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLOOR: %s %d->%d at (%d,%d)" % [
				merc.merc_name, merc_floor, jump_target_floor, jump_target_pos.x, jump_target_pos.y])
	merc.aim_active = false

	var _jnew_h := 0
	if field != null:
		if _jtop:
			_jnew_h = int(ceil(BattlefieldArea.obstacle_height(field.get_obs(jump_target_pos, jump_target_floor))))
		state.set_height(merc, _jnew_h)
		var _jfrom_e := field.cell_base_elevation(old_pos, merc_floor) + float(_jold_h)
		var _jto_e := field.cell_base_elevation(jump_target_pos, jump_target_floor) + float(_jnew_h)
		var _jdrop := _jfrom_e - _jto_e
		if _jdrop >= 1.0:
			lines.append_array(FallResolver.resolve_fall(merc, int(floor(_jdrop)), state))

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("JUMP: %s (%d,%d) F%d h%d -> (%d,%d) F%d h%d why=%s" % [
			merc.merc_name, old_pos.x, old_pos.y, merc_floor, _jold_h,
			jump_target_pos.x, jump_target_pos.y, jump_target_floor, _jnew_h, jump_why])

	lines.append("  %s leaps! ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(merc, state), old_pos.x, old_pos.y, jump_target_pos.x, jump_target_pos.y])

	return lines


#True when a pending roof leap can run now, so a Move on the take-off cell buys nothing.
static func route_ready(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null:
		return false
	var row: Dictionary = state.jump_route(merc)
	if row.is_empty():
		return false
	if int(merc.stats.get("jump", 0)) <= 0 or ConstStates.has_state(merc, ConstStates.CLIMBING):
		return false
	var land: Vector3i = row["to"] as Vector3i
	if state.is_position_occupied(Vector2i(land.x, land.y), merc, land.z):
		return false
	return state.can_afford(merc, state.get_cost(merc, "Jump", _CONFIG.move_base_ap))

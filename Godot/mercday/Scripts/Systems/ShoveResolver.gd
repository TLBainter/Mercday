class_name ShoveResolver
extends RefCounted

#Resolves shoves against mercs and obstacles, the forced movement they cause and the
#prediction of whether a shove is worth accepting.


static func shove(
		shover: MercenaryData,
		shoved: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var contest_def := {
		"stat_keys": ["dexterity", "vigor"],
		"formula": "melee_accuracy",
	}
	var atk_def := contest_def.duplicate()
	atk_def["enhancements"] = enhancements
	var atk_result := CheckSystem.make_check(shover, atk_def)
	var shover_successes: int = atk_result["successes"]
	var shover_crit: bool = bool(atk_result.get("critical", false))
	var shoved_successes := 0
	var shoved_crit := false
	if _should_accept_shove(shoved, shover, state):
		lines.append("  %s doesn't resist the shove!" % BattleState.colored_name(shoved, state))
	else:
		var def_result := CheckSystem.make_check(shoved, contest_def)
		shoved_successes = def_result["successes"]
		shoved_crit = bool(def_result.get("critical", false))
	lines.append("  %s shoves %s! [Shover: %d | Shoved: %d successes]" % [
		BattleState.colored_name(shover, state), BattleState.colored_name(shoved, state), shover_successes, shoved_successes])
	var shover_size := int(shover.stats.get("size", 1))
	var shoved_size := int(shoved.stats.get("size", 1))
	var shove_dist := maxi(0, (shover_size + shover_successes) - (shoved_size + shoved_successes))
	#One critical decides the contest outright; two cancel and the successes stand.
	if shover_crit and not shoved_crit:
		shove_dist = maxi(shove_dist, 1)
	elif shoved_crit and not shover_crit:
		shove_dist = 0
	if EncounterLogger.is_active() and (shover_crit or shoved_crit):
		var crit_who := "both"
		if shover_crit and not shoved_crit:
			crit_who = shover.merc_name
		elif shoved_crit and not shover_crit:
			crit_who = shoved.merc_name
		EncounterLogger.log_verbose("SHOVE CRIT: %s dist=%d" % [crit_who, shove_dist])
	if shove_dist == 0:
		lines.append("  %s holds their ground!" % BattleState.colored_name(shoved, state))
		return lines
	#forcible_move fires on_shove_seen once the shoved merc actually moves.
	lines.append_array(forcible_move(shover, shoved, shove_dist, state))
	return lines


#Unit step from one cell toward another; two bodies in one cell push east.
static func _push_dir(from: Vector2i, toward: Vector2i) -> Vector2i:
	var dir := Vector2i(signi(toward.x - from.x), signi(toward.y - from.y))
	return Vector2i(1, 0) if dir == Vector2i.ZERO else dir


#Glaive Redirect: the target is walked sideways off the attacker-target line.
static func lateral_move(mover: MercenaryData, target: MercenaryData, paces: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if target == null or state == null or state.battlefield == null or paces <= 0:
		return lines
	if ConstStates.has_state(target, ConstStates.CLIMBING):
		return forcible_move(mover, target, paces, state)
	var old_pos := state.get_position(target)
	var floor_num := state.get_floor(target)
	var mover_pos := state.get_position(mover)
	var along := _push_dir(mover_pos, old_pos)
	var left := Vector2i(-along.y, along.x)
	var right := Vector2i(along.y, -along.x)
	var push: Dictionary = walk_push(state, old_pos, left, paces, floor_num, target)
	if int(push["paces"]) <= 0:
		push = walk_push(state, old_pos, right, paces, floor_num, target)
	var moved: int = int(push["paces"])
	if moved <= 0:
		lines.append("  %s cannot be moved!" % BattleState.colored_name(target, state))
		return lines
	lines.append_array(_apply_push(target, old_pos, push["cell"], floor_num, moved, "shifted", state))
	return lines


#Puts the pushed merc on its new cell, resolves a fall, logs the move and fires the shove reactions.
static func _apply_push(target: MercenaryData, old_pos: Vector2i, current: Vector2i, floor_num: int,
		moved: int, verb: String, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	state.set_pos3(target, Vector3i(current.x, current.y, floor_num))
	target.aim_active = false
	var drop := state.battlefield.surface_height(old_pos) - state.battlefield.surface_height(current)
	if drop >= 1.0:
		lines.append_array(FallResolver.resolve_fall(target, int(floor(drop)), state))
	lines.append("  %s is %s %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(target, state), verb, moved, "s" if moved != 1 else "",
		old_pos.x, old_pos.y, current.x, current.y])
	lines.append_array(WeaponReactiveSystem.fire_shove_seen(target, state))
	return lines


static func shove_obstacle(
		shover: MercenaryData,
		obs_dict: Dictionary,
		state: BattleState,
		lines: Array[String]) -> void:
	var obs_data: ObstacleData = obs_dict.get("data") as ObstacleData
	if obs_data == null or not obs_data.moveable:
		lines.append("  %s cannot be moved." % (obs_data.obstacle_name if obs_data != null else "obstacle"))
		return
	var target_number: int = obs_data.size
	var result := CheckSystem.make_check(shover, {
		"stat_keys": ["vigor", "raw_power"],
		"formula": "melee_accuracy",
	})
	var successes: int = result["successes"]
	#A critical always beats the obstacle, if only by one Pace.
	if bool(result.get("critical", false)):
		successes = maxi(successes, target_number + 1)
	lines.append("  %s shoves %s! [%d successes, need >%d]" % [
		BattleState.colored_name(shover, state), obs_data.obstacle_name, successes, target_number])
	if successes <= target_number:
		lines.append("  Shove failed  -  insufficient successes.")
		return
	var shove_distance: int = successes - target_number
	var _raw_shv = obs_dict["pos"]
	var is_pos_3d := typeof(_raw_shv) == TYPE_VECTOR3I
	var obs_pos: Vector2i = Vector2i((_raw_shv as Vector3i).x, (_raw_shv as Vector3i).y) if is_pos_3d else _raw_shv as Vector2i
	var floor_num: int = (_raw_shv as Vector3i).z if is_pos_3d else state.get_floor(shover)
	var shover_pos := state.get_position(shover)
	var push_dir := _push_dir(shover_pos, obs_pos)
	var push := walk_push(state, obs_pos, push_dir, shove_distance, floor_num, null)
	var current: Vector2i = push["cell"]
	var moved: int = push["paces"]
	if moved == 0:
		lines.append("  %s cannot be moved!" % obs_data.obstacle_name)
		return
	if is_pos_3d:
		obs_dict["pos"] = Vector3i(current.x, current.y, floor_num)
	else:
		obs_dict["pos"] = current
	if state.battlefield != null:
		state.battlefield.bump_path_version()
	lines.append("  %s shoved %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
		obs_data.obstacle_name, moved, "s" if moved != 1 else "",
		obs_pos.x, obs_pos.y, current.x, current.y])


#Walks a push cell by cell; returns {"cell", "paces", "blocked"}. ignore is skipped in the occupant scan.
static func walk_push(state: BattleState, from: Vector2i, dir: Vector2i, max_paces: int,
		floor_num: int, ignore: MercenaryData, alive_only: bool = true) -> Dictionary:
	var current := from
	var moved := 0
	var blocked := false
	for _i: int in max_paces:
		var next := state.battlefield.clamp_position(current + dir)
		if next == current:
			blocked = true
			break
		var obs: Dictionary = state.battlefield.get_obs(next, floor_num)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				blocked = true
				break
		var occupied := false
		for m: MercenaryData in state.positions.keys():
			if m == ignore or m.off_field:
				continue
			if state.get_position(m) != next or state.get_floor(m) != floor_num:
				continue
			if alive_only and not BattleState._is_alive(m):
				continue
			occupied = true
			break
		if occupied:
			blocked = true
			break
		current = next
		moved += 1
	return {"cell": current, "paces": moved, "blocked": blocked}


static func forcible_move(
		shover: MercenaryData,
		shoved: MercenaryData,
		paces: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if ConstStates.has_state(shoved, ConstStates.CLIMBING):
		lines.append("  %s is knocked off the wall!" % BattleState.colored_name(shoved, state))
		lines.append_array(FallResolver.fall_from_wall(shoved, state))
		return lines
	if state.battlefield == null:
		lines.append("  %s is forcibly moved %d Pace%s." % [
			BattleState.colored_name(shoved, state), paces, "s" if paces != 1 else ""])
		return lines
	var old_pos := state.get_position(shoved)
	var floor_num := state.get_floor(shoved)
	var shover_pos := state.get_position(shover)
	var dir := _push_dir(shover_pos, old_pos)
	var push := walk_push(state, old_pos, dir, paces, floor_num, shoved)
	var current: Vector2i = push["cell"]
	var paces_moved: int = push["paces"]
	var paces_failed := paces - paces_moved
	if paces_failed > 0:
		lines.append("  %s slams into an obstacle and takes %d Strike!" % [
			BattleState.colored_name(shoved, state), paces_failed])
		lines.append_array(CombatApplicator.apply_damage(shover, shoved, paces_failed, "Strike", state))
	if paces_moved > 0:
		lines.append_array(_apply_push(shoved, old_pos, current, floor_num, paces_moved, "pushed", state))
	else:
		lines.append("  %s cannot be moved!" % BattleState.colored_name(shoved, state))
	if paces_moved >= ConstStates.knockdown_size(shoved):
		if not ConstStates.has_state(shoved, ConstStates.DEPOSED):
			if StateCascade.apply_state(shoved, ConstStates.DEPOSED, null, "", "engine:shove"):
				lines.append("  %s is knocked down and [b]Deposed[/b]!" % BattleState.colored_name(shoved, state))
			else:
				lines.append("  %s is immune to Deposed!" % BattleState.colored_name(shoved, state))
				state.learn_state_immunity(shover, shoved, ConstStates.DEPOSED)
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
	var dir := _push_dir(shover_pos, shoved_pos)
	var push := walk_push(state, shoved_pos, dir, shover_size, state.get_floor(shoved), shoved, false)
	var paces_moved: int = push["paces"]
	var slammed: bool = push["blocked"]
	var dest: Vector2i = push["cell"]

	var terrain_drop := state.battlefield.surface_height(shoved_pos) - state.battlefield.surface_height(dest)
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



class_name RescueWalk extends RefCounted

#Rescue movement: hidden creeping, detours and the step by step walk along a path.

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


#Buys moves toward a goal; when hiding it stops short of the first cell an enemy can see.
static func hidden_moves(merc: MercenaryData, state: BattleState, goal: Vector3i,
		lines: Array[String], hide: bool, max_moves: int, avoid: bool = false) -> Dictionary:
	var out: Dictionary = {"walked": 0, "seen_by": {}, "unseen": 0, "waited": false}
	if goal == PathTargeter.NO_CELL or state == null or state.battlefield == null:
		return out
	var waits: Dictionary = state.rescue["waits"]
	for _move: int in range(max_moves):
		if state.pos3(merc) == goal:
			break
		if StateEffects.is_blocked(merc, "action:move") or PaceBudget.pace_per_move(merc) <= 0:
			break
		if state.get_pace_pool(merc) <= 0:
			if not state.can_afford(merc, state.get_cost(merc, "Move Close", _CONFIG.move_base_ap)):
				break
			PaceBudget.buy_move(merc, state, "Move Close")
		var pace: int = state.get_pace_pool(merc)
		if pace <= 0:
			break
		var path: Array[Vector3i] = []
		if avoid:
			path = detour_path(merc, state, goal)
		if path.size() < 2:
			path = path_to(merc, state, goal)
		if path.size() < 2:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("RESCUE: %s finds no path to (%d,%d) F%d" % [
					merc.merc_name, goal.x, goal.y, goal.z])
			break
		var limit: int = mini(pace, path.size() - 1)
		var steps: int = limit
		if hide:
			var safe: int = 0
			for cand: int in range(1, limit + 1):
				if not _exposure(state, path, cand, merc).is_empty():
					break
				if not state.is_position_occupied(Vector2i(path[cand].x, path[cand].y), merc, path[cand].z):
					safe = cand
			if safe > 0:
				steps = safe
			else:
				var used: int = int(waits.get(merc, 0))
				if used < RescueSystem.MAX_WAITS and _exposure(state, path, 0, merc).is_empty():
					waits[merc] = used + 1
					out["waited"] = true
					lines.append("  %s waits in cover (%d/%d)." % [
						BattleState.colored_name(merc, state), used + 1, RescueSystem.MAX_WAITS])
					break
		var stepped: Array[Vector3i] = walk(merc, state, path, steps, lines)
		if stepped.is_empty():
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("RESCUE: %s cannot step to (%d,%d) F%d" % [
					merc.merc_name, path[1].x, path[1].y, path[1].z])
			break
		out["walked"] = int(out["walked"]) + stepped.size()
		if hide:
			for cell: Vector3i in stepped:
				var seers: Dictionary = RescueGrid.cell_seers(state, cell, merc)
				if seers.is_empty():
					out["unseen"] = int(out["unseen"]) + 1
				else:
					for key: Variant in seers.keys():
						(out["seen_by"] as Dictionary)[key] = true
	return out


#Steps the merc along a path one cell at a time, opening a shut door in the way.
static func walk(merc: MercenaryData, state: BattleState, path: Array[Vector3i], max_paces: int,
		lines: Array[String]) -> Array[Vector3i]:
	var stepped: Array[Vector3i] = []
	var field: BattlefieldArea = state.battlefield
	if field == null or path.size() < 2 or max_paces <= 0:
		return stepped
	var left: int = mini(max_paces, state.get_pace_pool(merc))
	var i: int = 1
	#Pace owed for standing allies crossed since the last free cell; paid only on reaching one.
	var crossing: int = 0
	while i < path.size() and left > 0:
		var cell: Vector3i = path[i]
		var flat := Vector2i(cell.x, cell.y)
		if state.is_position_occupied(flat, merc, cell.z):
			if MovementExecutor._get_standing_ally_at(cell, merc, state) == null:
				break
			crossing += 1
			left -= 1
			i += 1
			continue
		if PathCost.is_shut_door(field, cell):
			var door: Dictionary = field.get_obs(flat, cell.z)
			if DungeonLocks.is_locked(door) and not DungeonLocks.can_open(merc, door, state):
				break
			if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
				break
			if not InteractionSystem.perform(merc, door, cell, state, lines, " during move"):
				break
		state.set_pos3(merc, cell)
		state.set_pace_pool(merc, maxi(0, state.get_pace_pool(merc) - 1 - crossing))
		crossing = 0
		left -= 1
		stepped.append(cell)
		i += 1
	if not stepped.is_empty():
		var last: Vector3i = stepped[stepped.size() - 1]
		lines.append("  %s moves to (%d,%d) F%d. (AP: %d)" % [
			BattleState.colored_name(merc, state), last.x, last.y, last.z, merc.current_ap])
	return stepped


#The walk from the merc to the goal; the reachable field is widened once when the first try finds no path.
static func path_to(merc: MercenaryData, state: BattleState, goal: Vector3i) -> Array[Vector3i]:
	var from: Vector3i = state.pos3(merc)
	var path: Array[Vector3i] = ReachCache.walk_path_for(merc, state, from, goal)
	if path.size() < 2:
		ReachCache.reachable_far_for(merc, state, [goal])
		path = ReachCache.walk_path_for(merc, state, from, goal)
	return path


#A walk to the goal that steps on no enemy cell; empty when the enemies shut every way.
static func detour_path(merc: MercenaryData, state: BattleState, goal: Vector3i) -> Array[Vector3i]:
	var empty: Array[Vector3i] = []
	var field: BattlefieldArea = state.battlefield
	if field == null or goal == PathTargeter.NO_CELL:
		return empty
	var blocked: Dictionary = {}
	for key: Variant in RescueSystem.enemy_cells(state).keys():
		blocked[key] = true
	if blocked.has(goal):
		return empty
	PathCost.set_mover_doors(merc, state)
	var path: Array[Vector3i] = Pathfinder.find_path(state.pos3(merc), goal, field,
		state.ally_passable_3d(merc), PathTargeter.fall_tolerance(merc), PathTargeter.is_flying(merc),
		true, int(merc.stats.get("size", 1)), state.get_height(merc), blocked)
	return path if path.size() >= 2 else empty


#Enemies that can see any cell of path[0..upto].
static func _exposure(state: BattleState, path: Array[Vector3i], upto: int,
		merc: MercenaryData) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(0, mini(upto, path.size() - 1) + 1):
		for key: Variant in RescueGrid.cell_seers(state, path[i], merc).keys():
			out[key] = true
	return out


#First living enemy standing on the path ahead; null when the way is open.
static func path_blocker(state: BattleState, path: Array[Vector3i]) -> MercenaryData:
	var spots: Dictionary = RescueSystem.enemy_cells(state)
	for i: int in range(1, path.size()):
		if spots.has(path[i]):
			return spots[path[i]] as MercenaryData
	return null


#What a hidden merc does about an enemy on its path. Pure: every input is a plain flag.
static func blocked_decision(has_detour: bool, free_before: bool, is_captive: bool, favored: bool,
		fixed: bool, may_abort: bool) -> String:
	if has_detour:
		return RescueSystem.CALL_DETOUR
	if free_before:
		return RescueSystem.CALL_GO
	if is_captive:
		return RescueSystem.CALL_WAIT
	if favored:
		return RescueSystem.CALL_AMBUSH
	if may_abort:
		return RescueSystem.CALL_ABORT
	if fixed:
		return RescueSystem.CALL_AMBUSH
	return RescueSystem.CALL_WAIT


#Reads the way to the goal and settles wait, detour, ambush or abort; applies the wait and ambush itself.
static func blocked_call(merc: MercenaryData, state: BattleState, goal: Vector3i,
		lines: Array[String]) -> String:
	var rescue: Dictionary = state.rescue
	var counts: Dictionary = rescue["block_waits"]
	var own: Vector3i = state.pos3(merc)
	var path: Array[Vector3i] = RescueWalk.path_to(merc, state, goal)
	var blocker: MercenaryData = RescueWalk.path_blocker(state, path)
	if blocker == null:
		counts.erase(merc)
		return RescueSystem.CALL_GO
	var used: int = int(counts.get(merc, 0))
	var at: int = path.find(state.pos3(blocker))
	var free_before: bool = false
	for i: int in range(1, at):
		if not state.is_position_occupied(Vector2i(path[i].x, path[i].y), merc, path[i].z):
			free_before = true
			break
	if free_before and used < RescueSystem.BLOCK_WAITS:
		return RescueSystem.CALL_GO
	if used < RescueSystem.BLOCK_WAITS and RescueGrid.cell_seers(state, own, merc).is_empty():
		counts[merc] = used + 1
		rescue["block_wait_turns"] = int(rescue.get("block_wait_turns", 0)) + 1
		lines.append("  %s waits for the way to clear (%d/%d)." % [
			BattleState.colored_name(merc, state), used + 1, RescueSystem.BLOCK_WAITS])
		return RescueSystem.CALL_WAIT
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var role: String = str((rescue["roles"] as Dictionary).get(blocker, ""))
	var fixed: bool = role != RescueSystem.ROLE_WANDER and role != RescueSystem.ROLE_PATROL
	var may_abort: bool = not bool(rescue["freed"]) and not bool(rescue.get("aborted", false)) \
		and goal != (rescue["exit_cell"] as Vector3i)
	var o: float = RescueTactics.odds(state)
	var favored: bool = o >= RescueTune.tuned("ambush_odds")
	var has_detour: bool = not RescueWalk.detour_path(merc, state, goal).is_empty()
	var call_name: String = blocked_decision(has_detour, free_before, merc == captive, favored, fixed, may_abort)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("RESCUE BLOCKED: %s by %s calls %s (detour %s, odds %d%%, fixed %s)" % [
			merc.merc_name, blocker.merc_name, call_name, str(has_detour),
			roundi(o * 100.0), str(fixed)])
	if call_name == RescueSystem.CALL_DETOUR:
		rescue["detours"] = int(rescue.get("detours", 0)) + 1
	elif call_name == RescueSystem.CALL_WAIT:
		rescue["block_wait_turns"] = int(rescue.get("block_wait_turns", 0)) + 1
		lines.append("  %s waits for the way to clear." % BattleState.colored_name(merc, state))
	elif call_name == RescueSystem.CALL_AMBUSH:
		RescueStealth.spring_ambush(state, merc, blocker, lines)
	return call_name


#The party gives the captive up while still unseen and heads for the exit.
static func abort(state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("aborted", false)):
		return
	rescue["aborted"] = true
	lines.append("RESCUE: the way is shut and the odds are poor; the party pulls out.")

class_name RescueStealth extends RefCounted

#The stealth contest, the alarm and the ambush that a spotted creep sets off.


#One enemy looks over every hidden rescuer it can see.
static func notice_scan(enemy: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue["alarm"]):
		return
	var watch: Array[MercenaryData] = []
	for m: MercenaryData in state.teams[0]:
		watch.append(m)
	#The caged captive is no intruder; only a freed one can be spotted.
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if captive != null and bool(rescue["freed"]) and not watch.has(captive):
		watch.append(captive)
	for m: MercenaryData in watch:
		if not BattleState._is_alive(m) or not ConstStates.has_state(m, RescueSystem.STATE_HIDDEN):
			continue
		sight_contest(state, enemy, m, lines)


#The contest between an enemy and a hidden merc, run only while the alarm is down and the enemy can see it.
static func sight_contest(state: BattleState, enemy: MercenaryData, hidden: MercenaryData,
		lines: Array[String]) -> void:
	if bool(state.rescue["alarm"]):
		return
	if not bool(LineOfSight.check(state, enemy, hidden).get("visible", false)):
		return
	contest(hidden, enemy, 0, state, lines)


#Grace against Notice; a loss raises the alarm.
static func contest(hidden: MercenaryData, enemy: MercenaryData, unseen_paces: int,
		state: BattleState, lines: Array[String]) -> bool:
	if hidden == null or enemy == null:
		return true
	var a_def: Dictionary = CheckSystem.grace_def(unseen_paces)
	var b_def: Dictionary = CheckSystem.notice_def()
	var r: Dictionary = CheckSystem.opposed_check(hidden, enemy, a_def, b_def)
	var stays: bool = bool(r["a_wins"]) or bool(r["tie"])
	lines.append("  STEALTH: %s (Grace, +%de) vs %s (Notice): %s" % [
		BattleState.colored_name(hidden, state), unseen_paces,
		BattleState.colored_name(enemy, state), "unseen" if stays else "SPOTTED"])
	if not stays:
		_raise_alarm(state, enemy, hidden, lines)
	return stays


#Raises the alarm and logs the line; false when the alarm was already up.
static func _rouse(state: BattleState, lines: Array[String], line: String) -> bool:
	var rescue: Dictionary = state.rescue
	if bool(rescue["alarm"]):
		return false
	rescue["alarm"] = true
	rescue["alarm_round"] = state.round_number
	(rescue["waits"] as Dictionary).clear()
	(rescue["block_waits"] as Dictionary).clear()
	(rescue["roles"] as Dictionary).clear()
	clear_hidden(state)
	lines.append(line)
	return true


static func _raise_alarm(state: BattleState, spotter: MercenaryData, spotted: MercenaryData,
		lines: Array[String]) -> void:
	_rouse(state, lines, "ALARM: %s spots %s; the dungeon is roused." % [spotter.merc_name, spotted.merc_name])


#The hidden merc gives up its cover to strike first; the alarm follows at once.
static func spring_ambush(state: BattleState, merc: MercenaryData, blocker: MercenaryData,
		lines: Array[String]) -> void:
	var line: String = "AMBUSH: %s strikes from hiding at %s; the dungeon is roused." % [
		merc.merc_name, blocker.merc_name]
	if _rouse(state, lines, line):
		state.rescue["ambushes"] = int(state.rescue.get("ambushes", 0)) + 1


static func start_hidden(state: BattleState) -> void:
	var removal: Array[String] = []
	for m: MercenaryData in state.teams[0]:
		StateCascade.apply_state(m, RescueSystem.STATE_HIDDEN, null, "", "engine:rescue", removal, true)
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if captive != null:
		StateCascade.apply_state(captive, RescueSystem.STATE_HIDDEN, null, "", "engine:rescue", removal, true)


static func clear_hidden(state: BattleState) -> void:
	for team: Array in state.teams:
		for m: MercenaryData in team:
			if ConstStates.has_state(m, RescueSystem.STATE_HIDDEN):
				StateCascade.remove_state(m, RescueSystem.STATE_HIDDEN)
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if captive != null and ConstStates.has_state(captive, RescueSystem.STATE_HIDDEN):
		StateCascade.remove_state(captive, RescueSystem.STATE_HIDDEN)


static func enemy_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	var role: String = str((rescue["roles"] as Dictionary).get(merc, ""))
	if role == RescueSystem.ROLE_WANDER:
		_wander(merc, state, lines)
	elif role == RescueSystem.ROLE_PATROL:
		_patrol(merc, state, lines)
	else:
		lines.append("  %s keeps watch." % BattleState.colored_name(merc, state))
	RescueStealth.notice_scan(merc, state, lines)


static func _wander(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var goals: Dictionary = state.rescue["wander_goal"]
	var goal: Vector3i = goals.get(merc, PathTargeter.NO_CELL) as Vector3i
	if goal == PathTargeter.NO_CELL or goal == state.pos3(merc):
		goal = _new_wander_goal(merc, state)
		goals[merc] = goal
	if goal == PathTargeter.NO_CELL:
		lines.append("  %s keeps watch." % BattleState.colored_name(merc, state))
		return
	RescueWalk.hidden_moves(merc, state, goal, lines, false, 1)


static func _new_wander_goal(merc: MercenaryData, state: BattleState) -> Vector3i:
	var reach: Dictionary = ReachCache.reachable_for(merc, state)
	var own: Vector3i = state.pos3(merc)
	var rect: Rect2i = state.rescue["cell_rect"] as Rect2i
	var cell_floor: int = int(state.rescue["cell_floor"])
	var options: Array[Vector3i] = []
	for key: Variant in reach.keys():
		var cell: Vector3i = key as Vector3i
		if cell == own or int(reach[key]) >= PathTargeter.JUMP_COST_OFFSET:
			continue
		if cell.z == cell_floor and rect.has_point(Vector2i(cell.x, cell.y)):
			continue
		options.append(cell)
	if options.is_empty():
		return PathTargeter.NO_CELL
	return options[randi() % options.size()]


static func _patrol(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var goals: Dictionary = state.rescue["patrol_goals"]
	var pair: Array = goals.get(merc, []) as Array
	if pair.is_empty():
		lines.append("  %s keeps watch." % BattleState.colored_name(merc, state))
		return
	var goal: Vector3i = pair[0] as Vector3i
	if goal == state.pos3(merc) or goal == PathTargeter.NO_CELL:
		pair.reverse()
		goals[merc] = pair
		goal = pair[0] as Vector3i
	if goal == PathTargeter.NO_CELL or goal == state.pos3(merc):
		lines.append("  %s keeps watch." % BattleState.colored_name(merc, state))
		return
	RescueWalk.hidden_moves(merc, state, goal, lines, false, 1)

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
		if bool(rescue["alarm"]):
			return
		if not BattleState._is_alive(m) or not ConstStates.has_state(m, RescueSystem.STATE_HIDDEN):
			continue
		if not bool(LineOfSight.check(state, enemy, m).get("visible", false)):
			continue
		contest(m, enemy, 0, state, lines)


#Grace against Notice; a loss raises the alarm.
static func contest(hidden: MercenaryData, enemy: MercenaryData, unseen_paces: int,
		state: BattleState, lines: Array[String]) -> bool:
	if hidden == null or enemy == null:
		return true
	var a_def: Dictionary = {"stat_keys": ["dexterity"],
		"circumstances": [ConstCircumstances.GRACE_DEXTERITY], "knowledges": [], "tools": [],
		"formula": "luck", "flat_threshold_bonus": 0.0, "enhancements": unseen_paces}
	var b_def: Dictionary = {"stat_keys": ["cognition"],
		"circumstances": [ConstCircumstances.NOTICE_COGNITION], "knowledges": [], "tools": [],
		"formula": "luck", "flat_threshold_bonus": 0.0}
	var r: Dictionary = CheckSystem.opposed_check(hidden, enemy, a_def, b_def)
	var stays: bool = bool(r["a_wins"]) or bool(r["tie"])
	lines.append("  STEALTH: %s (Grace, +%de) vs %s (Notice): %s" % [
		BattleState.colored_name(hidden, state), unseen_paces,
		BattleState.colored_name(enemy, state), "unseen" if stays else "SPOTTED"])
	if not stays:
		_raise_alarm(state, enemy, hidden, lines)
	return stays


static func _raise_alarm(state: BattleState, spotter: MercenaryData, spotted: MercenaryData,
		lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue["alarm"]):
		return
	rescue["alarm"] = true
	rescue["alarm_round"] = state.round_number
	(rescue["waits"] as Dictionary).clear()
	(rescue["block_waits"] as Dictionary).clear()
	(rescue["roles"] as Dictionary).clear()
	clear_hidden(state)
	lines.append("ALARM: %s spots %s; the dungeon is roused." % [spotter.merc_name, spotted.merc_name])


#The hidden merc gives up its cover to strike first; the alarm follows at once.
static func spring_ambush(state: BattleState, merc: MercenaryData, blocker: MercenaryData,
		lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue["alarm"]):
		return
	rescue["alarm"] = true
	rescue["alarm_round"] = state.round_number
	rescue["ambushes"] = int(rescue.get("ambushes", 0)) + 1
	(rescue["waits"] as Dictionary).clear()
	(rescue["block_waits"] as Dictionary).clear()
	(rescue["roles"] as Dictionary).clear()
	clear_hidden(state)
	lines.append("AMBUSH: %s strikes from hiding at %s; the dungeon is roused." % [
		merc.merc_name, blocker.merc_name])


static func start_hidden(state: BattleState) -> void:
	var removal: Array[String] = []
	for m: MercenaryData in state.teams[0]:
		ConstStates.apply_state(m, RescueSystem.STATE_HIDDEN, null, "", "engine:rescue", removal, true)
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if captive != null:
		ConstStates.apply_state(captive, RescueSystem.STATE_HIDDEN, null, "", "engine:rescue", removal, true)


static func clear_hidden(state: BattleState) -> void:
	for team: Array in state.teams:
		for m: MercenaryData in team:
			if ConstStates.has_state(m, RescueSystem.STATE_HIDDEN):
				ConstStates.remove_state(m, RescueSystem.STATE_HIDDEN)
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if captive != null and ConstStates.has_state(captive, RescueSystem.STATE_HIDDEN):
		ConstStates.remove_state(captive, RescueSystem.STATE_HIDDEN)

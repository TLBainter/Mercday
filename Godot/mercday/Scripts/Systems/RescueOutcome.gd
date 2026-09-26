class_name RescueOutcome extends RefCounted

#Scores the finished rescue and puts the result into words.


#Everything the campaign side needs to score the event; empty when no rescue ran.
static func outcome(state: BattleState) -> Dictionary:
	if not RescueSystem.is_active(state):
		return {}
	var rescue: Dictionary = state.rescue
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var resolved: bool = bool(rescue.get("resolved", false))
	var alive: bool = bool(rescue["captive_alive"]) if resolved else RescueSystem.captive_alive(captive)
	var cleared: bool = bool(rescue["cleared"]) if resolved else RescueSystem.enemies_dead(state)
	var success: bool = bool(rescue["success"]) if resolved \
		else alive and (bool(rescue["captive_exited"]) or cleared)
	return {
		"mode": str(rescue["mode"]),
		"result": str(rescue["result"]),
		"success": success,
		"alarm": bool(rescue["alarm"]),
		"alarm_round": int(rescue["alarm_round"]),
		"freed": bool(rescue["freed"]),
		"freed_round": int(rescue["freed_round"]),
		"captive_exited": bool(rescue["captive_exited"]),
		"exit_round": int(rescue["exit_round"]),
		"enemies_dead": cleared,
		"rounds": state.round_number,
		"loot_restored": int(rescue["loot_restored"]),
		"picks": int(rescue["picks"]),
		"pick_fails": int(rescue["pick_fails"]),
		"captive": captive,
		"captive_alive": alive,
		"exited": state.exited.size(),
		"reason": str(rescue.get("reason", "")),
		"party_exits": int(rescue["party_exits"]),
		"party_dead": int(rescue.get("party_dead", 0)) if resolved else _party_dead(state),
		"start_odds": float(rescue.get("start_odds", -1.0)),
		"min_odds": float(rescue.get("min_odds", -1.0)),
		"abandoned": bool(rescue["abandoned"]),
		"go_count": int(rescue["go_count"]),
		"stay_count": int(rescue["stay_count"]),
		"gate_runs": int(rescue["gate_runs"]),
		"escort_turns": int(rescue["escort_turns"]),
		"withdraw_turns": int(rescue["withdraw_turns"]),
		"fall_back_turns": int(rescue["fall_back_turns"]),
		"shelter_turns": int(rescue.get("shelter_turns", 0)),
		"hide_turns": int(rescue.get("hide_turns", 0)),
		"door_opens": int(rescue.get("door_opens", 0)),
		"block_wait_turns": int(rescue.get("block_wait_turns", 0)),
		"detours": int(rescue.get("detours", 0)),
		"ambushes": int(rescue.get("ambushes", 0)),
		"aborted": bool(rescue.get("aborted", false)),
		"captive_acted": bool(rescue.get("captive_acted", false)),
		"gate_hopeless": bool(rescue["gate_hopeless"]),
	}


#Frees a captive left caged by a cleared dungeon, empties the chests and scores the event.
static func on_battle_end(state: BattleState, lines: Array[String]) -> void:
	if not RescueSystem.is_active(state):
		return
	var rescue: Dictionary = state.rescue
	if bool(rescue["done"]):
		return
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var field: BattlefieldArea = state.battlefield
	var cleared: bool = RescueSystem.enemies_dead(state)
	var alive: bool = RescueSystem.captive_alive(captive)
	if not bool(rescue["freed"]) and cleared and alive:
		RescueSystem.free_captive(state, lines, null, true)
	if not state.teams[0].has(captive):
		state.teams[0].append(captive)
	state._merc_team_index[captive] = 0
	for m: MercenaryData in state.exited:
		m.off_field = false
	var restored: int = ChestLoot.loot_all(field, captive)
	rescue["loot_restored"] = restored
	for m: MercenaryData in state.teams[0]:
		ChestLoot.wear_carried_armor(m)
	if restored > 0:
		lines.append("LOOT: %d item(s) recovered from %d chest(s)." % [restored, ChestLoot.chests(field).size()])
	RescueStealth.clear_hidden(state)
	var wiped: bool = RescueSystem.team_wiped(state)
	var success: bool = alive and (bool(rescue["captive_exited"]) or cleared)
	var result: String = RescueSystem.RESULT_FAILED
	if success and str(rescue["mode"]) == RescueSystem.MODE_STEALTH and not bool(rescue["alarm"]):
		result = RescueSystem.RESULT_STEALTH
	elif success:
		result = RescueSystem.RESULT_COMBAT
	var left: String = _party_left(state)
	var reason: String = "round_limit"
	if not alive:
		reason = "captive_dead"
	elif wiped:
		reason = "wiped"
	elif bool(rescue["captive_exited"]) and str(rescue["mode"]) == RescueSystem.MODE_COMBAT:
		reason = "exit_fight"
	elif bool(rescue["captive_exited"]) and not bool(rescue["alarm"]):
		reason = "exit_unseen"
	elif bool(rescue["captive_exited"]):
		reason = "exit_alarm"
	elif cleared:
		reason = "cleared"
	elif bool(rescue.get("aborted", false)) and not bool(rescue["alarm"]):
		reason = "aborted"
	elif left != "":
		reason = left
	elif not bool(rescue["freed"]):
		reason = "never_opened"
	rescue["reason"] = reason
	rescue["result"] = result
	rescue["cleared"] = cleared
	rescue["success"] = success
	rescue["wiped"] = wiped
	rescue["party_dead"] = _party_dead(state)
	rescue["captive_alive"] = alive
	rescue["resolved"] = true
	rescue["done"] = true
	state._cached_winner = 0 if (success or cleared) else 1
	lines.append("RESCUE RESULT: %s (%s)" % [result, reason_text(reason)])


#Plain words for one of the rescue reason codes.
static func reason_text(code: String) -> String:
	match code:
		"captive_dead":
			return "the captive died"
		"wiped":
			return "the party was wiped out"
		"exit_unseen":
			return "the captive walked out unseen"
		"exit_alarm":
			return "the captive walked out after the alarm"
		"exit_fight":
			return "the captive walked out during the fight"
		"cleared":
			return "the dungeon was cleared"
		"withdrew":
			return "the party pulled out without the captive"
		"routed":
			return "the last rescuers fled the dungeon"
		"aborted":
			return "the party left unseen without the captive"
		"never_opened":
			return "the cell was never opened"
	return "the round limit ran out"


#"" while a rescuer still stands inside; "withdrew" when any walked out, "routed" when the rest only fled.
static func _party_left(state: BattleState) -> String:
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	var exits: int = 0
	var ran: int = 0
	for m: MercenaryData in state.teams[0]:
		if m == captive:
			continue
		if state.exited.has(m):
			exits += 1
		elif state.escaped.has(m):
			ran += 1
		elif not m.is_dead and m.current_hp > 0:
			return ""
	if exits > 0:
		return "withdrew"
	return "routed" if ran > 0 else ""


#Rescuers other than the captive that the dungeon killed.
static func _party_dead(state: BattleState) -> int:
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	var n: int = 0
	for m: MercenaryData in state.teams[0]:
		if m == captive:
			continue
		if m.is_dead or m.current_hp <= 0:
			n += 1
	return n

class_name BetrayalTests
#Run: godot --headless --path . -- --betrayal-tests
#Pre-battle betrayal: who qualifies, the roll and the campaign gate, the side switch and the contract bookkeeping.

const TRAITOR := "Traitor"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	BetrayalSystem.reset()
	_case_qualifies(res)
	_case_npc_battle(res)
	_case_should_run(res)
	_case_threshold(res)
	_case_first_time(res)
	_case_gate(res)
	_case_several(res)
	_case_switch_team(res)
	_case_line_order(res)
	_case_helpers(res)
	_case_lifepath(res)
	_case_review(res)
	await _case_end_to_end(res)
	BetrayalSystem.reset()
	CheckSystem.forced_rolls.clear()
	return TestFixtures.summarize(res, "BETRAYAL")


#AmbushTests._merc plus an Unsavory value, full hit points and a campaign uid.
static func _merc(name: String, luck: float, unsavory: float) -> MercenaryData:
	return TestFixtures.fixed_merc(name, {"luck": luck, "unsavory": unsavory})


static func _state(side_a: Array[MercenaryData], side_b: Array[MercenaryData]) -> BattleState:
	return TestFixtures.battle_state(side_a, side_b)


static func _run(team: Array[MercenaryData], unsavory_contract: bool) -> ContractRun:
	var r := ContractRun.new()
	r.contract = ContractData.new()
	r.contract.unsavory = unsavory_contract
	r.team.assign(team)
	return r


static func _event(enemy_cell: String) -> EventData:
	var ev := EventData.new()
	ev.event_name = "Test Battle"
	ev.success_formula = "Battle"
	ev.enemy = enemy_cell
	return ev


#create() keeps the side arrays as its teams, so the roster the betrayal pass reads must be a separate array.
static func _copy(list: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	out.assign(list)
	return out


static func _foes() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = [_merc("Bandit", 40.0, 0.0)]
	return out


#One pre-battle pass on an unmarked contract against one bandit; returns run, state and switched.
static func _pass(team: Array[MercenaryData], rolls: Array) -> Dictionary:
	var cr := _run(team, false)
	var st := _state(_copy(team), _foes())
	BetrayalSystem.forced_rolls.assign(rolls)
	var switched: Array[MercenaryData] = BetrayalSystem.run_pre_battle(cr, st, team)
	return {"run": cr, "state": st, "switched": switched}


static func _count(lines: Array[String], prefix: String) -> int:
	var n: int = 0
	for line: String in lines:
		if line.begins_with(prefix):
			n += 1
	return n


static func _first(lines: Array[String], prefix: String) -> String:
	for line: String in lines:
		if line.begins_with(prefix):
			return line
	return ""


static func _only(list: Array, merc: MercenaryData) -> bool:
	return list.size() == 1 and list[0] == merc


static func _drained(res: Dictionary, label: String) -> void:
	TestFixtures.check(res, label, BetrayalSystem.forced_rolls.is_empty(),
		"rolls left %d" % BetrayalSystem.forced_rolls.size())


static func _gate_detail() -> String:
	return "gate %.1f betrayals %d rolls left %d" % [BetrayalSystem.gate_percent, BetrayalSystem.betrayals,
		BetrayalSystem.forced_rolls.size()]


static func _case_qualifies(res: Dictionary) -> void:
	var none: Array[MercenaryData] = []
	var plain := _run(none, false)
	var marked := _run(none, true)
	TestFixtures.check(res, "qualifies_bar", BetrayalSystem.qualifies(_merc("A", 40.0, 50.0), plain),
		"unsavory 50, unmarked contract")
	TestFixtures.check(res, "qualifies_below_bar", not BetrayalSystem.qualifies(_merc("B", 40.0, 49.9), plain),
		"unsavory 49.9, unmarked contract")
	TestFixtures.check(res, "qualifies_clean_marked", BetrayalSystem.qualifies(_merc("C", 40.0, 0.0), marked),
		"unsavory 0, unsavory contract")
	TestFixtures.check(res, "qualifies_clean_unmarked", not BetrayalSystem.qualifies(_merc("D", 40.0, 0.0), plain),
		"unsavory 0, unmarked contract")
	TestFixtures.check(res, "qualifies_mild_marked", not BetrayalSystem.qualifies(_merc("E", 40.0, 10.0), marked),
		"unsavory 10, unsavory contract")
	var dead := _merc("F", 40.0, 60.0)
	dead.is_dead = true
	TestFixtures.check(res, "qualifies_dead", not BetrayalSystem.qualifies(dead, plain), "unsavory 60, is_dead")


static func _case_npc_battle(res: Dictionary) -> void:
	TestFixtures.check(res, "npc_mercs", BetrayalSystem.is_npc_battle(_event("Mercs")), "Mercs")
	TestFixtures.check(res, "npc_taverngoer", BetrayalSystem.is_npc_battle(_event("Taverngoer")), "Taverngoer")
	TestFixtures.check(res, "npc_bandit_crew",
		BetrayalSystem.is_npc_battle(_event("Bandit Leader, Bandit Melee, Bandit Ranged")), "bandit crew")
	TestFixtures.check(res, "npc_blank", not BetrayalSystem.is_npc_battle(_event("")), "blank enemy cell")
	TestFixtures.check(res, "npc_unknown_term", not BetrayalSystem.is_npc_battle(_event("Bandit Leader, Nobody")),
		"Nobody is no NPC template")
	var talk := _event("Mercs")
	talk.success_formula = "15"
	TestFixtures.check(res, "npc_not_battle", not BetrayalSystem.is_npc_battle(talk), "formula event")


static func _case_should_run(res: Dictionary) -> void:
	TestFixtures.check(res, "should_run_opt_out", not BetrayalSystem.should_run(_event("Mercs"), {"betrayal": false}),
		"betrayal false")
	TestFixtures.check(res, "should_run_non_npc", not BetrayalSystem.should_run(_event(""), {}), "blank enemy cell")
	TestFixtures.check(res, "should_run_mercs", BetrayalSystem.should_run(_event("Mercs"), {}), "Mercs, no options")


static func _case_threshold(res: Dictionary) -> void:
	BetrayalSystem.reset()
	var t := _merc(TRAITOR, 40.0, 60.0)
	var team: Array[MercenaryData] = [_merc("Ada", 40.0, 0.0), _merc("Bo", 40.0, 0.0), t]
	var p: Dictionary = _pass(team, [1])
	var st: BattleState = p["state"]
	var want: String = "BETRAYAL ROLL: %s d100 1 vs Luck 40.0 minus Unsavory 60.0 = -20.0 -> betrays" % TRAITOR
	var got: String = _first(st.pre_battle_lines, "BETRAYAL ROLL: ")
	TestFixtures.check(res, "threshold_fires", _only(p["switched"], t) and (st.teams[1] as Array).has(t),
		"d100 1 against -20")
	TestFixtures.check(res, "threshold_line", got == want, got)
	_drained(res, "threshold_fire_drained")
	BetrayalSystem.reset()
	var h := _merc(TRAITOR, 80.0, 50.0)
	var team2: Array[MercenaryData] = [_merc("Cy", 80.0, 0.0), _merc("Di", 80.0, 0.0), h]
	var p2: Dictionary = _pass(team2, [20])
	var st2: BattleState = p2["state"]
	TestFixtures.check(res, "threshold_holds", (p2["switched"] as Array).is_empty() and (st2.teams[0] as Array).has(h),
		_first(st2.pre_battle_lines, "BETRAYAL ROLL: "))
	_drained(res, "threshold_hold_drained")


static func _case_first_time(res: Dictionary) -> void:
	BetrayalSystem.reset()
	var t := _merc(TRAITOR, 40.0, 60.0)
	var team: Array[MercenaryData] = [_merc("Ada", 40.0, 0.0), t]
	var p: Dictionary = _pass(team, [100])
	var st: BattleState = p["state"]
	var roll: String = _first(st.pre_battle_lines, "BETRAYAL ROLL: ")
	TestFixtures.check(res, "first_time_no_gate", _only(p["switched"], t) and roll.contains(" d100 100 ")
		and _count(st.pre_battle_lines, "BETRAYAL GATE: ") == 0, " | ".join(st.pre_battle_lines))
	_drained(res, "first_time_one_roll")


static func _case_gate(res: Dictionary) -> void:
	BetrayalSystem.reset()
	var opener: Array[MercenaryData] = [_merc("Ada", 40.0, 0.0), _merc(TRAITOR, 40.0, 60.0)]
	var _opened: Dictionary = _pass(opener, [100])
	TestFixtures.check(res, "gate_after_betrayal", is_equal_approx(BetrayalSystem.gate_percent, 1.0)
		and BetrayalSystem.betrayals == 1 and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())
	var shut_team: Array[MercenaryData] = [_merc("Bo", 40.0, 0.0), _merc(TRAITOR, 40.0, 60.0)]
	var shut: Dictionary = _pass(shut_team, [2])
	var shut_st: BattleState = shut["state"]
	TestFixtures.check(res, "gate_shut", (shut["switched"] as Array).is_empty()
		and _first(shut_st.pre_battle_lines, "BETRAYAL GATE: ") == "BETRAYAL GATE: d100 2 vs 1% -> shut"
		and _count(shut_st.pre_battle_lines, "BETRAYAL ROLL: ") == 0, " | ".join(shut_st.pre_battle_lines))
	TestFixtures.check(res, "gate_shut_unchanged", is_equal_approx(BetrayalSystem.gate_percent, 1.0)
		and BetrayalSystem.betrayals == 1 and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())
	var hold_team: Array[MercenaryData] = [_merc("Cy", 80.0, 0.0), _merc(TRAITOR, 80.0, 50.0)]
	var held: Dictionary = _pass(hold_team, [1, 20])
	var held_st: BattleState = held["state"]
	TestFixtures.check(res, "gate_doubles", is_equal_approx(BetrayalSystem.gate_percent, 2.0)
		and _count(held_st.pre_battle_lines, "BETRAYAL GATE: every roll held") == 1
		and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())
	var pair_hold: Array[MercenaryData] = [_merc("Di", 80.0, 0.0), _merc("Hold One", 80.0, 50.0),
		_merc("Hold Two", 80.0, 50.0)]
	var both: Dictionary = _pass(pair_hold, [1, 20, 20])
	var both_st: BattleState = both["state"]
	TestFixtures.check(res, "gate_doubles_once", is_equal_approx(BetrayalSystem.gate_percent, 4.0)
		and _count(both_st.pre_battle_lines, "BETRAYAL ROLL: ") == 2
		and _count(both_st.pre_battle_lines, "BETRAYAL GATE: every roll held") == 1
		and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())
	BetrayalSystem.gate_percent = 64.0
	var cap_team: Array[MercenaryData] = [_merc("Ed", 80.0, 0.0), _merc(TRAITOR, 80.0, 50.0)]
	var _capped: Dictionary = _pass(cap_team, [1, 20])
	TestFixtures.check(res, "gate_cap", is_equal_approx(BetrayalSystem.gate_percent, 100.0)
		and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())
	var pair_turn: Array[MercenaryData] = [_merc("Flo", 40.0, 0.0), _merc("Turn One", 40.0, 60.0),
		_merc("Turn Two", 40.0, 60.0)]
	var turned: Dictionary = _pass(pair_turn, [1, 100, 100])
	TestFixtures.check(res, "gate_two_switches", (turned["switched"] as Array).size() == 2
		and BetrayalSystem.betrayals == 3 and is_equal_approx(BetrayalSystem.gate_percent, 1.0)
		and BetrayalSystem.forced_rolls.is_empty(), _gate_detail())


static func _case_several(res: Dictionary) -> void:
	BetrayalSystem.reset()
	var a := _merc("Turn One", 40.0, 60.0)
	var b := _merc("Turn Two", 40.0, 60.0)
	var three: Array[MercenaryData] = [_merc("Gus", 40.0, 0.0), a, b]
	var p: Dictionary = _pass(three, [100, 100])
	var st: BattleState = p["state"]
	var side: Array = st.teams[1]
	TestFixtures.check(res, "several_both_switch", (p["switched"] as Array).size() == 2 and side.has(a) and side.has(b)
		and BetrayalSystem.forced_rolls.is_empty(), " | ".join(st.pre_battle_lines))
	BetrayalSystem.reset()
	var c := _merc("Turn Three", 40.0, 60.0)
	var d := _merc("Turn Four", 40.0, 60.0)
	var two: Array[MercenaryData] = [c, d]
	var p2: Dictionary = _pass(two, [100])
	var st2: BattleState = p2["state"]
	var sw2: Array = p2["switched"]
	var stayed: MercenaryData = d if sw2.has(c) else c
	TestFixtures.check(res, "several_first_switches", sw2.size() == 1
		and _count(st2.pre_battle_lines, "BETRAYAL ROLL: ") == 1 and BetrayalSystem.forced_rolls.is_empty(),
		" | ".join(st2.pre_battle_lines))
	TestFixtures.check(res, "several_second_skipped", _first(st2.pre_battle_lines, "BETRAYAL SKIPPED: ")
		== "BETRAYAL SKIPPED: %s (no loyal merc would remain)" % stayed.merc_name, " | ".join(st2.pre_battle_lines))
	BetrayalSystem.reset()
	var lone := _merc(TRAITOR, 40.0, 60.0)
	var one: Array[MercenaryData] = [lone]
	var p3: Dictionary = _pass(one, [])
	var st3: BattleState = p3["state"]
	TestFixtures.check(res, "several_lone_skipped", (p3["switched"] as Array).is_empty()
		and _count(st3.pre_battle_lines, "BETRAYAL SKIPPED: ") == 1
		and _count(st3.pre_battle_lines, "BETRAYAL ROLL: ") == 0 and (st3.teams[0] as Array).has(lone),
		" | ".join(st3.pre_battle_lines))


static func _case_switch_team(res: Dictionary) -> void:
	var ally := _merc("Ada", 40.0, 0.0)
	var t := _merc(TRAITOR, 40.0, 60.0)
	var foe := _merc("Bandit", 40.0, 0.0)
	var side_a: Array[MercenaryData] = [ally, t]
	var side_b: Array[MercenaryData] = [foe]
	var st := _state(side_a, side_b)
	TestFixtures.place(st, ally, Vector2i(2, 2))
	TestFixtures.place(st, t, Vector2i(3, 4))
	TestFixtures.place(st, foe, Vector2i(9, 9))
	var queue_at: int = st.turn_queue.find(t)
	st.move_goals[t] = Vector3i(5, 5, 0)
	st.move_targets[t] = foe
	st.move_targets[ally] = t
	st.last_attacked[t] = foe
	st.last_attacked[foe] = t
	st.movement_blocked[t] = {foe: true}
	st.movement_blocked[ally] = {t: true, foe: true}
	st.no_target_turns[t] = 2
	st.team_blocked_round[t] = 1
	st.team_blocked_count[t] = 1
	st.pending_interact[t] = Vector3i(4, 4, 0)
	st.pace_pool[t] = 3
	st.move_plan[t] = {"moves_allowed": 1, "reserve_ap": 0}
	st.no_progress_rounds[t] = 1
	st.position_history[t] = [Vector2i(3, 4)]
	ally.last_known_enemy_positions[t] = Vector3i(3, 4, 0)
	foe.last_known_enemy_positions[t] = Vector3i(3, 4, 0)
	t.last_known_enemy_positions[foe] = Vector3i(9, 9, 0)
	var caches: Array[Dictionary] = [st.move_goals, st.move_targets, st.last_attacked, st.movement_blocked,
		st.no_target_turns, st.team_blocked_round, st.team_blocked_count, st.pending_interact, st.pace_pool,
		st.move_plan, st.no_progress_rounds, st.position_history]
	var names: Array[String] = ["move_goals", "move_targets", "last_attacked", "movement_blocked",
		"no_target_turns", "team_blocked_round", "team_blocked_count", "pending_interact", "pace_pool",
		"move_plan", "no_progress_rounds", "position_history"]
	var to: int = st.switch_team(t)
	TestFixtures.check(res, "switch_returns_side", to == 1, "returned %d" % to)
	var kept: Array[String] = []
	for i: int in range(caches.size()):
		if caches[i].has(t):
			kept.append(names[i])
	TestFixtures.check(res, "switch_keys_cleared", kept.is_empty(),
		"left in %s" % (", ".join(kept) if not kept.is_empty() else "none"))
	TestFixtures.check(res, "switch_pointers_cleared", not st.move_targets.has(ally) and not st.last_attacked.has(foe),
		"move_targets %d last_attacked %d" % [st.move_targets.size(), st.last_attacked.size()])
	var blocked: Dictionary = st.movement_blocked.get(ally, {})
	TestFixtures.check(res, "switch_blocked_entry", not blocked.has(t) and blocked.has(foe),
		"ally blocks %d" % blocked.size())
	TestFixtures.check(res, "switch_sightings", not ally.last_known_enemy_positions.has(t)
		and not foe.last_known_enemy_positions.has(t) and t.last_known_enemy_positions.is_empty(),
		"traitor sightings %d" % t.last_known_enemy_positions.size())
	TestFixtures.check(res, "switch_sides", (st.teams[1] as Array).has(t) and not (st.teams[0] as Array).has(t),
		"team sizes %d/%d" % [(st.teams[0] as Array).size(), (st.teams[1] as Array).size()])
	TestFixtures.check(res, "switch_ally_view", st.get_enemies(ally).has(t) and not st.get_allies(ally).has(t)
		and st.get_allies(foe).has(t), "former ally sees the traitor as an enemy")
	TestFixtures.check(res, "switch_defected", _only(st.defected, t), "defected %d" % st.defected.size())
	TestFixtures.check(res, "switch_place_kept", st.positions.get(t) == Vector2i(3, 4)
		and st.turn_queue.find(t) == queue_at, "queue slot %d was %d" % [st.turn_queue.find(t), queue_at])
	var outsider := _merc("Stranger", 40.0, 60.0)
	TestFixtures.check(res, "switch_outsider", st.switch_team(outsider) == -1, "merc not in the battle")


static func _case_line_order(res: Dictionary) -> void:
	BetrayalSystem.reset()
	BetrayalSystem.betrayals = 1
	BetrayalSystem.gate_percent = 1.0
	var team: Array[MercenaryData] = [_merc("Ada", 40.0, 0.0), _merc(TRAITOR, 40.0, 60.0)]
	var p: Dictionary = _pass(team, [1, 100])
	var st: BattleState = p["state"]
	var cr: ContractRun = p["run"]
	var lines: Array[String] = st.pre_battle_lines
	TestFixtures.check(res, "lines_in_order", lines.size() == 3 and lines[0].begins_with("BETRAYAL GATE: ")
		and lines[1].begins_with("BETRAYAL ROLL: ") and lines[2] == "BETRAYAL: %s turns on the party!" % TRAITOR,
		" | ".join(lines))
	TestFixtures.check(res, "lines_in_run_log", cr.log_lines == lines, " | ".join(cr.log_lines))
	_drained(res, "lines_drained")
	BetrayalSystem.reset()


static func _case_helpers(res: Dictionary) -> void:
	var a := _merc("Ada", 40.0, 0.0)
	var b := _merc("Bo", 40.0, 0.0)
	var t := _merc(TRAITOR, 40.0, 60.0)
	var e1 := _merc("Bandit One", 40.0, 0.0)
	var e2 := _merc("Bandit Two", 40.0, 0.0)
	var roster: Array[MercenaryData] = [a, b, t]
	var enemies: Array[MercenaryData] = [e1, e2]
	var st := _state(_copy(roster), _copy(enemies))
	var _side: int = st.switch_team(t)
	var foe_list := BetrayalSystem.foes(enemies, st)
	TestFixtures.check(res, "helpers_foes", foe_list.size() == 3 and foe_list[0] == e1 and foe_list[1] == e2
		and foe_list[2] == t, "foes %d" % foe_list.size())
	var loyal_list := BetrayalSystem.loyal(roster, st)
	TestFixtures.check(res, "helpers_loyal", loyal_list.size() == 2 and loyal_list[0] == a and loyal_list[1] == b,
		"loyal %d" % loyal_list.size())
	var cr := _run(roster, false)
	cr.betrayers.append(t)
	var lines := BetrayalSystem.settle(cr, st)
	TestFixtures.check(res, "helpers_settle_living", not cr.team.has(t) and _only(cr.defectors, t)
		and lines.has("DEFECTED: %s" % TRAITOR), " | ".join(lines))
	var casualty_order: Array[MercenaryData] = [e1, t, a]
	st.casualties.assign(casualty_order)
	var dead := BetrayalSystem.dead_of(st, roster)
	TestFixtures.check(res, "helpers_dead_of", dead.size() == 2 and dead[0] == t and dead[1] == a,
		", ".join(cr.merc_names(dead)))
	var t2 := _merc("Dead Traitor", 40.0, 60.0)
	var roster2: Array[MercenaryData] = [_merc("Cy", 40.0, 0.0), _merc("Di", 40.0, 0.0), t2]
	var st2 := _state(_copy(roster2), _copy(enemies))
	var _side2: int = st2.switch_team(t2)
	t2.is_dead = true
	t2.current_hp = 0
	var fallen: Array[MercenaryData] = [t2]
	st2.casualties.assign(fallen)
	var cr2 := _run(roster2, false)
	cr2.betrayers.append(t2)
	var lines2 := BetrayalSystem.settle(cr2, st2)
	TestFixtures.check(res, "helpers_settle_dead", lines2.is_empty() and cr2.team.has(t2) and cr2.defectors.is_empty(),
		" | ".join(lines2))
	var _moved: Array[MercenaryData] = cr2.remove_dead(BetrayalSystem.dead_of(st2, roster2))
	TestFixtures.check(res, "helpers_dead_traitor_casualty", cr2.casualties.has(t2) and cr2.betrayers.has(t2)
		and not cr2.team.has(t2), "casualties %d betrayers %d" % [cr2.casualties.size(), cr2.betrayers.size()])
	var key: String = OverallSuccess.STAT_KEY
	t.stats[key] = 14.0
	a.stats[key] = 22.5
	var record: Dictionary = {t: 4.0, a: 2.5}
	BetrayalSystem.drop_delta(record, t)
	var after_drop: float = float(t.stats[key])
	OverallSuccess.revert_event_delta(record)
	TestFixtures.check(res, "helpers_drop_delta", is_equal_approx(after_drop, 10.0) and not record.has(t)
		and is_equal_approx(float(t.stats[key]), 10.0) and is_equal_approx(float(a.stats[key]), 20.0),
		"traitor %.1f loyal %.1f" % [float(t.stats[key]), float(a.stats[key])])


static func _case_lifepath(res: Dictionary) -> void:
	CampaignKnowledge.clear()
	RelationshipSystem.clear_tallies()
	var m := _merc("Ada", 40.0, 0.0)
	var mate := _merc("Bo", 40.0, 0.0)
	var t := _merc(TRAITOR, 40.0, 60.0)
	var team: Array[MercenaryData] = [m, mate, t]
	var cr := _run(team, false)
	cr.betrayers.append(t)
	RelationshipSystem.set_value(m, t, 3)
	TestFixtures.check(res, "lifepath_betrayer_3", TestFixtures.ok(m, cr, "Betrayer Relationship", "IS >=", "3"), "relationship 3")
	RelationshipSystem.set_value(m, t, 2)
	TestFixtures.check(res, "lifepath_betrayer_2", not TestFixtures.ok(m, cr, "Betrayer Relationship", "IS >=", "3"),
		"relationship 2")
	RelationshipSystem.set_value(m, mate, 5)
	RelationshipSystem.set_value(m, t, 0)
	TestFixtures.check(res, "lifepath_loyal_mate_ignored", not TestFixtures.ok(m, cr, "Betrayer Relationship", "IS >=", "3"),
		"5 toward a loyal teammate, 0 toward the betrayer")
	RelationshipSystem.set_value(m, t, 3)
	t.is_dead = true
	var fallen: Array[MercenaryData] = [t]
	var _moved: Array[MercenaryData] = cr.remove_dead(fallen)
	TestFixtures.check(res, "lifepath_dead_betrayer", TestFixtures.ok(m, cr, "Betrayer Relationship", "IS >=", "3")
		and cr.casualties.has(t), "betrayer dead and in casualties")
	var clean := _run(team, false)
	TestFixtures.check(res, "lifepath_no_betrayers", not TestFixtures.ok(m, clean, "Betrayer Relationship", "IS >=", "3"),
		"betrayers empty")
	TestFixtures.check(res, "lifepath_event_unmarked", not TestFixtures.ok(m, cr, "Contract Event", "IS", "Betrayal"), "no mark")
	cr.add_event_mark("Betrayal")
	TestFixtures.check(res, "lifepath_event_mark", TestFixtures.ok(m, cr, "Contract Event", "IS", "Betrayal"), "Betrayal mark")
	var betrayed := TestFixtures.lifepath("Betrayed")
	TestFixtures.check(res, "lifepath_betrayed_row", betrayed != null and betrayed.requirements.size() == 2,
		"requirements %d" % (betrayed.requirements.size() if betrayed != null else -1))
	if betrayed != null:
		TestFixtures.check(res, "lifepath_betrayed_allows", LifepathRequirements.allows(m, betrayed, cr),
			"mark and relationship 3")
		RelationshipSystem.set_value(m, t, 2)
		TestFixtures.check(res, "lifepath_betrayed_refuses", not LifepathRequirements.allows(m, betrayed, cr),
			"mark and relationship 2")
	CampaignKnowledge.clear()
	RelationshipSystem.clear_tallies()


#Settle stabilizes a downed defector and drops it from the Beau roster; the roll reads the party average.
static func _case_review(res: Dictionary) -> void:
	BetrayalSystem.reset()
	RelationshipSystem.clear_tallies()
	var ally := _merc("Ada", 40.0, 0.0)
	var t := _merc(TRAITOR, 40.0, 60.0)
	var roster: Array[MercenaryData] = [ally, t]
	var st := _state(_copy(roster), _foes())
	var _side: int = st.switch_team(t)
	t.current_hp = 0
	ConstStates.apply_state(t, ConstStates.DYING)
	var cr := _run(roster, false)
	var saved: Array[MercenaryData] = []
	saved.assign(BeauSystem.roster)
	BeauSystem.set_roster(roster)
	GuildRoster.set_roster(roster)
	var lines := BetrayalSystem.settle(cr, st)
	TestFixtures.check(res, "review_settle_stabilized", _only(cr.defectors, t) and t.current_hp == 1
		and not ConstStates.has_state(t, ConstStates.DYING) and lines.has("DEFECTED: %s" % TRAITOR),
		"hp %d dying %s" % [t.current_hp, str(ConstStates.has_state(t, ConstStates.DYING))])
	TestFixtures.check(res, "review_settle_beau_drop", not BeauSystem.roster.has(t) and BeauSystem.roster.has(ally),
		"roster %d" % BeauSystem.roster.size())
	BeauSystem.set_roster(saved)
	GuildRoster.set_roster(saved)
	BetrayalSystem.reset()
	var uneven: Array[MercenaryData] = [_merc("Bo", 20.0, 0.0), _merc("Cy", 20.0, 0.0), _merc(TRAITOR, 80.0, 60.0)]
	var p: Dictionary = _pass(uneven, [1])
	var st2: BattleState = p["state"]
	var want: String = "BETRAYAL ROLL: %s d100 1 vs Luck 40.0 minus Unsavory 60.0 = -20.0 -> betrays" % TRAITOR
	var got: String = _first(st2.pre_battle_lines, "BETRAYAL ROLL: ")
	TestFixtures.check(res, "review_party_luck", got == want, got)
	_drained(res, "review_party_luck_drained")
	BetrayalSystem.reset()
	var tie_team: Array[MercenaryData] = [_merc("Di", 100.0, 0.0), _merc(TRAITOR, 100.0, 50.0)]
	var tie: Dictionary = _pass(tie_team, [50])
	var tie_st: BattleState = tie["state"]
	var tie_line: String = _first(tie_st.pre_battle_lines, "BETRAYAL ROLL: ")
	TestFixtures.check(res, "review_threshold_tie", (tie["switched"] as Array).is_empty()
		and tie_line.ends_with("= 50.0 -> holds"), tie_line)
	_drained(res, "review_threshold_tie_drained")
	var healthy := _merc("Ed", 40.0, 0.0)
	var downed := _merc("Fay", 40.0, 0.0)
	downed.current_hp = 0
	var dying := _merc("Gus", 40.0, 0.0)
	ConstStates.apply_state(dying, ConstStates.DYING)
	TestFixtures.check(res, "review_standing", BetrayalSystem._standing(healthy)
		and not BetrayalSystem._standing(downed) and not BetrayalSystem._standing(dying),
		"healthy true, hp 0 and Dying false")
	var mate := _merc("Hal", 40.0, 0.0)
	var solo := _merc("Lone Traitor", 40.0, 60.0)
	var self_team: Array[MercenaryData] = [mate, solo]
	var self_run := _run(self_team, false)
	self_run.betrayers.append(solo)
	RelationshipSystem.set_value(mate, solo, 5)
	RelationshipSystem.set_value(solo, mate, 5)
	TestFixtures.check(res, "review_betrayer_self",
		not TestFixtures.ok(solo, self_run, "Betrayer Relationship", "IS >=", "3")
		and TestFixtures.ok(mate, self_run, "Betrayer Relationship", "IS >=", "3"),
		"self %d teammate %d" % [RelationshipSystem.value(solo, solo), RelationshipSystem.value(mate, solo)])
	RelationshipSystem.clear_tallies()
	BetrayalSystem.reset()
	BetrayalSystem.betrayals = 1
	BetrayalSystem.gate_percent = 50.0
	var lone: Array[MercenaryData] = [_merc(TRAITOR, 40.0, 60.0)]
	var opened: Dictionary = _pass(lone, [1])
	var open_st: BattleState = opened["state"]
	TestFixtures.check(res, "review_gate_no_attempt", is_equal_approx(BetrayalSystem.gate_percent, 50.0)
		and _first(open_st.pre_battle_lines, "BETRAYAL GATE: ") == "BETRAYAL GATE: d100 1 vs 50% -> open"
		and _count(open_st.pre_battle_lines, "BETRAYAL SKIPPED: ") == 1
		and _count(open_st.pre_battle_lines, "BETRAYAL ROLL: ") == 0, _gate_detail())
	_drained(res, "review_gate_no_attempt_drained")
	BetrayalSystem.reset()


#The only awaited case: a real Ambush through BattleEventResolver with merc 0 forced to betray.
static func _case_end_to_end(res: Dictionary) -> void:
	CampaignKnowledge.clear()
	var mercs: Array[MercenaryData] = []
	for i: int in range(3):
		mercs.append(HarnessRoster.roster_merc(i))
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
	var contract: ContractData = ContractGenerator.generate(ContractLibrary.config().default_contract_type)
	var event: EventData = ContractLibrary.event("Ambush")
	var places: Array[LocationData] = TestFixtures.wilderness_pool()
	if contract == null or event == null or places.is_empty():
		TestFixtures.check(res, "e2e_setup", false, "contract %s event %s wilderness %d" % [
			str(contract != null), str(event != null), places.size()])
		return
	contract.difficulty = 1.0
	contract.unsavory = false
	var lines: Array[String] = []
	var cr := ContractRun.new()
	cr.contract = contract
	cr.team.assign(mercs)
	cr.location = places[randi() % places.size()]
	cr.line_fn = func(line: String) -> void: lines.append(line)
	var m0: MercenaryData = mercs[0]
	var m1: MercenaryData = mercs[1]
	var m2: MercenaryData = mercs[2]
	StatCalculator.add_flat(m0, "unsavory", 75.0 - float(m0.stats.get("unsavory", 0.0)))
	StatCalculator.refresh(m0)
	TestFixtures.check(res, "e2e_setup", BetrayalSystem.qualifies(m0, cr)
		and not BetrayalSystem.qualifies(m1, cr) and not BetrayalSystem.qualifies(m2, cr),
		"merc 0 unsavory %.1f, mercs 1 and 2 %.1f %.1f" % [float(m0.stats.get("unsavory", 0.0)),
		float(m1.stats.get("unsavory", 0.0)), float(m2.stats.get("unsavory", 0.0))])
	var before: Dictionary = {}
	for merc: MercenaryData in mercs:
		before[merc] = float(merc.stats.get(OverallSuccess.STAT_KEY, 0.0))
	BetrayalSystem.reset()
	BetrayalSystem.forced_rolls.assign([100])
	RelationshipSystem.set_value(m1, m0, 3)
	RelationshipSystem.set_value(m2, m0, 0)
	FleeSystem.enabled = false
	var out: Dictionary = await BattleEventResolver.resolve(event, cr)
	FleeSystem.enabled = true
	var st: BattleState = BattleEventResolver.last_state
	if st == null:
		TestFixtures.check(res, "e2e_battle_ran", false, "no battle state, notes %s" % str(out.get("notes", [])))
		return
	var crew: Array[MercenaryData] = BattleEventResolver.last_enemies
	TestFixtures.check(res, "e2e_betrayers", _only(cr.betrayers, m0), ", ".join(cr.merc_names(cr.betrayers)))
	TestFixtures.check(res, "e2e_defected", _only(st.defected, m0) and (st.teams[1] as Array).has(m0),
		"defected %d" % st.defected.size())
	TestFixtures.check(res, "e2e_enemy_count", not crew.has(m0) and int(out.get("enemy_count", 0)) == crew.size() + 1,
		"enemy_count %d crew %d" % [int(out.get("enemy_count", 0)), crew.size()])
	TestFixtures.check(res, "e2e_left_team", cr.defectors.has(m0) != cr.casualties.has(m0) and not cr.team.has(m0),
		"defectors %d casualties %d team %d" % [cr.defectors.size(), cr.casualties.size(), cr.team.size()])
	TestFixtures.check(res, "e2e_event_mark", cr.event_marks.has("Betrayal"), ", ".join(cr.event_marks))
	TestFixtures.check(res, "e2e_betrayal_line", _count(lines, "BETRAYAL: ") >= 1, "%d lines" % lines.size())
	_drained(res, "e2e_drained")
	var drift: Array[String] = []
	for merc: MercenaryData in mercs:
		var now: float = float(merc.stats.get(OverallSuccess.STAT_KEY, 0.0))
		if not is_equal_approx(now, float(before[merc])):
			drift.append("%s %.3f -> %.3f" % [merc.merc_name, float(before[merc]), now])
	TestFixtures.check(res, "e2e_overall_success", drift.is_empty(),
		"; ".join(drift) if not drift.is_empty() else "unchanged")
	var betrayed := TestFixtures.lifepath("Betrayed")
	if betrayed == null:
		TestFixtures.check(res, "e2e_betrayed_row", false, "no Betrayed lifepath row")
	else:
		TestFixtures.check(res, "e2e_betrayed_allows", LifepathRequirements.allows(m1, betrayed, cr), "relationship 3")
		TestFixtures.check(res, "e2e_betrayed_refuses", not LifepathRequirements.allows(m2, betrayed, cr),
			"relationship 0")

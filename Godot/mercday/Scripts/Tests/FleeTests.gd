class_name FleeTests
#Run: godot --headless --path . -- --flee-tests
#Flee checks and flags, the escape goal, Withdraw, Aid, pursuit weights and the post-battle settle.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	MercPool.clear()
	_case_stat_formula(res)
	_case_swing(res)
	_case_spread(res)
	_case_gate(res)
	_case_abandon(res)
	_case_immune(res)
	_case_apply_source(res)
	_case_aid(res)
	_case_turn_start(res)
	_case_escape_goal(res)
	_case_withdraw(res)
	_case_run_turn(res)
	_case_bank(res)
	_case_pick_target(res)
	_case_escaping_bonus(res)
	_case_settle_return(res)
	_case_settle_abandon(res)
	_case_settle_held(res)
	_case_settle_npc(res)
	_case_pool(res)
	_case_settle_clear(res)
	_case_disabled(res)
	_fresh()
	MercPool.clear()
	return TestFixtures.summarize(res, "FLEE")


static func _fresh() -> void:
	FleeSystem.reset()
	FleeSystem.forced.clear()
	CheckSystem.forced_rolls.clear()


static func _merc(merc_name: String, flee: float) -> MercenaryData:
	return TestFixtures.fixed_merc(merc_name, {"luck": 5.0, "flee": flee})


#An enemy whose only action is an Advantage Attack on a mover leaving its melee range.
static func _reactor(merc_name: String) -> MercenaryData:
	var m := _merc(merc_name, 0.0)
	var drawn := WeaponTypeFacet.new()
	drawn.is_required = true
	drawn.require_drawn = true
	var near := WasInMeleeRangeFacet.new()
	near.is_required = true
	var dd := DecisionData.new()
	dd.facets.append(drawn)
	dd.facets.append(near)
	dd.threshold = 0.8
	var act := ActionData.new()
	act.action_name = "Advantage Attack"
	act.is_reactive = true
	act.trigger = "enemy_leaves_melee_range"
	act.ep_cost = 1
	act.ap_cost = 0
	act.execution_type = "attack"
	act.target_mode = "mover"
	act.decision = dd
	var aset := MercActionSet.new()
	aset.actions.append(act)
	m.action_set = aset
	return m


#Called after BattleState.create, which clears a weapon the merc does not hold.
static func _arm(m: MercenaryData) -> void:
	var w := WeaponData.new()
	w.melee_range = 1
	w.is_ranged = false
	m.equipped_weapon = w
	m.weapon_drawn = true
	m.current_ep = 5


static func _path_state(m: MercenaryData, foe: MercenaryData, field: BattlefieldArea, at: Vector2i,
		foe_at: Vector2i) -> BattleState:
	var a: Array[MercenaryData] = [m]
	var b: Array[MercenaryData] = [foe]
	var st := TestFixtures.battle_state(a, b, field)
	TestFixtures.place(st, m, at)
	TestFixtures.place(st, foe, foe_at)
	MovementExecutor.clear_caches()
	FleeSystem.begin_battle(st)
	return st


static func _flee_on(m: MercenaryData) -> void:
	m.flee_intent = true
	var rm: Array[String] = ["interact"]
	StateCascade.apply_state(m, ConstStates.TERRIFIED, null, "", "engine:flee", rm)


#A fresh flee state: one merc at this flee against one foe, hp set when above zero, passive added before the state exists.
static func _solo(merc_name: String, flee: float, foe_name: String, hp: int = 19,
		passive: String = "") -> Dictionary:
	_fresh()
	var m := _merc(merc_name, flee)
	if not passive.is_empty():
		m.passive_effects.append(passive)
	var foe := _merc(foe_name, 0.0)
	var a: Array[MercenaryData] = [m]
	var b: Array[MercenaryData] = [foe]
	var st := TestFixtures.battle_state(a, b)
	if hp > 0:
		m.current_hp = hp
	var lines: Array[String] = []
	return {"merc": m, "foe": foe, "lines": lines, "state": st}


#Queues the flee rolls, runs the solo merc's start of turn and stores the result under "ran".
static func _roll_run(solo: Dictionary, rolls: Array) -> Dictionary:
	var m: MercenaryData = solo["merc"]
	var st: BattleState = solo["state"]
	var lines: Array[String] = solo["lines"]
	FleeSystem.forced_rolls.assign(rolls)
	solo["ran"] = FleeSystem.start_of_turn(m, st, lines)
	return solo


#Flee 60 against a full-health foe with rolls 10 then 20: runs and abandons.
static func _abandon_run(emboldened: bool) -> Dictionary:
	var solo := _solo("Abe Runner", 60.0, "Foe One")
	if emboldened:
		var m: MercenaryData = solo["merc"]
		StateCascade.apply_state(m, ConstStates.EMBOLDENED)
	return _roll_run(solo, [10, 20])


static func _index(lines: Array[String], needle: String) -> int:
	for i: int in range(lines.size()):
		if lines[i].find(needle) >= 0:
			return i
	return -1


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _edge(c: Vector3i, field: BattlefieldArea) -> bool:
	return c.x <= 0 or c.y <= 0 or c.x >= field.width - 1 or c.y >= field.length - 1


static func _find_source(m: MercenaryData, kind: String, src_name: String) -> bool:
	for src: Dictionary in StateSources.state_sources(m, ConstStates.TERRIFIED):
		if str(src.get("kind", "")) == kind and str(src.get("name", "")) == src_name:
			return true
	return false


static func _case_stat_formula(res: Dictionary) -> void:
	var low := TestFixtures.sheet_merc("Hal Low", 5.0, {"max_vigor": 2, "max_wile": 1})
	var lv := int(low.stats.get("vigor", -1))
	var lw := int(low.stats.get("wile", -1))
	var lh := float(low.stats.get("healthiness", 0.0))
	var la := float(low.stats.get("avoid", 0.0))
	var lf := float(low.stats.get("flee", -999.0))
	TestFixtures.check(res, "negative healthiness leaves flee at avoid",
		lv == 1 and lw == 0 and lh < 0.0 and is_equal_approx(lf, la),
		"vigor %d wile %d healthiness %.2f avoid %.2f flee %.2f" % [lv, lw, lh, la, lf])
	var high := TestFixtures.sheet_merc("Hal High", 50.0, {"max_vigor": 2, "max_wile": 1})
	var hw := float(high.stats.get("wile", -1))
	var hh := float(high.stats.get("healthiness", 0.0))
	var ha := float(high.stats.get("avoid", 0.0))
	var hf := float(high.stats.get("flee", -999.0))
	var want := ha - maxf(0.0, hh) * maxf(1.0, hw)
	TestFixtures.check(res, "wile 0 counts as 1",
		int(hw) == 0 and hh > 0.0 and is_equal_approx(hf, want) and is_equal_approx(hf, ha - hh),
		"wile %d healthiness %.2f avoid %.2f flee %.2f want %.2f" % [int(hw), hh, ha, hf, want])


static func _case_swing(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Sam Swing", 0.0)
	var d := _merc("Dan Dead", 0.0)
	var r := _merc("Rex Out", 0.0)
	var e := _merc("Eve Gone", 0.0)
	var f1 := _merc("Foe Hurt", 0.0)
	var f2 := _merc("Foe Whole", 0.0)
	var a: Array[MercenaryData] = [m, d, r, e]
	var b: Array[MercenaryData] = [f1, f2]
	var st := TestFixtures.battle_state(a, b)
	var lines: Array[String] = []
	m.current_hp = 15
	d.current_hp = 0
	d.is_dead = true
	st.remove_from_field(r, "out", lines)
	st.remove_from_field(e, "fled", lines)
	f1.current_hp = 10
	var own := (5.0 + 20.0 + 20.0) / 60.0 * 100.0
	var foe := 10.0 / 40.0 * 100.0
	var sw := FleeSystem.swing(m, st)
	TestFixtures.check(res, "swing skips the escaped member", is_equal_approx(sw, own - foe),
		"swing %.2f want %.2f" % [sw, own - foe])


static func _case_spread(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Pip Spread", 54.0)
	var t1 := _merc("Tod Runs", 0.0)
	var t2 := _merc("Ula Gone", 0.0)
	var t3 := _merc("Vic Stays", 0.0)
	var a: Array[MercenaryData] = [m, t1, t2, t3]
	var b: Array[MercenaryData] = [_merc("Foe Two", 0.0)]
	var st := TestFixtures.battle_state(a, b)
	var lines: Array[String] = []
	_flee_on(t1)
	st.remove_from_field(t2, "fled", lines)
	m.current_hp = 19
	var sp := FleeSystem.spread(m, st)
	TestFixtures.check(res, "spread counts fleeing and escaped teammates", is_equal_approx(sp, 50.0),
		"spread %.1f" % sp)
	FleeSystem.forced_rolls.assign([100, 28])
	var ran := FleeSystem.start_of_turn(m, st, lines)
	TestFixtures.check(res, "spread carries the first roll, 28 over half returns",
		ran and m.flee_intent and not m.flee_abandons and FleeSystem.forced_rolls.is_empty(),
		"ran %s abandons %s rolls left %d" % [ran, m.flee_abandons, FleeSystem.forced_rolls.size()])


static func _case_gate(res: Dictionary) -> void:
	var over := _roll_run(_solo("Gil Gate", 46.0, "Foe Three"), [100])
	var lines: Array[String] = over["lines"]
	TestFixtures.check(res, "flee 51 rolls and stays",
		not over["ran"] and FleeSystem.checks_rolled == 1 and TestFixtures.has_line(lines, "-> stays"),
		"checks %d lines %s" % [FleeSystem.checks_rolled, str(lines)])
	var under := _roll_run(_solo("Gil Under", 45.9, "Foe Four"), [100])
	TestFixtures.check(res, "flee 50.9 does not roll",
		not under["ran"] and FleeSystem.checks_rolled == 0 and FleeSystem.forced_rolls.size() == 1,
		"checks %d rolls left %d" % [FleeSystem.checks_rolled, FleeSystem.forced_rolls.size()])
	var even := _roll_run(_solo("Gil Even", 80.0, "Foe Even", 0), [10])
	var w: MercenaryData = even["merc"]
	var f: MercenaryData = even["foe"]
	var st3: BattleState = even["state"]
	var lines3: Array[String] = even["lines"]
	var ran3: bool = even["ran"]
	w.current_hp = 15
	f.current_hp = 10
	var ran4 := FleeSystem.start_of_turn(w, st3, lines3)
	TestFixtures.check(res, "flee 80 with no losing swing does not roll",
		not ran3 and not ran4 and FleeSystem.checks_rolled == 0 and FleeSystem.forced_rolls.size() == 1,
		"checks %d rolls left %d" % [FleeSystem.checks_rolled, FleeSystem.forced_rolls.size()])
	FleeSystem.forced_rolls.clear()


static func _case_abandon(res: Dictionary) -> void:
	var plain := _abandon_run(false)
	var m: MercenaryData = plain["merc"]
	var lines: Array[String] = plain["lines"]
	TestFixtures.check(res, "roll 20 under half abandons",
		bool(plain["ran"]) and m.flee_intent and m.flee_abandons
		and ConstStates.has_state(m, ConstStates.TERRIFIED) and TestFixtures.has_line(lines, "breaks and runs!"),
		"lines %s" % str(lines))
	var bold := _abandon_run(true)
	var bm: MercenaryData = bold["merc"]
	var blines: Array[String] = bold["lines"]
	var same := not lines.is_empty() and not blines.is_empty() and lines[0] == blines[0]
	TestFixtures.check(res, "Emboldened leaves the flee rolls alone",
		bool(bold["ran"]) and bm.flee_intent and bm.flee_abandons and same
		and ConstStates.has_state(bm, ConstStates.EMBOLDENED),
		"%s / %s" % [str(lines.slice(0, 1)), str(blines.slice(0, 1))])


static func _case_immune(res: Dictionary) -> void:
	var solo := _solo("Ivo Brave", 60.0, "Foe Five", 19, "immune:terrified")
	var m: MercenaryData = solo["merc"]
	var st: BattleState = solo["state"]
	var lines: Array[String] = solo["lines"]
	var r1: bool = _roll_run(solo, [10, 20])["ran"]
	var r2 := FleeSystem.start_of_turn(m, st, lines)
	TestFixtures.check(res, "immune merc never rolls and logs once",
		not r1 and not r2 and FleeSystem.checks_rolled == 0 and FleeSystem.forced_rolls.size() == 2
		and TestFixtures.count_lines(lines, "FLEE IMMUNE") == 1,
		"checks %d rolls left %d lines %s" % [FleeSystem.checks_rolled, FleeSystem.forced_rolls.size(), str(lines)])
	FleeSystem.forced_rolls.clear()


static func _case_apply_source(res: Dictionary) -> void:
	var first := _abandon_run(false)
	var m: MercenaryData = first["merc"]
	var st: BattleState = first["state"]
	TestFixtures.check(res, "flee Terrified has no timer and an engine flee source",
		st.get_state_timer(m, ConstStates.TERRIFIED).is_empty() and _find_source(m, "engine", "flee"),
		"sources %s" % str(StateSources.state_sources(m, ConstStates.TERRIFIED)))
	_fresh()
	var k := _merc("Kit Kept", 60.0)
	var foe := _merc("Foe Six", 0.0)
	var a: Array[MercenaryData] = [k]
	var b: Array[MercenaryData] = [foe]
	var st2 := TestFixtures.battle_state(a, b)
	k.current_hp = 19
	StateCascade.apply_state(k, ConstStates.TERRIFIED, foe, "", "inflict:Test")
	st2.set_state_timer(k, ConstStates.TERRIFIED, 5, "Resist:Wile:3")
	FleeSystem.forced_rolls.assign([10, 20])
	var lines: Array[String] = []
	var ran := FleeSystem.start_of_turn(k, st2, lines)
	var src := ConstStates.get_source(k, ConstStates.TERRIFIED)
	TestFixtures.check(res, "an enemy Terrified keeps its source and loses its timer",
		ran and src == foe and _find_source(k, "inflict", "Test") and _find_source(k, "engine", "flee")
		and st2.get_state_timer(k, ConstStates.TERRIFIED).is_empty(),
		"source %s sources %s" % [src.merc_name if src != null else "none",
			str(StateSources.state_sources(k, ConstStates.TERRIFIED))])


static func _case_aid(res: Dictionary) -> void:
	_fresh()
	var helper := _merc("Hana Help", 0.0)
	var m := _merc("Milo Fled", 0.0)
	var foe := _merc("Foe Seven", 0.0)
	var a: Array[MercenaryData] = [helper, m]
	var b: Array[MercenaryData] = [foe]
	var st := TestFixtures.battle_state(a, b)
	TestFixtures.place(st, helper, Vector2i(5, 5))
	TestFixtures.place(st, m, Vector2i(6, 5))
	TestFixtures.place(st, foe, Vector2i(20, 20))
	_flee_on(m)
	m.flee_abandons = true
	m.flee_escape_paces = 4
	helper.current_ap = 5
	var verdict := StateReliefEvaluator.best_aid(helper, {"state": st})
	var ally: MercenaryData = verdict.get("ally")
	TestFixtures.check(res, "relief verdict names the flee Terrified",
		str(verdict.get("state", "")) == ConstStates.TERRIFIED and ally == m,
		"state %s ally %s" % [str(verdict.get("state", "")), ally.merc_name if ally != null else "none"])
	var lines := SpecialActionSystem.execute({"action_name": "aid_ally", "target": m,
		"state_name": ConstStates.TERRIFIED}, helper, st, {})
	TestFixtures.check(res, "Aid ends Terrified and the flee",
		not ConstStates.has_state(m, ConstStates.TERRIFIED) and not m.flee_intent and not m.flee_abandons
		and m.flee_escape_paces == 0 and TestFixtures.has_line(lines, "FLEE ENDED"),
		"lines %s" % str(lines))
	RelationshipSystem.clear_tallies()


static func _case_turn_start(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Lev Loop", 10.0)
	var a: Array[MercenaryData] = [m]
	var b: Array[MercenaryData] = [_merc("Foe Eight", 0.0)]
	var st := TestFixtures.battle_state(a, b)
	_flee_on(m)
	st.set_state_timer(m, ConstStates.TERRIFIED, 3, "Resist:Wile:3")
	var lines: Array[String] = []
	var kept := FleeSystem.start_of_turn(m, st, lines)
	TestFixtures.check(res, "a fleeing merc keeps running and loses the timer",
		kept and st.get_state_timer(m, ConstStates.TERRIFIED).is_empty() and FleeSystem.checks_rolled == 0,
		"kept %s checks %d" % [kept, FleeSystem.checks_rolled])
	StateCascade.remove_state(m, ConstStates.TERRIFIED)
	var lines2: Array[String] = []
	var again := FleeSystem.start_of_turn(m, st, lines2)
	TestFixtures.check(res, "Terrified gone ends the flee below the gate",
		not again and TestFixtures.has_line(lines2, "FLEE ENDED") and not m.flee_intent,
		"again %s lines %s" % [again, str(lines2)])


static func _case_escape_goal(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Nia Near", 0.0)
	var field := TestFixtures.exterior_field()
	var st := _path_state(m, _merc("Foe Far", 0.0), field, Vector2i(3, 5), Vector2i(20, 20))
	var g := FleeGoal.escape_goal(m, st)
	var probe: Array = [g]
	var cost := int(ReachCache.reachable_far_for(m, st, probe).get(g, -1))
	TestFixtures.check(res, "open field goal is an edge cell 3 paces off", _edge(g, field) and cost == 3,
		"goal %s cost %d" % [str(g), cost])
	_fresh()
	var n := _merc("Ola Corner", 0.0)
	var st2 := _path_state(n, _merc("Foe Near", 0.0), TestFixtures.exterior_field(), Vector2i(1, 5),
		Vector2i(0, 4))
	var g2 := FleeGoal.escape_goal(n, st2)
	TestFixtures.check(res, "goal skips the edge cell beside an enemy",
		g2 != PathTargeter.NO_CELL and g2 != Vector3i(0, 5, 0) and _cheb(Vector2i(g2.x, g2.y), Vector2i(0, 4)) > 1,
		"goal %s" % str(g2))
	_fresh()
	var walled := TestFixtures.exterior_field()
	for y: int in range(walled.length):
		TestFixtures.put(walled, Vector3i(0, y, 0), {"cell_type": "wall", "height": 4.0})
	var w := _merc("Pia Wall", 0.0)
	var st3 := _path_state(w, _merc("Foe Wall", 0.0), walled, Vector2i(3, 5), Vector2i(20, 20))
	var g3 := FleeGoal.escape_goal(w, st3)
	TestFixtures.check(res, "walled edge column is never the goal", g3 != PathTargeter.NO_CELL and g3.x != 0,
		"goal %s" % str(g3))
	_fresh()
	var boxed := TestFixtures.exterior_field()
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if dx != 0 or dy != 0:
				TestFixtures.put(boxed, Vector3i(5 + dx, 5 + dy, 0), {"cell_type": "wall", "height": 4.0})
	var bx := _merc("Quin Boxed", 0.0)
	var st4 := _path_state(bx, _merc("Foe Box", 0.0), boxed, Vector2i(5, 5), Vector2i(20, 20))
	var g4 := FleeGoal.escape_goal(bx, st4)
	TestFixtures.check(res, "boxed-in merc gets no goal", g4 == PathTargeter.NO_CELL, "goal %s" % str(g4))
	st4.battlefield = null
	var g5 := FleeGoal.escape_goal(bx, st4)
	TestFixtures.check(res, "no battlefield gives no goal", g5 == PathTargeter.NO_CELL, "goal %s" % str(g5))


static func _case_withdraw(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Rui Withdraw", 0.0)
	var r := _reactor("Foe Blade")
	var st := _path_state(m, r, TestFixtures.exterior_field(), Vector2i(3, 5), Vector2i(4, 5))
	_arm(r)
	_flee_on(m)
	var facet := AdvantageThreatFacet.new()
	var ctx := {"state": st}
	var danger := FleeGoal.in_danger(m, st)
	var score := facet.evaluate(m, ctx)
	TestFixtures.check(res, "an adjacent reactor is a danger", danger and is_equal_approx(score, 1.0),
		"in_danger %s facet %.1f" % [danger, score])
	st.start_of_turn(m)
	st.set_pace_pool(m, 1)
	var from := st.get_position(m)
	var lines := SpecialActionSystem.execute({"action_name": "withdraw", "target": r}, m, st, {})
	var moved := _cheb(from, st.get_position(m))
	TestFixtures.check(res, "Withdraw sets the immunity and counts",
		TestFixtures.has_line(lines, "withdraws!") and m.advantage_immune and FleeSystem.withdraws == 1,
		"immune %s withdraws %d lines %s" % [m.advantage_immune, FleeSystem.withdraws, str(lines)])
	TestFixtures.check(res, "Withdraw walks at most 2 paces and restores the pool",
		moved >= 1 and moved <= 2 and st.get_pace_pool(m) == 1,
		"moved %d pool %d" % [moved, st.get_pace_pool(m)])
	TestFixtures.check(res, "no Advantage Attack on the Withdraw",
		not TestFixtures.has_line(lines, "Advantage Attack") and r.current_ep == 5, "reactor ep %d" % r.current_ep)
	var none := MovementExecutor.advantage_attacks(m, st, from, Vector2i(from.x - 1, from.y), 0)
	TestFixtures.check(res, "an immune mover draws no reaction", none.is_empty(), "lines %s" % str(none))
	var turn_lines: Array[String] = []
	AutoBattle.process_start_of_turn_states(m, st, turn_lines)
	TestFixtures.check(res, "turn start clears the immunity", not m.advantage_immune,
		"immune %s" % m.advantage_immune)
	TestFixtures.place(st, r, Vector2i(20, 20))
	var calm := FleeGoal.in_danger(m, st)
	var calm_score := facet.evaluate(m, ctx)
	TestFixtures.check(res, "no reactor in range is no danger", not calm and is_equal_approx(calm_score, 0.0),
		"in_danger %s facet %.1f" % [calm, calm_score])


static func _case_run_turn(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Cal Turn", 0.0)
	var r := _reactor("Foe Twelve")
	var st := _path_state(m, r, TestFixtures.exterior_field(), Vector2i(3, 5), Vector2i(4, 5))
	_arm(r)
	_flee_on(m)
	st.start_of_turn(m)
	var lines: Array[String] = []
	FleeMover.run_turn(m, st, lines, 0)
	var w := _index(lines, "withdraws!")
	var mv := _index(lines, " <- ")
	TestFixtures.check(res, "run_turn withdraws before the first Move",
		w >= 0 and mv > w and FleeSystem.withdraws == 1 and m.advantage_immune,
		"withdraw %d move %d lines %s" % [w, mv, str(lines)])
	_fresh()
	var e := _merc("Dee Edge", 0.0)
	var st2 := _path_state(e, _merc("Foe Thirteen", 0.0), TestFixtures.exterior_field(), Vector2i(1, 5),
		Vector2i(20, 20))
	_flee_on(e)
	st2.start_of_turn(e)
	var lines2: Array[String] = []
	FleeMover.run_turn(e, st2, lines2, 0)
	TestFixtures.check(res, "run_turn banks paces once the runner reaches the edge",
		FleeGoal.on_edge(e, st2) and e.flee_escape_paces > 0 and st2.get_pace_pool(e) == 0
		and TestFixtures.has_line(lines2, "FLEE TRACK: %s" % e.merc_name),
		"paces %d pool %d lines %s" % [e.flee_escape_paces, st2.get_pace_pool(e), str(lines2)])


static func _case_bank(res: Dictionary) -> void:
	_fresh()
	var m := _merc("Sol Edge", 0.0)
	var st := _path_state(m, _merc("Foe Stays", 0.0), TestFixtures.exterior_field(), Vector2i(0, 5),
		Vector2i(20, 20))
	_flee_on(m)
	m.flee_escape_paces = 12
	m.current_ap = 2
	var edge := FleeGoal.on_edge(m, st)
	var lines: Array[String] = []
	FleeMover.bank(m, st, lines)
	var track := "FLEE TRACK: %s +3 paces (15/15)" % m.merc_name
	TestFixtures.check(res, "one Move banks 3 paces and the merc flees",
		edge and m.current_ap == 0 and TestFixtures.has_line(lines, track) and m.flee_escape_paces == 15
		and TestFixtures.has_line(lines, "FLED:") and st.escaped.has(m),
		"ap %d paces %d lines %s" % [m.current_ap, m.flee_escape_paces, str(lines)])
	TestFixtures.check(res, "a fled merc is out of the fight",
		not BattleState._is_alive(m) and st.get_winner() == 1, "winner %d" % st.get_winner())
	var cr := ContractRun.new()
	var foes: Array[MercenaryData] = [m]
	var beaten := BattleEventResolver.defeated_foes(foes, st, cr)
	TestFixtures.check(res, "an escaped foe counts as defeated",
		beaten == 1 and TestFixtures.has_line(cr.log_lines, "ESCAPED:"), "defeated %d log %s" % [beaten, str(cr.log_lines)])


static func _case_pick_target(res: Dictionary) -> void:
	_fresh()
	var att := _merc("Tam Hunter", 0.0)
	var runner := _merc("Foe Runner", 0.0)
	var stayer := _merc("Foe Stayer", 0.0)
	var a: Array[MercenaryData] = [att]
	var b: Array[MercenaryData] = [runner, stayer]
	var st := TestFixtures.battle_state(a, b)
	TestFixtures.place(st, att, Vector2i(5, 5))
	TestFixtures.place(st, runner, Vector2i(5, 8))
	TestFixtures.place(st, stayer, Vector2i(8, 5))
	att.equipped_weapon = null
	att.weapon_drawn = false
	st.priority_targets.append(runner)
	st.priority_targets.append(stayer)
	_flee_on(runner)
	runner.flee_escape_paces = 15
	var pool: Array = [runner, stayer]
	var hits := 0
	for _i: int in range(400):
		if TargetSelector.pick_target(att, pool, st) == runner:
			hits += 1
	TestFixtures.check(res, "pick_target favours the fleeing priority target", hits > 240, "%d of 400" % hits)


static func _case_escaping_bonus(res: Dictionary) -> void:
	_fresh()
	var att := _merc("Uma Hunter", 0.0)
	var leader := _merc("Foe Leader", 0.0)
	leader.auras.append({"state": ConstStates.EMBOLDENED, "paces": 5,
		"gate": "sight_or_hearing", "source": "Leadership"})
	var grunt := _merc("Foe Grunt", 0.0)
	var prio := _merc("Foe Prize", 0.0)
	var a: Array[MercenaryData] = [att]
	var b: Array[MercenaryData] = [leader, grunt, prio]
	var st := TestFixtures.battle_state(a, b)
	_flee_on(leader)
	_flee_on(grunt)
	_flee_on(prio)
	prio.flee_escape_paces = 5
	st.priority_targets.append(prio)
	var lb := FleeSystem.escaping_bonus(leader, st)
	var gb := FleeSystem.escaping_bonus(grunt, st)
	TestFixtures.check(res, "a fleeing leader draws pursuit and a fleeing grunt does not", lb > 0.0 and gb == 0.0,
		"leader %.2f grunt %.2f" % [lb, gb])
	var valid: Array = [grunt, prio]
	var from_grunt := FleeSystem.has_better_quarry(grunt, valid, st)
	var from_prio := FleeSystem.has_better_quarry(prio, valid, st)
	TestFixtures.check(res, "has_better_quarry points at the fleeing priority target", from_grunt and not from_prio,
		"grunt %s prize %s" % [from_grunt, from_prio])


#Settles a battle in which runner fled the field, over a roster of the party.
static func _fled_settle(party: Array[MercenaryData], foe: MercenaryData, runner: MercenaryData,
		abandons: bool) -> Dictionary:
	var b: Array[MercenaryData] = [foe]
	var st := TestFixtures.battle_state(party, b)
	var lines: Array[String] = []
	_flee_on(runner)
	runner.flee_abandons = abandons
	st.remove_from_field(runner, "fled", lines)
	var cr := ContractRun.new()
	cr.team.assign(party)
	var roster: Array[MercenaryData] = []
	roster.assign(party)
	return {"run": cr, "out": FleeSettlement.settle(cr, st, roster)}


static func _case_settle_return(res: Dictionary) -> void:
	_fresh()
	var p := TestFixtures.sheet_merc("Vera Back")
	var a: Array[MercenaryData] = [p]
	var settled := _fled_settle(a, _merc("Foe Nine", 0.0), p, false)
	var cr: ContractRun = settled["run"]
	var out: Array[String] = settled["out"]
	var marks: Array = cr.merc_marks.get(p, [])
	TestFixtures.check(res, "a returner is marked and stays on the team",
		marks.has("Fled") and TestFixtures.has_line(out, "RETURNED:") and cr.team.has(p) and cr.departed.is_empty(),
		"marks %s out %s" % [str(marks), str(out)])
	TestFixtures.check(res, "settle clears the returner",
		not p.off_field and not p.flee_intent and not p.flee_abandons and p.flee_escape_paces == 0
		and not ConstStates.has_state(p, ConstStates.TERRIFIED), "off_field %s intent %s" % [p.off_field, p.flee_intent])


static func _case_settle_abandon(res: Dictionary) -> void:
	_fresh()
	MercPool.clear()
	var q := TestFixtures.sheet_merc("Wes Gone")
	var stay := TestFixtures.sheet_merc("Xia Stays")
	var a: Array[MercenaryData] = [q, stay]
	var settled := _fled_settle(a, _merc("Foe Ten", 0.0), q, true)
	var cr: ContractRun = settled["run"]
	var out: Array[String] = settled["out"]
	var lp_line := TestFixtures.has_line(out, "LIFEPATH FORCED") and LifepathProgression.has_event(q, "Coward's Way Out")
	TestFixtures.check(res, "an abandoner takes the lifepath and joins the pool",
		lp_line and MercPool.count() == 1, "pool %d out %s" % [MercPool.count(), str(out)])
	TestFixtures.check(res, "an abandoner leaves the team",
		cr.departed.has(q) and not cr.team.has(q) and cr.team.has(stay) and TestFixtures.has_line(out, "DEPARTED:"),
		"departed %d team %d" % [cr.departed.size(), cr.team.size()])
	MercPool.clear()


static func _case_settle_held(res: Dictionary) -> void:
	_fresh()
	MercPool.clear()
	var q := TestFixtures.sheet_merc("Cid Twice")
	var a: Array[MercenaryData] = [q]
	LifepathProgression.force(q, "Coward's Way Out")
	var settled := _fled_settle(a, _merc("Foe Fourteen", 0.0), q, true)
	var cr: ContractRun = settled["run"]
	var out: Array[String] = settled["out"]
	TestFixtures.check(res, "an abandoner already holding the event logs neither lifepath line",
		not TestFixtures.has_line(out, "LIFEPATH FORCED") and not TestFixtures.has_line(out, "LIFEPATH REFUSED")
		and LifepathProgression.has_event(q, "Coward's Way Out"), "out %s" % str(out))
	TestFixtures.check(res, "a held event still pools and departs the abandoner",
		MercPool.count() == 1 and cr.departed.has(q) and not cr.team.has(q) and TestFixtures.has_line(out, "DEPARTED:"),
		"pool %d departed %d out %s" % [MercPool.count(), cr.departed.size(), str(out)])
	MercPool.clear()


static func _case_settle_npc(res: Dictionary) -> void:
	_fresh()
	MercPool.clear()
	var p := TestFixtures.sheet_merc("Yan Party")
	var npc := _merc("Foe Coward", 0.0)
	var a: Array[MercenaryData] = [p]
	var settled := _fled_settle(a, npc, npc, true)
	var cr: ContractRun = settled["run"]
	var out: Array[String] = settled["out"]
	TestFixtures.check(res, "an NPC escapee is neither pooled nor marked",
		MercPool.count() == 0 and cr.merc_marks.is_empty() and out.is_empty(),
		"pool %d marks %d out %s" % [MercPool.count(), cr.merc_marks.size(), str(out)])


static func _case_pool(res: Dictionary) -> void:
	MercPool.clear()
	var pm := _merc("Zoe Pool", 0.0)
	MercPool.add(pm)
	MercPool.add(pm)
	var dup := MercPool.count()
	TestFixtures.check(res, "a duplicate add keeps one entry", dup == 1, "count %d" % dup)
	var got: MercenaryData = MercPool.take(pm.merc_uid)
	TestFixtures.check(res, "take by uid returns the merc and empties the pool",
		got == pm and MercPool.count() == 0, "count %d" % MercPool.count())
	MercPool.clear()


static func _case_settle_clear(res: Dictionary) -> void:
	_fresh()
	var p := TestFixtures.sheet_merc("Abi Clear")
	var b1 := _merc("Foe Fled", 0.0)
	var b2 := _merc("Foe Scared", 0.0)
	var a: Array[MercenaryData] = [p]
	var b: Array[MercenaryData] = [b1, b2]
	var st := TestFixtures.battle_state(a, b)
	var lines: Array[String] = []
	_flee_on(p)
	st.remove_from_field(p, "fled", lines)
	_flee_on(b1)
	b1.flee_abandons = true
	b1.flee_escape_paces = 5
	b1.advantage_immune = true
	StateCascade.apply_state(b2, ConstStates.TERRIFIED, p, "", "inflict:Test")
	var cr := ContractRun.new()
	cr.team.assign(a)
	var roster: Array[MercenaryData] = [p]
	FleeSettlement.settle(cr, st, roster)
	var everyone: Array[MercenaryData] = [p, b1, b2]
	var flags_ok := true
	for m: MercenaryData in everyone:
		if m.off_field or m.flee_intent or m.flee_abandons or m.flee_escape_paces != 0 or m.advantage_immune:
			flags_ok = false
	TestFixtures.check(res, "settle clears the flee flags on both teams", flags_ok,
		"off_field %s b1 paces %d b1 immune %s" % [p.off_field, b1.flee_escape_paces, b1.advantage_immune])
	var b1_t := ConstStates.has_state(b1, ConstStates.TERRIFIED)
	var b2_t := ConstStates.has_state(b2, ConstStates.TERRIFIED)
	TestFixtures.check(res, "settle removes only the flee Terrified", not b1_t and b2_t,
		"b1 %s b2 %s" % [b1_t, b2_t])


static func _case_disabled(res: Dictionary) -> void:
	var solo := _solo("Bo Off", 60.0, "Foe Eleven")
	var m: MercenaryData = solo["merc"]
	var st: BattleState = solo["state"]
	var lines: Array[String] = solo["lines"]
	FleeSystem.enabled = false
	FleeSystem.forced_rolls.assign([10, 20])
	var r1 := FleeSystem.start_of_turn(m, st, lines)
	var c1 := FleeSystem.checks_rolled
	var left1 := FleeSystem.forced_rolls.size()
	FleeSystem.enabled = true
	TestFixtures.check(res, "FleeSystem.enabled false gives no roll", not r1 and c1 == 0 and left1 == 2,
		"checks %d rolls left %d" % [c1, left1])
	st.flee_enabled = false
	var r2 := FleeSystem.start_of_turn(m, st, lines)
	TestFixtures.check(res, "state.flee_enabled false gives no roll",
		not r2 and FleeSystem.checks_rolled == 0 and FleeSystem.forced_rolls.size() == 2,
		"checks %d rolls left %d" % [FleeSystem.checks_rolled, FleeSystem.forced_rolls.size()])
	FleeSystem.forced_rolls.clear()

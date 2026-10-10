class_name CompetitionTests
#Run: godot --headless --path . -- --competition-tests
#Competition primary: opposed checks, rival team, round plans, removal without death, rests, manager flow and Victor.

const WAR_KNOWLEDGES: Array[String] = ["Colosseum", "Chivalry", "Tactics"]
const OUT_MARK := "is out of the competition!"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	var saved_banking: bool = CriticalSuccessSystem.banking
	var saved_trigger: String = ContractLibrary.config().force_trigger_event
	_case_opposed(res)
	_case_expected(res)
	_case_merged(res)
	_case_event_kind(res)
	await _case_relevance(res)
	_case_rivals(res)
	_case_skew(res)
	await _case_check_def(res)
	_case_plan(res)
	_case_removal_hit(res)
	_case_removal_dot(res)
	_case_dying_unchanged(res)
	await _case_war_round(res)
	_case_score(res)
	await _case_forfeit(res)
	await _case_forfeit_before_rest(res)
	await _case_depletion_order(res)
	_case_deplete(res)
	_case_loss(res)
	await _case_rest_no_trigger(res)
	var manager_run: ContractRun = await _case_manager(res)
	_case_victor(res)
	if manager_run == null:
		TestFixtures.check(res, "log_round_counts", false, "the manager run did not complete")
	else:
		_case_log_counts(res, manager_run)
	_fresh()
	FleeSystem.reset()
	CriticalSuccessSystem.banking = saved_banking
	ContractLibrary.config().force_trigger_event = saved_trigger
	return TestFixtures.summarize(res, "COMPETITION")


static func _fresh() -> void:
	CompetitionResolver.reset()
	CheckSystem.forced_rolls.clear()
	CheckSystem.ambient_knowledges.clear()


#Hand-set stats: formula "15" with base_success_chance 0 gives threshold 15, and reroll 0 fails every reroll test.
static func _fx(merc_name: String, cog: int = 2, luck: float = 0.0) -> MercenaryData:
	var extras: Dictionary = {"luck": luck, "cognition": cog, "maximum_magic_points": 5}
	var m: MercenaryData = TestFixtures.fixed_merc(merc_name, extras)
	m.current_mp = 5
	return m


static func _def() -> Dictionary:
	return {"stat_keys": ["cognition"], "circumstances": [], "tools": [], "knowledges": [], "formula": "15"}


static func _removal_state(att: MercenaryData, target: MercenaryData, no_death: bool) -> BattleState:
	var side_a: Array[MercenaryData] = [att]
	var side_b: Array[MercenaryData] = [target]
	var st: BattleState = BattleState.create(side_a, side_b, null)
	st.no_death_removal = no_death
	return st


#The contract's own place when it has a terrain, else the first wilderness location.
static func _location_for(contract: ContractData) -> LocationData:
	return ContractFixtures.contract_location(contract, TestFixtures.wilderness_pool(), false)


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if str(a[i]) != str(b[i]):
			return false
	return true


static func _count_has(lines: Array[String], needle: String) -> int:
	var n: int = 0
	for line: String in lines:
		n += line.count(needle)
	return n


static func _opposed(a: MercenaryData, b: MercenaryData, rolls: Array) -> Dictionary:
	CheckSystem.forced_rolls.assign(rolls)
	return CheckSystem.opposed_check(a, b, _def())


static func _crit(out: Dictionary, side: String) -> bool:
	return bool((out[side] as Dictionary)["critical"])


static func _brief(out: Dictionary) -> String:
	var a: Dictionary = out["a"]
	var b: Dictionary = out["b"]
	return "a %d crit %s, b %d crit %s, margin %d, a_wins %s, tie %s, rolls left %d" % [int(a["successes"]),
		str(a["critical"]), int(b["successes"]), str(b["critical"]), int(out["margin"]), str(out["a_wins"]),
		str(out["tie"]), CheckSystem.forced_rolls.size()]


static func _name_of(merc: Variant) -> String:
	if merc is MercenaryData:
		return (merc as MercenaryData).merc_name
	return "none"


#Threshold 15, luck 0: a failed die draws a second d100 for the reroll test, a passed die draws one.
static func _case_opposed(res: Dictionary) -> void:
	_fresh()
	var saved: bool = CriticalSuccessSystem.banking
	CriticalSuccessSystem.banking = true
	var out: Dictionary = _opposed(_fx("Ada"), _fx("Bel"), [10, 12, 10, 100, 100])
	TestFixtures.check(res, "opposed_win", bool(out["a_wins"]) and not bool(out["tie"]) and int(out["margin"]) == 1
		and CheckSystem.forced_rolls.is_empty(), _brief(out))
	out = _opposed(_fx("Ada"), _fx("Bel"), [100, 100, 100, 100, 10, 11])
	TestFixtures.check(res, "opposed_loss", not bool(out["a_wins"]) and not bool(out["tie"]) and int(out["margin"]) == -2
		and CheckSystem.forced_rolls.is_empty(), _brief(out))
	out = _opposed(_fx("Ada", 1), _fx("Bel", 3), [15, 10, 11, 12])
	TestFixtures.check(res, "opposed_lone_critical", bool(out["a_wins"]) and int(out["margin"]) == -2
		and _crit(out, "a") and not _crit(out, "b") and CheckSystem.forced_rolls.is_empty(), _brief(out))
	out = _opposed(_fx("Ada", 1), _fx("Bel", 2), [15, 15, 15])
	TestFixtures.check(res, "opposed_both_critical", _crit(out, "a") and _crit(out, "b") and not bool(out["a_wins"])
		and not bool(out["tie"]) and int(out["margin"]) == -1 and CheckSystem.forced_rolls.is_empty(), _brief(out))
	out = _opposed(_fx("Ada", 1), _fx("Bel", 1), [10, 12])
	TestFixtures.check(res, "opposed_tie", bool(out["tie"]) and not bool(out["a_wins"]) and int(out["margin"]) == 0
		and CheckSystem.forced_rolls.is_empty(), _brief(out))
	CriticalSuccessSystem.banking = saved
	_fresh()


static func _case_expected(res: Dictionary) -> void:
	_fresh()
	var lo := _fx("Low", 1)
	var hi := _fx("High", 3)
	var e_lo: float = CheckSystem.expected_successes(lo, _def())
	var e_hi: float = CheckSystem.expected_successes(hi, _def())
	TestFixtures.check(res, "expected_successes_rank", e_hi > e_lo, "cognition 3 %.2f, cognition 1 %.2f" % [e_hi, e_lo])
	var pair: Array[MercenaryData] = [lo, hi]
	var best: MercenaryData = CompetitionResolver.best_for(pair, _def())
	TestFixtures.check(res, "best_for_highest", best == hi, "picked %s" % _name_of(best))
	var first := _fx("Even One")
	var second := _fx("Even Two")
	var even: Array[MercenaryData] = [first, second]
	best = CompetitionResolver.best_for(even, _def())
	TestFixtures.check(res, "best_for_tie_keeps_first", best == first, "picked %s" % _name_of(best))


static func _case_merged(res: Dictionary) -> void:
	_fresh()
	var primary := EventData.new()
	primary.knowledges.assign(["Colosseum", " Chivalry", ""])
	var row := EventData.new()
	row.knowledges.assign(["Chivalry", "Tactics", "Colosseum"])
	var merged: Array[String] = CompetitionResolver.merged_knowledges(primary, row)
	TestFixtures.check(res, "merged_knowledges_dedup_order", _same(merged, WAR_KNOWLEDGES), ", ".join(merged))
	var comp: EventData = ContractLibrary.event("Competition")
	var war: EventData = ContractLibrary.event("Competition of War")
	var real: Array[String] = []
	if comp != null and war != null:
		real = CompetitionResolver.merged_knowledges(comp, war)
	TestFixtures.check(res, "merged_knowledges_war_row", _same(real, WAR_KNOWLEDGES), ", ".join(real))


static func _case_event_kind(res: Dictionary) -> void:
	var comp: EventData = ContractLibrary.event("Competition")
	var war: EventData = ContractLibrary.event("Competition of War")
	var comp_formula: String = "missing"
	if comp != null:
		comp_formula = comp.success_formula
	var war_formula: String = "missing"
	if war != null:
		war_formula = war.success_formula
	TestFixtures.check(res, "event_competition_kind", comp != null and comp.is_competition() and not comp.is_battle(),
		"formula %s" % comp_formula)
	TestFixtures.check(res, "event_war_is_battle", war != null and war.is_battle(), "formula %s" % war_formula)


#Champion: 3 Cognition + 1 knowledge die at 26.5 draws 8; the rival's one die draws 2.
static func _case_relevance(res: Dictionary) -> void:
	_fresh()
	var other := _fx("Other", 1)
	other.stats["base_success_chance"] = 10.0
	var champ := _fx("Champ", 3)
	champ.stats["base_success_chance"] = 10.0
	champ.knowledges.append(ContractFixtures.utility("Education"))
	var rival := _fx("Rival", 1)
	var team: Array[MercenaryData] = [other, champ]
	var cr := ContractFixtures.bare_run(team, 1.0)
	CompetitionResolver.forced_kinds.assign(["Wit"])
	CompetitionResolver.forced_rivals = [rival]
	var rolls: Array[int] = []
	for _i: int in range(10):
		rolls.append(100)
	CheckSystem.forced_rolls.assign(rolls)
	var out: Dictionary = await CompetitionResolver.resolve(ContractLibrary.event("Competition"), cr)
	var rounds: Array[Dictionary] = CompetitionResolver.last_rounds
	var delta: float = 0.0
	var picked: Variant = null
	if rounds.size() == 1:
		delta = float(rounds[0].get("delta", 0.0))
		picked = rounds[0].get("champion", null)
	TestFixtures.check(res, "relevance_delta_positive", delta > 0.0 and picked == champ,
		"rounds %d, delta %.2f, champion %s, rounds_total %d" % [rounds.size(), delta, _name_of(picked),
		int(out.get("rounds_total", 0))])
	var champ_bsc: float = float(champ.stats.get("base_success_chance", 0.0))
	var other_bsc: float = float(other.stats.get("base_success_chance", 0.0))
	TestFixtures.check(res, "relevance_champion_restored", is_equal_approx(champ_bsc, 10.0), "champion %.3f" % champ_bsc)
	TestFixtures.check(res, "relevance_other_unmoved", is_equal_approx(other_bsc, 10.0), "other %.3f" % other_bsc)
	TestFixtures.check(res, "relevance_roll_budget", CheckSystem.forced_rolls.is_empty(),
		"rolls left %d" % CheckSystem.forced_rolls.size())
	_fresh()


static func _case_rivals(res: Dictionary) -> void:
	_fresh()
	var party: Array[MercenaryData] = []
	var total: float = 0.0
	for level: float in [5.0, 6.0, 7.0, 6.0]:
		var m := _fx("Party %d" % party.size())
		m.stats["level"] = level
		party.append(m)
		total += level
	var low: Array[MercenaryData] = CompetitionResolver.build_rivals(ContractFixtures.bare_run(party, 1.0), party)
	var high: Array[MercenaryData] = CompetitionResolver.build_rivals(ContractFixtures.bare_run(party, 5.0), party)
	TestFixtures.check(res, "rivals_count_d1", low.size() == 2, "party 4 at D1: %d rivals" % low.size())
	TestFixtures.check(res, "rivals_count_d5", high.size() == 8, "party 4 at D5: %d rivals" % high.size())
	var avg: float = total / float(party.size())
	var band_lo: int = maxi(1, int(floorf(avg * 0.5)))
	var band_hi: int = int(floorf(avg * 2.0))
	var everyone: Array[MercenaryData] = []
	everyone.append_array(low)
	everyone.append_array(high)
	var outside: Array[String] = []
	for rival: MercenaryData in everyone:
		var level: int = int(rival.stats.get("level", 0))
		if level < band_lo or level > band_hi:
			outside.append("%s L%d" % [rival.merc_name, level])
	var outside_text: String = "none"
	if not outside.is_empty():
		outside_text = ", ".join(outside)
	TestFixtures.check(res, "rival_levels_in_band", not everyone.is_empty() and outside.is_empty(),
		"avg %.1f band %d-%d, %d rivals, outside: %s" % [avg, band_lo, band_hi, everyone.size(), outside_text])
	_fresh()


#Two generations from one seed; NameGenerator keeps its recency tables, so they are put back between the two.
static func _case_skew(res: Dictionary) -> void:
	_fresh()
	var s1: int = CompetitionResolver.rival_skew(1.0)
	var s3: int = CompetitionResolver.rival_skew(3.0)
	var s5: int = CompetitionResolver.rival_skew(5.0)
	TestFixtures.check(res, "rival_skew_by_difficulty", s1 == 1 and s3 == 2 and s5 == 4,
		"D1 %d, D3 %d, D5 %d" % [s1, s3, s5])
	var solo: Array[MercenaryData] = [_fx("Solo")]
	var skew_run := ContractFixtures.bare_run(solo, 3.0)
	var config: ContractConfig = ContractLibrary.config()
	var req := OpponentRequest.new()
	req.source = "Mercs"
	req.count = -1
	req.count_formula = config.rival_count_formula
	req.party.assign(solo)
	req.difficulty = 3.0
	req.tradition_odds = config.rival_tradition_odds
	req.independent_traditions = true
	req.tag = "Competition"
	var saved_surnames: Dictionary = NameGenerator._recent_surnames.duplicate(true)
	var saved_first: Dictionary = NameGenerator._recent_first_names.duplicate(true)
	seed(777)
	var plain: Array[MercenaryData] = OpponentGenerator.generate(req)
	NameGenerator._recent_surnames = saved_surnames
	NameGenerator._recent_first_names = saved_first
	seed(777)
	var skewed: Array[MercenaryData] = CompetitionResolver.build_rivals(skew_run, solo)
	var names: String = "none"
	if plain.size() == 1 and skewed.size() == 1:
		names = "%s vs %s" % [plain[0].merc_name, skewed[0].merc_name]
	var baked: Array[String] = _skew_gaps(plain, skewed, 0.0)
	TestFixtures.check(res, "rival_skew_not_baked", baked.is_empty(), "%s, %s" % [names, ", ".join(baked)])
	var hp_was: int = skewed[0].current_hp if skewed.size() == 1 else -1
	var saved: Array = CompetitionResolver._skew_rivals(skew_run, skewed)
	var on: Array[String] = _skew_gaps(plain, skewed, float(s3))
	TestFixtures.check(res, "rival_skew_on_check", on.is_empty(), "want +%d, %s" % [s3, ", ".join(on)])
	CompetitionResolver._unskew_rivals(skewed, saved)
	var back: Array[String] = _skew_gaps(plain, skewed, 0.0)
	var hp_now: int = skewed[0].current_hp if skewed.size() == 1 else -2
	TestFixtures.check(res, "rival_skew_restored", back.is_empty() and hp_now == hp_was,
		"%s, hp %d was %d" % [", ".join(back), hp_now, hp_was])
	_fresh()


#Stat gaps between two single-rival teams that differ from want; empty when every core stat matches.
static func _skew_gaps(plain: Array[MercenaryData], skewed: Array[MercenaryData], want: float) -> Array[String]:
	var bad: Array[String] = []
	if plain.size() != 1 or skewed.size() != 1:
		bad.append("sizes %d/%d" % [plain.size(), skewed.size()])
		return bad
	for stat: String in StatCalculator.CORE_STATS:
		var gap: float = float(skewed[0].stats.get(stat, 0)) - float(plain[0].stats.get(stat, 0))
		if not is_equal_approx(gap, want):
			bad.append("%s %+.2f" % [stat, gap])
	return bad


#One Strength round at D1 and at D5, same rival and dice: 10 passes; each 100 fails and draws a reroll test.
static func _case_check_def(res: Dictionary) -> void:
	var seen: Array[Dictionary] = []
	for difficulty: float in [1.0, 5.0]:
		_fresh()
		var team: Array[MercenaryData] = [_fx("Lifter")]
		CompetitionResolver.forced_rivals = [_fx("Hauler")]
		CompetitionResolver.forced_kinds.assign(["Strength"])
		CheckSystem.forced_rolls.assign([10, 100, 100, 100, 100, 100, 100])
		await CompetitionResolver.resolve(ContractLibrary.event("Competition"), ContractFixtures.bare_run(team, difficulty))
		var rounds: Array[Dictionary] = CompetitionResolver.last_rounds
		if rounds.size() != 1 or not rounds[0].has("a"):
			seen.append({})
			continue
		var a: Dictionary = rounds[0]["a"]
		var b: Dictionary = rounds[0]["b"]
		seen.append({"a_t": float(a["threshold"]), "b_t": float(b["threshold"]), "a_roll": str(a["roll1"]),
			"b_roll": str(b["roll1"]), "result": String(rounds[0]["result"]), "left": CheckSystem.forced_rolls.size()})
	var d1: Dictionary = seen[0]
	var d5: Dictionary = seen[1]
	TestFixtures.check(res, "check_same_d1_d5", not d1.is_empty() and str(d1) == str(d5)
		and is_equal_approx(float(d1.get("b_t", 0.0)), 15.0) and String(d1.get("result", "")) == "won"
		and int(d1.get("left", -1)) == 0, "D1 %s | D5 %s" % [str(d1), str(d5)])
	_fresh()


static func _case_plan(res: Dictionary) -> void:
	_fresh()
	CompetitionResolver.forced_shape = CompetitionResolver.SHAPE_REPEAT
	CompetitionResolver.forced_round_count = 4
	var repeat: Array[String] = CompetitionResolver.plan_rounds()
	var repeat_ok: bool = repeat.size() == 4 and CompetitionResolver.last_shape == CompetitionResolver.SHAPE_REPEAT
	for kind: String in repeat:
		if kind != repeat[0] or not CompetitionResolver.CHECK_KINDS.has(kind):
			repeat_ok = false
	TestFixtures.check(res, "plan_repeat_four", repeat_ok, ", ".join(repeat))
	CompetitionResolver.forced_shape = CompetitionResolver.SHAPE_MIXED
	CompetitionResolver.forced_round_count = 5
	var mixed: Array[String] = CompetitionResolver.plan_rounds()
	var got: Array[String] = []
	got.assign(mixed)
	got.sort()
	var want: Array[String] = []
	want.assign(CompetitionResolver.KINDS)
	want.sort()
	TestFixtures.check(res, "plan_mixed_all_kinds", _same(got, want), ", ".join(mixed))
	CompetitionResolver.forced_shape = CompetitionResolver.SHAPE_TOURNAMENT
	CompetitionResolver.forced_round_count = -1
	var war: Array[String] = CompetitionResolver.plan_rounds()
	var war_ok: bool = war.size() >= 3 and war.size() <= 5
	for kind: String in war:
		if kind != "War":
			war_ok = false
	TestFixtures.check(res, "plan_tournament_war_only", war_ok, ", ".join(war))
	CompetitionResolver.forced_shape = CompetitionResolver.SHAPE_REPEAT
	var bad: int = 0
	for _i: int in range(50):
		var plan: Array[String] = CompetitionResolver.plan_rounds()
		if plan.has("War") or plan.size() < 3 or plan.size() > 5:
			bad += 1
	TestFixtures.check(res, "plan_repeat_never_war", bad == 0, "%d of 50 plans held War or a bad size" % bad)
	_fresh()


static func _case_removal_hit(res: Dictionary) -> void:
	_fresh()
	var att := TestFixtures.sheet_merc("Striker")
	var target := TestFixtures.sheet_merc("Target")
	var st: BattleState = _removal_state(att, target, true)
	target.current_hp = 3
	target.excess_hp = 0
	var lines: Array[String] = CombatApplicator.apply_damage(att, target, 5, "Sonic", st)
	TestFixtures.check(res, "removal_hit_leaves_field", target.current_hp == 1 and target.off_field
		and st.removed_from_field.has(target), "hp %d, off_field %s, removed %d" % [target.current_hp,
		str(target.off_field), st.removed_from_field.size()])
	var dying: bool = ConstStates.has_state(target, ConstStates.DYING)
	TestFixtures.check(res, "removal_hit_not_dying", not target.is_dead and not dying and not BattleState._is_alive(target),
		"dead %s, dying %s" % [str(target.is_dead), str(dying)])
	TestFixtures.check(res, "removal_hit_line", _count_has(lines, OUT_MARK) >= 1, " | ".join(lines))


static func _case_removal_dot(res: Dictionary) -> void:
	_fresh()
	var att := TestFixtures.sheet_merc("Burner")
	var target := TestFixtures.sheet_merc("Smoulder")
	var st: BattleState = _removal_state(att, target, true)
	target.current_hp = 1
	target.excess_hp = 0
	StateCascade.apply_state(target, ConstStates.BURNING)
	var lines: Array[String] = BattleStateUpdater.apply_dot_effects(target, st)
	TestFixtures.check(res, "removal_dot", target.current_hp == 1 and target.off_field and st.removed_from_field.has(target)
		and not target.is_dead and _count_has(lines, OUT_MARK) >= 1, "hp %d, off_field %s, lines: %s" % [
		target.current_hp, str(target.off_field), " | ".join(lines)])


static func _case_dying_unchanged(res: Dictionary) -> void:
	_fresh()
	var att := TestFixtures.sheet_merc("Striker")
	var target := TestFixtures.sheet_merc("Faller")
	var st: BattleState = _removal_state(att, target, false)
	target.current_hp = 3
	target.excess_hp = 0
	var lines: Array[String] = CombatApplicator.apply_damage(att, target, 5, "Sonic", st)
	TestFixtures.check(res, "dying_without_removal", ConstStates.has_state(target, ConstStates.DYING)
		and _count_has(lines, "is dying!") >= 1 and not target.off_field and not target.is_dead
		and st.removed_from_field.is_empty(), "hp %d, lines: %s" % [target.current_hp, " | ".join(lines)])


static func _case_war_round(res: Dictionary) -> void:
	_fresh()
	seed(4242)
	ContractFixtures.reset_party_state()
	var mercs: Array[MercenaryData] = ContractFixtures.roster_team(2)
	var contract: ContractData = ContractGenerator.generate("Entertain")
	var event: EventData = ContractLibrary.event("Competition")
	if contract == null or event == null:
		TestFixtures.check(res, "war_setup", false, "contract %s, event %s" % [str(contract != null), str(event != null)])
		return
	contract.difficulty = 1.0
	contract.unsavory = false
	var lines: Array[String] = []
	var cr: ContractRun = ContractFixtures.contract_run(contract, mercs, _location_for(contract),
		func(line: String) -> void: lines.append(line))
	CompetitionResolver.forced_kinds.assign(["War"])
	var out: Dictionary = await EventRunner.run(event, cr)
	var rounds: Array[Dictionary] = CompetitionResolver.last_rounds
	var result: String = "none"
	if rounds.size() == 1:
		result = String(rounds[0].get("result", ""))
	TestFixtures.check(res, "war_one_round", rounds.size() == 1 and ["won", "lost", "draw"].has(result),
		"rounds %d, result %s, %d lines" % [rounds.size(), result, lines.size()])
	var everyone: Array[MercenaryData] = []
	everyone.assign(mercs)
	everyone.append_array(CompetitionResolver.last_rivals)
	var dead: Array[String] = []
	var low: Array[String] = []
	var off: Array[String] = []
	for merc: MercenaryData in everyone:
		if merc.is_dead:
			dead.append(merc.merc_name)
		if merc.current_hp < 1:
			low.append("%s %d" % [merc.merc_name, merc.current_hp])
		if merc.off_field:
			off.append(merc.merc_name)
	TestFixtures.check(res, "war_no_death", not CompetitionResolver.last_rivals.is_empty() and dead.is_empty(),
		"rivals %d, dead: %s" % [CompetitionResolver.last_rivals.size(), ", ".join(dead)])
	TestFixtures.check(res, "war_hp_at_least_one", low.is_empty(), "below 1 HP: %s" % ", ".join(low))
	TestFixtures.check(res, "war_back_on_field", off.is_empty(), "off_field: %s" % ", ".join(off))
	TestFixtures.check(res, "war_ambient_knowledges", _same(CompetitionResolver.last_ambient, WAR_KNOWLEDGES)
		and CheckSystem.ambient_knowledges.is_empty(), "last_ambient %s, ambient now %d" % [
		", ".join(CompetitionResolver.last_ambient), CheckSystem.ambient_knowledges.size()])
	TestFixtures.check(res, "war_rounds_total", int(out.get("rounds_total", 0)) == 1,
		"rounds_total %d" % int(out.get("rounds_total", 0)))
	FleeSystem.reset()
	_fresh()


static func _case_score(res: Dictionary) -> void:
	_fresh()
	var won: int = CompetitionResolver.score("won")
	var tied: int = CompetitionResolver.score("tied")
	var draw: int = CompetitionResolver.score("draw")
	var lost: int = CompetitionResolver.score("lost")
	TestFixtures.check(res, "score_values", won == 1 and tied == 0 and draw == 0 and lost == 0,
		"won %d, tied %d, draw %d, lost %d" % [won, tied, draw, lost])
	var both_empty: String = CompetitionResolver.forfeit_result(0, 0)
	var rivals_empty: String = CompetitionResolver.forfeit_result(2, 0)
	var party_empty: String = CompetitionResolver.forfeit_result(0, 3)
	var neither: String = CompetitionResolver.forfeit_result(2, 3)
	TestFixtures.check(res, "forfeit_result", both_empty == "lost" and rivals_empty == "won" and party_empty == "lost"
		and neither == "", "0v0 %s, 2v0 %s, 0v3 %s, 2v3 [%s]" % [both_empty, rivals_empty, party_empty, neither])


static func _case_forfeit(res: Dictionary) -> void:
	_fresh()
	var team: Array[MercenaryData] = [_fx("Lone")]
	var cr := ContractFixtures.bare_run(team, 1.0)
	CompetitionResolver.forced_rivals = []
	CompetitionResolver.forced_kinds.assign(["Strength", "Wit", "Speed"])
	var out: Dictionary = await CompetitionResolver.resolve(ContractLibrary.event("Competition"), cr)
	TestFixtures.check(res, "forfeit_all_won", int(out.get("rounds_won", 0)) == 3 and bool(out.get("success", false)),
		"won %d of %d, success %s" % [int(out.get("rounds_won", 0)), int(out.get("rounds_total", 0)),
		str(out.get("success", false))])
	var forfeits: int = _count_has(cr.log_lines, "forfeit ->")
	var rival_rests: int = _count_has(cr.log_lines, "RIVAL REST:")
	var rests: int = _count_has(cr.log_lines, "REST TIME:")
	TestFixtures.check(res, "forfeit_lines_no_rest", forfeits == 3 and rival_rests == 0 and rests == 0,
		"forfeit %d, rival rest %d, rest time %d" % [forfeits, rival_rests, rests])
	_fresh()


#The line callable is the only hook inside resolve(); the party walks out once round 1 has been scored.
static func _drop_after_round_one(cr: ContractRun, gone: Array[MercenaryData], line: String) -> void:
	if line.begins_with("COMPETITION ROUND 1:"):
		cr.remove_departed(gone)


#A party emptied between rounds forfeits round 2 before the rest and the rival depletion.
static func _case_forfeit_before_rest(res: Dictionary) -> void:
	_fresh()
	var quitter := _fx("Quitter")
	var team: Array[MercenaryData] = [quitter]
	var gone: Array[MercenaryData] = [quitter]
	var cr := ContractFixtures.bare_run(team, 1.0)
	cr.line_fn = func(line: String) -> void: _drop_after_round_one(cr, gone, line)
	CompetitionResolver.forced_rivals = [_fx("Waiter")]
	CompetitionResolver.forced_kinds.assign(["Strength", "Strength"])
	var rolls: Array[int] = []
	for _i: int in range(8):
		rolls.append(100)
	CheckSystem.forced_rolls.assign(rolls)
	await CompetitionResolver.resolve(ContractLibrary.event("Competition"), cr)
	var rounds: Array[Dictionary] = CompetitionResolver.last_rounds
	var second: Dictionary = rounds[1] if rounds.size() > 1 else {}
	TestFixtures.check(res, "forfeit_empty_party_lost", rounds.size() == 2 and bool(second.get("forfeit", false))
		and String(second.get("result", "")) == "lost", "rounds %d, round 2 %s" % [rounds.size(), str(second)])
	var rival_rests: int = _count_has(cr.log_lines, "RIVAL REST:")
	var rests: int = _count_has(cr.log_lines, "REST TIME:")
	TestFixtures.check(res, "forfeit_before_rest", rival_rests == 0 and rests == 0 and cr.living_team().is_empty(),
		"rival rest %d, rest time %d, living %d" % [rival_rests, rests, cr.living_team().size()])
	_fresh()


#Two Vigor dice then two Cognition dice per side, all 100: 16 draws.
static func _case_depletion_order(res: Dictionary) -> void:
	_fresh()
	var team: Array[MercenaryData] = [_fx("Runner")]
	var cr := ContractFixtures.bare_run(team, 1.0)
	CompetitionResolver.forced_rivals = [_fx("Pacer")]
	CompetitionResolver.forced_kinds.assign(["Strength", "Wit"])
	var rolls: Array[int] = []
	for _i: int in range(16):
		rolls.append(100)
	CheckSystem.forced_rolls.assign(rolls)
	var out: Dictionary = await CompetitionResolver.resolve(ContractLibrary.event("Competition"), cr)
	var rival_rests: int = _count_has(cr.log_lines, "RIVAL REST:")
	var rest_at: int = ContractFixtures.index_of_prefix(cr.log_lines, "RIVAL REST:")
	var round_at: int = ContractFixtures.index_of_prefix(cr.log_lines, "COMPETITION ROUND 1:")
	TestFixtures.check(res, "depletion_after_round_one", rival_rests == 1 and round_at >= 0 and rest_at > round_at,
		"rival rest %d at line %d, round 1 at line %d, rounds_total %d" % [rival_rests, rest_at, round_at,
		int(out.get("rounds_total", 0))])
	TestFixtures.check(res, "depletion_roll_budget", CheckSystem.forced_rolls.is_empty(),
		"rolls left %d" % CheckSystem.forced_rolls.size())
	_fresh()


static func _case_deplete(res: Dictionary) -> void:
	_fresh()
	var r := _fx("Drained")
	r.stats["maximum_endurance_points"] = 10
	r.current_ep = 10
	var rivals: Array[MercenaryData] = [r]
	CompetitionResolver.deplete_rivals(rivals, {"hp": 20.0, "ep": 40.0, "mp": 0.0}, null)
	TestFixtures.check(res, "deplete_within_spread", r.current_hp >= 15 and r.current_hp <= 17 and r.current_hp >= 1
		and r.current_ep >= 5 and r.current_ep <= 7 and r.current_mp == 5,
		"HP %d/20, EP %d/10, MP %d/5" % [r.current_hp, r.current_ep, r.current_mp])


static func _case_loss(res: Dictionary) -> void:
	_fresh()
	var m := _fx("Steady")
	m.current_hp = 12
	var party: Array[MercenaryData] = [m]
	var snap: Dictionary = CompetitionResolver.snapshot(party)
	var same: Dictionary = CompetitionResolver.loss_percents(snap, party)
	TestFixtures.check(res, "loss_unchanged_zero", is_zero_approx(float(same["hp"])) and is_zero_approx(float(same["ep"]))
		and is_zero_approx(float(same["mp"])), str(same))
	m.current_hp = 10
	var hurt: Dictionary = CompetitionResolver.loss_percents(snap, party)
	TestFixtures.check(res, "loss_after_snapshot", is_equal_approx(float(hurt["hp"]), 10.0), str(hurt))


static func _case_rest_no_trigger(res: Dictionary) -> void:
	_fresh()
	var team: Array[MercenaryData] = [_fx("Camper")]
	var cr := ContractFixtures.bare_run(team, 1.0)
	var places: Array[LocationData] = TestFixtures.wilderness_pool()
	if not places.is_empty():
		cr.location = places[0]
	var config: ContractConfig = ContractLibrary.config()
	var saved: String = config.force_trigger_event
	config.force_trigger_event = "Ambush"
	await ContractManager.party_rest(cr, RestSystem.KIND_RESPITE, "t", false)
	config.force_trigger_event = saved
	var rests: int = _count_has(cr.log_lines, "REST TIME:")
	TestFixtures.check(res, "rest_without_trigger", not places.is_empty() and cr.triggered_events.is_empty() and rests == 1,
		"wilderness %d, triggered %d, rest lines %d" % [places.size(), cr.triggered_events.size(), rests])


static func _case_manager(res: Dictionary) -> ContractRun:
	_fresh()
	CampaignClock.reset()
	ContractFixtures.reset_party_state()
	var mercs: Array[MercenaryData] = ContractFixtures.roster_team(3)
	var contract: ContractData = ContractGenerator.generate("Entertain")
	if contract == null:
		TestFixtures.check(res, "manager_setup", false, "Entertain contract generation failed")
		return null
	contract.unsavory = false
	contract.assigned_primary_event = "Competition"
	contract.rolled_mishaps.clear()
	var cr: ContractRun = ContractFixtures.contract_run(contract, mercs, _location_for(contract))
	cr.triggered_events.append("Ambush")
	CompetitionResolver.forced_kinds.assign(["Wit", "Wit", "Wit"])
	var config: ContractConfig = ContractLibrary.config()
	var saved_base: float = config.ambush_base_chance
	var saved_floor: float = config.ambush_chance_floor
	var saved_escalation: float = config.ambush_escalation
	config.ambush_base_chance = 0.0
	config.ambush_chance_floor = 0.0
	config.ambush_escalation = 0.0
	ContractManager.start(cr)
	await ContractManager.execute(cr)
	ContractManager.end(cr)
	config.ambush_base_chance = saved_base
	config.ambush_chance_floor = saved_floor
	config.ambush_escalation = saved_escalation
	var last: Dictionary = {}
	if not cr.outcomes.is_empty():
		last = cr.outcomes[cr.outcomes.size() - 1]
	TestFixtures.check(res, "manager_last_outcome", String(last.get("event", "")) == "Competition"
		and String(last.get("event_type", "")) == "Primary", "outcomes %d, last %s (%s)" % [cr.outcomes.size(),
		String(last.get("event", "none")), String(last.get("event_type", ""))])
	TestFixtures.check(res, "manager_verdict_rule", (cr.verdict == "Succeeded") == bool(last.get("success", false)),
		"verdict %s, won %d of %d" % [cr.verdict, int(last.get("rounds_won", 0)), int(last.get("rounds_total", 0))])
	_fresh()
	return cr


static func _case_victor(res: Dictionary) -> void:
	_fresh()
	var lp: LifepathData = TestFixtures.lifepath("Victor")
	if lp == null or lp.requirements.size() != 3:
		var why: String = "missing"
		if lp != null:
			why = "%d requirements" % lp.requirements.size()
		TestFixtures.check(res, "victor_row", false, "Victor lifepath %s" % why)
		return
	var m := _fx("Laurel")
	m.stats["wile"] = 3
	var team: Array[MercenaryData] = [m]
	var won_run := ContractFixtures.bare_run(team, 1.0)
	won_run.outcomes.append({"event": "Competition", "rounds_won": 3})
	var short_run := ContractFixtures.bare_run(team, 1.0)
	short_run.outcomes.append({"event": "Competition", "rounds_won": 2})
	TestFixtures.check(res, "victor_three_wins", LifepathRequirements.allows(m, lp, won_run), "rounds_won 3, wile 3")
	TestFixtures.check(res, "victor_two_wins_refused", not LifepathRequirements.allows(m, lp, short_run),
		"rounds_won 2, wile 3")
	TestFixtures.check(res, "victor_contract_event", TestFixtures.ok(m, won_run, "Contract Event", "IS", "Competition"),
		"Contract Event IS Competition")


#The file holds the run's log lines as they stood before the CONTRACT LOG line was emitted.
static func _case_log_counts(res: Dictionary, cr: ContractRun) -> void:
	var path: String = ""
	for line: String in cr.log_lines:
		if line.begins_with("CONTRACT LOG: "):
			path = line.trim_prefix("CONTRACT LOG: ")
	if path == "":
		TestFixtures.check(res, "log_round_counts", false, "the contract log was not written")
		return
	var text: String = FileAccess.get_file_as_string(path)
	var in_file: int = text.count("COMPETITION ROUND ")
	var in_lines: int = _count_has(cr.log_lines, "COMPETITION ROUND ")
	TestFixtures.check(res, "log_round_counts", in_file == 3 and in_lines == 3,
		"file %d, lines %d, %s" % [in_file, in_lines, path])

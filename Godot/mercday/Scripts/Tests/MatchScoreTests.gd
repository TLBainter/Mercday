class_name MatchScoreTests

#MatchScore, the leader's shared rows, the flagged mishap ending and the kidnap delta; run from ContractTests.

const RELEVANCE_EVENT := "Assist with the Skirmish"


static func add_cases(res: Dictionary) -> void:
	_case_stars(res)
	_case_merc_net(res)
	_case_leader_rows(res)
	_case_leader_share(res)
	_case_share_lost(res)
	_case_team_solo(res)
	_case_default_leader(res)
	_case_feature_count(res)
	_case_loader_flag(res)
	await _case_mishap(res)
	_case_kidnap_delta(res)


static func _merc(merc_name: String, base_chance: float, knowledges: Array[String] = [],
		tools: Array[String] = []) -> MercenaryData:
	var m: MercenaryData = TestFixtures.fixed_merc(merc_name, {OverallSuccess.STAT_KEY: base_chance})
	for k: String in knowledges:
		m.knowledges.append(ContractFixtures.utility(k))
	for t: String in tools:
		m.tools.append(ContractFixtures.utility(t))
	return m


static func _contract(knowledge: Dictionary, tool: Dictionary = {}, tradition: Dictionary = {}) -> ContractData:
	var c := ContractData.new()
	c.contract_type = "Escort"
	c.knowledge_boosts = knowledge
	c.tool_boosts = tool
	c.tradition_boosts = tradition
	return c


static func _team(mercs: Array) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	out.assign(mercs)
	return out


static func _case_stars(res: Dictionary) -> void:
	var nets: Array[float] = [-5.0, 0.05, 0.1, 3.0, 5.0, 10.0, 15.0, 20.0, 30.0, 40.0, 46.0, 60.0]
	var want: Array[float] = [0.0, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var bad: Array[String] = []
	for i: int in range(nets.size()):
		var got: float = MatchScore.stars(nets[i])
		if not is_equal_approx(got, want[i]):
			bad.append("%.2f -> %.1f want %.1f" % [nets[i], got, want[i]])
	TestFixtures.check(res, "match: stars_table", bad.is_empty(), "; ".join(bad))


#merc_net is the run's net: the applied delta over the base, times 100.
static func _case_merc_net(res: Dictionary) -> void:
	var boost := _contract({"Dueling": 15.0})
	var m := _merc("Ada", 40.0, ["Dueling"])
	var team: Array[MercenaryData] = [m]
	var delta: float = float(OverallSuccess.for_merc(boost, team, m, null)["delta"])
	var net: float = MatchScore.merc_net(boost, team, m)
	TestFixtures.check(res, "match: merc_net_boost", is_equal_approx(net, 15.0)
		and is_equal_approx(net, delta / 40.0 * 100.0), "net %.2f delta %.2f" % [net, delta])
	var pen := _contract({})
	pen.penalties = [{"expr": "team.merc_count >= 1", "percent": 10.0}]
	delta = float(OverallSuccess.for_merc(pen, team, m, null)["delta"])
	net = MatchScore.merc_net(pen, team, m)
	TestFixtures.check(res, "match: merc_net_penalty", is_equal_approx(net, -10.0)
		and is_equal_approx(net, delta / 40.0 * 100.0), "net %.2f delta %.2f" % [net, delta])
	var rel := _contract({})
	rel.assigned_primary_event = RELEVANCE_EVENT
	var event: EventData = ContractLibrary.event(RELEVANCE_EVENT)
	var h := _merc("Hal", 40.0, ["Hunting"])
	var solo: Array[MercenaryData] = [h]
	delta = float(OverallSuccess.for_merc(rel, solo, h, event)["delta"])
	net = MatchScore.merc_net(rel, solo, h)
	var bonus: float = ContractLibrary.config().mishap_relevance_bonus_percent
	TestFixtures.check(res, "match: merc_net_relevance", event != null and is_equal_approx(net, bonus)
		and is_equal_approx(net, delta / 40.0 * 100.0), "net %.2f delta %.2f" % [net, delta])


static func _case_leader_rows(res: Dictionary) -> void:
	var c := _contract({"Dueling": 15.0, "Hunting": 5.0, "Tactics": 10.0}, {"Tracker's": 10.0}, {"Sellsword": 50.0})
	var lead := _merc("Lea", 40.0, ["Dueling", "Hunting", "Tactics"], ["Tracker's Kit"])
	var trad := TraditionData.new()
	trad.tradition_name = "Sellsword"
	lead.tradition = trad
	var rows: Array[Dictionary] = MatchScore.leader_rows(c, lead)
	var names: Array[String] = []
	for row: Dictionary in rows:
		names.append("%s:%s" % [String(row["kind"]), String(row["name"])])
	TestFixtures.check(res, "match: leader_rows_two_strongest", ", ".join(names) == "knowledge:Dueling, knowledge:Tactics",
		", ".join(names))
	var tie := _contract({"Tactics": 10.0}, {"Tracker's": 10.0})
	var tie_rows: Array[Dictionary] = MatchScore.leader_rows(tie, lead)
	TestFixtures.check(res, "match: leader_rows_tie_knowledge_first", tie_rows.size() == 2
		and String(tie_rows[0]["kind"]) == "knowledge" and String(tie_rows[1]["kind"]) == "tool", str(tie_rows))
	var trad_only := _contract({}, {}, {"Sellsword": 50.0})
	TestFixtures.check(res, "match: leader_rows_no_tradition", ContractModifiers.matched_rows(trad_only, lead).size() == 1
		and MatchScore.leader_rows(trad_only, lead).is_empty(), "tradition rows are never shared")


#A base 10 member with no match under a leader holding the 15% and 10% rows reads net 25 and value 12.5.
static func _case_leader_share(res: Dictionary) -> void:
	var c := _contract({"Dueling": 15.0, "Hunting": 5.0}, {"Tracker's": 10.0})
	var lead := _merc("Lea", 40.0, ["Dueling", "Hunting"], ["Tracker's Kit"])
	var mem := _merc("Mo", 10.0)
	var team: Array[MercenaryData] = [lead, mem]
	var info: Dictionary = OverallSuccess.for_merc(c, team, mem, null, lead)
	TestFixtures.check(res, "match: leader_share_net_25", is_equal_approx(float(info["net_percent"]), 25.0)
		and is_equal_approx(float(info["value"]), 12.5), "net %.1f value %.2f"
		% [float(info["net_percent"]), float(info["value"])])
	var own := _merc("Ow", 10.0, ["Dueling"])
	var team2: Array[MercenaryData] = [lead, own]
	var own_net: float = float(OverallSuccess.for_merc(c, team2, own, null, lead)["net_percent"])
	TestFixtures.check(res, "match: leader_share_no_double_count", is_equal_approx(own_net, 25.0), "net %.1f" % own_net)
	var lead_net: float = float(OverallSuccess.for_merc(c, team, lead, null, lead)["net_percent"])
	TestFixtures.check(res, "match: leader_own_rows_once", is_equal_approx(lead_net, 30.0), "net %.1f" % lead_net)
	var shared: int = 0
	for row: Dictionary in MatchScore.merc_rows(c, mem, lead):
		if bool(row["shared"]):
			shared += 1
	TestFixtures.check(res, "match: merc_rows_marks_shared", shared == 2, "shared %d" % shared)


static func _share_after(how: String) -> float:
	var c := _contract({"Dueling": 15.0}, {"Tracker's": 10.0})
	var lead := _merc("Lea", 40.0, ["Dueling"], ["Tracker's Kit"])
	var mem := _merc("Mo", 10.0)
	var run: ContractRun = ContractRun.make(c, _team([lead, mem]), Callable(), lead.merc_uid)
	var gone: Array[MercenaryData] = [lead]
	match how:
		"dead":
			lead.is_dead = true
		"kidnapped":
			var _k: Array[MercenaryData] = run.remove_kidnapped(gone)
		"fled":
			var _f: Array[MercenaryData] = run.remove_departed(gone)
		"defected":
			var _d: Array[String] = run.depart(lead, run.defectors)
		"none":
			run.leader_uid = -1
	var net: float = float(OverallSuccess.for_merc(c, run.living_team(), mem, null, run.leader())["net_percent"])
	var stale: float = float(OverallSuccess.for_merc(c, run.living_team(), mem, null, lead)["net_percent"])
	return net + stale


static func _case_share_lost(res: Dictionary) -> void:
	var c := _contract({"Dueling": 15.0}, {"Tracker's": 10.0})
	var lead := _merc("Lea", 40.0, ["Dueling"], ["Tracker's Kit"])
	var mem := _merc("Mo", 10.0)
	var run: ContractRun = ContractRun.make(c, _team([lead, mem]), Callable(), lead.merc_uid)
	var live: float = float(OverallSuccess.for_merc(c, run.living_team(), mem, null, run.leader())["net_percent"])
	TestFixtures.check(res, "match: share_live_leader", run.leader() == lead and is_equal_approx(live, 25.0),
		"net %.1f" % live)
	for how: String in ["dead", "kidnapped", "fled", "defected"]:
		var total: float = _share_after(how)
		TestFixtures.check(res, "match: share_lost_%s" % how, is_equal_approx(total, 0.0), "net sum %.1f" % total)
	var none: float = _share_after("none")
	TestFixtures.check(res, "match: share_lost_no_leader_uid", is_equal_approx(none, 25.0),
		"run.leader() null; only the stale leader passed in shares, net sum %.1f" % none)


static func _case_team_solo(res: Dictionary) -> void:
	var c := _contract({"Dueling": 15.0})
	c.penalties = [{"expr": "team.merc_count >= 2", "percent": 10.0}]
	var a := _merc("Ada", 40.0, ["Dueling"])
	var b := _merc("Bo", 40.0)
	var team: Array[MercenaryData] = [a, b]
	var mean: float = MatchScore.team_net(c, team)
	TestFixtures.check(res, "match: team_net_mean", is_equal_approx(mean, ((15.0 - 10.0) + (0.0 - 10.0)) / 2.0),
		"mean %.2f" % mean)
	var solo: float = MatchScore.solo_net(c, a)
	TestFixtures.check(res, "match: solo_net_size_one", is_equal_approx(solo, 15.0)
		and is_equal_approx(MatchScore.merc_net(c, team, a), 5.0), "solo %.1f" % solo)


static func _case_default_leader(res: Dictionary) -> void:
	var c := _contract({"Dueling": 15.0})
	var zed := _merc("Zed", 40.0, ["Dueling"])
	var abe := _merc("Abe", 40.0)
	var bea := _merc("Bea", 40.0)
	var top: MercenaryData = MatchScore.default_leader(c, _team([abe, zed, bea]))
	TestFixtures.check(res, "match: default_leader_highest_net", top == zed, top.merc_name if top != null else "null")
	var tie: MercenaryData = MatchScore.default_leader(c, _team([bea, abe]))
	TestFixtures.check(res, "match: default_leader_tie_name", tie == abe, tie.merc_name if tie != null else "null")
	var first := _merc("Twin", 40.0)
	var second := _merc("Twin", 40.0)
	var twin: MercenaryData = MatchScore.default_leader(c, _team([second, first]))
	TestFixtures.check(res, "match: default_leader_tie_uid", twin == first and first.merc_uid < second.merc_uid,
		"uids %d %d" % [first.merc_uid, second.merc_uid])
	TestFixtures.check(res, "match: default_leader_empty", MatchScore.default_leader(c, _team([])) == null, "")


static func _case_feature_count(res: Dictionary) -> void:
	var one := _contract({"Dueling": 15.0})
	var two := _contract({"Dueling": 5.0, "Hunting": 5.0}, {"Tracker's": 10.0})
	var m := _merc("Ada", 40.0, ["dueling"], ["Tracker's Kit"])
	var contracts: Array[ContractData] = [one, two]
	var count: int = MatchScore.feature_count(m, contracts)
	TestFixtures.check(res, "match: feature_count_two_contracts", count == 3, "count %d" % count)


static func _case_loader_flag(res: Dictionary) -> void:
	var on: EventData = ContractResourceBuilder.build_event({"Event Name": "Flag On", "Fail Ends Contract": " x "})
	var yes: EventData = ContractResourceBuilder.build_event({"Event Name": "Flag Yes", "Fail Ends Contract": "TRUE"})
	var blank: EventData = ContractResourceBuilder.build_event({"Event Name": "Flag Blank", "Fail Ends Contract": ""})
	var absent: EventData = ContractResourceBuilder.build_event({"Event Name": "Flag Absent"})
	TestFixtures.check(res, "match: loader_fail_ends_flag", on.fail_ends_contract and yes.fail_ends_contract
		and not blank.fail_ends_contract and not absent.fail_ends_contract, "x/TRUE true, blank/absent false")


static func _mishap(event_name: String, formula: String, flagged: bool) -> EventData:
	var e := EventData.new()
	e.event_name = event_name
	e.event_type = "Mishap"
	e.success_formula = formula
	e.fail_ends_contract = flagged
	return e


static func _case_mishap(res: Dictionary) -> void:
	var flagged := _mishap("Flagged Slip", "0", true)
	var run: ContractRun = ContractFixtures.bare_run(_team([_merc("Ada", 0.0), _merc("Bo", 0.0)]))
	var go_on: bool = await ContractManager.run_one_event(run, flagged, flagged.event_name, false)
	TestFixtures.check(res, "match: mishap_flagged_ends", not go_on and run.failed_event == "Flagged Slip"
		and run.log_lines.has("CONTRACT FAILED: Flagged Slip ended the contract")
		and String(ContractManager.next_event(run, 0).get("name", "")) == "Flagged Slip",
		"go_on %s failed %s" % [go_on, run.failed_event])
	var plain := _mishap("Plain Slip", "0", false)
	var run2: ContractRun = ContractFixtures.bare_run(_team([_merc("Ada", 0.0)]))
	var go_on2: bool = await ContractManager.run_one_event(run2, plain, plain.event_name, false)
	TestFixtures.check(res, "match: mishap_unflagged_continues", go_on2 and run2.failed_event == ""
		and run2.log_lines.has("MISHAP FAILED: Plain Slip"), "go_on %s failed %s" % [go_on2, run2.failed_event])
	var passed := _mishap("Passed Slip", "200", true)
	var run3: ContractRun = ContractFixtures.bare_run(_team([_merc("Ada", 0.0)]))
	var go_on3: bool = await ContractManager.run_one_event(run3, passed, passed.event_name, false)
	TestFixtures.check(res, "match: mishap_flagged_success_continues", go_on3 and run3.failed_event == "",
		"go_on %s" % go_on3)
	var dead := _merc("Ada", 0.0)
	dead.is_dead = true
	var run4: ContractRun = ContractFixtures.bare_run(_team([dead]))
	var go_on4: bool = await ContractManager.run_one_event(run4, flagged, flagged.event_name, false)
	TestFixtures.check(res, "match: mishap_wipe_aborts", not go_on4 and run4.failed_event == "Flagged Slip"
		and run4.log_lines.has("CONTRACT ABORTED: no mercs left after Flagged Slip")
		and not run4.log_lines.has("CONTRACT FAILED: Flagged Slip ended the contract"), "\n".join(run4.log_lines))


#The target's Break Free odds and roll carry its party delta; kidnapper rolls do not; stats come back.
static func _case_kidnap_delta(res: Dictionary) -> void:
	CheckSystem.forced_rolls.clear()
	var c := _contract({"Dueling": 15.0})
	var target := _merc("Ada", 40.0, ["Dueling"])
	var pair: Array[MercenaryData] = [_merc("Grab", 40.0), _merc("Hold", 40.0)]
	var run: ContractRun = ContractFixtures.bare_run(_team([target]))
	run.contract = c
	var event := EventData.new()
	event.event_name = RespiteKidnapResolver.EVENT_NAME
	var key: String = OverallSuccess.STAT_KEY
	var delta: float = RespiteKidnapResolver.party_delta(run, event, target)
	var odds: float = RespiteKidnapResolver.break_free_odds(target, pair, run, event)
	var after_odds: float = float(target.stats[key])
	OverallSuccess.apply_delta(target, delta)
	var want_odds: float = RespiteKidnapResolver.break_free_odds(target, pair)
	OverallSuccess.revert_event_delta({target: delta})
	TestFixtures.check(res, "match: kidnap_odds_with_delta", is_equal_approx(delta, 6.0)
		and is_equal_approx(odds, want_odds) and is_equal_approx(after_odds, 40.0),
		"delta %.2f odds %.3f want %.3f base %.1f" % [delta, odds, want_odds, after_odds])
	var lines: Array[String] = []
	seed(4242)
	var got: bool = RespiteKidnapResolver.break_free_roll(target, pair, lines, run, event)
	var after_roll: float = float(target.stats[key])
	var want_lines: Array[String] = []
	OverallSuccess.apply_delta(target, delta)
	seed(4242)
	var want: bool = RespiteKidnapResolver.break_free_roll(target, pair, want_lines)
	OverallSuccess.revert_event_delta({target: delta})
	TestFixtures.check(res, "match: kidnap_roll_with_delta", got == want and lines == want_lines
		and is_equal_approx(after_roll, 40.0) and is_equal_approx(float(pair[0].stats[key]), 40.0),
		"%s | %s" % [" ".join(lines), " ".join(want_lines)])
	TestFixtures.check(res, "match: kidnap_no_run_no_delta",
		is_equal_approx(RespiteKidnapResolver.party_delta(null, event, target), 0.0), "")

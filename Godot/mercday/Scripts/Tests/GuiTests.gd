class_name GuiTests

#Match scoring, travel planning, the dispatch optimizer and the metrics record.
#Run headless with the gui-tests suite flag; see HarnessEntry.gd for the exact arguments.
#The expected metrics numbers come from metrics_history_generator.js.

const HISTORY_PATH := "res://Scripts/GUI/Autoloads/MetricsHistory.gd"
#Guild opinion totals of metrics_history_generator.js over a 120 day preview.
const PREVIEW_DAYS := 120
const OPINION_SUMS: Array[int] = [307, -284, 118, -507]
const OPINION_LAST: Array[int] = [5, -2, 3, -3]
const PREVIEW_MERCS: Array[int] = [0, 1, 5, 9]
const PREVIEW_SALARIES: Array[int] = [60, 150, 40, 120]
#The axis formats a metric may name; LineChart.axis_text reads the same set.
const METRIC_FORMATS: Array[String] = ["money", "int", "op", "float"]

static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_score(res)
	_case_top_traits(res)
	_case_travel(res)
	_case_plan(res)
	_case_optimize(res)
	_case_optimize_guard(res)
	_case_optimize_ties(res)
	_case_optimize_valid(res)
	_case_optimize_slow(res)
	_case_metric_defs(res)
	_case_series(res)
	_case_event_series(res)
	_case_preview(res)
	_case_theme_states(res)
	return TestFixtures.summarize(res, "GUI")


static func _case_score(res: Dictionary) -> void:
	var contract: ContractData = _boosts({"K1": 15.0, "K2": 5.0}, {"Tracker's": 10.0}, {})
	var merc: MercenaryData = _fixed("Ada", 40.0, ["K1"], ["Tracker's Kit"])
	var solo: float = MatchScore.solo_net(contract, merc)
	TestFixtures.check(res, "the solo net sums the merc's matched rows", _near(solo, 25.0),
		"expected 25.0, got %.4f" % solo)
	var thin: MercenaryData = _fixed("Bo", 40.0, ["K2"], [])
	TestFixtures.check(res, "the solo net skips the rows the merc lacks",
		_near(MatchScore.solo_net(contract, thin), 5.0), "got %.4f" % MatchScore.solo_net(contract, thin))
	TestFixtures.check(res, "a net reads its stars on the anchors",
		_near(MatchScore.stars(solo), 3.0) and _near(MatchScore.stars(5.0), 1.5),
		"got %.2f and %.2f" % [MatchScore.stars(solo), MatchScore.stars(5.0)])
	TestFixtures.check(res, "stars never leave the zero to five band",
		_near(MatchScore.stars(-10.0), 0.0) and _near(MatchScore.stars(200.0), 5.0),
		"got %.2f and %.2f" % [MatchScore.stars(-10.0), MatchScore.stars(200.0)])
	var other: MercenaryData = _fixed("Cy", 10.0, [], [])
	var team: Array[MercenaryData] = [merc, other]
	var alone: float = MatchScore.solo_net(contract, other)
	var shared: float = MatchScore.merc_net(contract, team, other, merc)
	TestFixtures.check(res, "the leader's two strongest rows lift every other member",
		_near(alone, 0.0) and _near(shared, 25.0), "expected 0.0 and 25.0, got %.4f and %.4f" % [alone, shared])
	var bare: ContractData = _boosts({}, {}, {})
	TestFixtures.check(res, "a contract with no boost rows nets zero",
		_near(MatchScore.solo_net(bare, merc), 0.0), "got %.4f" % MatchScore.solo_net(bare, merc))


static func _case_top_traits(res: Dictionary) -> void:
	var contract: ContractData = _boosts({"K1": 15.0, "K2": 5.0, "K3": 10.0}, {"Tracker's": 12.0}, {"Tr1": 50.0})
	var lead: MercenaryData = _fixed("Lea", 40.0, ["K1", "K2", "K3"], ["Tracker's Kit"])
	var trad := TraditionData.new()
	trad.tradition_name = "Tr1"
	lead.tradition = trad
	var rows: Array[Dictionary] = MatchScore.leader_rows(contract, lead)
	TestFixtures.check(res, "the leader shares its two strongest knowledge or tool rows",
		rows.size() == 2 and str(rows[0]["name"]) == "K1" and str(rows[1]["name"]) == "Tracker's",
		"got %s" % str(rows))
	TestFixtures.check(res, "shared rows carry their kind and percent",
		rows.size() == 2 and str(rows[0]["kind"]) == "knowledge" and _near(float(rows[0]["pct"]), 15.0)
		and str(rows[1]["kind"]) == "tool" and _near(float(rows[1]["pct"]), 12.0), "got %s" % str(rows))
	var member: MercenaryData = _fixed("Mo", 10.0, ["K1"], [])
	var own: int = 0
	var lent: int = 0
	for row: Dictionary in MatchScore.merc_rows(contract, member, lead):
		if bool(row["shared"]):
			lent += 1
		else:
			own += 1
	TestFixtures.check(res, "a member's rows mark only the lent rows it lacks as shared", own == 1 and lent == 1,
		"own %d, shared %d" % [own, lent])
	var thin: MercenaryData = _fixed("Th", 40.0, [], [])
	TestFixtures.check(res, "a merc with no traits shares nothing",
		MatchScore.leader_rows(contract, thin).is_empty(), "got %s" % str(MatchScore.leader_rows(contract, thin)))


static func _case_travel(res: Dictionary) -> void:
	var modes: Array[Dictionary] = GuiTypes.TRAVEL_MODES
	var costs: Array[int] = []
	for mode: Dictionary in modes:
		costs.append(DispatchLogic.travel_cost(mode, 3, 2, 100))
	TestFixtures.check(res, "one leg of travel bills per mode",
		costs == [12, 28, 60, 300, 420, 1500], "got %s" % str(costs))
	TestFixtures.check(res, "a per merc mode bills at least the contract minimum",
		DispatchLogic.travel_cost(modes[0], 1, 2, 100) == 8,
		"got %d" % DispatchLogic.travel_cost(modes[0], 1, 2, 100))
	TestFixtures.check(res, "a caravan bills once whatever the team size",
		DispatchLogic.travel_cost(modes[1], 5, 2, 100) == 28,
		"got %d" % DispatchLogic.travel_cost(modes[1], 5, 2, 100))
	TestFixtures.check(res, "a short trip still bills one leg",
		DispatchLogic.travel_cost(modes[1], 3, 2, 10) == 7
		and DispatchLogic.travel_cost(modes[2], 3, 2, 10) == 15,
		"got %d and %d" % [DispatchLogic.travel_cost(modes[1], 3, 2, 10),
			DispatchLogic.travel_cost(modes[2], 3, 2, 10)])
	TestFixtures.check(res, "no distance bills no fare",
		DispatchLogic.travel_cost(modes[2], 3, 2, 0) == 0,
		"got %d" % DispatchLogic.travel_cost(modes[2], 3, 2, 0))
	TestFixtures.check(res, "travel hours read the daily distance",
		_near(DispatchLogic.travel_hours(modes[0], 100), 80.0)
		and _near(DispatchLogic.travel_hours(modes[2], 100), 20.0),
		"got %.4f and %.4f" % [DispatchLogic.travel_hours(modes[0], 100),
			DispatchLogic.travel_hours(modes[2], 100)])
	TestFixtures.check(res, "teleportation arrives at once",
		_near(DispatchLogic.travel_hours(modes[5], 100), 0.0),
		"got %.4f" % DispatchLogic.travel_hours(modes[5], 100))


static func _case_plan(res: Dictionary) -> void:
	var modes: Array[Dictionary] = GuiTypes.TRAVEL_MODES
	var keys: Array = []
	for mode: Dictionary in modes:
		keys.append(str(mode["key"]))
	var rich: Dictionary = DispatchLogic.plan_travel(modes, 1000, 3, 2, 100, keys, keys)
	TestFixtures.check(res, "with no reward cap the cheapest venture and return win",
		str((rich["venture"] as Dictionary).get("key", "")) == "foot"
		and str((rich["ret"] as Dictionary).get("key", "")) == "foot",
		"got %s then %s" % [str((rich["venture"] as Dictionary).get("key", "")),
			str((rich["ret"] as Dictionary).get("key", ""))])
	var gated: Dictionary = DispatchLogic.plan_travel(modes, 1000, 3, 2, 100, ["horse", "train"], keys)
	TestFixtures.check(res, "the venture comes only from the keys that reach in time",
		str((gated["venture"] as Dictionary).get("key", "")) == "horse"
		and str((gated["ret"] as Dictionary).get("key", "")) == "foot",
		"got %s then %s" % [str((gated["venture"] as Dictionary).get("key", "")),
			str((gated["ret"] as Dictionary).get("key", ""))])
	var broke: Dictionary = DispatchLogic.plan_travel(modes, 5, 3, 2, 100, keys, keys)
	TestFixtures.check(res, "a bank short of every fare still walks out and back",
		str((broke["venture"] as Dictionary).get("key", "")) == "foot"
		and str((broke["ret"] as Dictionary).get("key", "")) == "foot",
		"got %s" % str(broke))
	var paid: Array = ["caravan", "horse", "train", "airship", "teleport"]
	var unpaid: Dictionary = DispatchLogic.plan_travel(modes, 5, 3, 2, 100, paid, paid)
	TestFixtures.check(res, "a bank short of every fare buys no paid travel",
		(unpaid["venture"] as Dictionary).is_empty() and (unpaid["ret"] as Dictionary).is_empty(),
		"got %s" % str(unpaid))
	var none: Array[Dictionary] = []
	TestFixtures.check(res, "no travel modes plan no travel",
		(DispatchLogic.plan_travel(none, 1000, 3, 2, 100, keys, keys)["venture"] as Dictionary).is_empty(),
		"got %s" % str(DispatchLogic.plan_travel(none, 1000, 3, 2, 100, keys, keys)))


static func _case_optimize(res: Dictionary) -> void:
	var weights: Dictionary = {1: 12, 2: 5, 3: 30, 4: 8, 5: 22, 6: 3, 7: 17, 8: 9, 9: 26, 10: 14}
	var odds_fn: Callable = func(team: Array) -> int: return _odds(team, weights)
	var uids: Array[int] = []
	for uid: int in range(1, 11):
		uids.append(uid)
	var result: Dictionary = DispatchLogic.optimize_plan(_request(uids, 1, 4, weights))
	var picked: Array[int] = result["team"]
	var wanted: Array = _brute(uids, 4, odds_fn)
	TestFixtures.check(res, "ten mercs enumerate to the exhaustive best",
		int(odds_fn.call(picked)) == int(wanted[0]) and picked.size() == int(wanted[1])
		and _near(float(result["p"]) * 100.0, float(wanted[0])),
		"expected odds %d over %d mercs, got %d over %d" % [int(wanted[0]), int(wanted[1]),
			int(odds_fn.call(picked)), picked.size()])
	var sorted_picked: Array[int] = picked.duplicate()
	sorted_picked.sort()
	TestFixtures.check(res, "the best team drops the weakest of the four slots",
		sorted_picked == [3, 5, 9], "got %s" % str(sorted_picked))
	var empty: Array[int] = []
	var none: Dictionary = DispatchLogic.optimize_plan(_request(empty, 1, 4, weights))
	var capped: Dictionary = DispatchLogic.optimize_plan(_request(uids, 1, 0, weights))
	TestFixtures.check(res, "no candidates and no slots pick nobody",
		(none["team"] as Array).is_empty() and (capped["team"] as Array).is_empty(),
		"got %s and %s" % [str(none), str(capped)])


static func _case_optimize_guard(res: Dictionary) -> void:
	var weights: Dictionary = {}
	var uids: Array[int] = []
	for uid: int in range(1, 41):
		weights[uid] = (uid * 7) % 29 + 1
		uids.append(uid)
	var odds_fn: Callable = func(team: Array) -> int: return _odds(team, weights)
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = DispatchLogic.optimize_plan(_request(uids, 1, 5, weights))
	var spent: int = Time.get_ticks_msec() - started
	var picked: Array[int] = result["team"]
	TestFixtures.check(res, "forty mercs answer inside a second", spent < 1000,
		"took %d ms" % spent)
	var seen: Dictionary = {}
	for uid: int in picked:
		seen[uid] = true
	TestFixtures.check(res, "the climbed team fits the slots and repeats nobody",
		picked.size() >= 1 and picked.size() <= 5 and seen.size() == picked.size(),
		"got %s" % str(picked))
	var best_single: int = 0
	for uid: int in weights:
		var one: Array[int] = [uid]
		best_single = maxi(best_single, int(odds_fn.call(one)))
	TestFixtures.check(res, "the climb beats the best single merc",
		int(odds_fn.call(picked)) >= best_single,
		"expected at least %d, got %d" % [best_single, int(odds_fn.call(picked))])
	var again: Dictionary = DispatchLogic.optimize_plan(_request(uids, 1, 5, weights))
	TestFixtures.check(res, "optimize: the same request twice gives the same result", str(again) == str(result),
		"got %s then %s" % [str(result), str(again)])


static func _case_optimize_ties(res: Dictionary) -> void:
	var uids: Array[int] = [1, 2, 3]
	var flat: Dictionary = {1: 50, 2: 50, 3: 50}
	var request: Dictionary = _request(uids, 1, 3, flat)
	request["chance_fn"] = func(_team: Array[int], _leader: int) -> float: return 0.5
	var fewer: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "optimize: an equal p goes to the fewer mercs", (fewer["team"] as Array).size() == 1,
		"got %s" % str(fewer))
	var features: Dictionary = {1: 3, 2: 1, 3: 2}
	request["features_fn"] = func(uid: int) -> int: return int(features[uid])
	var lean: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "optimize: an equal p and size goes to the fewer features",
		(lean["team"] as Array) == [2], "got %s" % str(lean))
	var costs: Dictionary = {1: 9, 2: 7, 3: 8}
	request["features_fn"] = func(_uid: int) -> int: return 0
	request["mode_fn"] = func(team: Array[int]) -> Dictionary:
		var total: int = 0
		for uid: int in team:
			total += int(costs[uid])
		return {"mode": "foot", "cost": total}
	var cheap: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "optimize: an equal p, size and features goes to the lower cost",
		(cheap["team"] as Array) == [2] and int(cheap["cost"]) == 7, "got %s" % str(cheap))


static func _case_optimize_valid(res: Dictionary) -> void:
	var uids: Array[int] = [1, 2, 3]
	var weights: Dictionary = {1: 10, 2: 20, 3: 90}
	var request: Dictionary = _request(uids, 1, 3, weights)
	request["mode_fn"] = func(team: Array[int]) -> Dictionary:
		return {} if team.has(3) else {"mode": "foot", "cost": 0}
	var barred: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "optimize: a team with no valid mode is never returned",
		not (barred["team"] as Array).is_empty() and not (barred["team"] as Array).has(3), "got %s" % str(barred))
	request["mode_fn"] = func(_team: Array[int]) -> Dictionary: return {}
	var none: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "optimize: no valid team returns an empty team",
		(none["team"] as Array).is_empty() and int(none["leader_uid"]) == -1, "got %s" % str(none))
	var led: Dictionary = _request(uids, 3, 3, weights)
	led["chance_fn"] = func(_team: Array[int], leader: int) -> float: return 0.7 if leader == 2 else 0.4
	var lead: Dictionary = DispatchLogic.optimize_plan(led)
	TestFixtures.check(res, "optimize: the leader is the member with the highest p",
		int(lead["leader_uid"]) == 2 and int((lead["team"] as Array)[0]) == 2 and _near(float(lead["p"]), 0.7),
		"got %s" % str(lead))
	var twelve: Array[int] = []
	var spread: Dictionary = {}
	for uid: int in range(1, 13):
		twelve.append(uid)
		spread[uid] = (uid * 5) % 13 + 1
	var started: int = Time.get_ticks_msec()
	var wide: Dictionary = DispatchLogic.optimize_plan(_request(twelve, 1, 5, spread))
	var spent: int = Time.get_ticks_msec() - started
	TestFixtures.check(res, "optimize: twelve candidates at cap five answer within the time budget",
		spent <= DispatchLogic.TIME_BUDGET_MS + 200 and not (wide["team"] as Array).is_empty(),
		"took %d ms, got %s" % [spent, str(wide)])


#A chance that burns about 2 ms per call must not let one search round run past the budget.
static func _case_optimize_slow(res: Dictionary) -> void:
	var forty: Array[int] = []
	var spread: Dictionary = {}
	for uid: int in range(1, 41):
		forty.append(uid)
		spread[uid] = (uid * 7) % 41 + 1
	var request: Dictionary = _request(forty, 1, 5, spread)
	request["chance_fn"] = func(team: Array[int], _leader: int) -> float:
		var until: int = Time.get_ticks_msec() + 2
		while Time.get_ticks_msec() < until:
			pass
		return float(_odds(team, spread)) / 100.0
	var started: int = Time.get_ticks_msec()
	var slow: Dictionary = DispatchLogic.optimize_plan(request)
	var spent: int = Time.get_ticks_msec() - started
	TestFixtures.check(res, "optimize: a slow chance stops inside the budget",
		spent <= DispatchLogic.TIME_BUDGET_MS + 300 and not (slow["team"] as Array).is_empty(),
		"took %d ms, got %s" % [spent, str(slow)])


#A synthetic optimize_plan request: chance from _odds, every team walks at no fare, no features, uid names.
static func _request(uids: Array[int], lo: int, cap: int, weights: Dictionary) -> Dictionary:
	return {
		"uids": uids,
		"lo": lo,
		"cap": cap,
		"seed": 7,
		"chance_fn": func(team: Array[int], _leader: int) -> float: return float(_odds(team, weights)) / 100.0,
		"mode_fn": func(_team: Array[int]) -> Dictionary: return {"mode": "foot", "cost": 0},
		"features_fn": func(_uid: int) -> int: return 0,
		"solo_fn": func(_uid: int) -> float: return 0.0,
		"name_fn": func(uid: int) -> String: return "M%d" % uid,
	}


static func _fixed(merc_name: String, base_chance: float, knowledges: Array, tools: Array) -> MercenaryData:
	var m: MercenaryData = TestFixtures.fixed_merc(merc_name, {OverallSuccess.STAT_KEY: base_chance})
	for name: Variant in knowledges:
		m.knowledges.append(ContractFixtures.utility(str(name)))
	for name: Variant in tools:
		m.tools.append(ContractFixtures.utility(str(name)))
	return m


static func _boosts(knowledge: Dictionary, tool: Dictionary, tradition: Dictionary) -> ContractData:
	var c := ContractData.new()
	c.contract_type = "Escort"
	c.knowledge_boosts = knowledge
	c.tool_boosts = tool
	c.tradition_boosts = tradition
	return c


static func _case_metric_defs(res: Dictionary) -> void:
	var history: Variant = _history()
	var defs: Array[MetricDef] = history.defs
	TestFixtures.check(res, "the metrics list holds the 28 sample metrics", defs.size() == 28,
		"got %d" % defs.size())
	var found: Dictionary = {}
	for def: MetricDef in defs:
		found["%s/%s" % [def.source, def.key]] = def
	TestFixtures.check(res, "every metric names a known source and aggregation",
		found.size() == 28 and _agg(found, "Merc/op") == "AVG" and _agg(found, "Guild/bank") == "LAST"
		and _agg(found, "Contract/diff") == "EVENT_AVG" and _agg(found, "Merc/xp") == "SUM"
		and _agg(found, "Guild/port") == "LAST" and _agg(found, "Merc/vac") == "SUM",
		"got %d distinct keys" % found.size())
	var on_count: int = 0
	for def: MetricDef in defs:
		if def.default_on:
			on_count += 1
	TestFixtures.check(res, "eight metrics start switched on", on_count == 8,
		"got %d" % on_count)
	var undescribed: Array[String] = []
	var unformatted: Array[String] = []
	for def: MetricDef in defs:
		if def.description.strip_edges() == "":
			undescribed.append(def.key)
		if not METRIC_FORMATS.has(def.fmt):
			unformatted.append("%s on '%s'" % [def.key, def.fmt])
	TestFixtures.check(res, "every metric carries a tooltip line", undescribed.is_empty(),
		TestFixtures.detail(undescribed, defs.size(), "metrics"))
	TestFixtures.check(res, "every metric names one of the four axis formats", unformatted.is_empty(),
		TestFixtures.detail(unformatted, defs.size(), "metrics"))
	TestFixtures.check(res, "an empty record reports no days",
		int(history.days()) == 0 and int(history.first_day()) == -1,
		"got %d days from day %d" % [int(history.days()), int(history.first_day())])
	TestFixtures.check(res, "the scales open as the record grows",
		history.scales(99) == ["Days"] and history.scales(120) == ["Days", "Weeks"]
		and history.scales(330) == ["Days", "Weeks", "Months"]
		and history.scales(3300) == ["Days", "Weeks", "Months", "Quarters"],
		"got %s at 120 days" % str(history.scales(120)))
	history.free()


static func _case_series(res: Dictionary) -> void:
	var history: Variant = _history()
	history.guild_source = func(day: int) -> Dictionary:
		return {"exp": float(day - 3), "bank": float(day - 3), "cop": float(day - 3)}
	for day: int in 12:
		history.record_day(day + 4)
	TestFixtures.check(res, "the record counts its days from the first",
		int(history.days()) == 12 and int(history.first_day()) == 4,
		"got %d days from day %d" % [int(history.days()), int(history.first_day())])
	TestFixtures.check(res, "a summed metric adds its bucket",
		_values(history.series("Guild", "exp", 0, 5)) == [15.0, 40.0, 23.0],
		"got %s" % str(_values(history.series("Guild", "exp", 0, 5))))
	TestFixtures.check(res, "a last metric reads the end of its bucket",
		_values(history.series("Guild", "bank", 0, 5)) == [5.0, 10.0, 12.0],
		"got %s" % str(_values(history.series("Guild", "bank", 0, 5))))
	TestFixtures.check(res, "an averaged metric divides by the days it holds",
		_values(history.series("Guild", "cop", 0, 5)) == [3.0, 8.0, 11.5],
		"got %s" % str(_values(history.series("Guild", "cop", 0, 5))))
	var points: Array[Dictionary] = history.series("Guild", "exp", 0, 5)
	TestFixtures.check(res, "every point names the first day of its bucket",
		int(points[0]["day"]) == 0 and int(points[1]["day"]) == 5 and int(points[2]["day"]) == 10,
		"got %s" % str(points))
	TestFixtures.check(res, "a later start drops the days before it",
		_values(history.series("Guild", "exp", 10, 5)) == [23.0],
		"got %s" % str(_values(history.series("Guild", "exp", 10, 5))))
	TestFixtures.check(res, "an unknown source or key reads as empty or zero",
		history.series("Nowhere", "exp", 0, 5).is_empty()
		and _values(history.series("Guild", "nothing", 0, 12)) == [0.0],
		"got %s" % str(_values(history.series("Guild", "nothing", 0, 12))))
	history.free()


static func _case_event_series(res: Dictionary) -> void:
	var history: Variant = _history()
	var sums: Array[float] = [0.0, 0.0, 4.0, 0.0, 0.0, 9.0, 0.0, 0.0, 0.0, 0.0, 6.0, 0.0]
	var counts: Array[float] = [0.0, 0.0, 2.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0]
	history.contract_source = func(day: int) -> Dictionary:
		return {"diff": sums[day], "diff_n": counts[day]}
	for day: int in 12:
		history.record_day(day)
	TestFixtures.check(res, "an event metric averages over its events, not its days",
		_values(history.series("Contract", "diff", 0, 4)) == [2.0, 3.0, 3.0],
		"got %s" % str(_values(history.series("Contract", "diff", 0, 4))))
	TestFixtures.check(res, "a per type key reads the same aggregation",
		_values(history.series("Contract", "2/diff", 0, 4)) == [0.0, 0.0, 0.0],
		"got %s" % str(_values(history.series("Contract", "2/diff", 0, 4))))
	history.free()
	var lead: Variant = _history()
	var lead_sums: Array[float] = [0.0, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0, 0.0]
	var lead_counts: Array[float] = [0.0, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0.0]
	lead.contract_source = func(day: int) -> Dictionary:
		return {"diff": lead_sums[day], "diff_n": lead_counts[day]}
	for day: int in 8:
		lead.record_day(day)
	TestFixtures.check(res, "a leading bucket with no events takes the first value there is",
		_values(lead.series("Contract", "diff", 0, 4)) == [2.0, 2.0],
		"got %s" % str(_values(lead.series("Contract", "diff", 0, 4))))
	lead.free()
	var carry: Variant = _history()
	var carry_sums: Array[float] = [6.0, 0.0, 0.0, 0.0]
	var carry_counts: Array[float] = [3.0, 0.0, 0.0, 0.0]
	carry.contract_source = func(day: int) -> Dictionary:
		return {"diff": carry_sums[day], "diff_n": carry_counts[day]}
	for day: int in 4:
		carry.record_day(day)
	TestFixtures.check(res, "a later bucket with no events carries the last value forward",
		_values(carry.series("Contract", "diff", 0, 2)) == [2.0, 2.0],
		"got %s" % str(_values(carry.series("Contract", "diff", 0, 2))))
	carry.free()


static func _case_preview(res: Dictionary) -> void:
	var history: Variant = _history()
	history.seed_preview(PREVIEW_DAYS)
	TestFixtures.check(res, "the sample history fills every day it was asked for",
		int(history.days()) == PREVIEW_DAYS and int(history.first_day()) == 0,
		"got %d days from day %d" % [int(history.days()), int(history.first_day())])
	var bad: Array[String] = []
	for i: int in PREVIEW_MERCS.size():
		var merc: int = PREVIEW_MERCS[i]
		var mean: float = float(history.series("Merc", "%d/op" % merc, 0, PREVIEW_DAYS)[0]["value"])
		if not _near(mean * float(PREVIEW_DAYS), float(OPINION_SUMS[i])):
			bad.append("merc %d gave %.4f" % [merc, mean * float(PREVIEW_DAYS)])
	TestFixtures.check(res, "the sample guild opinions match the reference run", bad.is_empty(),
		TestFixtures.detail(bad, PREVIEW_MERCS.size(), "mercs"))
	var last: Array[String] = []
	for i: int in PREVIEW_MERCS.size():
		var merc: int = PREVIEW_MERCS[i]
		var value: float = float(history.series("Merc", "%d/op" % merc, PREVIEW_DAYS - 1,
			1)[0]["value"])
		if not _near(value, float(OPINION_LAST[i])):
			last.append("merc %d gave %.2f" % [merc, value])
	TestFixtures.check(res, "the last sampled day holds the starting opinion", last.is_empty(),
		TestFixtures.detail(last, PREVIEW_MERCS.size(), "mercs"))
	var pay: Array[String] = []
	for i: int in PREVIEW_MERCS.size():
		var merc: int = PREVIEW_MERCS[i]
		var salary: float = float(history.series("Merc", "%d/salary" % merc, 0,
			PREVIEW_DAYS)[0]["value"])
		if not _near(salary, float(PREVIEW_SALARIES[i])):
			pay.append("merc %d gave %.2f" % [merc, salary])
	TestFixtures.check(res, "an unraised sample salary stays at its hiring rate", pay.is_empty(),
		TestFixtures.detail(pay, PREVIEW_MERCS.size(), "mercs"))
	var opening: Array[float] = _values(history.series("Merc", "0/op", 0, 1)).slice(0, 3)
	TestFixtures.check(res, "the sample opinions drift day by day", opening == [1.0, 1.0, 0.0],
		"got %s" % str(opening))
	var count: float = float(history.series("Guild", "count", 0, PREVIEW_DAYS)[0]["value"])
	var dead: float = float(history.series("Guild", "dead", 0, PREVIEW_DAYS)[0]["value"])
	TestFixtures.check(res, "a 120 day sample hires ten mercs and buries none",
		_near(count, 10.0) and _near(dead, 0.0),
		"got %.1f mercs and %.1f casualties" % [count, dead])
	var bank: Array[Dictionary] = history.series("Guild", "bank", 0, 10)
	TestFixtures.check(res, "the sample bank never runs below a hundred",
		bank.size() == 12 and _lowest(bank) >= 100.0,
		"got %d points with a low of %.2f" % [bank.size(), _lowest(bank)])
	history.free()


#The four flat button variations synthesize hover and pressed from their normal fill.
static func _case_theme_states(res: Dictionary) -> void:
	var theme: Theme = load("res://Resources/GUI/Theme/guild_theme.tres")
	TestFixtures.check(res, "the guild theme loads", theme != null,
		"loaded" if theme != null else "got null")
	if theme == null:
		return
	var names: Array[String] = ["ButtonDanger", "ButtonGo", "ButtonNeutral", "ButtonOrange"]
	for type_name: String in names:
		var normal: StyleBoxFlat = theme.get_stylebox("normal", type_name) as StyleBoxFlat
		var hover: StyleBoxFlat = theme.get_stylebox("hover", type_name) as StyleBoxFlat
		var pressed: StyleBoxFlat = theme.get_stylebox("pressed", type_name) as StyleBoxFlat
		var ok: bool = (hover != null and pressed != null and hover != normal and pressed != normal
			and hover.bg_color.v > normal.bg_color.v and pressed.bg_color.v < normal.bg_color.v
			and hover.border_color == normal.border_color
			and pressed.border_color == normal.border_color)
		TestFixtures.check(res, "%s hover and pressed synthesize from the normal fill" % type_name, ok,
			"normal.v %.4f hover.v %.4f pressed.v %.4f" % [normal.bg_color.v, hover.bg_color.v,
				pressed.bg_color.v])
	var variations: Array[String] = ["PanelTitle", "TabActive", "TabIdle"]
	var missing: Array[String] = []
	for variation: String in variations:
		if not theme.has_font("font", variation):
			missing.append(variation)
	TestFixtures.check(res, "the theme carries the PanelTitle, TabActive and TabIdle variations",
		missing.is_empty(), "missing %s" % str(missing))


static func _history() -> Variant:
	return load(HISTORY_PATH).new()


#A sample odds function: the team's weights less a penalty for every slot past the first.
static func _odds(team: Array, weights: Dictionary) -> int:
	var sum: int = 0
	for uid: Variant in team:
		sum += int(weights.get(uid, 0))
	return clampi(sum - 20 * (team.size() - 1), 1, 99)


#The best odds and the smallest team reaching them, over every subset up to the cap.
static func _brute(uids: Array[int], cap: int, odds_fn: Callable) -> Array:
	var best: int = -1
	var best_size: int = 0
	for mask: int in range(1, 1 << uids.size()):
		var team: Array[int] = []
		for i: int in uids.size():
			if mask & (1 << i) != 0:
				team.append(uids[i])
		if team.size() > cap:
			continue
		var value: int = int(odds_fn.call(team))
		if value > best or (value == best and team.size() < best_size):
			best = value
			best_size = team.size()
	return [best, best_size]


static func _values(points: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for point: Dictionary in points:
		out.append(float(point["value"]))
	return out


static func _lowest(points: Array[Dictionary]) -> float:
	var low: float = INF
	for point: Dictionary in points:
		low = minf(low, float(point["value"]))
	return low


static func _agg(found: Dictionary, key: String) -> String:
	if not found.has(key):
		return ""
	return (found[key] as MetricDef).agg


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001

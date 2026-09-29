class_name GuiTests

#Dispatch scoring, travel planning, the dispatch optimizer and the metrics record.
#Run headless with the gui-tests suite flag; see HarnessEntry.gd for the exact arguments.
#The expected numbers come from dispatch_scoring.js and metrics_history_generator.js.

const HISTORY_PATH := "res://Scripts/GUI/Autoloads/MetricsHistory.gd"
#Rating weights of one sample merc against the sample contract, by role.
const LEADER_SCORE := 0.5083333333
const SUPPORT_SCORE := 0.625
#Guild opinion totals of metrics_history_generator.js over a 120 day preview.
const PREVIEW_DAYS := 120
const OPINION_SUMS: Array[int] = [307, -284, 118, -507]
const OPINION_LAST: Array[int] = [5, -2, 3, -3]
const PREVIEW_MERCS: Array[int] = [0, 1, 5, 9]
const PREVIEW_SALARIES: Array[int] = [60, 150, 40, 120]
#The axis formats a metric may name; LineChart.axis_text reads the same set.
const METRIC_FORMATS: Array[String] = ["money", "int", "op", "float"]

#F6B: the 21 scroll sites built as plain scenes; BailoutPage and FilterSection build in code.
const SCROLL_SCENES: Array[String] = [
	"res://Scenes/GUI/Finance/Overview/FinanceTransactions.tscn",
	"res://Scenes/GUI/Mercs/MercList.tscn",
	"res://Scenes/GUI/Mercs/TraitListPanel.tscn",
	"res://Scenes/GUI/Mercs/OverviewTab.tscn",
	"res://Scenes/GUI/Mercs/ActionsTab.tscn",
	"res://Scenes/GUI/Mercs/EquipmentTab.tscn",
	"res://Scenes/GUI/Mercs/RelationshipsTab.tscn",
	"res://Scenes/GUI/Contracts/ContractList.tscn",
	"res://Scenes/GUI/Contracts/TeamSlot.tscn",
	"res://Scenes/GUI/Contracts/MercPicker.tscn",
	"res://Scenes/GUI/Contracts/RecommendedList.tscn",
	"res://Scenes/GUI/Contracts/DispatchRoster.tscn",
	"res://Scenes/GUI/Finance/Payroll/PayrollTab.tscn",
	"res://Scenes/GUI/Clients/ClientList.tscn",
	"res://Scenes/GUI/Shared/TraitFilterPanel.tscn",
	"res://Scenes/GUI/Shared/CrewMercPicker.tscn",
	"res://Scenes/GUI/Promotions/CampaignList.tscn",
	"res://Scenes/GUI/Metrics/MetricsViewer.tscn",
	"res://Scenes/GUI/Notifications/NotificationPanel.tscn",
]

#F6B: the census of outer MarginContainers bumped to 14 px on every side.
const MARGIN_CENSUS: Array = [
	["res://Scenes/GUI/Subscription/SubscriptionViewer.tscn", "Margin"],
	["res://Scenes/GUI/Subscription/PlanCard.tscn", "Pad"],
	["res://Scenes/GUI/Subscription/PlanSwitchDialog.tscn", "Box/Pad"],
	["res://Scenes/GUI/Shared/LockedPage.tscn", "Panel/Pad"],
	["res://Scenes/GUI/Shared/FeatureLockDialog.tscn", "Box/Pad"],
	["res://Scenes/GUI/Shared/TextEntryDialog.tscn", "Box/Pad"],
	["res://Scenes/GUI/Contracts/DispatchWindow.tscn", "Margin"],
	["res://Scenes/GUI/Contracts/ContractViewer.tscn", "Margin"],
	["res://Scenes/GUI/Clients/ClientViewer.tscn", "Margin"],
	["res://Scenes/GUI/Bazaar/BazaarViewer.tscn", "Margin"],
	["res://Scenes/GUI/Mercs/CoachDialog.tscn", "Box/Pad"],
	["res://Scenes/GUI/Mercs/SalaryDialog.tscn", "Box/Pad"],
	["res://Scenes/GUI/Mercs/MercViewer.tscn", "Margin"],
	["res://Scenes/GUI/Shared/OddJobWindow.tscn", "Box/Pad"],
	["res://Scenes/GUI/Promotions/PromotionsViewer.tscn", "Body"],
	["res://Scenes/GUI/Promotions/CampaignBuilder.tscn", "Center/Frame/Pad"],
	["res://Scenes/GUI/Finance/Overview/FinanceTransactions.tscn", "Pad"],
	["res://Scenes/GUI/Metrics/MetricsViewer.tscn", "Margin"],
	["res://Scenes/GUI/Shared/CrewMercPicker.tscn", "Box/Pad"],
]

#F6B: census entries where the 14 px comes from a panel StyleBoxFlat on the named node, not a
#MarginContainer.
const STYLE_NODE_CENSUS: Array = [
	["res://Scenes/GUI/Mercs/OverviewTab.tscn", "Pad/Rows/Middle/Resources"],
	["res://Scenes/GUI/Contracts/MercPicker.tscn", "Center/Box"],
	["res://Scenes/GUI/Clients/ClientList.tscn", "."],
	["res://Scenes/GUI/Clients/ClientOverview.tscn",
		"Rows/Body/Lower/Left/RecentPanel/RecentScroll/Items/Empty"],
]

#F6B: shared style resources bumped to 14 px content margin on every side.
const STYLE_FILE_CENSUS: Array[String] = [
	"res://Resources/GUI/Theme/Styles/PanelContent.tres",
	"res://Resources/GUI/Theme/Styles/bazaar_content.tres",
	"res://Resources/GUI/Theme/Styles/client_panel.tres",
	"res://Resources/GUI/Theme/Styles/client_list_panel.tres",
]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_score(res)
	_case_top_traits(res)
	_case_travel(res)
	_case_plan(res)
	_case_optimize(res)
	_case_optimize_guard(res)
	_case_metric_defs(res)
	_case_series(res)
	_case_event_series(res)
	_case_preview(res)
	_case_theme_states(res)
	_case_scroll_padding(res)
	_case_box_padding(res)
	_case_portfolio_top(res)
	return TestFixtures.summarize(res, "GUI")


static func _case_score(res: Dictionary) -> void:
	var contract: ContractView = _contract(["K1", "K2", "K3", "K4"], ["T1", "T2", "T3"],
		["Tr1", "Tr2"])
	var merc: MercView = _merc(1, "Tr1", ["K2", "K4"], ["T3"])
	var leader: float = DispatchLogic.score(merc, contract, "Leader", {})
	TestFixtures.check(res, "the leader rating reads the lists unrotated",
		_near(leader, LEADER_SCORE), "expected %.7f, got %.7f" % [LEADER_SCORE, leader])
	var support: float = DispatchLogic.score(merc, contract, "Support", {})
	TestFixtures.check(res, "the support rating rotates the lists two places",
		_near(support, SUPPORT_SCORE), "expected %.7f, got %.7f" % [SUPPORT_SCORE, support])
	TestFixtures.check(res, "a rating rounds to half stars",
		_near(DispatchLogic.to_stars(leader), 2.5) and _near(DispatchLogic.to_stars(support), 3.0),
		"got %.2f and %.2f" % [DispatchLogic.to_stars(leader), DispatchLogic.to_stars(support)])
	TestFixtures.check(res, "stars never leave the half to five band",
		_near(DispatchLogic.to_stars(0.0), 0.5) and _near(DispatchLogic.to_stars(1.0), 5.0)
		and _near(DispatchLogic.to_stars(0.02), 0.5),
		"got %.2f, %.2f and %.2f" % [DispatchLogic.to_stars(0.0), DispatchLogic.to_stars(1.0),
			DispatchLogic.to_stars(0.02)])
	var other: MercView = _merc(2, "Tr2", ["K1"], [])
	var alone: float = DispatchLogic.score(other, contract, "Support", {})
	var shared: float = DispatchLogic.score(other, contract, "Support",
		DispatchLogic.leader_share(merc, contract))
	TestFixtures.check(res, "the leader's top traits lift every other slot",
		_near(alone, 0.225) and _near(shared, 0.45),
		"expected 0.2250000 and 0.4500000, got %.7f and %.7f" % [alone, shared])
	var repeated: ContractView = _contract(["K1", "K2", "K1", "K3"], [], [])
	var third: MercView = _merc(3, "", ["K3"], [])
	TestFixtures.check(res, "a repeated recommendation counts once",
		_near(DispatchLogic.score(third, repeated, "Leader", {}), 0.4 * (1.0 / 3.0) / 2.0),
		"got %.7f" % DispatchLogic.score(third, repeated, "Leader", {}))
	var bare: ContractView = _contract([], [], [])
	TestFixtures.check(res, "a contract with no recommendations rates zero",
		_near(DispatchLogic.score(merc, bare, "Leader", {}), 0.0),
		"got %.7f" % DispatchLogic.score(merc, bare, "Leader", {}))


static func _case_top_traits(res: Dictionary) -> void:
	var contract: ContractView = _contract(["K1", "K2", "K3", "K4"], ["T1", "T2", "T3"],
		["Tr1", "Tr2"])
	var merc: MercView = _merc(1, "Tr1", ["K2", "K4"], ["T3"])
	var traits: Array[Dictionary] = DispatchLogic.top_traits(merc, contract, "Leader")
	TestFixtures.check(res, "top traits return the two strongest",
		traits.size() == 2 and str(traits[0]["name"]) == "K2" and str(traits[1]["name"]) == "T3",
		"got %s" % str(traits))
	TestFixtures.check(res, "top traits carry their kind and weight",
		str(traits[0]["kind"]) == "know" and _near(float(traits[0]["value"]), 0.75)
		and str(traits[1]["kind"]) == "tool" and _near(float(traits[1]["value"]), 1.0 / 3.0),
		"got %s" % str(traits))
	var share: Dictionary = DispatchLogic.leader_share(merc, contract)
	TestFixtures.check(res, "the leader share splits knowledges from tools",
		share["know"] == ["K2"] and share["tools"] == ["T3"], "got %s" % str(share))
	var thin: MercView = _merc(4, "Tr1", [], [])
	TestFixtures.check(res, "a merc with no traits shares nothing",
		DispatchLogic.top_traits(thin, contract, "Leader").is_empty(),
		"got %s" % str(DispatchLogic.top_traits(thin, contract, "Leader")))


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
	var rich: Dictionary = DispatchLogic.plan_travel(modes, 1000, 500, 3, 2, 100)
	TestFixtures.check(res, "a tenth of the reward buys the fastest venture it covers",
		str((rich["venture"] as Dictionary).get("key", "")) == "caravan"
		and str((rich["ret"] as Dictionary).get("key", "")) == "foot",
		"got %s then %s" % [str((rich["venture"] as Dictionary).get("key", "")),
			str((rich["ret"] as Dictionary).get("key", ""))])
	var poor: Dictionary = DispatchLogic.plan_travel(modes, 1000, 10, 3, 2, 100)
	TestFixtures.check(res, "a reward that covers nothing falls back to the cheapest pair",
		str((poor["venture"] as Dictionary).get("key", "")) == "foot"
		and str((poor["ret"] as Dictionary).get("key", "")) == "foot",
		"got %s then %s" % [str((poor["venture"] as Dictionary).get("key", "")),
			str((poor["ret"] as Dictionary).get("key", ""))])
	var broke: Dictionary = DispatchLogic.plan_travel(modes, 5, 500, 3, 2, 100)
	TestFixtures.check(res, "an empty bank plans no travel at all",
		(broke["venture"] as Dictionary).is_empty() and (broke["ret"] as Dictionary).is_empty(),
		"got %s" % str(broke))
	var none: Array[Dictionary] = []
	TestFixtures.check(res, "no travel modes plan no travel",
		(DispatchLogic.plan_travel(none, 1000, 500, 3, 2, 100)["venture"] as Dictionary).is_empty(),
		"got %s" % str(DispatchLogic.plan_travel(none, 1000, 500, 3, 2, 100)))


static func _case_optimize(res: Dictionary) -> void:
	var weights: Dictionary = {1: 12, 2: 5, 3: 30, 4: 8, 5: 22, 6: 3, 7: 17, 8: 9, 9: 26, 10: 14}
	var odds_fn: Callable = func(team: Array) -> int: return _odds(team, weights)
	var candidates: Array[MercView] = []
	var uids: Array[int] = []
	for uid: int in range(1, 11):
		candidates.append(_merc(uid, "", [], []))
		uids.append(uid)
	var picked: Array[int] = DispatchLogic.optimize(candidates, 4, odds_fn)
	var wanted: Array = _brute(uids, 4, odds_fn)
	TestFixtures.check(res, "ten mercs enumerate to the exhaustive best",
		int(odds_fn.call(picked)) == int(wanted[0]) and picked.size() == int(wanted[1]),
		"expected odds %d over %d mercs, got %d over %d" % [int(wanted[0]), int(wanted[1]),
			int(odds_fn.call(picked)), picked.size()])
	var sorted_picked: Array[int] = picked.duplicate()
	sorted_picked.sort()
	TestFixtures.check(res, "the best team drops the weakest of the four slots",
		sorted_picked == [3, 5, 9], "got %s" % str(sorted_picked))
	var empty: Array[MercView] = []
	TestFixtures.check(res, "no candidates and no slots pick nobody",
		DispatchLogic.optimize(empty, 4, odds_fn).is_empty()
		and DispatchLogic.optimize(candidates, 0, odds_fn).is_empty(),
		"got %s and %s" % [str(DispatchLogic.optimize(empty, 4, odds_fn)),
			str(DispatchLogic.optimize(candidates, 0, odds_fn))])


static func _case_optimize_guard(res: Dictionary) -> void:
	var weights: Dictionary = {}
	var candidates: Array[MercView] = []
	for uid: int in range(1, 41):
		weights[uid] = (uid * 7) % 29 + 1
		candidates.append(_merc(uid, "", [], []))
	var odds_fn: Callable = func(team: Array) -> int: return _odds(team, weights)
	var started: int = Time.get_ticks_msec()
	var picked: Array[int] = DispatchLogic.optimize(candidates, 5, odds_fn)
	var spent: int = Time.get_ticks_msec() - started
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


static func _case_metric_defs(res: Dictionary) -> void:
	var history: Variant = load(HISTORY_PATH).new()
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
	var history: Variant = load(HISTORY_PATH).new()
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
	var history: Variant = load(HISTORY_PATH).new()
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
	var lead: Variant = load(HISTORY_PATH).new()
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
	var carry: Variant = load(HISTORY_PATH).new()
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
	var history: Variant = load(HISTORY_PATH).new()
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


#B3: the four flat button variations synthesize hover and pressed from their normal fill.
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


#F6B: every scroll site's first child is a Pad MarginContainer at 14 px top and bottom.
static func _case_scroll_padding(res: Dictionary) -> void:
	var bad: Array[String] = []
	for scene_path: String in SCROLL_SCENES:
		var packed: Variant = load(scene_path)
		if not (packed is PackedScene):
			bad.append("%s did not load" % scene_path)
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		var scrolls: Array[ScrollContainer] = []
		_find_scrolls(inst, scrolls, true)
		if scrolls.is_empty():
			bad.append("%s has no ScrollContainer" % scene_path)
		for scroll: ScrollContainer in scrolls:
			var first: Node = scroll.get_child(0) if scroll.get_child_count() > 0 else null
			var pad: MarginContainer = first as MarginContainer
			if pad == null:
				bad.append("%s %s's first child is not a MarginContainer" % [scene_path, scroll.name])
				continue
			var top: int = pad.get_theme_constant(&"margin_top")
			var bottom: int = pad.get_theme_constant(&"margin_bottom")
			if top != 14 or bottom != 14:
				bad.append("%s %s pad is %d/%d" % [scene_path, scroll.name, top, bottom])
			if not (pad.size_flags_horizontal & Control.SIZE_EXPAND):
				bad.append("%s %s pad does not expand" % [scene_path, scroll.name])
		inst.free()
	_check_code_scrolls(bad)
	TestFixtures.check(res, "every owned scroll container pads its content 14 px top and bottom",
		bad.is_empty(), TestFixtures.detail(bad, SCROLL_SCENES.size() + 2, "scroll sites"))


#Stops at the root of any nested instanced sub-scene so a component I do not own never counts.
static func _find_scrolls(node: Node, out: Array[ScrollContainer], is_root: bool) -> void:
	if node is ScrollContainer:
		out.append(node as ScrollContainer)
	if not is_root and node.scene_file_path != "":
		return
	for child: Node in node.get_children():
		_find_scrolls(child, out, false)


#The two scroll sites BailoutPage.gd and FilterSection.gd build in code rather than in a .tscn.
static func _check_code_scrolls(bad: Array[String]) -> void:
	var page: BailoutPage = BailoutPage.new()
	page._build()
	var bail_top: int = page.pad.get_theme_constant(&"margin_top") if page.pad != null else -1
	var bail_bottom: int = page.pad.get_theme_constant(&"margin_bottom") if page.pad != null else -1
	if bail_top != 14 or bail_bottom != 14:
		bad.append("BailoutPage.gd pad is %d/%d" % [bail_top, bail_bottom])
	page.free()
	var fs_packed: PackedScene = load("res://Scenes/GUI/Shared/FilterSection.tscn") as PackedScene
	var fs: FilterSection = fs_packed.instantiate() as FilterSection
	fs.title_label = fs.get_node(^"Title") as Label
	fs.lock = fs.get_node(^"Lock") as FeatureLock
	fs.body = fs.get_node(^"Body") as VBoxContainer
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(&"")
	fs._def = TraitFilterDefs.find(defs, &"loc")
	fs._build()
	var mods_pad: MarginContainer = fs.body.get_node_or_null(^"ModsBox/Scroll/Pad") as MarginContainer
	var mods_top: int = mods_pad.get_theme_constant(&"margin_top") if mods_pad != null else -1
	var mods_bottom: int = mods_pad.get_theme_constant(&"margin_bottom") if mods_pad != null else -1
	if mods_top != 14 or mods_bottom != 14:
		bad.append("FilterSection.gd mods pad is %d/%d" % [mods_top, mods_bottom])
	fs.free()


#F6B: the census of outer windows and shared styles padded 14 px on every side.
static func _case_box_padding(res: Dictionary) -> void:
	var bad: Array[String] = []
	var total: int = MARGIN_CENSUS.size() + STYLE_NODE_CENSUS.size() + STYLE_FILE_CENSUS.size()
	for entry: Array in MARGIN_CENSUS:
		var scene_path: String = entry[0]
		var node_path: String = entry[1]
		var packed: Variant = load(scene_path)
		if not (packed is PackedScene):
			bad.append("%s did not load" % scene_path)
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		var target: MarginContainer = inst.get_node_or_null(node_path) as MarginContainer
		if target == null:
			bad.append("%s has no MarginContainer at %s" % [scene_path, node_path])
		else:
			var sides: Array[int] = [
				target.get_theme_constant(&"margin_left"), target.get_theme_constant(&"margin_top"),
				target.get_theme_constant(&"margin_right"), target.get_theme_constant(&"margin_bottom"),
			]
			if sides != [14, 14, 14, 14]:
				bad.append("%s %s is %s" % [scene_path, node_path, str(sides)])
		inst.free()
	for entry: Array in STYLE_NODE_CENSUS:
		var scene_path: String = entry[0]
		var node_path: String = entry[1]
		var packed: Variant = load(scene_path)
		if not (packed is PackedScene):
			bad.append("%s did not load" % scene_path)
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		var target: Control = inst as Control
		if node_path != ".":
			target = inst.get_node_or_null(node_path) as Control
		var style: StyleBoxFlat = null
		if target != null:
			style = target.get_theme_stylebox(&"panel") as StyleBoxFlat
		if style == null:
			bad.append("%s %s has no panel style" % [scene_path, node_path])
		else:
			var sides: Array[float] = [style.content_margin_left, style.content_margin_top,
				style.content_margin_right, style.content_margin_bottom]
			if sides != [14.0, 14.0, 14.0, 14.0]:
				bad.append("%s %s style is %s" % [scene_path, node_path, str(sides)])
		inst.free()
	for style_path: String in STYLE_FILE_CENSUS:
		var style: Variant = load(style_path)
		if not (style is StyleBoxFlat):
			bad.append("%s did not load" % style_path)
			continue
		var flat: StyleBoxFlat = style
		var sides: Array[float] = [flat.content_margin_left, flat.content_margin_top,
			flat.content_margin_right, flat.content_margin_bottom]
		if sides != [14.0, 14.0, 14.0, 14.0]:
			bad.append("%s is %s" % [style_path, str(sides)])
	TestFixtures.check(res, "every census window pads its content 14 px on every side",
		bad.is_empty(), TestFixtures.detail(bad, total, "census entries"))


#F6B item 25: the Portfolio Value title sits 14 px from the widget's top and bottom.
static func _case_portfolio_top(res: Dictionary) -> void:
	var packed: PackedScene = load("res://Scenes/GUI/Finance/Invest/InvestPortfolio.tscn")
	var inst: PanelContainer = packed.instantiate() as PanelContainer
	var style: StyleBoxFlat = inst.get_theme_stylebox(&"panel") as StyleBoxFlat
	var pad: MarginContainer = inst.get_node_or_null(^"Pad") as MarginContainer
	var style_top: float = style.content_margin_top if style != null else -1.0
	var style_bottom: float = style.content_margin_bottom if style != null else -1.0
	var pad_top: int = pad.get_theme_constant(&"margin_top") if pad != null else -1
	var pad_bottom: int = pad.get_theme_constant(&"margin_bottom") if pad != null else -1
	TestFixtures.check(res, "the portfolio widget pads its title 14 px from the top and bottom",
		pad != null and style != null and is_equal_approx(style_top + float(pad_top), 14.0)
			and is_equal_approx(style_bottom + float(pad_bottom), 14.0),
		"style %.1f pad %d top, style %.1f pad %d bottom" % [style_top, pad_top, style_bottom,
			pad_bottom])
	var col: VBoxContainer = inst.get_node_or_null(^"Pad/Col") as VBoxContainer
	var first_child: Node = col.get_child(0) if col != null and col.get_child_count() > 0 else null
	TestFixtures.check(res, "nothing sits above the portfolio title",
		first_child != null and String(first_child.name) == "TitleLabel",
		"got %s" % ("none" if first_child == null else String(first_child.name)))
	inst.free()


static func _bonus(names: Array) -> Array[BonusEntry]:
	var out: Array[BonusEntry] = []
	for name: Variant in names:
		var entry := BonusEntry.new()
		entry.name = str(name)
		out.append(entry)
	return out


static func _merc(uid: int, tradition: String, knowledges: Array, tools: Array) -> MercView:
	var view := MercView.new()
	view.uid = uid
	view.name = "M%d" % uid
	view.level = 5
	view.tradition = tradition
	for name: Variant in knowledges:
		view.knowledges.append(str(name))
	for name: Variant in tools:
		view.tools.append(str(name))
	return view


static func _contract(know: Array, tools: Array, trads: Array) -> ContractView:
	var view := ContractView.new()
	view.entry_id = 1
	view.name = "Sample"
	view.difficulty = 3.0
	view.reward = 500
	view.distance_km = 100
	view.merc_min = 2
	view.merc_max = 4
	view.recommended_knowledges = _bonus(know)
	view.recommended_tools = _bonus(tools)
	view.recommended_traditions = _bonus(trads)
	return view


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

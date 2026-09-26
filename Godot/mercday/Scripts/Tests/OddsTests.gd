class_name OddsTests

#OddsEstimator: the formula mean, the battle model, the mishap product, the clamp and the band.
#Run: godot --headless --path . -- --odds-tests

const FORMULA_EVENT := "Identify the Killer"
const BATTLE_EVENT := "Battle"
const BATTLE_MISHAP := "Tavern Brawl"
const COMPETITION_EVENT := "Competition"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_formula_primary(res)
	_case_battle_strength(res)
	_case_mishap_product(res)
	_case_clamp(res)
	_case_for_contract(res)
	_case_no_mutation(res)
	_case_band(res)
	_case_competition(res)
	_case_formula_over_hundred(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "ODDS")


static func _team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(size):
		var merc: MercenaryData = MercGenerator.generate(i)
		ContractModifiers.set_level(merc, level)
		team.append(merc)
	GuildRoster.set_roster(team)
	return team


static func _uids(team: Array[MercenaryData]) -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in team:
		out.append(merc.merc_uid)
	return out


static func _contract(type_name: String, primary: String, mishaps: Array[String], level: int,
		difficulty: float, max_mercs: int) -> ContractData:
	var contract: ContractData = ContractLibrary.contract_type(type_name)
	if contract == null:
		return null
	contract.assigned_primary_event = primary
	contract.rolled_mishaps.assign(mishaps)
	contract.contract_level = level
	contract.difficulty = difficulty
	contract.max_mercs = max_mercs
	contract.reward_notes = 100
	contract.status = "Draft"
	return contract


#The mean of the team's raw event values, exactly as FormulaEventResolver builds its target.
static func _expected_formula(contract: ContractData, team: Array[MercenaryData]) -> float:
	var event: EventData = ContractLibrary.event(contract.assigned_primary_event)
	var record: Dictionary = ContractModifiers.apply(contract, team)
	var total: float = 0.0
	for merc: MercenaryData in team:
		var value: float = float(OverallSuccess.for_merc(contract, team, merc, event)["value"])
		value += FormulaEventResolver.evaluate(event.success_formula, merc)
		total += value
	ContractModifiers.revert(record)
	return total / float(team.size())


static func _case_formula_primary(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 8)
	for merc: MercenaryData in team:
		merc.stats["base_success_chance"] = 40.0
		merc.stats["investigate"] = 25.0
	var contract: ContractData = _contract("Investigate", FORMULA_EVENT, [], 8, 2.0, 3)
	if contract == null:
		TestFixtures.check(res, "formula_primary", false, "Investigate contract did not load")
		return
	var model: OddsModel = OddsEstimator.prepare(contract, team)
	var got: int = OddsEstimator.odds(model, _uids(team))
	var mean: float = _expected_formula(contract, team)
	var want: int = clampi(int(roundf(clampf(mean / 100.0, 0.0, 1.0)
		* OddsEstimator.band_factor(model, _uids(team)) * 100.0)),
		OddsEstimator.MIN_ODDS, OddsEstimator.MAX_ODDS)
	TestFixtures.check(res, "formula_mean", got == want, "odds %d expected %d from mean %.2f" % [got, want, mean])
	TestFixtures.check(res, "formula_mean_not_zero", mean > 0.0, "mean %.2f" % mean)
	TestFixtures.check(res, "formula_kind", model.events.size() == 1
		and String(model.events[0]["kind"]) == OddsModel.KIND_FORMULA,
		"events %d" % model.events.size())


static func _case_battle_strength(res: Dictionary) -> void:
	var weak: Array[MercenaryData] = _team(3, 2)
	var contract_a: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 3.0, 3)
	var low: int = OddsEstimator.for_contract(contract_a, weak)
	var strong: Array[MercenaryData] = _team(3, 25)
	var contract_b: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 3.0, 3)
	var high: int = OddsEstimator.for_contract(contract_b, strong)
	TestFixtures.check(res, "battle_stronger_team_wins_more", high > low,
		"level 25 team %d, level 2 team %d" % [high, low])
	var model: OddsModel = OddsEstimator.prepare(contract_b, strong)
	TestFixtures.check(res, "battle_kind", model.events.size() == 1
		and String(model.events[0]["kind"]) == OddsModel.KIND_BATTLE, "events %d" % model.events.size())
	var power: Dictionary = model.events[0]["enemy_power"] as Dictionary
	TestFixtures.check(res, "battle_power_per_size", power.size() == 3 and float(power[3]) > float(power[1]),
		"sizes %d" % power.size())


static func _case_mishap_product(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 10)
	var plain: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 3.0, 3)
	var base: int = OddsEstimator.for_contract(plain, team)
	var fights: ContractData = _contract("Military", BATTLE_EVENT, [BATTLE_MISHAP], 10, 3.0, 3)
	var after: int = OddsEstimator.for_contract(fights, team)
	TestFixtures.check(res, "mishap_battle_lowers_odds", after < base,
		"with a battle mishap %d, without %d" % [after, base])
	var quiet: ContractData = _contract("Military", BATTLE_EVENT, [FORMULA_EVENT], 10, 3.0, 3)
	var same: int = OddsEstimator.for_contract(quiet, team)
	TestFixtures.check(res, "mishap_non_battle_ignored", same == base,
		"with a formula mishap %d, without %d" % [same, base])


static func _case_clamp(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(1, 1)
	var hopeless: ContractData = _contract("Military", BATTLE_EVENT, [BATTLE_MISHAP, BATTLE_MISHAP], 40, 5.0, 1)
	var low: int = OddsEstimator.for_contract(hopeless, team)
	TestFixtures.check(res, "clamp_low", low >= OddsEstimator.MIN_ODDS and low <= OddsEstimator.MAX_ODDS,
		"odds %d" % low)
	var elite: Array[MercenaryData] = _team(4, 40)
	var easy: ContractData = _contract("Military", BATTLE_EVENT, [], 1, 0.5, 4)
	var high: int = OddsEstimator.for_contract(easy, elite)
	TestFixtures.check(res, "clamp_high", high <= OddsEstimator.MAX_ODDS and high > low,
		"elite %d hopeless %d" % [high, low])
	var model: OddsModel = OddsEstimator.prepare(easy, elite)
	var none: Array[int] = []
	TestFixtures.check(res, "clamp_empty_team", OddsEstimator.odds(model, none) == OddsEstimator.MIN_ODDS,
		"odds %d" % OddsEstimator.odds(model, none))


static func _case_for_contract(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 12)
	var contract: ContractData = _contract("Military", BATTLE_EVENT, [BATTLE_MISHAP], 12, 2.5, 3)
	var model: OddsModel = OddsEstimator.prepare(contract, team)
	var split: int = OddsEstimator.odds(model, _uids(team))
	var whole: int = OddsEstimator.for_contract(contract, team)
	TestFixtures.check(res, "prepare_matches_for_contract", split == whole,
		"prepare %d for_contract %d" % [split, whole])
	var pair: Array[int] = [team[0].merc_uid, team[1].merc_uid]
	var two: int = OddsEstimator.odds(model, pair)
	TestFixtures.check(res, "smaller_team_lower_odds", two <= split, "two %d three %d" % [two, split])


static func _case_no_mutation(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 9)
	var before: Array[Dictionary] = []
	for merc: MercenaryData in team:
		before.append(merc.stats.duplicate(true))
	var contract: ContractData = _contract("Military", BATTLE_EVENT, [BATTLE_MISHAP], 9, 3.0, 3)
	OddsEstimator.for_contract(contract, team)
	var drift: Array[String] = []
	for index: int in range(team.size()):
		var merc: MercenaryData = team[index]
		var was: Dictionary = before[index]
		for key: Variant in was:
			if typeof(was[key]) != TYPE_FLOAT and typeof(was[key]) != TYPE_INT:
				continue
			if absf(float(merc.stats.get(key, 0.0)) - float(was[key])) >= 0.0001:
				drift.append("%s %s" % [merc.merc_name, str(key)])
	TestFixtures.check(res, "no_stat_changed", drift.is_empty(), TestFixtures.detail(drift, team.size(), "merc"))
	var flags: bool = true
	for merc: MercenaryData in team:
		if merc.on_contract:
			flags = false
	TestFixtures.check(res, "no_contract_flag_set", flags, "a merc was marked on contract")


static func _case_band(res: Dictionary) -> void:
	var contract: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 0.5, 4)
	TestFixtures.check(res, "band_floor_low_difficulty", absf(OddsEstimator.band_floor(contract) - 7.5) < 0.001,
		"floor %.3f" % OddsEstimator.band_floor(contract))
	contract.difficulty = 5.0
	TestFixtures.check(res, "band_floor_high_difficulty", absf(OddsEstimator.band_floor(contract) - 10.0) < 0.001,
		"floor %.3f" % OddsEstimator.band_floor(contract))
	contract.contract_level = 0
	TestFixtures.check(res, "band_floor_unlevelled", OddsEstimator.band_floor(contract) == 0.0,
		"floor %.3f" % OddsEstimator.band_floor(contract))
	var under: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 5.0, 3)
	var team: Array[MercenaryData] = _team(3, 5)
	var model: OddsModel = OddsEstimator.prepare(under, team)
	var factor: float = OddsEstimator.band_factor(model, _uids(team))
	TestFixtures.check(res, "band_factor_under", absf(factor - 0.25) < 0.001, "factor %.4f" % factor)
	var at_band: Array[MercenaryData] = _team(3, 10)
	var model_b: OddsModel = OddsEstimator.prepare(under, at_band)
	TestFixtures.check(res, "band_factor_at", OddsEstimator.band_factor(model_b, _uids(at_band)) == 1.0,
		"factor %.4f" % OddsEstimator.band_factor(model_b, _uids(at_band)))


static func _case_competition(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 10)
	var contract: ContractData = _contract("Entertain", COMPETITION_EVENT, [], 10, 2.0, 3)
	if contract == null:
		TestFixtures.check(res, "competition_odds", false, "Entertain contract did not load")
		return
	var model: OddsModel = OddsEstimator.prepare(contract, team)
	TestFixtures.check(res, "competition_kind", model.events.size() == 1
		and String(model.events[0]["kind"]) == OddsModel.KIND_COMPETITION,
		"kind %s" % String(model.events[0]["kind"]) if not model.events.is_empty() else "no events")
	var got: int = OddsEstimator.odds(model, _uids(team))
	TestFixtures.check(res, "competition_odds", got >= OddsEstimator.MIN_ODDS and got <= OddsEstimator.MAX_ODDS,
		"odds %d" % got)
	var rows: int = 0
	for kind: String in CompetitionResolver.CHECK_KINDS:
		if ContractLibrary.event(CompetitionResolver.ROW_PREFIX + kind) != null:
			rows += 1
	var defs: Array[Dictionary] = OddsEstimator.competition_defs(
		ContractLibrary.event(COMPETITION_EVENT))
	TestFixtures.check(res, "competition_defs_count", defs.size() == rows,
		"defs %d for %d rows" % [defs.size(), rows])
	var marked: int = 0
	for check_def: Dictionary in defs:
		if String(check_def.get("formula", "")).strip_edges() == COMPETITION_EVENT:
			marked += 1
	TestFixtures.check(res, "competition_defs_formula", marked == 0,
		"%d defs still carry the marker formula" % marked)
	var primary: EventData = ContractLibrary.event(COMPETITION_EVENT)
	var lead: String = primary.knowledges[0] if not primary.knowledges.is_empty() else ""
	var first_ok: int = 0
	for check_def: Dictionary in defs:
		var known: Array = check_def.get("knowledges", [])
		if lead == "" or (not known.is_empty() and String(known[0]) == lead):
			first_ok += 1
	TestFixtures.check(res, "competition_defs_knowledges", first_ok == defs.size(),
		"%d of %d defs lead with the primary knowledge" % [first_ok, defs.size()])
	var entry: Dictionary = model.events[0]
	var expected: Dictionary = entry.get("expected", {})
	var wins: Dictionary = entry.get("wins", {})
	var positive: int = 0
	var in_range: int = 0
	for uid: int in _uids(team):
		if float(expected.get(uid, 0.0)) > 0.0:
			positive += 1
		var win: float = float(wins.get(uid, -1.0))
		if win >= 0.0 and win <= 1.0:
			in_range += 1
	TestFixtures.check(res, "competition_expected_positive", positive == team.size(),
		"%d of %d mercs expect successes" % [positive, team.size()])
	TestFixtures.check(res, "competition_wins_range", in_range == team.size(),
		"%d of %d win values inside 0 to 1" % [in_range, team.size()])


#A merc valued above 100 still lifts the team mean; only the mean is clamped, as the resolver does it.
static func _case_formula_over_hundred(res: Dictionary) -> void:
	var stub: Dictionary = {"values": {2: {1: 150.0, 2: 50.0}}}
	var stub_uids: Array[int] = [1, 2]
	var chance: float = OddsEstimator._formula_chance(stub, stub_uids, 2)
	TestFixtures.check(res, "formula_mean_clamped_once", absf(chance - 1.0) < 0.0001,
		"150 and 50 read %.4f, expected 1.0000" % chance)
	var team: Array[MercenaryData] = _team(2, 8)
	team[0].stats["base_success_chance"] = 120.0
	team[0].stats["investigate"] = 40.0
	team[1].stats["base_success_chance"] = 20.0
	team[1].stats["investigate"] = 10.0
	var contract: ContractData = _contract("Investigate", FORMULA_EVENT, [], 8, 2.0, 2)
	if contract == null:
		TestFixtures.check(res, "formula_value_unclamped", false, "Investigate contract did not load")
		return
	var model: OddsModel = OddsEstimator.prepare(contract, team)
	var values: Dictionary = (model.events[0]["values"] as Dictionary).get(2, {}) as Dictionary
	var top: float = float(values.get(team[0].merc_uid, 0.0))
	TestFixtures.check(res, "formula_value_unclamped", top > 100.0, "top merc value %.2f" % top)

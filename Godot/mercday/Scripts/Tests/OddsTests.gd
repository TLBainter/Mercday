class_name OddsTests

#OddsEstimator: the formula mean, the battle model, the mishap product, the clamp and the band.
#Run: godot --headless --path . -- --odds-tests

const FORMULA_EVENT := "Identify the Killer"
const BATTLE_EVENT := "Battle"
const BATTLE_MISHAP := "Tavern Brawl"
const COMPETITION_EVENT := "Competition"
const LORE := "Odds Test Lore"
const LORE_PCT := 20.0
const CHECK_CONTRACT := "Cat Stuck in Tree!"
const BANDIT_EVENT := "Fight Bandits"
const CHASE_EVENT := "Chase"
const TIMELINE_O1 := "a=check:Get Cat from Tree fail ; b=check:Get Cat from Tree fail"
const TIMELINE_O2 := "a=check:Get Cat from Tree ; b=check:Get Cat from Tree if a.success fail ; c=check:Get Cat from Tree if a.failure fail ; d=check:Get Cat from Tree fail"
const TIMELINE_O3 := "a=check:Get Cat from Tree role=Leader fail ; b=check:Get Cat from Tree fail"
const TIMELINE_BROKEN := "a=event:Fight Bandits"


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
	_case_majority(res)
	_case_from_scratch(res)
	_case_net_moves(res)
	_case_no_ceiling(res)
	_case_flagged_mishap(res)
	_case_check_math(res)
	_case_check_contract(res)
	_case_check_difficulty(res)
	_case_counter_factor(res)
	_case_chase(res)
	_case_timeline(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "ODDS")


static func _team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = TestFixtures.generated_team(size, level)
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
	var positive: int = 0
	for uid: int in _uids(team):
		if float(expected.get(uid, 0.0)) > 0.0:
			positive += 1
	TestFixtures.check(res, "competition_expected_positive", positive == team.size(),
		"%d of %d mercs expect successes" % [positive, team.size()])


#A merc valued above 100 still lifts the team mean; only the mean is clamped, as the resolver does it.
static func _case_formula_over_hundred(res: Dictionary) -> void:
	var stub: Dictionary = {1: 150.0, 2: 50.0}
	var stub_uids: Array[int] = [1, 2]
	var chance: float = OddsEstimator._formula_chance(stub, stub_uids)
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
	var values: Dictionary = OddsEstimator.formula_values(model, model.events[0], _uids(team), -1)
	var top: float = float(values.get(team[0].merc_uid, 0.0))
	TestFixtures.check(res, "formula_value_unclamped", top > 100.0, "top merc value %.2f" % top)


static func _lore(contract: ContractData, merc: MercenaryData) -> void:
	contract.knowledge_boosts = contract.knowledge_boosts.duplicate()
	contract.knowledge_boosts[LORE] = LORE_PCT
	if merc != null:
		merc.knowledges.append(ContractFixtures.utility(LORE))


static func _case_majority(res: Dictionary) -> void:
	var three: float = OddsEstimator.majority(0.5, 3)
	var four: float = OddsEstimator.majority(0.5, 4)
	var mean: float = OddsEstimator.rounds_chance(0.5)
	TestFixtures.check(res, "estimate: majority(3) at w 0.5 is 0.5", absf(three - 0.5) < 0.000001, "%.6f" % three)
	TestFixtures.check(res, "estimate: majority(4) at w 0.5 is 0.3125", absf(four - 0.3125) < 0.000001,
		"%.6f" % four)
	TestFixtures.check(res, "estimate: rounds average at w 0.5", absf(mean - (0.5 + 0.3125 + 0.5) / 3.0) < 0.000001,
		"%.6f" % mean)


#The formula chance rebuilt from MatchScore.merc_net and a team apply, without the model's caches.
static func _scratch_formula(contract: ContractData, model: OddsModel, team: Array[MercenaryData],
		leader: MercenaryData) -> float:
	var event: EventData = ContractLibrary.event(contract.assigned_primary_event)
	var nets: Array[float] = []
	for merc: MercenaryData in team:
		nets.append(MatchScore.merc_net(contract, team, merc, leader))
	var record: Dictionary = ContractModifiers.apply(contract, team)
	var total: float = 0.0
	for index: int in range(team.size()):
		var merc: MercenaryData = team[index]
		total += maxf(0.0, OverallSuccess.base(merc) * (1.0 + nets[index] / 100.0))
		total += FormulaEventResolver.evaluate(event.success_formula, merc)
	ContractModifiers.revert(record)
	var uids: Array[int] = _uids(team)
	return clampf(clampf(total / float(team.size()) / 100.0, 0.0, 1.0) * OddsEstimator.band_factor(model, uids),
		0.0, 1.0)


static func _case_from_scratch(res: Dictionary) -> void:
	var roster: Array[MercenaryData] = _team(5, 8)
	for index: int in range(roster.size()):
		roster[index].stats["base_success_chance"] = 30.0 + 5.0 * float(index)
		roster[index].stats["investigate"] = 20.0
	var contract: ContractData = _contract("Investigate", FORMULA_EVENT, [], 8, 2.0, 3)
	if contract == null:
		TestFixtures.check(res, "estimate: chance matches a from-scratch build for three teams", false,
			"Investigate contract did not load")
		return
	_lore(contract, roster[2])
	var model: OddsModel = OddsEstimator.prepare(contract, roster)
	var teams: Array = [[roster[0], roster[2]], [roster[1], roster[3], roster[4]], [roster[0], roster[1], roster[2]]]
	var leaders: Array = [roster[2], roster[3], roster[2]]
	var bad: Array[String] = []
	for index: int in range(teams.size()):
		var team: Array[MercenaryData] = []
		team.assign(teams[index])
		var leader: MercenaryData = leaders[index]
		var got: float = OddsEstimator.chance(model, _uids(team), leader.merc_uid)
		var want: float = _scratch_formula(contract, model, team, leader)
		if absf(got - want) >= 0.000001:
			bad.append("team %d got %.6f want %.6f" % [index, got, want])
	TestFixtures.check(res, "estimate: chance matches a from-scratch build for three teams", bad.is_empty(),
		", ".join(bad))


#A lent leader row raises the other member's net inside one model, so the rolled rival and enemy stay fixed.
static func _case_net_moves(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(2, 10)
	var battle: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 2.0, 2)
	_lore(battle, team[1])
	var model: OddsModel = OddsEstimator.prepare(battle, team)
	var plain: float = OddsEstimator.chance(model, _uids(team), -1)
	var shared: float = OddsEstimator.chance(model, _uids(team), team[1].merc_uid)
	TestFixtures.check(res, "estimate: battle p rises when a member gains a matching row", shared > plain,
		"with the row %.6f, without %.6f" % [shared, plain])
	var pair: Array[MercenaryData] = _team(2, 10)
	var show: ContractData = _contract("Entertain", COMPETITION_EVENT, [], 10, 2.0, 2)
	if show == null:
		TestFixtures.check(res, "estimate: competition p moves with the champion's delta", false,
			"Entertain contract did not load")
		return
	var first: OddsModel = OddsEstimator.prepare(show, pair)
	var expected: Dictionary = first.events[0].get("expected", {})
	var champ: int = 0 if float(expected.get(pair[0].merc_uid, 0.0)) >= float(expected.get(pair[1].merc_uid, 0.0)) else 1
	var other: MercenaryData = pair[1 - champ]
	_lore(show, other)
	var second: OddsModel = OddsEstimator.prepare(show, pair)
	var alone: float = OddsEstimator.chance(second, _uids(pair), -1)
	var lifted: float = OddsEstimator.chance(second, _uids(pair), other.merc_uid)
	TestFixtures.check(res, "estimate: competition p moves with the champion's delta", lifted > alone,
		"with the lent row %.6f, without %.6f" % [lifted, alone])


static func _case_no_ceiling(res: Dictionary) -> void:
	var good: Array[MercenaryData] = _team(1, 40)
	var easy: ContractData = _contract("Military", BATTLE_EVENT, [], 1, 0.5, 1)
	var low_model: OddsModel = OddsEstimator.prepare(easy, good)
	var low_odds: int = OddsEstimator.odds(low_model, _uids(good))
	var low: float = OddsEstimator.chance(low_model, _uids(good))
	var better: Array[MercenaryData] = _team(1, 60)
	var high_model: OddsModel = OddsEstimator.prepare(easy, better)
	var high: float = OddsEstimator.chance(high_model, _uids(better))
	TestFixtures.check(res, "estimate: a team shown at 99 can be beaten by a higher chance",
		low_odds == OddsEstimator.MAX_ODDS and high > low and high <= 1.0,
		"odds %d, chance %.6f against %.6f" % [low_odds, low, high])


static func _case_flagged_mishap(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3, 10)
	for merc: MercenaryData in team:
		merc.stats["base_success_chance"] = 40.0
		merc.stats["investigate"] = 25.0
	var plain: ContractData = _contract("Military", BATTLE_EVENT, [], 10, 3.0, 3)
	var base: float = OddsEstimator.chance(OddsEstimator.prepare(plain, team), _uids(team))
	var flagged: ContractData = _contract("Military", BATTLE_EVENT, [FORMULA_EVENT], 10, 3.0, 3)
	var model: OddsModel = OddsEstimator.prepare(flagged, team)
	var unflagged: float = OddsEstimator.chance(model, _uids(team))
	#ContractLibrary hands out a fresh copy per call and no event row is flagged yet, so the flag goes on the entry.
	model.events[0]["fail_ends"] = true
	var after: float = OddsEstimator.chance(model, _uids(team))
	TestFixtures.check(res, "estimate: a flagged non-battle mishap multiplies the chance",
		after < base and absf(unflagged - base) < 0.000001,
		"flagged %.6f, unflagged %.6f, plain %.6f" % [after, unflagged, base])


static func _dist(dice: int, crit: float, pmf: Array[float]) -> Dictionary:
	return {"dice": dice, "threshold": 50.0, "crit": crit, "pmf": pmf}


static func _near(got: float, want: float) -> bool:
	return absf(got - want) < 0.000001


static func _case_check_math(res: Dictionary) -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	var tail: Dictionary = _dist(2, 0.1, [0.25, 0.5, 0.25])
	var k1: float = OddsEstimator.check_pass(tail, 1)
	var k2: float = OddsEstimator.check_pass(tail, 2)
	var k3: float = OddsEstimator.check_pass(tail, 3)
	TestFixtures.check(res, "check_pass_tail", _near(k1, 0.75) and _near(k2, 0.25) and _near(k3, 0.1),
		"k1 %.6f, k2 %.6f, k3 %.6f" % [k1, k2, k3])
	var full: Dictionary = _dist(2, 0.0, [0.75, 0.0, 0.25])
	var half: Dictionary = _dist(2, 0.0, [0.9, 0.0, 0.1])
	var unopposed: Array[float] = []
	var retry: float = OddsEstimator.check_chance(full, half, 1, 1.0, unopposed)
	TestFixtures.check(res, "check_chance_retry", _near(retry, 0.325), "chance %.6f, want 0.325" % retry)
	var rival: Array[float] = [0.5, 0.5]
	var opposed: float = OddsEstimator.check_chance(full, half, 0, 1.0, rival)
	TestFixtures.check(res, "check_chance_opposed", _near(opposed, 0.25), "chance %.6f, want 0.25" % opposed)
	var falling: Dictionary = _dist(2, 0.05, [0.5, 0.4, 0.1])
	var low: float = OddsEstimator.check_chance(tail, falling, 0, 0.5, unopposed)
	var mid: float = OddsEstimator.check_chance(tail, falling, 0, 1.0, unopposed)
	var high: float = OddsEstimator.check_chance(tail, falling, 0, 2.0, unopposed)
	TestFixtures.check(res, "check_monotone", _near(low, 0.75) and _near(mid, 0.25) and _near(high, 0.1)
		and low > mid and mid > high, "x0.5 %.6f, x1 %.6f, x2 %.6f" % [low, mid, high])
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


static func _case_check_contract(res: Dictionary) -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	var cat: ContractData = ContractGenerator.generate_named(CHECK_CONTRACT)
	if cat == null:
		for label: String in ["check_prepare_kind", "check_in_range", "check_cache"]:
			TestFixtures.check(res, label, false, "%s did not generate" % CHECK_CONTRACT)
		return
	cat.rolled_mishaps.clear()
	var team: Array[MercenaryData] = [TestFixtures.fixed_merc("Odds Check A", {"base_success_chance": 50.0}),
		TestFixtures.fixed_merc("Odds Check B", {"base_success_chance": 50.0})]
	var model: OddsModel = OddsEstimator.prepare(cat, team)
	var entry: Dictionary = model.events.back() if not model.events.is_empty() else {}
	TestFixtures.check(res, "check_prepare_kind", String(entry.get("kind", "")) == OddsModel.KIND_CHECK,
		"primary %s kind %s" % [cat.assigned_primary_event, String(entry.get("kind", ""))])
	var uids: Array[int] = _uids(team)
	var first: float = OddsEstimator.chance(model, uids)
	TestFixtures.check(res, "check_in_range", first > 0.0 and first < 1.0, "chance %.6f" % first)
	var cache: Dictionary = entry.get("check_cache", {}) as Dictionary
	var size: int = cache.size()
	var second: float = OddsEstimator.chance(model, uids)
	TestFixtures.check(res, "check_cache", size >= 1 and cache.size() == size and _near(second, first),
		"cache %d then %d, chance %.6f then %.6f" % [size, cache.size(), first, second])
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


#The same team on the same Checks.tsv primary gets better odds at fewer stars (#720).
static func _case_check_difficulty(res: Dictionary) -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	var label: String = "#720 check odds rise as the difficulty falls"
	var cat: ContractData = ContractGenerator.generate_named(CHECK_CONTRACT)
	if cat == null:
		TestFixtures.check(res, label, false, "%s did not generate" % CHECK_CONTRACT)
		return
	cat.rolled_mishaps.clear()
	var chances: Array[float] = []
	for stars: float in [5.0, 3.0, 0.5]:
		cat.difficulty = stars
		var team: Array[MercenaryData] = [TestFixtures.fixed_merc("Odds Grade A", {"base_success_chance": 10.0}),
			TestFixtures.fixed_merc("Odds Grade B", {"base_success_chance": 10.0})]
		chances.append(OddsEstimator.chance(OddsEstimator.prepare(cat, team), _uids(team)))
	TestFixtures.check(res, label, chances[0] < chances[1] and chances[1] < chances[2],
		"5.0 / 3.0 / 0.5 stars: %.6f / %.6f / %.6f" % [chances[0], chances[1], chances[2]])
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


#An event style contract built in code: level 5, difficulty 2.0, so level 5 mercs sit above the band floor.
static func _event_contract(primary: String, cell: String, max_mercs: int) -> ContractData:
	var contract := ContractData.new()
	contract.style = "event"
	contract.completion = "event:" + primary
	contract.assigned_primary_event = primary
	contract.event_config = cell
	contract.contract_level = 5
	contract.difficulty = 2.0
	contract.max_mercs = max_mercs
	contract.status = "Draft"
	return contract


static func _fixed_team(prefix: String, count: int, extras: Dictionary) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for index: int in range(count):
		team.append(TestFixtures.fixed_merc("%s %d" % [prefix, index + 1], extras))
	return team


#The enemy count _enemy_power prices: its power divided by one enemy's power at the band centre level.
static func _priced_count(contract: ContractData, team: Array[MercenaryData], event: EventData) -> float:
	var model := OddsModel.new()
	model.contract = contract
	var bounds: Array[float] = OpponentGenerator.level_band_bounds(contract.difficulty)
	var level: int = clampi(int(roundf(float(contract.contract_level) * bounds[1])), 1, OpponentGenerator.LEVEL_CAP)
	return OddsEstimator._enemy_power(model, team, event) / pow(float(level) + 1.0, OddsEstimator.ALPHA)


static func _case_counter_factor(res: Dictionary) -> void:
	var labels: Array[String] = ["odds: counter factor fight bandits 2", "odds: counter factor blank",
		"odds: counter parity with builder"]
	var event: EventData = ContractLibrary.event(BANDIT_EVENT)
	if event == null:
		for label: String in labels:
			TestFixtures.check(res, label, false, "%s did not load" % BANDIT_EVENT)
		return
	var team: Array[MercenaryData] = _fixed_team("Odds Bandit", 3, {})
	var doubled: ContractData = _event_contract(BANDIT_EVENT, "bandits=2", 3)
	var plain: ContractData = _event_contract(BANDIT_EVENT, "", 3)
	var twice: float = _priced_count(doubled, team, event)
	var once: float = _priced_count(plain, team, event)
	TestFixtures.check(res, labels[0], _near(twice, 6.0), "count %.3f, want 6" % twice)
	TestFixtures.check(res, labels[1], _near(once, 3.0), "count %.3f, want 3" % once)
	var run: ContractRun = ContractRun.make(doubled, team, Callable())
	var built: Array[MercenaryData] = EnemyTeamBuilder.build(event, run, 0)
	TestFixtures.check(res, labels[2], _near(twice, 6.0) and built.size() == 6,
		"odds count %.3f, builder size %d" % [twice, built.size()])


#Every chase case on the level 5 fixture; target speeds come from generated mercs.
static func _chase_odds(cell: String, team: Array[MercenaryData]) -> float:
	var model: OddsModel = OddsEstimator.prepare(_event_contract(CHASE_EVENT, cell, team.size()), team)
	return OddsEstimator.chance(model, _uids(team))


static func _case_chase(res: Dictionary) -> void:
	var labels: Array[String] = ["odds: chase kind", "odds: chase in range", "odds: chase stable", "odds: chase flip",
		"odds: chase no push_error path"]
	if ContractLibrary.event(CHASE_EVENT) == null:
		for label: String in labels:
			TestFixtures.check(res, label, false, "%s did not load" % CHASE_EVENT)
		return
	var team: Array[MercenaryData] = _fixed_team("Odds Chase", 2, {})
	var model: OddsModel = OddsEstimator.prepare(_event_contract(CHASE_EVENT, "", 2), team)
	var entry: Dictionary = model.events.back() if not model.events.is_empty() else {}
	var samples: int = (entry.get("target_speeds", []) as Array).size()
	TestFixtures.check(res, labels[0], String(entry.get("kind", "")) == OddsModel.KIND_CHASE
		and samples == OddsEstimator.CHASE_SAMPLES, "kind %s, samples %d" % [String(entry.get("kind", "")), samples])
	var uids: Array[int] = _uids(team)
	var first: float = OddsEstimator.chance(model, uids)
	TestFixtures.check(res, labels[1], first > 0.0 and first < 1.0, "chance %.6f" % first)
	var second: float = OddsEstimator.chance(model, uids)
	TestFixtures.check(res, labels[2], _near(first, second), "chance %.6f then %.6f" % [first, second])
	var fast: Array[MercenaryData] = _fixed_team("Odds Fast", 2, {"speed": 40.0, "pace": 0})
	var slow: Array[MercenaryData] = _fixed_team("Odds Slow", 2, {"speed": -40.0, "pace": 0})
	var top: float = 1.0 - OddsEstimator.P_FLOOR
	var caught: float = _chase_odds("", fast)
	var escaped: float = _chase_odds("chasing=target", fast)
	var lost: float = _chase_odds("", slow)
	TestFixtures.check(res, labels[3], _near(caught, top) and _near(escaped, top)
		and _near(lost, OddsEstimator.P_FLOOR), "chase %.6f, flee %.6f, slow %.6f" % [caught, escaped, lost])
	TestFixtures.check(res, labels[4], not entry.has("eval") and entry.has("target_speeds"),
		"keys %s" % str(entry.keys()))


#A Style timeline contract built in code: level 5, difficulty 2.0, the cell as its Completion.
static func _timeline_contract(cell: String) -> ContractData:
	var contract := ContractData.new()
	contract.contract_name = "OT timeline"
	contract.style = "timeline"
	contract.completion = cell
	contract.assigned_primary_event = "timeline:OT timeline"
	contract.contract_level = 5
	contract.difficulty = 2.0
	contract.status = "Draft"
	return contract


static func _case_timeline(res: Dictionary) -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	var team: Array[MercenaryData] = _team(3, 5)
	var uids: Array[int] = _uids(team)
	var model: OddsModel = OddsEstimator.prepare(_timeline_contract(TIMELINE_O1), team)
	var entry: Dictionary = model.events.back() if not model.events.is_empty() else {}
	var size: int = clampi(uids.size(), 1, model.max_team)
	var subs: Array = entry.get("steps", []) as Array
	var p0: float = OddsEstimator._chance(model, subs[0], uids, size, -1) if subs.size() == 2 else -1.0
	var p1: float = OddsEstimator._chance(model, subs[1], uids, size, -1) if subs.size() == 2 else -1.0
	var tl: float = OddsEstimator._chance(model, entry, uids, size, -1)
	TestFixtures.check(res, "odds_timeline_product", String(entry.get("kind", "")) == OddsModel.KIND_TIMELINE
		and p0 > 0.0 and p0 < 1.0 and _near(tl, p0 * p1), "kind %s, p0 %.6f, p1 %.6f, timeline %.6f"
		% [String(entry.get("kind", "")), p0, p1, tl])
	var again: float = OddsEstimator._chance(model, entry, uids, size, -1)
	var cached: int = (entry.get("timeline_cache", {}) as Dictionary).size()
	TestFixtures.check(res, "odds_timeline_cache", again == tl and cached == 1,
		"chance %.6f then %.6f, cache %d" % [tl, again, cached])
	var branch: OddsModel = OddsEstimator.prepare(_timeline_contract(TIMELINE_O2), team)
	var top: Dictionary = branch.events.back() if not branch.events.is_empty() else {}
	var steps: Array = top.get("steps", []) as Array
	var p: Array[float] = []
	for sub: Dictionary in steps:
		p.append(OddsEstimator._chance(branch, sub, uids, size, -1))
	var whole: float = OddsEstimator._chance(branch, top, uids, size, -1)
	var want: float = p[0] * p[1] * p[3] + (1.0 - p[0]) * p[2] * p[3] if p.size() == 4 else -1.0
	TestFixtures.check(res, "odds_timeline_branch", p.size() == 4 and p[0] > 0.0 and p[0] < 1.0
		and _near(whole, want), "steps %d, timeline %.6f, want %.6f" % [p.size(), whole, want])
	var probs: Array[float] = [0.9, 0.5, 0.3, 0.7]
	var walked: float = OddsEstimator._walk(TimelineGrammar.parse(TIMELINE_O2), probs, 0, {})
	TestFixtures.check(res, "odds_timeline_walk_branch", _near(walked, 0.336), "walk %.6f, want 0.336" % walked)
	var pair: Array[float] = [0.6, 0.8]
	var stopped: float = OddsEstimator._walk(TimelineGrammar.parse(TIMELINE_O1), pair, 0, {})
	TestFixtures.check(res, "odds_timeline_walk_stop", _near(stopped, 0.48), "walk %.6f, want 0.48" % stopped)
	_case_timeline_leader(res)
	var broken: OddsModel = OddsEstimator.prepare(_timeline_contract(TIMELINE_BROKEN), team)
	var bad: Dictionary = broken.events.back() if not broken.events.is_empty() else {}
	var zero: float = OddsEstimator.chance(broken, uids)
	TestFixtures.check(res, "odds_timeline_broken", String(bad.get("kind", "")) == OddsModel.KIND_MISSING
		and zero == 0.0, "kind %s, chance %.6f" % [String(bad.get("kind", "")), zero])
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


#A Leader step rolls on the leader even when a better suited member stands beside them.
static func _case_timeline_leader(res: Dictionary) -> void:
	var team: Array[MercenaryData] = [
		TestFixtures.fixed_merc("OT 1", {"dexterity": 6, "wile": 6, "base_success_chance": 50.0}),
		TestFixtures.fixed_merc("OT 2", {"dexterity": 4, "wile": 4, "base_success_chance": 50.0}),
		TestFixtures.fixed_merc("OT 3", {"base_success_chance": 50.0})]
	GuildRoster.set_roster(team)
	var uids: Array[int] = _uids(team)
	var model: OddsModel = OddsEstimator.prepare(_timeline_contract(TIMELINE_O3), team)
	var entry: Dictionary = model.events.back() if not model.events.is_empty() else {}
	var subs: Array = entry.get("steps", []) as Array
	if subs.size() != 2:
		TestFixtures.check(res, "odds_timeline_leader", false, "steps %d, kind %s"
			% [subs.size(), String(entry.get("kind", ""))])
		return
	var size: int = clampi(uids.size(), 1, model.max_team)
	var expected: Dictionary = (subs[0] as Dictionary).get("expected", {}) as Dictionary
	var low: int = uids[0]
	for uid: int in uids:
		if float(expected.get(uid, 0.0)) < float(expected.get(low, 0.0)):
			low = uid
	var only: Array[int] = [low]
	var p_low: float = OddsEstimator._check_chance(model, subs[0], only, size, low)
	var p_best: float = OddsEstimator._check_chance(model, subs[0], uids, size, -1)
	var p1: float = OddsEstimator._chance(model, subs[1], uids, size, low)
	var tl: float = OddsEstimator._chance(model, entry, uids, size, low)
	TestFixtures.check(res, "odds_timeline_leader", low == team[2].merc_uid and not is_equal_approx(p_low, p_best)
		and _near(tl, p_low * p1), "leader %d, low %.6f, best %.6f, step b %.6f, timeline %.6f"
		% [low, p_low, p_best, p1, tl])

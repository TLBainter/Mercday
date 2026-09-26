class_name OddsEstimator

#Reads a contract's chance of success without rolling it: the primary event's odds times every
#battle mishap the crew has to survive first. prepare() does the work once, odds() is arithmetic.
#It never advances the clock, never makes a check and never leaves a stat changed.

const ALPHA := 1.5
const BETA := 2.0
const MIN_ODDS := 1
const MAX_ODDS := 99
const P_FLOOR := 0.05
const P_CEILING := 0.95
const DICE_SAMPLES := 16
const BAND_EXPONENT := 2.0


#MercenaryData exports nothing, so duplicate() returns a blank merc; the overlay goes on the roster
#itself and every dictionary it can write is snapshotted first and put back verbatim afterwards.
const SAVED_FIELDS: Array[String] = ["stats", "stat_bonuses", "stat_flat_bonuses", "stat_multipliers",
	"stats_baseline", "odds_bonuses", "circumstance_additional_bonus"]


#Per-merc and per-event numbers for one contract and one roster; the campaign mercs are never touched.
static func prepare(contract: ContractData, mercs: Array[MercenaryData]) -> OddsModel:
	var model := OddsModel.new()
	model.contract = contract
	if contract == null:
		return model
	var live: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead:
			continue
		live.append(merc)
		model.uids.append(merc.merc_uid)
		model.levels[merc.merc_uid] = float(ExperienceSystem.current_level(merc))
	if live.is_empty():
		return model
	var cap: int = contract.max_mercs if contract.max_mercs > 0 else live.size()
	model.max_team = maxi(1, mini(cap, live.size()))
	model.band_lo = band_floor(contract)
	var saved: Array[Dictionary] = _snapshot(live)
	var record: Dictionary = ContractModifiers.apply(contract, live)
	for index: int in range(contract.rolled_mishaps.size()):
		model.events.append(_event_entry(model, live, contract.rolled_mishaps[index], false))
	model.events.append(_event_entry(model, live, contract.assigned_primary_event, true))
	ContractModifiers.revert(record)
	_restore(live, saved)
	return model


static func _snapshot(team: Array[MercenaryData]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for merc: MercenaryData in team:
		var row: Dictionary = {}
		for field: String in SAVED_FIELDS:
			row[field] = (merc.get(field) as Dictionary).duplicate(true)
		out.append(row)
	return out


static func _restore(team: Array[MercenaryData], saved: Array[Dictionary]) -> void:
	for index: int in range(mini(team.size(), saved.size())):
		var row: Dictionary = saved[index]
		for field: String in SAVED_FIELDS:
			team[index].set(field, (row[field] as Dictionary).duplicate(true))


#1 to 99. The primary decides the verdict; a lost battle mishap is read as losing the crew.
static func odds(model: OddsModel, team_uids: Array[int]) -> int:
	if model == null or model.contract == null or team_uids.is_empty():
		return MIN_ODDS
	var size: int = clampi(team_uids.size(), 1, model.max_team)
	var chance: float = 0.0
	var survived: float = 1.0
	for entry: Dictionary in model.events:
		var p: float = _chance(model, entry, team_uids, size)
		if bool(entry["primary"]):
			chance = p
		elif String(entry["kind"]) == OddsModel.KIND_BATTLE:
			survived *= p
	var total: float = chance * survived * band_factor(model, team_uids)
	return clampi(int(roundf(total * 100.0)), MIN_ODDS, MAX_ODDS)


static func for_contract(contract: ContractData, team: Array[MercenaryData]) -> int:
	var model: OddsModel = prepare(contract, team)
	var uids: Array[int] = []
	for merc: MercenaryData in team:
		if merc != null and not merc.is_dead:
			uids.append(merc.merc_uid)
	return odds(model, uids)


#The recommended band floor of 11.4; 0 when the contract carries no level.
static func band_floor(contract: ContractData) -> float:
	if contract == null or contract.contract_level <= 0:
		return 0.0
	var t: float = clampf((contract.difficulty - 0.5) / 4.5, 0.0, 1.0)
	return float(contract.contract_level) * (0.75 + 0.25 * t)


#1.0 once the team is at the band floor, falling off as the square of how far under it sits.
static func band_factor(model: OddsModel, team_uids: Array[int]) -> float:
	if model == null or model.band_lo <= 0.0 or team_uids.is_empty():
		return 1.0
	var total: float = 0.0
	for uid: int in team_uids:
		total += model.level_of(uid)
	var average: float = total / float(team_uids.size())
	if average >= model.band_lo:
		return 1.0
	return pow(average / model.band_lo, BAND_EXPONENT)


static func _chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int) -> float:
	var kind: String = String(entry["kind"])
	if kind == OddsModel.KIND_BATTLE:
		return _battle_chance(model, entry, team_uids, size)
	if kind == OddsModel.KIND_FORMULA:
		return _formula_chance(entry, team_uids, size)
	if kind == OddsModel.KIND_COMPETITION:
		return _competition_chance(entry, team_uids)
	return 0.0


static func _battle_chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int) -> float:
	var enemy: float = float((entry["enemy_power"] as Dictionary).get(size, 0.0))
	if enemy <= 0.0:
		return P_CEILING
	var power: float = 0.0
	for uid: int in team_uids:
		power += pow(model.level_of(uid) + 1.0, ALPHA)
	if power <= 0.0:
		return P_FLOOR
	var ratio: float = pow(power / enemy, BETA)
	return clampf(ratio / (1.0 + ratio), P_FLOOR, P_CEILING)


#One roll against the team mean, as FormulaEventResolver rolls it: per merc values stay raw and
#only the mean is clamped, so a merc above 100 still lifts the team.
static func _formula_chance(entry: Dictionary, team_uids: Array[int], size: int) -> float:
	var by_uid: Dictionary = (entry["values"] as Dictionary).get(size, {}) as Dictionary
	var total: float = 0.0
	var counted: int = 0
	for uid: int in team_uids:
		if not by_uid.has(uid):
			continue
		total += float(by_uid[uid])
		counted += 1
	if counted == 0:
		return 0.0
	return clampf(total / float(counted) / 100.0, 0.0, 1.0)


#The team's best merc for this check takes the contest, exactly as CompetitionResolver picks it.
static func _competition_chance(entry: Dictionary, team_uids: Array[int]) -> float:
	var expected: Dictionary = entry["expected"] as Dictionary
	var wins: Dictionary = entry["wins"] as Dictionary
	var best: int = -1
	var best_value: float = 0.0
	for uid: int in team_uids:
		if not expected.has(uid):
			continue
		var value: float = float(expected[uid])
		if best < 0 or value > best_value:
			best = uid
			best_value = value
	if best < 0:
		return 0.0
	return clampf(float(wins.get(best, 0.0)), 0.0, 1.0)


static func _event_entry(model: OddsModel, copies: Array[MercenaryData], name: String,
		is_primary: bool) -> Dictionary:
	var entry: Dictionary = {"kind": OddsModel.KIND_MISSING, "name": name, "primary": is_primary}
	var event: EventData = ContractLibrary.event(name) if name != "" else null
	if event == null:
		return entry
	if event.is_battle():
		entry["kind"] = OddsModel.KIND_BATTLE
		entry["enemy_power"] = _enemy_power(model, copies, event)
		return entry
	if event.is_competition():
		entry["kind"] = OddsModel.KIND_COMPETITION
		var defs: Array[Dictionary] = competition_defs(event)
		var rival: MercenaryData = _rival_champion(model, copies, defs)
		var expected: Dictionary = {}
		var wins: Dictionary = {}
		for index: int in range(copies.size()):
			var uid: int = model.uids[index]
			expected[uid] = _mean_expected(copies[index], defs)
			wins[uid] = P_CEILING if rival == null else _mean_win(copies[index], defs, rival)
		entry["expected"] = expected
		entry["wins"] = wins
		return entry
	entry["kind"] = OddsModel.KIND_FORMULA
	entry["values"] = _formula_values(model, copies, event)
	return entry


#The enemy's total power at each team size; the count formula reads the pinned band centre.
static func _enemy_power(model: OddsModel, copies: Array[MercenaryData], event: EventData) -> Dictionary:
	var contract: ContractData = model.contract
	var bounds: Array[float] = OpponentGenerator.level_band_bounds(contract.difficulty)
	var centre: float = bounds[1]
	var level: int = clampi(int(roundf(float(contract.contract_level) * centre)), 1, OpponentGenerator.LEVEL_CAP)
	var each: float = pow(float(level) + 1.0, ALPHA)
	var out: Dictionary = {}
	for size: int in range(1, model.max_team + 1):
		var req := OpponentRequest.new()
		req.party.assign(_slice(copies, size))
		req.difficulty = contract.difficulty
		req.contract_level = contract.contract_level
		var ctx: Dictionary = OpponentGenerator.context(req)
		ctx[OpponentGenerator.LEVEL_BAND_TOKEN] = centre
		out[size] = float(_count(event.enemy_counter, ctx)) * each
	return out


#A counter holding a dice term is averaged, so one draw never decides the estimate.
static func _count(formula: String, ctx: Dictionary) -> float:
	if not formula.contains("randf("):
		return float(OpponentGenerator.eval_count(formula, ctx, "Odds"))
	var total: float = 0.0
	for i: int in range(DICE_SAMPLES):
		total += float(OpponentGenerator.eval_count(formula, ctx, "Odds"))
	return total / float(DICE_SAMPLES)


#Each merc's raw event value at each team size; team size only moves the penalty percent.
static func _formula_values(model: OddsModel, copies: Array[MercenaryData], event: EventData) -> Dictionary:
	var out: Dictionary = {}
	for size: int in range(1, model.max_team + 1):
		var team: Array[MercenaryData] = _slice(copies, size)
		var by_uid: Dictionary = {}
		for index: int in range(copies.size()):
			var merc: MercenaryData = copies[index]
			var value: float = float(OverallSuccess.for_merc(model.contract, team, merc, event)["value"])
			value += FormulaEventResolver.evaluate(event.success_formula, merc)
			by_uid[model.uids[index]] = value
		out[size] = by_uid
	return out


#The checks a competition really plays: the secondary rows, with the primary's knowledges added.
static func competition_defs(event: EventData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in CompetitionResolver.CHECK_KINDS:
		var row: EventData = ContractLibrary.event(CompetitionResolver.ROW_PREFIX + kind)
		if row == null:
			continue
		out.append(CompetitionResolver.check_def_for(row,
			CompetitionResolver.merged_knowledges(event, row)))
	if out.is_empty():
		out.append(CompetitionResolver.check_def_for(event, event.knowledges))
	return out


static func _mean_expected(merc: MercenaryData, defs: Array[Dictionary]) -> float:
	if defs.is_empty():
		return 0.0
	var total: float = 0.0
	for check_def: Dictionary in defs:
		total += CheckSystem.expected_successes(merc, check_def)
	return total / float(defs.size())


static func _mean_win(merc: MercenaryData, defs: Array[Dictionary], rival: MercenaryData) -> float:
	if defs.is_empty() or rival == null:
		return 0.0
	var total: float = 0.0
	for check_def: Dictionary in defs:
		total += CheckSystem.opposed_win_chance(merc, check_def, rival, check_def)
	return total / float(defs.size())


#One rolled rival team, kept only for its best merc; this is the estimator's only RNG.
static func _rival_champion(model: OddsModel, copies: Array[MercenaryData],
		defs: Array[Dictionary]) -> MercenaryData:
	var config: ContractConfig = ContractLibrary.config()
	if config == null:
		config = ContractConfig.new()
	var req := OpponentRequest.new()
	req.source = "Mercs"
	req.count = -1
	req.count_formula = config.rival_count_formula
	req.party.assign(copies)
	req.difficulty = model.contract.difficulty
	req.contract_level = model.contract.contract_level
	req.tradition_odds = config.rival_tradition_odds
	req.independent_traditions = true
	req.tag = "Odds"
	var rivals: Array[MercenaryData] = OpponentGenerator.generate(req)
	if rivals.is_empty():
		return null
	var best: MercenaryData = rivals[0]
	var best_score: float = _mean_expected(best, defs)
	for index: int in range(1, rivals.size()):
		var score: float = _mean_expected(rivals[index], defs)
		if score > best_score:
			best = rivals[index]
			best_score = score
	return best


static func _slice(copies: Array[MercenaryData], size: int) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for index: int in range(mini(size, copies.size())):
		out.append(copies[index])
	return out

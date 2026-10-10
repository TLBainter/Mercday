class_name OddsEstimator

#Reads a contract's chance of success without rolling it: the primary event's chance times every
#battle or flagged mishap the crew has to survive first. prepare() caches only what holds for any team;
#chance() works out each member's net for the chosen team and leader.
#It never advances the clock, never makes a check and never leaves a stat changed.

const ALPHA := 1.5
const BETA := 2.0
const MIN_ODDS := 1
const MAX_ODDS := 99
const P_FLOOR := 0.05
const CHASE_SAMPLES := 8
const DICE_SAMPLES := 16
const BAND_EXPONENT := 2.0
const COMPETITION_ROUNDS: Array[int] = [3, 4, 5]


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
	var parts: Dictionary = _merc_parts(model, live)
	for index: int in range(contract.rolled_mishaps.size()):
		model.events.append(_event_entry(model, live, parts, contract.rolled_mishaps[index], false))
	if contract.style == "timeline":
		model.events.append(_timeline_entry(model, live, parts, contract))
	else:
		model.events.append(_event_entry(model, live, parts, contract.assigned_primary_event, true))
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


#The team-independent pieces of each merc's net under the contract boosts: own rows, lendable rows,
#base success chance and the penalty at every team size.
static func _merc_parts(model: OddsModel, live: Array[MercenaryData]) -> Dictionary:
	var out: Dictionary = {}
	for merc: MercenaryData in live:
		var penalty: Dictionary = {}
		for size: int in range(1, model.max_team + 1):
			penalty[size] = ContractPenalty.percent_for(model.contract, merc, size)
		out[merc.merc_uid] = {
			"merc": merc,
			"own": ContractModifiers.matched_rows(model.contract, merc),
			"boost": ContractModifiers.boost_percent(model.contract, merc),
			"lend": MatchScore.leader_rows(model.contract, merc),
			"base": OverallSuccess.base(merc),
			"penalty": penalty,
		}
	return out


#Unrounded chance of success in 0 to 1; leader_uid -1 or a leader outside the team shares no rows.
static func chance(model: OddsModel, team_uids: Array[int], leader_uid: int = -1) -> float:
	if model == null or model.contract == null or team_uids.is_empty() or model.events.is_empty():
		return 0.0
	var size: int = clampi(team_uids.size(), 1, model.max_team)
	var parts: Dictionary = model.events[0]["parts"] as Dictionary
	var leader: int = leader_uid if team_uids.has(leader_uid) and parts.has(leader_uid) else -1
	var primary: float = 0.0
	var survived: float = 1.0
	for entry: Dictionary in model.events:
		if bool(entry["primary"]):
			primary = _chance(model, entry, team_uids, size, leader)
		elif String(entry["kind"]) == OddsModel.KIND_BATTLE:
			survived *= _battle_chance(model, entry, team_uids, size, -1, false)
		elif bool(entry.get("fail_ends", false)):
			survived *= _chance(model, entry, team_uids, size, leader)
	return clampf(primary * survived * band_factor(model, team_uids), 0.0, 1.0)


#1 to 99: the chance rounded and clamped.
static func odds(model: OddsModel, team_uids: Array[int], leader_uid: int = -1) -> int:
	if model == null or model.contract == null or team_uids.is_empty():
		return MIN_ODDS
	return clampi(roundi(chance(model, team_uids, leader_uid) * 100.0), MIN_ODDS, MAX_ODDS)


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


#Chance a strict majority of n rounds is won at w per round; a draw counts as a non-win.
static func majority(w: float, n: int) -> float:
	var total: float = 0.0
	for k: int in range(0, n + 1):
		if 2 * k > n:
			total += _choose(n, k) * pow(w, k) * pow(1.0 - w, n - k)
	return total


#The majority chance averaged over every round count a competition can play.
static func rounds_chance(w: float) -> float:
	var total: float = 0.0
	for n: int in COMPETITION_ROUNDS:
		total += majority(w, n)
	return total / float(COMPETITION_ROUNDS.size())


static func _choose(n: int, k: int) -> float:
	var out: float = 1.0
	for i: int in range(1, k + 1):
		out = out * float(n - k + i) / float(i)
	return out


#A merc's net percent on one entry for this team size and leader, as MatchScore.merc_net reads it.
static func _net(parts: Dictionary, uid: int, size: int, leader: int, relevance: float) -> float:
	var mine: Dictionary = parts[uid] as Dictionary
	var net: float = float(mine["boost"]) + relevance - float((mine["penalty"] as Dictionary).get(size, 0.0))
	if leader < 0 or leader == uid:
		return net
	var own: Array[Dictionary] = mine["own"]
	var lend: Array[Dictionary] = (parts[leader] as Dictionary)["lend"]
	for row: Dictionary in lend:
		if not ContractModifiers.has_row(own, row):
			net += float(row["pct"])
	return net


static func _chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int, leader: int) -> float:
	var kind: String = String(entry["kind"])
	if kind == OddsModel.KIND_BATTLE:
		return _battle_chance(model, entry, team_uids, size, leader, true)
	if kind == OddsModel.KIND_FORMULA:
		return _formula_chance(formula_values(model, entry, team_uids, leader), team_uids)
	if kind == OddsModel.KIND_COMPETITION:
		return _competition_chance(model, entry, team_uids, size, leader)
	if kind == OddsModel.KIND_CHECK:
		return _check_chance(model, entry, team_uids, size, leader)
	if kind == OddsModel.KIND_CHASE:
		return _chase_chance(entry, team_uids)
	if kind == OddsModel.KIND_TIMELINE:
		return _timeline_chance(model, entry, team_uids, size, leader)
	return 0.0


#Each member's level counts as level x (1 + net / 100) when with_net is set; a battle mishap reads raw levels.
static func _battle_chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int, leader: int,
		with_net: bool) -> float:
	var enemy: float = _enemy_for(model, entry, team_uids, size)
	if enemy <= 0.0:
		return 1.0
	var parts: Dictionary = entry["parts"] as Dictionary
	var relevance: Dictionary = entry["relevance"] as Dictionary
	var power: float = 0.0
	for uid: int in team_uids:
		var level: float = model.level_of(uid)
		if with_net and parts.has(uid):
			level = maxf(0.0, level * (1.0 + _net(parts, uid, size, leader, float(relevance.get(uid, 0.0))) / 100.0))
		power += pow(level + 1.0, ALPHA)
	if power <= 0.0:
		return P_FLOOR
	var ratio: float = pow(power / enemy, BETA)
	return clampf(ratio / (1.0 + ratio), P_FLOOR, 1.0)


#With a contract level the enemy reads only the team size; without one it reads the team, so it is keyed by it.
static func _enemy_for(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int) -> float:
	var by_size: Dictionary = entry["enemy_power"] as Dictionary
	if by_size.has(size):
		return float(by_size[size])
	var sorted: Array[int] = team_uids.duplicate()
	sorted.sort()
	var key: String = str(sorted)
	var by_team: Dictionary = entry["enemy_by_team"] as Dictionary
	if not by_team.has(key):
		var parts: Dictionary = entry["parts"] as Dictionary
		var party: Array[MercenaryData] = []
		for uid: int in sorted:
			if parts.has(uid):
				party.append((parts[uid] as Dictionary)["merc"] as MercenaryData)
		by_team[key] = _enemy_power(model, party, entry["event"] as EventData)
	return float(by_team[key])


#Each member's raw event value for this team and leader: base x (1 + net / 100) plus the event formula.
static func formula_values(model: OddsModel, entry: Dictionary, team_uids: Array[int], leader: int) -> Dictionary:
	var out: Dictionary = {}
	if model == null or String(entry.get("kind", "")) != OddsModel.KIND_FORMULA:
		return out
	var size: int = clampi(team_uids.size(), 1, model.max_team)
	var parts: Dictionary = entry["parts"] as Dictionary
	var relevance: Dictionary = entry["relevance"] as Dictionary
	var evals: Dictionary = entry["eval"] as Dictionary
	for uid: int in team_uids:
		if not parts.has(uid):
			continue
		var base: float = float((parts[uid] as Dictionary)["base"])
		var net: float = _net(parts, uid, size, leader, float(relevance.get(uid, 0.0)))
		out[uid] = maxf(0.0, base * (1.0 + net / 100.0)) + float(evals.get(uid, 0.0))
	return out


#One roll against the team mean, as FormulaEventResolver rolls it: per merc values stay raw and
#only the mean is clamped, so a merc above 100 still lifts the team.
static func _formula_chance(by_uid: Dictionary, team_uids: Array[int]) -> float:
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


#The team's best merc for the checks takes the contest carrying its Overall Success delta, as
#CompetitionResolver plays a round; the per-round chance feeds the majority over 3, 4 and 5 rounds.
static func _competition_chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int,
		leader: int) -> float:
	var expected: Dictionary = entry["expected"] as Dictionary
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
	return rounds_chance(_champion_win(model, entry, best, size, leader))


static func _champion_win(model: OddsModel, entry: Dictionary, champ_uid: int, size: int, leader: int) -> float:
	var rival: MercenaryData = entry["rival"] as MercenaryData
	if rival == null:
		return 1.0
	var key: String = "%d|%d|%d" % [champ_uid, size, leader]
	var cache: Dictionary = entry["win_cache"] as Dictionary
	if cache.has(key):
		return float(cache[key])
	var parts: Dictionary = entry["parts"] as Dictionary
	var mine: Dictionary = parts[champ_uid] as Dictionary
	var champ: MercenaryData = mine["merc"] as MercenaryData
	var defs: Array[Dictionary] = entry["defs"]
	var relevance: Array = (entry["def_relevance"] as Dictionary)[champ_uid]
	var solo: Array[MercenaryData] = [champ]
	var saved: Array[Dictionary] = _snapshot(solo)
	var record: Dictionary = ContractModifiers.apply(model.contract, solo)
	var base: float = float(mine["base"])
	var total: float = 0.0
	for index: int in range(defs.size()):
		var net: float = _net(parts, champ_uid, size, leader, float(relevance[index]))
		var delta: float = maxf(0.0, base * (1.0 + net / 100.0)) - base
		OverallSuccess.apply_delta(champ, delta)
		total += CheckSystem.opposed_win_chance(champ, defs[index], rival, defs[index])
		OverallSuccess.revert_event_delta({champ: delta})
	ContractModifiers.revert(record)
	_restore(solo, saved)
	var w: float = total / float(defs.size()) if not defs.is_empty() else 0.0
	cache[key] = w
	return w


#The team's roller as CheckEventResolver picks one, carrying its Overall Success delta and the row boosts;
#forced, when on the team, rolls instead.
static func _check_chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int,
		leader: int, forced: int = -1) -> float:
	var expected: Dictionary = entry["expected"] as Dictionary
	var best: float = 0.0
	var tied: Array[int] = []
	for uid: int in team_uids:
		if not expected.has(uid):
			continue
		var value: float = float(expected[uid])
		if tied.is_empty() or (value > best and not is_equal_approx(value, best)):
			best = value
			tied.clear()
			tied.append(uid)
		elif is_equal_approx(value, best):
			tied.append(uid)
	if tied.is_empty():
		return 0.0
	var roller: int = leader if leader >= 0 and tied.has(leader) else tied[0]
	if forced >= 0 and team_uids.has(forced) and expected.has(forced):
		roller = forced
	var key: String = "%d|%d|%d" % [roller, size, leader]
	var cache: Dictionary = entry["check_cache"] as Dictionary
	if cache.has(key):
		return float(cache[key])
	var parts: Dictionary = entry["parts"] as Dictionary
	var mine: Dictionary = parts[roller] as Dictionary
	var champ: MercenaryData = mine["merc"] as MercenaryData
	var relevance: Dictionary = entry["relevance"] as Dictionary
	var parsed: Dictionary = entry["parsed"] as Dictionary
	var def: Dictionary = entry["def"] as Dictionary
	var solo: Array[MercenaryData] = [champ]
	var saved: Array[Dictionary] = _snapshot(solo)
	var record: Dictionary = ContractModifiers.apply(model.contract, solo)
	var base: float = float(mine["base"])
	var net: float = _net(parts, roller, size, leader, float(relevance.get(roller, 0.0)))
	var delta_a: float = maxf(0.0, base * (1.0 + net / 100.0)) - base
	OverallSuccess.apply_delta(champ, delta_a)
	var boosts: Dictionary = CheckStore.apply_boosts(champ, parsed, base, delta_a)
	var full: Dictionary = CheckSystem.success_distribution(champ, def)
	var raw: float = CheckSystem.threshold_for(champ, def)
	var half: Dictionary = CheckSystem.success_distribution(champ,
		CheckStore.half_def(def, raw, float(full["threshold"])))
	var rival_pmf: Array[float] = entry["rival_pmf"]
	var p: float = check_chance(full, half, int(entry["retries"]), float(parsed.get("multiplier", 1.0)), rival_pmf)
	CheckStore.revert_boosts(boosts)
	OverallSuccess.revert_event_delta({champ: delta_a})
	ContractModifiers.revert(record)
	_restore(solo, saved)
	cache[key] = p
	return p


#The share of the drawn targets the team's mean speed catches (or escapes when the target chases).
static func _chase_chance(entry: Dictionary, team_uids: Array[int]) -> float:
	var speeds: Dictionary = entry["speeds"] as Dictionary
	var total: float = 0.0
	var counted: int = 0
	for uid: int in team_uids:
		if speeds.has(uid):
			total += float(speeds[uid])
			counted += 1
	if counted == 0:
		return P_FLOOR
	var targets: Array[float] = entry["target_speeds"]
	if targets.is_empty():
		return 1.0 - P_FLOOR
	var team: float = total / float(counted)
	var mercs_chase: bool = bool(entry["mercs_chase"])
	var gap: float = float(entry["start_gap"])
	var wanted: String = ChaseResolver.RESULT_CAUGHT if mercs_chase else ChaseResolver.RESULT_ESCAPED
	var wins: int = 0
	for t: float in targets:
		var sim: Dictionary = ChaseResolver.simulate(gap, team if mercs_chase else t, t if mercs_chase else team)
		if String(sim["result"]) == wanted:
			wins += 1
	return clampf(float(wins) / float(targets.size()), P_FLOOR, 1.0 - P_FLOOR)


#Chance one roll of this pool scores k or more; past the dice only a critical passes.
static func check_pass(dist: Dictionary, k: int) -> float:
	var dice: int = int(dist.get("dice", 0))
	if k > dice:
		return float(dist.get("crit", 0.0))
	var pmf: Array = dist.get("pmf", []) as Array
	var total: float = 0.0
	for index: int in range(maxi(k, 0), mini(dice + 1, pmf.size())):
		total += float(pmf[index])
	return total


#The first roll on the full pool, then retries re-rolls on the half pool; opposed, k follows each rival count.
static func check_chance(full: Dictionary, half: Dictionary, retries: int, multiplier: float,
		rival_pmf: Array[float]) -> float:
	if rival_pmf.is_empty():
		return clampf(_retry_pass(full, half, retries, CheckStore.needed(multiplier)), 0.0, 1.0)
	var total: float = 0.0
	for r: int in range(rival_pmf.size()):
		total += rival_pmf[r] * _retry_pass(full, half, retries, CheckStore.opposed_needed(r, multiplier))
	return clampf(total, 0.0, 1.0)


static func _retry_pass(full: Dictionary, half: Dictionary, retries: int, k: int) -> float:
	return 1.0 - (1.0 - check_pass(full, k)) * pow(1.0 - check_pass(half, k), float(maxi(retries, 0)))


static func _event_entry(model: OddsModel, copies: Array[MercenaryData], parts: Dictionary, name: String,
		is_primary: bool) -> Dictionary:
	var entry: Dictionary = {"kind": OddsModel.KIND_MISSING, "name": name, "primary": is_primary, "parts": parts}
	var event: EventData = ContractLibrary.event(name) if name != "" else null
	if event == null:
		return entry
	entry["event"] = event
	entry["fail_ends"] = event.fail_ends_contract
	var relevance: Dictionary = {}
	for merc: MercenaryData in copies:
		relevance[merc.merc_uid] = OverallSuccess.relevance_percent(merc, event)
	entry["relevance"] = relevance
	if CheckStore.is_check_name(name):
		return _check_entry(model, copies, entry, name)
	if event.is_chase():
		return _chase_entry(model, copies, entry, event)
	if event.is_battle():
		entry["kind"] = OddsModel.KIND_BATTLE
		entry["enemy_power"] = _enemy_by_size(model, copies, event)
		entry["enemy_by_team"] = {}
		return entry
	if event.is_competition():
		entry["kind"] = OddsModel.KIND_COMPETITION
		var defs: Array[Dictionary] = competition_defs(event)
		var rival: MercenaryData = _rival_champion(model, copies, defs)
		var expected: Dictionary = {}
		var def_relevance: Dictionary = {}
		for merc: MercenaryData in copies:
			var uid: int = merc.merc_uid
			expected[uid] = _mean_expected(merc, defs)
			var per_def: Array[float] = []
			for check_def: Dictionary in defs:
				per_def.append(_def_relevance(merc, check_def))
			def_relevance[uid] = per_def
		entry["defs"] = defs
		entry["rival"] = rival
		entry["expected"] = expected
		entry["def_relevance"] = def_relevance
		entry["win_cache"] = {}
		return entry
	entry["kind"] = OddsModel.KIND_FORMULA
	var evals: Dictionary = {}
	for merc: MercenaryData in copies:
		evals[merc.merc_uid] = FormulaEventResolver.evaluate(event.success_formula, merc)
	entry["eval"] = evals
	return entry


#A Checks.tsv primary: each merc's expected successes under the row boosts, the rival's pool and the retries.
static func _check_entry(model: OddsModel, copies: Array[MercenaryData], entry: Dictionary,
		name: String) -> Dictionary:
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(name))
	var def: Dictionary = CheckStore.check_def(parsed, CheckStore.difficulty_points(model.contract))
	var expected: Dictionary = {}
	for merc: MercenaryData in copies:
		var record: Dictionary = CheckStore.apply_boosts(merc, parsed, OverallSuccess.base(merc))
		expected[merc.merc_uid] = CheckSystem.expected_successes(merc, def)
		CheckStore.revert_boosts(record)
	var rival: MercenaryData = null
	#One rolled rival per prepare; an RNG point like _rival_champion and the chase targets.
	if bool(parsed.get("opposed", false)):
		rival = CheckStore.make_rival(copies, model.contract)
	var rival_pmf: Array[float] = []
	if rival != null:
		rival_pmf.assign(CheckSystem.success_distribution(rival, CheckStore.rival_def(parsed))["pmf"])
	var row_retry: int = int((parsed.get("consequence", {}) as Dictionary).get("retry", 0))
	var contract_cell: String = "" if model.contract.style == "timeline" else model.contract.consequence
	var contract_retry: int = int(CheckSheet.parse_consequence(contract_cell).get("retry", 0))
	entry["kind"] = OddsModel.KIND_CHECK
	entry["parsed"] = parsed
	entry["def"] = def
	entry["expected"] = expected
	entry["rival"] = rival
	entry["rival_pmf"] = rival_pmf
	entry["retries"] = absi(row_retry) + absi(contract_retry)
	entry["check_cache"] = {}
	return entry


#A "Chase" primary: each merc's Speed plus Pace and the target side speeds, drawn once here for every chance().
static func _chase_entry(model: OddsModel, copies: Array[MercenaryData], entry: Dictionary,
		event: EventData) -> Dictionary:
	var contract: ContractData = model.contract
	var cell: String = model.event_config()
	var chasing: String = EventConfig.choice_value(event.event_name, "chasing", cell)
	entry["kind"] = OddsModel.KIND_CHASE
	entry["mode"] = EventConfig.choice_value(event.event_name, "chase", cell)
	entry["mercs_chase"] = chasing != "target"
	var speeds: Dictionary = {}
	for merc: MercenaryData in copies:
		speeds[merc.merc_uid] = float(merc.stats.get("speed", 0)) + float(merc.stats.get("pace", 1))
	entry["speeds"] = speeds
	entry["start_gap"] = ChaseResolver.DEFAULT_GAP
	var level: int = -1
	if contract.contract_level >= 1:
		var bounds: Array[float] = OpponentGenerator.level_band_bounds(contract.difficulty)
		level = clampi(roundi(float(contract.contract_level) * bounds[1]), 1, OpponentGenerator.LEVEL_CAP)
	var party: Array[MercenaryData] = _slice(copies, model.max_team)
	var target_speeds: Array[float] = []
	for i: int in range(CHASE_SAMPLES):
		var req: OpponentRequest = ContractTarget.request(contract.target, party, contract)
		req.count = mini(req.count, model.max_team)
		if level >= 1 and req.fixed_level < 0 and req.level_min < 0 and req.level_max < 0:
			req.fixed_level = level
		target_speeds.append(ChaseResolver.side_speed(OpponentGenerator.generate(req), 0.0))
	entry["target_speeds"] = target_speeds
	return entry


#A timeline primary: one sub-entry per Completion step, priced by _timeline_chance; a broken cell stays missing.
static func _timeline_entry(model: OddsModel, copies: Array[MercenaryData], parts: Dictionary,
		contract: ContractData) -> Dictionary:
	var entry: Dictionary = {"kind": OddsModel.KIND_MISSING, "name": contract.assigned_primary_event,
		"primary": true, "parts": parts, "timeline": [], "steps": [], "timeline_cache": {}}
	if TimelineGrammar.error(contract.completion) != "":
		return entry
	var steps: Array = TimelineGrammar.parse(contract.completion)
	var known: Array[String] = []
	for item: Variant in steps:
		if (item as TimelineGrammar.Step).kind == "event":
			known = ContractLibrary.event_names()
			break
	var subs: Array[Dictionary] = []
	for item: Variant in steps:
		var step: TimelineGrammar.Step = item
		var sub: Dictionary
		if step.kind == "check":
			sub = _event_entry(model, copies, parts, CheckStore.PREFIX + step.name, false)
		elif known.has(step.name):
			model.step_config = step.cfg
			sub = _event_entry(model, copies, parts, step.name, false)
			model.step_config = ""
		else:
			sub = {"kind": OddsModel.KIND_MISSING, "name": step.name, "primary": false, "parts": parts}
		sub["id"] = step.id
		sub["fail"] = step.fail
		sub["if_id"] = step.if_id
		sub["if_outcome"] = step.if_outcome
		sub["role"] = step.role
		sub["cfg"] = step.cfg if step.kind == "event" else ""
		subs.append(sub)
	entry["kind"] = OddsModel.KIND_TIMELINE
	entry["timeline"] = steps
	entry["steps"] = subs
	return entry


#Each step priced as an independent draw under its own Event Config, then the paths walked; cached per team.
static func _timeline_chance(model: OddsModel, entry: Dictionary, team_uids: Array[int], size: int,
		leader: int) -> float:
	var sorted: Array[int] = team_uids.duplicate()
	sorted.sort()
	var key: String = "%s|%d|%d" % [str(sorted), size, leader]
	var cache: Dictionary = entry["timeline_cache"] as Dictionary
	if cache.has(key):
		return float(cache[key])
	var probs: Array[float] = []
	for sub: Dictionary in entry["steps"]:
		model.step_config = String(sub.get("cfg", ""))
		var p: float
		if String(sub["kind"]) == OddsModel.KIND_CHECK:
			var forced: int = leader if String(sub["role"]) == "Leader" and leader >= 0 else -1
			p = _check_chance(model, sub, team_uids, size, leader, forced)
		else:
			p = _chance(model, sub, team_uids, size, leader)
		model.step_config = ""
		probs.append(clampf(p, 0.0, 1.0))
	var result: float = clampf(_walk(entry["timeline"] as Array, probs, 0, {}), 0.0, 1.0)
	cache[key] = result
	return result


#The chance the last step ends in success, summed over every success and failure path the grammar lets run.
static func _walk(steps: Array, probs: Array[float], index: int, ended: Dictionary) -> float:
	if index >= steps.size():
		var last: TimelineGrammar.Step = steps[TimelineGrammar.last_index(steps)]
		return 1.0 if String(ended.get(last.id, "")) == "success" else 0.0
	if not TimelineGrammar.runs(steps, index, ended):
		return _walk(steps, probs, index + 1, ended)
	var id: String = (steps[index] as TimelineGrammar.Step).id
	var p: float = probs[index]
	var total: float = 0.0
	if p > 0.0:
		var won: Dictionary = ended.duplicate()
		won[id] = "success"
		total += p * _walk(steps, probs, index + 1, won)
	if p < 1.0:
		var lost: Dictionary = ended.duplicate()
		lost[id] = "failure"
		total += (1.0 - p) * _walk(steps, probs, index + 1, lost)
	return total


#OverallSuccess.relevance_percent for one competition check, which carries the merged knowledges.
static func _def_relevance(merc: MercenaryData, check_def: Dictionary) -> float:
	for name: Variant in (check_def.get("knowledges", []) as Array):
		if ContractModifiers.knowledge_matches(merc, str(name)):
			return ContractLibrary.config().mishap_relevance_bonus_percent
	for name: Variant in (check_def.get("tools", []) as Array):
		if ContractModifiers.tool_matches(merc, str(name)):
			return ContractLibrary.config().mishap_relevance_bonus_percent
	return 0.0


#With a contract level the count formula reads only the party size, so any party of that size gives the power.
static func _enemy_by_size(model: OddsModel, copies: Array[MercenaryData], event: EventData) -> Dictionary:
	var out: Dictionary = {}
	if model.contract.contract_level < 1:
		return out
	for size: int in range(1, model.max_team + 1):
		out[size] = _enemy_power(model, _slice(copies, size), event)
	return out


#The enemy's total power against this party; the count formula reads the pinned band centre.
static func _enemy_power(model: OddsModel, party: Array[MercenaryData], event: EventData) -> float:
	var contract: ContractData = model.contract
	var bounds: Array[float] = OpponentGenerator.level_band_bounds(contract.difficulty)
	var centre: float = bounds[1]
	var level: int = clampi(int(roundf(float(contract.contract_level) * centre)), 1, OpponentGenerator.LEVEL_CAP)
	var each: float = pow(float(level) + 1.0, ALPHA)
	var req := OpponentRequest.new()
	req.party.assign(party)
	req.difficulty = contract.difficulty
	req.contract_level = contract.contract_level
	var ctx: Dictionary = OpponentGenerator.context(req)
	ctx[OpponentGenerator.LEVEL_BAND_TOKEN] = centre
	var factor: float = EventConfig.counter_factor(event.event_name, model.event_config())
	if not is_nan(factor):
		ctx["difficulty_factor"] = factor
	return float(_count(event.enemy_counter, ctx)) * each


#A counter holding a dice term is averaged, so one draw never decides the estimate.
static func _count(formula: String, ctx: Dictionary) -> float:
	if not formula.contains("randf("):
		return float(OpponentGenerator.eval_count(formula, ctx, "Odds"))
	var total: float = 0.0
	for i: int in range(DICE_SAMPLES):
		total += float(OpponentGenerator.eval_count(formula, ctx, "Odds"))
	return total / float(DICE_SAMPLES)


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


#One rolled rival team, kept only for its best merc; one of the estimator's three RNG points.
static func _rival_champion(model: OddsModel, copies: Array[MercenaryData],
		defs: Array[Dictionary]) -> MercenaryData:
	var req: OpponentRequest = CompetitionResolver.rival_request(copies, model.contract.difficulty,
			model.contract.contract_level, "Odds")
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

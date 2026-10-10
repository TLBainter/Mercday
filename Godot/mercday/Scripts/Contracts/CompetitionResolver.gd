class_name CompetitionResolver

#A Competition primary: 3 to 5 opposed rounds against a rolled rival team, rests between rounds.

const KINDS: Array[String] = ["Strength", "Wit", "Entertainment", "Speed", "War"]
const CHECK_KINDS: Array[String] = ["Strength", "Wit", "Entertainment", "Speed"]
const ROW_PREFIX := "Competition of "
const SHAPE_REPEAT := 0
const SHAPE_MIXED := 1
const SHAPE_TOURNAMENT := 2
const SHAPE_NAMES: Array[String] = ["repeat", "mixed", "tournament"]
const DEPLETION_SPREAD := 0.15
const _POOL_KEYS: Array[String] = ["hp", "ep", "mp"]
const _POOL_MAX_STATS: Array[String] = ["maximum_hit_points", "maximum_endurance_points", "maximum_magic_points"]

#Test hooks, cleared by reset(): forced_kinds wins over forced_shape and forced_round_count.
static var forced_round_count: int = -1
static var forced_shape: int = -1
static var forced_kinds: Array[String] = []
#When not null (an Array, empty allowed) it replaces the rolled rival team.
static var forced_rivals: Variant = null
#Batch and test readers for the last competition.
static var last_shape: int = -1
static var last_rounds: Array[Dictionary] = []
static var last_rivals: Array[MercenaryData] = []
static var last_ambient: Array[String] = []


static func reset() -> void:
	forced_round_count = -1
	forced_shape = -1
	forced_kinds = []
	forced_rivals = null
	last_shape = -1
	last_rounds = []
	last_rivals = []
	last_ambient = []


static func plan_rounds() -> Array[String]:
	var out: Array[String] = []
	if not forced_kinds.is_empty():
		last_shape = -1
		out.assign(forced_kinds)
		return out
	var count: int = forced_round_count if forced_round_count > 0 else randi_range(3, 5)
	var shape: int = forced_shape
	if shape < SHAPE_REPEAT or shape > SHAPE_TOURNAMENT:
		shape = randi_range(SHAPE_REPEAT, SHAPE_TOURNAMENT)
	last_shape = shape
	if shape == SHAPE_REPEAT:
		var kind: String = CHECK_KINDS[randi_range(0, CHECK_KINDS.size() - 1)]
		for _i: int in range(count):
			out.append(kind)
	elif shape == SHAPE_MIXED:
		var pool: Array[String] = []
		pool.assign(KINDS)
		pool.shuffle()
		out.assign(pool.slice(0, count))
	else:
		for _i: int in range(count):
			out.append("War")
	return out


#The primary row's knowledges then the round row's, stripped, first occurrence kept.
static func merged_knowledges(primary: EventData, row: EventData) -> Array[String]:
	var out: Array[String] = []
	for source: EventData in [primary, row]:
		if source == null:
			continue
		for raw: String in source.knowledges:
			var name: String = raw.strip_edges()
			if name != "" and not out.has(name):
				out.append(name)
	return out


static func rival_skew(difficulty: float) -> int:
	return maxi(1, int(floorf(OpponentGenerator.difficulty_factor(difficulty) * 2.0)))


#The request for one rolled rival team; the odds estimator picks rivals through the same request.
static func rival_request(party: Array[MercenaryData], difficulty: float, contract_level: int, tag: String) -> OpponentRequest:
	var config: ContractConfig = ContractLibrary.config()
	var req := OpponentRequest.new()
	req.source = "Mercs"
	req.count = -1
	req.count_formula = config.rival_count_formula
	req.party.assign(party)
	req.difficulty = difficulty
	req.contract_level = contract_level
	req.tradition_odds = config.rival_tradition_odds
	req.independent_traditions = true
	req.tag = tag
	return req


static func build_rivals(run: ContractRun, party: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if forced_rivals is Array:
		out.assign(forced_rivals as Array)
		return out
	var difficulty: float = run.difficulty() if run != null else 0.0
	var level: int = -1
	if run != null and run.contract != null:
		level = run.contract.contract_level
	out.assign(OpponentGenerator.generate(rival_request(party, difficulty, level, "Competition")))
	return out


static func check_def_for(row: EventData, knowledges: Array[String]) -> Dictionary:
	var stat_keys: Array[String] = []
	for stat: String in row.check_stats:
		stat_keys.append(ContractModifiers.stat_key(stat))
	return {
		"stat_keys": stat_keys,
		"circumstances": row.circumstances,
		"tools": row.tools,
		"knowledges": knowledges,
		"formula": row.success_formula,
	}


#Highest expected successes; a tie keeps the earlier merc.
static func best_for(mercs: Array[MercenaryData], check_def: Dictionary) -> MercenaryData:
	var best: MercenaryData = null
	var best_value: float = 0.0
	for merc: MercenaryData in mercs:
		if merc == null:
			continue
		var value: float = CheckSystem.expected_successes(merc, check_def)
		if best == null or value > best_value:
			best = merc
			best_value = value
	return best


static func score(result: String) -> int:
	return 1 if result == "won" else 0


#A side with nobody left settles every remaining round; the party is checked first.
static func forfeit_result(party_count: int, rival_count: int) -> String:
	if party_count == 0:
		return "lost"
	if rival_count == 0:
		return "won"
	return ""


static func snapshot(party: Array[MercenaryData]) -> Dictionary:
	var out: Dictionary = {}
	for merc: MercenaryData in party:
		if merc != null:
			out[merc] = _pools(merc)
	return out


#Mean percent of each pool maximum the party lost since the snapshot; a pool never counts a gain.
static func loss_percents(snap: Dictionary, party: Array[MercenaryData]) -> Dictionary:
	var sums: Array[float] = [0.0, 0.0, 0.0]
	var counts: Array[int] = [0, 0, 0]
	for merc: MercenaryData in party:
		if merc == null or not snap.has(merc):
			continue
		var before: Array = snap[merc]
		var current: Array = _pools(merc)
		for p: int in range(_POOL_KEYS.size()):
			var maximum: int = int(merc.stats.get(_POOL_MAX_STATS[p], 0))
			if maximum <= 0:
				continue
			sums[p] += maxf(0.0, float(int(before[p]) - int(current[p]))) / float(maximum) * 100.0
			counts[p] += 1
	var out: Dictionary = {}
	for p: int in range(_POOL_KEYS.size()):
		out[_POOL_KEYS[p]] = sums[p] / float(counts[p]) if counts[p] > 0 else 0.0
	return out


#Rivals rest, then each pool is set to mirror the party's loss within the spread.
static func deplete_rivals(rivals: Array[MercenaryData], loss: Dictionary, run: ContractRun) -> void:
	RestSystem.respite(rivals, null)
	for rival: MercenaryData in rivals:
		if rival == null:
			continue
		var values: Array[int] = []
		var maxima: Array[int] = []
		for p: int in range(_POOL_KEYS.size()):
			var maximum: int = int(rival.stats.get(_POOL_MAX_STATS[p], 0))
			var pct: float = float(loss.get(_POOL_KEYS[p], 0.0))
			var spread: float = 1.0 + randf_range(-DEPLETION_SPREAD, DEPLETION_SPREAD)
			values.append(clampi(roundi(float(maximum) - float(maximum) * pct * spread / 100.0), 0, maximum))
			maxima.append(maximum)
		rival.current_hp = maxi(1, values[0])
		rival.current_ep = values[1]
		rival.current_mp = values[2]
		if run != null:
			run.emit("RIVAL REST: %s HP %d/%d EP %d/%d MP %d/%d" % [rival.merc_name,
				rival.current_hp, maxima[0], rival.current_ep, maxima[1], rival.current_mp, maxima[2]])


static func resolve(event: EventData, run: ContractRun) -> Dictionary:
	last_rounds.clear()
	last_rivals.clear()
	last_ambient.clear()
	var out: Dictionary = EventRunner.outcome(event)
	if event == null or run == null:
		return out
	var party: Array[MercenaryData] = run.living_team()
	if party.is_empty():
		var no_team: Array[String] = ["no living mercs"]
		out["notes"] = no_team
		run.emit("EVENT SKIPPED: %s (no living mercs)" % event.event_name)
		return out
	var kinds: Array[String] = plan_rounds()
	var loaded_rows: Dictionary = _load_rows(event, kinds, run, out)
	if not bool(loaded_rows["ok"]):
		return out
	var rows: Dictionary = loaded_rows["rows"]
	var shape_name: String = "forced"
	if last_shape >= 0 and last_shape < SHAPE_NAMES.size():
		shape_name = SHAPE_NAMES[last_shape]
	run.emit("COMPETITION: %s %d rounds: %s" % [shape_name, kinds.size(), ", ".join(kinds)])

	var rivals: Array[MercenaryData] = build_rivals(run, party)
	last_rivals.assign(rivals)
	var difficulty: float = run.difficulty()
	var skew_text: String = "forced" if forced_rivals is Array else "+%d" % rival_skew(difficulty)
	run.emit("RIVAL TEAM: %d rivals, difficulty %.1f, skew %s" % [rivals.size(), difficulty, skew_text])
	for rival: MercenaryData in rivals:
		run.emit("RIVAL: %s" % ContractLog.merc_line(rival))
	out["enemies"] = run.merc_names(rivals)
	out["enemy_count"] = rivals.size()

	var start_pools: Dictionary = snapshot(party)
	var won: int = 0
	var decided: String = ""
	var notes: Array[String] = []
	var casualties: Array[String] = []
	for i: int in range(kinds.size()):
		var n: int = i + 1
		var kind: String = kinds[i]
		var row: EventData = rows[kind]
		party = run.living_team()
		if decided == "":
			decided = forfeit_result(party.size(), rivals.size())
		if i > 0 and decided == "":
			await ContractManager.party_rest(run, RestSystem.KIND_RESPITE, "competition round %d" % n, false)
			party = run.living_team()
			deplete_rivals(rivals, loss_percents(start_pools, party), run)
			decided = forfeit_result(party.size(), rivals.size())
		var record: Dictionary = {}
		if decided != "":
			run.emit("COMPETITION ROUND %d: %s forfeit -> %s" % [n, kind, decided])
			record = {"round": n, "kind": kind, "result": decided, "forfeit": true}
		elif kind == "War":
			record = await _war_round(run, row, party, rivals, n, kind, casualties, out)
		else:
			record = _check_round(run, row, party, rivals, n, kind)
		var result: String = String(record["result"])
		won += score(result)
		if not bool(record["forfeit"]):
			run.add_event_mark(ROW_PREFIX + kind)
		last_rounds.append(record)
		notes.append("round %d %s %s" % [n, kind, result])

	var total: int = kinds.size()
	var success: bool = won * 2 > total
	out["notes"] = notes
	out["casualties"] = casualties
	out["rounds"] = total
	out["rounds_won"] = won
	out["rounds_total"] = total
	out["success"] = success
	out["winner"] = 0 if success else 1
	run.emit("COMPETITION %d of %d" % [won, total])
	run.emit("EVENT RESULT: %s %s rounds won %d/%d" % [event.event_name, "success" if success else "failure", won, total])
	return out


#The round EventData rows one per kind, each merged with the parent event knowledges; ok is false on a miss.
static func _load_rows(event: EventData, kinds: Array[String], run: ContractRun,
		out: Dictionary) -> Dictionary:
	var rows: Dictionary = {}
	for kind: String in kinds:
		if rows.has(kind):
			continue
		var row_name: String = ROW_PREFIX + kind
		var loaded: EventData = ContractLibrary.event(row_name)
		if loaded == null:
			push_warning("CompetitionResolver: missing event %s" % row_name)
			var missing: Array[String] = ["missing event %s" % row_name]
			out["notes"] = missing
			run.emit("EVENT FAILED: %s (missing event %s)" % [event.event_name, row_name])
			return {"ok": false, "rows": rows}
		loaded.knowledges = merged_knowledges(event, loaded)
		rows[kind] = loaded
	return {"ok": true, "rows": rows}


#One War bout: the rivals fight as an enemy team, the fallen leave the rival list and the log path carries over.
static func _war_round(run: ContractRun, row: EventData, party: Array[MercenaryData],
		rivals: Array[MercenaryData], n: int, kind: String, casualties: Array[String],
		out: Dictionary) -> Dictionary:
	CheckSystem.ambient_knowledges.assign(row.knowledges)
	last_ambient.assign(row.knowledges)
	run.emit("COMPETITION ROUND %d: War bout, %d vs %d" % [n, party.size(), rivals.size()])
	var bout_rivals: Array[MercenaryData] = []
	bout_rivals.assign(rivals)
	var bout: Dictionary = await BattleEventResolver.resolve(row, run, {"enemies": bout_rivals,
		"no_death_removal": true, "betrayal": false, "flee": true})
	CheckSystem.ambient_knowledges.clear()
	var abandoned: Array = bout.get("foes_abandoned", [])
	for rival: MercenaryData in rivals.duplicate():
		if rival.is_dead or abandoned.has(rival):
			rivals.erase(rival)
	var winner: int = int(bout.get("winner", -1))
	var war_result: String = "draw"
	if winner == 0:
		war_result = "won"
	elif winner == 1:
		war_result = "lost"
	run.emit("COMPETITION ROUND %d: War -> %s" % [n, war_result])
	for name: String in (bout.get("casualties", []) as Array):
		if not casualties.has(name):
			casualties.append(name)
	var log_file: String = String(bout.get("log_file", ""))
	if log_file != "":
		out["log_file"] = log_file
	return {"round": n, "kind": kind, "result": war_result, "winner": winner,
		"rounds": int(bout.get("rounds", 0)), "forfeit": false}


#One opposed check: the champion carries its Overall Success delta and the rivals their skew for this check only.
static func _check_round(run: ContractRun, row: EventData, party: Array[MercenaryData],
		rivals: Array[MercenaryData], n: int, kind: String) -> Dictionary:
	var check_def: Dictionary = check_def_for(row, row.knowledges)
	var saved: Array = _skew_rivals(run, rivals)
	var champ: MercenaryData = best_for(party, check_def)
	var rival: MercenaryData = best_for(rivals, check_def)
	var info: Dictionary = OverallSuccess.for_merc(run.contract, party, champ, row, run.leader())
	var delta: float = float(info["delta"])
	run.emit(OverallSuccess.describe(champ, info))
	OverallSuccess.apply_delta(champ, delta)
	var res: Dictionary = CheckSystem.opposed_check(champ, rival, check_def)
	OverallSuccess.revert_event_delta({champ: delta})
	_unskew_rivals(rivals, saved)
	var ra: Dictionary = res["a"]
	var rb: Dictionary = res["b"]
	var result: String = "lost"
	if bool(res["a_wins"]):
		result = "won"
	elif bool(res["tie"]):
		result = "tied"
	run.emit("COMPETITION ROUND %d: %s %s %d vs %s %d -> %s" % [n, kind, champ.merc_name,
		int(ra["successes"]), rival.merc_name, int(rb["successes"]), result])
	if bool(ra["critical"]):
		run.emit("COMPETITION CRITICAL: %s %s" % [champ.merc_name, str(ra["crit_reward"])])
	if bool(rb["critical"]):
		run.emit("COMPETITION CRITICAL: %s %s" % [rival.merc_name, str(rb["crit_reward"])])
	return {"round": n, "kind": kind, "result": result, "champion": champ, "rival": rival,
		"a": ra, "b": rb, "margin": int(res["margin"]), "delta": delta, "forfeit": false}


#Difficulty skew sits on the rivals for one opposed check only; War bouts and forced rivals fight unskewed.
static func _skew_rivals(run: ContractRun, rivals: Array[MercenaryData]) -> Array:
	var saved: Array = []
	if forced_rivals is Array:
		return saved
	var difficulty: float = run.difficulty() if run != null else 0.0
	var points: int = rival_skew(difficulty)
	var skew: Dictionary = {}
	for stat: String in StatCalculator.CORE_STATS:
		skew[stat] = points
	for rival: MercenaryData in rivals:
		saved.append([rival.stat_bonuses.duplicate(), rival.max_stats.duplicate(), _pools(rival)])
		OpponentGenerator._apply_skew(rival, skew, "Competition")
	return saved


static func _unskew_rivals(rivals: Array[MercenaryData], saved: Array) -> void:
	for k: int in range(saved.size()):
		var rival: MercenaryData = rivals[k]
		rival.stat_bonuses = saved[k][0]
		rival.max_stats = saved[k][1]
		StatCalculator.refresh(rival)
		rival.current_hp = saved[k][2][0]
		rival.current_ep = saved[k][2][1]
		rival.current_mp = saved[k][2][2]


static func _pools(merc: MercenaryData) -> Array:
	return [merc.current_hp, merc.current_ep, merc.current_mp]

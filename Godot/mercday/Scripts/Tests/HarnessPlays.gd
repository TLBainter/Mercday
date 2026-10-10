class_name HarnessPlays
extends RefCounted

#"--auto-play=N": solo plays of one contract row, posted through the board generator and run by ContractManager.

const LIVE_SHEET: String = "res://TSVs/Contracts.tsv"
const STATS: Array[String] = ["Dexterity", "Wile"]
const KNOWLEDGES: Array[String] = ["Zoology", "Diplomacy", "Hunting", "Psychology", "Salesmanship", "Tactics"]
const TOOLS: Array[String] = ["Scout's", "Survivalist's", "Tracker's", "Trapper's"]
const DESC_KEY_CHARS: int = 40


#Collects every engine and script error raised while the batch runs.
class ErrorTap extends Logger:
	var seen: Array[String] = []
	var lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		lock.lock()
		seen.append("%s:%d %s" % [file.get_file(), line, rationale if rationale != "" else code])
		lock.unlock()


#Contract Name of the first data row of the live sheet; "" when the sheet holds none.
static func default_row() -> String:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(LIVE_SHEET)
	for i: int in range(1, rows.size()):
		if rows[i].size() > 0 and rows[i][0].strip_edges() != "":
			return rows[i][0].strip_edges()
	return ""


#size fresh mercs at level; MercGenerator.forced_level is restored to what it was.
static func make_team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	var previous: int = MercGenerator.forced_level
	for i: int in range(maxi(1, size)):
		MercGenerator.forced_level = maxi(1, level)
		team.append(MercGenerator.generate(i))
	MercGenerator.forced_level = previous
	return team


static func run_auto_play(host: Node, count: int, row: String, level: int, team_size: int, seed_base: int) -> void:
	var tap := ErrorTap.new()
	OS.add_logger(tap)
	var kept: Dictionary = save_state()
	ContractLibrary.pinned_names = [row]
	MercPool.clear()
	print("PLAY BATCH: row=%s plays=%d level=%d team=%d seed=%d" % [row, count, level, team_size, seed_base])
	var results: Array[Dictionary] = []
	for i: int in range(count):
		var before: int = tap.seen.size()
		var result: Dictionary = await _play(i, row, level, team_size, seed_base)
		for k: int in range(before, tap.seen.size()):
			(result["anomalies"] as Array).append("error: " + tap.seen[k])
		results.append(result)
	restore_state(kept)
	OS.remove_logger(tap)
	for line: String in summary_lines(results):
		print(line)
	host.get_tree().quit()


static func save_state() -> Dictionary:
	return {"pinned": ContractLibrary.pinned_names.duplicate(), "mercs": GameState.mercs.duplicate()}


static func restore_state(kept: Dictionary) -> void:
	ContractLibrary.pinned_names.assign(kept["pinned"])
	GameState.mercs.assign(kept["mercs"])


static func _play(i: int, row: String, level: int, team_size: int, seed_base: int) -> Dictionary:
	var result: Dictionary = {"posted": false, "anomalies": []}
	TestFixtures.reset_generator_rolls()
	CampaignClock.reset()
	GuildRecord.reset()
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	var rng := RandomNumberGenerator.new()
	if seed_base >= 0:
		rng.seed = seed_base + i
		seed(seed_base + i)
	else:
		rng.randomize()
	var team: Array[MercenaryData] = make_team(team_size, level)
	GameState.mercs.assign(team)
	TestFixtures.set_roster(team)
	var now: int = CampaignClock.now()
	var board := ContractBoard.new()
	var ctx: Dictionary = DailyContractRound.context(board, now)
	var excluded: Array[int] = GenProvision.busy_issuers(board)
	excluded.append_array(board.pool.issuer_ids())
	var issuer: int = GenIssuer.pick(excluded, now, rng)
	var entry: BoardEntry = null
	if issuer >= 0:
		entry = GenPosting.generate_one(ctx, board, now, rng, issuer)
	if entry == null:
		result["reason"] = _no_post_reason(row, issuer)
		print("PLAY %d: NO POST (%s)" % [i, result["reason"]])
		return result
	board.pool.add(entry, now)
	board.post_pooled(entry, now)
	result["posted"] = true
	var contract: ContractData = entry.contract
	_note_generate(result, entry, ctx, now, team)
	for line: String in generate_lines(i, result, contract):
		print(line)
	for merc: MercenaryData in team:
		print("PLAY %d MERC: %s" % [i, merc_line(merc)])
	var levels_before: Array[int] = []
	for merc: MercenaryData in team:
		levels_before.append(ExperienceSystem.current_level(merc))
	result["ep_before"] = _team_ep(team)
	var run: ContractRun = await HarnessContracts.run_on_team(contract, team, "PLAY %d" % i)
	result["minutes"] = CampaignClock.now() - now
	result["ep_after"] = _team_ep(team)
	if run == null:
		(result["anomalies"] as Array).append("run did not start")
		return result
	_note_run(result, run, team, levels_before)
	print("PLAY %d RESULT: %s" % [i, result_line(result)])
	return result


static func _no_post_reason(row: String, issuer: int) -> String:
	if issuer < 0:
		return "no issuer seat"
	if GenPosting.null_reason != "":
		return GenPosting.null_reason
	if ContractLibrary.row_names().is_empty():
		return "row %s not in the contract library" % row
	return "generate_one returned null"


static func _note_generate(result: Dictionary, entry: BoardEntry, ctx: Dictionary, now: int,
		team: Array[MercenaryData]) -> void:
	var contract: ContractData = entry.contract
	var centre: float = float(ctx["level_centre"])
	result["name"] = contract.contract_name
	result["type"] = contract.contract_type
	result["level"] = contract.contract_level
	result["level_centre"] = centre
	result["difficulty"] = contract.difficulty
	result["location"] = contract.location_a
	result["distance_km"] = entry.distance_km
	result["deadline_h"] = float(entry.deadline_minute - now) / 60.0
	result["completion_h"] = entry.completion_hours
	result["expected_min"] = GenPosting.expected_minutes(entry, centre)
	result["quality"] = entry.quality
	result["value"] = entry.value
	result["issuer"] = entry.issuer
	result["issuer_type"] = "%s/%s" % [entry.issuer_type, IssuerOpinion.group_of(entry.issuer_id)]
	result["issuer_face"] = IssuerOpinion.face(entry.issuer_id)
	result["requestor"] = contract.requestor_name
	result["description"] = contract.description
	result["primary"] = contract.assigned_primary_event
	result["mishaps"] = contract.rolled_mishaps.size()
	result["mishap_names"] = ", ".join(PackedStringArray(contract.rolled_mishaps))
	result["odds"] = OddsEstimator.for_contract(contract, team)
	result["tradition"] = _tradition(team[0])
	var anomalies: Array = result["anomalies"]
	for key: String in ["name", "type", "location", "requestor", "description", "primary"]:
		if str(result[key]) == "":
			anomalies.append("missing " + key)
	if not str(result["primary"]).begins_with(CheckStore.PREFIX) and contract.style != "timeline":
		anomalies.append("non-check primary " + str(result["primary"]))


static func _note_run(result: Dictionary, run: ContractRun, team: Array[MercenaryData],
		levels_before: Array[int]) -> void:
	var check: Dictionary = {}
	for outcome: Dictionary in run.outcomes:
		if outcome.has("check"):
			check = outcome
	if check.is_empty() and not (run.contract != null and run.contract.style == "timeline"):
		(result["anomalies"] as Array).append("no check outcome")
	result["verdict"] = run.verdict
	result["success"] = run.verdict == "Succeeded"
	result["attempts"] = int(check.get("attempts", 0))
	result["successes"] = int(check.get("successes", 0))
	result["needed"] = int(check.get("needed", 0))
	result["roller"] = int(check.get("roller", -1))
	result["first_pass"] = bool(check.get("success", false)) and int(check.get("attempts", 0)) == 1
	result["retry"] = int(check.get("attempts", 0)) > 1
	result["consequences"] = ", ".join(PackedStringArray(check.get("consequences", [])))
	result["reward"] = run.reward_paid
	result["casualties"] = run.casualties.size()
	result["triggered"] = ", ".join(PackedStringArray(run.triggered_events))
	var level_ups: int = 0
	var xp_parts: Array[String] = []
	for k: int in range(team.size()):
		var now_level: int = ExperienceSystem.current_level(team[k])
		level_ups += maxi(0, now_level - levels_before[k])
		xp_parts.append("%s xp %d L%d" % [team[k].merc_name, team[k].xp, now_level])
	result["level_ups"] = level_ups
	result["xp"] = "; ".join(PackedStringArray(xp_parts))


static func generate_lines(i: int, r: Dictionary, contract: ContractData) -> Array[String]:
	var p: String = "PLAY %d GENERATE: " % i
	return [
		p + "name=%s" % r["name"],
		p + "type=%s" % r["type"],
		p + "contract_level=%d (level_centre %.2f)" % [int(r["level"]), float(r["level_centre"])],
		p + "difficulty=%.1f (row Difficulty Min %.1f Max %.1f)" % [float(r["difficulty"]),
			contract.difficulty_min, contract.difficulty_max],
		p + "location=%s" % r["location"],
		p + "distance_km=%d" % int(r["distance_km"]),
		p + "deadline_hours=%.1f" % float(r["deadline_h"]),
		p + "completion_hours=%d" % int(r["completion_h"]),
		p + "expected_minutes=%d" % int(r["expected_min"]),
		p + "quality=%.2f" % float(r["quality"]),
		p + "value=%d" % int(r["value"]),
		p + "issuer=%s type=%s face=%d" % [r["issuer"], r["issuer_type"], int(r["issuer_face"])],
		p + "requestor_name=%s" % r["requestor"],
		p + "description=%s" % r["description"],
		p + "primary_event=%s" % r["primary"],
		p + "mishaps=%d [%s]" % [int(r["mishaps"]), r["mishap_names"]],
		p + "odds=%d" % int(r["odds"]),
	]


static func merc_line(merc: MercenaryData) -> String:
	var parts: Array[String] = [merc.merc_name, "level %d" % ExperienceSystem.current_level(merc),
		_tradition(merc)]
	for stat: String in STATS:
		parts.append("%s %d" % [stat, int(merc.stats.get(ContractModifiers.stat_key(stat), 0))])
	for name: String in KNOWLEDGES:
		var value: int = _held_value(merc, merc.knowledges, name, "knowledge:")
		if value > 0:
			parts.append("%s %d" % [name, value])
	for name: String in TOOLS:
		var value: int = _held_value(merc, merc.tools, name, "tool:")
		if value > 0:
			parts.append("%s %d" % [name, value])
	parts.append("EP %d/%d" % [merc.current_ep, int(merc.stats.get("maximum_endurance_points", 0))])
	return ", ".join(PackedStringArray(parts))


#1 plus the trained bonus when the merc holds the utility, matched as CheckSystem matches it; 0 otherwise.
static func _held_value(merc: MercenaryData, held: Array[UtilityTraitData], name: String, kind: String) -> int:
	for u: UtilityTraitData in held:
		if u.utility_name == name or (kind == "tool:" and u.utility_name.begins_with(name)):
			return 1 + int(merc.trained_bonus.get(kind + u.utility_name, 0))
	return 0


static func result_line(r: Dictionary) -> String:
	return ("verdict=%s attempts=%d successes=%d/%d roller=%d retry=%s consequences=[%s] ep %d -> %d reward=%d"
		+ " casualties=%d triggered=[%s] clock_minutes=%d %s") % [r["verdict"], int(r["attempts"]),
		int(r["successes"]), int(r["needed"]), int(r["roller"]), "yes" if bool(r["retry"]) else "no",
		r["consequences"], int(r["ep_before"]), int(r["ep_after"]), int(r["reward"]), int(r["casualties"]),
		r["triggered"], int(r["minutes"]), r["xp"]]


static func _tradition(merc: MercenaryData) -> String:
	return merc.tradition.tradition_name if merc != null and merc.tradition != null else "none"


static func _team_ep(team: Array[MercenaryData]) -> int:
	var total: int = 0
	for merc: MercenaryData in team:
		total += merc.current_ep
	return total


#n of d as a whole percent with a percent sign; "0%" when d is 0.
static func pct(n: int, d: int) -> String:
	return "%d%%" % roundi(100.0 * float(n) / float(d)) if d > 0 else "0%"


#Count per key, keys sorted, as "k:n k:n".
static func histogram_text(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key: Variant in keys:
		parts.append("%s:%d" % [str(key), int(counts[key])])
	return " ".join(PackedStringArray(parts))


static func _bump(counts: Dictionary, key: Variant) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


#"min/mean/max" over one numeric key of the posted results.
static func spread(results: Array[Dictionary], key: String) -> String:
	var lo: float = INF
	var hi: float = -INF
	var sum: float = 0.0
	var n: int = 0
	for r: Dictionary in results:
		if not r.has(key):
			continue
		var v: float = float(r[key])
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
		n += 1
	if n == 0:
		return "none"
	return "%.1f/%.1f/%.1f" % [lo, sum / float(n), hi]


static func summary_lines(results: Array[Dictionary]) -> Array[String]:
	var posted: Array[Dictionary] = []
	var ran: Array[Dictionary] = []
	for r: Dictionary in results:
		if bool(r.get("posted", false)):
			posted.append(r)
		if r.has("verdict"):
			ran.append(r)
	var won: int = 0
	var first_pass: int = 0
	var retried: int = 0
	var drains: int = 0
	var drain_sum: int = 0
	var mishaps: int = 0
	var casualties: int = 0
	var level_ups: int = 0
	var triggered: Dictionary = {}
	var odds_sum: int = 0
	var diff_hist: Dictionary = {}
	var level_hist: Dictionary = {}
	var places: Dictionary = {}
	var issuers: Dictionary = {}
	var variants: Dictionary = {}
	var by_trad: Dictionary = {}
	var anomalies: Array[String] = []
	for i: int in range(results.size()):
		var r: Dictionary = results[i]
		if not bool(r.get("posted", false)):
			anomalies.append("play %d: no post (%s)" % [i, str(r.get("reason", "?"))])
		for a: Variant in r.get("anomalies", []):
			anomalies.append("play %d: %s" % [i, str(a)])
	for r: Dictionary in posted:
		_bump(diff_hist, "%.1f" % float(r["difficulty"]))
		_bump(level_hist, int(r["level"]))
		_bump(places, str(r["location"]))
		_bump(issuers, str(r["issuer_type"]))
		_bump(variants, str(r["description"]).substr(0, DESC_KEY_CHARS))
		mishaps += int(r["mishaps"])
		odds_sum += int(r["odds"])
	for r: Dictionary in ran:
		var trad: String = str(r.get("tradition", "none"))
		if not by_trad.has(trad):
			by_trad[trad] = [0, 0]
		by_trad[trad][1] += 1
		if bool(r["success"]):
			won += 1
			by_trad[trad][0] += 1
		first_pass += 1 if bool(r["first_pass"]) else 0
		retried += 1 if bool(r["retry"]) else 0
		var loss: int = int(r["ep_before"]) - int(r["ep_after"])
		if loss > 0:
			drains += 1
			drain_sum += loss
		casualties += int(r["casualties"])
		for name: String in str(r.get("triggered", "")).split(", ", false):
			_bump(triggered, name)
		level_ups += int(r["level_ups"])
	var n_ran: int = ran.size()
	var trad_parts: Array[String] = []
	var trad_keys: Array = by_trad.keys()
	trad_keys.sort()
	for key: Variant in trad_keys:
		trad_parts.append("%s %s of %d" % [str(key), pct(by_trad[key][0], by_trad[key][1]), by_trad[key][1]])
	var out: Array[String] = ["PLAY SUMMARY",
		"plays=%d posted=%d no_post=%d" % [results.size(), posted.size(), results.size() - posted.size()],
		"succeeded=%d (%s) failed=%d" % [won, pct(won, n_ran), n_ran - won],
		"first_roll_pass=%s retry_used=%s" % [pct(first_pass, n_ran), pct(retried, n_ran)],
		"mean_attempts=%s mean_clock_minutes=%s" % [_mean(ran, "attempts"), _mean(ran, "minutes")],
		"mean_odds=%d%% actual_success=%s" % [roundi(float(odds_sum) / float(maxi(1, posted.size()))),
			pct(won, n_ran)],
		"ep_drains=%d mean_loss=%.1f" % [drains, float(drain_sum) / float(maxi(1, drains))],
		"value min/mean/max=%s" % spread(posted, "value"),
		"difficulty=%s" % histogram_text(diff_hist),
		"level=%s" % histogram_text(level_hist),
		"distance_km min/mean/max=%s" % spread(posted, "distance_km"),
		"deadline_hours min/mean/max=%s" % spread(posted, "deadline_h"),
		"completion_hours min/mean/max=%s" % spread(posted, "completion_h"),
		"locations=%s" % histogram_text(places),
		"issuer_types=%s" % histogram_text(issuers),
		"description_variants=%d" % variants.size()]
	var variant_keys: Array = variants.keys()
	variant_keys.sort()
	for key: Variant in variant_keys:
		out.append("  %d x %s" % [int(variants[key]), str(key)])
	out.append_array(["mishaps=%d casualties=%d level_ups=%d" % [mishaps, casualties, level_ups],
		"triggered_events=%s" % histogram_text(triggered),
		"success_by_tradition=%s" % "; ".join(PackedStringArray(trad_parts)),
		"ANOMALIES=%d" % anomalies.size()])
	for a: String in anomalies:
		out.append("  " + a)
	return out


static func _mean(results: Array[Dictionary], key: String) -> String:
	if results.is_empty():
		return "0.0"
	var sum: float = 0.0
	for r: Dictionary in results:
		sum += float(r.get(key, 0))
	return "%.1f" % (sum / float(results.size()))

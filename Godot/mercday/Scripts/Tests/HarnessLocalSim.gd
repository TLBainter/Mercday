class_name HarnessLocalSim
extends RefCounted

#"--local-sim=N": per test one fresh level 1 merc per local contract row, mercs matched to contracts by the highest
#summed chance, each pair run solo; then success, attribute, tradition, utility and income stats (card 746).

const DEFAULT_SEED: int = 20261009
const TEAM_LEVEL: int = 1
const ATTRIBUTES: Array[String] = ["cognition", "dexterity", "vigor", "wile"]
const MIN_TRADITION_RUNS: int = 10
const ANOMALY_LINES: int = 20
const PREFIX: String = "LOCALSIM "
const COLUMNS: Array[String] = ["test", "row", "merc_name", "tradition", "cognition", "dexterity", "vigor", "wile",
	"chance", "verdict", "success", "attempts", "successes", "needed", "roller", "reward", "knowledge_hits",
	"tool_hits", "tradition_points", "casualties", "errors"]


static func run(host: Node, tests: int, seed_base: int, out_path: String) -> void:
	var tap := HarnessPlays.ErrorTap.new()
	OS.add_logger(tap)
	var kept: Dictionary = HarnessPlays.save_state()
	MercPool.clear()
	var rows: Array[String] = local_rows()
	print("%sROWS: %d: %s" % [PREFIX, rows.size(), ", ".join(PackedStringArray(rows))])
	ContractLibrary.pinned_names.assign(rows)
	var base: int = seed_base if seed_base >= 0 else DEFAULT_SEED
	var records: Array[Dictionary] = []
	var anomalies: Array[String] = []
	var skipped: int = 0
	for i: int in range(tests if not rows.is_empty() else 0):
		if not await _test(i, base + i, rows, tap, records, anomalies):
			skipped += 1
	HarnessPlays.restore_state(kept)
	OS.remove_logger(tap)
	for line: String in summary_lines(records, rows, tests, skipped, anomalies):
		print(line)
	if out_path != "":
		print("%sTSV: %s %s" % [PREFIX, out_path, "written" if write_tsv(out_path, records) else "NOT WRITTEN"])
	host.get_tree().quit()


#The live sheet's rows the library lists with Local set, in sheet order; library rows off the sheet follow, sorted.
static func local_rows() -> Array[String]:
	var pin: Array[String] = ContractLibrary.pinned_names.duplicate()
	ContractLibrary.pinned_names.clear()
	var listed: Array[String] = ContractLibrary.row_names()
	ContractLibrary.pinned_names.assign(pin)
	var order: Array[String] = []
	var sheet: Array[PackedStringArray] = TsvReader.load_tsv(HarnessPlays.LIVE_SHEET)
	for i: int in range(1, sheet.size()):
		var title: String = sheet[i][0].strip_edges() if sheet[i].size() > 0 else ""
		if listed.has(title) and not order.has(title):
			order.append(title)
	for title: String in listed:
		if not order.has(title):
			order.append(title)
	var out: Array[String] = []
	for title: String in order:
		var data: ContractData = ContractLibrary.contract(title)
		if data != null and data.local:
			out.append(title)
	return out


#False when a row did not generate, so the test is skipped.
static func _test(i: int, test_seed: int, rows: Array[String], tap: HarnessPlays.ErrorTap,
		records: Array[Dictionary], anomalies: Array[String]) -> bool:
	seed(test_seed)
	TestFixtures.reset_generator_rolls()
	CampaignClock.reset()
	GuildRecord.reset()
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	var team: Array[MercenaryData] = HarnessPlays.make_team(rows.size(), TEAM_LEVEL)
	GameState.mercs.assign(team)
	TestFixtures.set_roster(team)
	var contracts: Array[ContractData] = []
	for row: String in rows:
		var contract: ContractData = ContractGenerator.generate_named(row)
		if contract == null:
			anomalies.append("test %d: %s did not generate" % [i, row])
			return false
		contracts.append(contract)
	var chances: Array = []
	for _m: int in range(team.size()):
		chances.append([])
	for contract: ContractData in contracts:
		var model: OddsModel = OddsEstimator.prepare(contract, team)
		for m: int in range(team.size()):
			(chances[m] as Array).append(OddsEstimator.chance(model, [team[m].merc_uid]))
	var pick: Array[int] = best_assignment(chances)
	for m: int in range(team.size()):
		var merc: MercenaryData = team[m]
		var contract: ContractData = contracts[pick[m]]
		var row: String = rows[pick[m]]
		var record: Dictionary = _merc_record(i, row, merc, contract, float(chances[m][pick[m]]))
		var before: int = tap.seen.size()
		var solo: Array[MercenaryData] = [merc]
		var run: ContractRun = await HarnessContracts.run_on_team(contract, solo, "SIM %d %s" % [i, row])
		var errors: Array[String] = []
		errors.assign(tap.seen.slice(before))
		record["errors"] = errors
		if run == null:
			anomalies.append("test %d %s: run did not start" % [i, row])
			continue
		_note_run(record, run)
		if not bool(record["checked"]):
			anomalies.append("test %d %s: no check outcome" % [i, row])
		if not errors.is_empty():
			anomalies.append("test %d %s: %d errors, first %s" % [i, row, errors.size(), errors[0]])
		records.append(record)
	return true


static func _merc_record(i: int, row: String, merc: MercenaryData, contract: ContractData, chance: float) -> Dictionary:
	var record: Dictionary = {"test": i, "row": row, "merc_name": merc.merc_name,
		"tradition": merc.tradition.tradition_name if merc.tradition != null else "none", "chance": chance}
	for key: String in ATTRIBUTES:
		record[key] = int(merc.stats.get(key, 0))
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(contract.assigned_primary_event))
	var knowledge_hits: int = 0
	for entry: Dictionary in parsed.get("knowledges", []):
		if ContractModifiers.knowledge_matches(merc, String(entry.get("name", ""))):
			knowledge_hits += 1
	var tool_hits: int = 0
	for entry: Dictionary in parsed.get("tools", []):
		if ContractModifiers.tool_matches(merc, String(entry.get("name", ""))):
			tool_hits += 1
	var points: int = 0
	for entry: Dictionary in parsed.get("traditions", []):
		if ContractModifiers.tradition_matches(merc, String(entry.get("name", ""))):
			points = int(entry.get("value", 0))
	record["knowledge_hits"] = knowledge_hits
	record["tool_hits"] = tool_hits
	record["tradition_points"] = points
	return record


#The check outcome read as HarnessPlays._note_run reads it.
static func _note_run(record: Dictionary, run: ContractRun) -> void:
	var check: Dictionary = {}
	for outcome: Dictionary in run.outcomes:
		if outcome.has("check"):
			check = outcome
	record["checked"] = not check.is_empty()
	record["verdict"] = run.verdict
	record["success"] = run.verdict == "Succeeded"
	record["attempts"] = int(check.get("attempts", 0))
	record["successes"] = int(check.get("successes", 0))
	record["needed"] = int(check.get("needed", 0))
	record["roller"] = int(check.get("roller", -1))
	record["reward"] = run.reward_paid
	record["casualties"] = run.casualties.size()


#chances[m][c] for merc m on contract c; the contract index per merc that gives the highest sum over every
#permutation, enumerated in lexical order so the first found wins a tie.
static func best_assignment(chances: Array) -> Array[int]:
	var n: int = chances.size()
	var best: Array[int] = []
	var best_sum: float = -INF
	var perm: Array[int] = []
	for k: int in range(n):
		perm.append(k)
	while true:
		var total: float = 0.0
		for m: int in range(n):
			total += float(chances[m][perm[m]])
		if total > best_sum:
			best_sum = total
			best = perm.duplicate()
		if not _next_permutation(perm):
			break
	return best


#Steps perm to the next one in lexical order; false after the last.
static func _next_permutation(perm: Array[int]) -> bool:
	var i: int = perm.size() - 2
	while i >= 0 and perm[i] >= perm[i + 1]:
		i -= 1
	if i < 0:
		return false
	var j: int = perm.size() - 1
	while perm[j] <= perm[i]:
		j -= 1
	var held: int = perm[i]
	perm[i] = perm[j]
	perm[j] = held
	var lo: int = i + 1
	var hi: int = perm.size() - 1
	while lo < hi:
		held = perm[lo]
		perm[lo] = perm[hi]
		perm[hi] = held
		lo += 1
		hi -= 1
	return true


static func summary_lines(records: Array[Dictionary], rows: Array[String], tests: int, skipped: int,
		anomalies: Array[String]) -> Array[String]:
	var out: Array[String] = ["TESTS: run %d skipped %d runs %d anomalies %d" % [tests - skipped, skipped,
		records.size(), anomalies.size()]]
	out.append_array(contract_lines(records, rows))
	out.append_array(attribute_lines(records, rows))
	out.append_array(tradition_lines(records))
	out.append_array(utility_lines(records))
	out.append_array(income_lines(records))
	for k: int in range(mini(anomalies.size(), ANOMALY_LINES)):
		out.append("ANOMALY " + anomalies[k])
	if anomalies.size() > ANOMALY_LINES:
		out.append("ANOMALY and %d more" % (anomalies.size() - ANOMALY_LINES))
	var prefixed: Array[String] = []
	for line: String in out:
		prefixed.append(PREFIX + line)
	return prefixed


static func contract_lines(records: Array[Dictionary], rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for row: String in rows:
		var runs: Array[Dictionary] = _of_row(records, row)
		var won: Array[Dictionary] = _where(runs, true)
		out.append("CONTRACT %s: runs %d successes %d failures %d success %s mean_chance %.1f%% mean_reward_success %.1f"
			% [row, runs.size(), won.size(), runs.size() - won.size(), HarnessPlays.pct(won.size(), runs.size()),
			100.0 * mean(runs, "chance"), mean(won, "reward")])
	return out


#[{stat, success_mean, fail_mean, delta, won, lost}] ranked by delta, highest first; a stable sort keeps ATTRIBUTES order
#on ties. When either group is empty every delta is NAN and the entries keep ATTRIBUTES order.
static func attribute_deltas(records: Array[Dictionary]) -> Array[Dictionary]:
	var won: Array[Dictionary] = _where(records, true)
	var lost: Array[Dictionary] = _where(records, false)
	var valid: bool = not won.is_empty() and not lost.is_empty()
	var out: Array[Dictionary] = []
	for stat: String in ATTRIBUTES:
		var a: float = mean(won, stat)
		var b: float = mean(lost, stat)
		var delta: float = a - b if valid else NAN
		var index: int = out.size()
		if valid:
			index = 0
			while index < out.size() and float(out[index]["delta"]) >= delta:
				index += 1
		out.insert(index, {"stat": stat, "success_mean": a, "fail_mean": b, "delta": delta, "won": won.size(),
			"lost": lost.size()})
	return out


static func delta_text(delta: float) -> String:
	return "n/a" if is_nan(delta) else "%+.2f" % delta


static func attribute_lines(records: Array[Dictionary], rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var ranked: Array[Dictionary] = attribute_deltas(records)
	var valid: bool = not ranked.is_empty() and not is_nan(float(ranked[0]["delta"]))
	for k: int in range(ranked.size()):
		var tag: String = ""
		if valid and k == 0:
			tag = " (most valuable)"
		elif valid and k == ranked.size() - 1:
			tag = " (least valuable)"
		out.append("ATTRIBUTE %d %s: success_mean %.2f fail_mean %.2f delta %s%s" % [k + 1, ranked[k]["stat"],
			float(ranked[k]["success_mean"]), float(ranked[k]["fail_mean"]), delta_text(float(ranked[k]["delta"])), tag])
	for row: String in rows:
		var parts: Array[String] = []
		var by_stat: Dictionary = {}
		for entry: Dictionary in attribute_deltas(_of_row(records, row)):
			by_stat[entry["stat"]] = float(entry["delta"])
		for stat: String in ATTRIBUTES:
			parts.append("%s %s" % [stat, delta_text(float(by_stat.get(stat, NAN)))])
		out.append("ATTRIBUTE DELTAS %s: %s" % [row, " ".join(PackedStringArray(parts))])
	return out


#[{name, runs, successes, rate}] sorted by success rate, then runs, highest first, then by name.
static func tradition_stats(records: Array[Dictionary]) -> Array[Dictionary]:
	var tally: Dictionary = {}
	for r: Dictionary in records:
		var name: String = String(r["tradition"])
		if not tally.has(name):
			tally[name] = {"name": name, "runs": 0, "successes": 0, "rate": 0.0}
		tally[name]["runs"] += 1
		if bool(r["success"]):
			tally[name]["successes"] += 1
	var out: Array[Dictionary] = []
	for name: Variant in tally:
		var entry: Dictionary = tally[name]
		entry["rate"] = float(entry["successes"]) / float(entry["runs"])
		out.append(entry)
	out.sort_custom(_tradition_before)
	return out


static func _tradition_before(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["rate"]), float(b["rate"])):
		return float(a["rate"]) > float(b["rate"])
	if int(a["runs"]) != int(b["runs"]):
		return int(a["runs"]) > int(b["runs"])
	return String(a["name"]) < String(b["name"])


#The first and last of tradition_stats among entries with at least MIN_TRADITION_RUNS runs, else among all.
static func best_worst_tradition(stats: Array[Dictionary]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry: Dictionary in stats:
		if int(entry["runs"]) >= MIN_TRADITION_RUNS:
			pool.append(entry)
	if pool.is_empty():
		pool = stats
	if pool.is_empty():
		return []
	return [pool[0], pool[pool.size() - 1]]


static func tradition_lines(records: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var stats: Array[Dictionary] = tradition_stats(records)
	for entry: Dictionary in stats:
		out.append("TRADITION %s: runs %d successes %d success %s" % [entry["name"], int(entry["runs"]),
			int(entry["successes"]), HarnessPlays.pct(int(entry["successes"]), int(entry["runs"]))])
	var ends: Array[Dictionary] = best_worst_tradition(stats)
	if ends.size() == 2:
		for k: int in range(2):
			out.append("%s TRADITION: %s %s of %d" % ["BEST" if k == 0 else "WORST", ends[k]["name"],
				HarnessPlays.pct(int(ends[k]["successes"]), int(ends[k]["runs"])), int(ends[k]["runs"])])
	return out


#[successes with, runs with, successes without, runs without] split on key > 0.
static func split_counts(records: Array[Dictionary], key: String) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	for r: Dictionary in records:
		var side: int = 0 if int(r[key]) > 0 else 2
		out[side + 1] += 1
		if bool(r["success"]):
			out[side] += 1
	return out


static func utility_lines(records: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for pair: Array in [["KNOWLEDGE", "knowledge_hits"], ["TOOL", "tool_hits"]]:
		var c: Array[int] = split_counts(records, String(pair[1]))
		out.append("%s MATCH: with %s of %d, without %s of %d" % [pair[0], HarnessPlays.pct(c[0], c[1]), c[1],
			HarnessPlays.pct(c[2], c[3]), c[3]])
	return out


#{increased, decreased, flat, paid, unpaid, sinks, mean, min, max}: tests by reward total, runs by reward.
static func income(records: Array[Dictionary]) -> Dictionary:
	var totals: Dictionary = {}
	var out: Dictionary = {"increased": 0, "decreased": 0, "flat": 0, "paid": 0, "unpaid": 0, "sinks": 0, "mean": 0.0,
		"min": 0, "max": 0}
	for r: Dictionary in records:
		var reward: int = int(r["reward"])
		totals[r["test"]] = int(totals.get(r["test"], 0)) + reward
		if reward > 0:
			out["paid"] += 1
		else:
			out["unpaid"] += 1
		if reward < 0:
			out["sinks"] += 1
	if totals.is_empty():
		return out
	var lo: int = 1 << 62
	var hi: int = -(1 << 62)
	var sum: int = 0
	for key: Variant in totals:
		var total: int = int(totals[key])
		if total > 0:
			out["increased"] += 1
		elif total < 0:
			out["decreased"] += 1
		else:
			out["flat"] += 1
		lo = mini(lo, total)
		hi = maxi(hi, total)
		sum += total
	out["mean"] = float(sum) / float(totals.size())
	out["min"] = lo
	out["max"] = hi
	return out


static func income_lines(records: Array[Dictionary]) -> Array[String]:
	var money: Dictionary = income(records)
	return ["INCOME TESTS: increased %d decreased %d flat %d" % [int(money["increased"]), int(money["decreased"]),
		int(money["flat"])], "INCOME RUNS: paid %d unpaid %d" % [int(money["paid"]), int(money["unpaid"])],
		"INCOME PER TEST: mean %.1f min %d max %d" % [float(money["mean"]), int(money["min"]), int(money["max"])],
		"MONEY SINKS: runs with negative reward %d (expected 0)" % int(money["sinks"])]


static func mean(records: Array[Dictionary], key: String) -> float:
	if records.is_empty():
		return 0.0
	var sum: float = 0.0
	for r: Dictionary in records:
		sum += float(r[key])
	return sum / float(records.size())


static func _of_row(records: Array[Dictionary], row: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in records:
		if String(r["row"]) == row:
			out.append(r)
	return out


static func _where(records: Array[Dictionary], success: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in records:
		if bool(r["success"]) == success:
			out.append(r)
	return out


#Header plus one line per record; the errors column holds the count.
static func write_tsv(path: String, records: Array[Dictionary]) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("\t".join(PackedStringArray(COLUMNS)))
	for r: Dictionary in records:
		var cells: PackedStringArray = []
		for column: String in COLUMNS:
			var value: Variant = r.get(column, "")
			if column == "errors":
				cells.append(str((value as Array).size()) if value is Array else "0")
			elif column == "chance":
				cells.append("%.4f" % float(value))
			elif column == "success":
				cells.append("TRUE" if bool(value) else "FALSE")
			else:
				cells.append(str(value))
		file.store_line("\t".join(cells))
	file.close()
	return true

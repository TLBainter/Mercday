class_name CompetitionBatch
extends RefCounted

#Runs a batch of Competition primaries, a fresh party per event, and reports round, War bout and removal numbers.

const EVENT_NAME := "Competition"
const CONTRACT_TYPE := "Entertain"
const PARTY_MIN := 2
const PARTY_MAX := 5
const OUT_MARK := "is out of the competition!"
const FLED_MARK := "FLED: "
const DEPARTED_MARK := "DEPARTED: "
const ROW_FMT := "%-5s %4s %6s %7s %6s %6s %6s %6s %6s %6s %9s"
const HEADINGS: Array = ["Diff", "N", "Party", "Rivals", "PLvl", "RLvl", "Win%", "Rnd%", "Tie%", "War%", "Out/bout"]
const WIDTHS: Array = [5, 4, 6, 7, 6, 6, 6, 6, 6, 6, 9]
const KIND_FMT := "%-14s %7s %6s %6s %10s"
const KIND_HEADINGS: Array = ["Kind", "Rounds", "Won%", "Lost%", "Tie/Draw%"]
const KIND_WIDTHS: Array = [14, 7, 6, 6, 10]

#The run's line callable keeps every line for the removal counts, so the store cannot live in a local.
static var _lines: Array[String] = []


static func run(host: Node, count: int) -> void:
	print("\n====== COMPETITION BATCH ======\n")
	var deck: Array[float] = TestFixtures.build_deck(count)
	print(TestFixtures.deck_line(deck))
	var event: EventData = ContractLibrary.event(EVENT_NAME)
	if event == null:
		print("COMPETITION BATCH FAILED: event '%s' is missing" % EVENT_NAME)
		host.get_tree().quit()
		return
	var places: Array[LocationData] = TestFixtures.wilderness_pool()
	var records: Array[Dictionary] = []
	var skipped: int = 0
	var total: int = deck.size()
	for i: int in range(total):
		TestFixtures.reset_generator_rolls()
		ContractFixtures.reset_party_state()
		var size: int = randi_range(PARTY_MIN, PARTY_MAX)
		var team: Array[MercenaryData] = ContractFixtures.roster_team(size)
		CompetitionResolver.reset()
		var contract: ContractData = ContractGenerator.generate(CONTRACT_TYPE)
		if contract == null:
			skipped += 1
			print("COMPETITION %s/%d SKIPPED: contract generation failed" % [TestFixtures.index(i, total), total])
			continue
		contract.difficulty = deck[i]
		contract.assigned_primary_event = EVENT_NAME
		contract.unsavory = false
		var party_level: float = BatchReport.level_mean(team)
		var contract_run: ContractRun = ContractFixtures.contract_run(contract, team,
			ContractFixtures.contract_location(contract, places, true), _line_fn())
		_lines.clear()
		var outcome: Dictionary = await EventRunner.run(event, contract_run)
		var record: Dictionary = _measure(outcome, deck[i], size, party_level)
		records.append(record)
		print(_event_line(i, total, record))
	CompetitionResolver.reset()
	print_report(records, skipped)
	host.get_tree().quit()


static func _line_fn() -> Callable:
	var fn := func(s: String) -> void:
		print_rich(s)
		_lines.append(s)
	return fn


static func _count_lines(mark: String) -> int:
	var n: int = 0
	for line: String in _lines:
		n += line.count(mark)
	return n


#One event reduced to the numbers the tables read; -1 marks nothing to measure.
static func _measure(outcome: Dictionary, difficulty: float, party: int, party_level: float) -> Dictionary:
	var rivals: Array[MercenaryData] = CompetitionResolver.last_rivals
	var shape: String = "forced"
	var shape_id: int = CompetitionResolver.last_shape
	if shape_id >= 0 and shape_id < CompetitionResolver.SHAPE_NAMES.size():
		shape = CompetitionResolver.SHAPE_NAMES[shape_id]
	var rounds: Array[Dictionary] = []
	var ties: int = 0
	var war_bouts: int = 0
	var war_won: int = 0
	var forfeits: int = 0
	for entry: Dictionary in CompetitionResolver.last_rounds:
		var kind: String = String(entry.get("kind", ""))
		var result: String = String(entry.get("result", ""))
		var forfeit: bool = bool(entry.get("forfeit", false))
		rounds.append({"kind": kind, "result": result, "forfeit": forfeit})
		if forfeit:
			forfeits += 1
			continue
		if result == "tied" or result == "draw":
			ties += 1
		if kind == "War":
			war_bouts += 1
			if result == "won":
				war_won += 1
	return {
		"difficulty": difficulty,
		"party": party,
		"rivals": rivals.size(),
		"party_level": party_level,
		"rival_level": BatchReport.level_mean(rivals),
		"shape": shape,
		"rounds": rounds,
		"rounds_won": int(outcome.get("rounds_won", 0)),
		"rounds_total": int(outcome.get("rounds_total", 0)),
		"win": bool(outcome.get("success", false)),
		"ties": ties,
		"war_bouts": war_bouts,
		"war_won": war_won,
		"forfeits": forfeits,
		"outs": _count_lines(OUT_MARK),
		"fled": _count_lines(FLED_MARK),
		"departed": _count_lines(DEPARTED_MARK),
		"log_file": String(outcome.get("log_file", "")),
	}


static func _event_line(i: int, total: int, record: Dictionary) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in (record["rounds"] as Array):
		var text: String = "%s %s" % [String(entry["kind"]), String(entry["result"])]
		if bool(entry["forfeit"]):
			text += " (forfeit)"
		parts.append(text)
	var line: String = "COMPETITION %s/%d D%.1f party %d L%.1f rivals %d L%s %s: %s -> %d/%d %s out %d fled %d departed %d" % [
		TestFixtures.index(i, total), total, float(record["difficulty"]), int(record["party"]), float(record["party_level"]),
		int(record["rivals"]), TestFixtures.num(float(record["rival_level"])), String(record["shape"]), ", ".join(parts),
		int(record["rounds_won"]), int(record["rounds_total"]), "WIN" if bool(record["win"]) else "LOSS",
		int(record["outs"]), int(record["fled"]), int(record["departed"])]
	var log_file: String = String(record["log_file"])
	if log_file != "":
		line += " log %s" % log_file
	return line


static func print_report(records: Array[Dictionary], skipped: int) -> void:
	print("\n====== COMPETITION BATCH RESULTS ======\n")
	if skipped > 0:
		print("SKIPPED: %d event(s) lost to a failed contract generation" % skipped)
	if records.is_empty():
		print("COMPETITION BATCH: no event completed")
		return
	print(_row(HEADINGS))
	print(BatchReport.rule(WIDTHS, ROW_FMT))
	for difficulty: float in TestFixtures.difficulties(records):
		print(_row(_stats_row("%.1f" % difficulty, TestFixtures.at_difficulty(records, difficulty))))
	print(_row(_stats_row("ALL", records)))
	_print_kinds(records)
	_print_shapes(records)
	_print_removals(records)
	print("\nENCOUNTER LOGS: %s (%s)" % [
		EncounterLogger.LOG_DIR, ProjectSettings.globalize_path(EncounterLogger.LOG_DIR)])


#Rnd% and Tie% share the rounds played; War% and Out/bout read only the contested War bouts.
static func _stats_row(label: String, rows: Array[Dictionary]) -> Array:
	var total: int = _sum(rows, "rounds_total")
	var bouts: int = _sum(rows, "war_bouts")
	return [
		label,
		str(rows.size()),
		"%.1f" % TestFixtures.mean(rows, "party"),
		"%.1f" % TestFixtures.mean(rows, "rivals"),
		TestFixtures.num(TestFixtures.mean_valid(rows, "party_level")),
		TestFixtures.num(TestFixtures.mean_valid(rows, "rival_level")),
		TestFixtures.pct(TestFixtures.rate(rows, "win")),
		TestFixtures.pct(BatchReport.share(_sum(rows, "rounds_won"), total)),
		TestFixtures.pct(BatchReport.share(_sum(rows, "ties"), total)),
		TestFixtures.pct(BatchReport.share(_sum(rows, "war_won"), bouts)),
		TestFixtures.ratio(BatchReport.per(_sum(rows, "outs"), bouts)),
	]


#Forfeited rounds stay out: they measure the team sizes, not the kind.
static func _print_kinds(records: Array[Dictionary]) -> void:
	var tallies: Dictionary = {}
	for kind: String in CompetitionResolver.KINDS:
		tallies[kind] = [0, 0, 0]
	for record: Dictionary in records:
		for entry: Dictionary in (record["rounds"] as Array):
			if bool(entry["forfeit"]):
				continue
			var key: String = String(entry["kind"])
			if not tallies.has(key):
				tallies[key] = [0, 0, 0]
			var tally: Array = tallies[key]
			var result: String = String(entry["result"])
			if result == "won":
				tally[0] = int(tally[0]) + 1
			elif result == "lost":
				tally[1] = int(tally[1]) + 1
			else:
				tally[2] = int(tally[2]) + 1
	print("\n--- ROUNDS BY KIND (contested rounds) ---\n")
	print(KIND_FMT % KIND_HEADINGS)
	print(BatchReport.rule(KIND_WIDTHS, KIND_FMT))
	var sums: Array = [0, 0, 0]
	for key: String in tallies.keys():
		var tally: Array = tallies[key]
		for p: int in range(3):
			sums[p] = int(sums[p]) + int(tally[p])
		print(_kind_row(key, tally))
	print(_kind_row("ALL", sums))


static func _kind_row(label: String, tally: Array) -> String:
	var n: int = int(tally[0]) + int(tally[1]) + int(tally[2])
	return KIND_FMT % [label, str(n), TestFixtures.pct(BatchReport.share(int(tally[0]), n)),
		TestFixtures.pct(BatchReport.share(int(tally[1]), n)), TestFixtures.pct(BatchReport.share(int(tally[2]), n))]


static func _print_shapes(records: Array[Dictionary]) -> void:
	var shapes: Dictionary = {}
	for label: String in CompetitionResolver.SHAPE_NAMES:
		shapes[label] = 0
	var forfeits: int = 0
	var rounds: int = 0
	for record: Dictionary in records:
		var key: String = String(record["shape"])
		shapes[key] = int(shapes.get(key, 0)) + 1
		forfeits += int(record["forfeits"])
		rounds += int(record["rounds_total"])
	var parts: Array[String] = []
	for key: String in shapes.keys():
		parts.append("%s %d" % [key, int(shapes[key])])
	print("\nSHAPES: %s" % ", ".join(parts))
	print("FORFEITS: %d of %d rounds (%s)" % [forfeits, rounds, TestFixtures.pct(BatchReport.share(forfeits, rounds))])


static func _print_removals(records: Array[Dictionary]) -> void:
	var outs: int = _sum(records, "outs")
	var bouts: int = _sum(records, "war_bouts")
	print("REMOVALS: %d out of the competition in %d War bouts (%s per bout), fled %d, departed %d" % [
		outs, bouts, TestFixtures.ratio(BatchReport.per(outs, bouts)), _sum(records, "fled"), _sum(records, "departed")])


static func _row(cells: Array) -> String:
	return ROW_FMT % cells


static func _sum(rows: Array[Dictionary], key: String) -> int:
	var total: int = 0
	for record: Dictionary in rows:
		total += int(record[key])
	return total

class_name OddsProbe

#Calibration probe: the odds OddsEstimator predicts against the verdict the same contract returns.
#Run: godot --headless --path . -- --odds-probe=200 --auto-seed=7

const BUCKETS := 10
const TEAM_MIN := 2
const TEAM_MAX := 5
const LEVEL_MIN := 1
const LEVEL_MAX := 20
const DEFAULT_SEED := 4242


static func run(count: int) -> bool:
	var n: int = maxi(1, count)
	ContractResourceBuilder.build_all()
	var base: int = HarnessFlags.auto_seed(DEFAULT_SEED)
	var types: Array[String] = ContractLibrary.contract_type_names()
	var rows: Array[Dictionary] = []
	for i: int in range(BUCKETS):
		rows.append({"runs": 0, "predicted": 0.0, "won": 0})
	var brier: float = 0.0
	var done: int = 0
	var verdicts: int = 0
	var t0: int = Time.get_ticks_msec()
	for i: int in range(n):
		var record: Dictionary = await _trial(base + i, types)
		if record.is_empty():
			continue
		done += 1
		if String(record["verdict"]) != "":
			verdicts += 1
		var predicted: int = int(record["predicted"])
		var won: int = 1 if String(record["verdict"]) == "Succeeded" else 0
		var bucket: Dictionary = rows[clampi(int(predicted / 10.0), 0, BUCKETS - 1)]
		bucket["runs"] = int(bucket["runs"]) + 1
		bucket["predicted"] = float(bucket["predicted"]) + float(predicted)
		bucket["won"] = int(bucket["won"]) + won
		var p: float = float(predicted) / 100.0
		brier += (p - float(won)) * (p - float(won))
	CampaignClock.reset()
	_print_table(rows, done, base, brier, Time.get_ticks_msec() - t0)
	var res: Dictionary = {"pass": 0, "fail": 0}
	TestFixtures.check(res, "the probe ran every contract", done == n, "%d of %d" % [done, n])
	TestFixtures.check(res, "every contract returned a verdict", verdicts == done,
		"%d of %d" % [verdicts, done])
	TestFixtures.check(res, "the predictions spread over more than one band", _filled(rows) > 1,
		"%d bands" % _filled(rows))
	return TestFixtures.summarize(res, "ODDS PROBE")


#One seeded contract: a fresh team, the predicted odds, then the same contract actually run.
static func _trial(seed_value: int, types: Array[String]) -> Dictionary:
	if types.is_empty():
		return {}
	TestFixtures.reset_generator_rolls()
	seed(seed_value)
	var size: int = randi_range(TEAM_MIN, TEAM_MAX)
	var level: int = randi_range(LEVEL_MIN, LEVEL_MAX)
	var type_name: String = types[randi() % types.size()]
	var team: Array[MercenaryData] = TestFixtures.generated_team(size, level, true)
	TestFixtures.set_roster(team)
	var contract: ContractData = ContractGenerator.generate(type_name)
	if contract == null:
		return {}
	var predicted: int = OddsEstimator.for_contract(contract, team)
	var contract_run: ContractRun = await ContractManager.run(contract, team, Callable())
	return {"predicted": predicted, "verdict": contract_run.verdict, "type": type_name,
		"size": size, "level": level}


static func _print_table(rows: Array[Dictionary], n: int, base: int, brier: float, ms: int) -> void:
	print("\n====== ODDS PROBE ======\n")
	print("contracts %d, seed base %d, %.1f s" % [n, base, float(ms) / 1000.0])
	print("band       runs   predicted    realized      gap")
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var runs: int = int(row["runs"])
		if runs == 0:
			print("%2d-%2d %9d           -           -        -" % [i * 10, i * 10 + 9, 0])
			continue
		var predicted: float = float(row["predicted"]) / float(runs)
		var realized: float = float(int(row["won"])) / float(runs) * 100.0
		print("%2d-%2d %9d %10.1f%% %11.1f%% %+8.1f" % [i * 10, i * 10 + 9, runs,
			predicted, realized, realized - predicted])
	if n > 0:
		print("BRIER: %.4f over %d contracts" % [brier / float(n), n])


static func _filled(rows: Array[Dictionary]) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if int(row["runs"]) > 0:
			count += 1
	return count

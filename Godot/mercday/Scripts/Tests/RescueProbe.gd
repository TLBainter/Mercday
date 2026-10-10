class_name RescueProbe

#Rescue battle probe: how often a dungeon rescue succeeds, how it ends and how loud it gets.
#Run: godot --headless --path . -- --rescue-probe --probe-levels=1,9,19,29,40 --probe-n=1000

const DEFAULT_LEVELS: Array[int] = [1, 9, 19, 29, 40]
const COUNT_FORMULA := "max(2, party.merc_count * difficulty_factor)"
const PARTY_SIZE := 4
const PROGRESS_STEP := 100
const BANDS := 5
const ODDS_EDGES: Array[float] = [0.25, 0.4, 0.5, 0.65, 0.8, 1.0, 1.25, 1.5, 2.0, 1000.0]

#Outcome keys added into a row counter, written as row key to outcome key.
const SUM_KEYS: Dictionary = {"rounds": "rounds", "enemies": "enemy_count", "picks": "picks",
	"pick_fails": "pick_fails", "party_dead": "party_dead", "party_exits": "party_exits",
	"go": "go_count", "stay": "stay_count", "gate_runs": "gate_runs",
	"escort_turns": "escort_turns", "withdraw_turns": "withdraw_turns",
	"fall_back_turns": "fall_back_turns", "shelter_turns": "shelter_turns",
	"hide_turns": "hide_turns", "door_opens": "door_opens", "detours": "detours",
	"ambushes": "ambushes", "block_wait_turns": "block_wait_turns"}

#Outcome flags that bump a row counter by one when true, written as row key to outcome key.
const FLAG_KEYS: Dictionary = {"success": "success", "alarms": "alarm",
	"exits": "captive_exited", "freed": "freed", "aborted": "aborted",
	"captive_acted": "captive_acted", "abandoned": "abandoned", "hopeless": "gate_hopeless"}

static var _event_row: EventData = null
static var _event_read: bool = false


static func run() -> bool:
	ContractResourceBuilder.build_all()
	var levels := BattleHarness.probe_levels(DEFAULT_LEVELS)
	var n := maxi(2, BattleHarness.arg_int("--probe-n", 1000))
	seed(BattleHarness.arg_int("--probe-seed", 4242))
	var saved_level := MercGenerator.forced_level
	var saved_logs := EncounterLogger.suppressed
	var saved_banking := CriticalSuccessSystem.banking
	EncounterLogger.suppressed = true
	#A rolled critical would hand a probe merc a real reward; banking parks it instead.
	CriticalSuccessSystem.banking = true
	_event_row = null
	_event_read = false
	var forced: String = ContractLibrary.config().rescue_mode
	var done := 0
	for level: int in levels:
		await _run_level(level, n, forced)
		done += 1
	MercGenerator.forced_level = saved_level
	EncounterLogger.suppressed = saved_logs
	CriticalSuccessSystem.banking = saved_banking
	randomize()
	var res := {"pass": 0, "fail": 0}
	TestFixtures.check(res, "the probe ran every requested level", done == levels.size(),
		"%d levels" % done)
	return TestFixtures.summarize(res, "RESCUE PROBE")


static func _run_level(level: int, n: int, forced: String) -> void:
	var t0 := Time.get_ticks_msec()
	var acc := _new_acc()
	for i: int in range(n):
		var mode := _mode_for(i, n, forced)
		var ro: Dictionary = await _trial(level, i, mode)
		if ro.is_empty():
			acc["skipped"] = int(acc["skipped"]) + 1
		else:
			_tally(acc, mode, ro)
		if (i + 1) % PROGRESS_STEP == 0:
			print("RESCUE PROBE L=%d trial %d/%d" % [level, i + 1, n])
	_print_level(level, n, acc, Time.get_ticks_msec() - t0)


static func _mode_for(index: int, n: int, forced: String) -> String:
	if forced == RescueSystem.MODE_COMBAT or forced == RescueSystem.MODE_STEALTH:
		return forced
	return RescueSystem.MODE_COMBAT if index < int(n / 2.0) else RescueSystem.MODE_STEALTH


static func _new_acc() -> Dictionary:
	return {"combat": _new_mode(), "stealth": _new_mode(), "bands": {}, "skipped": 0}


static func _new_mode() -> Dictionary:
	var row: Dictionary = {"n": 0, "stealthy": 0, "with_combat": 0, "failed": 0, "reasons": {},
		"samples": []}
	for key: String in SUM_KEYS:
		row[key] = 0
	for key: String in FLAG_KEYS:
		row[key] = 0
	return row


static func _band_row(acc: Dictionary, band: int, mode: String) -> Dictionary:
	var bands: Dictionary = acc["bands"]
	if not bands.has(band):
		bands[band] = {"combat": _new_mode(), "stealth": _new_mode()}
	return (bands[band] as Dictionary)[mode]


static func _tally(acc: Dictionary, mode: String, ro: Dictionary) -> void:
	var band := clampi(floori(float(ro.get("difficulty", 1.0))), 1, BANDS)
	_count(acc[mode] as Dictionary, ro)
	_count(_band_row(acc, band, mode), ro)


static func _count(row: Dictionary, ro: Dictionary) -> void:
	row["n"] = int(row["n"]) + 1
	for key: String in SUM_KEYS:
		row[key] = int(row[key]) + int(ro.get(SUM_KEYS[key], 0))
	for key: String in FLAG_KEYS:
		if bool(ro.get(FLAG_KEYS[key], false)):
			row[key] = int(row[key]) + 1
	var result: String = String(ro.get("result", ""))
	if result == RescueSystem.RESULT_STEALTH:
		row["stealthy"] = int(row["stealthy"]) + 1
	elif result == RescueSystem.RESULT_COMBAT:
		row["with_combat"] = int(row["with_combat"]) + 1
	else:
		row["failed"] = int(row["failed"]) + 1
	var reason: String = String(ro.get("reason", ""))
	if reason != "":
		var reasons: Dictionary = row["reasons"]
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	if float(ro.get("start_odds", -1.0)) >= 0.0:
		(row["samples"] as Array).append([float(ro["start_odds"]), float(ro["min_odds"]),
			1 if bool(ro.get("success", false)) else 0, int(ro.get("party_dead", 0))])


#One rescue battle; {} when the dungeon carried no cell block or the teams failed to build.
static func _trial(level: int, index: int, mode: String) -> Dictionary:
	TestFixtures.reset_generator_rolls()
	var base := index * (PARTY_SIZE + 1)
	var party: Array[MercenaryData] = RescueTests.leveled_party(level, PARTY_SIZE, base)
	var held: Array[MercenaryData] = RescueTests.leveled_party(level, 1, base + PARTY_SIZE)
	if party.is_empty() or held.is_empty():
		return {}
	var captive: MercenaryData = held[0]
	var d: float = ContractGenerator.roll_difficulty()
	var enemies: Array[MercenaryData] = _captors(party, d)
	if enemies.is_empty():
		return {}
	var ctx := GenerationContext.new()
	ctx.difficulty = d
	ctx.team_size_a = party.size() + 1
	ctx.team_size_b = enemies.size()
	ctx.min_cell_blocks = 1
	var field: BattlefieldArea = BattlefieldArea.generate_random(null, ctx, "Dungeon",
		DataManager.get_random_area("Dungeon"))
	if field == null:
		return {}
	var state: BattleState = RescueTests.rescue_state(party, captive, enemies, field, mode, d)
	state.flee_enabled = false
	if not RescueSystem.is_active(state):
		return {}
	await AutoBattle.run_battle(state, Callable(), "Rescue")
	var ro: Dictionary = RescueOutcome.outcome(state)
	if ro.is_empty():
		return {}
	ro["difficulty"] = d
	ro["enemy_count"] = enemies.size()
	return ro


static func _captors(party: Array[MercenaryData], d: float) -> Array[MercenaryData]:
	if not _event_read:
		_event_row = ContractLibrary.event(RescueSystem.EVENT_NAME)
		_event_read = true
	var req := OpponentRequest.new()
	req.source = RescueTests.CREW
	req.count_formula = COUNT_FORMULA
	if _event_row != null:
		if _event_row.enemy != "":
			req.source = _event_row.enemy
		if _event_row.enemy_counter != "":
			req.count_formula = _event_row.enemy_counter
	req.party = party
	req.difficulty = d
	req.extra_ctx = {"bad_luck_roll": 0}
	req.tag = RescueSystem.EVENT_NAME
	var out: Array[MercenaryData] = []
	out.assign(OpponentGenerator.generate(req))
	return out


static func _pct(part: int, total: int) -> float:
	return 0.0 if total <= 0 else 100.0 * float(part) / float(total)


static func _mean(total: int, count: int) -> float:
	return 0.0 if count <= 0 else float(total) / float(count)


static func _print_level(level: int, n: int, acc: Dictionary, ms: int) -> void:
	var combat: Dictionary = acc["combat"]
	var stealth: Dictionary = acc["stealth"]
	var head: String = "RESCUE PROBE L=%d n=%d (combat %d, stealth %d) policy %s, withdraw %s, melee %s"
	head += ", careful %s, caged leave %s, tune %s"
	print(head % [level, n,
		int(combat["n"]), int(stealth["n"]), RescueTactics.policy,
		"on" if RescueTactics.withdraw_enabled else "off", RescueTactics.melee_rule,
		"on" if RescueTactics.careful else "off",
		"on" if RescueTactics.caged_wounded_leave else "off", RescueTune.tune_text()])
	print("  combat: success %d (%.1f%%), failed %d (%.1f%%), mean rounds %.1f, mean enemies %.1f" % [
		int(combat["success"]), _pct(int(combat["success"]), int(combat["n"])),
		int(combat["failed"]), _pct(int(combat["failed"]), int(combat["n"])),
		_mean(int(combat["rounds"]), int(combat["n"])),
		_mean(int(combat["enemies"]), int(combat["n"]))])
	print("  stealth: stealthy %d (%.1f%%), with combat %d (%.1f%%), failed %d (%.1f%%), alarms %d, mean rounds %.1f" % [
		int(stealth["stealthy"]), _pct(int(stealth["stealthy"]), int(stealth["n"])),
		int(stealth["with_combat"]), _pct(int(stealth["with_combat"]), int(stealth["n"])),
		int(stealth["failed"]), _pct(int(stealth["failed"]), int(stealth["n"])),
		int(stealth["alarms"]), _mean(int(stealth["rounds"]), int(stealth["n"]))])
	print("  by band: %s" % _band_text(acc))
	print("  gate: freed %d/%d, captive exits %d, picks %d, failed picks %d, skipped %d, ms %d" % [
		int(combat["freed"]) + int(stealth["freed"]), int(combat["n"]) + int(stealth["n"]),
		int(combat["exits"]) + int(stealth["exits"]),
		int(combat["picks"]) + int(stealth["picks"]),
		int(combat["pick_fails"]) + int(stealth["pick_fails"]), int(acc["skipped"]), ms])
	for mode: String in ["combat", "stealth"]:
		var row: Dictionary = acc[mode]
		print("  %s reasons: %s" % [mode, _reason_text(row)])
		print("  %s party: mean dead %.2f, mean exited %.2f, abandoned %d" % [mode,
			_mean(int(row["party_dead"]), int(row["n"])), _mean(int(row["party_exits"]), int(row["n"])),
			int(row["abandoned"])])
		var fmt: String = "  %s tactics: go %d, stay %d, gate runs %d, escort turns %d"
		fmt += ", withdraw turns %d, fall back turns %d, hopeless %d"
		fmt += ", shelter turns %d, hide turns %d, door opens %d"
		print(fmt % [mode, int(row["go"]), int(row["stay"]), int(row["gate_runs"]),
			int(row["escort_turns"]), int(row["withdraw_turns"]), int(row["fall_back_turns"]),
			int(row["hopeless"]), int(row["shelter_turns"]), int(row["hide_turns"]),
			int(row["door_opens"])])
		print("  %s blocked: wait turns %d, detour turns %d, ambushes %d, aborted %d, captive acted %d" % [mode,
			int(row["block_wait_turns"]), int(row["detours"]), int(row["ambushes"]), int(row["aborted"]),
			int(row["captive_acted"])])
		print("  %s start odds: %s" % [mode, _odds_bands(row, 0)])
		print("  %s lowest odds: %s" % [mode, _odds_bands(row, 1)])


#Fights per odds band with their success rate and mean party dead; col 0 = first odds, 1 = lowest odds.
static func _odds_bands(row: Dictionary, col: int) -> String:
	var parts: Array[String] = []
	var low: float = 0.0
	for high: float in ODDS_EDGES:
		var n: int = 0
		var wins: int = 0
		var dead: int = 0
		for s: Array in row["samples"] as Array:
			if float(s[col]) < low or float(s[col]) >= high:
				continue
			n += 1
			wins += int(s[2])
			dead += int(s[3])
		if n > 0:
			parts.append("%d-%d%% n %d win %.0f%% dead %.1f" % [roundi(low * 100.0), roundi(minf(high, 9.99) * 100.0),
				n, _pct(wins, n), _mean(dead, n)])
		low = high
	return "none" if parts.is_empty() else "; ".join(parts)


#Battle end reason codes of one mode, commonest first.
static func _reason_text(row: Dictionary) -> String:
	var reasons: Dictionary = row["reasons"]
	var codes: Array[String] = []
	for key: Variant in reasons:
		codes.append(String(key))
	codes.sort_custom(func(a: String, b: String) -> bool: return int(reasons[a]) > int(reasons[b]))
	var parts: Array[String] = []
	for code: String in codes:
		parts.append("%s %d (%.1f%%)" % [code, int(reasons[code]),
			_pct(int(reasons[code]), int(row["n"]))])
	return "none" if parts.is_empty() else ", ".join(parts)


static func _band_text(acc: Dictionary) -> String:
	var bands: Dictionary = acc["bands"]
	var parts: Array[String] = []
	for band: int in range(1, BANDS + 1):
		if not bands.has(band):
			continue
		var row: Dictionary = bands[band]
		var c: Dictionary = row["combat"]
		var s: Dictionary = row["stealth"]
		parts.append("B%d combat s/f %d/%d stealth s/c/f %d/%d/%d" % [band, int(c["success"]),
			int(c["failed"]), int(s["stealthy"]), int(s["with_combat"]), int(s["failed"])])
	return "none" if parts.is_empty() else " ".join(parts)

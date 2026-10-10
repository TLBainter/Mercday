class_name EventContractTests

#Event style contracts: the four stage 6 Events.tsv rows, multipliers, Prison Break, Chase, Time, Consequence, dispatch.
#Run: godot --headless --path . -- --eventcontract-tests

const FOUR: Array[String] = ["Fight Bandits", "Military Battle", "Prison Break", "Chase"]
const CHASE := "Chase"
const BANDITS := "Fight Bandits"
const CAT_CONTRACT := "Cat Stuck in Tree!"
const PLAIN := "EctPlain"
const FAIL_ROLL := 99
const GUILD_LINE := "CONTRACT CONSEQUENCE: guild opinion"
const RETRY_LINE := "CONTRACT CONSEQUENCE: retry has no meaning for an event, ignored"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	var saved_logs: bool = EncounterLogger.suppressed
	_case_rows(res)
	_case_gen(res)
	_case_factor(res)
	_case_etb(res)
	await _case_prison(res)
	_case_target(res)
	await _case_chase(res)
	await _case_time(res)
	await _case_consequence(res)
	_case_dispatch(res)
	ChaseResolver.reset()
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	CampaignClock.reset()
	EncounterLogger.suppressed = saved_logs
	return TestFixtures.summarize(res, "EVENTCONTRACT")


static func _contract(event_name: String, cell: String = "", minutes: int = 0,
		consequence: String = "") -> ContractData:
	var contract := ContractData.new()
	contract.contract_name = "ECT " + event_name
	contract.style = "event"
	contract.completion = "event:" + event_name
	contract.assigned_primary_event = event_name
	contract.contract_level = 5
	contract.difficulty = 2.0
	contract.event_config = cell
	contract.time_minutes = minutes
	contract.consequence = consequence
	return contract


static func _team(n: int, prefix: String, extras: Dictionary = {}) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for i: int in range(n):
		out.append(TestFixtures.fixed_merc("%s %d" % [prefix, i + 1], extras))
	return out


static func _run(contract: ContractData, team: Array[MercenaryData], leader_uid: int = -1) -> ContractRun:
	return ContractRun.make(contract, team, Callable(), leader_uid)


static func _sheet_row(event_name: String) -> Dictionary:
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Event Name", "")) == event_name:
			return row
	return {}


static func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		out.assign(value)
	return out


static func _case_rows(res: Dictionary) -> void:
	var missing: Array[String] = []
	for event_name: String in FOUR:
		if ContractLibrary.event(event_name) == null:
			missing.append(event_name)
	TestFixtures.check(res, "rows: four present", missing.is_empty(), "missing %s" % str(missing))

	var military: Dictionary = _sheet_row("Military Battle")
	TestFixtures.check(res, "rows: military battle mercs",
		String(military.get("Enemy", "")) == "Mercs" and String(military.get("Map", "")) == "Location",
		"enemy '%s' map '%s'" % [String(military.get("Enemy", "")), String(military.get("Map", ""))])

	var filled: Array[String] = []
	for event_name: String in FOUR:
		var row: Dictionary = _sheet_row(event_name)
		if row.is_empty() or String(row.get("Possible Contracts", "")).strip_edges() != "" \
				or String(row.get("Trigger", "")).strip_edges() != "":
			filled.append(event_name)
	var prison_places: String = String(_sheet_row("Prison Break").get("Possible Locations", "")).strip_edges()
	TestFixtures.check(res, "rows: blank contracts and trigger", filled.is_empty() and prison_places == "",
		"filled %s prison locations '%s'" % [str(filled), prison_places])

	var warnings: Array[String] = []
	for event_name: String in FOUR:
		var data: EventData = ContractLibrary.event(event_name)
		if data == null:
			warnings.append("%s missing" % event_name)
			continue
		warnings.append_array(ContractDataValidator.validate_event(data, _sheet_row(event_name)))
	TestFixtures.check(res, "rows: validate clean", warnings.is_empty(), "warnings %s" % str(warnings))

	var chase: EventData = ContractLibrary.event(CHASE)
	TestFixtures.check(res, "rows: chase is chase", chase != null and chase.is_chase() and not chase.is_battle(),
		"chase %s" % ("null" if chase == null else chase.success_formula))
	var bandits: EventData = ContractLibrary.event(BANDITS)
	TestFixtures.check(res, "rows: fight bandits battle",
		bandits != null and bandits.is_battle() and bandits.map_rule == "Location",
		"bandits %s" % ("null" if bandits == null else "%s map %s" % [bandits.success_formula, bandits.map_rule]))


static func _case_gen(res: Dictionary) -> void:
	var row: ContractData = ContractLibrary.contract(CAT_CONTRACT)
	var assigned: String = "<no row>"
	if row != null:
		row.style = "event"
		row.completion = "event:" + CHASE
		var made: ContractData = ContractGenerator.generate_row(row, 5, 2.0, "")
		assigned = made.assigned_primary_event if made != null else "<null>"
	TestFixtures.check(res, "gen: event branch primary", assigned == CHASE, "assigned '%s'" % assigned)


static func _case_factor(res: Dictionary) -> void:
	var cases: Array = [
		["factor: fight bandits blank 1", BANDITS, "", 1.0],
		["factor: fight bandits 2", BANDITS, "bandits=2", 2.0],
		["factor: off grid default", BANDITS, "bandits=1.3", 1.0],
		["factor: above max default", BANDITS, "bandits=5", 1.0],
		["factor: military 0.5", "Military Battle", "soldiers=0.5", 0.5],
	]
	for c: Array in cases:
		var got: float = EventConfig.counter_factor(String(c[1]), String(c[2]))
		TestFixtures.check(res, String(c[0]), not is_nan(got) and is_equal_approx(got, float(c[3])),
			"factor %s want %s" % [str(got), str(c[3])])
	var nan_cases: Array = [
		["factor: chase nan", CHASE, "chase=vehicle"],
		["factor: prison nan", "Prison Break", ""],
		["factor: ambush nan", "Ambush", ""],
	]
	for c: Array in nan_cases:
		var got: float = EventConfig.counter_factor(String(c[1]), String(c[2]))
		TestFixtures.check(res, String(c[0]), is_nan(got), "factor %s" % str(got))


static func _case_etb(res: Dictionary) -> void:
	var bandits: EventData = ContractLibrary.event(BANDITS)
	var doubled: int = EnemyTeamBuilder.build(bandits, _run(_contract(BANDITS, "bandits=2"), _team(3, "Etb")), 0).size()
	TestFixtures.check(res, "etb: fight bandits x2 count 6", doubled == 6, "count %d" % doubled)
	var plain: int = EnemyTeamBuilder.build(bandits, _run(_contract(BANDITS, ""), _team(3, "Etb")), 0).size()
	TestFixtures.check(res, "etb: fight bandits blank count 3", plain == 3, "count %d" % plain)
	var battle: EventData = ContractLibrary.event("Battle")
	var classic: int = EnemyTeamBuilder.build(battle, _run(_contract("Battle", ""), _team(3, "Etb")), 0).size()
	TestFixtures.check(res, "etb: battle unchanged count 5", classic == 5, "count %d" % classic)


static func _case_prison(res: Dictionary) -> void:
	var event: EventData = ContractLibrary.event(RescueContractBuilder.PRISON_EVENT)
	var contract: ContractData = _contract(RescueContractBuilder.PRISON_EVENT)
	contract.location_a = "Aerdis"
	var team: Array[MercenaryData] = _team(3, "Jailer")
	var setup_run: ContractRun = _run(contract, team)
	var setup: Dictionary = RescueContractBuilder.prison_setup(setup_run, contract, event)
	var mode: String = String(setup.get("mode", ""))
	var foes: Array = setup.get("enemies", [])
	var record: Dictionary = setup.get("record", {"unset": true})
	var kind: String = String(setup.get("kind", ""))
	TestFixtures.check(res, "prison: setup shape",
		setup.get("captive", null) != null and kind == RescueContractBuilder.KIND_PRISONER and record.is_empty()
		and not foes.is_empty() and (mode == RescueSystem.MODE_COMBAT or mode == RescueSystem.MODE_STEALTH),
		"kind '%s' record %s enemies %d mode '%s'" % [kind, str(record), foes.size(), mode])
	TestFixtures.check(res, "prison: setup log", TestFixtures.has_line(setup_run.log_lines, "PRISON BREAK: "),
		"lines %d" % setup_run.log_lines.size())

	var captive: MercenaryData = TestFixtures.fixed_merc("Prisoner")
	var freed_run: ContractRun = _run(contract, team)
	RescueContractBuilder.complete(freed_run, {"captive": captive, "success": true},
		RescueContractBuilder.KIND_PRISONER)
	TestFixtures.check(res, "prison: complete freed no release",
		TestFixtures.has_line(freed_run.log_lines, "PRISONER FREED: ") and freed_run.rescued.is_empty(),
		"lines %s rescued %d" % [str(freed_run.log_lines), freed_run.rescued.size()])
	var lost_run: ContractRun = _run(contract, team)
	RescueContractBuilder.complete(lost_run, {"captive": captive, "success": false, "captive_alive": false},
		RescueContractBuilder.KIND_PRISONER)
	TestFixtures.check(res, "prison: complete lost", TestFixtures.has_line(lost_run.log_lines, "PRISONER LOST: "),
		"lines %s" % str(lost_run.log_lines))
	var held_run: ContractRun = _run(contract, team)
	RescueContractBuilder.complete(held_run, {"captive": captive, "success": false, "captive_alive": true},
		RescueContractBuilder.KIND_PRISONER)
	TestFixtures.check(res, "prison: complete held", TestFixtures.has_line(held_run.log_lines, "PRISONER HELD: "),
		"lines %s" % str(held_run.log_lines))

	var gate_run: ContractRun = _run(contract, team)
	var gate_out: Dictionary = EventRunner.outcome(event)
	var built: Dictionary = BattleEventResolver._build_enemies(event, gate_run, team, {}, gate_out)
	var rescue: Dictionary = built.get("rescue", {})
	TestFixtures.check(res, "prison: battle gate routes",
		String(rescue.get("kind", "")) == RescueContractBuilder.KIND_PRISONER,
		"rescue kind '%s'" % String(rescue.get("kind", "")))

	var party: Array[MercenaryData] = []
	var previous_level: int = MercGenerator.forced_level
	MercGenerator.forced_level = 5
	for i: int in range(3):
		var merc: MercenaryData = MercGenerator.generate(60 + i)
		if merc != null:
			party.append(merc)
	MercGenerator.forced_level = previous_level
	var battle_run: ContractRun = _run(contract, party)
	var saved: bool = EncounterLogger.suppressed
	EncounterLogger.suppressed = true
	var out: Dictionary = await BattleEventResolver.resolve(event, battle_run)
	EncounterLogger.suppressed = saved
	var prisoner_lines: int = TestFixtures.count_lines(battle_run.log_lines, "PRISONER ", true)
	TestFixtures.check(res, "prison: settle passes kind",
		out.has("rescue") and prisoner_lines == 1 and battle_run.rescued.is_empty(),
		"has rescue %s prisoner lines %d rescued %d" % [str(out.has("rescue")), prisoner_lines,
			battle_run.rescued.size()])


static func _case_target(res: Dictionary) -> void:
	var party: Array[MercenaryData] = _team(3, "Seeker")
	var contract: ContractData = _contract(CHASE)
	var npc: OpponentRequest = ContractTarget.request("npc:Bandit Leader", party, contract)
	TestFixtures.check(res, "target: npc source", npc.source == "Bandit Leader", "source '%s'" % npc.source)
	var monster: OpponentRequest = ContractTarget.request("monster:Wolf", party, contract)
	TestFixtures.check(res, "target: monster falls back to Mercs", monster.source == "Mercs",
		"source '%s'" % monster.source)
	var fixed: OpponentRequest = ContractTarget.request("random:level=7, count=2", party, contract)
	TestFixtures.check(res, "target: fixed level and count", fixed.fixed_level == 7 and fixed.count == 2,
		"level %d count %d" % [fixed.fixed_level, fixed.count])
	var whole: OpponentRequest = ContractTarget.request("random:level=party, count=party", party, contract)
	TestFixtures.check(res, "target: party count", whole.count == 3, "count %d" % whole.count)


#One Chase as the contract primary against a single forced quarry; the manager path also fires Time and Consequence.
static func _chase(team_speed: float, target_speed: float, cell: String = "", minutes: int = 0,
		consequence: String = "", with_leader: bool = true, via_manager: bool = false) -> Dictionary:
	var team: Array[MercenaryData] = _team(2, "Runner", {"speed": team_speed, "pace": 0})
	var contract: ContractData = _contract(CHASE, cell, minutes, consequence)
	var contract_run: ContractRun = _run(contract, team, team[0].merc_uid if with_leader else -1)
	var quarry: Array[MercenaryData] = [TestFixtures.fixed_merc("Quarry", {"speed": target_speed, "pace": 0})]
	ChaseResolver.forced_target.assign(quarry)
	var event: EventData = ContractLibrary.event(CHASE)
	var out: Dictionary = {}
	if via_manager:
		await ContractManager.run_one_event(contract_run, event, CHASE, true)
		if not contract_run.outcomes.is_empty():
			out = contract_run.outcomes[0]
	else:
		out = await EventRunner.run(event, contract_run)
	ChaseResolver.reset()
	return {"run": contract_run, "out": out, "team": team}


static func _case_chase(res: Dictionary) -> void:
	var gap_run: ContractRun = _run(null, _team(1, "Gap"))
	gap_run.location = LocationData.new()
	var gap: float = ChaseResolver.start_gap(gap_run, null)
	TestFixtures.check(res, "chase: start gap default 18", is_equal_approx(gap, ChaseResolver.DEFAULT_GAP),
		"gap %.2f" % gap)
	gap_run.location = DataManager.locations.get("Aerdis", null) as LocationData
	var live: float = ChaseResolver.start_gap(gap_run, null)
	TestFixtures.check(res, "chase: start gap live location", gap_run.location != null and live > 0.0,
		"location %s gap %.2f" % [str(gap_run.location != null), live])

	var caught: Dictionary = ChaseResolver.simulate(18.0, 10.0, 4.0)
	TestFixtures.check(res, "chase: simulate caught",
		String(caught["result"]) == ChaseResolver.RESULT_CAUGHT and int(caught["rounds"]) == 3
		and _gaps_match(caught["gaps"], [12.0, 6.0, 0.0]), str(caught))
	var escaped: Dictionary = ChaseResolver.simulate(18.0, 4.0, 10.0)
	TestFixtures.check(res, "chase: simulate escaped",
		String(escaped["result"]) == ChaseResolver.RESULT_ESCAPED and int(escaped["rounds"]) == 3
		and _gaps_match(escaped["gaps"], [24.0, 30.0, 36.0]), str(escaped))
	var tied: Dictionary = ChaseResolver.simulate(18.0, 6.0, 6.0)
	TestFixtures.check(res, "chase: simulate timeout",
		String(tied["result"]) == ChaseResolver.RESULT_ESCAPED and int(tied["rounds"]) == 20
		and bool(tied["timed_out"]),
		"result %s rounds %d timed_out %s" % [String(tied["result"]), int(tied["rounds"]), str(tied["timed_out"])])
	var zero: Dictionary = ChaseResolver.simulate(0.0, 1.0, 1.0)
	TestFixtures.check(res, "chase: simulate zero gap",
		String(zero["result"]) == ChaseResolver.RESULT_CAUGHT and int(zero["rounds"]) == 0, str(zero))

	var pair: Array[MercenaryData] = [TestFixtures.fixed_merc("Fast", {"speed": 10.0, "pace": 0}),
		TestFixtures.fixed_merc("Slow", {"speed": 4.0, "pace": 2})]
	var mean: float = ChaseResolver.side_speed(pair, 0.0)
	TestFixtures.check(res, "chase: side speed mean", is_equal_approx(mean, 8.0), "mean %.2f" % mean)
	var empty: float = ChaseResolver.side_speed([], 0.0)
	TestFixtures.check(res, "chase: side speed empty", is_equal_approx(empty, 0.0), "speed %.2f" % empty)
	var foot_run: ContractRun = _run(_contract(CHASE), _team(1, "Rider"))
	var vehicle: float = ChaseResolver.vehicle_bonus(foot_run, "vehicle")
	var foot: float = ChaseResolver.vehicle_bonus(foot_run, "foot")
	TestFixtures.check(res, "chase: vehicle bonus",
		foot_run.travel_mode == "foot" and is_equal_approx(vehicle, 1.0) and is_equal_approx(foot, 0.0),
		"mode %s vehicle %.2f foot %.2f" % [foot_run.travel_mode, vehicle, foot])

	var win: Dictionary = await _chase(10.0, 4.0)
	var win_out: Dictionary = win["out"]
	var win_chase: Dictionary = win_out.get("chase", {})
	TestFixtures.check(res, "chase: run mercs catch",
		bool(win_out.get("success", false)) and String(win_chase.get("result", "")) == ChaseResolver.RESULT_CAUGHT,
		"success %s chase %s" % [str(win_out.get("success", false)), str(win_chase)])
	var lose: Dictionary = await _chase(4.0, 10.0)
	var lose_out: Dictionary = lose["out"]
	var lose_chase: Dictionary = lose_out.get("chase", {})
	TestFixtures.check(res, "chase: run mercs lose",
		not bool(lose_out.get("success", true))
		and String(lose_chase.get("result", "")) == ChaseResolver.RESULT_ESCAPED,
		"success %s chase %s" % [str(lose_out.get("success", true)), str(lose_chase)])
	var flip: Dictionary = await _chase(10.0, 4.0, "chasing=target")
	var flip_out: Dictionary = flip["out"]
	var flip_chase: Dictionary = flip_out.get("chase", {})
	TestFixtures.check(res, "chase: run target flees flip",
		bool(flip_out.get("success", false)) and String(flip_chase.get("result", "")) == ChaseResolver.RESULT_ESCAPED
		and String(flip_chase.get("chasing", "")) == "target",
		"success %s chase %s" % [str(flip_out.get("success", false)), str(flip_chase)])
	var win_run: ContractRun = win["run"]
	TestFixtures.check(res, "chase: foot mark", win_run.event_marks.has(ChaseResolver.FOOT_MARK),
		"marks %s" % str(win_run.event_marks))
	var ride: Dictionary = await _chase(10.0, 4.0, "chase=vehicle")
	var ride_run: ContractRun = ride["run"]
	TestFixtures.check(res, "chase: vehicle mark", ride_run.event_marks.has(ChaseResolver.VEHICLE_MARK),
		"marks %s" % str(ride_run.event_marks))
	var missing: Array[String] = []
	for key: String in ["mode", "chasing", "start_gap", "result", "gaps"]:
		if not win_chase.has(key):
			missing.append(key)
	TestFixtures.check(res, "chase: outcome keys", missing.is_empty() and int(win_out.get("winner", -1)) == 0,
		"missing %s winner %d" % [str(missing), int(win_out.get("winner", -1))])


static func _gaps_match(got: Variant, want: Array) -> bool:
	if not (got is Array):
		return false
	var list: Array = got
	if list.size() != want.size():
		return false
	for i: int in range(want.size()):
		if not is_equal_approx(float(list[i]), float(want[i])):
			return false
	return true


static func _case_time(res: Dictionary) -> void:
	CampaignClock.reset()
	var timed: Dictionary = await _chase(10.0, 4.0, "", 150, "", true, true)
	var timed_out: Dictionary = timed["out"]
	var timed_run: ContractRun = timed["run"]
	TestFixtures.check(res, "time: outcome minutes",
		bool(timed_out.get("success", false)) and int(timed_out.get("minutes", 0)) == 150,
		"success %s minutes %d" % [str(timed_out.get("success", false)), int(timed_out.get("minutes", 0))])
	TestFixtures.check(res, "time: clock advance", CampaignClock.now() == 150, "clock %d" % CampaignClock.now())
	var hours: int = ContractBoard.completion_hours(timed_run.contract)
	TestFixtures.check(res, "time: completion hours", hours == 3, "hours %d" % hours)

	CampaignClock.reset()
	var plain: Dictionary = await _chase(10.0, 4.0, "", 0, "", true, true)
	var plain_run: ContractRun = plain["run"]
	var plain_hours: int = ContractBoard.completion_hours(plain_run.contract)
	TestFixtures.check(res, "time: zero keeps default",
		plain_hours == 1 and CampaignClock.now() == CampaignClock.EVENT_MINUTES,
		"hours %d clock %d" % [plain_hours, CampaignClock.now()])
	CampaignClock.reset()


static func _case_consequence(res: Dictionary) -> void:
	CampaignClock.reset()
	var lost: Dictionary = await _chase(4.0, 10.0, "", 0, "hp -2, guild -1", true, true)
	var lost_out: Dictionary = lost["out"]
	var lost_team: Array[MercenaryData] = []
	lost_team.assign(lost["team"])
	var lost_lines: Array[String] = _strings(lost_out.get("consequences", []))
	TestFixtures.check(res, "consequence: fires on failure",
		not bool(lost_out.get("success", true)) and TestFixtures.has_line(lost_lines, "CONTRACT CONSEQUENCE:")
		and lost_team[0].current_hp == 16,
		"consequences %s leader hp %d" % [str(lost_lines), lost_team[0].current_hp])

	var won: Dictionary = await _chase(10.0, 4.0, "", 0, "hp -2, guild -1", true, true)
	var won_run: ContractRun = won["run"]
	var won_team: Array[MercenaryData] = []
	won_team.assign(won["team"])
	TestFixtures.check(res, "consequence: silent on success",
		not TestFixtures.has_line(won_run.log_lines, "CONTRACT CONSEQUENCE") and won_team[0].current_hp == 20,
		"leader hp %d" % won_team[0].current_hp)

	var leaderless: Dictionary = await _chase(4.0, 10.0, "", 0, "hp -2", false, true)
	var leaderless_team: Array[MercenaryData] = []
	leaderless_team.assign(leaderless["team"])
	TestFixtures.check(res, "consequence: no leader uses first",
		leaderless_team[0].current_hp == 16 and leaderless_team[1].current_hp == 20,
		"hp %d %d" % [leaderless_team[0].current_hp, leaderless_team[1].current_hp])

	var retry: Dictionary = await _chase(4.0, 10.0, "", 0, "retry -1", true, true)
	var retry_run: ContractRun = retry["run"]
	var retry_lines: int = 0
	for line: String in retry_run.log_lines:
		if line == RETRY_LINE:
			retry_lines += 1
	TestFixtures.check(res, "consequence: retry ignored line", retry_lines == 1, "lines %d" % retry_lines)

	var check_style := ContractData.new()
	check_style.style = "check"
	check_style.completion = CheckStore.PREFIX + PLAIN
	check_style.assigned_primary_event = CheckStore.PREFIX + PLAIN
	check_style.consequence = "guild -1"
	var check_run: ContractRun = await _failed_check(check_style)
	var check_count: int = TestFixtures.count_lines(check_run.log_lines, GUILD_LINE, true)
	TestFixtures.check(res, "consequence: check row single fire", check_count == 1, "summary lines %d" % check_count)

	var event_style: ContractData = _contract(CheckStore.PREFIX + PLAIN, "", 0, "guild -1")
	var event_run: ContractRun = await _failed_check(event_style)
	var event_count: int = TestFixtures.count_lines(event_run.log_lines, GUILD_LINE, true)
	TestFixtures.check(res, "consequence: event row check primary single fire", event_count == 1,
		"summary lines %d completion %s" % [event_count, event_style.completion])
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	CampaignClock.reset()


#A Checks.tsv test row with no consequence of its own, rolled to fail as the contract primary.
static func _failed_check(contract: ContractData) -> ContractRun:
	CheckStore.reset()
	var row: Dictionary = {}
	for key: String in CheckSheet.HEADER:
		row[key] = ""
	row[CheckSheet.HEADER[CheckSheet.NAME]] = PLAIN
	row[CheckSheet.HEADER[CheckSheet.ATTRIBUTES]] = "Dexterity, Wile"
	var rows: Array[Dictionary] = [row]
	CheckStore.test_rows.assign(rows)
	var merc: MercenaryData = TestFixtures.fixed_merc("Checker", {"base_success_chance": 50.0})
	var team: Array[MercenaryData] = [merc]
	var def: Dictionary = CheckStore.check_def(CheckStore.parse(CheckStore.find(PLAIN)))
	var dice: int = int(CheckSystem.success_distribution(merc, def)["dice"])
	CheckSystem.forced_rolls.clear()
	for _i: int in range(dice * 2):
		CheckSystem.forced_rolls.append(FAIL_ROLL)
	var contract_run: ContractRun = _run(contract, team)
	var event: EventData = CheckStore.stand_in(PLAIN)
	await ContractManager.run_one_event(contract_run, event, event.event_name, true)
	CheckSystem.forced_rolls.clear()
	return contract_run


static func _case_dispatch(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(2, "Rider")
	var plain: ContractRun = ContractRun.make(_contract(CHASE), team, Callable())
	TestFixtures.check(res, "dispatch: run default foot", plain.travel_mode == "foot", "mode %s" % plain.travel_mode)
	var board := ContractBoard.new()
	var first: BoardEntry = board.post(_contract(CHASE), 0)
	var horse: ContractScheduler = board.activate(first.id, team, 240, 0, Callable(), -1, "horse")
	var horse_mode: String = "<none>"
	if horse != null and first.scheduler != null:
		horse_mode = first.scheduler.run.travel_mode
	TestFixtures.check(res, "dispatch: activate mode stored", horse_mode == "horse", "mode %s" % horse_mode)
	for merc: MercenaryData in team:
		merc.on_contract = false
	var second: BoardEntry = board.post(_contract(CHASE), 0)
	var blank: ContractScheduler = board.activate(second.id, team, 240, 0, Callable(), -1, "")
	var blank_mode: String = "<none>"
	if blank != null and second.scheduler != null:
		blank_mode = second.scheduler.run.travel_mode
	TestFixtures.check(res, "dispatch: activate blank mode foot", blank_mode == "foot", "mode %s" % blank_mode)
	for merc: MercenaryData in team:
		merc.on_contract = false

class_name TimelineContractTests

#Timeline style contracts: the TimelineRunner walk, steps, roles, minutes, consequences, hours and odds hooks.
#Run: godot --headless --path . -- --timelinecontract-tests

const CAT := "Get Cat from Tree"
const TWO_CHECKS := "a=check:Get Cat from Tree ; b=check:Get Cat from Tree fail"
const FLAGGED := "a=check:Get Cat from Tree fail ; b=check:Get Cat from Tree fail"
const CHECK_BATTLE := "a=check:Get Cat from Tree ; b=event:Fight Bandits fail"
const BRANCH := "a=check:Get Cat from Tree ; b=check:Get Cat from Tree ; c=check:Get Cat from Tree if a.failure ; d=check:Get Cat from Tree fail"
const ROLE := "a=check:Get Cat from Tree role=Driver ; b=check:Get Cat from Tree fail"
const LEADER := "a=check:Get Cat from Tree role=Leader ; b=check:Get Cat from Tree fail"
const CFG := "a=event:Chase cfg=chase=vehicle ; b=check:Get Cat from Tree fail"
const TIMED := "a=event:Fight Bandits time=150 ; b=check:Get Cat from Tree fail"
const CONS := "a=event:Fight Bandits role=Driver cons=hp -2, guild -1 ; b=check:Get Cat from Tree fail"
const RETRY := "a=event:Fight Bandits cons=retry -1 ; b=check:Get Cat from Tree fail"
const HOURS := "a=check:Get Cat from Tree ; c=check:Get Cat from Tree if a.failure ; b=event:Fight Bandits time=150 fail"
const MISS_CHECK := "a=check:No Such Check ; b=check:Get Cat from Tree fail"
const MISS_EVENT := "a=event:No Such Event ; b=check:Get Cat from Tree fail"
const BROKEN := "a=event:Fight Bandits"
const STRAY := "a=event:Fight Bandits role=Driver ; b=event:Fight Bandits fail"
const PASS_ROLL := 1
const FAIL_ROLL := 99
const RETRY_LINE := "STEP CONSEQUENCE: retry has no meaning for an event, ignored"
const ACTIONS := "res://Scripts/Actions/Resources/DefaultActionSet.tres"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var held: Dictionary = {}
	ContractResourceBuilder.build_all()
	var saved_logs: bool = EncounterLogger.suppressed
	EncounterLogger.suppressed = true
	_case_library(res)
	await _case_router(res)
	await _case_verdicts(res, held)
	await _case_missing(res)
	await _case_minutes(res)
	_case_summary(res, held)
	await _case_consequence(res)
	await _case_roles(res)
	await _case_config(res)
	await _case_battle(res)
	_case_board(res)
	_case_harness_run(res, held)
	await _case_contract_cc(res)
	await _case_mishaps(res)
	_case_run_roles(res)
	_case_harness_generate(res)
	TimelineRunner.forced_results.clear()
	ChaseResolver.reset()
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()
	CampaignClock.reset()
	EncounterLogger.suppressed = saved_logs
	return TestFixtures.summarize(res, "TIMELINECONTRACT")


static func _contract(tag: String, cell: String, roles: Array[String] = []) -> ContractData:
	var contract := ContractData.new()
	contract.contract_name = "TL " + tag
	contract.style = "timeline"
	contract.completion = cell
	contract.assigned_primary_event = TimelineRunner.PRIMARY_PREFIX + contract.contract_name
	contract.roles.assign(roles)
	contract.contract_level = 5
	contract.difficulty = 2.0
	contract.time_minutes = 0
	contract.event_config = ""
	return contract


static func _team(n: int, prefix: String = "TL", extras: Dictionary = {}) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for i: int in range(n):
		out.append(TestFixtures.fixed_merc("%s %d" % [prefix, i + 1], extras))
	return out


#The contract's primary run through the manager with the forced step results held for the walk only.
static func _walk(contract: ContractData, team: Array[MercenaryData], leader_uid: int = -1,
		roles: Dictionary = {}, forced: Dictionary = {}) -> ContractRun:
	TimelineRunner.forced_results = forced.duplicate()
	var contract_run: ContractRun = ContractRun.make(contract, team, Callable(), leader_uid)
	contract_run.roles = roles
	await ContractManager.run_one_event(contract_run, ContractLibrary.event(contract.assigned_primary_event),
		contract.assigned_primary_event, true)
	TimelineRunner.forced_results.clear()
	return contract_run


#Fixed mercs carry no action set; a real battle turn needs the default one.
static func _armed(team: Array[MercenaryData]) -> Array[MercenaryData]:
	var actions: MercActionSet = load(ACTIONS)
	for merc: MercenaryData in team:
		merc.action_set = actions
	return team


static func _summary(contract_run: ContractRun) -> Dictionary:
	return contract_run.outcomes.back() if not contract_run.outcomes.is_empty() else {}


static func _outcome(contract_run: ContractRun, index: int) -> Dictionary:
	return contract_run.outcomes[index] if index < contract_run.outcomes.size() else {}


static func _starts(lines: Array[String], head: String) -> bool:
	return TestFixtures.count_lines(lines, head, true) > 0


static func _index(lines: Array[String], head: String, from: int = 0) -> int:
	for i: int in range(from, lines.size()):
		if lines[i].begins_with(head):
			return i
	return -1


static func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		out.assign(value)
	return out


static func _rolls(value: int, count: int) -> void:
	CheckSystem.forced_rolls.clear()
	for _i: int in range(count):
		CheckSystem.forced_rolls.append(value)


static func _hp(team: Array[MercenaryData]) -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in team:
		out.append(merc.current_hp)
	return out


static func _case_library(res: Dictionary) -> void:
	var made: ContractData = ContractGenerator.generate_row(_contract("gen", TWO_CHECKS), 5, 2.0, "")
	var assigned: String = made.assigned_primary_event if made != null else "<null>"
	TestFixtures.check(res, "timeline: sentinel primary", assigned == "timeline:TL gen", "assigned '%s'" % assigned)

	var stand: EventData = ContractLibrary.event("timeline:TL x")
	var bandits: EventData = ContractLibrary.event("Fight Bandits")
	var fields_ok: bool = stand != null and stand.event_name == "timeline:TL x" and stand.event_type == "Primary" \
		and stand.success_formula == "Timeline" and not stand.fail_ends_contract and stand.is_timeline()
	TestFixtures.check(res, "timeline: stand-in fields",
		fields_ok and bandits != null and not bandits.is_timeline(),
		"stand %s bandits %s" % ["null" if stand == null else "%s %s %s %s" % [stand.event_name, stand.event_type,
			stand.success_formula, str(stand.fail_ends_contract)], "null" if bandits == null else str(bandits.is_timeline())])

	TestFixtures.check(res, "timeline: has_event true",
		ContractLibrary.has_event("Fight Bandits") and ContractLibrary.has_event("Chase"),
		"bandits %s chase %s" % [str(ContractLibrary.has_event("Fight Bandits")), str(ContractLibrary.has_event("Chase"))])

	var wrong: Array[String] = []
	for name: String in ["", "No Such Event", "check:Get Cat from Tree", "timeline:Fight Bandits"]:
		if ContractLibrary.has_event(name):
			wrong.append("'%s'" % name)
	TestFixtures.check(res, "timeline: has_event false", wrong.is_empty(), "true for %s" % str(wrong))


static func _case_router(res: Dictionary) -> void:
	var contract: ContractData = _contract("route", TWO_CHECKS)
	var contract_run: ContractRun = ContractRun.make(contract, _team(3), Callable())
	TimelineRunner.forced_results = {"a": true, "b": true}
	var out: Dictionary = await EventRunner.run(ContractLibrary.event(contract.assigned_primary_event), contract_run)
	TimelineRunner.forced_results.clear()
	TestFixtures.check(res, "timeline: event runner routes",
		bool(out.get("clocked", false)) and int(out.get("steps", 0)) == 2
		and _starts(contract_run.log_lines, "EVENT START: timeline:"),
		"clocked %s steps %d" % [str(out.get("clocked", false)), int(out.get("steps", 0))])


static func _case_verdicts(res: Dictionary, held: Dictionary) -> void:
	var six: ContractRun = await _walk(_contract("six", TWO_CHECKS), _team(3), -1, {}, {"a": true, "b": true})
	held["six_size"] = six.outcomes.size()
	held["six"] = six
	ContractManager.arrive_home(six)
	TestFixtures.check(res, "timeline: all success verdict", six.verdict == BoardEntry.STATUS_SUCCEEDED,
		"verdict %s" % six.verdict)

	var flagged: ContractRun = await _walk(_contract("flag", FLAGGED), _team(3), -1, {}, {"a": false, "b": true})
	var flagged_out: Dictionary = _summary(flagged)
	TestFixtures.check(res, "timeline: flagged failure ends",
		not bool(flagged_out.get("success", true)) and String(flagged_out.get("failed_step", "")) == "a " + CAT
		and flagged.failed_event == "a " + CAT,
		"success %s failed_step '%s' failed_event '%s'" % [str(flagged_out.get("success", true)),
			String(flagged_out.get("failed_step", "")), flagged.failed_event])
	TestFixtures.check(res, "timeline: later steps skipped",
		_starts(flagged.log_lines, "TIMELINE SKIP: b " + CAT) and not _starts(flagged.log_lines, "TIMELINE STEP b ")
		and int(flagged_out.get("steps", -1)) == 1
		and _starts(flagged.log_lines, "TIMELINE RESULT: FAILED, 1 of 2 steps ran"),
		"steps %d" % int(flagged_out.get("steps", -1)))
	ContractManager.arrive_home(flagged)
	TestFixtures.check(res, "timeline: flagged failure verdict", flagged.verdict == BoardEntry.STATUS_FAILED,
		"verdict %s" % flagged.verdict)

	var ten: ContractRun = await _walk(_contract("ten", TWO_CHECKS), _team(3), -1, {}, {"a": false, "b": true})
	held["ten"] = ten
	var ten_out: Dictionary = _summary(ten)
	TestFixtures.check(res, "timeline: unflagged failure continues",
		bool(ten_out.get("success", false)) and int(ten_out.get("steps", 0)) == 2 and ten.failed_event == "",
		"success %s steps %d failed_event '%s'" % [str(ten_out.get("success", false)), int(ten_out.get("steps", 0)),
			ten.failed_event])

	var order: ContractRun = await _walk(_contract("order", BRANCH), _team(3), -1, {},
		{"a": false, "b": true, "c": true, "d": true})
	var at: Array[int] = []
	for id: String in ["a", "b", "c", "d"]:
		at.append(_index(order.log_lines, "TIMELINE STEP %s " % id))
	var rising: bool = at[0] >= 0
	for i: int in range(1, at.size()):
		rising = rising and at[i] > at[i - 1]
	TestFixtures.check(res, "timeline: branch on failure order", rising, "indexes %s" % str(at))

	var skip: ContractRun = await _walk(_contract("skip", BRANCH), _team(3), -1, {},
		{"a": true, "b": true, "c": true, "d": true})
	TestFixtures.check(res, "timeline: branch skipped on success",
		_starts(skip.log_lines, "TIMELINE SKIP: c " + CAT) and int(_summary(skip).get("steps", 0)) == 3,
		"steps %d" % int(_summary(skip).get("steps", 0)))

	TestFixtures.check(res, "timeline: forced results hook",
		not _starts(ten.log_lines, "CHECK:") and String(_outcome(ten, 0).get("step", "")) == "a"
		and String(_outcome(ten, 1).get("step", "")) == "b",
		"steps '%s' '%s'" % [String(_outcome(ten, 0).get("step", "")), String(_outcome(ten, 1).get("step", ""))])


static func _case_missing(res: Dictionary) -> void:
	var check: ContractRun = await _walk(_contract("misscheck", MISS_CHECK), _team(3), -1, {}, {"b": true})
	TestFixtures.check(res, "timeline: missing check",
		_starts(check.log_lines, "EVENT MISSING: check:No Such Check")
		and _starts(check.log_lines, "TIMELINE STEP a No Such Check: failure (60 min)")
		and bool(_summary(check).get("success", false)),
		"success %s" % str(_summary(check).get("success", false)))

	var event: ContractRun = await _walk(_contract("missevent", MISS_EVENT), _team(3), -1, {}, {"b": true})
	TestFixtures.check(res, "timeline: missing event",
		_starts(event.log_lines, "EVENT MISSING: No Such Event")
		and not _starts(event.log_lines, "EVENT START: No Such Event"),
		"missing line %s" % str(_starts(event.log_lines, "EVENT MISSING: No Such Event")))

	var broken: ContractRun = await _walk(_contract("broken", BROKEN), _team(3))
	var broken_out: Dictionary = _summary(broken)
	TestFixtures.check(res, "timeline: broken cell",
		_starts(broken.log_lines, "TIMELINE BROKEN: Timeline needs at least 2 steps, has 1")
		and not bool(broken_out.get("success", true)) and int(broken_out.get("steps", -1)) == 0
		and broken.failed_event == "timeline" and broken.outcomes.size() == 1,
		"success %s steps %d failed_event '%s' outcomes %d" % [str(broken_out.get("success", true)),
			int(broken_out.get("steps", -1)), broken.failed_event, broken.outcomes.size()])


static func _case_minutes(res: Dictionary) -> void:
	CampaignClock.reset()
	var timed: ContractRun = await _walk(_contract("timed", TIMED), _team(3), -1, {}, {"a": true, "b": true})
	var first: int = int(_outcome(timed, 0).get("minutes", 0))
	TestFixtures.check(res, "timeline: step time minutes",
		first == 150 and _starts(timed.log_lines, "TIMELINE STEP a Fight Bandits: success (150 min)"),
		"minutes %d" % first)
	var second: int = int(_outcome(timed, 1).get("minutes", 0))
	TestFixtures.check(res, "timeline: default minutes", second == CampaignClock.EVENT_MINUTES, "minutes %d" % second)
	TestFixtures.check(res, "timeline: clock sum", CampaignClock.now() == 150 + CampaignClock.EVENT_MINUTES,
		"clock %d" % CampaignClock.now())
	CampaignClock.reset()

	_rolls(PASS_ROLL, 10)
	var real: ContractRun = await _walk(_contract("real", TWO_CHECKS), _team(3), -1, {}, {"b": true})
	CheckSystem.forced_rolls.clear()
	var step: Dictionary = _outcome(real, 0)
	var product: int = int(CheckStore.parse(CheckStore.find(CAT))["minutes"]) * int(step.get("attempts", 0))
	var want: int = product if product > 0 else CampaignClock.EVENT_MINUTES
	TestFixtures.check(res, "timeline: resolver minutes", int(step.get("minutes", 0)) == want,
		"minutes %d want %d" % [int(step.get("minutes", 0)), want])
	TestFixtures.check(res, "timeline: real check step",
		String(step.get("check", "")) == CAT and _starts(real.log_lines, "CHECK: %s roller " % CAT),
		"check '%s'" % String(step.get("check", "")))
	CampaignClock.reset()


static func _case_summary(res: Dictionary, held: Dictionary) -> void:
	var ten: ContractRun = held["ten"]
	var out: Dictionary = _summary(ten)
	var missing: Array[String] = []
	for key: String in ["success", "steps", "failed_step", "consequences"]:
		if not out.has(key):
			missing.append(key)
	TestFixtures.check(res, "timeline: summary keys",
		String(out.get("event", "")) == "timeline:TL ten" and String(out.get("event_type", "")) == "Primary"
		and int(out.get("minutes", -1)) == 0 and bool(out.get("clocked", false)) and missing.is_empty(),
		"event '%s' type '%s' minutes %d missing %s" % [String(out.get("event", "")), String(out.get("event_type", "")),
			int(out.get("minutes", -1)), str(missing)])

	var six: ContractRun = held["six"]
	TestFixtures.check(res, "timeline: outcomes hold steps and summary",
		int(held["six_size"]) == 3 and String(_outcome(six, 0).get("step", "")) == "a"
		and String(_outcome(six, 1).get("step", "")) == "b"
		and String(_outcome(six, 2).get("event", "")) == six.contract.assigned_primary_event,
		"size %d" % int(held["six_size"]))


static func _case_consequence(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3)
	var lost: ContractRun = await _walk(_contract("cons", CONS), team, team[0].merc_uid,
		{team[1].merc_uid: "Driver"}, {"a": false, "b": true})
	var step_lines: Array[String] = _strings(_outcome(lost, 0).get("consequences", []))
	var summary_lines: Array[String] = _strings(_summary(lost).get("consequences", []))
	var joined: bool = not step_lines.is_empty()
	for line: String in step_lines:
		joined = joined and summary_lines.has(line)
	TestFixtures.check(res, "timeline: step consequence fires",
		team[1].current_hp == 16 and team[0].current_hp == 20 and _starts(lost.log_lines, "STEP CONSEQUENCE: TL 2 loses")
		and _starts(lost.log_lines, "STEP CONSEQUENCE: guild opinion -1 for 3 mercs") and joined,
		"hp %s step %s summary %s" % [str(_hp(team)), str(step_lines), str(summary_lines)])

	var retry: ContractRun = await _walk(_contract("retry", RETRY), _team(3), -1, {}, {"a": false, "b": true})
	var retry_count: int = 0
	for line: String in retry.log_lines:
		if line == RETRY_LINE:
			retry_count += 1
	TestFixtures.check(res, "timeline: retry ignored", retry_count == 1, "lines %d" % retry_count)

	var calm_team: Array[MercenaryData] = _team(3)
	var calm: ContractRun = await _walk(_contract("calm", CONS), calm_team, calm_team[0].merc_uid,
		{calm_team[1].merc_uid: "Driver"}, {"a": true, "b": true})
	var whole: bool = true
	for merc: MercenaryData in calm_team:
		whole = whole and merc.current_hp == 20
	TestFixtures.check(res, "timeline: no consequence on success",
		not TestFixtures.has_line(calm.log_lines, "STEP CONSEQUENCE") and whole, "hp %s" % str(_hp(calm_team)))


static func _case_roles(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3)
	_rolls(PASS_ROLL, 10)
	var driver: ContractRun = await _walk(_contract("role", ROLE), team, team[2].merc_uid,
		{team[1].merc_uid: "Driver"}, {"b": true})
	CheckSystem.forced_rolls.clear()
	TestFixtures.check(res, "timeline: role holder rolls", _starts(driver.log_lines, "CHECK: %s roller TL 2 (" % CAT),
		"roller line %d" % _index(driver.log_lines, "CHECK: %s roller " % CAT))

	var lead_team: Array[MercenaryData] = _team(3)
	lead_team[0].stats["dexterity"] = 6
	lead_team[0].stats["wile"] = 6
	_rolls(PASS_ROLL, 10)
	var lead: ContractRun = await _walk(_contract("leader", LEADER), lead_team, lead_team[2].merc_uid, {}, {"b": true})
	CheckSystem.forced_rolls.clear()
	var holders: Array[MercenaryData] = lead.holders("Leader")
	TestFixtures.check(res, "timeline: leader role rolls",
		_starts(lead.log_lines, "CHECK: %s roller TL 3 (" % CAT) and holders.size() == 1 and holders[0] == lead_team[2],
		"holders %s" % str(lead.merc_names(holders)))

	var fallback_line: String = "CHECK: no living Driver for %s, best suited rolls" % CAT
	var nobody: ContractRun = await _walk(_contract("nobody", ROLE), _team(3), -1, {}, {"b": true})
	var dead_team: Array[MercenaryData] = _team(3)
	dead_team[1].is_dead = true
	var dead: ContractRun = await _walk(_contract("dead", ROLE), dead_team, -1, {dead_team[1].merc_uid: "Driver"},
		{"b": true})
	var shown: Array[bool] = []
	for fall: ContractRun in [nobody, dead]:
		var at: int = _index(fall.log_lines, fallback_line)
		shown.append(at >= 0 and _index(fall.log_lines, "CHECK: %s roller " % CAT, at + 1) > at)
	TestFixtures.check(res, "timeline: role fallback", shown.size() == 2 and shown[0] and shown[1],
		"runs %s" % str(shown))

	var board := ContractBoard.new()
	var entry: BoardEntry = board.post(_contract("board", TWO_CHECKS), 0)
	var roles: Dictionary = {team[1].merc_uid: "Driver"}
	var scheduler: ContractScheduler = board.activate(entry.id, team, 240, 0, Callable(), team[0].merc_uid, "foot",
		roles)
	roles.clear()
	var stored: Dictionary = {}
	var drivers: Array[MercenaryData] = []
	if scheduler != null and scheduler.run != null:
		stored = scheduler.run.roles
		drivers = scheduler.run.holders("Driver")
	TestFixtures.check(res, "timeline: roles reach the run",
		stored.size() == 1 and String(stored.get(team[1].merc_uid, "")) == "Driver" and drivers.size() == 1
		and drivers[0] == team[1],
		"roles %s drivers %d" % [str(stored), drivers.size()])
	for merc: MercenaryData in team:
		merc.on_contract = false


static func _case_config(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(2, "TL", {"speed": 10.0, "pace": 0})
	var contract: ContractData = _contract("cfg", CFG)
	ChaseResolver.forced_target.assign([TestFixtures.fixed_merc("Quarry", {"speed": 4.0, "pace": 0})])
	var chase: ContractRun = await _walk(contract, team, team[0].merc_uid, {}, {"b": true})
	ChaseResolver.reset()
	TestFixtures.check(res, "timeline: step config during step",
		_starts(chase.log_lines, "CHASE START: Chase mode vehicle"),
		"chase line %d" % _index(chase.log_lines, "CHASE START: "))
	TestFixtures.check(res, "timeline: step config cleared",
		chase.step_config == "" and chase.event_config() == "",
		"step_config '%s' event_config '%s'" % [chase.step_config, chase.event_config()])
	TestFixtures.check(res, "timeline: board contract untouched",
		contract.event_config == "" and contract.completion == CFG,
		"event_config '%s' completion '%s'" % [contract.event_config, contract.completion])

	var own: ContractData = _contract("own", TWO_CHECKS)
	own.event_config = "chase=foot; chasing=mercs"
	var own_run: ContractRun = ContractRun.make(own, _team(1), Callable())
	var before: String = own_run.event_config()
	own_run.step_config = "chase=vehicle; chasing=mercs"
	var after: String = own_run.event_config()
	TestFixtures.check(res, "timeline: event_config fallback",
		before == "chase=foot; chasing=mercs" and after == "chase=vehicle; chasing=mercs",
		"before '%s' after '%s'" % [before, after])


static func _case_battle(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _armed(_team(3))
	var battle: ContractRun = await _walk(_contract("battle", CHECK_BATTLE), team, team[0].merc_uid, {}, {"a": true})
	TestFixtures.check(res, "timeline: real battle step",
		String(_outcome(battle, 1).get("event", "")) == "Fight Bandits"
		and _starts(battle.log_lines, "TIMELINE STEP b Fight Bandits: ") and not battle.target_record.is_empty(),
		"event '%s' target %s" % [String(_outcome(battle, 1).get("event", "")), str(not battle.target_record.is_empty())])

	var dead: Array[MercenaryData] = _team(3)
	for merc: MercenaryData in dead:
		merc.is_dead = true
	var wipe: ContractRun = await _walk(_contract("wipe", TWO_CHECKS), dead, -1, {}, {"a": true, "b": true})
	var wipe_out: Dictionary = _summary(wipe)
	TestFixtures.check(res, "timeline: wipe ends failed",
		not bool(wipe_out.get("success", true)) and String(wipe_out.get("failed_step", "")) == "a " + CAT
		and wipe.failed_event == "a " + CAT and not _starts(wipe.log_lines, "TIMELINE STEP b "),
		"success %s failed_step '%s' failed_event '%s'" % [str(wipe_out.get("success", true)),
			String(wipe_out.get("failed_step", "")), wipe.failed_event])


static func _case_board(res: Dictionary) -> void:
	var want: int = CheckStore.hours(CheckStore.parse(CheckStore.find(CAT))) + 3
	var keyed: int = ContractBoard.completion_hours(_contract("hours", HOURS))
	var bare: ContractData = _contract("hours", HOURS)
	bare.assigned_primary_event = ""
	var unkeyed: int = ContractBoard.completion_hours(bare)
	TestFixtures.check(res, "timeline: completion hours sum", keyed == want and unkeyed == want,
		"hours %d and %d want %d" % [keyed, unkeyed, want])
	var broken: int = ContractBoard.completion_hours(_contract("broken", BROKEN))
	TestFixtures.check(res, "timeline: completion hours broken", broken == 1, "hours %d" % broken)

	var stray: String = ContractDataValidator._timeline_reason(STRAY, [])
	var listed: String = ContractDataValidator._timeline_reason(STRAY, ["Driver"] as Array[String])
	var leader: String = ContractDataValidator._timeline_reason(LEADER, [])
	TestFixtures.check(res, "timeline: validator stray role",
		stray == "step a role Driver is not a contract role" and listed == "" and leader == "",
		"stray '%s' listed '%s' leader '%s'" % [stray, listed, leader])


static func _case_harness_run(res: Dictionary, held: Dictionary) -> void:
	var ten: ContractRun = held["ten"]
	var result: Dictionary = {"anomalies": []}
	var levels: Array[int] = []
	for merc: MercenaryData in ten.team:
		levels.append(ExperienceSystem.current_level(merc))
	HarnessPlays._note_run(result, ten, ten.team, levels)
	var anomalies: Array = result["anomalies"]
	TestFixtures.check(res, "timeline: harness plays no anomaly", not anomalies.has("no check outcome"),
		"anomalies %s" % str(anomalies))


static func _case_contract_cc(res: Dictionary) -> void:
	var contract: ContractData = _contract("cc", TWO_CHECKS)
	contract.consequence = "guild -1"
	_rolls(FAIL_ROLL, 20)
	var failed: ContractRun = await _walk(contract, _team(3), -1, {}, {"b": true})
	CheckSystem.forced_rolls.clear()
	TestFixtures.check(res, "timeline: no contract consequence",
		_starts(failed.log_lines, "CHECK RESULT: %s FAILED" % CAT)
		and not _starts(failed.log_lines, "CONTRACT CONSEQUENCE:"),
		"result line %d contract lines %d" % [_index(failed.log_lines, "CHECK RESULT: "),
			TestFixtures.count_lines(failed.log_lines, "CONTRACT CONSEQUENCE:", true)])


static func _case_mishaps(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _armed(_team(3))
	var brawl_run: ContractRun = ContractRun.make(_contract("mb", TWO_CHECKS), team, Callable())
	await EventRunner.run(ContractLibrary.event("Tavern Brawl"), brawl_run)
	TestFixtures.check(res, "timeline: mishap battle no target", brawl_run.target_record.is_empty(),
		"target %s" % str(brawl_run.target_record))

	var contract: ContractData = _contract("mishap", TWO_CHECKS)
	contract.rolled_mishaps.assign(["Tavern Brawl"])
	var contract_run: ContractRun = ContractRun.make(contract, _team(3), Callable())
	var first: Dictionary = ContractManager.next_event(contract_run, 0)
	var second: Dictionary = ContractManager.next_event(contract_run, 1)
	var event: EventData = second["event"]
	TestFixtures.check(res, "timeline: mishaps first",
		String(first["name"]) == "Tavern Brawl" and not bool(first["is_primary"]) and bool(second["is_primary"])
		and String(second["name"]) == contract.assigned_primary_event and event != null and event.is_timeline(),
		"first %s/%s second %s/%s" % [String(first["name"]), str(first["is_primary"]), String(second["name"]),
			str(second["is_primary"])])

	var scored: ContractData = _contract("score", TWO_CHECKS)
	var primary: EventData = MatchScore.primary_event(scored)
	var net: float = MatchScore.team_net(scored, team)
	TestFixtures.check(res, "timeline: match score",
		primary != null and primary.event_name == scored.assigned_primary_event and is_finite(net),
		"primary %s net %s" % ["null" if primary == null else primary.event_name, str(net)])


static func _case_run_roles(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(2)
	var active := ActiveRun.new()
	for pair: Array in [[0, "Driver"], [team[0].merc_uid, ""], [team[1].merc_uid, "Driver"]]:
		var member := TeamMember.new()
		member.merc_uid = int(pair[0])
		member.role = String(pair[1])
		active.team.append(member)
	var got: Dictionary = GameState.run_roles(active)
	TestFixtures.check(res, "timeline: run_roles",
		got.size() == 1 and String(got.get(team[1].merc_uid, "")) == "Driver", "roles %s" % str(got))


static func _case_harness_generate(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(3)
	var result: Dictionary = {"anomalies": []}
	HarnessPlays._note_generate(result, ContractBoard.new().post(_contract("hg", TWO_CHECKS), 0),
		{"level_centre": 5.0}, 0, team)
	var hits: Array[String] = []
	for anomaly: Variant in result["anomalies"]:
		if str(anomaly).begins_with("non-check primary"):
			hits.append(str(anomaly))
	TestFixtures.check(res, "timeline: harness generate no anomaly", hits.is_empty(), "anomalies %s" % str(hits))

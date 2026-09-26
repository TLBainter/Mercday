class_name SchedulerTests

#ContractScheduler phases, travel time, the nightly camp at 22:00, the short-night rule and the
#all-dead branch.
#Run: godot --headless --path . -- --scheduler-tests

const STEP_CAP := 500
const TICK_MINUTE := 1
const TICK_SHIFT := 480
const HOUR := CampaignClock.MINUTES_PER_HOUR

#Minute the last _drive settled its TRAVEL_OUT phase at; -1 when that drive never arrived.
static var last_arrival: int = -1


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_create(res)
	await _case_phase_order(res)
	await _case_travel_minutes(res)
	await _case_night(res)
	await _case_night_splits_travel(res)
	await _case_night_splits_gap(res)
	await _case_night_splits_rest(res)
	await _case_night_every_night(res)
	await _case_short_night(res)
	await _case_long_night_after_midnight(res)
	_case_night_boundary(res)
	await _case_missing_primary(res)
	await _case_all_dead(res)
	await _case_tick_sizes(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "SCHEDULER")


#A reset clock reads D1 00:00, which is night, so every running-phase case starts at 8:00 instead.
static func _morning() -> void:
	CampaignClock.reset()
	CampaignClock.advance(8 * HOUR)


#One fresh team at the given level, registered as the guild roster.
static func _team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(size):
		var merc: MercenaryData = MercGenerator.generate(i)
		ContractModifiers.set_level(merc, level)
		team.append(merc)
	GuildRoster.set_roster(team)
	return team


static func _run_for(contract: ContractData, team: Array[MercenaryData]) -> ContractRun:
	var contract_run := ContractRun.new()
	contract_run.contract = contract
	contract_run.team.assign(team)
	contract_run.line_fn = Callable()
	if contract != null and contract.location_a != "":
		contract_run.location = DataManager.locations.get(contract.location_a, null) as LocationData
	return contract_run


static func _release(team: Array[MercenaryData]) -> void:
	for merc: MercenaryData in team:
		merc.on_contract = false


#Advances the clock in ticks, landing exactly on each due minute, and steps every phase that comes due.
#night_d100 is forced before every NIGHT step, so a case can plant a roll that would fire.
static func _drive(scheduler: ContractScheduler, tick: int, seen: Array[int],
		night_d100: int = 100) -> int:
	var steps: int = 0
	last_arrival = -1
	while not scheduler.is_done() and steps < STEP_CAP:
		var target: int = mini(CampaignClock.now() + tick, scheduler.next_due())
		if target > CampaignClock.now():
			CampaignClock.advance_to(target)
		if CampaignClock.now() < scheduler.next_due():
			continue
		var stepped: int = scheduler.phase
		seen.append(stepped)
		if stepped == ContractScheduler.Phase.NIGHT:
			EventTrigger.forced_d100 = night_d100
		await scheduler.step()
		if stepped == ContractScheduler.Phase.TRAVEL_OUT:
			last_arrival = CampaignClock.now()
		steps += 1
	return steps


static func _case_create(res: Dictionary) -> void:
	_morning()
	var start: int = CampaignClock.now()
	var team: Array[MercenaryData] = _team(3, 5)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 240, CampaignClock.now())
	TestFixtures.check(res, "create_phase", scheduler.phase == ContractScheduler.Phase.TRAVEL_OUT,
		"phase %d" % scheduler.phase)
	TestFixtures.check(res, "create_due", scheduler.next_due() == start + 240, "due %d" % scheduler.next_due())
	TestFixtures.check(res, "create_departed", contract.status == "Active" and contract.team_uids.size() == 3,
		"status %s uids %d" % [contract.status, contract.team_uids.size()])
	var on_contract: bool = true
	for merc: MercenaryData in team:
		if not merc.on_contract:
			on_contract = false
	TestFixtures.check(res, "create_on_contract", on_contract, "every merc marked on contract")
	TestFixtures.check(res, "create_header", not contract_run.log_lines.is_empty(),
		"log lines %d" % contract_run.log_lines.size())
	TestFixtures.check(res, "create_not_done", not scheduler.is_done(), "phase %d" % scheduler.phase)
	_release(team)


static func _case_phase_order(res: Dictionary) -> void:
	_morning()
	seed(9110)
	var team: Array[MercenaryData] = _team(3, 6)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, CampaignClock.TRAVEL_MINUTES, CampaignClock.now())
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_MINUTE, seen)
	TestFixtures.check(res, "order_done", scheduler.is_done() and steps < STEP_CAP,
		"done %s steps %d" % [str(scheduler.is_done()), steps])
	TestFixtures.check(res, "order_first_travel", not seen.is_empty() and seen[0] == ContractScheduler.Phase.TRAVEL_OUT,
		"phases %s" % str(seen))
	TestFixtures.check(res, "order_has_event", seen.has(ContractScheduler.Phase.EVENT),
		"phases %s" % str(seen))
	var ends_home: bool = not seen.is_empty() and seen[seen.size() - 1] == ContractScheduler.Phase.TRAVEL_BACK
	TestFixtures.check(res, "order_last_phase", ends_home or scheduler.all_dead,
		"phases %s all_dead %s" % [str(seen), str(scheduler.all_dead)])
	TestFixtures.check(res, "order_verdict", contract_run.verdict != "" and contract.status == contract_run.verdict,
		"verdict %s status %s" % [contract_run.verdict, contract.status])
	var went: bool = TestFixtures.has_line(contract_run.log_lines, "travel out")
	var came: bool = scheduler.all_dead or TestFixtures.has_line(contract_run.log_lines, "travel back")
	TestFixtures.check(res, "order_travel_lines", went and came, "travel lines missing")
	EventTrigger.missed_respites = 0


static func _case_travel_minutes(res: Dictionary) -> void:
	_morning()
	var start: int = CampaignClock.now()
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 125, CampaignClock.now())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "travel_due_honored", CampaignClock.now() == start + 125, "now %d" % CampaignClock.now())
	TestFixtures.check(res, "travel_line", TestFixtures.has_line(contract_run.log_lines, "travel out +2 h 5 min"),
		"lines %s" % str(contract_run.log_lines.slice(maxi(0, contract_run.log_lines.size() - 3))))
	TestFixtures.check(res, "travel_next_phase", scheduler.phase == ContractScheduler.Phase.EVENT,
		"phase %d" % scheduler.phase)
	_release(team)


#A party that signs at 23:00 camps on the spot and only marches once the wake respite has landed.
static func _case_night(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(23 * HOUR)
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 0, CampaignClock.now())
	TestFixtures.check(res, "night_suspends", scheduler.phase == ContractScheduler.Phase.NIGHT and scheduler.night_active,
		"phase %d active %s" % [scheduler.phase, str(scheduler.night_active)])
	TestFixtures.check(res, "night_wakes_at_six", scheduler.next_due() == 30 * HOUR,
		"due %d" % scheduler.next_due())
	TestFixtures.check(res, "night_resume_phase", scheduler.resume_phase == ContractScheduler.Phase.TRAVEL_OUT,
		"resume %d" % scheduler.resume_phase)
	TestFixtures.check(res, "night_resume_minutes", scheduler.resume_minutes == 0,
		"minutes %d" % scheduler.resume_minutes)
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "night_line", TestFixtures.has_line(contract_run.log_lines, "night +7 h"),
		"no night clock line")
	TestFixtures.check(res, "night_resumes", scheduler.phase == ContractScheduler.Phase.TRAVEL_OUT and not scheduler.night_active,
		"phase %d active %s" % [scheduler.phase, str(scheduler.night_active)])
	TestFixtures.check(res, "night_no_double_wake",
		scheduler.phase != ContractScheduler.Phase.NIGHT and scheduler.next_due() >= 30 * HOUR,
		"phase %d due %d" % [scheduler.phase, scheduler.next_due()])
	await scheduler.step()
	TestFixtures.check(res, "night_travel_line", TestFixtures.has_line(contract_run.log_lines, "travel out +0 min"),
		"no travel out line")
	TestFixtures.check(res, "night_event_due",
		scheduler.phase == ContractScheduler.Phase.EVENT and scheduler.next_due() == CampaignClock.now(),
		"phase %d due %d now %d" % [scheduler.phase, scheduler.next_due(), CampaignClock.now()])
	EventTrigger.missed_respites = 0
	_release(team)


#Travel that runs into 22:00 stops there and finishes its remaining minutes after the wake.
static func _case_night_splits_travel(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(14 * HOUR)
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 600, CampaignClock.now())
	TestFixtures.check(res, "split_travel_due", scheduler.next_due() == 22 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	var camped: bool = scheduler.phase == ContractScheduler.Phase.NIGHT and scheduler.resume_minutes == 120
	camped = camped and scheduler.resume_phase == ContractScheduler.Phase.TRAVEL_OUT
	TestFixtures.check(res, "split_travel_camps", camped,
		"phase %d resume %d minutes %d" % [scheduler.phase, scheduler.resume_phase, scheduler.resume_minutes])
	TestFixtures.check(res, "split_travel_wake_due", scheduler.next_due() == 30 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "split_travel_night_line", TestFixtures.has_line(contract_run.log_lines, "night +8 h"),
		"no night clock line")
	TestFixtures.check(res, "split_travel_resumes",
		scheduler.phase == ContractScheduler.Phase.TRAVEL_OUT and scheduler.next_due() == 32 * HOUR,
		"phase %d due %d" % [scheduler.phase, scheduler.next_due()])
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "split_travel_full_delta", TestFixtures.has_line(contract_run.log_lines, "travel out +10 h"),
		"no full travel delta")
	TestFixtures.check(res, "split_travel_next_phase", scheduler.phase == ContractScheduler.Phase.EVENT,
		"phase %d" % scheduler.phase)
	EventTrigger.missed_respites = 0
	_release(team)


#The gap between two events pauses at 22:00 and still reports its whole delta when it settles.
static func _case_night_splits_gap(res: Dictionary) -> void:
	_morning()
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 60, CampaignClock.now())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	CampaignClock.advance_to(16 * HOUR)
	scheduler.phase = ContractScheduler.Phase.GAP
	scheduler.gap_kind = ""
	scheduler.phase_minutes = 420
	scheduler.next_minute = CampaignClock.now() + 420
	TestFixtures.check(res, "split_gap_due", scheduler.next_due() == 22 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "split_gap_camps",
		scheduler.phase == ContractScheduler.Phase.NIGHT and scheduler.resume_minutes == 60,
		"phase %d minutes %d" % [scheduler.phase, scheduler.resume_minutes])
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "split_gap_resume_due", scheduler.next_due() == 31 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "split_gap_line",
		TestFixtures.has_line(contract_run.log_lines, "%s +7 h" % ContractManager.gap_tag("")), "no gap clock line")
	TestFixtures.check(res, "split_gap_next_phase", scheduler.phase == ContractScheduler.Phase.EVENT,
		"phase %d" % scheduler.phase)
	EventTrigger.missed_respites = 0
	_release(team)


#The closing respite pauses at 22:00 too and picks up its last four hours after the camp.
static func _case_night_splits_rest(res: Dictionary) -> void:
	_morning()
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 60, CampaignClock.now())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	CampaignClock.advance_to(20 * HOUR)
	scheduler.phase = ContractScheduler.Phase.CLOSING_REST
	scheduler.gap_kind = ""
	scheduler.phase_minutes = 360
	scheduler.next_minute = CampaignClock.now() + 360
	TestFixtures.check(res, "split_rest_due", scheduler.next_due() == 22 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "split_rest_camps",
		scheduler.phase == ContractScheduler.Phase.NIGHT and scheduler.resume_minutes == 240,
		"phase %d minutes %d" % [scheduler.phase, scheduler.resume_minutes])
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "split_rest_resume_due", scheduler.next_due() == 34 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "split_rest_line", TestFixtures.has_line(contract_run.log_lines, "respite +6 h"),
		"no respite clock line")
	TestFixtures.check(res, "split_rest_next_phase", scheduler.phase == ContractScheduler.Phase.TRAVEL_BACK,
		"phase %d" % scheduler.phase)
	EventTrigger.missed_respites = 0
	_release(team)


#A 50-hour march camps every night away: 14 h of the first day, then 16 h a day until it lands.
static func _case_night_every_night(res: Dictionary) -> void:
	var team: Array[MercenaryData] = _team(2, 5)
	_morning()
	EventTrigger.missed_respites = 0
	seed(777)
	var contract: ContractData = ContractGenerator.generate("Military")
	contract.rolled_mishaps.assign(["No Such Mishap", "No Such Mishap"])
	contract.assigned_primary_event = "No Such Event"
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 3000, CampaignClock.now())
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_SHIFT, seen)
	TestFixtures.check(res, "every_night_arrival", last_arrival == 4920, "arrived %d" % last_arrival)
	TestFixtures.check(res, "every_night_done",
		scheduler.is_done() and steps < STEP_CAP and CampaignClock.now() == 9360,
		"done %s steps %d now %d" % [str(scheduler.is_done()), steps, CampaignClock.now()])
	var nights: int = TestFixtures.count_lines(contract_run.log_lines, "CLOCK: night", true)
	TestFixtures.check(res, "every_night_camps", nights == 6, "night lines %d" % nights)
	TestFixtures.check(res, "every_night_rolls", EventTrigger.missed_respites == 6,
		"streak %d" % EventTrigger.missed_respites)
	TestFixtures.check(res, "every_night_verdict", contract_run.verdict == "Failed", "verdict %s" % contract_run.verdict)
	EventTrigger.missed_respites = 0
	_release(team)


#One scheduler suspended at the given minute of day 1, inspected without ever being driven.
static func _camp_at(minute: int) -> ContractScheduler:
	CampaignClock.reset()
	CampaignClock.advance(minute)
	var team: Array[MercenaryData] = _team(2, 3)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 240, CampaignClock.now())
	_release(team)
	return scheduler


#True when a REST TIME line follows the first night CLOCK line before the next CLOCK line of the run.
static func _rested_at_night(contract_run: ContractRun) -> bool:
	var start: int = -1
	for i: int in range(contract_run.log_lines.size()):
		if contract_run.log_lines[i].begins_with("CLOCK: night"):
			start = i
			break
	if start < 0:
		return false
	for i: int in range(start + 1, contract_run.log_lines.size()):
		var text: String = contract_run.log_lines[i]
		if text.begins_with("CLOCK: "):
			return false
		if text.begins_with("REST TIME:"):
			return true
	return false


#A camp pitched at 4:30 is too short to roll or rest: the party simply marches on at 6:00.
static func _case_short_night(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(4 * HOUR + 30)
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 3)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 240, CampaignClock.now())
	TestFixtures.check(res, "short_night_phase", scheduler.phase == ContractScheduler.Phase.NIGHT,
		"phase %d" % scheduler.phase)
	TestFixtures.check(res, "short_night_no_rest", not scheduler.night_rests,
		"night_rests %s" % str(scheduler.night_rests))
	TestFixtures.check(res, "short_night_wake", scheduler.next_minute == 6 * HOUR,
		"next %d" % scheduler.next_minute)
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_SHIFT, seen, 1)
	TestFixtures.check(res, "short_night_line", TestFixtures.has_line(contract_run.log_lines, "night +1 h 30 min"),
		"no 90 minute night line")
	TestFixtures.check(res, "short_night_silent", not _rested_at_night(contract_run),
		"a rest landed on a short night")
	TestFixtures.check(res, "short_night_arrival", last_arrival == 6 * HOUR + 240 and steps < STEP_CAP,
		"arrived %d steps %d" % [last_arrival, steps])
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	_release(team)


#A camp pitched at 3:00 rests its whole six hours, so the party only breaks camp at 9:00.
static func _case_long_night_after_midnight(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(3 * HOUR)
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = _team(2, 3)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 240, CampaignClock.now())
	TestFixtures.check(res, "long_night_phase", scheduler.phase == ContractScheduler.Phase.NIGHT,
		"phase %d" % scheduler.phase)
	TestFixtures.check(res, "long_night_rests", scheduler.night_rests, "night_rests false at 3:00")
	TestFixtures.check(res, "long_night_wake",
		scheduler.next_minute == 3 * HOUR + RestSystem.RESPITE_MINUTES,
		"next %d" % scheduler.next_minute)
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_SHIFT, seen)
	TestFixtures.check(res, "long_night_line", TestFixtures.has_line(contract_run.log_lines, "night +6 h"),
		"no 360 minute night line")
	TestFixtures.check(res, "long_night_rested", _rested_at_night(contract_run), "no rest landed on a full night")
	TestFixtures.check(res, "long_night_arrival", last_arrival == 9 * HOUR + 240 and steps < STEP_CAP,
		"arrived %d steps %d" % [last_arrival, steps])
	EventTrigger.missed_respites = 0
	_release(team)


#Two hours before 6:00 is the exact line between a camp that rests and one that only waits for dawn.
static func _case_night_boundary(res: Dictionary) -> void:
	var early: ContractScheduler = _camp_at(4 * HOUR)
	TestFixtures.check(res, "boundary_rests", early.night_rests, "night_rests false at 4:00")
	TestFixtures.check(res, "boundary_rests_wake", early.next_minute == 10 * HOUR,
		"next %d" % early.next_minute)
	var late: ContractScheduler = _camp_at(4 * HOUR + 1)
	TestFixtures.check(res, "boundary_waits", not late.night_rests, "night_rests true at 4:01")
	TestFixtures.check(res, "boundary_waits_wake", late.next_minute == 6 * HOUR,
		"next %d" % late.next_minute)


static func _case_missing_primary(res: Dictionary) -> void:
	_morning()
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	contract.rolled_mishaps.clear()
	contract.assigned_primary_event = "No Such Event"
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 60, CampaignClock.now())
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_SHIFT, seen)
	TestFixtures.check(res, "missing_done", scheduler.is_done() and steps <= 6, "steps %d" % steps)
	TestFixtures.check(res, "missing_line", TestFixtures.has_line(contract_run.log_lines, "EVENT MISSING: No Such Event"),
		"no missing line")
	TestFixtures.check(res, "missing_verdict", contract_run.verdict == "Failed", "verdict %s" % contract_run.verdict)
	TestFixtures.check(res, "missing_travelled_back", TestFixtures.has_line(contract_run.log_lines, "travel back"),
		"no travel back line")


static func _case_all_dead(res: Dictionary) -> void:
	_morning()
	var team: Array[MercenaryData] = _team(2, 4)
	var contract: ContractData = ContractGenerator.generate("Military")
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 60, CampaignClock.now())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	scheduler.phase = ContractScheduler.Phase.GAP
	scheduler.gap_kind = ""
	scheduler.phase_minutes = CampaignClock.EVENT_GAP_MINUTES
	scheduler.next_minute = CampaignClock.now() + CampaignClock.EVENT_GAP_MINUTES
	for merc: MercenaryData in team:
		merc.is_dead = true
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "dead_done", scheduler.is_done(), "phase %d" % scheduler.phase)
	TestFixtures.check(res, "dead_flag", scheduler.all_dead, "all_dead %s" % str(scheduler.all_dead))
	TestFixtures.check(res, "dead_no_travel_back", not TestFixtures.has_line(contract_run.log_lines, "travel back"),
		"a dead crew marched home")
	TestFixtures.check(res, "dead_verdict", contract_run.verdict == "Failed", "verdict %s" % contract_run.verdict)
	for merc: MercenaryData in team:
		merc.is_dead = false
	_release(team)


#The same contract lands the same phases at the same minutes, tick by the minute or by the shift.
static func _case_tick_sizes(res: Dictionary) -> void:
	var fine: Array[String] = await _seeded_schedule(TICK_MINUTE)
	var coarse: Array[String] = await _seeded_schedule(TICK_SHIFT)
	TestFixtures.check(res, "tick_step_count", fine.size() == coarse.size() and not fine.is_empty(),
		"minute %d shift %d" % [fine.size(), coarse.size()])
	var first_diff: int = -1
	for i: int in range(mini(fine.size(), coarse.size())):
		if fine[i] != coarse[i]:
			first_diff = i
			break
	TestFixtures.check(res, "tick_schedule_identical", first_diff < 0,
		"minute %s shift %s" % [str(fine), str(coarse)])


#Phase and due minute of every step; no event of the contract exists, so no roll can move the schedule.
static func _seeded_schedule(tick: int) -> Array[String]:
	var team: Array[MercenaryData] = _team(2, 5)
	_morning()
	EventTrigger.missed_respites = 0
	seed(777)
	var contract: ContractData = ContractGenerator.generate("Military")
	contract.rolled_mishaps.assign(["No Such Mishap", "No Such Mishap"])
	contract.assigned_primary_event = "No Such Event"
	var contract_run: ContractRun = _run_for(contract, team)
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, CampaignClock.TRAVEL_MINUTES,
		CampaignClock.now())
	var out: Array[String] = []
	var steps: int = 0
	while not scheduler.is_done() and steps < STEP_CAP:
		var target: int = mini(CampaignClock.now() + tick, scheduler.next_due())
		if target > CampaignClock.now():
			CampaignClock.advance_to(target)
		if CampaignClock.now() < scheduler.next_due():
			continue
		out.append("%d@%d" % [scheduler.phase, scheduler.next_due()])
		if scheduler.phase == ContractScheduler.Phase.NIGHT:
			EventTrigger.forced_d100 = 100
		await scheduler.step()
		steps += 1
	EventTrigger.missed_respites = 0
	_release(team)
	return out

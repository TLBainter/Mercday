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
	await _night_split(res, "gap", "gap", 16, ContractScheduler.Phase.GAP, 420, 60, 31,
		"%s +7 h" % ContractManager.gap_tag(""), ContractScheduler.Phase.EVENT)
	await _night_split(res, "rest", "respite", 20, ContractScheduler.Phase.CLOSING_REST, 360, 240, 34,
		"respite +6 h", ContractScheduler.Phase.TRAVEL_BACK, 100)
	await _case_night_every_night(res)
	await _case_short_night(res)
	await _case_long_night_after_midnight(res)
	_case_night_boundary(res)
	await _case_missing_primary(res)
	await _case_all_dead(res)
	await _case_flagged_mishap(res)
	await _case_tick_sizes(res)
	await _case_local_day(res)
	await _case_local_night(res)
	await _case_local_gap(res)
	await _case_local_midrun_night(res)
	_case_local_late(res)
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	CampaignClock.reset()
	return TestFixtures.summarize(res, "SCHEDULER")


#A reset clock reads D1 00:00, which is night, so every running-phase case starts at 8:00 instead.
static func _morning() -> void:
	CampaignClock.reset()
	CampaignClock.advance(8 * HOUR)


#One fresh team at the given level, registered as the guild roster.
static func _team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = TestFixtures.generated_team(size, level)
	GuildRoster.set_roster(team)
	return team


static func _military(team: Array[MercenaryData]) -> ContractRun:
	return TestFixtures.run_for(team, ContractGenerator.generate("Military"))


#A fresh team on a fresh Military contract, departed with this many minutes of travel.
static func _schedule(size: int, level: int, minutes: int) -> ContractScheduler:
	return ContractScheduler.create(_military(_team(size, level)), minutes, CampaignClock.now())


#A seeded contract whose events do not exist, so no roll can move its schedule.
static func _no_event_schedule(minutes: int) -> ContractScheduler:
	var team: Array[MercenaryData] = _team(2, 5)
	_morning()
	EventTrigger.missed_respites = 0
	seed(777)
	var contract_run: ContractRun = _military(team)
	contract_run.contract.rolled_mishaps.assign(["No Such Mishap", "No Such Mishap"])
	contract_run.contract.assigned_primary_event = "No Such Event"
	return ContractScheduler.create(contract_run, minutes, CampaignClock.now())


static func _release(team: Array[MercenaryData]) -> void:
	for merc: MercenaryData in team:
		merc.on_contract = false


#Advances the clock in ticks, landing exactly on each due minute, and steps every phase that comes due.
#night_d100 is forced before every NIGHT step, so a case can plant a roll that would fire.
#due_log gets the phase and due minute of every step.
static func _drive(scheduler: ContractScheduler, tick: int, seen: Array[int],
		night_d100: int = 100, due_log: Array[String] = []) -> int:
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
		due_log.append("%d@%d" % [stepped, scheduler.next_due()])
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
	var scheduler: ContractScheduler = _schedule(3, 5, 240)
	var contract_run: ContractRun = scheduler.run
	var contract: ContractData = contract_run.contract
	TestFixtures.check(res, "create_phase", scheduler.phase == ContractScheduler.Phase.TRAVEL_OUT,
		"phase %d" % scheduler.phase)
	TestFixtures.check(res, "create_due", scheduler.next_due() == start + 240, "due %d" % scheduler.next_due())
	TestFixtures.check(res, "create_departed", contract.status == "Active" and contract.team_uids.size() == 3,
		"status %s uids %d" % [contract.status, contract.team_uids.size()])
	var on_contract: bool = true
	for merc: MercenaryData in contract_run.team:
		if not merc.on_contract:
			on_contract = false
	TestFixtures.check(res, "create_on_contract", on_contract, "every merc marked on contract")
	TestFixtures.check(res, "create_header", not contract_run.log_lines.is_empty(),
		"log lines %d" % contract_run.log_lines.size())
	TestFixtures.check(res, "create_not_done", not scheduler.is_done(), "phase %d" % scheduler.phase)
	_release(contract_run.team)


static func _case_phase_order(res: Dictionary) -> void:
	_morning()
	seed(9110)
	var scheduler: ContractScheduler = _schedule(3, 6, CampaignClock.TRAVEL_MINUTES)
	var contract_run: ContractRun = scheduler.run
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
	TestFixtures.check(res, "order_verdict",
		contract_run.verdict != "" and contract_run.contract.status == contract_run.verdict,
		"verdict %s status %s" % [contract_run.verdict, contract_run.contract.status])
	var went: bool = TestFixtures.has_line(contract_run.log_lines, "travel out")
	var came: bool = scheduler.all_dead or TestFixtures.has_line(contract_run.log_lines, "travel back")
	TestFixtures.check(res, "order_travel_lines", went and came, "travel lines missing")
	EventTrigger.missed_respites = 0


static func _case_travel_minutes(res: Dictionary) -> void:
	_morning()
	var start: int = CampaignClock.now()
	var scheduler: ContractScheduler = _schedule(2, 4, 125)
	var contract_run: ContractRun = scheduler.run
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "travel_due_honored", CampaignClock.now() == start + 125, "now %d" % CampaignClock.now())
	TestFixtures.check(res, "travel_line", TestFixtures.has_line(contract_run.log_lines, "travel out +2 h 5 min"),
		"lines %s" % str(contract_run.log_lines.slice(maxi(0, contract_run.log_lines.size() - 3))))
	TestFixtures.check(res, "travel_next_phase", scheduler.phase == ContractScheduler.Phase.EVENT,
		"phase %d" % scheduler.phase)
	_release(contract_run.team)


#A party that signs at 23:00 camps on the spot and only marches once the wake respite has landed.
static func _case_night(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(23 * HOUR)
	EventTrigger.missed_respites = 0
	var scheduler: ContractScheduler = _schedule(2, 4, 0)
	var contract_run: ContractRun = scheduler.run
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
	_release(contract_run.team)


#Travel that runs into 22:00 stops there and finishes its remaining minutes after the wake.
static func _case_night_splits_travel(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(14 * HOUR)
	EventTrigger.missed_respites = 0
	var scheduler: ContractScheduler = _schedule(2, 4, 600)
	var contract_run: ContractRun = scheduler.run
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
	_release(contract_run.team)


#A gap or closing respite set at start_hour pauses at 22:00, resumes its remaining minutes after the camp and
#still reports its whole delta when it settles. last_d100 is forced before the settling step when not -1.
static func _night_split(res: Dictionary, tag: String, noun: String, start_hour: int, phase: int, minutes: int,
		want_resume: int, want_due_hour: int, want_line: String, want_next: int, last_d100: int = -1) -> void:
	_morning()
	EventTrigger.missed_respites = 0
	var scheduler: ContractScheduler = _schedule(2, 4, 60)
	var contract_run: ContractRun = scheduler.run
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	CampaignClock.advance_to(start_hour * HOUR)
	scheduler.phase = phase
	scheduler.gap_kind = ""
	scheduler.phase_minutes = minutes
	scheduler.next_minute = CampaignClock.now() + minutes
	TestFixtures.check(res, "split_%s_due" % tag, scheduler.next_due() == 22 * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "split_%s_camps" % tag,
		scheduler.phase == ContractScheduler.Phase.NIGHT and scheduler.resume_minutes == want_resume,
		"phase %d minutes %d" % [scheduler.phase, scheduler.resume_minutes])
	CampaignClock.advance_to(scheduler.next_due())
	EventTrigger.forced_d100 = 100
	await scheduler.step()
	TestFixtures.check(res, "split_%s_resume_due" % tag, scheduler.next_due() == want_due_hour * HOUR,
		"due %d" % scheduler.next_due())
	CampaignClock.advance_to(scheduler.next_due())
	if last_d100 >= 0:
		EventTrigger.forced_d100 = last_d100
	await scheduler.step()
	TestFixtures.check(res, "split_%s_line" % tag, TestFixtures.has_line(contract_run.log_lines, want_line),
		"no %s clock line" % noun)
	TestFixtures.check(res, "split_%s_next_phase" % tag, scheduler.phase == want_next,
		"phase %d" % scheduler.phase)
	EventTrigger.missed_respites = 0
	_release(contract_run.team)


#A 50-hour march camps every night away: 14 h of the first day, then 16 h a day until it lands.
static func _case_night_every_night(res: Dictionary) -> void:
	var scheduler: ContractScheduler = _no_event_schedule(3000)
	var contract_run: ContractRun = scheduler.run
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
	_release(contract_run.team)


#One scheduler suspended at the given minute of day 1, inspected without ever being driven.
static func _camp_at(minute: int) -> ContractScheduler:
	CampaignClock.reset()
	CampaignClock.advance(minute)
	var scheduler: ContractScheduler = _schedule(2, 3, 240)
	_release(scheduler.run.team)
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
	var scheduler: ContractScheduler = _schedule(2, 3, 240)
	var contract_run: ContractRun = scheduler.run
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
	_release(contract_run.team)


#A camp pitched at 3:00 rests its whole six hours, so the party only breaks camp at 9:00.
static func _case_long_night_after_midnight(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(3 * HOUR)
	EventTrigger.missed_respites = 0
	var scheduler: ContractScheduler = _schedule(2, 3, 240)
	var contract_run: ContractRun = scheduler.run
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
	_release(contract_run.team)


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
	var contract_run: ContractRun = _military(_team(2, 4))
	contract_run.contract.rolled_mishaps.clear()
	contract_run.contract.assigned_primary_event = "No Such Event"
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
	var scheduler: ContractScheduler = _schedule(2, 4, 60)
	var contract_run: ContractRun = scheduler.run
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	scheduler.phase = ContractScheduler.Phase.GAP
	scheduler.gap_kind = ""
	scheduler.phase_minutes = CampaignClock.EVENT_GAP_MINUTES
	scheduler.next_minute = CampaignClock.now() + CampaignClock.EVENT_GAP_MINUTES
	for merc: MercenaryData in contract_run.team:
		merc.is_dead = true
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "dead_done", scheduler.is_done(), "phase %d" % scheduler.phase)
	TestFixtures.check(res, "dead_flag", scheduler.all_dead, "all_dead %s" % str(scheduler.all_dead))
	TestFixtures.check(res, "dead_no_travel_back", not TestFixtures.has_line(contract_run.log_lines, "travel back"),
		"a dead crew marched home")
	TestFixtures.check(res, "dead_verdict", contract_run.verdict == "Failed", "verdict %s" % contract_run.verdict)
	for merc: MercenaryData in contract_run.team:
		merc.is_dead = false
	_release(contract_run.team)


#A stub mishap that always fails, written where ContractLibrary.event finds it; the caller removes the file.
static func _stub_mishap(event_name: String, flagged: bool) -> String:
	var e := EventData.new()
	e.event_name = event_name
	e.event_type = "Mishap"
	e.success_formula = "0"
	e.fail_ends_contract = flagged
	var path: String = ContractResourceBuilder.event_path(event_name)
	ResourceTextWriter.save(e, path, "EventData", ContractResourceBuilder.EVENT_SCRIPT)
	return path


#Travel out, then the one mishap; the respite roll is forced quiet so no triggered event adds an outcome.
static func _mishap_schedule(event_name: String, primary: String) -> ContractScheduler:
	var team: Array[MercenaryData] = _team(2, 5)
	_morning()
	seed(777)
	var contract_run: ContractRun = _military(team)
	contract_run.contract.rolled_mishaps.assign([event_name])
	if primary != "":
		contract_run.contract.assigned_primary_event = primary
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run, 60, CampaignClock.now())
	for i: int in range(2):
		CampaignClock.advance_to(scheduler.next_due())
		EventTrigger.forced_d100 = 100
		await scheduler.step()
	return scheduler


#A failed flagged mishap ends a stepped run the way execute does: closing respite, home, no primary.
static func _case_flagged_mishap(res: Dictionary) -> void:
	var flagged_path: String = _stub_mishap("TEST Flagged Slip", true)
	var plain_path: String = _stub_mishap("TEST Plain Slip", false)
	var flagged: ContractScheduler = await _mishap_schedule("TEST Flagged Slip", "")
	var contract_run: ContractRun = flagged.run
	var rest: int = ContractManager.rest_minutes(contract_run, RestSystem.KIND_RESPITE)
	var want: int = ContractScheduler.Phase.CLOSING_REST if rest > 0 else ContractScheduler.Phase.TRAVEL_BACK
	TestFixtures.check(res, "sched:flagged_closing_rest", flagged.phase == want
		and flagged.phase != ContractScheduler.Phase.GAP, "phase %d want %d" % [flagged.phase, want])
	TestFixtures.check(res, "sched:flagged_failed_event", contract_run.failed_event == "TEST Flagged Slip",
		"failed %s" % contract_run.failed_event)
	var steps: int = 0
	while not flagged.is_done() and steps < STEP_CAP:
		CampaignClock.advance_to(maxi(CampaignClock.now(), flagged.next_due()))
		EventTrigger.forced_d100 = 100
		await flagged.step()
		steps += 1
	TestFixtures.check(res, "sched:flagged_one_outcome", flagged.is_done() and contract_run.outcomes.size() == 1,
		"done %s outcomes %d" % [str(flagged.is_done()), contract_run.outcomes.size()])
	TestFixtures.check(res, "sched:flagged_no_primary", flagged.events_run == 1
		and not TestFixtures.has_line(contract_run.log_lines, "EVENT MISSING")
		and TestFixtures.has_line(contract_run.log_lines, "travel back"), "events_run %d" % flagged.events_run)
	_release(contract_run.team)
	var plain: ContractScheduler = await _mishap_schedule("TEST Plain Slip", "No Such Event")
	var plain_run: ContractRun = plain.run
	TestFixtures.check(res, "sched:flagged_unflagged_gap", plain.phase == ContractScheduler.Phase.GAP
		and plain_run.failed_event == "", "phase %d failed %s" % [plain.phase, plain_run.failed_event])
	CampaignClock.advance_to(plain.next_due())
	EventTrigger.forced_d100 = 100
	await plain.step()
	TestFixtures.check(res, "sched:flagged_unflagged_goes_on", plain.phase == ContractScheduler.Phase.EVENT
		and plain_run.outcomes.size() == 1, "phase %d outcomes %d" % [plain.phase, plain_run.outcomes.size()])
	_release(plain_run.team)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flagged_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(plain_path))
	EventTrigger.forced_d100 = -1


#A Local Military run at a wilderness place, created now; travel minutes are passed so the local rule must drop them.
static func _local_schedule(team: Array[MercenaryData], mishaps: Array[String], primary: String) -> ContractScheduler:
	var contract_run: ContractRun = _military(team)
	contract_run.contract.local = true
	contract_run.contract.rolled_mishaps.assign(mishaps)
	if primary != "":
		contract_run.contract.assigned_primary_event = primary
	contract_run.location = ContractFixtures.location("Aerdis")
	return ContractScheduler.create(contract_run, CampaignClock.TRAVEL_MINUTES, CampaignClock.now())


static func _travel_lines(lines: Array[String]) -> int:
	var count: int = 0
	for line: String in lines:
		if line.contains("travel out") or line.contains("travel back"):
			count += 1
	return count


#Card 736: a Local run starts at its event, heads home after the primary, never travels and never takes a closing rest.
static func _case_local_day(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(10 * HOUR)
	seed(7361)
	var start: int = CampaignClock.now()
	var team: Array[MercenaryData] = _team(3, 6)
	var scheduler: ContractScheduler = _local_schedule(team, [], "")
	var contract_run: ContractRun = scheduler.run
	TestFixtures.check(res, "local:create_event", scheduler.phase == ContractScheduler.Phase.EVENT
		and scheduler.next_due() == start, "phase %d due %d start %d" % [scheduler.phase, scheduler.next_due(), start])
	var seen: Array[int] = []
	var steps: int = await _drive(scheduler, TICK_MINUTE, seen, 1)
	TestFixtures.check(res, "local:day_done", scheduler.is_done() and steps < STEP_CAP
		and not seen.is_empty() and seen[0] == ContractScheduler.Phase.EVENT, "phases %s" % str(seen))
	var moved: bool = seen.has(ContractScheduler.Phase.TRAVEL_OUT) or seen.has(ContractScheduler.Phase.TRAVEL_BACK) \
		or seen.has(ContractScheduler.Phase.CLOSING_REST)
	TestFixtures.check(res, "local:day_no_closing_rest", not moved, "phases %s" % str(seen))
	TestFixtures.check(res, "local:day_no_travel_line", _travel_lines(contract_run.log_lines) == 0
		and TestFixtures.has_line(contract_run.log_lines, ContractManager.LOCAL_LINE),
		"travel lines %d" % _travel_lines(contract_run.log_lines))
	_release(contract_run.team)


#Card 736: a Local run created at 22:00 camps until 06:00, rests, and never rolls the wilderness trigger.
static func _case_local_night(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(22 * HOUR)
	var team: Array[MercenaryData] = _team(2, 5)
	var scheduler: ContractScheduler = _local_schedule(team, [], "")
	var contract_run: ContractRun = scheduler.run
	TestFixtures.check(res, "local:night_suspends", scheduler.phase == ContractScheduler.Phase.NIGHT
		and scheduler.resume_phase == ContractScheduler.Phase.EVENT and scheduler.next_due() == 30 * HOUR,
		"phase %d resume %d due %d" % [scheduler.phase, scheduler.resume_phase, scheduler.next_due()])
	team[0].stats[RestSystem.MAX_HP] = 20
	team[0].current_hp = 1
	EventTrigger.missed_respites = 3
	EventTrigger.forced_d100 = 1
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	EventTrigger.forced_d100 = -1
	TestFixtures.check(res, "local:night_rests", TestFixtures.has_line(contract_run.log_lines, "CLOCK: night")
		and _rested_at_night(contract_run) and team[0].current_hp > 1, "hp %d" % team[0].current_hp)
	TestFixtures.check(res, "local:night_no_roll", not TestFixtures.has_line(contract_run.log_lines, "AMBUSH ROLL")
		and EventTrigger.missed_respites == 3, "streak %d" % EventTrigger.missed_respites)
	TestFixtures.check(res, "local:night_resumes", scheduler.phase == ContractScheduler.Phase.EVENT
		and scheduler.next_due() >= 30 * HOUR, "phase %d due %d" % [scheduler.phase, scheduler.next_due()])
	EventTrigger.missed_respites = 0
	_release(contract_run.team)


#Card 736: a two-event Local run with HP lost takes its gap respite with recovery and no trigger roll.
static func _case_local_gap(res: Dictionary) -> void:
	var path: String = _stub_mishap("TEST Local Slip", false)
	_morning()
	seed(7362)
	var team: Array[MercenaryData] = _team(2, 5)
	var scheduler: ContractScheduler = _local_schedule(team, ["TEST Local Slip"], "No Such Event")
	var contract_run: ContractRun = scheduler.run
	team[0].current_hp = 1
	EventTrigger.forced_d100 = 1
	await scheduler.step()
	TestFixtures.check(res, "local:gap_respite_kind", scheduler.phase == ContractScheduler.Phase.GAP
		and scheduler.gap_kind == RestSystem.KIND_RESPITE, "phase %d kind %s" % [scheduler.phase, scheduler.gap_kind])
	var hp_before: int = team[0].current_hp
	EventTrigger.missed_respites = 3
	EventTrigger.forced_d100 = 1
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	TestFixtures.check(res, "local:gap_recovers", TestFixtures.has_line(contract_run.log_lines,
		"between events (%s)" % RestSystem.KIND_RESPITE) and team[0].current_hp > hp_before,
		"hp %d before %d" % [team[0].current_hp, hp_before])
	TestFixtures.check(res, "local:gap_no_roll", not TestFixtures.has_line(contract_run.log_lines, "AMBUSH ROLL")
		and EventTrigger.missed_respites == 3, "streak %d" % EventTrigger.missed_respites)
	var seen: Array[int] = []
	await _drive(scheduler, TICK_MINUTE, seen, 1)
	TestFixtures.check(res, "local:gap_home", scheduler.is_done() and _travel_lines(contract_run.log_lines) == 0,
		"done %s phases %s" % [str(scheduler.is_done()), str(seen)])
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	_release(contract_run.team)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


#Card 736: a Local run made at 21:30 meets 22:00 mid-run, camps with rest and no roll, then resumes its phase.
static func _case_local_midrun_night(res: Dictionary) -> void:
	var path: String = _stub_mishap("TEST Local Night Slip", false)
	CampaignClock.reset()
	CampaignClock.advance(21 * HOUR + 30)
	seed(7363)
	var team: Array[MercenaryData] = _team(2, 5)
	var scheduler: ContractScheduler = _local_schedule(team, ["TEST Local Night Slip"], "No Such Event")
	var contract_run: ContractRun = scheduler.run
	team[0].current_hp = 1
	EventTrigger.forced_d100 = 1
	var steps: int = 0
	while scheduler.phase != ContractScheduler.Phase.NIGHT and not scheduler.is_done() and steps < STEP_CAP:
		CampaignClock.advance_to(maxi(CampaignClock.now(), scheduler.next_due()))
		await scheduler.step()
		steps += 1
	var resume_phase: int = scheduler.resume_phase
	var resume_minutes: int = scheduler.resume_minutes
	TestFixtures.check(res, "local:midrun_night", scheduler.phase == ContractScheduler.Phase.NIGHT
		and scheduler.events_run == 1 and scheduler.next_due() == 30 * HOUR,
		"phase %d events %d due %d" % [scheduler.phase, scheduler.events_run, scheduler.next_due()])
	EventTrigger.missed_respites = 3
	EventTrigger.forced_d100 = 1
	CampaignClock.advance_to(scheduler.next_due())
	await scheduler.step()
	EventTrigger.forced_d100 = -1
	TestFixtures.check(res, "local:midrun_no_roll", EventTrigger.missed_respites == 3
		and not TestFixtures.has_line(contract_run.log_lines, "AMBUSH ROLL"), "streak %d" % EventTrigger.missed_respites)
	TestFixtures.check(res, "local:midrun_resume", scheduler.phase == resume_phase
		and resume_phase != ContractScheduler.Phase.NIGHT and scheduler.next_due() == 30 * HOUR + resume_minutes,
		"phase %d resume %d due %d minutes %d" % [scheduler.phase, resume_phase, scheduler.next_due(), resume_minutes])
	EventTrigger.missed_respites = 0
	_release(contract_run.team)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


#Card 736: a Local run made past its deadline fails late and goes home at once; one on time starts at its event.
static func _case_local_late(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(10 * HOUR)
	var late_run: ContractRun = _military(_team(2, 5))
	late_run.contract.local = true
	late_run.deadline_minute = CampaignClock.now() - 1
	var late: ContractScheduler = ContractScheduler.create(late_run, CampaignClock.TRAVEL_MINUTES, CampaignClock.now())
	TestFixtures.check(res, "local:late_fails", late.is_done() and late_run.failed_event == ContractManager.LATE_EVENT
		and _travel_lines(late_run.log_lines) == 0, "done %s failed %s travel lines %d"
		% [str(late.is_done()), late_run.failed_event, _travel_lines(late_run.log_lines)])
	_release(late_run.team)
	var on_time_run: ContractRun = _military(_team(2, 5))
	on_time_run.contract.local = true
	on_time_run.deadline_minute = CampaignClock.now() + 100 * HOUR
	var on_time: ContractScheduler = ContractScheduler.create(on_time_run, CampaignClock.TRAVEL_MINUTES,
		CampaignClock.now())
	TestFixtures.check(res, "local:on_time_runs", on_time.phase == ContractScheduler.Phase.EVENT
		and on_time_run.failed_event == "", "phase %d failed %s" % [on_time.phase, on_time_run.failed_event])
	_release(on_time_run.team)


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


#Phase and due minute of every step of the no-event contract.
static func _seeded_schedule(tick: int) -> Array[String]:
	var scheduler: ContractScheduler = _no_event_schedule(CampaignClock.TRAVEL_MINUTES)
	var out: Array[String] = []
	var seen: Array[int] = []
	var _steps: int = await _drive(scheduler, tick, seen, 100, out)
	EventTrigger.missed_respites = 0
	_release(scheduler.run.team)
	return out

class_name AutoFurloughTests

#Auto-Furlough (Mail plan 3.7): idle windows, their work hooks and the one Furlough each window pays.
#Plan tests 24, 55, 87-93, 95-97 and 104. Run inside the gui-mail-tests harness flag.

const DAY: int = CampaignClock.MINUTES_PER_DAY
const NEED: int = RestSystem.FURLOUGH_MINUTES
const LOC_ID: int = 1
const BAIL: int = 120
const SENTENCE: int = 10


static func run(res: Dictionary) -> void:
	_case_rr0_window(res)
	_case_no_furlough_branch(res)
	_case_hire_minute(res)
	_case_depart_breaks(res)
	_case_return_restarts(res)
	await _case_away(res)
	_case_captivity(res)
	_case_one_per_window(res)
	_case_poll_guard(res)
	_case_train(res)
	_case_note(res)
	_case_need(res)
	await _case_day_order(res)


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


#A roster merc at Rest Recovery 0 whose idle window opens now.
static func _idler() -> MercenaryData:
	var merc: MercenaryData = GameState.mercs[0]
	merc.stats["rest_recovery"] = 0.0
	merc.idle_since_minute = CampaignClock.now()
	return merc


static func _at(merc: MercenaryData, minute: int) -> Array[String]:
	if minute > CampaignClock.now():
		CampaignClock.advance_to(minute)
	var party: Array[MercenaryData] = [merc]
	return RestSystem.complete_due_rests(party, minute)


static func _count(lines: Array[String], merc: MercenaryData) -> int:
	var prefix: String = "FURLOUGH COMPLETE: %s " % merc.merc_name
	var n: int = 0
	for line: String in lines:
		if line.begins_with(prefix):
			n += 1
	return n


static func _line_with(lines: Array[String], head: String) -> String:
	for line: String in lines:
		if line.begins_with(head):
			return line
	return ""


static func _available(merc: MercenaryData) -> bool:
	var row: Dictionary = GameState.merc_status(merc)
	return int(row["status"]) == GuiTypes.MercStatus.AVAILABLE and RestSystem.is_deployable(merc)


#The merc departs on a generated contract, spends away minutes on it and comes home.
static func _round_trip(merc: MercenaryData, away: int) -> void:
	var party: Array[MercenaryData] = [merc]
	var trip: ContractRun = ContractRun.make(ContractGenerator.generate("Military"), party, Callable())
	ContractManager.depart(trip)
	CampaignClock.advance(away)
	ContractManager.arrive_home(trip)


#24: Rest Recovery 0 idle exactly 14400 minutes completes one Furlough and never leaves AVAILABLE.
static func _case_rr0_window(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var t0: int = merc.idle_since_minute
	var steady: bool = _available(merc)
	var early: Array[String] = _at(merc, t0 + int(NEED * 0.5))
	steady = steady and _available(merc)
	early.append_array(_at(merc, t0 + NEED - 1))
	steady = steady and _available(merc)
	var done: Array[String] = _at(merc, t0 + NEED)
	steady = steady and _available(merc)
	TestFixtures.check(res, "24 an RR 0 merc idle 14400 minutes completes one Furlough, AVAILABLE throughout",
		_count(early, merc) == 0 and _count(done, merc) == 1 and steady and merc.idle_since_minute == -2,
		"early %d done %d steady %s idle %d" % [_count(early, merc), _count(done, merc), steady,
			merc.idle_since_minute])


#55: no vacation days, no old entry points, no KIND_FURLOUGH branch; the verb still reaches every hook.
static func _case_no_furlough_branch(res: Dictionary) -> void:
	_fresh()
	TraitRuntime.clear_all()
	var merc: MercenaryData = _idler()
	merc.perks.append(TestFixtures.perk("TEST Auto Furlough Hook", "on:rest_complete:always:resource:excess_ep:+1",
		"Merc"))
	var only_furlough: Array[String] = [RestSystem.KIND_FURLOUGH]
	StateCascade.apply_state(merc, ConstStates.DEBILITATED, null, "", "", only_furlough)
	var held_before: bool = ConstStates.has_state(merc, ConstStates.DEBILITATED)
	var days_before: int = BenefitsManager.vacation_days_taken(merc.merc_uid)
	var ep_before: int = merc.excess_ep
	var lines: Array[String] = _at(merc, merc.idle_since_minute + NEED)
	var action: String = _line_with(lines, "REST ACTION: %s %s " % [merc.merc_name, RestSystem.KIND_FURLOUGH])
	var relax: int = 1 if action.begins_with("REST ACTION: %s %s Relax " % [merc.merc_name,
		RestSystem.KIND_FURLOUGH]) else 0
	TestFixtures.check(res, "55 an auto-Furlough leaves vacation_days_taken unchanged",
		_count(lines, merc) == 1 and BenefitsManager.vacation_days_taken(merc.merc_uid) == days_before,
		"days %d -> %d" % [days_before, BenefitsManager.vacation_days_taken(merc.merc_uid)])
	TestFixtures.check(res, "55 clear_by_verb, RestActions.take and fire_rest receive the furlough verb",
		held_before and not ConstStates.has_state(merc, ConstStates.DEBILITATED) and action != ""
			and merc.excess_ep == ep_before + 1 + relax,
		"held %s now %s action '%s' ep %d -> %d" % [held_before, ConstStates.has_state(merc,
			ConstStates.DEBILITATED), action, ep_before, merc.excess_ep])
	var names: Array[String] = []
	var script: Script = load("res://Scripts/Systems/RestSystem.gd")
	for method: Dictionary in script.get_script_method_list():
		names.append(String(method["name"]))
	TestFixtures.check(res, "55 furlough_start and furlough_complete are gone; KIND_FURLOUGH stays",
		names.has("idle_furlough") and not names.has("furlough_start") and not names.has("furlough_complete")
			and RestSystem.KIND_FURLOUGH == "furlough",
		"methods seen %d" % names.size())
	var lapsed: MercenaryData = GameState.mercs[1]
	lapsed.idle_since_minute = -2
	lapsed.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	lapsed.rest_lockout_start = CampaignClock.now() - DAY
	lapsed.rest_lockout_until = CampaignClock.now() - 1
	var swept: Array[String] = _at(lapsed, CampaignClock.now())
	TestFixtures.check(res, "55 complete_due_rests has no KIND_FURLOUGH lockout branch",
		_count(swept, lapsed) == 0 and lapsed.rest_lockout_kind == RestSystem.KIND_FURLOUGH
			and lapsed.idle_since_minute == -2,
		"lines %s kind %s" % [str(swept), lapsed.rest_lockout_kind])
	TraitRuntime.clear_all()


#87: the opening roster opens its window at the start minute, a hire at the hire minute.
static func _case_hire_minute(res: Dictionary) -> void:
	_fresh()
	var start: int = CampaignClock.now()
	var opened: bool = not GameState.mercs.is_empty()
	for merc: MercenaryData in GameState.mercs:
		if merc.idle_since_minute != start:
			opened = false
	CampaignClock.advance(300)
	var hired: MercenaryData = TestFixtures.add_mercs(1)[0]
	TestFixtures.check(res, "87 idle_since_minute is set at start_new_game and at the hire minute",
		opened and hired.idle_since_minute == CampaignClock.now(),
		"start %d hire %d at %d" % [start, hired.idle_since_minute, CampaignClock.now()])


#Moves the clock into the night of the current day so a dispatch queues for 6:00.
static func _to_night() -> void:
	var now: int = CampaignClock.now()
	if not ContractScheduler.is_night_minute(now):
		CampaignClock.advance_to(now - now % DAY + 23 * 60)


static func _queue(merc: MercenaryData) -> ActiveRun:
	var open: Array[BoardEntry] = GameState.board.available()
	var sent := ActiveRun.new()
	sent.travel_mode = "foot"
	sent.hours = 24.0
	var member := TeamMember.new()
	member.merc_uid = merc.merc_uid
	sent.team.append(member)
	if open.is_empty() or not GameState.dispatch(open[0].id, sent):
		return null
	return sent


#88: a queued commit and its call-off leave the window alone; the 6:00 departure breaks it.
static func _case_depart_breaks(res: Dictionary) -> void:
	_fresh()
	_to_night()
	var merc: MercenaryData = GameState.mercs[0]
	var t0: int = merc.idle_since_minute
	var first: ActiveRun = _queue(merc)
	var queued: bool = first != null and GameState.queued.has(first.entry_id)
	_at(merc, CampaignClock.now())
	var held: bool = merc.idle_since_minute == t0 and RestSystem.is_idle(merc)
	var called_off: bool = first != null and GameState.cancel_dispatch(first.entry_id)
	TestFixtures.check(res, "88 a queued dispatch and its call-off leave the idle window unchanged",
		queued and held and called_off and merc.idle_since_minute == t0,
		"queued %s held %s off %s idle %d t0 %d" % [queued, held, called_off, merc.idle_since_minute, t0])
	var second: ActiveRun = _queue(merc)
	var waiting: int = merc.idle_since_minute
	if second != null:
		CampaignClock.advance_to(second.depart_minute)
		GameState._depart_queued(second.depart_minute)
	TestFixtures.check(res, "88 idle breaks at ContractManager.depart, not at the dispatch commit",
		second != null and waiting == t0 and merc.on_contract and merc.idle_since_minute == -1,
		"sent %s before %d on %s idle %d" % [second != null, waiting, merc.on_contract, merc.idle_since_minute])
	var ripe: MercenaryData = GameState.mercs[1]
	ripe.stats["rest_recovery"] = 0.0
	var opened: int = ripe.idle_since_minute
	CampaignClock.advance_to(opened + NEED + 60)
	var party: Array[MercenaryData] = [ripe]
	var trip: ContractRun = ContractRun.make(ContractGenerator.generate("Military"), party, Callable())
	ContractManager.depart(trip)
	TestFixtures.check(res, "88 a Furlough the window earned before the departure completes at the departure",
		_count(trip.log_lines, ripe) == 1 and ripe.last_furlough_minute == opened + NEED and ripe.idle_since_minute == -1,
		"count %d last %d want %d idle %d" % [_count(trip.log_lines, ripe), ripe.last_furlough_minute, opened + NEED,
			ripe.idle_since_minute])
	ContractManager.arrive_home(trip)


#89: the return opens the window, the post-contract Respite counts, rests on the road never do.
static func _case_return_restarts(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var party: Array[MercenaryData] = [merc]
	var trip: ContractRun = ContractRun.make(ContractGenerator.generate("Military"), party, Callable())
	ContractManager.depart(trip)
	var road: Array[String] = _at(merc, CampaignClock.now() + 2 * NEED)
	var road_idle: int = merc.idle_since_minute
	ContractManager.arrive_home(trip)
	var back: int = CampaignClock.now()
	merc.stats["rest_recovery"] = 0.0
	var resting: bool = merc.rest_lockout_kind == RestSystem.KIND_RESPITE and merc.rest_lockout_until > back
	var respite: Array[String] = _at(merc, merc.rest_lockout_until)
	var before: Array[String] = _at(merc, back + NEED - 1)
	var done: Array[String] = _at(merc, back + NEED)
	TestFixtures.check(res, "89 rests on a contract never count toward the window",
		_count(road, merc) == 0 and road_idle == -1, "idle %d lines %d" % [road_idle, _count(road, merc)])
	TestFixtures.check(res, "89 the return opens the window and the 6 h Respite counts toward it",
		resting and _line_with(respite, "RESPITE: " + merc.merc_name) != "" and _count(before, merc) == 0
			and _count(done, merc) == 1,
		"resting %s respite %s before %d done %d" % [resting, str(respite), _count(before, merc),
			_count(done, merc)])


#90: every away status breaks the window; the return minute or clear_away opens the next.
static func _case_away(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(1)
	var lent: MercenaryData = GameState.mercs[0]
	var jobber: MercenaryData = GameState.mercs[1]
	var jailed: MercenaryData = GameState.mercs[2]
	var until: int = CampaignClock.now() + 120
	GameState.set_away(lent.merc_uid, GuiTypes.MercStatus.LOAN, until)
	GameState.set_away(jobber.merc_uid, GuiTypes.MercStatus.ODD_JOB)
	GameState.set_away(jailed.merc_uid, GuiTypes.MercStatus.CAPTURED)
	var broken: bool = lent.idle_since_minute == -1 and jobber.idle_since_minute == -1 \
		and jailed.idle_since_minute == -1
	TestFixtures.check(res, "90 LOAN, ODD_JOB and a legal hold break idle", broken,
		"loan %d job %d legal %d" % [lent.idle_since_minute, jobber.idle_since_minute, jailed.idle_since_minute])
	await GameState.process_until(until + 30)
	GameState.clear_away(jobber.merc_uid)
	TestFixtures.check(res, "90 _clear_returned_away and clear_away restart idle",
		lent.idle_since_minute == until and jobber.idle_since_minute == CampaignClock.now()
			and jailed.idle_since_minute == -1,
		"loan %d (until %d) job %d now %d legal %d" % [lent.idle_since_minute, until, jobber.idle_since_minute,
			CampaignClock.now(), jailed.idle_since_minute])
	GameState.clear_away(jailed.merc_uid)


#91: captivity breaks the window even past the return, and either release opens the next.
static func _case_captivity(res: Dictionary) -> void:
	_fresh()
	var taken: MercenaryData = GameState.mercs[0]
	taken.on_contract = true
	MercPool.add_captive(taken, "Escort", "Aerdis", "Day 1")
	var broken: bool = taken.idle_since_minute == -1
	taken.on_contract = false
	RestSystem.idle_restart(taken, CampaignClock.now())
	_at(taken, CampaignClock.now() + 60)
	var stayed: bool = taken.idle_since_minute == -1
	CampaignClock.advance(60)
	RescueContractBuilder.release(taken.merc_uid)
	var rescued: bool = taken.idle_since_minute == CampaignClock.now() and not SalarySystem.is_captive(taken)
	TestFixtures.check(res, "91 captivity breaks idle and RescueContractBuilder.release restarts it",
		broken and stayed and rescued, "broken %s stayed %s idle %d now %d" % [broken, stayed,
			taken.idle_since_minute, CampaignClock.now()])
	var jailed: MercenaryData = GameState.mercs[1]
	jailed.on_contract = true
	var row: CaptureData = LegalManager.add_capture(jailed.merc_uid, LOC_ID, "Brawling", -1, SENTENCE, BAIL)
	var held: bool = jailed.idle_since_minute == -1
	jailed.on_contract = false
	RestSystem.idle_restart(jailed, CampaignClock.now())
	var kept: bool = jailed.idle_since_minute == -1
	CampaignClock.advance(60)
	LegalManager._release(row)
	TestFixtures.check(res, "91 a legal hold breaks idle and the LegalManager release restarts it",
		held and kept and jailed.idle_since_minute == CampaignClock.now() and not GameState.is_away(jailed.merc_uid),
		"held %s kept %s idle %d now %d" % [held, kept, jailed.idle_since_minute, CampaignClock.now()])


#92: one Furlough per window; a contract round trip opens the next, which ends the last one's training.
static func _case_one_per_window(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var t0: int = merc.idle_since_minute
	var lines: Array[String] = _at(merc, t0 + 3 * NEED)
	lines.append_array(_at(merc, t0 + 3 * NEED + DAY))
	TestFixtures.check(res, "92 idle for 3 x need completes exactly one Furlough",
		_count(lines, merc) == 1 and merc.idle_since_minute == -2,
		"count %d idle %d" % [_count(lines, merc), merc.idle_since_minute])
	if merc.trained_bonus.is_empty():
		RestActions._train(merc)
	var trained: bool = not merc.trained_bonus.is_empty()
	_round_trip(merc, DAY)
	var back: int = CampaignClock.now()
	var reopened: bool = merc.idle_since_minute == back
	merc.stats["rest_recovery"] = 0.0
	var next: Array[String] = _at(merc, back + NEED)
	var line: String = _line_with(next, "FURLOUGH COMPLETE: " + merc.merc_name)
	TestFixtures.check(res, "92 a contract round trip opens a new window whose Furlough ends the training",
		trained and reopened and _count(next, merc) == 1 and line.contains("training ended")
			and merc.idle_since_minute == -2,
		"trained %s reopened %s line '%s'" % [trained, reopened, line])


#95: the poll in complete_due_rests backs up any hook a path lacks.
static func _case_poll_guard(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(2)
	var now: int = CampaignClock.now()
	var worker: MercenaryData = GameState.mercs[0]
	worker.on_contract = true
	worker.idle_since_minute = now - DAY
	var lost: MercenaryData = GameState.mercs[1]
	lost.missing_since = now
	lost.idle_since_minute = -1
	var idler: MercenaryData = GameState.mercs[2]
	idler.idle_since_minute = -1
	var spent: MercenaryData = GameState.mercs[3]
	spent.idle_since_minute = -2
	var party: Array[MercenaryData] = [worker, lost, idler, spent]
	RestSystem.complete_due_rests(party, now)
	TestFixtures.check(res, "95 the poll guard: working -1, idle or Missing at -1 gets now, -2 stays",
		worker.idle_since_minute == -1 and lost.idle_since_minute == now and idler.idle_since_minute == now
			and spent.idle_since_minute == -2,
		"worker %d lost %d idler %d spent %d" % [worker.idle_since_minute, lost.idle_since_minute,
			idler.idle_since_minute, spent.idle_since_minute])
	worker.on_contract = false
	lost.missing_since = -1


#96: a Furlough's Train pick is guild work that leaves the window counting.
static func _case_train(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var t0: int = merc.idle_since_minute
	var detail: String = RestActions._train(merc)
	_at(merc, t0 + DAY)
	TestFixtures.check(res, "96 RestActions._train does not break idle",
		detail != "" and merc.idle_since_minute == t0, "train '%s' idle %d t0 %d" % [detail,
			merc.idle_since_minute, t0])


#97: the progress note counts whole idle days against the need; the merc stays AVAILABLE.
static func _case_note(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var at: int = merc.idle_since_minute + 4 * DAY + 90
	_at(merc, at)
	var note: String = RestSystem.furlough_note(merc, at)
	TestFixtures.check(res, "97 furlough_note reads Furlough 4/10 d and the merc stays AVAILABLE",
		note == "Furlough 4/10 d" and _available(merc), "note '%s'" % note)


#104: the need follows rest_minutes from Rest Recovery (Healthiness), floored at one day.
static func _case_need(res: Dictionary) -> void:
	_fresh()
	var healths: Array[float] = []
	var want_healths: Array[float] = [50.0, -50.0]
	var sheet_spans: Array[int] = []
	var want_spans: Array[int] = [5 * DAY, 15 * DAY]
	for sheet: Array in [[85.0, 2], [0.0, 1]]:
		var probe: MercenaryData = TestFixtures.sheet_merc("Hale", float(sheet[0]), {"max_vigor": sheet[1], "max_wile": 1})
		probe.idle_since_minute = CampaignClock.now()
		healths.append(float(probe.stats.get("healthiness", 999.0)))
		var span: int = RestSystem.rest_minutes(probe, NEED)
		var early: Array[String] = _at(probe, probe.idle_since_minute + span - 1)
		var done: Array[String] = _at(probe, probe.idle_since_minute + span)
		sheet_spans.append(span if _count(early, probe) == 0 and _count(done, probe) == 1 else -span)
	TestFixtures.check(res, "104 Healthiness +50 completes after 5 idle days, -50 after 15",
		healths == want_healths and sheet_spans == want_spans,
		"health %s spans %s" % [str(healths), str(sheet_spans)])
	var spans: Array[int] = []
	var want: Array[int] = [DAY, DAY]
	for rr: float in [100.0, 150.0]:
		var merc: MercenaryData = _idler()
		merc.stats["rest_recovery"] = rr
		var need: int = RestSystem.rest_minutes(merc, NEED)
		var t0: int = merc.idle_since_minute
		var early: Array[String] = _at(merc, t0 + need - 1)
		var done: Array[String] = _at(merc, t0 + need)
		spans.append(need if _count(early, merc) == 0 and _count(done, merc) == 1 else -need)
	TestFixtures.check(res, "104 the Furlough need is never under 1440 minutes", spans == want, str(spans))


#93: the first day pass completes the Furlough (step 0) before day_tick (step 4) adds that day's pressure.
static func _case_day_order(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _idler()
	var need: int = RestSystem.rest_minutes(merc, NEED)
	var next: int = (GameState.day() + 1) * DAY
	merc.idle_since_minute = next - need
	BenefitsManager.tick(CampaignClock.now())
	merc.furlough_pressure = 50.0
	merc.fail_stress = 2.0
	var heard: Array[int] = [0]
	var hear: Callable = func() -> void: heard[0] += 1
	GameState.roster_changed.connect(hear)
	await GameState.process_until(next + 2 * DAY + 60)
	GameState.roster_changed.disconnect(hear)
	var v: float = VacationDesire.vulnerability(merc)
	var stress: float = 1.0 * pow(VacationDesire.FAIL_DECAY_PER_DAY, 3.0)
	TestFixtures.check(res, "93 a multi-day process_until completes the Furlough before day_tick sees the pressures",
		merc.last_furlough_minute == next and is_equal_approx(merc.furlough_pressure, 3.0 * v)
			and is_equal_approx(merc.fail_stress, stress),
		"last %d want %d pressure %.4f want %.4f stress %.4f want %.4f" % [merc.last_furlough_minute, next,
			merc.furlough_pressure, 3.0 * v, merc.fail_stress, stress])
	TestFixtures.check(res, "93 a Furlough step 0 completes reaches the roster: roster_changed fires, the book lines drain",
		heard[0] > 0 and BenefitsManager.book.furlough_lines.is_empty(), "roster_changed %d lines %d" % [heard[0],
			BenefitsManager.book.furlough_lines.size()])

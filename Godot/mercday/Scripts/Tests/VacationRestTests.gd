class_name VacationRestTests

#Mail plan M2: the vacation answers, the start-day pass, the day count, vacation rest and the queued hold.
#Plan tests 19-23, 25, 54, 61-64, 76-82, 94, 98, 102, 107-110 and 115. Run inside the gui-mail-tests harness flag.

const DAY: int = CampaignClock.MINUTES_PER_DAY
const NEED: int = RestSystem.FURLOUGH_MINUTES
const ALLOW: int = 40
const MAX_LEN: int = 30
const SEED: int = 7331
const FAR: int = 60
const FAKE_ID: int = 990001
const HOUR: int = 60


class OrderBook extends VacationBook:
	var order: Array[String] = []

	func day_passed(day: int) -> Array[int]:
		order.append("day")
		return super.day_passed(day)

	func cancel_held(team: Array[MercenaryData], today: int) -> void:
		order.append("held")
		super.cancel_held(team, today)


static func run(res: Dictionary) -> void:
	_case_answers(res)
	_case_shift_mail(res)
	_case_taken(res)
	_case_idle_vacations(res)
	_case_worked_until(res)
	_case_short(res)
	_case_spent_window(res)
	_case_lockout_furlough(res)
	_case_fail_stress(res)
	_case_year(res)
	_case_reminders(res)
	_case_lapse_and_auto(res)
	_case_busy_start(res, true)
	_case_busy_start(res, false)
	_case_shift_rules(res)
	_case_cancel_frees(res)
	await _case_roll_gate(res)
	await _case_queued_hold(res, false)
	await _case_queued_hold(res, true)
	_case_call_off(res)
	_case_late_call_off(res)
	_case_refund(res)
	_case_missing(res)
	_case_gone_rows(res)
	GuiVacationTests._fresh()


#A fresh campaign on the authored mail rows, a 40 day allowance, 30 day maximum and Rest Recovery 0 everywhere.
static func _boot(approval: bool = true, staff: int = 3) -> void:
	GuiVacationTests._fresh()
	if GameState.mercs.size() < staff:
		TestFixtures.add_mercs(staff - GameState.mercs.size())
	MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	MailCenter.reset()
	MailCenter._due.clear()
	BenefitsManager.set_vacation({"start": ALLOW, "max_len": MAX_LEN, "max_unit": "days", "approval": approval})
	BenefitsManager.tick(CampaignClock.now())
	BenefitsManager.book.rng.seed = SEED
	for merc: MercenaryData in GameState.mercs:
		merc.stats["rest_recovery"] = 0.0


static func _add(merc: MercenaryData, start: int, days: int,
		state: int = VacationRequest.State.APPROVED) -> VacationRequest:
	var req: VacationRequest = GuiVacationTests._row(merc.merc_uid, start, days, state)
	BenefitsManager.book.rows.append(req)
	return req


#One clock minute: the day passes due, the Furlough lines they made and every rest that has come due.
static func _step(minute: int) -> Array[String]:
	if minute > CampaignClock.now():
		CampaignClock.advance_to(minute)
	BenefitsManager.tick(minute)
	var lines: Array[String] = BenefitsManager.book.furlough_lines.duplicate()
	BenefitsManager.book.furlough_lines.clear()
	lines.append_array(RestSystem.complete_due_rests(GameState.mercs, minute))
	return lines


#Every midnight up to minute, then minute itself.
static func _walk(minute: int) -> Array[String]:
	var lines: Array[String] = []
	var next: int = (GameState.day() + 1) * DAY
	while next <= minute:
		lines.append_array(_step(next))
		next += DAY
	if minute > CampaignClock.now():
		lines.append_array(_step(minute))
	return lines


static func _mails_of(def_id: StringName) -> Array[MailInstance]:
	var out: Array[MailInstance] = []
	for folder: StringName in MailCatalog.FOLDERS:
		for archived: bool in [false, true]:
			for mail: MailInstance in MailCenter.mail_in(folder, archived):
				if mail.def_id == def_id:
					out.append(mail)
	return out


static func _has_line(lines: Array[String], head: String) -> bool:
	return AutoFurloughTests._line_with(lines, head) != ""


static func _taken(merc: MercenaryData) -> int:
	return BenefitsManager.vacation_days_taken(merc.merc_uid)


#A mailed request: the row in the live book and its R1, as the requested signal sends it.
static func _asked(merc: MercenaryData, start: int, days: int) -> VacationRequest:
	VacationDays.book_row(BenefitsManager.book, merc.merc_uid, start, days, GameState.day())
	return BenefitsManager.book.rows[BenefitsManager.book.rows.size() - 1]


static func _case_answers(res: Dictionary) -> void:
	_boot()
	var a: MercenaryData = GameState.mercs[0]
	var b: MercenaryData = GameState.mercs[1]
	var start: int = GameState.day() + FAR
	var free_b: int = BenefitsManager.book.free_days(b.merc_uid)
	var yes: VacationRequest = _asked(a, start, 5)
	var no: VacationRequest = _asked(b, start, 5)
	var taken: Array[int] = [_taken(a), _taken(b)]
	MailCenter.choose(yes.mail_id, 0)
	MailCenter.choose(no.mail_id, 1)
	TestFixtures.check(res, "19 vac:approve sets APPROVED and leaves vacation_days_taken unchanged",
		yes.state == VacationRequest.State.APPROVED and _taken(a) == taken[0] and yes.mail_id != &"",
		"state %d taken %d -> %d" % [yes.state, taken[0], _taken(a)])
	TestFixtures.check(res, "20 vac:deny sets DENIED and leaves vacation days alone",
		no.state == VacationRequest.State.DENIED and _taken(b) == taken[1]
			and BenefitsManager.book.free_days(b.merc_uid) == free_b,
		"state %d taken %d free %d want %d" % [no.state, _taken(b), BenefitsManager.book.free_days(b.merc_uid), free_b])


static func _case_shift_mail(res: Dictionary) -> void:
	_boot()
	var option: Dictionary = MailCatalog.options(MailCatalog.VAC_REQUEST)[2]
	var fx: PackedStringArray = option["fx"]
	var n: int = 0
	for token: String in fx:
		if token.begins_with("vac:shift:"):
			n = int(token.get_slice(":", 2))
	var req: VacationRequest = _asked(GameState.mercs[0], GameState.day() + FAR, 4)
	var start: int = req.start_day
	MailCenter.choose(req.mail_id, 2)
	MailCenter.tick(CampaignClock.advance(DAY))
	var next: StringName = StringName(String(option["next"]))
	var follow: Array[MailInstance] = _mails_of(next)
	TestFixtures.check(res, "21 vac:shift:N sets APPROVED, moves start_day by N and delivers only the Next row",
		n != 0 and req.state == VacationRequest.State.APPROVED and req.start_day == start + n and follow.size() == 1
			and follow[0].parent == req.mail_id and _mails_of(MailCatalog.VAC_REQUEST).size() == 1,
		"n %d state %d start %d -> %d next %d requests %d" % [n, req.state, start, req.start_day, follow.size(),
			_mails_of(MailCatalog.VAC_REQUEST).size()])


#22, 23, 78 and 80: the start, the lockout, the day count and a death mid-vacation.
static func _case_taken(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var dies: MercenaryData = GameState.mercs[1]
	var s: int = GameState.day() + 2
	var req: VacationRequest = _add(m, s, 5)
	var dead_row: VacationRequest = _add(dies, s, 5)
	_walk(s * DAY)
	var status: int = int(GameState.merc_status(m)["status"])
	TestFixtures.check(res, "22 on start_day: lockout vacation until (end_day + 1) * 1440, status VACATION, not deployable",
		req.state == VacationRequest.State.TAKEN and m.rest_lockout_kind == RestSystem.KIND_VACATION
			and m.rest_lockout_until == (req.end_day() + 1) * DAY and status == GuiTypes.MercStatus.VACATION
			and not RestSystem.is_deployable(m),
		"state %d kind '%s' until %d status %d" % [req.state, m.rest_lockout_kind, m.rest_lockout_until, status])
	var open: Array[BoardEntry] = GameState.board.available()
	var sent := ActiveRun.new()
	sent.travel_mode = "foot"
	sent.hours = 24.0
	var member := TeamMember.new()
	member.merc_uid = m.merc_uid
	sent.team.append(member)
	var refused: bool = not open.is_empty() and not GameState.dispatch(open[0].id, sent)
	var team: Array[MercenaryData] = [m]
	BenefitsManager.book.cancel(req)
	BenefitsManager.book.cancel_held(team, s)
	var kept: bool = req.state == VacationRequest.State.TAKEN
	_walk((s + 2) * DAY)
	var two: Array[int] = [_taken(m), _taken(dies)]
	dies.is_dead = true
	_walk((req.end_day() + 4) * DAY)
	TestFixtures.check(res, "23 each completed vacation day adds 1; a 5 day vacation takes exactly 5",
		two[0] == 2 and _taken(m) == 5 and req.counted == 5, "after 2 days %d, end %d" % [two[0], _taken(m)])
	TestFixtures.check(res, "78 a TAKEN merc is not deployable, dispatch refuses it, no cancel path mid-vacation",
		refused and kept and _taken(m) == req.days, "refused %s kept %s" % [refused, kept])
	TestFixtures.check(res, "80 a dead merc's TAKEN row counts no days",
		two[1] == 2 and _taken(dies) == 2 and dead_row.counted == 2, "taken %d counted %d" % [_taken(dies),
			dead_row.counted])


#25: vacation days are idle days toward the one Furlough of the window.
static func _case_idle_vacations(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var d0: int = GameState.day() + 1
	var s: int = d0 + 5
	var req: VacationRequest = _add(m, s, 5)
	var lines: Array[String] = _walk(d0 * DAY - HOUR)
	m.idle_since_minute = CampaignClock.now()
	var due: int = m.idle_since_minute + NEED
	lines = _walk((req.end_day() + 1) * DAY)
	var on_last: bool = due >= req.end_day() * DAY and due < (req.end_day() + 1) * DAY
	TestFixtures.check(res, "25 5 idle days then a 5 day vacation complete one Furlough on the vacation's last day",
		on_last and AutoFurloughTests._count(lines, m) == 1 and m.last_furlough_minute == due,
		"count %d last %d want %d" % [AutoFurloughTests._count(lines, m), m.last_furlough_minute, due])
	var got: Array[int] = []
	var want: Array[int] = []
	for days: int in [10, 14]:
		_boot()
		var merc: MercenaryData = GameState.mercs[0]
		var start: int = GameState.day() + 2
		var row: VacationRequest = _add(merc, start, days)
		_walk(start * DAY - 1)
		merc.idle_since_minute = CampaignClock.now()
		var all: Array[String] = _walk((row.end_day() + 1) * DAY + 20 * DAY)
		got.append(AutoFurloughTests._count(all, merc))
		got.append(merc.last_furlough_minute)
		want.append(1)
		want.append(start * DAY - 1 + NEED)
	TestFixtures.check(res, "25 a 10 day vacation alone completes one Furlough at its end; a 14 day one exactly one",
		got == want, "got %s want %s" % [got, want])


#102, 76 and 94: a merc back from work the hour before its vacation completes one Furlough mid-vacation.
static func _case_worked_until(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var s: int = GameState.day() + 2
	var req: VacationRequest = _add(m, s, 12)
	m.on_contract = true
	_walk(s * DAY - HOUR)
	m.on_contract = false
	RestSystem.idle_restart(m, CampaignClock.now())
	var window: int = m.idle_since_minute
	var lines: Array[String] = _walk(window + NEED - 1)
	m.fail_stress = 4.0
	m.furlough_pressure = 30.0
	m.deficit_pressure = 0.0
	lines.append_array(_walk(window + NEED))
	var halved: bool = is_equal_approx(m.fail_stress, 2.0) and m.furlough_pressure == 0.0
	var held: bool = m.rest_lockout_kind == RestSystem.KIND_VACATION and m.rest_lockout_until == (req.end_day() + 1) * DAY
	lines.append_array(_walk((req.end_day() + 3) * DAY))
	TestFixtures.check(res, "102 worked until the start: one Furlough at window start + need, every day counted",
		window == s * DAY - HOUR and AutoFurloughTests._count(lines, m) == 1 and m.last_furlough_minute == window + NEED
			and _taken(m) == req.days,
		"window %d count %d last %d taken %d" % [window, AutoFurloughTests._count(lines, m), m.last_furlough_minute,
			_taken(m)])
	TestFixtures.check(res, "76 a Furlough inside a vacation halves fail_stress, zeroes pressure, sets last_furlough_minute",
		halved, "fail %.3f furlough %.3f" % [m.fail_stress, m.furlough_pressure])
	TestFixtures.check(res, "94 a Furlough inside a vacation lockout leaves the lockout in place", held,
		"kind '%s' until %d" % [m.rest_lockout_kind, m.rest_lockout_until])


#77: a vacation shorter than the need ends with the Respite recovery and keeps the window counting.
static func _case_short(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var s: int = GameState.day() + 2
	var req: VacationRequest = _add(m, s, 3)
	_walk(s * DAY - 1)
	m.idle_since_minute = CampaignClock.now()
	var window: int = m.idle_since_minute
	var lines: Array[String] = _walk((req.end_day() + 1) * DAY)
	var name: String = m.merc_name
	TestFixtures.check(res, "77 a short vacation ends with Respite recovery, its pick and _unlock; the window keeps counting",
		_has_line(lines, "VACATION COMPLETE: %s" % name) and _has_line(lines, "RESPITE: %s " % name)
			and _has_line(lines, "REST ACTION: %s %s " % [name, RestSystem.KIND_RESPITE])
			and m.rest_lockout_kind == "" and m.rest_lockout_until == 0 and m.rest_lockout_start == -1
			and m.idle_since_minute == window and AutoFurloughTests._count(lines, m) == 0,
		"kind '%s' until %d idle %d want %d lines %s" % [m.rest_lockout_kind, m.rest_lockout_until,
			m.idle_since_minute, window, lines])


#109: a spent window (-2) at the start: no Furlough however long the vacation; the Respite recovery ends it.
static func _case_spent_window(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var s: int = GameState.day() + 2
	var req: VacationRequest = _add(m, s, 12)
	_walk(s * DAY - 1)
	m.idle_since_minute = -2
	m.last_furlough_minute = CampaignClock.now() - DAY
	var last: int = m.last_furlough_minute
	var lines: Array[String] = _walk((req.end_day() + 1) * DAY)
	TestFixtures.check(res, "109 a spent window takes no Furlough on a long vacation; the Respite recovery ends it",
		AutoFurloughTests._count(lines, m) == 0 and m.last_furlough_minute == last and m.idle_since_minute == -2
			and _has_line(lines, "VACATION COMPLETE: %s" % m.merc_name) and _has_line(lines, "RESPITE: %s " % m.merc_name),
		"count %d last %d idle %d" % [AutoFurloughTests._count(lines, m), m.last_furlough_minute, m.idle_since_minute])


#94: a Respite or vacation lockout running when the Furlough comes due stays in place.
static func _case_lockout_furlough(res: Dictionary) -> void:
	_boot()
	var now: int = CampaignClock.now()
	var rest: MercenaryData = GameState.mercs[0]
	var away: MercenaryData = GameState.mercs[1]
	rest.rest_lockout_kind = RestSystem.KIND_RESPITE
	rest.rest_lockout_start = now
	rest.rest_lockout_until = now + 2 * DAY
	RestSystem.vacation_start(away, now + 3 * DAY, now)
	var bad: Array[String] = []
	for merc: MercenaryData in [rest, away]:
		var kind: String = merc.rest_lockout_kind
		var until: int = merc.rest_lockout_until
		merc.idle_since_minute = now - NEED + HOUR
		var lines: Array[String] = AutoFurloughTests._at(merc, now + 2 * HOUR)
		if AutoFurloughTests._count(lines, merc) != 1 or merc.rest_lockout_kind != kind or merc.rest_lockout_until != until:
			bad.append("%s '%s' %d" % [merc.merc_name, merc.rest_lockout_kind, merc.rest_lockout_until])
	TestFixtures.check(res, "94 a merc inside a Respite or vacation lockout completes its Furlough; the lockout stays",
		bad.is_empty(), "%s" % [bad])


static func _case_fail_stress(res: Dictionary) -> void:
	_boot()
	var alive: MercenaryData = GameState.mercs[0]
	var dead: MercenaryData = GameState.mercs[1]
	for merc: MercenaryData in [alive, dead]:
		merc.fail_stress = 1.0
	var result := ContractResultData.new()
	result.failed = true
	for pair: Array in [[alive, ResultMemberData.Fate.ALIVE], [dead, ResultMemberData.Fate.DEAD]]:
		var member := ResultMemberData.new()
		member.uid = (pair[0] as MercenaryData).merc_uid
		member.fate = int(pair[1])
		result.members.append(member)
	var v: float = VacationDesire.vulnerability(alive)
	GameState._fail_stress(result)
	var raised: float = alive.fail_stress
	VacationDesire.day_tick(alive)
	var decayed: float = alive.fail_stress
	alive.furlough_pressure = 9.0
	alive.deficit_pressure = 4.0
	VacationDesire.on_furlough(alive, 777)
	TestFixtures.check(res, "76 fail_stress: + v per ALIVE member, x 0.98282 a day; on_furlough halves it and zeroes both",
		is_equal_approx(raised, 1.0 + v) and is_equal_approx(dead.fail_stress, 1.0)
			and is_equal_approx(decayed, raised * VacationDesire.FAIL_DECAY_PER_DAY)
			and is_equal_approx(alive.fail_stress, decayed * 0.5) and alive.furlough_pressure == 0.0
			and alive.deficit_pressure == 0.0 and alive.last_furlough_minute == 777,
		"raised %.4f (v %.4f) dead %.4f decayed %.4f after %.4f" % [raised, v, dead.fail_stress, decayed,
			alive.fail_stress])


#54: Daith 1 counts against the old year, then the count clears entering Daith 2.
static func _case_year(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var year: int = TrynnCalendar.DAYS_PER_YEAR
	var daith1: int = (int(GameState.day() / float(year)) + 1) * year
	var req: VacationRequest = _add(m, daith1 - 2, 3, VacationRequest.State.TAKEN)
	_walk(daith1 * DAY)
	var before: int = _taken(m)
	_walk((daith1 + 1) * DAY)
	TestFixtures.check(res, "54 vacation_taken clears entering Daith 2 after the Daith 1 day was counted",
		before == 2 and req.counted == 3 and _taken(m) == 0, "before %d counted %d after %d" % [before, req.counted,
			_taken(m)])


static func _case_reminders(res: Dictionary) -> void:
	_boot()
	var req: VacationRequest = _asked(GameState.mercs[0], GameState.day() + FAR, 3)
	var asked: int = req.asked_day
	_walk((asked + 40) * DAY)
	var nudges: Array[MailInstance] = _mails_of(MailCatalog.VAC_REMIND)
	var days: Array[int] = [asked]
	for mail: MailInstance in nudges:
		days.append(mail.received_day)
	days.sort()
	var spaced: bool = nudges.size() >= 3
	for i: int in range(1, days.size()):
		var gap: int = days[i] - days[i - 1]
		if gap < VacationBook.REMIND_MIN or gap > VacationBook.REMIND_MAX:
			spaced = false
	var threaded: bool = nudges.all(func(mail: MailInstance) -> bool: return mail.parent == req.mail_id)
	var nudge: MailInstance = nudges[0] if not nudges.is_empty() else null
	if nudge != null:
		MailCenter.choose(nudge.id, 0)
	MailCenter.choose(req.mail_id, 1)
	var first: MailInstance = MailCenter.get_mail(req.mail_id)
	TestFixtures.check(res, "61 R1M every 7-14 days on the R1 thread; approving from R1M makes a later R1 choice do nothing",
		spaced and threaded and req.state == VacationRequest.State.APPROVED and first != null and first.choice == -1,
		"days %s threaded %s state %d" % [days, threaded, req.state])


static func _case_lapse_and_auto(res: Dictionary) -> void:
	_boot()
	var req: VacationRequest = _asked(GameState.mercs[0], GameState.day() + 3, 2)
	_walk(req.start_day * DAY)
	var lapse: Array[MailInstance] = _mails_of(MailCatalog.VAC_REJECT)
	TestFixtures.check(res, "63 a request still PENDING on start_day lapses to REJECTED with R1X",
		req.state == VacationRequest.State.REJECTED and lapse.size() == 1 and lapse[0].parent == req.mail_id,
		"state %d R1X %d" % [req.state, lapse.size()])
	_boot(false)
	var before: int = GuiVacationTests._mail_count()
	var auto: VacationRequest = _asked(GameState.mercs[0], GameState.day() + 3, 2)
	var listed: bool = MailCenter.vacation_spans(auto.start_day, auto.start_day).has(auto)
	var silent: bool = GuiVacationTests._mail_count() == before
	_walk(auto.start_day * DAY)
	TestFixtures.check(res, "64 approval OFF: no mail, APPROVED auto with no mail_id, in vacation_spans, and it starts",
		silent and listed and auto.auto and auto.mail_id == &"" and auto.state == VacationRequest.State.TAKEN
			and GuiVacationTests._mail_count() == before,
		"silent %s listed %s auto %s state %d" % [silent, listed, auto.auto, auto.state])


#62 (approval ON) and 79 (approval OFF): busy on the start day cancels; a merc on Respite starts.
static func _case_busy_start(res: Dictionary, approval: bool) -> void:
	_boot(approval, 4)
	var working: MercenaryData = GameState.mercs[0]
	var away: MercenaryData = GameState.mercs[1]
	var caught: MercenaryData = GameState.mercs[2]
	var resting: MercenaryData = GameState.mercs[3]
	var s: int = GameState.day() + 2
	var busy: Array[VacationRequest] = []
	var free: Array[int] = []
	for merc: MercenaryData in [working, away, caught]:
		free.append(BenefitsManager.book.free_days(merc.merc_uid))
		var req: VacationRequest = _add(merc, s, 3)
		req.auto = not approval
		busy.append(req)
	var rest_row: VacationRequest = _add(resting, s, 3)
	working.on_contract = true
	GameState.set_away(away.merc_uid, GuiTypes.MercStatus.ODD_JOB)
	caught.on_contract = true
	MercPool.add_captive(caught, "Escort", "Aerdis", "Day 1")
	caught.on_contract = false
	_walk(s * DAY - HOUR)
	resting.rest_lockout_kind = RestSystem.KIND_RESPITE
	resting.rest_lockout_start = CampaignClock.now()
	resting.rest_lockout_until = CampaignClock.now() + 3 * DAY
	var mails: int = GuiVacationTests._mail_count()
	_walk(s * DAY + HOUR)
	var bad: Array[String] = []
	for i: int in busy.size():
		var merc: MercenaryData = GameState.merc_by_uid(busy[i].merc_uid)
		if busy[i].state != VacationRequest.State.CANCELLED or merc.rest_lockout_kind != "" or _taken(merc) != 0 \
				or BenefitsManager.book.free_days(merc.merc_uid) != free[i]:
			bad.append("%s state %d kind '%s'" % [merc.merc_name, busy[i].state, merc.rest_lockout_kind])
	var cancels: int = _mails_of(MailCatalog.VAC_CANCEL).size()
	var started: bool = rest_row.state == VacationRequest.State.TAKEN \
		and resting.rest_lockout_kind == RestSystem.KIND_VACATION
	GameState.clear_away(away.merc_uid)
	RescueContractBuilder.release(caught.merc_uid)
	working.on_contract = false
	if approval:
		TestFixtures.check(res, "62 on contract, away or captive on start_day: CANCELLED with R1C, no lockout or days; Respite starts",
			bad.is_empty() and cancels == 3 and started, "bad %s R1C %d started %s" % [bad, cancels, started])
	else:
		TestFixtures.check(res, "79 approval OFF: on contract, away or captive on start_day cancels with no mail of any kind",
			bad.is_empty() and GuiVacationTests._mail_count() == mails and started,
			"bad %s mail %d -> %d started %s" % [bad, mails, GuiVacationTests._mail_count(), started])


static func _case_shift_rules(res: Dictionary) -> void:
	_boot()
	var book: VacationBook = BenefitsManager.book
	var a: MercenaryData = GameState.mercs[0]
	var today: int = GameState.day()
	_add(GameState.mercs[1], today + FAR, 5)
	_add(GameState.mercs[2], today + FAR, 5)
	_add(a, today + FAR + 20, 2)
	var crowded: VacationRequest = _add(a, today + FAR - 15, 3, VacationRequest.State.PENDING)
	var early: VacationRequest = _add(a, today + FAR - 10, 2, VacationRequest.State.PENDING)
	var into: int = today + FAR + 1
	var blocked: bool = not book.can_book(a.merc_uid, into, 3) and not book.can_book(a.merc_uid, today + 30, 2)
	var moved: bool = book.shift(crowded, into - crowded.start_day) and book.shift(early, today + 30 - early.start_day)
	TestFixtures.check(res, "81 shift(req, n) that breaks gap, max_at or the 41 day lead still applies",
		blocked and moved and crowded.state == VacationRequest.State.APPROVED and crowded.start_day == into
			and early.state == VacationRequest.State.APPROVED and early.start_day == today + 30,
		"blocked %s moved %s starts %d %d" % [blocked, moved, crowded.start_day, early.start_day])


static func _case_cancel_frees(res: Dictionary) -> void:
	_boot()
	var book: VacationBook = BenefitsManager.book
	var a: MercenaryData = GameState.mercs[0]
	var today: int = GameState.day()
	var free: int = book.free_days(a.merc_uid)
	var req: VacationRequest = _add(a, today + FAR, 5)
	var booked: int = book.free_days(a.merc_uid)
	var cap_open: int = book.wish_cap(a.merc_uid, today)
	book.cancel(req)
	TestFixtures.check(res, "82 a cancelled row frees its days and the merc can roll again",
		booked == free - 5 and cap_open == 0 and req.state == VacationRequest.State.CANCELLED
			and book.free_days(a.merc_uid) == free and book.wish_cap(a.merc_uid, today) > 0,
		"free %d booked %d after %d cap %d -> %d" % [free, booked, book.free_days(a.merc_uid), cap_open,
			book.wish_cap(a.merc_uid, today)])


#98: the 08:00 roll reaches available and Respite mercs only; the day pass ticks every merc's pressure once.
static func _case_roll_gate(res: Dictionary) -> void:
	_boot(true, 6)
	var saved: VacationBook = BenefitsManager.book
	var spy: GuiVacationTests.Spy = GuiVacationTests._install()
	spy.rng.seed = SEED
	var now: int = CampaignClock.now()
	var working: MercenaryData = GameState.mercs[1]
	var away: MercenaryData = GameState.mercs[2]
	var caught: MercenaryData = GameState.mercs[3]
	var on_leave: MercenaryData = GameState.mercs[4]
	var resting: MercenaryData = GameState.mercs[5]
	working.on_contract = true
	GameState.set_away(away.merc_uid, GuiTypes.MercStatus.ODD_JOB)
	caught.on_contract = true
	MercPool.add_captive(caught, "Escort", "Aerdis", "Day 1")
	caught.on_contract = false
	RestSystem.vacation_start(on_leave, now + 5 * DAY, now)
	resting.rest_lockout_kind = RestSystem.KIND_RESPITE
	resting.rest_lockout_start = now
	resting.rest_lockout_until = now + 5 * DAY
	var before: Array[float] = []
	var grow: Array[float] = []
	for merc: MercenaryData in GameState.mercs:
		before.append(merc.furlough_pressure)
		grow.append(VacationDesire.vulnerability(merc))
	var wish_at: int = ContractScheduler.next_hour_after(now, GameState.WISH_HOUR)
	await GameState.process_until(wish_at)
	var rolled: Array[int] = []
	var want: Array[int] = []
	for i: int in GameState.mercs.size():
		if spy.wishes.has(GameState.mercs[i].merc_uid):
			rolled.append(i)
		if i == 0 or i >= 5:
			want.append(i)
	var ticked: bool = true
	for i: int in GameState.mercs.size():
		if not is_equal_approx(GameState.mercs[i].furlough_pressure, before[i] + grow[i]):
			ticked = false
	GameState.clear_away(away.merc_uid)
	RescueContractBuilder.release(caught.merc_uid)
	working.on_contract = false
	BenefitsManager.book = saved
	TestFixtures.check(res, "98 the 08:00 roll reaches available and Respite mercs only; day_tick runs once for every status",
		spy.calls == [wish_at] and rolled == want and ticked, "calls %s rolled %s want %s ticked %s" % [spy.calls,
			rolled, want, ticked])


#A run queued at 23:00 for the merc list: on the board's first open posting, or forced under FAKE_ID when forced.
static func _queue(mercs: Array[MercenaryData], forced: bool) -> ActiveRun:
	AutoFurloughTests._to_night()
	var sent := ActiveRun.new()
	sent.travel_mode = "foot"
	sent.return_mode = "foot"
	sent.hours = 24.0
	for merc: MercenaryData in mercs:
		var member := TeamMember.new()
		member.merc_uid = merc.merc_uid
		sent.team.append(member)
	if forced:
		sent.entry_id = FAKE_ID
		sent.dispatched_minute = CampaignClock.now()
		sent.depart_minute = ContractScheduler.next_wake_minute(CampaignClock.now())
		GameState.queued[FAKE_ID] = sent
		return sent
	var open: Array[BoardEntry] = GameState.board.available()
	if open.is_empty() or not GameState.dispatch(open[0].id, sent):
		return null
	return sent


#107: a queued merc's row holds through the midnight pass and cancels at the 6:00 departure.
static func _case_queued_hold(res: Dictionary, jump: bool) -> void:
	_boot()
	var saved: VacationBook = BenefitsManager.book
	var book := OrderBook.new()
	book.rng.seed = SEED
	BenefitsManager.book = book
	VacationMail.link(book)
	var m: MercenaryData = GameState.mercs[0]
	var quiet: MercenaryData = GameState.mercs[1]
	var free: int = book.free_days(m.merc_uid)
	var team: Array[MercenaryData] = [m, quiet]
	var sent: ActiveRun = _queue(team, false)
	var s: int = GameState.day() + 1
	var req: VacationRequest = _add(m, s, 3)
	var auto: VacationRequest = _add(quiet, s, 3)
	auto.auto = true
	var mails: int = GuiVacationTests._mail_count()
	var held: bool = true
	if not jump:
		_walk(s * DAY)
		held = sent != null and GameState.queued.has(sent.entry_id) and sent.uids().has(m.merc_uid) \
			and req.state == VacationRequest.State.APPROVED and m.rest_lockout_kind == "" \
			and _mails_of(MailCatalog.VAC_CANCEL).is_empty()
	await GameState.process_until(s * DAY + 6 * HOUR)
	var left: bool = sent != null and not GameState.queued.has(sent.entry_id) and m.on_contract
	var cancels: Array[MailInstance] = _mails_of(MailCatalog.VAC_CANCEL)
	var ordered: bool = book.order.has("day") and book.order.find("day") < book.order.find("held")
	BenefitsManager.book = saved
	var label: String = "107 jump: day pass before _depart_queued, same result" if jump \
		else "107 a queued merc's row holds over midnight, then cancels with R1C at the 6:00 departure"
	TestFixtures.check(res, label,
		held and left and ordered and req.state == VacationRequest.State.CANCELLED and cancels.size() == 1
			and auto.state == VacationRequest.State.CANCELLED and _taken(m) == 0 and book.free_days(m.merc_uid) == free
			and GuiVacationTests._mail_count() == mails + 1 and not GameState.has_method("drop_queued"),
		"held %s left %s order %s state %d auto %d R1C %d free %d want %d" % [held, left, book.order, req.state,
			auto.state, cancels.size(), book.free_days(m.merc_uid), free])


#108: a call-off before 08:00 on the start day starts the row at that minute; the eve call-off and a vanished posting.
static func _case_call_off(res: Dictionary) -> void:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var team: Array[MercenaryData] = [m]
	var sent: ActiveRun = _queue(team, false)
	var s: int = GameState.day() + 1
	var req: VacationRequest = _add(m, s, 3)
	var idle: int = m.idle_since_minute
	_walk(s * DAY)
	var call_at: int = s * DAY + 3 * HOUR
	_walk(call_at)
	var called: bool = sent != null and GameState.cancel_dispatch(sent.entry_id)
	var locked: bool = req.state == VacationRequest.State.TAKEN and req.start_day == s \
		and m.rest_lockout_kind == RestSystem.KIND_VACATION and m.rest_lockout_start == call_at \
		and m.rest_lockout_until == (req.end_day() + 1) * DAY and m.idle_since_minute == idle
	_walk((req.end_day() + 2) * DAY)
	TestFixtures.check(res, "108 a 03:00 call-off on the start day: TAKEN from 03:00, start day counts, idle window kept",
		called and locked and _taken(m) == req.days and req.counted == req.days,
		"called %s locked %s state %d start %d taken %d" % [called, locked, req.state, m.rest_lockout_start, _taken(m)])
	_boot()
	var eve_merc: MercenaryData = GameState.mercs[0]
	var eve_team: Array[MercenaryData] = [eve_merc]
	var eve_run: ActiveRun = _queue(eve_team, false)
	var eve: VacationRequest = _add(eve_merc, GameState.day() + 1, 2)
	var eve_called: bool = eve_run != null and GameState.cancel_dispatch(eve_run.entry_id)
	var waited: bool = eve.state == VacationRequest.State.APPROVED
	_walk(eve.start_day * DAY)
	_boot()
	var gone_merc: MercenaryData = GameState.mercs[0]
	var gone_team: Array[MercenaryData] = [gone_merc]
	var gone_run: ActiveRun = _queue(gone_team, true)
	var gone: VacationRequest = _add(gone_merc, GameState.day() + 1, 2)
	_walk(gone_run.depart_minute)
	GameState._depart_queued(gone_run.depart_minute)
	TestFixtures.check(res, "108 a 23:00 call-off waits for the midnight pass; a vanished posting starts the row at 6:00",
		eve_called and waited and eve.state == VacationRequest.State.TAKEN and gone.state == VacationRequest.State.TAKEN
			and gone_merc.rest_lockout_start == gone_run.depart_minute and not GameState.queued.has(FAKE_ID),
		"eve %s/%s/%d gone %d start %d" % [eve_called, waited, eve.state, gone.state, gone_merc.rest_lockout_start])


#115: a forced queue called off at minute on its start day, with an optional next row of the same merc.
static func _late(minute: int, days: int, next_days: int, next_state: int) -> Dictionary:
	_boot()
	var m: MercenaryData = GameState.mercs[0]
	var team: Array[MercenaryData] = [m]
	_queue(team, true)
	var s: int = GameState.day() + 1
	var req: VacationRequest = _add(m, s, days)
	var old_end: int = req.end_day()
	var next: VacationRequest = _add(m, old_end + 1, next_days, next_state) if next_days > 0 else null
	_walk(s * DAY)
	_walk(s * DAY + minute)
	var free: int = BenefitsManager.book.free_days(m.merc_uid)
	var mails: int = GuiVacationTests._mail_count()
	GameState.cancel_dispatch(FAKE_ID)
	var out: Dictionary = {"req": req, "next": next, "s": s, "old_end": old_end, "kind": m.rest_lockout_kind,
		"from": m.rest_lockout_start, "until": m.rest_lockout_until, "free": free,
		"free_after": BenefitsManager.book.free_days(m.merc_uid), "mail": GuiVacationTests._mail_count() - mails}
	_walk((old_end + next_days + 3) * DAY)
	out["taken"] = _taken(m)
	return out


static func _case_late_call_off(res: Dictionary) -> void:
	var nine: Dictionary = _late(9 * HOUR, 3, 0, 0)
	var req: VacationRequest = nine["req"]
	var s: int = int(nine["s"])
	var old_end: int = int(nine["old_end"])
	TestFixtures.check(res, "115 a 09:00 call-off: TAKEN from the next day, end + 1, lockout from 09:00, days taken = days",
		req.state == VacationRequest.State.TAKEN and req.start_day == s + 1 and req.days == 3 and req.end_day() == old_end + 1
			and String(nine["kind"]) == RestSystem.KIND_VACATION and int(nine["from"]) == s * DAY + 9 * HOUR
			and int(nine["until"]) == (old_end + 2) * DAY and int(nine["taken"]) == 3,
		"%s start %d days %d" % [nine, req.start_day, req.days])
	var eight: Dictionary = _late(8 * HOUR, 3, 0, 0)
	var early: Dictionary = _late(8 * HOUR - 1, 3, 0, 0)
	TestFixtures.check(res, "115 a call-off at exactly 08:00 shifts the same way; one at 07:59 does not",
		(eight["req"] as VacationRequest).start_day == int(eight["s"]) + 1
			and (early["req"] as VacationRequest).start_day == int(early["s"])
			and (early["req"] as VacationRequest).state == VacationRequest.State.TAKEN and int(early["taken"]) == 3,
		"08:00 start %d 07:59 start %d" % [(eight["req"] as VacationRequest).start_day,
			(early["req"] as VacationRequest).start_day])
	var merged: Dictionary = _late(9 * HOUR, 3, 2, VacationRequest.State.APPROVED)
	var held: VacationRequest = merged["req"]
	TestFixtures.check(res, "115 the next APPROVED row at old end + 1 within the max merges into the held row",
		held.days == 5 and (merged["next"] as VacationRequest).state == VacationRequest.State.MERGED
			and int(merged["taken"]) == 5 and int(merged["free_after"]) == int(merged["free"]),
		"days %d next %d taken %d free %d -> %d" % [held.days, (merged["next"] as VacationRequest).state,
			int(merged["taken"]), int(merged["free"]), int(merged["free_after"])])
	var bad: Array[String] = []
	var over: Dictionary = _late(9 * HOUR, 3, MAX_LEN - 2, VacationRequest.State.APPROVED)
	var asked: Dictionary = _late(9 * HOUR, 3, 2, VacationRequest.State.PENDING)
	for trimmed: Dictionary in [over, asked]:
		var row: VacationRequest = trimmed["req"]
		if row.start_day != int(trimmed["s"]) + 1 or row.days != 2 or row.end_day() != int(trimmed["old_end"]) \
				or int(trimmed["free_after"]) != int(trimmed["free"]) + 1:
			bad.append("start %d days %d free %d -> %d" % [row.start_day, row.days, int(trimmed["free"]),
				int(trimmed["free_after"])])
	var one: Dictionary = _late(9 * HOUR, 1, 2, VacationRequest.State.PENDING)
	var lone: VacationRequest = one["req"]
	TestFixtures.check(res, "115 over the max or a PENDING next row trims a day; a 1 day row trimmed is CANCELLED silently",
		bad.is_empty() and lone.state == VacationRequest.State.CANCELLED and String(one["kind"]) == ""
			and int(one["mail"]) == 0,
		"bad %s lone %d kind '%s' mail %d" % [bad, lone.state, String(one["kind"]), int(one["mail"])])


#110: calling off a 3 merc per_merc queued run refunds exactly its travel cost; a merc dead at 6:00 refunds nothing.
static func _case_refund(res: Dictionary) -> void:
	_boot()
	GameState.bank_notes = 100000
	var refunds: Array[int] = [0]
	var spy: Callable = func(_delta: int, reason: String, _label: String) -> void:
		if reason == GameState.REASON_TRAVEL_REFUND:
			refunds[0] += 1
	GameState.money_logged.connect(spy)
	var bank: int = GameState.bank_notes
	var sent: ActiveRun = _horse_run()
	var paid: int = bank - GameState.bank_notes
	var called: bool = sent != null and GameState.cancel_dispatch(sent.entry_id)
	TestFixtures.check(res, "110 cancel_dispatch on a 3 merc per_merc queued run refunds exactly run.travel_cost",
		called and paid == sent.travel_cost and paid > 0 and GameState.bank_notes == bank and refunds[0] == 1,
		"paid %d cost %d bank %d -> %d refunds %d" % [paid, sent.travel_cost if sent != null else -1, bank,
			GameState.bank_notes, refunds[0]])
	refunds[0] = 0
	var again: ActiveRun = _horse_run()
	var after_pay: int = GameState.bank_notes
	GameState.mercs[2].is_dead = true
	if again != null:
		CampaignClock.advance_to(again.depart_minute)
		GameState._depart_queued(again.depart_minute)
	GameState.money_logged.disconnect(spy)
	TestFixtures.check(res, "110 a merc dead at 6:00 is skipped with no refund",
		again != null and not GameState.queued.has(again.entry_id) and refunds[0] == 0
			and GameState.bank_notes == after_pay,
		"queued %s refunds %d bank %d want %d" % [again != null and GameState.queued.has(again.entry_id), refunds[0],
			GameState.bank_notes, after_pay])
	GameState.mercs[2].is_dead = false


static func _horse_run() -> ActiveRun:
	AutoFurloughTests._to_night()
	var open: Array[BoardEntry] = GameState.board.available()
	if open.is_empty():
		return null
	var entry: BoardEntry = open[0]
	var sent := ActiveRun.new()
	sent.travel_mode = "horse"
	sent.return_mode = "horse"
	sent.hours = 24.0
	for i: int in 3:
		var member := TeamMember.new()
		member.merc_uid = GameState.mercs[i].merc_uid
		sent.team.append(member)
	var leg: int = DispatchLogic.travel_cost(GuiTypes.travel_mode("horse"), 3, maxi(1, entry.merc_min), entry.distance_km)
	sent.travel_cost = leg * 2
	return sent if GameState.dispatch(entry.id, sent) else null


#Card 672: a Missing merc is idle for the Furlough tracker only; it never wishes and its APPROVED row cancels on the day.
static func _case_missing(res: Dictionary) -> void:
	_boot()
	var lost: MercenaryData = GameState.mercs[0]
	GuiVacationTests._crave(lost)
	lost.missing_since = CampaignClock.now()
	var idle: bool = RestSystem.is_idle(lost)
	var spy := GuiVacationTests.Spy.new()
	spy.rng.seed = SEED
	var team: Array[MercenaryData] = [lost]
	GuiVacationTests._roll_year(spy, team)
	var rows: int = spy.rows.size()
	var rolled: int = int(spy.wishes.get(lost.merc_uid, 0))
	lost.missing_since = -1
	GuiVacationTests._roll_year(spy, team)
	TestFixtures.check(res, "card 672: a Missing merc is idle yet a year of 08:00 rolls books no row; back home it wishes",
		idle and rows == 0 and rolled == 0 and not spy.rows.is_empty(),
		"idle %s rows %d wishes %d back %d" % [idle, rows, rolled, spy.rows.size()])
	var gone: MercenaryData = GameState.mercs[1]
	var s: int = GameState.day() + 2
	var row: VacationRequest = _add(gone, s, 3)
	gone.missing_since = CampaignClock.now()
	var hits: Array[int] = [0]
	var counter: Callable = func(_req: VacationRequest) -> void:
		hits[0] += 1
	BenefitsManager.book.cancelled.connect(counter)
	_walk(s * DAY + HOUR)
	BenefitsManager.book.cancelled.disconnect(counter)
	var r1c: Array[MailInstance] = _mails_of(MailCatalog.VAC_CANCEL)
	TestFixtures.check(res, "card 672: a Missing merc's APPROVED row cancels on its start day with R1C and no lockout",
		row.state == VacationRequest.State.CANCELLED and hits[0] == 1 and r1c.size() == 1 and r1c[0].request == row
			and gone.rest_lockout_kind == "",
		"state %d signal %d R1C %d kind '%s'" % [row.state, hits[0], r1c.size(), gone.rest_lockout_kind])
	gone.missing_since = -1


#Card 649: the day pass closes every live row of a fired or dead merc with no mail; captive and Missing rows stay.
static func _case_gone_rows(res: Dictionary) -> void:
	_boot(true, 5)
	var today: int = GameState.day()
	var quit: MercenaryData = GameState.mercs[0]
	var dead: MercenaryData = GameState.mercs[1]
	var caught: MercenaryData = GameState.mercs[2]
	var lost: MercenaryData = GameState.mercs[3]
	var asked: VacationRequest = _asked(quit, today + FAR, 5)
	asked.remind_day = today + 1
	var r1: MailInstance = MailCenter.get_mail(asked.mail_id)
	var seen: Array = [r1.read, r1.archived, r1.folder] if r1 != null else []
	var let_go: bool = BenefitsManager.fire(quit.merc_uid)
	if not let_go:
		GameState.remove_merc(quit.merc_uid, "fired", GuiTypes.MercStatus.FIRED)
	var listed: bool = BenefitsManager.book.spans(today + FAR, today + FAR).has(asked)
	var held: VacationRequest = _add(dead, today + FAR, 5)
	var taken: VacationRequest = _add(dead, today - 1, 5, VacationRequest.State.TAKEN)
	taken.counted = 1
	dead.is_dead = true
	var stay: Array[VacationRequest] = [_add(caught, today + FAR, 5),
		_add(lost, today + FAR, 5, VacationRequest.State.PENDING)]
	caught.on_contract = true
	MercPool.add_captive(caught, "Escort", "Aerdis", "Day 1")
	caught.on_contract = false
	lost.missing_since = CampaignClock.now()
	var mails: int = GuiVacationTests._mail_count()
	_step((today + 1) * DAY)
	var quiet: int = _mails_of(MailCatalog.VAC_REMIND).size() + _mails_of(MailCatalog.VAC_REJECT).size() \
		+ _mails_of(MailCatalog.VAC_CANCEL).size()
	var kept: bool = r1 != null and MailCenter.get_mail(asked.mail_id) == r1 and r1.request == asked \
		and [r1.read, r1.archived, r1.folder] == seen
	var still: bool = BenefitsManager.book.spans(today + FAR, today + FAR).has(asked)
	TestFixtures.check(res, "card 649: a fired merc's PENDING row closes CANCELLED with no mail and leaves spans; R1 untouched",
		let_go and asked.state == VacationRequest.State.CANCELLED and GuiVacationTests._mail_count() == mails
			and quiet == 0 and listed and not still and kept,
		"fired %s state %d mail %d -> %d R1M/R1X/R1C %d listed %s -> %s R1 kept %s" % [let_go, asked.state, mails,
			GuiVacationTests._mail_count(), quiet, listed, still, kept])
	TestFixtures.check(res, "card 649: a dead merc's APPROVED row closes CANCELLED before its start day",
		held.state == VacationRequest.State.CANCELLED and held.start_day > GameState.day(),
		"state %d start %d day %d" % [held.state, held.start_day, GameState.day()])
	TestFixtures.check(res, "card 649: a dead merc's TAKEN row closes CANCELLED and counts no further day",
		taken.state == VacationRequest.State.CANCELLED and taken.counted == 1,
		"state %d counted %d" % [taken.state, taken.counted])
	TestFixtures.check(res, "card 649: the rows of a captive and a Missing merc stay live through the day pass",
		stay[0].is_live() and stay[1].is_live(), "captive %d missing %d" % [stay[0].state, stay[1].state])
	RescueContractBuilder.release(caught.merc_uid)
	lost.missing_since = -1
	dead.is_dead = false

class_name GuiVacationTests

#VacationBook, its mail and the 08:00 wish hook (Mail plan 3.5, 3.6).
#Plan tests 56-60, 65, 66, 74, 100, 101, 103, 105, 106 and 111. Run inside the gui-mail-tests harness flag.

const DAY: int = CampaignClock.MINUTES_PER_DAY
const WISH_MINUTE: int = GameState.WISH_HOUR * 60
const SEED: int = 7331
const YEAR: int = TrynnCalendar.DAYS_PER_YEAR
const ROLLS: int = 3000
const LEAD_GAP: int = 50
const BLOCK_DAYS: int = 120
const FAR_DAYS: int = 100


#Counts every roll_wishes call and every merc that reached the roll; hits are (start, days, today).
class Spy extends VacationBook:
	var calls: Array[int] = []
	var wishes: Dictionary = {}
	var hits: Array[Vector3i] = []

	func roll_wishes(now: int, team: Array[MercenaryData] = []) -> void:
		calls.append(now)
		super.roll_wishes(now, team)

	func _wish(merc: MercenaryData, today: int) -> Vector2i:
		wishes[merc.merc_uid] = int(wishes.get(merc.merc_uid, 0)) + 1
		var hit: Vector2i = super._wish(merc, today)
		if hit.x >= 0:
			hits.append(Vector3i(hit.x, hit.y, today))
		return hit


static func run(res: Dictionary) -> void:
	_case_lengths(res)
	_case_free_days(res)
	_case_lead_and_seed(res)
	_case_can_book(res)
	_case_request_mail(res)
	_case_spans(res)
	_case_one_open(res)
	_case_window_blocked(res)
	await _case_daily_hook(res)
	await _case_no_board(res)
	await _case_return_roll(res)
	await _case_queued(res)
	_fresh()


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	if GameState.mercs.size() < 3:
		TestFixtures.add_mercs(3 - GameState.mercs.size())


#Every desire input at its worst, a tracked relation of 0 toward every peer included: desire reads +100.
static func _crave(m: MercenaryData) -> void:
	m.furlough_pressure = 400.0
	m.deficit_pressure = 200.0
	m.fail_stress = 5.0
	m.guild_opinion = -5
	m.stats["healthiness"] = -50.0
	m.current_hp = int(RestActions.max_of(m, RestSystem.MAX_HP) * 0.5)
	for peer: MercenaryData in GameState.mercs:
		if peer != m:
			CampaignKnowledge.set_relation(m.merc_uid, peer.merc_uid, 0)


static func _row(uid: int, start: int, days: int, state: int) -> VacationRequest:
	var req := VacationRequest.new()
	req.merc_uid = uid
	req.start_day = start
	req.days = days
	req.state = state
	return req


static func _roll_year(book: VacationBook, team: Array[MercenaryData] = []) -> void:
	var today: int = GameState.day()
	for d: int in range(YEAR):
		book.roll_wishes((today + d) * DAY + WISH_MINUTE, team)


static func _rows_of(book: VacationBook, uid: int) -> Array[VacationRequest]:
	var out: Array[VacationRequest] = []
	for req: VacationRequest in book.rows:
		if req.merc_uid == uid:
			out.append(req)
	return out


static func _mail_count() -> int:
	var n: int = 0
	for folder: StringName in MailCatalog.FOLDERS:
		n += MailCenter.mail_in(folder).size() + MailCenter.mail_in(folder, true).size()
	return n


static func _install() -> Spy:
	var spy := Spy.new()
	spy.rng.seed = SEED
	BenefitsManager.book = spy
	return spy


static func _case_lengths(res: Dictionary) -> void:
	var p := VacationPolicy.new()
	var got: Array[int] = [VacationPolicy.week_days(), VacationPolicy.month_days(), p.max_len_days(), p.gap_days()]
	p.merge({"max_len": 4, "max_unit": "days", "gap": 1, "gap_unit": "months"})
	got.append(p.max_len_days())
	got.append(p.gap_days())
	p.merge({"gap": 2, "gap_unit": "weeks"})
	got.append(p.gap_days())
	TestFixtures.check(res, "59 max_len_days and gap_days: 1 week = 10 days, 1 month = 33 days",
		got == [10, 33, 10, 99, 4, 33, 20], str(got))


static func _case_free_days(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_vacation({"start": 30, "add_days": 0})
	var a: MercenaryData = GameState.mercs[0]
	var book := VacationBook.new()
	var start: int = GameState.day() + LEAD_GAP
	book.rows.append(_row(a.merc_uid, start, 4, VacationRequest.State.APPROVED))
	var taken: VacationRequest = _row(a.merc_uid, start + 20, 4, VacationRequest.State.TAKEN)
	taken.counted = 1
	book.rows.append(taken)
	book.rows.append(_row(a.merc_uid, start + 40, 5, VacationRequest.State.DENIED))
	book.rows.append(_row(GameState.mercs[1].merc_uid, start, 6, VacationRequest.State.APPROVED))
	var free: int = book.free_days(a.merc_uid)
	var m: MercenaryData = GameState.mercs[2]
	_crave(m)
	var caps: Array[int] = []
	var bad: Array[String] = []
	var seen: Array[int] = []
	for policy_start: int in [30, 3]:
		BenefitsManager.set_vacation({"start": policy_start})
		var empty := VacationBook.new()
		empty.rng.seed = SEED
		var cap: int = mini(empty.free_days(m.merc_uid), BenefitsManager.policy().max_len_days())
		caps.append(cap)
		for _i: int in range(ROLLS):
			var hit: Vector2i = VacationDesire.wish(m, empty, empty.rng, GameState.day())
			if hit.x >= 0:
				seen.append(hit.y)
				if hit.y < 1 or hit.y > cap:
					bad.append("start %d days %d" % [policy_start, hit.y])
	TestFixtures.check(res, "56 a wish never asks more than free_days (left minus booked) nor max_len_days()",
		free == 30 - 4 - 3 and caps == [10, 3] and bad.is_empty() and seen.size() > 10,
		"free %d caps %s bad %s hits %d" % [free, caps, bad, seen.size()])


static func _case_lead_and_seed(res: Dictionary) -> void:
	_fresh()
	for m: MercenaryData in GameState.mercs:
		_crave(m)
	var made: Array = []
	for _pass: int in range(2):
		var book := VacationBook.new()
		book.rng.seed = SEED
		_roll_year(book)
		var rows: Array[Vector4i] = []
		for req: VacationRequest in book.rows:
			rows.append(Vector4i(req.merc_uid, req.start_day, req.days, req.asked_day))
		made.append(rows)
	var bad: Array[Vector4i] = []
	for row: Vector4i in made[0]:
		if row.y - row.w < VacationDesire.LEAD_DAYS or row.y - row.w > VacationDesire.LEAD_DAYS + VacationDesire.LEAD_SPREAD:
			bad.append(row)
	TestFixtures.check(res, "57 every request starts at least 41 days after its asked_day",
		not (made[0] as Array).is_empty() and bad.is_empty(), "rows %d bad %s" % [(made[0] as Array).size(), bad])
	TestFixtures.check(res, "74 two books with the same seed and roster make identical requests over 330 days",
		not (made[0] as Array).is_empty() and made[0] == made[1], "%s vs %s" % [made[0], made[1]])


static func _case_can_book(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_vacation({"start": 30, "max_at": 2})
	var a: int = GameState.mercs[0].merc_uid
	var s: int = GameState.day() + LEAD_GAP
	var book := VacationBook.new()
	book.rows.append(_row(GameState.mercs[1].merc_uid, s, 5, VacationRequest.State.APPROVED))
	var other: VacationRequest = _row(GameState.mercs[2].merc_uid, s + 2, 5, VacationRequest.State.PENDING)
	book.rows.append(other)
	var crowd: Array[bool] = [book.can_book(a, s + 3, 2), book.can_book(a, s + 5, 2)]
	other.state = VacationRequest.State.DENIED
	crowd.append(book.can_book(a, s + 3, 2))
	var own := VacationBook.new()
	own.rows.append(_row(a, s, 3, VacationRequest.State.APPROVED))
	var gap: int = BenefitsManager.policy().gap_days()
	var gaps: Array[bool] = [own.can_book(a, s + 2 + gap, 1), own.can_book(a, s + 3 + gap, 1)]
	var empty := VacationBook.new()
	var zero: Array[bool] = [empty.can_book(a, s + FAR_DAYS, 1)]
	BenefitsManager.set_vacation({"max_at": 0})
	zero.append(empty.can_book(a, s + FAR_DAYS, 1))
	TestFixtures.check(res, "58 can_book refuses at max_at overlaps, inside gap_days() of its own vacation and at max_at 0",
		crowd == [false, true, true] and gaps == [false, true] and zero == [true, false],
		"crowd %s gap %s zero %s" % [crowd, gaps, zero])


static func _case_request_mail(res: Dictionary) -> void:
	_fresh()
	MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	MailCenter.reset()
	var book: VacationBook = BenefitsManager.book
	book.rng.seed = SEED
	var m: MercenaryData = GameState.mercs[0]
	_crave(m)
	var team: Array[MercenaryData] = [m]
	var today: int = GameState.day()
	for d: int in range(YEAR):
		if not book.rows.is_empty():
			break
		book.roll_wishes((today + d) * DAY + WISH_MINUTE, team)
	var req: VacationRequest = book.rows[0] if not book.rows.is_empty() else VacationRequest.new()
	var mail: MailInstance = MailCenter.get_mail(req.mail_id)
	var who: Object = MailCatalog.sender(mail.sender_id, mail.merc_uid) if mail != null else null
	TestFixtures.check(res, "60 approval ON: a wish delivers R1 from the merc with mail.request set and req.mail_id",
		req.state == VacationRequest.State.PENDING and mail != null and mail.def_id == MailCatalog.VAC_REQUEST
		and mail.request == req and mail.merc_uid == m.merc_uid and who is MercenaryData
		and (who as MercenaryData).merc_uid == m.merc_uid, "req %s mail %s" % [req.mail_id, mail])
	req.remind_day = today
	book.day_passed(today)
	var nudge: MailInstance = GuiMailTests._find(MailCatalog.VAC_REMIND)
	TestFixtures.check(res, "a due reminder delivers R1M on the request thread and rolls the next reminder",
		nudge != null and nudge.parent == req.mail_id and nudge.request == req
		and req.remind_day >= today + VacationBook.REMIND_MIN and req.remind_day <= today + VacationBook.REMIND_MAX,
		"nudge %s remind %d" % [nudge, req.remind_day])
	BenefitsManager.set_vacation({"approval": false})
	var before: int = _mail_count()
	book.day_passed(today + 1)
	TestFixtures.check(res, "65 approval OFF turns PENDING rows APPROVED (auto) on the next day pass with no mail",
		req.state == VacationRequest.State.APPROVED and req.auto and _mail_count() == before,
		"state %d auto %s mail %d -> %d" % [req.state, req.auto, before, _mail_count()])
	book._close(req, VacationRequest.State.CANCELLED)
	var silent: bool = _mail_count() == before
	BenefitsManager.set_vacation({"approval": true})
	VacationDays.book_row(book, GameState.mercs[1].merc_uid, today + FAR_DAYS, 1, today)
	var asked: VacationRequest = book.rows[book.rows.size() - 1]
	book._close(asked, VacationRequest.State.REJECTED)
	var lapse: MailInstance = GuiMailTests._find(MailCatalog.VAC_REJECT)
	TestFixtures.check(res, "a closed auto row mails nothing; a closed mailed row delivers R1X on its thread",
		silent and asked.mail_id != &"" and lapse != null and lapse.parent == asked.mail_id and lapse.request == asked,
		"silent %s lapse %s" % [silent, lapse])


static func _case_spans(res: Dictionary) -> void:
	_fresh()
	var book: VacationBook = BenefitsManager.book
	var s: int = GameState.day() + LEAD_GAP
	var pending: VacationRequest = null
	for state: int in VacationRequest.State.values():
		var req: VacationRequest = _row(GameState.mercs[0].merc_uid, s, 3, state)
		pending = req if state == VacationRequest.State.PENDING else pending
		book.rows.append(req)
	var states: Array[int] = []
	for req: VacationRequest in MailCenter.vacation_spans(s, s + 2):
		states.append(req.state)
	states.sort()
	var heard: Array[int] = [0]
	var bump: Callable = func() -> void: heard[0] += 1
	MailCenter.changed.connect(bump)
	book.approve(pending)
	MailCenter.changed.disconnect(bump)
	var live: Array[int] = [VacationRequest.State.PENDING, VacationRequest.State.APPROVED, VacationRequest.State.TAKEN]
	live.sort()
	TestFixtures.check(res, "66 vacation_spans drops DENIED, REJECTED and CANCELLED; book.changed emits MailCenter.changed",
		states == live and heard[0] == 1, "states %s heard %d" % [states, heard[0]])
	book.clear()


static func _case_one_open(res: Dictionary) -> void:
	_fresh()
	var a: MercenaryData = GameState.mercs[0]
	_crave(a)
	var team: Array[MercenaryData] = [a]
	var book := VacationBook.new()
	book.rng.seed = SEED
	var today: int = GameState.day()
	var held: VacationRequest = _row(a.merc_uid, today + FAR_DAYS, 1, VacationRequest.State.PENDING)
	book.rows.append(held)
	_roll_year(book, team)
	var while_pending: int = _rows_of(book, a.merc_uid).size()
	held.state = VacationRequest.State.APPROVED
	_roll_year(book, team)
	var while_approved: int = _rows_of(book, a.merc_uid).size()
	held.state = VacationRequest.State.TAKEN
	held.start_day = today - 5
	held.days = 3
	held.counted = 3
	_roll_year(book, team)
	var after: Array[VacationRequest] = _rows_of(book, a.merc_uid)
	var quiet_until: int = held.end_day() + BenefitsManager.policy().gap_days()
	var early: bool = false
	for req: VacationRequest in after:
		early = early or (req != held and req.asked_day <= quiet_until)
	TestFixtures.check(res, "100 a merc at +100 makes no row while PENDING or APPROVED, or inside gap_days() of its last end",
		VacationDesire.compute(a) >= 99.99 and while_pending == 1 and while_approved == 1 and after.size() == 2
		and not early, "desire %.2f pending %d approved %d after %d early %s" % [VacationDesire.compute(a),
			while_pending, while_approved, after.size(), early])


static func _case_window_blocked(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_vacation({"max_at": 1})
	var a: MercenaryData = GameState.mercs[0]
	_crave(a)
	var team: Array[MercenaryData] = [a]
	var today: int = GameState.day()
	var spy := Spy.new()
	spy.rng.seed = SEED
	var block: VacationRequest = _row(GameState.mercs[1].merc_uid, today + VacationDesire.LEAD_DAYS, BLOCK_DAYS,
		VacationRequest.State.APPROVED)
	spy.rows.append(block)
	_roll_year(spy, team)
	var mine: Array[VacationRequest] = _rows_of(spy, a.merc_uid)
	var booked: VacationRequest = mine[0] if not mine.is_empty() else null
	var refused: int = 0
	var clear_refused: int = 0
	for hit: Vector3i in spy.hits:
		if booked != null and hit.z < booked.asked_day:
			refused += 1
			clear_refused += 0 if block.overlaps(hit.x, hit.x + hit.y - 1) else 1
	TestFixtures.check(res, "101 a day whose window breaks max_at makes no row; the merc rolls again later and books",
		mine.size() == 1 and refused > 0 and clear_refused == 0
		and not block.overlaps(booked.start_day, booked.end_day()),
		"rows %d refused %d clear %d hits %d" % [mine.size(), refused, clear_refused, spy.hits.size()])


static func _case_daily_hook(res: Dictionary) -> void:
	_fresh()
	var saved: VacationBook = BenefitsManager.book
	var spy: Spy = _install()
	var away: MercenaryData = GameState.mercs[1]
	away.rest_lockout_kind = VacationBook.LOCKOUT_KIND
	away.rest_lockout_until = CampaignClock.now() + 10 * DAY
	var first: int = ContractScheduler.next_hour_after(CampaignClock.now(), GameState.WISH_HOUR)
	await GameState.process_until(first + 2 * DAY + 60)
	var bad: Array[String] = []
	for m: MercenaryData in GameState.mercs:
		var want: int = 0 if m == away else 3
		if int(spy.wishes.get(m.merc_uid, 0)) != want:
			bad.append("%d:%d" % [m.merc_uid, int(spy.wishes.get(m.merc_uid, 0))])
	TestFixtures.check(res, "105 a 3 day process_until rolls each eligible merc exactly once per 08:00",
		bad.is_empty() and spy.calls == [first, first + DAY, first + 2 * DAY], "bad %s calls %s" % [bad, spy.calls])
	away.rest_lockout_kind = ""
	away.rest_lockout_until = 0
	BenefitsManager.book = saved


static func _case_no_board(res: Dictionary) -> void:
	_fresh()
	var saved: VacationBook = BenefitsManager.book
	var board: ContractBoard = GameState.board
	var spy: Spy = _install()
	var posted: Array[int] = [0]
	var count: Callable = func(_n: int) -> void: posted[0] += 1
	GameState.contracts_posted.connect(count)
	GameState.board = null
	var first: int = ContractScheduler.next_hour_after(CampaignClock.now(), GameState.WISH_HOUR)
	await GameState.process_until(first + 2 * DAY + 60)
	var three: Array[int] = spy.calls.duplicate()
	var exact: int = first + 3 * DAY
	await GameState.process_until(exact)
	var on_hour: bool = three.all(func(t: int) -> bool: return t % DAY == WISH_MINUTE)
	GameState.board = board
	GameState.contracts_posted.disconnect(count)
	TestFixtures.check(res, "106 with board null a 3 day process_until rolls once per 08:00; a target at 08:00 rolls once",
		three == [first, first + DAY, first + 2 * DAY] and on_hour and spy.calls == three + [exact] and posted[0] == 0,
		"calls %s posted %d" % [spy.calls, posted[0]])
	BenefitsManager.book = saved


static func _case_return_roll(res: Dictionary) -> void:
	_fresh()
	var saved: VacationBook = BenefitsManager.book
	var spy: Spy = _install()
	var home: MercenaryData = GameState.mercs[0]
	var taken: MercenaryData = GameState.mercs[1]
	var entry: BoardEntry = GameState.board.available()[0]
	var team: Array[MercenaryData] = [home, taken]
	var scheduler: ContractScheduler = GameState.board.activate(entry.id, team, 0, CampaignClock.now(), Callable())
	scheduler.phase = ContractScheduler.Phase.DONE
	scheduler.all_dead = false
	scheduler.run.verdict = BoardEntry.STATUS_FAILED
	scheduler.run.kidnapped.append(taken)
	home.on_contract = false
	taken.on_contract = false
	var settled_at: int = CampaignClock.now()
	GameState._clock_depth += 1
	GameState._settle(entry)
	GameState._clock_depth -= 1
	var at_return: Dictionary = spy.wishes.duplicate()
	var calls: Array[int] = spy.calls.duplicate()
	TestFixtures.check(res, "103 a living returned merc rolls once at the return minute; a kidnapped merc does not",
		calls == [settled_at] and at_return == {home.merc_uid: 1}, "calls %s wishes %s" % [calls, at_return])
	TestFixtures.check(res, "each ALIVE member of a failed contract gains fail stress; a kidnapped member does not",
		is_equal_approx(home.fail_stress, VacationDesire.vulnerability(home)) and is_zero_approx(taken.fail_stress),
		"home %.3f v %.3f taken %.3f" % [home.fail_stress, VacationDesire.vulnerability(home), taken.fail_stress])
	var next: int = ContractScheduler.next_hour_after(settled_at, GameState.WISH_HOUR)
	await GameState.process_until(next)
	TestFixtures.check(res, "103 the next roll after the return is the following 08:00",
		spy.calls == [settled_at, next], "calls %s want %d" % [spy.calls, next])
	BenefitsManager.book = saved


static func _case_queued(res: Dictionary) -> void:
	_fresh()
	AutoFurloughTests._to_night()
	var merc: MercenaryData = GameState.mercs[0]
	var sent: ActiveRun = AutoFurloughTests._queue(merc)
	var next: int = ContractScheduler.next_hour_after(CampaignClock.now(), GameState.WISH_HOUR)
	if sent != null:
		sent.depart_minute = next + 60
	var saved: VacationBook = BenefitsManager.book
	var spy: Spy = _install()
	await GameState.process_until(next)
	var hooked: int = int(spy.wishes.get(merc.merc_uid, 0))
	spy.roll_wishes(CampaignClock.now())
	var direct: int = int(spy.wishes.get(merc.merc_uid, 0))
	var status: int = int(GameState.merc_status(merc)["status"])
	var still: bool = sent != null and GameState.queued.has(sent.entry_id) and not merc.on_contract
	TestFixtures.check(res, "111 a queued merc rolls at the 08:00 hook and at a direct roll_wishes; it reads PREPARING",
		still and hooked == 1 and direct == 2 and status == GuiTypes.MercStatus.PREPARING,
		"queued %s hook %d direct %d status %d" % [still, hooked, direct, status])
	if sent != null:
		GameState.cancel_dispatch(sent.entry_id)
	BenefitsManager.book = saved

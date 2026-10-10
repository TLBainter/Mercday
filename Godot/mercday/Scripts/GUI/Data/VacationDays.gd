class_name VacationDays

#The vacation book's day rules (Mail plan 3.5): the day count, the start-day pass, the cancels and the queued hold.
#Static helpers over one VacationBook; the book keeps the entry points.

#A call-off on a held row at or after 08:00 moves its first vacation day to the next day (Q68).
const LATE_CALL_OFF_MINUTE := 480


#Step 1: each TAKEN row whose day before this one is a vacation day counts it for a living merc; returns their uids.
static func count(book: VacationBook, day: int) -> Array[int]:
	var out: Array[int] = []
	for req: VacationRequest in book.rows:
		if req.state != VacationRequest.State.TAKEN or req.counted >= req.days:
			continue
		if day - 1 < req.start_day or day - 1 > req.end_day():
			continue
		var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
		if merc == null or merc.is_dead:
			continue
		req.counted += 1
		out.append(req.merc_uid)
	return out


#Step 0b (card 649): every live row of a merc that died or left the roster closes CANCELLED with no mail.
static func close_gone(book: VacationBook) -> void:
	for req: VacationRequest in book.rows:
		var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
		if req.is_live() and (merc == null or merc.is_dead):
			_drop(book, req)


#Step 2: a PENDING row lapses on its start day; an APPROVED one starts, cancels when its merc is busy or Missing, or
#holds while the merc is queued (N63).
static func start(book: VacationBook, day: int) -> void:
	for req: VacationRequest in book.rows:
		if req.start_day != day:
			continue
		if req.state == VacationRequest.State.PENDING:
			book._close(req, VacationRequest.State.REJECTED)
			continue
		if req.state != VacationRequest.State.APPROVED or GameState.is_queued(req.merc_uid):
			continue
		var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
		if merc == null or merc.is_dead:
			_drop(book, req)
		elif merc.missing_since >= 0 or not RestSystem.is_idle(merc):
			cancel(book, req)
		else:
			_take(book, req, merc, day * CampaignClock.MINUTES_PER_DAY)


#CANCELLED with its days back in free_days; R1C goes out unless the row is auto.
static func cancel(book: VacationBook, req: VacationRequest) -> void:
	if req != null and req.state == VacationRequest.State.APPROVED:
		book._close(req, VacationRequest.State.CANCELLED)


#Departure (ContractManager.depart): every APPROVED row of a departing merc that has reached its start day cancels.
static func cancel_held(book: VacationBook, team: Array[MercenaryData], today: int) -> void:
	for merc: MercenaryData in team:
		for req: VacationRequest in book.rows:
			if merc != null and req.merc_uid == merc.merc_uid and req.start_day <= today:
				cancel(book, req)


#A queued dispatch called off or gone: each held row of its mercs starts at minute under the Q68 call-off rule.
static func release_held(book: VacationBook, uids: Array[int], minute: int) -> void:
	var today: int = TrynnCalendar.day_index(minute)
	for req: VacationRequest in book.rows:
		if not uids.has(req.merc_uid) or req.state != VacationRequest.State.APPROVED:
			continue
		if req.start_day > today or req.end_day() < today:
			continue
		var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
		if merc == null or merc.is_dead:
			continue
		if minute - today * CampaignClock.MINUTES_PER_DAY >= LATE_CALL_OFF_MINUTE and not _shift_late(book, req):
			continue
		_take(book, req, merc, minute)


#Q68 and Q69: the first day moves out by one; reaching the merc's next row merges with an APPROVED one inside the
#policy max, else trims a day. False when the trim leaves no day (CANCELLED, no mail).
static func _shift_late(book: VacationBook, req: VacationRequest) -> bool:
	var next: VacationRequest = _next_row(book, req)
	var reaches: bool = next != null and next.start_day <= req.end_day() + 1
	req.start_day += 1
	if not reaches:
		return true
	if next.state == VacationRequest.State.APPROVED and req.days + next.days <= BenefitsManager.policy().max_len_days():
		req.days += next.days
		next.state = VacationRequest.State.MERGED
		return true
	req.days -= 1
	if req.days > 0:
		return true
	_drop(book, req)
	return false


#The merc's earliest PENDING or APPROVED row after req.
static func _next_row(book: VacationBook, req: VacationRequest) -> VacationRequest:
	var best: VacationRequest = null
	for other: VacationRequest in book.rows:
		var open: bool = other.state == VacationRequest.State.PENDING or other.state == VacationRequest.State.APPROVED
		if other == req or not open or other.merc_uid != req.merc_uid or other.start_day <= req.start_day:
			continue
		if best == null or other.start_day < best.start_day:
			best = other
	return best


static func _take(book: VacationBook, req: VacationRequest, merc: MercenaryData, from_minute: int) -> void:
	book.furlough_lines.append_array(RestSystem.vacation_start(merc, (req.end_day() + 1) * CampaignClock.MINUTES_PER_DAY,
		from_minute))
	req.state = VacationRequest.State.TAKEN
	book.changed.emit()


#A silent CANCELLED: no signal, so no mail.
static func _drop(book: VacationBook, req: VacationRequest) -> void:
	req.state = VacationRequest.State.CANCELLED
	book.changed.emit()


#A new row from a wish: PENDING with a reminder day and the requested signal, or APPROVED (auto) with approval OFF.
static func book_row(book: VacationBook, uid: int, start_day: int, days: int, today: int) -> void:
	var req: VacationRequest = VacationRequest.new()
	req.merc_uid = uid
	req.start_day = start_day
	req.days = days
	req.asked_day = today
	req.auto = not BenefitsManager.policy().approval
	req.state = VacationRequest.State.APPROVED if req.auto else VacationRequest.State.PENDING
	req.remind_day = -1 if req.auto else today + book.rng.randi_range(VacationBook.REMIND_MIN, VacationBook.REMIND_MAX)
	book.rows.append(req)
	if not req.auto:
		book._announce(req)
	book.changed.emit()


#Every merc the guild employs and that lives, captives included; the fired and the dead never count.
static func employed() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in GameState.mercs:
		if merc != null and not merc.is_dead and not BenefitsManager.fired.has(merc.merc_uid):
			out.append(merc)
	return out

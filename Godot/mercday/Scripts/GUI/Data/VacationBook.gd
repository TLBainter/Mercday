class_name VacationBook extends RefCounted

#Every vacation, mailed or not (Mail plan 3.5). BenefitsManager holds the one book and MailCenter mails its signals.

signal requested(req: VacationRequest)
signal reminder_due(req: VacationRequest)
signal rejected(req: VacationRequest)
signal cancelled(req: VacationRequest)
signal changed

const REMIND_MIN := 7
const REMIND_MAX := 14
const LOCKOUT_KIND := RestSystem.KIND_VACATION

var rows: Array[VacationRequest] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var furlough_lines: Array[String] = []  #step 0 Furlough lines; GameState.process_until drains them as a roster change


func clear() -> void:
	rows.clear()
	changed.emit()


#VacationDays.book_row raises requested through here.
func _announce(req: VacationRequest) -> void:
	requested.emit(req)


func spans(from_day: int, to_day: int) -> Array[VacationRequest]:
	var out: Array[VacationRequest] = []
	for req: VacationRequest in rows:
		if req.is_live() and req.overlaps(from_day, to_day):
			out.append(req)
	return out


func free_days(uid: int) -> int:
	var booked: int = 0
	for req: VacationRequest in rows:
		if req.merc_uid == uid and req.is_live():
			booked += maxi(0, req.days - req.counted)
	return maxi(0, BenefitsManager.vacation_days_left(uid) - booked)


func can_book(uid: int, start: int, days: int) -> bool:
	var policy: VacationPolicy = BenefitsManager.policy()
	if days < 1 or days > policy.max_len_days() or days > free_days(uid) or start < GameState.day() + VacationDesire.LEAD_DAYS:
		return false
	var end: int = start + days - 1
	var gap: int = policy.gap_days()
	var others: int = 0
	for req: VacationRequest in rows:
		if req.is_live() and req.merc_uid == uid and req.start_day - gap <= end and req.end_day() + gap >= start:
			return false
		if req.is_live() and req.merc_uid != uid and req.overlaps(start, end):
			others += 1
	return others < policy.max_at


#The longest wish a merc may make today; 0 while it has a PENDING or APPROVED row or sits inside the gap.
func wish_cap(uid: int, today: int) -> int:
	var gap: int = BenefitsManager.policy().gap_days()
	for req: VacationRequest in rows:
		var open: bool = req.state == VacationRequest.State.PENDING or req.state == VacationRequest.State.APPROVED
		if req.merc_uid == uid and (open or (req.state == VacationRequest.State.TAKEN and today <= req.end_day() + gap)):
			return 0
	return mini(free_days(uid), BenefitsManager.policy().max_len_days())


func approve(req: VacationRequest) -> bool:
	return shift(req, 0)


func deny(req: VacationRequest) -> bool:
	return shift(req, 0, VacationRequest.State.DENIED)


#Answers a PENDING row: the start moves by n days even past the gap, max_at or the lead.
func shift(req: VacationRequest, n: int, state: int = VacationRequest.State.APPROVED) -> bool:
	if req == null or req.state != VacationRequest.State.PENDING:
		return false
	req.state = state
	req.start_day += n
	changed.emit()
	return true


#Closes a row as REJECTED (lapsed) or CANCELLED (busy on its start day); the start-day pass calls it.
func _close(req: VacationRequest, state: int) -> void:
	req.state = state
	(rejected if state == VacationRequest.State.REJECTED else cancelled).emit(req)
	changed.emit()


#One new day: steps 0, 0b and 1-4 of plan 3.5 with the approval-off auto-approve after the start; returns the counted uids.
func day_passed(day: int) -> Array[int]:
	var staff: Array[MercenaryData] = VacationDays.employed()
	for merc: MercenaryData in staff:
		RestSystem.idle_furlough(merc, day * CampaignClock.MINUTES_PER_DAY, furlough_lines)
	VacationDays.close_gone(self)
	var counted: Array[int] = VacationDays.count(self, day)
	VacationDays.start(self, day)
	var moved: bool = false
	for req: VacationRequest in rows:
		if req.state == VacationRequest.State.PENDING and not BenefitsManager.policy().approval:
			req.state = VacationRequest.State.APPROVED
			req.auto = true
			moved = true
		elif req.state == VacationRequest.State.PENDING and req.remind_day >= 0 and req.remind_day <= day:
			reminder_due.emit(req)
			req.remind_day = day + rng.randi_range(REMIND_MIN, REMIND_MAX)
	for merc: MercenaryData in staff:
		VacationDesire.day_tick(merc)
	if moved:
		changed.emit()
	return counted


func cancel(req: VacationRequest) -> void:
	VacationDays.cancel(self, req)


func cancel_held(team: Array[MercenaryData], today: int) -> void:
	VacationDays.cancel_held(self, team, today)


func release_held(uids: Array[int], minute: int) -> void:
	VacationDays.release_held(self, uids, minute)


#The 08:00 roll over every employed merc, or over a returned team only; a merc must be idle and off vacation, and a
#Missing merc never wishes.
func roll_wishes(now: int, team: Array[MercenaryData] = []) -> void:
	var today: int = TrynnCalendar.day_index(now)
	var staff: Array[MercenaryData] = VacationDays.employed()
	for merc: MercenaryData in (staff if team.is_empty() else team):
		var away: bool = merc.rest_lockout_kind == LOCKOUT_KIND and merc.rest_lockout_until > now
		if away or merc.missing_since >= 0 or not staff.has(merc) or not RestSystem.is_idle(merc):
			continue
		var hit: Vector2i = _wish(merc, today)
		if hit.x >= 0 and can_book(merc.merc_uid, hit.x, hit.y):
			VacationDays.book_row(self, merc.merc_uid, hit.x, hit.y, today)


func _wish(merc: MercenaryData, today: int) -> Vector2i:
	return VacationDesire.wish(merc, self, rng, today)

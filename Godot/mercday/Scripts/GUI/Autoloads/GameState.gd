extends Node

#The live campaign: the bank, the roster, the contract board and the clock that moves them.
#_ready only builds the clock child and wires the metrics sources, so a harness run is untouched;
#start_new_game is called by the GUI once the harness has declined the launch.
#A dispatch made between 22:00 and 6:00 is queued: the team waits in the tavern and leaves at 6:00.

const START_BANK := 100
const START_MERCS := 10
const START_LEVEL := 1
const SALARY_HOUR := 8
const CLOCK_NAME := "ClockRunner"
const QUEUED_TAG := "queued in the tavern"
const DEFAULT_EXTRAS: Dictionary = {"level_mode": "Auto"}
#Board states the contract list always shows; the rest are closed (B4).
const LISTED_STATUSES: Array[String] = [BoardEntry.STATUS_DRAFT, BoardEntry.STATUS_ACTIVE]
#Closed states; each one stays on the list until the calendar month its closed_minute falls in ends.
const CLOSED_STATUSES: Array[String] = [BoardEntry.STATUS_SUCCEEDED, BoardEntry.STATUS_FAILED,
	BoardEntry.STATUS_EXPIRED, BoardEntry.STATUS_REJECTED]

signal contracts_changed
signal roster_changed
signal money_changed(bank_notes: int)
signal day_changed(day_index: int)
signal month_changed(year: int, month: int)
signal speed_changed(level: int)

var bank_notes: int = START_BANK
var mercs: Array[MercenaryData] = []
var roster: Array[MercView] = []
var board: ContractBoard = null
var contracts: Array[ContractView] = []
var active_contracts: Dictionary = {}
#Entry id to ActiveRun: the night dispatches that leave at 6:00, each one in active_contracts too.
var queued: Dictionary = {}
var merc_extras: Dictionary = {}
var clock: ClockRunner = null
var started: bool = false

#Day counters for the metrics record; the guild source reads and clears them.
var _day_expenses: int = 0
var _day_contracts: Dictionary = {}
var _dead_counted: int = 0


func _ready() -> void:
	clock = ClockRunner.new()
	clock.name = CLOCK_NAME
	clock.processor = process_until
	add_child(clock)
	clock.day_changed.connect(_relay_day)
	clock.month_changed.connect(_relay_month)
	clock.speed_changed.connect(_relay_speed)
	day_changed.connect(MetricsHistory.record_day)
	MetricsHistory.merc_source = _merc_metrics
	MetricsHistory.contract_source = _contract_metrics
	MetricsHistory.guild_source = _guild_metrics


#A fresh guild: ten level 1 mercs hired in order and a full board, both dated to the start minute.
func start_new_game() -> void:
	ContractResourceBuilder.build_all()
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)
	mercs.clear()
	roster.clear()
	contracts.clear()
	merc_extras.clear()
	active_contracts.clear()
	queued.clear()
	bank_notes = START_BANK
	_day_expenses = 0
	_day_contracts.clear()
	_dead_counted = 0
	var previous_level: int = MercGenerator.forced_level
	for i: int in range(START_MERCS):
		MercGenerator.forced_level = START_LEVEL
		var merc: MercenaryData = MercGenerator.generate(i)
		MercGenerator.forced_level = previous_level
		hire(merc)
	GuildRoster.set_roster(mercs)
	BeauSystem.set_roster(mercs)
	board = ContractBoard.new()
	board.launch(CampaignClock.now())
	started = true
	refresh_views()


#Signs one merc on at the current minute; their wage and opening opinion are fixed here.
func hire(merc: MercenaryData) -> void:
	if merc == null:
		return
	var earlier: Array[MercenaryData] = []
	earlier.assign(mercs)
	SalarySystem.hire(merc, earlier, CampaignClock.now())
	mercs.append(merc)
	merc_extras[merc.merc_uid] = DEFAULT_EXTRAS.duplicate(true)
	refresh_views()
	roster_changed.emit()


#Moves the campaign to a minute, settling everything due on the way in order (11.2). A tick may
#jump over several due moments, so the earliest is fired one at a time until none is left.
func process_until(target: int) -> void:
	var contracts_dirty: bool = false
	var roster_dirty: bool = false
	var start_month: Dictionary = TrynnCalendar.date_of(CampaignClock.now())
	while true:
		var now: int = CampaignClock.now()
		var salary_at: int = _next_salary_minute(now)
		var expiry_at: int = board.next_expiry_minute(now) if board != null else -1
		var refill_at: int = board.next_refill_minute(now) if board != null else -1
		var depart_at: int = _next_depart_minute(now)
		var due: int = -1
		due = _earliest(due, salary_at, target)
		due = _earliest(due, expiry_at, target)
		due = _earliest(due, refill_at, target)
		due = _earliest(due, depart_at, target)
		for entry: BoardEntry in _active_entries():
			due = _earliest(due, entry.scheduler.next_due(), target)
		if due < 0:
			break
		CampaignClock.advance_to(due)
		if salary_at == due:
			_debit_salaries()
		if board != null and expiry_at == due:
			if not board.expire_due(due).is_empty():
				contracts_dirty = true
		if board != null and refill_at == due:
			if not board.refill(due).is_empty():
				contracts_dirty = true
		if depart_at == due:
			_depart_queued(due)
			contracts_dirty = true
			roster_dirty = true
		for entry: BoardEntry in _active_entries():
			if entry.scheduler.next_due() != due:
				continue
			await entry.scheduler.step()
			contracts_dirty = true
			roster_dirty = true
			if entry.scheduler.is_done():
				_settle(entry)
	CampaignClock.advance_to(target)
	if not RestSystem.complete_due_rests(mercs, target).is_empty():
		roster_dirty = true
	if _month_turned(start_month, CampaignClock.now()):
		contracts_dirty = true
	refresh_views()
	if contracts_dirty:
		contracts_changed.emit()
	if roster_dirty:
		roster_changed.emit()


#Sends a team out: the travel cost leaves the bank at once and the scheduler takes over the run.
func dispatch(entry_id: int, run: ActiveRun) -> bool:
	if board == null or run == null:
		return false
	var entry: BoardEntry = board.entry(entry_id)
	if entry == null or not entry.is_open():
		return false
	var uids: Array[int] = run.uids()
	if uids.is_empty():
		return false
	var busy: Array[int] = busy_uids()
	var team: Array[MercenaryData] = []
	for uid: int in uids:
		var merc: MercenaryData = merc_by_uid(uid)
		if merc == null or busy.has(uid) or not RestSystem.is_deployable(merc):
			return false
		team.append(merc)
	var now: int = CampaignClock.now()
	if ContractScheduler.is_night_minute(now):
		return _queue_dispatch(entry, run, now)
	var scheduler: ContractScheduler = board.activate(entry_id, team,
		travel_minutes(run.travel_mode, entry.distance_km), now, _line_sink(entry))
	if scheduler == null:
		return false
	_spend(run.travel_cost)
	run.dispatched_minute = now
	run.depart_minute = now
	run.entry_id = entry_id
	active_contracts[entry_id] = run
	refresh_views()
	contracts_changed.emit()
	return true


#Calls a queued dispatch off before 6:00: the travel money comes back and the posting reopens.
#A team already on the road cannot be called back this way.
func cancel_dispatch(entry_id: int) -> bool:
	if not queued.has(entry_id):
		return false
	var run: ActiveRun = queued[entry_id] as ActiveRun
	if run != null:
		_refund(run.travel_cost)
	var entry: BoardEntry = board.entry(entry_id) if board != null else null
	if entry != null:
		entry.status = BoardEntry.STATUS_DRAFT
		if entry.contract != null:
			entry.contract.status = "Draft"
		entry.log_lines.clear()
	queued.erase(entry_id)
	active_contracts.erase(entry_id)
	refresh_views()
	contracts_changed.emit()
	roster_changed.emit()
	return true


#Turns a posting down; it stays listed as Rejected until the month ends (B4).
func reject(entry_id: int) -> bool:
	if board == null or not board.reject(entry_id):
		return false
	refresh_views()
	contracts_changed.emit()
	return true


#Erases a posting a dispatch could not take; nothing was charged, so nothing comes back (B5).
func discard(entry_id: int) -> bool:
	if board == null or active_contracts.has(entry_id) or queued.has(entry_id):
		return false
	var entry: BoardEntry = board.entry(entry_id)
	if entry == null or entry.is_active() or _is_settled(entry):
		return false
	board.entries.erase(entry)
	refresh_views()
	contracts_changed.emit()
	return true


#A posting that already ran has a record; discard only strikes off one that never started.
func _is_settled(entry: BoardEntry) -> bool:
	return entry.status == BoardEntry.STATUS_SUCCEEDED \
		or entry.status == BoardEntry.STATUS_FAILED or entry.verdict != ""


const LEVEL_MODES: Array[String] = ["Auto", "Defensive", "Offensive", "Utility"]


#Writes a new wage through SalarySystem and returns the opinion the merc now holds.
func set_salary(uid: int, new_salary: int) -> int:
	var merc: MercenaryData = merc_by_uid(uid)
	if merc == null:
		return 0
	var opinion: int = SalarySystem.apply_salary_change(merc, new_salary)
	refresh_views()
	roster_changed.emit()
	return opinion


#The level-up preference the Merc Viewer stores per merc; unknown modes are ignored.
func set_level_mode(uid: int, mode: String) -> bool:
	if not merc_extras.has(uid) or not LEVEL_MODES.has(mode):
		return false
	merc_extras[uid]["level_mode"] = mode
	refresh_views()
	roster_changed.emit()
	return true


func set_speed(level: int) -> void:
	if clock != null:
		clock.set_speed(level)


#What the merc is doing and how long is left of it, for the roster list (GuiTypes.MercStatus).
func merc_status(merc: MercenaryData) -> Dictionary:
	if merc == null:
		return {"status": GuiTypes.MercStatus.AVAILABLE, "hours_left": 0.0}
	var now: int = CampaignClock.now()
	var waiting: ActiveRun = _queued_run_of(merc.merc_uid)
	if waiting != null:
		return {"status": GuiTypes.MercStatus.CONTRACT,
			"hours_left": _hours(waiting.depart_minute - now)}
	if merc.on_contract:
		var entry: BoardEntry = _entry_of(merc)
		var due: int = entry.scheduler.next_minute if entry != null else now
		return {"status": GuiTypes.MercStatus.CONTRACT, "hours_left": _hours(due - now)}
	if RestSystem.is_resting(merc):
		var kind: int = GuiTypes.MercStatus.RESTING
		if merc.rest_lockout_kind == RestSystem.KIND_FURLOUGH:
			kind = GuiTypes.MercStatus.VACATION
		return {"status": kind, "hours_left": _hours(merc.rest_lockout_until - now)}
	return {"status": GuiTypes.MercStatus.AVAILABLE, "hours_left": 0.0}


#Everyone who cannot be sent anywhere right now.
func busy_uids() -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in mercs:
		if merc == null:
			continue
		if merc.on_contract or not RestSystem.is_deployable(merc):
			out.append(merc.merc_uid)
	for id: int in queued:
		var run: ActiveRun = queued[id] as ActiveRun
		if run == null:
			continue
		for uid: int in run.uids():
			if not out.has(uid):
				out.append(uid)
	return out


func merc_by_uid(uid: int) -> MercenaryData:
	for merc: MercenaryData in mercs:
		if merc != null and merc.merc_uid == uid:
			return merc
	return null


#Rebuilds the two view lists the screens read; the dead and the captive are hidden for now.
func refresh_views() -> void:
	var now: int = CampaignClock.now()
	roster.clear()
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead or SalarySystem.is_captive(merc):
			continue
		var state: Dictionary = merc_status(merc)
		roster.append(MercView.from_merc(merc, int(state["status"]), float(state["hours_left"]),
			employment_months(merc), _extras_for(merc)))
	contracts.clear()
	if board == null:
		return
	for entry: BoardEntry in board.entries:
		if _is_listed(entry, now):
			contracts.append(ContractView.from_entry(entry, now))


#Open and active postings always list; a closed one lists until its month ends (B4).
#A closed entry with no stamp never got one, so it drops out the way it did before stage 4.
func _is_listed(entry: BoardEntry, now: int) -> bool:
	if entry == null:
		return false
	if LISTED_STATUSES.has(entry.status):
		return true
	if not CLOSED_STATUSES.has(entry.status):
		return false
	if entry.closed_minute < 0:
		return false
	return not _month_turned(TrynnCalendar.date_of(entry.closed_minute), now)


#True when the minute falls outside the calendar month the date dictionary names.
func _month_turned(start: Dictionary, now: int) -> bool:
	var at: Dictionary = TrynnCalendar.date_of(now)
	return int(at["year"]) != int(start["year"]) or int(at["month"]) != int(start["month"])


func month_expenses() -> int:
	return SalarySystem.month_expenses(mercs)


func employment_months(merc: MercenaryData) -> int:
	if merc == null or merc.hired_minute < 0:
		return 0
	return TrynnCalendar.months_between(merc.hired_minute, CampaignClock.now())


#Minutes on the road for a travel mode over a distance; an unknown mode falls back to the
#scheduler's own travel figure and a mode with no daily range arrives at once.
func travel_minutes(mode_key: String, distance_km: int) -> int:
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		if String(mode["key"]) != mode_key:
			continue
		var per_day: float = float(mode["km_per_day"])
		if per_day <= 0.0:
			return 0
		return int(ceil(float(distance_km) / per_day * float(CampaignClock.MINUTES_PER_DAY)))
	return CampaignClock.TRAVEL_MINUTES


#The next salary minute strictly after this one: the 2nd of the month at SALARY_HOUR.
func _next_salary_minute(now: int) -> int:
	var date: Dictionary = TrynnCalendar.date_of(now)
	var at: int = TrynnCalendar.first_weekday_minute(int(date["year"]), int(date["month"]), SALARY_HOUR)
	if at > now:
		return at
	var next: Dictionary = TrynnCalendar.date_of(TrynnCalendar.next_month_start(now))
	return TrynnCalendar.first_weekday_minute(int(next["year"]), int(next["month"]), SALARY_HOUR)


#The earlier of two due minutes, ignoring anything past the target or already behind.
func _earliest(best: int, candidate: int, target: int) -> int:
	if candidate < 0 or candidate > target:
		return best
	if best < 0 or candidate < best:
		return candidate
	return best


func _active_entries() -> Array[BoardEntry]:
	var out: Array[BoardEntry] = []
	if board == null:
		return out
	for entry: BoardEntry in board.active_entries():
		if entry.scheduler != null:
			out.append(entry)
	return out


func _entry_of(merc: MercenaryData) -> BoardEntry:
	for entry: BoardEntry in _active_entries():
		if entry.scheduler.run != null and entry.scheduler.run.team.has(merc):
			return entry
	return null


#The log sink an entry hands its scheduler; the queued departure reuses it.
func _line_sink(entry: BoardEntry) -> Callable:
	return func(line: String) -> void:
		entry.log_lines.append(line)


#A dispatch made at night: the crew and the travel money are committed now, the team leaves at 6:00.
func _queue_dispatch(entry: BoardEntry, run: ActiveRun, now: int) -> bool:
	run.dispatched_minute = now
	run.entry_id = entry.id
	run.depart_minute = ContractScheduler.next_wake_minute(now)
	entry.log_lines.clear()
	entry.log_lines.append(_queued_line(now, run.depart_minute))
	entry.verdict = ""
	entry.status = BoardEntry.STATUS_ACTIVE
	if entry.contract != null:
		entry.contract.status = "Active"
	_spend(run.travel_cost)
	active_contracts[entry.id] = run
	queued[entry.id] = run
	refresh_views()
	contracts_changed.emit()
	roster_changed.emit()
	return true


#The one line a queued posting carries, in the CampaignClock.line style, timed to the departure.
func _queued_line(now: int, depart: int) -> String:
	return "CLOCK: %s %s -> %s" % [QUEUED_TAG, CampaignClock.delta_text(depart - now),
		CampaignClock.stamp(depart)]


#The soonest queued departure strictly after this minute; -1 when nothing is waiting.
func _next_depart_minute(now: int) -> int:
	var soonest: int = -1
	for id: int in queued:
		var run: ActiveRun = queued[id] as ActiveRun
		if run == null or run.depart_minute <= now:
			continue
		if soonest < 0 or run.depart_minute < soonest:
			soonest = run.depart_minute
	return soonest


#6:00: every queued team still standing leaves; one with nobody left has its dispatch called off.
func _depart_queued(due: int) -> void:
	var ids: Array[int] = []
	for id: int in queued:
		var run: ActiveRun = queued[id] as ActiveRun
		if run != null and run.depart_minute == due:
			ids.append(id)
	ids.sort()
	for id: int in ids:
		var run: ActiveRun = queued[id] as ActiveRun
		var entry: BoardEntry = board.entry(id) if board != null else null
		if entry == null:
			queued.erase(id)
			active_contracts.erase(id)
			continue
		var team: Array[MercenaryData] = []
		for uid: int in run.uids():
			var merc: MercenaryData = merc_by_uid(uid)
			if merc != null and not merc.is_dead:
				team.append(merc)
		if team.is_empty():
			_call_off_queued(entry, run, due)
			continue
		var held: String = entry.log_lines[0] if not entry.log_lines.is_empty() else ""
		entry.status = BoardEntry.STATUS_DRAFT
		var scheduler: ContractScheduler = board.activate(id, team,
			travel_minutes(run.travel_mode, entry.distance_km), due, _line_sink(entry))
		if scheduler == null:
			_call_off_queued(entry, run, due)
			continue
		if held != "":
			entry.log_lines.insert(0, held)
		queued.erase(id)


#A queued dispatch with nobody left to send: the money comes back and the posting reopens.
func _call_off_queued(entry: BoardEntry, run: ActiveRun, due: int) -> void:
	if run != null:
		_refund(run.travel_cost)
	entry.status = BoardEntry.STATUS_DRAFT
	if entry.contract != null:
		entry.contract.status = "Draft"
	entry.log_lines.clear()
	entry.log_lines.append("%s CALLED OFF: nobody left to send" % CampaignClock.stamp(due))
	queued.erase(entry.id)
	active_contracts.erase(entry.id)


#The queued run a merc is waiting on; null when they are not in one.
func _queued_run_of(uid: int) -> ActiveRun:
	for id: int in queued:
		var run: ActiveRun = queued[id] as ActiveRun
		if run != null and run.uids().has(uid):
			return run
	return null


#One month's wages leave the bank; a captive's share is recorded by SalarySystem, never paid.
func _debit_salaries() -> void:
	var result: Dictionary = SalarySystem.monthly_debit(mercs, CampaignClock.stamp())
	_spend(int(result["total"]))


#Closes a finished run: the board decides the posting's fate and a success pays out (G13).
func _settle(entry: BoardEntry) -> void:
	var run: ContractRun = entry.scheduler.run
	board.settle(entry, CampaignClock.now())
	if run != null:
		var type_name: String = entry.contract_type()
		_day_contracts[type_name] = int(_day_contracts.get(type_name, 0)) + 1
		if run.verdict == BoardEntry.STATUS_SUCCEEDED:
			bank_notes += run.reward_paid
			money_changed.emit(bank_notes)
	active_contracts.erase(entry.id)


func _spend(amount: int) -> void:
	if amount == 0:
		return
	bank_notes -= amount
	_day_expenses += amount
	money_changed.emit(bank_notes)


#The travel debit of a dispatch that never left, back in the bank and off the day's expenses.
func _refund(amount: int) -> void:
	if amount == 0:
		return
	bank_notes += amount
	_day_expenses -= amount
	money_changed.emit(bank_notes)


func _extras_for(merc: MercenaryData) -> Dictionary:
	if not merc_extras.has(merc.merc_uid):
		merc_extras[merc.merc_uid] = DEFAULT_EXTRAS.duplicate(true)
	return merc_extras[merc.merc_uid]


func _hours(minutes: int) -> float:
	return maxf(0.0, float(minutes) / float(CampaignClock.MINUTES_PER_HOUR))


func _relay_day(day_index: int) -> void:
	day_changed.emit(day_index)


func _relay_month(year: int, month: int) -> void:
	month_changed.emit(year, month)


func _relay_speed(level: int) -> void:
	speed_changed.emit(level)


#One day of per-merc samples; the dead drop out of the record.
func _merc_metrics(_day_index: int) -> Dictionary:
	var row: Dictionary = {}
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead:
			continue
		var prefix: String = "%d/" % merc.merc_uid
		row[prefix + "salary"] = float(merc.monthly_salary)
		row[prefix + "level"] = float(ExperienceSystem.current_level(merc))
		row[prefix + "op"] = float(merc.guild_opinion)
		var status: int = int(merc_status(merc)["status"])
		row[prefix + "vac"] = 1.0 if status == GuiTypes.MercStatus.VACATION else 0.0
	return row


#One day of contract samples: what settled today, per type and in total.
func _contract_metrics(_day_index: int) -> Dictionary:
	var row: Dictionary = {}
	var total: float = 0.0
	for type_name: String in _day_contracts:
		var count: float = float(_day_contracts[type_name])
		row[type_name + "/count"] = count
		total += count
	row["count"] = total
	return row


#One day of guild samples. This source is recorded last, so the day counters reset here.
func _guild_metrics(_day_index: int) -> Dictionary:
	var living: int = 0
	var dead: int = 0
	for merc: MercenaryData in mercs:
		if merc == null:
			continue
		if merc.is_dead:
			dead += 1
		else:
			living += 1
	var row: Dictionary = {
		"bank": float(bank_notes),
		"exp": float(_day_expenses),
		"count": float(living),
		"dead": float(maxi(0, dead - _dead_counted)),
		#No investment system exists yet, so the portfolio stays flat at nothing.
		"port": 0.0,
	}
	_dead_counted = dead
	_day_expenses = 0
	_day_contracts.clear()
	return row

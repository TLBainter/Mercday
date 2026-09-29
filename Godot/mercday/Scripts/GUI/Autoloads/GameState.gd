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
#PLACEHOLDER: the contract accounting a finance layer will own. Expenses run at a flat percent of
#the reward, a failure pays a fraction of the experience and the experience itself is a flat draw.
const RESULT_EXPENSE_PCT: int = 12
const RESULT_FAIL_XP_PCT: int = 35
const RESULT_XP_BASE: int = 40
const RESULT_XP_PER_DIFF: int = 30
#PLACEHOLDER: sample roles and bar levels for seed_results_preview; no real run reads them.
const RESULT_PREVIEW_ROLES: Array[String] = ["Guide", "Escort", "Driver", "Assassin", "Support"]
const RESULT_PREVIEW_AFTER_PCT: int = 55
const RESULT_PREVIEW_GAP_PCT: int = 30
#Reasons money_moved carries; a finance ledger reads these to sort its transaction list.
const REASON_TRAVEL: String = "travel"
const REASON_PAYROLL: String = "payroll"
const REASON_CONTRACT: String = "contract"
const REASON_TRAVEL_REFUND: String = "travel_refund"
const REASON_LOAN: String = "loan"
const REASON_LOAN_PAYMENT: String = "loan_payment"
const REASON_LOAN_PAYOFF: String = "loan_payoff"
const REASON_ODD_JOB: String = "odd_job"
const REASON_STOCK: String = "stock"
const REASON_DIVIDEND: String = "dividend"
#A credit carrying one of these reasons is income, so it never lowers the day's expenses.
const INCOME_REASONS: Array[String] = [REASON_LOAN, REASON_STOCK, REASON_DIVIDEND]
#Ledger texts GameState writes itself; every other label comes from the caller.
const LABEL_PAYROLL: String = "Payroll"
const LABEL_REWARD: String = "%s - Reward"
const LABEL_TRAVEL: String = "Travel - %s (x%d)"
#The autoloads that take a tick each time the clock moves, in the order they run.
const TICK_ORDER: Array[String] = ["FinanceManager", "FinanceLedger", "BenefitsManager",
	"StockMarket", "LegalManager", "PromotionsManager", "BazaarManager"]
const TICK_METHOD: String = "tick"
#The away registry takes the statuses from LOAN to ODD_JOB and nothing else.
const AWAY_FIRST_STATUS: int = GuiTypes.MercStatus.LOAN
const AWAY_LAST_STATUS: int = GuiTypes.MercStatus.ODD_JOB

signal contracts_changed
signal roster_changed
signal money_changed(bank_notes: int)
#Every debit and credit the bank takes, with the reason it moved (finance ledger, HUD flyouts).
signal money_moved(delta: int, reason: String)
#The same move with the ledger text a finance row prints; it follows money_moved every time.
signal money_logged(delta: int, reason: String, label: String)
signal day_changed(day_index: int)
signal month_changed(year: int, month: int)
signal speed_changed(level: int)
#A lock or an upsell asking for the Plans screen; target names the page and the row to open on.
signal go_to_plans_requested(target: Dictionary)
signal pip_modes_changed
#Promotions handing one campaign's applicants to the Hiring tab.
signal open_hiring_requested(campaign_id: int)
#The HUD money counter asked to fly a change the bank has already taken.
signal money_fly_requested(amount: int)
#One posting settled and its result is waiting to be opened.
signal results_recorded(entry_id: int)
signal results_seen(entry_id: int)
#One merc left the guild or came back to it (the away registry).
signal away_changed(uid: int)

var bank_notes: int = START_BANK
var mercs: Array[MercenaryData] = []
var roster: Array[MercView] = []
var board: ContractBoard = null
var contracts: Array[ContractView] = []
var active_contracts: Dictionary = {}
#Entry id to ActiveRun: the night dispatches that leave at 6:00, each one in active_contracts too.
var queued: Dictionary = {}
var merc_extras: Dictionary = {}
#Merc uid to the level-up mode it is coached on; a uid with no entry runs on Auto (PipDefs).
var pip_modes: Dictionary = {}
#The applicant filter the Hiring tab picks up once; {} while nothing has asked for one.
var hire_filter: Dictionary = {}
#Entry id to ContractResultData: what every settled posting paid, kept for the results screen.
var results: Dictionary = {}
#Entry id to true once the player has opened that result.
var seen_results: Dictionary = {}
#Entry id to {merc uid: snapshot}: what each merc looked like when the team left.
var _departure: Dictionary = {}
#Merc uid to {status, until}: every merc the guild sent away (LOAN to CAPTURED).
var _away: Dictionary = {}
#Every merc the guild no longer has, oldest first, kept for the systems that bring them back.
var removed: Array[RemovedMercRecord] = []
var clock: ClockRunner = null
var started: bool = false
#Where the ticked managers are looked up; a suite points it at its own probe parent.
var tick_root: String = "/root/"

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
	SubscriptionManager.changed.connect(prune_pip_modes)


#A fresh guild: ten level 1 mercs hired in order and a full board, both dated to the start minute.
func start_new_game() -> void:
	ContractResourceBuilder.build_all()
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)
	mercs.clear()
	roster.clear()
	contracts.clear()
	merc_extras.clear()
	pip_modes.clear()
	hire_filter.clear()
	active_contracts.clear()
	queued.clear()
	results.clear()
	seen_results.clear()
	_departure.clear()
	_away.clear()
	removed.clear()
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
	SubscriptionManager.reset()
	SubscriptionManager.apply_harness_flag()
	_reset_notices()
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
	if _clear_returned_away(CampaignClock.now()):
		roster_dirty = true
	_tick_managers(CampaignClock.now())
	_escalate_notices()
	if not RestSystem.complete_due_rests(mercs, target).is_empty():
		roster_dirty = true
	if _month_turned(start_month, CampaignClock.now()):
		contracts_dirty = true
	refresh_views()
	if contracts_dirty:
		contracts_changed.emit()
	if roster_dirty:
		roster_changed.emit()


#Every away merc whose return minute has passed is back on the roster; true when a row went.
func _clear_returned_away(now: int) -> bool:
	var back: Array[int] = []
	for uid: int in _away:
		var ends: int = int((_away[uid] as Dictionary)["until"])
		if ends >= 0 and ends <= now:
			back.append(uid)
	if back.is_empty():
		return false
	for uid: int in back:
		_away.erase(uid)
		away_changed.emit(uid)
	return true


#Hands the new minute to every manager that keeps its own timed events, in TICK_ORDER; a manager
#without a tick and one this build does not carry are both skipped.
func _tick_managers(now: int) -> void:
	for manager: String in TICK_ORDER:
		var node: Node = get_node_or_null(tick_root + manager)
		if node != null and node.has_method(TICK_METHOD):
			node.call(TICK_METHOD, now)


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
	_spend(run.travel_cost, REASON_TRAVEL, _travel_label(run))
	run.dispatched_minute = now
	run.depart_minute = now
	run.entry_id = entry_id
	active_contracts[entry_id] = run
	_snap_departure(entry_id, team)
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
		_refund(run.travel_cost, REASON_TRAVEL_REFUND, _travel_label(run))
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
	var sent: int = away_status(merc.merc_uid)
	if sent >= 0:
		var ends: int = away_until(merc.merc_uid)
		return {"status": sent, "hours_left": _hours(ends - now) if ends >= 0 else 0.0}
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
	for uid: int in _away:
		if not out.has(uid):
			out.append(uid)
	for id: int in queued:
		var run: ActiveRun = queued[id] as ActiveRun
		if run == null:
			continue
		for uid: int in run.uids():
			if not out.has(uid):
				out.append(uid)
	return out


#Sends one merc away from the guild: a status from LOAN to ODD_JOB and the minute they come back
#(-1 = no end). Any other status is refused and the registry is left alone.
func set_away(uid: int, status: int, until_minute: int = -1) -> bool:
	if status < AWAY_FIRST_STATUS or status > AWAY_LAST_STATUS:
		return false
	_away[uid] = {"status": status, "until": until_minute}
	refresh_views()
	roster_changed.emit()
	away_changed.emit(uid)
	return true


func clear_away(uid: int) -> void:
	if not _away.has(uid):
		return
	_away.erase(uid)
	refresh_views()
	roster_changed.emit()
	away_changed.emit(uid)


#The away status of one merc, or -1 when the guild has them.
func away_status(uid: int) -> int:
	if not _away.has(uid):
		return -1
	return int((_away[uid] as Dictionary)["status"])


func is_away(uid: int) -> bool:
	return _away.has(uid)


#The minute an away merc comes back; -1 when the row has no end and when there is no row.
func away_until(uid: int) -> int:
	if not _away.has(uid):
		return -1
	return int((_away[uid] as Dictionary)["until"])


#Takes one merc out of the guild for good and files what they were in the removed queue. Returns
#the record, or null when no merc holds the uid. A status of -1 reads the merc's own payroll
#status. Everything keyed on the uid leaves with them; the run history stays.
func remove_merc(uid: int, reason: String, status: int = -1) -> RemovedMercRecord:
	var merc: MercenaryData = merc_by_uid(uid)
	if merc == null:
		return null
	var left_status: int = status
	if left_status < 0:
		left_status = int(merc_status(merc)["status"])
	var record: RemovedMercRecord = RemovedMercRecord.make(merc, reason, left_status,
		CampaignClock.now())
	mercs.erase(merc)
	GuildRoster.mercs.erase(merc)
	BeauSystem.roster.erase(merc)
	merc_extras.erase(uid)
	pip_modes.erase(uid)
	_away.erase(uid)
	for entry_id: int in _departure:
		(_departure[entry_id] as Dictionary).erase(uid)
	removed.append(record)
	refresh_views()
	roster_changed.emit()
	return record


#The record of one removed merc, or null when the guild never lost that uid.
func removed_by_uid(uid: int) -> RemovedMercRecord:
	for record: RemovedMercRecord in removed:
		if record != null and record.uid == uid:
			return record
	return null


func removed_count() -> int:
	return removed.size()


#The mercs a payroll run pays for: a fired merc is off the books and everyone else is on them.
func payroll_mercs() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc == null or away_status(merc.merc_uid) == GuiTypes.MercStatus.FIRED:
			continue
		out.append(merc)
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
	if is_unclaimed(entry.id):
		return true
	if entry.closed_minute < 0:
		return false
	return not _month_turned(TrynnCalendar.date_of(entry.closed_minute), now)


#True when the minute falls outside the calendar month the date dictionary names.
func _month_turned(start: Dictionary, now: int) -> bool:
	var at: Dictionary = TrynnCalendar.date_of(now)
	return int(at["year"]) != int(start["year"]) or int(at["month"]) != int(start["month"])


func month_expenses() -> int:
	return SalarySystem.month_expenses(payroll_mercs())


#The next minute payroll fires, for a screen that counts down to payday.
func next_payday_minute() -> int:
	return _next_salary_minute(CampaignClock.now())


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


#The ledger text of one travel charge: the mode and how many left on it.
func _travel_label(run: ActiveRun) -> String:
	if run == null:
		return ""
	var mode: Dictionary = GuiTypes.travel_mode(run.travel_mode)
	return LABEL_TRAVEL % [String(mode.get("label", run.travel_mode)), run.uids().size()]


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
	_spend(run.travel_cost, REASON_TRAVEL, _travel_label(run))
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
		_snap_departure(id, team)
		queued.erase(id)


#A queued dispatch with nobody left to send: the money comes back and the posting reopens.
func _call_off_queued(entry: BoardEntry, run: ActiveRun, due: int) -> void:
	if run != null:
		_refund(run.travel_cost, REASON_TRAVEL_REFUND, _travel_label(run))
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
	var result: Dictionary = SalarySystem.monthly_debit(payroll_mercs(), CampaignClock.stamp())
	_spend(int(result["total"]), REASON_PAYROLL, LABEL_PAYROLL)


#Closes a finished run: the board decides the posting's fate and a success pays out (G13).
func _settle(entry: BoardEntry) -> void:
	var run: ContractRun = entry.scheduler.run
	var sent: ActiveRun = active_contracts.get(entry.id) as ActiveRun
	board.settle(entry, CampaignClock.now())
	if run != null:
		var type_name: String = entry.contract_type()
		_day_contracts[type_name] = int(_day_contracts.get(type_name, 0)) + 1
		if run.verdict == BoardEntry.STATUS_SUCCEEDED:
			bank_notes += run.reward_paid
			money_changed.emit(bank_notes)
			money_moved.emit(run.reward_paid, REASON_CONTRACT)
			money_logged.emit(run.reward_paid, REASON_CONTRACT, LABEL_REWARD % _entry_name(entry))
		_record_result(entry, run, sent)
	active_contracts.erase(entry.id)
	_departure.erase(entry.id)


func _spend(amount: int, reason: String = "", label: String = "") -> void:
	if amount == 0:
		return
	bank_notes -= amount
	_day_expenses += amount
	money_changed.emit(bank_notes)
	money_moved.emit(-amount, reason)
	money_logged.emit(-amount, reason, label)


#Notes back in the bank: the travel debit of a dispatch that never left comes off the day's
#expenses, while income (a loan, a share sale, a dividend) only raises the bank.
func _refund(amount: int, reason: String = "", label: String = "") -> void:
	if amount == 0:
		return
	bank_notes += amount
	if not INCOME_REASONS.has(reason):
		_day_expenses -= amount
	money_changed.emit(bank_notes)
	money_moved.emit(amount, reason)
	money_logged.emit(amount, reason, label)


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


#The Plans screen the locks and the upsells jump to; target names the page and the row to open on.
func go_to_plans(target: Dictionary) -> void:
	go_to_plans_requested.emit(target)


#Opens Finance on its Hiring tab, filtered to the applicants one campaign brought in.
func open_hiring(campaign_id: int) -> void:
	hire_filter = {"from": [campaign_id]}
	open_hiring_requested.emit(campaign_id)


#Hands the stored filter over once; the next caller gets nothing.
func take_hire_filter() -> Dictionary:
	var filter: Dictionary = hire_filter
	hire_filter = {}
	return filter


#Asks the HUD to fly notes in or out of its counter; spend() or refund() moved them already.
func fly_money(amount: int) -> void:
	if amount == 0:
		return
	money_fly_requested.emit(amount)


func can_afford(amount: int) -> bool:
	return amount <= bank_notes


#Debits the bank when the notes are there; a refusal leaves it untouched.
func spend(amount: int, reason: String = "", label: String = "") -> bool:
	if amount < 0 or amount > bank_notes:
		return false
	_spend(amount, reason, label)
	return true


func refund(amount: int, reason: String = "", label: String = "") -> void:
	_refund(amount, reason, label)


#The bill that always lands: payroll, a loan payment or a fine takes the notes whether they are
#there or not, so the bank can go below zero.
func charge(amount: int, reason: String = "", label: String = "") -> void:
	if amount <= 0:
		return
	_spend(amount, reason, label)


func day() -> int:
	return TrynnCalendar.day_index(CampaignClock.now())


#Coaches one merc onto a level-up mode. A mode the subscription does not hold is refused; the
#engine only knows the four LEVEL_MODES, so every other mode mirrors onto Auto for now.
func set_pip_mode(uid: int, mode: StringName) -> bool:
	if merc_by_uid(uid) == null or not PipDefs.has(mode):
		return false
	if not PipDefs.unlocked(mode, SubscriptionManager.entitlements()):
		return false
	pip_modes[uid] = mode
	_mirror_level_mode(uid, mode)
	refresh_views()
	pip_modes_changed.emit()
	return true


#The mode in force: the stored one while its gate holds, else Auto.
func pip_mode(uid: int) -> StringName:
	var mode: StringName = stored_pip_mode(uid)
	if PipDefs.unlocked(mode, SubscriptionManager.entitlements()):
		return mode
	return PipDefs.DEFAULT_MODE


func stored_pip_mode(uid: int) -> StringName:
	return StringName(pip_modes.get(uid, PipDefs.DEFAULT_MODE))


#A downgrade takes its modes with it: every stored mode whose gate is gone falls back to Auto.
func prune_pip_modes() -> void:
	var ent: Dictionary = SubscriptionManager.entitlements()
	var dropped: Array[int] = []
	for uid: int in pip_modes:
		if not PipDefs.unlocked(StringName(pip_modes[uid]), ent):
			dropped.append(uid)
	if dropped.is_empty():
		return
	for uid: int in dropped:
		pip_modes.erase(uid)
		_mirror_level_mode(uid, PipDefs.DEFAULT_MODE)
	refresh_views()
	pip_modes_changed.emit()


#The engine's own level_mode field, held in step with the part of the coached mode it can express.
func _mirror_level_mode(uid: int, mode: StringName) -> void:
	var merc: MercenaryData = merc_by_uid(uid)
	if merc == null:
		return
	var text: String = String(mode)
	_extras_for(merc)["level_mode"] = text if LEVEL_MODES.has(text) else "Auto"


#The result of one settled posting; null while the posting has none.
func result_of(entry_id: int) -> ContractResultData:
	return results.get(entry_id) as ContractResultData


func has_result(entry_id: int) -> bool:
	return results.has(entry_id)


#A result nobody has opened yet: its posting stays on the list however old it is.
func is_unclaimed(entry_id: int) -> bool:
	return results.has(entry_id) and not seen_results.has(entry_id)


func unclaimed_ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in results:
		if not seen_results.has(id):
			out.append(id)
	out.sort()
	return out


#The player opened a result: the posting stops being unclaimed and its notifications go read.
func mark_seen(entry_id: int) -> bool:
	if not results.has(entry_id) or seen_results.has(entry_id):
		return false
	seen_results[entry_id] = true
	var center: Node = _notices()
	if center != null:
		center.call("read_contract", entry_id)
	results_seen.emit(entry_id)
	contracts_changed.emit()
	return true


#Two closed postings for the results click-through: one success, one failure, nobody really hurt.
func seed_results_preview() -> Array[int]:
	var out: Array[int] = []
	if board == null:
		return out
	var now: int = CampaignClock.now()
	if board.available().size() < 2:
		board.refill(now)
	var open_entries: Array[BoardEntry] = board.available()
	if open_entries.size() < 2:
		return out
	out.append(_seed_preview(open_entries[0], false, now))
	out.append(_seed_preview(open_entries[1], true, now))
	refresh_views()
	contracts_changed.emit()
	return out


func _notices() -> Node:
	return get_node_or_null("/root/NotificationCenter")


func _reset_notices() -> void:
	var center: Node = _notices()
	if center != null:
		center.call("reset")


func _escalate_notices() -> void:
	var center: Node = _notices()
	if center != null:
		center.call("escalate", CampaignClock.now())


#What each merc looked like when the team left, so the result can show the change.
func _snap_departure(entry_id: int, team: Array[MercenaryData]) -> void:
	var rows: Dictionary = {}
	for merc: MercenaryData in team:
		if merc == null:
			continue
		rows[merc.merc_uid] = {
			"hp": merc.current_hp,
			"ep": merc.current_ep,
			"mp": merc.current_mp,
			"hp_max": int(merc.stats.get("maximum_hit_points", 0)),
			"ep_max": int(merc.stats.get("maximum_endurance_points", 0)),
			"mp_max": int(merc.stats.get("maximum_magic_points", 0)),
			"xp": merc.xp,
			"level": ExperienceSystem.current_level(merc),
		}
	_departure[entry_id] = rows


#Builds the result of a settled posting. A run the board sent back to Draft keeps no result.
func _record_result(entry: BoardEntry, run: ContractRun, sent: ActiveRun) -> void:
	var failed: bool = entry.status == BoardEntry.STATUS_FAILED
	if not failed and entry.status != BoardEntry.STATUS_SUCCEEDED:
		return
	var result := ContractResultData.new()
	result.entry_id = entry.id
	result.name = _entry_name(entry)
	result.failed = failed
	result.closed_minute = entry.closed_minute
	if entry.contract != null:
		result.difficulty = entry.contract.difficulty
		result.listed_reward = entry.contract.reward_notes
	result.reward = 0 if failed else run.reward_paid
	result.expenses = sent.travel_cost if sent != null else 0
	#The finance layer writes result.bonus_pct before the results screen reads it.
	result.bonus_pct = 0
	result.members = _result_members(entry, run, sent)
	result.pick_mvp()
	result.assign_pay()
	_store_result(result)
	_push_result_notice(result)


func _result_members(entry: BoardEntry, run: ContractRun,
		sent: ActiveRun) -> Array[ResultMemberData]:
	var snaps: Dictionary = _departure.get(entry.id, {})
	var order: Array[int] = []
	var roles: Dictionary = {}
	if sent != null:
		for spot: TeamMember in sent.team:
			if spot == null or order.has(spot.merc_uid):
				continue
			order.append(spot.merc_uid)
			roles[spot.merc_uid] = spot.role
	else:
		for group: Array[MercenaryData] in [run.team, run.casualties, run.kidnapped]:
			for merc: MercenaryData in group:
				if merc != null and not order.has(merc.merc_uid):
					order.append(merc.merc_uid)
	var out: Array[ResultMemberData] = []
	for uid: int in order:
		var merc: MercenaryData = merc_by_uid(uid)
		if merc == null:
			continue
		out.append(_result_member(merc, String(roles.get(uid, "")), run,
			snaps.get(uid, {}) as Dictionary))
	return out


func _result_member(merc: MercenaryData, role: String, run: ContractRun,
		snap: Dictionary) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = merc.merc_uid
	member.name = merc.merc_name
	member.role = role
	member.tradition = merc.tradition.tradition_name if merc.tradition != null else ""
	member.fate = ResultMemberData.Fate.ALIVE
	if merc.is_dead or run.casualties.has(merc):
		member.fate = ResultMemberData.Fate.DEAD
	elif run.kidnapped.has(merc) or SalarySystem.is_captive(merc):
		member.fate = ResultMemberData.Fate.CAPTURED
	member.level_after = ExperienceSystem.current_level(merc)
	member.level_before = int(snap.get("level", member.level_after))
	var before_total: int = int(snap.get("xp", merc.xp))
	member.xp_gained = maxi(0, merc.xp - before_total)
	member.xp_need = ExperienceSystem.xp_for_level(member.level_before + 1) - \
		ExperienceSystem.xp_for_level(member.level_before)
	member.xp_before = maxi(0, before_total - ExperienceSystem.xp_for_level(member.level_before))
	member.hp = Vector2i(merc.current_hp, int(merc.stats.get("maximum_hit_points", 0)))
	member.ep = Vector2i(merc.current_ep, int(merc.stats.get("maximum_endurance_points", 0)))
	member.mp = Vector2i(merc.current_mp, int(merc.stats.get("maximum_magic_points", 0)))
	member.hp_before = int(snap.get("hp", member.hp.x))
	member.ep_before = int(snap.get("ep", member.ep.x))
	member.mp_before = int(snap.get("mp", member.mp.x))
	return member


func _store_result(result: ContractResultData) -> void:
	results[result.entry_id] = result
	seen_results.erase(result.entry_id)
	results_recorded.emit(result.entry_id)


#One row on the bell per settled posting. The snap never names the outcome, only the posting.
func _push_result_notice(result: ContractResultData) -> void:
	var center: Node = _notices()
	if center == null:
		return
	var notice_type: StringName = NotificationData.TYPE_CONTRACT_COMPLETED
	if result.failed:
		notice_type = NotificationData.TYPE_CONTRACT_FAILED
	var snap: Dictionary = {
		"name": result.name,
		"difficulty": result.difficulty,
		"reward": result.listed_reward,
	}
	center.call("push", notice_type, result.entry_id, snap,
		NotificationData.Urgency.INFORMATIONAL, "")


func _entry_name(entry: BoardEntry) -> String:
	if entry.contract == null:
		return entry.contract_type()
	return ContractView.contract_name(entry.contract.contract_type, entry.contract.location_a)


#Closes one posting on paper only: no merc is touched and no money moves.
func _seed_preview(entry: BoardEntry, failed: bool, now: int) -> int:
	var status: String = BoardEntry.STATUS_FAILED if failed else BoardEntry.STATUS_SUCCEEDED
	entry.status = status
	entry.verdict = status
	entry.closed_minute = now
	var listed: int = 0
	var difficulty: float = 0.0
	if entry.contract != null:
		entry.contract.status = status
		listed = entry.contract.reward_notes
		difficulty = entry.contract.difficulty
	var result := ContractResultData.new()
	result.entry_id = entry.id
	result.name = _entry_name(entry)
	result.difficulty = difficulty
	result.failed = failed
	result.listed_reward = listed
	result.reward = 0 if failed else listed
	result.expenses = int(round(float(listed) * float(RESULT_EXPENSE_PCT) / 100.0))
	result.closed_minute = now
	result.preview = true
	result.bonus_pct = 0
	for i: int in mini(4, roster.size()):
		result.members.append(_preview_member(roster[i], i, failed, difficulty))
	result.pick_mvp()
	result.assign_pay()
	_store_result(result)
	_push_result_notice(result)
	return entry.id


func _preview_member(view: MercView, index: int, failed: bool,
		difficulty: float) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = view.uid
	member.name = view.name
	member.tradition = view.tradition
	member.role = ContractResultData.ROLE_LEADER
	if index > 0:
		member.role = RESULT_PREVIEW_ROLES[(index - 1) % RESULT_PREVIEW_ROLES.size()]
	member.fate = ResultMemberData.Fate.ALIVE
	if failed and index == 1:
		member.fate = ResultMemberData.Fate.DEAD
	elif failed and index == 2:
		member.fate = ResultMemberData.Fate.CAPTURED
	var earned: int = RESULT_XP_BASE + int(round(difficulty * float(RESULT_XP_PER_DIFF)))
	if failed:
		earned = int(round(float(earned) * float(RESULT_FAIL_XP_PCT) / 100.0))
	member.xp_gained = earned if member.alive() else 0
	member.xp_need = ExperienceSystem.XP_PER_LEVEL
	member.level_before = view.level
	if index == 0:
		member.xp_before = maxi(0, member.xp_need - member.xp_gained)
	member.level_after = member.level_before + \
		int(floor(float(member.xp_before + member.xp_gained) / float(member.xp_need)))
	var hp_bar: Vector2i = _preview_bar(view.hp_max)
	var ep_bar: Vector2i = _preview_bar(view.ep_max)
	var mp_bar: Vector2i = _preview_bar(view.mp_max)
	member.hp = Vector2i(hp_bar.x, view.hp_max)
	if member.fate == ResultMemberData.Fate.DEAD:
		member.hp = Vector2i(0, view.hp_max)
	member.ep = Vector2i(ep_bar.x, view.ep_max)
	member.mp = Vector2i(mp_bar.x, view.mp_max)
	member.hp_before = hp_bar.y
	member.ep_before = ep_bar.y
	member.mp_before = mp_bar.y
	return member


#A sample bar: (value at return, value at departure) with the departure value the higher one.
func _preview_bar(maximum: int) -> Vector2i:
	if maximum <= 0:
		return Vector2i.ZERO
	var after: int = maxi(1, int(round(float(maximum) * float(RESULT_PREVIEW_AFTER_PCT) / 100.0)))
	var gap: int = int(round(float(maximum) * float(RESULT_PREVIEW_GAP_PCT) / 100.0))
	return Vector2i(after, mini(maximum, after + maxi(1, gap)))

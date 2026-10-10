extends Node

#The live campaign: the bank, the roster, the contract board and the clock that moves them.
#_ready only builds the clock child and wires the metrics sources, so a harness run is untouched;
#start_new_game is called by the GUI once the harness has declined the launch.
#A dispatch made between 22:00 and 6:00 is queued: the team waits in the tavern and leaves at 6:00.

const START_BANK := 100
const START_MERCS := 2
const START_LEVEL := 1
const LAUNCH_POSTINGS := 1
const START_DIFFICULTY := 1.0
const START_QUALITY := 0.9
const START_FOOT_TRIES := 10
const POSTING_NOTICE_KIND := "Contract"
const SALARY_HOUR := 8
const WISH_HOUR := 8
const CLOCK_NAME := "ClockRunner"
const QUEUED_TAG := "queued in the tavern"
const DEFAULT_EXTRAS: Dictionary = {"level_mode": "Auto"}
#Board states the contract list always shows; the rest are closed.
const LISTED_STATUSES: Array[String] = [BoardEntry.STATUS_DRAFT, BoardEntry.STATUS_ACTIVE]
#Closed states; each one stays on the list until the calendar month its closed_minute falls in ends.
const CLOSED_STATUSES: Array[String] = [BoardEntry.STATUS_SUCCEEDED, BoardEntry.STATUS_FAILED,
	BoardEntry.STATUS_EXPIRED, BoardEntry.STATUS_REJECTED]
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
const REASON_GUILD: String = "guild"
const REASON_SUBSCRIPTION: String = "subscription"
const REASON_UPGRADE: String = "upgrade"
const REASON_ADS: String = "ads"
const REASON_BAZAAR: String = "bazaar"
const REASON_LEGAL: String = "legal"
const REASON_FINE: String = "fine"
const REASON_BAIL: String = "bail"
const REASON_PERMIT: String = "permit"
const REASON_HIRING: String = "hiring"
const REASON_HIRE: String = "hire"
const REASON_BENEFIT: String = "benefit"
const REASON_BONUS: String = "bonus"
const REASON_MAIL: String = "mail"
#A credit carrying one of these reasons is income, so it never lowers the day's expenses.
const INCOME_REASONS: Array[String] = [REASON_LOAN, REASON_STOCK, REASON_DIVIDEND, REASON_MAIL]
#Ledger texts GameState writes itself; every other label comes from the caller.
const LABEL_PAYROLL: String = "Payroll"
const LABEL_REWARD: String = "%s - Reward"
const LABEL_BONUS: String = "%s - Merc Bonus"
const LABEL_TRAVEL: String = "Travel - %s (x%d)"
#The removed queue reason for a merc who switched sides on a contract.
const REMOVED_DEFECTED: String = "defected"
#The autoloads that take a tick each time the clock moves, in the order they run.
const TICK_ORDER: Array[String] = ["FinanceManager", "FinanceLedger", "BenefitsManager",
	"StockMarket", "LegalManager", "PromotionsManager", "BazaarManager", "MailCenter"]
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
signal time_hold_changed(held: bool)
#A lock or an upsell asking for the Plans screen; target names the page and the row to open on.
signal go_to_plans_requested(target: Dictionary)
signal pip_modes_changed
#Promotions handing one campaign's applicants to the Hiring tab.
signal open_hiring_requested(campaign_id: int)
#Promotions handing one campaign's contracts to the Contracts window.
signal open_contracts_requested(campaign_id: int)
#A View in Calendar link asking the calendar to open on that day index.
signal open_calendar_requested(day: int)
#The HUD money counter asked to fly a change the bank has already taken.
signal money_fly_requested(amount: int)
#The same fly when it should be heard; a result opened again flies in silence.
signal money_fly_cued(amount: int)
#One posting settled and its result is waiting to be opened.
signal results_recorded(entry_id: int)
signal results_seen(entry_id: int)
#A team was sent out, or queued at night to leave at 6:00.
signal dispatched(run: ActiveRun)
signal contracts_posted(count: int)
signal contract_rejected(entry_id: int)
#One merc left the guild or came back to it (the away registry).
signal away_changed(uid: int)
#A new campaign is fully set up; the per-campaign managers reset on it.
signal game_started
#roster, captives and contracts were rebuilt; it fires on every clock step as well as on a change.
signal views_refreshed

var bank_notes: int = START_BANK
var mercs: Array[MercenaryData] = []
var roster: Array[MercView] = []
#The captives' views, kept off roster; only the roster list shows them, when its filter asks.
var captives: Array[MercView] = []
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
#The contract filter the Contracts window picks up once; {} while nothing has asked for one.
var contract_filter: Dictionary = {}
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
#The travel mode and distance of the money movement being logged, for FinanceLedger to stamp on its
#row; empty outside a travel charge or refund.
var logged_mode: String = ""
var logged_km: int = 0
var _day_contracts: Dictionary = {}
var _dead_counted: int = 0

#Above zero while the clock settles time; money moved then is a clock deduction and plays no cue.
var _clock_depth: int = 0
#Every draw of the daily contract round; seed_round pins it for a test.
var _round_rng: RandomNumberGenerator = RandomNumberGenerator.new()
#The day a new game started on; its 8:00 round is skipped (the opening board stands in for it).
var _start_day: int = -1


func _ready() -> void:
	clock = ClockRunner.new()
	clock.name = CLOCK_NAME
	clock.processor = process_until
	add_child(clock)
	clock.day_changed.connect(_on_clock_day)
	clock.month_changed.connect(_on_clock_month)
	clock.speed_changed.connect(speed_changed.emit)
	clock.hold_changed.connect(time_hold_changed.emit)
	day_changed.connect(MetricsHistory.record_day)
	MetricsHistory.merc_source = _merc_metrics
	MetricsHistory.contract_source = _contract_metrics
	MetricsHistory.guild_source = _guild_metrics
	SubscriptionManager.changed.connect(prune_pip_modes)


#A fresh guild: START_MERCS level 1 mercs hired in order and the opening board, both dated to the start minute.
func start_new_game() -> void:
	ContractResourceBuilder.build_all()
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)
	_round_rng.randomize()
	_start_day = day()
	mercs.clear()
	roster.clear()
	captives.clear()
	contracts.clear()
	merc_extras.clear()
	pip_modes.clear()
	hire_filter.clear()
	contract_filter.clear()
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
	GuildRecord.reset()
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	var previous_level: int = MercGenerator.forced_level
	for i: int in range(START_MERCS):
		MercGenerator.forced_level = START_LEVEL
		var merc: MercenaryData = MercGenerator.generate(i)
		MercGenerator.forced_level = previous_level
		hire(merc)
	GuildRoster.set_roster(mercs)
	BeauSystem.set_roster(mercs)
	SubscriptionManager.reset()
	SubscriptionManager.apply_harness_flag()
	board = ContractBoard.new()
	_launch_opening_board(CampaignClock.now())
	NotificationCenter.reset()
	started = true
	refresh_views()
	game_started.emit()
	if _expire_postings(CampaignClock.now()):
		refresh_views()
		contracts_changed.emit()


#The opening posting at START_DIFFICULTY and START_QUALITY, redrawn up to START_FOOT_TRIES times until foot reaches it.
func _launch_opening_board(now: int) -> void:
	var previous: float = ContractGenerator.forced_difficulty
	ContractGenerator.forced_difficulty = START_DIFFICULTY
	for _try: int in range(START_FOOT_TRIES):
		board.launch(now, LAUNCH_POSTINGS)
		if board.entries.is_empty() or Reachability.can_reach(board.entries[0], Reachability.FOOT, now):
			break
	ContractGenerator.forced_difficulty = previous
	for entry: BoardEntry in board.entries:
		entry.quality = START_QUALITY


#Signs one merc on at the current minute; their wage and opening opinion are fixed here.
func hire(merc: MercenaryData) -> void:
	if merc == null:
		return
	var earlier: Array[MercenaryData] = []
	earlier.assign(mercs)
	SalarySystem.hire(merc, earlier, CampaignClock.now())
	merc.idle_since_minute = CampaignClock.now()
	mercs.append(merc)
	merc_extras[merc.merc_uid] = DEFAULT_EXTRAS.duplicate(true)
	GuildRoster.set_roster(mercs)
	refresh_views()
	roster_changed.emit()


#Pins the daily contract round's draws.
func seed_round(seed_value: int) -> void:
	_round_rng.seed = seed_value


#True while the clock settles time: inside process_until and while the day and month signals run.
func clock_moving() -> bool:
	return _clock_depth > 0


#Moves the campaign to a minute, settling everything due on the way in order (11.2). A tick may
#jump over several due moments, so the earliest is fired one at a time until none is left.
#The clock depth covers each synchronous step and is never held across a scheduler await.
func process_until(target: int) -> void:
	var contracts_dirty: bool = false
	var roster_dirty: bool = false
	var start_month: Dictionary = TrynnCalendar.date_of(CampaignClock.now())
	while true:
		var now: int = CampaignClock.now()
		var salary_at: int = _next_salary_minute(now)
		var expiry_at: int = board.next_expiry_minute(now) if board != null else -1
		var warn_at: int = _next_warning_minute(now)
		var refill_at: int = board.next_refill_minute(now) if board != null else -1
		var depart_at: int = _next_depart_minute(now)
		var wish_at: int = _next_wish_minute(now)
		var due: int = -1
		due = _earliest(due, salary_at, target)
		due = _earliest(due, expiry_at, target)
		due = _earliest(due, warn_at, target)
		due = _earliest(due, refill_at, target)
		due = _earliest(due, depart_at, target)
		due = _earliest(due, wish_at, target)
		for entry: BoardEntry in _active_entries():
			due = _earliest(due, entry.scheduler.next_due(), target)
		if due < 0:
			break
		_clock_depth += 1
		CampaignClock.advance_to(due)
		if salary_at == due:
			_debit_salaries()
		if wish_at == due:
			BenefitsManager.tick(due)
			BenefitsManager.book.roll_wishes(due)
		if _expire_postings(due):
			contracts_dirty = true
		if board != null and refill_at == due and day() != _start_day:
			var posted: int = int(DailyContractRound.run(board, due, _round_rng)["provisioned"])
			if posted > 0:
				contracts_dirty = true
				contracts_posted.emit(posted)
				_note_postings(posted, due)
			PromotionsManager.hire_round(due)
		if depart_at == due:
			BenefitsManager.tick(due)
			_depart_queued(due)
			contracts_dirty = true
			roster_dirty = true
		if (refill_at == due or depart_at == due) and _expire_postings(due):
			contracts_dirty = true
		_clock_depth -= 1
		for entry: BoardEntry in _active_entries():
			if entry.scheduler.next_due() != due:
				continue
			await entry.scheduler.step()
			contracts_dirty = true
			roster_dirty = true
			if entry.scheduler.is_done():
				_clock_depth += 1
				_settle(entry)
				_clock_depth -= 1
	_clock_depth += 1
	CampaignClock.advance_to(target)
	if _clear_returned_away(CampaignClock.now()):
		roster_dirty = true
	_tick_managers(CampaignClock.now())
	NotificationCenter.escalate(CampaignClock.now())
	if not RestSystem.complete_due_rests(mercs, target).is_empty():
		roster_dirty = true
	if not BenefitsManager.book.furlough_lines.is_empty():
		roster_dirty = true
	BenefitsManager.book.furlough_lines.clear()
	_clock_depth -= 1
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
		var returned: int = int((_away[uid] as Dictionary)["until"])
		_away.erase(uid)
		RestSystem.idle_restart(merc_by_uid(uid), returned)
		away_changed.emit(uid)
	return true


#Hands the new minute to every manager that keeps its own timed events, in TICK_ORDER; a manager
#without a tick and one this build does not carry are both skipped.
func _tick_managers(now: int) -> void:
	for manager: String in TICK_ORDER:
		var node: Node = get_node_or_null(tick_root + manager)
		if node != null and node.has_method(TICK_METHOD):
			node.call(TICK_METHOD, now)


#The clock's day and month signals reach their listeners inside clock_moving(): their bills are clock deductions.
func _on_clock_day(day_index: int) -> void:
	_clock_depth += 1
	day_changed.emit(day_index)
	_clock_depth -= 1


func _on_clock_month(year: int, month: int) -> void:
	_clock_depth += 1
	month_changed.emit(year, month)
	_clock_depth -= 1


#Calls on_day for each day after last_day up to the day of now and returns the new last day; under zero only records today.
func for_each_new_day(last_day: int, now: int, on_day: Callable) -> int:
	var today: int = TrynnCalendar.day_index(now)
	if last_day < 0:
		return today
	while last_day < today:
		last_day += 1
		on_day.call(last_day)
	return last_day


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
	if not _dispatch_allowed(entry, run, now):
		return false
	if ContractScheduler.is_night_minute(now):
		return _queue_dispatch(entry, run, now)
	var scheduler: ContractScheduler = board.activate(entry_id, team,
		travel_minutes(run.travel_mode, entry.distance_km), now, _line_sink(entry), run.leader_uid(), run.travel_mode,
		run_roles(run))
	if scheduler == null:
		return false
	_travel_money(run, entry.distance_km, false)
	run.dispatched_minute = now
	run.depart_minute = now
	run.entry_id = entry_id
	active_contracts[entry_id] = run
	_snap_departure(entry_id, team)
	refresh_views()
	contracts_changed.emit()
	dispatched.emit(run)
	return true


#The venture must make the deadline, in the red both legs walk, and each paid leg must fit the bank left when it is paid.
func _dispatch_allowed(entry: BoardEntry, run: ActiveRun, now: int) -> bool:
	if not Reachability.can_reach(entry, run.travel_mode, now):
		return false
	if is_in_red() and (run.travel_mode != Reachability.FOOT or run.return_mode != Reachability.FOOT):
		return false
	var venture: int = DispatchLogic.travel_cost(GuiTypes.travel_mode(run.travel_mode), run.uids().size(),
		maxi(1, entry.merc_min), entry.distance_km)
	var out_cost: int = clampi(venture, 0, run.travel_cost)
	var back_cost: int = run.travel_cost - out_cost
	return Reachability.fare_ok(run.travel_mode, out_cost, bank_notes) \
		and Reachability.fare_ok(run.return_mode, back_cost, bank_notes - out_cost)


#Calls a queued dispatch off before 6:00: the travel money comes back and the posting reopens.
#A team already on the road cannot be called back this way.
func cancel_dispatch(entry_id: int) -> bool:
	if not queued.has(entry_id):
		return false
	var entry: BoardEntry = board.entry(entry_id) if board != null else null
	_call_off_queued(entry_id, entry, queued[entry_id] as ActiveRun, -1)
	refresh_views()
	contracts_changed.emit()
	roster_changed.emit()
	return true


#Turns a posting down; it stays listed as Rejected until the month ends and a dearer copy goes back to the pool.
func reject(entry_id: int) -> bool:
	if board == null:
		return false
	var entry: BoardEntry = board.entry(entry_id)
	if not board.reject(entry_id):
		return false
	if entry != null:
		var face: int = IssuerOpinion.face(entry.issuer_id) if entry.issuer_id >= 0 else 0
		if entry.issuer_id >= 0:
			IssuerOpinion.on_reject(entry.issuer_id)
		board.pool.return_rejected(entry, face, CampaignClock.now())
	refresh_views()
	contracts_changed.emit()
	contract_rejected.emit(entry_id)
	return true


#Erases a posting a dispatch could not take; nothing was charged, so nothing comes back.
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


#Test hook: the level-up preference the Merc Viewer stores per merc; unknown modes are ignored.
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


func hold_time(holder: Object) -> void:
	if clock != null:
		clock.hold(holder)


func release_time(holder: Object) -> void:
	if clock != null:
		clock.release(holder)


func is_time_held() -> bool:
	return clock != null and clock.is_held()


#What the merc is doing, how long is left of it and the fraction of its span left (-1 = unknown), for
#the roster list (GuiTypes.MercStatus).
func merc_status(merc: MercenaryData) -> Dictionary:
	if merc == null:
		return _status_row(GuiTypes.MercStatus.AVAILABLE, 0.0, -1.0)
	var now: int = CampaignClock.now()
	if merc.is_dead:
		return _status_row(GuiTypes.MercStatus.DEAD, 0.0, -1.0)
	if SalarySystem.is_captive(merc):
		return _status_row(GuiTypes.MercStatus.CAPTURED, 0.0, -1.0)
	var sent: int = away_status(merc.merc_uid)
	if sent >= 0:
		var ends: int = away_until(merc.merc_uid)
		return _status_row(sent, _hours(ends - now) if ends >= 0 else 0.0, -1.0)
	if merc.missing_since >= 0:
		return _status_row(GuiTypes.MercStatus.MISSING, 0.0, _missing_fraction(merc, now))
	var waiting: ActiveRun = _queued_run_of(merc.merc_uid)
	if waiting != null:
		return _status_row(GuiTypes.MercStatus.PREPARING, _hours(waiting.depart_minute - now),
			_span_fraction(waiting.dispatched_minute, waiting.depart_minute, now))
	if merc.on_contract:
		var entry: BoardEntry = _entry_of(merc)
		var due: int = entry.scheduler.next_minute if entry != null else now
		return _status_row(GuiTypes.MercStatus.CONTRACT, _hours(due - now),
			_contract_fraction(entry, now))
	if RestSystem.is_resting(merc):
		var kind: int = GuiTypes.MercStatus.RESTING
		if merc.rest_lockout_kind == RestSystem.KIND_FURLOUGH or merc.rest_lockout_kind == RestSystem.KIND_VACATION:
			kind = GuiTypes.MercStatus.VACATION
		return _status_row(kind, _hours(merc.rest_lockout_until - now),
			_span_fraction(merc.rest_lockout_start, merc.rest_lockout_until, now))
	return _status_row(GuiTypes.MercStatus.AVAILABLE, 0.0, -1.0)


func _status_row(status: int, hours_left: float, fraction: float) -> Dictionary:
	return {"status": status, "hours_left": hours_left, "fraction": fraction}


#The share of start..end still ahead of now, 0..1; -1 when the span is unknown or empty.
func _span_fraction(start: int, end: int, now: int) -> float:
	if start < 0 or end <= start:
		return -1.0
	return clampf(float(end - now) / float(end - start), 0.0, 1.0)


#The contract span runs from departure (else dispatch) to the run's return minute, as the payday reads it.
func _contract_fraction(entry: BoardEntry, now: int) -> float:
	if entry == null:
		return -1.0
	var run: ActiveRun = active_contracts.get(entry.id) as ActiveRun
	if run == null or run.hours <= 0.0:
		return -1.0
	var start: int = run.depart_minute if run.depart_minute >= 0 else run.dispatched_minute
	return _span_fraction(start, run.return_minute(), now)


#Missing runs out over as long again as the merc served before going missing, at least a day.
func _missing_fraction(merc: MercenaryData, now: int) -> float:
	if merc.hired_minute < 0:
		return -1.0
	var tenure: int = maxi(merc.missing_since - merc.hired_minute, CampaignClock.MINUTES_PER_DAY)
	return clampf(1.0 - float(now - merc.missing_since) / float(tenure), 0.0, 1.0)


#Everyone who cannot be sent anywhere right now.
func busy_uids() -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in mercs:
		if merc == null:
			continue
		if merc.on_contract or merc.missing_since >= 0 or not RestSystem.is_deployable(merc):
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
	RestSystem.idle_break(merc_by_uid(uid))
	refresh_views()
	roster_changed.emit()
	away_changed.emit(uid)
	return true


func clear_away(uid: int) -> void:
	if not _away.has(uid):
		return
	_away.erase(uid)
	RestSystem.idle_restart(merc_by_uid(uid), CampaignClock.now())
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


#The mercs who switched sides on a contract, kept so a later system can bring them back.
func defectors() -> Array[RemovedMercRecord]:
	var out: Array[RemovedMercRecord] = []
	for record: RemovedMercRecord in removed:
		if record != null and record.reason == REMOVED_DEFECTED:
			out.append(record)
	return out


#Test hook: the record of one removed merc, or null when the guild never lost that uid.
func removed_by_uid(uid: int) -> RemovedMercRecord:
	for record: RemovedMercRecord in removed:
		if record != null and record.uid == uid:
			return record
	return null


#Test hook.
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


#The roster view of a merc, or null when no roster view carries that uid.
func view_by_uid(uid: int) -> MercView:
	return MercView.by_uid(roster, uid)


#The uid of every merc on the roster, in roster order.
func roster_uids() -> Array[int]:
	var out: Array[int] = []
	for view: MercView in roster:
		if view != null:
			out.append(view.uid)
	return out


#Rebuilds the two view lists the screens read; the dead and the captive are hidden for now.
func refresh_views() -> void:
	var now: int = CampaignClock.now()
	roster.clear()
	captives.clear()
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead:
			continue
		var state: Dictionary = merc_status(merc)
		var view: MercView = MercView.from_merc(merc, int(state["status"]), float(state["hours_left"]),
			employment_months(merc), _extras_for(merc))
		view.status_fraction_left = float(state["fraction"])
		if SalarySystem.is_captive(merc):
			captives.append(view)
		else:
			roster.append(view)
	contracts.clear()
	if board != null:
		for entry: BoardEntry in board.entries:
			if _is_listed(entry, now):
				contracts.append(ContractView.from_entry(entry, now))
	views_refreshed.emit()


#Open and active postings always list; a closed one lists until its month ends.
#A closed entry with no close stamp drops out at once.
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


#The run's dispatch roles, merc_uid to role; empty slots and blank roles are left out.
func run_roles(run: ActiveRun) -> Dictionary:
	var out: Dictionary = {}
	for member: TeamMember in run.team:
		if member == null or member.merc_uid == 0 or member.role == "":
			continue
		out[member.merc_uid] = member.role
	return out


#Minutes on the road for a travel mode over a distance; an unknown mode falls back to the
#scheduler's own travel figure and a mode with no daily range arrives at once.
func travel_minutes(mode_key: String, distance_km: int) -> int:
	return Reachability.base_minutes(mode_key, distance_km)


#True when the contract's start location holds an active teleport permit; false for no contract or an unknown place.
func tele_permit_for(entry: BoardEntry) -> bool:
	if entry == null or entry.contract == null:
		return false
	var index: int = ClientRegistry.LOCATIONS.find(entry.contract.location_a)
	if index < 0:
		return false
	return LegalManager.permit_state(index, LegalManager.PERMIT_TELE) == LegalManager.STATE_ACTIVE


#Charges a run's fare, or hands it back, with its mode and distance stamped on the ledger row.
func _travel_money(run: ActiveRun, km: int, back: bool) -> void:
	logged_mode = run.travel_mode
	logged_km = km
	if back:
		refund(run.travel_cost, REASON_TRAVEL_REFUND, _travel_label(run))
	else:
		_spend(run.travel_cost, REASON_TRAVEL, _travel_label(run))
	logged_mode = ""
	logged_km = 0


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


#The daily vacation wish roll (Mail plan 3.6): the next WISH_HOUR strictly after this minute.
func _next_wish_minute(now: int) -> int:
	return ContractScheduler.next_hour_after(now, WISH_HOUR)


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
	if not Reachability.can_reach(entry, run.travel_mode, now):
		return false
	run.dispatched_minute = now
	run.entry_id = entry.id
	run.depart_minute = ContractScheduler.next_wake_minute(now)
	entry.log_lines.clear()
	entry.log_lines.append(_queued_line(now, run.depart_minute))
	entry.verdict = ""
	set_entry_status(entry, BoardEntry.STATUS_ACTIVE)
	_travel_money(run, entry.distance_km, false)
	active_contracts[entry.id] = run
	queued[entry.id] = run
	refresh_views()
	contracts_changed.emit()
	roster_changed.emit()
	dispatched.emit(run)
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


#The soonest minute after now that an unwarned bounded posting enters its last day; -1 when none is waiting.
func _next_warning_minute(now: int) -> int:
	if board == null:
		return -1
	var soonest: int = -1
	for entry: BoardEntry in board.entries:
		if not entry.is_open() or entry.reach_warned or entry.deadline_minute <= 0:
			continue
		var at: int = Reachability.warning_minute(entry.expires_minute)
		if at > now and (soonest < 0 or at < soonest):
			soonest = at
	return soonest


#Sweeps reach, then closes every posting whose time ran out with an expired notice; true when the board changed.
func _expire_postings(now: int) -> bool:
	if board == null:
		return false
	var moved: bool = _sweep_reach(now)
	var gone: Array[BoardEntry] = board.expire_due(now)
	for entry: BoardEntry in gone:
		NotificationCenter.push(NotificationData.TYPE_EXPIRED, entry.id, _posting_snap(entry),
			NotificationData.Urgency.INFORMATIONAL, POSTING_NOTICE_KIND)
	return moved or not gone.is_empty()


#Pulls each bounded open posting in to the last minute its best affordable mode makes the deadline, or to now
#when no mode does, and warns once inside the last day; true when an expiry moved.
func _sweep_reach(now: int) -> bool:
	var moved: bool = false
	for entry: BoardEntry in board.entries:
		if not entry.is_open() or entry.deadline_minute <= 0:
			continue
		var best: String = Reachability.best_mode(entry, now, bank_notes, tele_permit_for(entry),
			maxi(1, entry.merc_min))
		entry.best_mode = best
		var expires: int = now
		if best != "":
			var modes: Array[String] = [best]
			expires = mini(entry.expires_minute, Reachability.auto_reject_minute(entry, modes, now))
		if expires != entry.expires_minute:
			entry.expires_minute = expires
			moved = true
		if entry.reach_warned or entry.expires_minute <= now:
			continue
		if entry.expires_minute - now <= Reachability.WARNING_MINUTES:
			entry.reach_warned = true
			NotificationCenter.push(NotificationData.TYPE_EXPIRY_WARNING, entry.id, _posting_snap(entry),
				NotificationData.Urgency.IMPORTANT, POSTING_NOTICE_KIND)
	return moved


#The bell snap of a posting: the name, difficulty and reward keys a result notice carries.
func _posting_snap(entry: BoardEntry) -> Dictionary:
	var snap: Dictionary = {"name": entry_name(entry), "difficulty": 0.0, "reward": 0}
	if entry.contract != null:
		snap["difficulty"] = entry.contract.difficulty
		snap["reward"] = entry.contract.reward_notes
	return snap


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
			BenefitsManager.book.release_held(run.uids(), due)
			queued.erase(id)
			active_contracts.erase(id)
			continue
		var team: Array[MercenaryData] = []
		for uid: int in run.uids():
			var merc: MercenaryData = merc_by_uid(uid)
			if merc != null and not merc.is_dead:
				team.append(merc)
		if team.is_empty():
			_call_off_queued(id, entry, run, due)
			continue
		var held: String = entry.log_lines[0] if not entry.log_lines.is_empty() else ""
		entry.status = BoardEntry.STATUS_DRAFT
		var scheduler: ContractScheduler = board.activate(id, team,
			travel_minutes(run.travel_mode, entry.distance_km), due, _line_sink(entry), run.leader_uid(),
			run.travel_mode, run_roles(run))
		if scheduler == null:
			_call_off_queued(id, entry, run, due)
			continue
		if held != "":
			entry.log_lines.insert(0, held)
		_snap_departure(id, team)
		queued.erase(id)


#Calls a queued dispatch off: the money comes back and the posting reopens; due -1 logs no called-off line.
func _call_off_queued(entry_id: int, entry: BoardEntry, run: ActiveRun, due: int) -> void:
	if run != null:
		_travel_money(run, entry.distance_km if entry != null else 0, true)
		BenefitsManager.book.release_held(run.uids(), CampaignClock.now() if due < 0 else due)
	if entry != null:
		set_entry_status(entry, BoardEntry.STATUS_DRAFT)
		entry.log_lines.clear()
		if due >= 0:
			entry.log_lines.append("%s CALLED OFF: nobody left to send" % CampaignClock.stamp(due))
	queued.erase(entry_id)
	active_contracts.erase(entry_id)
	_expire_postings(CampaignClock.now())


#The queue entry and its contract always carry the same status.
func set_entry_status(entry: BoardEntry, status: String) -> void:
	entry.status = status
	if entry.contract != null:
		entry.contract.status = status


#True while the merc waits in a queued dispatch that has not departed (N63).
func is_queued(uid: int) -> bool:
	return _queued_run_of(uid) != null


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


#Closes a finished run: the board decides the posting's fate; a success banks the reward (G13), then pays the merc bonus.
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
			money_logged.emit(run.reward_paid, REASON_CONTRACT, LABEL_REWARD % entry_name(entry))
		_record_standing(entry, run.verdict, CampaignClock.now())
		_record_result(entry, run, sent, BenefitsManager.per_contract)
		_fail_stress(result_of(entry.id))
		_spend(result_of(entry.id).bonus(), REASON_BONUS, LABEL_BONUS % entry_name(entry))
		_accrue_bonus_owed(result_of(entry.id))
	active_contracts.erase(entry.id)
	_departure.erase(entry.id)
	if run != null:
		_remove_defectors(result_of(entry.id))
		_roll_returned(result_of(entry.id))


#Each ALIVE member of a failed contract takes the failed-contract stress (Mail plan 3.6).
func _fail_stress(result: ContractResultData) -> void:
	if result == null or not result.failed:
		return
	for member: ResultMemberData in result.living():
		var merc: MercenaryData = merc_by_uid(member.uid)
		if merc != null:
			VacationDesire.on_failed_contract(merc)


#The returned team rolls its vacation wishes at once; an empty team would roll the whole guild, so it is skipped.
func _roll_returned(result: ContractResultData) -> void:
	if result == null:
		return
	var team: Array[MercenaryData] = []
	for member: ResultMemberData in result.living():
		if merc_by_uid(member.uid) != null:
			team.append(merc_by_uid(member.uid))
	if not team.is_empty():
		BenefitsManager.book.roll_wishes(CampaignClock.now(), team)


#A settled verdict feeds the guild record and the issuer's opinion, judged on the bank after the reward lands.
func _record_standing(entry: BoardEntry, verdict: String, now: int) -> void:
	var won: bool = verdict == BoardEntry.STATUS_SUCCEEDED
	if not won and verdict != BoardEntry.STATUS_FAILED:
		return
	GuildRecord.guild.record(won, now)
	if entry.issuer_id < 0:
		return
	if won:
		IssuerOpinion.on_success(entry.issuer_id, now, is_in_red())
	else:
		IssuerOpinion.on_fail(entry.issuer_id, now)


#A defector leaves the roster once the result rows exist; their record joins the defector pool.
func _remove_defectors(result: ContractResultData) -> void:
	if result == null:
		return
	for member: ResultMemberData in result.members:
		if member != null and member.forfeits() and merc_by_uid(member.uid) != null:
			remove_merc(member.uid, REMOVED_DEFECTED, GuiTypes.MercStatus.FIRED)


#An away member's bonus share waits on the merc, like a captive's backpay: no bank move, no ledger row.
func _accrue_bonus_owed(result: ContractResultData) -> void:
	for member: ResultMemberData in result.members:
		if member == null or member.owed <= 0:
			continue
		var merc: MercenaryData = merc_by_uid(member.uid)
		if merc != null:
			merc.bonus_owed += member.owed


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
func refund(amount: int, reason: String = "", label: String = "") -> void:
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
		#The live portfolio metric does not read the StockMarket holdings, so it stays flat at 0.
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


#Opens the Contracts window filtered to the postings one Guild Ads campaign brought in.
func open_contracts(campaign_id: int) -> void:
	contract_filter = {"campaign": campaign_id}
	open_contracts_requested.emit(campaign_id)


#Opens the calendar on that day index (a View in Calendar link).
func open_calendar(on_day: int) -> void:
	open_calendar_requested.emit(on_day)


#Hands the stored contract filter over once; the next caller gets nothing.
func take_contract_filter() -> Dictionary:
	var filter: Dictionary = contract_filter
	contract_filter = {}
	return filter


#Every posting one Guild Ads campaign brought in, in board order, closed and past-month ones included.
func campaign_contracts(campaign_id: int) -> Array[ContractView]:
	var out: Array[ContractView] = []
	if board == null or campaign_id <= 0:
		return out
	var now: int = CampaignClock.now()
	for entry: BoardEntry in board.entries:
		if entry != null and entry.campaign_id == campaign_id:
			out.append(ContractView.from_entry(entry, now))
	return out


#Posts one contract a Guild Ads campaign brought in, tagged with its id and swept at once; quiet skips the new-postings notice.
func post_campaign_contract(contract: ContractData, campaign_id: int, quiet: bool = false) -> BoardEntry:
	if board == null or contract == null:
		return null
	var entry: BoardEntry = board.post(contract, CampaignClock.now())
	entry.campaign_id = campaign_id
	_expire_postings(CampaignClock.now())
	refresh_views()
	contracts_changed.emit()
	if not quiet:
		contracts_posted.emit(1)
		_note_postings(1, CampaignClock.now())
	return entry


#Counts new postings on the bell: one row per day, and the next day's row replaces the last one.
func _note_postings(count: int, minute: int) -> void:
	if count > 0:
		NotificationCenter.add_postings(TrynnCalendar.day_index(minute), count)


#Asks the HUD to fly notes in or out of its counter; spend() or refund() moved them already.
#cue false flies them in silence.
func fly_money(amount: int, cue: bool = true) -> void:
	if amount == 0:
		return
	money_fly_requested.emit(amount)
	if cue:
		money_fly_cued.emit(amount)


func can_afford(amount: int) -> bool:
	return amount <= bank_notes


func is_in_red() -> bool:
	return bank_notes < 0


#Debits the bank when the notes are there; a refusal leaves it untouched.
func spend(amount: int, reason: String = "", label: String = "") -> bool:
	if amount < 0 or amount > bank_notes:
		return false
	_spend(amount, reason, label)
	return true


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


#The posted contract with that board entry id; null when none matches.
func contract_view(entry_id: int) -> ContractView:
	if entry_id < 0:
		return null
	for view: ContractView in contracts:
		if view != null and view.entry_id == entry_id:
			return view
	return null


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
	NotificationCenter.read_contract(entry_id)
	results_seen.emit(entry_id)
	contracts_changed.emit()
	return true


#What each merc looked like when the team left, so the result can show the change.
func _snap_departure(entry_id: int, team: Array[MercenaryData]) -> void:
	var rows: Dictionary = {}
	for merc: MercenaryData in team:
		if merc == null:
			continue
		var top: Vector3i = _max_stats(merc)
		rows[merc.merc_uid] = {
			"hp": merc.current_hp,
			"ep": merc.current_ep,
			"mp": merc.current_mp,
			"hp_max": top.x,
			"ep_max": top.y,
			"mp_max": top.z,
			"xp": merc.xp,
			"level": ExperienceSystem.current_level(merc),
		}
	_departure[entry_id] = rows


#Builds the result of a settled posting at the bonus percent settlement paid.
func _record_result(entry: BoardEntry, run: ContractRun, sent: ActiveRun, pct: int) -> void:
	var failed: bool = entry.status == BoardEntry.STATUS_FAILED
	var result := ContractResultData.from_entry(entry, entry_name(entry), failed, run.reward_paid,
		sent.travel_cost if sent != null else 0, _result_members(entry, run, sent), pct)
	publish_result(result)


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
		for group: Array[MercenaryData] in [run.team, run.casualties, run.kidnapped, run.defectors, run.departed]:
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
	elif run.defectors.has(merc):
		member.fate = ResultMemberData.Fate.DEFECTED
	elif run.departed.has(merc):
		member.fate = ResultMemberData.Fate.DEPARTED
	member.level_after = ExperienceSystem.current_level(merc)
	member.level_before = int(snap.get("level", member.level_after))
	var before_total: int = int(snap.get("xp", merc.xp))
	member.xp_gained = maxi(0, merc.xp - before_total)
	member.xp_need = ExperienceSystem.xp_for_level(member.level_before + 1) - \
		ExperienceSystem.xp_for_level(member.level_before)
	member.xp_before = maxi(0, before_total - ExperienceSystem.xp_for_level(member.level_before))
	var top: Vector3i = _max_stats(merc)
	member.hp = Vector2i(merc.current_hp, top.x)
	member.ep = Vector2i(merc.current_ep, top.y)
	member.mp = Vector2i(merc.current_mp, top.z)
	member.hp_before = int(snap.get("hp", member.hp.x))
	member.ep_before = int(snap.get("ep", member.ep.x))
	member.mp_before = int(snap.get("mp", member.mp.x))
	return member


#The merc's HP, EP and MP maximums as x, y and z.
static func _max_stats(merc: MercenaryData) -> Vector3i:
	return Vector3i(int(merc.stats.get("maximum_hit_points", 0)),
		int(merc.stats.get("maximum_endurance_points", 0)),
		int(merc.stats.get("maximum_magic_points", 0)))


#Stores a result and rings the bell for it.
func publish_result(result: ContractResultData) -> void:
	_store_result(result)
	_push_result_notice(result)


func _store_result(result: ContractResultData) -> void:
	results[result.entry_id] = result
	seen_results.erase(result.entry_id)
	results_recorded.emit(result.entry_id)


#One row on the bell per settled posting. The snap never names the outcome, only the posting.
func _push_result_notice(result: ContractResultData) -> void:
	var notice_type: StringName = NotificationData.TYPE_CONTRACT_COMPLETED
	if result.failed:
		notice_type = NotificationData.TYPE_CONTRACT_FAILED
	var snap: Dictionary = {
		"name": result.name,
		"difficulty": result.difficulty,
		"reward": result.listed_reward,
	}
	NotificationCenter.push(notice_type, result.entry_id, snap,
		NotificationData.Urgency.INFORMATIONAL, "")


func entry_name(entry: BoardEntry) -> String:
	if entry.contract == null:
		return entry.contract_type()
	return ContractView.posting_title(entry.contract)

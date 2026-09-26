class_name GameStateTests

#GameState launch, the ordered clock processing, the salary debit, dispatch, reject, the night
#dispatch queue and the metrics record. The script is loaded by path so the suite never depends on the autoload registration.
#Run: godot --headless --path . -- --gamestate-tests

const STATE_PATH := "res://Scripts/GUI/Autoloads/GameState.gd"
const START_SEED := 7
const SHIFT := 480
const DAY_CAP := 60
const SALARY_MINUTE_MONTH := 1
const REST_MINUTES := 120
#Minutes from the start minute to 23:00 of the same day, and the hours that wait leaves.
const NIGHT_SHIFT := 900
const QUEUE_HOURS := 7.0


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	await Engine.get_main_loop().process_frame
	_case_launch(res)
	await _case_daily_refill(res)
	await _case_salary_debit(res)
	await _case_relays(res)
	await _case_dispatch(res)
	await _case_reject(res)
	_case_discard(res)
	await _case_night_queue(res)
	await _case_night_cancel(res)
	await _case_night_departs(res)
	_case_rest_status(res)
	await _case_metrics(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GAMESTATE")


#A fresh campaign on a fixed seed, in the tree so the autoload wiring of _ready runs.
static func _state() -> Variant:
	TestFixtures.reset_generator_rolls()
	seed(START_SEED)
	var state: Variant = load(STATE_PATH).new()
	(Engine.get_main_loop() as SceneTree).root.add_child(state)
	state.start_new_game()
	return state


static func _drop(state: Variant) -> void:
	state.set_speed(ClockRunner.Speed.PAUSE)
	(Engine.get_main_loop() as SceneTree).root.remove_child(state)
	state.free()


static func _open_entry(state: Variant) -> BoardEntry:
	var open: Array[BoardEntry] = state.board.available()
	return null if open.is_empty() else open[0]


#An ActiveRun the GUI would hand to dispatch: a walking team and the cost already priced.
static func _active_run(uids: Array[int], cost: int) -> ActiveRun:
	var contract_run := ActiveRun.new()
	contract_run.travel_mode = "foot"
	contract_run.travel_cost = cost
	for uid: int in uids:
		var member := TeamMember.new()
		member.merc_uid = uid
		contract_run.team.append(member)
	return contract_run


static func _case_launch(res: Dictionary) -> void:
	var state: Variant = _state()
	var mercs: Array[MercenaryData] = state.mercs
	TestFixtures.check(res, "launch_merc_count", mercs.size() == 10, "mercs %d" % mercs.size())
	var levels: Array[String] = []
	var order: Array[String] = []
	var wages: Array[String] = []
	for i: int in range(mercs.size()):
		var merc: MercenaryData = mercs[i]
		if ExperienceSystem.current_level(merc) != 1:
			levels.append(merc.merc_name)
		if merc.hire_index != i or merc.hired_minute != TrynnCalendar.START_MINUTE:
			order.append("%s %d@%d" % [merc.merc_name, merc.hire_index, merc.hired_minute])
		if merc.monthly_salary < 1 or merc.guild_opinion < -5 or merc.guild_opinion > 5:
			wages.append("%s %d op %d" % [merc.merc_name, merc.monthly_salary, merc.guild_opinion])
	TestFixtures.check(res, "launch_levels", levels.is_empty(), TestFixtures.detail(levels, 10, "merc"))
	TestFixtures.check(res, "launch_hire_order", order.is_empty(), TestFixtures.detail(order, 10, "merc"))
	TestFixtures.check(res, "launch_wages", wages.is_empty(), TestFixtures.detail(wages, 10, "merc"))
	TestFixtures.check(res, "launch_bank", int(state.bank_notes) == 100, "bank %d" % int(state.bank_notes))
	var entries: int = (state.board.entries as Array[BoardEntry]).size()
	TestFixtures.check(res, "launch_board", entries == ContractLibrary.config().board_target, "entries %d" % entries)
	var views: int = (state.contracts as Array[ContractView]).size()
	TestFixtures.check(res, "launch_contract_views", views == ContractLibrary.config().board_target, "views %d" % views)
	var roster: int = (state.roster as Array[MercView]).size()
	TestFixtures.check(res, "launch_roster_views", roster == 10, "roster %d" % roster)
	TestFixtures.check(res, "launch_started", bool(state.started), "started %s" % str(state.started))
	TestFixtures.check(res, "launch_paused", int(state.clock.speed) == ClockRunner.Speed.PAUSE,
		"speed %d" % int(state.clock.speed))
	TestFixtures.check(res, "launch_minute", CampaignClock.now() == TrynnCalendar.START_MINUTE,
		"now %d" % CampaignClock.now())
	var bad: Array[String] = []
	for view: MercView in (state.roster as Array[MercView]):
		if view.status != GuiTypes.MercStatus.AVAILABLE or view.status_time_left_hours != 0.0:
			bad.append("%s %d %.1f" % [view.name, view.status, view.status_time_left_hours])
		if view.employment_months != 0:
			bad.append("%s months %d" % [view.name, view.employment_months])
	TestFixtures.check(res, "launch_views_available", bad.is_empty(), TestFixtures.detail(bad, 10, "merc"))
	_drop(state)


static func _case_daily_refill(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	state.reject(entry.id)
	var before: int = int(state.bank_notes)
	var open_after_reject: int = (state.board.available() as Array[BoardEntry]).size()
	await state.process_until(TrynnCalendar.START_MINUTE + CampaignClock.MINUTES_PER_DAY)
	var open_now: int = (state.board.available() as Array[BoardEntry]).size()
	TestFixtures.check(res, "refill_rejected", open_after_reject == ContractLibrary.config().board_target - 1,
		"open %d" % open_after_reject)
	TestFixtures.check(res, "refill_topped_up", open_now == ContractLibrary.config().board_target, "open %d" % open_now)
	TestFixtures.check(res, "refill_no_debit", int(state.bank_notes) == before,
		"bank %d was %d" % [int(state.bank_notes), before])
	_drop(state)


static func _case_salary_debit(res: Dictionary) -> void:
	var state: Variant = _state()
	var debit_minute: int = TrynnCalendar.first_weekday_minute(TrynnCalendar.START_YEAR,
		SALARY_MINUTE_MONTH, 8)
	await state.process_until(debit_minute - 1)
	TestFixtures.check(res, "debit_none_before", int(state.bank_notes) == 100,
		"bank %d at %d" % [int(state.bank_notes), CampaignClock.now()])
	var entry: BoardEntry = _open_entry(state)
	if entry != null:
		state.reject(entry.id)
	var open_at_debit: Array[int] = []
	var watcher: Callable = func(_notes: int) -> void:
		open_at_debit.append((state.board.available() as Array[BoardEntry]).size())
	state.money_changed.connect(watcher)
	var expected: int = SalarySystem.month_expenses(state.mercs)
	var before: int = int(state.bank_notes)
	await state.process_until(debit_minute)
	state.money_changed.disconnect(watcher)
	TestFixtures.check(res, "debit_amount", int(state.bank_notes) == before - expected,
		"bank %d expected %d" % [int(state.bank_notes), before - expected])
	TestFixtures.check(res, "debit_once", open_at_debit.size() == 1, "money_changed %d" % open_at_debit.size())
	var open_now: int = (state.board.available() as Array[BoardEntry]).size()
	var ordered: bool = not open_at_debit.is_empty() and open_at_debit[0] < ContractLibrary.config().board_target \
		and open_now == ContractLibrary.config().board_target
	TestFixtures.check(res, "debit_before_refill", ordered,
		"open at debit %s after %d" % [str(open_at_debit), open_now])
	var held: int = int(state.bank_notes)
	await state.process_until(debit_minute + CampaignClock.MINUTES_PER_HOUR)
	TestFixtures.check(res, "debit_not_twice", int(state.bank_notes) == held,
		"bank %d was %d" % [int(state.bank_notes), held])
	_drop(state)


static func _case_relays(res: Dictionary) -> void:
	var state: Variant = _state()
	var days: Array[int] = []
	var months: Array[String] = []
	state.day_changed.connect(func(day_index: int) -> void: days.append(day_index))
	state.month_changed.connect(func(year: int, month: int) -> void: months.append("%d/%d" % [year, month]))
	state.set_speed(ClockRunner.Speed.VERY_FAST)
	await state.clock.tick()
	TestFixtures.check(res, "relay_no_day_yet", days.is_empty(), "days %s" % str(days))
	await state.clock.tick()
	var today: int = TrynnCalendar.day_index(CampaignClock.now())
	TestFixtures.check(res, "relay_day", days.size() == 1 and days[0] == today, "days %s" % str(days))
	var month_start: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, SALARY_MINUTE_MONTH)
	await state.process_until(month_start - SHIFT)
	await state.clock.tick()
	var month_day: int = int(month_start / float(CampaignClock.MINUTES_PER_DAY))
	TestFixtures.check(res, "relay_month_day", days.size() == 2 and days[1] == month_day,
		"days %s" % str(days))
	TestFixtures.check(res, "relay_month", months.size() == 1 and months[0] == "301/1", "months %s" % str(months))
	_drop(state)


static func _case_dispatch(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid, mercs[1].merc_uid]
	var contract_run: ActiveRun = _active_run(uids, 10)
	var before: int = int(state.bank_notes)
	var sent: bool = state.dispatch(entry.id, contract_run)
	TestFixtures.check(res, "dispatch_sent", sent, "dispatch returned %s" % str(sent))
	TestFixtures.check(res, "dispatch_cost", int(state.bank_notes) == before - 10,
		"bank %d was %d" % [int(state.bank_notes), before])
	TestFixtures.check(res, "dispatch_active", entry.status == BoardEntry.STATUS_ACTIVE,
		"status %s" % entry.status)
	var busy: Array[int] = state.busy_uids()
	TestFixtures.check(res, "dispatch_busy", busy.has(uids[0]) and busy.has(uids[1]), "busy %s" % str(busy))
	var status: Dictionary = state.merc_status(mercs[0])
	TestFixtures.check(res, "dispatch_status", int(status["status"]) == GuiTypes.MercStatus.CONTRACT,
		"status %d hours %.1f" % [int(status["status"]), float(status["hours_left"])])
	TestFixtures.check(res, "dispatch_twice", not state.dispatch(entry.id, _active_run(uids, 10)),
		"the same posting took a second team")
	var other: BoardEntry = _open_entry(state)
	var mixed: Array[int] = [uids[0], mercs[2].merc_uid]
	TestFixtures.check(res, "dispatch_busy_blocked", not state.dispatch(other.id, _active_run(mixed, 10)),
		"a busy merc was sent out again")
	var banked: int = int(state.bank_notes)
	var cap: int = int(float(DAY_CAP * CampaignClock.MINUTES_PER_DAY) / float(SHIFT))
	var steps: int = 0
	while entry.status == BoardEntry.STATUS_ACTIVE and steps < cap:
		await state.process_until(CampaignClock.now() + SHIFT)
		steps += 1
	var settled: bool = entry.status == BoardEntry.STATUS_SUCCEEDED \
		or entry.status == BoardEntry.STATUS_FAILED or entry.verdict == BoardEntry.STATUS_FAILED
	TestFixtures.check(res, "run_settled", settled and steps < cap,
		"status %s verdict %s steps %d" % [entry.status, entry.verdict, steps])
	TestFixtures.check(res, "run_dropped", (state.active_contracts as Dictionary).is_empty(),
		"active %d" % (state.active_contracts as Dictionary).size())
	var still_out: Array[String] = []
	for uid: int in uids:
		var merc: MercenaryData = state.merc_by_uid(uid)
		if merc != null and merc.on_contract:
			still_out.append(merc.merc_name)
	TestFixtures.check(res, "run_home", still_out.is_empty(), TestFixtures.detail(still_out, 2, "merc"))
	var reward: int = entry.contract.reward_notes if entry.verdict == BoardEntry.STATUS_SUCCEEDED else 0
	TestFixtures.check(res, "run_reward", int(state.bank_notes) == banked + reward,
		"bank %d expected %d verdict %s" % [int(state.bank_notes), banked + reward, entry.verdict])
	_drop(state)


#A rejected posting stays listed as Rejected until the calendar month it closed in ends (B4).
static func _case_reject(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var dropped: bool = state.reject(entry.id)
	var view: ContractView = null
	for row: ContractView in (state.contracts as Array[ContractView]):
		if row.entry_id == entry.id:
			view = row
	TestFixtures.check(res, "reject_returns", dropped, "reject returned %s" % str(dropped))
	TestFixtures.check(res, "reject_keeps_listed",
		view != null and view.status == GuiTypes.ContractStatus.REJECTED,
		"the rejected posting left the list")
	TestFixtures.check(res, "reject_stamps_closed",
		entry.closed_minute >= 0 and view != null and view.closed_minute == entry.closed_minute,
		"closed %d" % entry.closed_minute)
	TestFixtures.check(res, "reject_twice", not state.reject(entry.id),
		"a posting was rejected twice")
	await state.process_until(TrynnCalendar.next_month_start(CampaignClock.now()))
	var still: bool = false
	for row: ContractView in (state.contracts as Array[ContractView]):
		if row.entry_id == entry.id:
			still = true
	TestFixtures.check(res, "reject_drops_next_month", not still,
		"the rejected posting outlived its month")
	_drop(state)


#A posting a dispatch could not take is struck off; an active one is never discarded (B5).
static func _case_discard(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var before: int = (state.board.entries as Array[BoardEntry]).size()
	var gone: bool = state.discard(entry.id)
	TestFixtures.check(res, "discard_removes",
		gone and (state.board.entries as Array[BoardEntry]).size() == before - 1
		and state.board.entry(entry.id) == null,
		"entries %d of %d" % [(state.board.entries as Array[BoardEntry]).size(), before - 1])
	var listed: bool = false
	for row: ContractView in (state.contracts as Array[ContractView]):
		if row.entry_id == entry.id:
			listed = true
	TestFixtures.check(res, "discard_unlists", not listed,
		"the discarded posting is still listed")
	TestFixtures.check(res, "discard_unknown", not state.discard(entry.id),
		"a missing posting was discarded")
	var second: BoardEntry = _open_entry(state)
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid, mercs[1].merc_uid]
	var sent: bool = state.dispatch(second.id, _active_run(uids, 0))
	TestFixtures.check(res, "discard_setup_dispatch", sent, "the test dispatch failed")
	TestFixtures.check(res, "discard_refuses_active", not state.discard(second.id),
		"an active posting was discarded")
	var third: BoardEntry = _open_entry(state)
	third.status = BoardEntry.STATUS_SUCCEEDED
	third.closed_minute = -1
	state.refresh_views()
	var unstamped: bool = false
	for row: ContractView in (state.contracts as Array[ContractView]):
		if row.entry_id == third.id:
			unstamped = true
	TestFixtures.check(res, "discard_unstamped_unlisted", not unstamped,
		"a closed posting with no closed_minute stayed listed")
	TestFixtures.check(res, "discard_refuses_settled", not state.discard(third.id),
		"a settled posting was discarded")
	_drop(state)


#A dispatch at 23:00 waits in the tavern: the money and the crew are committed, nobody leaves.
static func _case_night_queue(res: Dictionary) -> void:
	var state: Variant = _state()
	await state.process_until(TrynnCalendar.START_MINUTE + NIGHT_SHIFT)
	var entry: BoardEntry = _open_entry(state)
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid, mercs[1].merc_uid]
	var before: int = int(state.bank_notes)
	var contract_run: ActiveRun = _active_run(uids, 20)
	var sent: bool = state.dispatch(entry.id, contract_run)
	TestFixtures.check(res, "night_queued", sent, "dispatch returned %s" % str(sent))
	TestFixtures.check(res, "night_cost", int(state.bank_notes) == before - 20,
		"bank %d was %d" % [int(state.bank_notes), before])
	TestFixtures.check(res, "night_entry_active", entry.status == BoardEntry.STATUS_ACTIVE
		and entry.scheduler == null, "status %s" % entry.status)
	var queued: Dictionary = state.queued
	var active: Dictionary = state.active_contracts
	TestFixtures.check(res, "night_tracked", queued.has(entry.id) and active.has(entry.id),
		"queued %d active %d" % [queued.size(), active.size()])
	var wake: int = ContractScheduler.next_wake_minute(CampaignClock.now())
	TestFixtures.check(res, "night_depart_minute", contract_run.depart_minute == wake,
		"depart %d wake %d" % [contract_run.depart_minute, wake])
	var busy: Array[int] = state.busy_uids()
	TestFixtures.check(res, "night_busy", busy.has(uids[0]) and busy.has(uids[1]),
		"busy %s" % str(busy))
	TestFixtures.check(res, "night_not_on_contract",
		not mercs[0].on_contract and not mercs[1].on_contract, "the queued team left early")
	var waiting: Array[String] = []
	for uid: int in uids:
		var status: Dictionary = state.merc_status(state.merc_by_uid(uid))
		if int(status["status"]) != GuiTypes.MercStatus.CONTRACT:
			waiting.append("%d status %d" % [uid, int(status["status"])])
		if not is_equal_approx(float(status["hours_left"]), QUEUE_HOURS):
			waiting.append("%d hours %.2f" % [uid, float(status["hours_left"])])
	TestFixtures.check(res, "night_status", waiting.is_empty(),
		TestFixtures.detail(waiting, 4, "merc"))
	var views: Array[String] = []
	for view: MercView in (state.roster as Array[MercView]):
		if uids.has(view.uid) and view.status != GuiTypes.MercStatus.CONTRACT:
			views.append("%s %d" % [view.name, view.status])
	TestFixtures.check(res, "night_views", views.is_empty(), TestFixtures.detail(views, 4, "merc"))
	TestFixtures.check(res, "night_twice", not state.dispatch(entry.id, _active_run(uids, 20)),
		"a queued posting took a second team")
	TestFixtures.check(res, "night_reject", not state.reject(entry.id),
		"a queued posting was rejected")
	_drop(state)


#The queue is called off before 6:00; a team already on the road is not.
static func _case_night_cancel(res: Dictionary) -> void:
	var state: Variant = _state()
	await state.process_until(TrynnCalendar.START_MINUTE + NIGHT_SHIFT)
	var entry: BoardEntry = _open_entry(state)
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid, mercs[1].merc_uid]
	var before: int = int(state.bank_notes)
	state.dispatch(entry.id, _active_run(uids, 20))
	var cancelled: bool = state.cancel_dispatch(entry.id)
	TestFixtures.check(res, "cancel_returns", cancelled, "cancel returned %s" % str(cancelled))
	TestFixtures.check(res, "cancel_refund", int(state.bank_notes) == before,
		"bank %d was %d" % [int(state.bank_notes), before])
	TestFixtures.check(res, "cancel_reopens", entry.is_open(), "status %s" % entry.status)
	var queued: Dictionary = state.queued
	var active: Dictionary = state.active_contracts
	TestFixtures.check(res, "cancel_clears", queued.is_empty() and active.is_empty(),
		"queued %d active %d" % [queued.size(), active.size()])
	var stuck: Array[String] = []
	for uid: int in uids:
		var status: Dictionary = state.merc_status(state.merc_by_uid(uid))
		if int(status["status"]) != GuiTypes.MercStatus.AVAILABLE:
			stuck.append("%d status %d" % [uid, int(status["status"])])
	TestFixtures.check(res, "cancel_frees", stuck.is_empty(), TestFixtures.detail(stuck, 4, "merc"))
	TestFixtures.check(res, "cancel_twice", not state.cancel_dispatch(entry.id),
		"a posting was called off twice")
	_drop(state)
	var day: Variant = _state()
	var day_entry: BoardEntry = _open_entry(day)
	var day_uid: int = (day.mercs as Array[MercenaryData])[0].merc_uid
	var road: bool = day.dispatch(day_entry.id, _active_run([day_uid], 10))
	TestFixtures.check(res, "cancel_on_the_road", road and not day.cancel_dispatch(day_entry.id)
		and day_entry.status == BoardEntry.STATUS_ACTIVE,
		"sent %s status %s" % [str(road), day_entry.status])
	_drop(day)


#6:00: the queued team leaves, the posting never expires overnight and the run settles as usual.
static func _case_night_departs(res: Dictionary) -> void:
	var state: Variant = _state()
	await state.process_until(TrynnCalendar.START_MINUTE + NIGHT_SHIFT)
	var entry: BoardEntry = _open_entry(state)
	entry.expires_minute = CampaignClock.now() + 3 * CampaignClock.MINUTES_PER_HOUR
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid, mercs[1].merc_uid]
	var contract_run: ActiveRun = _active_run(uids, 20)
	state.dispatch(entry.id, contract_run)
	var queued_line: String = entry.log_lines[0] if not entry.log_lines.is_empty() else ""
	await state.process_until(TrynnCalendar.START_MINUTE + CampaignClock.MINUTES_PER_DAY)
	TestFixtures.check(res, "depart_active", entry.status == BoardEntry.STATUS_ACTIVE
		and entry.scheduler != null, "status %s" % entry.status)
	TestFixtures.check(res, "depart_queue_empty", (state.queued as Dictionary).is_empty(),
		"queued %d" % (state.queued as Dictionary).size())
	TestFixtures.check(res, "depart_on_contract", mercs[0].on_contract and mercs[1].on_contract,
		"the team never left")
	var travel: int = int(state.travel_minutes("foot", entry.distance_km))
	var due: int = contract_run.depart_minute + travel
	var moved: bool = entry.scheduler != null and (entry.scheduler.next_minute == due
		or (entry.scheduler.phase != ContractScheduler.Phase.DONE
		and not entry.log_lines.is_empty() and entry.log_lines[0] == queued_line))
	TestFixtures.check(res, "depart_travel", moved, "next %d expected %d" %
		[entry.scheduler.next_minute if entry.scheduler != null else -1, due])
	TestFixtures.check(res, "depart_keeps_line", not entry.log_lines.is_empty()
		and entry.log_lines[0] == queued_line,
		"first line %s" % (entry.log_lines[0] if not entry.log_lines.is_empty() else "none"))
	var cap: int = int(float(DAY_CAP * CampaignClock.MINUTES_PER_DAY) / float(SHIFT))
	var steps: int = 0
	while entry.status == BoardEntry.STATUS_ACTIVE and steps < cap:
		await state.process_until(CampaignClock.now() + SHIFT)
		steps += 1
	TestFixtures.check(res, "depart_settled", steps < cap
		and (state.active_contracts as Dictionary).is_empty(),
		"status %s steps %d active %d" % [entry.status, steps,
		(state.active_contracts as Dictionary).size()])
	var still_out: Array[String] = []
	for uid: int in uids:
		var merc: MercenaryData = state.merc_by_uid(uid)
		if merc != null and merc.on_contract and not merc.is_dead:
			still_out.append(merc.merc_name)
	TestFixtures.check(res, "depart_home", still_out.is_empty(),
		TestFixtures.detail(still_out, 2, "merc"))
	_drop(state)


static func _case_rest_status(res: Dictionary) -> void:
	var state: Variant = _state()
	var merc: MercenaryData = (state.mercs as Array[MercenaryData])[0]
	merc.rest_lockout_until = CampaignClock.now() + REST_MINUTES
	merc.rest_lockout_kind = RestSystem.KIND_RESPITE
	var resting: Dictionary = state.merc_status(merc)
	TestFixtures.check(res, "rest_status", int(resting["status"]) == GuiTypes.MercStatus.RESTING,
		"status %d" % int(resting["status"]))
	TestFixtures.check(res, "rest_hours", is_equal_approx(float(resting["hours_left"]), 2.0),
		"hours %.2f" % float(resting["hours_left"]))
	merc.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	var away: Dictionary = state.merc_status(merc)
	TestFixtures.check(res, "rest_vacation", int(away["status"]) == GuiTypes.MercStatus.VACATION,
		"status %d" % int(away["status"]))
	TestFixtures.check(res, "rest_vacation_hours", is_equal_approx(float(away["hours_left"]), 2.0),
		"hours %.2f" % float(away["hours_left"]))
	merc.rest_lockout_until = 0
	merc.rest_lockout_kind = ""
	_drop(state)


static func _case_metrics(res: Dictionary) -> void:
	var state: Variant = _state()
	MetricsHistory.clear()
	state.set_speed(ClockRunner.Speed.VERY_FAST)
	var crossed: int = 0
	while crossed < 2 and CampaignClock.now() < TrynnCalendar.START_MINUTE + 3 * CampaignClock.MINUTES_PER_DAY:
		var before: int = TrynnCalendar.day_index(CampaignClock.now())
		await state.clock.tick()
		crossed += TrynnCalendar.day_index(CampaignClock.now()) - before
	TestFixtures.check(res, "metrics_days", MetricsHistory.days() >= 2, "days %d" % MetricsHistory.days())
	var bank: Array[Dictionary] = MetricsHistory.series("Guild", "bank", 0, 1)
	TestFixtures.check(res, "metrics_bank", not bank.is_empty() and float(bank[0]["value"]) == 100.0,
		"points %d" % bank.size())
	_drop(state)
	MetricsHistory.clear()

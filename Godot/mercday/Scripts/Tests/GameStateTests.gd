class_name GameStateTests

#GameState launch, the ordered clock processing, the salary debit, dispatch, reject, the night
#dispatch queue, the metrics record, the money log, the away registry and the manager tick, with the
#verdict standing, the reach sweep, the late arrival and the one start.
#The script is loaded by path so the suite never depends on the autoload registration; only the start check
#runs on the autoload, whose game_started signal resets the managers.

const STATE_PATH := "res://Scripts/GUI/Autoloads/GameState.gd"
const START_SEED := 7
const SHIFT := 480
const DAY_CAP := 60
#Kusarra, the first month to start after the 3rd of Erta launch; its 2nd is the first payday.
const SALARY_MINUTE_MONTH := 5
const REST_MINUTES := 120
#Minutes from the start minute to 23:00 of the same day, and the hours that wait leaves.
const NIGHT_SHIFT := 900
const QUEUE_HOURS := 7.0
#The seat moves a win and a loss make, and seats a standing check starts from (80 rejects to 60).
const SEAT_WIN := 10
const SEAT_LOSS := 15
const MID_SAT := 50
const REJECT_SAT := 80
const REJECTED_SAT := 60
#A deadline no venture makes, a bank in the red, a run's fare, an expiry inside the last day and a far deadline.
const TIGHT_MINUTES := 60
const RED_BANK := -5
const FARE := 10
const LAST_DAY_HOURS := 23
const FAR_DAYS := 30
#The one start: two mercs and one posting at difficulty 1.0 and quality 0.9; the guild bills 30 a month, travel from the offers.
const START_ROSTER := 2
const OPENING_POSTINGS := 1
const OPENING_DIFFICULTY := 1.0
const OPENING_QUALITY := 0.9
const GUILD_RATE := 30
#A bank in the red before a win's reward lands, and the reward that lifts it out.
const SETTLE_BANK := -20
const SETTLE_REWARD := 50
#A walk that arrives the same day, so no night camp rolls a respite trigger on the way out.
const LATE_KM := 5
#A posting far enough out to ride by horse.
const SPLIT_KM := 100


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	await Engine.get_main_loop().process_frame
	_case_launch(res)
	_case_launch_posting(res)
	await _case_daily_refill(res)
	await _case_salary_debit(res)
	await _case_relays(res)
	await _case_dispatch(res)
	await _case_reject(res)
	_case_standing(res)
	_case_red_settle(res)
	_case_discard(res)
	await _case_night_queue(res)
	await _case_night_cancel(res)
	await _case_night_departs(res)
	await _case_night_refusal(res)
	await _case_sweep_expired(res)
	await _case_sweep_warning(res)
	_case_campaign_sweep(res)
	await _case_late_arrival(res)
	_case_red_dispatch(res)
	_case_split_fares(res)
	_case_rest_status(res)
	await _case_metrics(res)
	_case_money_log(res)
	_case_income_expenses(res)
	await _case_away(res)
	_case_removed(res)
	await _case_next_payday(res)
	await _case_tick_order(res)
	_case_time_hold(res)
	_case_start(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GAMESTATE")


#A fresh campaign on a fixed seed, in the tree so the autoload wiring of _ready runs.
static func _state() -> Variant:
	TestFixtures.reset_generator_rolls()
	seed(START_SEED)
	var state: Variant = load(STATE_PATH).new()
	(Engine.get_main_loop() as SceneTree).root.add_child(state)
	state.start_new_game()
	state.seed_round(START_SEED)
	return state


static func _drop(state: Variant) -> void:
	state.set_speed(ClockRunner.Speed.PAUSE)
	(Engine.get_main_loop() as SceneTree).root.remove_child(state)
	state.free()


static func _open_entry(state: Variant) -> BoardEntry:
	var open: Array[BoardEntry] = state.board.available()
	return null if open.is_empty() else open[0]


#Tops the board up to count open postings the way the 8:00 refill does; the start posts only one.
static func _top_up(state: Variant, count: int) -> void:
	state.board.refill(CampaignClock.now(), count)
	state._expire_postings(CampaignClock.now())
	state.refresh_views()


#The most open postings the daily round leaves: the plan's roster cap.
static func _board_cap() -> int:
	return SubscriptionManager.max_contracts()


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


#The listed view of this board entry, or null when it is not listed.
static func _view(state: Variant, entry_id: int) -> ContractView:
	var found: ContractView = null
	for row: ContractView in (state.contracts as Array[ContractView]):
		if row.entry_id == entry_id:
			found = row
	return found


static func _settle_cap() -> int:
	return int(float(DAY_CAP * CampaignClock.MINUTES_PER_DAY) / float(SHIFT))


#Steps the clock a shift at a time until the entry stops being active; the steps taken, at most the cap.
static func _settle(state: Variant, entry: BoardEntry) -> int:
	var steps: int = 0
	while entry.status == BoardEntry.STATUS_ACTIVE and steps < _settle_cap():
		await state.process_until(CampaignClock.now() + SHIFT)
		steps += 1
	return steps


#Names of the mercs still marked on contract; skip_dead leaves the dead out.
static func _still_out(state: Variant, uids: Array[int], skip_dead: bool) -> Array[String]:
	var out: Array[String] = []
	for uid: int in uids:
		var merc: MercenaryData = state.merc_by_uid(uid)
		if merc != null and merc.on_contract and not (skip_dead and merc.is_dead):
			out.append(merc.merc_name)
	return out


static func _case_launch(res: Dictionary) -> void:
	var state: Variant = _state()
	var mercs: Array[MercenaryData] = state.mercs
	TestFixtures.check(res, "launch_merc_count", mercs.size() == 2, "mercs %d" % mercs.size())
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
	TestFixtures.check(res, "launch_board", entries == OPENING_POSTINGS, "entries %d" % entries)
	var views: int = (state.contracts as Array[ContractView]).size()
	TestFixtures.check(res, "launch_contract_views", views == OPENING_POSTINGS, "views %d" % views)
	var roster: int = (state.roster as Array[MercView]).size()
	TestFixtures.check(res, "launch_roster_views", roster == 2, "roster %d" % roster)
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


#The one start: the Free plan, one open posting issued from a seat under its name with a deadline past its expiry.
static func _case_launch_posting(res: Dictionary) -> void:
	var state: Variant = _state()
	TestFixtures.check(res, "the harness launches on the Free plan",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE, "plan %d" % SubscriptionManager.plan())
	var entries: Array[BoardEntry] = state.board.entries
	var open: Array[BoardEntry] = state.board.available()
	TestFixtures.check(res, "the launch opens one posting",
		entries.size() == OPENING_POSTINGS and open.size() == OPENING_POSTINGS,
		"entries %d open %d" % [entries.size(), open.size()])
	var seats: int = IssuerOpinion.ORG_SEATS + IssuerOpinion.PEOPLE_SEATS + IssuerOpinion.PLACE_SEATS
	var off_seat: Array[String] = []
	var early: Array[String] = []
	for entry: BoardEntry in entries:
		if entry.issuer_id < 0 or entry.issuer_id >= seats or entry.issuer.is_empty() \
				or entry.issuer != IssuerOpinion.name_of(entry.issuer_id):
			off_seat.append("%d seat %d %s" % [entry.id, entry.issuer_id, entry.issuer])
		if entry.deadline_minute <= entry.expires_minute:
			early.append("%d deadline %d expires %d" % [entry.id, entry.deadline_minute, entry.expires_minute])
	TestFixtures.check(res, "every launch posting is issued from a seat under that seat's name", off_seat.is_empty(),
		TestFixtures.detail(off_seat, entries.size(), "posting"))
	TestFixtures.check(res, "every launch deadline falls after the posting's expiry", early.is_empty(),
		TestFixtures.detail(early, entries.size(), "posting"))
	_drop(state)


static func _case_daily_refill(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	state.reject(entry.id)
	var before: int = int(state.bank_notes)
	var open_after_reject: int = (state.board.available() as Array[BoardEntry]).size()
	await state.process_until(TrynnCalendar.START_MINUTE + CampaignClock.MINUTES_PER_DAY)
	var open_now: int = (state.board.available() as Array[BoardEntry]).size()
	TestFixtures.check(res, "refill_rejected", open_after_reject == OPENING_POSTINGS - 1,
		"open %d" % open_after_reject)
	TestFixtures.check(res, "refill_topped_up", open_now >= 1 and open_now <= _board_cap(), "open %d" % open_now)
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
	var open_before: int = (state.board.available() as Array[BoardEntry]).size()
	await state.process_until(debit_minute)
	state.money_changed.disconnect(watcher)
	TestFixtures.check(res, "debit_amount", int(state.bank_notes) == before - expected,
		"bank %d expected %d" % [int(state.bank_notes), before - expected])
	TestFixtures.check(res, "debit_once", open_at_debit.size() == 1, "money_changed %d" % open_at_debit.size())
	var open_now: int = (state.board.available() as Array[BoardEntry]).size()
	var ordered: bool = not open_at_debit.is_empty() and open_at_debit[0] == open_before \
		and open_now <= _board_cap()
	TestFixtures.check(res, "debit_before_refill", ordered,
		"open %d, at debit %s, after %d" % [open_before, str(open_at_debit), open_now])
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
	state.set_speed(ClockRunner.Speed.PLAY)
	var step: int = ClockRunner.AFTER_HOURS_STEPS[ClockRunner.Speed.PLAY]
	var next_day: int = (TrynnCalendar.day_index(CampaignClock.now()) + 1) * CampaignClock.MINUTES_PER_DAY
	await state.process_until(next_day - 2 * step)
	await state.clock.tick()
	TestFixtures.check(res, "relay_no_day_yet", days.is_empty(), "days %s" % str(days))
	await state.clock.tick()
	var today: int = TrynnCalendar.day_index(CampaignClock.now())
	TestFixtures.check(res, "relay_day", days.size() == 1 and days[0] == today, "days %s" % str(days))
	var month_start: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, SALARY_MINUTE_MONTH)
	await state.process_until(month_start - step)
	await state.clock.tick()
	var month_day: int = int(month_start / float(CampaignClock.MINUTES_PER_DAY))
	TestFixtures.check(res, "relay_month_day", days.size() == 2 and days[1] == month_day,
		"days %s" % str(days))
	TestFixtures.check(res, "relay_month", months.size() == 1 and months[0] == "212/%d" % SALARY_MINUTE_MONTH,
		"months %s" % str(months))
	_drop(state)


#hold_time and release_time reach the clock and relay its hold signal; with no clock they do nothing.
static func _case_time_hold(res: Dictionary) -> void:
	var state: Variant = _state()
	var holds: Array[bool] = []
	state.time_hold_changed.connect(func(held: bool) -> void: holds.append(held))
	var screen := RefCounted.new()
	state.set_speed(ClockRunner.Speed.PLAY)
	state.hold_time(screen)
	TestFixtures.check(res, "time_hold_pauses", bool(state.is_time_held())
		and int(state.clock.speed) == ClockRunner.Speed.PAUSE and holds == [true],
		"held %s speed %d holds %s" % [str(state.is_time_held()), int(state.clock.speed), str(holds)])
	state.release_time(screen)
	TestFixtures.check(res, "time_hold_restores", not bool(state.is_time_held())
		and int(state.clock.speed) == ClockRunner.Speed.PLAY and holds == [true, false],
		"held %s speed %d holds %s" % [str(state.is_time_held()), int(state.clock.speed), str(holds)])
	_drop(state)
	var bare: Variant = load(STATE_PATH).new()
	bare.hold_time(screen)
	TestFixtures.check(res, "time_hold_no_clock", not bool(bare.is_time_held()), "held with no clock")
	bare.release_time(screen)
	bare.free()


static func _case_dispatch(res: Dictionary) -> void:
	var state: Variant = _state()
	_top_up(state, 2)
	TestFixtures.add_mercs(1, 1, state)
	var entry: BoardEntry = _open_entry(state)
	var seat: int = entry.issuer_id
	IssuerOpinion._set_satisfaction(seat, MID_SAT)
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
	var cap: int = _settle_cap()
	var steps: int = await _settle(state, entry)
	var settled: bool = entry.status == BoardEntry.STATUS_SUCCEEDED \
		or entry.status == BoardEntry.STATUS_FAILED or entry.verdict == BoardEntry.STATUS_FAILED
	TestFixtures.check(res, "run_settled", settled and steps < cap,
		"status %s verdict %s steps %d" % [entry.status, entry.verdict, steps])
	TestFixtures.check(res, "run_dropped", (state.active_contracts as Dictionary).is_empty(),
		"active %d" % (state.active_contracts as Dictionary).size())
	var still_out: Array[String] = _still_out(state, uids, false)
	TestFixtures.check(res, "run_home", still_out.is_empty(), TestFixtures.detail(still_out, 2, "merc"))
	var reward: int = entry.contract.reward_notes if entry.verdict == BoardEntry.STATUS_SUCCEEDED else 0
	TestFixtures.check(res, "run_reward", int(state.bank_notes) == banked + reward,
		"bank %d expected %d verdict %s" % [int(state.bank_notes), banked + reward, entry.verdict])
	var won: int = 1 if entry.verdict == BoardEntry.STATUS_SUCCEEDED else 0
	var lost: int = 1 if entry.verdict == BoardEntry.STATUS_FAILED else 0
	var want_sat: int = MID_SAT + won * SEAT_WIN - lost * SEAT_LOSS
	TestFixtures.check(res, "the settled verdict is written to the guild record and the issuer seat",
		GuildRecord.guild.successes == won and GuildRecord.guild.failures == lost
		and IssuerOpinion.satisfaction(seat) == want_sat,
		"verdict %s guild %d/%d seat %d want %d" % [entry.verdict, GuildRecord.guild.successes,
		GuildRecord.guild.failures, IssuerOpinion.satisfaction(seat), want_sat])
	_drop(state)


#A rejected posting stays listed as Rejected until the calendar month it closed in ends.
static func _case_reject(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var dropped: bool = state.reject(entry.id)
	var view: ContractView = _view(state, entry.id)
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
	var still: bool = _view(state, entry.id) != null
	TestFixtures.check(res, "reject_drops_next_month", not still,
		"the rejected posting outlived its month")
	_drop(state)


#A win adds 10 to the issuer seat (none in the red) and a loss takes 15, each counted on the guild and group
#records; a reject leaves three quarters of the seat and records nothing.
static func _case_standing(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var seat: int = entry.issuer_id
	var now: int = CampaignClock.now()
	var bank: int = int(state.bank_notes)
	IssuerOpinion._set_satisfaction(seat, MID_SAT)
	state._record_standing(entry, BoardEntry.STATUS_SUCCEEDED, now)
	TestFixtures.check(res, "a win adds a guild and a group success and 10 to the issuer seat",
		_tally(seat) == [1, 0, 1, 0] and IssuerOpinion.satisfaction(seat) == MID_SAT + SEAT_WIN, _standing(seat))
	state.bank_notes = RED_BANK
	state._record_standing(entry, BoardEntry.STATUS_SUCCEEDED, now)
	state.bank_notes = bank
	TestFixtures.check(res, "a win in the red counts on both records but leaves the issuer seat",
		_tally(seat) == [2, 0, 2, 0] and IssuerOpinion.satisfaction(seat) == MID_SAT + SEAT_WIN, _standing(seat))
	state._record_standing(entry, BoardEntry.STATUS_FAILED, now)
	TestFixtures.check(res, "a loss adds a guild and a group failure and takes 15 from the issuer seat",
		_tally(seat) == [2, 1, 2, 1] and IssuerOpinion.satisfaction(seat) == MID_SAT + SEAT_WIN - SEAT_LOSS,
		_standing(seat))
	state._record_standing(entry, BoardEntry.STATUS_EXPIRED, now)
	TestFixtures.check(res, "a verdict that is neither a win nor a loss records nothing",
		_tally(seat) == [2, 1, 2, 1] and IssuerOpinion.satisfaction(seat) == MID_SAT + SEAT_WIN - SEAT_LOSS,
		_standing(seat))
	IssuerOpinion._set_satisfaction(seat, REJECT_SAT)
	var dropped: bool = state.reject(entry.id)
	TestFixtures.check(res, "a reject leaves three quarters of the issuer seat and records nothing",
		dropped and _tally(seat) == [2, 1, 2, 1] and IssuerOpinion.satisfaction(seat) == REJECTED_SAT,
		_standing(seat))
	_drop(state)


#Standing is judged after the reward lands: a win paying 50 settled from a bank of -20 is no win in the red.
static func _case_red_settle(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var seat: int = entry.issuer_id
	IssuerOpinion._set_satisfaction(seat, MID_SAT)
	var team: Array[MercenaryData] = [(state.mercs as Array[MercenaryData])[0]]
	var scheduler: ContractScheduler = state.board.activate(entry.id, team, 0, CampaignClock.now(), Callable())
	scheduler.phase = ContractScheduler.Phase.DONE
	scheduler.all_dead = false
	scheduler.run.verdict = BoardEntry.STATUS_SUCCEEDED
	scheduler.run.reward_paid = SETTLE_REWARD
	state.bank_notes = SETTLE_BANK
	state._clock_depth += 1
	state._settle(entry)
	state._clock_depth -= 1
	TestFixtures.check(res, "a win whose reward lifts the bank out of the red adds 10 to the issuer seat",
		entry.verdict == BoardEntry.STATUS_SUCCEEDED and _tally(seat) == [1, 0, 1, 0]
		and IssuerOpinion.satisfaction(seat) == MID_SAT + SEAT_WIN,
		"%s verdict %s bank %d" % [_standing(seat), entry.verdict, int(state.bank_notes)])
	_drop(state)


#Guild successes and failures, then those of the seat's issuer group.
static func _tally(seat: int) -> Array:
	var group: GuildRecord = IssuerOpinion.group_record(IssuerOpinion.group_of(seat))
	return [GuildRecord.guild.successes, GuildRecord.guild.failures, group.successes, group.failures]


static func _standing(seat: int) -> String:
	return "guild and group %s seat %d" % [str(_tally(seat)), IssuerOpinion.satisfaction(seat)]


#A posting a dispatch could not take is struck off; an active one is never discarded.
static func _case_discard(res: Dictionary) -> void:
	var state: Variant = _state()
	_top_up(state, 3)
	var entry: BoardEntry = _open_entry(state)
	var before: int = (state.board.entries as Array[BoardEntry]).size()
	var gone: bool = state.discard(entry.id)
	TestFixtures.check(res, "discard_removes",
		gone and (state.board.entries as Array[BoardEntry]).size() == before - 1
		and state.board.entry(entry.id) == null,
		"entries %d of %d" % [(state.board.entries as Array[BoardEntry]).size(), before - 1])
	var listed: bool = _view(state, entry.id) != null
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
	var unstamped: bool = _view(state, third.id) != null
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
		if int(status["status"]) != GuiTypes.MercStatus.PREPARING:
			waiting.append("%d status %d" % [uid, int(status["status"])])
		if not is_equal_approx(float(status["hours_left"]), QUEUE_HOURS):
			waiting.append("%d hours %.2f" % [uid, float(status["hours_left"])])
	TestFixtures.check(res, "night_status", waiting.is_empty(),
		TestFixtures.detail(waiting, 4, "merc"))
	var views: Array[String] = []
	for view: MercView in (state.roster as Array[MercView]):
		if uids.has(view.uid) and view.status != GuiTypes.MercStatus.PREPARING:
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
	var cap: int = _settle_cap()
	var steps: int = await _settle(state, entry)
	TestFixtures.check(res, "depart_settled", steps < cap
		and (state.active_contracts as Dictionary).is_empty(),
		"status %s steps %d active %d" % [entry.status, steps,
		(state.active_contracts as Dictionary).size()])
	var still_out: Array[String] = _still_out(state, uids, true)
	TestFixtures.check(res, "depart_home", still_out.is_empty(),
		TestFixtures.detail(still_out, 2, "merc"))
	_drop(state)


#At 23:00 a dispatch waits for the 6:00 departure: one whose deadline that departure misses is refused and spends
#nothing, one it still makes queues as before.
static func _case_night_refusal(res: Dictionary) -> void:
	var state: Variant = _state()
	_top_up(state, 2)
	await state.process_until(TrynnCalendar.START_MINUTE + NIGHT_SHIFT)
	var open: Array[BoardEntry] = state.board.available()
	TestFixtures.check(res, "two postings are open at 23:00 for the night refusal", open.size() >= 2,
		"open %d" % open.size())
	if open.size() < 2:
		_drop(state)
		return
	var missed: BoardEntry = open[0]
	var met: BoardEntry = open[1]
	var wake: int = ContractScheduler.next_wake_minute(CampaignClock.now())
	missed.deadline_minute = _foot_deadline(missed, wake) - 1
	met.deadline_minute = _foot_deadline(met, wake)
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid]
	var before: int = int(state.bank_notes)
	var refused: bool = not state.dispatch(missed.id, _active_run(uids, FARE))
	TestFixtures.check(res, "a night dispatch whose 6:00 departure misses the deadline is refused",
		refused and missed.is_open() and not (state.queued as Dictionary).has(missed.id),
		"refused %s status %s" % [str(refused), missed.status])
	var busy: Array[int] = state.busy_uids()
	TestFixtures.check(res, "the refused night dispatch spends nothing and holds nobody",
		int(state.bank_notes) == before and busy.is_empty() and (state.active_contracts as Dictionary).is_empty(),
		"bank %d was %d busy %s" % [int(state.bank_notes), before, str(busy)])
	var queued: bool = state.dispatch(met.id, _active_run(uids, FARE))
	TestFixtures.check(res, "a night dispatch the 6:00 departure still brings in on time queues as before",
		queued and (state.queued as Dictionary).has(met.id) and int(state.bank_notes) == before - FARE,
		"queued %s bank %d was %d" % [str(queued), int(state.bank_notes), before])
	_drop(state)


#The last deadline a walking party that leaves at depart still makes.
static func _foot_deadline(entry: BoardEntry, depart: int) -> int:
	var walk: int = Reachability.base_minutes(Reachability.FOOT, entry.distance_km)
	return Reachability.arrival_minute(depart, walk) + Reachability.completion_minutes(entry)


#A posting no venture brings in by its deadline leaves the board at the next sweep with one expired notice.
static func _case_sweep_expired(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var now: int = CampaignClock.now()
	var warned_before: int = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id).size()
	entry.deadline_minute = now + TIGHT_MINUTES
	#A clock pass sweeps only when something is due; an expiry a day and a minute out puts its warning at now + 1.
	entry.expires_minute = now + 1 + Reachability.WARNING_MINUTES
	await state.process_until(now + 1)
	TestFixtures.check(res, "a posting no venture brings in by its deadline expires at the next sweep",
		entry.status == BoardEntry.STATUS_EXPIRED and entry.expires_minute == now + 1
		and entry.closed_minute == now + 1,
		"status %s expires %d closed %d now %d" % [entry.status, entry.expires_minute, entry.closed_minute, now])
	var gone: Array[NotificationData] = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRED, entry.id)
	var row: NotificationData = gone[0] if gone.size() == 1 else null
	TestFixtures.check(res, "its expiry pushes one posting expired notice with its name, difficulty and reward",
		_snap_of(row, state, entry) and row.kind == state.POSTING_NOTICE_KIND
		and row.urgency == NotificationData.Urgency.INFORMATIONAL,
		"rows %d %s" % [gone.size(), _row_text(row)])
	var warned: int = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id).size()
	TestFixtures.check(res, "a posting that goes out of reach at the sweep is never warned",
		warned_before == 0 and warned == 0, "warnings %d before %d" % [warned, warned_before])
	_drop(state)


#A posting inside its last day is warned once across two sweeps, then expires on its minute.
static func _case_sweep_warning(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var now: int = CampaignClock.now()
	var warned_before: int = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id).size()
	var expires: int = now + LAST_DAY_HOURS * CampaignClock.MINUTES_PER_HOUR
	entry.deadline_minute += FAR_DAYS * CampaignClock.MINUTES_PER_DAY
	entry.expires_minute = expires
	state._expire_postings(now)
	state._expire_postings(now)
	var warned: Array[NotificationData] = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id)
	var row: NotificationData = warned[0] if warned.size() == 1 else null
	TestFixtures.check(res, "a posting 23 hours from expiry is warned once across two sweeps",
		warned_before == 0 and warned.size() == 1 and entry.reach_warned and entry.is_open()
		and entry.expires_minute == expires,
		"rows %d before %d status %s expires %d want %d" % [warned.size(), warned_before, entry.status,
		entry.expires_minute, expires])
	TestFixtures.check(res, "the warning names the posting and carries its difficulty and reward",
		_snap_of(row, state, entry) and row.kind == state.POSTING_NOTICE_KIND
		and row.urgency == NotificationData.Urgency.IMPORTANT, _row_text(row))
	await state.process_until(expires)
	var gone: Array[NotificationData] = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRED, entry.id)
	var later: int = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id).size()
	TestFixtures.check(res, "it expires on its minute with one expired notice and no second warning",
		entry.status == BoardEntry.STATUS_EXPIRED and entry.closed_minute == expires and gone.size() == 1
		and later == 1 and _snap_of(gone[0], state, entry),
		"status %s closed %d expired rows %d warnings %d" % [entry.status, entry.closed_minute, gone.size(), later])
	_drop(state)


#A campaign posting rolled inside its last day is swept as it posts: it stays open with one warning already pushed.
static func _case_campaign_sweep(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	var min_hours: int = cfg.board_expiry_min_hours
	var max_hours: int = cfg.board_expiry_max_hours
	var state: Variant = _state()
	cfg.board_expiry_min_hours = LAST_DAY_HOURS
	cfg.board_expiry_max_hours = LAST_DAY_HOURS
	var military: Array[String] = ["Military"]
	var anywhere: Array[String] = []
	var contract: ContractData = ContractGenerator.generate_for(military, anywhere, 0.5, 5.0)
	var entry: BoardEntry = state.post_campaign_contract(contract, 1, true)
	var warned: Array[NotificationData] = []
	if entry != null:
		warned = NotificationCenter.rows_of(NotificationData.TYPE_EXPIRY_WARNING, entry.id)
	var row: NotificationData = warned[0] if warned.size() == 1 else null
	TestFixtures.check(res, "a campaign posting inside its last day stays open and is warned once as it posts",
		entry != null and entry.is_open() and entry.reach_warned and warned.size() == 1,
		"status %s warned %s rows %d hours left %.1f" % [entry.status if entry != null else "none",
		str(entry.reach_warned if entry != null else false), warned.size(),
		entry.hours_left(CampaignClock.now()) if entry != null else -1.0])
	TestFixtures.check(res, "the campaign posting's warning names it and carries the posting kind",
		entry != null and _snap_of(row, state, entry) and row.kind == state.POSTING_NOTICE_KIND, _row_text(row))
	cfg.board_expiry_min_hours = min_hours
	cfg.board_expiry_max_hours = max_hours
	_drop(state)


#True when the notice row carries the posting's name, difficulty and reward.
static func _snap_of(row: NotificationData, state: Variant, entry: BoardEntry) -> bool:
	if row == null or entry.contract == null:
		return false
	return row.name_text() == String(state.entry_name(entry)) \
		and is_equal_approx(float(row.snap.get("difficulty", -1.0)), entry.contract.difficulty) \
		and int(row.snap.get("reward", -1)) == entry.contract.reward_notes


static func _row_text(row: NotificationData) -> String:
	if row == null:
		return "no row"
	return "%s | %s | %s | urgency %d" % [row.name_text(), str(row.snap), row.kind, row.urgency]


#A team that reaches the job after its deadline fails there before any event: nothing is paid, the log says
#LATE and the loss is written to the guild record and the issuer seat.
static func _case_late_arrival(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	var seat: int = entry.issuer_id
	IssuerOpinion._set_satisfaction(seat, MID_SAT)
	entry.deadline_minute += FAR_DAYS * CampaignClock.MINUTES_PER_DAY
	entry.distance_km = LATE_KM
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid]
	var sent: bool = state.dispatch(entry.id, _active_run(uids, FARE))
	var contract_run: ContractRun = entry.scheduler.run if sent and entry.scheduler != null else null
	if contract_run != null:
		contract_run.deadline_minute = CampaignClock.now() + 1
	var banked: int = int(state.bank_notes)
	var steps: int = await _settle(state, entry)
	TestFixtures.check(res, "a run that arrives after its deadline settles Failed",
		contract_run != null and entry.status == BoardEntry.STATUS_FAILED
		and entry.verdict == BoardEntry.STATUS_FAILED and steps < _settle_cap(),
		"sent %s status %s verdict %s steps %d" % [str(sent), entry.status, entry.verdict, steps])
	TestFixtures.check(res, "the late run fails on arrival before any event",
		contract_run != null and contract_run.outcomes.is_empty()
		and contract_run.failed_event == ContractManager.LATE_EVENT,
		"outcomes %d failed %s" % [contract_run.outcomes.size() if contract_run != null else -1,
		contract_run.failed_event if contract_run != null else "no run"])
	var late_lines: int = TestFixtures.count_lines(entry.log_lines, "LATE:")
	TestFixtures.check(res, "the late run pays nothing and its log carries one LATE line",
		contract_run != null and contract_run.reward_paid == 0 and int(state.bank_notes) == banked
		and late_lines == 1,
		"reward %d bank %d was %d late lines %d" % [contract_run.reward_paid if contract_run != null else -1,
		int(state.bank_notes), banked, late_lines])
	TestFixtures.check(res, "the late loss adds a guild failure and takes 15 from the issuer seat",
		GuildRecord.guild.successes == 0 and GuildRecord.guild.failures == 1
		and IssuerOpinion.satisfaction(seat) == MID_SAT - SEAT_LOSS, _standing(seat))
	_drop(state)


#In the red only foot leaves: a horse dispatch the deadline and the fare would allow is refused, and a foot
#dispatch goes with its fare sinking the bank further.
static func _case_red_dispatch(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _open_entry(state)
	entry.deadline_minute += FAR_DAYS * CampaignClock.MINUTES_PER_DAY
	var mercs: Array[MercenaryData] = state.mercs
	var uids: Array[int] = [mercs[0].merc_uid]
	var horse_run: ActiveRun = _active_run(uids, FARE)
	horse_run.travel_mode = "horse"
	var allowed: bool = state._dispatch_allowed(entry, horse_run, CampaignClock.now())
	state.bank_notes = RED_BANK
	var refused: bool = not state.dispatch(entry.id, horse_run)
	TestFixtures.check(res, "in the red a horse dispatch the deadline and fare allow outside it is refused",
		allowed and refused and entry.is_open() and int(state.bank_notes) == RED_BANK,
		"allowed %s refused %s bank %d" % [str(allowed), str(refused), int(state.bank_notes)])
	var home_run: ActiveRun = _active_run(uids, FARE)
	home_run.return_mode = "horse"
	state.bank_notes = RED_BANK
	var home_refused: bool = not state.dispatch(entry.id, home_run)
	TestFixtures.check(res, "in the red a foot venture with a horse return is refused",
		home_refused and entry.is_open() and int(state.bank_notes) == RED_BANK,
		"refused %s status %s bank %d" % [str(home_refused), entry.status, int(state.bank_notes)])
	var sent: bool = state.dispatch(entry.id, _active_run(uids, FARE))
	TestFixtures.check(res, "in the red a foot dispatch still goes and its fare sinks the bank further",
		sent and entry.status == BoardEntry.STATUS_ACTIVE and int(state.bank_notes) == RED_BANK - FARE,
		"sent %s status %s bank %d" % [str(sent), entry.status, int(state.bank_notes)])
	_drop(state)


#Each leg is paid from what the bank holds when it comes due: a horse venture may take the whole bank while the
#return walks, and a horse return must fit what the walking venture leaves.
static func _case_split_fares(res: Dictionary) -> void:
	var state: Variant = _state()
	var entry: BoardEntry = _split_entry(state)
	var uids: Array[int] = [(state.mercs as Array[MercenaryData])[0].merc_uid]
	var horse_leg: int = _leg(entry, "horse", uids.size())
	var foot_leg: int = _leg(entry, "foot", uids.size())
	var ride: ActiveRun = _active_run(uids, horse_leg + foot_leg)
	ride.travel_mode = "horse"
	state.bank_notes = horse_leg
	var rode: bool = state.dispatch(entry.id, ride)
	TestFixtures.check(res, "a horse venture whose fare is the whole bank dispatches while the return walks",
		horse_leg > 0 and rode and entry.status == BoardEntry.STATUS_ACTIVE and int(state.bank_notes) == -foot_leg,
		"horse %d foot %d sent %s status %s bank %d" % [horse_leg, foot_leg, str(rode), entry.status,
		int(state.bank_notes)])
	_drop(state)
	state = _state()
	entry = _split_entry(state)
	uids = [(state.mercs as Array[MercenaryData])[0].merc_uid]
	var short_run: ActiveRun = _active_run(uids, foot_leg + horse_leg)
	short_run.return_mode = "horse"
	state.bank_notes = foot_leg + horse_leg - 1
	var refused: bool = not state.dispatch(entry.id, short_run)
	TestFixtures.check(res, "a foot venture whose horse return is one note over what the walk leaves is refused",
		horse_leg > 0 and refused and entry.is_open() and int(state.bank_notes) == foot_leg + horse_leg - 1,
		"horse %d foot %d refused %s status %s bank %d" % [horse_leg, foot_leg, str(refused), entry.status,
		int(state.bank_notes)])
	_drop(state)
	state = _state()
	entry = _split_entry(state)
	uids = [(state.mercs as Array[MercenaryData])[0].merc_uid]
	var home_run: ActiveRun = _active_run(uids, foot_leg + horse_leg)
	home_run.return_mode = "horse"
	state.bank_notes = foot_leg + horse_leg
	var sent: bool = state.dispatch(entry.id, home_run)
	TestFixtures.check(res, "the same horse return at exactly what the walk leaves dispatches",
		horse_leg > 0 and sent and entry.status == BoardEntry.STATUS_ACTIVE and int(state.bank_notes) == 0,
		"horse %d foot %d sent %s status %s bank %d" % [horse_leg, foot_leg, str(sent), entry.status,
		int(state.bank_notes)])
	_drop(state)


#The first open posting pushed out to a horse distance with a far deadline.
static func _split_entry(state: Variant) -> BoardEntry:
	var entry: BoardEntry = _open_entry(state)
	entry.deadline_minute += FAR_DAYS * CampaignClock.MINUTES_PER_DAY
	entry.distance_km = SPLIT_KM
	return entry


#One leg's fare the way the dispatch window prices it.
static func _leg(entry: BoardEntry, key: String, crew: int) -> int:
	return ContractPreview.leg_cost(ContractView.from_entry(entry, CampaignClock.now()), GuiTypes.travel_mode(key), crew)


static func _case_rest_status(res: Dictionary) -> void:
	var state: Variant = _state()
	var merc: MercenaryData = (state.mercs as Array[MercenaryData])[0]
	merc.rest_lockout_start = CampaignClock.now()
	merc.rest_lockout_until = CampaignClock.now() + REST_MINUTES
	merc.rest_lockout_kind = RestSystem.KIND_RESPITE
	var resting: Dictionary = state.merc_status(merc)
	TestFixtures.check(res, "rest_status", int(resting["status"]) == GuiTypes.MercStatus.RESTING,
		"status %d" % int(resting["status"]))
	TestFixtures.check(res, "rest_fraction", is_equal_approx(float(resting["fraction"]), 1.0),
		"fraction %.2f" % float(resting["fraction"]))
	TestFixtures.check(res, "rest_hours", is_equal_approx(float(resting["hours_left"]), 2.0),
		"hours %.2f" % float(resting["hours_left"]))
	merc.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	var away: Dictionary = state.merc_status(merc)
	TestFixtures.check(res, "rest_vacation", int(away["status"]) == GuiTypes.MercStatus.VACATION,
		"status %d" % int(away["status"]))
	TestFixtures.check(res, "rest_vacation_hours", is_equal_approx(float(away["hours_left"]), 2.0),
		"hours %.2f" % float(away["hours_left"]))
	merc.rest_lockout_until = 0
	merc.rest_lockout_start = -1
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


#Every move of money carries a reason and a label the ledger can print.
static func _case_money_log(res: Dictionary) -> void:
	var state: Variant = _state()
	var rec: MoneyLog = MoneyLog.new()
	state.money_logged.connect(rec.on_money)
	var bank: int = state.bank_notes
	state.charge(0, "x", "nothing")
	state.charge(-40, "x", "nothing")
	TestFixtures.check(res, "a charge of nothing or less is not a move of money",
		rec.rows.is_empty() and state.bank_notes == bank,
		"%d rows, %d notes" % [rec.rows.size(), state.bank_notes])
	state.charge(40, state.REASON_LOAN_PAYMENT, "Lender 1 - Payment")
	TestFixtures.check(res, "a charge always goes through and is logged with its label",
		state.bank_notes == bank - 40 and rec.rows.size() == 1
		and int(rec.rows[0]["delta"]) == -40
		and String(rec.rows[0]["reason"]) == state.REASON_LOAN_PAYMENT
		and String(rec.rows[0]["label"]) == "Lender 1 - Payment", "%s" % [rec.rows])
	TestFixtures.check(res, "spending what the guild has is logged the same way",
		state.spend(10, state.REASON_ODD_JOB, "Odd Job - Loan Request (Lender 5)")
		and rec.rows.size() == 2 and int(rec.rows[1]["delta"]) == -10
		and String(rec.rows[1]["label"]) == "Odd Job - Loan Request (Lender 5)",
		"%s" % [rec.rows[rec.rows.size() - 1]])
	TestFixtures.check(res, "spending more than the guild has moves and logs nothing",
		not state.spend(state.bank_notes + 1, state.REASON_LOAN_PAYOFF, "Lender 1 - Payoff")
		and rec.rows.size() == 2, "%d rows" % rec.rows.size())
	state.refund(500, state.REASON_LOAN, "Lender 2 - Loan")
	TestFixtures.check(res, "notes coming in are logged as a credit with their label",
		state.bank_notes == bank - 50 + 500 and rec.rows.size() == 3
		and int(rec.rows[2]["delta"]) == 500
		and String(rec.rows[2]["label"]) == "Lender 2 - Loan", "%s" % [rec.rows[2]])
	TestFixtures.check(res, "a charge that carries no label still logs its reason",
		state.spend(5, state.REASON_STOCK) and String(rec.rows[3]["label"]) == ""
		and String(rec.rows[3]["reason"]) == state.REASON_STOCK, "%s" % [rec.rows[3]])
	_drop(state)


#Income raises the bank without ever lowering the day's expenses.
static func _case_income_expenses(res: Dictionary) -> void:
	var state: Variant = _state()
	state.charge(300, state.REASON_LOAN_PAYMENT, "Lender 1 - Payment")
	state.refund(100, state.REASON_LOAN, "Lender 1 - Loan")
	state.refund(60, state.REASON_DIVIDEND, "Dividend")
	var income_exp: int = int(float(state._guild_metrics(0)["exp"]))
	TestFixtures.check(res, "a loan and a dividend leave the day's expenses where they were",
		income_exp == 300, "%d spent" % income_exp)
	state.charge(300, state.REASON_TRAVEL, "Travel - On Foot (x2)")
	state.refund(100, state.REASON_TRAVEL_REFUND, "Travel - On Foot (x2)")
	var travel_exp: int = int(float(state._guild_metrics(0)["exp"]))
	TestFixtures.check(res, "a travel refund comes off the day's expenses",
		travel_exp == 200, "%d spent" % travel_exp)
	TestFixtures.check(res, "every income reason is listed once",
		state.INCOME_REASONS.size() == 4 and state.INCOME_REASONS.has(state.REASON_LOAN)
		and state.INCOME_REASONS.has(state.REASON_STOCK)
		and state.INCOME_REASONS.has(state.REASON_DIVIDEND)
		and state.INCOME_REASONS.has(state.REASON_MAIL), "%s" % [state.INCOME_REASONS])
	_drop(state)


#The away registry every wave 2 manager writes into.
static func _case_away(res: Dictionary) -> void:
	var state: Variant = _state()
	TestFixtures.add_mercs(2, 1, state)
	var uids: Array[int] = []
	for merc: MercenaryData in state.mercs:
		if uids.size() < 4:
			uids.append(merc.merc_uid)
	var payroll_full: int = state.month_expenses()
	var refused: bool = not state.set_away(uids[0], GuiTypes.MercStatus.AVAILABLE) \
		and not state.set_away(uids[0], GuiTypes.MercStatus.RESTING) \
		and not state.set_away(uids[0], GuiTypes.MercStatus.CONTRACT) \
		and not state.set_away(uids[0], GuiTypes.MercStatus.VACATION)
	TestFixtures.check(res, "a status the guild is at home for cannot send a merc away",
		refused and not state.is_away(uids[0]), "away %d" % state.away_status(uids[0]))
	var back: int = CampaignClock.now() + 120
	TestFixtures.check(res, "a merc can be sent away on loan business until a minute",
		state.set_away(uids[0], GuiTypes.MercStatus.LOAN, back)
		and state.away_status(uids[0]) == GuiTypes.MercStatus.LOAN
		and state.is_away(uids[0]) and state.away_until(uids[0]) == back,
		"%d until %d" % [state.away_status(uids[0]), state.away_until(uids[0])])
	var row: Dictionary = state.merc_status(state.merc_by_uid(uids[0]))
	TestFixtures.check(res, "the roster reads the away status and the hours left of it",
		int(row["status"]) == GuiTypes.MercStatus.LOAN and float(row["hours_left"]) == 2.0,
		"%s" % [row])
	TestFixtures.check(res, "an away merc counts as busy",
		state.busy_uids().has(uids[0]), "%s" % [state.busy_uids()])
	TestFixtures.check(res, "a merc can be away with no end in sight",
		state.set_away(uids[1], GuiTypes.MercStatus.FIRED)
		and state.away_until(uids[1]) == -1
		and float(state.merc_status(state.merc_by_uid(uids[1]))["hours_left"]) == 0.0,
		"until %d" % state.away_until(uids[1]))
	TestFixtures.check(res, "a fired merc is off the payroll and everyone else is on it",
		state.payroll_mercs().size() == state.mercs.size() - 1,
		"%d of %d" % [state.payroll_mercs().size(), state.mercs.size()])
	var fired_cost: int = state.month_expenses()
	TestFixtures.check(res, "the month of salaries drops by what the fired merc cost",
		fired_cost == payroll_full - state.merc_by_uid(uids[1]).monthly_salary,
		"%d of %d" % [fired_cost, payroll_full])
	TestFixtures.check(res, "a captive is away too",
		state.set_away(uids[2], GuiTypes.MercStatus.CAPTURED)
		and state.away_status(uids[2]) == GuiTypes.MercStatus.CAPTURED,
		"away %d" % state.away_status(uids[2]))
	TestFixtures.check(res, "a status past ODD_JOB is refused",
		not state.set_away(uids[3], GuiTypes.MercStatus.ODD_JOB + 1) and not state.is_away(uids[3]),
		"away %d" % state.away_status(uids[3]))
	var odd_job_full: int = state.month_expenses()
	TestFixtures.check(res, "a merc can be sent on an odd job until a minute",
		state.set_away(uids[3], GuiTypes.MercStatus.ODD_JOB, back)
		and state.away_status(uids[3]) == GuiTypes.MercStatus.ODD_JOB
		and state.busy_uids().has(uids[3]),
		"away %d" % state.away_status(uids[3]))
	TestFixtures.check(res, "a merc on an odd job stays on the payroll",
		state.payroll_mercs().has(state.merc_by_uid(uids[3]))
		and state.month_expenses() == odd_job_full,
		"%d of %d" % [state.payroll_mercs().size(), state.mercs.size()])
	await state.process_until(back + 60)
	TestFixtures.check(res, "the minute they are due back the guild has them again",
		not state.is_away(uids[0]) and state.is_away(uids[1]) and state.is_away(uids[2])
		and not state.is_away(uids[3]),
		"%d, %d, %d, %d" % [state.away_status(uids[0]), state.away_status(uids[1]),
		state.away_status(uids[2]), state.away_status(uids[3])])
	state.clear_away(uids[1])
	state.clear_away(uids[0])
	TestFixtures.check(res, "clearing a row brings a merc back and clearing nothing is quiet",
		not state.is_away(uids[1]) and state.payroll_mercs().size() == state.mercs.size()
		and state.month_expenses() == payroll_full,
		"%d of %d, %d a month" % [state.payroll_mercs().size(), state.mercs.size(),
		state.month_expenses()])
	state.start_new_game()
	TestFixtures.check(res, "a new campaign starts with nobody away",
		not state.is_away(uids[2]) and state.away_status(uids[2]) == -1,
		"away %d" % state.away_status(uids[2]))
	_drop(state)


#The queue of removed mercs. A merc taken off the roster leaves the guild whole, and
#nothing keyed on the uid stays behind.
static func _case_removed(res: Dictionary) -> void:
	var state: Variant = _state()
	var seen: Dictionary = {"n": 0}
	var counter: Callable = func() -> void:
		seen["n"] = int(seen["n"]) + 1
	state.roster_changed.connect(counter)
	var merc: MercenaryData = state.mercs[0]
	var uid: int = merc.merc_uid
	var full: int = state.mercs.size()
	var wage: int = state.month_expenses()
	TestFixtures.check(res, "a uid nobody holds removes nobody",
		state.remove_merc(-1, "fired") == null and state.mercs.size() == full
		and state.removed_count() == 0 and int(seen["n"]) == 0,
		"%d of %d, %d removed" % [state.mercs.size(), full, state.removed_count()])
	var record: RemovedMercRecord = state.remove_merc(uid, "fired", GuiTypes.MercStatus.FIRED)
	TestFixtures.check(res, "a removal files the merc itself and what it was worth",
		record != null and record.uid == uid and record.merc == merc
		and record.reason == "fired" and record.status == GuiTypes.MercStatus.FIRED
		and record.name == merc.merc_name and record.salary == merc.monthly_salary
		and record.guild_opinion == merc.guild_opinion,
		"%s" % [record.to_dict() if record != null else {}])
	TestFixtures.check(res, "the removed merc is off the roster, the payroll and the uid keys",
		state.mercs.size() == full - 1 and state.merc_by_uid(uid) == null
		and state.roster.size() == full - 1 and not state.merc_extras.has(uid)
		and not state.pip_modes.has(uid) and not state.is_away(uid)
		and state.month_expenses() == wage - merc.monthly_salary,
		"%d of %d, %d a month" % [state.mercs.size(), full, state.month_expenses()])
	TestFixtures.check(res, "a removal tells the roster once", int(seen["n"]) == 1, str(seen["n"]))
	TestFixtures.check(res, "the queue answers by uid and by count",
		state.removed_by_uid(uid) == record and state.removed_count() == 1
		and state.removed_by_uid(-1) == null, str(state.removed_count()))
	var second: MercenaryData = state.mercs[0]
	var want_status: int = int(state.merc_status(second)["status"])
	var day: int = TrynnCalendar.day_index(CampaignClock.now())
	var quit_record: RemovedMercRecord = state.remove_merc(second.merc_uid, "left")
	TestFixtures.check(res, "a removal with no status reads the status the merc stood at",
		quit_record != null and quit_record.reason == "left"
		and quit_record.status == want_status and quit_record.day_index == day
		and quit_record.minute == CampaignClock.now() and state.removed_count() == 2
		and int(seen["n"]) == 2,
		"%s" % [quit_record.to_dict() if quit_record != null else {}])
	state.roster_changed.disconnect(counter)
	state.start_new_game()
	TestFixtures.check(res, "a new campaign starts with an empty queue",
		state.removed_count() == 0 and state.removed_by_uid(uid) == null,
		str(state.removed_count()))
	_drop(state)


#Next_payday_minute names the next salary tick, and the campaign clock lands on it.
static func _case_next_payday(res: Dictionary) -> void:
	var state: Variant = _state()
	var at: int = state.next_payday_minute()
	TestFixtures.check(res, "next_payday_minute is ahead of the clock",
		at > CampaignClock.now(), "%d vs %d" % [at, CampaignClock.now()])
	var expected: int = SalarySystem.month_expenses(state.mercs)
	var before: int = int(state.bank_notes)
	await state.process_until(at)
	TestFixtures.check(res, "next_payday_minute lands on the payroll debit",
		int(state.bank_notes) == before - expected,
		"bank %d expected %d" % [int(state.bank_notes), before - expected])
	_drop(state)


#The clock hands every manager the new minute, in the order the ledger needs.
#The probes carry the real autoload names, so they hang under a parent of their own and the state
#looks them up there: add_child renames a node that clashes with a sibling, and a probe under the
#root would be renamed while the lookup found the live autoload instead.
static func _case_tick_order(res: Dictionary) -> void:
	var state: Variant = _state()
	var trail: Array = []
	var probes: Array[Node] = []
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var parent: Node = Node.new()
	parent.name = "TickProbeRoot"
	root.add_child(parent)
	state.tick_root = "%s/" % String(parent.get_path())
	var order: Array = state.TICK_ORDER
	var expected: Array = []
	for manager: String in order:
		var probe: TickProbe = TickProbe.new()
		probe.name = manager
		probe.trail = trail
		parent.add_child(probe)
		probes.append(probe)
		expected.append(manager)
	TestFixtures.check(res, "eight managers are ticked and finance goes first",
		order.size() == 8 and String(order[0]) == "FinanceManager"
		and String(order[1]) == "FinanceLedger", "%s" % [order])
	TestFixtures.check(res, "every probe keeps the name its manager is looked up by",
		_probe_names(probes) == expected, "%s" % [_probe_names(probes)])
	var target: int = CampaignClock.now() + 60
	await state.process_until(target)
	TestFixtures.check(res, "the managers in the tree are ticked in the listed order",
		trail == expected, "%s" % [trail])
	var first: TickProbe = probes[0] as TickProbe
	var last: TickProbe = probes[probes.size() - 1] as TickProbe
	TestFixtures.check(res, "each one is told the minute the campaign reached, once",
		first.ticks.size() == 1 and first.ticks[0] == target and last.ticks.size() == 1
		and last.ticks[0] == target, "%s" % [first.ticks])
	await state.process_until(target + 60)
	TestFixtures.check(res, "the next jump ticks them all again",
		trail.size() == order.size() * 2 and (probes[1] as TickProbe).ticks.size() == 2,
		"%d calls" % trail.size())
	var dropped: Node = probes.pop_back()
	parent.remove_child(dropped)
	dropped.free()
	var short_order: Array = expected.duplicate()
	short_order.pop_back()
	trail.clear()
	await state.process_until(target + 120)
	TestFixtures.check(res, "a manager the tree does not hold is skipped without a word",
		trail == short_order, "%s" % [trail])
	for probe: Node in probes:
		parent.remove_child(probe)
		probe.free()
	root.remove_child(parent)
	parent.free()
	_drop(state)


#The one start on the autoload, whose game_started clears the managers: the Free plan, two mercs, one posting a walk
#reaches at difficulty 1.0 and quality 0.9, no seeded rows, the guild at 30 and travel from the offers; a max-out never carries.
static func _case_start(res: Dictionary) -> void:
	GameState.start_new_game()
	var now: int = CampaignClock.now()
	var entries: Array[BoardEntry] = GameState.board.entries
	var roster: int = (GameState.roster as Array[MercView]).size()
	TestFixtures.check(res, "a new game starts on the Free plan with two mercs and one posting",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE and GameState.mercs.size() == START_ROSTER
		and roster == START_ROSTER and entries.size() == OPENING_POSTINGS,
		"plan %d mercs %d roster %d postings %d" % [SubscriptionManager.plan(), GameState.mercs.size(), roster,
		entries.size()])
	var entry: BoardEntry = entries[0] if not entries.is_empty() else null
	var contract: ContractData = entry.contract if entry != null else null
	var walks: bool = entry != null and Reachability.can_reach(entry, Reachability.FOOT, now)
	TestFixtures.check(res, "the opening posting is difficulty 1.0 at quality 0.9 and a walk reaches it in time",
		contract != null and is_equal_approx(contract.difficulty, OPENING_DIFFICULTY)
		and is_equal_approx(entry.quality, OPENING_QUALITY) and walks,
		"difficulty %.2f quality %.2f foot %s" % [contract.difficulty if contract != null else -1.0,
		entry.quality if entry != null else -1.0, str(walks)])
	var seeded: Dictionary = {"ledger rows": FinanceLedger.transactions.size(), "loans": FinanceManager.loans.size(),
		"offers": FinanceManager.offers.size(), "campaigns": PromotionsManager.campaigns.size(),
		"fines": LegalManager.fines.size(),
		"captures": LegalManager.captured.size(), "holdings": StockMarket.holdings().size()}
	var rows: Array[String] = []
	for key: String in seeded:
		if int(seeded[key]) != 0:
			rows.append("%s %d" % [key, int(seeded[key])])
	TestFixtures.check(res, "a new game seeds no ledger row, loan, offer, campaign, fine, capture or holding",
		rows.is_empty(), TestFixtures.detail(rows, seeded.size(), "list"))
	var walk_ins: int = 0
	for row: ApplicantData in PromotionsManager.applicants:
		if row.pool and row.campaign_id == -1:
			walk_ins += 1
	TestFixtures.check(res, "a new game seeds the start pool of walk-in applicants and nothing else",
		walk_ins == HirePool.POOL_START and PromotionsManager.applicants.size() == HirePool.POOL_START,
		"%d walk-ins of %d" % [walk_ins, PromotionsManager.applicants.size()])
	TestFixtures.check(res, "a new game bills the guild 30 a month", FinanceLedger.guild_rate() == GUILD_RATE,
		"guild %d" % FinanceLedger.guild_rate())
	var travel: Dictionary = FinanceLedger.travel_forecast()
	var guess: Dictionary = TravelForecaster.new().fallback(GameState.day())
	TestFixtures.check(res, "a new game estimates travel from the opening offers",
		bool(travel["estimate"]) and FinanceLedger.travel_rate() > 0
		and FinanceLedger.travel_rate() == int(guess.get("total", 0)),
		"travel %d, estimate %s, guess %s" % [FinanceLedger.travel_rate(), travel["estimate"], guess])
	SubscriptionManager.max_out()
	GameState.start_new_game()
	TestFixtures.check(res, "a new game after an Enterprise max-out is the Free start again",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE and GameState.board.entries.size() == OPENING_POSTINGS,
		"plan %d postings %d" % [SubscriptionManager.plan(), GameState.board.entries.size()])


#The names the probes answer to, so a rename by the tree shows up as a failed check.
static func _probe_names(probes: Array[Node]) -> Array:
	var out: Array = []
	for probe: Node in probes:
		out.append(String(probe.name))
	return out


#Records every move of money the way a ledger screen would.
class MoneyLog extends RefCounted:
	var rows: Array[Dictionary] = []

	func on_money(delta: int, reason: String, label: String) -> void:
		rows.append({"delta": delta, "reason": reason, "label": label})


#Stands in for a wave 2 manager that is not built yet.
class TickProbe extends Node:
	var ticks: Array[int] = []
	var trail: Array = []

	func tick(now: int) -> void:
		ticks.append(now)
		trail.append(String(name))

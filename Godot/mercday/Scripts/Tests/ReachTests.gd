class_name ReachTests

#Reachability, venture gating and the auto-reject sweep.
#Run: godot --headless --path . -- --reach-tests

const HOUR := CampaignClock.MINUTES_PER_HOUR
const DAY := CampaignClock.MINUTES_PER_DAY
const STEP_CAP := 200
const ALL_KEYS: Array[String] = ["foot", "caravan", "horse", "train", "airship", "teleport"]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_base_minutes(res)
	_case_departure(res)
	await _case_arrival(res)
	_case_distance(res)
	_case_offered(res)
	_case_fares(res)
	_case_can_reach(res)
	_case_last_reach(res)
	_case_best_mode(res)
	_case_expiry(res)
	_case_auto_reject(res)
	_case_plan_travel(res)
	GenPlaceTests.add_cases(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "REACH")


#A posting this far out with this deadline (0 is unbounded) and these hours of work once there.
static func _entry(km: int, deadline: int, hours: int = 8) -> BoardEntry:
	var entry: BoardEntry = BoardEntry.new()
	entry.distance_km = km
	entry.deadline_minute = deadline
	entry.completion_hours = hours
	return entry


static func _case_base_minutes(res: Dictionary) -> void:
	TestFixtures.check(res, "foot covers 30 km in one day", Reachability.base_minutes("foot", 30) == DAY,
		"got %d" % Reachability.base_minutes("foot", 30))
	var foot_31: int = Reachability.base_minutes("foot", 31)
	TestFixtures.check(res, "foot 31 km runs past one day, minute for minute as GameState.travel_minutes",
		foot_31 > DAY and foot_31 == GameState.travel_minutes("foot", 31),
		"got %d travel_minutes %d" % [foot_31, GameState.travel_minutes("foot", 31)])
	TestFixtures.check(res, "an airship covers 300 km in one day",
		Reachability.base_minutes("airship", 300) == DAY,
		"got %d" % Reachability.base_minutes("airship", 300))
	TestFixtures.check(res, "teleport takes no time at any distance",
		Reachability.base_minutes("teleport", 0) == 0 and Reachability.base_minutes("teleport", 900) == 0,
		"got %d and %d" % [Reachability.base_minutes("teleport", 0), Reachability.base_minutes("teleport", 900)])
	var odd: Array[String] = []
	for key: String in ALL_KEYS + ["glider"]:
		for km: int in [0, 10, 31, 125, 240]:
			if Reachability.base_minutes(key, km) != GameState.travel_minutes(key, km):
				odd.append("%s %d" % [key, km])
	TestFixtures.check(res, "every leg prices in the minutes GameState.travel_minutes gives", odd.is_empty(),
		"differ %s" % str(odd))


static func _case_departure(res: Dictionary) -> void:
	var noon: int = 12 * HOUR
	TestFixtures.check(res, "a daytime order leaves at once", Reachability.departure_minute(noon) == noon,
		"got %d" % Reachability.departure_minute(noon))
	TestFixtures.check(res, "a 23:00 order waits for the next 6:00",
		Reachability.departure_minute(23 * HOUR) == DAY + 6 * HOUR,
		"got %d" % Reachability.departure_minute(23 * HOUR))
	var dawn: int = DAY + 5 * HOUR + 59
	TestFixtures.check(res, "a 5:59 order leaves at 6:00 the same day",
		Reachability.departure_minute(dawn) == DAY + 6 * HOUR,
		"got %d" % Reachability.departure_minute(dawn))
	TestFixtures.check(res, "22:00 is already night and 6:00 is already day",
		Reachability.departure_minute(22 * HOUR) == DAY + 6 * HOUR
		and Reachability.departure_minute(DAY + 6 * HOUR) == DAY + 6 * HOUR,
		"got %d and %d" % [Reachability.departure_minute(22 * HOUR),
			Reachability.departure_minute(DAY + 6 * HOUR)])


static func _case_arrival(res: Dictionary) -> void:
	TestFixtures.check(res, "600 minutes from 8:00 arrive at 18:00 the same day",
		Reachability.arrival_minute(8 * HOUR, 600) == 18 * HOUR,
		"got %d" % Reachability.arrival_minute(8 * HOUR, 600))
	TestFixtures.check(res, "no travel arrives on departure",
		Reachability.arrival_minute(8 * HOUR, 0) == 8 * HOUR,
		"got %d" % Reachability.arrival_minute(8 * HOUR, 0))
	TestFixtures.check(res, "a leg that ends on 22:00 arrives without a camp",
		Reachability.arrival_minute(6 * HOUR, 16 * HOUR) == 22 * HOUR,
		"got %d" % Reachability.arrival_minute(6 * HOUR, 16 * HOUR))
	await _parity(res, "foot", 30, 8 * HOUR)
	await _parity(res, "horse", 120, 21 * HOUR)
	await _parity(res, "caravan", 60, 23 * HOUR)


#A real scheduler leaves when the dispatch would (a night order is queued to 6:00) and must log its travel out
#line on the minute Reachability predicts.
static func _parity(res: Dictionary, mode_key: String, km: int, order_minute: int) -> void:
	CampaignClock.reset()
	var depart: int = Reachability.departure_minute(order_minute)
	CampaignClock.advance_to(depart)
	EventTrigger.missed_respites = 0
	var team: Array[MercenaryData] = TestFixtures.generated_team(2, 4)
	GuildRoster.set_roster(team)
	var contract_run: ContractRun = TestFixtures.run_for(team, ContractGenerator.generate("Military"))
	var scheduler: ContractScheduler = ContractScheduler.create(contract_run,
		GameState.travel_minutes(mode_key, km), CampaignClock.now())
	var arrived: int = -1
	var steps: int = 0
	while arrived < 0 and not scheduler.is_done() and steps < STEP_CAP:
		CampaignClock.advance_to(scheduler.next_due())
		if scheduler.phase == ContractScheduler.Phase.NIGHT:
			EventTrigger.forced_d100 = 100
		var seen: int = contract_run.log_lines.size()
		await scheduler.step()
		for i: int in range(seen, contract_run.log_lines.size()):
			if contract_run.log_lines[i].contains("travel out"):
				arrived = CampaignClock.now()
		steps += 1
	var want: int = Reachability.arrival_minute(depart, Reachability.base_minutes(mode_key, km))
	TestFixtures.check(res, "%d km by %s ordered at minute %d arrives when the scheduler does"
		% [km, mode_key, order_minute], arrived == want and arrived > depart,
		"scheduler %d predicted %d depart %d" % [arrived, want, depart])
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	for merc: MercenaryData in team:
		merc.on_contract = false


static func _case_distance(res: Dictionary) -> void:
	TestFixtures.check(res, "foot is offered at no distance at all", Reachability.distance_ok("foot", 0),
		"foot at 0 km barred")
	TestFixtures.check(res, "a caravan is barred at 15 km and offered at 16",
		not Reachability.distance_ok("caravan", 15) and Reachability.distance_ok("caravan", 16),
		"15 %s 16 %s" % [Reachability.distance_ok("caravan", 15), Reachability.distance_ok("caravan", 16)])
	var gates: Dictionary = {"caravan": 15, "horse": 22, "train": 60, "airship": 125, "teleport": 125}
	for key: String in gates:
		var gate: int = int(gates[key])
		TestFixtures.check(res, "%s is barred at %d km and offered just past it" % [key, gate],
			not Reachability.distance_ok(key, gate) and Reachability.distance_ok(key, gate + 1),
			"%d %s %d %s" % [gate, Reachability.distance_ok(key, gate), gate + 1,
				Reachability.distance_ok(key, gate + 1)])
	TestFixtures.check(res, "an unknown mode is never offered", not Reachability.distance_ok("glider", 900),
		"glider offered")


static func _case_offered(res: Dictionary) -> void:
	var near: BoardEntry = _entry(10, 0)
	var far: BoardEntry = _entry(200, 0)
	TestFixtures.check(res, "10 km offers foot only", Reachability.offered_modes(near, 1000, true) == ["foot"],
		"got %s" % str(Reachability.offered_modes(near, 1000, true)))
	TestFixtures.check(res, "200 km with the permit offers all six",
		Reachability.offered_modes(far, 1000, true) == ALL_KEYS,
		"got %s" % str(Reachability.offered_modes(far, 1000, true)))
	TestFixtures.check(res, "200 km without the permit offers five, no teleport",
		Reachability.offered_modes(far, 1000, false) == ["foot", "caravan", "horse", "train", "airship"],
		"got %s" % str(Reachability.offered_modes(far, 1000, false)))
	TestFixtures.check(res, "in the red only foot is offered", Reachability.offered_modes(far, -1, true) == ["foot"],
		"got %s" % str(Reachability.offered_modes(far, -1, true)))
	TestFixtures.check(res, "no posting offers nothing", Reachability.offered_modes(null, 1000, true).is_empty(),
		"got %s" % str(Reachability.offered_modes(null, 1000, true)))


static func _case_fares(res: Dictionary) -> void:
	TestFixtures.check(res, "a fare of 5 fits a bank of 10", Reachability.fare_ok("horse", 5, 10), "barred")
	TestFixtures.check(res, "a fare of 15 does not fit a bank of 10", not Reachability.fare_ok("horse", 15, 10),
		"passed")
	TestFixtures.check(res, "in the red foot still walks", Reachability.fare_ok("foot", 5, -1), "barred")
	TestFixtures.check(res, "in the red a horse is barred", not Reachability.fare_ok("horse", 5, -1), "passed")
	TestFixtures.check(res, "foot walks on an empty bank whatever the fare",
		Reachability.fare_ok(Reachability.FOOT, 999, 0), "barred")
	TestFixtures.check(res, "foot walks deep in the red", Reachability.fare_ok(Reachability.FOOT, 5, -100), "barred")
	TestFixtures.check(res, "a horse fare of 50 does not fit a bank of 10", not Reachability.fare_ok("horse", 50, 10),
		"passed")
	TestFixtures.check(res, "a horse fare equal to the bank fits", Reachability.fare_ok("horse", 10, 10), "barred")
	var foot_zero: int = DispatchLogic.travel_cost(GuiTypes.travel_mode("foot"), 3, 2, 0)
	TestFixtures.check(res, "foot at 0 km bills one day for the team", foot_zero == 3, "got %d" % foot_zero)


static func _case_can_reach(res: Dictionary) -> void:
	var now: int = 8 * HOUR
	var unset: int = Reachability.completion_minutes(_entry(10, 0, 0))
	var ten: int = Reachability.completion_minutes(_entry(10, 0, 10))
	TestFixtures.check(res, "an unset completion time reads eight hours, a set one its own",
		unset == 480 and Reachability.completion_minutes(null) == 480 and ten == 600,
		"got %d %d %d" % [unset, Reachability.completion_minutes(null), ten])
	TestFixtures.check(res, "a day of slack at 10 km reaches on foot",
		Reachability.can_reach(_entry(10, now + DAY), "foot", now), "late")
	TestFixtures.check(res, "600 minutes of slack at 10 km does not",
		not Reachability.can_reach(_entry(10, now + 600), "foot", now), "reached")
	TestFixtures.check(res, "an unbounded posting is always in reach",
		Reachability.can_reach(_entry(900, 0), "foot", now)
		and Reachability.can_reach(_entry(900, 0), "foot", 23 * HOUR), "late")
	TestFixtures.check(res, "no posting is never in reach", not Reachability.can_reach(null, "foot", now), "reached")


static func _case_last_reach(res: Dictionary) -> void:
	var now: int = 8 * HOUR
	var near_timed: BoardEntry = _entry(10, DAY + 12 * HOUR)
	var far_timed: BoardEntry = _entry(120, now + 4 * DAY)
	var pairs: Array = [[near_timed, "foot"], [far_timed, "horse"]]
	for pair: Array in pairs:
		var entry: BoardEntry = pair[0]
		var key: String = pair[1]
		var last: int = Reachability.last_reach_minute(entry, key, now)
		TestFixtures.check(res, "the last %s departure to %d km reaches and the next minute does not"
			% [key, entry.distance_km], last >= now and Reachability.can_reach(entry, key, last)
			and not Reachability.can_reach(entry, key, last + 1), "last %d" % last)
	TestFixtures.check(res, "foot to 10 km by 12:00 the next day must leave by 14:00",
		Reachability.last_reach_minute(near_timed, "foot", now) == 14 * HOUR,
		"got %d" % Reachability.last_reach_minute(near_timed, "foot", now))
	TestFixtures.check(res, "a posting already out of reach has no last minute",
		Reachability.last_reach_minute(_entry(10, now + 600), "foot", now) == -1,
		"got %d" % Reachability.last_reach_minute(_entry(10, now + 600), "foot", now))
	TestFixtures.check(res, "an unbounded posting has no last minute",
		Reachability.last_reach_minute(_entry(10, 0), "foot", now) == -1,
		"got %d" % Reachability.last_reach_minute(_entry(10, 0), "foot", now))


static func _case_best_mode(res: Dictionary) -> void:
	var now: int = 8 * HOUR
	var far: BoardEntry = _entry(200, 0)
	var fares: Array[String] = []
	for key: String in ALL_KEYS:
		fares.append("%s %d" % [key, Reachability.outbound_cost(key, 200, 1)])
	TestFixtures.check(res, "a deep bank with the permit teleports",
		Reachability.best_mode(far, now, 1000, true, 1) == "teleport",
		"got %s fares %s" % [Reachability.best_mode(far, now, 1000, true, 1), str(fares)])
	TestFixtures.check(res, "a bank of 30 takes the fastest mode it can pay",
		Reachability.best_mode(far, now, 30, true, 1) == "foot",
		"got %s fares %s" % [Reachability.best_mode(far, now, 30, true, 1), str(fares)])
	TestFixtures.check(res, "a bank of 250 rides the train, not the dearer airship",
		Reachability.best_mode(far, now, 250, true, 1) == "train",
		"got %s fares %s" % [Reachability.best_mode(far, now, 250, true, 1), str(fares)])
	TestFixtures.check(res, "without the permit the airship is the fastest",
		Reachability.best_mode(far, now, 1000, false, 1) == "airship",
		"got %s" % Reachability.best_mode(far, now, 1000, false, 1))
	TestFixtures.check(res, "in the red the best is foot when foot reaches in time",
		Reachability.best_mode(far, now, -1, true, 1) == "foot",
		"got %s" % Reachability.best_mode(far, now, -1, true, 1))
	var day_out: BoardEntry = _entry(200, now + DAY)
	TestFixtures.check(res, "in the red with foot too slow there is no best mode",
		Reachability.best_mode(day_out, now, -1, true, 1) == "",
		"got %s" % Reachability.best_mode(day_out, now, -1, true, 1))
	var two_days: BoardEntry = _entry(200, now + 2 * DAY)
	TestFixtures.check(res, "modes in time drop the ones that miss the deadline",
		Reachability.modes_in_time(two_days, now, 1000, true) == ["train", "airship", "teleport"],
		"got %s" % str(Reachability.modes_in_time(two_days, now, 1000, true)))


static func _case_expiry(res: Dictionary) -> void:
	var now: int = 8 * HOUR
	var near_timed: BoardEntry = _entry(10, DAY + 12 * HOUR)
	var near_expiry: int = Reachability.expiry_minute(near_timed, now, 1000, false, 1)
	TestFixtures.check(res, "a posting expires the minute after the last departure of its best mode",
		near_expiry == Reachability.last_reach_minute(near_timed, "foot", now) + 1 and near_expiry == 14 * HOUR + 1,
		"got %d" % near_expiry)
	var far_timed: BoardEntry = _entry(200, now + 3 * DAY)
	var far_expiry: int = Reachability.expiry_minute(far_timed, now, 1000, true, 1)
	TestFixtures.check(res, "a teleport posting expires at 22:00 on the last day it can still leave",
		far_expiry == Reachability.last_reach_minute(far_timed, "teleport", now) + 1
		and far_expiry == 2 * DAY + 22 * HOUR, "got %d" % far_expiry)
	TestFixtures.check(res, "a posting nothing can reach expires now",
		Reachability.expiry_minute(_entry(10, now + 600), now, 1000, false, 1) == now,
		"got %d" % Reachability.expiry_minute(_entry(10, now + 600), now, 1000, false, 1))
	TestFixtures.check(res, "an unbounded posting never expires",
		Reachability.expiry_minute(_entry(10, 0), now, 1000, false, 1) == -1,
		"got %d" % Reachability.expiry_minute(_entry(10, 0), now, 1000, false, 1))
	TestFixtures.check(res, "the warning lands a day before expiry",
		Reachability.warning_minute(near_expiry) == near_expiry - DAY,
		"got %d" % Reachability.warning_minute(near_expiry))


static func _case_auto_reject(res: Dictionary) -> void:
	var now: int = 8 * HOUR
	TestFixtures.check(res, "an unbounded posting has no auto-reject minute",
		Reachability.auto_reject_minute(_entry(10, 0), Reachability.MODES, now) == -1,
		"got %d" % Reachability.auto_reject_minute(_entry(10, 0), Reachability.MODES, now))
	var hopeless: BoardEntry = _entry(10, now + HOUR)
	TestFixtures.check(res, "a deadline no mode can meet auto-rejects now",
		Reachability.auto_reject_minute(hopeless, Reachability.MODES, now) == now,
		"got %d" % Reachability.auto_reject_minute(hopeless, Reachability.MODES, now))
	var timed: Array[BoardEntry] = [_entry(10, DAY + 12 * HOUR), _entry(120, now + 4 * DAY), _entry(200, now + 2 * DAY)]
	var off: Array[String] = []
	for entry: BoardEntry in timed:
		var latest: int = -1
		for key: String in Reachability.MODES:
			latest = maxi(latest, Reachability.last_reach_minute(entry, key, now))
		var got: int = Reachability.auto_reject_minute(entry, Reachability.MODES, now)
		if latest < now or got != latest + 1:
			off.append("%d km got %d latest %d" % [entry.distance_km, got, latest])
	TestFixtures.check(res, "a reachable posting auto-rejects one minute past the latest departure of any mode",
		off.is_empty(), "off %s" % str(off))
	var foot_only: Array[String] = [Reachability.FOOT]
	var every: Array[BoardEntry] = [hopeless, _entry(10, 0)]
	every.append_array(timed)
	var later: Array[String] = []
	for entry: BoardEntry in every:
		var by_foot: int = Reachability.auto_reject_minute(entry, foot_only, now)
		var by_any: int = Reachability.auto_reject_minute(entry, Reachability.MODES, now)
		if by_foot > by_any:
			later.append("%d km foot %d any %d" % [entry.distance_km, by_foot, by_any])
	TestFixtures.check(res, "foot alone never auto-rejects later than every mode together", later.is_empty(),
		"later %s" % str(later))


static func _case_plan_travel(res: Dictionary) -> void:
	var modes: Array[Dictionary] = GuiTypes.TRAVEL_MODES
	var keys: Array = ALL_KEYS.duplicate()
	var train_fare: int = DispatchLogic.travel_cost(GuiTypes.travel_mode("train"), 3, 2, 100)
	var dear: Dictionary = DispatchLogic.plan_travel(modes, 1000, 3, 2, 100, ["train", "airship"], keys)
	TestFixtures.check(res, "no reward cap: a venture dearer than a tenth of a 500 reward goes when cheapest",
		_key(dear, "venture") == "train" and _key(dear, "ret") == "foot" and train_fare > 50,
		"got %s then %s fare %d" % [_key(dear, "venture"), _key(dear, "ret"), train_fare])
	var gated: Dictionary = DispatchLogic.plan_travel(modes, 1000, 3, 2, 100, ["horse", "airship"], keys)
	TestFixtures.check(res, "the venture never leaves the in-time keys, even for cheaper foot",
		_key(gated, "venture") == "horse" and _key(gated, "ret") == "foot",
		"got %s then %s" % [_key(gated, "venture"), _key(gated, "ret")])
	var horse_fare: int = DispatchLogic.travel_cost(GuiTypes.travel_mode("horse"), 3, 2, 100)
	var exact: Dictionary = DispatchLogic.plan_travel(modes, train_fare + horse_fare, 3, 2, 100, ["train"],
		["horse", "airship"])
	TestFixtures.check(res, "the return comes from the return keys and what the venture leaves",
		_key(exact, "venture") == "train" and _key(exact, "ret") == "horse",
		"got %s then %s" % [_key(exact, "venture"), _key(exact, "ret")])
	var short: Dictionary = DispatchLogic.plan_travel(modes, train_fare + horse_fare - 1, 3, 2, 100, ["train"],
		["horse", "airship"])
	TestFixtures.check(res, "a return the leftover notes cannot pay stays empty",
		_key(short, "venture") == "train" and (short["ret"] as Dictionary).is_empty(),
		"got %s then %s" % [_key(short, "venture"), str(short["ret"])])
	var foot_fare: int = DispatchLogic.travel_cost(GuiTypes.travel_mode("foot"), 3, 2, 100)
	var broke: Dictionary = DispatchLogic.plan_travel(modes, 5, 3, 2, 100, keys, keys)
	TestFixtures.check(res, "with five notes foot still goes both ways though its fare is above the bank",
		_key(broke, "venture") == "foot" and _key(broke, "ret") == "foot" and foot_fare > 5,
		"got %s then %s fare %d" % [_key(broke, "venture"), _key(broke, "ret"), foot_fare])
	var paid: Array = ["caravan", "horse", "train", "airship", "teleport"]
	var priced_out: Dictionary = DispatchLogic.plan_travel(modes, 5, 3, 2, 100, paid, paid)
	TestFixtures.check(res, "no paid mode fits five notes, so both legs stay empty",
		(priced_out["venture"] as Dictionary).is_empty() and (priced_out["ret"] as Dictionary).is_empty(),
		"got %s" % str(priced_out))
	var red: Dictionary = DispatchLogic.plan_travel(modes, -1, 3, 2, 100, ["foot"], ["foot"])
	TestFixtures.check(res, "in the red the guild still walks both ways at a cost above the bank",
		_key(red, "venture") == "foot" and _key(red, "ret") == "foot" and foot_fare > -1,
		"got %s then %s fare %d" % [_key(red, "venture"), _key(red, "ret"), foot_fare])


static func _key(plan: Dictionary, side: String) -> String:
	return str((plan.get(side, {}) as Dictionary).get("key", ""))

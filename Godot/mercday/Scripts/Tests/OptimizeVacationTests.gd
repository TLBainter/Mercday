class_name OptimizeVacationTests

#Mail plan M2: Optimize's vacation screen, the PENDING odds penalty and the trip day span. Plan tests 112-114.
#Run inside the gui-mail-tests harness flag.

const WINDOW: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchWindow.tscn")
const DAY: int = CampaignClock.MINUTES_PER_DAY
#DispatchWindow._best_unplaced takes the free merc with the highest solo net however low (card 659). SUNK_ROW docks
#every merc 1 percent, down to the old -1 floor, and LOW_ROW docks a merc of cognition 1 another 4.
const SUNK_ROW: Dictionary = {"expr": "team.merc_count >= 1", "percent": 1.0}
const LOW_ROW: Dictionary = {"expr": "cognition <= 1", "percent": 4.0}


static func run(res: Dictionary, host: Node) -> void:
	_case_trip_days(res)
	_case_screen(res)
	_case_penalty(res)
	_case_unscreened(res)
	await _case_fill(res, host)
	await _case_fill_sunk(res, host)


#A stub odds function: the summed weights of the team as a 0..1 chance.
static func _request(uids: Array[int], weights: Dictionary) -> Dictionary:
	return {
		"uids": uids,
		"lo": 1,
		"cap": 1,
		"seed": 7,
		"chance_fn": func(team: Array[int], _leader: int) -> float:
			var sum: int = 0
			for uid: int in team:
				sum += int(weights.get(uid, 0))
			return sum / 100.0,
		"mode_fn": func(_team: Array[int]) -> Dictionary: return {"mode": "foot", "cost": 0},
		"features_fn": func(_uid: int) -> int: return 0,
		"solo_fn": func(_uid: int) -> float: return 0.0,
		"name_fn": func(uid: int) -> String: return "M%d" % uid,
	}


static func _views(uids: Array[int]) -> Array[MercView]:
	var out: Array[MercView] = []
	for uid: int in uids:
		var view := MercView.new()
		view.uid = uid
		out.append(view)
	return out


static func _uids_of(views: Array[MercView]) -> Array[int]:
	var out: Array[int] = []
	for view: MercView in views:
		out.append(view.uid)
	return out


#The screened plan, as DispatchWindow.optimize builds it: the pool's uids and the penalised odds.
static func _screened(views: Array[MercView], book: VacationBook, from_day: int, to_day: int,
		weights: Dictionary) -> Dictionary:
	var screen: Dictionary = DispatchLogic.vacation_screen(views, book, from_day, to_day)
	var request: Dictionary = _request(_uids_of(screen["pool"] as Array[MercView]), weights)
	request["chance_fn"] = DispatchLogic.vacation_odds(request["chance_fn"] as Callable, screen["pending"] as Array[int])
	return DispatchLogic.optimize_plan(request)


static func _book_with(rows: Array[VacationRequest]) -> VacationBook:
	var book := VacationBook.new()
	book.rows.append_array(rows)
	return book


static func _case_trip_days(res: Dictionary) -> void:
	var d: int = 200
	var night: Vector2i = DispatchLogic.trip_days(d * DAY + 23 * 60, 10.0)
	var long_day: Vector2i = DispatchLogic.trip_days(d * DAY + 10 * 60, 30.0)
	var short_day: Vector2i = DispatchLogic.trip_days(d * DAY + 10 * 60, 10.0)
	TestFixtures.check(res, "112 trip_days: 23:00 starts the next day; 10:00 with 30 h ends a day later, with 10 h the same day",
		night.x == d + 1 and long_day == Vector2i(d, d + 1) and short_day == Vector2i(d, d),
		"night %s 30 h %s 10 h %s" % [night, long_day, short_day])


static func _case_screen(res: Dictionary) -> void:
	var from_day: int = 300
	var to_day: int = 304
	var weights: Dictionary = {1: 60, 2: 40, 3: 30}
	var views: Array[MercView] = _views([1, 2, 3] as Array[int])
	var rows: Array[VacationRequest] = [
		GuiVacationTests._row(1, to_day, 3, VacationRequest.State.APPROVED),
		GuiVacationTests._row(2, from_day - 3, 3, VacationRequest.State.APPROVED),
		GuiVacationTests._row(3, to_day + 1, 2, VacationRequest.State.TAKEN),
	]
	var book: VacationBook = _book_with(rows)
	var screen: Dictionary = DispatchLogic.vacation_screen(views, book, from_day, to_day)
	var plan: Dictionary = _screened(views, book, from_day, to_day, weights)
	var team: Array[int] = plan["team"]
	TestFixtures.check(res, "112 an APPROVED row over the trip leaves the best merc out; rows the day before or after do not",
		_uids_of(screen["pool"] as Array[MercView]) == [2, 3] and (screen["pending"] as Array[int]).is_empty()
			and team == [2],
		"pool %s pending %s team %s" % [_uids_of(screen["pool"] as Array[MercView]), screen["pending"], team])


static func _case_penalty(res: Dictionary) -> void:
	var from_day: int = 300
	var to_day: int = 302
	var views: Array[MercView] = _views([1, 2, 3] as Array[int])
	var rows: Array[VacationRequest] = [GuiVacationTests._row(1, from_day + 1, 4, VacationRequest.State.PENDING)]
	var book: VacationBook = _book_with(rows)
	var near: Dictionary = _screened(views, book, from_day, to_day, {1: 69, 2: 50, 3: 40})
	var far: Dictionary = _screened(views, book, from_day, to_day, {1: 71, 2: 50, 3: 40})
	TestFixtures.check(res, "113 a PENDING merc 19 points ahead is left out, 21 points ahead is picked (penalty 20)",
		(near["team"] as Array[int]) == [2] and (far["team"] as Array[int]) == [1]
			and DispatchLogic.VACATION_PENALTY == 20,
		"19 ahead %s 21 ahead %s" % [near["team"], far["team"]])


static func _case_unscreened(res: Dictionary) -> void:
	var weights: Dictionary = {1: 12, 2: 5, 3: 30, 4: 8, 5: 22, 6: 3, 7: 17, 8: 9, 9: 26, 10: 14}
	var uids: Array[int] = []
	for uid: int in range(1, 11):
		uids.append(uid)
	var views: Array[MercView] = _views(uids)
	var plain_request: Dictionary = _request(uids, weights)
	plain_request["cap"] = 4
	var plain: Dictionary = DispatchLogic.optimize_plan(plain_request)
	var screen: Dictionary = DispatchLogic.vacation_screen(views, _book_with([] as Array[VacationRequest]), 1, 9)
	var request: Dictionary = _request(_uids_of(screen["pool"] as Array[MercView]), weights)
	request["cap"] = 4
	request["chance_fn"] = DispatchLogic.vacation_odds(request["chance_fn"] as Callable, screen["pending"] as Array[int])
	var screened: Dictionary = DispatchLogic.optimize_plan(request)
	TestFixtures.check(res, "114 with no vacation rows the screened picks and leader equal the unscreened result",
		screened["team"] == plain["team"] and int(screened["leader_uid"]) == int(plain["leader_uid"])
			and is_equal_approx(float(screened["p"]), float(plain["p"])),
		"screened %s plain %s" % [screened, plain])


#A view of the first open posting with a copy of its contract stripped of boosts, penalties and the primary event, so
#every merc's solo net is 0 whatever the generators rolled.
static func _open_view() -> ContractView:
	if GameState.board == null:
		return null
	for entry: BoardEntry in GameState.board.available():
		if entry == null or entry.contract == null:
			continue
		var view: ContractView = ContractView.from_entry(entry, CampaignClock.now())
		var neutral: ContractData = entry.contract.duplicate(true) as ContractData
		var no_penalties: Array[Dictionary] = []
		neutral.stat_boosts = {}
		neutral.circumstance_boosts = {}
		neutral.tool_boosts = {}
		neutral.knowledge_boosts = {}
		neutral.tradition_boosts = {}
		neutral.penalties = no_penalties
		neutral.assigned_primary_event = ""
		view.contract = neutral
		return view
	return null


#_fill_to_minimum on a one slot window: an APPROVED row bars the top scorer; a PENDING one is taken only when alone.
static func _case_fill(res: Dictionary, host: Node) -> void:
	seed(7)
	GuiVacationTests._fresh()
	BenefitsManager.book.rows.clear()
	var view: ContractView = _open_view()
	if view == null:
		TestFixtures.check(res, "112 the board lists an open posting for the dispatch window", false, "none")
		return
	view.merc_min = 1
	view.merc_max = 1
	var window: DispatchWindow = WINDOW.instantiate()
	window.contract = view
	host.add_child(window)
	await host.get_tree().process_frame
	window.optimize()
	var plain_team: Array[int] = window.team_uids()
	var plain_roles: Array[String] = window.roles.duplicate()
	var unscreened: Dictionary = DispatchLogic.optimize_plan(window.optimize_request())
	TestFixtures.check(res, "114 the window's Optimize with no vacation rows equals the unscreened plan",
		window.last_plan["team"] == unscreened["team"] and plain_team == (unscreened["team"] as Array[int])
			and plain_roles[0] == ContractResultData.ROLE_LEADER,
		"window %s unscreened %s" % [window.last_plan["team"], unscreened["team"]])
	var scores: Dictionary = window.scores_for(0)
	var ranked: Array[int] = _uids_of(window.candidates)
	ranked.sort_custom(func(a: int, b: int) -> bool: return float(scores.get(a, 0.0)) > float(scores.get(b, 0.0)))
	window._screen = {}
	var top: int = _refill(window)
	var trip: Vector2i = DispatchLogic.trip_days(CampaignClock.now(), 24.0)
	var barred: VacationBook = _book_with([GuiVacationTests._row(top, trip.x, 2, VacationRequest.State.APPROVED)]
		as Array[VacationRequest])
	var picks: Array[int] = []
	window._screen = DispatchLogic.vacation_screen(window.candidates, barred, trip.x, trip.y)
	picks.append(_refill(window))
	var asked: VacationBook = _book_with([GuiVacationTests._row(top, trip.x, 2, VacationRequest.State.PENDING)]
		as Array[VacationRequest])
	window._screen = DispatchLogic.vacation_screen(window.candidates, asked, trip.x, trip.y)
	picks.append(_refill(window))
	var alone: Array[MercView] = []
	for candidate: MercView in window.candidates:
		if candidate.uid == top:
			alone.append(candidate)
	var only: Array[int] = [top]
	window._screen = {"pool": alone, "pending": only}
	picks.append(_refill(window))
	window._screen = {}
	window.queue_free()
	await host.get_tree().process_frame
	TestFixtures.check(res, "112/113 _fill_to_minimum never takes a barred merc; a PENDING one only when no other is left",
		ranked.size() >= 2 and top != 0 and picks[0] != top and picks[0] != 0 and picks[1] != top and picks[1] != 0
			and picks[2] == top,
		"top %d of %s picks %s scores %s" % [top, ranked, picks, scores])


#A two slot window over three fixture mercs netting -5, -1 and -1 in pool order: the fill reaches merc_min, takes the
#higher net first and a tie in pool order, a PENDING merc only when no other is left, and nobody from an empty pool.
static func _case_fill_sunk(res: Dictionary, host: Node) -> void:
	seed(7)
	GuiVacationTests._fresh()
	var view: ContractView = _open_view()
	if view == null:
		TestFixtures.check(res, "the board lists an open posting for the sunk dispatch window", false, "none")
		return
	var rows: Array[Dictionary] = [SUNK_ROW, LOW_ROW]
	view.contract.penalties = rows
	view.merc_min = 2
	view.merc_max = 2
	var window: DispatchWindow = WINDOW.instantiate()
	window.contract = view
	host.add_child(window)
	await host.get_tree().process_frame
	window.candidates = _fixture_views([1, 2, 2] as Array[int])
	var pool: Array[int] = _uids_of(window.candidates)
	var low: int = pool[0]
	var mid: int = pool[1]
	var last: int = pool[2]
	var scores: Dictionary = window.scores_for(0)
	var nets: Array[float] = [float(scores.get(low, 0.0)), float(scores.get(mid, 0.0)), float(scores.get(last, 0.0))]
	var trip: Vector2i = DispatchLogic.trip_days(CampaignClock.now(), 24.0)
	var ask: int = VacationRequest.State.PENDING
	var off: int = VacationRequest.State.APPROVED
	var full: Array[int] = _team_from(window, {})
	var asked: Array[int] = _team_from(window, _screen_for(window, trip, {mid: ask}))
	var alone: Array[int] = _team_from(window, _screen_for(window, trip, {mid: ask, last: off}))
	var none: Array[int] = _team_from(window, _screen_for(window, trip, {low: off, mid: off, last: off}))
	window._screen = {}
	window.queue_free()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Optimize's fill reaches merc_min when every free merc nets -1 or lower",
		nets == [-5.0, -1.0, -1.0] and full.size() == view.merc_min, "nets %s team %s" % [nets, full])
	TestFixtures.check(res, "the fill takes the highest net first and a tie in pool order",
		full == [mid, last], "team %s pool %s" % [full, pool])
	TestFixtures.check(res, "the fill takes a PENDING merc only when no other is left, even over a lower net",
		asked == [last, low] and alone == [low, mid], "asked %s alone %s pool %s" % [asked, alone, pool])
	TestFixtures.check(res, "an empty pool leaves the team short and the fill returns", none.is_empty(),
		"team %s" % [none])


static func _refill(window: DispatchWindow) -> int:
	window.clear_team()
	window._fill_to_minimum()
	var team: Array[int] = window.team_uids()
	return team[0] if not team.is_empty() else 0


static func _team_from(window: DispatchWindow, screen: Dictionary) -> Array[int]:
	window._screen = screen
	_refill(window)
	return window.team_uids()


#Candidate views over hand-set fixture mercs, one per cognition value, in pool order.
static func _fixture_views(cognitions: Array[int]) -> Array[MercView]:
	var out: Array[MercView] = []
	for cognition: int in cognitions:
		var view := MercView.new()
		view.merc = TestFixtures.fixed_merc("Sunk %d" % out.size(), {"cognition": cognition})
		view.uid = view.merc.merc_uid
		out.append(view)
	return out


#Optimize's vacation screen over the window's candidates with a two day row from the trip's first day per uid given.
static func _screen_for(window: DispatchWindow, trip: Vector2i, states: Dictionary) -> Dictionary:
	var rows: Array[VacationRequest] = []
	for uid: int in states:
		rows.append(GuiVacationTests._row(uid, trip.x, 2, int(states[uid])))
	return DispatchLogic.vacation_screen(window.candidates, _book_with(rows), trip.x, trip.y)

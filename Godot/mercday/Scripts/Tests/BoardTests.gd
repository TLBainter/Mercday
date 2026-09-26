class_name BoardTests

#Contract board launch, refill, expiry, reject, dispatch and the all-dead return.
#Run: godot --headless --path . -- --board-tests


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_launch(res)
	_case_refill(res)
	_case_refill_minute(res)
	_case_expiry(res)
	_case_reject(res)
	_case_urgency(res)
	_case_activate(res)
	_case_all_dead_returns(res)
	_case_all_dead_fails(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "BOARD")


static func _team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(size):
		var merc: MercenaryData = MercGenerator.generate(i)
		ContractModifiers.set_level(merc, level)
		team.append(merc)
	GuildRoster.set_roster(team)
	return team


static func _board(now: int) -> ContractBoard:
	_team(3, 5)
	var board := ContractBoard.new()
	board.launch(now)
	return board


static func _case_launch(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	TestFixtures.check(res, "launch_count", board.entries.size() == ContractLibrary.config().board_target,
		"entries %d" % board.entries.size())
	TestFixtures.check(res, "launch_all_open", board.available().size() == ContractLibrary.config().board_target,
		"open %d" % board.available().size())
	var types: Array[String] = ContractLibrary.contract_type_names()
	var missing: Array[String] = []
	for name: String in types:
		var found: bool = false
		for entry: BoardEntry in board.entries:
			if entry.contract_type() == name:
				found = true
		if not found:
			missing.append(name)
	TestFixtures.check(res, "launch_type_coverage", missing.is_empty(),
		"types %d missing %s" % [types.size(), "none" if missing.is_empty() else ", ".join(missing)])
	var ids: Array[int] = []
	var placeholders: bool = true
	for entry: BoardEntry in board.entries:
		if ids.has(entry.id):
			placeholders = false
		ids.append(entry.id)
		if entry.distance_km < ContractLibrary.config().board_distance_min_km:
			placeholders = false
		if entry.distance_km > ContractLibrary.config().board_distance_max_km:
			placeholders = false
		var hours: float = entry.hours_left(0)
		if hours < float(ContractLibrary.config().board_expiry_min_hours):
			placeholders = false
		if hours > float(ContractLibrary.config().board_expiry_max_hours):
			placeholders = false
		if entry.issuer_type < 1 or entry.issuer_type > ContractLibrary.config().board_issuer_types:
			placeholders = false
		if entry.merc_min != ContractLibrary.config().board_merc_min or entry.completion_hours <= 0:
			placeholders = false
	TestFixtures.check(res, "launch_placeholders", placeholders, "Q29 placeholder ranges")


static func _case_refill(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	board.reject(board.entries[0].id)
	board.reject(board.entries[1].id)
	board.reject(board.entries[2].id)
	var added: Array[BoardEntry] = board.refill(ContractLibrary.config().board_refill_hour * CampaignClock.MINUTES_PER_HOUR)
	TestFixtures.check(res, "refill_added", added.size() == 3, "added %d" % added.size())
	TestFixtures.check(res, "refill_target", board.available().size() == ContractLibrary.config().board_target,
		"open %d" % board.available().size())
	TestFixtures.check(res, "refill_keeps_history", board.entries.size() == ContractLibrary.config().board_target + 3,
		"entries %d" % board.entries.size())
	var again: Array[BoardEntry] = board.refill(0)
	TestFixtures.check(res, "refill_idempotent", again.is_empty(), "added %d" % again.size())


static func _case_refill_minute(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var eight: int = ContractLibrary.config().board_refill_hour * CampaignClock.MINUTES_PER_HOUR
	TestFixtures.check(res, "refill_minute_midnight", board.next_refill_minute(0) == eight,
		"got %d" % board.next_refill_minute(0))
	TestFixtures.check(res, "refill_minute_on_the_hour",
		board.next_refill_minute(eight) == eight + CampaignClock.MINUTES_PER_DAY,
		"got %d" % board.next_refill_minute(eight))
	TestFixtures.check(res, "refill_minute_afternoon",
		board.next_refill_minute(eight + 600) == eight + CampaignClock.MINUTES_PER_DAY,
		"got %d" % board.next_refill_minute(eight + 600))


static func _case_expiry(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var first: BoardEntry = board.entries[0]
	first.expires_minute = 100
	TestFixtures.check(res, "expiry_next_minute", board.next_expiry_minute(0) == 100,
		"got %d" % board.next_expiry_minute(0))
	var due: Array[BoardEntry] = board.expire_due(99)
	TestFixtures.check(res, "expiry_not_yet", due.is_empty() and first.is_open(), "status %s" % first.status)
	due = board.expire_due(100)
	TestFixtures.check(res, "expiry_due", due.size() == 1 and due[0] == first, "expired %d" % due.size())
	TestFixtures.check(res, "expiry_status", first.status == BoardEntry.STATUS_EXPIRED, "status %s" % first.status)
	TestFixtures.check(res, "expiry_stamps_closed", first.closed_minute == 100,
		"closed %d" % first.closed_minute)
	TestFixtures.check(res, "expiry_leaves_offers", board.available().size() == ContractLibrary.config().board_target - 1,
		"open %d" % board.available().size())
	TestFixtures.check(res, "expiry_keeps_history", board.entries.has(first), "the posting left the list")
	var empty := ContractBoard.new()
	TestFixtures.check(res, "expiry_none", empty.next_expiry_minute(0) == -1,
		"got %d" % empty.next_expiry_minute(0))


static func _case_reject(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var first: BoardEntry = board.entries[0]
	TestFixtures.check(res, "reject_once", board.reject(first.id), "reject returned false")
	TestFixtures.check(res, "reject_status", first.status == BoardEntry.STATUS_REJECTED, "status %s" % first.status)
	TestFixtures.check(res, "reject_stamps_closed", first.closed_minute == CampaignClock.now(),
		"closed %d now %d" % [first.closed_minute, CampaignClock.now()])
	TestFixtures.check(res, "reject_twice", not board.reject(first.id), "a rejected posting rejected again")
	TestFixtures.check(res, "reject_unknown", not board.reject(9999), "an unknown id rejected")
	TestFixtures.check(res, "reject_leaves_offers", board.available().size() == ContractLibrary.config().board_target - 1,
		"open %d" % board.available().size())


static func _case_urgency(res: Dictionary) -> void:
	var entry := BoardEntry.new()
	entry.expires_minute = 23 * CampaignClock.MINUTES_PER_HOUR
	TestFixtures.check(res, "urgency_high", entry.urgency(0) == BoardEntry.URGENCY_HIGH,
		"got %d" % entry.urgency(0))
	entry.expires_minute = 30 * CampaignClock.MINUTES_PER_HOUR
	TestFixtures.check(res, "urgency_low", entry.urgency(0) == BoardEntry.URGENCY_LOW,
		"got %d" % entry.urgency(0))
	entry.expires_minute = 100 * CampaignClock.MINUTES_PER_HOUR
	TestFixtures.check(res, "urgency_none", entry.urgency(0) == BoardEntry.URGENCY_NONE,
		"got %d" % entry.urgency(0))
	TestFixtures.check(res, "urgency_hours_left", absf(entry.hours_left(60) - 99.0) < 0.001,
		"got %.3f" % entry.hours_left(60))


static func _case_activate(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(8 * CampaignClock.MINUTES_PER_HOUR)
	var start: int = CampaignClock.now()
	var board: ContractBoard = _board(start)
	var team: Array[MercenaryData] = _team(3, 5)
	var first: BoardEntry = board.entries[0]
	var scheduler: ContractScheduler = board.activate(first.id, team, 240, start, Callable())
	TestFixtures.check(res, "activate_scheduler", scheduler != null and first.scheduler == scheduler,
		"no scheduler on the entry")
	TestFixtures.check(res, "activate_status", first.status == BoardEntry.STATUS_ACTIVE, "status %s" % first.status)
	TestFixtures.check(res, "activate_mirrors_contract", first.contract.status == "Active",
		"contract status %s" % first.contract.status)
	TestFixtures.check(res, "activate_team", first.contract.team_uids.size() == 3,
		"uids %d" % first.contract.team_uids.size())
	TestFixtures.check(res, "activate_due", scheduler != null and scheduler.next_due() == start + 240,
		"due %d" % (scheduler.next_due() if scheduler != null else -1))
	TestFixtures.check(res, "activate_leaves_offers", board.available().size() == ContractLibrary.config().board_target - 1
		and board.active_entries().size() == 1,
		"open %d active %d" % [board.available().size(), board.active_entries().size()])
	TestFixtures.check(res, "activate_twice", board.activate(first.id, team, 240, start, Callable()) == null,
		"an active posting was dispatched again")
	var empty: Array[MercenaryData] = []
	TestFixtures.check(res, "activate_empty_team", board.activate(board.entries[1].id, empty, 240, start, Callable()) == null,
		"an empty team was dispatched")
	for merc: MercenaryData in team:
		merc.on_contract = false


#Every merc sent is lost, the deadline still holds and there is room: the posting goes back up.
static func _case_all_dead_returns(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var team: Array[MercenaryData] = _team(3, 5)
	var first: BoardEntry = board.entries[0]
	first.expires_minute = 10000
	var scheduler: ContractScheduler = board.activate(first.id, team, 240, 0, Callable())
	_finish(scheduler, "Failed", true)
	var verdict: String = board.settle(first, 1000)
	TestFixtures.check(res, "dead_return_verdict", verdict == "Failed", "verdict %s" % verdict)
	TestFixtures.check(res, "dead_return_status", first.status == BoardEntry.STATUS_DRAFT, "status %s" % first.status)
	TestFixtures.check(res, "dead_return_clears_closed", first.closed_minute == -1,
		"closed %d" % first.closed_minute)
	TestFixtures.check(res, "dead_return_team_cleared", first.contract.team_uids.is_empty(),
		"uids %d" % first.contract.team_uids.size())
	TestFixtures.check(res, "dead_return_keeps_events", not first.contract.assigned_primary_event.is_empty(),
		"the rolled events were dropped")
	TestFixtures.check(res, "dead_return_no_scheduler", first.scheduler == null, "the scheduler stayed")
	TestFixtures.check(res, "dead_return_offers", board.available().size() == ContractLibrary.config().board_target,
		"open %d" % board.available().size())
	for merc: MercenaryData in team:
		merc.on_contract = false


#The same loss with the board full, or past the deadline, closes the posting as Failed.
static func _case_all_dead_fails(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var team: Array[MercenaryData] = _team(3, 5)
	var first: BoardEntry = board.entries[0]
	first.expires_minute = 10000
	var scheduler: ContractScheduler = board.activate(first.id, team, 240, 0, Callable())
	board.post(ContractGenerator.generate("Military"), 0)
	_finish(scheduler, "Failed", true)
	var verdict: String = board.settle(first, 1000)
	TestFixtures.check(res, "dead_full_verdict", verdict == "Failed", "verdict %s" % verdict)
	TestFixtures.check(res, "dead_full_status", first.status == BoardEntry.STATUS_FAILED, "status %s" % first.status)
	TestFixtures.check(res, "settle_stamps_closed", first.closed_minute == 1000,
		"closed %d" % first.closed_minute)
	var second: BoardEntry = board.entries[1]
	var scheduler_b: ContractScheduler = board.activate(second.id, team, 240, 0, Callable())
	second.expires_minute = 500
	_finish(scheduler_b, "Failed", true)
	board.settle(second, 600)
	TestFixtures.check(res, "dead_late_status", second.status == BoardEntry.STATUS_FAILED, "status %s" % second.status)
	var third: BoardEntry = board.entries[2]
	var scheduler_c: ContractScheduler = board.activate(third.id, team, 240, 0, Callable())
	_finish(scheduler_c, "Succeeded", false)
	TestFixtures.check(res, "settle_succeeded", board.settle(third, 100) == "Succeeded"
		and third.status == BoardEntry.STATUS_SUCCEEDED, "status %s" % third.status)
	TestFixtures.check(res, "settle_unfinished", board.settle(board.entries[3], 100) == "",
		"an idle posting settled")
	for merc: MercenaryData in team:
		merc.on_contract = false


#Closes a scheduler without running the contract, so the board branches are tested on their own.
static func _finish(scheduler: ContractScheduler, verdict: String, all_dead: bool) -> void:
	if scheduler == null:
		return
	scheduler.phase = ContractScheduler.Phase.DONE
	scheduler.all_dead = all_dead
	scheduler.run.verdict = verdict
	scheduler.run.log_lines.append("BOARD TEST LINE")

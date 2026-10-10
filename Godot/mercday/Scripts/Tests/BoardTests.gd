class_name BoardTests

#Contract board launch, refill, expiry, reject, dispatch, the retired comeback rule, the campaign room and the round.
#Run: godot --headless --path . -- --board-tests

#A type name no Contracts.tsv row carries, so ContractGenerator.generate returns null for it.
const NULL_TYPE: String = "No Such Type"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_launch(res)
	_case_refill(res)
	_case_null_draw(res)
	_case_refill_minute(res)
	_case_expiry(res)
	_case_reject(res)
	_case_urgency(res)
	_case_activate(res)
	_case_all_dead_comeback(res)
	_case_comeback_out_of_reach(res)
	_case_all_dead_fails(res)
	_case_campaign_room(res)
	PoolTests.add_cases(res)
	RoundTests.add_cases(res)
	_case_row_merc_min(res)
	_case_local_post(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "BOARD")


#Frees the mercs a dispatch put on a contract.
static func _release(team: Array[MercenaryData]) -> void:
	for merc: MercenaryData in team:
		merc.on_contract = false


static func _board(now: int) -> ContractBoard:
	ContractFixtures.generated_team(3, 5)
	var board := ContractBoard.new()
	board.launch(now)
	return board


static func _case_launch(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	TestFixtures.check(res, "launch_count", board.entries.size() == cfg.board_target,
		"entries %d" % board.entries.size())
	TestFixtures.check(res, "launch_all_open", board.available().size() == cfg.board_target,
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
		if entry.distance_km < cfg.board_distance_min_km:
			placeholders = false
		if entry.distance_km > cfg.board_distance_max_km:
			placeholders = false
		var hours: float = entry.hours_left(0)
		if hours < float(cfg.board_expiry_min_hours):
			placeholders = false
		if hours > float(cfg.board_expiry_max_hours):
			placeholders = false
		if not ["person", "place", "org"].has(entry.issuer_type):
			placeholders = false
		var source: ContractData = null
		if entry.contract != null:
			source = ContractLibrary.contract(ContractLibrary.row_name(entry.contract))
		var want_min: int = source.min_mercs if source != null and source.min_mercs > 0 else cfg.board_merc_min
		if entry.merc_min != want_min or entry.completion_hours <= 0:
			placeholders = false
	TestFixtures.check(res, "launch_placeholders", placeholders, "Q29 placeholder ranges")


#Card 285: a posting takes the contract's Min Mercs when set, else board_merc_min.
static func _case_row_merc_min(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var set_row: ContractData = ContractGenerator.generate("Military")
	var blank_row: ContractData = ContractGenerator.generate("Military")
	if set_row == null or blank_row == null:
		TestFixtures.check(res, "card285_board_row_min", false, "Military generated null")
		return
	set_row.min_mercs = 2
	blank_row.min_mercs = 0
	var set_entry: BoardEntry = board.post(set_row, 0)
	var blank_entry: BoardEntry = board.post(blank_row, 0)
	TestFixtures.check(res, "card285_board_row_min", set_entry.merc_min == 2
		and blank_entry.merc_min == cfg.board_merc_min, "set %d, blank %d" % [set_entry.merc_min, blank_entry.merc_min])


#Card 736: a Local contract posts at 0 km on the board and through GenPosting, at the guild home.
static func _case_local_post(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var local_row: ContractData = ContractGenerator.generate("Military")
	var plain_row: ContractData = ContractGenerator.generate("Military")
	if local_row == null or plain_row == null:
		TestFixtures.check(res, "local:board_post_zero", false, "Military generated null")
		return
	local_row.local = true
	var local_entry: BoardEntry = board.post(local_row, 0)
	var plain_entry: BoardEntry = board.post(plain_row, 0)
	TestFixtures.check(res, "local:board_post_zero", local_entry.distance_km == 0
		and plain_entry.distance_km >= cfg.board_distance_min_km and plain_entry.distance_km <= cfg.board_distance_max_km,
		"local %d plain %d" % [local_entry.distance_km, plain_entry.distance_km])
	var cat: ContractData = ContractLibrary.contract("Cat Stuck in Tree!")
	if cat == null:
		TestFixtures.check(res, "local:gen_posting_home", false, "no Cat row")
		return
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	var seated := ContractBoard.new()
	var ctx: Dictionary = DailyContractRound.context(seated, 0)
	ctx["level"] = maxi(1, cat.level_min)
	var cat_rows: Array[ContractData] = [cat]
	ctx["rows_by_type"] = {cat.contract_type: cat_rows}
	var rng := RandomNumberGenerator.new()
	rng.seed = 736
	var applied: Array[String] = []
	var entry: BoardEntry = GenPosting.generate_one(ctx, seated, 0, rng, ContractIssuer.seat_id("people", 0), applied, {})
	var why: String = "null: %s" % GenPosting.null_reason
	if entry != null:
		why = "km %d location %s local %s" % [entry.distance_km, entry.contract.location_a, str(entry.contract.local)]
	TestFixtures.check(res, "local:gen_posting_home", entry != null and entry.distance_km == 0
		and entry.contract.location_a == GenConstants.GUILD_HOME and entry.contract.local, why)


static func _case_refill(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	board.reject(board.entries[0].id)
	board.reject(board.entries[1].id)
	board.reject(board.entries[2].id)
	var added: Array[BoardEntry] = board.refill(cfg.board_refill_hour * CampaignClock.MINUTES_PER_HOUR)
	TestFixtures.check(res, "refill_added", added.size() == 3, "added %d" % added.size())
	TestFixtures.check(res, "refill_target", board.available().size() == cfg.board_target,
		"open %d" % board.available().size())
	TestFixtures.check(res, "refill_keeps_history", board.entries.size() == cfg.board_target + 3,
		"entries %d" % board.entries.size())
	var again: Array[BoardEntry] = board.refill(0)
	TestFixtures.check(res, "refill_idempotent", again.is_empty(), "added %d" % again.size())


#A null draw leaves no hole: the opening and the refill draw again until the room is filled or no type is left.
static func _case_null_draw(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	ContractFixtures.generated_team(3, 5)
	var mixed: Array[String] = [NULL_TYPE, "Military"]
	var opened := ContractBoard.new()
	opened._open_with(mixed, 4, 0)
	TestFixtures.check(res, "open_tops_up_null_draw", opened.entries.size() == 4
		and ", ".join(_types_of(opened.entries)) == "Military",
		"entries %d types %s" % [opened.entries.size(), ", ".join(_types_of(opened.entries))])
	var nulls: Array[String] = [NULL_TYPE]
	var barren := ContractBoard.new()
	barren._open_with(nulls, 2, 0)
	TestFixtures.check(res, "open_all_null_ends_empty", barren.entries.is_empty(), "entries %d" % barren.entries.size())
	#One call in eight never draws the null type, so the call repeats until it has been drawn once.
	var board := ContractBoard.new()
	var kept: Array[String] = [NULL_TYPE, "Military"]
	var drawn: Array[BoardEntry] = board._post_drawn(3, 0, kept)
	for _try: int in range(20):
		if not kept.has(NULL_TYPE):
			break
		kept = [NULL_TYPE, "Military"]
		drawn = board._post_drawn(3, 0, kept)
	var emptied: Array[String] = [NULL_TYPE]
	var none: Array[BoardEntry] = board._post_drawn(2, 0, emptied)
	TestFixtures.check(res, "drawn_drops_null_type", drawn.size() == 3
		and ", ".join(_types_of(drawn)) == "Military" and ", ".join(kept) == "Military"
		and none.is_empty() and emptied.is_empty(),
		"drawn %d types %s kept %s then drawn %d left %d" % [drawn.size(), ", ".join(_types_of(drawn)),
		", ".join(kept), none.size(), emptied.size()])
	var full: int = 0
	var single: int = 0
	var launched := ContractBoard.new()
	for _try: int in range(20):
		launched.launch(0)
		if launched.own_open() == cfg.board_target:
			full += 1
		launched.launch(0, 1)
		if launched.entries.size() == 1:
			single += 1
	TestFixtures.check(res, "launch_fills_target", full == 20 and single == 20,
		"full board %d of 20 one posting %d of 20" % [full, single])


#The distinct contract types of these postings, in first-seen order.
static func _types_of(list: Array[BoardEntry]) -> Array[String]:
	var out: Array[String] = []
	for item: BoardEntry in list:
		if not out.has(item.contract_type()):
			out.append(item.contract_type())
	return out


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
	var team: Array[MercenaryData] = ContractFixtures.generated_team(3, 5)
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
	_release(team)


#Every merc sent is lost before the deadline: the posting fails like any other and, with the comeback queue
#retired, stays closed; a failed story posting goes back to the pool as a pooled copy at its old value.
static func _case_all_dead_comeback(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var team: Array[MercenaryData] = ContractFixtures.generated_team(3, 5)
	var first: BoardEntry = board.entries[0]
	var second: BoardEntry = board.entries[1]
	first.posted_minute = 200
	first.expires_minute = 10000
	first.issuer = "Comeback Issuer"
	first.issuer_id = 5
	first.deadline_minute = 50000
	var scheduler: ContractScheduler = board.activate(first.id, team, 240, 200, Callable())
	_finish(scheduler, "Failed", true)
	var verdict: String = board.settle(first, 1000)
	TestFixtures.check(res, "comeback_verdict", verdict == "Failed", "verdict %s" % verdict)
	TestFixtures.check(res, "comeback_status", first.status == BoardEntry.STATUS_FAILED and first.closed_minute == 1000,
		"status %s closed %d" % [first.status, first.closed_minute])
	TestFixtures.check(res, "comeback_no_scheduler", first.scheduler == null, "the scheduler stayed")
	TestFixtures.check(res, "comeback_retired_not_pooled", board.pool.entries.is_empty(),
		"pool %d" % board.pool.entries.size())
	TestFixtures.check(res, "comeback_leaves_offers", board.available().size() == cfg.board_target - 1,
		"open %d" % board.available().size())
	second.story = true
	second.issuer = "Story Issuer"
	second.issuer_id = 6
	second.value = 77
	second.contract.reward_notes = 77
	second.expires_minute = 10000
	second.deadline_minute = 50000
	_finish(board.activate(second.id, team, 240, 1000, Callable()), "Failed", true)
	board.settle(second, 2000)
	var copy: BoardEntry = board.pool.entries[0] if board.pool.entries.size() == 1 else BoardEntry.new()
	TestFixtures.check(res, "comeback_story_pooled", board.pool.entries.size() == 1 and copy != second
		and copy.status == BoardEntry.STATUS_POOLED and copy.pooled_minute == 2000 and copy.story
		and second.status == BoardEntry.STATUS_FAILED, "pool %d status %s" % [board.pool.entries.size(), copy.status])
	TestFixtures.check(res, "comeback_story_keeps_issuer", copy.issuer == second.issuer
		and copy.issuer_id == second.issuer_id and copy.distance_km == second.distance_km
		and copy.deadline_minute == second.deadline_minute,
		"issuer %s id %d distance %d" % [copy.issuer, copy.issuer_id, copy.distance_km])
	TestFixtures.check(res, "comeback_story_keeps_value", copy.value == 77 and copy.contract != null
		and copy.contract != second.contract and copy.contract.reward_notes == 77 and copy.reject_count == 0,
		"value %d rejects %d" % [copy.value, copy.reject_count])
	_release(team)


#A pooled story copy survives the pool sweep even when out of reach; post_pooled lists it with its expiry clamped
#to the auto-reject minute and a fresh id.
static func _case_comeback_out_of_reach(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var team: Array[MercenaryData] = ContractFixtures.generated_team(3, 5)
	var lost: BoardEntry = board.entries[0]
	lost.story = true
	lost.expires_minute = 10000
	_finish(board.activate(lost.id, team, 240, 0, Callable()), "Failed", true)
	board.settle(lost, 500)
	var copy: BoardEntry = board.pool.entries[0] if board.pool.entries.size() == 1 else BoardEntry.new()
	copy.deadline_minute = 1501
	var swept: Array[BoardEntry] = board.pool.sweep(1500, 0, func(_e: BoardEntry) -> bool: return false)
	TestFixtures.check(res, "comeback_story_not_swept", swept.is_empty() and board.pool.entries.size() == 1,
		"swept %d pool %d" % [swept.size(), board.pool.entries.size()])
	var back_at: int = 1500
	copy.deadline_minute = Reachability.departure_minute(back_at) + Reachability.completion_minutes(copy) + 600
	var again: BoardEntry = board.post_pooled(copy, back_at)
	var reject_at: int = Reachability.auto_reject_minute(again, Reachability.MODES, back_at)
	TestFixtures.check(res, "comeback_expiry_clamped", again == copy and again.contract != lost.contract
		and again.id != lost.id and again.is_open() and again.posted_minute == back_at
		and again.expires_minute == reject_at and board.pool.entries.is_empty(),
		"expires %d reject %d pool %d" % [again.expires_minute, reject_at, board.pool.entries.size()])
	_release(team)


#With the comeback queue retired no plain failure is pooled: an all-dead loss before the deadline,
#a loss at or past the deadline and one with survivors all stay closed.
static func _case_all_dead_fails(res: Dictionary) -> void:
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var team: Array[MercenaryData] = ContractFixtures.generated_team(3, 5)
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
	TestFixtures.check(res, "dead_full_not_pooled", board.pool.entries.is_empty(), "pool %d" % board.pool.entries.size())
	var second: BoardEntry = board.entries[1]
	var scheduler_b: ContractScheduler = board.activate(second.id, team, 240, 0, Callable())
	second.expires_minute = 500
	_finish(scheduler_b, "Failed", true)
	board.settle(second, 600)
	TestFixtures.check(res, "dead_late_status", second.status == BoardEntry.STATUS_FAILED, "status %s" % second.status)
	TestFixtures.check(res, "dead_late_not_queued", board.pool.entries.is_empty(), "pool %d" % board.pool.entries.size())
	var fourth: BoardEntry = board.entries[4]
	var scheduler_d: ContractScheduler = board.activate(fourth.id, team, 240, 0, Callable())
	fourth.expires_minute = 700
	_finish(scheduler_d, "Failed", true)
	board.settle(fourth, 700)
	TestFixtures.check(res, "dead_deadline_not_queued", fourth.status == BoardEntry.STATUS_FAILED
		and board.pool.entries.is_empty(), "status %s pool %d" % [fourth.status, board.pool.entries.size()])
	var fifth: BoardEntry = board.entries[5]
	var scheduler_e: ContractScheduler = board.activate(fifth.id, team, 240, 0, Callable())
	fifth.expires_minute = 10000
	_finish(scheduler_e, "Failed", false)
	board.settle(fifth, 800)
	TestFixtures.check(res, "failed_alive_not_queued", fifth.status == BoardEntry.STATUS_FAILED
		and board.pool.entries.is_empty(), "status %s pool %d" % [fifth.status, board.pool.entries.size()])
	var third: BoardEntry = board.entries[2]
	var scheduler_c: ContractScheduler = board.activate(third.id, team, 240, 0, Callable())
	_finish(scheduler_c, "Succeeded", false)
	TestFixtures.check(res, "settle_succeeded", board.settle(third, 100) == "Succeeded"
		and third.status == BoardEntry.STATUS_SUCCEEDED, "status %s" % third.status)
	TestFixtures.check(res, "settle_unfinished", board.settle(board.entries[3], 100) == "",
		"an idle posting settled")
	_release(team)


#Campaign postings stay listed and do not count toward the target that a refill fills.
static func _case_campaign_room(res: Dictionary) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	CampaignClock.reset()
	var board: ContractBoard = _board(0)
	var tagged: BoardEntry = board.post(ContractGenerator.generate("Military"), 0)
	tagged.campaign_id = 7
	TestFixtures.check(res, "room_full_with_campaign", board.board_room() == 0,
		"room %d open %d" % [board.board_room(), board.available().size()])
	board.reject(board.entries[0].id)
	board.reject(board.entries[1].id)
	TestFixtures.check(res, "room_counts_own", board.board_room() == 2, "room %d" % board.board_room())
	TestFixtures.check(res, "own_open_counts_own", board.own_open() == board.available().size() - 1
		and board.own_open() == board.entries.size() - 3 and tagged.is_open() and not board.entries[0].is_open(),
		"own %d open %d entries %d" % [board.own_open(), board.available().size(), board.entries.size()])
	var added: Array[BoardEntry] = board.refill(cfg.board_refill_hour * CampaignClock.MINUTES_PER_HOUR)
	var own: int = 0
	for entry: BoardEntry in board.available():
		if entry.campaign_id == 0:
			own += 1
	TestFixtures.check(res, "room_refill_own_target", added.size() == 2 and own == cfg.board_target,
		"added %d own %d" % [added.size(), own])
	TestFixtures.check(res, "room_campaign_listed", board.available().has(tagged)
		and board.available().size() == cfg.board_target + 1, "open %d" % board.available().size())


#Rejects the newest open posting to free one slot for the next refill.
static func _free_slot(board: ContractBoard) -> void:
	var listed: Array[BoardEntry] = board.available()
	if not listed.is_empty():
		board.reject(listed[listed.size() - 1].id)


#Closes a scheduler without running the contract, so the board branches are tested on their own.
static func _finish(scheduler: ContractScheduler, verdict: String, all_dead: bool) -> void:
	if scheduler == null:
		return
	scheduler.phase = ContractScheduler.Phase.DONE
	scheduler.all_dead = all_dead
	scheduler.run.verdict = verdict
	scheduler.run.log_lines.append("BOARD TEST LINE")

class_name RoundTests
#The daily contract round through run_with and a seeded rng; joined to the board suite.

const NOW: int = 8 * 60 + 2 * 1440
const FAR: int = NOW + 10 * 1440


static func add_cases(res: Dictionary) -> void:
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	_case_no_room(res)
	_case_excluded_issuer(res)
	_case_busy_waits(res)
	_case_room_limits(res)
	_case_reject_waits(res)
	_case_swept(res)
	_case_story_first(res)
	_case_story_failure(res)
	_case_promo_credit(res)
	_case_promo_no_criteria(res)
	_case_place_in_country(res)
	_case_value_notes(res)
	_case_no_global_draw(res)
	_case_mean_value(res)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _ctx(roster_max: int, with_rows: bool) -> Dictionary:
	var rows_by_type: Dictionary = {}
	if with_rows:
		for type_name: String in ContractLibrary.contract_type_names():
			rows_by_type[type_name] = ContractLibrary.contracts_for_type(type_name)
	var none: Array[MercenaryData] = []
	return {"roster_max": roster_max, "living": none, "available": none, "resting": none, "level_centre": 10.0,
		"diff_centre": 2.5, "bank": 100000, "campaigns": [] as Array[Dictionary],
		"rates": {"overall": 0.5, "recent": 0.5, "blended": 0.5}, "rows_by_type": rows_by_type,
		"places": GenLocation.places(func(_p: String) -> bool: return true, func(_p: String) -> bool: return false),
		"tele_fn": func(_e: BoardEntry) -> bool: return false}


static func _entry(issuer: int, value: int) -> BoardEntry:
	var entry := BoardEntry.new()
	entry.contract = ContractData.new()
	entry.contract.reward_notes = value
	entry.value = value
	entry.distance_km = 10
	entry.completion_hours = 8
	entry.merc_min = 1
	entry.issuer_id = issuer
	entry.deadline_minute = FAR
	return entry


static func _seat(i: int) -> int:
	return IssuerOpinion.ids()[i]


static func _case_no_room(res: Dictionary) -> void:
	var board := ContractBoard.new()
	board.post_pooled(_entry(_seat(0), 50), NOW)
	board.pool.add(_entry(_seat(1), 50), NOW)
	var out: Dictionary = DailyContractRound.run_with(_ctx(1, true), board, NOW, _rng(1))
	TestFixtures.check(res, "round:no_room_posts_nothing", out.get("stop", "") == "no room"
		and int(out["provisioned"]) == 0 and int(out["generated"]) == 0 and board.pool.entries.size() == 1,
		"out %s pool %d" % [str(out), board.pool.entries.size()])


static func _case_excluded_issuer(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var ctx: Dictionary = _ctx(40, true)
	ctx["rates"] = {"overall": 1.0, "recent": 1.0, "blended": 1.0}
	var made: int = 0
	for day: int in range(4):
		made += int(DailyContractRound.run_with(ctx, board, NOW + day * 1440, _rng(10 + day))["generated"])
	var seen: Array[int] = []
	var unique: bool = true
	var held: Array[BoardEntry] = board.available()
	held.append_array(board.pool.entries)
	for entry: BoardEntry in held:
		unique = unique and not seen.has(entry.issuer_id)
		seen.append(entry.issuer_id)
	TestFixtures.check(res, "round:excluded_issuer_once", made > 0 and unique,
		"generated %d held %d unique %s" % [made, held.size(), unique])


static func _case_busy_waits(res: Dictionary) -> void:
	var board := ContractBoard.new()
	board.post_pooled(_entry(_seat(0), 50), NOW)
	var waiting: BoardEntry = _entry(_seat(0), 60)
	board.pool.add(waiting, NOW - 60)
	var out: Dictionary = DailyContractRound.run_with(_ctx(5, false), board, NOW, _rng(2))
	TestFixtures.check(res, "round:busy_issuer_waits", int(out["provisioned"]) == 0
		and board.pool.entries.has(waiting), "out %s" % str(out))


static func _case_room_limits(res: Dictionary) -> void:
	var board := ContractBoard.new()
	for i: int in range(3):
		board.pool.add(_entry(_seat(i), 50 + i), NOW - 60)
	var out: Dictionary = DailyContractRound.run_with(_ctx(1, false), board, NOW, _rng(3))
	TestFixtures.check(res, "round:room_limits_provision", int(out["room"]) == 1 and int(out["provisioned"]) == 1
		and board.available().size() == 1 and board.pool.entries.size() == 2, "out %s" % str(out))


static func _case_reject_waits(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var posted: BoardEntry = board.post_pooled(_entry(_seat(0), 100), NOW - 600)
	board.reject(posted.id)
	var back: BoardEntry = board.pool.return_rejected(posted, 3, NOW)
	var out: Dictionary = DailyContractRound.run_with(_ctx(5, false), board, NOW, _rng(4))
	TestFixtures.check(res, "round:reject_pooled_with_bonus", back.value == 145 and back.contract.reward_notes == 145
		and back.reject_count == 1, "value %d" % back.value)
	TestFixtures.check(res, "round:reject_not_same_call", int(out["provisioned"]) == 0
		and board.pool.entries.has(back), "out %s" % str(out))


static func _case_swept(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var stale: BoardEntry = _entry(_seat(0), 50)
	stale.deadline_minute = NOW + 1
	board.pool.add(stale, NOW - 600)
	var out: Dictionary = DailyContractRound.run_with(_ctx(5, false), board, NOW, _rng(5))
	TestFixtures.check(res, "round:swept_counted_expired", int(out["expired"]) == 1
		and not board.pool.entries.has(stale) and not board.entries.has(stale), "out %s" % str(out))


static func _case_story_first(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var plain: BoardEntry = _entry(_seat(0), 50)
	plain.quality = 1.0
	var story: BoardEntry = _entry(_seat(1), 50)
	story.story = true
	story.deadline_minute = NOW + 1
	board.pool.add(plain, NOW - 600)
	board.pool.add(story, NOW - 60)
	var out: Dictionary = DailyContractRound.run_with(_ctx(1, false), board, NOW, _rng(6))
	var fresh: int = GenPosting.fresh_deadline(story, NOW, 10.0)
	TestFixtures.check(res, "round:story_first_fresh_deadline", int(out["provisioned"]) == 1
		and board.available().has(story) and story.deadline_minute == fresh and fresh > NOW + 1
		and board.pool.entries.has(plain), "out %s deadline %d" % [str(out), story.deadline_minute])


static func _case_story_failure(res: Dictionary) -> void:
	CampaignClock.reset()
	var board := ContractBoard.new()
	board.launch(0)
	var team: Array[MercenaryData] = ContractFixtures.generated_team(3, 5)
	var plain: BoardEntry = board.entries[0]
	var story: BoardEntry = board.entries[1]
	story.story = true
	for entry: BoardEntry in [plain, story]:
		entry.expires_minute = 10000
		var scheduler: ContractScheduler = board.activate(entry.id, team, 240, 0, Callable())
		scheduler.phase = ContractScheduler.Phase.DONE
		scheduler.all_dead = true
		scheduler.run.verdict = "Failed"
		board.settle(entry, 1000)
	var back: bool = board.pool.entries.size() == 1 and board.pool.entries[0].story
	TestFixtures.check(res, "round:story_failure_returns_plain_not", back, "pool %d" % board.pool.entries.size())
	for merc: MercenaryData in team:
		merc.on_contract = false


static func _case_promo_credit(res: Dictionary) -> void:
	var campaign := CampaignData.new()
	campaign.id = 9901
	PromotionsManager.campaigns.append(campaign)
	var shape: Dictionary = {"id": 9901, "effect": 100.0, "types": ["Military"], "places": [], "diff_lo": 0.0,
		"diff_hi": 0.0, "issuers": []}
	var out: Dictionary = {}
	var board := ContractBoard.new()
	for seed_value: int in range(20):
		var ctx: Dictionary = _ctx(0, true)
		ctx["roster_max"] = 40
		ctx["campaigns"] = [shape] as Array[Dictionary]
		board = ContractBoard.new()
		out = DailyContractRound.run_with(ctx, board, NOW, _rng(100 + seed_value))
		if int(out["promo"]) > 0:
			break
	var tagged: int = 0
	for entry: BoardEntry in board.entries + board.pool.entries:
		tagged += 1 if entry.campaign_id == 9901 and entry.contract_type() == "Military" else 0
	TestFixtures.check(res, "round:promo_credits_once", int(out["promo"]) > 0 and campaign.results == int(out["promo"])
		and tagged == int(out["promo"]), "promo %d results %d tagged %d" % [int(out["promo"]), campaign.results, tagged])
	PromotionsManager.campaigns.erase(campaign)


#A campaign with no active criteria still yields contracts; its hits ask for nothing, so match_pct is 0.
static func _case_promo_no_criteria(res: Dictionary) -> void:
	var campaign := CampaignData.new()
	campaign.id = 9902
	PromotionsManager.campaigns.append(campaign)
	var shape: Dictionary = {"id": 9902, "effect": 100.0, "types": [], "places": [], "diff_lo": 0.0,
		"diff_hi": 0.0, "issuers": []}
	var out: Dictionary = {}
	var board := ContractBoard.new()
	for seed_value: int in range(20):
		var ctx: Dictionary = _ctx(0, true)
		ctx["roster_max"] = 40
		ctx["campaigns"] = [shape] as Array[Dictionary]
		board = ContractBoard.new()
		out = DailyContractRound.run_with(ctx, board, NOW, _rng(200 + seed_value))
		if int(out["promo"]) > 0:
			break
	var tagged: int = 0
	var off: int = 0
	for entry: BoardEntry in board.entries + board.pool.entries:
		if entry.campaign_id == 9902:
			tagged += 1
			off += 0 if entry.match_pct == 0.0 else 1
	TestFixtures.check(res, "round:promo_no_criteria", int(out["promo"]) > 0 and campaign.results == int(out["promo"])
		and tagged > 0 and off == 0, "promo %d results %d tagged %d off %d" % [int(out["promo"]), campaign.results,
		tagged, off])
	PromotionsManager.campaigns.erase(campaign)


#Location A for a round place stays inside that country (generate_row resolves it through pick_location_among).
static func _case_place_in_country(res: Dictionary) -> void:
	var index: int = 0
	var outside: Array[String] = []
	for key: String in GenConstants.DISTANCE_KM:
		seed(1000 + index)
		var names: Array[String] = [key]
		for _i: int in range(50):
			var loc: LocationData = ContractGenerator.pick_location_among(names)
			if loc == null or GenLocation.country_of(loc.location_name) != key:
				outside.append("%s:%s" % [key, loc.location_name if loc != null else "<null>"])
				break
		index += 1
	TestFixtures.check(res, "round:place_stays_in_country", outside.is_empty(), "outside %s" % str(outside))
	randomize()


static func _case_value_notes(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var ctx: Dictionary = _ctx(40, true)
	ctx["rates"] = {"overall": 1.0, "recent": 1.0, "blended": 1.0}
	var out: Dictionary = DailyContractRound.run_with(ctx, board, NOW, _rng(7))
	var bad: int = 0
	for entry: BoardEntry in board.entries + board.pool.entries:
		bad += 0 if entry.value == entry.contract.reward_notes and entry.value > 0 else 1
	TestFixtures.check(res, "round:value_equals_notes", int(out["generated"]) > 0 and bad == 0,
		"generated %d bad %d" % [int(out["generated"]), bad])


#Empty rows keep ContractGenerator (global draws by design) out; the rest of the round must use only rng.
static func _case_no_global_draw(res: Dictionary) -> void:
	var board := ContractBoard.new()
	board.pool.add(_entry(_seat(0), 50), NOW - 600)
	seed(4242)
	DailyContractRound.run_with(_ctx(5, false), board, NOW, _rng(8))
	var after: int = randi()
	seed(4242)
	var control: int = randi()
	TestFixtures.check(res, "round:no_global_draw", after == control and board.available().size() == 1,
		"after %d control %d open %d" % [after, control, board.available().size()])
	randomize()


static func _case_mean_value(res: Dictionary) -> void:
	var board := ContractBoard.new()
	var ctx: Dictionary = _ctx(40, true)
	ctx["level"] = 10
	var rng: RandomNumberGenerator = _rng(9)
	var seats: Array[int] = IssuerOpinion.ids()
	var total: float = 0.0
	var count: int = 0
	for i: int in range(300):
		var entry: BoardEntry = GenPosting.generate_one(ctx, board, NOW, rng, seats[i % seats.size()])
		if entry == null:
			continue
		var mode: String = GenExpense.mode_for(10.0, entry.distance_km)
		var expense: int = GenExpense.expense(mode, entry.distance_km, entry.contract.max_mercs)
		total += float(entry.value - GenExpense.travel_add(expense, entry.quality))
		count += 1
	var mean: float = total / float(maxi(1, count))
	TestFixtures.check(res, "round:mean_value_level10", count == 300 and mean >= 35.0 and mean <= 65.0,
		"count %d mean %.1f" % [count, mean])

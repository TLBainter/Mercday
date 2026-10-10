class_name ContractGateTests

#Page 1 fields at runtime: the level gate, issuer words, seats and text, the story flag and the offered roles.

const WINDOW: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchWindow.tscn")
const SLOT: PackedScene = preload("res://Scenes/GUI/Contracts/TeamSlot.tscn")
const DRAWS: int = 50
const ROW_BASE: int = 101
#Contract Name, Contract Type, Level Min, Level Max, Issuer Type, Issuer, Story, Roles.
const TEST_ROWS: Array = [
	["TEST Noble", "TEST Gate", "3", "6", "person", "Noble", "", ""],
	["TEST Place", "TEST Gate", "", "", "place", "TEST Hamlet", "", ""],
	["TEST Org", "TEST Gate", "", "", "org", "TEST Guild", "", ""],
	["TEST Blank", "TEST Gate", "", "", "", "", "", ""],
	["TEST Story", "TEST Story", "", "", "", "", "TRUE", ""],
	["TEST Roles", "TEST Story", "", "", "", "", "", "Driver, Investigator"],
	["TEST High", "TEST High", "30", "", "", "", "", ""],
]
const COLUMNS: Array[String] = ["Contract Name", "Contract Type", "Level Min", "Level Max", "Issuer Type", "Issuer",
	"Story", "Roles"]
const ORG_ROW: Dictionary = {"Name": "TEST Guild", "Type": "Guild", "Home": "Aerdis"}
const GATE_ROWS: Array[String] = ["TEST Noble", "TEST Place", "TEST Org", "TEST Blank"]
const HIGH_ONLY: Array[String] = ["TEST High"]

static var _saved_rows: Array[Dictionary] = []
static var _saved_orgs: Array[Dictionary] = []
static var _saved_pins: Array[String] = []
static var _saved_roster: Array[MercenaryData] = []
static var _test_rows: Array[Dictionary] = []


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_saved_rows = DataManager.contract_rows
	_saved_orgs = DataManager.organization_rows
	_saved_pins = ContractLibrary.pinned_names.duplicate()
	_saved_roster.assign(GuildRoster.mercs)
	#Suites run before the harness build, so the library is built here and the cleanup compares like with like.
	ContractResourceBuilder.build_all()
	var before_names: Array[String] = ContractLibrary.contract_names()
	if not _make_rows():
		TestFixtures.check(res, "gate:military_row", false, "no Military row")
		return TestFixtures.summarize(res, "CONTRACTGATE")
	_case_level_ok(res)
	_case_blank_draws(res)
	_case_round(res)
	_case_build_retry(res)
	_case_opening_board(res)
	_case_issuer_words(res)
	_case_issuer_texts(res)
	_case_seats(res)
	_case_org_posting(res)
	_case_people_subs(res)
	_case_story(res)
	_case_roles(res)
	_case_cdv_min_only(res)
	_case_kind_word(res)
	_case_issuers_criterion(res)
	_case_detail_kind_text(res)
	_case_generate_type(res)
	await _case_bare_slot(res, host)
	await _case_window(res, host)
	_case_campaign_post(res)
	_restore()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	var after_names: Array[String] = ContractLibrary.contract_names()
	var files_left: Array[String] = []
	for row: Array in TEST_ROWS:
		if FileAccess.file_exists(ContractResourceBuilder.contract_path(String(row[0]))):
			files_left.append(String(row[0]))
	TestFixtures.check(res, "gate:rows_cleanup", after_names == before_names and files_left.is_empty()
		and ContractLibrary.pinned_names == _saved_pins,
		"names %d of %d, files %s" % [after_names.size(), before_names.size(), ", ".join(files_left)])
	return TestFixtures.summarize(res, "CONTRACTGATE")


#The test rows: copies of the stock Military row with the page 1 cells overwritten.
static func _make_rows() -> bool:
	var military: Dictionary = {}
	for row: Dictionary in _saved_rows:
		if ContractResourceBuilder.row_name(row) == "Military":
			military = row
			break
	if military.is_empty():
		return false
	_test_rows.clear()
	for i: int in TEST_ROWS.size():
		var cells: Array = TEST_ROWS[i]
		var row: Dictionary = military.duplicate(true)
		for c: int in COLUMNS.size():
			row[COLUMNS[c]] = cells[c]
		row["_row"] = ROW_BASE + i
		_test_rows.append(row)
	return true


static func _inject(pins: Array[String]) -> void:
	var rows: Array[Dictionary] = []
	rows.append_array(_saved_rows)
	rows.append_array(_test_rows)
	DataManager.contract_rows = rows
	var orgs: Array[Dictionary] = []
	orgs.append_array(_saved_orgs)
	orgs.append(ORG_ROW.duplicate())
	DataManager.organization_rows = orgs
	ContractResourceBuilder.build_all()
	ContractLibrary.pinned_names = pins.duplicate()
	TestFixtures.reset_generator_rolls()
	seed(7)


static func _restore() -> void:
	DataManager.contract_rows = _saved_rows
	DataManager.organization_rows = _saved_orgs
	ContractLibrary.pinned_names = _saved_pins.duplicate()
	GuildRoster.set_roster(_saved_roster)
	ContractResourceBuilder.build_all()


static func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


#A fresh board over freshly seeded issuer seats, so every group has free named seats.
static func _seated_board() -> ContractBoard:
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	return ContractBoard.new()


static func _ctx(board: ContractBoard, level: int) -> Dictionary:
	var ctx: Dictionary = DailyContractRound.context(board, 0)
	ctx["level"] = level
	return ctx


static func _people_seat() -> int:
	return ContractIssuer.seat_id("people", 0)


static func _post_one(ctx: Dictionary, board: ContractBoard, rng: RandomNumberGenerator, issuer: int) -> BoardEntry:
	var applied: Array[String] = []
	return GenPosting.generate_one(ctx, board, 0, rng, issuer, applied, {})


static func _name_of(entry: BoardEntry) -> String:
	if entry == null or entry.contract == null:
		return "null"
	return entry.contract.contract_name


static func _case_level_ok(res: Dictionary) -> void:
	var c := ContractData.new()
	TestFixtures.check(res, "gate:level_ok_blank", ContractGenerator.level_ok(c, 1) and ContractGenerator.level_ok(c, 40)
		and ContractGenerator.level_ok(c, 240), "min 0 max 0")
	c.level_min = 3
	TestFixtures.check(res, "gate:level_ok_min_only", not ContractGenerator.level_ok(c, 2)
		and ContractGenerator.level_ok(c, 3) and ContractGenerator.level_ok(c, 99), "min 3 max 0")
	c.level_min = 0
	c.level_max = 4
	TestFixtures.check(res, "gate:level_ok_max_only", ContractGenerator.level_ok(c, 1)
		and ContractGenerator.level_ok(c, 4) and not ContractGenerator.level_ok(c, 5), "min 0 max 4")
	c.level_min = 3
	c.level_max = 6
	TestFixtures.check(res, "gate:level_ok_both", not ContractGenerator.level_ok(c, 2)
		and ContractGenerator.level_ok(c, 3) and ContractGenerator.level_ok(c, 6)
		and not ContractGenerator.level_ok(c, 7), "min 3 max 6")
	TestFixtures.check(res, "gate:level_ok_null", not ContractGenerator.level_ok(null, 5), "null contract")


static func _case_blank_draws(res: Dictionary) -> void:
	_inject(_saved_pins)
	var board := ContractBoard.new()
	var ctx: Dictionary = _ctx(board, 0)
	var shares: Dictionary = GenPosting.shares_of(board, float(ctx["diff_centre"]))
	var places: Array[Dictionary] = ctx["places"]
	var applied: Array[String] = []
	var a: RandomNumberGenerator = _rng()
	var b: RandomNumberGenerator = _rng()
	var at_zero: ContractData = GenPick.row(ctx, shares, a, applied, {}, places, 0)
	var at_five: ContractData = GenPick.row(ctx, shares, b, applied, {}, places, 5)
	var name_a: String = at_zero.contract_name if at_zero != null else "null"
	var name_b: String = at_five.contract_name if at_five != null else "null"
	TestFixtures.check(res, "gate:blank_rows_take_no_draws", at_zero != null and name_a == name_b and a.state == b.state,
		"level 0 %s level 5 %s state %d %d" % [name_a, name_b, a.state, b.state])
	_restore()


static func _case_round(res: Dictionary) -> void:
	for level: int in [8, 4]:
		_inject(GATE_ROWS)
		var board: ContractBoard = _seated_board()
		var rng: RandomNumberGenerator = _rng()
		var ctx: Dictionary = _ctx(board, level)
		var posted: int = 0
		var noble: int = 0
		for _i: int in range(DRAWS):
			var entry: BoardEntry = _post_one(ctx, board, rng, _people_seat())
			if entry == null:
				continue
			posted += 1
			if _name_of(entry) == "TEST Noble":
				noble += 1
		if level == 8:
			TestFixtures.check(res, "gate:round_skips_ineligible", noble == 0 and posted >= 1,
				"posted %d noble %d" % [posted, noble])
		else:
			TestFixtures.check(res, "gate:round_keeps_eligible", noble >= 1, "posted %d noble %d" % [posted, noble])
		_restore()
	_inject(HIGH_ONLY)
	var high_board: ContractBoard = _seated_board()
	var high_rng: RandomNumberGenerator = _rng()
	var high_ctx: Dictionary = _ctx(high_board, 8)
	var issuer: int = _people_seat()
	var nulls: int = 0
	var reasons: int = 0
	ContractGenerator.gate_line = ""
	for _i: int in range(DRAWS):
		if _post_one(high_ctx, high_board, high_rng, issuer) == null:
			nulls += 1
			if GenPosting.null_reason == "level gate":
				reasons += 1
	TestFixtures.check(res, "gate:round_no_row_null", nulls == DRAWS and reasons == DRAWS,
		"nulls %d level gate %d last %s" % [nulls, reasons, GenPosting.null_reason])
	TestFixtures.check(res, "gate:round_log_line", ContractGenerator.gate_line == "BOARD: no row eligible at level 8",
		"line %s" % ContractGenerator.gate_line)
	var reason: String = HarnessPlays._no_post_reason("TEST High", issuer)
	TestFixtures.check(res, "gate:harness_reason", reason == "level gate", "reason %s" % reason)
	_restore()


static func _case_build_retry(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST Noble", "TEST Place", "TEST Org", "TEST Blank", "TEST High"]
	_inject(pins)
	GuildRoster.reset()
	var types: Array[String] = ["TEST High", "TEST Gate"]
	var anywhere: Array[String] = []
	var nulls: int = 0
	var off: Array[String] = []
	for _i: int in range(DRAWS):
		var drawn: ContractData = ContractGenerator.generate_for(types, anywhere, 0.5, 5.0)
		if drawn == null:
			nulls += 1
		elif ["TEST High", "TEST Noble"].has(drawn.contract_name) and not off.has(drawn.contract_name):
			off.append(drawn.contract_name)
	TestFixtures.check(res, "gate:build_retry_eligible", nulls == 0 and off.is_empty(),
		"nulls %d off %s" % [nulls, ", ".join(off)])
	_restore()
	_inject(HIGH_ONLY)
	GuildRoster.reset()
	var high_types: Array[String] = ["TEST High"]
	var built: int = 0
	ContractGenerator.gate_line = ""
	for _i: int in range(DRAWS):
		if ContractGenerator.generate_for(high_types, anywhere, 0.5, 5.0) != null:
			built += 1
	TestFixtures.check(res, "gate:build_null_when_none",
		built == 0 and ContractGenerator.gate_line == "BOARD: no row eligible at level 1",
		"built %d line %s" % [built, ContractGenerator.gate_line])
	_restore()


static func _case_opening_board(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST High", "TEST Blank"]
	_inject(pins)
	GuildRoster.reset()
	var board := ContractBoard.new()
	board.launch(0, 4)
	var names: Array[String] = []
	for entry: BoardEntry in board.entries:
		names.append(_name_of(entry))
	TestFixtures.check(res, "gate:opening_board_gates", names.size() == 4 and not names.has("TEST High"),
		"posted %s" % ", ".join(names))
	_restore()
	_inject(HIGH_ONLY)
	GuildRoster.reset()
	var empty_board := ContractBoard.new()
	ContractGenerator.gate_line = ""
	empty_board.launch(0, 3)
	TestFixtures.check(res, "gate:opening_board_empty", empty_board.entries.is_empty(),
		"entries %d" % empty_board.entries.size())
	TestFixtures.check(res, "gate:opening_board_log", ContractGenerator.gate_line == "BOARD: no row eligible at level 1",
		"line %s" % ContractGenerator.gate_line)
	var named: ContractData = ContractGenerator.generate_named("TEST High")
	TestFixtures.check(res, "gate:generate_named_not_gated", named != null,
		"level %d" % (named.contract_level if named != null else -1))
	_restore()


static func _case_issuer_words(res: Dictionary) -> void:
	_inject(GATE_ROWS)
	_seated_board()
	var org_seat: int = ContractIssuer.seat_id("orgs", 0)
	var words: Array[String] = []
	for row: String in ["TEST Noble", "TEST Place", "TEST Org"]:
		words.append(ContractBoard.issuer_word(ContractGenerator.generate_named(row), org_seat))
	var want: Array[String] = ["person", "place", "org"]
	TestFixtures.check(res, "gate:issuer_word_typed", words == want, "words %s" % ", ".join(words))
	var blank: ContractData = ContractGenerator.generate_named("TEST Blank")
	var by_seat: Array[String] = []
	for group: String in ["orgs", "people", "places"]:
		by_seat.append(ContractBoard.issuer_word(blank, ContractIssuer.seat_id(group, 0)))
	var want_seat: Array[String] = ["org", "person", "place"]
	TestFixtures.check(res, "gate:issuer_word_blank_by_seat", by_seat == want_seat, "words %s" % ", ".join(by_seat))
	_restore()


static func _case_issuer_texts(res: Dictionary) -> void:
	_inject(GATE_ROWS)
	var seat: int = _people_seat()
	var noble: ContractData = ContractGenerator.generate_named("TEST Noble")
	var texts: Array[String] = []
	for requestor: String in ["Ada", "", "Unknown"]:
		noble.requestor_name = requestor
		texts.append(ContractBoard.issuer_text(noble, seat))
	var want: Array[String] = ["Ada", "Noble", "Noble"]
	TestFixtures.check(res, "gate:issuer_text_person", texts == want, "texts %s" % ", ".join(texts))
	var place: String = ContractBoard.issuer_text(ContractGenerator.generate_named("TEST Place"), seat)
	TestFixtures.check(res, "gate:issuer_text_place", place == "TEST Hamlet", "text %s" % place)
	var org: String = ContractBoard.issuer_text(ContractGenerator.generate_named("TEST Org"), seat)
	TestFixtures.check(res, "gate:issuer_text_org", org == "TEST Guild", "text %s" % org)
	_restore()
	_inject(GATE_ROWS)
	_seated_board()
	var blank: String = ContractBoard.issuer_text(ContractGenerator.generate_named("TEST Blank"), seat)
	TestFixtures.check(res, "gate:issuer_text_blank", blank != "" and blank == IssuerOpinion.name_of(seat),
		"text %s seat %s" % [blank, IssuerOpinion.name_of(seat)])
	_restore()


static func _case_seats(res: Dictionary) -> void:
	_inject(GATE_ROWS)
	var board: ContractBoard = _seated_board()
	var rng: RandomNumberGenerator = _rng()
	var org_seat: int = ContractIssuer.seat_id("orgs", 0)
	var noble: ContractData = ContractGenerator.generate_named("TEST Noble")
	var moved: int = GenIssuer.for_row(noble, org_seat, board, 0, rng)
	TestFixtures.check(res, "gate:seat_regroup", IssuerOpinion.group_of(moved) == "people",
		"seat %d group %s" % [moved, IssuerOpinion.group_of(moved)])
	var blank: ContractData = ContractGenerator.generate_named("TEST Blank")
	var state: int = rng.state
	var kept: int = GenIssuer.for_row(blank, org_seat, board, 0, rng)
	TestFixtures.check(res, "gate:seat_keep_blank", kept == org_seat and rng.state == state,
		"seat %d of %d state moved %s" % [kept, org_seat, rng.state != state])
	var first: int = ContractBoard.seat_for_row(noble, 7)
	var again: int = ContractBoard.seat_for_row(noble, 7)
	var want: int = ContractIssuer.seat_id("people", posmod(6, ContractIssuer.group_size("people")))
	var spread: Array[int] = []
	for entry_id: int in [1, 2, 3]:
		var seat: int = ContractBoard.seat_for_row(noble, entry_id)
		if not spread.has(seat):
			spread.append(seat)
	TestFixtures.check(res, "gate:opening_seat_deterministic", first == again
		and ContractIssuer.kind_of_seat(first) == "people" and first == want and spread.size() == 3,
		"seat %d again %d want %d distinct %d" % [first, again, want, spread.size()])
	_restore()


static func _case_org_posting(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST Org"]
	_inject(pins)
	var board: ContractBoard = _seated_board()
	var entry: BoardEntry = _post_one(_ctx(board, 5), board, _rng(), _people_seat())
	var group: String = IssuerOpinion.group_of(entry.issuer_id) if entry != null else ""
	TestFixtures.check(res, "gate:org_row_org_seat", entry != null and group == "orgs"
		and entry.issuer == "TEST Guild" and entry.issuer_type == "org",
		"null %s" % GenPosting.null_reason if entry == null
		else "group %s issuer %s type %s" % [group, entry.issuer, entry.issuer_type])
	_restore()


static func _case_people_subs(res: Dictionary) -> void:
	TestFixtures.check(res, "gate:people_subs_four", ClientRegistry.PEOPLE_SUBS == ContractDataValidator.PERSON_ISSUERS,
		"subs %s" % ", ".join(ClientRegistry.PEOPLE_SUBS))


static func _case_story(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST Story", "TEST Blank"]
	_inject(pins)
	var board := ContractBoard.new()
	var story_entry: BoardEntry = board.post(ContractGenerator.generate_named("TEST Story"), 0)
	var blank_entry: BoardEntry = board.post(ContractGenerator.generate_named("TEST Blank"), 0)
	var story_view: ContractView = ContractView.from_entry(story_entry, 0)
	var blank_view: ContractView = ContractView.from_entry(blank_entry, 0)
	TestFixtures.check(res, "gate:story_view_flag", story_view.story and not blank_view.story,
		"story %s blank %s" % [story_view.story, blank_view.story])
	_restore()
	var story_pin: Array[String] = ["TEST Story"]
	_inject(story_pin)
	var round_board: ContractBoard = _seated_board()
	var rng: RandomNumberGenerator = _rng()
	var ctx: Dictionary = _ctx(round_board, 5)
	var drawn: BoardEntry = null
	for _i: int in range(DRAWS):
		drawn = _post_one(ctx, round_board, rng, _people_seat())
		if drawn != null:
			break
	var posted: BoardEntry = round_board.post(ContractGenerator.generate_named("TEST Story"), 0)
	TestFixtures.check(res, "gate:board_entry_story_untouched", drawn != null and _name_of(drawn) == "TEST Story"
		and not drawn.story and not posted.story,
		"round %s story %s post story %s" % [_name_of(drawn), drawn.story if drawn != null else false, posted.story])
	_restore()


static func _case_roles(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST Blank", "TEST Roles"]
	_inject(pins)
	var blank: Array[String] = DispatchWindow.roles_for(ContractGenerator.generate_named("TEST Blank"))
	var want_blank: Array[String] = ["Support"]
	TestFixtures.check(res, "gate:roles_blank", blank == want_blank, "roles %s" % ", ".join(blank))
	var listed_row: ContractData = ContractGenerator.generate_named("TEST Roles")
	var listed: Array[String] = DispatchWindow.roles_for(listed_row)
	var want_listed: Array[String] = ["Support", "Driver", "Investigator"]
	TestFixtures.check(res, "gate:roles_listed", listed == want_listed, "roles %s" % ", ".join(listed))
	var odd: ContractData = listed_row.duplicate()
	var odd_roles: Array[String] = ["Pilot", "Leader", "Escort"]
	odd.roles = odd_roles
	var dropped: Array[String] = DispatchWindow.roles_for(odd)
	var want_dropped: Array[String] = ["Support", "Escort"]
	TestFixtures.check(res, "gate:roles_unknown_dropped", dropped == want_dropped, "roles %s" % ", ".join(dropped))
	var guided: ContractData = listed_row.duplicate()
	var guided_roles: Array[String] = ["Guide", "Driver", "Leader", "Support"]
	guided.roles = guided_roles
	var named: Array[String] = DispatchWindow.roles_for(guided)
	var want_named: Array[String] = ["Support", "Driver", "Guide"]
	TestFixtures.check(res, "gate:roles_guide_named", named == want_named, "roles %s" % ", ".join(named))
	TestFixtures.check(res, "gate:roles_investigator", GuiTypes.ROLES.size() == 7 and GuiTypes.ROLES[6] == "Investigator"
		and DispatchWindow.roles_for(null) == TeamSlot.slot_roles(), "roles %s" % ", ".join(GuiTypes.ROLES))
	_restore()


static func _case_cdv_min_only(res: Dictionary) -> void:
	var data := ContractData.new()
	data.level_min = 5
	data.level_max = 0
	var open_top: int = _above_count(ContractDataValidator._level_warnings(data, ROW_BASE))
	data.level_min = 6
	data.level_max = 4
	var crossed: int = _above_count(ContractDataValidator._level_warnings(data, ROW_BASE))
	TestFixtures.check(res, "gate:cdv_min_only", open_top == 0 and crossed == 1,
		"min 5 max 0: %d; min 6 max 4: %d" % [open_top, crossed])


static func _above_count(lines: Array[String]) -> int:
	var count: int = 0
	for line: String in lines:
		if line.contains("above Level Max"):
			count += 1
	return count


static func _case_kind_word(res: Dictionary) -> void:
	var inputs: Array = ["person", "Bogus", 1, 2, 3, 4, 0, 1.0, null]
	var got: Array[String] = []
	for value: Variant in inputs:
		got.append(ContractView.kind_word(value))
	var want: Array[String] = ["person", "", "person", "place", "org", "person", "org", "person", ""]
	TestFixtures.check(res, "gate:view_kind_word", got == want, "words %s" % ", ".join(got))


static func _case_issuers_criterion(res: Dictionary) -> void:
	var pins: Array[String] = ["TEST Noble", "TEST Org", "TEST Blank"]
	_inject(pins)
	var board := ContractBoard.new()
	var ctx: Dictionary = _ctx(board, 5)
	var shares: Dictionary = GenPosting.shares_of(board, float(ctx["diff_centre"]))
	var places: Array[Dictionary] = ctx["places"]
	var applied: Array[String] = ["issuers"]
	var rng: RandomNumberGenerator = _rng()
	var noble: int = 0
	var kept: int = 0
	for _i: int in range(DRAWS):
		var row: ContractData = GenPick.row(ctx, shares, rng, applied, {}, places)
		if row == null:
			continue
		if row.contract_name == "TEST Noble":
			noble += 1
		elif row.contract_name == "TEST Org" or row.contract_name == "TEST Blank":
			kept += 1
	TestFixtures.check(res, "gate:issuers_criterion_rows", noble == 0 and kept >= 1,
		"noble %d org or blank %d" % [noble, kept])
	_restore()


static func _view_of(word: String, issuer_class: String) -> ContractView:
	var view := ContractView.new()
	view.issuer_type = word
	view.issuer_class = issuer_class
	return view


static func _case_detail_kind_text(res: Dictionary) -> void:
	var texts: Array[String] = [
		ContractDetail.issuer_kind_text(_view_of("person", "Noble")),
		ContractDetail.issuer_kind_text(_view_of("person", "")),
		ContractDetail.issuer_kind_text(_view_of("place", "")),
		ContractDetail.issuer_kind_text(_view_of("org", "")),
		ContractDetail.issuer_kind_text(_view_of("", "")),
	]
	var want: Array[String] = ["Person, Noble", "Person", "Place", "Org", "Unknown"]
	_inject(GATE_ROWS)
	var board := ContractBoard.new()
	var noble: ContractView = ContractView.from_entry(board.post(ContractGenerator.generate_named("TEST Noble"), 0), 0)
	var place: ContractView = ContractView.from_entry(board.post(ContractGenerator.generate_named("TEST Place"), 0), 0)
	TestFixtures.check(res, "gate:detail_kind_text", texts == want and noble.issuer_type == "person"
		and noble.issuer_class == "Noble" and place.issuer_class == "",
		"texts %s; noble %s %s; place class %s" % [" | ".join(texts), noble.issuer_type, noble.issuer_class,
		place.issuer_class])
	_restore()


static func _case_generate_type(res: Dictionary) -> void:
	_inject(HIGH_ONLY)
	GuildRoster.reset()
	var built: ContractData = ContractGenerator.generate("TEST High")
	TestFixtures.check(res, "gate:generate_type_not_gated", built != null and built.contract_name == "TEST High",
		"built %s" % (built.contract_name if built != null else "null"))
	_restore()


#GuiContractTests._fresh: start a new game from the stock pins after the rows are restored.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _case_bare_slot(res: Dictionary, host: Node) -> void:
	_fresh()
	var node: TeamSlot = SLOT.instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	var labels: Array[String] = []
	for option: Dictionary in node.role_option.options:
		labels.append(String(option.get("label", "")))
	TestFixtures.check(res, "gate:bare_slot_fallback", labels == TeamSlot.slot_roles(), "labels %s" % ", ".join(labels))
	node.queue_free()
	await host.get_tree().process_frame


static func _case_window(res: Dictionary, host: Node) -> void:
	var pins: Array[String] = ["TEST Roles"]
	_inject(pins)
	var data: ContractData = ContractGenerator.generate_named("TEST Roles")
	_restore()
	_fresh()
	var now: int = CampaignClock.now()
	var view: ContractView = ContractView.from_entry(GameState.board.post(data, now), now)
	view.merc_min = 2
	view.merc_max = 5
	var window: DispatchWindow = WINDOW.instantiate()
	window.contract = view
	host.add_child(window)
	await host.get_tree().process_frame
	var ok: bool = window.roles.size() >= 3 and window.slot_at(1) != null
	var why: String = "roles %d" % window.roles.size()
	if ok:
		var labels: Array[String] = []
		for option: Dictionary in window.slot_at(1).role_option.options:
			labels.append(String(option.get("label", "")))
		var before: String = window.roles[1]
		window.set_role(1, "Assassin")
		var refused: bool = window.roles[1] == before and window.slot_at(1).role() == before
		window.set_role(1, "Investigator")
		var taken: bool = window.roles[1] == "Investigator" and window.slot_at(1).role() == "Investigator"
		var leader: String = window.slot_at(0).role()
		ok = labels == window.offered_roles and refused and taken and leader == "Leader"
		why = "options %s offered %s refused %s taken %s leader %s" % [", ".join(labels),
			", ".join(window.offered_roles), refused, taken, leader]
	TestFixtures.check(res, "gate:window_offer_and_refuse", ok, why)
	window.queue_free()
	await host.get_tree().process_frame


static func _case_campaign_post(res: Dictionary) -> void:
	_inject(HIGH_ONLY)
	var data: ContractData = ContractGenerator.generate_named("TEST High")
	_restore()
	_fresh()
	var entry: BoardEntry = GameState.post_campaign_contract(data, 1, true)
	TestFixtures.check(res, "gate:campaign_post_not_gated", data != null and entry != null,
		"entry %s" % ("null" if entry == null else _name_of(entry)))

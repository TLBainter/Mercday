class_name StatusBadgeTests

#The merc status badge: the eight atlas ids, the colour rules, the status fractions, the roster
#count rule, the captive filter of the roster list and the defected badge on a results row.
#Run with the status-badge-tests harness flag.

const MERC_VIEWER: PackedScene = preload("res://Scenes/GUI/Mercs/MercViewer.tscn")
const PORTRAIT: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const PANEL: PackedScene = preload("res://Scenes/GUI/Results/ContractResults.tscn")
const EXTRA_MERCS: int = 3
const DAY: int = CampaignClock.MINUTES_PER_DAY
const HOUR: int = CampaignClock.MINUTES_PER_HOUR
const FRACTIONS: Array[float] = [0.0, 0.5, 1.0]
const NO_FRACTION: float = -1.0
const FAKE_ENTRY: int = 990001

#id, cell column, trimmed offset, trimmed size: the pixel scan of row 6 of the sheet.
const BADGES: Array[Array] = [
	["status_preparing", 7, Vector2i(1, 6), Vector2i(14, 4)],
	["status_contract", 8, Vector2i(0, 2), Vector2i(16, 12)],
	["status_resting", 9, Vector2i(2, 0), Vector2i(12, 15)],
	["status_captured", 10, Vector2i(0, 0), Vector2i(16, 16)],
	["status_dead", 11, Vector2i(2, 1), Vector2i(13, 15)],
	["status_defected", 12, Vector2i(0, 0), Vector2i(16, 16)],
	["status_missing", 13, Vector2i(1, 0), Vector2i(14, 16)],
	["status_vacation", 14, Vector2i(0, 0), Vector2i(16, 16)],
]
const BADGE_ROW: int = 6


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	_case_ids(res)
	_case_ordinals(res)
	_case_colors(res)
	_case_roster_rule(res)
	_case_missing(res)
	_case_preparing(res)
	_case_rest(res)
	_case_contract(res)
	_case_tables(res)
	_case_flee_missing(res)
	_case_rest_lock(res)
	_case_dead(res)
	_case_view_fractions(res)
	_case_dispatched(res)
	_case_counts(res)
	await _case_portrait(res, host)
	await _case_captive_filter(res, host)
	await _case_legal_hold(res, host)
	await _case_clock_tint(res, host)
	await _case_defected_row(res, host)
	_fresh()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "STATUS BADGE")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(11)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


static func _same(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)


static func _case_ids(res: Dictionary) -> void:
	var bad: Array[String] = []
	for row: Array in BADGES:
		var id: String = String(row[0])
		if not Icons.has(id):
			bad.append("%s missing" % id)
			continue
		if Icons.cell(id) != Vector2i(int(row[1]), BADGE_ROW):
			bad.append("%s cell %s" % [id, Icons.cell(id)])
		if Icons.offset(id) != row[2] or Icons.size(id) != row[3]:
			bad.append("%s box %s %s" % [id, Icons.offset(id), Icons.size(id)])
		if not Icons.is_mono(id):
			bad.append("%s not mono" % id)
	TestFixtures.check(res, "the eight status ids sit in row 6 with their trimmed boxes and mono tint",
		bad.is_empty(), TestFixtures.detail(bad, BADGES.size(), "ids"))
	var mapped: Array[String] = []
	for status: int in GuiTypes.BADGE_IDS:
		mapped.append(GuiTypes.badge_id(status))
	var named: bool = true
	for row: Array in BADGES:
		named = named and mapped.has(String(row[0]))
	TestFixtures.check(res, "every status id is the badge of one status", named and mapped.size() == BADGES.size(),
		str(mapped))


static func _case_ordinals(res: Dictionary) -> void:
	var held: Array[int] = [GuiTypes.MercStatus.AVAILABLE, GuiTypes.MercStatus.RESTING, GuiTypes.MercStatus.CONTRACT,
		GuiTypes.MercStatus.VACATION, GuiTypes.MercStatus.LOAN, GuiTypes.MercStatus.DEAD, GuiTypes.MercStatus.FIRED,
		GuiTypes.MercStatus.MISSING, GuiTypes.MercStatus.CAPTURED, GuiTypes.MercStatus.ODD_JOB,
		GuiTypes.MercStatus.PREPARING, GuiTypes.MercStatus.DEFECTED]
	TestFixtures.check(res, "the status ordinals hold, Preparing and Defected at the end",
		held == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], str(held))
	var preparing: String = GuiTypes.merc_status_text(GuiTypes.MercStatus.PREPARING)
	var defected: String = GuiTypes.merc_status_text(GuiTypes.MercStatus.DEFECTED)
	TestFixtures.check(res, "Preparing and Defected read their names", preparing == "Preparing" and defected == "Defected",
		"%s %s" % [preparing, defected])


static func _case_colors(res: Dictionary) -> void:
	TestFixtures.check(res, "the ramp runs red at 0, yellow at 0.5 and green at 1",
		_same(GuiColors.ramp_color(0.0), GuiColors.RAMP_RED) and _same(GuiColors.ramp_color(0.5), GuiColors.RAMP_YELLOW)
			and _same(GuiColors.ramp_color(1.0), GuiColors.RAMP_GREEN),
		"%s %s %s" % [GuiColors.ramp_color(0.0), GuiColors.ramp_color(0.5), GuiColors.ramp_color(1.0)])
	var bad: Array[String] = []
	for f: float in FRACTIONS:
		for status: int in [GuiTypes.MercStatus.PREPARING, GuiTypes.MercStatus.MISSING]:
			if not _same(GuiTypes.badge_color(status, f), GuiColors.ramp_color(f)):
				bad.append("falling %d at %.1f" % [status, f])
		for status: int in [GuiTypes.MercStatus.CONTRACT, GuiTypes.MercStatus.RESTING, GuiTypes.MercStatus.VACATION]:
			if not _same(GuiTypes.badge_color(status, f), GuiColors.ramp_color(1.0 - f)):
				bad.append("rising %d at %.1f" % [status, f])
		if not _same(GuiTypes.badge_color(GuiTypes.MercStatus.CAPTURED, f), GuiColors.ORANGE):
			bad.append("captured at %.1f" % f)
		for status: int in [GuiTypes.MercStatus.DEAD, GuiTypes.MercStatus.DEFECTED]:
			if not _same(GuiTypes.badge_color(status, f), GuiColors.RED):
				bad.append("fixed red %d at %.1f" % [status, f])
	TestFixtures.check(res, "each badge reads its colour rule at 0, 0.5 and 1", bad.is_empty(),
		TestFixtures.detail(bad, 3, "colours"))
	TestFixtures.check(res, "Preparing is green as it begins and red as it ends; Contract the other way",
		_same(GuiTypes.badge_color(GuiTypes.MercStatus.PREPARING, 1.0), GuiColors.RAMP_GREEN)
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.PREPARING, 0.0), GuiColors.RAMP_RED)
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.CONTRACT, 1.0), GuiColors.RAMP_RED)
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.CONTRACT, 0.0), GuiColors.RAMP_GREEN), "ends")
	TestFixtures.check(res, "an unknown fraction reads the middle of the ramp; fixed colours stay fixed",
		_same(GuiTypes.badge_color(GuiTypes.MercStatus.RESTING, NO_FRACTION), GuiColors.ramp_color(0.5))
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.MISSING, NO_FRACTION), GuiColors.ramp_color(0.5))
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.CAPTURED, NO_FRACTION), GuiColors.ORANGE)
			and _same(GuiTypes.badge_color(GuiTypes.MercStatus.DEAD, NO_FRACTION), GuiColors.RED),
		str(GuiTypes.badge_color(GuiTypes.MercStatus.RESTING, NO_FRACTION)))


static func _case_roster_rule(res: Dictionary) -> void:
	var counted: Array[int] = [GuiTypes.MercStatus.AVAILABLE, GuiTypes.MercStatus.PREPARING, GuiTypes.MercStatus.CONTRACT,
		GuiTypes.MercStatus.RESTING, GuiTypes.MercStatus.CAPTURED, GuiTypes.MercStatus.MISSING, GuiTypes.MercStatus.VACATION,
		GuiTypes.MercStatus.LOAN, GuiTypes.MercStatus.ODD_JOB]
	var bad: Array[String] = []
	for status: int in counted:
		if not GuiTypes.counts_toward_roster(status):
			bad.append("%d left out" % status)
	for status: int in [GuiTypes.MercStatus.DEAD, GuiTypes.MercStatus.DEFECTED, GuiTypes.MercStatus.FIRED]:
		if GuiTypes.counts_toward_roster(status):
			bad.append("%d counted" % status)
	TestFixtures.check(res, "the roster counts every status but Dead, Defected and Fired", bad.is_empty(),
		str(bad))


static func _case_missing(res: Dictionary) -> void:
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	var now: int = CampaignClock.now()
	var cases: Array[Array] = [[10 * DAY, 5 * DAY, 0.5], [10 * DAY, 0, 1.0], [10 * DAY, 10 * DAY, 0.0],
		[10 * DAY, 20 * DAY, 0.0], [HOUR, 12 * HOUR, 0.5]]
	var bad: Array[String] = []
	for row: Array in cases:
		merc.missing_since = now - int(row[1])
		merc.hired_minute = merc.missing_since - int(row[0])
		var state: Dictionary = GameState.merc_status(merc)
		var fraction: float = float(state["fraction"])
		if int(state["status"]) != GuiTypes.MercStatus.MISSING or not is_equal_approx(fraction, float(row[2])):
			bad.append("tenure %d elapsed %d: %d %.3f" % [int(row[0]), int(row[1]), int(state["status"]),
				float(state["fraction"])])
	TestFixtures.check(res, "Missing runs out over the tenure, floored at a day, red when elapsed meets it",
		bad.is_empty(), TestFixtures.detail(bad, cases.size(), "cases"))
	merc.hired_minute = -1
	var unknown: Dictionary = GameState.merc_status(merc)
	TestFixtures.check(res, "Missing with no hire minute has an unknown fraction",
		float(unknown["fraction"]) < 0.0, "%.2f" % float(unknown["fraction"]))
	TestFixtures.check(res, "a missing merc is busy and still counts on the roster",
		GameState.busy_uids().has(merc.merc_uid) and GuiTypes.counts_toward_roster(GuiTypes.MercStatus.MISSING),
		str(GameState.busy_uids()))
	merc.missing_since = -1


static func _case_preparing(res: Dictionary) -> void:
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	var now: int = CampaignClock.now()
	var run := ActiveRun.new()
	var member := TeamMember.new()
	member.merc_uid = merc.merc_uid
	run.team.append(member)
	run.dispatched_minute = now - 3 * HOUR
	run.depart_minute = now + HOUR
	GameState.queued[FAKE_ENTRY] = run
	var state: Dictionary = GameState.merc_status(merc)
	GameState.queued.erase(FAKE_ENTRY)
	TestFixtures.check(res, "a queued merc is Preparing with (depart - now) / (depart - dispatched) left",
		int(state["status"]) == GuiTypes.MercStatus.PREPARING and is_equal_approx(float(state["fraction"]), 0.25),
		"%d %.3f" % [int(state["status"]), float(state["fraction"])])


static func _case_rest(res: Dictionary) -> void:
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	var now: int = CampaignClock.now()
	merc.rest_lockout_kind = RestSystem.KIND_RESPITE
	merc.rest_lockout_start = now - 3 * HOUR
	merc.rest_lockout_until = now + HOUR
	var resting: Dictionary = GameState.merc_status(merc)
	merc.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	var away: Dictionary = GameState.merc_status(merc)
	merc.rest_lockout_start = -1
	var unknown: Dictionary = GameState.merc_status(merc)
	merc.rest_lockout_until = 0
	merc.rest_lockout_kind = ""
	TestFixtures.check(res, "Resting and Vacation read (until - now) / (until - start)",
		int(resting["status"]) == GuiTypes.MercStatus.RESTING and is_equal_approx(float(resting["fraction"]), 0.25)
			and int(away["status"]) == GuiTypes.MercStatus.VACATION and is_equal_approx(float(away["fraction"]), 0.25),
		"%d %.3f / %d %.3f" % [int(resting["status"]), float(resting["fraction"]), int(away["status"]),
			float(away["fraction"])])
	TestFixtures.check(res, "a rest with no start has an unknown fraction", float(unknown["fraction"]) < 0.0,
		"%.2f" % float(unknown["fraction"]))


static func _case_contract(res: Dictionary) -> void:
	var now: int = CampaignClock.now()
	var entry := BoardEntry.new()
	entry.id = FAKE_ENTRY
	var run := ActiveRun.new()
	run.hours = 10.0
	run.dispatched_minute = now - 4 * HOUR
	run.depart_minute = now - 2 * HOUR
	GameState.active_contracts[FAKE_ENTRY] = run
	var departed: float = GameState._contract_fraction(entry, now)
	run.depart_minute = -1
	var undeparted: float = GameState._contract_fraction(entry, now)
	run.hours = 0.0
	var unknown: float = GameState._contract_fraction(entry, now)
	GameState.active_contracts.erase(FAKE_ENTRY)
	TestFixtures.check(res, "a contract runs its stored hours from departure, else from dispatch",
		is_equal_approx(departed, 0.8) and is_equal_approx(undeparted, 0.6) and unknown < 0.0,
		"%.3f %.3f %.3f" % [departed, undeparted, unknown])


static func _case_tables(res: Dictionary) -> void:
	var bad: Array[String] = []
	for status: int in [GuiTypes.MercStatus.PREPARING, GuiTypes.MercStatus.DEFECTED]:
		if not GuiTypes.MERC_STATUS_NAMES.has(status):
			bad.append("%d name" % status)
		if not GuiTypes.MERC_STATUS_COLORS.has(status):
			bad.append("%d colour" % status)
		if not PayrollTab.ROW_OF_STATUS.has(status):
			bad.append("%d payroll row" % status)
		if String(BenefitsManager.STATUS_NOTES.get(status, "")) == "":
			bad.append("%d note" % status)
	TestFixtures.check(res, "Preparing and Defected have a name, a colour, a payroll row and a note",
		bad.is_empty() and int(PayrollTab.ROW_OF_STATUS[GuiTypes.MercStatus.PREPARING]) == 2
			and int(PayrollTab.ROW_OF_STATUS[GuiTypes.MercStatus.DEFECTED]) == 6, str(bad))


static func _case_flee_missing(res: Dictionary) -> void:
	_fresh()
	FleeTests._fresh()
	MercPool.clear()
	var party: Array[MercenaryData] = TestFixtures.add_mercs(2)
	var runner: MercenaryData = party[0]
	var now: int = CampaignClock.now()
	var settled: Dictionary = FleeTests._fled_settle(party, FleeTests._merc("Foe Badge", 0.0), runner, true)
	var cr: ContractRun = settled["run"]
	var status: int = int(GameState.merc_status(runner)["status"])
	TestFixtures.check(res, "an abandoner settled by FleeSettlement goes Missing, stays a busy merc and counts",
		cr.departed.has(runner) and runner.missing_since == now and GameState.mercs.has(runner)
			and status == GuiTypes.MercStatus.MISSING and GameState.busy_uids().has(runner.merc_uid)
			and GuiTypes.counts_toward_roster(status),
		"missing_since %d status %d" % [runner.missing_since, status])
	runner.missing_since = -1
	FleeTests._fresh()
	MercPool.clear()


static func _case_rest_lock(res: Dictionary) -> void:
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	var now: int = CampaignClock.now()
	var lines: Array[String] = []
	RestSystem._lock(merc, RestSystem.KIND_RESPITE, 4 * HOUR, "RESPITE", lines)
	var start: int = merc.rest_lockout_start
	var state: Dictionary = GameState.merc_status(merc)
	TestFixtures.check(res, "RestSystem._lock stamps the rest start and the merc rests with the whole span left",
		start == now and int(state["status"]) == GuiTypes.MercStatus.RESTING
			and is_equal_approx(float(state["fraction"]), 1.0),
		"start %d now %d status %d %.3f" % [start, now, int(state["status"]), float(state["fraction"])])
	RestSystem._unlock(merc)
	TestFixtures.check(res, "RestSystem._unlock clears the rest start",
		merc.rest_lockout_start == -1 and merc.rest_lockout_until == 0 and merc.rest_lockout_kind == "",
		"start %d until %d" % [merc.rest_lockout_start, merc.rest_lockout_until])


static func _case_dead(res: Dictionary) -> void:
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	merc.is_dead = true
	var status: int = int(GameState.merc_status(merc)["status"])
	merc.is_dead = false
	TestFixtures.check(res, "a dead merc reads Dead", status == GuiTypes.MercStatus.DEAD, "status %d" % status)


static func _case_view_fractions(res: Dictionary) -> void:
	var crew: Array[MercenaryData] = TestFixtures.add_mercs(2)
	var rester: MercenaryData = crew[0]
	var waiter: MercenaryData = crew[1]
	var now: int = CampaignClock.now()
	var lines: Array[String] = []
	RestSystem._lock(rester, RestSystem.KIND_RESPITE, 4 * HOUR, "RESPITE", lines)
	var run := ActiveRun.new()
	var member := TeamMember.new()
	member.merc_uid = waiter.merc_uid
	run.team.append(member)
	run.dispatched_minute = now - 3 * HOUR
	run.depart_minute = now + HOUR
	GameState.queued[FAKE_ENTRY] = run
	GameState.refresh_views()
	var resting: MercView = MercView.by_uid(GameState.roster, rester.merc_uid)
	var waiting: MercView = MercView.by_uid(GameState.roster, waiter.merc_uid)
	GameState.queued.erase(FAKE_ENTRY)
	RestSystem._unlock(rester)
	GameState.refresh_views()
	TestFixtures.check(res, "refresh_views hands the rest and the preparing fractions to the views",
		resting != null and resting.status == GuiTypes.MercStatus.RESTING
			and is_equal_approx(resting.status_fraction_left, 1.0) and waiting != null
			and waiting.status == GuiTypes.MercStatus.PREPARING and is_equal_approx(waiting.status_fraction_left, 0.25),
		"%.3f %.3f" % [resting.status_fraction_left if resting != null else -9.0,
			waiting.status_fraction_left if waiting != null else -9.0])


#A real dispatch by day: the merc is on the contract with the whole stored span left.
static func _case_dispatched(res: Dictionary) -> void:
	_fresh()
	var now: int = CampaignClock.now()
	if ContractScheduler.is_night_minute(now):
		CampaignClock.advance_to(ContractScheduler.next_wake_minute(now))
	var open: Array[BoardEntry] = GameState.board.available()
	var merc: MercenaryData = GameState.mercs[0]
	var run := ActiveRun.new()
	run.travel_mode = "foot"
	run.hours = 24.0
	var member := TeamMember.new()
	member.merc_uid = merc.merc_uid
	run.team.append(member)
	var sent: bool = not open.is_empty() and GameState.dispatch(open[0].id, run)
	var state: Dictionary = GameState.merc_status(merc)
	var fraction: float = float(state["fraction"])
	TestFixtures.check(res, "a dispatched merc is On a Contract with a 0..1 fraction from the real run",
		sent and int(state["status"]) == GuiTypes.MercStatus.CONTRACT and fraction >= 0.0 and fraction <= 1.0
			and is_equal_approx(fraction, 1.0),
		"sent %s status %d %.3f" % [sent, int(state["status"]), fraction])


#The old rules: employed() counted the payroll less the dead, the guild metric every living merc.
static func _case_counts(res: Dictionary) -> void:
	_fresh()
	var crew: Array[MercenaryData] = TestFixtures.add_mercs(3)
	MercPool.add_captive(crew[0], "Escort", "Aerdis", "Day 1")
	crew[1].is_dead = true
	GameState.set_away(crew[2].merc_uid, GuiTypes.MercStatus.FIRED)
	var old_employed: int = 0
	var old_count: int = 0
	for merc: MercenaryData in GameState.mercs:
		if merc == null or merc.is_dead:
			continue
		old_count += 1
		if GameState.away_status(merc.merc_uid) != GuiTypes.MercStatus.FIRED:
			old_employed += 1
	var employed: int = SubscriptionManager.employed()
	var count: int = int(GameState._guild_metrics(0)["count"])
	TestFixtures.check(res, "employed() and the guild count match the old rules over a captive, a dead and a fired merc",
		employed == old_employed and count == old_count and old_employed == old_count - 1,
		"employed %d/%d count %d/%d" % [employed, old_employed, count, old_count])
	MercPool.take_captive(crew[0].merc_uid)
	crew[1].is_dead = false
	GameState.clear_away(crew[2].merc_uid)


static func _view(status: int, fraction: float) -> MercView:
	var view := MercView.new()
	view.uid = 77
	view.name = "Badge Probe"
	view.status = status
	view.status_fraction_left = fraction
	return view


static func _case_portrait(res: Dictionary, host: Node) -> void:
	var face: MercPortrait = PORTRAIT.instantiate() as MercPortrait
	host.add_child(face)
	await host.get_tree().process_frame
	face.set_merc(null)
	var none_null: bool = not face.badge_shown()
	var bad: Array[String] = []
	for status: int in [GuiTypes.MercStatus.AVAILABLE, GuiTypes.MercStatus.LOAN, GuiTypes.MercStatus.ODD_JOB,
			GuiTypes.MercStatus.FIRED]:
		face.set_merc(_view(status, 0.5))
		if face.badge_shown():
			bad.append("%d shows %s" % [status, face.badge_id()])
	TestFixtures.check(res, "a null view, Available, Loan, Odd Job and Fired show no badge",
		none_null and bad.is_empty(), str(bad))
	face.set_merc(_view(GuiTypes.MercStatus.RESTING, 0.25))
	var node: IconRect = face.badge_node()
	TestFixtures.check(res, "a resting merc wears the resting badge centred on the portrait, ramp tinted",
		face.badge_id() == "status_resting" and node != null and node.position == ((Vector2(48, 48) - node.size) / 2.0).floor()
			and _same(face.badge_tint(), GuiColors.ramp_color(0.75)) and node.pixel_scale == _fit("status_resting", 48),
		"%s %s %s" % [face.badge_id(), face.badge_tint(), node.position if node != null else Vector2(-1, -1)])
	face.pixel_size = 96
	TestFixtures.check(res, "the badge scales to fit the portrait in whole steps",
		node != null and node.pixel_scale == _fit("status_resting", 96) and node.size == Vector2(Icons.tex("status_resting", true).get_size() * node.pixel_scale),
		"scale %d size %s" % [node.pixel_scale if node != null else -1, node.size if node != null else Vector2.ZERO])
	face.show_badge = false
	var off: bool = not face.badge_shown()
	face.show_badge = true
	TestFixtures.check(res, "show_badge off hides the badge at a site", off and face.badge_shown(), str(off))
	var applicant := ApplicantData.new()
	applicant.name = "Hopeful"
	var hopeful: MercView = MercView.from_applicant(applicant)
	face.set_merc(hopeful)
	TestFixtures.check(res, "an applicant shows no badge",
		hopeful.status == GuiTypes.MercStatus.AVAILABLE and not face.badge_shown(), "status %d" % hopeful.status)
	face.queue_free()


static func _fit(id: String, px: int) -> int:
	var art: Vector2i = Icons.tex(id, true).get_size()
	return maxi(1, int(px / float(maxi(art.x, art.y))))


static func _case_captive_filter(res: Dictionary, host: Node) -> void:
	_fresh()
	var added: Array[MercenaryData] = TestFixtures.add_mercs(EXTRA_MERCS)
	var held: MercenaryData = added[0]
	MercPool.add_captive(held, "Escort", "Aerdis", "Day 1")
	GameState.refresh_views()
	var screen: MercViewer = MERC_VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	var total: int = GameState.mercs.size()
	var roster_uids: Array[int] = GameState.roster_uids()
	TestFixtures.check(res, "a captive stays off GameState.roster and sits in GameState.captives",
		not roster_uids.has(held.merc_uid) and MercView.by_uid(GameState.captives, held.merc_uid) != null,
		str(roster_uids))
	var list: MercList = screen.list
	TestFixtures.check(res, "the roster list hides captives by default",
		not list.showing_captives() and list.row_count() == total - 1 and not _row_uids(list).has(held.merc_uid),
		"%d rows of %d" % [list.row_count(), total])
	list.filter_button().toggle(FilterButton.LABELS.size())
	await host.get_tree().process_frame
	var row: MercListItem = _row_for(list, held.merc_uid)
	TestFixtures.check(res, "Show captives adds the captive row with the orange Captured badge",
		list.showing_captives() and list.row_count() == total and row != null
			and row.portrait.badge_id() == "status_captured" and _same(row.portrait.badge_tint(), GuiColors.ORANGE),
		"%d rows, badge %s" % [list.row_count(), row.portrait.badge_id() if row != null else "none"])
	screen.show_merc(held.merc_uid)
	var picked: MercView = screen.selected()
	TestFixtures.check(res, "a shown captive can be picked into the card",
		picked != null and picked.uid == held.merc_uid and picked.status == GuiTypes.MercStatus.CAPTURED,
		"picked %d" % (picked.uid if picked != null else 0))
	list.filter_button().reset()
	await host.get_tree().process_frame
	var after: MercView = screen.selected()
	TestFixtures.check(res, "reset hides captives again and the card moves off the captive",
		not list.showing_captives() and list.row_count() == total - 1 and after != null and after.uid != held.merc_uid,
		"%d rows, selected %d" % [list.row_count(), after.uid if after != null else 0])
	TestFixtures.check(res, "the status rows of the filter keep their nine labels",
		FilterButton.LABELS.size() == 9 and list.filter_button().states().size() == 10,
		str(list.filter_button().states().keys()))
	screen.queue_free()
	MercPool.take_captive(held.merc_uid)
	GameState.refresh_views()


#A merc the law holds stays on GameState.roster yet hides with the contract captives; Missing always shows.
static func _case_legal_hold(res: Dictionary, host: Node) -> void:
	_fresh()
	var crew: Array[MercenaryData] = TestFixtures.add_mercs(EXTRA_MERCS)
	var held: MercenaryData = crew[0]
	var lost: MercenaryData = crew[1]
	GameState.set_away(held.merc_uid, GuiTypes.MercStatus.CAPTURED, -1)
	lost.missing_since = CampaignClock.now()
	GameState.refresh_views()
	var screen: MercViewer = MERC_VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	var list: MercList = screen.list
	var off_rows: Array[int] = _row_uids(list)
	list.filter_button().toggle(FilterButton.LABELS.size())
	await host.get_tree().process_frame
	var on_rows: Array[int] = _row_uids(list)
	var row: MercListItem = _row_for(list, held.merc_uid)
	TestFixtures.check(res, "a legal-held captive hides with the filter off and shows with it on",
		GameState.roster_uids().has(held.merc_uid) and not off_rows.has(held.merc_uid) and on_rows.has(held.merc_uid)
			and row != null and row.portrait.badge_id() == "status_captured",
		"off %s on %s" % [str(off_rows), str(on_rows)])
	TestFixtures.check(res, "a Missing merc shows with the filter off and on",
		off_rows.has(lost.merc_uid) and on_rows.has(lost.merc_uid), str(off_rows))
	screen.queue_free()
	GameState.clear_away(held.merc_uid)
	lost.missing_since = -1
	GameState.refresh_views()


#The clock moves a resting merc's badge along the ramp on the open roster row, with no rebuild.
static func _case_clock_tint(res: Dictionary, host: Node) -> void:
	_fresh()
	var merc: MercenaryData = TestFixtures.add_mercs(1)[0]
	var lines: Array[String] = []
	RestSystem._lock(merc, RestSystem.KIND_RESPITE, 8 * HOUR, "RESPITE", lines)
	GameState.refresh_views()
	var screen: MercViewer = MERC_VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	var row: MercListItem = _row_for(screen.list, merc.merc_uid)
	var before: Color = row.portrait.badge_tint() if row != null else Color.WHITE
	var minutes_before: int = row.time_left_minutes if row != null else 0
	await GameState.process_until(CampaignClock.now() + (merc.rest_lockout_until - merc.rest_lockout_start) / 2)
	var later: MercListItem = _row_for(screen.list, merc.merc_uid)
	var view: MercView = MercView.by_uid(GameState.roster, merc.merc_uid)
	var after: Color = later.portrait.badge_tint() if later != null else Color.WHITE
	var want: Color = GuiTypes.badge_color(GuiTypes.MercStatus.RESTING, view.status_fraction_left if view != null else -1.0)
	TestFixtures.check(res, "the open row's badge and time tag follow the clock in place",
		row != null and later == row and not _same(before, after) and _same(after, want)
			and later.time_left_minutes < minutes_before,
		"before %s after %s want %s minutes %d -> %d" % [before, after, want, minutes_before,
			later.time_left_minutes if later != null else -1])
	screen.queue_free()
	RestSystem._unlock(merc)
	GameState.refresh_views()


static func _row_uids(list: MercList) -> Array[int]:
	var out: Array[int] = []
	for item: MercListItem in list.rows():
		out.append(item.uid)
	return out


static func _row_for(list: MercList, uid: int) -> MercListItem:
	for item: MercListItem in list.rows():
		if item.uid == uid:
			return item
	return null


static func _member(uid: int, fate: int) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = uid
	member.name = "Badge %d" % uid
	member.role = "Guide"
	member.tradition = "Bowman"
	member.fate = fate
	member.level_before = 3
	member.level_after = 3
	member.xp_before = 20
	member.xp_need = 100
	member.xp_gained = 10
	member.hp = Vector2i(24, 40)
	member.ep = Vector2i(12, 20)
	member.mp = Vector2i(6, 10)
	member.hp_before = 40
	member.ep_before = 20
	member.mp_before = 10
	return member


static func _case_defected_row(res: Dictionary, host: Node) -> void:
	var fate := ResultMemberData.Fate
	TestFixtures.check(res, "the defected fate wears the bandit and the departed the missing icon; skull and bars stay for the others",
		ResultsGlyphs.overlay_for(fate.DEFECTED) == ResultsGlyphs.bandit() and ResultsGlyphs.overlay_for(fate.DEAD) != null
			and ResultsGlyphs.overlay_for(fate.CAPTURED) == ResultsGlyphs.bars()
			and ResultsGlyphs.overlay_for(fate.DEPARTED) == ResultsGlyphs.missing()
			and ResultsGlyphs.overlay_for(fate.ALIVE) == null, "overlays")
	_fresh()
	var crew: Array[MercenaryData] = TestFixtures.add_mercs(2)
	var turned: MercenaryData = crew[0]
	var fallen: MercenaryData = crew[1]
	GameState.remove_merc(turned.merc_uid, GameState.REMOVED_DEFECTED, GuiTypes.MercStatus.FIRED)
	fallen.is_dead = true
	GameState.refresh_views()
	var result := ContractResultData.new()
	result.entry_id = -1
	result.name = "Badge Contract"
	result.difficulty = 3.0
	result.failed = true
	result.members.append(_member(turned.merc_uid, fate.DEFECTED))
	result.members.append(_member(fallen.merc_uid, fate.DEAD))
	var panel: ContractResults = PANEL.instantiate() as ContractResults
	host.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.show_result(result)
	await host.get_tree().process_frame
	var view: MercView = result.members[0].merc_view()
	TestFixtures.check(res, "a defector's record view reads Defected",
		view != null and view.status == GuiTypes.MercStatus.DEFECTED,
		"status %d" % (view.status if view != null else -1))
	panel.set_time(0.0)
	var early: String = panel.row_of(0).badge_id()
	panel.set_time(ResultsTimeline.FATES)
	var row: ResultRow = panel.row_of(0)
	TestFixtures.check(res, "a defected row shows the bandit overlay with the fates and no badge",
		early == "" and row.badge_id() == "" and row.overlay_shown(),
		"early '%s' late '%s' overlay %s" % [early, row.badge_id(), row.overlay_shown()])
	var dead_row: ResultRow = panel.row_of(1)
	TestFixtures.check(res, "a dead row keeps the skull and shows no badge",
		dead_row.overlay_shown() and dead_row.badge_id() == "", "badge '%s'" % dead_row.badge_id())
	panel.queue_free()
	fallen.is_dead = false

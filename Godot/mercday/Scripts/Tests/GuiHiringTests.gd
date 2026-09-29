class_name GuiHiringTests
extends RefCounted

#Run: godot --headless --path . with the --gui-hiring-tests flag.
#The Finance Hiring page: the trait filter column, the applicant card grid and its sorts, the
#offer and counter-offer dialog, the hire and reject confirms, the applicant popup and the
#notice banner. Every case drives the public helpers, because a synthetic click never reaches a
#button headless. Days are driven by emitting GameState.day_changed, so the clock stays paused.

const PAGE: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/HiringTab.tscn")
const PAGE_SIZE: Vector2 = Vector2(1280.0, 720.0)
#The bank a hire or an Odd Job crew needs, well over the seeded asking rates.
const RICH: int = 5000
const FILTER_W: float = 290.0
const FILTER_PAD: float = 24.0
const SLACK: float = 1.5
const HOLD: float = 0.05
const WAIT_MS: int = 4000
const DOT_SIDE: Vector2 = Vector2(28, 28)
const FIT_STAR_MIN: Vector2 = Vector2(88, 16)
const CARD_MIN_FULL: Vector2 = Vector2(208, 334)
const ADD_WRAP: Vector2 = Vector2(150.0, 34.0)

const GREEN: Color = Color("#6cc36a")
const PENDING: Color = Color("#f2b33d")
const SKY: Color = Color("#9cc6ef")
const CREAM: Color = Color("#f3ead7")
const BLUE2: Color = Color("#2b4f8a")
const ORANGE: Color = Color("#f28c28")

const VALUE_GROUP: String = "Value"
const SHUT_GROUPS: Array[String] = ["Identity", "Physical", "Mental"]
const IDENTITY_ENT: Dictionary = {"hiringDiscrim": 1, "background": 1}
const OPINION_ENT: Dictionary = {"guildOpinion": 1, "survey": 1}
#Employee Survey needs Merc Metrics I under it, so the owned pair is what hides the lock.
const SURVEY_TIERS: Dictionary = {"mercmetrics": 1, "survey": 1}
const CREW_ENT: Dictionary = {"oddJobs": 1}
const CREW3_ENT: Dictionary = {"oddJobs": 3}
const BASE_ROWS: Array[String] = ["salary", "uniq", "fit", "via"]
const FULL_ROWS: Array[String] = ["salary", "uniq", "fit", "via", "ancestry", "bloodline", "age",
	"heritage"]

#The seeded eight in every sort, both directions; ties break on the lower id.
const FIT_DESC: Array[int] = [25, 23, 21, 24, 27, 26, 20, 22]
const FIT_ASC: Array[int] = [22, 20, 26, 24, 27, 21, 23, 25]
const SALARY_DESC: Array[int] = [25, 23, 27, 21, 24, 20, 26, 22]
const SALARY_ASC: Array[int] = [22, 26, 20, 24, 21, 27, 23, 25]
const LEVEL_DESC: Array[int] = [25, 23, 21, 27, 24, 20, 26, 22]
const LEVEL_ASC: Array[int] = [22, 26, 20, 24, 27, 21, 23, 25]
const UNIQ_DESC: Array[int] = [25, 23, 21, 27, 24, 22, 20, 26]
const UNIQ_ASC: Array[int] = [20, 26, 22, 24, 21, 27, 23, 25]

const NO_MATCH: Array = [1500.0, 2000.0]
const CHEAP: Array = [0.0, 400.0]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var roster: Array[MercenaryData] = GameState.mercs.duplicate()
	var bank: int = GameState.bank_notes
	await host.get_tree().process_frame
	await _case_layout(res, host)
	await _case_mount_size(res, host)
	await _case_header(res, host)
	await _case_counts(res, host)
	await _case_sorts(res, host)
	await _case_empty(res, host)
	await _case_rows(res, host)
	await _case_identity(res, host)
	await _case_dot(res, host)
	await _case_status(res, host)
	await _case_view(res, host)
	await _case_reject(res, host)
	await _case_facts(res, host)
	await _case_stepper(res, host)
	await _case_opinion(res, host)
	await _case_hints(res, host)
	await _case_counter_block(res, host)
	await _case_odds(res, host)
	await _case_blocks(res, host)
	await _case_hire(res, host)
	await _case_send_counter(res, host)
	await _case_resolve(res, host)
	await _case_notice(res, host)
	await _case_shown(res, host)
	await _case_plans(res, host)
	await _case_glyphs(res, host)
	await _case_modal_host(res, host)
	await _case_offer_frame(res, host)
	await _case_hidden(res, host)
	GuiFrameStack.clear()
	GameState.mercs = roster
	GameState.bank_notes = bank
	CampaignClock.minutes = clock
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
	PromotionsManager.reset()
	return TestFixtures.summarize(res, "GUI HIRING")


#Every case starts bare: Enterprise with no upgrade tier, then the seeded eight applicants.
static func _fresh(ent: Dictionary = {}) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	if not ent.is_empty():
		SubscriptionManager.set_entitlements(ent)
	LegalManager.reset()
	PromotionsManager.reset()


static func _frames(host: Node, count: int = 2) -> void:
	for _i: int in count:
		await host.get_tree().process_frame


static func _open(host: Node, ent: Dictionary = {}) -> HiringTab:
	_fresh(ent)
	var page: HiringTab = PAGE.instantiate() as HiringTab
	page.custom_minimum_size = PAGE_SIZE
	host.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = PAGE_SIZE
	await _frames(host, 3)
	return page


static func _escape(host: Node) -> void:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	host.get_viewport().push_input(esc)


static func _shut(host: Node, page: HiringTab) -> void:
	page.queue_free()
	await _frames(host, 2)


static func _id(index: int) -> int:
	return PromotionsManager.FIRST_APPLICANT_ID + index


static func _applicant(index: int) -> ApplicantData:
	return PromotionsManager.applicant_of(_id(index))


static func _def_keys(defs: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in defs:
		out.append(String(def.get("key", "")))
	return out


static func _fill_roster() -> void:
	while PromotionsManager.free_slots() > 0 and not GameState.mercs.is_empty():
		GameState.mercs.append(GameState.mercs[0])


static func _wait_clear(host: Node, banner: HiringNotice) -> void:
	var until: int = Time.get_ticks_msec() + WAIT_MS
	while banner.showing() and Time.get_ticks_msec() < until:
		await host.get_tree().process_frame


#L: the two columns, the panel it wraps and the grid under the header.
static func _case_layout(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var panel: TraitFilterPanel = page.filter_panel()
	var col: PanelContainer = page.filter_column()
	var grid: GridContainer = page.card_grid()
	var panel_w: float = 0.0 if panel == null else panel.size.x
	var col_w: float = 0.0 if col == null else col.size.x
	var grid_w: float = 0.0 if grid == null else grid.size.x
	TestFixtures.check(res, "the filter atom is 290 px wide", absf(panel_w - FILTER_W) <= SLACK,
		"%.1f px" % panel_w)
	TestFixtures.check(res, "the filter column wraps it with 12 px padding",
		absf(col_w - (FILTER_W + FILTER_PAD)) <= SLACK, "%.1f px" % col_w)
	TestFixtures.check(res, "the card column takes the rest of the page", grid_w > col_w + 100.0,
		"grid %.1f, column %.1f" % [grid_w, col_w])
	TestFixtures.check(res, "the panel carries the hiring defs",
		panel != null and _def_keys(panel.defs()) == _def_keys(PromotionsManager.hiring_defs()),
		"%s" % [_def_keys(panel.defs())])
	var value_group: FilterGroup = panel.group_for(VALUE_GROUP)
	TestFixtures.check(res, "the Value group opens with the page",
		value_group != null and value_group.is_open(), "open %s" % [value_group != null
		and value_group.is_open()])
	var shut: Array[String] = []
	for group_name: String in SHUT_GROUPS:
		var group: FilterGroup = panel.group_for(group_name)
		if group != null and group.is_open():
			shut.append(group_name)
	TestFixtures.check(res, "every other filter group stays closed", shut.is_empty(),
		"open %s" % [shut])
	TestFixtures.check(res, "the panel shows Clear and filters by the lock verb",
		panel.show_clear and panel.lock_verb == "filter by", "%s, %s" % [panel.show_clear,
		panel.lock_verb])
	TestFixtures.check(res, "the panel carries no footer note", panel.footer_note == "",
		"note %s" % [panel.footer_note])
	TestFixtures.check(res, "the card grid runs three equal columns",
		grid != null and grid.columns == 3, "columns %d" % [0 if grid == null else grid.columns])
	var title: Label = page.title_label()
	var title_text: String = "" if title == null else title.text
	TestFixtures.check(res, "the header reads Applicants",
		title != null and title.text == "Applicants", "%s" % [title_text])
	var scroll: ScrollContainer = _scroll_of(grid)
	TestFixtures.check(res, "the card grid sits in a scroll that never runs sideways",
		scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"%s" % [scroll])
	await _shut(host, page)


#GX4F-13: the page mounts to its full size with no anchor warning.
static func _case_mount_size(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	TestFixtures.check(res, "the page mounts at 1280 x 720", page.size == PAGE_SIZE,
		"%s" % [page.size])
	await _shut(host, page)


static func _has_scroll(node: Node, skip: Node) -> bool:
	for child: Node in node.get_children():
		if child == skip:
			continue
		if child is ScrollContainer:
			return true
		if _has_scroll(child, skip):
			return true
	return false


static func _box_of(dialog: HireOfferDialog) -> Control:
	for child: Node in dialog.get_children():
		if child is CenterContainer and child.get_child_count() > 0:
			return child.get_child(0) as Control
	return null


static func _scroll_of(node: Node) -> ScrollContainer:
	var walk: Node = null if node == null else node.get_parent()
	while walk != null:
		if walk is ScrollContainer:
			return walk as ScrollContainer
		walk = walk.get_parent()
	return null


#H: the sort controls and their defaults.
static func _case_header(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var pick: OptionDropdown = page.sort_dropdown()
	var keys: Array[String] = []
	var all_on: bool = true
	for row: Dictionary in pick.options:
		keys.append(String(row.get("key", "")))
		if not bool(row.get("enabled", false)):
			all_on = false
	var want: Array[String] = []
	for row: Dictionary in PromotionsManager.SORTS:
		want.append(String(row.get("key", "")))
	TestFixtures.check(res, "the sort dropdown lists every sort key", keys == want,
		"%s" % [keys])
	TestFixtures.check(res, "every sort option is enabled", all_on, "all enabled %s" % [all_on])
	TestFixtures.check(res, "the sort dropdown is 160 x 32",
		pick.custom_minimum_size == Vector2(160.0, 32.0), "%s" % [pick.custom_minimum_size])
	var toggle: SortDirToggle = page.sort_toggle()
	TestFixtures.check(res, "the direction toggle keeps the atom size",
		toggle != null and toggle.custom_minimum_size == SortDirToggle.TOGGLE_SIZE,
		"%s" % [toggle.custom_minimum_size])
	TestFixtures.check(res, "the page opens on Fit, descending",
		page.sort_key() == &"fit" and page.descending(),
		"%s, desc %s" % [page.sort_key(), page.descending()])
	TestFixtures.check(res, "the dropdown shows the sort the page holds", pick.selected == &"fit",
		"%s" % [pick.selected])
	page.set_sort(&"level")
	TestFixtures.check(res, "a sort change reaches the dropdown", pick.selected == &"level",
		"%s" % [pick.selected])
	page.set_descending(false)
	TestFixtures.check(res, "a direction change reaches the toggle", not toggle.descending,
		"desc %s" % [toggle.descending])
	await _shut(host, page)


#C: the count line under the header.
static func _case_counts(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	TestFixtures.check(res, "the count line reads all eight with no filter",
		page.count_text() == "8 of 8 applicants shown", "%s" % [page.count_text()])
	page.filter_panel().press_value("salary", CHEAP)
	await _frames(host, 1)
	TestFixtures.check(res, "a salary range narrows the count",
		page.count_text() == "3 of 8 applicants shown", "%s" % [page.count_text()])
	TestFixtures.check(res, "the narrowed grid holds the cheap three",
		page.card_ids().size() == 3, "%s" % [page.card_ids()])
	page.press_clear()
	await _frames(host, 1)
	TestFixtures.check(res, "Clear puts every applicant back",
		page.count_text() == "8 of 8 applicants shown", "%s" % [page.count_text()])
	page.filter_panel().press_value("from", [ApplicantData.WALK_IN])
	await _frames(host, 1)
	TestFixtures.check(res, "one Applied Via chip leaves the walk-ins",
		page.count_text() == "2 of 8 applicants shown", "%s" % [page.count_text()])
	TestFixtures.check(res, "the walk-in ids are the ones shown",
		page.card_ids().has(_id(2)) and page.card_ids().has(_id(6)) and page.shown_count() == 2,
		"%s" % [page.card_ids()])
	TestFixtures.check(res, "the total counts every applicant on the list",
		page.total_count() == PromotionsManager.applicants.size(), "%d" % [page.total_count()])
	await _shut(host, page)


#S: the four sorts, both directions.
static func _case_sorts(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var rows: Array = [[&"fit", FIT_DESC, FIT_ASC], [&"salary", SALARY_DESC, SALARY_ASC],
		[&"level", LEVEL_DESC, LEVEL_ASC], [&"uniqueness", UNIQ_DESC, UNIQ_ASC]]
	for row: Array in rows:
		var key: StringName = row[0]
		page.set_sort(key)
		page.set_descending(true)
		await _frames(host, 1)
		TestFixtures.check(res, "%s sorts the grid downward" % [key],
			page.card_ids() == row[1], "%s" % [page.card_ids()])
		page.set_descending(false)
		await _frames(host, 1)
		TestFixtures.check(res, "%s sorts the grid upward" % [key], page.card_ids() == row[2],
			"%s" % [page.card_ids()])
	await _shut(host, page)


#E: the two empty lines.
static func _case_empty(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	TestFixtures.check(res, "a filled grid carries no empty line", page.empty_text() == "",
		"%s" % [page.empty_text()])
	page.filter_panel().press_value("salary", NO_MATCH)
	await _frames(host, 1)
	TestFixtures.check(res, "a filter that matches nobody says so",
		page.empty_text() == "No applicants match your filters.", "%s" % [page.empty_text()])
	TestFixtures.check(res, "the empty line shows and the grid hides",
		page.empty_label().visible and not page.card_grid().visible,
		"empty %s, grid %s" % [page.empty_label().visible, page.card_grid().visible])
	TestFixtures.check(res, "the count line reads none of eight",
		page.count_text() == "0 of 8 applicants shown", "%s" % [page.count_text()])
	page.press_clear()
	PromotionsManager.applicants.clear()
	page.refresh()
	await _frames(host, 1)
	TestFixtures.check(res, "an empty list points at a Job Posting",
		page.empty_text() == "No applicants yet. Run a Job Posting to attract mercs.",
		"%s" % [page.empty_text()])
	TestFixtures.check(res, "the empty label carries that text",
		page.empty_label().text == page.empty_text(), "%s" % [page.empty_label().text])
	await _shut(host, page)


#R: the card rows of a campaign applicant, a walk-in and an ended campaign.
static func _case_rows(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var first: ApplicantData = _applicant(0)
	var card: ApplicantCard = page.card_of(first.id)
	var card_keys: Array[String] = [] if card == null else card.row_keys()
	TestFixtures.check(res, "a card holds the four unlocked rows", card != null
		and card.row_keys() == BASE_ROWS, "%s" % [card_keys])
	TestFixtures.check(res, "the salary row reads the asking rate",
		card.row_text("salary") == "%s / mo" % NotesLabel.format_amount(first.ask),
		"%s" % [card.row_text("salary")])
	TestFixtures.check(res, "the salary row is budget yellow",
		card.row_color("salary").is_equal_approx(PENDING), "%s" % [card.row_color("salary")])
	TestFixtures.check(res, "no unique trait reads None", card.row_text("uniq") == "None",
		"%s" % [card.row_text("uniq")])
	TestFixtures.check(res, "None is sky, not the green of a find",
		card.row_color("uniq").is_equal_approx(SKY), "%s" % [card.row_color("uniq")])
	var second: ApplicantCard = page.card_of(_id(1))
	TestFixtures.check(res, "a unique count reads its rarity",
		second.row_text("uniq") == "2 - Uncommon", "%s" % [second.row_text("uniq")])
	TestFixtures.check(res, "a unique count is green",
		second.row_color("uniq").is_equal_approx(GREEN), "%s" % [second.row_color("uniq")])
	TestFixtures.check(res, "the fit row reads one decimal",
		card.row_text("fit") == "2.0", "%s" % [card.row_text("fit")])
	TestFixtures.check(res, "the fit row takes the star colour",
		card.row_color("fit").is_equal_approx(FitStars.color_of(first.fit)),
		"%s" % [card.row_color("fit")])
	TestFixtures.check(res, "a campaign applicant names the campaign",
		card.row_text("via") == PromotionsManager.campaign_name(first.campaign_id),
		"%s" % [card.row_text("via")])
	var walk: ApplicantCard = page.card_of(_id(2))
	TestFixtures.check(res, "a walk-in says Walk-In", walk.row_text("via") == "Walk-In",
		"%s" % [walk.row_text("via")])
	first.campaign_id = 999
	page.refresh()
	await _frames(host, 1)
	var ended: ApplicantCard = page.card_of(first.id)
	TestFixtures.check(res, "a campaign that is gone reads Ended campaign",
		ended.row_text("via") == "Ended campaign", "%s" % [ended.row_text("via")])
	TestFixtures.check(res, "the level badge pads one digit to two",
		ended.level_text() == "04", "%s" % [ended.level_text()])
	var high: ApplicantCard = page.card_of(_id(3))
	TestFixtures.check(res, "a two digit level stays as it is", high.level_text() == "12",
		"%s" % [high.level_text()])
	TestFixtures.check(res, "the card names the applicant",
		ended.name_text() == first.name, "%s" % [ended.name_text()])
	TestFixtures.check(res, "the card names the tradition",
		ended.tradition_text() == first.tradition, "%s" % [ended.tradition_text()])
	await _shut(host, page)


#I: the identity rows behind hiringDiscrim and background.
static func _case_identity(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var card: ApplicantCard = page.card_of(_id(0))
	TestFixtures.check(res, "the identity rows stay off the card while locked",
		card.row_keys() == BASE_ROWS, "%s" % [card.row_keys()])
	await _shut(host, page)
	var open_page: HiringTab = await _open(host, IDENTITY_ENT)
	var first: ApplicantData = _applicant(0)
	var full: ApplicantCard = open_page.card_of(first.id)
	var full_keys: Array[String] = [] if full == null else full.row_keys()
	TestFixtures.check(res, "the four identity rows land with the entitlements",
		full != null and full.row_keys() == FULL_ROWS,
		"%s" % [full_keys])
	TestFixtures.check(res, "the ancestry row reads the applicant",
		full.row_text("ancestry") == first.ancestry, "%s" % [full.row_text("ancestry")])
	TestFixtures.check(res, "the bloodline row reads the applicant",
		full.row_text("bloodline") == first.bloodline, "%s" % [full.row_text("bloodline")])
	TestFixtures.check(res, "the age row reads the applicant",
		full.row_text("age") == str(first.age), "%s" % [full.row_text("age")])
	TestFixtures.check(res, "the heritage row reads the applicant",
		full.row_text("heritage") == first.heritage, "%s" % [full.row_text("heritage")])
	TestFixtures.check(res, "the identity rows are cream",
		full.row_color("ancestry").is_equal_approx(CREAM), "%s" % [full.row_color("ancestry")])
	var stars: FitStars = full.fit_stars()
	var stars_min: Vector2 = Vector2.ZERO if stars == null else stars.get_combined_minimum_size()
	TestFixtures.check(res, "the fit row draws its stars at cell 1",
		stars != null and stars_min.is_equal_approx(FIT_STAR_MIN), "%s" % [stars_min])
	var card_min: Vector2 = full.get_combined_minimum_size()
	TestFixtures.check(res, "a card with every row shown keeps its outer size",
		absf(card_min.x - CARD_MIN_FULL.x) <= SLACK and absf(card_min.y - CARD_MIN_FULL.y) <= SLACK,
		"%s" % [card_min])
	var card_box: StyleBoxFlat = full.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "an ApplicantCard casts no shadow of its own",
		card_box != null and card_box.shadow_size == 0,
		"%s" % [-1 if card_box == null else card_box.shadow_size])
	var card0: ApplicantCard = open_page.card_of(_id(0))
	var card1: ApplicantCard = open_page.card_of(_id(1))
	var card2: ApplicantCard = open_page.card_of(_id(2))
	var trio_ok: bool = card0 != null and card1 != null and card2 != null
	var trio_msg: String = ""
	if trio_ok:
		var trio: Array[ApplicantCard] = [card0, card1, card2]
		trio.sort_custom(func(a: ApplicantCard, b: ApplicantCard) -> bool: return a.position.x < b.position.x)
		trio_ok = (trio[1].position.x >= trio[0].position.x + trio[0].size.x
			and trio[2].position.x >= trio[1].position.x + trio[1].size.x)
		trio_msg = "%s, %s, %s" % [trio[0].position.x + trio[0].size.x, trio[1].position.x,
			trio[2].position.x]
	TestFixtures.check(res, "three cards with wide fit rows sit side by side with no overlap",
		trio_ok, trio_msg)
	await _shut(host, open_page)


#D: the unseen dot.
static func _case_dot(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var unseen: ApplicantCard = page.card_of(_id(3))
	var seen: ApplicantCard = page.card_of(_id(0))
	var dot_size: Vector2 = Vector2.ZERO if unseen.dot() == null else unseen.dot().size
	TestFixtures.check(res, "the card dot is 28 x 28",
		unseen.dot() != null and unseen.dot().size == DOT_SIDE,
		"%s" % [dot_size])
	TestFixtures.check(res, "an unseen applicant carries the dot",
		unseen.dot_on() and unseen.dot().visible, "on %s" % [unseen.dot_on()])
	TestFixtures.check(res, "a seen applicant carries none",
		not seen.dot_on() and not seen.dot().visible, "on %s" % [seen.dot_on()])
	page.press_view(_id(3))
	await _frames(host, 1)
	TestFixtures.check(res, "View marks the applicant seen",
		not PromotionsManager.applicant_of(_id(3)).unseen and not page.card_of(_id(3)).dot_on(),
		"unseen %s" % [PromotionsManager.applicant_of(_id(3)).unseen])
	await _shut(host, page)
	var offer_page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	offer_page.press_offer(_id(5))
	await _frames(host, 1)
	TestFixtures.check(res, "Offer marks the applicant seen",
		not PromotionsManager.applicant_of(_id(5)).unseen,
		"unseen %s" % [PromotionsManager.applicant_of(_id(5)).unseen])
	await _shut(host, offer_page)
	var reject_page: HiringTab = await _open(host)
	reject_page.press_reject(_id(5))
	await _frames(host, 1)
	TestFixtures.check(res, "Reject marks the applicant seen",
		not PromotionsManager.applicant_of(_id(5)).unseen,
		"unseen %s" % [PromotionsManager.applicant_of(_id(5)).unseen])
	await _shut(host, reject_page)


#T: the four card states and the buttons they block.
static func _case_status(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var card: ApplicantCard = page.card_of(_id(0))
	TestFixtures.check(res, "an open applicant says nothing and rings blue",
		card.status_text() == "" and card.ring_color().is_equal_approx(BLUE2),
		"%s, %s" % [card.status_text(), card.ring_color()])
	var one: ApplicantData = _applicant(0)
	one.status = ApplicantData.STATUS_COUNTERED
	page.refresh()
	await _frames(host, 1)
	var pending: ApplicantCard = page.card_of(one.id)
	TestFixtures.check(res, "a sent counter-offer shows and rings yellow",
		pending.status_text() == "Counter-offer sent..."
		and pending.ring_color().is_equal_approx(PENDING),
		"%s, %s" % [pending.status_text(), pending.ring_color()])
	TestFixtures.check(res, "the pending status line is yellow",
		pending.status_color().is_equal_approx(PENDING), "%s" % [pending.status_color()])
	TestFixtures.check(res, "Reject does nothing while the answer is out",
		pending.offer_block() == "Waiting for their answer.", "%s" % [pending.offer_block()])
	page.press_reject(one.id)
	await _frames(host, 1)
	TestFixtures.check(res, "no confirm opens for a pending applicant",
		not page.confirm_dialog().visible, "visible %s" % [page.confirm_dialog().visible])
	page.press_offer(one.id)
	await _frames(host, 1)
	TestFixtures.check(res, "the dialog stays shut for a pending applicant",
		not page.offer_dialog().is_open(), "open %s" % [page.offer_dialog().is_open()])
	one.status = ApplicantData.STATUS_OPEN
	one.refused_counter = true
	page.refresh()
	await _frames(host, 1)
	var refused: ApplicantCard = page.card_of(one.id)
	TestFixtures.check(res, "a refusal shows and rings red",
		refused.status_text() == ApplicantCard.REFUSED_TEXT,
		"%s" % [refused.status_text()])
	TestFixtures.check(res, "the refusal ring is the red of the ramp",
		refused.ring_color().is_equal_approx(GuiColors.RAMP_RED), "%s" % [refused.ring_color()])
	one.refused_counter = false
	one.accepted_counter = true
	page.refresh()
	await _frames(host, 1)
	var taken: ApplicantCard = page.card_of(one.id)
	TestFixtures.check(res, "an accepted counter-offer shows and rings green",
		taken.status_text() == "Accepted your counter-offer"
		and taken.ring_color().is_equal_approx(GREEN),
		"%s, %s" % [taken.status_text(), taken.ring_color()])
	_fill_roster()
	page.refresh()
	await _frames(host, 1)
	TestFixtures.check(res, "Offer reads the slot block with no free slot",
		page.card_of(one.id).offer_block() == "No free merc slots.",
		"%s" % [page.card_of(one.id).offer_block()])
	await _shut(host, page)


#V: the applicant popup.
static func _case_view(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var view_card: ApplicantCard = page.card_of(_id(0))
	var view_btn: Button = view_card.view_button()
	var view_hover: StyleBoxFlat = view_btn.get_theme_stylebox(&"hover") as StyleBoxFlat
	var view_normal: StyleBoxFlat = view_btn.get_theme_stylebox(&"normal") as StyleBoxFlat
	var hover_tint: Color = Color.BLACK if view_hover == null else view_hover.bg_color
	var normal_tint: Color = Color.BLACK if view_normal == null else view_normal.bg_color
	TestFixtures.check(res, "the View button hover stylebox is lit blue",
		view_hover != null and view_hover.bg_color.is_equal_approx(Color("#3b6fb6")),
		"%s" % [hover_tint])
	TestFixtures.check(res, "the View button normal stylebox stays the base blue",
		view_normal != null and view_normal.bg_color.is_equal_approx(Color("#2b4f8a")),
		"%s" % [normal_tint])
	TestFixtures.check(res, "the View button centres its eye icon in the square",
		view_btn.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and view_btn.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER
		and not view_btn.expand_icon,
		"h %d v %d expand %s" % [view_btn.icon_alignment, view_btn.vertical_icon_alignment,
			view_btn.expand_icon])
	var face: MercPortrait = view_card.portrait()
	TestFixtures.check(res, "an applicant card draws a merc portrait of that applicant",
		face != null and face.merc_uid == _id(0) and face.pixel_size == ApplicantCard.HATCH_SIDE,
		"uid %d" % [0 if face == null else face.merc_uid])
	var reject_btn: BevelButton = view_card.reject_button() as BevelButton
	var offer_btn: BevelButton = view_card.offer_button() as BevelButton
	TestFixtures.check(res, "Reject is a core bevel button on the danger palette",
		reject_btn != null and reject_btn.kind == &"danger"
		and reject_btn.fill.is_equal_approx(GuiColors.RAMP_RED),
		"%s" % [&"" if reject_btn == null else reject_btn.kind])
	TestFixtures.check(res, "Offer is a core bevel button on the go palette",
		offer_btn != null and offer_btn.kind == &"go" and offer_btn.fill.is_equal_approx(GREEN),
		"%s" % [&"" if offer_btn == null else offer_btn.kind])
	page.press_view(_id(0))
	await _frames(host, 2)
	var popup: ViewerPopup = page.applicant_popup()
	TestFixtures.check(res, "View opens the applicant popup", popup != null,
		"popup %s" % [popup != null])
	TestFixtures.check(res, "the popup sits on the modal host",
		popup != null and popup.get_parent() == page.modal_host(),
		"%s" % [null if popup == null else popup.get_parent()])
	popup.close()
	await _frames(host, 2)
	TestFixtures.check(res, "closing the popup drops it", page.applicant_popup() == null,
		"popup %s" % [page.applicant_popup()])
	page.press_view(9999)
	await _frames(host, 1)
	TestFixtures.check(res, "View on an applicant that is gone opens nothing",
		page.applicant_popup() == null, "popup %s" % [page.applicant_popup()])
	await _shut(host, page)


#J: the reject confirm.
static func _case_reject(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var who: String = _applicant(0).name
	page.press_reject(_id(0))
	await _frames(host, 1)
	var ask: ConfirmDialog = page.confirm_dialog()
	TestFixtures.check(res, "the reject confirm names the applicant",
		ask.title == "Reject %s?" % who, "%s" % [ask.title])
	TestFixtures.check(res, "the reject confirm says the application goes",
		ask.message == "Their application is removed.", "%s" % [ask.message])
	TestFixtures.check(res, "the reject confirm leads with Cancel",
		ask.button_labels() == ["Cancel", "Reject"], "%s" % [ask.button_labels()])
	ask.press(0)
	await _frames(host, 1)
	TestFixtures.check(res, "Cancel keeps the applicant",
		PromotionsManager.applicant_of(_id(0)) != null and page.card_of(_id(0)) != null,
		"card %s" % [page.card_of(_id(0)) != null])
	page.press_reject(_id(0))
	await _frames(host, 1)
	ask.press(1)
	await _frames(host, 1)
	TestFixtures.check(res, "a confirmed reject drops the applicant",
		PromotionsManager.applicant_of(_id(0)) == null and page.card_of(_id(0)) == null,
		"left %d" % [PromotionsManager.applicants.size()])
	TestFixtures.check(res, "the count line follows the reject",
		page.count_text() == "7 of 7 applicants shown", "%s" % [page.count_text()])
	await _shut(host, page)


#F: the dialog title, width and five facts.
static func _case_facts(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "Offer opens the dialog on the asking rate",
		dialog.is_open() and dialog.amount() == one.ask,
		"open %s, %d" % [dialog.is_open(), dialog.amount()])
	TestFixtures.check(res, "the title reads Offer with the name",
		dialog.title_text() == "Offer - %s" % one.name, "%s" % [dialog.title_text()])
	TestFixtures.check(res, "an offer box is 820 px wide", dialog.box_width() == 820,
		"%d px" % [dialog.box_width()])
	var box_shadow: StyleBoxFlat = dialog.box().get_theme_stylebox(&"panel") as StyleBoxFlat
	var shadow_text: String = "" if box_shadow == null else "%s" % [[box_shadow.shadow_offset,
		box_shadow.shadow_size, box_shadow.shadow_color]]
	TestFixtures.check(res, "the dialog box casts the kit shadow",
		box_shadow != null and box_shadow.shadow_offset.is_equal_approx(Vector2(10.0, 10.0))
		and box_shadow.shadow_size == 4
		and box_shadow.shadow_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.5)),
		"%s" % [shadow_text])
	TestFixtures.check(res, "the tradition fact reads the tradition",
		dialog.fact_text("tradition") == one.tradition, "%s" % [dialog.fact_text("tradition")])
	TestFixtures.check(res, "the tradition fact takes the tradition colour",
		dialog.fact_color("tradition").is_equal_approx(GuiTypes.tradition_color(one.tradition)),
		"%s" % [dialog.fact_color("tradition")])
	TestFixtures.check(res, "the level fact reads the level",
		dialog.fact_text("level") == str(one.level), "%s" % [dialog.fact_text("level")])
	TestFixtures.check(res, "the asking fact reads the rate a month",
		dialog.fact_text("asking") == "%s / mo" % NotesLabel.format_amount(one.ask),
		"%s" % [dialog.fact_text("asking")])
	TestFixtures.check(res, "the offer fact reads no margin at the asking rate",
		dialog.fact_text("offer") == "+0%", "%s" % [dialog.fact_text("offer")])
	TestFixtures.check(res, "the offer fact is green at the asking rate",
		dialog.fact_color("offer").is_equal_approx(GREEN), "%s" % [dialog.fact_color("offer")])
	TestFixtures.check(res, "the slots fact is headed Open Slots",
		dialog.fact_label("slots") == "Open Slots", "%s" % [dialog.fact_label("slots")])
	var free: int = PromotionsManager.free_slots()
	TestFixtures.check(res, "the slots fact counts the free roster slots",
		free > 0 and dialog.fact_text("slots") == str(free),
		"%s, free %d" % [dialog.fact_text("slots"), free])
	TestFixtures.check(res, "the slots fact is cream while a slot is free",
		dialog.fact_color("slots").is_equal_approx(CREAM), "%s" % [dialog.fact_color("slots")])
	dialog.set_amount(one.ask * 2)
	TestFixtures.check(res, "an offer over the rate reads its percent",
		dialog.fact_text("offer") == "+100%", "%s" % [dialog.fact_text("offer")])
	TestFixtures.check(res, "the box stays 820 px over the rate", dialog.box_width() == 820,
		"%d px" % [dialog.box_width()])
	dialog.set_amount(roundi(float(one.ask) * 0.8))
	TestFixtures.check(res, "a counter reads its negative percent",
		dialog.fact_text("offer") == "-20%", "%s" % [dialog.fact_text("offer")])
	TestFixtures.check(res, "a counter paints the offer fact red",
		dialog.fact_color("offer").is_equal_approx(GuiColors.RAMP_RED),
		"%s" % [dialog.fact_color("offer")])
	TestFixtures.check(res, "the title reads Counter-Offer below the rate",
		dialog.title_text() == "Counter-Offer - %s" % one.name, "%s" % [dialog.title_text()])
	TestFixtures.check(res, "a counter box is 1000 px wide", dialog.box_width() == 1000,
		"%d px" % [dialog.box_width()])
	_fill_roster()
	GameState.roster_changed.emit()
	await _frames(host, 1)
	TestFixtures.check(res, "the slots fact turns red with no free slot",
		dialog.fact_color("slots").is_equal_approx(GuiColors.RAMP_RED),
		"%s" % [dialog.fact_color("slots")])
	TestFixtures.check(res, "the slots fact reads no free slot as zero",
		dialog.fact_text("slots") == "0", "%s" % [dialog.fact_text("slots")])
	await _shut(host, page)


#Q: the stepper and the centred offer row.
static func _case_stepper(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	var step: QuantityStepper = dialog.stepper()
	TestFixtures.check(res, "the stepper opens on the asking rate",
		step != null and step.value == one.ask, "%d" % [0 if step == null else step.value])
	TestFixtures.check(res, "the stepper floor is half the asking rate, rounded to ten",
		step.min_value == roundi(float(one.ask) * 0.5 / 10.0) * 10, "%d" % [step.min_value])
	TestFixtures.check(res, "the stepper ceiling is three times the asking rate",
		step.max_value == one.ask * 3, "%d" % [step.max_value])
	TestFixtures.check(res, "the stepper moves in tens", step.step == 10, "%d" % [step.step])
	TestFixtures.check(res, "the stepper is 200 x 38",
		step.custom_minimum_size == Vector2(200.0, 38.0), "%s" % [step.custom_minimum_size])
	var row: HBoxContainer = dialog.offer_row()
	TestFixtures.check(res, "the offer block centres the stepper row",
		row != null and row.alignment == BoxContainer.ALIGNMENT_CENTER,
		"%d" % [-1 if row == null else row.alignment])
	TestFixtures.check(res, "the offer row holds the stepper and the unit label alone",
		row != null and row.get_child_count() == 2,
		"%d children" % [0 if row == null else row.get_child_count()])
	TestFixtures.check(res, "no percent or Asking pick is left in the dialog",
		_pick_labels(dialog).is_empty(), "%s" % [_pick_labels(dialog)])
	dialog.set_amount(400)
	TestFixtures.check(res, "the amount the caller sets is the amount offered",
		dialog.amount() == 400, "%d" % [dialog.amount()])
	dialog.set_amount(333)
	TestFixtures.check(res, "the stepper follows a set amount", step.value == 333,
		"%d" % [step.value])
	dialog.set_amount(one.ask * 9)
	TestFixtures.check(res, "an amount over the ceiling clamps to it",
		dialog.amount() == one.ask * 3, "%d" % [dialog.amount()])
	await _shut(host, page)


#Every button label under the dialog box that reads like one of the dropped quick picks.
static func _pick_labels(dialog: HireOfferDialog) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[Node] = [dialog.box()]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var press: Button = node as Button
		if press != null and (press.text == "Asking" or press.text.ends_with("%")):
			out.append(press.text)
		for kid: Node in node.get_children():
			stack.append(kid)
	return out


#O: the Guild Opinion row.
static func _case_opinion(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	page.press_offer(_id(0))
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "Guild Opinion is locked on the bare plan", dialog.opinion_locked(),
		"locked %s" % [dialog.opinion_locked()])
	TestFixtures.check(res, "the locked row shows the feature lock",
		dialog.opinion_lock() != null and dialog.opinion_lock().visible,
		"visible %s" % [dialog.opinion_lock() != null and dialog.opinion_lock().visible])
	await _shut(host, page)
	var open_page: HiringTab = await _open(host, OPINION_ENT)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	open_page.press_offer(one.id)
	await _frames(host, 1)
	var open_dialog: HireOfferDialog = open_page.offer_dialog()
	TestFixtures.check(res, "the entitlement opens Guild Opinion", not open_dialog.opinion_locked(),
		"locked %s" % [open_dialog.opinion_locked()])
	var open_lock: FeatureLock = open_dialog.opinion_lock()
	TestFixtures.check(res, "the lock stands until the upgrade itself is owned",
		open_lock != null and open_lock.visible, "visible %s" % [open_lock != null and open_lock.visible])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, SURVEY_TIERS)
	await _frames(host, 1)
	TestFixtures.check(res, "Employee Survey is owned once its own requirement is met",
		SubscriptionManager.tier_of("survey") == 1, "tier %d" % [SubscriptionManager.tier_of("survey")])
	TestFixtures.check(res, "owning Employee Survey hides the lock",
		open_lock != null and not open_lock.visible,
		"visible %s" % [open_lock != null and open_lock.visible])
	var margins: Array[int] = [one.ask, 352, 400, 480, 640]
	var deltas: Array[int] = [1, 2, 3, 4, 5]
	for i: int in margins.size():
		open_dialog.set_amount(margins[i])
		TestFixtures.check(res, "an offer of %d notes is worth +%d" % [margins[i], deltas[i]],
			open_dialog.opinion_text() == "+%d" % [deltas[i]],
			"%s" % [open_dialog.opinion_text()])
	open_dialog.set_amount(roundi(float(one.ask) * 0.8))
	TestFixtures.check(res, "a counter-offer is worth nothing yet",
		open_dialog.opinion_text() == "+0", "%s" % [open_dialog.opinion_text()])
	await _shut(host, open_page)


#N: the three hints.
static func _case_hints(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "the asking rate says nothing and takes the hint line away",
		dialog.hint_text() == "" and not dialog.hint_shown(), "%s" % [dialog.hint_text()])
	dialog.set_amount(one.ask * 2)
	TestFixtures.check(res, "double the rate tops the bonus out",
		dialog.hint_text() == "Maximum opinion bonus reached.", "%s" % [dialog.hint_text()])
	TestFixtures.check(res, "a hint with something to say is shown", dialog.hint_shown(),
		"shown %s" % [dialog.hint_shown()])
	dialog.set_amount(one.ask - 10)
	TestFixtures.check(res, "below the rate the hint warns of a refusal",
		dialog.hint_text() == "Below their asking rate. They may refuse.",
		"%s" % [dialog.hint_text()])
	await _shut(host, page)


#B: the counter block, the crew and the Odd Jobs lock.
static func _case_counter_block(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "the counter block stays away at the asking rate",
		dialog.crew() == null and not dialog.is_counter(),
		"counter %s" % [dialog.is_counter()])
	dialog.set_amount(one.ask - 60)
	TestFixtures.check(res, "Odd Jobs is locked on the bare plan", dialog.crew_locked(),
		"locked %s" % [dialog.crew_locked()])
	TestFixtures.check(res, "the locked counter block offers the upsell row",
		dialog.lock_row() != null and dialog.lock_row().visible,
		"visible %s" % [dialog.lock_row() != null and dialog.lock_row().visible])
	TestFixtures.check(res, "the Add Merc lock keeps its 150 x 34 wrap",
		dialog.add_lock() != null and dialog.add_lock().get_parent() is Control
		and (dialog.add_lock().get_parent() as Control).custom_minimum_size == ADD_WRAP,
		"%s" % [(dialog.add_lock().get_parent() as Control).custom_minimum_size])
	TestFixtures.check(res, "the wrap is the named node",
		dialog.add_lock().get_parent().name == "AddMercLockWrap",
		"%s" % [dialog.add_lock().get_parent().name])
	TestFixtures.check(res, "no crew is handed out while Odd Jobs is locked",
		dialog.crew() == null, "crew %s" % [dialog.crew()])
	await _shut(host, page)
	var one_seat: HiringTab = await _open(host, CREW_ENT)
	GameState.bank_notes = RICH
	var two: ApplicantData = _applicant(0)
	one_seat.press_offer(two.id)
	await _frames(host, 1)
	var seat_dialog: HireOfferDialog = one_seat.offer_dialog()
	seat_dialog.set_amount(two.ask - 60)
	await _frames(host, 1)
	TestFixtures.check(res, "one Odd Jobs tier hands over a crew of one",
		seat_dialog.crew() != null and seat_dialog.crew().max_mercs == 1,
		"crew %s" % [seat_dialog.crew() == null])
	TestFixtures.check(res, "the crew row hides the upsell",
		not seat_dialog.lock_row().visible, "visible %s" % [seat_dialog.lock_row().visible])
	TestFixtures.check(res, "the crew opens with nobody on it",
		seat_dialog.team().is_empty() and seat_dialog.pay_per() == PromotionsManager.default_pay(),
		"%s, pay %d" % [seat_dialog.team(), seat_dialog.pay_per()])
	TestFixtures.check(res, "the crew is 130 px tall",
		seat_dialog.crew().custom_minimum_size.y == 130.0,
		"%s" % [seat_dialog.crew().custom_minimum_size])
	await _shut(host, one_seat)
	var three_seats: HiringTab = await _open(host, CREW3_ENT)
	GameState.bank_notes = RICH
	var third: ApplicantData = _applicant(0)
	three_seats.press_offer(third.id)
	await _frames(host, 1)
	var wide_dialog: HireOfferDialog = three_seats.offer_dialog()
	wide_dialog.set_amount(third.ask - 60)
	await _frames(host, 1)
	TestFixtures.check(res, "three Odd Jobs tiers hand over three slots",
		wide_dialog.crew() != null and wide_dialog.crew().max_mercs == 3,
		"%d" % [0 if wide_dialog.crew() == null else wide_dialog.crew().max_mercs])
	TestFixtures.check(res, "the widest dialog builds no scroll of its own",
		not _has_scroll(wide_dialog, wide_dialog.crew()),
		"scroll %s" % [_has_scroll(wide_dialog, wide_dialog.crew())])
	var wide_box: Control = _box_of(wide_dialog)
	TestFixtures.check(res, "the widest box fits the page with the crew and the odds on it",
		wide_box != null and wide_box.size.x == 1000.0 and wide_box.size.y <= PAGE_SIZE.y,
		"%s" % [Vector2.ZERO if wide_box == null else wide_box.size])
	await _shut(host, three_seats)


#K: the success odds text, colour and cells.
static func _case_odds(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host, CREW_ENT)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	var rows: Array = [[319, 95, GREEN, 19], [256, 60, GREEN, 12], [254, 59, PENDING, 12],
		[224, 40, PENDING, 8], [223, 39, GuiColors.RAMP_RED, 8], [160, 5, GuiColors.RAMP_RED, 1]]
	for row: Array in rows:
		dialog.set_amount(int(row[0]))
		var odds: int = dialog.odds()
		TestFixtures.check(res, "an offer of %d notes reads %d%%" % [int(row[0]), int(row[1])],
			odds == int(row[1]), "%d%%" % [odds])
		TestFixtures.check(res, "%d%% odds take their band colour" % [int(row[1])],
			dialog.odds_color().is_equal_approx(row[2] as Color), "%s" % [dialog.odds_color()])
		TestFixtures.check(res, "%d%% odds light %d cells" % [int(row[1]), int(row[3])],
			dialog.odds_cells() == int(row[3]) and dialog.bar().filled == int(row[3]),
			"%d cells" % [dialog.odds_cells()])
	TestFixtures.check(res, "the odds bar holds twenty cells", dialog.bar().cells == 20,
		"%d" % [dialog.bar().cells])
	dialog.set_amount(224)
	var bare: int = dialog.odds()
	var crew: OddJobCrew = dialog.crew()
	var uid: int = GameState.mercs[0].merc_uid
	crew.add_merc(uid)
	await _frames(host, 1)
	TestFixtures.check(res, "a merc on the crew lifts the odds", dialog.odds() > bare
		and dialog.odds() == PromotionsManager.counter_odds(one.id, 224, [uid]),
		"%d from %d" % [dialog.odds(), bare])
	TestFixtures.check(res, "the crew the dialog hands over holds that merc",
		dialog.team() == [uid], "%s" % [dialog.team()])
	await _shut(host, page)


#X: the action text, the block reasons and the two ways out.
static func _case_blocks(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host, CREW_ENT)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "the action reads the hire and its salary",
		dialog.action_text() == "Hire for %s / mo" % NotesLabel.format_amount(one.ask),
		"%s" % [dialog.action_text()])
	TestFixtures.check(res, "nothing blocks a hire the guild can pay for",
		dialog.block_reason() == "", "%s" % [dialog.block_reason()])
	dialog.set_amount(one.ask - 60)
	TestFixtures.check(res, "the action reads the counter-offer below the rate",
		dialog.action_text() == "Send Counter-Offer", "%s" % [dialog.action_text()])
	GameState.bank_notes = 10
	var crew: OddJobCrew = dialog.crew()
	crew.add_merc(GameState.mercs[0].merc_uid)
	await _frames(host, 1)
	var pay_reason: String = PromotionsManager.can_counter(one.id, dialog.amount(),
		dialog.team(), dialog.pay_per())["reason"]
	TestFixtures.check(res, "crew pay the bank cannot cover blocks the counter",
		dialog.block_reason() == pay_reason and pay_reason != "", "%s" % [dialog.block_reason()])
	TestFixtures.check(res, "a blocked action is dimmed and carries the reason",
		is_equal_approx(dialog.action_button().modulate.a, 0.45)
		and dialog.action_button().tooltip_text == pay_reason,
		"alpha %.2f, tip %s" % [dialog.action_button().modulate.a,
		dialog.action_button().tooltip_text])
	dialog.press_action()
	await _frames(host, 1)
	TestFixtures.check(res, "a blocked press sends nothing",
		PromotionsManager.applicant_of(one.id).status == ApplicantData.STATUS_OPEN,
		"%s" % [PromotionsManager.applicant_of(one.id).status])
	GameState.bank_notes = RICH
	crew.remove_merc(GameState.mercs[0].merc_uid)
	dialog.set_amount(one.ask)
	var keep: Array[MercenaryData] = GameState.mercs.duplicate()
	_fill_roster()
	GameState.roster_changed.emit()
	await _frames(host, 1)
	TestFixtures.check(res, "no free slot blocks the hire",
		dialog.block_reason() == "No free merc slots.", "%s" % [dialog.block_reason()])
	dialog.press_cancel()
	await _frames(host, 1)
	TestFixtures.check(res, "Cancel closes the dialog", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	GameState.mercs = keep
	GameState.roster_changed.emit()
	page.press_offer(one.id)
	await _frames(host, 1)
	TestFixtures.check(res, "the X closes the dialog too", dialog.close_button() != null,
		"button %s" % [dialog.close_button() != null])
	dialog.close_button().pressed.emit()
	await _frames(host, 1)
	TestFixtures.check(res, "the red X is the Cancel of the dialog", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	await _shut(host, page)


#G: the hire confirm and what it signs.
static func _case_hire(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	var who: String = one.name
	var salary: int = one.ask
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	dialog.press_action()
	await _frames(host, 1)
	var ask: ConfirmDialog = page.confirm_dialog()
	TestFixtures.check(res, "the hire confirm names the applicant",
		ask.title == "Hire %s?" % who, "%s" % [ask.title])
	TestFixtures.check(res, "the hire confirm reads the salary and the slot",
		ask.message == "Salary: %s notes / month. Uses 1 merc slot."
		% NotesLabel.format_amount(salary), "%s" % [ask.message])
	TestFixtures.check(res, "the hire confirm leads with Cancel",
		ask.button_labels() == ["Cancel", "Hire"], "%s" % [ask.button_labels()])
	TestFixtures.check(res, "the dialog steps back for the confirm", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	ask.press(0)
	await _frames(host, 1)
	TestFixtures.check(res, "Cancel hires nobody",
		PromotionsManager.applicant_of(one.id) != null and page.card_of(one.id) != null,
		"card %s" % [page.card_of(one.id) != null])
	var roster: int = GameState.mercs.size()
	page.press_offer(one.id)
	await _frames(host, 1)
	dialog.press_action()
	await _frames(host, 1)
	ask.press(1)
	await _frames(host, 2)
	TestFixtures.check(res, "a confirmed hire takes the applicant off the list",
		PromotionsManager.applicant_of(one.id) == null and page.card_of(one.id) == null,
		"left %d" % [PromotionsManager.applicants.size()])
	TestFixtures.check(res, "the hire notice names the new merc",
		page.notice().showing() and page.notice().text() == "%s joined your guild." % who,
		"%s" % [page.notice().text()])
	TestFixtures.check(res, "the hire notice is green",
		page.notice().color().is_equal_approx(GREEN), "%s" % [page.notice().color()])
	TestFixtures.check(res, "a confirmed hire adds one merc",
		GameState.mercs.size() == roster + 1, "%d from %d" % [GameState.mercs.size(), roster])
	var hired_direct: MercenaryData = GameState.merc_by_uid(PromotionsManager.last_hired_uid)
	TestFixtures.check(res, "the new merc earns the agreed salary",
		hired_direct != null and hired_direct.monthly_salary == salary,
		"%d" % [-1 if hired_direct == null else hired_direct.monthly_salary])
	await _shut(host, page)


#P: sending a counter-offer.
static func _case_send_counter(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host, CREW_ENT)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	page.press_offer(one.id)
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	dialog.set_amount(one.ask - 60)
	var uid: int = GameState.mercs[0].merc_uid
	dialog.crew().add_merc(uid)
	await _frames(host, 1)
	var pay: int = dialog.pay_per()
	var bank: int = GameState.bank_notes
	dialog.press_action()
	await _frames(host, 2)
	TestFixtures.check(res, "the counter-offer marks the applicant pending",
		PromotionsManager.applicant_of(one.id).status == ApplicantData.STATUS_COUNTERED,
		"%s" % [PromotionsManager.applicant_of(one.id).status])
	TestFixtures.check(res, "the counter-offer keeps the offer it was sent with",
		PromotionsManager.applicant_of(one.id).counter_offer == one.ask - 60,
		"%d" % [PromotionsManager.applicant_of(one.id).counter_offer])
	TestFixtures.check(res, "the Odd Job pay leaves the bank once",
		GameState.bank_notes == bank - pay, "%d from %d, pay %d" % [GameState.bank_notes, bank,
		pay])
	TestFixtures.check(res, "the dialog closes behind the counter-offer", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	TestFixtures.check(res, "the card shows the answer is out",
		page.card_of(one.id) != null and page.card_of(one.id).is_pending(),
		"pending %s" % [page.card_of(one.id) != null and page.card_of(one.id).is_pending()])
	await _shut(host, page)


#Y: the answer that lands three days later.
static func _case_resolve(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var one: ApplicantData = _applicant(0)
	var who: String = one.name
	var offer: int = one.ask - 60
	var before: int = GameState.mercs.size()
	PromotionsManager.counter(one.id, offer)
	one.counter_odds = 100
	await _frames(host, 1)
	GameState.day_changed.emit(GameState.day() + PromotionsManager.COUNTER_DAYS)
	await _frames(host, 2)
	TestFixtures.check(res, "a forced pass reads as accepted",
		one.accepted_counter, "accepted %s" % [one.accepted_counter])
	TestFixtures.check(res, "an accepted counter-offer becomes the asking rate",
		one.ask == offer, "%d" % [one.ask])
	TestFixtures.check(res, "an accepted counter-offer signs the applicant on",
		one.status == ApplicantData.STATUS_HIRED and PromotionsManager.applicant_of(one.id) == null,
		"%s, gone %s" % [one.status, PromotionsManager.applicant_of(one.id) == null])
	TestFixtures.check(res, "the hire adds one merc",
		GameState.mercs.size() == before + 1 and PromotionsManager.last_hired_uid != 0,
		"%d from %d, uid %d" % [GameState.mercs.size(), before, PromotionsManager.last_hired_uid])
	var hired_counter: MercenaryData = GameState.merc_by_uid(PromotionsManager.last_hired_uid)
	TestFixtures.check(res, "the hired merc earns the counter offer",
		hired_counter != null and hired_counter.monthly_salary == offer,
		"%d" % [-1 if hired_counter == null else hired_counter.monthly_salary])
	TestFixtures.check(res, "the accepted notice names the applicant",
		page.notice().text() == HiringTab.NOTICE_HIRED % who,
		"%s" % [page.notice().text()])
	TestFixtures.check(res, "the accepted notice is green",
		page.notice().color().is_equal_approx(GREEN), "%s" % [page.notice().color()])
	await _shut(host, page)
	var slot_page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var three: ApplicantData = _applicant(2)
	var name_three: String = three.name
	var offer_three: int = three.ask - 60
	PromotionsManager.counter(three.id, offer_three)
	three.counter_odds = 100
	await _frames(host, 1)
	_fill_roster()
	var full_roster: int = GameState.mercs.size()
	GameState.day_changed.emit(GameState.day() + PromotionsManager.COUNTER_DAYS)
	await _frames(host, 2)
	TestFixtures.check(res, "an accepted offer with no free slot stays open",
		PromotionsManager.applicant_of(three.id) != null and three.accepted_counter
		and three.ask == offer_three and three.status == ApplicantData.STATUS_OPEN,
		"%s, %s, %d, %s" % [PromotionsManager.applicant_of(three.id) != null,
		three.accepted_counter, three.ask, three.status])
	TestFixtures.check(res, "a no-slot accept leaves the roster as filled",
		GameState.mercs.size() == full_roster,
		"%d from %d" % [GameState.mercs.size(), full_roster])
	TestFixtures.check(res, "the no-slot accept notice names the applicant and rings green",
		slot_page.notice().text() == HiringTab.NOTICE_ACCEPTED % name_three
		and slot_page.notice().color().is_equal_approx(GREEN),
		"%s" % [slot_page.notice().text()])
	var card_three: ApplicantCard = slot_page.card_of(three.id)
	TestFixtures.check(res, "the card of a no-slot accept shows the accepted text",
		card_three != null and card_three.status_text() == ApplicantCard.ACCEPTED_TEXT,
		"%s" % ["" if card_three == null else card_three.status_text()])
	await _shut(host, slot_page)
	var refuse_page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var two: ApplicantData = _applicant(1)
	var name_two: String = two.name
	var rate: int = two.ask
	PromotionsManager.counter(two.id, rate - 60)
	two.counter_odds = 0
	await _frames(host, 1)
	GameState.day_changed.emit(GameState.day() + PromotionsManager.COUNTER_DAYS)
	await _frames(host, 2)
	TestFixtures.check(res, "a forced refusal reads as refused",
		PromotionsManager.applicant_of(two.id).refused_counter,
		"refused %s" % [PromotionsManager.applicant_of(two.id).refused_counter])
	TestFixtures.check(res, "a refusal leaves the asking rate standing",
		PromotionsManager.applicant_of(two.id).ask == rate,
		"%d" % [PromotionsManager.applicant_of(two.id).ask])
	TestFixtures.check(res, "the refusal notice names the applicant",
		refuse_page.notice().text() == "%s refused your counter-offer." % name_two,
		"%s" % [refuse_page.notice().text()])
	TestFixtures.check(res, "the refusal notice is red",
		refuse_page.notice().color().is_equal_approx(GuiColors.RAMP_RED),
		"%s" % [refuse_page.notice().color()])
	await _shut(host, refuse_page)


#W: the notice banner itself.
static func _case_notice(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	var banner: HiringNotice = page.notice()
	TestFixtures.check(res, "the banner starts out of the way",
		banner != null and not banner.showing(), "showing %s" % [banner.showing()])
	banner.hold_seconds = 3.2
	banner.flash("First line", GREEN)
	TestFixtures.check(res, "a flash shows the line and its colour",
		banner.showing() and banner.text() == "First line"
		and banner.color().is_equal_approx(GREEN), "%s" % [banner.text()])
	banner.flash("Second line", GuiColors.RAMP_RED)
	TestFixtures.check(res, "a new flash replaces the old one",
		banner.text() == "Second line" and banner.color().is_equal_approx(GuiColors.RAMP_RED),
		"%s" % [banner.text()])
	banner.clear()
	TestFixtures.check(res, "clear takes the banner away",
		not banner.showing() and banner.text() == "", "showing %s" % [banner.showing()])
	banner.hold_seconds = HOLD
	banner.flash("Held line", GREEN)
	await _wait_clear(host, banner)
	TestFixtures.check(res, "the hold runs out on its own", not banner.showing(),
		"showing %s" % [banner.showing()])
	page.hide()
	await _frames(host, 1)
	var one: ApplicantData = _applicant(0)
	GameState.bank_notes = RICH
	PromotionsManager.hire(one.id, one.ask)
	await _frames(host, 1)
	TestFixtures.check(res, "a hidden page flashes nothing", not banner.showing(),
		"showing %s" % [banner.showing()])
	page.show()
	await _frames(host, 1)
	await _shut(host, page)


#A: the page opening on a stored hire filter.
static func _case_shown(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.open_hiring(3)
	page.page_shown()
	await _frames(host, 1)
	TestFixtures.check(res, "page_shown reads the stored campaign filter",
		page.filter_panel().value_of("from") == [3],
		"%s" % [page.filter_panel().value_of("from")])
	TestFixtures.check(res, "only that campaign is left on the grid",
		page.card_ids() == [_id(1)], "%s" % [page.card_ids()])
	TestFixtures.check(res, "the count line follows the stored filter",
		page.count_text() == "1 of 8 applicants shown", "%s" % [page.count_text()])
	TestFixtures.check(res, "the stored filter is handed over once",
		GameState.hire_filter.is_empty(), "%s" % [GameState.hire_filter])
	var group: FilterGroup = page.filter_panel().group_for(VALUE_GROUP)
	TestFixtures.check(res, "page_shown opens the Value group",
		group != null and group.is_open(), "open %s" % [group != null and group.is_open()])
	TestFixtures.check(res, "page_shown marks nobody seen",
		PromotionsManager.applicant_of(_id(3)).unseen,
		"unseen %s" % [PromotionsManager.applicant_of(_id(3)).unseen])
	await _shut(host, page)


#U: the two ways a lock asks for the Plans page.
static func _case_plans(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	var seen: Array[Dictionary] = []
	var grab := func(target: Dictionary) -> void:
		seen.append(target)
	GameState.go_to_plans_requested.connect(grab)
	page.filter_panel().take_me_there.emit({"page": "plans", "row": "hiringDiscrim"})
	await _frames(host, 1)
	TestFixtures.check(res, "a filter lock asks for the Plans page", seen.size() == 1
		and String(seen[0].get("row", "")) == "hiringDiscrim", "%s" % [seen])
	page.press_offer(_id(0))
	await _frames(host, 1)
	var dialog: HireOfferDialog = page.offer_dialog()
	dialog.set_amount(_applicant(0).ask - 60)
	await _frames(host, 1)
	dialog.add_lock().take_me_there.emit({"page": "plans", "row": "oddjobs"})
	await _frames(host, 1)
	TestFixtures.check(res, "the Odd Jobs lock asks for the Plans page", seen.size() == 2
		and String(seen[1].get("row", "")) == "oddjobs", "%s" % [seen])
	TestFixtures.check(res, "the dialog closes on the way to Plans", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	GameState.go_to_plans_requested.disconnect(grab)
	await _shut(host, page)


#G2: the runtime glyphs the page draws instead of a PNG.
static func _case_glyphs(res: Dictionary, host: Node) -> void:
	var eye: Texture2D = Icons.tex("eye", true)
	TestFixtures.check(res, "the eye glyph is the 12 x 8 atlas cut",
		eye != null and eye.get_size() == Vector2(12, 8), "%s" % [eye])
	TestFixtures.check(res, "the atlas cut is cached", Icons.tex("eye", true) == eye,
		"%s" % [eye])
	var hatch: ImageTexture = HiringGlyphs.hatch(ApplicantCard.HATCH_SIDE)
	TestFixtures.check(res, "the portrait hatch is square at the side it was asked for",
		hatch != null and hatch.get_size() == Vector2(ApplicantCard.HATCH_SIDE,
			ApplicantCard.HATCH_SIDE),
		"%s" % [Vector2.ZERO if hatch == null else hatch.get_size()])
	await _frames(host, 1)


#M: the modal host with and without a layer above the page.
static func _case_modal_host(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	TestFixtures.check(res, "with no layer above it the page is its own modal host",
		page.modal_host() == page, "%s" % [page.modal_host()])
	TestFixtures.check(res, "the dialog sits on the page",
		page.offer_dialog().get_parent() == page, "%s" % [page.offer_dialog().get_parent()])
	await _shut(host, page)
	_fresh()
	var frame := Control.new()
	var layer := Control.new()
	layer.name = "ModalLayer"
	layer.add_to_group(&"finance_modal_host")
	frame.add_child(layer)
	host.add_child(frame)
	var deep: HiringTab = PAGE.instantiate() as HiringTab
	frame.add_child(deep)
	await _frames(host, 2)
	TestFixtures.check(res, "a ModalLayer above the page takes the modals",
		deep.modal_host() == layer, "%s" % [deep.modal_host()])
	TestFixtures.check(res, "the dialog lands on that layer",
		deep.offer_dialog().get_parent() == layer, "%s" % [deep.offer_dialog().get_parent()])
	TestFixtures.check(res, "the confirm lands on that layer too",
		deep.confirm_dialog().get_parent() == layer, "%s" % [deep.confirm_dialog().get_parent()])
	frame.queue_free()
	await _frames(host, 2)


#Z: a refresh while the page is away.
static func _case_hidden(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	page.hide()
	await _frames(host, 1)
	var before: int = page.shown_count()
	PromotionsManager.reject(_id(0))
	await _frames(host, 1)
	TestFixtures.check(res, "a hidden page keeps the cards it had",
		page.shown_count() == before, "%d from %d" % [page.shown_count(), before])
	page.show()
	await _frames(host, 1)
	TestFixtures.check(res, "showing the page catches it up",
		page.shown_count() == before - 1, "%d from %d" % [page.shown_count(), before])
	TestFixtures.check(res, "the count line catches up with it",
		page.count_text() == "7 of 7 applicants shown", "%s" % [page.count_text()])
	await _shut(host, page)


#F2: the offer page as a frame of the modal ladder.
static func _case_offer_frame(res: Dictionary, host: Node) -> void:
	var page: HiringTab = await _open(host)
	GameState.bank_notes = RICH
	GuiFrameStack.clear()
	page.press_offer(_id(0))
	await _frames(host, 2)
	var dialog: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "the offer page is fitted to the viewport, not the scaled canvas",
		dialog.top_level and dialog.position == Vector2.ZERO,
		"top %s at %s" % [dialog.top_level, dialog.position])
	TestFixtures.check(res, "opening the offer page pushes it on the frame ladder",
		GuiFrameStack.top() == dialog and GuiFrameStack.depth() == 1,
		"depth %d" % [GuiFrameStack.depth()])
	var above := Control.new()
	above.name = "AboveTheOffer"
	host.add_child(above)
	await _frames(host, 1)
	GuiFrameStack.push(above)
	_escape(host)
	await _frames(host, 2)
	TestFixtures.check(res, "Esc under a frame above it leaves the offer page open",
		dialog.is_open() and GuiFrameStack.depth() == 2,
		"open %s depth %d" % [dialog.is_open(), GuiFrameStack.depth()])
	GuiFrameStack.remove(above)
	above.queue_free()
	await _frames(host, 1)
	_escape(host)
	await _frames(host, 2)
	TestFixtures.check(res, "Esc on the top frame closes the offer page alone",
		not dialog.is_open() and GuiFrameStack.depth() == 0,
		"open %s depth %d" % [dialog.is_open(), GuiFrameStack.depth()])
	var action: BevelButton = dialog.action_button() as BevelButton
	var cancel: BevelButton = dialog.cancel_button() as BevelButton
	TestFixtures.check(res, "the offer page commits through a core bevel button",
		action != null and action.kind == &"go" and action.fill.is_equal_approx(GREEN),
		"%s" % [&"" if action == null else action.kind])
	TestFixtures.check(res, "the offer page dismisses through a core bevel button",
		cancel != null and cancel.kind == &"blue" and cancel.fill.is_equal_approx(BLUE2),
		"%s" % [&"" if cancel == null else cancel.kind])
	await _shut(host, page)

class_name GuiPayViewTests

#The Payroll page of the Finance Viewer: the two stat tiles, the sorted and filtered merc list, the
#hover card, the benefits panel, the two benefit dialogs and the wage box with its fire confirm.
#The page runs on its own here, so every case builds it, drives it through the public helpers the
#screens expose and frees it again. A synthetic click never reaches a button in a headless run,
#which is why nothing here presses a Button node.

const PAGE_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollTab.tscn")
const STEP_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollStepper.tscn")
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollItem.tscn")
const MONEY: int = 10000
const RICH_WAGE: int = 2500
const BENEFIT_KEYS: Array[String] = ["profit", "contract", "odd"]
const VACATION_CELLS: int = 6
const STATUSES: Array[int] = [GuiTypes.MercStatus.AVAILABLE, GuiTypes.MercStatus.RESTING,
	GuiTypes.MercStatus.CONTRACT, GuiTypes.MercStatus.VACATION, GuiTypes.MercStatus.LOAN,
	GuiTypes.MercStatus.DEAD, GuiTypes.MercStatus.FIRED, GuiTypes.MercStatus.MISSING,
	GuiTypes.MercStatus.CAPTURED]
const REJECT_WAIT: float = 0.55
const BAR_RESERVE: float = 76.0
const BAND_AVAILABLE: Color = Color("#6cc36a")
const BAND_GONE: Color = Color("#e8583f")
const BAND_OTHER: Color = Color("#f3ead7")


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	await _case_stats(res, host)
	await _case_sort(res, host)
	await _case_filter(res, host)
	await _case_rows(res, host)
	await _case_press(res, host)
	await _case_tooltip(res, host)
	await _case_benefits(res, host)
	await _case_benefit_dialog(res, host)
	await _case_vacation_dialog(res, host)
	await _case_stepper(res, host)
	await _case_fire(res, host)
	await _case_host(res, host)
	await _case_hidden(res, host)
	await _case_band(res, host)
	await _case_modal_escape(res, host)
	await _case_bevel_buttons(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	BenefitsManager.reset()
	SubscriptionManager.reset()
	GuiFrameStack.clear()
	return TestFixtures.summarize(res, "GUI PAYVIEW")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	BenefitsManager.reset()
	SubscriptionManager.reset()
	GuiFrameStack.clear()
	GameState.bank_notes = MONEY


static func _open(host: Node) -> PayrollTab:
	_fresh()
	var page: PayrollTab = PAGE_SCENE.instantiate() as PayrollTab
	host.add_child(page)
	await host.get_tree().process_frame
	page.refresh()
	return page


static func _close(page: PayrollTab, host: Node) -> void:
	if page != null and is_instance_valid(page):
		page.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	GuiFrameStack.clear()


static func _uid(index: int) -> int:
	if index < 0 or index >= GameState.roster.size():
		return 0
	return GameState.roster[index].uid


static func _set_pay(uid: int, salary: int, opinion: int) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.monthly_salary = maxi(1, salary)
	merc.guild_opinion = clampi(opinion, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX)
	GameState.refresh_views()


static func _set_level(uid: int, level: int) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.stats["level"] = level
	GameState.refresh_views()


#The mood a merc left the guild with; the payroll drops a removed merc, the record keeps it.
static func _left_opinion(uid: int) -> int:
	var record: RemovedMercRecord = GameState.removed_by_uid(uid)
	return record.guild_opinion if record != null else 0


static func _rest(uid: int, kind: String) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.rest_lockout_kind = kind
	merc.rest_lockout_until = CampaignClock.now() + CampaignClock.MINUTES_PER_DAY
	GameState.refresh_views()


static func _contract(uid: int, out: bool) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.on_contract = out
	GameState.refresh_views()


static func _top_salary() -> int:
	var top: int = 0
	for view: MercView in GameState.roster:
		if view != null:
			top = maxi(top, view.monthly_salary)
	return top


static func _row_of(uid: int) -> Dictionary:
	for row: Dictionary in BenefitsManager.payroll_rows():
		if int(row.get("uid", 0)) == uid:
			return row
	return {}


static func _band(status: int) -> String:
	return GuiTypes.merc_status_text(status).to_upper()


#The colour the strip node of a row wears, read off the row itself and not off the row dictionary.
static func _strip_color(page: PayrollTab, uid: int) -> Color:
	for node: Node in page.list.get_children():
		var item: PayrollItem = node as PayrollItem
		if item != null and item.uid() == uid and not item.is_queued_for_deletion():
			return item.strip.get_theme_color("font_color")
	return Color(0.0, 0.0, 0.0, 0.0)


#The control a hover over the centre of a node resolves to, asked of the stepper the node sits in.
static func _hover_at(step: PayrollStepper, node: Control) -> Control:
	var centre: Vector2 = node.get_global_rect().get_center()
	return step.hover_target(step.get_global_transform().affine_inverse() * centre)


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(key) or str(b[key]) != str(a[key]):
			return false
	return true


static func _index_of(page: PayrollTab, uid: int) -> int:
	for i: int in page.row_count():
		if page.row_uid(i) == uid:
			return i
	return -1


static func _numbers(page: PayrollTab, field: String) -> Array[int]:
	var out: Array[int] = []
	for i: int in page.row_count():
		var uid: int = page.row_uid(i)
		if field == "guild":
			out.append(BenefitsManager.opinion_of(uid))
		elif field == "level":
			var view: MercView = BenefitsManager.view_of(uid)
			out.append(view.level if view != null else 0)
		else:
			out.append(BenefitsManager.salary_of(uid))
	return out


static func _falls(list: Array[int]) -> bool:
	for i: int in list.size() - 1:
		if list[i] < list[i + 1]:
			return false
	return true


static func _rises(list: Array[int]) -> bool:
	for i: int in list.size() - 1:
		if list[i] > list[i + 1]:
			return false
	return true


static func _names(page: PayrollTab) -> Array[String]:
	var out: Array[String] = []
	for i: int in page.row_count():
		out.append(page.row_text(i, "name"))
	return out


static func _a_to_z(names: Array[String]) -> bool:
	for i: int in names.size() - 1:
		if names[i].naturalnocasecmp_to(names[i + 1]) > 0:
			return false
	return true


static func _z_to_a(names: Array[String]) -> bool:
	for i: int in names.size() - 1:
		if names[i].naturalnocasecmp_to(names[i + 1]) < 0:
			return false
	return true


#The frame the hover card is placed inside: the page when it has a size, the viewport otherwise.
static func _frame(page: PayrollTab) -> Vector2:
	return page.size if page.size.x > 0.0 else Vector2(page.get_viewport_rect().size)


static func _cell_value(panel: BenefitsPanel, label: String) -> String:
	for i: int in panel.cell_count():
		if panel.cell_text(i, "label") == label:
			return panel.cell_text(i, "value")
	return ""


#The two tiles over the list: the wage bill and the payday countdown, then the licence count.
static func _case_stats(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	TestFixtures.check(res, "the page titles the merc list",
		page.title.text == PayrollTab.TITLE_TEXT, page.title.text)
	TestFixtures.check(res, "the payroll tile carries the monthly wage bill",
		page.stat_text("payroll") == str(BenefitsManager.payroll_total())
			and page.payroll_tile.label == PayrollTab.PAYROLL_LABEL,
		"tile '%s' total %d" % [page.stat_text("payroll"), BenefitsManager.payroll_total()])
	TestFixtures.check(res, "the wage bill reads in the spend colour",
		page.stat_color("payroll") == PayrollTab.RED, str(page.stat_color("payroll")))
	TestFixtures.check(res, "the payday tile counts the days to the next wages",
		page.stat_text("payday") == BenefitsManager.payday_text()
			and page.payday_tile.label == PayrollTab.PAYDAY_LABEL,
		"tile '%s' text '%s'" % [page.stat_text("payday"), BenefitsManager.payday_text()])
	TestFixtures.check(res, "the payday tile takes the band colour",
		page.stat_color("payday") == BenefitsManager.payday_color(),
		"%s vs %s" % [page.stat_color("payday"), BenefitsManager.payday_color()])
	TestFixtures.check(res, "only the wage bill wears the notes glyph",
		page.payroll_tile.show_glyph and not page.payday_tile.show_glyph,
		"bill %s payday %s" % [page.payroll_tile.show_glyph, page.payday_tile.show_glyph])
	var employed: int = BenefitsManager.employed_views().size()
	var cap: int = int(SubscriptionManager.entitlements().get("maxMercs", 0))
	TestFixtures.check(res, "the head counts the employed mercs against the licence",
		page.count_text() == "%d/%d" % [employed, cap] and employed == GameState.roster.size(),
		"count '%s' employed %d cap %d" % [page.count_text(), employed, cap])
	SubscriptionManager.set_entitlements({"maxMercs": 12})
	TestFixtures.check(res, "a licence change redraws the count",
		page.count_text() == "%d/%d" % [employed, 12], page.count_text())
	var before: String = page.stat_text("payroll")
	var uid: int = _uid(0)
	var _after: int = BenefitsManager.apply_salary(uid, BenefitsManager.salary_of(uid) + 500)
	TestFixtures.check(res, "a wage written through the manager redraws the bill",
		page.stat_text("payroll") == str(BenefitsManager.payroll_total())
			and page.stat_text("payroll") != before,
		"bill '%s' was '%s'" % [page.stat_text("payroll"), before])
	TestFixtures.check(res, "an unknown tile key reads empty",
		page.stat_text("nope") == "" and page.stat_color("nope") == PayrollTab.CREAM,
		"'%s'" % page.stat_text("nope"))
	await _close(page, host)


#The four sort rows and the direction toggle over one list of known wages, opinions and levels.
static func _case_sort(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	for i: int in GameState.roster.size():
		var uid: int = _uid(i)
		_set_pay(uid, 40 + i * 30, clampi(i - 4, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX))
		_set_level(uid, 2 + i)
	page.refresh()
	TestFixtures.check(res, "the list opens on the wage, highest first",
		page.sort_key() == "salary" and page.descending()
			and page.row_count() == GameState.roster.size(),
		"key %s down %s rows %d" % [page.sort_key(), page.descending(), page.row_count()])
	TestFixtures.check(res, "the wage rows run down the list",
		_falls(_numbers(page, "salary")), str(_numbers(page, "salary")))
	page.set_descending(false)
	TestFixtures.check(res, "the direction toggle turns the wages around",
		not page.descending() and _rises(_numbers(page, "salary")),
		str(_numbers(page, "salary")))
	page.set_descending(true)
	page.set_sort("guild")
	TestFixtures.check(res, "the guild opinion row sorts on the opinion",
		page.sort_key() == "guild" and page.sort_button.selected == 1
			and _falls(_numbers(page, "guild")),
		"key %s pick %d %s" % [page.sort_key(), page.sort_button.selected,
			str(_numbers(page, "guild"))])
	page.set_descending(false)
	TestFixtures.check(res, "the ascending opinion runs the other way",
		_rises(_numbers(page, "guild")), str(_numbers(page, "guild")))
	page.set_descending(true)
	page.set_sort("level")
	TestFixtures.check(res, "the level row sorts on the level",
		page.sort_key() == "level" and _falls(_numbers(page, "level")),
		str(_numbers(page, "level")))
	page.set_descending(false)
	TestFixtures.check(res, "the ascending level runs the other way",
		_rises(_numbers(page, "level")), str(_numbers(page, "level")))
	page.set_descending(true)
	page.set_sort("name")
	TestFixtures.check(res, "the name row reads A to Z with the toggle down",
		page.sort_key() == "name" and _a_to_z(_names(page)), str(_names(page)))
	page.set_descending(false)
	TestFixtures.check(res, "the toggle turns the names around",
		_z_to_a(_names(page)), str(_names(page)))
	page.set_descending(true)
	page.set_sort("nope")
	TestFixtures.check(res, "an unknown sort key is refused",
		page.sort_key() == "name" and page.sort_button.selected == 3,
		"key %s pick %d" % [page.sort_key(), page.sort_button.selected])
	page.set_sort("salary")
	TestFixtures.check(res, "the toolbar offers the four rows the page sorts on",
		page.sort_button.options.size() == PayrollTab.SORT_LABELS.size()
			and page.sort_button.options[0] == PayrollTab.SORT_LABELS[0],
		str(page.sort_button.options))
	await _close(page, host)


#The status filter: the default rows, one status off, a status nothing answers to, the reset and the
#empty state. An odd job answers to the loan row.
static func _case_filter(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var total: int = GameState.roster.size()
	_rest(_uid(1), RestSystem.KIND_BREATHER)
	_rest(_uid(2), RestSystem.KIND_FURLOUGH)
	_contract(_uid(3), true)
	var odd: int = _uid(4)
	var _sent: bool = GameState.set_away(odd, GuiTypes.MercStatus.ODD_JOB)
	page.refresh()
	TestFixtures.check(res, "the guild statuses start shown",
		page.status_shown(GuiTypes.MercStatus.AVAILABLE)
			and page.status_shown(GuiTypes.MercStatus.RESTING)
			and page.status_shown(GuiTypes.MercStatus.CONTRACT)
			and page.status_shown(GuiTypes.MercStatus.VACATION)
			and page.status_shown(GuiTypes.MercStatus.LOAN),
		"available %s" % page.status_shown(GuiTypes.MercStatus.AVAILABLE))
	TestFixtures.check(res, "the mercs the guild has lost start hidden",
		not page.status_shown(GuiTypes.MercStatus.DEAD)
			and not page.status_shown(GuiTypes.MercStatus.FIRED)
			and not page.status_shown(GuiTypes.MercStatus.MISSING)
			and not page.status_shown(GuiTypes.MercStatus.CAPTURED),
		"dead %s" % page.status_shown(GuiTypes.MercStatus.DEAD))
	TestFixtures.check(res, "every merc in the guild is on the list", page.row_count() == total,
		"rows %d of %d" % [page.row_count(), total])
	TestFixtures.check(res, "an odd job answers to the loan row",
		page.status_shown(GuiTypes.MercStatus.ODD_JOB)
			== page.status_shown(GuiTypes.MercStatus.LOAN) and _index_of(page, odd) >= 0,
		"odd %s at %d" % [page.status_shown(GuiTypes.MercStatus.ODD_JOB), _index_of(page, odd)])
	TestFixtures.check(res, "the default set leaves the filter button plain",
		not page.filter_active()
			and not page.filter_button.has_theme_stylebox_override("normal"),
		"active %s" % page.filter_active())
	page.set_status_shown(GuiTypes.MercStatus.LOAN, false)
	TestFixtures.check(res, "hiding the loan row hides the odd job merc",
		_index_of(page, odd) < 0 and page.row_count() == total - 1
			and not page.status_shown(GuiTypes.MercStatus.ODD_JOB),
		"rows %d at %d" % [page.row_count(), _index_of(page, odd)])
	TestFixtures.check(res, "a changed set turns the filter button orange",
		page.filter_active()
			and page.filter_button.get_theme_stylebox("normal") == PayrollTab.STYLE_ORANGE
			and page.filter_button.get_theme_color("font_color") == PayrollTab.DARK,
		"active %s" % page.filter_active())
	page.reset_filter()
	TestFixtures.check(res, "the reset puts every default row back",
		page.row_count() == total and not page.filter_active()
			and not page.filter_button.has_theme_stylebox_override("normal"),
		"rows %d active %s" % [page.row_count(), page.filter_active()])
	page.set_status_shown(GuiTypes.MercStatus.AVAILABLE, false)
	var available: int = 0
	for view: MercView in GameState.roster:
		if view != null and BenefitsManager.status_of(view.uid) == GuiTypes.MercStatus.AVAILABLE:
			available += 1
	TestFixtures.check(res, "hiding the available row drops those mercs",
		page.row_count() == total - available and available > 0,
		"rows %d of %d less %d" % [page.row_count(), total, available])
	page.reset_filter()
	page.set_status_shown(GuiTypes.MercStatus.MISSING, true)
	TestFixtures.check(res, "showing a status nothing answers to adds no row",
		page.row_count() == total and page.filter_active(),
		"rows %d active %s" % [page.row_count(), page.filter_active()])
	page.reset_filter()
	for status: int in STATUSES:
		page.set_status_shown(status, false)
	TestFixtures.check(res, "hiding every row empties the list",
		page.row_count() == 0 and page.empty_text() == PayrollTab.EMPTY_TEXT
			and not page.scroll.visible and page.empty_box.visible,
		"rows %d empty '%s'" % [page.row_count(), page.empty_text()])
	TestFixtures.check(res, "the empty list carries no hover card",
		page.tooltip().shown_uid() == 0 and not page.tooltip().visible,
		"uid %d" % page.tooltip().shown_uid())
	page.reset_filter()
	TestFixtures.check(res, "the reset brings the list back",
		page.row_count() == total and page.scroll.visible and page.empty_text() == "",
		"rows %d empty '%s'" % [page.row_count(), page.empty_text()])
	await _close(page, host)


#What one row shows: the name, the tradition, the status band, the wage and the level plate, and the
#three colours the row carries.
static func _case_rows(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var uid_a: int = _uid(0)
	var wage: int = maxi(_top_salary() + 100, RICH_WAGE)
	_set_pay(uid_a, wage, 2)
	page.refresh()
	var at: int = _index_of(page, uid_a)
	var view: MercView = BenefitsManager.view_of(uid_a)
	TestFixtures.check(res, "the top wage takes the first row",
		at == 0 and page.row_uid(0) == uid_a, "at %d uid %d wage %d" % [at, uid_a, wage])
	TestFixtures.check(res, "the row names the merc", page.row_text(at, "name") == view.name,
		"'%s' vs '%s'" % [page.row_text(at, "name"), view.name])
	TestFixtures.check(res, "the row names the tradition",
		page.row_text(at, "tradition") == view.tradition,
		"'%s' vs '%s'" % [page.row_text(at, "tradition"), view.tradition])
	TestFixtures.check(res, "the portrait band reads the status in capitals",
		page.row_text(at, "status") == _band(GuiTypes.MercStatus.AVAILABLE),
		"'%s' vs '%s'" % [page.row_text(at, "status"), _band(GuiTypes.MercStatus.AVAILABLE)])
	TestFixtures.check(res, "the row reads the monthly wage",
		page.row_text(at, "salary") == NotesLabel.format_amount(wage),
		"'%s' vs '%s'" % [page.row_text(at, "salary"), NotesLabel.format_amount(wage)])
	TestFixtures.check(res, "the plate reads the level",
		page.row_text(at, "level") == "%02d" % view.level,
		"'%s' vs %d" % [page.row_text(at, "level"), view.level])
	var level_was: int = view.level
	_set_level(uid_a, 7)
	page.refresh()
	var one_digit: String = page.row_text(_index_of(page, uid_a), "level")
	_set_level(uid_a, 12)
	page.refresh()
	var two_digits: String = page.row_text(_index_of(page, uid_a), "level")
	_set_level(uid_a, 0)
	page.refresh()
	var no_level: String = page.row_text(_index_of(page, uid_a), "level")
	TestFixtures.check(res, "the plate pads one digit and prints ten or more as it stands",
		one_digit == "07" and two_digits == "12" and no_level == "00",
		"'%s' '%s' '%s'" % [one_digit, two_digits, no_level])
	_set_level(uid_a, level_was)
	page.refresh()
	TestFixtures.check(res, "an unknown row key reads empty", page.row_text(at, "nope") == "",
		"'%s'" % page.row_text(at, "nope"))
	TestFixtures.check(res, "an available merc wears the available band colour",
		page.row_color(at, "status") == BAND_AVAILABLE
			and _strip_color(page, uid_a) == BAND_AVAILABLE,
		"%s strip %s" % [str(page.row_color(at, "status")), str(_strip_color(page, uid_a))])
	TestFixtures.check(res, "the tradition line takes the tradition colour",
		page.row_color(at, "tradition") == GuiTypes.tradition_color(view.tradition),
		str(page.row_color(at, "tradition")))
	TestFixtures.check(res, "a wage over a tenth of the bank warns",
		page.row_color(at, "salary") == PayrollLogic.salary_color(wage, GameState.bank_notes)
			and page.row_color(at, "salary") == PayrollLogic.WARN_COLOR,
		str(page.row_color(at, "salary")))
	GameState.bank_notes = wage - 1
	page.refresh()
	TestFixtures.check(res, "a wage over the bank reads over",
		page.row_color(_index_of(page, uid_a), "salary") == PayrollLogic.OVER_COLOR,
		str(page.row_color(_index_of(page, uid_a), "salary")))
	GameState.bank_notes = wage * 100
	page.refresh()
	TestFixtures.check(res, "a wage a full bank covers reads well",
		page.row_color(_index_of(page, uid_a), "salary") == PayrollLogic.OK_COLOR,
		str(page.row_color(_index_of(page, uid_a), "salary")))
	var uid_b: int = _uid(1)
	_rest(uid_b, RestSystem.KIND_BREATHER)
	page.refresh()
	var rest_at: int = _index_of(page, uid_b)
	TestFixtures.check(res, "a resting merc reads resting on the band",
		rest_at >= 0 and page.row_text(rest_at, "status") == _band(GuiTypes.MercStatus.RESTING),
		"at %d '%s'" % [rest_at, page.row_text(rest_at, "status")])
	TestFixtures.check(res, "a merc off duty wears the plain band colour",
		page.row_color(rest_at, "status") == BAND_OTHER
			and page.row_color(rest_at, "status") != BAND_AVAILABLE
			and _strip_color(page, uid_b) == BAND_OTHER,
		"%s strip %s" % [str(page.row_color(rest_at, "status")), str(_strip_color(page, uid_b))])
	var uid_c: int = _uid(2)
	var gone: bool = BenefitsManager.fire(uid_c)
	page.set_status_shown(GuiTypes.MercStatus.FIRED, true)
	var fired_at: int = _index_of(page, uid_c)
	TestFixtures.check(res, "a fired merc reads off the page even with that row shown",
		gone and fired_at < 0 and _strip_color(page, uid_c) == Color(0.0, 0.0, 0.0, 0.0),
		"gone %s at %d" % [gone, fired_at])
	var fired_row: PayrollItem = ROW_SCENE.instantiate() as PayrollItem
	host.add_child(fired_row)
	await host.get_tree().process_frame
	fired_row.set_row({"uid": 0, "name": "Let go", "status": GuiTypes.MercStatus.FIRED,
		"level": 3})
	TestFixtures.check(res, "a fired row reads fired on the band",
		fired_row.text("status") == _band(GuiTypes.MercStatus.FIRED),
		"'%s'" % fired_row.text("status"))
	TestFixtures.check(res, "a fired row wears the gone band colour",
		fired_row.color("status") == BAND_GONE
			and fired_row.strip.get_theme_color("font_color") == BAND_GONE,
		"%s strip %s" % [str(fired_row.color("status")),
			str(fired_row.strip.get_theme_color("font_color"))])
	fired_row.queue_free()
	await host.get_tree().process_frame
	var dead_row: PayrollItem = ROW_SCENE.instantiate() as PayrollItem
	host.add_child(dead_row)
	await host.get_tree().process_frame
	dead_row.set_row({"uid": 0, "name": "Gone", "status": GuiTypes.MercStatus.DEAD, "level": 3})
	TestFixtures.check(res, "a dead row wears the gone band colour too",
		dead_row.color("status") == BAND_GONE
			and dead_row.strip.get_theme_color("font_color") == BAND_GONE,
		"%s strip %s" % [str(dead_row.color("status")),
			str(dead_row.strip.get_theme_color("font_color"))])
	dead_row.queue_free()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an index off the list reads empty and cream",
		page.row_text(99, "name") == "" and page.row_color(99, "salary") == PayrollTab.CREAM
			and page.row_uid(-1) == 0,
		"'%s'" % page.row_text(99, "name"))
	await _close(page, host)


#A press on a row opens the wage box on that merc; the hover card gets out of the way first.
static func _case_press(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var uid: int = page.row_uid(0)
	page.hover_row(0)
	page.press_row(0)
	var dialog: SalaryDialog = page.salary_dialog()
	TestFixtures.check(res, "a press opens the wage box on that merc",
		dialog.visible and dialog.merc_uid == uid,
		"open %s uid %d wanted %d" % [dialog.visible, dialog.merc_uid, uid])
	TestFixtures.check(res, "the hover card leaves when the box opens",
		page.tooltip().shown_uid() == 0, "uid %d" % page.tooltip().shown_uid())
	TestFixtures.check(res, "the open box is the top frame",
		GuiFrameStack.top() == dialog and GuiFrameStack.depth() == 1,
		"depth %d" % GuiFrameStack.depth())
	TestFixtures.check(res, "the box names the merc it opened for",
		dialog.text("name") == page.row_text(0, "name")
			and dialog.text("kicker") == SalaryDialog.KICKER_TEXT,
		"'%s' vs '%s'" % [dialog.text("name"), page.row_text(0, "name")])
	await host.get_tree().process_frame
	var fire_row: HBoxContainer = dialog.fire_link.get_parent() as HBoxContainer
	var row_end: float = fire_row.get_global_rect().end.x
	var link_end: float = dialog.fire_link.get_global_rect().end.x
	TestFixtures.check(res, "the Fire link sits at the right edge of its row",
		fire_row.alignment == BoxContainer.ALIGNMENT_END and absf(row_end - link_end) <= 1.0,
		"row %.1f link %.1f align %d" % [row_end, link_end, fire_row.alignment])
	dialog.press_cancel()
	TestFixtures.check(res, "cancel closes the box and clears the stack",
		not dialog.visible and GuiFrameStack.depth() == 0,
		"open %s depth %d" % [dialog.visible, GuiFrameStack.depth()])
	page.press_row(-1)
	page.press_row(99)
	TestFixtures.check(res, "a press off the list opens nothing", not dialog.visible,
		"open %s" % dialog.visible)
	page.press_row(0)
	var opening: int = dialog.value()
	dialog.set_value(opening + 100)
	dialog.press_confirm()
	await host.get_tree().process_frame
	var at: int = _index_of(page, uid)
	TestFixtures.check(res, "a wage confirmed from the page redraws that row",
		at >= 0 and page.row_text(at, "salary") == NotesLabel.format_amount(opening + 100)
			and BenefitsManager.salary_of(uid) == opening + 100,
		"row '%s' wage %d" % [page.row_text(at, "salary"), BenefitsManager.salary_of(uid)])
	TestFixtures.check(res, "the wage bill follows the change",
		page.stat_text("payroll") == str(BenefitsManager.payroll_total()),
		page.stat_text("payroll"))
	await _close(page, host)


#The hover card: what it reads off the row, the trait rows under it and where it lands.
static func _case_tooltip(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var uid: int = page.row_uid(0)
	var tip: PayrollTooltip = page.tooltip()
	page.hover_row(0)
	var view: MercView = BenefitsManager.view_of(uid)
	var row: Dictionary = _row_of(uid)
	TestFixtures.check(res, "a hover raises the card for that merc",
		tip.visible and tip.shown_uid() == uid,
		"open %s uid %d wanted %d" % [tip.visible, tip.shown_uid(), uid])
	TestFixtures.check(res, "the card names the merc", tip.text("name") == view.name,
		"'%s' vs '%s'" % [tip.text("name"), view.name])
	TestFixtures.check(res, "the card reads the heritage",
		tip.text("heritage") == view.heritage,
		"'%s' vs '%s'" % [tip.text("heritage"), view.heritage])
	var ancestry: String = String(row.get("ancestry", ""))
	var age: String = String(row.get("age", ""))
	var origin: String = ancestry + age
	if ancestry != "" and age != "":
		origin = "%s - %s" % [ancestry, age]
	TestFixtures.check(res, "the card reads the ancestry and the age band",
		tip.text("origin") == origin and origin != "",
		"'%s' vs '%s'" % [tip.text("origin"), origin])
	TestFixtures.check(res, "the card reads how long the merc has served",
		tip.text("employed") == BenefitsManager.employed_text(uid),
		"'%s' vs '%s'" % [tip.text("employed"), BenefitsManager.employed_text(uid)])
	TestFixtures.check(res, "the card names the tradition in its colour",
		tip.text("tradition") == view.tradition
			and tip.tradition_color() == GuiTypes.tradition_color(view.tradition),
		"'%s' %s" % [tip.text("tradition"), tip.tradition_color()])
	await host.get_tree().process_frame
	var sigil_art: Vector2 = tip.sigil.custom_minimum_size
	var sigil_frame: Vector2 = tip.sigil_box.custom_minimum_size
	var sigil_rect: Rect2 = Rect2(tip.sigil.position, tip.sigil.size)
	TestFixtures.check(res, "the tradition sigil sits at one to one inside its frame",
		tip.sigil.pixel_scale == 1 and sigil_art == Vector2(16.0, 16.0)
			and sigil_frame == Vector2(20.0, 20.0)
			and sigil_rect.size == Vector2(16.0, 16.0)
			and sigil_rect.position == Vector2(2.0, 2.0)
			and Rect2(Vector2.ZERO, tip.sigil_box.size).encloses(sigil_rect),
		"%s at %s in %s" % [sigil_art, sigil_rect.position, sigil_frame])
	TestFixtures.check(res, "the card reads the wage",
		tip.text("salary") == NotesLabel.format_amount(view.monthly_salary),
		"'%s' vs %d" % [tip.text("salary"), view.monthly_salary])
	var kept: Array[Dictionary] = BenefitsManager.unique_traits(uid)
	TestFixtures.check(res, "the card lists the traits the manager picked",
		tip.trait_count() == kept.size(),
		"card %d manager %d" % [tip.trait_count(), kept.size()])
	if not kept.is_empty():
		TestFixtures.check(res, "a trait row carries its kind, name and rarity",
			tip.trait_text(0, "kind") == String(kept[0].get("kind", ""))
				and tip.trait_text(0, "name") == String(kept[0].get("name", ""))
				and tip.trait_text(0, "rarity") == String(kept[0].get("rarity", "")),
			"'%s' '%s' '%s'" % [tip.trait_text(0, "kind"), tip.trait_text(0, "name"),
				tip.trait_text(0, "rarity")])
	else:
		TestFixtures.check(res, "a merc with no unique trait lists none",
			tip.trait_text(0, "kind") == "", tip.trait_text(0, "kind"))
	TestFixtures.check(res, "a trait row off the list reads empty",
		tip.trait_text(99, "name") == "" and tip.trait_text(-1, "name") == "",
		"'%s'" % tip.trait_text(99, "name"))
	TestFixtures.check(res, "an unknown card key reads empty", tip.text("nope") == "",
		"'%s'" % tip.text("nope"))
	TestFixtures.check(res, "the card never takes the mouse",
		tip.mouse_filter == Control.MOUSE_FILTER_IGNORE, str(tip.mouse_filter))
	var frame: Vector2 = _frame(page)
	tip.show_for(uid, Rect2(100.0, 60.0, 200.0, PayrollItem.ROW_HEIGHT))
	TestFixtures.check(res, "the card sits to the right of the row it belongs to",
		is_equal_approx(tip.position.x, 100.0 + 200.0 + PayrollTooltip.GAP)
			and is_equal_approx(tip.position.y, 60.0),
		"at %s frame %s" % [tip.position, frame])
	TestFixtures.check(res, "the card is never narrower than the prototype card",
		tip.size.x >= PayrollTooltip.WIDTH, str(tip.size))
	var edge: float = frame.x - 200.0
	tip.show_for(uid, Rect2(edge, 60.0, 100.0, PayrollItem.ROW_HEIGHT))
	TestFixtures.check(res, "a row against the right edge flips the card to its left",
		tip.position.x < edge
			and is_equal_approx(tip.position.x, edge - tip.size.x - PayrollTooltip.GAP),
		"at %s edge %f" % [tip.position, edge])
	tip.show_for(uid, Rect2(100.0, frame.y - 20.0, 200.0, PayrollItem.ROW_HEIGHT))
	TestFixtures.check(res, "a row near the floor holds the card inside the frame",
		tip.position.y + tip.size.y <= frame.y - PayrollTooltip.EDGE_PAD + 0.5,
		"at %s size %s frame %s" % [tip.position, tip.size, frame])
	page.clear_hover()
	TestFixtures.check(res, "leaving the row hides the card",
		not tip.visible and tip.shown_uid() == 0,
		"open %s uid %d" % [tip.visible, tip.shown_uid()])
	page.hover_row(99)
	TestFixtures.check(res, "a hover off the list raises nothing", not tip.visible,
		"open %s" % tip.visible)
	await _close(page, host)


#The benefits panel beside the list: the three bonus rows, the six policy cells and the two buttons.
static func _case_benefits(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var panel: BenefitsPanel = page.benefits()
	TestFixtures.check(res, "the panel lists the three bonuses",
		panel.row_count() == BENEFIT_KEYS.size(), str(panel.row_count()))
	var named: bool = true
	var valued: bool = true
	var off: bool = true
	for i: int in BENEFIT_KEYS.size():
		var name_key: String = BENEFIT_KEYS[i]
		var def: Dictionary = BenefitsManager.benefit_def(name_key)
		named = named and panel.row_key(i) == name_key
		named = named and panel.row_text(i, "label") == String(def.get("label", ""))
		named = named and panel.row_text(i, "desc") == String(def.get("desc", ""))
		valued = valued and (panel.row_text(i, "value")
			== BenefitsManager.benefit_text(name_key, BenefitsManager.benefit(name_key)))
		off = off and panel.row_color(i) == BenefitsManager.OFF_COLOR
	TestFixtures.check(res, "every bonus row carries its label and blurb", named,
		"%s %s %s" % [panel.row_key(0), panel.row_key(1), panel.row_key(2)])
	TestFixtures.check(res, "every bonus row reads the value the manager holds", valued,
		panel.row_text(0, "value"))
	TestFixtures.check(res, "a bonus that is off reads in the off colour", off,
		str(panel.row_color(0)))
	BenefitsManager.set_benefit("profit", 10)
	TestFixtures.check(res, "a bonus set from outside redraws the row in the on colour",
		panel.row_text(0, "value") == BenefitsManager.benefit_text("profit", 10)
			and panel.row_color(0) == BenefitsManager.ON_COLOR,
		"'%s' %s" % [panel.row_text(0, "value"), panel.row_color(0)])
	TestFixtures.check(res, "a row off the panel reads empty",
		panel.row_text(9, "value") == "" and panel.row_key(9) == "",
		"'%s'" % panel.row_text(9, "value"))
	TestFixtures.check(res, "the panel lays out the six policy cells",
		panel.cell_count() == VACATION_CELLS, str(panel.cell_count()))
	var rows: Array[Dictionary] = BenefitsManager.vacation_rows()
	var cells: bool = true
	for i: int in rows.size():
		cells = cells and panel.cell_text(i, "label") == String(rows[i].get("label", ""))
		cells = cells and panel.cell_text(i, "value") == String(rows[i].get("value_text", ""))
	TestFixtures.check(res, "every policy cell reads the policy", cells,
		"%s '%s'" % [panel.cell_text(0, "label"), panel.cell_text(0, "value")])
	TestFixtures.check(res, "a cell off the grid reads empty",
		panel.cell_text(99, "value") == "" and panel.cell_text(99, "nope") == "",
		"'%s'" % panel.cell_text(99, "value"))
	panel.press_adjust("contract")
	TestFixtures.check(res, "Adjust opens the benefit dialog on that bonus",
		page.benefit_dialog().is_open() and page.benefit_dialog().key() == "contract",
		"open %s key '%s'" % [page.benefit_dialog().is_open(), page.benefit_dialog().key()])
	page.benefit_dialog().press_cancel()
	panel.press_edit()
	TestFixtures.check(res, "Edit opens the vacation dialog",
		page.vacation_dialog().is_open(), "open %s" % page.vacation_dialog().is_open())
	page.vacation_dialog().press_cancel()
	await _close(page, host)


#The benefit dialog behind Adjust: one box for all three bonuses.
static func _case_benefit_dialog(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var box: BenefitDialog = page.benefit_dialog()
	var shaped: bool = true
	var bounded: bool = true
	for name_key: String in BENEFIT_KEYS:
		var def: Dictionary = BenefitsManager.benefit_def(name_key)
		box.open_for(name_key)
		shaped = shaped and box.is_open() and box.key() == name_key
		shaped = shaped and box.text("title") == String(def.get("label", ""))
		shaped = shaped and box.text("desc") == String(def.get("desc", ""))
		bounded = bounded and box.stepper().label == BenefitsManager.step_label(name_key)
		bounded = bounded and box.stepper().min_value == 0
		bounded = bounded and box.stepper().max_value == BenefitsManager.step_max(name_key)
		bounded = bounded and box.stepper().show_glyph == (String(def.get("unit", "")) == "notes")
		box.press_cancel()
	TestFixtures.check(res, "the dialog titles every bonus it opens on", shaped, "titles")
	TestFixtures.check(res, "the stepper takes the label and the bound of that bonus", bounded,
		"bounds")
	box.open_for("profit")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the benefit box holds to its own width with room for its content",
		is_equal_approx(box.box.size.x, BenefitDialog.BOX_WIDTH)
			and box.rows.size.x <= BenefitDialog.BOX_WIDTH - 28.0,
		"box %.1f rows %.1f" % [box.box.size.x, box.rows.size.x])
	TestFixtures.check(res, "the dialog wears the benefits kicker",
		box.text("kicker") == BenefitDialog.KICKER_TEXT, box.text("kicker"))
	TestFixtures.check(res, "the dialog opens on the value the manager holds",
		box.value() == BenefitsManager.benefit("profit"), str(box.value()))
	box.set_value(25)
	var change: Dictionary = BenefitsManager.benefit_change("profit", 25)
	TestFixtures.check(res, "a dialled value previews the change and the old value",
		box.value() == 25 and box.text("sub") == String(change.get("text", ""))
			and box.text("note") == BenefitDialog.WAS_PREFIX
				+ BenefitsManager.benefit_text("profit", 0),
		"sub '%s' note '%s'" % [box.text("sub"), box.text("note")])
	var got: Array = []
	box.confirmed.connect(func(k: String, v: int) -> void: got.append([k, v]))
	box.press_confirm()
	TestFixtures.check(res, "confirm writes the bonus and reports it once",
		BenefitsManager.benefit("profit") == 25 and not box.is_open() and got.size() == 1
			and String(got[0][0]) == "profit" and int(got[0][1]) == 25,
		"benefit %d got %s" % [BenefitsManager.benefit("profit"), str(got)])
	TestFixtures.check(res, "the panel row follows the confirmed bonus",
		page.benefits().row_text(0, "value") == BenefitsManager.benefit_text("profit", 25),
		page.benefits().row_text(0, "value"))
	box.open_for("profit")
	box.set_value(40)
	box.press_cancel()
	TestFixtures.check(res, "cancel leaves the bonus alone",
		BenefitsManager.benefit("profit") == 25 and not box.is_open(),
		str(BenefitsManager.benefit("profit")))
	box.open_for("profit")
	box.set_value(140)
	TestFixtures.check(res, "a percentage clamps to a hundred",
		box.value() == BenefitsManager.PERCENT_MAX, str(box.value()))
	box.set_value(-20)
	TestFixtures.check(res, "a percentage clamps to none", box.value() == 0, str(box.value()))
	box.press_cancel()
	box.open_for("odd")
	box.set_value(5000)
	TestFixtures.check(res, "an odd job bonus in notes has no ceiling", box.value() == 5000,
		str(box.value()))
	box.press_confirm()
	TestFixtures.check(res, "the notes bonus writes as dialled",
		BenefitsManager.benefit("odd") == 5000, str(BenefitsManager.benefit("odd")))
	box.open_for("nope")
	TestFixtures.check(res, "an unknown bonus opens nothing",
		not box.is_open() and box.key() == "",
		"open %s key '%s'" % [box.is_open(), box.key()])
	await _close(page, host)


#The vacation dialog behind Edit: a draft policy the box clamps, then one write.
static func _case_vacation_dialog(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var box: VacationDialog = page.vacation_dialog()
	box.open()
	TestFixtures.check(res, "the dialog opens on a copy of the policy",
		box.is_open() and _same(box.draft().to_dict(), BenefitsManager.policy().to_dict())
			and box.draft() != BenefitsManager.policy(),
		str(box.draft().to_dict()))
	TestFixtures.check(res, "the starting days and the earned days carry the policy caps",
		box.field_max("start") == VacationPolicy.START_MAX
			and box.field_max("add_days") == VacationPolicy.ADD_MAX,
		"start %d add %d" % [box.field_max("start"), box.field_max("add_days")])
	var steppers: Array[PayrollStepper] = [box.start_step, box.add_step, box.every_step,
		box.len_step, box.at_step, box.gap_step]
	var sized_ok: bool = true
	for s: PayrollStepper in steppers:
		if not s.custom_minimum_size.is_equal_approx(s.compact_row.get_combined_minimum_size()):
			sized_ok = false
	TestFixtures.check(res, "every field stepper carries no fixed size override of its own",
		sized_ok, "sized_ok %s" % sized_ok)
	box.set_field("unit", "months")
	TestFixtures.check(res, "the accrual bound follows the unit picked",
		box.field_max("every") == int(VacationPolicy.EVERY_MAX["months"]),
		str(box.field_max("every")))
	box.set_field("unit", "years")
	TestFixtures.check(res, "years bound the accrual lower",
		box.field_max("every") == int(VacationPolicy.EVERY_MAX["years"]),
		str(box.field_max("every")))
	box.set_field("max_unit", "days")
	TestFixtures.check(res, "the length bound follows its own unit",
		box.field_max("max_len") == int(VacationPolicy.LEN_MAX["days"]),
		str(box.field_max("max_len")))
	box.set_field("gap_unit", "weeks")
	TestFixtures.check(res, "the gap bound follows its own unit",
		box.field_max("gap") == int(VacationPolicy.GAP_MAX["weeks"]),
		str(box.field_max("gap")))
	TestFixtures.check(res, "the mercs away at once are bound at fifty",
		box.field_max("max_at") == VacationPolicy.MAX_AT_MAX
			and VacationPolicy.MAX_AT_MAX == 50,
		str(box.field_max("max_at")))
	TestFixtures.check(res, "an unknown field has no bound", box.field_max("nope") == 0,
		str(box.field_max("nope")))
	box.set_field("max_at", 0)
	TestFixtures.check(res, "the dialog keeps one merc away at a time",
		box.draft().max_at == VacationDialog.MAX_AT_MIN, str(box.draft().max_at))
	box.set_field("max_at", 99)
	TestFixtures.check(res, "the dialog clamps the mercs away at once",
		box.draft().max_at == VacationPolicy.MAX_AT_MAX, str(box.draft().max_at))
	box.set_field("add_days", 1)
	TestFixtures.check(res, "one earned day reads in the singular",
		box.word("add_days") == "day", box.word("add_days"))
	box.set_field("add_days", 2)
	TestFixtures.check(res, "two earned days read in the plural",
		box.word("add_days") == "days", box.word("add_days"))
	box.set_field("max_at", 1)
	TestFixtures.check(res, "one merc away reads in the singular",
		box.word("max_at") == "merc", box.word("max_at"))
	box.set_field("max_at", 3)
	TestFixtures.check(res, "three mercs away read in the plural",
		box.word("max_at") == "mercs", box.word("max_at"))
	box.set_field("unit", "years")
	box.set_field("every", 1)
	TestFixtures.check(res, "the accrual unit reads with its own count",
		box.word("unit") == "year", box.word("unit"))
	TestFixtures.check(res, "an unknown word reads empty", box.word("nope") == "",
		box.word("nope"))
	box.set_field("start", 9)
	box.set_field("approval", true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the approval tick is the atlas check at two pixels an art pixel",
		box.check_button.icon != null and not box.check_button.expand_icon
			and box.check_button.icon.get_size() == Vector2(22.0, 20.0),
		"%s" % [box.check_button.icon.get_size() if box.check_button.icon != null
			else Vector2.ZERO])
	box.set_field("approval", false)
	var draft: Dictionary = box.draft().to_dict()
	var got: Array = []
	box.confirmed.connect(func(values: Dictionary) -> void: got.append(values))
	box.press_confirm()
	TestFixtures.check(res, "confirm writes the whole policy and reports it once",
		_same(BenefitsManager.policy().to_dict(), draft) and got.size() == 1
			and not box.is_open(),
		"policy %s" % str(BenefitsManager.policy().to_dict()))
	TestFixtures.check(res, "the panel cells follow the written policy",
		_cell_value(page.benefits(), "Approval") == "Not Required"
			and _cell_value(page.benefits(), "Starting") == VacationPolicy.plural(9, "Day"),
		"approval '%s' start '%s'" % [_cell_value(page.benefits(), "Approval"),
			_cell_value(page.benefits(), "Starting")])
	box.open()
	box.set_field("start", 21)
	box.press_cancel()
	TestFixtures.check(res, "cancel leaves the written policy standing",
		BenefitsManager.policy().start == 9 and not box.is_open(),
		str(BenefitsManager.policy().start))
	await _close(page, host)


#The stepper both looks wear: the bounds, the rejected flash, the hold ramp and the locked look.
static func _case_stepper(res: Dictionary, host: Node) -> void:
	_fresh()
	var step: PayrollStepper = STEP_SCENE.instantiate() as PayrollStepper
	host.add_child(step)
	await host.get_tree().process_frame
	step.min_value = 0
	step.max_value = 10
	step.step = 1
	var seen: Array[int] = []
	step.value_changed.connect(func(v: int) -> void: seen.append(v))
	step.set_value_silent(5)
	TestFixtures.check(res, "a value written by the host raises no signal",
		step.value == 5 and seen.is_empty(), "value %d seen %d" % [step.value, seen.size()])
	step.press_plus()
	step.press_minus()
	TestFixtures.check(res, "a press up and a press down report each new value",
		step.value == 5 and seen.size() == 2 and seen[0] == 6 and seen[1] == 5,
		"value %d seen %s" % [step.value, str(seen)])
	TestFixtures.check(res, "a step inside the bounds never flashes", not step.is_rejecting(),
		"rejecting %s" % step.is_rejecting())
	step.step = 3
	step.press_plus()
	TestFixtures.check(res, "a longer step counts by its own stride", step.value == 8,
		str(step.value))
	step.press_plus()
	TestFixtures.check(res, "a press past the ceiling holds the edge and flashes",
		step.value == 10 and step.is_rejecting() and step.rejected_side() == 1,
		"value %d side %d" % [step.value, step.rejected_side()])
	TestFixtures.check(res, "the flashing stepper leans off centre",
		not is_equal_approx(step.shake_offset(), 0.0), str(step.shake_offset()))
	await host.get_tree().create_timer(REJECT_WAIT).timeout
	TestFixtures.check(res, "the flash clears itself and the box settles back",
		not step.is_rejecting() and is_equal_approx(step.shake_offset(), 0.0)
			and step.rejected_side() == 0,
		"rejecting %s offset %f" % [step.is_rejecting(), step.shake_offset()])
	step.set_value_silent(1)
	step.press_minus()
	TestFixtures.check(res, "a press past the floor holds the floor and flashes",
		step.value == 0 and step.is_rejecting() and step.rejected_side() == -1,
		"value %d side %d" % [step.value, step.rejected_side()])
	step.max_value = PayrollStepper.NO_MAX
	step.set_value_silent(10)
	step.press_plus()
	TestFixtures.check(res, "a stepper with no ceiling counts on", step.value == 13,
		str(step.value))
	step.set_value_silent(9999)
	TestFixtures.check(res, "a stepper with no ceiling takes any value", step.value == 9999,
		str(step.value))
	step.max_value = 10
	TestFixtures.check(res, "a ceiling set under the value pulls the value down at once",
		step.value == 10, str(step.value))
	TestFixtures.check(res, "the tall look shows the display and sizes to its own content",
		not step.compact and step.display.visible and not step.compact_row.visible
			and step.custom_minimum_size == step.display.get_combined_minimum_size(),
		"size %s" % step.custom_minimum_size)
	TestFixtures.check(res, "the tall look reads the value off its notes label",
		step.value_text() == step.value_row.value_text(), step.value_text())
	step.compact = true
	TestFixtures.check(res, "the compact look swaps the row and sizes to its own content",
		step.compact_row.visible and not step.display.visible
			and step.custom_minimum_size == step.compact_row.get_combined_minimum_size(),
		"size %s" % step.custom_minimum_size)
	TestFixtures.check(res, "the compact look reads the value off its own label",
		step.value_text() == step.value_small.text, step.value_text())
	var digit_width: float = PayrollStepper.FONT_BOLD.get_string_size(
		"999", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	TestFixtures.check(res, "the compact value box widens to fit three digits",
		is_equal_approx(step.value_box.custom_minimum_size.x, digit_width + 8.0),
		"%.1f vs %.1f" % [step.value_box.custom_minimum_size.x, digit_width + 8.0])
	var sep: float = step.compact_row.get_theme_constant("separation")
	var expect_total: float = (step.minus_small.get_combined_minimum_size().x + sep
		+ step.value_box.get_combined_minimum_size().x + sep
		+ step.plus_small.get_combined_minimum_size().x)
	TestFixtures.check(res, "the compact row width is the sum of its three parts",
		is_equal_approx(step.compact_row.get_combined_minimum_size().x, expect_total),
		"%.1f vs %.1f" % [step.compact_row.get_combined_minimum_size().x, expect_total])
	step.compact = false
	step.size = Vector2(320.0, PayrollStepper.DISPLAY_HEIGHT)
	var held: int = step.value
	step.disabled = true
	step.disabled_text = BenefitsManager.LOCK_TEXT
	step.press_plus()
	step.press_minus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a locked stepper takes no press", step.value == held,
		"value %d was %d" % [step.value, held])
	TestFixtures.check(res, "a locked stepper dims, keeps the mouse on itself and says why",
		is_equal_approx(step.modulate.a, PayrollStepper.DISABLED_ALPHA)
			and step.mouse_filter == Control.MOUSE_FILTER_STOP
			and step.tooltip_text == BenefitsManager.LOCK_TEXT,
		"alpha %f filter %d tip '%s'" % [step.modulate.a, step.mouse_filter, step.tooltip_text])
	TestFixtures.check(res, "a locked stepper takes its four buttons out of the hover",
		step.minus_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and step.plus_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and step.minus_small.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and step.plus_small.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and step.minus_button.disabled and step.plus_button.disabled,
		"minus %d plus %d" % [step.minus_button.mouse_filter, step.plus_button.mouse_filter])
	TestFixtures.check(res, "a hover over a locked tall stepper lands on the reason",
		_hover_at(step, step.minus_button) == step and _hover_at(step, step.plus_button) == step
			and _hover_at(step, step.middle) == step
			and step.tooltip_text == BenefitsManager.LOCK_TEXT,
		"minus %s plus %s middle %s" % [str(_hover_at(step, step.minus_button)),
			str(_hover_at(step, step.plus_button)), str(_hover_at(step, step.middle))])
	step.compact = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hover over a locked compact stepper lands on the reason",
		_hover_at(step, step.minus_small) == step and _hover_at(step, step.plus_small) == step
			and _hover_at(step, step.value_box) == step and step.value == held,
		"minus %s box %s" % [str(_hover_at(step, step.minus_small)),
			str(_hover_at(step, step.value_box))])
	step.disabled = false
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unlocked compact stepper hands the hover to its own buttons",
		_hover_at(step, step.plus_small) == step.plus_small
			and _hover_at(step, step.minus_small) == step.minus_small
			and step.plus_small.mouse_filter == Control.MOUSE_FILTER_STOP
			and step.tooltip_text == "",
		"plus %s filter %d" % [str(_hover_at(step, step.plus_small)), step.plus_small.mouse_filter])
	step.compact = false
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unlocked stepper drops the reason and takes the mouse again",
		step.tooltip_text == "" and step.mouse_filter == Control.MOUSE_FILTER_PASS
			and is_equal_approx(step.modulate.a, 1.0),
		"tip '%s' filter %d" % [step.tooltip_text, step.mouse_filter])
	TestFixtures.check(res, "an unlocked tall stepper hands the hover to the plus button",
		_hover_at(step, step.plus_button) == step.plus_button
			and step.plus_button.mouse_filter == Control.MOUSE_FILTER_STOP
			and step.minus_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"plus %s filter %d" % [str(_hover_at(step, step.plus_button)),
			step.plus_button.mouse_filter])
	TestFixtures.check(res, "a held button waits out the delay before it repeats",
		is_equal_approx(PayrollLogic.hold_rate(0.2), 0.0)
			and is_equal_approx(PayrollLogic.hold_rate(PayrollLogic.HOLD_DELAY_SECONDS),
				PayrollLogic.HOLD_RATE_BASE),
		"%f then %f" % [PayrollLogic.hold_rate(0.2),
			PayrollLogic.hold_rate(PayrollLogic.HOLD_DELAY_SECONDS)])
	TestFixtures.check(res, "the repeat ramps up the longer the button is held",
		is_equal_approx(PayrollLogic.hold_rate(1.0), PayrollLogic.HOLD_RATE_BASE
			+ (1.0 - PayrollLogic.HOLD_DELAY_SECONDS) * PayrollLogic.HOLD_RATE_RAMP),
		str(PayrollLogic.hold_rate(1.0)))
	TestFixtures.check(res, "the repeat stops rising at its ceiling",
		is_equal_approx(PayrollLogic.hold_rate(3.0), PayrollLogic.HOLD_RATE_MAX),
		str(PayrollLogic.hold_rate(3.0)))
	step.queue_free()
	await host.get_tree().process_frame


#Firing from the page: the wage box, the fire confirm over it and what the list does after.
static func _case_fire(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var uid: int = page.row_uid(0)
	page.press_row(0)
	var dialog: SalaryDialog = page.salary_dialog()
	var fires: Array = []
	dialog.fired.connect(func(u: int) -> void: fires.append(u))
	dialog.press_fire()
	var fire_box: FireConfirmDialog = dialog.fire_dialog()
	TestFixtures.check(res, "the Fire link opens the confirm over the wage box",
		fire_box.is_open() and fire_box.uid() == uid and dialog.visible,
		"open %s uid %d" % [fire_box.is_open(), fire_box.uid()])
	TestFixtures.check(res, "the confirm names the merc under the fire kicker",
		fire_box.text("kicker") == FireConfirmDialog.KICKER_TEXT
			and fire_box.text("name") == page.row_text(0, "name")
			and fire_box.text("employed") == BenefitsManager.employed_text(uid),
		"'%s' '%s'" % [fire_box.text("kicker"), fire_box.text("name")])
	TestFixtures.check(res, "the confirm lists what the guild would lose",
		fire_box.note_count() > 0 and fire_box.note_text(0) != ""
			and fire_box.text("body") == FireConfirmDialog.BODY_TEXT,
		"notes %d first '%s'" % [fire_box.note_count(), fire_box.note_text(0)])
	fire_box.press_cancel()
	TestFixtures.check(res, "cancelling the confirm leaves the merc employed",
		not fire_box.is_open() and dialog.visible and not BenefitsManager.is_fired(uid),
		"open %s fired %s" % [fire_box.is_open(), BenefitsManager.is_fired(uid)])
	var opinion: int = BenefitsManager.opinion_of(uid)
	var want: int = maxi(SalarySystem.OPINION_MIN, opinion - PayrollLogic.fire_drop(opinion))
	dialog.press_fire()
	fire_box.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "confirming the fire marks the merc and drops the opinion",
		fires.size() == 1 and int(fires[0]) == uid and BenefitsManager.is_fired(uid)
			and _left_opinion(uid) == want and not dialog.visible,
		"fires %s opinion %d wanted %d" % [str(fires), _left_opinion(uid), want])
	TestFixtures.check(res, "the fired merc leaves the default list",
		_index_of(page, uid) < 0, "at %d" % _index_of(page, uid))
	page.set_status_shown(GuiTypes.MercStatus.FIRED, true)
	var at: int = _index_of(page, uid)
	TestFixtures.check(res, "the fired row stays away with that filter row on",
		at < 0 and GameState.merc_by_uid(uid) == null
			and GameState.removed_by_uid(uid) != null,
		"at %d removed %d" % [at, GameState.removed_count()])
	TestFixtures.check(res, "the wage bill no longer pays the fired merc",
		page.stat_text("payroll") == str(BenefitsManager.payroll_total()),
		page.stat_text("payroll"))
	page.press_row(at)
	TestFixtures.check(res, "a fired merc has no row to press, so the page opens nothing",
		not dialog.visible and not fire_box.is_open(),
		"wage %s fire %s" % [dialog.visible, fire_box.is_open()])
	await _close(page, host)


#Where the two full frame dialogs hang: the modal layer of the shell when there is one, the page
#itself when the page runs alone, and nothing left behind when the page goes.
static func _case_host(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var box: BenefitDialog = page.benefit_dialog()
	var vac: VacationDialog = page.vacation_dialog()
	TestFixtures.check(res, "a page on its own hosts its own dialogs",
		page.modal_host() == page and box.get_parent() == page and vac.get_parent() == page,
		"host %s" % page.modal_host())
	TestFixtures.check(res, "both dialogs cover the frame they hang in",
		is_equal_approx(box.anchor_right, 1.0) and is_equal_approx(box.anchor_bottom, 1.0)
			and is_equal_approx(vac.anchor_right, 1.0),
		"right %f bottom %f" % [box.anchor_right, box.anchor_bottom])
	page.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a page that leaves takes its dialogs with it",
		not is_instance_valid(box) and not is_instance_valid(vac),
		"benefit %s vacation %s" % [is_instance_valid(box), is_instance_valid(vac)])
	var shell: Control = Control.new()
	shell.add_to_group(PayrollTab.HOST_GROUP)
	var layer: Control = Control.new()
	layer.name = PayrollTab.HOST_CHILD
	shell.add_child(layer)
	host.add_child(shell)
	var inner: PayrollTab = PAGE_SCENE.instantiate() as PayrollTab
	shell.add_child(inner)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a page inside a shell hangs its dialogs from the modal layer",
		inner.modal_host() == layer and inner.benefit_dialog().get_parent() == layer
			and inner.vacation_dialog().get_parent() == layer,
		"host %s" % inner.modal_host())
	inner.benefits().press_adjust("odd")
	TestFixtures.check(res, "a dialog in the modal layer still opens from the panel",
		inner.benefit_dialog().is_open() and inner.benefit_dialog().key() == "odd",
		"open %s key '%s'" % [inner.benefit_dialog().is_open(), inner.benefit_dialog().key()])
	inner.benefit_dialog().press_cancel()
	shell.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	GuiFrameStack.clear()


#A page that changed while it was hidden catches up when the shell opens the tab again.
static func _case_hidden(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var total: int = page.row_count()
	page.visible = false
	BenefitsManager.set_benefit("profit", 15)
	TestFixtures.check(res, "a hidden page does not redraw on a change",
		page.benefits().row_text(0, "value") == BenefitsManager.benefit_text("profit", 0),
		page.benefits().row_text(0, "value"))
	var uid: int = page.row_uid(0)
	var gone: bool = BenefitsManager.fire(uid)
	TestFixtures.check(res, "a hidden page keeps the rows it drew",
		gone and page.row_count() == total and _index_of(page, uid) >= 0,
		"rows %d of %d" % [page.row_count(), total])
	page.visible = true
	page.page_shown()
	TestFixtures.check(res, "the tab opening catches the page up",
		page.benefits().row_text(0, "value") == BenefitsManager.benefit_text("profit", 15)
			and page.row_count() == total - 1 and _index_of(page, uid) < 0,
		"'%s' rows %d" % [page.benefits().row_text(0, "value"), page.row_count()])
	page.page_shown()
	TestFixtures.check(res, "a page already caught up stays as it is",
		page.row_count() == total - 1, str(page.row_count()))
	var before: int = page.row_count()
	BenefitsManager.set_benefit("contract", 20)
	TestFixtures.check(res, "a visible page redraws at once",
		page.benefits().row_text(1, "value") == BenefitsManager.benefit_text("contract", 20)
			and page.row_count() == before,
		page.benefits().row_text(1, "value"))
	await _close(page, host)
#Every popup keeps its box in the band above the bottom bar, at the width the page draws.
static func _case_band(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var was: float = GuiFrameStack.bottom_reserve
	GuiFrameStack.bottom_reserve = BAR_RESERVE
	var band: float = GuiFrameStack.band_height(host.get_viewport().get_visible_rect().size.y)
	var uid: int = _uid(0)
	_contract(uid, true)
	var salary: SalaryDialog = page.salary_dialog()
	salary.open_for_uid(uid)
	TestFixtures.check(res, "the wage box on a locked merc stays in the band above the bar",
		salary.is_locked() and _fits(salary.box, band),
		"locked %s rect %s band %.1f" % [salary.is_locked(), str(salary.box.get_global_rect()), band])
	TestFixtures.check(res, "the wage box keeps the width the page draws",
		is_equal_approx(salary.box.size.x, SalaryDialog.BOX_WIDTH),
		"width %.1f wanted %.1f" % [salary.box.size.x, SalaryDialog.BOX_WIDTH])
	salary.press_cancel()
	_contract(uid, false)
	salary.open_for_uid(uid)
	salary.press_fire()
	var fire: FireConfirmDialog = salary.fire_dialog()
	TestFixtures.check(res, "the fire box stays in the band above the bar",
		fire.is_open() and _fits(fire.box, band),
		"open %s rect %s band %.1f" % [fire.is_open(), str(fire.box.get_global_rect()), band])
	fire.press_cancel()
	salary.press_cancel()
	var bonus: BenefitDialog = page.benefit_dialog()
	bonus.open_for("profit")
	TestFixtures.check(res, "the bonus box stays in the band above the bar",
		bonus.is_open() and _fits(bonus.box, band),
		"open %s rect %s band %.1f" % [bonus.is_open(), str(bonus.box.get_global_rect()), band])
	bonus.press_cancel()
	var holiday: VacationDialog = page.vacation_dialog()
	holiday.open()
	TestFixtures.check(res, "the vacation box stays in the band above the bar",
		holiday.is_open() and _fits(holiday.box, band),
		"open %s rect %s band %.1f" % [holiday.is_open(), str(holiday.box.get_global_rect()), band])
	holiday.press_cancel()
	GuiFrameStack.bottom_reserve = was
	await _close(page, host)


#A box fits when its bottom edge stops at or above the band the bottom bar leaves.
static func _fits(node: Control, band: float) -> bool:
	return node.get_global_rect().end.y <= band + 0.5


static func _esc() -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = KEY_ESCAPE
	k.pressed = true
	return k


#The two full frame dialogs: top_level after fit, push on open and answer Esc only while they
#are the top frame; a frame pushed above them absorbs the key instead.
static func _case_modal_escape(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var box: BenefitDialog = page.benefit_dialog()
	var vac: VacationDialog = page.vacation_dialog()
	var blocker := Control.new()
	blocker.top_level = true
	host.add_child(blocker)
	box.open_for("profit")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the benefit dialog goes top_level and pushes itself on open",
		box.top_level and GuiFrameStack.top() == box,
		"top_level %s top %s" % [box.top_level, str(GuiFrameStack.top())])
	GuiFrameStack.push(blocker)
	host.get_viewport().push_input(_esc())
	await host.get_tree().process_frame
	TestFixtures.check(res, "a frame above the benefit dialog keeps Esc from closing it",
		box.is_open(), "open %s" % box.is_open())
	GuiFrameStack.remove(blocker)
	host.get_viewport().push_input(_esc())
	await host.get_tree().process_frame
	TestFixtures.check(res, "the benefit dialog closes alone on Esc once it is the top frame",
		not box.is_open() and GuiFrameStack.top() != box,
		"open %s top %s" % [box.is_open(), str(GuiFrameStack.top())])
	vac.open()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the vacation dialog goes top_level and pushes itself on open",
		vac.top_level and GuiFrameStack.top() == vac,
		"top_level %s top %s" % [vac.top_level, str(GuiFrameStack.top())])
	GuiFrameStack.push(blocker)
	host.get_viewport().push_input(_esc())
	await host.get_tree().process_frame
	TestFixtures.check(res, "a frame above the vacation dialog keeps Esc from closing it",
		vac.is_open(), "open %s" % vac.is_open())
	GuiFrameStack.remove(blocker)
	host.get_viewport().push_input(_esc())
	await host.get_tree().process_frame
	TestFixtures.check(res, "the vacation dialog closes alone on Esc once it is the top frame",
		not vac.is_open() and GuiFrameStack.top() != vac,
		"open %s top %s" % [vac.is_open(), str(GuiFrameStack.top())])
	blocker.queue_free()
	await _close(page, host)


#Every owned, text labelled action button is a BevelButton; the stepper's plus and minus, the
#vacation approval toggle, the list rows and the two dialog closes are excluded by design and
#carry no BevelButton script.
static func _case_bevel_buttons(res: Dictionary, host: Node) -> void:
	var page: PayrollTab = await _open(host)
	var box: BenefitDialog = page.benefit_dialog()
	var vac: VacationDialog = page.vacation_dialog()
	var buttons: Array[Button] = [box.cancel_button, box.confirm_button,
		vac.cancel_button, vac.confirm_button, page.benefits().edit_button]
	for row: Node in page.benefits().bonus_list.get_children():
		var brow: BenefitRow = row as BenefitRow
		if brow != null:
			buttons.append(brow.adjust_button)
	page.press_row(0)
	var salary: SalaryDialog = page.salary_dialog()
	salary.press_fire()
	var fire: FireConfirmDialog = salary.fire_dialog()
	buttons.append(fire.cancel_button)
	buttons.append(fire.confirm_button)
	var all_bevel: bool = true
	var bad: String = ""
	for btn: Button in buttons:
		if not (btn.get_script() is GDScript) or String((btn.get_script() as GDScript).resource_path) \
				!= "res://Scripts/GUI/Shared/BevelButton.gd":
			all_bevel = false
			bad = btn.name if bad == "" else bad
	TestFixtures.check(res, "every owned action button carries the BevelButton script",
		all_bevel, "first offender: %s" % bad)
	TestFixtures.check(res, "both dialog closes carry the shared close art and no letter",
		box.close_button.text == "" and vac.close_button.text == ""
			and box.close_button.icon == CloseX.icon(CloseX.SCALE_WINDOW)
			and vac.close_button.icon == CloseX.icon(CloseX.SCALE_WINDOW)
			and box.close_button.custom_minimum_size == Vector2(36.0, 36.0)
			and vac.close_button.custom_minimum_size == Vector2(36.0, 36.0),
		"%s / %s" % [box.close_button.text, vac.close_button.text])
	TestFixtures.check(res, "the fire confirm plate holds the 64 px sigil",
		is_equal_approx(FireConfirmDialog.PLATE, 70.0) and fire.sigil.pixel_scale == 4
			and fire.face.pixel_scale == 4,
		"%s at %d" % [FireConfirmDialog.PLATE, fire.sigil.pixel_scale])
	fire.press_cancel()
	salary.press_cancel()
	await _close(page, host)

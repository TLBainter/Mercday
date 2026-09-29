class_name GuiLoanViewTests

#The Loans page of the Finance viewer: the rows the page draws, the cards, the toolbar, the filter
#popup, the request window and the two offer dialogs. Headless, so nothing is clicked: every press
#goes through the public helper the button of that control calls.

const MONEY: int = 1000
const RICH: int = 9000
const OFFER_1: int = 101
const OFFER_2: int = 102
const OFFER_3: int = 103
const OFFER_4: int = 104
const LOAN_1: int = 1
const LOAN_2: int = 2
const CLOSED_1: int = 201
const CLOSED_2: int = 202


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_style(res)
	_case_rows_offer(res)
	_case_rows_request(res)
	_case_rows_active(res)
	_case_rows_closed(res)
	_case_rows_expired(res)
	_case_caps(res)
	_case_filters(res)
	_case_sort(res)
	_case_change(res)
	await _case_card_offer(res, host)
	await _case_card_expired(res, host)
	await _case_card_request(res, host)
	await _case_card_active(res, host)
	await _case_card_closed(res, host)
	await _case_strip(res, host)
	await _case_popup(res, host)
	await _case_shell(res, host)
	await _case_offer_dialog(res, host)
	await _case_accept_confirm(res, host)
	await _case_tab_views(res, host)
	await _case_tab_sort(res, host)
	await _case_tab_filter(res, host)
	await _case_tab_request(res, host)
	await _case_tab_offer(res, host)
	await _case_tab_expired(res, host)
	await _case_tab_payoff(res, host)
	await _case_tab_unknown_offer(res, host)
	await _case_tab_modal_exit(res, host)
	await _case_tab_push(res, host)
	await _case_tab_crew(res, host)
	await _case_tab_pay_cap(res, host)
	await _case_odd_job_buttons(res, host)
	await _case_tab_freed_host(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	FinanceManager.reset()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI LOANVIEW")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	_set_money(MONEY)
	NotificationCenter.reset()
	FinanceManager.reset()


static func _set_money(amount: int) -> void:
	if GameState.bank_notes > amount:
		GameState.spend(GameState.bank_notes - amount)
	elif GameState.bank_notes < amount:
		GameState.refund(amount - GameState.bank_notes)


static func _uids(count: int) -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in GameState.mercs:
		if out.size() >= count:
			break
		out.append(merc.merc_uid)
	return out


static func _spawn(host: Node, path: String) -> Node:
	var scene: PackedScene = load(path) as PackedScene
	var node: Node = scene.instantiate()
	host.add_child(node)
	return node


static func _frames(host: Node, count: int) -> void:
	for _i: int in count:
		await host.get_tree().process_frame


static func _drop(host: Node, node: Node) -> void:
	node.queue_free()
	await host.get_tree().process_frame


static func _rows_of(view: StringName, show_requests: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(LoanRows.sets(show_requests, true).get(view, []) as Array)
	return out


static func _row_for(view: StringName, id: int) -> Dictionary:
	for row: Dictionary in _rows_of(view, true):
		if int(row["id"]) == id:
			return row
	return {}


static func _ids(rows: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for row: Dictionary in rows:
		out.append(int(row["id"]))
	return out


static func _snap() -> Dictionary:
	return {"lender": "Lender 1", "amount": 1500, "rate": 0.08, "term": 6, "first_due": 2,
		"monthly": 270, "interest": 120, "odds": 71, "team": [], "per": 0, "total": 0,
		"away_hours": 124, "away": "Offer expected in 5 Days, 4 Hours"}


#Case 1: the shared style of the page and the glyphs it draws itself.
static func _case_style(res: Dictionary) -> void:
	var button: Button = LoanStyle.button("Pay Off", LoanStyle.GREEN, LoanStyle.INK, 38.0)
	TestFixtures.check(res, "a page button takes the height it is asked for",
		is_equal_approx(button.custom_minimum_size.y, 38.0) and button.text == "Pay Off",
		"%s at %f" % [button.text, button.custom_minimum_size.y])
	var notes: NotesLabel = LoanStyle.notes(1500, LoanStyle.CREAM, 13)
	TestFixtures.check(res, "a notes label prints the amount with its separator",
		notes.value_text() == NotesLabel.format_amount(1500), notes.value_text())
	var ring: StyleBoxFlat = LoanStyle.window_style(LoanStyle.YELLOW)
	TestFixtures.check(res, "a window frame takes the ring colour of its window",
		ring.border_color == LoanStyle.YELLOW and ring.border_width_left == 4,
		"%s at %d" % [ring.border_color, ring.border_width_left])
	var cell: PanelContainer = LoanStyle.stat_cell("Monthly Payment", notes)
	TestFixtures.check(res, "a stat cell holds its caption over its value",
		cell.get_child_count() == 1 and (cell.get_child(0) as VBoxContainer).get_child_count() == 2,
		"%d children" % cell.get_child_count())
	var arrow: ImageTexture = LoanGlyphs.arrow(&"up", LoanStyle.GREEN)
	TestFixtures.check(res, "a change arrow is a seven pixel glyph",
		arrow != null and arrow.get_width() == 7 and arrow.get_height() == 7,
		"%s" % [arrow.get_size() if arrow != null else Vector2.ZERO])
	TestFixtures.check(res, "each of the four arrow directions draws",
		LoanGlyphs.arrow(&"down", LoanStyle.RED) != null
		and LoanGlyphs.arrow(&"diag_up", LoanStyle.SKY) != null
		and LoanGlyphs.arrow(&"diag_down", LoanStyle.SKY) != null, "four arrows")
	var portrait: Control = LoanGlyphs.portrait(40.0)
	TestFixtures.check(res, "a lender portrait is square and takes the side it is given",
		portrait != null and is_equal_approx(portrait.custom_minimum_size.x, 40.0)
		and is_equal_approx(portrait.custom_minimum_size.y, 40.0),
		"%s" % [portrait.custom_minimum_size if portrait != null else Vector2.ZERO])


#Case 2: one offer as the list reads it.
static func _case_rows_offer(res: Dictionary) -> void:
	_fresh()
	var pending: Array[Dictionary] = _rows_of(LoanRows.VIEW_PENDING, true)
	TestFixtures.check(res, "the pending view holds one row per open offer",
		pending.size() == 4, "%d rows" % pending.size())
	var row: Dictionary = _row_for(LoanRows.VIEW_PENDING, OFFER_1)
	TestFixtures.check(res, "an offer row is marked as an offer",
		StringName(row["kind"]) == LoanRows.KIND_OFFER, "%s" % [row.get("kind", "")])
	TestFixtures.check(res, "an offer row carries the offered amount, not the asked one",
		int(row["amount"]) == 1500, "%d notes" % int(row["amount"]))
	TestFixtures.check(res, "the monthly payment of the offer is priced from the offered terms",
		int(row["monthly"]) == 270, "%d a month" % int(row["monthly"]))
	var text: Dictionary = row["text"] as Dictionary
	TestFixtures.check(res, "the header of the row reads the lender and the terms",
		String(text["lender"]) == "Lender 1" and String(text["terms"]) == "at 8% - 6 months",
		"%s %s" % [text["lender"], text["terms"]])
	TestFixtures.check(res, "the first payment cell counts in months",
		String(text["first_due"]) == "2 Months", String(text["first_due"]))
	TestFixtures.check(res, "the deadline cell counts the days and hours left",
		String(text["deadline"]) == "3 Days, 18 Hours", String(text["deadline"]))
	TestFixtures.check(res, "the right of an offer row asks for a review",
		String(text["right"]) == LoanRows.REVIEW_TEXT, String(text["right"]))
	TestFixtures.check(res, "an offer nobody has answered is unread",
		bool(row["unread"]), "%s" % [row["unread"]])
	var metrics: Dictionary = row["metrics"] as Dictionary
	TestFixtures.check(res, "the metrics of an offer price every payment of the term",
		int(metrics["remaining"]) == 1620 and int(metrics["rate"]) == 8
		and int(metrics["duration"]) == 6, "%s" % [metrics])


#Case 3: a request an envoy is still carrying.
static func _case_rows_request(res: Dictionary) -> void:
	_fresh()
	var team: Array[int] = _uids(1)
	var calc: Dictionary = FinanceManager.request_calc("Lender 5",
		FinanceManager.fair_draft("Lender 5"), team)
	var sent: bool = FinanceManager.request_loan({"lender": "Lender 5",
		"amount": int(calc["amount"]), "rate": float(calc["rate"]), "term": int(calc["months"]),
		"first_due": int(calc["first_due"]), "team": team, "odds": int(calc["odds"]), "per": 25})
	TestFixtures.check(res, "a request the envoys carry joins the pending view",
		sent and _rows_of(LoanRows.VIEW_PENDING, true).size() == 5,
		"%d rows" % _rows_of(LoanRows.VIEW_PENDING, true).size())
	TestFixtures.check(res, "hiding the requests leaves the offers alone",
		_rows_of(LoanRows.VIEW_PENDING, false).size() == 4,
		"%d rows" % _rows_of(LoanRows.VIEW_PENDING, false).size())
	var row: Dictionary = {}
	for item: Dictionary in _rows_of(LoanRows.VIEW_PENDING, true):
		if StringName(item["kind"]) == LoanRows.KIND_REQUEST:
			row = item
			break
	var text: Dictionary = row["text"] as Dictionary
	TestFixtures.check(res, "a request row prints the approval odds it was sent with",
		String(text["odds"]) == "%d%%" % int(calc["odds"]), String(text["odds"]))
	TestFixtures.check(res, "a request row names the envoy that carries it",
		(row["team_rows"] as Array).size() == 1 and String(text["team"]) != LoanRows.NO_TEAM_TEXT,
		String(text["team"]))
	TestFixtures.check(res, "a request row waits instead of offering a button",
		String(text["right"]) == LoanRows.AWAITING_TEXT and String(text["note"]) == "",
		String(text["right"]))
	TestFixtures.check(res, "a request with no envoy says so",
		String((LoanRows.request_row({"id": 9, "lender": "Lender 7", "amount": 500,
		"rate": 0.11, "term": 6, "first_due": 2, "team": [], "odds": 20})["text"]
		as Dictionary)["team"]) == LoanRows.NO_TEAM_TEXT, "no envoy")


#Case 4: a loan the guild is paying off.
static func _case_rows_active(res: Dictionary) -> void:
	_fresh()
	var rows: Array[Dictionary] = _rows_of(LoanRows.VIEW_ACTIVE, true)
	TestFixtures.check(res, "the active view holds one row per running loan",
		rows.size() == 2, "%d rows" % rows.size())
	var row: Dictionary = _row_for(LoanRows.VIEW_ACTIVE, LOAN_1)
	TestFixtures.check(res, "an active row is marked as active and prices its month",
		StringName(row["kind"]) == LoanRows.KIND_ACTIVE and int(row["monthly"]) == 180,
		"%d a month" % int(row["monthly"]))
	TestFixtures.check(res, "an active row counts what is left over the months left",
		int(row["remaining"]) == 1440, "%d left" % int(row["remaining"]))
	TestFixtures.check(res, "an active row prices the payoff of today",
		int(row["payoff"]) == 1334, "%d to close" % int(row["payoff"]))
	TestFixtures.check(res, "a payoff over the bank cannot be paid",
		not bool(row["can_pay"]), "%d notes" % GameState.bank_notes)
	var text: Dictionary = row["text"] as Dictionary
	TestFixtures.check(res, "an active row counts the payments made",
		String(text["progress"]) == "4 / 12 paid", String(text["progress"]))
	TestFixtures.check(res, "an active row names the day the next payment lands",
		String(text["due"]) != "" and String(text["due_rel"]) != "",
		"%s %s" % [text["due"], text["due_rel"]])
	TestFixtures.check(res, "the note under the button prices closing the loan",
		String(text["note"]) == "%s %s" % [NotesLabel.format_amount(1334), LoanRows.CLOSE_NOTE],
		String(text["note"]))
	var second: Dictionary = _row_for(LoanRows.VIEW_ACTIVE, LOAN_2)
	TestFixtures.check(res, "a payoff the bank covers can be paid",
		int(second["payoff"]) == 667 and bool(second["can_pay"]),
		"%d to close" % int(second["payoff"]))


#Case 5: a loan that is over.
static func _case_rows_closed(res: Dictionary) -> void:
	_fresh()
	var rows: Array[Dictionary] = _rows_of(LoanRows.VIEW_CLOSED, true)
	TestFixtures.check(res, "the closed view holds one row per loan that ended",
		rows.size() == 2, "%d rows" % rows.size())
	var row: Dictionary = _row_for(LoanRows.VIEW_CLOSED, CLOSED_1)
	var text: Dictionary = row["text"] as Dictionary
	TestFixtures.check(res, "a closed row counts everything the guild paid",
		int(row["total_paid"]) == 672 and int(row["interest"]) == 72,
		"%d paid, %d interest" % [int(row["total_paid"]), int(row["interest"])])
	TestFixtures.check(res, "a loan paid to the end counts every payment",
		String(text["progress"]) == "6 / 6 paid", String(text["progress"]))
	TestFixtures.check(res, "a closed row names how it ended and offers no button",
		String(text["closed_as"]) == "Paid in Full" and String(text["right"]) == "",
		String(text["closed_as"]))
	var early: Dictionary = _row_for(LoanRows.VIEW_CLOSED, CLOSED_2)
	TestFixtures.check(res, "a loan closed early counts its payments and the payoff",
		String((early["text"] as Dictionary)["progress"]) == "7 payments + payoff",
		String((early["text"] as Dictionary)["progress"]))


#Case 5b: an offer that has expired, as the row and the two-pass sort read it.
static func _case_rows_expired(res: Dictionary) -> void:
	_fresh()
	var row_103: Dictionary = FinanceManager.offer(OFFER_3)
	CampaignClock.advance_to(int(row_103["expires_minute"]) + 1)
	FinanceManager.tick(CampaignClock.now())
	var row: Dictionary = _row_for(LoanRows.VIEW_PENDING, OFFER_3)
	TestFixtures.check(res, "an expired offer row is marked expired",
		bool(row["expired"]), "%s" % [row.get("expired", false)])
	var text: Dictionary = row["text"] as Dictionary
	TestFixtures.check(res, "an expired row reads Expired, Dismiss and its own note",
		String(text["deadline"]) == "Expired" and String(text["right"]) == "Dismiss"
		and String(text["note"]) == "Offer expired", "%s" % [text])
	TestFixtures.check(res, "an expired row is never unread",
		not bool(row["unread"]), "%s" % [row["unread"]])
	var pending: Array[Dictionary] = _rows_of(LoanRows.VIEW_PENDING, true)
	var caps: Dictionary = LoanRows.caps(pending)
	var down: Array[Dictionary] = LoanRows.apply(pending, {}, caps, "monthly", true)
	TestFixtures.check(res, "the expired offer sorts after every live offer, sorted down",
		int(down[3]["id"]) == OFFER_3 and not bool(down[0]["expired"])
		and not bool(down[1]["expired"]) and not bool(down[2]["expired"]),
		"%s" % [_ids(down)])
	var up: Array[Dictionary] = LoanRows.apply(pending, {}, caps, "monthly", false)
	TestFixtures.check(res, "the expired offer still sorts last with the direction reversed",
		int(up[3]["id"]) == OFFER_3 and not bool(up[0]["expired"])
		and not bool(up[1]["expired"]) and not bool(up[2]["expired"]),
		"%s" % [_ids(up)])


#Case 6: the caps the filters take from the view they are shown over.
static func _case_caps(res: Dictionary) -> void:
	_fresh()
	var caps: Dictionary = LoanRows.caps(_rows_of(LoanRows.VIEW_PENDING, true))
	TestFixtures.check(res, "a cap is the highest value of the view rounded up to the step",
		is_equal_approx(float(caps["monthly"]), 310.0)
		and is_equal_approx(float(caps["remaining"]), 3650.0),
		"%f monthly, %f remaining" % [caps["monthly"], caps["remaining"]])
	TestFixtures.check(res, "the interest cap counts in whole percent",
		is_equal_approx(float(caps["rate"]), 29.0), "%f" % caps["rate"])
	TestFixtures.check(res, "a metric no row carries still leaves one step of room",
		is_equal_approx(float(caps["paid"]), 1.0), "%f" % caps["paid"])
	var active: Dictionary = LoanRows.caps(_rows_of(LoanRows.VIEW_ACTIVE, true))
	TestFixtures.check(res, "the active view caps on its own rows",
		is_equal_approx(float(active["monthly"]), 180.0)
		and is_equal_approx(float(active["paid"]), 4.0),
		"%f monthly, %f paid" % [active["monthly"], active["paid"]])
	var span: Vector2 = LoanRows.range_of("monthly", {}, active)
	TestFixtures.check(res, "an unset range is the whole span of its cap",
		is_equal_approx(span.x, 0.0) and is_equal_approx(span.y, 180.0), "%s" % [span])
	var clamped: Vector2 = LoanRows.range_of("monthly", {"monthly": Vector2(50.0, 500.0)}, active)
	TestFixtures.check(res, "a range wider than the cap is clamped into it",
		is_equal_approx(clamped.x, 50.0) and is_equal_approx(clamped.y, 180.0), "%s" % [clamped])


#Case 7: what the filters keep and what the sort does with it.
static func _case_filters(res: Dictionary) -> void:
	_fresh()
	var base: Array[Dictionary] = _rows_of(LoanRows.VIEW_PENDING, true)
	var caps: Dictionary = LoanRows.caps(base)
	var narrow: Dictionary = {"monthly": Vector2(0.0, 200.0)}
	var kept: Array[Dictionary] = LoanRows.apply(base, narrow, caps, "monthly", true)
	TestFixtures.check(res, "a monthly range drops every row that costs more",
		kept.size() == 1 and int(kept[0]["id"]) == OFFER_4, "%d rows" % kept.size())
	TestFixtures.check(res, "a row inside every range passes",
		LoanRows.passes(base[0], {}, caps), "%s" % [base[0]["id"]])
	TestFixtures.check(res, "a range that meets nothing empties the list",
		LoanRows.apply(base, {"paid": Vector2(1.0, 1.0)}, caps, "monthly", true).is_empty(),
		"no offer has a payment behind it")
	TestFixtures.check(res, "no range and every request and expired offer shown is no filter at all",
		not LoanRows.filters_active(true, true, {}, caps), "unfiltered")
	TestFixtures.check(res, "a narrowed range counts as a filter",
		LoanRows.filters_active(true, true, narrow, caps), "narrowed")
	TestFixtures.check(res, "hiding the requests counts as a filter",
		LoanRows.filters_active(false, true, {}, caps), "requests hidden")
	TestFixtures.check(res, "hiding expired offers counts as a filter",
		LoanRows.filters_active(true, false, {}, caps), "expired hidden")
	TestFixtures.check(res, "a notes filter prints its bound as notes",
		LoanRows.value_text("monthly", 1500.0) == NotesLabel.format_amount(1500),
		LoanRows.value_text("monthly", 1500.0))
	TestFixtures.check(res, "an interest filter prints whole percent and a count prints plain",
		LoanRows.value_text("rate", 12.0) == "12%" and LoanRows.value_text("paid", 4.0) == "4",
		"%s %s" % [LoanRows.value_text("rate", 12.0), LoanRows.value_text("paid", 4.0)])
	TestFixtures.check(res, "a range reads low to high",
		LoanRows.range_text("rate", 0.0, 29.0) == "0% - 29%",
		LoanRows.range_text("rate", 0.0, 29.0))
	TestFixtures.check(res, "an empty view says the view is empty, a filtered one says so",
		LoanRows.empty_text(LoanRows.VIEW_CLOSED, 0) == "No closed loans."
		and LoanRows.empty_text(LoanRows.VIEW_CLOSED, 3) == LoanRows.EMPTY_FILTERED,
		LoanRows.empty_text(LoanRows.VIEW_CLOSED, 0))
	TestFixtures.check(res, "an unnamed view falls back to Active",
		LoanRows.view_for(&"nowhere", LoanRows.sets(true, true)) == LoanRows.VIEW_ACTIVE,
		"%s" % [LoanRows.view_for(&"nowhere", LoanRows.sets(true, true))])
	TestFixtures.check(res, "Active stays chosen even with nothing in it",
		LoanRows.view_for(LoanRows.VIEW_ACTIVE, {LoanRows.VIEW_ACTIVE: []})
		== LoanRows.VIEW_ACTIVE, "active")


#Case 8: the three ways the list sorts.
static func _case_sort(res: Dictionary) -> void:
	_fresh()
	var base: Array[Dictionary] = _rows_of(LoanRows.VIEW_PENDING, true)
	var caps: Dictionary = LoanRows.caps(base)
	var down: Array[Dictionary] = LoanRows.apply(base, {}, caps, "monthly", true)
	TestFixtures.check(res, "the dearest month leads the monthly sort",
		int(down[0]["id"]) == OFFER_3 and int(down[3]["id"]) == OFFER_4,
		"%d then %d" % [int(down[0]["id"]), int(down[3]["id"])])
	var up: Array[Dictionary] = LoanRows.apply(base, {}, caps, "monthly", false)
	TestFixtures.check(res, "the direction toggle turns the same list around",
		int(up[0]["id"]) == OFFER_4 and int(up[3]["id"]) == OFFER_3,
		"%d then %d" % [int(up[0]["id"]), int(up[3]["id"])])
	var payoff: Array[Dictionary] = LoanRows.apply(base, {}, caps, "payoff", true)
	TestFixtures.check(res, "the payoff sort leads with the largest sum owed",
		int(payoff[0]["id"]) == OFFER_3 and int(payoff[1]["id"]) == OFFER_4,
		"%d then %d" % [int(payoff[0]["id"]), int(payoff[1]["id"])])
	var duration: Array[Dictionary] = LoanRows.apply(base, {}, caps, "duration", true)
	TestFixtures.check(res, "the duration sort leads with the longest term",
		int(duration[0]["term"]) == 12 and int(duration[3]["term"]) == 6,
		"%d then %d" % [int(duration[0]["term"]), int(duration[3]["term"])])
	TestFixtures.check(res, "a sort key nobody knows falls back to the monthly payment",
		int(LoanRows.apply(base, {}, caps, "nowhere", true)[0]["id"]) == OFFER_3,
		"fallback")
	TestFixtures.check(res, "every sort key has a label for the popup",
		LoanRows.SORT_LABELS.size() == LoanRows.SORT_KEYS.size()
		and String(LoanRows.SORT_LABELS["payoff"]) == "Payoff Amount",
		"%d labels" % LoanRows.SORT_LABELS.size())


#Case 9: the change cell of the offer table.
static func _case_change(res: Dictionary) -> void:
	var better: Dictionary = LoanLogic.change_row(1000.0, 1200.0, 1)
	TestFixtures.check(res, "more notes than asked for is good news with a full arrow",
		String(better["text"]) == "+20%" and (better["color"] as Color)
		== LoanLogic.CHANGE_GOOD_COLOR and StringName(better["arrow"]) == &"up",
		"%s %s" % [better["text"], better["arrow"]])
	var worse: Dictionary = LoanLogic.change_row(0.12, 0.29, -1)
	TestFixtures.check(res, "a higher rate than asked for is bad news",
		(worse["color"] as Color) == LoanLogic.CHANGE_BAD_COLOR
		and StringName(worse["arrow"]) == &"up", "%s" % [worse["text"]])
	var small: Dictionary = LoanLogic.change_row(200.0, 202.0, -1)
	TestFixtures.check(res, "a small change takes the slanted arrow",
		StringName(small["arrow"]) == &"diag_up", "%s" % [small["arrow"]])
	var same: Dictionary = LoanLogic.change_row(1500.0, 1500.0, 1)
	TestFixtures.check(res, "terms that did not move print no change and no arrow",
		String(same["text"]) == LoanLogic.CHANGE_NONE and StringName(same["arrow"]) == &""
		and (same["color"] as Color) == LoanLogic.CHANGE_FLAT_COLOR, String(same["text"]))
	var neutral: Dictionary = LoanLogic.change_row(6.0, 12.0, 0)
	TestFixtures.check(res, "a term that is neither good nor bad takes the neutral colour",
		(neutral["color"] as Color) == LoanLogic.CHANGE_NEUTRAL_COLOR, "%s" % [neutral["color"]])
	TestFixtures.check(res, "a term change counts months, and years when it divides",
		LoanLogic.term_delta(6, 9, false) == "+3 months"
		and LoanLogic.term_delta(24, 12, false) == "-1 year",
		"%s %s" % [LoanLogic.term_delta(6, 9, false), LoanLogic.term_delta(24, 12, false)])
	TestFixtures.check(res, "the short term change fits a narrow cell",
		LoanLogic.term_delta(2, 3, true) == "+1 mo" and LoanLogic.term_delta(6, 6, true)
		== LoanLogic.CHANGE_NONE, LoanLogic.term_delta(2, 3, true))
	TestFixtures.check(res, "a month count reads as one month or many",
		LoanLogic.months_label(1) == "1 Month" and LoanLogic.months_label(3) == "3 Months",
		LoanLogic.months_label(1))
	TestFixtures.check(res, "a deadline names the days and hours an offer still stands",
		LoanLogic.deadline_text(30.0) == "Offer Expires in 1 Days, 6 Hours",
		LoanLogic.deadline_text(30.0))
	TestFixtures.check(res, "a calm deadline is blue, a late one is red",
		LoanLogic.deadline_color(60.0) == LoanLogic.DEADLINE_CALM
		and LoanLogic.deadline_color(8.0) == LoanLogic.DEADLINE_LATE,
		"%s" % [LoanLogic.deadline_color(8.0)])


#Case 10: the card of an offer.
static func _case_card_offer(res: Dictionary, host: Node) -> void:
	_fresh()
	var card: LoanCard = _spawn(host, LoanCard.SCENE_PATH) as LoanCard
	card.set_row(_row_for(LoanRows.VIEW_PENDING, OFFER_1))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an offer card knows the offer it draws",
		card.kind() == LoanRows.KIND_OFFER and card.row_id() == OFFER_1,
		"%s %d" % [card.kind(), card.row_id()])
	TestFixtures.check(res, "an offer card carries four cells in the prototype order",
		card.cell_count() == 4 and card.cell_caption(0) == "Offered"
		and card.cell_caption(3) == "Offer Expires In", "%d cells" % card.cell_count())
	TestFixtures.check(res, "the offered amount is green",
		card.cell_text(0) == NotesLabel.format_amount(1500)
		and card.cell_color(0) == LoanStyle.GREEN, card.cell_text(0))
	TestFixtures.check(res, "the monthly cell prices the offered terms",
		card.cell_caption(1) == "Monthly Payment"
		and card.cell_text(1) == NotesLabel.format_amount(270), card.cell_text(1))
	TestFixtures.check(res, "the deadline cell takes the colour of its urgency",
		card.cell_color(3) == LoanLogic.deadline_color(FinanceManager.hours_left(OFFER_1)),
		"%s" % [card.cell_color(3)])
	TestFixtures.check(res, "an unread offer card shows its dot",
		card.dot_on(), "dot on")
	var button: Button = card.action_button()
	TestFixtures.check(res, "the offer dot hangs on the Review Offer button, not the card",
		card.dot() != null and card.dot().get_parent() == button,
		"%s" % [null if card.dot() == null else card.dot().get_parent()])
	TestFixtures.check(res, "an offer card offers the review button",
		button != null and button.text == LoanRows.REVIEW_TEXT and card.can_press(),
		"%s" % [button.text if button != null else ""])
	var seen: Array[int] = []
	card.review_pressed.connect(func(id: int) -> void: seen.append(id))
	card.press_action()
	TestFixtures.check(res, "pressing review names the offer to open",
		seen == [OFFER_1], "%s" % [seen])
	FinanceManager.mark_offer_seen(OFFER_1)
	NotificationCenter.read_offer(OFFER_1)
	card.set_row(_row_for(LoanRows.VIEW_PENDING, OFFER_1))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an answered offer card drops its dot",
		not card.dot_on(), "dot off")
	await _drop(host, card)


#Case 10b: the card of an offer that has expired.
static func _case_card_expired(res: Dictionary, host: Node) -> void:
	_fresh()
	var row_103: Dictionary = FinanceManager.offer(OFFER_3)
	CampaignClock.advance_to(int(row_103["expires_minute"]) + 1)
	FinanceManager.tick(CampaignClock.now())
	var card: LoanCard = _spawn(host, LoanCard.SCENE_PATH) as LoanCard
	card.set_row(_row_for(LoanRows.VIEW_PENDING, OFFER_3))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an expired card knows it is expired",
		card.expired(), "expired")
	TestFixtures.check(res, "an expired card dims its columns but keeps the card itself at full alpha",
		is_equal_approx(card.modulate.a, 1.0), "%f" % card.modulate.a)
	var overlay: Label = card.overlay()
	TestFixtures.check(res, "an expired card carries an EXPIRED overlay in red",
		overlay != null and overlay.text == "EXPIRED"
		and overlay.get_theme_color("font_color") == LoanStyle.RED, "%s" % [overlay])
	var button: Button = card.action_button()
	TestFixtures.check(res, "an expired card offers Dismiss and it is always pressable",
		button != null and button.text == "Dismiss" and card.can_press(),
		"%s" % [button.text if button != null else ""])
	TestFixtures.check(res, "an expired card shows no notification dot",
		not card.dot_on(), "no dot")
	var seen: Array[int] = []
	card.dismiss_pressed.connect(func(id: int) -> void: seen.append(id))
	card.press_action()
	TestFixtures.check(res, "pressing Dismiss names the offer to remove",
		seen == [OFFER_3], "%s" % [seen])
	await _drop(host, card)


#Case 11: the card of a request.
static func _case_card_request(res: Dictionary, host: Node) -> void:
	_fresh()
	var team: Array[int] = _uids(2)
	var calc: Dictionary = FinanceManager.request_calc("Lender 5",
		FinanceManager.fair_draft("Lender 5"), team)
	FinanceManager.request_loan({"lender": "Lender 5", "amount": int(calc["amount"]),
		"rate": float(calc["rate"]), "term": int(calc["months"]),
		"first_due": int(calc["first_due"]), "team": team, "odds": int(calc["odds"]), "per": 25})
	var row: Dictionary = {}
	for item: Dictionary in _rows_of(LoanRows.VIEW_PENDING, true):
		if StringName(item["kind"]) == LoanRows.KIND_REQUEST:
			row = item
	var card: LoanCard = _spawn(host, LoanCard.SCENE_PATH) as LoanCard
	card.set_row(row)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a request card carries three cells",
		card.cell_count() == 3 and card.cell_caption(2) == "Approval Odds",
		"%d cells" % card.cell_count())
	TestFixtures.check(res, "the requested amount is yellow",
		card.cell_color(0) == LoanStyle.YELLOW and card.cell_caption(0) == "Requested",
		"%s" % [card.cell_color(0)])
	TestFixtures.check(res, "the odds cell takes the colour of the odds",
		card.cell_color(2) == LoanLogic.odds_color(int(row["odds"])), card.cell_text(2))
	TestFixtures.check(res, "a request card is greyed and presses nothing",
		card.action_button() == null and not card.can_press()
		and card.modulate == LoanCard.REQUEST_GREY, "%s" % [card.modulate])
	TestFixtures.check(res, "a request card has no payment strip and no dot",
		card.payment_cells() == null and not card.dot_on(), "no strip")
	var faces: Array[int] = []
	for i: int in card.team_face_count():
		faces.append(card.team_portrait(i).merc_uid)
	faces.sort()
	var want: Array[int] = team.duplicate()
	want.sort()
	TestFixtures.check(res, "a request card draws a portrait of every envoy it sent",
		card.team_face_count() == 2 and faces == want,
		"%s for %s" % [faces, want])
	await _drop(host, card)


#Case 12: the card of a running loan.
static func _case_card_active(res: Dictionary, host: Node) -> void:
	_fresh()
	var card: LoanCard = _spawn(host, LoanCard.SCENE_PATH) as LoanCard
	card.set_row(_row_for(LoanRows.VIEW_ACTIVE, LOAN_1))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an active card carries three cells",
		card.cell_count() == 3 and card.cell_caption(0) == "Remaining"
		and card.cell_caption(2) == "Next Due", "%d cells" % card.cell_count())
	TestFixtures.check(res, "what is left to pay is red",
		card.cell_color(0) == LoanStyle.RED
		and card.cell_text(0) == NotesLabel.format_amount(1440), card.cell_text(0))
	var button: Button = card.action_button()
	TestFixtures.check(res, "an active card offers the payoff button",
		button != null and button.text == LoanRows.PAY_OFF_TEXT,
		"%s" % [button.text if button != null else ""])
	TestFixtures.check(res, "a payoff the bank cannot cover is blocked and says why",
		not card.can_press() and button.tooltip_text == LoanCard.BLOCK_TIP,
		button.tooltip_text)
	var strip: LoanPaymentCells = card.payment_cells()
	TestFixtures.check(res, "an active card draws one payment cell per month",
		strip != null and strip.cell_count() == 12,
		"%d cells" % [strip.cell_count() if strip != null else 0])
	var seen: Array[int] = []
	card.pay_off_pressed.connect(func(id: int) -> void: seen.append(id))
	card.press_action()
	TestFixtures.check(res, "a blocked payoff button emits nothing",
		seen.is_empty(), "%s" % [seen])
	card.set_row(_row_for(LoanRows.VIEW_ACTIVE, LOAN_2))
	await host.get_tree().process_frame
	card.press_action()
	TestFixtures.check(res, "a payoff the bank covers names the loan to close",
		card.can_press() and seen == [LOAN_2], "%s" % [seen])
	await _drop(host, card)


#Case 13: the card of a loan that ended.
static func _case_card_closed(res: Dictionary, host: Node) -> void:
	_fresh()
	var card: LoanCard = _spawn(host, LoanCard.SCENE_PATH) as LoanCard
	card.set_row(_row_for(LoanRows.VIEW_CLOSED, CLOSED_1))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a closed card counts what was paid and what it cost",
		card.cell_caption(0) == "Total Paid" and card.cell_caption(2) == "Interest Paid"
		and card.cell_text(2) == NotesLabel.format_amount(72), card.cell_text(2))
	TestFixtures.check(res, "the interest of a closed loan is red",
		card.cell_color(2) == LoanStyle.RED, "%s" % [card.cell_color(2)])
	TestFixtures.check(res, "a closed card is dimmed and offers no button",
		card.action_button() == null and not card.can_press()
		and is_equal_approx(card.modulate.a, LoanCard.CLOSED_ALPHA), "%s" % [card.modulate])
	var strip: LoanPaymentCells = card.payment_cells()
	TestFixtures.check(res, "a closed card keeps the strip of what it paid",
		strip != null and strip.cell_count() == 6,
		"%d cells" % [strip.cell_count() if strip != null else 0])
	await _drop(host, card)


#Case 14: the payment strip and the panel it opens under the pointer.
static func _case_strip(res: Dictionary, host: Node) -> void:
	_fresh()
	var strip := LoanPaymentCells.new()
	host.add_child(strip)
	await host.get_tree().process_frame
	strip.set_rows(FinanceManager.payment_rows(LOAN_1))
	TestFixtures.check(res, "the strip holds one cell per payment of the loan",
		strip.cell_count() == 12 and strip.hovered() == -1, "%d cells" % strip.cell_count())
	TestFixtures.check(res, "a payment sent is green and one still due is blue",
		strip.cell_color(0) == LoanPaymentCells.SENT
		and strip.cell_color(11) == LoanPaymentCells.FUTURE, "%s" % [strip.cell_color(11)])
	strip.hover_cell(3)
	TestFixtures.check(res, "the hovered cell grows and lightens",
		strip.hovered() == 3 and is_equal_approx(strip.cell_height(3),
		LoanPaymentCells.HOVER_HEIGHT) and strip.cell_color(3)
		== LoanPaymentCells.SENT_HOVER, "%f" % strip.cell_height(3))
	TestFixtures.check(res, "the panel names the payment and what it cost",
		strip.tip_open() and strip.tip_text("label") == "Payment 4 Sent"
		and strip.tip_text("amount") == NotesLabel.format_amount(180),
		"%s %s" % [strip.tip_text("label"), strip.tip_text("amount")])
	TestFixtures.check(res, "a payment already sent reads as sent",
		strip.tip_text("amount_label") == LoanPaymentCells.SENT_TEXT
		and strip.tip_text("date") != "", strip.tip_text("date"))
	strip.hover_cell(11)
	TestFixtures.check(res, "a payment still to come reads as due and leaves nothing behind",
		strip.tip_text("amount_label") == LoanPaymentCells.DUE_TEXT
		and strip.tip_text("after") == NotesLabel.format_amount(0),
		"%s %s" % [strip.tip_text("amount_label"), strip.tip_text("after")])
	strip.hover_cell(-1)
	TestFixtures.check(res, "leaving the strip closes the panel",
		not strip.tip_open() and strip.hovered() == -1 and strip.tip_text("label") == "",
		"panel closed")
	await _drop(host, strip)


#Case 15: the filter popup.
static func _case_popup(res: Dictionary, host: Node) -> void:
	_fresh()
	var popup: LoanFilterPopup = _spawn(host, LoanFilterPopup.SCENE_PATH) as LoanFilterPopup
	await host.get_tree().process_frame
	var caps: Dictionary = LoanRows.caps(_rows_of(LoanRows.VIEW_ACTIVE, true))
	popup.set_state(true, true, {}, caps)
	TestFixtures.check(res, "the popup holds one block per filter",
		popup.filter_count() == LoanRows.FILTER_DEFS.size()
		and popup.row_label("monthly") == "Monthly Payment", "%d blocks" % popup.filter_count())
	TestFixtures.check(res, "the popup is as wide as the prototype popup",
		is_equal_approx(popup.custom_minimum_size.x, LoanFilterPopup.WIDTH),
		"%f wide" % popup.custom_minimum_size.x)
	TestFixtures.check(res, "each block reads its whole span before it is touched",
		popup.range_text("monthly") == LoanRows.range_text("monthly", 0.0, 180.0),
		popup.range_text("monthly"))
	TestFixtures.check(res, "both sliders of a block stop at the cap of the view",
		is_equal_approx(popup.slider("monthly", true).max_value, 180.0)
		and is_equal_approx(popup.slider("monthly", false).max_value, 180.0),
		"%f" % popup.slider("monthly", true).max_value)
	TestFixtures.check(res, "the switch starts on, with the requests shown",
		popup.show_requests(), "requests shown")
	var toggles: Array[bool] = []
	popup.requests_toggled.connect(func(on: bool) -> void: toggles.append(on))
	popup.toggle_requests(false)
	TestFixtures.check(res, "turning the requests off tells the page",
		toggles == [false] and not popup.show_requests(), "%s" % [toggles])
	var changes: Array[String] = []
	popup.range_changed.connect(func(key: String, low: float, high: float) -> void:
		changes.append("%s %d %d" % [key, roundi(low), roundi(high)]))
	popup.set_slider("monthly", true, 150.0)
	TestFixtures.check(res, "dragging a bound hands the page the new range",
		changes == ["monthly 0 150"], "%s" % [changes])
	var resets: Array[bool] = []
	popup.reset_pressed.connect(func() -> void: resets.append(true))
	popup.press_reset()
	TestFixtures.check(res, "Reset asks the page to clear every filter",
		resets.size() == 1 and popup.reset_button() != null, "%s" % [resets])
	popup.set_state(true, true, {"monthly": Vector2(20.0, 150.0)}, caps)
	TestFixtures.check(res, "the page writes its ranges back into the popup",
		popup.range_text("monthly") == LoanRows.range_text("monthly", 20.0, 150.0)
		and is_equal_approx(popup.slider("monthly", false).value, 20.0),
		popup.range_text("monthly"))
	await _drop(host, popup)


#Case 16: the shared window shell, through the confirm of a request.
static func _case_shell(res: Dictionary, host: Node) -> void:
	_fresh()
	var window: LoanRequestConfirm = _spawn(host,
		LoanRequestConfirm.SCENE_PATH) as LoanRequestConfirm
	await host.get_tree().process_frame
	TestFixtures.check(res, "a window starts closed and hidden",
		not window.is_open() and not window.visible, "closed")
	TestFixtures.check(res, "a window has a frame, a body and a close button",
		window.frame_box() != null and window.body_box() != null
		and window.close_button() != null, "built")
	TestFixtures.check(res, "the close button of the confirm cancels",
		window.close_button().tooltip_text == LoanRequestConfirm.CANCEL_TEXT,
		window.close_button().tooltip_text)
	TestFixtures.check(res, "the confirm is as wide as the prototype window",
		is_equal_approx(window.frame_size().x, LoanRequestConfirm.WINDOW_WIDTH),
		"%f wide" % window.frame_size().x)
	window.open_for(_snap())
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening a window shows it",
		window.is_open() and window.visible, "open")
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var shell: PanelContainer = window.frame_box()
	var shell_x: float = shell.global_position.x + shell.size.x / 2.0
	var shell_y: float = shell.global_position.y + shell.size.y / 2.0
	var shell_band: float = GuiFrameStack.band_height(view.y)
	TestFixtures.check(res, "an open window fits the viewport and centres on its band",
		window.top_level and window.size.is_equal_approx(view)
			and absf(shell_x - view.x / 2.0) <= 1.0
			and absf(shell_y - shell_band / 2.0) <= 1.0,
		"size %s view %s centre %.1f/%.1f" % [window.size, view, shell_x, shell_y])
	TestFixtures.check(res, "an open window takes a rung above the HUD popups",
		GuiFrameStack.top() == window and window.z_index >= GuiFrameStack.BASE_Z,
		"top %s z %d" % [GuiFrameStack.top(), window.z_index])
	TestFixtures.check(res, "the confirm names what is about to be sent",
		window.kicker_text() == LoanRequestConfirm.KICKER
		and window.lender_text() == "Lender 1", window.lender_text())
	TestFixtures.check(res, "the confirm prints the rate of the draft",
		window.rate_text() == "8.0%" + LoanRequestConfirm.INTEREST_SUFFIX, window.rate_text())
	TestFixtures.check(res, "the confirm carries the six terms of the draft",
		window.cell_count() == 6 and window.cell_caption(0) == "Amount"
		and window.cell_caption(5) == "Total Repaid", "%d cells" % window.cell_count())
	TestFixtures.check(res, "the confirm prices the amount, the interest and the total",
		window.cell_text(0) == NotesLabel.format_amount(1500)
		and window.cell_text(4) == NotesLabel.format_amount(120)
		and window.cell_text(5) == NotesLabel.format_amount(1620), window.cell_text(5))
	TestFixtures.check(res, "the confirm counts the term and the first payment in months",
		window.cell_text(1) == LoanLogic.term_label(6)
		and window.cell_text(3) == LoanLogic.months_label(2), window.cell_text(1))
	TestFixtures.check(res, "the confirm meters the approval odds",
		window.odds() == 71 and window.odds_text() == "71%"
		and window.odds_cells() == SuccessMeter.filled_cells(71), window.odds_text())
	TestFixtures.check(res, "a request with no envoy says it goes by letter",
		window.no_team() and window.team_count() == 0 and window.away_text() != "",
		window.away_text())
	window.set_dimmed(true)
	TestFixtures.check(res, "a window dims while a confirm of its own sits over it",
		window.dimmed(), "dimmed")
	var sends: Array[bool] = []
	window.send_pressed.connect(func() -> void: sends.append(true))
	window.press_send()
	TestFixtures.check(res, "Send Request asks the page to send, and sends nothing itself",
		sends.size() == 1 and FinanceManager.requests.is_empty(), "%s" % [sends])
	var closes: Array[bool] = []
	window.closed.connect(func() -> void: closes.append(true))
	window.press_cancel()
	TestFixtures.check(res, "cancelling closes the window and clears the dim",
		not window.is_open() and not window.visible and not window.dimmed()
		and closes.size() == 1, "%s" % [closes])
	TestFixtures.check(res, "a closed window is off the frame stack",
		GuiFrameStack.top() != window, "top %s" % GuiFrameStack.top())
	var team: Array[int] = _uids(2)
	var snap: Dictionary = _snap()
	snap["team"] = team
	window.open_for(snap)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a request with envoys names them instead",
		not window.no_team() and window.team_count() == 2, "%d envoys" % window.team_count())
	var first: MercPortrait = window.team_portrait(0)
	var second: MercPortrait = window.team_portrait(1)
	TestFixtures.check(res, "the confirm draws a portrait of each envoy it names",
		first != null and second != null and team.has(first.merc_uid)
		and team.has(second.merc_uid) and first.merc_uid != second.merc_uid,
		"%s" % [[0 if first == null else first.merc_uid,
			0 if second == null else second.merc_uid]])
	await _drop(host, window)


#Case 17: the offer dialog.
static func _case_offer_dialog(res: Dictionary, host: Node) -> void:
	_fresh()
	var dialog: LoanOfferDialog = _spawn(host, LoanOfferDialog.SCENE_PATH) as LoanOfferDialog
	await host.get_tree().process_frame
	dialog.open_for(OFFER_2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dialog opens on the offer it was given",
		dialog.is_open() and dialog.offer_id() == OFFER_2, "%d" % dialog.offer_id())
	TestFixtures.check(res, "the dialog names the lender and the deadline",
		dialog.lender_text() == "Lender 2" and dialog.kicker_text() == LoanOfferDialog.KICKER
		and dialog.deadline_text() == LoanLogic.deadline_text(30.0), dialog.deadline_text())
	TestFixtures.check(res, "the deadline takes the colour of its urgency",
		dialog.deadline_color() == LoanLogic.deadline_color(30.0),
		"%s" % [dialog.deadline_color()])
	TestFixtures.check(res, "the table holds the six terms in the prototype order",
		dialog.row_count() == 6 and dialog.row_label(0) == "Amount"
		and dialog.row_label(4) == "First Payment Due", "%d rows" % dialog.row_count())
	TestFixtures.check(res, "the amount row reads the ask beside the offer",
		dialog.req_text(0) == NotesLabel.format_amount(1000)
		and dialog.off_text(0) == NotesLabel.format_amount(1200),
		"%s %s" % [dialog.req_text(0), dialog.off_text(0)])
	TestFixtures.check(res, "more notes than asked for is good news",
		dialog.change_text(0) == "+20%"
		and dialog.change_color(0) == LoanLogic.CHANGE_GOOD_COLOR, dialog.change_text(0))
	TestFixtures.check(res, "the rate row reads in whole percent",
		dialog.req_text(1) == "12%" and dialog.off_text(1) == "10%",
		"%s %s" % [dialog.req_text(1), dialog.off_text(1)])
	TestFixtures.check(res, "a lower rate than asked for is good news",
		dialog.change_color(1) == LoanLogic.CHANGE_GOOD_COLOR, dialog.change_text(1))
	TestFixtures.check(res, "a term that did not move prints no change",
		dialog.req_text(2) == LoanLogic.months_label(6)
		and dialog.change_text(2) == LoanLogic.CHANGE_NONE, dialog.change_text(2))
	TestFixtures.check(res, "the monthly row prices both sets of terms",
		dialog.req_text(3) == NotesLabel.format_amount(LoanLogic.payment(1000, 0.12, 6))
		and dialog.off_text(3) == NotesLabel.format_amount(220), dialog.off_text(3))
	TestFixtures.check(res, "a dearer month than asked for is bad news",
		dialog.change_color(3) == LoanLogic.CHANGE_BAD_COLOR, dialog.change_text(3))
	TestFixtures.check(res, "the first payment row prints its own wording",
		dialog.off_text(4) == LoanLogic.months_label(3)
		and dialog.change_text(4) == LoanLogic.term_delta(2, 3, false), dialog.change_text(4))
	TestFixtures.check(res, "a later first payment is good news",
		dialog.change_color(4) == LoanLogic.CHANGE_GOOD_COLOR, dialog.change_text(4))
	TestFixtures.check(res, "the total repaid counts the interest of the offer",
		dialog.off_text(5) == NotesLabel.format_amount(1320)
		and dialog.change_color(5) == LoanLogic.CHANGE_BAD_COLOR, dialog.off_text(5))
	TestFixtures.check(res, "a row that moved draws its arrow, one that did not draws none",
		dialog.has_arrow(0) and not dialog.has_arrow(2), "arrows")
	TestFixtures.check(res, "the dialog offers Decline and Accept",
		dialog.decline_button() != null and dialog.accept_button() != null
		and dialog.decline_button().text == LoanOfferDialog.DECLINE_TEXT,
		dialog.accept_button().text)
	TestFixtures.check(res, "another offer on the table means accepting is confirmed first",
		dialog.needs_confirm() and dialog.other_offers().size() == 3,
		"%d others" % dialog.other_offers().size())
	var asked: Array[int] = []
	dialog.accept_asked.connect(func(id: int) -> void: asked.append(id))
	dialog.press_accept()
	TestFixtures.check(res, "Accept asks for the confirm instead of taking the offer",
		asked == [OFFER_2] and FinanceManager.loans.size() == 2, "%s" % [asked])
	var declined: Array[int] = []
	dialog.declined.connect(func(id: int) -> void: declined.append(id))
	dialog.press_decline()
	TestFixtures.check(res, "Decline turns the offer down and closes the dialog",
		declined == [OFFER_2] and FinanceManager.offer(OFFER_2).is_empty()
		and not dialog.is_open(), "%s" % [declined])
	var before: int = GameState.bank_notes
	dialog.open_for(OFFER_1)
	await host.get_tree().process_frame
	var taken: Array[int] = []
	dialog.accepted.connect(func(id: int) -> void: taken.append(id))
	TestFixtures.check(res, "taking an offer books the notes and closes the dialog",
		dialog.accept_now() and GameState.bank_notes == before + 1500 and taken == [OFFER_1]
		and not dialog.is_open(), "%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "the last offer standing needs no confirm",
		FinanceManager.offers.is_empty() and not dialog.needs_confirm(), "none left")
	await _drop(host, dialog)


#Case 18: the confirm over the offer dialog.
static func _case_accept_confirm(res: Dictionary, host: Node) -> void:
	_fresh()
	var confirm: LoanAcceptConfirm = _spawn(host,
		LoanAcceptConfirm.SCENE_PATH) as LoanAcceptConfirm
	await host.get_tree().process_frame
	confirm.open_for(OFFER_1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the confirm asks whether the guild is sure",
		confirm.title_text() == LoanAcceptConfirm.TITLE
		and confirm.title_label().text == LoanAcceptConfirm.TITLE, confirm.title_text())
	TestFixtures.check(res, "the confirm keeps the dialog under it visible",
		confirm.backdrop_color() == LoanStyle.CLEAR, "%s" % [confirm.backdrop_color()])
	TestFixtures.check(res, "the confirm warns what accepting throws away",
		confirm.line_text() == LoanAcceptConfirm.LINE_TEXT and confirm.base_id() == OFFER_1,
		confirm.line_text())
	TestFixtures.check(res, "the confirm lists every alternate offer, oldest first",
		confirm.card_count() == 3 and confirm.card_offer_id(0) == OFFER_2
		and confirm.card_offer_id(2) == OFFER_4, "%d cards" % confirm.card_count())
	TestFixtures.check(res, "each card names its lender and its deadline",
		confirm.card_lender(0) == "Lender 2"
		and confirm.card_deadline(0) == LoanLogic.deadline_text(30.0), confirm.card_deadline(0))
	TestFixtures.check(res, "each card carries the six terms in short form",
		confirm.cell_count(0) == 6 and confirm.cell_caption(0, 0) == "Amount"
		and confirm.cell_caption(0, 4) == "First Due", "%d cells" % confirm.cell_count(0))
	TestFixtures.check(res, "a card prices the alternate offer, not the one being taken",
		confirm.cell_value(0, 0) == NotesLabel.format_amount(1200)
		and confirm.cell_value(0, 3) == NotesLabel.format_amount(220), confirm.cell_value(0, 0))
	TestFixtures.check(res, "a short cell counts months and percent",
		confirm.cell_value(0, 1) == "10%" and confirm.cell_value(0, 2) == "6 mo",
		"%s %s" % [confirm.cell_value(0, 1), confirm.cell_value(0, 2)])
	TestFixtures.check(res, "a smaller alternate amount reads as the worse news",
		confirm.cell_change(0, 0) == "-20%"
		and confirm.cell_change_color(0, 0) == LoanLogic.CHANGE_BAD_COLOR,
		confirm.cell_change(0, 0))
	TestFixtures.check(res, "a cheaper alternate month reads as the better news",
		confirm.cell_change_color(0, 3) == LoanLogic.CHANGE_GOOD_COLOR,
		confirm.cell_change(0, 3))
	TestFixtures.check(res, "a term cell prints the short change and no arrow when it is level",
		confirm.cell_change(0, 2) == LoanLogic.CHANGE_NONE and not confirm.cell_has_arrow(0, 2)
		and confirm.cell_change(0, 4) == LoanLogic.term_delta(2, 3, true),
		confirm.cell_change(0, 4))
	TestFixtures.check(res, "the list of cards is the one box of the confirm that scrolls",
		confirm.list_box() != null and confirm.list_box().get_parent() is ScrollContainer,
		"one scroll")
	var taken: Array[int] = []
	confirm.confirmed.connect(func(id: int) -> void: taken.append(id))
	confirm.press_accept()
	TestFixtures.check(res, "the confirm answers the dialog and books nothing itself",
		taken == [OFFER_1] and FinanceManager.loans.size() == 2, "%s" % [taken])
	confirm.press_cancel()
	TestFixtures.check(res, "cancelling the confirm closes it and leaves every offer standing",
		not confirm.is_open() and FinanceManager.offers.size() == 4,
		"%d offers" % FinanceManager.offers.size())
	FinanceManager.reject_offer(OFFER_2)
	FinanceManager.reject_offer(OFFER_3)
	FinanceManager.reject_offer(OFFER_4)
	confirm.open_for(OFFER_1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "with nothing to throw away the confirm says so",
		confirm.card_count() == 0, "%d cards" % confirm.card_count())
	await _drop(host, confirm)


#Case 19: the three views of the page.
static func _case_tab_views(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	TestFixtures.check(res, "the page opens on the active loans",
		tab.view() == LoanRows.VIEW_ACTIVE and tab.card_count() == 2,
		"%s with %d cards" % [tab.view(), tab.card_count()])
	TestFixtures.check(res, "each view button counts its rows",
		tab.view_count(LoanRows.VIEW_ACTIVE) == 2
		and tab.view_count(LoanRows.VIEW_PENDING) == 4
		and tab.view_count(LoanRows.VIEW_CLOSED) == 2,
		"%d pending" % tab.view_count(LoanRows.VIEW_PENDING))
	TestFixtures.check(res, "an unread offer puts a dot on the pending button alone",
		tab.view_dot(LoanRows.VIEW_PENDING) and not tab.view_dot(LoanRows.VIEW_ACTIVE)
		and not tab.view_dot(LoanRows.VIEW_CLOSED), "one dot")
	tab.press_view(LoanRows.VIEW_PENDING)
	TestFixtures.check(res, "pressing a view draws its rows",
		tab.view() == LoanRows.VIEW_PENDING and tab.card_count() == 4
		and not tab.empty_visible(), "%d cards" % tab.card_count())
	TestFixtures.check(res, "the cards come in the sorted order of the rows",
		tab.row_ids() == [OFFER_3, OFFER_1, OFFER_2, OFFER_4], "%s" % [tab.row_ids()])
	TestFixtures.check(res, "the first card is the card of the first row",
		tab.card(0) != null and tab.card(0).row_id() == OFFER_3,
		"%d" % [tab.card(0).row_id() if tab.card(0) != null else -1])
	tab.press_view(LoanRows.VIEW_CLOSED)
	TestFixtures.check(res, "the closed view draws the loans that ended",
		tab.view() == LoanRows.VIEW_CLOSED and tab.card_count() == 2,
		"%d cards" % tab.card_count())
	FinanceManager.reject_offer(OFFER_1)
	FinanceManager.reject_offer(OFFER_2)
	FinanceManager.reject_offer(OFFER_3)
	FinanceManager.reject_offer(OFFER_4)
	TestFixtures.check(res, "an empty view cannot be pressed and says why",
		not tab.view_enabled(LoanRows.VIEW_PENDING)
		and tab.view_button(LoanRows.VIEW_PENDING).disabled
		and tab.view_button(LoanRows.VIEW_PENDING).tooltip_text == "No pending loans",
		tab.view_button(LoanRows.VIEW_PENDING).tooltip_text)
	tab.press_view(LoanRows.VIEW_PENDING)
	TestFixtures.check(res, "an empty view is not opened",
		tab.view() == LoanRows.VIEW_CLOSED, "%s" % [tab.view()])
	TestFixtures.check(res, "the pending dot goes with the offers",
		not tab.view_dot(LoanRows.VIEW_PENDING)
		and tab.view_count(LoanRows.VIEW_PENDING) == 0, "no dot")
	TestFixtures.check(res, "Active is always open, even with nothing in it",
		tab.view_enabled(LoanRows.VIEW_ACTIVE)
		and not tab.view_button(LoanRows.VIEW_ACTIVE).disabled, "active open")
	tab.hide()
	_set_money(2000)
	TestFixtures.check(res, "a hidden page only marks itself dirty",
		tab.dirty(), "dirty")
	tab.show()
	TestFixtures.check(res, "showing the page again reads the finances over",
		not tab.dirty(), "clean")
	tab.hide()
	_set_money(1500)
	tab.visibility_changed.disconnect(Callable(tab, "_on_visibility_changed"))
	tab.show()
	TestFixtures.check(res, "a page shown without its own signal stays dirty",
		tab.dirty(), "dirty")
	tab.page_shown()
	TestFixtures.check(res, "page_shown writes the page the shell just opened",
		not tab.dirty() and tab.card_count() > 0, "%d" % [tab.card_count()])
	await _drop(host, tab)


#Case 20: the sort button, its popup and the direction toggle.
static func _case_tab_sort(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	tab.press_view(LoanRows.VIEW_PENDING)
	var drop: OptionDropdown = tab.sort_dropdown()
	TestFixtures.check(res, "the sort control is the shared dropdown atom",
		drop != null and tab.sort_button() == drop.toggle, "%s" % [drop])
	TestFixtures.check(res, "the dropdown takes the size of the prototype button",
		is_equal_approx(drop.custom_minimum_size.x, LoansTab.SORT_BUTTON_WIDTH)
		and is_equal_approx(drop.custom_minimum_size.y, LoansTab.TOOL_HEIGHT),
		"%s" % [drop.custom_minimum_size])
	TestFixtures.check(res, "the dropdown holds the three sort keys in order",
		_keys_of(drop) == ["monthly", "payoff", "duration"]
		and drop.selected == &"monthly", "%s" % [_keys_of(drop)])
	TestFixtures.check(res, "the page sorts by the monthly payment first",
		tab.sort_key() == "monthly" and tab.sort_label() == "Monthly Payment"
		and tab.descending(), tab.sort_label())
	TestFixtures.check(res, "the sort popup is closed until the button is pressed",
		not tab.sort_popup_open() and tab.sort_button() != null, "closed")
	tab.press_sort()
	TestFixtures.check(res, "the button opens a popup with one row per sort key",
		tab.sort_popup_open() and tab.sort_option_count() == 3
		and tab.sort_option_label(1) == "Payoff Amount", tab.sort_option_label(1))
	tab.pick_sort(1)
	TestFixtures.check(res, "picking a key closes the popup and re-sorts the list",
		not tab.sort_popup_open() and tab.sort_key() == "payoff"
		and tab.row_ids() == [OFFER_3, OFFER_4, OFFER_1, OFFER_2], "%s" % [tab.row_ids()])
	TestFixtures.check(res, "the button names the key it is sorting on",
		tab.sort_label() == "Payoff Amount", tab.sort_label())
	tab.toggle_direction()
	TestFixtures.check(res, "the direction toggle turns the list around",
		not tab.descending() and tab.row_ids() == [OFFER_2, OFFER_1, OFFER_4, OFFER_3],
		"%s" % [tab.row_ids()])
	TestFixtures.check(res, "the toggle and the page agree on the direction",
		tab.direction_toggle() != null
		and tab.direction_toggle().descending == tab.descending(), "agreed")
	tab.pick_sort(2)
	TestFixtures.check(res, "the duration sort leads with the longest term",
		tab.sort_key() == "duration" and tab.card_count() == 4, tab.sort_label())
	tab.pick_sort(9)
	TestFixtures.check(res, "a row the popup does not have changes nothing",
		tab.sort_key() == "duration", tab.sort_key())
	tab.press_sort()
	tab.press_filter()
	TestFixtures.check(res, "opening one popup closes the other",
		tab.filter_popup_open() and not tab.sort_popup_open(), "one popup")
	tab.press_filter()
	TestFixtures.check(res, "pressing the same button again closes its popup",
		not tab.filter_popup_open(), "closed")
	tab.press_filter()
	tab.press_sort()
	TestFixtures.check(res, "the sort popup takes the filter popup down as well",
		tab.sort_popup_open() and not tab.filter_popup_open(), "sort only")
	tab.press_sort()
	tab.press_filter()
	drop.open_popup()
	TestFixtures.check(res, "the button of the atom closes the filter popup too",
		drop.popup_open() and not tab.filter_popup_open(), "sort only")
	drop.close_popup()
	TestFixtures.check(res, "the page reads the popup of the atom as its own",
		not tab.sort_popup_open(), "closed")
	await _drop(host, tab)


#Case 21: the filters of the page.
static func _case_tab_filter(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	tab.press_view(LoanRows.VIEW_PENDING)
	TestFixtures.check(res, "nothing is filtered when the page opens",
		not tab.filters_active() and tab.show_requests() and tab.ranges().is_empty(),
		"unfiltered")
	tab.set_filter("monthly", 0.0, 200.0)
	TestFixtures.check(res, "a monthly bound drops the rows that cost more",
		tab.card_count() == 1 and tab.row_ids() == [OFFER_4] and tab.filters_active(),
		"%s" % [tab.row_ids()])
	TestFixtures.check(res, "the popup reads the range the page holds",
		tab.filter_popup().range_text("monthly")
		== LoanRows.range_text("monthly", 0.0, 200.0),
		tab.filter_popup().range_text("monthly"))
	tab.set_filter("monthly", 320.0, 320.0)
	TestFixtures.check(res, "a range nothing meets empties the list and says so",
		tab.card_count() == 0 and tab.empty_visible()
		and tab.empty_text() == LoanRows.EMPTY_FILTERED, tab.empty_text())
	TestFixtures.check(res, "a bound over the cap is clamped into it",
		is_equal_approx((tab.ranges()["monthly"] as Vector2).y, 320.0)
		and is_equal_approx(tab.filter_popup().slider("monthly", true).value, 310.0),
		"%s" % [tab.ranges()["monthly"]])
	tab.reset_filters()
	TestFixtures.check(res, "Reset brings every row back",
		tab.card_count() == 4 and not tab.empty_visible() and not tab.filters_active(),
		"%d cards" % tab.card_count())
	tab.set_show_requests(false)
	TestFixtures.check(res, "hiding the requests counts as a filter of its own",
		tab.filters_active() and not tab.show_requests(), "requests hidden")
	tab.reset_filters()
	tab.press_view(LoanRows.VIEW_ACTIVE)
	tab.set_filter("paid", 3.0, 4.0)
	TestFixtures.check(res, "the filters read the metrics of the view they are over",
		tab.row_ids() == [LOAN_1], "%s" % [tab.row_ids()])
	tab.reset_filters()
	TestFixtures.check(res, "an unfiltered active view draws both loans",
		tab.card_count() == 2, "%d cards" % tab.card_count())
	await _drop(host, tab)


#Case 22: the request window from the page, and the confirm in front of it.
static func _case_tab_request(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	TestFixtures.check(res, "the page offers the request button",
		tab.request_button() != null
		and tab.request_button().text == LoansTab.REQUEST_TEXT,
		tab.request_button().text)
	tab.press_request()
	await host.get_tree().process_frame
	var window: LoanRequestWindow = tab.request_window()
	TestFixtures.check(res, "the button opens the request window",
		window != null and window.is_open(), "open")
	TestFixtures.check(res, "the window lists every lender",
		window.lender_count() == FinanceManager.LENDER_ROWS.size(),
		"%d lenders" % window.lender_count())
	TestFixtures.check(res, "a lender that already holds an offer is busy",
		window.card_for("Lender 1") != null and window.card_for("Lender 1").is_busy()
		and window.card_for("Lender 1").tag_visible(), "Lender 1 busy")
	TestFixtures.check(res, "the window opens on the warmest lender that is free",
		window.chosen_lender() == "Lender 8" and window.can_send(), window.chosen_lender())
	window.press_request()
	await host.get_tree().process_frame
	var confirm: LoanRequestConfirm = tab.request_confirm()
	TestFixtures.check(res, "Request opens the confirm and dims the window under it",
		confirm.is_open() and window.dimmed() and window.is_open(), "dimmed")
	TestFixtures.check(res, "the confirm reads the draft of the window",
		confirm.lender_text() == "Lender 8" and confirm.odds() == window.odds(),
		"%d per cent" % confirm.odds())
	confirm.press_cancel()
	TestFixtures.check(res, "cancelling the confirm clears the dim and keeps the window",
		not confirm.is_open() and not window.dimmed() and window.is_open(), "back")
	window.press_request()
	await host.get_tree().process_frame
	confirm.press_send()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Send Request sends it and closes both windows",
		FinanceManager.requests.size() == 1 and not confirm.is_open()
		and not window.is_open(), "%d requests" % FinanceManager.requests.size())
	TestFixtures.check(res, "the request joins the pending view of the page",
		tab.view_count(LoanRows.VIEW_PENDING) == 5, "%d pending"
		% tab.view_count(LoanRows.VIEW_PENDING))
	TestFixtures.check(res, "the lender that was asked is busy now",
		FinanceManager.lender_busy("Lender 8"), "Lender 8 busy")
	await _drop(host, tab)


#Case 23: reviewing an offer from the page and taking it.
static func _case_tab_offer(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	tab.open_offer(OFFER_1)
	await host.get_tree().process_frame
	var dialog: LoanOfferDialog = tab.offer_dialog()
	TestFixtures.check(res, "opening an offer switches to the pending view",
		tab.view() == LoanRows.VIEW_PENDING and dialog.is_open()
		and dialog.offer_id() == OFFER_1, "%s" % [tab.view()])
	TestFixtures.check(res, "opening an offer answers the row that announced it",
		not FinanceManager.offer_unread(OFFER_1), "read")
	TestFixtures.check(res, "an offer nobody has opens nothing",
		not _opens(tab, 999), "no such offer")
	dialog.press_accept()
	await host.get_tree().process_frame
	var confirm: LoanAcceptConfirm = tab.accept_confirm()
	TestFixtures.check(res, "Accept opens the confirm and dims the dialog under it",
		confirm.is_open() and dialog.dimmed() and not dialog.close_button().visible,
		"dimmed")
	TestFixtures.check(res, "the confirm lists the offers that accepting throws away",
		confirm.base_id() == OFFER_1 and confirm.card_count() == 3,
		"%d cards" % confirm.card_count())
	var before: int = GameState.bank_notes
	confirm.press_accept()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the confirm books the loan and closes both windows",
		GameState.bank_notes == before + 1500 and not confirm.is_open()
		and not dialog.is_open(), "%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "taking one offer drops every other offer",
		FinanceManager.offers.is_empty() and FinanceManager.loans.size() == 3,
		"%d loans" % FinanceManager.loans.size())
	TestFixtures.check(res, "the page falls back to the active view and draws the new loan",
		tab.view() == LoanRows.VIEW_ACTIVE and tab.card_count() == 3,
		"%d cards" % tab.card_count())
	TestFixtures.check(res, "the dialog is undimmed once the confirm is answered",
		not dialog.dimmed() and dialog.close_button().visible, "undimmed")
	await _drop(host, tab)


static func _opens(tab: LoansTab, offer_id: int) -> bool:
	tab.open_offer(offer_id)
	return tab.offer_dialog().offer_id() == offer_id


#Case 23b: an expired offer on the page: hidden by the filter, dismissed by its own button.
static func _case_tab_expired(res: Dictionary, host: Node) -> void:
	_fresh()
	var row_103: Dictionary = FinanceManager.offer(OFFER_3)
	CampaignClock.advance_to(int(row_103["expires_minute"]) + 1)
	FinanceManager.tick(CampaignClock.now())
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	tab.press_view(LoanRows.VIEW_PENDING)
	TestFixtures.check(res, "the expired offer still lists by default, sorted last",
		tab.card_count() == 4 and tab.row_ids()[3] == OFFER_3 and tab.show_expired(),
		"%s" % [tab.row_ids()])
	TestFixtures.check(res, "opening an expired offer opens nothing",
		not _opens(tab, OFFER_3), "dialog opened")
	tab.set_show_expired(false)
	TestFixtures.check(res, "hiding expired offers drops the row and counts as a filter",
		tab.card_count() == 3 and not tab.row_ids().has(OFFER_3) and tab.filters_active(),
		"%s" % [tab.row_ids()])
	tab.reset_filters()
	TestFixtures.check(res, "Reset brings the expired offer back and clears the filter",
		tab.card_count() == 4 and tab.row_ids().has(OFFER_3) and tab.show_expired()
		and not tab.filters_active(), "%s" % [tab.row_ids()])
	var card: LoanCard = null
	for i: int in tab.card_count():
		if tab.card(i).row_id() == OFFER_3:
			card = tab.card(i)
	TestFixtures.check(res, "the expired card presses Dismiss, not Review",
		card != null and card.expired() and card.action_button().text == "Dismiss", "found card")
	card.press_action()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Dismiss removes the offer and its card",
		FinanceManager.offer(OFFER_3).is_empty() and not tab.row_ids().has(OFFER_3),
		"%s" % [tab.row_ids()])
	await _drop(host, tab)


#Case 24: paying a loan off from the page.
static func _case_tab_payoff(res: Dictionary, host: Node) -> void:
	_fresh()
	_set_money(RICH)
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await host.get_tree().process_frame
	TestFixtures.check(res, "a payoff the bank covers can be pressed",
		tab.card_count() == 2 and tab.card(0).can_press(), "%d cards" % tab.card_count())
	tab.ask_payoff(LOAN_2)
	await host.get_tree().process_frame
	var dialog: ConfirmDialog = tab.payoff_dialog()
	TestFixtures.check(res, "the payoff button asks before it spends",
		dialog != null and dialog.visible and tab.payoff_id() == LOAN_2,
		"%d" % tab.payoff_id())
	TestFixtures.check(res, "the safe answer leads and the payoff carries the price",
		dialog.button_labels() == [LoansTab.PAYOFF_NO, LoansTab.PAYOFF_YES],
		"%s" % [dialog.button_labels()])
	dialog.press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancelling the question pays nothing",
		FinanceManager.loan_by_id(LOAN_2) != null and GameState.bank_notes == RICH,
		"%d notes" % GameState.bank_notes)
	tab.ask_payoff(LOAN_2)
	await host.get_tree().process_frame
	dialog.press(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "answering it closes the loan and takes the payoff",
		FinanceManager.loan_by_id(LOAN_2) == null and GameState.bank_notes == RICH - 667,
		"%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "the closed loan leaves the active list",
		tab.card_count() == 1 and tab.row_ids() == [LOAN_1], "%s" % [tab.row_ids()])
	TestFixtures.check(res, "the page forgets which loan it asked about",
		tab.payoff_id() == -1, "%d" % tab.payoff_id())
	tab.press_view(LoanRows.VIEW_CLOSED)
	TestFixtures.check(res, "the loan that was paid off joins the closed view",
		tab.card_count() == 3 and tab.view_count(LoanRows.VIEW_CLOSED) == 3,
		"%d cards" % tab.card_count())
	tab.ask_payoff(999)
	TestFixtures.check(res, "a loan nobody has asks nothing",
		tab.payoff_id() == -1, "%d" % tab.payoff_id())
	await _drop(host, tab)


static func _keys_of(drop: OptionDropdown) -> Array[String]:
	var out: Array[String] = []
	for opt: Dictionary in drop.options:
		out.append(String(opt.get("key", "")))
	return out


static func _range_is(tab: LoansTab, key: String, low: float, high: float) -> bool:
	if not tab.ranges().has(key):
		return false
	var got: Vector2 = tab.ranges()[key] as Vector2
	return is_equal_approx(got.x, low) and is_equal_approx(got.y, high)


static func _slider_at(tab: LoansTab, key: String, top: bool, value: float) -> bool:
	var node: LoanSlider = tab.filter_popup().slider(key, top)
	return node != null and is_equal_approx(node.value, value)


#Case 25: an offer the bank no longer holds. The view still turns, the dialog stays shut.
static func _case_tab_unknown_offer(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await _frames(host, 1)
	TestFixtures.check(res, "the page opens on the active view",
		tab.view() == LoanRows.VIEW_ACTIVE, "%s" % [tab.view()])
	tab.open_offer(999)
	await _frames(host, 1)
	TestFixtures.check(res, "an id the bank does not hold still shows the pending view",
		tab.view() == LoanRows.VIEW_PENDING and not tab.offer_dialog().is_open(),
		"%s" % [tab.view()])
	TestFixtures.check(res, "an offer nobody has answers no row of its own",
		FinanceManager.offer_unread(OFFER_1) and FinanceManager.offer_unread(OFFER_2),
		"unread")
	tab.open_offer(OFFER_2)
	await _frames(host, 1)
	TestFixtures.check(res, "a known id opens the dialog and answers its row",
		tab.offer_dialog().is_open() and tab.offer_dialog().offer_id() == OFFER_2
		and not FinanceManager.offer_unread(OFFER_2), "%d" % tab.offer_dialog().offer_id())
	tab.offer_dialog().close_window()
	var ids: Array[int] = []
	for row: Dictionary in FinanceManager.offers:
		ids.append(int(row.get("id", -1)))
	for oid: int in ids:
		FinanceManager.reject_offer(oid)
	await _frames(host, 1)
	tab.open_offer(999)
	await _frames(host, 1)
	TestFixtures.check(res, "an empty pending view falls back to the active one",
		tab.view() == LoanRows.VIEW_ACTIVE and not tab.offer_dialog().is_open(),
		"%s" % [tab.view()])
	await _drop(host, tab)


#Case 26: the modals hang off a host above the page, so the page takes them with it.
static func _case_tab_modal_exit(res: Dictionary, host: Node) -> void:
	_fresh()
	var shell: Control = Control.new()
	host.add_child(shell)
	var layer: Control = Control.new()
	layer.name = LoansTab.HOST_CHILD
	layer.add_to_group(LoansTab.HOST_GROUP)
	shell.add_child(layer)
	var pages: Control = Control.new()
	shell.add_child(pages)
	var scene: PackedScene = load(LoansTab.SCENE_PATH) as PackedScene
	var tab: LoansTab = scene.instantiate() as LoansTab
	pages.add_child(tab)
	await _frames(host, 2)
	var window: LoanRequestWindow = tab.request_window()
	TestFixtures.check(res, "the five modals of the page land on the layer above it",
		layer.get_child_count() == 5 and window.get_parent() == layer,
		"%d modals" % layer.get_child_count())
	tab.press_request()
	await _frames(host, 1)
	TestFixtures.check(res, "the request window is open while the page is in the tree",
		window.is_open(), "open")
	pages.remove_child(tab)
	await _frames(host, 1)
	TestFixtures.check(res, "the page closes its modals when it leaves the tree",
		not window.is_open() and not window.visible, "closed")
	pages.add_child(tab)
	await _frames(host, 1)
	tab.press_request()
	await _frames(host, 1)
	TestFixtures.check(res, "the same modals serve the page when it comes back",
		window.is_open() and tab.request_window() == window
		and layer.get_child_count() == 5, "%d modals" % layer.get_child_count())
	var modals: Array[Node] = []
	for node: Node in layer.get_children():
		modals.append(node)
	tab.queue_free()
	await _frames(host, 3)
	var left: int = 0
	for node: Node in modals:
		if is_instance_valid(node):
			left += 1
	TestFixtures.check(res, "freeing the page frees the modals it left on the layer",
		left == 0 and layer.get_child_count() == 0, "%d left" % left)
	await _drop(host, shell)


#Case 27: a bound dragged past the other one. The side that moved keeps its value.
static func _case_tab_push(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await _frames(host, 1)
	tab.press_view(LoanRows.VIEW_PENDING)
	tab.set_filter("monthly", 100.0, 200.0)
	tab.set_filter("monthly", 250.0, 200.0)
	TestFixtures.check(res, "a Min dragged over the Max pushes the Max up",
		_range_is(tab, "monthly", 250.0, 250.0), "%s" % [tab.ranges()])
	tab.set_filter("monthly", 100.0, 200.0)
	tab.set_filter("monthly", 100.0, 50.0)
	TestFixtures.check(res, "a Max dragged under the Min pulls the Min down",
		_range_is(tab, "monthly", 50.0, 50.0), "%s" % [tab.ranges()])
	tab.set_filter("monthly", 100.0, 200.0)
	tab.set_filter("monthly", 120.0, 200.0)
	TestFixtures.check(res, "a bound that crosses nothing moves on its own",
		_range_is(tab, "monthly", 120.0, 200.0), "%s" % [tab.ranges()])
	tab.set_filter("monthly", 100.0, 200.0)
	tab.filter_popup().set_slider("monthly", false, 250.0)
	TestFixtures.check(res, "the Min slider carries the Max slider up with it",
		_range_is(tab, "monthly", 250.0, 250.0) and _slider_at(tab, "monthly", true, 250.0)
		and _slider_at(tab, "monthly", false, 250.0), "%s" % [tab.ranges()])
	tab.set_filter("monthly", 100.0, 200.0)
	tab.filter_popup().set_slider("monthly", true, 50.0)
	TestFixtures.check(res, "the Max slider carries the Min slider down with it",
		_range_is(tab, "monthly", 50.0, 50.0) and _slider_at(tab, "monthly", true, 50.0)
		and _slider_at(tab, "monthly", false, 50.0), "%s" % [tab.ranges()])
	tab.reset_filters()
	TestFixtures.check(res, "Reset clears the range that was pushed",
		tab.ranges().is_empty() and tab.card_count() == 4, "%d cards" % tab.card_count())
	await _drop(host, tab)


#Case 28: the envoy crew of the request window: its texts, its lock and its link.
static func _case_tab_crew(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await _frames(host, 1)
	tab.press_request()
	await _frames(host, 1)
	var window: LoanRequestWindow = tab.request_window()
	var crew: OddJobCrew = window.crew()
	TestFixtures.check(res, "the crew names the odd job it sends",
		crew != null and crew.tip_kind == "Loan Envoy", crew.tip_kind)
	TestFixtures.check(res, "the crew tip is the line of the prototype",
		crew.tip_text == "Send a merc to \"persuade\" the lenders to give you a good rate.",
		crew.tip_text)
	var pick: String = "Sorted by best fit. Performer and Warrior traditions, "
	pick += "Wile and Vigor raise approval odds."
	TestFixtures.check(res, "the picker says what raises the approval odds",
		crew.pick_desc == pick, crew.pick_desc)
	SubscriptionManager.set_entitlements({"oddJobs": 0})
	window.close_window()
	tab.press_request()
	await _frames(host, 1)
	TestFixtures.check(res, "no odd job slot locks the crew of the window",
		window.locked_crew() and crew.locked and crew.max_mercs == 0, "locked")
	var seen: Array[Dictionary] = []
	var grab := func(target: Dictionary) -> void:
		seen.append(target)
	GameState.go_to_plans_requested.connect(grab)
	crew.take_me_there.emit({"page": "plans", "row": "oddJobs"})
	await _frames(host, 1)
	TestFixtures.check(res, "Take me there closes the window and asks for the Plans page",
		not window.is_open() and seen.size() == 1
		and String(seen[0].get("row", "")) == "oddJobs", "%s" % [seen])
	GameState.go_to_plans_requested.disconnect(grab)
	SubscriptionManager.reset()
	await _drop(host, tab)


#Counts engine error lines that name a previously freed object; hears them through OS.add_logger.
class _FreedLogger extends Logger:
	var hits: int = 0

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) \
			-> void:
		if code.contains("previously freed") or rationale.contains("previously freed"):
			hits += 1


#Builds root -> [page, ModalLayer] off the tree first (page as the first child, the layer as a
#later one) so the layer already exists when the whole subtree enters the tree together and the
#page's _ready() (called synchronously by that add_child) finds it: _ready() runs on add_child
#when the parent is already inside a tree, so a layer added after the page would still be missing
#when _build_modals() looks for it and the page would fall back to itself as its own host.
static func _stub_host(host: Node) -> Array:
	var root: Control = Control.new()
	var scene: PackedScene = load(LoansTab.SCENE_PATH) as PackedScene
	var tab: LoansTab = scene.instantiate() as LoansTab
	root.add_child(tab)
	var layer: Control = Control.new()
	layer.name = LoansTab.HOST_CHILD
	layer.add_to_group(LoansTab.HOST_GROUP)
	root.add_child(layer)
	host.add_child(root)
	return [root, tab, layer]


#Case 29: the modal host is freed before the page gets NOTIFICATION_PREDELETE, so the five
#members hold freed objects when _modals() runs; reading them must print no engine error line.
static func _case_tab_freed_host(res: Dictionary, host: Node) -> void:
	_fresh()
	var freed_log: _FreedLogger = _FreedLogger.new()
	var built_a: Array = _stub_host(host)
	var root_a: Control = built_a[0] as Control
	var layer_a: Control = built_a[2] as Control
	await _frames(host, 2)
	TestFixtures.check(res, "the stub host of case a holds the five modals",
		layer_a.get_child_count() == 5, "%d modals" % layer_a.get_child_count())
	OS.add_logger(freed_log)
	root_a.free()
	OS.remove_logger(freed_log)
	TestFixtures.check(res, "freeing the root before the page raises no freed-object engine error",
		freed_log.hits == 0, "%d hits" % freed_log.hits)
	freed_log.hits = 0
	var built_b: Array = _stub_host(host)
	var root_b: Control = built_b[0] as Control
	var tab_b: LoansTab = built_b[1] as LoansTab
	var layer_b: Control = built_b[2] as Control
	await _frames(host, 2)
	TestFixtures.check(res, "the stub host of case b holds the five modals",
		layer_b.get_child_count() == 5, "%d modals" % layer_b.get_child_count())
	OS.add_logger(freed_log)
	layer_b.free()
	tab_b.free()
	OS.remove_logger(freed_log)
	TestFixtures.check(res, "freeing the modal host then the page raises no freed-object engine error",
		freed_log.hits == 0, "%d hits" % freed_log.hits)
	await _drop(host, root_b)


#Case 30: an odd job pay total the guild cannot afford blocks the request.
static func _case_tab_pay_cap(res: Dictionary, host: Node) -> void:
	_fresh()
	var tab: LoansTab = _spawn(host, LoansTab.SCENE_PATH) as LoansTab
	await _frames(host, 1)
	tab.press_request()
	await _frames(host, 1)
	var window: LoanRequestWindow = tab.request_window()
	var crew: OddJobCrew = window.crew()
	TestFixtures.check(res, "a request with no envoy to pay for can be sent",
		window.can_send() and not window.request_button().disabled,
		"disabled %s" % [window.request_button().disabled])
	crew.per = MONEY + 500
	crew.team = _uids(1)
	await _frames(host, 1)
	TestFixtures.check(res, "a pay total over the bank notes blocks the request",
		not window.can_send() and window.request_button().disabled
		and window.pay_total() > GameState.bank_notes,
		"%d of %d, disabled %s" % [window.pay_total(), GameState.bank_notes,
			window.request_button().disabled])
	TestFixtures.check(res, "the blocked request button says why it is blocked",
		window.request_button().tooltip_text == LoanRequestWindow.MONEY_BLOCK,
		window.request_button().tooltip_text)
	window.press_request()
	await _frames(host, 1)
	var confirm: LoanRequestConfirm = tab.request_confirm()
	TestFixtures.check(res, "a blocked request opens no confirm at all",
		confirm == null or not confirm.is_open(),
		"open %s" % [confirm != null and confirm.is_open()])
	crew.per = 10
	await _frames(host, 1)
	TestFixtures.check(res, "a pay total back under the bank notes frees the request",
		window.can_send() and not window.request_button().disabled
		and window.request_button().tooltip_text == "",
		"%d of %d" % [window.pay_total(), GameState.bank_notes])
	await _drop(host, tab)


#Case 31: the odd job window commits and dismisses through the core action button.
static func _case_odd_job_buttons(res: Dictionary, host: Node) -> void:
	_fresh()
	var window: OddJobWindow = _spawn(host,
		"res://Scenes/GUI/Shared/OddJobWindow.tscn") as OddJobWindow
	await _frames(host, 1)
	var send: BevelButton = window.send_button as BevelButton
	var cancel: BevelButton = window.cancel_button as BevelButton
	TestFixtures.check(res, "the odd job window sends through a core bevel button",
		send != null and send.kind == &"go" and send.fill.is_equal_approx(OddJobWindow.SEND_BG),
		"%s" % [&"" if send == null else send.kind])
	TestFixtures.check(res, "the odd job window dismisses through a core bevel button",
		cancel != null and cancel.kind == &"blue"
		and cancel.fill.is_equal_approx(OddJobWindow.CANCEL_BG),
		"%s" % [&"" if cancel == null else cancel.kind])
	TestFixtures.check(res, "both keep the 42 px height of the prototype",
		send != null and cancel != null and is_equal_approx(send.custom_minimum_size.y, 42.0)
		and is_equal_approx(cancel.custom_minimum_size.y, 42.0),
		"%s" % [Vector2.ZERO if send == null else send.custom_minimum_size])
	await _drop(host, window)

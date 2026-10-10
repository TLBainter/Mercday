class_name MailEffectsTests

#Mail plan M2: the fx tokens MailCenter.choose applies, bills, the income tooltip and the opinion targets.
#Run from GuiMailTests under the gui-mail-tests flag.

const PROJECTION: PackedScene = preload("res://Scenes/GUI/Finance/Overview/FinanceProjection.tscn")
const GIFT: int = 75
const FEE: int = 50
const SHORT_BANK: int = 3
const RENT: int = 400
const SAT_START: int = 50


static func run(res: Dictionary, host: Node) -> void:
	_case_money(res)
	await _case_tooltip(res, host)
	_case_bills(res)
	await _case_notice(res)
	_case_opinion(res)
	_case_rel(res)
	_case_read_rows(res)


#A fixture catalog plus extra rows, and a fresh mailbox over it.
static func _boot_with(extra: Array[Dictionary]) -> void:
	GuiMailTests._fresh()
	var warnings: PackedStringArray = GuiMailTests._with(extra)
	if not warnings.is_empty():
		push_error("MailEffectsTests fixture warnings: %s" % [warnings])
	MailCenter.reset()


#The authored rows plus the sample rows, with the start-row queue emptied, so only the mail a case delivers arrives.
static func _boot_real() -> void:
	GuiMailTests._fresh()
	sample_catalog()
	MailCenter.reset()
	MailCenter._due.clear()


#The live catalog becomes the authored rows plus the sample rows, with no new campaign.
static func sample_catalog() -> void:
	var rows: Array[Dictionary] = TsvReader.load_header_rows(MailCatalog.MAIL_TSV)
	rows.append_array(samples())
	var warnings: PackedStringArray = MailCatalog.parse_rows(rows)
	if not warnings.is_empty():
		push_error("MailEffectsTests sample warnings: %s" % [warnings])


#Test copies of the Mail.tsv sample rows the designer removed on 2026-10-09 (cards 734 and 735).
static func samples() -> Array[Dictionary]:
	var bill: Dictionary = {"Folder": "Bills", "Bill Id": "rent_m8", "Amount": "400", "Due": "14",
		"Option 1": "Pay Now", "Next 1": "B1A", "Fx 1": "pay"}
	var remind: Dictionary = bill.duplicate()
	remind.merge({"Subject": "Reminder: rent due {date}", "Body": "{amount} notes are due on {date}.",
		"Delay Min": "2|0|0"}, true)
	bill.merge({"Subject": "Guild Hall rent, Month 8", "Body": "Rent for Month 8 is {amount} notes, due {date}.",
		"Option 2": "Remind Me Later", "Next 2": "B1R"}, true)
	return [GuiMailTests._cells("I1", "mercday", {"Subject": "Your Mercday Pro plan renews soon",
			"Body": "Your plan renews on {sub_due} for {sub_amount} notes.", "Read": "TRUE",
			"Bill Id": "mercday_renew", "Option 1": "Ok"}),
		GuiMailTests._cells("B1", "landlord", bill), GuiMailTests._cells("B1R", "landlord", remind),
		GuiMailTests._cells("B1A", "landlord", {"Folder": "Bills", "Body": "Received {amount} notes. Thank you.",
			"Delay Min": "0|1|0", "Bill Id": "rent_m8", "Option 1": "Ok"}),
		GuiMailTests._cells("N3", "herald", {"Folder": "News", "Read": "TRUE", "Option 1": "Ok"})]


static func _one(id: String, fx: String, sender: String = "landlord") -> Dictionary:
	return GuiMailTests._cells(id, sender, {"Option 1": "Take It", "Fx 1": fx})


static func _case_money(res: Dictionary) -> void:
	var rows: Array[Dictionary] = [_one("MG", "money:%d" % GIFT), _one("MF", "money:-%d" % FEE)]
	_boot_with(rows)
	var expenses: int = GameState._day_expenses
	var income: int = FinanceLedger.income_in(FinanceLedger.RATE_DAYS)
	var bank: int = GameState.bank_notes
	var gift: MailInstance = MailCenter.deliver(&"MG")
	MailCenter.choose(gift.id, 0)
	TestFixtures.check(res, "13 money:+N refunds with REASON_MAIL: _day_expenses unchanged, income_in(30) rises by N",
		GameState._day_expenses == expenses and FinanceLedger.income_in(FinanceLedger.RATE_DAYS) == income + GIFT
			and GameState.bank_notes == bank + GIFT,
		"expenses %d -> %d income %d -> %d" % [expenses, GameState._day_expenses, income,
			FinanceLedger.income_in(FinanceLedger.RATE_DAYS)])
	var lines: Array[Dictionary] = FinanceLedger.income_lines()
	var heading: int = -1
	var gifts: int = -1
	for i: int in lines.size():
		if String(lines[i]["label"]) == FinanceLedger.OTHER_CATEGORY and int(lines[i]["amount"]) < 0:
			heading = i
		elif String(lines[i]["label"]) == MailEffects.GIFT_LABEL and int(lines[i]["amount"]) == GIFT:
			gifts = i
	TestFixtures.check(res, "14 income_lines lists an Other heading with a Gifts line for a mail credit",
		heading >= 0 and gifts > heading, "%s" % [lines])
	var settled: int = GameState.bank_notes
	MailCenter.choose(gift.id, 0)
	TestFixtures.check(res, "18 second choose on an answered mail is ignored",
		GameState.bank_notes == settled and gift.choice == 0, "bank %d -> %d" % [settled, GameState.bank_notes])
	GameState.bank_notes = SHORT_BANK
	var fee: MailInstance = MailCenter.deliver(&"MF")
	MailCenter.choose(fee.id, 0)
	TestFixtures.check(res, "15 money:-N charges even when funds are short",
		GameState.bank_notes == SHORT_BANK - FEE and fee.choice == 0, "bank %d" % GameState.bank_notes)


#53: the Expected Income row hover fills the tooltip from income_lines.
static func _case_tooltip(res: Dictionary, host: Node) -> void:
	_boot_with([_one("MG", "money:%d" % GIFT)])
	MailCenter.choose(MailCenter.deliver(&"MG").id, 0)
	await host.get_tree().process_frame
	var proj: FinanceProjection = PROJECTION.instantiate() as FinanceProjection
	host.add_child(proj)
	await host.get_tree().process_frame
	var line: ValueRow = proj._rows.get(FinanceProjection.INCOME_KEY, null)
	var shown: bool = false
	var got: Array[String] = []
	if line != null:
		(line.get_parent() as Control).mouse_entered.emit()
		shown = proj.tooltip().visible
		got = proj.tooltip().line_texts()
	var want: Array[String] = []
	for row: Dictionary in FinanceLedger.income_lines():
		var amount: int = int(row["amount"])
		var label: String = String(row["label"])
		want.append(label if amount < 0 else "%s: %s" % [label, TooltipPanel.line_amount_text(amount)])
	TestFixtures.check(res, "53 Projection Expected Income row hover shows the income_lines tooltip",
		line != null and shown and got == want and want.has("%s: %s" % [MailEffects.GIFT_LABEL,
			TooltipPanel.line_amount_text(GIFT)]),
		"row %s shown %s got %s want %s" % [line != null, shown, got, want])
	proj.queue_free()
	await host.get_tree().process_frame


static func _case_bills(res: Dictionary) -> void:
	TestFixtures.check(res, "33 bill status rule: no due date means PAID, pay option means UNPAID, else AUTO",
		Bill.status_for(-1, true) == Bill.Status.PAID and Bill.status_for(5, true) == Bill.Status.UNPAID
			and Bill.status_for(5, false) == Bill.Status.AUTO,
		"%d %d %d" % [Bill.status_for(-1, true), Bill.status_for(5, true), Bill.status_for(5, false)])
	_boot_real()
	var bank: int = GameState.bank_notes
	var rent: MailInstance = MailCenter.deliver(&"B1")
	var unpaid: bool = rent != null and rent.bill != null and rent.bill.status == Bill.Status.UNPAID
	MailCenter.choose(rent.id, 0)
	var again: MailInstance = MailCenter.deliver(&"B1R", rent.id)
	MailCenter.choose(again.id, 0)
	TestFixtures.check(res, "16 pay marks a mail-native bill paid and charges the amount once",
		unpaid and rent.bill.status == Bill.Status.PAID and GameState.bank_notes == bank - RENT,
		"unpaid %s status %d bank %d -> %d" % [unpaid, rent.bill.status, bank, GameState.bank_notes])
	_boot_real()
	var first: MailInstance = MailCenter.deliver(&"B1")
	var due: int = first.received_day + int(MailCatalog.row(&"B1")["due"])
	MailCenter.choose(first.id, 1)
	MailCenter.tick(CampaignClock.advance(2 * CampaignClock.MINUTES_PER_DAY))
	var reminder: MailInstance = GuiMailTests._find(&"B1R")
	var threaded: bool = reminder != null and reminder.parent == first.id
	if reminder != null:
		MailCenter.choose(reminder.id, 0)
	var bills: Array[Bill] = MailCenter.bills_between(0, due + TrynnCalendar.DAYS_PER_YEAR)
	TestFixtures.check(res, "48 B1R arrives 2 days after Remind; paying it makes B1 PAID; one rent_m8 Bill, due fixed at B1",
		threaded and first.bill.status == Bill.Status.PAID and reminder.bill == first.bill and bills.size() == 1
			and bills[0].bill_id == &"rent_m8" and bills[0].due_day == due,
		"threaded %s status %d bills %d due %d want %d" % [threaded, first.bill.status, bills.size(),
			bills[0].due_day if not bills.is_empty() else -1, due])


#17: the Mercday notice is AUTO; the ledger owns the subscription charge, so no mail money moves.
static func _case_notice(res: Dictionary) -> void:
	_boot_real()
	var moved: Array[int] = [0]
	var spy: Callable = func(_delta: int, reason: String, _label: String) -> void:
		if reason == GameState.REASON_MAIL:
			moved[0] += 1
	GameState.money_logged.connect(spy)
	var notice: MailInstance = MailCenter.deliver(&"I1")
	var on_arrival: int = moved[0]
	var cost: int = SubscriptionManager.monthly_cost()
	var due: int = GameState.day() + FinanceLedger.next_in(SubscriptionManager.BILL_DAY)
	var body: String = MailText.fill(String(MailCatalog.row(&"I1")["body"]), notice)
	var bill: Bill = notice.bill
	var auto: bool = bill != null and bill.status == Bill.Status.AUTO and bill.amount == cost and bill.due_day == due
	await GameState.process_until(due * CampaignClock.MINUTES_PER_DAY + 12 * 60)
	GameState.money_logged.disconnect(spy)
	TestFixtures.check(res, "17 an AUTO notice (I1) charges nothing on delivery or due day; tokens match the plan",
		auto and on_arrival == 0 and moved[0] == 0 and body.contains(TransactionData.grouped(cost))
			and body.contains(GuiDates.short_text(due)),
		"auto %s moved %d/%d body '%s'" % [auto, on_arrival, moved[0], body])


static func _case_opinion(res: Dictionary) -> void:
	_boot_with([_one("OP", "opinion:0:99"), _one("O1", "opinion:1:-1")])
	TestFixtures.add_mercs(maxi(0, 3 - GameState.mercs.size()))
	for m: MercenaryData in GameState.mercs:
		m.guild_opinion = 0
	var target: MercenaryData = GameState.merc_by_uid(MailSenders.merc_uid_for("merc0"))
	MailCenter.choose(MailCenter.deliver(&"OP").id, 0)
	TestFixtures.check(res, "26 opinion:MERC:N clamps at OPINION_MAX",
		target != null and target.guild_opinion == SalarySystem.OPINION_MAX,
		"opinion %d" % (target.guild_opinion if target != null else -99))
	var shown: MercView = GameState.view_by_uid(target.merc_uid) if target != null else null
	TestFixtures.check(res, "26 the roster view shows the new opinion right after the choice",
		shown != null and shown.guild_opinion == target.guild_opinion,
		"view %d merc %d" % [shown.guild_opinion if shown != null else -99, target.guild_opinion if target != null else -99])
	for m: MercenaryData in GameState.mercs:
		m.guild_opinion = 0
	var asker: MercenaryData = GameState.mercs[2]
	var req: VacationRequest = GuiVacationTests._row(asker.merc_uid, GameState.day() + 50, 3,
		VacationRequest.State.PENDING)
	BenefitsManager.book.rows.append(req)
	var vac: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	MailCenter.choose(vac.id, 1)
	var others: bool = true
	for m: MercenaryData in GameState.mercs:
		if m != asker and m.guild_opinion != 0:
			others = false
	TestFixtures.check(res, "26 opinion:0:N on a merc0 request hits the requesting merc, no one else",
		req.state == VacationRequest.State.DENIED and asker.guild_opinion == -1 and others,
		"state %d asker %d others %s" % [req.state, asker.guild_opinion, others])
	var named: MercenaryData = GameState.merc_by_uid(MailSenders.merc_uid_for("merc1"))
	var named_before: int = named.guild_opinion
	MailCenter.choose(MailCenter.deliver(&"O1").id, 0)
	TestFixtures.check(res, "26 opinion:1:N from a non-merc sender hits mercK on the roster; null merc moves nothing",
		named.guild_opinion == named_before - 1 and SalarySystem.adjust_opinion(null, 5) == 0,
		"opinion %d -> %d" % [named_before, named.guild_opinion])


static func _case_rel(res: Dictionary) -> void:
	_boot_with([_one("RL", "rel:person5:1")])
	var seat: int = ContractIssuer.seat_id("people", 4)
	var held: bool = IssuerOpinion.seats.has(seat)
	if held:
		IssuerOpinion._set_satisfaction(seat, SAT_START)
	var before: int = IssuerOpinion.face(seat)
	var mail: MailInstance = MailCenter.deliver(&"RL")
	MailCenter.choose(mail.id, 0)
	TestFixtures.check(res, "27 rel:person5:1 moves IssuerOpinion.face(seat_id(people, 4)) by 1",
		held and IssuerOpinion.face(seat) == before + 1, "held %s face %d -> %d" % [held, before,
			IssuerOpinion.face(seat)])
	var option: Dictionary = MailCatalog.options(&"RL")[0]
	var fx: PackedStringArray = option["fx"]
	var label: String = String(option["label"]).to_lower()
	TestFixtures.check(res, "28 a rel-only option: cost 0, tone 0 and no rel text in its label",
		MailEffects.cost(mail, fx) == 0 and MailEffects.tone(fx) == 0 and not label.contains("rel")
			and not label.contains("person"),
		"cost %d tone %d label '%s'" % [MailEffects.cost(mail, fx), MailEffects.tone(fx), label])


static func _case_read_rows(res: Dictionary) -> void:
	_boot_real()
	var news: MailInstance = MailCenter.deliver(&"N3")
	TestFixtures.check(res, "49 a Read row with one option (N3) arrives answered",
		news != null and news.read and news.choice == 0 and news.choice_day == news.received_day
			and news.choice_minute == news.received_minute,
		"read %s choice %d" % [news.read if news != null else false, news.choice if news != null else -9])
	var emits: Array[int] = [0]
	var spy: Callable = func() -> void: emits[0] += 1
	MailCenter.changed.connect(spy)
	MailCenter.mark_read(news.id)
	var quiet: int = emits[0]
	var rent: MailInstance = MailCenter.deliver(&"B1")
	emits[0] = 0
	MailCenter.mark_read(rent.id)
	MailCenter.changed.disconnect(spy)
	TestFixtures.check(res, "mark_read on a read mail emits no changed; on an unread one it emits once",
		quiet == 0 and emits[0] == 1, "read %d unread %d" % [quiet, emits[0]])

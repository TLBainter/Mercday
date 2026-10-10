class_name GuiMailTests

#Mail data and service: MailCatalog parse and validation, MailSenders, MailText and the MailCenter store,
#due queue, archive and threads. Fixture rows are built here. Run with the gui-mail-tests harness flag.

const ROLLS: int = 20
const ROLL_SEED: int = 4242
const EXACT_DELAY: int = 90
const RANGE_MIN: int = 60
const RANGE_MAX: int = 1440
const I2_MINUTE: int = 500
const VAC_LEAD: int = 3
const VAC_DAYS: int = 5


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_catalog(res)
	_case_senders(res)
	_case_delay(res)
	await _case_start_row(res)
	await _case_follow_up(res)
	_case_read_archive(res)
	await _case_threads(res)
	_case_text(res)
	_case_reset(res)
	_case_ranges(res)
	await AutoFurloughTests.run(res)
	VacationDesireTests.run(res)
	await GuiVacationTests.run(res)
	await MailEffectsTests.run(res, host)
	await VacationRestTests.run(res)
	await OptimizeVacationTests.run(res, host)
	await MailViewTests.run(res, host)
	await MailBlockTests.run(res, host)
	await MailHudTests.run(res, host)
	await MailHelpTests.run(res, host)
	MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	_fresh()
	return TestFixtures.summarize(res, "GUI MAIL")


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


#A fresh campaign whose mail runs on the fixture rows.
static func _boot() -> void:
	_fresh()
	MailCatalog.parse_rows(_fixture())
	MailCenter.reset()


static func _cells(id: String, sender: String, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"Id": id, "Folder": "Inbox", "Sender": sender, "Subject": "S " + id, "Body": "B " + id}
	out.merge(extra, true)
	return out


static func _fixture() -> Array[Dictionary]:
	var vac: Dictionary = {"Folder": "Requests", "Option 1": "Approve", "Next 1": "R1A", "Fx 1": "vac:approve",
		"Option 2": "Deny", "Next 2": "", "Fx 2": "vac:deny;opinion:0:-1", "Option 3": "Later", "Fx 3": "vac:shift:10"}
	var rows: Array[Dictionary] = [_cells("R1", "merc0", vac), _cells("R1M", "merc0", vac), _cells("R1X", "merc0"),
		_cells("R1C", "merc0"), _cells("R1A", "merc0", {"Folder": "Requests", "Delay Min": "0|2|0", "Option 1": "Ok"}),
		_cells("I1", "mercday", {"Start Day": "0", "Start Time": "09:00", "Read": "TRUE", "Bill Id": "sub",
			"Option 1": "Ok"}),
		_cells("I2", "org3", {"Start Day": "1", "Start Time": "08:20", "Option 1": "Ok", "Fx 1": "rel:org3:1"}),
		_cells("M5", "merc5", {"Folder": "Requests"}),
		_cells("B1", "landlord", {"Folder": "Bills", "Bill Id": "rent", "Amount": "400", "Due": "14",
			"Option 1": "Pay Now", "Fx 1": "pay;money:-5"}),
		_cells("F1", "landlord", {"Start Day": "0", "Start Time": "08:30", "Option 1": "Exact", "Next 1": "FX",
			"Option 2": "Range", "Next 2": "FR"}),
		_cells("FX", "landlord", {"Delay Min": "0|1|30", "Delay Max": "0|1|30", "Option 1": "Again", "Next 1": "FR"}),
		_cells("FR", "landlord", {"Delay Min": "0|1|0", "Delay Max": "1|0|0"})]
	return rows


static func _with(extra_rows: Array[Dictionary], drop: String = "") -> PackedStringArray:
	var rows: Array[Dictionary] = []
	for cells: Dictionary in _fixture():
		if String(cells["Id"]) != drop:
			rows.append(cells)
	rows.append_array(extra_rows)
	return MailCatalog.parse_rows(rows)


static func _warned(warnings: PackedStringArray, needle: String) -> bool:
	for line: String in warnings:
		if line.contains(needle):
			return true
	return false


#The newest delivered mail of a row, live or archived; null when none has arrived.
static func _find(def_id: StringName) -> MailInstance:
	for folder: StringName in MailCatalog.FOLDERS:
		for archived: bool in [false, true]:
			for mail: MailInstance in MailCenter.mail_in(folder, archived):
				if mail.def_id == def_id:
					return mail
	return null


static func _case_catalog(res: Dictionary) -> void:
	var clean: PackedStringArray = MailCatalog.parse_rows(_fixture())
	TestFixtures.check(res, "1 the fixture rows parse with no warnings", clean.is_empty(), "%s" % [clean])
	var bad_fx: PackedStringArray = _with([_cells("X1", "mercday", {"Option 1": "A", "Fx 1": "bogus:1",
		"Option 2": "B", "Fx 2": "delete"})])
	TestFixtures.check(res, "2 an unknown fx token and a delete token both warn",
		_warned(bad_fx, "bogus:1: unknown") and _warned(bad_fx, "delete: no delete"), "%s" % [bad_fx])
	var bad_link: PackedStringArray = _with([_cells("X2", "org10", {"Option 1": "A", "Next 1": "NOPE"})])
	TestFixtures.check(res, "3 a Next with no row and a seat sender off the layout both warn",
		_warned(bad_link, "Next NOPE has no row") and _warned(bad_link, "unknown sender org10"), "%s" % [bad_link])
	var missing: Array[String] = []
	for id: StringName in MailCatalog.TEMPLATES:
		if not _warned(_with([], String(id)), "%s: vacation template row missing" % id):
			missing.append(String(id))
	TestFixtures.check(res, "67 a missing R1, R1M, R1X or R1C row warns", missing.is_empty(), "%s" % [missing])
	var authored: PackedStringArray = MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	TestFixtures.check(res, "the authored Mail.tsv parses with no warnings", authored.is_empty(), "%s" % [authored])


static func _case_senders(res: Dictionary) -> void:
	_boot()
	var registry: ClientRegistry = ClientRegistry.from_game()
	var seats: Array[ClientData] = [registry.client(&"orgs", 8), registry.client(&"people", 7)]
	var resolved: Array = [MailCatalog.sender("org9"), MailCatalog.sender("person8")]
	var want: Array[String] = []
	var got: Array[String] = []
	for i: int in range(seats.size()):
		want.append("%s %s" % [seats[i].key(), seats[i].name] if seats[i] != null else "none")
		got.append("%s %s" % [(resolved[i] as ClientData).key(), (resolved[i] as ClientData).name]
			if resolved[i] is ClientData else "none")
	TestFixtures.check(res, "4 org9 and person8 resolve to the ClientData of seat_id(orgs, 8) and seat_id(people, 7)",
		got == want and want[0].begins_with("orgs:8 ") and want[1].begins_with("people:7 ")
		and ContractIssuer.seat_id("orgs", 8) == MailSenders.seat_of("org9")
		and ContractIssuer.seat_id("people", 7) == MailSenders.seat_of("person8"), "%s vs %s" % [got, want])
	var table: Object = MailCatalog.sender("landlord")
	TestFixtures.check(res, "a Mail Senders.tsv id resolves to its ClientData row",
		table is ClientData and (table as ClientData).name == "Landlord Name"
		and (table as ClientData).kind_label == "Person" and MailCatalog.sender("nobody") == null, "%s" % [table])
	TestFixtures.add_mercs(maxi(3 - GameState.roster.size(), 0))
	GameState.refresh_views()
	var size: int = GameState.roster.size()
	GameState.roster.resize(3)
	var uid: int = MailSenders.merc_uid_for("merc5")
	var mail: MailInstance = MailCenter.deliver(&"M5")
	var who: Object = MailCatalog.sender("merc5", mail.merc_uid) if mail != null else null
	TestFixtures.check(res, "5 merc5 with 3 mercs wraps to roster_uids()[2] and resolves to that MercenaryData",
		size >= 3 and uid == GameState.roster_uids()[2] and mail != null and mail.merc_uid == uid
		and who is MercenaryData and (who as MercenaryData).merc_uid == uid, "roster %d uid %d" % [size, uid])
	GameState.roster.clear()
	var before: int = MailCenter.mail_in(&"requests").size()
	var skipped: MailInstance = MailCenter.deliver(&"M5")
	TestFixtures.check(res, "6 an empty roster skips merc mail",
		skipped == null and MailCenter.mail_in(&"requests").size() == before, "delivered %s" % [skipped])
	GameState.refresh_views()


static func _case_delay(res: Dictionary) -> void:
	var values: Array[int] = [MailCatalog.parse_delay("1|4|30"), MailCatalog.parse_delay("0|0|0"),
		MailCatalog.parse_delay(""), MailCatalog.parse_delay("1|4"), MailCatalog.parse_delay("a|b|c")]
	var warned: PackedStringArray = _with([_cells("X3", "mercday", {"Delay Min": "1|4"}),
		_cells("X4", "mercday", {"Delay Min": "a|b|c"})])
	TestFixtures.check(res, "8 parse_delay reads D|H|M and a malformed cell warns",
		values == [1710, 0, 0, -1, -1] and _warned(warned, "X3: bad Delay") and _warned(warned, "X4: bad Delay"),
		"%s %s" % [values, warned])
	var under: PackedStringArray = _with([_cells("X5", "mercday", {"Delay Min": "0|2|0", "Delay Max": "0|1|0"}),
		_cells("X6", "mercday", {"Delay Min": "0|3|0"})])
	var low: Dictionary = MailCatalog.row(&"X5")
	var blank: Dictionary = MailCatalog.row(&"X6")
	TestFixtures.check(res, "9 Max under Min warns and uses Min; a blank Max equals Min",
		_warned(under, "X5: bad Delay") and int(low["delay_max"]) == 120 and int(blank["delay_max"]) == 180
		and int(blank["delay_min"]) == 180, "%s %s %s" % [under, low, blank])


static func _case_start_row(res: Dictionary) -> void:
	_boot()
	var minute: int = (GameState.day() + 1) * TrynnCalendar.MINUTES_PER_DAY + I2_MINUTE
	await GameState.process_until(minute - 1)
	var early: bool = _find(&"I2") != null
	await GameState.process_until(minute)
	var mail: MailInstance = _find(&"I2")
	TestFixtures.check(res, "7 a start-day row delivers on its day at its HH:MM minute (I2 at minute 500)",
		not early and mail != null and mail.received_minute == minute
		and mail.received_minute % TrynnCalendar.MINUTES_PER_DAY == I2_MINUTE, "early %s mail %s" % [early, mail])


static func _case_follow_up(res: Dictionary) -> void:
	_boot()
	await GameState.process_until(TrynnCalendar.START_MINUTE + 30)
	var first: MailInstance = _find(&"F1")
	var now: int = CampaignClock.now()
	MailCenter.choose(first.id, 0)
	await GameState.process_until(now + EXACT_DELAY - 1)
	var early: bool = _find(&"FX") != null
	await GameState.process_until(now + EXACT_DELAY)
	var exact: MailInstance = _find(&"FX")
	TestFixtures.check(res, "10 a follow-up with Min = Max lands at exactly that minute, not before",
		not early and exact != null and exact.received_minute == now + EXACT_DELAY, "early %s" % early)
	MailCenter.rolls.seed = ROLL_SEED
	var start: int = CampaignClock.now()
	for _i: int in range(ROLLS):
		MailCenter.choose(MailCenter.deliver(&"F1").id, 1)
	await GameState.process_until(start + RANGE_MAX)
	var minutes: Array[int] = []
	for mail: MailInstance in MailCenter.mail_in(&"inbox"):
		if mail.def_id == &"FR":
			minutes.append(mail.received_minute - start)
	var inside: bool = minutes.size() == ROLLS and minutes.all(func(m: int) -> bool:
		return m >= RANGE_MIN and m <= RANGE_MAX) and minutes.min() != minutes.max()
	TestFixtures.check(res, "11 a ranged follow-up lands inside [Min, Max] over 20 seeded rolls", inside,
		"%s" % [minutes])


static func _case_read_archive(res: Dictionary) -> void:
	_boot()
	var mail: MailInstance = MailCenter.deliver(&"F1")
	var read_one: MailInstance = MailCenter.deliver(&"I1")
	var counts: Array[int] = [MailCenter.unread(&"inbox"), MailCenter.unread(), MailCenter.unread(&"bills")]
	MailCenter.mark_read(mail.id)
	TestFixtures.check(res, "12 unread counts live unread mail per folder and mark_read clears it",
		counts == [1, 1, 0] and read_one.read and MailCenter.unread(&"inbox") == 0, "%s" % [counts])
	var other: MailInstance = MailCenter.deliver(&"F1")
	MailCenter.archive(other.id)
	var archived: bool = not MailCenter.mail_in(&"inbox").has(other) and MailCenter.mail_in(&"inbox", true).has(other)
	MailCenter.restore(other.id)
	TestFixtures.check(res, "29 archive moves a mail to the archived list and marks it read; restore brings it back",
		archived and other.read and MailCenter.mail_in(&"inbox").has(other) and not other.archived, "%s" % archived)
	_with([_cells("X7", "landlord", {"Option 1": "A", "Next 1": "GONE"})])
	var orphan: MailInstance = MailCenter.deliver(&"X7")
	var count: int = MailCenter.mail_in(&"inbox").size()
	MailCenter.choose(orphan.id, 0)
	TestFixtures.check(res, "a choice whose Next row is missing records the answer and queues nothing",
		orphan.choice == 0 and MailCenter.mail_in(&"inbox").size() == count, "choice %d" % orphan.choice)
	MailCatalog.parse_rows(_fixture())


static func _case_threads(res: Dictionary) -> void:
	_boot()
	var root: MailInstance = MailCenter.deliver(&"F1")
	MailCenter.choose(root.id, 0)
	MailCenter.archive(root.id)
	var unread_live: int = MailCenter.unread()
	await GameState.process_until(CampaignClock.now() + EXACT_DELAY)
	var child: MailInstance = _find(&"FX")
	TestFixtures.check(res, "30 unread ignores archived mail; its follow-up arrives live with the parent kept",
		unread_live == 0 and child != null and not child.archived and child.parent == root.id
		and MailCenter.get_mail(root.id) == root and root.archived, "unread %d" % unread_live)
	MailCenter.choose(child.id, 0)
	await GameState.process_until(CampaignClock.now() + RANGE_MAX)
	var leaf: MailInstance = _find(&"FR")
	var chain: Array[StringName] = []
	for mail: MailInstance in MailCenter.thread(leaf.id if leaf != null else &""):
		chain.append(mail.def_id)
	TestFixtures.check(res, "31 thread returns the parent chain oldest first", chain == [&"F1", &"FX", &"FR"],
		"%s" % [chain])
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST)
	var request := VacationRequest.new()
	request.mail_id = ask.id
	request.merc_uid = ask.merc_uid
	ask.request = request
	MailCenter.choose(ask.id, 0)
	await GameState.process_until(CampaignClock.now() + int(MailCatalog.row(&"R1A")["delay_max"]))
	var reply: MailInstance = _find(&"R1A")
	TestFixtures.check(res, "32 a follow-up inherits the root VacationRequest and merc",
		reply != null and reply.request == request and reply.merc_uid == ask.merc_uid and reply.kind() == &"vacation",
		"%s" % [reply])


static func _case_text(res: Dictionary) -> void:
	_fresh()
	MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	MailCenter.reset()
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST)
	var request := VacationRequest.new()
	request.merc_uid = ask.merc_uid
	request.start_day = GameState.day() + VAC_LEAD
	request.days = VAC_DAYS
	ask.request = request
	var ask_body: String = MailText.fill(String(MailCatalog.row(ask.def_id)["body"]), ask)
	var ask_subject: String = MailText.fill(String(MailCatalog.row(ask.def_id)["subject"]), ask)
	var end_dm: String = MailText.day_month(request.end_day())
	MailEffectsTests._boot_real()
	var notice: MailInstance = MailCenter.deliver(&"I1")
	var notice_body: String = MailText.fill(String(MailCatalog.row(notice.def_id)["body"]), notice)
	TestFixtures.check(res, "50 MailText leaves no { in the R1 and I1 bodies; vac_end is start + days - 1",
		not ask_body.contains("{") and not notice_body.contains("{") and request.end_day() == request.start_day + 4
		and ask_body.contains(end_dm) and notice_body.contains(TransactionData.grouped(SubscriptionManager.monthly_cost())),
		"%s | %s" % [ask_body, notice_body])
	var subject_want: String = "Vacation Request, %s - %s" % [MailText.month_day(request.start_day),
		MailText.month_day(request.end_day())]
	var body_wants: Array[String] = ["a %d day vacation" % request.days,
		"starting in %d days" % (request.start_day - ask.received_day),
		"beginning on %s and ending on %s." % [MailText.day_month(request.start_day), end_dm]]
	var body_ok: bool = not ask_body.contains("{")
	for want: String in body_wants:
		body_ok = body_ok and ask_body.contains(want)
	TestFixtures.check(res, "the authored R1 subject reads Vacation Request, start - end in month/day form;"
		+ " the body fills days, lead and day/month dates", ask_subject == subject_want and body_ok,
		"%s | %s" % [ask_subject, ask_body])


static func _case_reset(res: Dictionary) -> void:
	_boot()
	MailCenter.deliver(&"F1")
	MailCenter.deliver(&"B1")
	var had: int = MailCenter.unread()
	GameState.start_new_game()
	var left: int = 0
	for folder: StringName in MailCatalog.FOLDERS:
		left += MailCenter.mail_in(folder).size() + MailCenter.mail_in(folder, true).size()
	var bills: int = MailCenter.bills_between(-TrynnCalendar.DAYS_PER_YEAR * 1000, TrynnCalendar.DAYS_PER_YEAR * 1000).size()
	TestFixtures.check(res, "35 game_started clears the store and the bills",
		had == 2 and left == 0 and MailCenter.unread() == 0 and bills == 0, "had %d left %d bills %d" % [had, left, bills])


static func _case_ranges(res: Dictionary) -> void:
	_boot()
	MailCenter.deliver(&"B1")
	var newest: MailInstance = MailCenter.deliver(&"B1")
	var due: int = -1
	var hits: Array[int] = []
	for bill: Bill in MailCenter.bills_between(-TrynnCalendar.DAYS_PER_YEAR, TrynnCalendar.DAYS_PER_YEAR * 10):
		due = bill.due_day if bill.bill_id == &"rent" else due
		hits.append(1 if bill.mail_id == newest.id else 0)
	hits.append(MailCenter.bills_between(due, due).size())
	hits.append(MailCenter.bills_between(due + 1, due + VAC_DAYS).size())
	hits.append(MailCenter.bills_between(due - VAC_DAYS, due - 1).size())
	var s: int = GameState.day() + VAC_LEAD
	var row := VacationRequest.new()
	row.merc_uid = GameState.mercs[0].merc_uid
	row.start_day = s
	row.days = VAC_DAYS
	row.state = VacationRequest.State.APPROVED
	BenefitsManager.book.rows.append(row)
	var spans: Array[int] = [MailCenter.vacation_spans(s + VAC_DAYS, s + 2 * VAC_DAYS).size(),
		MailCenter.vacation_spans(s - VAC_DAYS, s - 1).size(), MailCenter.vacation_spans(s + VAC_DAYS - 1, s + 9).size(),
		MailCenter.vacation_spans(s - VAC_DAYS, s).size()]
	BenefitsManager.book.clear()
	TestFixtures.check(res, "47 vacation_spans and bills_between keep only in-range items; Bill.mail_id is the newest mail",
		hits == [1, 1, 0, 0] and spans == [0, 0, 1, 1], "bills %s spans %s due %d" % [hits, spans, due])

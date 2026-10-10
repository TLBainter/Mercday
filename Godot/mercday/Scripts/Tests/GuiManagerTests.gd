class_name GuiManagerTests

#GuiDates, BazaarManager, LegalManager and FinanceManager off a fresh campaign. Every case
#restarts the game and resets the three managers, so the catalog, the legal books and the
#clock all read the same way on every run; the legal cases file their rows with
#GuiLegalTests._lay_legal. Entitlements are faked with set_entitlements.

const CATALOG_ITEMS := 140
const ALL_RARITY := 4
#The odd job cap check sends three idle mercs, one past the start roster.
const ODD_JOB_EXTRA := 1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_dates(res)
	_case_bazaar_catalog(res)
	_case_bazaar_cart(res)
	_case_bazaar_orders(res)
	_case_bazaar_filters(res)
	_case_bazaar_search(res)
	_case_bazaar_sorts(res)
	_case_bazaar_counts(res)
	_case_legal_seed(res)
	_case_legal_permits(res)
	_case_permit_places(res)
	_case_legal_fees(res)
	_case_legal_payments(res)
	_case_legal_odd_job_odds(res)
	_case_legal_odd_job_crew(res)
	_case_legal_odd_jobs(res)
	_case_finance(res)
	_case_legal_seen(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.max_out()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI MANAGER")


#Every case starts bare: Enterprise with no upgrade tier and no override, so a case that needs a
#tier says so with set_entitlements or set_tier.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	BazaarManager.reset()
	LegalManager.reset()
	FinanceManager.reset()


#Crosses day boundaries without running the contract machinery: the clock moves and the day
#signal fires, which is all the managers listen for.
static func advance_days(n: int) -> void:
	CampaignClock.advance(n * CampaignClock.MINUTES_PER_DAY)
	GameState.day_changed.emit(GameState.day())


static func _item_named(name: String) -> BazaarItemData:
	for found: BazaarItemData in BazaarManager.catalog:
		if found.name == name:
			return found
	return null


static func _cheapest(rarity_cap: int) -> BazaarItemData:
	var best: BazaarItemData = null
	for found: BazaarItemData in BazaarManager.catalog:
		if found.rarity > rarity_cap:
			continue
		if best == null or found.price < best.price:
			best = found
	return best


#The first n roster mercs no manager is holding; available_only also needs the Available status.
static func idle_views(n: int, available_only: bool = false) -> Array[MercView]:
	var busy: Array[int] = GameState.busy_uids()
	var out: Array[MercView] = []
	for view: MercView in GameState.roster:
		if out.size() >= n:
			break
		if busy.has(view.uid):
			continue
		if available_only and view.status != GuiTypes.MercStatus.AVAILABLE:
			continue
		out.append(view)
	return out


static func idle_uids(n: int, available_only: bool = false) -> Array[int]:
	var out: Array[int] = []
	for view: MercView in idle_views(n, available_only):
		out.append(view.uid)
	return out


#A roster merc nobody is holding and who is Available, or -1.
static func free_uid() -> int:
	var found: Array[int] = idle_uids(1, true)
	return -1 if found.is_empty() else found[0]


#The date and duration strings.
static func _case_dates(res: Dictionary) -> void:
	TestFixtures.check(res, "day_text reads the first day of the calendar",
		GuiDates.day_text(0) == "1 Daith 212", GuiDates.day_text(0))
	TestFixtures.check(res, "day_text reads the campaign start day",
		GuiDates.day_text(1) == "2 Daith 212", GuiDates.day_text(1))
	TestFixtures.check(res, "day_text rolls into the second month",
		GuiDates.day_text(30) == "1 Ruadd 212", GuiDates.day_text(30))
	TestFixtures.check(res, "day_text rolls into the second year",
		GuiDates.day_text(330) == "1 Daith 213", GuiDates.day_text(330))
	TestFixtures.check(res, "short_text cuts the month to three letters and drops the year",
		GuiDates.short_text(30) == "1 Rua", GuiDates.short_text(30))
	TestFixtures.check(res, "days_text keeps one day singular",
		GuiDates.days_text(1) == "1 day", GuiDates.days_text(1))
	TestFixtures.check(res, "days_text pluralises every other count",
		GuiDates.days_text(12) == "12 days", GuiDates.days_text(12))
	TestFixtures.check(res, "eta_text reads Delivered once the arrival day has passed",
		GuiDates.eta_text(-1) == "Delivered", GuiDates.eta_text(-1))
	TestFixtures.check(res, "eta_text reads Arrives today on the arrival day",
		GuiDates.eta_text(0) == "Arrives today", GuiDates.eta_text(0))
	TestFixtures.check(res, "eta_text counts the days left",
		GuiDates.eta_text(3) == "Arrives in 3 days", GuiDates.eta_text(3))
	TestFixtures.check(res, "eta_text keeps the last day singular",
		GuiDates.eta_text(1) == "Arrives in 1 day", GuiDates.eta_text(1))


#The generated catalog, the rarity cap and the delivery speed.
static func _case_bazaar_catalog(res: Dictionary) -> void:
	_fresh()
	var subtypes: int = 0
	for dept: Dictionary in BazaarManager.DEPARTMENTS:
		subtypes += (dept["subtypes"] as Array).size()
	TestFixtures.check(res, "the catalog holds five items per subtype",
		BazaarManager.catalog.size() == subtypes * BazaarManager.ITEMS_PER_SUBTYPE
		and BazaarManager.catalog.size() == CATALOG_ITEMS,
		"%d items over %d subtypes" % [BazaarManager.catalog.size(), subtypes])
	TestFixtures.check(res, "the catalog names an item after the singular of its subtype",
		_item_named("Sword 5") != null and _item_named("Sword 6") == null,
		"Sword 5 %s" % [_item_named("Sword 5") != null])
	var same: bool = true
	var before: Array[int] = []
	for found: BazaarItemData in BazaarManager.catalog:
		before.append(found.price)
	BazaarManager.reset()
	for i: int in range(BazaarManager.catalog.size()):
		if BazaarManager.catalog[i].price != before[i]:
			same = false
	TestFixtures.check(res, "a reset rebuilds the same catalog from the fixed seed", same,
		"%d prices compared" % before.size())
	TestFixtures.check(res, "the Bazaar is locked until the plan unlocks it",
		not BazaarManager.unlocked(), "unlocked %s" % BazaarManager.unlocked())
	SubscriptionManager.set_entitlements({"bazaar": true})
	TestFixtures.check(res, "the bazaar entitlement unlocks the shop", BazaarManager.unlocked(),
		"unlocked %s" % BazaarManager.unlocked())
	SubscriptionManager.set_entitlements({"bazaarRarity": 0})
	var ordinary: int = BazaarManager.filter_items({}).size()
	var high: BazaarItemData = null
	for found: BazaarItemData in BazaarManager.catalog:
		if found.rarity == ALL_RARITY:
			high = found
			break
	TestFixtures.check(res, "the rarity cap hides everything above it",
		ordinary > 0 and ordinary < CATALOG_ITEMS and not BazaarManager.available(high),
		"%d of %d listed" % [ordinary, CATALOG_ITEMS])
	SubscriptionManager.set_entitlements({"bazaarRarity": ALL_RARITY})
	TestFixtures.check(res, "the top rarity tier lists the whole catalog",
		BazaarManager.filter_items({}).size() == CATALOG_ITEMS,
		"%d of %d listed" % [BazaarManager.filter_items({}).size(), CATALOG_ITEMS])
	var bad_speed: Array[String] = []
	for tier: int in range(BazaarManager.DELIVERY_DAYS.size()):
		SubscriptionManager.set_entitlements({"bazaarSpeed": tier})
		if BazaarManager.delivery_days() != BazaarManager.DELIVERY_DAYS[tier]:
			bad_speed.append("tier %d gave %d" % [tier, BazaarManager.delivery_days()])
	TestFixtures.check(res, "every delivery speed tier reads its own day count",
		bad_speed.is_empty(), TestFixtures.detail(bad_speed, BazaarManager.DELIVERY_DAYS.size(),
		"tiers"))


#The cart arithmetic and the checkout line.
static func _case_bazaar_cart(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY})
	var sword: BazaarItemData = _item_named("Sword 1")
	BazaarManager.add_to_cart(sword.id, 2)
	TestFixtures.check(res, "adding to the cart counts the quantity and totals the price",
		BazaarManager.cart_count() == 2 and BazaarManager.cart_total() == sword.price * 2,
		"%d items for %d notes" % [BazaarManager.cart_count(), BazaarManager.cart_total()])
	BazaarManager.add_to_cart(sword.id, 1)
	TestFixtures.check(res, "adding the same item again stacks on the line",
		BazaarManager.cart_count() == 3, "%d items" % BazaarManager.cart_count())
	var bomb: BazaarItemData = _item_named("Bomb 1")
	BazaarManager.set_qty(bomb.id, 4)
	TestFixtures.check(res, "the cart totals every line",
		BazaarManager.cart_total() == sword.price * 3 + bomb.price * 4
		and BazaarManager.cart_ids().size() == 2,
		"%d notes over %d lines" % [BazaarManager.cart_total(),
		BazaarManager.cart_ids().size()])
	BazaarManager.set_qty(bomb.id, 0)
	TestFixtures.check(res, "a quantity of zero takes the line out of the cart",
		BazaarManager.cart_ids().size() == 1 and BazaarManager.cart_total() == sword.price * 3,
		"%d lines" % BazaarManager.cart_ids().size())
	BazaarManager.remove_from_cart(sword.id)
	TestFixtures.check(res, "an empty cart cannot check out and says so",
		not BazaarManager.can_checkout()
		and BazaarManager.checkout_reason() == "Your cart is empty.",
		BazaarManager.checkout_reason())
	BazaarManager.set_qty(sword.id, 1000)
	var short: int = BazaarManager.cart_total() - GameState.bank_notes
	TestFixtures.check(res, "a cart over the bank closes checkout with no line and reports the shortfall",
		not BazaarManager.can_checkout() and BazaarManager.checkout_reason() == ""
		and BazaarManager.notes_short() == short,
		"reason '%s' short %d" % [BazaarManager.checkout_reason(), BazaarManager.notes_short()])
	GameState.refund(BazaarManager.cart_total())
	TestFixtures.check(res, "enough notes clears the checkout line",
		BazaarManager.can_checkout() and BazaarManager.checkout_reason() == "",
		"reason '%s'" % BazaarManager.checkout_reason())
	SubscriptionManager.set_entitlements({"bazaarRarity": 0})
	var locked: BazaarItemData = null
	for found: BazaarItemData in BazaarManager.catalog:
		if found.rarity == ALL_RARITY:
			locked = found
			break
	TestFixtures.check(res, "an item over the rarity cap cannot enter the cart",
		not BazaarManager.add_to_cart(locked.id, 1), "locked %s" % locked.name)
	BazaarManager.clear_cart()
	TestFixtures.check(res, "clearing the cart empties every line",
		BazaarManager.cart_count() == 0 and BazaarManager.cart_ids().is_empty(),
		"%d items" % BazaarManager.cart_count())


#Placing an order, its progress and its arrival on a day tick.
static func _case_bazaar_orders(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY,
		"bazaarSpeed": 5})
	var cheap: BazaarItemData = _cheapest(ALL_RARITY)
	GameState.refund(cheap.price * 3)
	BazaarManager.set_qty(cheap.id, 3)
	var bank: int = GameState.bank_notes
	var total: int = BazaarManager.cart_total()
	var placed: Array[int] = []
	var on_placed := func(o: OrderData) -> void: placed.append(o.id)
	BazaarManager.order_placed.connect(on_placed)
	var order: OrderData = BazaarManager.place_order()
	BazaarManager.order_placed.disconnect(on_placed)
	TestFixtures.check(res, "placing an order debits the bank and empties the cart",
		order != null and GameState.bank_notes == bank - total
		and BazaarManager.cart_count() == 0 and placed.size() == 1,
		"bank %d of %d, cart %d" % [GameState.bank_notes, bank - total,
		BazaarManager.cart_count()])
	TestFixtures.check(res, "the order keeps the day it was placed and the speed it was bought at",
		order.placed_day == GameState.day() and order.days == BazaarManager.delivery_days()
		and order.total == total and order.item_count() == 3,
		"day %d, %d days, %d notes" % [order.placed_day, order.days, order.total])
	TestFixtures.check(res, "a fresh order is in transit and nothing has arrived",
		not BazaarManager.is_delivered(order) and BazaarManager.in_transit_count() == 1
		and BazaarManager.days_left(order) == order.days
		and is_equal_approx(BazaarManager.progress(order), 0.0),
		"%d days left" % BazaarManager.days_left(order))
	var arrived: Array[int] = []
	var on_arrived := func(o: OrderData) -> void: arrived.append(o.id)
	BazaarManager.order_arrived.connect(on_arrived)
	advance_days(1)
	TestFixtures.check(res, "an order halfway there is still in transit",
		arrived.is_empty() and BazaarManager.days_left(order) == order.days - 1
		and is_equal_approx(BazaarManager.progress(order), 0.5),
		"%d days left, progress %.2f" % [BazaarManager.days_left(order),
		BazaarManager.progress(order)])
	advance_days(1)
	TestFixtures.check(res, "the day tick lands the order on its arrival day",
		arrived.size() == 1 and BazaarManager.is_delivered(order) and order.arrived
		and BazaarManager.days_left(order) == 0,
		"%d arrivals, delivered %s" % [arrived.size(), BazaarManager.is_delivered(order)])
	advance_days(2)
	BazaarManager.order_arrived.disconnect(on_arrived)
	TestFixtures.check(res, "an order announces its arrival once only",
		arrived.size() == 1 and BazaarManager.days_left(order) == -2
		and BazaarManager.in_transit_count() == 0,
		"%d arrivals, %d days left" % [arrived.size(), BazaarManager.days_left(order)])
	TestFixtures.check(res, "a delivered order is unseen until the Orders tab is opened",
		BazaarManager.has_unseen_delivery(), "unseen %s" % BazaarManager.has_unseen_delivery())
	BazaarManager.mark_orders_seen()
	TestFixtures.check(res, "marking the orders seen clears the delivery dot",
		not BazaarManager.has_unseen_delivery() and order.seen,
		"unseen %s" % BazaarManager.has_unseen_delivery())
	GameState.refund(cheap.price)
	BazaarManager.set_qty(cheap.id, 1)
	var second: OrderData = BazaarManager.place_order()
	var counts: Dictionary = BazaarManager.order_counts()
	TestFixtures.check(res, "the order filters split the list into transit and delivered",
		int(counts[&"all"]) == 2 and int(counts[&"transit"]) == 1
		and int(counts[&"delivered"]) == 1,
		"all %d, transit %d, delivered %d" % [int(counts[&"all"]), int(counts[&"transit"]),
		int(counts[&"delivered"])])
	TestFixtures.check(res, "the order list reads newest first",
		BazaarManager.orders_filtered(&"all")[0].id == second.id,
		"first %d of %d" % [BazaarManager.orders_filtered(&"all")[0].id, second.id])


#The shop filters and the price presets.
static func _case_bazaar_filters(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY})
	var swords: Array[BazaarItemData] = BazaarManager.filter_items({"department": "weapons",
		"subtypes": ["Swords"]})
	var only_swords: bool = true
	for found: BazaarItemData in swords:
		if found.subtype != "Swords" or found.department != "weapons":
			only_swords = false
	TestFixtures.check(res, "the department and subtype filters narrow together",
		swords.size() == BazaarManager.ITEMS_PER_SUBTYPE and only_swords,
		"%d rows" % swords.size())
	TestFixtures.check(res, "a department filter and a foreign subtype leave nothing",
		BazaarManager.filter_items({"department": "weapons", "subtypes": ["Potions"]}).is_empty(),
		"%d rows" % BazaarManager.filter_items({"department": "weapons",
		"subtypes": ["Potions"]}).size())
	var rare: Array[BazaarItemData] = BazaarManager.filter_items({"rarities": [3, 4]})
	var only_rare: bool = not rare.is_empty()
	for found: BazaarItemData in rare:
		if found.rarity != 3 and found.rarity != 4:
			only_rare = false
	TestFixtures.check(res, "the rarity filter keeps the tiers it was given", only_rare,
		"%d rows" % rare.size())
	var bad_preset: Array[String] = []
	for row: Dictionary in BazaarManager.PRICE_PRESETS:
		var key: StringName = row["key"] as StringName
		var hi: int = int(row["hi"])
		for found: BazaarItemData in BazaarManager.filter_items({"price_preset": key}):
			if found.price < int(row["lo"]) or (hi >= 0 and found.price >= hi):
				bad_preset.append("%s took %d" % [String(key), found.price])
	TestFixtures.check(res, "every price preset lists only the prices inside it",
		bad_preset.is_empty(), TestFixtures.detail(bad_preset,
		BazaarManager.PRICE_PRESETS.size(), "presets"))
	var custom: Array[BazaarItemData] = BazaarManager.filter_items({"price_custom": Vector2i(100, 200)})
	var in_range: bool = not custom.is_empty()
	for found: BazaarItemData in custom:
		if found.price < 100 or found.price > 200:
			in_range = false
	TestFixtures.check(res, "a custom price range wins over the preset",
		in_range and BazaarManager.filter_items({"price_preset": &"u50",
		"price_custom": Vector2i(100, 200)}).size() == custom.size(),
		"%d rows" % custom.size())


#The shop search over names, subtypes and departments.
static func _case_bazaar_search(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY})
	var found_rows: Array[BazaarItemData] = BazaarManager.filter_items({"search": "sword"})
	var all_swords: bool = not found_rows.is_empty()
	for found: BazaarItemData in found_rows:
		if found.subtype != "Swords":
			all_swords = false
	TestFixtures.check(res, "the search reads the name, the subtype and the department",
		all_swords and found_rows.size() == BazaarManager.ITEMS_PER_SUBTYPE
		and BazaarManager.filter_items({"search": "WEAPONS"}).size() == 30,
		"%d sword rows, %d weapon rows" % [found_rows.size(),
		BazaarManager.filter_items({"search": "WEAPONS"}).size()])
	TestFixtures.check(res, "a search that matches nothing lists nothing",
		BazaarManager.filter_items({"search": "zzzz"}).is_empty(),
		"%d rows" % BazaarManager.filter_items({"search": "zzzz"}).size())


#Every shop sort orders the whole catalog.
static func _case_bazaar_sorts(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY})
	var bad_sort: Array[String] = []
	for sort: StringName in BazaarManager.SORTS:
		var rows: Array[BazaarItemData] = BazaarManager.filter_items({"sort": sort})
		if rows.size() != CATALOG_ITEMS:
			bad_sort.append("%s dropped rows" % String(sort))
			continue
		for i: int in range(1, rows.size()):
			var a: BazaarItemData = rows[i - 1]
			var b: BazaarItemData = rows[i]
			var ok: bool = true
			match sort:
				&"featured":
					ok = a.featured_rank < b.featured_rank
				&"price_asc":
					ok = a.price <= b.price
				&"price_desc":
					ok = a.price >= b.price
				&"rarity":
					ok = a.rarity > b.rarity or (a.rarity == b.rarity and a.price <= b.price)
				&"name":
					ok = a.name.naturalnocasecmp_to(b.name) <= 0
			if not ok:
				bad_sort.append("%s broke at %d" % [String(sort), i])
				break
	TestFixtures.check(res, "every sort orders the whole list", bad_sort.is_empty(),
		TestFixtures.detail(bad_sort, BazaarManager.SORTS.size(), "sorts"))


#The counts beside each filter option.
static func _case_bazaar_counts(res: Dictionary) -> void:
	_fresh()
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY})
	var q: Dictionary = {"department": "weapons", "subtypes": ["Swords"]}
	var dept_counts: Dictionary = BazaarManager.option_counts(q, &"department")
	var summed: int = 0
	for dept: Dictionary in BazaarManager.DEPARTMENTS:
		summed += int(dept_counts[str(dept["key"])])
	TestFixtures.check(res, "the department counts drop the department and subtype picked",
		int(dept_counts[""]) == CATALOG_ITEMS and summed == CATALOG_ITEMS
		and int(dept_counts["weapons"]) == 30,
		"all %d, summed %d, weapons %d" % [int(dept_counts[""]), summed,
		int(dept_counts["weapons"])])
	var sub_counts: Dictionary = BazaarManager.option_counts(q, &"subtype")
	TestFixtures.check(res, "the subtype counts keep the department and drop the subtype",
		sub_counts.size() == 6 and int(sub_counts["Axes"]) == BazaarManager.ITEMS_PER_SUBTYPE
		and int(sub_counts["Swords"]) == BazaarManager.ITEMS_PER_SUBTYPE,
		"%d subtypes, Axes %d" % [sub_counts.size(), int(sub_counts["Axes"])])
	var priced: Dictionary = BazaarManager.option_counts({"price_preset": &"u50"}, &"price")
	TestFixtures.check(res, "the price counts drop the price filter itself",
		int(priced[&"any"]) == CATALOG_ITEMS
		and int(priced[&"u50"]) == BazaarManager.filter_items({"price_preset": &"u50"}).size(),
		"any %d, under 50 %d" % [int(priced[&"any"]), int(priced[&"u50"])])
	SubscriptionManager.set_entitlements({"bazaarRarity": 0})
	var rarity_counts: Dictionary = BazaarManager.option_counts({}, &"rarity")
	var rarity_total: int = 0
	for i: int in range(BazaarManager.RARITIES.size()):
		rarity_total += int(rarity_counts[i])
	TestFixtures.check(res, "the rarity counts ignore the rarity cap",
		rarity_total == CATALOG_ITEMS and int(rarity_counts[ALL_RARITY]) > 0,
		"%d counted, top tier %d" % [rarity_total, int(rarity_counts[ALL_RARITY])])
	SubscriptionManager.set_entitlements({"bazaarRarity": ALL_RARITY})
	var search_counts: Dictionary = BazaarManager.option_counts({"search": "sword"},
		&"department")
	TestFixtures.check(res, "the counts keep the filters they were not asked about",
		int(search_counts[""]) == BazaarManager.ITEMS_PER_SUBTYPE
		and int(search_counts["armor"]) == 0,
		"all %d, armor %d" % [int(search_counts[""]), int(search_counts["armor"])])


#The thirteen locations, a reset that files nothing, and the rows add_fine and add_capture file.
static func _case_legal_seed(res: Dictionary) -> void:
	_fresh()
	var today: int = GameState.day()
	TestFixtures.check(res, "the legal table holds the thirteen locations under their real names",
		LegalManager.locations().size() == 13
		and LegalManager.location(0).name == CampaignTypeDefs.locations()[0]
		and LegalManager.location(8).name == CampaignTypeDefs.locations()[8]
		and LegalManager.location(0).name == "Buern"
		and LegalManager.location(8).name == "Cyfrolaef",
		"%d locations, %s to %s" % [LegalManager.locations().size(),
		LegalManager.location(0).name, LegalManager.location(8).name])
	TestFixtures.check(res, "each location carries its scope, its costs and its rules",
		LegalManager.location(0).scope == 1 and LegalManager.location(5).scope == 2
		and LegalManager.location(7).scope == 3 and LegalManager.location(0).ops_cost == 0
		and LegalManager.location(8).tele_cost == 2000
		and LegalManager.location(3).rules.size() == 3,
		"scopes %d %d %d" % [LegalManager.location(0).scope, LegalManager.location(5).scope,
		LegalManager.location(7).scope])
	TestFixtures.check(res, "an unknown location id reads null",
		LegalManager.location(99) == null, "location 99")
	TestFixtures.check(res, "a reset files no fines and no captures",
		LegalManager.fines.is_empty() and LegalManager.captured.is_empty(),
		"%d fines, %d captures" % [LegalManager.fines.size(), LegalManager.captured.size()])
	var mercs: Array[int] = [3, 6]
	var first: FineData = LegalManager.add_fine(2, "Crime 1", mercs, 11, 180, 18)
	TestFixtures.check(res, "a filed fine is issued today and falls due after its days",
		first.id == 1 and first.day_issued == today and first.day_due == today + 18
		and first.amount == 180 and first.mercs.size() == 2 and first.unread,
		"id %d, issued %d, due %d, today %d" % [first.id, first.day_issued, first.day_due, today])
	var held: CaptureData = LegalManager.add_capture(4, 3, "Crime 5", 13, 30, 350)
	TestFixtures.check(res, "a filed capture starts today and holds its merc",
		held.id == 1 and held.day_captured == today and held.merc_uid == 4 and held.unread
		and GameState.away_status(4) == GuiTypes.MercStatus.CAPTURED,
		"id %d, captured %d, today %d, status %d" % [held.id, held.day_captured, today,
		GameState.away_status(4)])
	LegalManager.reset()
	GuiLegalTests._lay_legal()
	TestFixtures.check(res, "the paid fine reads as paid and the rest do not",
		LegalManager.fine(4).is_paid() and LegalManager.fine(4).paid == 60
		and not LegalManager.fine(1).is_paid()
		and LegalManager.unpaid_fines().size() == 3,
		"%d unpaid" % LegalManager.unpaid_fines().size())
	TestFixtures.check(res, "the unread rows raise the fine and capture dots",
		LegalManager.has_unread_fine() and LegalManager.has_unread_capture(),
		"fine %s, capture %s" % [LegalManager.has_unread_fine(),
		LegalManager.has_unread_capture()])
	LegalManager.mark_fines_seen()
	LegalManager.mark_captures_seen()
	TestFixtures.check(res, "marking them seen clears both dots",
		not LegalManager.has_unread_fine() and not LegalManager.has_unread_capture(),
		"fine %s, capture %s" % [LegalManager.has_unread_fine(),
		LegalManager.has_unread_capture()])
	TestFixtures.check(res, "good standing needs no debt and nobody held there",
		LegalManager.good_standing(1) and not LegalManager.good_standing(0)
		and not LegalManager.good_standing(3) and LegalManager.good_standing(4),
		"loc 0 %s, loc 1 %s" % [LegalManager.good_standing(0), LegalManager.good_standing(1)])


#The permits the plan reaches and the notes they cost.
static func _case_legal_permits(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "the guild starts with the operating permit at home alone",
		LegalManager.has_permit(0, LegalManager.PERMIT_OPS)
		and not LegalManager.has_permit(0, LegalManager.PERMIT_TELE)
		and not LegalManager.has_permit(2, LegalManager.PERMIT_OPS)
		and not LegalManager.has_permit(2, LegalManager.PERMIT_TELE)
		and not LegalManager.has_permit(1, LegalManager.PERMIT_OPS),
		"loc 0 ops %s, loc 2 tele %s" % [LegalManager.has_permit(0, LegalManager.PERMIT_OPS),
		LegalManager.has_permit(2, LegalManager.PERMIT_TELE)])
	GameState.refund(20000)
	var blocked: Dictionary = LegalManager.can_request(1, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "no permit tier at all blocks every request",
		not bool(blocked["ok"])
		and str(blocked["reason"]) == "Your plan does not reach this location.",
		str(blocked["reason"]))
	SubscriptionManager.set_entitlements({"opsPermits": 1})
	TestFixtures.check(res, "tier one reaches a scope one location",
		bool(LegalManager.can_request(1, LegalManager.PERMIT_OPS)["ok"]),
		str(LegalManager.can_request(1, LegalManager.PERMIT_OPS)["reason"]))
	TestFixtures.check(res, "tier one does not reach a restricted nation",
		not bool(LegalManager.can_request(5, LegalManager.PERMIT_OPS)["ok"]),
		str(LegalManager.can_request(5, LegalManager.PERMIT_OPS)["reason"]))
	SubscriptionManager.set_entitlements({"opsPermits": 2})
	TestFixtures.check(res, "tier two reaches a restricted nation but not another domain",
		bool(LegalManager.can_request(5, LegalManager.PERMIT_OPS)["ok"])
		and not bool(LegalManager.can_request(7, LegalManager.PERMIT_OPS)["ok"]),
		str(LegalManager.can_request(7, LegalManager.PERMIT_OPS)["reason"]))
	SubscriptionManager.set_entitlements({"opsPermits": 3, "teleport": 3})
	var bank: int = GameState.bank_notes
	TestFixtures.check(res, "requesting a permit spends its cost and records it",
		LegalManager.request_permit(1, LegalManager.PERMIT_OPS)
		and GameState.bank_notes == bank - 400
		and LegalManager.has_permit(1, LegalManager.PERMIT_OPS),
		"bank %d of %d" % [GameState.bank_notes, bank - 400])
	var again: Dictionary = LegalManager.can_request(1, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "a permit already held cannot be bought twice",
		not bool(again["ok"]) and str(again["reason"]) == "You already hold this permit."
		and not LegalManager.request_permit(1, LegalManager.PERMIT_OPS), str(again["reason"]))
	var tele: Dictionary = LegalManager.can_request(3, LegalManager.PERMIT_TELE)
	TestFixtures.check(res, "a teleport permit waits on the operating permit there",
		not bool(tele["ok"]) and str(tele["reason"]) == "An operating permit comes first.",
		str(tele["reason"]))
	bank = GameState.bank_notes
	TestFixtures.check(res, "the teleport permit opens once the operating permit is held",
		LegalManager.request_permit(1, LegalManager.PERMIT_TELE)
		and GameState.bank_notes == bank - 250
		and LegalManager.has_permit(1, LegalManager.PERMIT_TELE),
		"bank %d of %d" % [GameState.bank_notes, bank - 250])
	GameState.spend(GameState.bank_notes)
	var poor: Dictionary = LegalManager.can_request(4, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "an empty bank blocks a permit with no line and reports the shortfall",
		not bool(poor["ok"]) and str(poor["reason"]) == "" and int(poor.get("short", 0)) == 1200,
		"reason '%s' short %d" % [str(poor["reason"]), int(poor.get("short", 0))])


#The four permit only countries and the by-name permit reads.
static func _case_permit_places(res: Dictionary) -> void:
	_fresh()
	var places: Array[String] = CampaignTypeDefs.permit_places()
	var rows_ok: bool = places.size() == 13
	for id: int in range(9, 13):
		var place: LegalLocationData = LegalManager.location(id)
		rows_ok = rows_ok and place != null and place.scope == 3 and place.name == places[id]
	TestFixtures.check(res, "Kathaya, Suorr, Kahfald and Cipex hold permit rows 9 to 12 at scope 3",
		rows_ok and places.slice(9) == CampaignTypeDefs.PERMIT_ONLY_PLACES
		and CampaignTypeDefs.locations().size() == 9, "%s" % [places])
	TestFixtures.check(res, "loc_id_of reads the first and the last place and -1 for an unknown name",
		LegalManager.loc_id_of("Buern") == 0 and LegalManager.loc_id_of("Cipex") == 12
		and LegalManager.loc_id_of("Nowhere") == -1,
		"%d %d %d" % [LegalManager.loc_id_of("Buern"), LegalManager.loc_id_of("Cipex"),
		LegalManager.loc_id_of("Nowhere")])
	TestFixtures.check(res, "home holds its operating permit and no teleport permit by name",
		LegalManager.ops_held_at("Buern") and not LegalManager.tele_held_at("Buern"), "")
	SubscriptionManager.set_entitlements({"opsPermits": 3, "teleport": 3})
	GameState.refund(20000)
	LegalManager.request_permit(9, LegalManager.PERMIT_OPS)
	LegalManager.request_permit(9, LegalManager.PERMIT_TELE)
	TestFixtures.check(res, "a bought place reads both permits held by name",
		LegalManager.ops_held_at("Kathaya") and LegalManager.tele_held_at("Kathaya")
		and not LegalManager.ops_held_at("Suorr"), "")
	SubscriptionManager.set_entitlements({"opsPermits": 1, "teleport": 1})
	TestFixtures.check(res, "an INACTIVE permit reads not held by name, home stays held",
		LegalManager.permit_state(9, LegalManager.PERMIT_OPS) == LegalManager.STATE_INACTIVE
		and not LegalManager.ops_held_at("Kathaya") and not LegalManager.tele_held_at("Kathaya")
		and LegalManager.ops_held_at("Buern"), "")
	TestFixtures.check(res, "an unknown name holds no permit",
		not LegalManager.ops_held_at("Nowhere") and not LegalManager.tele_held_at("Nowhere"), "")


#The late fee, the custody fee and what who you know takes off them.
static func _case_legal_fees(res: Dictionary) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	var overdue: FineData = LegalManager.fine(2)
	TestFixtures.check(res, "the late fee runs two percent of the fine per overdue day",
		LegalManager.late_fee(overdue) == 45 and LegalManager.fine_due(overdue) == 495,
		"fee %d, due %d" % [LegalManager.late_fee(overdue), LegalManager.fine_due(overdue)])
	TestFixtures.check(res, "a fine inside its due date carries no late fee",
		LegalManager.late_fee(LegalManager.fine(1)) == 0
		and LegalManager.fine_due(LegalManager.fine(1)) == 180,
		"fee %d" % LegalManager.late_fee(LegalManager.fine(1)))
	var held: CaptureData = LegalManager.capture(1)
	TestFixtures.check(res, "custody costs five notes a day on top of the bail",
		LegalManager.custody_fee(held) == 20 and LegalManager.bail_due(held) == 370,
		"custody %d, bail due %d" % [LegalManager.custody_fee(held),
		LegalManager.bail_due(held)])
	advance_days(3)
	TestFixtures.check(res, "both fees grow with the days that pass",
		LegalManager.late_fee(overdue) == 72 and LegalManager.custody_fee(held) == 35,
		"fee %d, custody %d" % [LegalManager.late_fee(overdue),
		LegalManager.custody_fee(held)])
	SubscriptionManager.set_entitlements({"whoKnows": 7})
	TestFixtures.check(res, "tier seven halves the late fee",
		LegalManager.fee_reduction() == 50 and LegalManager.late_fee(overdue) == 36,
		"fee %d" % LegalManager.late_fee(overdue))
	SubscriptionManager.set_entitlements({"whoKnows": 8})
	TestFixtures.check(res, "tier eight drops the late fee altogether",
		LegalManager.fee_reduction() == 100 and LegalManager.late_fee(overdue) == 0
		and LegalManager.fine_due(overdue) == 450,
		"fee %d" % LegalManager.late_fee(overdue))
	SubscriptionManager.set_entitlements({"whoKnows": 1})
	TestFixtures.check(res, "the money and prison cuts read off the tier owned",
		LegalManager.money_reduction() == 5 and LegalManager.prison_reduction() == 0,
		"money %d, prison %d" % [LegalManager.money_reduction(),
		LegalManager.prison_reduction()])
	SubscriptionManager.set_entitlements({"whoKnows": 5})
	TestFixtures.check(res, "a higher tier replaces the cut below it",
		LegalManager.money_reduction() == 25 and LegalManager.prison_reduction() == 15,
		"money %d, prison %d" % [LegalManager.money_reduction(),
		LegalManager.prison_reduction()])
	var mercs: Array[int] = [1]
	var fresh_fine: FineData = LegalManager.add_fine(4, "Crime 7", mercs, 14, 100, 10)
	TestFixtures.check(res, "who you know cuts a new fine and keeps what it was",
		fresh_fine.amount == 75 and fresh_fine.previous_amount == 100
		and fresh_fine.unread and LegalManager.fines.size() == 5,
		"%d of %d" % [fresh_fine.amount, fresh_fine.previous_amount])
	var fresh_capture: CaptureData = LegalManager.add_capture(1, 4, "Crime 8", 14, 20, 400)
	TestFixtures.check(res, "who you know cuts new bail and a new sentence",
		fresh_capture.bail == 300 and fresh_capture.previous_bail == 400
		and fresh_capture.sentence_days == 17,
		"bail %d, sentence %d" % [fresh_capture.bail, fresh_capture.sentence_days])
	TestFixtures.check(res, "who you know leaves the fines already standing alone",
		LegalManager.fine(2).amount == 450 and LegalManager.capture(1).bail == 350,
		"fine %d, bail %d" % [LegalManager.fine(2).amount, LegalManager.capture(1).bail])


#Paying a fine and paying bail.
static func _case_legal_payments(res: Dictionary) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	GameState.refund(20000)
	var owed: int = LegalManager.fine_due(LegalManager.fine(2))
	var bank: int = GameState.bank_notes
	TestFixtures.check(res, "paying a fine spends what is due and closes the row",
		LegalManager.pay_fine(2) and GameState.bank_notes == bank - owed
		and LegalManager.fine(2).is_paid() and LegalManager.fine(2).paid == owed
		and LegalManager.fine(2).day_paid == GameState.day(),
		"bank %d of %d for %d" % [GameState.bank_notes, bank - owed, owed])
	TestFixtures.check(res, "a paid fine cannot be paid again and stops accruing",
		not LegalManager.pay_fine(2) and LegalManager.unpaid_fines().size() == 2,
		"%d unpaid" % LegalManager.unpaid_fines().size())
	advance_days(5)
	TestFixtures.check(res, "the fee on a paid fine is frozen at the day it was paid",
		LegalManager.fine_due(LegalManager.fine(2)) == owed,
		"due %d of %d" % [LegalManager.fine_due(LegalManager.fine(2)), owed])
	var bail: int = LegalManager.bail_due(LegalManager.capture(1))
	bank = GameState.bank_notes
	TestFixtures.check(res, "paying bail spends what is due and frees the merc",
		LegalManager.pay_bail(1) and GameState.bank_notes == bank - bail
		and LegalManager.capture(1) == null and LegalManager.captured.size() == 1,
		"bank %d of %d for %d" % [GameState.bank_notes, bank - bail, bail])
	TestFixtures.check(res, "bail on a capture already cleared does nothing",
		not LegalManager.pay_bail(1) and LegalManager.captured.size() == 1,
		"%d held" % LegalManager.captured.size())
	TestFixtures.check(res, "a paid location is in good standing while a debt is not",
		LegalManager.good_standing(0) and not LegalManager.good_standing(3),
		"loc 0 %s, loc 3 %s" % [LegalManager.good_standing(0), LegalManager.good_standing(3)])
	TestFixtures.check(res, "paying the last fine there restores good standing",
		LegalManager.pay_fine(3) and LegalManager.good_standing(3),
		"loc 3 %s" % LegalManager.good_standing(3))
	GameState.spend(GameState.bank_notes)
	TestFixtures.check(res, "an empty bank cannot pay a fine", not LegalManager.pay_fine(1),
		"bank %d" % GameState.bank_notes)


#The Odd Job odds with and without counsel.
static func _case_legal_odd_job_odds(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "the odds run thirty plus twenty a merc",
		LegalManager.odd_job_odds(1, LegalManager.JOB_RENEGOTIATE) == 50
		and LegalManager.odd_job_odds(2, LegalManager.JOB_BREAKOUT) == 70,
		"one merc %d" % LegalManager.odd_job_odds(1, LegalManager.JOB_RENEGOTIATE))
	SubscriptionManager.set_entitlements({"counsel": true, "counselPct": 15})
	TestFixtures.check(res, "counsel adds its percentage a merc and the odds cap at 95",
		LegalManager.odd_job_odds(3, LegalManager.JOB_RENEGOTIATE) == 95
		and LegalManager.odd_job_odds(1, LegalManager.JOB_RENEGOTIATE) == 65,
		"three mercs %d" % LegalManager.odd_job_odds(3, LegalManager.JOB_RENEGOTIATE))
	TestFixtures.check(res, "counsel does not help a break out",
		LegalManager.odd_job_odds(3, LegalManager.JOB_BREAKOUT) == 90,
		"three mercs %d" % LegalManager.odd_job_odds(3, LegalManager.JOB_BREAKOUT))


#Which crews can start an Odd Job.
static func _case_legal_odd_job_crew(res: Dictionary) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	GameState.refund(20000)
	TestFixtures.add_mercs(ODD_JOB_EXTRA)
	var pair: Array[int] = idle_uids(2)
	var blocked: Dictionary = LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, pair, 50)
	TestFixtures.check(res, "no Odd Jobs tier blocks the crew",
		not bool(blocked["ok"])
		and str(blocked["reason"]) == "Odd Jobs are not part of your plan.",
		str(blocked["reason"]))
	SubscriptionManager.set_entitlements({"oddJobs": 2})
	var three: Array[int] = idle_uids(3)
	var over: Dictionary = LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, three, 50)
	TestFixtures.check(res, "the plan caps how many mercs go",
		not bool(over["ok"]) and str(over["reason"]) == "Your plan allows 2 mercs.",
		str(over["reason"]))
	var empty: Array[int] = []
	var twice: Array[int] = [pair[0], pair[0]]
	TestFixtures.check(res, "an empty crew and a doubled merc are both refused",
		str(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, empty,
		50)["reason"]) == "Pick at least one merc."
		and str(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, twice,
		50)["reason"]) == "That merc is already on the crew.",
		str(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, twice, 50)["reason"]))
	TestFixtures.check(res, "a case that does not exist takes no crew",
		not bool(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 99, pair, 50)["ok"])
		and not bool(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 4, pair,
		50)["ok"]),
		"paid fine %s" % str(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 4, pair,
		50)["reason"]))


#The job runs, is paid up front and resolves on the day tick.
static func _case_legal_odd_jobs(res: Dictionary) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	GameState.refund(20000)
	SubscriptionManager.set_entitlements({"counsel": true, "counselPct": 15, "oddJobs": 2})
	var pair: Array[int] = idle_uids(2)
	var bank: int = GameState.bank_notes
	var job: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_FINE, 1,
		LegalManager.JOB_RENEGOTIATE, pair, 50)
	TestFixtures.check(res, "starting an Odd Job pays the crew up front",
		job != null and GameState.bank_notes == bank - 100 and job.total_pay() == 100
		and job.days == LegalManager.JOB_DAYS and job.odds == 95,
		"bank %d of %d, odds %d" % [GameState.bank_notes, bank - 100, job.odds])
	TestFixtures.check(res, "the running job is found by its target and counts down",
		LegalManager.active_odd_job(LegalManager.TARGET_FINE, 1) == job
		and LegalManager.odd_job_days_left(job) == LegalManager.JOB_DAYS,
		"%d days left" % LegalManager.odd_job_days_left(job))
	TestFixtures.check(res, "one case takes one job at a time",
		LegalManager.start_odd_job(LegalManager.TARGET_FINE, 1,
		LegalManager.JOB_RENEGOTIATE, pair, 50) == null
		and str(LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, 1, pair,
		50)["reason"]) == "A job is already running on this case.",
		"%d jobs" % LegalManager.odd_jobs.size())
	var resolved: Array[Dictionary] = []
	var on_resolved := func(target: Dictionary, success: bool) -> void:
		resolved.append({"target": target, "success": success})
	LegalManager.odd_job_resolved.connect(on_resolved)
	advance_days(LegalManager.JOB_DAYS - 1)
	TestFixtures.check(res, "the job holds until its last day",
		resolved.is_empty() and LegalManager.odd_jobs.size() == 1
		and LegalManager.odd_job_days_left(job) == 1,
		"%d days left" % LegalManager.odd_job_days_left(job))
	var before: int = LegalManager.fine(1).amount
	advance_days(1)
	var won: bool = bool(resolved[0]["success"])
	var want: int = int(round(float(before) * (LegalManager.RENEGOTIATE_WIN if won
		else LegalManager.RENEGOTIATE_LOSS)))
	TestFixtures.check(res, "the day tick resolves the job and applies the renegotiation",
		resolved.size() == 1 and LegalManager.odd_jobs.is_empty()
		and LegalManager.fine(1).amount == want
		and LegalManager.fine(1).previous_amount == before,
		"%s: %d of %d" % ["won" if won else "lost", LegalManager.fine(1).amount, before])
	TestFixtures.check(res, "the resolution names the case it was about",
		StringName(resolved[0]["target"]["kind"]) == LegalManager.TARGET_FINE
		and int(resolved[0]["target"]["id"]) == 1,
		"%s %d" % [str(resolved[0]["target"]["kind"]), int(resolved[0]["target"]["id"])])
	var held: int = LegalManager.captured.size()
	var bail: int = LegalManager.capture(1).bail
	var out: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_CAPTURE, 1,
		LegalManager.JOB_BREAKOUT, pair, 10)
	advance_days(LegalManager.JOB_DAYS)
	LegalManager.odd_job_resolved.disconnect(on_resolved)
	var broke: bool = bool(resolved[1]["success"])
	var freed: bool = LegalManager.captured.size() == held - 1
	var raised: bool = LegalManager.capture(1) != null \
		and LegalManager.capture(1).bail == int(round(float(bail) * LegalManager.BREAKOUT_LOSS))
	TestFixtures.check(res, "a break out either frees the merc or raises the bail",
		out != null and resolved.size() == 2 and (freed if broke else raised),
		"%s: %d held, bail %d" % ["freed" if broke else "failed", LegalManager.captured.size(),
		bail])


#The loan offers and the monthly budget.
static func _case_finance(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "a fresh guild holds no offers, loans or closed loans",
		FinanceManager.offers.is_empty() and FinanceManager.loans.is_empty()
		and FinanceManager.closed_loans.is_empty() and not FinanceManager.has_offers(),
		"%d offers, %d loans, %d closed" % [FinanceManager.offers.size(), FinanceManager.loans.size(),
		FinanceManager.closed_loans.size()])
	var lender: String = "Lender 5"
	var team: Array[int] = [(GameState.mercs as Array[MercenaryData])[0].merc_uid]
	var calc: Dictionary = FinanceManager.request_calc(lender, FinanceManager.fair_draft(lender), team)
	var sent: bool = FinanceManager.request_loan({"lender": lender, "amount": int(calc["amount"]),
		"rate": float(calc["rate"]), "term": int(calc["months"]), "first_due": int(calc["first_due"]),
		"team": team, "odds": int(calc["odds"]), "per": 0})
	var away: int = int(FinanceManager.lender_row(lender)["away_hours"])
	var arrival: int = CampaignClock.now() + away * CampaignClock.MINUTES_PER_HOUR
	CampaignClock.advance_to(arrival)
	FinanceManager.tick(arrival)
	TestFixtures.check(res, "a returned loan request arrives as one unread offer",
		sent and FinanceManager.offers.size() == 1 and FinanceManager.has_offers(),
		"sent %s, %d offers, unread %s" % [sent, FinanceManager.offers.size(), FinanceManager.has_offers()])
	var offer: Dictionary = FinanceManager.offers[0] if not FinanceManager.offers.is_empty() else {}
	TestFixtures.check(res, "an offer carries its lender, amount, rate and term",
		offer.has("lender") and offer.has("amount") and offer.has("rate_pct")
		and offer.has("months") and offer.has("offer_amount") and offer.has("expires_minute"),
		"keys %s" % [offer.keys()])
	FinanceManager.mark_offers_seen()
	TestFixtures.check(res, "marking the offers seen clears the Finance dot",
		not FinanceManager.has_offers() and FinanceManager.offers.size() == 1,
		"unread %s" % FinanceManager.has_offers())
	var loan: LoanData = TestFixtures.add_loan("Lender 2", 1000, 0.1, 10)
	TestFixtures.check(res, "a loan on the books is listed", FinanceManager.loans == [loan],
		"%d loans" % FinanceManager.loans.size())
	var budget: Dictionary = FinanceManager.budget()
	var want_other: int = FinanceLedger.monthly_expenses() - FinanceLedger.loans_total()
	want_other -= SubscriptionManager.monthly_cost()
	TestFixtures.check(res, "the budget reads income, other expenses and the subscription",
		budget.has("income") and budget.has("other_expenses") and budget.has("subscription")
		and int(budget["income"]) == FinanceLedger.income_in(FinanceLedger.RATE_DAYS)
		and int(budget["other_expenses"]) == want_other
		and int(budget["subscription"]) == SubscriptionManager.monthly_cost(),
		"income %d, other %d want %d, subscription %d" % [int(budget["income"]),
		int(budget["other_expenses"]), want_other, int(budget["subscription"])])
	TestFixtures.check(res, "the net reads the budget it was built from",
		FinanceManager.net() == int(budget["income"]) - int(budget["other_expenses"])
		- int(budget["subscription"]), "net %d" % FinanceManager.net())
	FinanceManager.reset()
	TestFixtures.check(res, "a reset clears the offers and the loans",
		FinanceManager.offers.is_empty() and FinanceManager.loans.is_empty() and not FinanceManager.has_offers(),
		"%d offers, %d loans" % [FinanceManager.offers.size(), FinanceManager.loans.size()])


#Marking the legal rows seen emits its signal once and then stops.
static func _case_legal_seen(res: Dictionary) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	var fine_beats: Array[int] = []
	var capture_beats: Array[int] = []
	var on_fines := func() -> void: fine_beats.append(1)
	var on_captures := func() -> void: capture_beats.append(1)
	LegalManager.fines_changed.connect(on_fines)
	LegalManager.captures_changed.connect(on_captures)
	TestFixtures.check(res, "the legal rows start with an unread fine and capture",
		LegalManager.has_unread_fine() and LegalManager.has_unread_capture(),
		"fine %s capture %s" % [LegalManager.has_unread_fine(),
			LegalManager.has_unread_capture()])
	LegalManager.mark_fines_seen()
	TestFixtures.check(res, "marking the fines seen clears them and emits fines_changed once",
		fine_beats.size() == 1 and not LegalManager.has_unread_fine(),
		"beats %d unread %s" % [fine_beats.size(), LegalManager.has_unread_fine()])
	LegalManager.mark_fines_seen()
	TestFixtures.check(res, "marking the fines seen with nothing unread emits nothing",
		fine_beats.size() == 1, "beats %d" % fine_beats.size())
	LegalManager.mark_captures_seen()
	TestFixtures.check(res, "marking the captures seen clears them and emits captures_changed once",
		capture_beats.size() == 1 and not LegalManager.has_unread_capture(),
		"beats %d unread %s" % [capture_beats.size(), LegalManager.has_unread_capture()])
	LegalManager.mark_captures_seen()
	TestFixtures.check(res, "marking the captures seen with nothing unread emits nothing",
		capture_beats.size() == 1, "beats %d" % capture_beats.size())
	TestFixtures.check(res, "marking one kind seen leaves the other kind's signal alone",
		fine_beats.size() == 1 and capture_beats.size() == 1,
		"fines %d captures %d" % [fine_beats.size(), capture_beats.size()])
	LegalManager.fines_changed.disconnect(on_fines)
	LegalManager.captures_changed.disconnect(on_captures)

class_name GuiClickDTests
extends RefCounted

#Run: godot --headless --path . with the arg separator, then --gui-click-d-tests
#README Part D, the nine numbered steps a person clicks through: the locked My Bazaar tile, the
#buy that opens it, the Shop filters, the rarity locks, the cart, an order, the Metrics scales,
#the coaching plan and the Customize tree. Every step is driven through the GameHUD and the real
#viewer scenes with the public press helpers, because a synthetic click never lands headless.

const CLEAR_TEXT: String = "Clear all filters"
const TYPE_HEAD: String = "Weapons Type"
const WEAPONS: String = "weapons"
#README C2: the breadcrumb reads the department, then the checked subtypes, then the query.
const WEAPONS_CRUMB: String = "Weapons"
#README C2 line 228 and line 234: the breadcrumb literals, spelled here and not read off ShopPage.
const ALL_CRUMB_TEXT: String = "All Departments"
const CRUMB_JOIN_TEXT: String = " > "
const SUB_A: String = "Swords"
const SUB_B: String = "Axes"
const PRICE_KEY: StringName = &"50"
const LOW: int = 50
const HIGH: int = 150
const RARE: int = 3
const VERY_RARE: int = 4
const RED: Color = Color("#e8583f")
const DIM_ALPHA: float = 0.4
const HALF_ALPHA: float = 0.5
const PROGRESS_CELLS: int = 20
const LIFEPATH_SLOTS: int = 8
const REASON_DAY: String = "Days need a period of 6m or less"
const REASON_WEEK: String = "Weeks need a period of 1y or less"
const REASON_QUARTER: String = "Quarters need a period of 1y or more"
const DEEP_DAYS: int = 1000
const RICH: int = 400000
const FAST_TIER: int = 5
const FAST_DAYS: int = 2
const OLIVE_SPREAD: float = 0.25
#The greyed row colour of a shared dropdown and the nominal 33-day metrics month of MetricsPeriod.
const GREY_TEXT: Color = Color("#4a5a78")
const HALF_YEAR_DAYS: int = 198


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var bank: int = GameState.bank_notes
	await host.get_tree().process_frame
	await _case_d01_bazaar_locked(res, host)
	await _case_d02_buy_unlocks(res, host)
	await _case_d03_shop_filters(res, host)
	await _case_d04_rarity_locks(res, host)
	await _case_d05_cart_badge(res, host)
	await _case_d06_order_flow(res, host)
	await _case_d07_metrics_scales(res, host)
	await _case_d08_coach_plan(res, host)
	await _case_d09_customize_tree(res, host)
	CampaignClock.minutes = clock
	GameState.bank_notes = bank
	PulseClock.reset()
	MetricsHistory.clear()
	MetricsHistory.clear_preview()
	GuildRoster.reset()
	SubscriptionManager.max_out()
	BazaarManager.reset()
	TestFixtures.reset_campaign()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	return TestFixtures.summarize(res, "GUI CLICK D")


#A fresh campaign on Enterprise holding exactly the upgrade tiers the step starts from.
static func _fresh(tiers: Dictionary) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, tiers)
	BazaarManager.reset()
	TestFixtures.fund_budget(SubscriptionManager.BUDGET_FALLBACK)


static func _drop(host: Node, hud: GameHUD) -> void:
	hud.popup().close()
	await host.get_tree().process_frame
	hud.queue_free()
	await host.get_tree().process_frame


#Opens one HUD tile the way the player does, by pressing its button.
static func _press_tile(host: Node, hud: GameHUD, key: StringName) -> Node:
	var button: GridMenuButton = hud.button_of(key)
	if button == null:
		return null
	button.press()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return hud.popup().current()


#The first roster merc that is free right now; Amendment 1 holds the seeded crews and captives.
static func _free_view() -> MercView:
	var idle: Array[MercView] = GuiManagerTests.idle_views(1)
	if not idle.is_empty():
		return idle[0]
	return null if GameState.roster.is_empty() else GameState.roster[0]


#The count label a filter row carries on its right edge.
static func _row_count(panel: FilterPanel, key: String) -> int:
	var row: Button = panel.row_for(key)
	if row == null:
		return -1
	for child: Node in row.get_children():
		if child is Label:
			return int((child as Label).text)
	return -1


static func _total_of(cart: Dictionary) -> int:
	var sum: int = 0
	for id: Variant in cart:
		var found: BazaarItemData = BazaarManager.item(int(id))
		if found != null:
			sum += found.price * int(cart[id])
	return sum


#Two catalog items the cart cases buy, taken from what the shop is showing.
static func _two_items(shop: ShopPage) -> Array[BazaarItemData]:
	var out: Array[BazaarItemData] = []
	for found: BazaarItemData in shop.results():
		out.append(found)
		if out.size() == 2:
			break
	return out


#Every catalog id the README filter of the step would leave on the shelf.
static func _expected(dept: String, subs: Array[String], lo: int, hi: int) -> Array[int]:
	var out: Array[int] = []
	for found: BazaarItemData in BazaarManager.catalog:
		if not BazaarManager.available(found):
			continue
		if dept != "" and found.department != dept:
			continue
		if not subs.is_empty() and not subs.has(found.subtype):
			continue
		if lo >= 0 and found.price < lo:
			continue
		if hi >= 0 and found.price >= hi:
			continue
		out.append(found.id)
	out.sort()
	return out


static func _shown(shop: ShopPage) -> Array[int]:
	var out: Array[int] = []
	for found: BazaarItemData in shop.results():
		out.append(found.id)
	out.sort()
	return out


#D1: "HUD shows My Mercday; My Bazaar is locked on Free/Pro and on Enterprise without the
#upgrade. Clicking it opens the lock dialog only; Take Me There lands on the Bazaar upgrade."
static func _case_d01_bazaar_locked(res: Dictionary, host: Node) -> void:
	_fresh({})
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "D1 the plan tile of the HUD reads My Mercday",
		hud.label_of(&"mercday") == "My Mercday"
		and hud.button_of(&"mercday").label == "My Mercday",
		"'%s'" % hud.button_of(&"mercday").label)
	TestFixtures.check(res, "D1 the bazaar tile reads My Bazaar",
		hud.label_of(&"bazaar") == "My Bazaar" and hud.button_of(&"bazaar").label == "My Bazaar",
		"'%s'" % hud.button_of(&"bazaar").label)
	TestFixtures.check(res, "D1 My Bazaar is locked on Mercday Free",
		hud.is_locked(&"bazaar") and hud.button_of(&"bazaar").locked
		and hud.lock_tooltip(&"bazaar") == GuiHudTests.PLAN_TIP, "'%s'" % hud.lock_tooltip(&"bazaar"))
	hud.button_of(&"bazaar").press()
	await host.get_tree().process_frame
	var free_lines: Array[String] = GuiHudTests.lock_lines(hud)
	TestFixtures.check(res, "D1 the press on Free opens the lock dialog and no Bazaar window",
		hud.lock_dialog() != null and hud.lock_dialog().visible and not hud.popup().is_open()
		and free_lines[0] == GuiHudTests.PLAN_LINE1 and free_lines[1] == GuiHudTests.BAZAAR_PLAN_LINE2,
		"'%s' / '%s'" % [free_lines[0], free_lines[1]])
	var free_target: Dictionary = GuiHudTests.press_take_me_there(hud.lock_dialog())
	TestFixtures.check(res, "D1 Take Me There on Free lands on the Plans tab",
		String(free_target.get("tab", "")) == "plans", str(free_target))
	await host.get_tree().process_frame
	hud.popup().close()
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	hud.button_of(&"bazaar").press()
	await host.get_tree().process_frame
	var pro_lines: Array[String] = GuiHudTests.lock_lines(hud)
	TestFixtures.check(res, "D1 My Bazaar is locked on Mercday Pro with the same plan copy",
		hud.is_locked(&"bazaar") and hud.lock_tooltip(&"bazaar") == GuiHudTests.PLAN_TIP
		and not hud.popup().is_open() and pro_lines[0] == GuiHudTests.PLAN_LINE1
		and pro_lines[1] == GuiHudTests.BAZAAR_PLAN_LINE2, "'%s'" % pro_lines[1])
	hud.lock_dialog().press_close()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "D1 Enterprise without the upgrade keeps My Bazaar locked",
		hud.is_locked(&"bazaar") and hud.button_of(&"bazaar").locked
		and hud.lock_tooltip(&"bazaar") == GuiHudTests.BAZAAR_UP_TIP, "'%s'" % hud.lock_tooltip(&"bazaar"))
	hud.button_of(&"bazaar").press()
	await host.get_tree().process_frame
	var ent_lines: Array[String] = GuiHudTests.lock_lines(hud)
	TestFixtures.check(res, "D1 the press on Enterprise names the missing upgrade, not the plan",
		hud.lock_dialog().visible and not hud.popup().is_open()
		and ent_lines[0] == GuiHudTests.BAZAAR_UP_LINE1 and ent_lines[1] == GuiHudTests.BAZAAR_UP_LINE2,
		"'%s' / '%s'" % [ent_lines[0], ent_lines[1]])
	var target: Dictionary = GuiHudTests.press_take_me_there(hud.lock_dialog())
	TestFixtures.check(res, "D1 Take Me There aims at the Bazaar upgrade of the Customize tree",
		String(target.get("tab", "")) == "customize"
		and String(target.get("upgrade", "")) == "bazaar" and int(target.get("tier", 0)) == 1,
		str(target))
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var subs: SubscriptionViewer = hud.popup().current() as SubscriptionViewer
	var page: CustomizePage = null if subs == null else subs.customize_page()
	var tree: SkillTree = null if page == null else page.tree_node() as SkillTree
	var dialog: UpgradeTierDialog = null if tree == null else tree.dialog()
	TestFixtures.check(res, "D1 Take Me There opens My Mercday on Customize at the Bazaar module",
		subs != null and subs.current_tab() == SubscriptionViewer.CUSTOMIZE_TAB
		and dialog != null and dialog.is_open() and dialog.upgrade_id() == "bazaar",
		"tab %s" % ("none" if subs == null else String(subs.current_tab())))
	await _drop(host, hud)


#D2: "Buy Bazaar I -> button unlocks -> window opens on Shop."
static func _case_d02_buy_unlocks(res: Dictionary, host: Node) -> void:
	_fresh({})
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	hud.button_of(&"bazaar").press()
	await host.get_tree().process_frame
	var _aim: Dictionary = GuiHudTests.press_take_me_there(hud.lock_dialog())
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var subs: SubscriptionViewer = hud.popup().current() as SubscriptionViewer
	var tree: SkillTree = subs.customize_page().tree_node() as SkillTree
	var dialog: UpgradeTierDialog = tree.dialog()
	var charge: int = dialog.charge_today()
	var bank: int = GameState.bank_notes
	TestFixtures.check(res, "D2 the Bazaar module opens unowned and names a charge for today",
		dialog.is_open() and dialog.tier() == 0 and charge > 0
		and SubscriptionManager.tier_of("bazaar") == 0, "%d notes today" % charge)
	dialog.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D2 buying Bazaar I takes the notes the dialog named out of the bank",
		SubscriptionManager.tier_of("bazaar") == 1 and GameState.bank_notes == bank - charge,
		"bank %d of %d" % [GameState.bank_notes, bank - charge])
	var row: TransactionData = FinanceLedger.rows(1)[0]
	TestFixtures.check(res, "D2 the buy files its own ledger row",
		row.label == "Bazaar I" and row.amount == -charge, "'%s' %d" % [row.label, row.amount])
	TestFixtures.check(res, "D2 the HUD tile unlocks the moment the upgrade is owned",
		not hud.is_locked(&"bazaar") and not hud.button_of(&"bazaar").locked
		and hud.lock_tooltip(&"bazaar") == "", "'%s'" % hud.lock_tooltip(&"bazaar"))
	hud.popup().close()
	await host.get_tree().process_frame
	var view: Node = await _press_tile(host, hud, &"bazaar")
	var bazaar: BazaarViewer = view as BazaarViewer
	TestFixtures.check(res, "D2 pressing My Bazaar now opens the Bazaar window",
		hud.popup().is_open() and bazaar != null and not hud.lock_dialog().visible,
		"opened %s" % ("nothing" if view == null else view.get_class()))
	TestFixtures.check(res, "D2 the Bazaar window opens on the Shop tab",
		bazaar != null and bazaar.current_tab() == BazaarViewer.TAB_KEYS[0]
		and bazaar.shop.visible and not bazaar.lock.visible,
		"tab %s" % ("none" if bazaar == null else String(bazaar.current_tab())))
	await _drop(host, hud)


#D3: "Shop: pick Weapons -> Type filter appears; check two subtypes; set 50-150; counts and
#results update; Clear all filters resets."
static func _case_d03_shop_filters(res: Dictionary, host: Node) -> void:
	_fresh({"bazaar": 1, "betteritems": UpgradeDefs.tier_count("betteritems")})
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var bazaar: BazaarViewer = await _press_tile(host, hud, &"bazaar") as BazaarViewer
	var shop: ShopPage = bazaar.shop
	var panel: FilterPanel = shop.filter_panel()
	var opening: int = shop.result_count()
	TestFixtures.check(res, "D3 the Shop opens on the whole catalogue with no filter active",
		not panel.any_active() and shop.breadcrumb_text() == ALL_CRUMB_TEXT
		and _shown(shop) == _expected("", [], -1, -1) and shop.card_count() == opening,
		"%d items, %d cards" % [opening, shop.card_count()])
	TestFixtures.check(res, "D3 the Type filter is absent until a department is picked",
		not panel.has_type_section(), "type head %s" % str(panel.head_for("type_head")))
	shop.pick_department(WEAPONS)
	await host.get_tree().process_frame
	TestFixtures.check(res, "D3 picking Weapons brings up the Weapons Type filter",
		panel.has_type_section() and panel.head_for("type_head").text == TYPE_HEAD,
		"'%s'" % ("" if not panel.has_type_section() else panel.head_for("type_head").text))
	var weapon_count: int = shop.result_count()
	TestFixtures.check(res, "D3 the Weapons shelf holds weapons only and matches its own count",
		_shown(shop) == _expected(WEAPONS, [], -1, -1)
		and weapon_count == _row_count(panel, WEAPONS) and weapon_count < opening
		and shop.breadcrumb_text() == WEAPONS_CRUMB,
		"%d shown, row says %d" % [weapon_count, _row_count(panel, WEAPONS)])
	var sword_all: int = _row_count(panel, SUB_A)
	shop.toggle_subtype(SUB_A)
	await host.get_tree().process_frame
	shop.toggle_subtype(SUB_B)
	await host.get_tree().process_frame
	var two_subs: Array[String] = [SUB_A, SUB_B]
	var subs_count: int = shop.result_count()
	TestFixtures.check(res, "D3 two checked subtypes leave only those two on the shelf",
		panel.checked_subtypes().size() == 2
		and _shown(shop) == _expected(WEAPONS, two_subs, -1, -1) and subs_count < weapon_count,
		"%d of %d weapons" % [subs_count, weapon_count])
	TestFixtures.check(res, "D3 the breadcrumb names the department and both subtypes",
		shop.breadcrumb_text() == "%s%s%s, %s" % [WEAPONS_CRUMB, CRUMB_JOIN_TEXT,
		SUB_A, SUB_B], "the crumb read %s" % shop.breadcrumb_text())
	TestFixtures.check(res, "D3 the two subtype counts add up to the result count",
		subs_count == _row_count(panel, SUB_A) + _row_count(panel, SUB_B)
		and shop.card_count() == subs_count,
		"%d + %d for %d" % [_row_count(panel, SUB_A), _row_count(panel, SUB_B), subs_count])
	shop.pick_price(PRICE_KEY)
	await host.get_tree().process_frame
	var band: Dictionary = BazaarManager.preset(PRICE_KEY)
	var priced: int = shop.result_count()
	var inside: bool = true
	for found: BazaarItemData in shop.results():
		if found.price < LOW or found.price > HIGH:
			inside = false
	TestFixtures.check(res, "D3 the 50 to 150 band leaves no price outside it",
		inside and priced > 0 and String(band["label"]) == "50 to 150",
		"%d items under '%s'" % [priced, String(band["label"])])
	TestFixtures.check(res, "D3 the band narrows the shelf and the counts with it",
		_shown(shop) == _expected(WEAPONS, two_subs, int(band["lo"]), int(band["hi"]))
		and priced <= subs_count and _row_count(panel, SUB_A) <= sword_all,
		"%d of %d, swords %d of %d" % [priced, subs_count, _row_count(panel, SUB_A), sword_all])
	var link: Button = panel.clear_link()
	TestFixtures.check(res, "D3 the filter panel offers the Clear all filters link",
		link != null and link.text == CLEAR_TEXT and panel.any_active(),
		"'%s'" % ("" if link == null else link.text))
	shop.clear_filters()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D3 Clear all filters puts the whole catalogue back",
		shop.result_count() == opening and _shown(shop) == _expected("", [], -1, -1)
		and not panel.any_active() and not panel.has_type_section()
		and shop.breadcrumb_text() == ALL_CRUMB_TEXT,
		"%d of %d back" % [shop.result_count(), opening])
	await _drop(host, hud)


#D4: "Rarity: with Better Items 2, Rare and Very Rare are locked; buy tier 3 -> Rare unlocks."
static func _case_d04_rarity_locks(res: Dictionary, host: Node) -> void:
	_fresh({"bazaar": 1, "betteritems": 2})
	GameState.bank_notes = RICH
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var bazaar: BazaarViewer = await _press_tile(host, hud, &"bazaar") as BazaarViewer
	var shop: ShopPage = bazaar.shop
	var panel: FilterPanel = shop.filter_panel()
	var rare_name: String = BazaarUi.rarity_name(RARE)
	var top_name: String = BazaarUi.rarity_name(VERY_RARE)
	TestFixtures.check(res, "D4 Better Items 2 locks the Rare and Very Rare rows",
		panel.lock_for(RARE) != null and panel.lock_for(VERY_RARE) != null
		and panel.row_for(rare_name) == null and panel.row_for(top_name) == null,
		"%s / %s" % [rare_name, top_name])
	var rare_lock: FeatureLock = panel.lock_for(RARE)
	TestFixtures.check(res, "D4 the Rare lock names the Better Items tier that opens it",
		rare_lock != null and rare_lock.upgrade_id == "betteritems" and rare_lock.tier == RARE
		and rare_lock.upgrade == UpgradeDefs.name_of("betteritems"),
		"'%s' tier %d" % ["" if rare_lock == null else rare_lock.upgrade,
			0 if rare_lock == null else rare_lock.tier])
	var open_rows: int = 0
	for i: int in RARE:
		if panel.row_for(BazaarUi.rarity_name(i)) != null:
			open_rows += 1
	TestFixtures.check(res, "D4 the three rarities the guild owns stay open rows",
		open_rows == RARE and BazaarManager.rarity_cap() == 2, "%d open rows" % open_rows)
	var bank: int = GameState.bank_notes
	var charge: int = SubscriptionManager.upgrade_charge_today("betteritems", RARE)
	var bought: bool = SubscriptionManager.buy_tier("betteritems")
	await host.get_tree().process_frame
	TestFixtures.check(res, "D4 buying Better Items 3 charges the upgrade and raises the cap",
		bought and SubscriptionManager.tier_of("betteritems") == RARE
		and BazaarManager.rarity_cap() == RARE and GameState.bank_notes == bank - charge,
		"bank %d of %d" % [GameState.bank_notes, bank - charge])
	TestFixtures.check(res, "D4 the buy opens the Rare row and leaves Very Rare locked",
		panel.lock_for(RARE) == null and panel.row_for(rare_name) != null
		and panel.lock_for(VERY_RARE) != null and panel.row_for(top_name) == null,
		"rare row %s" % str(panel.row_for(rare_name)))
	shop.toggle_rarity(RARE)
	await host.get_tree().process_frame
	var only_rare: bool = shop.result_count() > 0
	for found: BazaarItemData in shop.results():
		if found.rarity != RARE:
			only_rare = false
	var picked: Array = panel.query()["rarities"] as Array
	TestFixtures.check(res, "D4 the freed Rare row filters the shelf down to Rare items",
		only_rare and picked.has(RARE), "%d items" % shop.result_count())
	await _drop(host, hud)


#D5: "Cart: adding items raises the Cart tab badge by the quantity; a cart total above the bank
#disables checkout." The red total carries the warning; no reason line prints for it.
static func _case_d05_cart_badge(res: Dictionary, host: Node) -> void:
	_fresh({"bazaar": 1, "betteritems": 4})
	GameState.bank_notes = RICH
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var bazaar: BazaarViewer = await _press_tile(host, hud, &"bazaar") as BazaarViewer
	var shop: ShopPage = bazaar.shop
	var picked: Array[BazaarItemData] = _two_items(shop)
	TestFixtures.check(res, "D5 the shop holds two items to put in the cart",
		picked.size() == 2, "the shop showed %d items" % picked.size())
	for found: BazaarItemData in picked:
		shop.card_for(found.id).press_add()
	await host.get_tree().process_frame
	shop.card_for(picked[0].id).press_plus()
	await host.get_tree().process_frame
	var cart_tab: TabButton = bazaar.tab_button(BazaarViewer.TAB_KEYS[1])
	var counted: int = BazaarManager.cart_count()
	TestFixtures.check(res, "D5 the Cart tab badge counts the items in the cart",
		cart_tab.badge == counted,
		"the badge reads %d for a cart of %d" % [cart_tab.badge, counted])
	bazaar.press_tab(BazaarViewer.TAB_KEYS[1])
	await host.get_tree().process_frame
	var cart: CartPage = bazaar.cart
	var total: int = BazaarManager.cart_total()
	TestFixtures.check(res, "D5 the cart lists one row per item and counts the quantity",
		cart.row_count() == picked.size()
		and cart.count_text() == "%d items" % counted
		and total == _total_of(BazaarManager.cart),
		"%d rows and the line %s" % [cart.row_count(), cart.count_text()])
	var summary: OrderSummary = cart.summary()
	GameState.bank_notes = total - 1
	cart.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D5 a cart over the bank shuts checkout and prints no line under it",
		summary.checkout_button().disabled
		and is_equal_approx(summary.checkout_button().modulate.a, DIM_ALPHA)
		and summary.reason_text() == "",
		"reason %s at alpha %f" % [summary.reason_text(), summary.checkout_button().modulate.a])
	cart.press_checkout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D5 a shut checkout never opens the checkout dialog",
		not bazaar.checkout.is_open(), "the dialog opened over a cart nobody can pay")
	GameState.bank_notes = RICH
	cart.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D5 notes enough for the cart open the checkout button again",
		not summary.checkout_button().disabled and summary.reason_text() == ""
		and is_equal_approx(summary.checkout_button().modulate.a, 1.0),
		"the button stayed shut on %d notes" % GameState.bank_notes)
	await _drop(host, hud)


#D6: "Order: placing an order lowers the bank by the total, empties the cart, and Orders lists the
#order as Arriving with a partly filled bar; after buying Faster Items 5 a new order is 2-Day."
static func _case_d06_order_flow(res: Dictionary, host: Node) -> void:
	_fresh({"bazaar": 1, "betteritems": 4})
	GameState.bank_notes = RICH
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var bazaar: BazaarViewer = await _press_tile(host, hud, &"bazaar") as BazaarViewer
	var shop: ShopPage = bazaar.shop
	for found: BazaarItemData in _two_items(shop):
		shop.card_for(found.id).press_add()
	await host.get_tree().process_frame
	var lines: int = BazaarManager.cart_ids().size()
	var total: int = BazaarManager.cart_total()
	var bank: int = GameState.bank_notes
	bazaar.press_tab(BazaarViewer.TAB_KEYS[1])
	await host.get_tree().process_frame
	bazaar.cart.press_checkout()
	await host.get_tree().process_frame
	var checkout: CheckoutDialog = bazaar.checkout
	TestFixtures.check(res, "D6 the cart hands the order to the checkout dialog",
		checkout.is_open() and checkout.line_count() == lines,
		"the dialog showed %d of %d lines" % [checkout.line_count(), lines])
	checkout.press_place()
	await host.get_tree().process_frame
	var order: OrderData = BazaarManager.orders[BazaarManager.orders.size() - 1]
	TestFixtures.check(res, "D6 placing the order pays the total and empties the cart",
		GameState.bank_notes == bank - total and BazaarManager.cart_count() == 0
		and order.total == total, "the bank went %d to %d for a total of %d" % [bank,
		GameState.bank_notes, total])
	var placed: OrderPlacedDialog = bazaar.placed
	TestFixtures.check(res, "D6 the order placed dialog names the order and its delivery",
		placed.is_open() and placed.message_text().begins_with("Order #%d will arrive" % order.id)
		and placed.message_text().ends_with(" (%d days)." % order.days),
		"the dialog read %s" % placed.message_text())
	placed.press_view()
	await host.get_tree().process_frame
	var orders: OrdersPage = bazaar.orders
	var card: OrderCard = orders.card_for(order.id)
	TestFixtures.check(res, "D6 View Orders lands on the Orders tab with the order as Arriving",
		bazaar.current_tab() == BazaarViewer.TAB_KEYS[2] and card != null
		and card.title_text().begins_with("Arriving ") and card.filled_cells() == 0
		and card.chip_count() == lines, "the Orders tab showed %d cards" % orders.card_count())
	GuiManagerTests.advance_days(int(floor(float(order.days) / 2.0)))
	await host.get_tree().process_frame
	card = orders.card_for(order.id)
	TestFixtures.check(res, "D6 the bar fills part way while the order is still on the road",
		card != null and card.filled_cells() > 0 and card.filled_cells() < PROGRESS_CELLS
		and card.title_text().begins_with("Arriving "),
		"the bar read %d cells" % (-1 if card == null else card.filled_cells()))
	GameState.bank_notes = RICH
	for _i: int in FAST_TIER:
		SubscriptionManager.buy_tier("fasteritems")
	await host.get_tree().process_frame
	TestFixtures.check(res, "D6 Faster Items 5 cuts the delivery to two days",
		SubscriptionManager.tier_of("fasteritems") == FAST_TIER
		and BazaarManager.delivery_days() == FAST_DAYS,
		"tier %d gives %d days" % [SubscriptionManager.tier_of("fasteritems"),
		BazaarManager.delivery_days()])
	var again: BazaarItemData = _two_items(shop)[0]
	shop.card_for(again.id).press_add()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D6 a shop card under Faster Items 5 offers the 2-Day delivery",
		shop.card_for(again.id).eta_label().text.ends_with("(2-Day)"),
		"the card read %s" % shop.card_for(again.id).eta_label().text)
	bazaar.press_tab(BazaarViewer.TAB_KEYS[1])
	await host.get_tree().process_frame
	bazaar.cart.press_checkout()
	await host.get_tree().process_frame
	checkout.press_place()
	await host.get_tree().process_frame
	var fast: OrderData = BazaarManager.orders[BazaarManager.orders.size() - 1]
	TestFixtures.check(res, "D6 the new order is placed as a 2-Day delivery",
		fast.days == FAST_DAYS and placed.message_text().ends_with(" (2-Day delivery)."),
		"order %d runs %d days and reads %s" % [fast.id, fast.days, placed.message_text()])
	await _drop(host, hud)


#D7: "Metrics: Period 6m makes every scale valid; with the scale Days picked, switching the period
#to 3y snaps the scale to Months." README A3 gives the rule the screen follows: Days 6m or less,
#Weeks 1y or less, Months 6m or more, Quarters 1y or more.
static func _case_d07_metrics_scales(res: Dictionary, host: Node) -> void:
	_fresh({})
	var uids: Array[int] = []
	for view: MercView in GameState.roster:
		uids.append(view.uid)
	MetricsHistory.seed_preview(DEEP_DAYS, uids)
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var metrics: MetricsViewer = await _press_tile(host, hud, &"metrics") as MetricsViewer
	metrics.period_drop.open_popup()
	await host.get_tree().process_frame
	metrics.period_drop.row_for(&"m6").pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D7 the Period dropdown moves the chart window to 6m",
		metrics.period == MetricsPeriod.Period.M6 and metrics.period_drop.button_text() == "6m"
		and metrics.span_days() == HALF_YEAR_DAYS,
		"the window reads %s over %d days" % [metrics.period_drop.button_text(),
		metrics.span_days()])
	metrics.scale_drop.open_popup()
	await host.get_tree().process_frame
	var day_row: Button = metrics.scale_drop.row_for(&"day")
	var week_row: Button = metrics.scale_drop.row_for(&"week")
	var month_row: Button = metrics.scale_drop.row_for(&"month")
	var quarter_row: Button = metrics.scale_drop.row_for(&"quarter")
	TestFixtures.check(res, "D7 at 6m the Days, Weeks and Months scales are all open",
		day_row != null and week_row != null and month_row != null
		and day_row.tooltip_text == "" and week_row.tooltip_text == ""
		and month_row.tooltip_text == "", "a scale of the 6m window carried a reason")
	TestFixtures.check(res, "D7 at 6m Quarters is the one scale the window cannot carry",
		quarter_row != null and quarter_row.tooltip_text == REASON_QUARTER
		and quarter_row.get_theme_color(&"font_color").is_equal_approx(GREY_TEXT),
		"Quarters read %s" % ("" if quarter_row == null else quarter_row.tooltip_text))
	day_row.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D7 picking Days puts the chart on the Days scale",
		metrics.chart_scale == MetricsPeriod.Scale.DAY
		and metrics.scale_drop.button_text() == "Days",
		"the scale reads %s" % metrics.scale_drop.button_text())
	metrics.period_drop.open_popup()
	await host.get_tree().process_frame
	metrics.period_drop.row_for(&"y3").pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D7 switching the period to 3y snaps the scale from Days to Months",
		metrics.period == MetricsPeriod.Period.Y3
		and metrics.chart_scale == MetricsPeriod.Scale.MONTH
		and metrics.scale_drop.button_text() == "Months",
		"3y left the chart on %s" % metrics.scale_drop.button_text())
	metrics.scale_drop.open_popup()
	await host.get_tree().process_frame
	var day_row_3y: Button = metrics.scale_drop.row_for(&"day")
	var week_row_3y: Button = metrics.scale_drop.row_for(&"week")
	TestFixtures.check(res, "D7 at 3y Days is greyed with the reason it needs 6m or less",
		day_row_3y != null and day_row_3y.tooltip_text == REASON_DAY
		and day_row_3y.get_theme_color(&"font_color").is_equal_approx(GREY_TEXT),
		"Days read %s" % ("" if day_row_3y == null else day_row_3y.tooltip_text))
	TestFixtures.check(res, "D7 at 3y Weeks is greyed with the reason it needs 1y or less",
		week_row_3y != null and week_row_3y.tooltip_text == REASON_WEEK
		and week_row_3y.get_theme_color(&"font_color").is_equal_approx(GREY_TEXT),
		"Weeks read %s" % ("" if week_row_3y == null else week_row_3y.tooltip_text))
	await _drop(host, hud)
	MetricsHistory.clear_preview()


#A free roster merc whose lifepath carries events, so the D8 list has rows to show.
static func _lifepath_view() -> MercView:
	var busy: Array[int] = GameState.busy_uids()
	for view: MercView in GameState.roster:
		if not busy.has(view.uid) and not view.lifepaths.is_empty():
			return view
	return _free_view()


#D8: "Merc Viewer: the Lifepath list shows events (entitlement lifepath met); Coach, pick Support,
#Confirm gives the line Plan: Support; removing the Combat PIP upgrade in Customize puts the merc
#back to Plan: Auto."
static func _case_d08_coach_plan(res: Dictionary, host: Node) -> void:
	_fresh({"background": 5, "pip": 1, "combatpip": 1})
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var mercs: MercViewer = await _press_tile(host, hud, &"mercs") as MercViewer
	var view: MercView = _lifepath_view()
	mercs.show_merc(view.uid)
	mercs.select_tab(MercViewer.TAB_OVERVIEW)
	await host.get_tree().process_frame
	var overview: OverviewTab = mercs.overview()
	var chips: Array[SlotChip] = overview.lifepath_chips()
	var filled: int = overview.filled_count(chips)
	TestFixtures.check(res, "D8 Background Check 5 opens the Lifepath block and lists its events",
		not overview.lifepath_lock.is_locked() and overview.lifepath_scroll.visible
		and chips.size() == LIFEPATH_SLOTS and filled > 0
		and filled == mini(view.lifepaths.size(), LIFEPATH_SLOTS)
		and overview.lifepath_count.text == "%d/%d" % [filled, LIFEPATH_SLOTS],
		"%d of %d chips filled and the head read %s" % [filled, chips.size(),
		overview.lifepath_count.text])
	var box: CoachingBox = overview.coaching_box()
	TestFixtures.check(res, "D8 the merc opens on the Auto plan",
		box.plan_text() == "Plan: Auto" and box.can_coach(),
		"the box read %s" % box.plan_text())
	box.press_coach()
	await host.get_tree().process_frame
	var coach: CoachDialog = mercs.coach_dialog()
	coach.press_mode(&"Support")
	await host.get_tree().process_frame
	TestFixtures.check(res, "D8 the Coach dialog takes the Support plan and opens Confirm",
		coach.visible and coach.confirm_enabled() and coach.module_for(&"Support") != null,
		"the dialog showed %d modules" % coach.modules().size())
	coach.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D8 confirming the plan writes the line Plan: Support",
		box.plan_text() == "Plan: Support" and GameState.pip_mode(view.uid) == &"Support"
		and not coach.visible, "the box read %s" % box.plan_text())
	hud.popup().close()
	await host.get_tree().process_frame
	var subs: SubscriptionViewer = await _press_tile(host, hud, &"mercday") as SubscriptionViewer
	subs.open_tab(SubscriptionViewer.CUSTOMIZE_TAB)
	await host.get_tree().process_frame
	var tree: SkillTree = subs.customize_page().tree_node() as SkillTree
	tree.press_block("combatpip")
	await host.get_tree().process_frame
	var dialog: UpgradeTierDialog = tree.dialog()
	dialog.press_minus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "D8 the tier dialog drops the Combat PIP upgrade off the guild",
		dialog.is_open() and dialog.upgrade_id() == "combatpip" and dialog.tier() == 0
		and not bool(SubscriptionManager.entitlements().get("lvSupport", false)),
		"the dialog left Combat PIP at tier %d" % dialog.tier())
	hud.popup().close()
	await host.get_tree().process_frame
	mercs = await _press_tile(host, hud, &"mercs") as MercViewer
	mercs.show_merc(view.uid)
	mercs.select_tab(MercViewer.TAB_OVERVIEW)
	await host.get_tree().process_frame
	TestFixtures.check(res, "D8 losing the upgrade puts the merc back on Plan: Auto",
		mercs.overview().coaching_box().plan_text() == "Plan: Auto"
		and GameState.pip_mode(view.uid) == &"Auto",
		"the box read %s" % mercs.overview().coaching_box().plan_text())
	await _drop(host, hud)


#Every connector segment with an endpoint on the edge of one box, in the canvas' own space.
static func _touching(canvas: TreeCanvas, box: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wide: Rect2 = box.grow(1.0)
	for row: Dictionary in canvas.connectors():
		var pts: PackedVector2Array = row["points"]
		if pts.size() < 2:
			continue
		if wide.has_point(pts[0]) or wide.has_point(pts[pts.size() - 1]):
			out.append(row)
	return out


#The end of one segment that lies away from a box.
static func _far_end(row: Dictionary, box: Rect2) -> Vector2:
	var pts: PackedVector2Array = row["points"]
	return pts[pts.size() - 1] if box.grow(1.0).has_point(pts[0]) else pts[0]


#Every other connector segment that ends on one point.
static func _meeting(canvas: TreeCanvas, at: Vector2, skip: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in canvas.connectors():
		if is_same(row, skip):
			continue
		var pts: PackedVector2Array = row["points"]
		if pts.size() < 2:
			continue
		if pts[0].distance_to(at) < 0.5 or pts[pts.size() - 1].distance_to(at) < 0.5:
			out.append(row)
	return out


#The leg of a touching pair that runs out of the gate: the one whose far end meets no other leg.
static func _out_leg(canvas: TreeCanvas, touch: Array[Dictionary], box: Rect2) -> Dictionary:
	for row: Dictionary in touch:
		if _meeting(canvas, _far_end(row, box), row).size() < 2:
			return row
	return {}


#D9: "Customize: the merged leg into the gate of Criminal Background Check is the blend colour
#when one parent is complete (green) and the other is not (red); a line out of an unmet module is
#drawn at 50 percent opacity; completing Limits makes its icon glow, and the glow reads
#PulseClock (the same phase as every other glow; no timer and no tween of its own)."
static func _case_d09_customize_tree(res: Dictionary, host: Node) -> void:
	var tiers: Dictionary = {"discrim": UpgradeDefs.tier_count("discrim"),
		"pip": UpgradeDefs.tier_count("pip")}
	for id: String in TreeLayout.cat_members("limits"):
		tiers[id] = UpgradeDefs.tier_count(id)
	for id: String in TreeLayout.cat_members("coaching"):
		tiers[id] = UpgradeDefs.tier_count(id)
	_fresh(tiers)
	GameState.bank_notes = RICH
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var subs: SubscriptionViewer = await _press_tile(host, hud, &"mercday") as SubscriptionViewer
	subs.open_tab(SubscriptionViewer.CUSTOMIZE_TAB)
	await host.get_tree().process_frame
	var tree: SkillTree = subs.customize_page().tree_node() as SkillTree
	var canvas: TreeCanvas = tree.canvas()
	var gate: RequirementGate = canvas.gate("criminal")
	var box: Rect2 = Rect2(gate.position - Vector2(0.0, TreeLayout.OY), TreeLayout.GATE_BOX)
	var touch: Array[Dictionary] = _touching(canvas, box)
	var out_leg: Dictionary = _out_leg(canvas, touch, box)
	TestFixtures.check(res, "D9 one leg runs into the Criminal gate and one leg runs out of it",
		touch.size() == 2 and not out_leg.is_empty() and not gate.is_met()
		and SubscriptionManager.tier_of("discrim") == UpgradeDefs.tier_count("discrim"),
		"%d legs touch a gate that reads %s" % [touch.size(), gate.text_value()])
	var in_leg: Dictionary = touch[0] if is_same(touch[1], out_leg) else touch[1]
	var parents: Array[Dictionary] = _meeting(canvas, _far_end(in_leg, box), in_leg)
	var blend: Color = in_leg["color_a"]
	var one: Color = parents[0]["color_a"]
	var two: Color = parents[1]["color_a"] if parents.size() > 1 else one
	var lit: Color = one if one.g > one.r else two
	var dark: Color = two if one.g > one.r else one
	TestFixtures.check(res, "D9 the Criminal gate is fed by one green parent and one red parent",
		parents.size() == 2 and lit.g > lit.r and lit.g > lit.b
		and dark.r > dark.g and dark.r > dark.b,
		"the legs read %s and %s" % [str(one), str(two)])
	var pb0: Color = parents[0]["color_b"]
	var pb1: Color = parents[parents.size() - 1]["color_b"]
	TestFixtures.check(res, "D9 the merged leg into the gate is the blend of the two parents",
		is_equal_approx(blend.r, (one.r + two.r) / 2.0)
		and is_equal_approx(blend.g, (one.g + two.g) / 2.0)
		and is_equal_approx(blend.b, (one.b + two.b) / 2.0)
		and blend.b < minf(blend.r, blend.g) and absf(blend.r - blend.g) < OLIVE_SPREAD
		and pb0.is_equal_approx(blend) and pb1.is_equal_approx(blend),
		"the merged leg read %s over %s and %s" % [str(blend), str(one), str(two)])
	var out_alpha: float = out_leg["alpha"]
	var in_alpha: float = in_leg["alpha"]
	TestFixtures.check(res, "D9 the leg out of the unmet gate is drawn at half opacity",
		is_equal_approx(out_alpha, HALF_ALPHA) and is_equal_approx(in_alpha, 1.0),
		"the legs read %f out and %f in" % [out_alpha, in_alpha])
	var need: int = UpgradeDefs.requirement_need("criminal")
	for _i: int in UpgradeDefs.tier_count("background"):
		if UpgradeDefs.requirement_met("criminal", SubscriptionManager.tiers()):
			break
		SubscriptionManager.buy_tier("background")
	await host.get_tree().process_frame
	var met_leg: Dictionary = _out_leg(canvas, _touching(canvas, box), box)
	var met_alpha: float = 0.0 if met_leg.is_empty() else float(met_leg["alpha"])
	TestFixtures.check(res, "D9 meeting the requirement lights the leg out of the gate",
		canvas.gate("criminal").is_met() and is_equal_approx(met_alpha, 1.0)
		and canvas.gate("criminal").text_value() == "%d/%d" % [need, need],
		"the gate reads %s at %f" % [canvas.gate("criminal").text_value(), met_alpha])
	PulseClock.set_running(false)
	PulseClock.pulse.emit(0.0, PackedFloat32Array())
	var limits: CategoryBox = canvas.cat_box("limits")
	var coaching: CategoryBox = canvas.cat_box("coaching")
	var testing: CategoryBox = canvas.cat_box("testing")
	var met_gate: RequirementGate = canvas.gate("combatpip")
	TestFixtures.check(res, "D9 Limits and Coaching read complete while Testing stays open",
		limits.is_complete() and coaching.is_complete() and not testing.is_complete()
		and met_gate.is_met(), "Limits %s, Coaching %s, Testing %s" % [str(limits.is_complete()),
		str(coaching.is_complete()), str(testing.is_complete())])
	TestFixtures.check(res, "D9 a still pulse leaves every icon at its flat brightness",
		is_equal_approx(limits.glow_factor(), 1.0) and is_equal_approx(testing.glow_factor(), 1.0)
		and is_equal_approx(met_gate.glow_factor(), 1.0),
		"Limits read %f" % limits.glow_factor())
	PulseClock.pulse.emit(0.5, PackedFloat32Array())
	var half: float = limits.glow_factor()
	TestFixtures.check(res, "D9 the finished Limits icon glows on the shared PulseClock",
		half > 1.0 and is_equal_approx(half, coaching.glow_factor())
		and is_equal_approx(half, met_gate.glow_factor())
		and is_equal_approx(testing.glow_factor(), 1.0),
		"Limits %f, Coaching %f, gate %f" % [half, coaching.glow_factor(),
		met_gate.glow_factor()])
	PulseClock.pulse.emit(1.0, PackedFloat32Array())
	var full: float = limits.glow_factor()
	TestFixtures.check(res, "D9 a higher pulse lifts every finished icon by the same step",
		full > half and is_equal_approx(full, coaching.glow_factor())
		and is_equal_approx(full, met_gate.glow_factor())
		and is_equal_approx(testing.glow_factor(), 1.0),
		"the glow went %f to %f" % [half, full])
	PulseClock.set_running(true)
	await _drop(host, hud)

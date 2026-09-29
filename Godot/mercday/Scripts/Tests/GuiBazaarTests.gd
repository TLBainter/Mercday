class_name GuiBazaarTests
extends RefCounted

#Run: godot --headless --path . with the --gui-bazaar-tests flag.
#The My Bazaar window: the tab row and its lock, the Shop filters with their counts, the item
#cards, the cart and its summary, the checkout dialog and the Orders list. Every case drives the
#public helpers, because a synthetic click never reaches a button headless.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Bazaar/BazaarViewer.tscn")
const ALL_RARITY: int = 4
const FAST_TIER: int = 5
const FAST_DAYS: int = 2
const CATALOG_ITEMS: int = 140
const WEAPON_ITEMS: int = 30
const SUBTYPE_ITEMS: int = 5
const RICH: int = 400000
const PLAN_LINE1: String = "This feature of Mercday is not available on your plan!"
const PLAN_LINE2: String = "Upgrade to Mercday Enterprise to use the Bazaar."
const UPGRADE_LINE1: String = "The Bazaar is locked."
const UPGRADE_LINE2: String = "It requires the Bazaar upgrade!"
const EMPTY_REASON: String = "Your cart is empty."


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var bank: int = GameState.bank_notes
	_fresh()
	_full()
	await host.get_tree().process_frame
	var viewer: BazaarViewer = VIEWER.instantiate() as BazaarViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	await _case_tabs(res, host, viewer)
	await _case_lock(res, host, viewer)
	await _case_filters(res, host, viewer)
	await _case_rarity(res, host, viewer)
	await _case_search(res, host, viewer)
	await _case_sort(res, host, viewer)
	await _case_cards(res, host, viewer)
	await _case_cart(res, host, viewer)
	await _case_checkout(res, host, viewer)
	await _case_orders(res, host, viewer)
	await _case_badges(res, host, viewer)
	await _case_fix_round3(res, host, viewer)
	await _case_bevel_sweep(res, host, viewer)
	viewer.queue_free()
	await host.get_tree().process_frame
	CampaignClock.minutes = clock
	GameState.bank_notes = bank
	SubscriptionManager.reset()
	BazaarManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	return TestFixtures.summarize(res, "GUI BAZAAR")


#Every case starts on a fresh campaign with an Enterprise plan that holds no upgrade tier, so a
#case that wants the Bazaar open says so with _full().
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	BazaarManager.reset()


#The Bazaar open, every rarity buyable and the fastest delivery, which is the two day tier.
static func _full() -> void:
	SubscriptionManager.set_entitlements({"bazaar": true, "bazaarRarity": ALL_RARITY,
		"bazaarSpeed": FAST_TIER})


static func _reset(viewer: BazaarViewer) -> void:
	_fresh()
	_full()
	viewer.open_tab(BazaarViewer.TAB_KEYS[0])
	viewer.orders_page().filter = BazaarManager.ORDER_FILTERS[0]
	viewer.shop_page().pick_sort(BazaarManager.SORTS[0])
	viewer.shop_page().clear_filters()
	viewer.checkout_dialog().close()
	viewer.placed_dialog().close()
	viewer.refresh()


static func _fund(amount: int) -> void:
	GameState.refund(amount)


#Crosses day boundaries without running the contract machinery: the clock moves and the day
#signal fires, which is all the Bazaar listens for.
static func _advance_days(n: int) -> void:
	CampaignClock.advance(n * CampaignClock.MINUTES_PER_DAY)
	GameState.day_changed.emit(GameState.day())


static func _item_named(item_name: String) -> BazaarItemData:
	for found: BazaarItemData in BazaarManager.catalog:
		if found.name == item_name:
			return found
	return null


static func _rarity_count(index: int) -> int:
	var count: int = 0
	for found: BazaarItemData in BazaarManager.catalog:
		if found.rarity == index:
			count += 1
	return count


#Catalog items of one department inside a price band; either end may be -1 for an open end.
static func _price_count(department: String, low: int, high: int) -> int:
	var count: int = 0
	for found: BazaarItemData in BazaarManager.catalog:
		if department != "" and found.department != department:
			continue
		if low >= 0 and found.price < low:
			continue
		if high >= 0 and found.price > high:
			continue
		count += 1
	return count


#Case 1: the tab row, the pages under it and the delivery dot on the Orders tab.
static func _case_tabs(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the three tab keys read shop, cart and orders",
		BazaarViewer.TAB_KEYS == [&"shop", &"cart", &"orders"], str(BazaarViewer.TAB_KEYS))
	TestFixtures.check(res, "the viewer opens on the Shop tab with the other pages hidden",
		viewer.current_tab() == &"shop" and viewer.shop_page().visible
		and not viewer.cart_page().visible and not viewer.orders_page().visible,
		"tab %s" % viewer.current_tab())
	TestFixtures.check(res, "the tab row is built in the prototype order, Orders first",
		viewer.tab_row.get_child_count() == 3 and viewer.tab_row.get_child(0) == viewer.orders_tab
		and viewer.tab_row.get_child(2) == viewer.shop_tab,
		"%d tabs" % viewer.tab_row.get_child_count())
	TestFixtures.check(res, "every tab carries its label and its page index",
		viewer.shop_tab.label == "Shop" and viewer.cart_tab.label == "Cart"
		and viewer.orders_tab.label == "Orders" and viewer.shop_tab.index == 0
		and viewer.cart_tab.index == 1 and viewer.orders_tab.index == 2,
		"%s, %s, %s" % [viewer.shop_tab.label, viewer.cart_tab.label, viewer.orders_tab.label])
	TestFixtures.check(res, "every tab wears its own bazaar icon",
		viewer.shop_tab.icon_rect.texture == BazaarUi.ICON_SHOP
		and viewer.cart_tab.icon_rect.texture == BazaarUi.ICON_CART
		and viewer.orders_tab.icon_rect.texture == BazaarUi.ICON_ORDERS,
		"shop icon %s" % (viewer.shop_tab.icon_rect.texture != null))
	TestFixtures.check(res, "the active flag sits on the open tab alone",
		viewer.shop_tab.active and not viewer.cart_tab.active and not viewer.orders_tab.active,
		"shop %s, cart %s" % [viewer.shop_tab.active, viewer.cart_tab.active])
	var seen: Array[StringName] = []
	var on_tab := func(key: StringName) -> void: seen.append(key)
	viewer.tab_changed.connect(on_tab)
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing the Cart tab swaps the page and reports the move once",
		viewer.current_tab() == &"cart" and viewer.cart_page().visible
		and not viewer.shop_page().visible and seen.size() == 1 and seen[0] == &"cart",
		"tab %s, %d reports" % [viewer.current_tab(), seen.size()])
	viewer.press_tab(&"cart")
	TestFixtures.check(res, "pressing the tab already open reports nothing",
		seen.size() == 1, "%d reports" % seen.size())
	viewer.press_tab(&"nowhere")
	TestFixtures.check(res, "a key no tab owns is ignored",
		viewer.current_tab() == &"cart" and seen.size() == 1,
		"tab %s, %d reports" % [viewer.current_tab(), seen.size()])
	viewer.press_tab(&"orders")
	await host.get_tree().process_frame
	viewer.tab_changed.disconnect(on_tab)
	TestFixtures.check(res, "pressing the Orders tab shows the orders page",
		viewer.current_tab() == &"orders" and viewer.orders_page().visible
		and viewer.orders_tab.active and seen.size() == 2,
		"tab %s" % viewer.current_tab())
	TestFixtures.check(res, "tab_for maps each key onto its own button",
		viewer.tab_for(&"shop") == viewer.shop_tab and viewer.tab_for(&"cart") == viewer.cart_tab
		and viewer.tab_for(&"orders") == viewer.orders_tab, "mapped")
	viewer.press_tab(&"shop")
	_fund(RICH)
	var cheap: BazaarItemData = _item_named("Ration 1")
	BazaarManager.set_qty(cheap.id, 1)
	BazaarManager.place_order()
	await host.get_tree().process_frame
	viewer.placed_dialog().close()
	TestFixtures.check(res, "an order in transit leaves the Orders tab without a dot",
		not viewer.orders_tab.dot, "dot %s" % viewer.orders_tab.dot)
	_advance_days(FAST_DAYS)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a delivered order puts the dot on the Orders tab",
		viewer.orders_tab.dot and BazaarManager.has_unseen_delivery(),
		"dot %s" % viewer.orders_tab.dot)
	viewer.press_tab(&"orders")
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the Orders tab clears the delivery dot",
		not viewer.orders_tab.dot and not BazaarManager.has_unseen_delivery(),
		"dot %s" % viewer.orders_tab.dot)


#Case 2: the locked page over the content, with the copy and the target of the HUD lock.
static func _case_lock(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the bazaar entitlement leaves the locked page hidden",
		BazaarManager.unlocked() and not viewer.locked_page().visible,
		"lock %s" % viewer.locked_page().visible)
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	var lock: LockedPage = viewer.locked_page()
	TestFixtures.check(res, "a plan below Enterprise covers the content with the locked page",
		not BazaarManager.unlocked() and lock.visible, "lock %s" % lock.visible)
	TestFixtures.check(res, "the locked page names the plan the Bazaar needs",
		lock.line1_label.text == PLAN_LINE1 and lock.line2_label.text == PLAN_LINE2,
		"'%s'" % lock.line2_label.text)
	var plan_target: Dictionary = lock.target()
	TestFixtures.check(res, "take me there sends a plan guild to the Plans page",
		str(plan_target.get("tab", "")) == "plans" and not plan_target.has("upgrade"),
		str(plan_target))
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "Enterprise without the upgrade still shows the locked page",
		not BazaarManager.unlocked() and lock.visible, "lock %s" % lock.visible)
	TestFixtures.check(res, "the locked page names the Bazaar upgrade on Enterprise",
		lock.line1_label.text == UPGRADE_LINE1 and lock.line2_label.text == UPGRADE_LINE2,
		"'%s' '%s'" % [lock.line1_label.text, lock.line2_label.text])
	var up_target: Dictionary = lock.target()
	TestFixtures.check(res, "take me there sends an Enterprise guild to the Bazaar upgrade",
		str(up_target.get("tab", "")) == "customize"
		and str(up_target.get("upgrade", "")) == "bazaar"
		and int(up_target.get("tier", 0)) == 1, str(up_target))
	_full()
	await host.get_tree().process_frame
	TestFixtures.check(res, "buying the upgrade takes the locked page off the content",
		BazaarManager.unlocked() and not lock.visible, "lock %s" % lock.visible)


#Case 3: the department, subtype and price filters of the Shop page and the breadcrumb over them.
static func _case_filters(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	await host.get_tree().process_frame
	var shop: ShopPage = viewer.shop_page()
	var panel: FilterPanel = shop.filter_panel()
	TestFixtures.check(res, "the Shop opens on the whole catalog",
		shop.card_count() == CATALOG_ITEMS and shop.result_text() == "140 results"
		and shop.breadcrumb_text() == "All Departments",
		"%d cards, '%s'" % [shop.card_count(), shop.result_text()])
	TestFixtures.check(res, "no department picked hides the Type section and the clear link",
		not panel.has_type_section() and panel.clear_link() == null and not panel.any_active(),
		"type %s" % panel.has_type_section())
	TestFixtures.check(res, "the panel holds a row per department over an All Departments row",
		panel.row_for("weapons") != null and panel.row_for("") != null
		and panel.head_for("department_head") != null, "rows built")
	shop.pick_department(&"weapons")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a department narrows the grid and names itself in the breadcrumb",
		shop.card_count() == WEAPON_ITEMS and shop.breadcrumb_text() == "Weapons"
		and shop.result_text() == "30 results",
		"%d cards, '%s'" % [shop.card_count(), shop.breadcrumb_text()])
	TestFixtures.check(res, "picking a department opens the Type section and the clear link",
		panel.has_type_section() and panel.clear_link() != null and panel.any_active(),
		"type %s, link %s" % [panel.has_type_section(), panel.clear_link() != null])
	TestFixtures.check(res, "the Type section heads with the department name",
		panel.head_for("type_head").text == "Weapons Type",
		"'%s'" % panel.head_for("type_head").text)
	shop.toggle_subtype("Swords")
	await host.get_tree().process_frame
	var only_swords: bool = true
	for entry: BazaarItemData in shop.results():
		if entry.subtype != "Swords":
			only_swords = false
	TestFixtures.check(res, "a subtype check narrows to that subtype alone",
		shop.card_count() == SUBTYPE_ITEMS and only_swords
		and shop.breadcrumb_text() == "Weapons > Swords",
		"%d cards, '%s'" % [shop.card_count(), shop.breadcrumb_text()])
	shop.toggle_subtype("Swords")
	await host.get_tree().process_frame
	TestFixtures.check(res, "unchecking the subtype hands the department back",
		shop.card_count() == WEAPON_ITEMS and panel.checked_subtypes().is_empty(),
		"%d cards" % shop.card_count())
	shop.pick_price(&"u50")
	await host.get_tree().process_frame
	var under_fifty: bool = true
	for entry: BazaarItemData in shop.results():
		if entry.price >= 50:
			under_fifty = false
	var cheap_count: int = _price_count("weapons", -1, 49)
	TestFixtures.check(res, "the Under 50 preset keeps the weapons under fifty notes",
		under_fifty and shop.card_count() == cheap_count
		and shop.query()["price_preset"] == &"u50",
		"%d cards of %d" % [shop.card_count(), cheap_count])
	shop.set_custom_price(100, 200)
	await host.get_tree().process_frame
	var in_range: bool = true
	for entry: BazaarItemData in shop.results():
		if entry.price < 100 or entry.price > 200:
			in_range = false
	var band_count: int = _price_count("weapons", 100, 200)
	TestFixtures.check(res, "a custom range beats the preset still on the panel",
		in_range and shop.card_count() == band_count and panel.custom_active(),
		"%d cards of %d" % [shop.card_count(), band_count])
	shop.set_custom_price(-1, 40)
	await host.get_tree().process_frame
	var under_forty: bool = true
	for entry: BazaarItemData in shop.results():
		if entry.price > 40:
			under_forty = false
	var low_count: int = _price_count("weapons", -1, 40)
	TestFixtures.check(res, "a custom range with an open low end reads as a ceiling",
		under_forty and shop.card_count() == low_count,
		"%d cards of %d" % [shop.card_count(), low_count])
	shop.pick_price(&"any")
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a preset again drops the custom range",
		not panel.custom_active() and shop.card_count() == WEAPON_ITEMS,
		"%d cards, custom %s" % [shop.card_count(), panel.custom_active()])
	shop.pick_department(&"consumables")
	shop.toggle_subtype("Potions")
	await host.get_tree().process_frame
	TestFixtures.check(res, "moving to another department drops the subtypes of the last one",
		shop.breadcrumb_text() == "Consumables > Potions"
		and shop.card_count() == SUBTYPE_ITEMS,
		"'%s', %d cards" % [shop.breadcrumb_text(), shop.card_count()])
	shop.clear_filters()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clear all filters hands the whole catalog back",
		shop.card_count() == CATALOG_ITEMS and not panel.any_active()
		and shop.breadcrumb_text() == "All Departments" and panel.clear_link() == null,
		"%d cards" % shop.card_count())


#Case 4: the rarity rows, the Better Items locks over them and the cap on what may be bought.
static func _case_rarity(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	SubscriptionManager.set_entitlements({"bazaarRarity": 0})
	await host.get_tree().process_frame
	var shop: ShopPage = viewer.shop_page()
	var panel: FilterPanel = shop.filter_panel()
	TestFixtures.check(res, "tier zero Better Items locks every rarity over Ordinary",
		panel.lock_for(0) == null and panel.lock_for(1) != null and panel.lock_for(4) != null,
		"ordinary lock %s" % (panel.lock_for(0) != null))
	TestFixtures.check(res, "a locked rarity row reads as locked and names its upgrade",
		panel.lock_for(2).locked() and panel.lock_for(2).upgrade == "Better Items"
		and panel.lock_for(2).tier == 2, "tier %d" % panel.lock_for(2).tier)
	TestFixtures.check(res, "the cap keeps every item over it out of the grid",
		shop.card_count() == _rarity_count(0) and BazaarManager.rarity_cap() == 0,
		"%d cards of %d" % [shop.card_count(), _rarity_count(0)])
	shop.toggle_rarity(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a rarity over the cap cannot be checked",
		(shop.query()["rarities"] as Array).is_empty(), str(shop.query()["rarities"]))
	SubscriptionManager.set_entitlements({"bazaarRarity": 2})
	await host.get_tree().process_frame
	TestFixtures.check(res, "raising the tier unlocks the rarities up to the new cap",
		panel.lock_for(2) == null and panel.lock_for(3) != null
		and panel.row_for("Uncommon") != null,
		"uncommon lock %s" % (panel.lock_for(2) != null))
	var capped: int = _rarity_count(0) + _rarity_count(1) + _rarity_count(2)
	TestFixtures.check(res, "the grid grows with the cap",
		shop.card_count() == capped, "%d cards of %d" % [shop.card_count(), capped])
	SubscriptionManager.set_entitlements({"bazaarRarity": ALL_RARITY})
	await host.get_tree().process_frame
	TestFixtures.check(res, "the top tier leaves no rarity locked",
		panel.lock_for(4) == null and panel.row_for("Very Rare") != null
		and shop.card_count() == CATALOG_ITEMS, "%d cards" % shop.card_count())
	shop.toggle_rarity(ALL_RARITY)
	await host.get_tree().process_frame
	var only_top: bool = true
	for entry: BazaarItemData in shop.results():
		if entry.rarity != ALL_RARITY:
			only_top = false
	TestFixtures.check(res, "checking a rarity keeps that rarity alone",
		only_top and shop.card_count() == _rarity_count(ALL_RARITY),
		"%d cards of %d" % [shop.card_count(), _rarity_count(ALL_RARITY)])
	shop.toggle_rarity(ALL_RARITY)
	await host.get_tree().process_frame
	TestFixtures.check(res, "unchecking the last rarity hands every rarity back",
		shop.card_count() == CATALOG_ITEMS and panel.clear_link() == null,
		"%d cards" % shop.card_count())


#Case 5: the search field, the empty grid and the way a search clears.
static func _case_search(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	await host.get_tree().process_frame
	var shop: ShopPage = viewer.shop_page()
	shop.set_search("Sword")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a search on a name narrows the grid to it",
		shop.card_count() == SUBTYPE_ITEMS and shop.result_text() == "5 results"
		and not shop.empty_visible(),
		"%d cards, '%s'" % [shop.card_count(), shop.result_text()])
	TestFixtures.check(res, "the breadcrumb quotes the search text",
		shop.breadcrumb_text() == "All Departments > \"Sword\"",
		"'%s'" % shop.breadcrumb_text())
	TestFixtures.check(res, "a search alone offers the clear link",
		shop.filter_panel().clear_link() != null, "link offered")
	shop.set_search("  compass 1  ")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the search text is trimmed and the count reads in the singular",
		shop.search_text() == "compass 1" and shop.card_count() == 1
		and shop.result_text() == "1 result",
		"'%s', '%s'" % [shop.search_text(), shop.result_text()])
	shop.set_search("zzz")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a search that matches nothing empties the grid",
		shop.card_count() == 0 and shop.result_text() == "0 results" and shop.empty_visible(),
		"%d cards, empty %s" % [shop.card_count(), shop.empty_visible()])
	TestFixtures.check(res, "the empty grid holds the one pair of empty state texts",
		ShopPage.EMPTY_TITLE == "No items match your filters"
		and ShopPage.EMPTY_NOTE == "Try a different department, price, or rarity.",
		ShopPage.EMPTY_TITLE)
	shop.set_search("")
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing the search hands the whole catalog back",
		shop.card_count() == CATALOG_ITEMS and not shop.empty_visible(),
		"%d cards" % shop.card_count())
	shop.pick_department(&"weapons")
	shop.set_search("bomb")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a search and a department narrow together",
		shop.card_count() == 0 and shop.empty_visible(), "%d cards" % shop.card_count())
	shop.clear_filters()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clear all filters drops the search with the filters",
		shop.search_text() == "" and shop.search_field().text == ""
		and shop.card_count() == CATALOG_ITEMS,
		"'%s', %d cards" % [shop.search_text(), shop.card_count()])


#Case 6: every sort of the Shop page and the dropdown that names it.
static func _case_sort(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	await host.get_tree().process_frame
	var shop: ShopPage = viewer.shop_page()
	TestFixtures.check(res, "the Shop opens on the Featured sort",
		shop.sort_key() == &"featured" and shop.sort_dropdown().selected == &"featured",
		"sort %s" % shop.sort_key())
	var rows: Array[BazaarItemData] = shop.results()
	var by_rank: bool = true
	for i: int in range(rows.size() - 1):
		if rows[i].featured_rank > rows[i + 1].featured_rank:
			by_rank = false
	TestFixtures.check(res, "the Featured sort reads in the seeded shuffle order",
		by_rank and rows.size() == CATALOG_ITEMS, "%d rows" % rows.size())
	shop.pick_sort(&"price_asc")
	await host.get_tree().process_frame
	rows = shop.results()
	var rising: bool = true
	for i: int in range(rows.size() - 1):
		if rows[i].price > rows[i + 1].price:
			rising = false
	TestFixtures.check(res, "Price: Low to High reads cheapest first",
		rising and shop.sort_key() == &"price_asc",
		"%d to %d" % [rows[0].price, rows[rows.size() - 1].price])
	shop.pick_sort(&"price_desc")
	await host.get_tree().process_frame
	rows = shop.results()
	var falling: bool = true
	for i: int in range(rows.size() - 1):
		if rows[i].price < rows[i + 1].price:
			falling = false
	TestFixtures.check(res, "Price: High to Low reads dearest first",
		falling, "%d to %d" % [rows[0].price, rows[rows.size() - 1].price])
	shop.pick_sort(&"rarity")
	await host.get_tree().process_frame
	rows = shop.results()
	var by_rarity: bool = true
	for i: int in range(rows.size() - 1):
		if rows[i].rarity < rows[i + 1].rarity:
			by_rarity = false
	TestFixtures.check(res, "Rarity: Highest First reads the rarest first",
		by_rarity and rows[0].rarity == ALL_RARITY, "first rarity %d" % rows[0].rarity)
	shop.pick_sort(&"name")
	await host.get_tree().process_frame
	rows = shop.results()
	var by_name: bool = true
	for i: int in range(rows.size() - 1):
		if rows[i].name.naturalnocasecmp_to(rows[i + 1].name) > 0:
			by_name = false
	TestFixtures.check(res, "Name: A to Z reads alphabetically",
		by_name, "first '%s'" % rows[0].name)
	TestFixtures.check(res, "the sort dropdown follows the pick without opening its popup",
		shop.sort_dropdown().selected == &"name" and not shop.sort_dropdown().popup_open(),
		"selected %s" % shop.sort_dropdown().selected)
	shop.pick_sort(&"nonsense")
	TestFixtures.check(res, "a sort key the manager does not own is ignored",
		shop.sort_key() == &"name", "sort %s" % shop.sort_key())
	TestFixtures.check(res, "the dropdown offers one row per sort the manager owns",
		shop.sort_dropdown().options.size() == BazaarManager.SORTS.size(),
		"%d rows" % shop.sort_dropdown().options.size())


#Case 7: the item cards, the Add to Cart button and the stepper that takes a line out again.
static func _case_cards(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	var shop: ShopPage = viewer.shop_page()
	shop.pick_department(&"weapons")
	shop.toggle_subtype("Swords")
	await host.get_tree().process_frame
	var sword: BazaarItemData = _item_named("Sword 1")
	var card: ItemCard = shop.card_for(sword.id)
	TestFixtures.check(res, "the grid holds one card per result, keyed by the item",
		card != null and shop.card_count() == SUBTYPE_ITEMS,
		"%d cards" % shop.card_count())
	TestFixtures.check(res, "the card offers the Add to Cart button and an empty stepper",
		card.add_button().text == "Add to Cart" and card.add_button().visible
		and card.stepper().value == 0, "'%s'" % card.add_button().text)
	TestFixtures.check(res, "the card names the day the item would arrive",
		card.eta_label().text == "Arrives %s" % BazaarUi.eta_text(FAST_DAYS, GameState.day()),
		"'%s'" % card.eta_label().text)
	card.press_add()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Add to Cart puts one of the item in the cart",
		BazaarManager.cart_count() == 1 and int(BazaarManager.cart.get(sword.id, 0)) == 1,
		"%d in the cart" % BazaarManager.cart_count())
	card = shop.card_for(sword.id)
	TestFixtures.check(res, "the card swaps the button for the stepper the cart filled",
		card.stepper().value == 1 and not card.add_button().visible,
		"stepper %d" % card.stepper().value)
	card.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the plus of the card stacks the line",
		BazaarManager.cart_count() == 2 and int(BazaarManager.cart.get(sword.id, 0)) == 2,
		"%d in the cart" % BazaarManager.cart_count())
	card = shop.card_for(sword.id)
	card.press_minus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the minus of the card takes one back off the line",
		int(BazaarManager.cart.get(sword.id, 0)) == 1,
		"%d of the sword" % int(BazaarManager.cart.get(sword.id, 0)))
	card = shop.card_for(sword.id)
	card.press_minus()
	await host.get_tree().process_frame
	card = shop.card_for(sword.id)
	TestFixtures.check(res, "stepping the last one off takes the line out of the cart",
		BazaarManager.cart_ids().is_empty() and card.add_button().visible,
		"%d lines" % BazaarManager.cart_ids().size())
	var second: BazaarItemData = _item_named("Sword 2")
	shop.card_for(sword.id).press_add()
	shop.card_for(second.id).press_add()
	await host.get_tree().process_frame
	TestFixtures.check(res, "two cards fill two lines of the cart",
		BazaarManager.cart_ids().size() == 2 and BazaarManager.cart_count() == 2,
		"%d lines" % BazaarManager.cart_ids().size())
	TestFixtures.check(res, "the cart page follows the cards without being opened",
		viewer.cart_page().row_count() == 2, "%d rows" % viewer.cart_page().row_count())


#Case 8: the cart page, its rows and the order summary beside them.
static func _case_cart(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	var page: CartPage = viewer.cart_page()
	var summary: OrderSummary = page.summary()
	TestFixtures.check(res, "an empty cart shows its empty state and no rows",
		page.row_count() == 0 and page.count_text() == "0 items"
		and CartPage.EMPTY_TITLE == "Your cart is empty",
		"%d rows, '%s'" % [page.row_count(), page.count_text()])
	TestFixtures.check(res, "the summary of an empty cart closes checkout and says why",
		summary.checkout_button().disabled and summary.reason_text() == EMPTY_REASON
		and summary.row_text(&"arrives") == "-", "'%s'" % summary.reason_text())
	var sword: BazaarItemData = _item_named("Sword 1")
	var bomb: BazaarItemData = _item_named("Bomb 1")
	BazaarManager.set_qty(sword.id, 2)
	BazaarManager.set_qty(bomb.id, 1)
	await host.get_tree().process_frame
	var total: int = sword.price * 2 + bomb.price
	TestFixtures.check(res, "the cart lists one row per line, lowest item id first",
		page.row_count() == 2 and page.rows()[0].item_id() == mini(sword.id, bomb.id),
		"%d rows" % page.row_count())
	TestFixtures.check(res, "the count over the list counts every item",
		page.count_text() == "3 items", "'%s'" % page.count_text())
	TestFixtures.check(res, "a row totals its own line",
		page.row_for(sword.id).line_total() == sword.price * 2
		and page.row_for(sword.id).stepper().value == 2,
		"%d notes" % page.row_for(sword.id).line_total())
	TestFixtures.check(res, "the summary counts the items and totals the cart",
		summary.items_caption() == "Items (3)"
		and summary.row_text(&"total") == NotesLabel.format_amount(total),
		"'%s', '%s'" % [summary.items_caption(), summary.row_text(&"total")])
	TestFixtures.check(res, "the summary calls delivery free and names the arrival day",
		summary.row_text(&"delivery") == "Free"
		and summary.row_text(&"arrives") == BazaarUi.eta_text(FAST_DAYS, GameState.day()),
		"'%s'" % summary.row_text(&"arrives"))
	TestFixtures.check(res, "the summary reads the bank and the notes left after the buy",
		summary.row_text(&"notes") == NotesLabel.format_amount(GameState.bank_notes)
		and summary.row_text(&"after") == NotesLabel.format_amount(GameState.bank_notes - total),
		"'%s'" % summary.row_text(&"after"))
	TestFixtures.check(res, "an affordable cart opens checkout with no reason under it",
		not summary.checkout_button().disabled and summary.reason_text() == "",
		"'%s'" % summary.reason_text())
	page.row_for(sword.id).press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the plus of a row stacks the line and retotals the summary",
		page.row_for(sword.id).stepper().value == 3
		and summary.row_text(&"total") == NotesLabel.format_amount(sword.price * 3 + bomb.price),
		"'%s'" % summary.row_text(&"total"))
	page.row_for(bomb.id).press_remove()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Remove takes the whole line out of the cart",
		page.row_count() == 1 and page.row_for(bomb.id) == null
		and not BazaarManager.cart.has(bomb.id), "%d rows" % page.row_count())
	var bank: int = GameState.bank_notes
	BazaarManager.set_qty(sword.id, 1)
	GameState.bank_notes = 0
	page.refresh()
	await host.get_tree().process_frame
	var short: int = BazaarManager.cart_total()
	TestFixtures.check(res, "a cart over the bank closes checkout and names the notes needed",
		summary.checkout_button().disabled
		and summary.reason_text() == "Not enough notes. Remove items or earn %d more." % short,
		"'%s'" % summary.reason_text())
	GameState.bank_notes = bank
	BazaarManager.clear_cart()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing the cart brings the empty state back",
		page.row_count() == 0 and page.count_text() == "0 items"
		and summary.reason_text() == EMPTY_REASON, "%d rows" % page.row_count())
	page.press_continue()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Continue Shopping sends the guild back to the Shop tab",
		viewer.current_tab() == &"shop", "tab %s" % viewer.current_tab())


#Case 9: the checkout dialog, the one spend behind it and the order placed dialog after it.
static func _case_checkout(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	var dialog: CheckoutDialog = viewer.checkout_dialog()
	var placed: OrderPlacedDialog = viewer.placed_dialog()
	TestFixtures.check(res, "both order dialogs start closed",
		not dialog.is_open() and not placed.is_open(),
		"checkout %s, placed %s" % [dialog.is_open(), placed.is_open()])
	viewer.cart_page().press_checkout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty cart cannot open the checkout dialog",
		not dialog.is_open(), "open %s" % dialog.is_open())
	var sword: BazaarItemData = _item_named("Sword 1")
	var bomb: BazaarItemData = _item_named("Bomb 1")
	BazaarManager.set_qty(sword.id, 2)
	BazaarManager.set_qty(bomb.id, 1)
	await host.get_tree().process_frame
	var total: int = BazaarManager.cart_total()
	var bank: int = GameState.bank_notes
	viewer.cart_page().press_checkout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filled cart opens the checkout dialog on its lines",
		dialog.is_open() and dialog.line_count() == 2, "%d lines" % dialog.line_count())
	TestFixtures.check(res, "the dialog names the arrival day of the order",
		dialog.arrival_text() == BazaarUi.eta_text(FAST_DAYS, GameState.day()),
		"'%s'" % dialog.arrival_text())
	TestFixtures.check(res, "the dialog offers Cancel and Place Order",
		dialog.cancel_button().text == "Cancel" and dialog.place_button().text == "Place Order"
		and not dialog.place_button().disabled, "'%s'" % dialog.place_button().text)
	dialog.press_cancel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Cancel closes the dialog and leaves the cart alone",
		not dialog.is_open() and BazaarManager.cart_count() == 3
		and GameState.bank_notes == bank, "%d in the cart" % BazaarManager.cart_count())
	viewer.cart_page().press_checkout()
	await host.get_tree().process_frame
	var logged: Array[String] = []
	var on_logged := func(delta: int, reason: String, label: String) -> void:
		logged.append("%d|%s|%s" % [delta, reason, label])
	GameState.money_logged.connect(on_logged)
	dialog.press_place()
	await host.get_tree().process_frame
	GameState.money_logged.disconnect(on_logged)
	var order: OrderData = BazaarManager.orders[0] if not BazaarManager.orders.is_empty() else null
	TestFixtures.check(res, "Place Order spends the total and empties the cart",
		order != null and GameState.bank_notes == bank - total
		and BazaarManager.cart_count() == 0 and order.total == total,
		"bank %d of %d" % [GameState.bank_notes, bank - total])
	TestFixtures.check(res, "the spend reaches the ledger as a bazaar order with its number",
		logged.size() == 1 and logged[0] == "%d|bazaar|Bazaar order #1001" % -total,
		str(logged))
	TestFixtures.check(res, "the first order takes the first number and the day it was placed",
		order.id == BazaarManager.FIRST_ORDER_ID and order.placed_day == GameState.day()
		and order.days == FAST_DAYS, "order %d" % order.id)
	TestFixtures.check(res, "placing the order closes checkout and opens the placed dialog",
		not dialog.is_open() and placed.is_open(), "placed %s" % placed.is_open())
	TestFixtures.check(res, "the placed dialog names the order and the two day delivery",
		placed.message_text() == "Order #1001 will arrive %s (2-Day delivery)."
		% GuiDates.day_text(order.placed_day + order.days), "'%s'" % placed.message_text())
	TestFixtures.check(res, "the placed dialog offers Keep Shopping and View Orders",
		placed.keep_button().text == "Keep Shopping" and placed.view_button().text == "View Orders",
		"'%s'" % placed.view_button().text)
	placed.press_keep()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Keep Shopping closes the dialog on the Shop tab",
		not placed.is_open() and viewer.current_tab() == &"shop",
		"tab %s" % viewer.current_tab())
	_fund(RICH)
	BazaarManager.set_qty(sword.id, 1)
	viewer.press_tab(&"cart")
	viewer.cart_page().press_checkout()
	await host.get_tree().process_frame
	dialog.press_place()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the next order takes the next number",
		BazaarManager.orders.size() == 2
		and BazaarManager.orders[1].id == BazaarManager.FIRST_ORDER_ID + 1,
		"order %d" % BazaarManager.orders[1].id)
	placed.press_view()
	await host.get_tree().process_frame
	TestFixtures.check(res, "View Orders opens the Orders tab on the All filter",
		not placed.is_open() and viewer.current_tab() == &"orders"
		and viewer.orders_page().filter == &"all", "tab %s" % viewer.current_tab())
	dialog.press_place()
	TestFixtures.check(res, "a closed dialog cannot place an order",
		BazaarManager.orders.size() == 2, "%d orders" % BazaarManager.orders.size())


#Case 10: the Orders page, its three filters and the progress of one order to its arrival.
static func _case_orders(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	var sword: BazaarItemData = _item_named("Sword 1")
	BazaarManager.set_qty(sword.id, 2)
	var order: OrderData = BazaarManager.place_order()
	viewer.placed_dialog().close()
	viewer.press_tab(&"orders")
	await host.get_tree().process_frame
	var page: OrdersPage = viewer.orders_page()
	var card: OrderCard = page.card_for(order.id)
	TestFixtures.check(res, "the Orders page holds one card per order",
		page.card_count() == 1 and card != null and not page.empty_visible(),
		"%d cards" % page.card_count())
	TestFixtures.check(res, "a card in transit titles itself with the arrival day",
		card.title_text() == "Arriving %s" % GuiDates.day_text(order.placed_day + order.days),
		"'%s'" % card.title_text())
	TestFixtures.check(res, "a card on the day it was placed shows no progress",
		card.filled_cells() == 0 and card.chip_count() == 1,
		"%d cells, %d chips" % [card.filled_cells(), card.chip_count()])
	TestFixtures.check(res, "the filter buttons count the orders under each one",
		page.button_text(&"all") == "All (1)" and page.button_text(&"transit") == "In Transit (1)"
		and page.button_text(&"delivered") == "Delivered (0)",
		"'%s'" % page.button_text(&"transit"))
	page.pick_filter(&"delivered")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Delivered filter of a fresh order shows the empty list",
		page.card_count() == 0 and page.empty_visible()
		and OrdersPage.EMPTY_TEXT == "No orders here yet.",
		"%d cards" % page.card_count())
	page.pick_filter(&"transit")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the In Transit filter holds the order that has not landed",
		page.card_count() == 1 and page.first_card().order_id() == order.id,
		"%d cards" % page.card_count())
	_advance_days(1)
	await host.get_tree().process_frame
	card = page.card_for(order.id)
	TestFixtures.check(res, "a day of the two day delivery fills half the progress bar",
		card.filled_cells() == 10 and card.sub_text() == "1 day left - Day 1 of 2",
		"%d cells, '%s'" % [card.filled_cells(), card.sub_text()])
	_advance_days(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the arrival day drops the order out of In Transit",
		page.card_count() == 0 and page.button_text(&"transit") == "In Transit (0)"
		and page.button_text(&"delivered") == "Delivered (1)",
		"'%s'" % page.button_text(&"delivered"))
	page.pick_filter(&"delivered")
	await host.get_tree().process_frame
	card = page.card_for(order.id)
	TestFixtures.check(res, "a delivered card fills the bar and says where the goods went",
		card != null and card.filled_cells() == 20
		and card.sub_text() == "Delivered to Guild Storage",
		"%d cells, '%s'" % [card.filled_cells(), card.sub_text()])
	TestFixtures.check(res, "a delivered card titles itself with the day it landed",
		card.title_text() == "Delivered %s" % GuiDates.day_text(order.placed_day + order.days),
		"'%s'" % card.title_text())
	_fund(RICH)
	BazaarManager.set_qty(sword.id, 1)
	var second: OrderData = BazaarManager.place_order()
	viewer.placed_dialog().close()
	page.pick_filter(&"all")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the All filter lists every order, newest first",
		page.card_count() == 2 and page.first_card().order_id() == second.id
		and page.button_text(&"all") == "All (2)",
		"%d cards, first %d" % [page.card_count(), page.first_card().order_id()])
	TestFixtures.check(res, "a second order of a different day splits the two filters",
		page.button_text(&"transit") == "In Transit (1)"
		and page.button_text(&"delivered") == "Delivered (1)",
		"'%s'" % page.button_text(&"transit"))
	page.pick_filter(&"all")
	TestFixtures.check(res, "picking the filter already open changes nothing",
		page.filter == &"all" and page.card_count() == 2, "%d cards" % page.card_count())
	BazaarManager.reset()
	viewer.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a reset of the manager empties the Orders page",
		page.card_count() == 0 and page.empty_visible()
		and page.button_text(&"all") == "All (0)", "%d cards" % page.card_count())


#Case 11: the Cart and Orders tab badges, their shared colour and the dot's priority over them.
#GX4A-01: README C2 line 212, Cart = item count, Orders = in-transit count, both orange #f28c28.
static func _case_badges(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	TestFixtures.check(res, "an empty cart and no orders show no badge on either tab",
		viewer.cart_tab.badge == 0 and viewer.orders_tab.badge == 0,
		"cart %d, orders %d" % [viewer.cart_tab.badge, viewer.orders_tab.badge])
	var sword: BazaarItemData = _item_named("Sword 1")
	var bomb: BazaarItemData = _item_named("Bomb 1")
	BazaarManager.set_qty(sword.id, 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "one item in the cart puts a 1 on the Cart tab badge",
		viewer.cart_tab.badge == 1, "badge %d" % viewer.cart_tab.badge)
	BazaarManager.set_qty(sword.id, 3)
	BazaarManager.set_qty(bomb.id, 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Cart badge sums every line's quantity, not the row count",
		viewer.cart_tab.badge == 4, "badge %d" % viewer.cart_tab.badge)
	TestFixtures.check(res, "both tab badges read the same README orange",
		viewer.cart_tab.badge_color == BazaarViewer.BADGE_COLOR
		and viewer.orders_tab.badge_color == BazaarViewer.BADGE_COLOR,
		"cart %s" % viewer.cart_tab.badge_color)
	BazaarManager.clear_cart()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing the cart drops the Cart badge back to none",
		viewer.cart_tab.badge == 0, "badge %d" % viewer.cart_tab.badge)
	BazaarManager.set_qty(sword.id, 1)
	BazaarManager.place_order()
	viewer.placed_dialog().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "one order in transit puts a 1 on the Orders tab badge",
		viewer.orders_tab.badge == 1, "badge %d" % viewer.orders_tab.badge)
	_advance_days(1)
	await host.get_tree().process_frame
	_fund(RICH)
	BazaarManager.set_qty(bomb.id, 1)
	BazaarManager.place_order()
	viewer.placed_dialog().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Orders badge counts every order still in transit, not just one",
		viewer.orders_tab.badge == 2, "badge %d" % viewer.orders_tab.badge)
	_advance_days(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the arrival of the older order drops the Orders badge by one",
		viewer.orders_tab.badge == 1, "badge %d" % viewer.orders_tab.badge)
	TestFixtures.check(res, "the dot from that arrival hides the badge though the count holds",
		viewer.orders_tab.dot and not viewer.orders_tab.badge_panel.visible,
		"dot %s, panel %s" % [viewer.orders_tab.dot, viewer.orders_tab.badge_panel.visible])
	viewer.press_tab(&"orders")
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening Orders clears the dot and lets the badge panel show again",
		not viewer.orders_tab.dot and viewer.orders_tab.badge_panel.visible
		and viewer.orders_tab.badge == 1,
		"dot %s, panel %s" % [viewer.orders_tab.dot, viewer.orders_tab.badge_panel.visible])


#Case 12: fix round 3, GX3A-01 comma prices, GX3A-03 digit only fields, GX3A-05 empty note tint.
static func _case_fix_round3(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	var cheap: BazaarItemData = null
	var costly: BazaarItemData = null
	for entry: BazaarItemData in BazaarManager.catalog:
		if costly == null and entry.price >= 1000:
			costly = entry
		if cheap == null and entry.price < 1000:
			cheap = entry
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	var page: CartPage = viewer.cart_page()
	BazaarManager.set_qty(cheap.id, 1)
	BazaarManager.set_qty(costly.id, 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a cart row under a thousand reads the price with no separator",
		page.row_for(cheap.id).each_text() == "%d each" % cheap.price,
		"'%s'" % page.row_for(cheap.id).each_text())
	TestFixtures.check(res, "a cart row of a thousand or more reads the price grouped",
		page.row_for(costly.id).each_text() == "%s each" % NotesLabel.format_amount(costly.price),
		"'%s'" % page.row_for(costly.id).each_text())
	BazaarManager.clear_cart()
	viewer.press_tab(&"shop")
	await host.get_tree().process_frame
	var panel: FilterPanel = viewer.shop_page().filter_panel()
	panel.type_field("min", "12a3")
	TestFixtures.check(res, "a letter typed among digits in the Min box is dropped",
		panel.field_text("min") == "123", "'%s'" % panel.field_text("min"))
	panel.type_field("min", "abc")
	TestFixtures.check(res, "letters alone in the Min box leave it empty",
		panel.field_text("min") == "", "'%s'" % panel.field_text("min"))
	panel.type_field("min", "45")
	TestFixtures.check(res, "digits alone stay as typed",
		panel.field_text("min") == "45", "'%s'" % panel.field_text("min"))
	panel.type_field("min", "12a")
	TestFixtures.check(res, "the caret moves back by the letters dropped before it",
		panel.field_text("min") == "12" and panel.field_caret("min") == 2,
		"'%s' at %d" % [panel.field_text("min"), panel.field_caret("min")])
	TestFixtures.check(res, "the Shop empty note reads in BazaarUi.SKY",
		viewer.shop_page().empty_note_color() == BazaarUi.SKY,
		str(viewer.shop_page().empty_note_color()))
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Cart empty note reads in BazaarUi.SKY",
		page.empty_note_color() == BazaarUi.SKY, str(page.empty_note_color()))
	viewer.press_tab(&"orders")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Orders empty note reads in BazaarUi.SKY",
		viewer.orders_page().empty_note_color() == BazaarUi.SKY,
		str(viewer.orders_page().empty_note_color()))


#Item 11 (F6H): every Bazaar action button is the core BevelButton scene with its kind kept.
static func _case_bevel_sweep(res: Dictionary, host: Node, viewer: BazaarViewer) -> void:
	_reset(viewer)
	_fund(RICH)
	await host.get_tree().process_frame
	var add_bevel: BevelButton = viewer.shop_page().first_card().add_button() as BevelButton
	TestFixtures.check(res, "the shop card Add to Cart button is an orange BevelButton",
		add_bevel != null and add_bevel.kind == &"orange" and add_bevel.text == "Add to Cart",
		str(add_bevel))
	var picked_bevel: BevelButton = viewer.orders_page().button_for(
		BazaarManager.ORDER_FILTERS[0]) as BevelButton
	TestFixtures.check(res, "the picked Orders filter button shades orange as a BevelButton",
		picked_bevel != null and picked_bevel.kind == &"orange", str(picked_bevel))
	var other_bevel: BevelButton = viewer.orders_page().button_for(
		BazaarManager.ORDER_FILTERS[1]) as BevelButton
	TestFixtures.check(res, "an unpicked Orders filter button shades neutral as a BevelButton",
		other_bevel != null and other_bevel.kind == &"neutral", str(other_bevel))
	var sword: BazaarItemData = _item_named("Sword 1")
	BazaarManager.set_qty(sword.id, 1)
	viewer.press_tab(&"cart")
	await host.get_tree().process_frame
	var checkout_bevel: BevelButton = viewer.cart_page().summary().checkout_button() as BevelButton
	TestFixtures.check(res, "the cart Checkout button is a go BevelButton",
		checkout_bevel != null and checkout_bevel.kind == &"go"
		and checkout_bevel.text == "Proceed to Checkout", str(checkout_bevel))
	viewer.cart_page().press_checkout()
	await host.get_tree().process_frame
	var dialog: CheckoutDialog = viewer.checkout_dialog()
	var cancel_bevel: BevelButton = dialog.cancel_button() as BevelButton
	var place_bevel: BevelButton = dialog.place_button() as BevelButton
	TestFixtures.check(res, "the checkout dialog buttons are neutral Cancel and go Place Order",
		cancel_bevel != null and cancel_bevel.kind == &"neutral"
		and place_bevel != null and place_bevel.kind == &"go", "%s %s" % [cancel_bevel, place_bevel])
	dialog.press_place()
	await host.get_tree().process_frame
	var placed: OrderPlacedDialog = viewer.placed_dialog()
	var keep_bevel: BevelButton = placed.keep_button() as BevelButton
	var view_bevel: BevelButton = placed.view_button() as BevelButton
	TestFixtures.check(res, "the order placed dialog buttons are neutral Keep and go View",
		keep_bevel != null and keep_bevel.kind == &"neutral"
		and view_bevel != null and view_bevel.kind == &"go", "%s %s" % [keep_bevel, view_bevel])

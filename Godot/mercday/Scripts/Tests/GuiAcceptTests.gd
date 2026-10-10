class_name GuiAcceptTests
extends RefCounted

#Run: godot --headless --path . with the --gui-accept-tests flag.
#The acceptance rules of RUNBOOK.md that no click-through step covers. A1 opens every viewer
#alone as the first screen of a fresh game, A2 collects every ScrollContainer and every viewer
#size, A3 reads the locks at plan Free, A4 reads every notification dot, A5 drives the six
#notes-spending actions README E5 names and watches the bank.

const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const CONTENT_SIZE: Vector2 = Vector2(1280.0, 720.0)
#ICON_SHEET_UPDATE.md:77: a HUD window band is 1280 x 644 above the 76 px bottom bar.
const BAND_SIZE: Vector2 = Vector2(1280.0, 644.0)
const FIT_SLACK: float = 1.0
#ICON_SHEET_UPDATE.md:79 and F7_common pinned interface 1: a 4 px #f28c28 border inside the canvas.
const BORDER_COLOR: Color = Color("#f28c28")
const BORDER_PX: int = 4
const SUBWINDOW_SCENE: String = "res://Scenes/GUI/Shared/SubWindow.tscn"
const POPUP_SCENE: String = "res://Scenes/GUI/Shared/ViewerPopup.tscn"
const FLAT_TEXT_DIRS: Array[String] = ["res://Scenes/GUI/Mercs", "res://Scripts/GUI/Mercs",
	"res://Scenes/GUI/Contracts", "res://Scripts/GUI/Contracts", "res://Scenes/GUI/Clients",
	"res://Scripts/GUI/Clients", "res://Scenes/GUI/Metrics", "res://Scripts/GUI/Metrics"]
const TEXT_EFFECTS: Array[String] = ["font_shadow_color", "shadow_offset_x", "shadow_offset_y",
	"shadow_outline_size", "outline_size", "font_outline_color"]
const RICH: int = 400000

#A4 dot design values of Notification Dot.dc.html, read beside their own source line, never
#copied from the game's consts.
const DOT_RED: Color = Color("#e8583f")             #Notification Dot.dc.html:28
const DOT_OUTLINE: Color = Color("#0a0f1c")         #Notification Dot.dc.html:32
const DOT_PX: Vector2 = Vector2(16.0, 16.0)         #Notification Dot.dc.html:21 and :33 (8 cells of 2 px)
const DOT_FRAME_PX: Vector2 = Vector2(28.0, 28.0)   #Notification Dot.dc.html:17

#My own copy of the HUD routing table, in grid order. A table edit shows as a failing check
#instead of agreeing with GameHUD silently.
const VIEW_KEYS: Array[StringName] = [&"mercs", &"contracts", &"clients", &"promotions",
	&"mercday", &"finance", &"legal", &"bazaar", &"metrics"]
const VIEW_SCENES: Array[String] = [
	"res://Scenes/GUI/Mercs/MercViewer.tscn",
	"res://Scenes/GUI/Contracts/ContractViewer.tscn",
	"res://Scenes/GUI/Clients/ClientViewer.tscn",
	"res://Scenes/GUI/Promotions/PromotionsViewer.tscn",
	"res://Scenes/GUI/Subscription/SubscriptionViewer.tscn",
	"res://Scenes/GUI/Finance/FinanceViewer.tscn",
	"res://Scenes/GUI/Legal/LegalViewer.tscn",
	"res://Scenes/GUI/Bazaar/BazaarViewer.tscn",
	"res://Scenes/GUI/Metrics/MetricsViewer.tscn",
]

#The rows GuiLegalTests._lay_legal files: fine 1 is unpaid, capture 1 holds a merc.
const FINE_ID: int = 1
const CAPTURE_ID: int = 1
const PERMIT_LOC: int = 1

#Every list that may scroll, keyed by the script of the nearest scripted node above the
#container, with how many ScrollContainer nodes that owner may hold. A container under a
#script not in this list, or one more than its row allows, is reported the same way:
#the allow list names the container, not the page.
#Ground per group, never one sentence for all of them:
#- No trailing comment: scrolled before this package (commit 4998e35, the first GUI pass).
#- "RUNBOOK.md:38": the permit slider, the fines and bailout lists, the campaign list,
#the filter list, the applicant grid, the Contract Type / Location boxes and the pickers.
#- "README C2": the Bazaar shop, cart and orders lists.
#- A prototype line: the prototype is the base spec and it scrolls every one of these
#(overflow-y auto). Each line was checked against the .dc.html file; LoanRequestWindow.gd:677
#is the Send a Merc picker.
const DROP_PANEL_SCRIPT: String = "res://Scripts/GUI/Shared/DropPanel.gd"
const SCROLL_OWNERS: Dictionary = {
	"res://Scripts/GUI/Contracts/ContractList.gd": 1,
	"res://Scripts/GUI/Contracts/DispatchRoster.gd": 1,
	"res://Scripts/GUI/Contracts/RecommendedList.gd": 1,
	"res://Scripts/GUI/Shared/MercPicker.gd": 1,
	"res://Scripts/GUI/Shared/PaddedScroll.gd": 1,
	"res://Scripts/GUI/Contracts/TeamSlot.gd": 1,
	"res://Scripts/GUI/Mercs/MercList.gd": 1,
	"res://Scripts/GUI/Mercs/OverviewTab.gd": 1,
	"res://Scripts/GUI/Mercs/EquipmentTab.gd": 0,
	"res://Scripts/GUI/Mercs/ActionsTab.gd": 2,
	"res://Scripts/GUI/Mercs/RelationshipsTab.gd": 1,
	"res://Scripts/GUI/Mercs/TraitListPanel.gd": 1,
	"res://Scripts/GUI/Mercs/TraitTab.gd": 0,
	"res://Scripts/GUI/Mercs/MercHeader.gd": 1,                  #ICON_SHEET_UPDATE.md:77
	"res://Scripts/GUI/Metrics/MetricsViewer.gd": 1,
	"res://Scripts/GUI/Notifications/NotificationPanel.gd": 1,
	"res://Scripts/GUI/Legal/PermitsPage.gd": 1,               #RUNBOOK.md:38
	"res://Scripts/GUI/Legal/PermitRequestDialog.gd": 1,        #RUNBOOK.md:38
	"res://Scripts/GUI/Legal/FinesPage.gd": 1,                  #RUNBOOK.md:38
	"res://Scripts/GUI/Legal/BailoutPage.gd": 1,                #RUNBOOK.md:38
	"res://Scripts/GUI/Promotions/CampaignList.gd": 1,          #RUNBOOK.md:38
	"res://Scripts/GUI/Shared/FilterSection.gd": 1,             #RUNBOOK.md:38
	"res://Scripts/GUI/Shared/TraitFilterPanel.gd": 1,          #RUNBOOK.md:38
	"res://Scripts/GUI/Clients/ClientFilterButton.gd": 1,       #RUNBOOK.md:38
	"res://Scripts/GUI/Finance/Hiring/HiringTab.gd": 1,         #RUNBOOK.md:38
	"res://Scripts/GUI/Bazaar/ShopPage.gd": 1,                  #README C2
	"res://Scripts/GUI/Bazaar/CartPage.gd": 1,                  #README C2
	"res://Scripts/GUI/Bazaar/OrdersPage.gd": 1,                #README C2
	"res://Scripts/GUI/Bazaar/FilterPanel.gd": 1,               #README C2
	"res://Scripts/GUI/Clients/ClientList.gd": 1,               #Client Viewer.dc.html:72
	"res://Scripts/GUI/Clients/ClientOverview.gd": 1,           #Client Viewer.dc.html:128
	"res://Scripts/GUI/Subscription/UpgradeTierDialog.gd": 1,   #Subscription Viewer.dc.html:206
	"res://Scripts/GUI/Finance/Overview/FinanceTransactions.gd": 1, #Finance Viewer.dc.html:222
	"res://Scripts/GUI/Finance/Loans/LoansTab.gd": 1,           #Finance Viewer.dc.html:288
	"res://Scripts/GUI/Finance/Invest/InvestCompanyList.gd": 1, #Finance Viewer.dc.html:382
	"res://Scripts/GUI/Finance/Payroll/PayrollTab.gd": 1,       #Finance Viewer.dc.html:570
	"res://Scripts/GUI/Finance/Loans/LoanRequestWindow.gd": 1,  #Finance Viewer.dc.html:677
	"res://Scripts/GUI/Finance/Loans/LoanAcceptConfirm.gd": 1,  #Finance Viewer.dc.html:805
	"res://Scripts/GUI/Finance/Overview/FinanceProjection.gd": 1, #quick fix item 1, 2026-09-28
	"res://Scripts/GUI/Subscription/PlanSwitchDialog.gd": 1,    #downgrade upgrade loss list
	"res://Scripts/GUI/Finance/Invest/InvestChart.gd": 1,       #hover tip event rows
}

#Locks a host hides together with the control they stand for, so a hidden lock that reads locked
#is by design there: MetricsViewer._apply_compare_state shows the compare button and its lock only
#on a merc row (on_row), and off a row both hide.
const CONTEXT_HIDDEN_LOCKS: Dictionary = {
	"res://Scripts/GUI/Metrics/MetricsViewer.gd": ["CompareLock"],
}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_a1_contracts(res, host)
	await _case_a1_mercs(res, host)
	await _case_a1_metrics(res, host)
	await _case_a1_mercday(res, host)
	await _case_a1_bazaar(res, host)
	await _case_a1_legal(res, host)
	await _case_a1_promotions(res, host)
	await _case_a1_finance(res, host)
	await _case_a1_clients(res, host)
	await _case_a1_dispatch(res, host)
	await _case_a1_hud(res, host)
	await _case_a2_scrolls(res, host)
	await _case_a2_scroll_report(res, host)
	await _case_a2_fit(res, host)
	await _case_a2_hud(res, host)
	await _case_a6_window_border(res, host)
	await _case_a6_popup_border(res, host)
	_case_a6_flat_text(res)
	await _case_a3_locks(res, host)
	await _case_a4_dots(res, host)
	await _case_a5_permit(res, host)
	await _case_a5_review(res, host, LegalManager.TARGET_FINE, FINE_ID, "pay fine")
	await _case_a5_review(res, host, LegalManager.TARGET_CAPTURE, CAPTURE_ID, "pay bail")
	await _case_a5_hire(res, host)
	await _case_a5_reject(res, host)
	await _case_a5_campaign(res, host)
	_fresh()
	return TestFixtures.summarize(res, "GUI ACCEPT")


#A fresh process state: a new game with every entitlement met and no screen opened yet.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	TestFixtures.fix_applicant_seed()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	PromotionsManager.reset()
	SubscriptionManager.max_out()
	GuiFrameStack.clear()


static func _spawn(host: Node, path: String) -> Control:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return null
	var made: Control = scene.instantiate() as Control
	if made == null:
		return null
	host.add_child(made)
	return made


#Freed at once, not queued: a screen that lives on to the next case still answers the
#autoload signals of the fixture and rebuilds itself outside the tree.
static func _drop(node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		node.get_parent().remove_child(node)
	node.free()
	GuiFrameStack.clear()


static func _kids(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 0
	for child: Node in node.get_children():
		total += 1 + _kids(child)
	return total


#Every node at or under the root that is an instance of the kind, in tree order.
static func _collect(root: Node, kind: Variant) -> Array[Node]:
	var out: Array[Node] = []
	if is_instance_of(root, kind):
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_collect(child, kind))
	return out


static func _scrolls(root: Node) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	out.assign(_collect(root, ScrollContainer))
	return out


static func _locks(root: Node) -> Array[FeatureLock]:
	var out: Array[FeatureLock] = []
	out.assign(_collect(root, FeatureLock))
	return out


static func _locked_pages(root: Node) -> Array[LockedPage]:
	var out: Array[LockedPage] = []
	out.assign(_collect(root, LockedPage))
	return out


static func _dots(root: Node) -> Array[NotificationDot]:
	var out: Array[NotificationDot] = []
	out.assign(_collect(root, NotificationDot))
	return out


#The text nodes under a dot: a dot carries no count, so any of them is a failure.
static func _text_nodes(node: Node) -> int:
	var total: int = 0
	for child: Node in node.get_children():
		if child is Label or child is RichTextLabel:
			total += 1
		total += _text_nodes(child)
	return total


#The nearest node at or above the container that carries a script, or null when none does. A bare
#DropPanel (the old PopupPanel menu, D3c) is skipped, so its list stays owned by the button around it.
static func _owner_node_of(node: Node) -> Node:
	var walk: Node = node
	while walk != null:
		var scr: Script = walk.get_script() as Script
		if scr != null and scr.resource_path != "" and scr.resource_path != DROP_PANEL_SCRIPT:
			return walk
		walk = walk.get_parent()
	return null


#The script of the nearest node at or above the container, which names the list that scrolls.
static func _owner_of(node: Node) -> String:
	var owner: Node = _owner_node_of(node)
	if owner == null:
		return "(no script)"
	return (owner.get_script() as Script).resource_path


#True when the lock's owning script lists lock's node name among the locks it hides on purpose,
#read from CONTEXT_HIDDEN_LOCKS keyed by _owner_of. The walk starts at the parent: FeatureLock
#itself carries a script, so _owner_of(lock) would just return FeatureLock.gd and never reach the
#viewer that actually owns it.
static func _context_hidden(lock: FeatureLock) -> bool:
	var hidden: Array = CONTEXT_HIDDEN_LOCKS.get(_owner_of(lock.get_parent()), []) as Array
	return hidden.has(String(lock.name))


#True when a lock still sits at the FeatureLock defaults: no entitlement key, no upgrade and never
#pinned visible by a host. FeatureLock.locked() then falls back to required_plan's Enterprise
#default, which genuine call sites always override with a real key, upgrade or always_visible=true
#(GuiLockTests.gd covers that fallback directly), so a hidden lock still at those defaults, like
#InfoField's Lock child on a field with no lock_key, was never wired to a gate and is not a defect.
static func _unconfigured(lock: FeatureLock) -> bool:
	return lock.entitlement == "" and lock.upgrade_id == "" and not lock.always_visible


static func _path_of(root: Node, node: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var walk: Node = node
	while walk != null and walk != root:
		parts.insert(0, String(walk.name))
		walk = walk.get_parent()
	return "/".join(parts)


#What the managers hold before a screen opens, so that opening one shows up as a difference.
static func _snapshot() -> Dictionary:
	return {
		"bank": GameState.bank_notes,
		"mercs": GameState.mercs.size(),
		"contracts": GameState.contracts.size(),
		"busy": GameState.busy_uids().size(),
		"fines": LegalManager.fines.size(),
		"captured": LegalManager.captured.size(),
		"campaigns": PromotionsManager.campaigns.size(),
		"applicants": PromotionsManager.applicants.size(),
		"plan": int(SubscriptionManager.plan()),
	}


static func _snap_text(before: Dictionary, after: Dictionary) -> String:
	var diff: PackedStringArray = PackedStringArray()
	for key: String in before.keys():
		if before[key] != after[key]:
			diff.append("%s %s to %s" % [key, before[key], after[key]])
	return "no change" if diff.is_empty() else ", ".join(diff)


#The label of a scroll failure names the node path and the script that owns the list, either
#because no row names that owner or because that owner NODE's own count of containers is
#already spent. The count is kept per owner instance, not per owner script, so a component
#used more than once on a screen (TraitListPanel per merc, TeamSlot per slot) is not summed
#across its copies.
static func _scroll_report(root: Node, name_text: String) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for box: ScrollContainer in _scrolls(root):
		var owner: Node = _owner_node_of(box)
		var owner_path: String = _owner_of(box)
		var key: int = owner.get_instance_id() if owner != null else 0
		var allowed: int = int(SCROLL_OWNERS.get(owner_path, -1))
		var count: int = int(seen.get(key, 0)) + 1
		seen[key] = count
		if allowed < 0:
			bad.append("%s %s (%s, not in SCROLL_OWNERS)" % [name_text, _path_of(root, box), owner_path])
		elif count > allowed:
			bad.append("%s %s (%s, over its allowed %d)" % [name_text, _path_of(root, box), owner_path, allowed])
	return bad


#Spawns one A1 screen from VIEW_SCENES and checks it stands in the tree; null when it never spawned.
static func _a1_open(res: Dictionary, host: Node, scene_index: int, name_text: String) -> Control:
	var view: Control = _spawn(host, VIEW_SCENES[scene_index])
	await host.get_tree().process_frame
	TestFixtures.check(res, "A1 %s opens alone as the first screen" % name_text,
		view != null and view.is_inside_tree(), "node %s" % view)
	return view


#Checks the open touched no manager since the snapshot, then frees the screen.
static func _a1_close(res: Dictionary, name_text: String, view: Node, before: Dictionary) -> void:
	TestFixtures.check(res, "A1 %s touches no manager" % name_text,
		_snap_text(before, _snapshot()) == "no change", _snap_text(before, _snapshot()))
	_drop(view)


#A1. Every viewer opens alone, as the first screen of a fresh game, with no other screen before
#it and no manager touched by the open.
static func _case_a1_contracts(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: ContractViewer = (await _a1_open(res, host, 1, "contracts")) as ContractViewer
	if view == null:
		return
	var rows: int = view.list().row_count() if view.list() != null else -1
	var open_rows: int = 0
	for posting: ContractView in GameState.contracts:
		if not ContractListItem.is_closed(posting):
			open_rows += 1
	TestFixtures.check(res, "A1 contracts lists the seeded board's open postings",
		rows == open_rows and open_rows > 0,
		"rows %d of %d open, %d seeded" % [rows, open_rows, int(before["contracts"])])
	TestFixtures.check(res, "A1 contracts builds its detail pane",
		view.detail() != null and _kids(view.detail()) > 0,
		"children %d" % _kids(view.detail()))
	_a1_close(res, "contracts", view, before)


static func _case_a1_mercs(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: MercViewer = (await _a1_open(res, host, 0, "mercs")) as MercViewer
	if view == null:
		return
	TestFixtures.check(res, "A1 mercs lists the seeded roster",
		view.list != null and view.list.row_count() == int(before["mercs"]),
		"rows %d of %d" % [view.list.row_count(), int(before["mercs"])])
	for i: int in MercViewer.TAB_NAMES.size():
		view.select_tab(i)
		await host.get_tree().process_frame
		var page: Control = view.page(i)
		TestFixtures.check(res, "A1 mercs tab %s builds its page" % MercViewer.TAB_NAMES[i],
			page != null and _kids(page) > 0, "children %d" % _kids(page))
	_a1_close(res, "mercs", view, before)


static func _case_a1_metrics(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: MetricsViewer = (await _a1_open(res, host, 8, "metrics")) as MetricsViewer
	if view == null:
		return
	TestFixtures.check(res, "A1 metrics builds its metric list",
		view.metric_list != null and _kids(view.metric_list) > 0,
		"children %d" % _kids(view.metric_list))
	TestFixtures.check(res, "A1 metrics builds its chart",
		view.chart != null and view.chart.is_inside_tree(), "chart %s" % view.chart)
	_a1_close(res, "metrics", view, before)


static func _case_a1_mercday(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: SubscriptionViewer = (await _a1_open(res, host, 4, "mercday")) as SubscriptionViewer
	if view == null:
		return
	for key: StringName in SubscriptionViewer.TAB_KEYS:
		view.open_tab(key)
		await host.get_tree().process_frame
		var page: Control = view.customize_page()
		if key == SubscriptionViewer.PLANS_TAB:
			page = view.plans_page()
		TestFixtures.check(res, "A1 mercday tab %s builds its page" % key,
			page != null and _kids(page) > 0, "children %d" % _kids(page))
	_a1_close(res, "mercday", view, before)


static func _case_a1_bazaar(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: BazaarViewer = (await _a1_open(res, host, 7, "bazaar")) as BazaarViewer
	if view == null:
		return
	TestFixtures.check(res, "A1 bazaar shows no locked page at full entitlement",
		view.lock == null or not view.lock.visible,
		"locked page %s" % view.lock)
	for key: StringName in BazaarViewer.TAB_KEYS:
		view.open_tab(key)
		await host.get_tree().process_frame
		var page: Control = view.shop
		if key == BazaarViewer.TAB_KEYS[1]:
			page = view.cart
		elif key == BazaarViewer.TAB_KEYS[2]:
			page = view.orders
		TestFixtures.check(res, "A1 bazaar tab %s builds its page" % key,
			page != null and _kids(page) > 0, "children %d" % _kids(page))
	view.open_tab(BazaarViewer.TAB_KEYS[0])
	await host.get_tree().process_frame
	TestFixtures.check(res, "A1 bazaar shop lists the seeded stock",
		BazaarManager.catalog.size() > 0 and view.shop.card_count() > 0,
		"catalog %d cards %d" % [BazaarManager.catalog.size(), view.shop.card_count()])
	_a1_close(res, "bazaar", view, before)


static func _case_a1_legal(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: LegalViewer = (await _a1_open(res, host, 6, "legal")) as LegalViewer
	if view == null:
		return
	for key: StringName in LegalViewer.TAB_KEYS:
		view.open_tab(key)
		await host.get_tree().process_frame
		var page: Control = view.permits_page()
		if key == LegalViewer.TAB_KEYS[1]:
			page = view.fines_page()
		elif key == LegalViewer.TAB_KEYS[2]:
			page = view.bailout_page()
		TestFixtures.check(res, "A1 legal tab %s builds its page" % key,
			page != null and _kids(page) > 0, "children %d" % _kids(page))
	view.open_tab(LegalViewer.TAB_KEYS[0])
	await host.get_tree().process_frame
	TestFixtures.check(res, "A1 legal permits lists a card per location",
		view.permits_page().card_count() == LegalManager.LOCATIONS.size(),
		"cards %d of %d" % [view.permits_page().card_count(), LegalManager.LOCATIONS.size()])
	_a1_close(res, "legal", view, before)


static func _case_a1_promotions(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiHiringTests._lay_board()
	var before: Dictionary = _snapshot()
	var view: PromotionsViewer = (await _a1_open(res, host, 3, "promotions")) as PromotionsViewer
	if view == null:
		return
	for key: StringName in [PromotionsViewer.JOB_KEY, PromotionsViewer.PROMO_KEY]:
		view.open_tab(key)
		await host.get_tree().process_frame
		TestFixtures.check(res, "A1 promotions tab %s builds its list" % key,
			view.campaign_list() != null and _kids(view.campaign_list()) > 0,
			"children %d" % _kids(view.campaign_list()))
		TestFixtures.check(res, "A1 promotions tab %s shows no lock at full entitlement" % key,
			not view.lock_shown(), "lock shown %s" % view.lock_shown())
	view.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A1 promotions job lists the board's job ads",
		view.card_count() > 0, "cards %d" % view.card_count())
	_a1_close(res, "promotions", view, before)


static func _case_a1_finance(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiHiringTests._lay_board()
	var before: Dictionary = _snapshot()
	var view: FinanceViewer = (await _a1_open(res, host, 5, "finance")) as FinanceViewer
	if view == null:
		return
	for key: StringName in FinanceViewer.TAB_KEYS:
		view.open_tab(key)
		await host.get_tree().process_frame
		var page: Node = view.page(key)
		if key == FinanceViewer.OVERVIEW_KEY:
			page = view.overview()
		TestFixtures.check(res, "A1 finance tab %s builds its page" % key,
			page != null and _kids(page) > 0, "children %d" % _kids(page))
	view.open_tab(FinanceViewer.HIRING_KEY)
	await host.get_tree().process_frame
	var hiring: HiringTab = view.page(FinanceViewer.HIRING_KEY) as HiringTab
	var cards: int = hiring.card_ids().size() if hiring != null else -1
	TestFixtures.check(res, "A1 finance hiring lists the board's applicants",
		cards == int(before["applicants"]),
		"cards %d of %d" % [cards, int(before["applicants"])])
	_a1_close(res, "finance", view, before)


static func _case_a1_clients(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var view: ClientViewer = (await _a1_open(res, host, 2, "clients")) as ClientViewer
	if view == null:
		return
	for kind: StringName in ClientRegistry.KINDS:
		view.open_tab(kind)
		await host.get_tree().process_frame
		var listed: int = view.list.rows().size()
		#Client Viewer.dc.html:233, "only clients who have sent you contracts": the list is the
		#offered subset, not the raw registry.
		var held: int = view.registry().total(kind)
		TestFixtures.check(res, "A1 clients tab %s lists the offered clients" % kind,
			listed == held, "listed %d of %d" % [listed, held])
		TestFixtures.check(res, "A1 clients tab %s builds its overview" % kind,
			view.overview != null and _kids(view.overview) > 0,
			"children %d" % _kids(view.overview))
	_a1_close(res, "clients", view, before)


static func _case_a1_dispatch(res: Dictionary, host: Node) -> void:
	_fresh()
	var before: Dictionary = _snapshot()
	var has_board: bool = GameState.contracts.size() > 0
	TestFixtures.check(res, "A1 dispatch has a contract to open",
		has_board, "contracts %d" % GameState.contracts.size())
	if not has_board:
		return
	var entry: ContractView = GameState.contracts[0]
	var win: DispatchWindow = await GuiContractTests._spawn_window(entry, host)
	TestFixtures.check(res, "A1 dispatch opens over the contract viewer",
		win.is_inside_tree(), "in tree %s" % win.is_inside_tree())
	TestFixtures.check(res, "A1 dispatch builds its roster panel",
		win.roster_panel() != null and _kids(win.roster_panel()) > 0,
		"children %d" % _kids(win.roster_panel()))
	TestFixtures.check(res, "A1 dispatch builds its team slots",
		win.slot_at(0) != null, "slot %s" % win.slot_at(0))
	_a1_close(res, "dispatch", win, before)


static func _spawn_hud(host: Node) -> GameHUD:
	var scene: PackedScene = load(HUD_SCENE) as PackedScene
	var hud: GameHUD = scene.instantiate() as GameHUD
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	return hud


#A1 second half: the same nine viewers through the HUD grid routing.
static func _case_a1_hud(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await host.get_tree().process_frame
	for i: int in VIEW_KEYS.size():
		TestFixtures.check(res, "A1 hud grid tile %d is %s" % [i, VIEW_KEYS[i]],
			hud.entry_key(i) == VIEW_KEYS[i], "key %s" % hud.entry_key(i))
		TestFixtures.check(res, "A1 hud routes %s to its scene" % VIEW_KEYS[i],
			String(GameHUD.VIEWER_SCENES.get(VIEW_KEYS[i], "")) == VIEW_SCENES[i],
			"path %s" % GameHUD.VIEWER_SCENES.get(VIEW_KEYS[i], ""))
		hud.open_menu(i)
		await host.get_tree().process_frame
		var made: Node = hud.popup().current()
		var made_path: String = made.scene_file_path if made != null else ""
		TestFixtures.check(res, "A1 hud opens %s from the grid" % VIEW_KEYS[i],
			made != null and made.is_inside_tree() and made_path == VIEW_SCENES[i],
			"opened %s" % made_path)
	hud.popup().close()
	await host.get_tree().process_frame
	_drop(hud)


#Opens every tab of a viewer, so that A2, A3 and A4 see the whole screen and not the first page.
static func _open_all_tabs(view: Control, key: StringName, host: Node) -> void:
	if key == &"mercs":
		for i: int in MercViewer.TAB_NAMES.size():
			(view as MercViewer).select_tab(i)
			await host.get_tree().process_frame
	elif key == &"clients":
		for kind: StringName in ClientRegistry.KINDS:
			(view as ClientViewer).open_tab(kind)
			await host.get_tree().process_frame
	elif key == &"promotions":
		for promo_key: StringName in [PromotionsViewer.JOB_KEY, PromotionsViewer.PROMO_KEY]:
			(view as PromotionsViewer).open_tab(promo_key)
			await host.get_tree().process_frame
	elif key == &"mercday":
		for sub_key: StringName in SubscriptionViewer.TAB_KEYS:
			(view as SubscriptionViewer).open_tab(sub_key)
			await host.get_tree().process_frame
	elif key == &"finance":
		for fin_key: StringName in FinanceViewer.TAB_KEYS:
			(view as FinanceViewer).open_tab(fin_key)
			await host.get_tree().process_frame
	elif key == &"legal":
		for legal_key: StringName in LegalViewer.TAB_KEYS:
			(view as LegalViewer).open_tab(legal_key)
			await host.get_tree().process_frame
	elif key == &"bazaar":
		for baz_key: StringName in BazaarViewer.TAB_KEYS:
			(view as BazaarViewer).open_tab(baz_key)
			await host.get_tree().process_frame
	await host.get_tree().process_frame


#A2. A window never scrolls: only the lists RUNBOOK.md line 38 and README C2 name, and the
#lists that scrolled before this package, may hold a ScrollContainer.
static func _case_a2_scrolls(res: Dictionary, host: Node) -> void:
	_fresh()
	for i: int in VIEW_KEYS.size():
		var view: Control = _spawn(host, VIEW_SCENES[i])
		await host.get_tree().process_frame
		await _open_all_tabs(view, VIEW_KEYS[i], host)
		var bad: PackedStringArray = _scroll_report(view, String(VIEW_KEYS[i]))
		TestFixtures.check(res, "A2 %s scrolls only in a list the docs name" % VIEW_KEYS[i],
			bad.is_empty(), "; ".join(bad))
		_drop(view)
		await host.get_tree().process_frame
	var has_board: bool = GameState.contracts.size() > 0
	TestFixtures.check(res, "A2 dispatch has a contract to open",
		has_board, "contracts %d" % GameState.contracts.size())
	if not has_board:
		return
	var entry: ContractView = GameState.contracts[0]
	var win: DispatchWindow = await GuiContractTests._spawn_window(entry, host)
	var win_bad: PackedStringArray = _scroll_report(win, "dispatch")
	TestFixtures.check(res, "A2 dispatch scrolls only in a list the docs name",
		win_bad.is_empty(), "; ".join(win_bad))
	_drop(win)
	await host.get_tree().process_frame


#A2. Proves _scroll_report flags an owner absent from SCROLL_OWNERS and an owner whose
#ScrollContainer count exceeds its row. The probe root carries a real script loaded
#from disk, so its resource_path is not empty, but it is never added to the tree: no _ready()
#fires and no scene game file is created.
static func _case_a2_scroll_report(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var unlisted_script: Script = load("res://Scripts/GUI/Shared/LockedPage.gd") as Script
	var unlisted_root: Control = Control.new()
	unlisted_root.set_script(unlisted_script)
	unlisted_root.add_child(ScrollContainer.new())
	var unlisted_bad: PackedStringArray = _scroll_report(unlisted_root, "probe")
	TestFixtures.check(res, "A2 scroll report flags an owner not in SCROLL_OWNERS",
		unlisted_bad.size() == 1 and unlisted_bad[0].contains("not in SCROLL_OWNERS"),
		"; ".join(unlisted_bad))
	unlisted_root.free()

	var over_script: Script = load("res://Scripts/GUI/Shared/MercPicker.gd") as Script
	var over_root: Control = Control.new()
	over_root.set_script(over_script)
	over_root.add_child(ScrollContainer.new())
	over_root.add_child(ScrollContainer.new())
	var over_bad: PackedStringArray = _scroll_report(over_root, "probe")
	TestFixtures.check(res, "A2 scroll report flags an owner over its allowed count",
		over_bad.size() == 1 and over_bad[0].contains("over its allowed"),
		"; ".join(over_bad))
	over_root.free()


#A2. Every viewer fits the 1280 x 644 content box of its SubWindow.
static func _case_a2_fit(res: Dictionary, host: Node) -> void:
	_fresh()
	for i: int in VIEW_KEYS.size():
		var view: Control = _spawn(host, VIEW_SCENES[i])
		await host.get_tree().process_frame
		await _open_all_tabs(view, VIEW_KEYS[i], host)
		view.size = BAND_SIZE
		await host.get_tree().process_frame
		var want: Vector2 = view.get_combined_minimum_size()
		TestFixtures.check(res, "A2 %s fits the 1280 x 644 window" % VIEW_KEYS[i],
			want.x <= BAND_SIZE.x + FIT_SLACK and want.y <= BAND_SIZE.y + FIT_SLACK,
			"minimum %s" % want)
		_drop(view)
		await host.get_tree().process_frame


#A2. The HUD never scrolls except the notification list of the bell dropdown (Game HUD.dc.html
#329 overflow-y auto; scene note 605), so the walk of SCROLL_OWNERS applies, with
#NotificationPanel.gd allowed one container.
static func _case_a2_hud(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await host.get_tree().process_frame
	hud.bell().open_panel()
	await host.get_tree().process_frame
	var found: PackedStringArray = _scroll_report(hud, "hud")
	TestFixtures.check(res, "A2 hud scrolls only in the bell panel list",
		found.is_empty(), "; ".join(found))
	var hud_min: Vector2 = hud.root.get_combined_minimum_size()
	TestFixtures.check(res, "A2 hud fits the screen it is built for",
		hud_min.y <= CONTENT_SIZE.y + FIT_SLACK, "minimum %s" % hud_min)
	_drop(hud)
	await host.get_tree().process_frame


#The close X rect of a window canvas of this width, in canvas coordinates (SubWindow._layout).
static func close_x_rect(width: float) -> Rect2:
	var art: float = float(CloseX.ART * CloseX.SCALE_WINDOW)
	var outline: float = float(CloseX.SCALE_WINDOW)
	return Rect2(Vector2(width - SubWindow.CLOSE_INSET - art - outline,
		SubWindow.CLOSE_INSET - outline), CloseX.size(CloseX.SCALE_WINDOW))


#Pinned interface 3, read by the viewer suites: a page asks for no more than the canvas and no
#control ends outside it. The viewer root pins custom_minimum_size to the canvas, so the page is
#measured on the layout containers under it as well. A scrolled list is allowed to overflow, so
#the walk stops at a ScrollContainer, and a top_level node lays out on its own.
static func fit_report(view: Control) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	var canvas: Rect2 = Rect2(view.global_position, BAND_SIZE)
	_fit_min(view, bad)
	for child: Node in view.get_children():
		if child is Container:
			_fit_min(child as Control, bad)
	_fit_walk(view, canvas, bad)
	return bad


static func _fit_min(box: Control, bad: PackedStringArray) -> void:
	if not box.visible:
		return
	var want: Vector2 = box.get_combined_minimum_size()
	if want.x > BAND_SIZE.x + FIT_SLACK or want.y > BAND_SIZE.y + FIT_SLACK:
		bad.append("%s asks for %s via %s" % [box.name, want,
			widest_chain(box, want.x > BAND_SIZE.x + FIT_SLACK)])


#The chain of the children asking for the most width (or height) under a box, so a fit failure
#names the control that drives the overflow.
static func widest_chain(box: Control, by_width: bool) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var node: Control = box
	while node != null:
		var next: Control = null
		var most: float = -1.0
		for child: Node in node.get_children():
			var sub: Control = child as Control
			if sub == null or not sub.visible or sub.top_level:
				continue
			var want: Vector2 = sub.get_combined_minimum_size()
			var ask: float = want.x if by_width else want.y
			if ask > most:
				most = ask
				next = sub
		if next == null:
			break
		parts.append("%s %d" % [next.name, int(most)])
		node = next
	return " > ".join(parts)


static func _fit_walk(node: Node, canvas: Rect2, bad: PackedStringArray) -> void:
	for child: Node in node.get_children():
		var box: Control = child as Control
		if box == null or not box.visible or box.top_level:
			continue
		if not canvas.grow(FIT_SLACK).encloses(box.get_global_rect()):
			bad.append("%s ends outside the canvas at %s" % [box.name, box.get_global_rect()])
		elif not (box is ScrollContainer):
			_fit_walk(box, canvas, bad)


#Pinned interfaces 2 and 3 for a viewer sized to the 1280 x 644 band at the top left of the screen.
static func window_report(view: Control) -> PackedStringArray:
	var bad: PackedStringArray = fit_report(view)
	var x_rect: Rect2 = close_x_rect(BAND_SIZE.x)
	x_rect.position += view.global_position
	bad.append_array(close_clear_report(view, x_rect))
	return bad


#Pinned interface 2, read by the viewer suites: no text, icon or button of the viewer lies under
#the close X. Panels and layout boxes may run under it; what they hold may not.
static func close_clear_report(root: Control, x_rect: Rect2) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	_close_walk(root, x_rect, bad)
	return bad


static func _close_walk(node: Node, x_rect: Rect2, bad: PackedStringArray) -> void:
	for child: Node in node.get_children():
		var box: Control = child as Control
		if box == null or not box.visible or box.top_level:
			continue
		var rect: Rect2 = box.get_global_rect()
		if not rect.intersects(x_rect):
			continue
		if box is Container or box is Panel or box is ColorRect:
			_close_walk(box, x_rect, bad)
		elif _blank_spacer(box):
			continue
		else:
			bad.append("%s lies under the close X at %s" % [box.name, rect])


#A plain Control with no script and no children draws nothing and takes no click.
static func _blank_spacer(box: Control) -> bool:
	return (box.get_class() == "Control" and box.get_script() == null
		and box.get_child_count() == 0 and box.mouse_filter == Control.MOUSE_FILTER_IGNORE)


#A6. The orange border lies inside the canvas edge, over the content and under the close X, so
#every side of it is on screen at 1280 x 720 with the bottom bar reserved.
static func _border_report(root: Control, holder: Control, frame: Control, border: Panel,
		close_x: Control) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	var canvas: Rect2 = Rect2(holder.position, holder.size)
	if not (frame.position.is_equal_approx(canvas.position)
			and frame.size.is_equal_approx(canvas.size)):
		bad.append("frame %s/%s is not the canvas %s" % [frame.position, frame.size, canvas])
	if not (border.position.is_equal_approx(canvas.position)
			and border.size.is_equal_approx(canvas.size)):
		bad.append("border %s/%s is not the canvas %s" % [border.position, border.size, canvas])
	var style: StyleBoxFlat = border.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		bad.append("the border carries no StyleBoxFlat")
	else:
		if style.draw_center:
			bad.append("the border style draws its centre over the content")
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			if style.get_border_width(side) != BORDER_PX:
				bad.append("border width %d on side %d" % [style.get_border_width(side), side])
		if style.border_color.to_html(false) != BORDER_COLOR.to_html(false):
			bad.append("border colour %s" % style.border_color)
	if border.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		bad.append("the border eats the mouse (filter %d)" % border.mouse_filter)
	if border.get_index() < holder.get_index() or border.get_index() > close_x.get_index():
		bad.append("the border is not drawn between the content and the close X")
	var screen: Rect2 = Rect2(Vector2.ZERO, root.size)
	if not screen.grow(FIT_SLACK).encloses(Rect2(border.position, border.size)):
		bad.append("the border leaves the screen %s" % screen)
	var x_rect: Rect2 = Rect2(close_x.position, close_x.size)
	if not canvas.grow(FIT_SLACK).encloses(x_rect):
		bad.append("the close X %s is outside the canvas" % x_rect)
	var want: Vector2 = canvas.position + close_x_rect(canvas.size.x).position
	if not close_x.position.is_equal_approx(want):
		bad.append("the close X sits at %s, not %s" % [close_x.position, want])
	return bad


static func _case_a6_window_border(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiFrameStack.bottom_reserve = 76.0
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win._layout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "A6 the sub window canvas stays 1280 x 644",
		win.holder.size.is_equal_approx(BAND_SIZE), "holder %s" % win.holder.size)
	var bad: PackedStringArray = _border_report(win, win.holder, win.frame, win.border, win.close_x)
	TestFixtures.check(res, "A6 the sub window border sits inside the canvas under the close X",
		bad.is_empty(), "; ".join(bad))
	GuiFrameStack.bottom_reserve = 0.0
	_drop(win)
	await host.get_tree().process_frame


static func _case_a6_popup_border(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiFrameStack.bottom_reserve = 76.0
	var popup: ViewerPopup = (load(POPUP_SCENE) as PackedScene).instantiate()
	popup.content_width = float(ViewerPopup.MERC["width"])
	host.add_child(popup)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	popup._layout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "A6 a narrow popup keeps its own 988 wide canvas",
		popup.holder.size.is_equal_approx(Vector2(988.0, BAND_SIZE.y)),
		"holder %s" % popup.holder.size)
	var bad: PackedStringArray = _border_report(popup, popup.holder, popup.frame, popup.border,
		popup.close_x)
	TestFixtures.check(res, "A6 the popup border sits inside its box under the close X",
		bad.is_empty(), "; ".join(bad))
	GuiFrameStack.bottom_reserve = 0.0
	_drop(popup)
	await host.get_tree().process_frame


#A6. No label or button in the merc, contract, client or metrics screens draws a text shadow
#or outline, neither from a scene override nor from a script override.
static func _case_a6_flat_text(res: Dictionary) -> void:
	var bad: PackedStringArray = []
	var read: int = 0
	for dir: String in FLAT_TEXT_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if not (file.ends_with(".tscn") or file.ends_with(".gd")):
				continue
			var body: String = FileAccess.get_file_as_string(dir.path_join(file))
			read += 1
			for effect: String in TEXT_EFFECTS:
				if (body.contains("/" + effect + " =")
						or body.contains("_override(\"" + effect + "\"")):
					bad.append("%s %s" % [file, effect])
	TestFixtures.check(res, "A6 the screen text draws flat with no shadow or outline",
		read > 0 and bad.is_empty(), "read %d; %s" % [read, "; ".join(bad)])


#The text effect overrides one control carries; empty when its text draws flat.
static func text_effect_report(ctrl: Control) -> PackedStringArray:
	var bad: PackedStringArray = []
	for effect: String in TEXT_EFFECTS:
		if ctrl.has_theme_color_override(effect) or ctrl.has_theme_constant_override(effect):
			bad.append(effect)
	return bad


static func _dialog_under(node: Node) -> FeatureLockDialog:
	for child: Node in node.get_children():
		var found: Array[Node] = _collect(child, FeatureLockDialog)
		if not found.is_empty():
			return found[0] as FeatureLockDialog
	return null


#A3. At plan Free with no upgrade every lock a viewer shows is on screen as a locked control,
#opens the lock dialog when it is pressed, and names an upgrade or a plan that exists. The
#screens gate their own rows by entitlement key, so a lock a screen does not show is a row
#that is off for another reason and is not read here.
static func _case_a3_locks(res: Dictionary, host: Node) -> void:
	_fresh()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	await host.get_tree().process_frame
	var seen_locks: int = 0
	var seen_pages: int = 0
	for i: int in VIEW_KEYS.size():
		var view: Control = _spawn(host, VIEW_SCENES[i])
		await host.get_tree().process_frame
		await _open_all_tabs(view, VIEW_KEYS[i], host)
		var hidden_locked: PackedStringArray = PackedStringArray()
		for lock: FeatureLock in _locks(view):
			if not lock.visible and lock.locked() and not _context_hidden(lock) \
					and not _unconfigured(lock):
				hidden_locked.append(_path_of(view, lock))
			if not lock.visible:
				continue
			seen_locks += 1
			var where: String = "%s %s" % [VIEW_KEYS[i], _path_of(view, lock)]
			TestFixtures.check(res, "A3 a shown lock reads as locked at Free: %s" % where,
				lock.locked(), "locked %s" % lock.locked())
			TestFixtures.check(res, "A3 lock names a real plan: %s" % where,
				SubscriptionManager.PLAN_NAMES.has(lock.plan), "plan %s" % lock.plan)
			TestFixtures.check(res, "A3 lock names a real upgrade: %s" % where,
				lock.upgrade_id == "" or UpgradeDefs.has_id(lock.upgrade_id),
				"upgrade id %s" % lock.upgrade_id)
			lock.open_dialog()
			await host.get_tree().process_frame
			var dialog: FeatureLockDialog = _dialog_under(lock)
			TestFixtures.check(res, "A3 lock opens the lock dialog: %s" % where,
				dialog != null and dialog.visible, "dialog %s" % dialog)
			if dialog != null:
				dialog.press_close()
				await host.get_tree().process_frame
		#RUNBOOK.md:37, Locked controls stay visible. A hidden lock that reads locked() is a
		#defect unless its host lists it in CONTEXT_HIDDEN_LOCKS or the lock itself was never
		#wired to a gate (_unconfigured).
		TestFixtures.check(res, "A3 %s hides no lock that reads as locked" % VIEW_KEYS[i],
			hidden_locked.is_empty(), "; ".join(hidden_locked))
		for page: LockedPage in _locked_pages(view):
			if not page.visible:
				continue
			seen_pages += 1
			var spot: String = "%s %s" % [VIEW_KEYS[i], _path_of(view, page)]
			TestFixtures.check(res, "A3 locked page names a real plan: %s" % spot,
				SubscriptionManager.PLAN_NAMES.has(page.plan), "plan %s" % page.plan)
			TestFixtures.check(res, "A3 locked page names a real upgrade: %s" % spot,
				page.upgrade_id == "" or UpgradeDefs.has_id(page.upgrade_id),
				"upgrade id %s" % page.upgrade_id)
			var target: Dictionary = page.target()
			var tab: String = String(target.get("tab", ""))
			TestFixtures.check(res, "A3 locked page targets a real tab: %s" % spot,
				SubscriptionViewer.TAB_KEYS.has(StringName(tab)), "tab %s" % tab)
		_drop(view)
		await host.get_tree().process_frame
	TestFixtures.check(res, "A3 the Free plan shows locks to read",
		seen_locks + seen_pages > 0, "locks %d pages %d" % [seen_locks, seen_pages])
	_fresh()


static func _check_dot(res: Dictionary, dot: NotificationDot, where: String) -> void:
	#The scene note of HANDOFF\reference_html\Game HUD.dc.html line 613 names NotificationDot.tscn
	#as the one shared dot of the bell, the menu buttons and the list items.
	TestFixtures.check(res, "A4 dot is the shared scene: %s" % where,
		dot.scene_file_path == NotificationDot.SCENE_PATH,
		"scene %s" % ("(built in code)" if dot.scene_file_path == "" else dot.scene_file_path))
	TestFixtures.check(res, "A4 dot shows no count: %s" % where,
		_text_nodes(dot) == 0 and dot.get_child_count() == 0,
		"children %d text %d" % [dot.get_child_count(), _text_nodes(dot)])
	TestFixtures.check(res, "A4 dot keeps the one red style: %s" % where,
		dot.custom_minimum_size.is_equal_approx(NotificationDot.FRAME_SIZE)
		and dot.modulate.is_equal_approx(Color(1.0, 1.0, 1.0, 1.0))
		and dot.self_modulate.is_equal_approx(Color(1.0, 1.0, 1.0, 1.0)),
		"size %s modulate %s self %s" % [dot.custom_minimum_size, dot.modulate,
		dot.self_modulate])
	#Design values of Notification Dot.dc.html, read as suite consts beside their own source
	#line, never a const of the game.
	var color_variant: Variant = dot.get("color")
	var has_color: bool = color_variant is Color
	var color_val: Color = color_variant if has_color else Color()
	var color_text: String = "NotificationDot has no color" if not has_color else "%s" % color_val
	TestFixtures.check(res, "A4 dot color is the design red: %s" % where,
		has_color and color_val.is_equal_approx(DOT_RED), color_text)
	TestFixtures.check(res, "A4 dot outline is the design colour: %s" % where,
		NotificationDot.OUTLINE_COLOR.is_equal_approx(DOT_OUTLINE),
		"outline %s" % NotificationDot.OUTLINE_COLOR)
	if dot.has_method("dot_rect"):
		var rect: Rect2 = dot.call("dot_rect")
		TestFixtures.check(res, "A4 dot rect is 16 x 16: %s" % where,
			rect.size.is_equal_approx(DOT_PX), "rect %s" % rect)
	else:
		TestFixtures.check(res, "A4 dot rect is 16 x 16: %s" % where,
			false, "NotificationDot has no dot_rect")
	if dot.has_method("frame_rect"):
		var frame: Rect2 = dot.call("frame_rect")
		TestFixtures.check(res, "A4 dot frame is 28 x 28: %s" % where,
			frame.size.is_equal_approx(DOT_FRAME_PX), "frame %s" % frame)
	else:
		TestFixtures.check(res, "A4 dot frame is 28 x 28: %s" % where,
			false, "NotificationDot has no frame_rect")


#A4. Every dot in every viewer and in the HUD is the one shared scene, with no count and one
#red style (README E5).
static func _case_a4_dots(res: Dictionary, host: Node) -> void:
	_fresh()
	var seen: int = 0
	for i: int in VIEW_KEYS.size():
		var view: Control = _spawn(host, VIEW_SCENES[i])
		await host.get_tree().process_frame
		await _open_all_tabs(view, VIEW_KEYS[i], host)
		for dot: NotificationDot in _dots(view):
			seen += 1
			_check_dot(res, dot, "%s %s" % [VIEW_KEYS[i], _path_of(view, dot)])
		_drop(view)
		await host.get_tree().process_frame
	var hud: GameHUD = _spawn_hud(host)
	await host.get_tree().process_frame
	hud.refresh_dots()
	await host.get_tree().process_frame
	var hud_dots: Array[NotificationDot] = _dots(hud)
	for dot: NotificationDot in hud_dots:
		seen += 1
		_check_dot(res, dot, "hud %s" % _path_of(hud, dot))
	TestFixtures.check(res, "A4 the hud grid carries a dot per tile",
		hud_dots.size() >= VIEW_KEYS.size(), "dots %d tiles %d" % [hud_dots.size(),
		VIEW_KEYS.size()])
	TestFixtures.check(res, "A4 the screens carry dots to read", seen > 0, "dots %d" % seen)
	_drop(hud)
	await host.get_tree().process_frame


#A5. README E5: every notes-spending action confirms first. Permit request.
static func _case_a5_permit(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.bank_notes = RICH
	var view: LegalViewer = _spawn(host, VIEW_SCENES[6]) as LegalViewer
	await host.get_tree().process_frame
	view.open_tab(LegalViewer.TAB_KEYS[0])
	await host.get_tree().process_frame
	var before: int = GameState.bank_notes
	view.permits_page().press_request(PERMIT_LOC)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 permit request opens the request dialog",
		view.request_dialog().visible, "visible %s" % view.request_dialog().visible)
	view.request_dialog().press_permit(LegalManager.PERMIT_OPS)
	await host.get_tree().process_frame
	await _check_confirm_spend(res, host, view, before, "permit request")
	_drop(view)
	await host.get_tree().process_frame


#A5 for a review dialog: pays the fine or capture row named by the target kind and id.
static func _case_a5_review(res: Dictionary, host: Node, target: String, id: int,
		label: String) -> void:
	_fresh()
	GuiLegalTests._lay_legal()
	GameState.bank_notes = RICH
	var view: LegalViewer = _spawn(host, VIEW_SCENES[6]) as LegalViewer
	await host.get_tree().process_frame
	view.open_review(target, id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 %s opens the review dialog" % label,
		view.review_dialog().visible and view.review_dialog().pay_enabled(),
		"visible %s enabled %s" % [view.review_dialog().visible,
		view.review_dialog().pay_enabled()])
	var before: int = GameState.bank_notes
	view.review_dialog().press_pay()
	await host.get_tree().process_frame
	await _check_confirm_spend(res, host, view, before, label)
	_drop(view)
	await host.get_tree().process_frame


#The shared tail of the A5 spend cases: the confirm shows first, the bank holds, then confirm spends.
static func _check_confirm_spend(res: Dictionary, host: Node, view: LegalViewer, before: int,
		label: String) -> void:
	TestFixtures.check(res, "A5 %s confirms before it spends" % label,
		view.confirm().visible, "confirm visible %s" % view.confirm().visible)
	TestFixtures.check(res, "A5 %s leaves the bank alone until confirm" % label,
		GameState.bank_notes == before, "bank %d of %d" % [GameState.bank_notes, before])
	view.confirm().press(view.confirm().button_count() - 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 %s spends once confirm is pressed" % label,
		GameState.bank_notes < before, "bank %d of %d" % [GameState.bank_notes, before])


static func _hiring_tab(host: Node, view: FinanceViewer) -> HiringTab:
	view.open_tab(FinanceViewer.HIRING_KEY)
	await host.get_tree().process_frame
	return view.page(FinanceViewer.HIRING_KEY) as HiringTab


static func _case_a5_hire(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiHiringTests._lay_board()
	GameState.bank_notes = RICH
	var view: FinanceViewer = _spawn(host, VIEW_SCENES[5]) as FinanceViewer
	await host.get_tree().process_frame
	var tab: HiringTab = await _hiring_tab(host, view)
	var picked: int = -1
	for id: int in tab.card_ids():
		tab.press_offer(id)
		await host.get_tree().process_frame
		if tab.offer_dialog() != null and not tab.offer_dialog().is_counter():
			picked = id
			break
		if tab.offer_dialog() != null:
			tab.offer_dialog().press_cancel()
			await host.get_tree().process_frame
	TestFixtures.check(res, "A5 hire opens the offer dialog for an applicant",
		picked >= 0 and tab.offer_dialog().visible, "applicant %d" % picked)
	if picked < 0:
		_drop(view)
		return
	var before: int = GameState.mercs.size()
	var stored: MercenaryData = PromotionsManager.merc_of(PromotionsManager.applicant_of(picked))
	tab.offer_dialog().press_action()
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 hire confirms before it spends",
		tab.confirm_dialog().visible, "confirm visible %s" % tab.confirm_dialog().visible)
	TestFixtures.check(res, "A5 hire leaves the roster alone until confirm",
		GameState.mercs.size() == before, "roster %d of %d" % [GameState.mercs.size(), before])
	tab.confirm_dialog().press(tab.confirm_dialog().button_count() - 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 hire adds the merc once confirm is pressed",
		GameState.mercs.size() == before + 1,
		"roster %d of %d" % [GameState.mercs.size(), before])
	TestFixtures.check(res, "A5 hire signs on the merc rolled when the applicant appeared",
		stored != null and GameState.mercs.has(stored)
		and PromotionsManager.last_hired_uid == stored.merc_uid,
		"stored %s hired uid %d" % [str(stored != null), PromotionsManager.last_hired_uid])
	_drop(view)
	await host.get_tree().process_frame


static func _case_a5_reject(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiHiringTests._lay_board()
	var view: FinanceViewer = _spawn(host, VIEW_SCENES[5]) as FinanceViewer
	await host.get_tree().process_frame
	var tab: HiringTab = await _hiring_tab(host, view)
	var ids: Array[int] = tab.card_ids()
	TestFixtures.check(res, "A5 reject has an applicant to reject", ids.size() > 0,
		"applicants %d" % ids.size())
	if ids.is_empty():
		_drop(view)
		return
	var before: int = PromotionsManager.applicants.size()
	tab.press_reject(ids[0])
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 reject confirms before it drops the applicant",
		tab.confirm_dialog().visible, "confirm visible %s" % tab.confirm_dialog().visible)
	TestFixtures.check(res, "A5 reject leaves the applicant list alone until confirm",
		PromotionsManager.applicants.size() == before,
		"applicants %d of %d" % [PromotionsManager.applicants.size(), before])
	tab.confirm_dialog().press(tab.confirm_dialog().button_count() - 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 reject drops the applicant once confirm is pressed",
		PromotionsManager.applicants.size() == before - 1,
		"applicants %d of %d" % [PromotionsManager.applicants.size(), before])
	_drop(view)
	await host.get_tree().process_frame


static func _case_a5_campaign(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiHiringTests._lay_board()
	var view: PromotionsViewer = _spawn(host, VIEW_SCENES[3]) as PromotionsViewer
	await host.get_tree().process_frame
	view.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	var picked: int = -1
	for campaign: CampaignData in PromotionsManager.campaigns:
		if bool(PromotionsManager.end_preview(campaign.id).get("ok", false)):
			picked = campaign.id
			break
	TestFixtures.check(res, "A5 end campaign has a running campaign to end", picked >= 0,
		"campaign %d" % picked)
	if picked < 0:
		_drop(view)
		return
	var before: int = GameState.bank_notes
	view.press_end(picked)
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 end campaign confirms before it ends",
		view.confirm().visible, "confirm visible %s" % view.confirm().visible)
	TestFixtures.check(res, "A5 end campaign leaves the bank alone until confirm",
		GameState.bank_notes == before, "bank %d of %d" % [GameState.bank_notes, before])
	TestFixtures.check(res, "A5 end campaign leaves the campaign running until confirm",
		bool(PromotionsManager.end_preview(picked).get("ok", false)),
		"still endable %s" % PromotionsManager.end_preview(picked).get("ok", false))
	view.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "A5 end campaign ends it once confirm is pressed",
		not bool(PromotionsManager.end_preview(picked).get("ok", false)),
		"still endable %s" % PromotionsManager.end_preview(picked).get("ok", false))
	_drop(view)
	await host.get_tree().process_frame

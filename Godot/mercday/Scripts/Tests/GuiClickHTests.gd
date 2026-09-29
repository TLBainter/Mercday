class_name GuiClickHTests
extends RefCounted

#Click-through suite for README Part H, steps H1 to H9. Every case drives the real GameHUD and
#the real viewer scenes through the press helpers the screens expose, because a synthetic click
#never reaches a button headless. Flag --gui-click-h-tests.

const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const RICH: int = 40000

#README E1, row-major: the nine tiles of the 3 x 3 grid.
const GRID_LABELS: Array[String] = ["My Mercs", "My Contracts", "My Clients", "My Promotions",
	"My Mercday", "My Finance", "My Legal", "My Bazaar", "My Metrics"]
const GRID_KEYS: Array[StringName] = [&"mercs", &"contracts", &"clients", &"promotions",
	&"mercday", &"finance", &"legal", &"bazaar", &"metrics"]
const PROMO_KEY: StringName = &"promotions"
const PROMO_TIP: String = "Run ad campaigns and hire mercs who apply"
const PLAN_TIP: String = "Locked. Requires Mercday Enterprise."
const PLAN_LINE1: String = "This feature of Mercday is not available on your plan!"
const PLAN_LINE2: String = "Upgrade to Mercday Enterprise to use Promotions."
const UPGRADE_LINE1: String = "Promotions is locked."
const UPGRADE_LINE2: String = "It requires the Promotions upgrade."

#README 301: hover lifts a grid tile to z_index 25; the grid itself sits at z_index 3.
const HOVER_Z_INDEX: int = 25
const GRID_Z_INDEX: int = 3

#The seeded legal rows: fines 1 and 3 and capture 1 arrive unread, fines 2 and 4 and capture 2
#arrive read. Fine 2 is five days past due, fine 1 carries the contract the crew worked.
const FINE_UNREAD: int = 1
const FINE_READ: int = 2
const FINE_PAID: int = 4
const CONTRACT_ENTRY: int = 11
const CAPTURE_UNREAD: int = 1
const CAPTURE_READ: int = 2
#LegalManager.gd SEED_CAPTURES row id 1: the merc uid held by the unread capture.
const CAPTURE_UID: int = 4
#README 388: the Bailout column heads.
const HEAD_SERVED_TEXT: String = "Time Served"
const HEAD_LEFT_TEXT: String = "Time Remaining"
const HOME_LOC: int = 0
const NEAR_LOC: int = 1
const SHORT_LOC: int = 5
const SHORT_TIER: int = 1
const LOCATION_COUNT: int = 9

#README G1: the campaign name field takes 64 characters at most.
const NAME_MAX: int = 64
const OVER_NAME: int = 84
const IDENTITY_GROUP: String = "Identity"
const VALUE_GROUP: String = "Value"
const LOCKED_TRAITS: Array[String] = ["ancestry", "bloodline", "age"]
#Everything the builder needs except the trait viewers, so the locked traits stay locked.
const BUILD_ENT: Dictionary = {"promotions": true, "oddJobs": 2, "adDirect": true,
	"adRadio": true, "adSponsor": true, "maxPromoDays": 30, "jobPostings": true,
	"guildPromo": true}

#README E2: with Odd Jobs at tier 0 the Send Mercs box shows one locked 150 x 40 "Add Merc".
const ADD_MERC_TEXT: String = "Add Merc"
const ADD_MERC_SIZE: Vector2 = Vector2(150.0, 40.0)
#SendMercsPanel.gd sets the lock's upgrade_id to oddjobs; Take Me There sends it as the target.
const ODD_JOBS_UPGRADE: String = "oddjobs"
#README 306: envoy slots = entitlements.oddJobs; the two tiers H8 proves the cap against.
const ODD_JOBS_MID_TIER: int = 2
const ODD_JOBS_TOP_TIER: int = 3

#README 432: the Hiring applicant count line.
const COUNT_FMT_TEXT: String = "%d of %d applicants shown"
#Hiring.dc.html 263; README 435: the message an applicant card shows with no free merc slots.
const BLOCK_SLOTS_TEXT: String = "No free merc slots."
#README 310: greyed applicant fields read grayscale at opacity 0.4.
const GREY_ALPHA: float = 0.4
#README 362: the six engine icon names a horizontal scroll bar's pixel arrow buttons carry.
const ARROW_KEY_NAMES: Array[StringName] = [&"decrement", &"decrement_highlight",
	&"decrement_pressed", &"increment", &"increment_highlight", &"increment_pressed"]
#README 362: the permits row overflows past three cards of this width before it scrolls.
const CARD_WIDTH_PX: float = 330.0

#README E4: the three category boxes of the left column and the two bottom branches.
const LEFT_COLUMN: Array[String] = ["limits", "promoCat", "bazaarCat"]
const BOTTOM_LEFT: Array[String] = ["legalCat", "lessLegal"]
const BOTTOM_RIGHT: String = "insights"
const APTITUDE_DY: float = 18.0
const SLACK: float = 0.5
#The tiers the fade check runs on: one source of a gate ahead of the other.
const FADE_TIERS: Dictionary = {"aptitude": 1}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var roster: Array[MercenaryData] = GameState.mercs.duplicate()
	var board: Array[ContractView] = GameState.contracts.duplicate()
	var bank: int = GameState.bank_notes
	await host.get_tree().process_frame
	await _case_h01_hud_grid(res, host)
	await _case_h02_hud_dots(res, host)
	await _case_h03_permits(res, host)
	await _case_h04_fines(res, host)
	await _case_h05_bailout(res, host)
	await _case_h06_builder(res, host)
	await _case_h07_hiring(res, host)
	await _case_h08_loan(res, host)
	await _case_h09_customize(res, host)
	GuiFrameStack.clear()
	GameState.mercs = roster
	GameState.contracts = board
	GameState.bank_notes = bank
	CampaignClock.minutes = clock
	SubscriptionManager.reset()
	LegalManager.reset()
	PromotionsManager.reset()
	FinanceManager.reset()
	NotificationCenter.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI CLICK H")


#A fresh campaign with the seeded managers, a full plan and a bank that can pay for anything.
static func _fresh(ent: Dictionary = {}) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	if not ent.is_empty():
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
		SubscriptionManager.set_entitlements(ent)
	NotificationCenter.reset()
	LegalManager.reset()
	PromotionsManager.reset()
	FinanceManager.reset()
	GameState.bank_notes = RICH


static func _frames(host: Node, count: int = 2) -> void:
	for _i: int in count:
		await host.get_tree().process_frame


static func _spawn_hud(host: Node) -> GameHUD:
	var scene: PackedScene = load(HUD_SCENE) as PackedScene
	var hud: GameHUD = scene.instantiate() as GameHUD
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	return hud


static func _drop(host: Node, node: Node) -> void:
	if node != null:
		node.queue_free()
	await _frames(host, 2)


static func _lines(hud: GameHUD) -> Array[String]:
	var dialog: FeatureLockDialog = hud.lock_dialog()
	if dialog == null:
		return ["", ""]
	return [dialog.line1_label.text, dialog.line2_label.text]


#Presses Take Me There on an already-open lock dialog and returns the target it sends.
static func _take_me_there(dialog: FeatureLockDialog) -> Dictionary:
	if dialog == null:
		return {}
	var seen: Array[Dictionary] = []
	var catcher := func(target: Dictionary) -> void: seen.append(target)
	GameState.go_to_plans_requested.connect(catcher)
	dialog.press_take_me_there()
	GameState.go_to_plans_requested.disconnect(catcher)
	return {} if seen.is_empty() else seen[0]


#Every dot source reports nothing unseen, so a dot that stays lit comes from the HUD itself.
static func _quiet(hud: GameHUD) -> void:
	FinanceManager.mark_offers_seen()
	PromotionsManager.mark_seen()
	LegalManager.mark_fines_seen()
	LegalManager.mark_captures_seen()
	for id: int in GameState.unclaimed_ids():
		GameState.mark_seen(id)
	hud.refresh_dots()


static func _dots_on(hud: GameHUD) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in 9:
		if hud.button(i).dot_node.on:
			out.append(GRID_KEYS[i])
	return out


static func _only_dot(hud: GameHUD, key: StringName) -> bool:
	var on: Array[StringName] = _dots_on(hud)
	return on.size() == 1 and on.has(key)


#A merc the managers are not already holding, per the wave 4 amendment on busy uids.
static func _free_uid() -> int:
	var busy: Array[int] = GameState.busy_uids()
	for view: MercView in GameState.roster:
		if busy.has(view.uid):
			continue
		if view.status == GuiTypes.MercStatus.AVAILABLE:
			return view.uid
	return -1


#The first free mercs of the roster, at most count of them, never a merc a manager holds.
static func _free_uids(count: int) -> Array[int]:
	var out: Array[int] = []
	var busy: Array[int] = GameState.busy_uids()
	for view: MercView in GameState.roster:
		if out.size() >= count:
			break
		if busy.has(view.uid):
			continue
		if view.status == GuiTypes.MercStatus.AVAILABLE:
			out.append(view.uid)
	return out


static func _scrolls_in(node: Node) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	if node == null:
		return out
	for child: Node in node.get_children():
		if child is ScrollContainer:
			out.append(child as ScrollContainer)
		out.append_array(_scrolls_in(child))
	return out


#The first ScrollContainer above a node, stopping at the node the case owns.
static func _scroll_above(node: Node, stop: Node) -> ScrollContainer:
	var walk: Node = null if node == null else node.get_parent()
	while walk != null and walk != stop:
		if walk is ScrollContainer:
			return walk as ScrollContainer
		walk = walk.get_parent()
	return null


static func _lock_in(node: Node, want: String) -> FeatureLock:
	if node == null:
		return null
	for found: Node in node.find_children("*", "FeatureLock", true, false):
		var lock: FeatureLock = found as FeatureLock
		if lock != null and lock.label == want:
			return lock
	return null


static func _lock_dialog_of(lock: FeatureLock) -> FeatureLockDialog:
	if lock == null:
		return null
	for found: Node in lock.find_children("*", "FeatureLockDialog", true, false):
		return found as FeatureLockDialog
	return null


#Every character of text that is not one of the ten digits, dropped.
static func _digits_of(text: String) -> String:
	var out: String = ""
	for c: String in text:
		if c.is_valid_int():
			out += c
	return out


#README 310: an applicant field greys to alpha 0.4, red == green == blue.
static func _is_greyed(c: Color) -> bool:
	return absf(c.a - GREY_ALPHA) <= 0.01 and is_equal_approx(c.r, c.g) and is_equal_approx(c.g, c.b)


#A wheel event through the viewport, never a direct write of scroll_horizontal.
static func _wheel(pos: Vector2, up: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = pos
	return event


#H1 "HUD: 3x3 order matches E1; hover each button - tooltip always on top. My Promotions greyed +
#lock until the Promotions upgrade (plan copy on Free/Pro, upgrade copy on Enterprise); click ->
#lock dialog. Unlocked: opens Promotions."
static func _case_h01_hud_grid(res: Dictionary, host: Node) -> void:
	_fresh()
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var order: Array[String] = []
	var tips: int = 0
	for i: int in 9:
		order.append(hud.label_of(GRID_KEYS[i]))
		if hud.button(i).tooltip_text != "":
			tips += 1
	TestFixtures.check(res, "H1 the 3 x 3 order is the order of README E1", order == GRID_LABELS,
		", ".join(order))
	TestFixtures.check(res, "H1 every tile carries a tooltip", tips == 9, str(tips))
	var promo: GridMenuButton = hud.button_of(PROMO_KEY)
	promo.hover(true)
	var lifted: int = promo.z_index
	promo.hover(false)
	TestFixtures.check(res, "H1 hover lifts the tile onto the tooltip layer",
		lifted == HOVER_Z_INDEX, str(lifted))
	TestFixtures.check(res, "H1 the grid draws below the tooltip layer",
		hud.menu_grid.z_index == GRID_Z_INDEX, str(hud.menu_grid.z_index))
	TestFixtures.check(res, "H1 the tile drops back when the hover ends", promo.z_index == 0,
		str(promo.z_index))
	TestFixtures.check(res, "H1 My Promotions is locked on Pro", hud.is_locked(PROMO_KEY), "")
	TestFixtures.check(res, "H1 the locked tile is greyed",
		promo.icon_rect.modulate.is_equal_approx(GridMenuButton.GRAY_TINT),
		str(promo.icon_rect.modulate))
	TestFixtures.check(res, "H1 the Pro tooltip names the plan", promo.tooltip_text == PLAN_TIP,
		promo.tooltip_text)
	hud.open_viewer(PROMO_KEY)
	await _frames(host, 2)
	var plan_copy: Array[String] = _lines(hud)
	TestFixtures.check(res, "H1 the plan copy first line", plan_copy[0] == PLAN_LINE1, plan_copy[0])
	TestFixtures.check(res, "H1 the plan copy second line", plan_copy[1] == PLAN_LINE2,
		plan_copy[1])
	hud.popup().close()
	await _frames(host, 1)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	hud.refresh_locks()
	await _frames(host, 1)
	TestFixtures.check(res, "H1 the Enterprise tooltip names the upgrade instead of the plan",
		promo.tooltip_text != PLAN_TIP and promo.tooltip_text.contains("upgrade"),
		promo.tooltip_text)
	hud.open_viewer(PROMO_KEY)
	await _frames(host, 2)
	var up_copy: Array[String] = _lines(hud)
	TestFixtures.check(res, "H1 the upgrade copy first line", up_copy[0] == UPGRADE_LINE1,
		up_copy[0])
	TestFixtures.check(res, "H1 the upgrade copy second line", up_copy[1] == UPGRADE_LINE2,
		up_copy[1])
	hud.popup().close()
	await _frames(host, 1)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"promotions": 1})
	hud.refresh_locks()
	await _frames(host, 1)
	TestFixtures.check(res, "H1 the unlocked tile shows its own description",
		promo.tooltip_text == PROMO_TIP, promo.tooltip_text)
	var view: Node = hud.open_viewer(PROMO_KEY)
	await _frames(host, 2)
	TestFixtures.check(res, "H1 the unlocked tile opens the Promotions viewer",
		view is PromotionsViewer, str(view))
	hud.popup().close()
	await _drop(host, hud)


#H2 "HUD dots: My Legal (unread fine/capture), My Finance (loan offer or unseen applicant)."
static func _case_h02_hud_dots(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	TestFixtures.check(res, "H2 the seeded unread legal rows light My Legal",
		_dots_on(hud).has(&"legal"), str(_dots_on(hud)))
	_quiet(hud)
	await _frames(host, 1)
	TestFixtures.check(res, "H2 every dot clears once each source is seen",
		_dots_on(hud).is_empty(), str(_dots_on(hud)))
	var none: Array[int] = []
	LegalManager.add_fine(NEAR_LOC, "Trespass", none, -1, 50, 10)
	hud.refresh_dots()
	TestFixtures.check(res, "H2 an unread fine lights My Legal alone", _only_dot(hud, &"legal"),
		str(_dots_on(hud)))
	LegalManager.mark_fines_seen()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 reading the fine clears My Legal", _dots_on(hud).is_empty(),
		str(_dots_on(hud)))
	LegalManager.add_capture(_free_uid(), NEAR_LOC, "Brawling", -1, 10, 120)
	hud.refresh_dots()
	TestFixtures.check(res, "H2 an unread capture lights My Legal alone",
		_only_dot(hud, &"legal"), str(_dots_on(hud)))
	LegalManager.mark_captures_seen()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 reading the capture clears My Legal", _dots_on(hud).is_empty(),
		str(_dots_on(hud)))
	FinanceManager.reset()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 a loan offer lights My Finance alone",
		_only_dot(hud, &"finance"), str(_dots_on(hud)))
	FinanceManager.mark_offers_seen()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 seeing the offer clears My Finance", _dots_on(hud).is_empty(),
		str(_dots_on(hud)))
	PromotionsManager.reset()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 an unseen applicant lights My Finance alone",
		_only_dot(hud, &"finance"), str(_dots_on(hud)))
	PromotionsManager.mark_seen()
	hud.refresh_dots()
	TestFixtures.check(res, "H2 seeing the applicants clears My Finance",
		_dots_on(hud).is_empty(), str(_dots_on(hud)))
	await _drop(host, hud)


#H3 "Legal > Permits: cards scroll horizontally (wheel + pixel arrow buttons). Request -> dialog
#-> Request -> confirm -> permit becomes Active; notes deducted. Low tier -> locked label button
#opens lock dialog."
static func _case_h03_permits(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var legal: LegalViewer = hud.open_viewer(&"legal") as LegalViewer
	await _frames(host, 2)
	legal.press_tab(&"permits")
	await _frames(host, 2)
	var page: PermitsPage = legal.permits_page()
	var scroll: ScrollContainer = page.scroll_node()
	TestFixtures.check(res, "H3 the card row scrolls sideways and never down",
		scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		str(scroll.horizontal_scroll_mode) + "/" + str(scroll.vertical_scroll_mode))
	var arrows: int = 0
	for key: StringName in ARROW_KEY_NAMES:
		if scroll.get_h_scroll_bar().has_theme_icon_override(key):
			arrows += 1
	TestFixtures.check(res, "H3 the row carries its pixel arrow buttons",
		arrows == ARROW_KEY_NAMES.size(), str(arrows))
	TestFixtures.check(res, "H3 one card per location", page.card_count() == LOCATION_COUNT,
		str(page.card_count()))
	TestFixtures.check(res, "H3 the row is wider than three cards of its frame",
		page.strip.size.x > 3.0 * CARD_WIDTH_PX, str(page.strip.size.x))
	#get_global_rect() gives the position in the viewport's own canvas coordinates (the same
	#space Control.global_position uses), not the containing window's pixel coordinates. Since
	#push_input's default in_local_coords=false expects a window-pixel position and re-applies
	#the viewport's transform, a canvas-space position must be pushed with in_local_coords=true.
	var wheel_pos: Vector2 = scroll.get_global_rect().get_center()
	host.get_viewport().push_input(_wheel(wheel_pos, false), true)
	await _frames(host, 2)
	TestFixtures.check(res, "H3 a wheel down event scrolls the row horizontally",
		scroll.scroll_horizontal > 0 and scroll.scroll_vertical == 0,
		str(scroll.scroll_horizontal) + "/" + str(scroll.scroll_vertical))
	var after_down: int = scroll.scroll_horizontal
	host.get_viewport().push_input(_wheel(wheel_pos, true), true)
	await _frames(host, 2)
	TestFixtures.check(res, "H3 a wheel up event scrolls the row back",
		scroll.scroll_horizontal < after_down and scroll.scroll_vertical == 0,
		str(scroll.scroll_horizontal) + "/" + str(scroll.scroll_vertical))
	var before: int = GameState.bank_notes
	var cost: int = LegalManager.permit_cost(NEAR_LOC, &"ops")
	page.press_request(NEAR_LOC)
	await _frames(host, 2)
	TestFixtures.check(res, "H3 Request opens the permit dialog", legal.request_dialog().visible,
		"")
	legal.request_dialog().press_permit(&"ops")
	await _frames(host, 2)
	TestFixtures.check(res, "H3 the dialog Request asks for a confirm", legal.confirm().visible,
		"")
	legal.confirm().press(legal.confirm().button_count() - 1)
	await _frames(host, 2)
	TestFixtures.check(res, "H3 the permit is held after the confirm",
		LegalManager.has_permit(NEAR_LOC, &"ops"), "")
	TestFixtures.check(res, "H3 the notes are deducted",
		GameState.bank_notes == before - cost, str(before - GameState.bank_notes))
	legal.press_tab(&"permits")
	await _frames(host, 2)
	legal.permits_page().press_request(NEAR_LOC)
	await _frames(host, 2)
	var row: PermitRow = legal.request_dialog().permit_row(&"ops")
	TestFixtures.check(res, "H3 the permit now reads Active", row.owned_text() == "Active",
		row.owned_text())
	legal.request_dialog().press_close()
	hud.popup().close()
	await _frames(host, 2)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"opspermit": SHORT_TIER})
	legal = hud.open_viewer(&"legal") as LegalViewer
	await _frames(host, 2)
	legal.press_tab(&"permits")
	await _frames(host, 2)
	var card: LocationCard = legal.permits_page().card_for(SHORT_LOC)
	var marks: int = 0
	for i: int in card.permission_count():
		if card.permission_locked(i):
			marks += 1
	TestFixtures.check(res, "H3 a location beyond the tier shows a locked mark", marks > 0,
		str(marks))
	card.press_request()
	await _frames(host, 2)
	var short_row: PermitRow = legal.request_dialog().permit_row(&"ops")
	TestFixtures.check(res, "H3 the short row shows the locked label button",
		short_row.lock_visible(), "")
	var lock: FeatureLock = short_row.lock_node()
	lock.open_dialog()
	await _frames(host, 2)
	var dialog: FeatureLockDialog = _lock_dialog_of(lock)
	TestFixtures.check(res, "H3 the locked label button opens the lock dialog",
		dialog != null and dialog.visible, str(dialog))
	if dialog != null:
		dialog.press_close()
	legal.request_dialog().press_close()
	hud.popup().close()
	await _drop(host, hud)


#H4 "Legal > Fines: each unread row has a dot; Review marks read. Review shows merc modules
#(hover card), contract module + link, relationship (or lock), late fees. Pay Fine -> rich confirm
#-> paid (moves to Paid). Renegotiate -> OddJobCrew; Odd Jobs 0 -> locked."
static func _case_h04_fines(res: Dictionary, host: Node) -> void:
	_fresh()
	SubscriptionManager.set_tier("whoknows", 0)
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var legal: LegalViewer = hud.open_viewer(&"legal") as LegalViewer
	await _frames(host, 2)
	legal.press_tab(&"fines")
	await _frames(host, 2)
	var page: FinesPage = legal.fines_page()
	TestFixtures.check(res, "H4 an unread fine row carries a dot",
		page.row_for(FINE_UNREAD).dot.on, "")
	TestFixtures.check(res, "H4 a read fine row carries none",
		not page.row_for(FINE_READ).dot.on, "")
	page.press_review(FINE_UNREAD)
	await _frames(host, 2)
	var review: ReviewDialog = legal.review_dialog()
	TestFixtures.check(res, "H4 Review opens the review dialog", review.visible, "")
	TestFixtures.check(res, "H4 Review marks the row read",
		not page.row_for(FINE_UNREAD).dot.on, "")
	TestFixtures.check(res, "H4 the review lists the mercs on record",
		review.crew_module().member_count() > 0, str(review.crew_module().member_count()))
	TestFixtures.check(res, "H4 the review names the contract",
		review.contract_entry_id() == CONTRACT_ENTRY, str(review.contract_entry_id()))
	TestFixtures.check(res, "H4 the contract link opens the contract",
		review.press_view_contract() != null, "")
	await _frames(host, 2)
	TestFixtures.check(res, "H4 the relationship is readable on a full plan",
		not review.opinion_locked(), "")
	TestFixtures.check(res, "H4 the money rows are base, late fees and total",
		review.money_row_count() == 3, str(review.money_row_count()))
	TestFixtures.check(res, "H4 the middle money row is the late fee",
		review.money_label(1).begins_with("Late Fees"), review.money_label(1))
	TestFixtures.check(res, "H4 Renegotiate is open at the top Odd Jobs tier",
		not review.odd_locked(), "")
	review.press_odd_job()
	await _frames(host, 2)
	TestFixtures.check(res, "H4 Renegotiate opens the Odd Job crew",
		legal.odd_job_window().visible, "")
	legal.odd_job_window().hide()
	await _frames(host, 2)
	var owed: int = review.total_due()
	var purse: int = GameState.bank_notes
	review.press_pay()
	await _frames(host, 2)
	TestFixtures.check(res, "H4 Pay Fine asks for a rich confirm", legal.confirm().visible, "")
	var labels: Array[String] = legal.confirm().button_labels()
	TestFixtures.check(res, "H4 the confirm button names the sum",
		labels[labels.size() - 1].begins_with("Pay ")
		and _digits_of(labels[labels.size() - 1]) == str(owed),
		labels[labels.size() - 1])
	legal.confirm().press(legal.confirm().button_count() - 1)
	await _frames(host, 2)
	TestFixtures.check(res, "H4 the fine is paid out of the bank",
		GameState.bank_notes == purse - owed, str(purse - GameState.bank_notes))
	legal.press_tab(&"fines")
	await _frames(host, 2)
	legal.fines_page().pick_filter(FinesPage.FILTER_PAID)
	await _frames(host, 2)
	var paid_row: FineRow = legal.fines_page().row_for(FINE_UNREAD)
	TestFixtures.check(res, "H4 the paid fine moves under Paid",
		paid_row != null and paid_row.is_paid(), str(paid_row))
	var seeded_paid: FineRow = legal.fines_page().row_for(FINE_PAID)
	TestFixtures.check(res, "H4 a seeded paid fine sits in the Paid list",
		seeded_paid != null and seeded_paid.is_paid(), str(seeded_paid))
	hud.popup().close()
	await _frames(host, 2)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	legal = hud.open_viewer(&"legal") as LegalViewer
	await _frames(host, 2)
	legal.press_tab(&"fines")
	await _frames(host, 2)
	legal.fines_page().press_review(FINE_READ)
	await _frames(host, 2)
	TestFixtures.check(res, "H4 Renegotiate is locked at Odd Jobs tier 0",
		legal.review_dialog().odd_locked(), "")
	hud.popup().close()
	await _drop(host, hud)


#H5 "Legal > Bailout: Time Served / Time Remaining; Pay Bail confirm -> merc released; Break Out
#= Odd Job."
static func _case_h05_bailout(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var legal: LegalViewer = hud.open_viewer(&"legal") as LegalViewer
	await _frames(host, 2)
	legal.press_tab(&"bail")
	await _frames(host, 2)
	var page: BailoutPage = legal.bailout_page()
	TestFixtures.check(res, "H5 an unread capture row carries a dot",
		page.row_for(CAPTURE_UNREAD).dot.on, "")
	TestFixtures.check(res, "H5 a read capture row carries none",
		not page.row_for(CAPTURE_READ).dot.on, "")
	var served_head: Label = page.column_head.get_child(2) as Label
	var left_head: Label = page.column_head.get_child(3) as Label
	TestFixtures.check(res, "H5 the page names the Time Served column",
		served_head != null and served_head.text == HEAD_SERVED_TEXT,
		"" if served_head == null else served_head.text)
	TestFixtures.check(res, "H5 the page names the Time Remaining column",
		left_head != null and left_head.text == HEAD_LEFT_TEXT,
		"" if left_head == null else left_head.text)
	var row: CapturedRow = page.row_for(CAPTURE_UNREAD)
	TestFixtures.check(res, "H5 the held merc shows the days served",
		row.served_days() >= 0 and row.served_text() != "", row.served_text())
	TestFixtures.check(res, "H5 the held merc shows the days remaining",
		row.remaining_days() > 0 and row.remaining_text() != "", row.remaining_text())
	page.press_review(CAPTURE_UNREAD)
	await _frames(host, 2)
	var review: ReviewDialog = legal.review_dialog()
	TestFixtures.check(res, "H5 the review offers Break Out as an Odd Job",
		review.odd_button.text == ReviewDialog.BREAKOUT_TEXT, review.odd_button.text)
	TestFixtures.check(res, "H5 the review names the held merc",
		review.crew_module().member_count() > 0
		and review.crew_module().member_uid(0) == CAPTURE_UID,
		str(review.crew_module().member_count()))
	review.press_odd_job()
	await _frames(host, 2)
	TestFixtures.check(res, "H5 Break Out opens the Odd Job crew",
		legal.odd_job_window().visible, "")
	legal.odd_job_window().hide()
	await _frames(host, 2)
	TestFixtures.check(res, "H5 the pay button reads Pay Bail",
		review.pay_button.text == ReviewDialog.PAY_BAIL_TEXT, review.pay_button.text)
	var bail: int = review.total_due()
	var purse: int = GameState.bank_notes
	review.press_pay()
	await _frames(host, 2)
	TestFixtures.check(res, "H5 Pay Bail asks for a confirm", legal.confirm().visible, "")
	legal.confirm().press(legal.confirm().button_count() - 1)
	await _frames(host, 2)
	TestFixtures.check(res, "H5 the bail is paid out of the bank",
		GameState.bank_notes == purse - bail, str(purse - GameState.bank_notes))
	legal.press_tab(&"bail")
	await _frames(host, 2)
	TestFixtures.check(res, "H5 the released merc leaves the custody list",
		legal.bailout_page().row_for(CAPTURE_UNREAD) == null, "")
	hud.popup().close()
	await _drop(host, hud)


#H6 "Promotions builder: name field opens keyboard (64 max); groups collapse/expand with counts;
#locked traits show lock buttons; Direct Sale disabled on Job Ads; guild difficulty half-stars
#with contract colors; Contract Type / Locations boxes scroll independently, no page scroll;
#no-permit locations greyed. Launch deducts cost."
static func _case_h06_builder(res: Dictionary, host: Node) -> void:
	_fresh(BUILD_ENT)
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var promo: PromotionsViewer = hud.open_viewer(PROMO_KEY) as PromotionsViewer
	await _frames(host, 2)
	promo.open_tab(PromotionsViewer.JOB_KEY)
	await _frames(host, 2)
	promo.press_new()
	await _frames(host, 2)
	var builder: CampaignBuilder = promo.builder()
	TestFixtures.check(res, "H6 New opens the builder on Job Ads",
		builder.is_open() and builder.mode() == CampaignData.MODE_JOB, builder.mode())
	builder.press_name()
	await _frames(host, 2)
	TestFixtures.check(res, "H6 the name field opens the on screen keyboard", builder.naming(), "")
	builder.name_dialog.press_cancel()
	await _frames(host, 2)
	builder.set_campaign_name("A".repeat(OVER_NAME))
	await _frames(host, 2)
	TestFixtures.check(res, "H6 the campaign name stops at 64 characters",
		builder.campaign_name().length() == NAME_MAX, str(builder.campaign_name().length()))
	TestFixtures.check(res, "H6 the counter reads the cap",
		builder.count_text() == "%d / %d" % [NAME_MAX, NAME_MAX], builder.count_text())
	var panel: TraitFilterPanel = builder.job_panel()
	var group: FilterGroup = panel.group_for(IDENTITY_GROUP)
	var opened: bool = group.is_open()
	group.toggle()
	await _frames(host, 1)
	TestFixtures.check(res, "H6 a filter group collapses and expands",
		group.is_open() != opened, str(group.is_open()))
	group.toggle()
	await _frames(host, 1)
	TestFixtures.check(res, "H6 the group returns to where it started",
		group.is_open() == opened, str(group.is_open()))
	TestFixtures.check(res, "H6 an untouched group shows no count", group.count() == 0,
		str(group.count()))
	var picks: Array = [TraitFilterDefs.traditions()[0]]
	panel.section_for("tradition").press_value(picks)
	await _frames(host, 2)
	TestFixtures.check(res, "H6 the group counts the filter that narrows",
		group.count() == 1 and panel.active_in(IDENTITY_GROUP) == 1,
		str(group.count()) + "/" + str(panel.active_in(IDENTITY_GROUP)))
	var value_group: FilterGroup = panel.group_for(VALUE_GROUP)
	panel.section_for("salary").press_value([0.0, TraitFilterDefs.SALARY_MAX * 0.5])
	await _frames(host, 2)
	TestFixtures.check(res, "H6 a second group counts its own filter independently",
		value_group.count() == 1 and panel.active_in(VALUE_GROUP) == 1 and group.count() == 1,
		str(value_group.count()) + "/" + str(group.count()))
	var locks: int = 0
	for key: String in LOCKED_TRAITS:
		var section: FilterSection = panel.section_for(key)
		if section != null and section.is_locked() and section.section_lock() != null:
			locks += 1
	TestFixtures.check(res, "H6 every locked trait shows a lock button",
		locks == LOCKED_TRAITS.size(), str(locks))
	var direct: TypeRow = builder.type_row(&"direct")
	TestFixtures.check(res, "H6 Direct Sale is disabled on Job Ads",
		direct.is_blocked() and not direct.is_pickable(), "")
	TestFixtures.check(res, "H6 Direct Sale says why it is disabled",
		direct.tooltip_text == TypeRow.BLOCKED_TIP, direct.tooltip_text)
	var was: StringName = builder.type_key()
	builder.pick_type(&"direct")
	TestFixtures.check(res, "H6 pressing Direct Sale on Job Ads changes nothing",
		builder.type_key() == was, String(builder.type_key()))
	builder.pick_type(&"flyers")
	builder.set_campaign_name("Bill Run")
	await _frames(host, 2)
	var cost: int = builder.cost()
	var purse: int = GameState.bank_notes
	TestFixtures.check(res, "H6 the campaign is ready to launch", builder.launch_enabled(),
		builder.reason_text())
	builder.press_launch()
	await _frames(host, 2)
	TestFixtures.check(res, "H6 Launch deducts the cost",
		GameState.bank_notes == purse - cost, str(purse - GameState.bank_notes))
	promo.open_tab(PromotionsViewer.PROMO_KEY)
	await _frames(host, 2)
	SubscriptionManager.set_entitlements({"gpMinDifficulty": 1, "gpMaxDifficulty": 1,
		"gpContractType": 1})
	promo.press_new()
	await _frames(host, 2)
	var guild: GuildTargeting = builder.guild_panel()
	var stars: StarRangePicker = guild.section_for(GuildTargeting.DIFF_KEY).star_picker()
	stars.press_star(StarRangePicker.ROW_MIN, 2.5)
	await _frames(host, 1)
	TestFixtures.check(res, "H6 the difficulty picker takes half stars",
		is_equal_approx(stars.row_value(StarRangePicker.ROW_MIN), 2.5),
		str(stars.row_value(StarRangePicker.ROW_MIN)))
	TestFixtures.check(res, "H6 the half star carries the contract colour",
		stars.row_color(StarRangePicker.ROW_MIN).is_equal_approx(GuiTypes.difficulty_color(2.5)),
		str(stars.row_color(StarRangePicker.ROW_MIN)))
	var type_box: Array[ScrollContainer] = _scrolls_in(guild.section_for(GuildTargeting.TYPE_KEY))
	var loc_box: Array[ScrollContainer] = _scrolls_in(guild.section_for(GuildTargeting.LOC_KEY))
	TestFixtures.check(res, "H6 Contract Type and Locations each own one scroll box",
		type_box.size() == 1 and loc_box.size() == 1 and type_box[0] != loc_box[0],
		str(type_box.size()) + "/" + str(loc_box.size()))
	TestFixtures.check(res, "H6 the page behind the two boxes never scrolls",
		_scroll_above(guild, builder) == null, "")
	TestFixtures.check(res, "H6 a location with an Operations Permit is pickable",
		not guild.tile_for(GuildTargeting.LOC_KEY, HOME_LOC).is_blocked(), "")
	var tile: ModuleTile = guild.tile_for(GuildTargeting.LOC_KEY, NEAR_LOC)
	TestFixtures.check(res, "H6 a location with no permit is greyed and unpickable",
		tile.is_blocked() and tile.modulate.a < 1.0, str(tile.modulate.a))
	builder.press_close()
	hud.popup().close()
	await _drop(host, hud)


#H7 "Finance > Hiring: tab dot while unseen applicants; filters (incl. Walk-In) and sort dropdown
#work; View opens applicant Merc Viewer with Coaching/Salary/Metrics greyed; Offer at asking ->
#confirm -> hired (+1 opinion, slot used); below asking -> counter-offer with odds + crew; no free
#slot -> Offer disabled."
static func _case_h07_hiring(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var finance: FinanceViewer = hud.open_viewer(&"finance") as FinanceViewer
	await _frames(host, 2)
	TestFixtures.check(res, "H7 the Hiring tab shows a dot while an applicant is unseen",
		finance.has_dot(FinanceViewer.HIRING_KEY), "")
	finance.press_tab(FinanceViewer.HIRING_KEY)
	await _frames(host, 2)
	var page: HiringTab = finance.page(FinanceViewer.HIRING_KEY) as HiringTab
	var total: int = page.total_count()
	TestFixtures.check(res, "H7 the unfiltered list holds every applicant",
		total > 0 and page.shown_count() == total, str(page.shown_count()) + "/" + str(total))
	TestFixtures.check(res, "H7 the count line reads shown of total",
		page.count_text() == COUNT_FMT_TEXT % [total, total], page.count_text())
	var walk_ids: Array[int] = []
	for a: ApplicantData in PromotionsManager.applicants:
		if a.campaign_id == ApplicantData.WALK_IN:
			walk_ids.append(a.id)
	page.filter_panel().press_value("from", [ApplicantData.WALK_IN])
	await _frames(host, 2)
	TestFixtures.check(res, "H7 the Walk-In filter leaves the walk-in applicants",
		_same_ids(page.card_ids(), walk_ids),
		str(page.card_ids().size()) + "/" + str(walk_ids.size()))
	page.press_clear()
	await _frames(host, 2)
	TestFixtures.check(res, "H7 Clear brings the whole list back",
		page.shown_count() == total, str(page.shown_count()))
	page.set_sort(&"salary")
	page.set_descending(false)
	await _frames(host, 2)
	var rising: bool = _asks_ordered(page.card_ids(), true)
	TestFixtures.check(res, "H7 the sort dropdown follows the salary sort",
		page.sort_dropdown().selected == &"salary", String(page.sort_dropdown().selected))
	page.set_descending(true)
	await _frames(host, 2)
	var falling: bool = _asks_ordered(page.card_ids(), false)
	TestFixtures.check(res, "H7 the salary sort orders the list both ways", rising and falling,
		str(rising) + "/" + str(falling))
	page.set_sort(&"fit")
	page.set_descending(true)
	await _frames(host, 2)
	var first: int = page.card_ids()[0]
	page.press_view(first)
	await _frames(host, 2)
	var popup: ViewerPopup = page.applicant_popup()
	TestFixtures.check(res, "H7 View opens the applicant popup",
		popup != null and popup.is_open(), "")
	var merc: MercViewer = popup.current() as MercViewer
	TestFixtures.check(res, "H7 the popup is the Merc Viewer in applicant mode",
		merc != null and merc.applicant_mode(), str(merc))
	TestFixtures.check(res, "H7 Coaching is greyed for an applicant",
		merc.overview().coaching_box().greyed, "")
	TestFixtures.check(res, "H7 Salary is greyed for an applicant",
		_is_greyed(merc.header.salary_chip().modulate),
		str(merc.header.salary_chip().modulate))
	TestFixtures.check(res, "H7 Metrics is greyed for an applicant",
		_is_greyed(merc.tabs()[MercViewer.TAB_METRICS].modulate),
		str(merc.tabs()[MercViewer.TAB_METRICS].modulate))
	popup.close()
	await _frames(host, 2)
	var ask: int = PromotionsManager.applicant_of(first).ask
	page.press_offer(first)
	await _frames(host, 2)
	var offer: HireOfferDialog = page.offer_dialog()
	TestFixtures.check(res, "H7 the offer opens at the asking salary",
		offer.is_open() and offer.amount() == ask and not offer.is_counter(), str(offer.amount()))
	offer.set_amount(maxi(1, roundi(float(ask) * 0.6)))
	await _frames(host, 2)
	TestFixtures.check(res, "H7 below asking the offer becomes a counter offer",
		offer.is_counter() and offer.action_text() == HireOfferDialog.ACTION_COUNTER,
		offer.action_text())
	TestFixtures.check(res, "H7 the counter offer shows its odds",
		offer.odds() == PromotionsManager.counter_odds(first, offer.amount(), offer.team()),
		str(offer.odds()))
	TestFixtures.check(res, "H7 the counter offer carries its crew",
		offer.crew() != null and not offer.crew_locked(), "")
	offer.set_amount(ask)
	await _frames(host, 2)
	var deltas: Array[int] = []
	var catcher: Callable = func(_a: ApplicantData, _s: int, d: int) -> void:
		deltas.append(d)
	PromotionsManager.applicant_hired.connect(catcher)
	var slots: int = PromotionsManager.free_slots()
	var roster: int = GameState.mercs.size()
	offer.press_action()
	await _frames(host, 2)
	TestFixtures.check(res, "H7 an offer at the asking salary asks for a confirm",
		page.confirm_dialog().visible, "")
	page.confirm_dialog().press(page.confirm_dialog().button_count() - 1)
	await _frames(host, 2)
	PromotionsManager.applicant_hired.disconnect(catcher)
	TestFixtures.check(res, "H7 the confirm hires the applicant",
		GameState.mercs.size() == roster + 1, str(GameState.mercs.size() - roster))
	TestFixtures.check(res, "H7 the hire lifts the guild opinion by one",
		deltas.size() == 1 and deltas[0] == 1, str(deltas))
	TestFixtures.check(res, "H7 the hire uses one merc slot",
		PromotionsManager.free_slots() == slots - 1, str(PromotionsManager.free_slots()))
	var guard: int = 0
	while PromotionsManager.free_slots() > 0 and not GameState.mercs.is_empty() and guard < 200:
		GameState.mercs.append(GameState.mercs[0])
		guard += 1
	page.refresh()
	await _frames(host, 2)
	var next_id: int = page.card_ids()[0]
	TestFixtures.check(res, "H7 with no free slot the card names the block",
		page.card_of(next_id).offer_block() == BLOCK_SLOTS_TEXT,
		page.card_of(next_id).offer_block())
	page.press_offer(next_id)
	await _frames(host, 2)
	TestFixtures.check(res, "H7 with no free slot Offer opens nothing",
		not page.offer_dialog().is_open(), "")
	hud.popup().close()
	await _drop(host, hud)


#True when both lists hold the same applicant ids, in any order.
static func _same_ids(left: Array[int], right: Array[int]) -> bool:
	for id: int in left:
		if not right.has(id):
			return false
	return left.size() == right.size()


#True when the asking salaries of these applicants rise (or fall) from the first card to the last.
static func _asks_ordered(ids: Array[int], rising: bool) -> bool:
	var last: int = -1
	for id: int in ids:
		var row: ApplicantData = PromotionsManager.applicant_of(id)
		if row == null:
			return false
		if last >= 0 and ((rising and row.ask < last) or (not rising and row.ask > last)):
			return false
		last = row.ask
	return ids.size() > 1


#H8 "Finance > Request a Loan: Odd Jobs tier caps envoy slots; 0 -> locked Add Merc."
static func _case_h08_loan(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var finance: FinanceViewer = hud.open_viewer(&"finance") as FinanceViewer
	await _frames(host, 2)
	finance.press_tab(FinanceViewer.LOANS_KEY)
	await _frames(host, 2)
	var loans: LoansTab = finance.page(FinanceViewer.LOANS_KEY) as LoansTab
	loans.press_request()
	await _frames(host, 2)
	var window: LoanRequestWindow = loans.request_window()
	TestFixtures.check(res, "H8 an open crew is not locked",
		not window.locked_crew() and not window.crew().locked, "")
	TestFixtures.check(res, "H8 an open crew hides the lock",
		not window.crew().send_panel.lock.is_visible_in_tree(), "")
	for tier: int in [ODD_JOBS_MID_TIER, ODD_JOBS_TOP_TIER]:
		SubscriptionManager.set_entitlements({"oddJobs": tier})
		loans.press_request()
		await _frames(host, 2)
		TestFixtures.check(res, "H8 Odd Jobs tier %d sets the envoy cap" % [tier],
			window.odd_job_cap() == tier, str(window.odd_job_cap()))
		TestFixtures.check(res, "H8 Odd Jobs tier %d opens that many crew slots" % [tier],
			window.crew().max_mercs == tier, str(window.crew().max_mercs))
		var envoys: Array[int] = _free_uids(tier + 1)
		TestFixtures.check(res, "H8 tier %d has more free mercs than the envoy cap" % [tier],
			envoys.size() == tier + 1, str(envoys.size()))
		for uid: int in envoys:
			window.crew().add_merc(uid)
		await _frames(host, 2)
		TestFixtures.check(res, "H8 tier %d caps the envoys taken" % [tier],
			window.crew().team.size() == tier, str(window.crew().team.size()))
		TestFixtures.check(res, "H8 tier %d shows one slot per envoy" % [tier],
			window.crew().send_panel.slot_count() == tier,
			str(window.crew().send_panel.slot_count()))
	window.press_cancel()
	await _frames(host, 2)
	SubscriptionManager.set_entitlements({"oddJobs": 0})
	loans.press_request()
	await _frames(host, 2)
	TestFixtures.check(res, "H8 Odd Jobs tier 0 locks the envoy crew",
		window.odd_job_cap() == 0 and window.locked_crew(), str(window.odd_job_cap()))
	var lock: FeatureLock = window.crew().send_panel.lock
	TestFixtures.check(res, "H8 the locked slot reads Add Merc",
		lock.visible and lock.label == ADD_MERC_TEXT, lock.label)
	TestFixtures.check(res, "H8 the locked slot is 150 by 40",
		is_equal_approx(lock.custom_minimum_size.x, ADD_MERC_SIZE.x)
		and is_equal_approx(lock.height, ADD_MERC_SIZE.y),
		str(lock.custom_minimum_size.x) + "x" + str(lock.height))
	TestFixtures.check(res, "H8 no envoy slot stands beside the lock",
		not window.crew().send_panel.slots_row.visible, "")
	var take_lock: FeatureLock = _lock_in(window.crew().send_panel, ADD_MERC_TEXT)
	if take_lock != null:
		take_lock.open_dialog()
	await _frames(host, 2)
	var take_dialog: FeatureLockDialog = _lock_dialog_of(take_lock)
	var target: Dictionary = _take_me_there(take_dialog)
	TestFixtures.check(res, "H8 Take Me There sends the Odd Jobs upgrade",
		String(target.get("upgrade", "")) == ODD_JOBS_UPGRADE, str(target))
	if take_dialog != null:
		take_dialog.press_close()
	window.press_cancel()
	hud.popup().close()
	await _drop(host, hud)


#H9 "Customize: first open shows Base + all categories; Limits (up) / Promotions / Bazaar (down)
#share one column; Legal/Less Legal/Insights hang from the two bottom branches; every merge leg
#fades only on its last segment; Aptitude has two parallel exits."
static func _case_h09_customize(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _spawn_hud(host)
	await _frames(host, 2)
	var mercday: SubscriptionViewer = hud.open_viewer(&"mercday") as SubscriptionViewer
	await _frames(host, 2)
	mercday.open_tab(SubscriptionViewer.CUSTOMIZE_TAB)
	await _frames(host, 2)
	var page: CustomizePage = mercday.customize_page()
	TestFixtures.check(res, "H9 Customize is open on an Enterprise plan", not page.is_locked(), "")
	TestFixtures.check(res, "H9 the page carries the tree", page.has_tree(), "")
	var tree: SkillTree = page.tree_node() as SkillTree
	var canvas: TreeCanvas = tree.canvas()
	var home: Vector2 = TreeLayout.clamp_pan(TreeLayout.home_pan(tree.view()), tree.view())
	TestFixtures.check(res, "H9 the first open centres Base and every category in the frame",
		tree.view() == tree.size and (tree.pan() - home).length() <= SLACK,
		str(tree.pan()) + " vs " + str(home) + " view " + str(tree.view()) + " size " + str(tree.size))
	TestFixtures.check(res, "H9 the home view holds the Base block",
		canvas.block("base") != null and canvas.block("base").visible, "")
	var frame: Rect2 = Rect2(Vector2.ZERO, tree.view())
	var lift: Vector2 = tree.pan() + Vector2(0.0, TreeLayout.OY)
	TestFixtures.check(res, "H9 the first open frames the Base block",
		frame.has_point(TreeLayout.block_center("base") + lift),
		str(TreeLayout.block_center("base") + lift))
	var boxes: int = 0
	var framed: int = 0
	for cat: String in TreeLayout.cat_ids():
		if canvas.cat_box(cat) != null and canvas.cat_box(cat).visible:
			boxes += 1
		if frame.has_point(TreeLayout.cat_center(cat) + lift):
			framed += 1
	TestFixtures.check(res, "H9 the home view holds every category box",
		boxes == TreeLayout.cat_ids().size(), str(boxes) + "/" + str(TreeLayout.cat_ids().size()))
	TestFixtures.check(res, "H9 the first open holds the centre of every category box",
		framed == TreeLayout.cat_ids().size(),
		str(framed) + "/" + str(TreeLayout.cat_ids().size()))
	var column: Array[float] = []
	for cat: String in LEFT_COLUMN:
		column.append(TreeLayout.cat_center(cat).x)
	TestFixtures.check(res, "H9 Limits, Promotions and Bazaar share one column",
		is_equal_approx(column[0], column[1]) and is_equal_approx(column[1], column[2]),
		str(column))
	TestFixtures.check(res, "H9 Limits sits above Promotions and Bazaar below it",
		TreeLayout.cat_center(LEFT_COLUMN[0]).y < TreeLayout.cat_center(LEFT_COLUMN[1]).y
		and TreeLayout.cat_center(LEFT_COLUMN[1]).y < TreeLayout.cat_center(LEFT_COLUMN[2]).y, "")
	var bottom: Array[float] = []
	for cat: String in BOTTOM_LEFT:
		bottom.append(TreeLayout.cat_center(cat).y)
	bottom.append(TreeLayout.cat_center(BOTTOM_RIGHT).y)
	TestFixtures.check(res, "H9 Legal, Less Legal and Insights stand on one bottom row",
		is_equal_approx(bottom[0], bottom[1]) and is_equal_approx(bottom[1], bottom[2]),
		str(bottom))
	TestFixtures.check(res, "H9 the bottom row hangs below the base row",
		bottom[0] > TreeLayout.cat_center("testing").y, str(bottom[0]))
	TestFixtures.check(res, "H9 the two bottom branches carry the three boxes apart",
		TreeLayout.cat_center(BOTTOM_LEFT[0]).x < TreeLayout.cat_center(BOTTOM_LEFT[1]).x
		and TreeLayout.cat_center(BOTTOM_LEFT[1]).x < TreeLayout.cat_center(BOTTOM_RIGHT).x, "")
	var lines: Array[Dictionary] = canvas.connectors()
	TestFixtures.check(res, "H9 the tree draws its connectors", not lines.is_empty(),
		str(lines.size()))
	var box: Rect2 = TreeLayout.block_rect("aptitude")
	var right: float = box.position.x + box.size.x
	var middle: float = box.position.y + box.size.y / 2.0
	var exits: Array[float] = []
	for line: Dictionary in lines:
		var pts: PackedVector2Array = line["points"]
		if absf(pts[0].x - right) > SLACK:
			continue
		if pts[0].y < box.position.y or pts[0].y > box.position.y + box.size.y:
			continue
		exits.append(pts[0].y)
	exits.sort()
	TestFixtures.check(res, "H9 Aptitude leaves by two parallel exits",
		exits.size() == 2 and absf(exits[0] - (middle - APTITUDE_DY)) <= SLACK
		and absf(exits[1] - (middle + APTITUDE_DY)) <= SLACK, str(exits))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, FADE_TIERS)
	await _frames(host, 2)
	var half: Array[Dictionary] = canvas.connectors()
	var faded: Array[Dictionary] = []
	for line: Dictionary in half:
		if not (line["color_a"] as Color).is_equal_approx(line["color_b"] as Color):
			faded.append(line)
	TestFixtures.check(res, "H9 a merge leg ends in the merged colour", not faded.is_empty(),
		str(faded.size()))
	var carried: int = 0
	for line: Dictionary in faded:
		if _merge_follows(half, line):
			carried += 1
	TestFixtures.check(res, "H9 a leg fades only where it merges",
		carried == faded.size(), str(carried) + "/" + str(faded.size()))
	hud.popup().close()
	await _drop(host, hud)


#True when the merged colour of this faded segment carries on from where the segment ends, which
#is what makes the faded segment the last one of its leg.
static func _merge_follows(lines: Array[Dictionary], leg: Dictionary) -> bool:
	var pts: PackedVector2Array = leg["points"]
	var end: Vector2 = pts[pts.size() - 1]
	var merged: Color = leg["color_b"]
	for line: Dictionary in lines:
		if line == leg:
			continue
		var other: PackedVector2Array = line["points"]
		if other[0].distance_to(end) > SLACK:
			continue
		if (line["color_a"] as Color).is_equal_approx(merged):
			return true
	return false

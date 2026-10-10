class_name GuiSubsTests
extends RefCounted

#Run: godot --headless --path . with the --gui-subs-tests flag.
#The My Mercday window and the billing rules under it: the tab row, the three plan cards, the plan
#switch dialog, the Customize page host, the spend readout and the SubscriptionManager money API.
#Every case drives the public helpers, because a synthetic click never reaches a button headless.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Subscription/SubscriptionViewer.tscn")
#Daith holds 30 days and Erta 40, so both month lengths are read by the billing cases.
const SHORT_MONTH: int = 0
const LONG_MONTH: int = 4
const RICH: int = 5000
#The Pro plan as the design prototype writes it: plans 412 to 416 and planCards 589.
const PRO_ACCENT: String = "#f2d33d"
const PRO_INDEX: int = 1
const PRO_FEATURES: Array[String] = ["Up to 8 mercenaries", "Up to 8 contracts",
	"Advanced Merc Manager", "Advanced Contract Manager", "Advanced Finance Management",
	"Guild Metrics", "See some physical attributes of your mercenaries"]
#The payroll case builds its own crew, so every merc carries a uid of its own.
const FIRST_UID: int = 9001
#The caps case builds its crews from here up, clear of the payroll case.
const CAPS_UID: int = 9101
const SEATS_TWO_FEE: int = 9
#Board sizes for the switch dialog: over the free cap, and inside it.
const FULL_BOARD: int = 9
const LIGHT_BOARD: int = 4
#The Guild Ads campaign that lays one posting on a full board.
const AD_CAMPAIGN: int = 7
#The head the dialog writes when the guild leaves Enterprise with upgrades to lose.
const LOSE_HEAD: String = ("You will lose access to the following upgrades and will have to"
	+ " purchase them individually again")
#The loss list: the dialog box width, a scroll offset deep into the list and a part bought guild in table order.
const LOSS_BOX_WIDTH: float = 720.0
const LOSS_SCROLL_PROBE: int = 400
const PART_STATE: Dictionary = {"seats": 2, "contracts": 1}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var roster: Array[MercenaryData] = GameState.mercs.duplicate()
	var board: Array[ContractView] = GameState.contracts.duplicate()
	var bank: int = GameState.bank_notes
	GuiTreeTests._fresh()
	await host.get_tree().process_frame
	var viewer: SubscriptionViewer = VIEWER.instantiate() as SubscriptionViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	await _case_tabs(res, host, viewer)
	await _case_cards(res, host, viewer)
	await _case_dialog(res, host, viewer)
	await _case_loss_cards(res, host, viewer)
	_case_switch_rules(res)
	_case_billing(res)
	_case_charges(res)
	_case_limits(res)
	await _case_spend(res, host, viewer)
	_case_payroll_fee(res)
	_case_caps(res)
	GuiFrameStack.clear()
	viewer.queue_free()
	CampaignClock.minutes = clock
	GameState.mercs = roster
	GameState.contracts = board
	GameState.bank_notes = bank
	SubscriptionManager.max_out()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI SUBS")


#Every "id tier" pair of the upgrade table for which the predicate holds.
static func _tiers_where(pred: Callable) -> Array[String]:
	var out: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		for tier: int in range(1, UpgradeDefs.tier_count(id) + 1):
			if pred.call(id, tier):
				out.append("%s %d" % [id, tier])
	return out


static func _plan_ids(viewer: SubscriptionViewer) -> Array[String]:
	var out: Array[String] = []
	for card: PlanCard in viewer.plans_page().cards():
		out.append(card.plan_id)
	return out


#Case 1: the tab row, the page under it and the lock the Customize tab wears below Enterprise.
static func _case_tabs(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var seen: Array[String] = []
	viewer.tab_changed.connect(func(key: StringName) -> void: seen.append(String(key)))
	var plans: PlansPage = viewer.plans_page()
	var customize: CustomizePage = viewer.customize_page()
	TestFixtures.check(res, "the window opens on the Plans tab",
		viewer.current_tab() == SubscriptionViewer.PLANS_TAB and plans.visible
			and not customize.visible,
		"tab %s" % [viewer.current_tab()])
	TestFixtures.check(res, "the Plans page heads its cards the way the prototype writes it",
		plans.title.text == "Mercday Plans:", "title %s" % [plans.title.text])
	TestFixtures.check(res, "each tab carries its own title",
		viewer.tab_title(SubscriptionViewer.PLANS_TAB) == SubscriptionViewer.PLANS_TITLE
			and viewer.tab_title(SubscriptionViewer.CUSTOMIZE_TAB) == SubscriptionViewer.CUSTOMIZE_TITLE,
		"titles %s and %s" % [viewer.tab_title(SubscriptionViewer.PLANS_TAB),
			viewer.tab_title(SubscriptionViewer.CUSTOMIZE_TAB)])
	TestFixtures.check(res, "the Customize tab is open on Enterprise",
		not customize.is_locked() and not viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB).locked,
		"locked %s" % [customize.is_locked()])
	viewer.open_tab(SubscriptionViewer.CUSTOMIZE_TAB)
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the Customize tab swaps the page and reports it once",
		viewer.current_tab() == SubscriptionViewer.CUSTOMIZE_TAB and customize.visible
			and not plans.visible and seen == ["customize"],
		"seen %s" % [seen])
	viewer.open_tab(SubscriptionViewer.CUSTOMIZE_TAB)
	TestFixtures.check(res, "re-opening the same tab reports nothing new",
		seen.size() == 1, "seen %s" % [seen])
	viewer.open_tab(&"nowhere")
	TestFixtures.check(res, "an unknown tab key is ignored",
		viewer.current_tab() == SubscriptionViewer.CUSTOMIZE_TAB and seen.size() == 1,
		"tab %s seen %s" % [viewer.current_tab(), seen])
	TestFixtures.check(res, "each key names its own tab button",
		viewer.tab_button(SubscriptionViewer.PLANS_TAB) != viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB)
			and viewer.tab_button(SubscriptionViewer.PLANS_TAB).index == 0
			and viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB).index == 1,
		"indices %d and %d" % [viewer.tab_button(SubscriptionViewer.PLANS_TAB).index,
			viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB).index])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	var customize_tab: TabButton = viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB)
	TestFixtures.check(res, "the Customize tab locks below Enterprise",
		customize_tab.locked and customize.is_locked()
			and customize_tab.tooltip_text == SubscriptionViewer.CUSTOMIZE_LOCKED_TITLE,
		"tooltip %s" % [customize_tab.tooltip_text])
	TestFixtures.check(res, "the locked Customize page covers itself and names the plan",
		customize.lock.visible and customize.note_text() == CustomizePage.NOTE_LOCKED
			and customize.note_color().is_equal_approx(CustomizePage.NOTE_LOCKED_COLOR),
		"note %s" % [customize.note_text()])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the open Customize page invites a click",
		not customize.lock.visible and customize.note_text() == CustomizePage.NOTE_OPEN
			and customize.note_color().is_equal_approx(CustomizePage.NOTE_OPEN_COLOR),
		"note %s" % [customize.note_text()])
	viewer.open_target({"tab": "plans"})
	TestFixtures.check(res, "a plain lock target opens the Plans tab",
		viewer.current_tab() == SubscriptionViewer.PLANS_TAB, "tab %s" % [viewer.current_tab()])
	viewer.open_target({"tab": "customize", "upgrade": "seats", "tier": 2})
	await host.get_tree().process_frame
	TestFixtures.check(res, "an upgrade lock target opens the Customize tab",
		viewer.current_tab() == SubscriptionViewer.CUSTOMIZE_TAB, "tab %s" % [viewer.current_tab()])
	TestFixtures.check(res, "the Customize page hosts the tree",
		customize.has_tree() and customize.focus_upgrade("seats", 1),
		"host %s" % [customize.has_tree()])
	viewer.open_tab(SubscriptionViewer.PLANS_TAB)
	await host.get_tree().process_frame
	var open_tab: TabButton = viewer.tab_button(SubscriptionViewer.PLANS_TAB)
	var idle_tab: TabButton = viewer.tab_button(SubscriptionViewer.CUSTOMIZE_TAB)
	TestFixtures.check(res, "a resting icon tab keeps the idle box and hides its label",
		not idle_tab.label_always and not idle_tab.text_label.visible
			and idle_tab.custom_minimum_size.is_equal_approx(TabButton.IDLE_SIZE),
		"box %s label %s" % [idle_tab.custom_minimum_size, idle_tab.text_label.visible])
	TestFixtures.check(res, "the open tab shows its label and stands taller",
		open_tab.active and open_tab.text_label.visible and not open_tab.label_always
			and is_equal_approx(open_tab.custom_minimum_size.x, TabButton.IDLE_SIZE.x)
			and is_equal_approx(open_tab.custom_minimum_size.y, float(TabButton.ACTIVE_HEIGHT)),
		"box %s label %s" % [open_tab.custom_minimum_size, open_tab.text_label.visible])
	TestFixtures.check(res, "both tabs and the header logo carry their atlas ids at x2",
		open_tab.icon_rect.icon_id == "mercday"
			and idle_tab.icon_rect.icon_id == "customize"
			and open_tab.icon_scale == 2 and viewer.plans.logo is IconRect
			and viewer.plans.logo.icon_id == "mercday" and viewer.plans.logo.pixel_scale == 2
			and viewer.plans.logo.custom_minimum_size == Vector2(32, 32),
		"plans '%s' customize '%s' logo '%s' box %s" % [open_tab.icon_rect.icon_id,
			idle_tab.icon_rect.icon_id, viewer.plans.logo.icon_id,
			str(viewer.plans.logo.custom_minimum_size)])
	TestFixtures.check(res, "the window fits the 644 px frame",
		viewer.get_combined_minimum_size().y <= 644.0,
		"minimum %.1f" % viewer.get_combined_minimum_size().y)


#Case 2: the three plan cards, their prices and every reason one of them refuses a switch.
static func _case_cards(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var plans: PlansPage = viewer.plans_page()
	GuiTreeTests._set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.max_out()
	viewer.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the page holds one card per plan in table order",
		_plan_ids(viewer) == ["free", "pro", "enterprise"], "cards %s" % [_plan_ids(viewer)])
	var free_card: PlanCard = plans.card("free")
	var pro_card: PlanCard = plans.card("pro")
	var ent_card: PlanCard = plans.card_of(SubscriptionManager.Plan.ENTERPRISE)
	TestFixtures.check(res, "the free card asks for nothing",
		free_card.price_text() == "Free" and free_card.estimate_text() == "No service fee",
		"%s and %s" % [free_card.price_text(), free_card.estimate_text()])
	TestFixtures.check(res, "a paid card prices the merc and the roster",
		pro_card.price_text() == "5 notes per merc / month"
			and pro_card.estimate_text() == "15 notes / month for your 3 mercs",
		"%s and %s" % [pro_card.price_text(), pro_card.estimate_text()])
	var pro_accent: Color = Color(PRO_ACCENT)
	TestFixtures.check(res, "the pro card carries the prototype's accent, index and features",
		pro_card.accent_color().is_equal_approx(pro_accent) and pro_card.plan_index() == PRO_INDEX
			and pro_card.features() == PRO_FEATURES
			and pro_card.accent.color.is_equal_approx(pro_accent),
		"accent %s index %d lines %d" % [pro_card.accent_color(), pro_card.plan_index(),
			pro_card.features().size()])
	var rows: Array[CheckRow] = []
	for child: Node in pro_card.features_box.get_children():
		var row: CheckRow = child as CheckRow
		if row != null:
			rows.append(row)
	var bad: Array[String] = []
	for i: int in mini(rows.size(), PRO_FEATURES.size()):
		if rows[i].text != PRO_FEATURES[i] or not rows[i].color.is_equal_approx(pro_accent):
			bad.append(rows[i].text)
	var marks: Array[String] = []
	for row: CheckRow in rows:
		if row.mark.custom_minimum_size != Vector2(12, 12) or row.mark.texture == null:
			marks.append(row.text)
	TestFixtures.check(res, "the pro card builds one check row per prototype feature",
		rows.size() == PRO_FEATURES.size() and bad.is_empty() and marks.is_empty(),
		TestFixtures.detail(bad + marks, rows.size(), "rows"))
	var order: Array[String] = []
	for card: PlanCard in plans.cards():
		order.append("%s %d" % [card.plan_id, card.plan_index()])
	TestFixtures.check(res, "the cards keep the prototype's plan order",
		order == ["free 0", "pro 1", "enterprise 2"], "order %s" % [order])
	TestFixtures.check(res, "the ring reads green on the current plan and navy on the others",
		PlanCard.RING_CURRENT == GuiColors.GREEN
			and PlanCard.RING_IDLE == GuiColors.BLUE_LO
			and ent_card.is_current() and not pro_card.is_current()
			and not free_card.is_current(),
		"current %s pro %s" % [ent_card.is_current(), pro_card.is_current()])
	TestFixtures.check(res, "the current Enterprise card offers the Customize tab",
		ent_card.is_current() and ent_card.is_enabled()
			and ent_card.button_text() == "Customize Plan"
			and ent_card.button_tooltip() == "Open the Customize tab",
		"%s and %s" % [ent_card.button_text(), ent_card.button_tooltip()])
	ent_card.press_switch()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Enterprise card changes tab instead of switching plan",
		viewer.current_tab() == SubscriptionViewer.CUSTOMIZE_TAB
			and not viewer.dialog().visible,
		"tab %s" % [viewer.current_tab()])
	viewer.open_tab(SubscriptionViewer.PLANS_TAB)
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "the current paid card is dead and says so",
		pro_card.is_current() and not pro_card.is_enabled()
			and pro_card.button_text() == "Current Plan"
			and pro_card.button_tooltip() == "This is your current plan"
			and pro_card.reason_text() == "",
		"%s and %s" % [pro_card.button_text(), pro_card.button_tooltip()])
	GuiTreeTests._set_crew(8)
	viewer.refresh()
	TestFixtures.check(res, "a roster over the cap blocks the downgrade",
		not free_card.is_enabled()
			and free_card.reason_text()
				== "You must fire 3 mercs before you are eligible to downgrade"
			and free_card.button_tooltip() == "You have 8 mercs. Mercday Free allows up to 5.",
		"%s and %s" % [free_card.reason_text(), free_card.button_tooltip()])
	GuiTreeTests._set_crew(6)
	viewer.refresh()
	TestFixtures.check(res, "one merc over the cap reads as one merc",
		free_card.reason_text() == "You must fire 1 merc before you are eligible to downgrade",
		"reason %s" % [free_card.reason_text()])
	GuiTreeTests._set_crew(3)
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	GameState.bank_notes = 0
	viewer.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty bank blocks the upgrade",
		not pro_card.is_enabled()
			and pro_card.reason_text() == "Not enough notes: 1 month costs 15."
			and pro_card.button_tooltip()
				== "You need at least 15 notes (1 month of service) to switch.",
		"%s and %s" % [pro_card.reason_text(), pro_card.button_tooltip()])
	GameState.bank_notes = RICH
	viewer.refresh()
	TestFixtures.check(res, "a card the bank can cover offers the switch",
		pro_card.is_enabled() and pro_card.button_text() == "Switch to Pro Plan"
			and pro_card.reason_text() == "",
		"%s enabled %s" % [pro_card.button_text(), pro_card.is_enabled()])
	TestFixtures.check(res, "every plan card's switch button is the shared BevelButton scene",
		free_card.switch_button is BevelButton and pro_card.switch_button is BevelButton
			and ent_card.switch_button is BevelButton
			and pro_card.switch_button.text == pro_card.button_text(),
		"free %s pro %s ent %s" % [free_card.switch_button is BevelButton,
			pro_card.switch_button is BevelButton, ent_card.switch_button is BevelButton])
	pro_card.press_switch()
	await host.get_tree().process_frame
	var dialog: PlanSwitchDialog = viewer.dialog()
	TestFixtures.check(res, "pressing a live card opens the dialog on that plan",
		dialog.visible and dialog.target_plan() == SubscriptionManager.Plan.PRO,
		"visible %s target %d" % [dialog.visible, dialog.target_plan()])
	dialog.press_cancel()
	await host.get_tree().process_frame


#Case 3: the switch dialog in both directions, its sections, its price and its two answers.
static func _case_dialog(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var dialog: PlanSwitchDialog = viewer.dialog()
	var done: Array[int] = []
	var back: Array[int] = []
	var switched: Array[int] = []
	dialog.confirmed.connect(func() -> void: done.append(dialog.target_plan()))
	dialog.cancelled.connect(func() -> void: back.append(1))
	viewer.plan_switched.connect(func(plan: int) -> void: switched.append(plan))
	GuiTreeTests._set_crew(3)
	GuiTreeTests._set_board(LIGHT_BOARD)
	GuiTreeTests._set_day(SHORT_MONTH, 1)
	GameState.bank_notes = RICH
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the upgrade dialog names the direction and the plan",
		not dialog.is_downgrade() and dialog.kind_text() == "Upgrade Plan"
			and dialog.ok_text() == "Upgrade"
			and dialog.ring_color.is_equal_approx(PlanSwitchDialog.RING_UP)
			and dialog.target_label.text == "Mercday Pro",
		"%s to %s" % [dialog.kind_text(), dialog.target_label.text])
	TestFixtures.check(res, "the upgrade dialog lists what the plan includes",
		dialog.sections() == ["Includes:"], "sections %s" % [dialog.sections()])
	TestFixtures.check(res, "the upgrade dialog prices one month of the target",
		dialog.fee() == 15
			and dialog.note_text() == "5 notes per merc, billed with Guild Expenses on the 2nd.",
		"fee %d note %s" % [dialog.fee(), dialog.note_text()])
	TestFixtures.check(res, "an affordable switch reads cream with a live confirm",
		dialog.can_afford() and dialog.cost_color().is_equal_approx(PlanSwitchDialog.CREAM)
			and is_equal_approx(dialog.ok_alpha(), 1.0),
		"colour %s alpha %f" % [dialog.cost_color(), dialog.ok_alpha()])
	TestFixtures.check(res, "an upgrade puts Back on blue and the go confirm on green",
		dialog._link is BevelButton and dialog._link.kind == &"blue"
			and dialog._link.text == "Back"
			and dialog._solid is BevelButton and dialog._solid.kind == &"go"
			and dialog._solid.text == "Upgrade",
		"link %s solid %s" % [dialog._link.kind, dialog._solid.kind])
	GameState.bank_notes = 0
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unaffordable switch reads red with a dead confirm",
		not dialog.can_afford() and dialog.cost_color().is_equal_approx(PlanSwitchDialog.RED)
			and is_equal_approx(dialog.ok_alpha(), PlanSwitchDialog.DEAD_ALPHA),
		"colour %s alpha %f" % [dialog.cost_color(), dialog.ok_alpha()])
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dead confirm refuses the switch",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE and dialog.visible
			and done.is_empty(),
		"plan %d visible %s" % [SubscriptionManager.plan(), dialog.visible])
	dialog.press_cancel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Back closes the dialog and reports it",
		not dialog.visible and back.size() == 1, "visible %s back %s" % [dialog.visible, back])
	GameState.bank_notes = RICH
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await host.get_tree().process_frame
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the live confirm switches the plan and reports it",
		SubscriptionManager.plan() == SubscriptionManager.Plan.PRO and not dialog.visible
			and done == [SubscriptionManager.Plan.PRO] and switched == [SubscriptionManager.Plan.PRO],
		"plan %d done %s switched %s" % [SubscriptionManager.plan(), done, switched])
	SubscriptionManager.max_out()
	_set_live_board(FULL_BOARD)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the downgrade dialog swaps the words and the ring",
		dialog.is_downgrade() and dialog.kind_text() == "Downgrade Plan"
			and dialog.ok_text() == "Downgrade"
			and dialog.ring_color.is_equal_approx(PlanSwitchDialog.RING_DOWN),
		"%s ring %s" % [dialog.kind_text(), dialog.ring_color])
	TestFixtures.check(res, "a downgrade swaps the confirm to danger and Back to blue",
		dialog._link is BevelButton and dialog._link.kind == &"danger"
			and dialog._link.text == "Downgrade"
			and dialog._solid is BevelButton and dialog._solid.kind == &"blue"
			and dialog._solid.text == "Back",
		"link %s solid %s" % [dialog._link.kind, dialog._solid.kind])
	TestFixtures.check(res, "a free target carries no service fee",
		dialog.fee() == 0 and dialog.note_text() == "No service fee."
			and not dialog.cost_value.glyph.visible,
		"fee %d note %s" % [dialog.fee(), dialog.note_text()])
	var free_cap: int = UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
	var over: int = SubscriptionManager.board_count() - free_cap
	var board_lead: String = "%d postings are over the Free cap of %d" % [over, free_cap]
	var board_head: String = (board_lead + "; they stay until they close and nothing new is posted"
		+ " until the board is under the cap")
	TestFixtures.check(res, "leaving Enterprise lists the upgrades that go",
		dialog.sections().has(LOSE_HEAD) and not SubscriptionManager.owned_lines().is_empty(),
		"sections %s" % [dialog.sections()])
	TestFixtures.check(res, "a full board heads the downgrade with the postings over the Free cap",
		SubscriptionManager.board_count() == FULL_BOARD and over == FULL_BOARD - free_cap
			and dialog.sections()[0].begins_with(board_lead) and dialog.sections()[0] == board_head,
		"sections %s" % [dialog.sections()])
	TestFixtures.check(res, "the over cap warning keeps the postings and removes none",
		not " ".join(PackedStringArray(dialog.sections())).to_lower().contains("removed"),
		"sections %s" % [dialog.sections()])
	TestFixtures.check(res, "the free board cap that warning counts against comes from the table",
		UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
				== UpgradeDefs.FREE_CONTRACTS
			and UpgradeDefs.FREE_CONTRACTS == 5,
		"cap %d" % [UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)])
	TestFixtures.check(res, "a downgrade never lists what the target includes",
		not dialog.sections().has("Includes:"), "sections %s" % [dialog.sections()])
	var ad: ContractData = ContractGenerator.generate("Military")
	var tagged: BoardEntry = GameState.post_campaign_contract(ad, AD_CAMPAIGN, true)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a campaign posting on a full board stays out of the count over the Free cap",
		tagged != null and tagged.campaign_id == AD_CAMPAIGN and tagged.is_open()
			and SubscriptionManager.board_count() == FULL_BOARD + 1 and over == FULL_BOARD - free_cap
			and dialog.sections().find(board_head) == 0,
		"board %d own %d sections %s" % [SubscriptionManager.board_count(), GameState.board.own_open(),
			dialog.sections()])
	_set_live_board(LIGHT_BOARD)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a board inside the free cap raises no warning",
		not dialog.sections().has(board_head) and dialog.sections() == [LOSE_HEAD],
		"sections %s" % [dialog.sections()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a downgrade with nothing to lose names the plan it leaves",
		dialog.sections() == ["You will lose the features of Mercday Enterprise."],
		"sections %s" % [dialog.sections()])
	dialog.press_cancel()
	await host.get_tree().process_frame


#Case 3b: leaving Enterprise shows what goes as scrolling cards that read like the Customize tiles.
static func _case_loss_cards(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var dialog: PlanSwitchDialog = viewer.dialog()
	var canvas: TreeCanvas = viewer.customize_page().tree_node().canvas()
	var scroll: ScrollContainer = dialog.modules_scroll
	_set_live_board(FULL_BOARD)
	SubscriptionManager.max_out()
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await _settle(host)
	var ids: Array[String] = []
	var fees: int = 0
	var worn: Array[String] = []
	var drift: Array[String] = []
	var inert: bool = true
	for i: int in range(dialog.module_count()):
		var card: UpgradeLossCard = dialog.module(i)
		var id: String = card.upgrade_id
		var most: int = UpgradeDefs.tier_count(id)
		ids.append(id)
		fees += card.fee()
		inert = inert and _all_ignore(card)
		if (card.tier() != most or card.max_tier() != most
				or card.fee() != UpgradeDefs.monthly_of(id, most)
				or card.tier_text() != SubscriptionManager.roman(most)
				or card.fee_text() != TransactionData.grouped(card.fee()) + CustomizeBlock.SUFFIX
				or card.give_text() != UpgradeDefs.tier_text(id, most)):
			worn.append(id)
		var miss: String = _card_drift(card, canvas.block(id))
		if miss != "":
			drift.append(miss)
	TestFixtures.check(res, "leaving Enterprise lists one card per owned upgrade in table order",
		dialog.modules_visible() and ids == UpgradeDefs.ORDER,
		"cards %d visible %s" % [ids.size(), dialog.modules_visible()])
	TestFixtures.check(res, "each card shows the owned tier, its numeral, the give line and the monthly fee",
		worn.is_empty() and fees > 0 and fees == SubscriptionManager.monthly_upgrade_cost(),
		"off %s fees %d bill %d" % [worn, fees, SubscriptionManager.monthly_upgrade_cost()])
	TestFixtures.check(res, "each card reads like the Customize tile of its upgrade",
		drift.is_empty(), "drift %s" % [drift.slice(0, 3)])
	TestFixtures.check(res, "the cards ignore the pointer so the wheel reaches the scroll", inert,
		"a card still takes the pointer")
	TestFixtures.check(res, "the lose head stays above the list and no text rows stand in for the cards",
		dialog.sections().has(LOSE_HEAD) and dialog.sections_box.get_index() < dialog.modules_box.get_index()
			and dialog.sections_box.get_child_count() == dialog.sections().size(),
		"sections %s rows %d" % [dialog.sections(), dialog.sections_box.get_child_count()])
	TestFixtures.check(res, "the cards sit in the only scroll of the dialog, inside the inset shell",
		_scroll_count(dialog) == 1 and dialog.list_box().get_parent() == scroll
			and scroll.get_parent() == dialog.modules_box
			and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"scrolls %d" % [_scroll_count(dialog)])
	TestFixtures.check(res, "the list is longer than its window so it scrolls",
		scroll.size.y > 0.0 and dialog.list_box().size.y > scroll.size.y + 1.0,
		"list %f window %f" % [dialog.list_box().size.y, scroll.size.y])
	var band: float = GuiFrameStack.band_height(host.get_viewport().get_visible_rect().size.y)
	var want_h: float = minf(PlanSwitchDialog.BOX_H, band - PlanSwitchDialog.BAND_GAP)
	TestFixtures.check(res, "the box keeps its set height inside the band however long the list is",
		is_equal_approx(dialog.box.size.y, want_h) and dialog.box.size.y <= band,
		"box %f want %f band %f" % [dialog.box.size.y, want_h, band])
	TestFixtures.check(res, "the box is the wide one that gives the cards room",
		is_equal_approx(dialog.box.size.x, LOSS_BOX_WIDTH) and is_equal_approx(dialog.box_width, LOSS_BOX_WIDTH),
		"box %f width %f" % [dialog.box.size.x, dialog.box_width])
	scroll.scroll_vertical = LOSS_SCROLL_PROBE
	await host.get_tree().process_frame
	var moved: int = scroll.scroll_vertical
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await _settle(host)
	TestFixtures.check(res, "reopening the dialog scrolls the list back to the top",
		moved > 0 and scroll.scroll_vertical == 0, "moved %d now %d" % [moved, scroll.scroll_vertical])
	_set_live_board(LIGHT_BOARD)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, PART_STATE)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await _settle(host)
	var kept: Array[String] = []
	var part_off: Array[String] = []
	var part_drift: Array[String] = []
	for i: int in range(dialog.module_count()):
		var part: UpgradeLossCard = dialog.module(i)
		var owned: int = int(PART_STATE.get(part.upgrade_id, 0))
		var filled: int = 0
		for p: int in range(part.pip_count()):
			if not part.pip_color(p).is_equal_approx(CustomizeBlock.CHUNK_BG):
				filled += 1
		kept.append(part.upgrade_id)
		if (part.tier() != owned or part.max_tier() != UpgradeDefs.tier_count(part.upgrade_id)
				or part.fee() != UpgradeDefs.monthly_of(part.upgrade_id, owned)
				or part.pip_count() != part.max_tier() or filled != owned
				or part.well_color().is_equal_approx(CustomizeBlock.BG_MAX)
				or part.tier_text() != SubscriptionManager.roman(owned)
				or not part.ring_color().is_equal_approx(part.icon_tint())):
			part_off.append(part.upgrade_id)
		var part_miss: String = _card_drift(part, canvas.block(part.upgrade_id))
		if part_miss != "":
			part_drift.append(part_miss)
	TestFixtures.check(res, "a part bought guild lists only what it owns, at the tier it owns",
		kept == PART_STATE.keys() and part_off.is_empty() and dialog.sections() == [LOSE_HEAD],
		"cards %s off %s sections %s" % [kept, part_off, dialog.sections()])
	TestFixtures.check(res, "a part owned card fills only the pips it owns and still reads like its tile",
		part_drift.is_empty(), "drift %s" % [part_drift])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await _settle(host)
	TestFixtures.check(res, "a downgrade from Pro has no upgrade list and the box fits its rows",
		dialog.module_count() == 0 and not dialog.modules_visible()
			and is_zero_approx(dialog.box.custom_minimum_size.y)
			and dialog.sections() == ["You will lose the features of Mercday Pro."],
		"cards %d visible %s sections %s" % [dialog.module_count(), dialog.modules_visible(),
			dialog.sections()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await _settle(host)
	TestFixtures.check(res, "an upgrade shows no upgrade list",
		dialog.module_count() == 0 and not dialog.modules_visible() and dialog.sections() == ["Includes:"],
		"cards %d visible %s" % [dialog.module_count(), dialog.modules_visible()])
	SubscriptionManager.max_out()
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await _settle(host)
	TestFixtures.check(res, "moving from Enterprise to Pro loses the same upgrades",
		dialog.module_count() == UpgradeDefs.ORDER.size() and dialog.modules_visible(),
		"cards %d visible %s" % [dialog.module_count(), dialog.modules_visible()])
	dialog.press_cancel()
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})


#The first way a loss card reads differently from the Customize tile of its upgrade, or "" when they match.
static func _card_drift(card: UpgradeLossCard, block: CustomizeBlock) -> String:
	var id: String = card.upgrade_id
	if block == null:
		return "%s has no tile" % id
	if card.icon_id() == "" or card.icon_id() != TreeIcons.id_of(id):
		return "%s icon %s" % [id, card.icon_id()]
	if not card.icon_tint().is_equal_approx(block.icon_color()):
		return "%s tint %s tile %s" % [id, card.icon_tint(), block.icon_color()]
	if not card.well_color().is_equal_approx(block.bg_color()):
		return "%s well %s tile %s" % [id, card.well_color(), block.bg_color()]
	if card.name_text() != block.name_text() or card.kind_text() != block.kind_text():
		return "%s name %s kind %s" % [id, card.name_text(), card.kind_text()]
	if card.desc_text() != block.desc_text():
		return "%s desc %s" % [id, card.desc_text()]
	if card.tier() != block.tier() or card.max_tier() != block.max_tier() or card.fee() != block.monthly_fee():
		return "%s tier %d of %d fee %d, tile %d of %d fee %d" % [id, card.tier(), card.max_tier(),
			card.fee(), block.tier(), block.max_tier(), block.monthly_fee()]
	if card.pip_count() != block.max_tier():
		return "%s pips %d" % [id, card.pip_count()]
	for i: int in range(card.pip_count()):
		if not card.pip_color(i).is_equal_approx(block.pip_color(i)):
			return "%s pip %d %s tile %s" % [id, i, card.pip_color(i), block.pip_color(i)]
	return ""


static func _scroll_count(node: Node) -> int:
	var total: int = 1 if node is ScrollContainer else 0
	for child: Node in node.get_children():
		total += _scroll_count(child)
	return total


#True when node and every Control below it ignores the pointer.
static func _all_ignore(node: Node) -> bool:
	var control: Control = node as Control
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not _all_ignore(child):
			return false
	return true


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


#A fresh board of n open postings of its own beside the n listed views of _set_board, so own_open() and board_count() agree.
static func _set_live_board(n: int) -> void:
	GameState.board = ContractBoard.new()
	for _i: int in range(n):
		GameState.board.post(ContractGenerator.generate("Military"), CampaignClock.now())
	GuiTreeTests._set_board(n)


#Case 4: what SubscriptionManager allows a switch to cost and when it refuses one outright.
static func _case_switch_rules(res: Dictionary) -> void:
	GuiTreeTests._set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	TestFixtures.check(res, "the current plan refuses a switch to itself",
		not SubscriptionManager.can_switch(SubscriptionManager.Plan.PRO)
			and SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)
				== "This is your current plan",
		"reason %s" % [SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)])
	GuiTreeTests._set_crew(8)
	TestFixtures.check(res, "a roster over the cap refuses the switch",
		SubscriptionManager.switch_reason(SubscriptionManager.Plan.FREE)
			== "You have 8 mercs. Mercday Free allows up to 5.",
		"reason %s" % [SubscriptionManager.switch_reason(SubscriptionManager.Plan.FREE)])
	GuiTreeTests._set_crew(3)
	GameState.bank_notes = 10
	TestFixtures.check(res, "a bank under one month refuses the switch",
		SubscriptionManager.switch_reason(SubscriptionManager.Plan.ENTERPRISE)
			== "You need at least 45 notes (1 month of service) to switch.",
		"reason %s" % [SubscriptionManager.switch_reason(SubscriptionManager.Plan.ENTERPRISE)])
	TestFixtures.check(res, "switch_plan obeys its own refusal",
		not SubscriptionManager.switch_plan(SubscriptionManager.Plan.ENTERPRISE)
			and SubscriptionManager.plan() == SubscriptionManager.Plan.PRO,
		"plan %d" % SubscriptionManager.plan())
	GameState.bank_notes = RICH
	SubscriptionManager.max_out()
	var held: int = SubscriptionManager.tiers().size()
	TestFixtures.check(res, "switching off Enterprise drops every tier",
		SubscriptionManager.switch_plan(SubscriptionManager.Plan.FREE) and held > 0
			and SubscriptionManager.tiers().is_empty() and SubscriptionManager.tier_of("seats") == 0,
		"held %d now %d" % [held, SubscriptionManager.tiers().size()])
	TestFixtures.check(res, "service_fee prices any plan against the payroll",
		SubscriptionManager.service_fee(SubscriptionManager.Plan.FREE) == 0
			and SubscriptionManager.service_fee(SubscriptionManager.Plan.PRO) == 15
			and SubscriptionManager.service_fee(SubscriptionManager.Plan.ENTERPRISE) == 45
			and SubscriptionManager.employed() == 3,
		"pro %d enterprise %d" % [SubscriptionManager.service_fee(SubscriptionManager.Plan.PRO),
			SubscriptionManager.service_fee(SubscriptionManager.Plan.ENTERPRISE)])


#Case 5: the billing day of the game calendar, in a 30 day month and in a 40 day one.
static func _case_billing(res: Dictionary) -> void:
	GuiTreeTests._set_day(SHORT_MONTH, 7)
	TestFixtures.check(res, "day_of_month follows the game calendar",
		SubscriptionManager.day_of_month() == 7, "day %d" % SubscriptionManager.day_of_month())
	GuiTreeTests._set_day(SHORT_MONTH, 1)
	var first: int = SubscriptionManager.days_to_bill()
	TestFixtures.check(res, "the bill falls on the 2nd and days_to_bill counts down to it",
		SubscriptionManager.BILL_DAY == 2 and first == 1,
		"bill day %d, day 1 reads %d" % [SubscriptionManager.BILL_DAY, first])
	GuiTreeTests._set_day(SHORT_MONTH, SubscriptionManager.BILL_DAY)
	TestFixtures.check(res, "the 2nd reads the whole short month ahead",
		SubscriptionManager.days_to_bill() == 30, "reads %d" % SubscriptionManager.days_to_bill())
	GuiTreeTests._set_day(SHORT_MONTH, 3)
	var after: int = SubscriptionManager.days_to_bill()
	GuiTreeTests._set_day(SHORT_MONTH, 30)
	TestFixtures.check(res, "days_to_bill counts through the end of a short month",
		after == 29 and SubscriptionManager.days_to_bill() == 2,
		"day 3 reads %d, day 30 reads %d" % [after, SubscriptionManager.days_to_bill()])
	GuiTreeTests._set_day(LONG_MONTH, SubscriptionManager.BILL_DAY)
	TestFixtures.check(res, "the 2nd of a long month reads forty days ahead",
		SubscriptionManager.days_to_bill() == 40, "reads %d" % SubscriptionManager.days_to_bill())
	GuiTreeTests._set_day(LONG_MONTH, 3)
	var long_after: int = SubscriptionManager.days_to_bill()
	GuiTreeTests._set_day(LONG_MONTH, 40)
	TestFixtures.check(res, "days_to_bill counts through the end of a long month",
		long_after == 39 and SubscriptionManager.days_to_bill() == 2,
		"day 3 reads %d, day 40 reads %d" % [long_after, SubscriptionManager.days_to_bill()])


#Case 6: what one more tier costs today, pro-rated to the billing day and never charged twice.
static func _case_charges(res: Dictionary) -> void:
	GuiTreeTests._set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.max_out()
	TestFixtures.check(res, "tier_price reads one tier without the tiers under it",
		SubscriptionManager.tier_price("seats", 1) == 3
			and SubscriptionManager.tier_price("seats", 3) == 12
			and SubscriptionManager.tier_price("seats", 0) == 0,
		"tier 3 costs %d" % SubscriptionManager.tier_price("seats", 3))
	GuiTreeTests._set_day(LONG_MONTH, SubscriptionManager.BILL_DAY)
	var counted: int = _tiers_where(func(_id: String, _tier: int) -> bool: return true).size()
	var over: Array[String] = _tiers_where(func(id: String, tier: int) -> bool:
		return (SubscriptionManager.upgrade_charge_today(id, tier)
			> SubscriptionManager.tier_price(id, tier)))
	TestFixtures.check(res, "a charge today never passes the month's price",
		over.is_empty(), TestFixtures.detail(over, counted, "tiers"))
	GuiTreeTests._set_day(SHORT_MONTH, SubscriptionManager.BILL_DAY)
	var short: Array[String] = _tiers_where(func(id: String, tier: int) -> bool:
		return (SubscriptionManager.upgrade_charge_today(id, tier)
			!= SubscriptionManager.tier_price(id, tier)))
	TestFixtures.check(res, "the whole month is charged on the billing day",
		short.is_empty(), TestFixtures.detail(short, counted, "tiers"))
	GuiTreeTests._set_day(SHORT_MONTH, SubscriptionManager.BILL_DAY - 1)
	TestFixtures.fund_budget(SubscriptionManager.BUDGET_FALLBACK)
	TestFixtures.check(res, "one day left is pro-rated up to a whole note",
		SubscriptionManager.upgrade_charge_today("seats", 1) == 1
			and SubscriptionManager.upgrade_charge_today("representation", 1) == 17,
		"seats %d representation %d" % [SubscriptionManager.upgrade_charge_today("seats", 1),
			SubscriptionManager.upgrade_charge_today("representation", 1)])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	GameState.bank_notes = 500
	var charge: int = SubscriptionManager.upgrade_charge_today("seats", 1)
	var bought: bool = SubscriptionManager.buy_tier("seats")
	TestFixtures.check(res, "buy_tier spends the pro-rated charge",
		bought and GameState.bank_notes == 500 - charge
			and SubscriptionManager.tier_of("seats") == 1,
		"charge %d bank %d" % [charge, GameState.bank_notes])
	TestFixtures.check(res, "what this cycle paid for is not charged twice",
		SubscriptionManager.prepaid_tier("seats") == 1
			and SubscriptionManager.upgrade_charge_today("seats", 1) == 0
			and SubscriptionManager.upgrade_charge_today("seats", 2) > 0,
		"prepaid %d" % SubscriptionManager.prepaid_tier("seats"))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2, "contracts": 1})
	var owned: Dictionary = SubscriptionManager.tiers()
	var sum: int = 0
	for key: Variant in owned:
		if int(owned[key]) > 0:
			sum += SubscriptionManager.upgrade_fee(String(key))
	TestFixtures.check(res, "upgrade_fee reads one upgrade or every owned upgrade added up",
		SubscriptionManager.upgrade_fee("seats") == 9 and SubscriptionManager.upgrade_fee() == sum
			and sum > SubscriptionManager.upgrade_fee("seats"),
		"seats %d sum %d whole %d" % [SubscriptionManager.upgrade_fee("seats"), sum,
			SubscriptionManager.upgrade_fee()])


#Case 7: the floors a live roster and board put under a tier, the income rule and the cascade.
static func _case_limits(res: Dictionary) -> void:
	GameState.bank_notes = RICH
	GuiTreeTests._set_day(SHORT_MONTH, 14)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	GuiTreeTests._set_crew(UpgradeDefs.ENTERPRISE_MERCS)
	var seats_at_cap: int = SubscriptionManager.min_tier("seats")
	GuiTreeTests._set_crew(UpgradeDefs.ENTERPRISE_MERCS + 1)
	var seats_over: int = SubscriptionManager.min_tier("seats")
	GuiTreeTests._set_crew(UpgradeDefs.ENTERPRISE_MERCS + 3)
	var seats_full: int = SubscriptionManager.min_tier("seats")
	GuiTreeTests._set_crew(UpgradeDefs.ENTERPRISE_MERCS + 4)
	TestFixtures.check(res, "min_tier keeps the seats the roster is sitting in",
		seats_at_cap == 0 and seats_over == 1 and seats_full == 1
			and SubscriptionManager.min_tier("seats") == 2,
		"8 reads %d, 9 reads %d, 11 reads %d, 12 reads %d" % [seats_at_cap, seats_over,
			seats_full, SubscriptionManager.min_tier("seats")])
	GuiTreeTests._set_board(UpgradeDefs.ENTERPRISE_CONTRACTS)
	var board_at_cap: int = SubscriptionManager.min_tier("contracts")
	GuiTreeTests._set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 1)
	var board_over: int = SubscriptionManager.min_tier("contracts")
	GuiTreeTests._set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 3)
	var board_full: int = SubscriptionManager.min_tier("contracts")
	GuiTreeTests._set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 4)
	TestFixtures.check(res, "min_tier keeps the slots the board is using",
		board_at_cap == 0 and board_over == 1 and board_full == 1
			and SubscriptionManager.min_tier("contracts") == 2
			and SubscriptionManager.board_count() == 12,
		"8 reads %d, 9 reads %d, 11 reads %d, 12 reads %d" % [board_at_cap, board_over,
			board_full, SubscriptionManager.min_tier("contracts")])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"seats": 2, "contracts": 2})
	TestFixtures.check(res, "a seat tier the roster is using cannot be dropped",
		not SubscriptionManager.can_lower("seats")
			and SubscriptionManager.lower_reason("seats")
				== "Can't go below Tier 2: 12 mercs are using those seats.",
		"reason %s" % [SubscriptionManager.lower_reason("seats")])
	TestFixtures.check(res, "a contract tier the board is using cannot be dropped",
		not SubscriptionManager.can_lower("contracts")
			and SubscriptionManager.lower_reason("contracts")
				== "Can't go below Tier 2: 12 contracts are on your board.",
		"reason %s" % [SubscriptionManager.lower_reason("contracts")])
	GuiTreeTests._set_crew(3)
	GuiTreeTests._set_board(4)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"opspermit": 1, "representation": 2})
	TestFixtures.fund_budget(SubscriptionManager.BUDGET_FALLBACK)
	TestFixtures.check(res, "an upgrade over the monthly income is refused",
		SubscriptionManager.raise_reason("representation") == "Not enough monthly income."
			and SubscriptionManager.budget_available() == SubscriptionManager.BUDGET_FALLBACK,
		"reason %s" % [SubscriptionManager.raise_reason("representation")])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"opspermit": 1, "representation": 1})
	var dropped: bool = SubscriptionManager.lower_tier("opspermit")
	TestFixtures.check(res, "dropping a tier takes down what stood on it",
		dropped and SubscriptionManager.tier_of("opspermit") == 0
			and SubscriptionManager.tier_of("representation") == 0,
		"opspermit %d representation %d" % [SubscriptionManager.tier_of("opspermit"),
			SubscriptionManager.tier_of("representation")])
	TestFixtures.check(res, "an upgrade below Enterprise is refused outright",
		SubscriptionManager.raise_reason("seats") == ""
			and _reason_on_free("seats") == "Requires Mercday Enterprise.",
		"free reads %s" % [_reason_on_free("seats")])


#The raise refusal one plan down, with the Enterprise state put back afterwards.
static func _reason_on_free(id: String) -> String:
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var reason: String = SubscriptionManager.raise_reason(id)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	return reason


#Case 8: the spend readout of the Customize page and the three colours it reads the income in.
static func _case_spend(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	TestFixtures.check(res, "the readout keeps cream while the bills fit",
		SpendReadout.tint_for(100, 1000).is_equal_approx(SpendReadout.CREAM)
			and SpendReadout.tint_for(899, 1000).is_equal_approx(SpendReadout.CREAM),
		"899 of 1000 reads %s" % [SpendReadout.tint_for(899, 1000)])
	TestFixtures.check(res, "the readout warns from nine tenths of the income on",
		SpendReadout.tint_for(900, 1000).is_equal_approx(SpendReadout.ORANGE)
			and SpendReadout.tint_for(1000, 1000).is_equal_approx(SpendReadout.ORANGE),
		"900 of 1000 reads %s" % [SpendReadout.tint_for(900, 1000)])
	TestFixtures.check(res, "the readout reads red once the bills pass the income",
		SpendReadout.tint_for(1001, 1000).is_equal_approx(SpendReadout.RED)
			and SpendReadout.tint_for(1, 0).is_equal_approx(SpendReadout.RED),
		"1001 of 1000 reads %s" % [SpendReadout.tint_for(1001, 1000)])
	GuiTreeTests._set_crew(3)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2})
	var readout: SpendReadout = viewer.customize_page().spend_readout()
	readout.refresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the readout adds the plan fee to the add-ons",
		readout.base_fee() == 45 and readout.addon_fee() == 9 and readout.total() == 54
			and readout.text_value() == "45 + 9",
		"text %s" % [readout.text_value()])
	TestFixtures.check(res, "the readout names both halves and the income in its tooltip",
		readout.income() == SubscriptionManager.BUDGET_FALLBACK
			and readout.tooltip_value()
				== "Plan 45 + add-ons 9 of 1350 available monthly income"
			and readout.tint().is_equal_approx(SpendReadout.CREAM),
		"tooltip %s" % [readout.tooltip_value()])


#Case 9: the plan fee follows the payroll, so a fired merc stops costing the guild every month.
static func _case_payroll_fee(res: Dictionary) -> void:
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "the payroll case has a roster to fire from", false, "no mercs")
		return
	var template: MercenaryData = GameState.mercs[0]
	var crew: Array[MercenaryData] = []
	for i: int in range(3):
		var hand: MercenaryData = template.duplicate() as MercenaryData
		hand.merc_uid = FIRST_UID + i
		crew.append(hand)
	GameState.mercs = crew
	SubscriptionManager.max_out()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2})
	var per_merc: int = int(UpgradeDefs.plan_data(SubscriptionManager.Plan.ENTERPRISE).get(
		"per_merc", 0))
	var whole: int = SubscriptionManager.employed()
	var sent: bool = GameState.set_away(FIRST_UID + 1, GuiTypes.MercStatus.FIRED)
	TestFixtures.check(res, "a fired merc leaves the payroll the plan fee is counted on",
		sent and whole == 3 and SubscriptionManager.employed() == 2
			and SubscriptionManager.service_fee() == per_merc * 2 and per_merc > 0,
		"employed %d of %d, fee %d" % [SubscriptionManager.employed(), whole,
			SubscriptionManager.service_fee()])
	TestFixtures.check(res, "the monthly bill counts the payroll, not every merc in the roster",
		SubscriptionManager.monthly_cost() == SubscriptionManager.service_fee()
				+ SubscriptionManager.upgrade_fee()
			and SubscriptionManager.monthly_cost() == per_merc * 2 + SEATS_TWO_FEE
			and SubscriptionManager.monthly_cost() < per_merc * 3 + SEATS_TWO_FEE,
		"bill %d, fee %d, upgrades %d" % [SubscriptionManager.monthly_cost(),
			SubscriptionManager.service_fee(), SubscriptionManager.upgrade_fee()])
	GameState.clear_away(FIRST_UID + 1)


#Case 10: the caps of the three plans, the seats the dead hand back and the postings a board counts.
static func _case_caps(res: Dictionary) -> void:
	GameState.bank_notes = RICH
	SubscriptionManager.max_out()
	TestFixtures.check(res, "max_out gives Enterprise with every tier maxed, 32 mercs and 20 contracts",
		SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
			and SubscriptionManager.max_mercs() == 32 and SubscriptionManager.max_contracts() == 20
			and SubscriptionManager.tier_of("seats") == 8 and SubscriptionManager.tier_of("contracts") == 4,
		"%s %d/%d" % [SubscriptionManager.plan_key(), SubscriptionManager.max_mercs(),
			SubscriptionManager.max_contracts()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	TestFixtures.fund_budget(SubscriptionManager.BUDGET_FALLBACK)
	var bought: bool = SubscriptionManager.buy_tier("seats")
	SubscriptionManager.set_entitlements({"maxMercs": 99})
	SubscriptionManager.reset()
	var seen: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "reset opens on Free with five mercs and five contracts",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE
			and SubscriptionManager.max_mercs() == 5 and SubscriptionManager.max_contracts() == 5
			and int(seen["maxMercs"]) == 5 and int(seen["maxContracts"]) == 5,
		"%s %d/%d, laid %d" % [SubscriptionManager.plan_key(), SubscriptionManager.max_mercs(),
			SubscriptionManager.max_contracts(), int(seen["maxMercs"])])
	var owned: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		if SubscriptionManager.tier_of(id) != 0 or SubscriptionManager.prepaid_tier(id) != 0:
			owned.append(id)
	TestFixtures.check(res, "reset leaves every upgrade at tier 0 with nothing prepaid",
		bought and owned.is_empty() and SubscriptionManager.tiers().is_empty(),
		"bought %s, %s" % [bought, TestFixtures.detail(owned, UpgradeDefs.ORDER.size(), "upgrades")])
	var seat_bad: Array[String] = []
	for tier: int in range(1, UpgradeDefs.tier_count("seats") + 1):
		var seat_cap: int = UpgradeDefs.plan_max_mercs(SubscriptionManager.Plan.ENTERPRISE, tier)
		if UpgradeDefs.tier_text("seats", tier) != "+3 max mercenaries (%d)" % seat_cap:
			seat_bad.append(UpgradeDefs.tier_text("seats", tier))
	TestFixtures.check(res, "eight seat tiers add three mercs each, from 11 up to 32",
		seat_bad.is_empty() and UpgradeDefs.tier_count("seats") == 8
			and UpgradeDefs.tier_text("seats", 1) == "+3 max mercenaries (11)"
			and UpgradeDefs.tier_text("seats", 8) == "+3 max mercenaries (32)",
		TestFixtures.detail(seat_bad, UpgradeDefs.tier_count("seats"), "tiers"))
	var board_bad: Array[String] = []
	for tier: int in range(1, UpgradeDefs.tier_count("contracts") + 1):
		var board_cap: int = UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.ENTERPRISE, tier)
		if UpgradeDefs.tier_text("contracts", tier) != "+3 contract board slots (%d)" % board_cap:
			board_bad.append(UpgradeDefs.tier_text("contracts", tier))
	TestFixtures.check(res, "four contract tiers add three slots each, from 11 up to 20",
		board_bad.is_empty() and UpgradeDefs.tier_count("contracts") == 4
			and UpgradeDefs.tier_text("contracts", 1) == "+3 contract board slots (11)"
			and UpgradeDefs.tier_text("contracts", 4) == "+3 contract board slots (20)",
		TestFixtures.detail(board_bad, UpgradeDefs.tier_count("contracts"), "tiers"))
	TestFixtures.check(res, "the eighth seat tier bills 384 alone and 765 with the seven under it",
		SubscriptionManager.tier_price("seats", 8) == 384 and SubscriptionManager.tier_price("seats", 7) == 192
			and UpgradeDefs.monthly_of("seats", 8) == 765 and UpgradeDefs.monthly_of("contracts", 4) == 150,
		"tier 8 %d, seats %d, contracts %d" % [SubscriptionManager.tier_price("seats", 8),
			UpgradeDefs.monthly_of("seats", 8), UpgradeDefs.monthly_of("contracts", 4)])
	TestFixtures.check(res, "both numeral tables run to VIII",
		SubscriptionManager.roman(8) == "VIII" and SubscriptionManager.roman(9) == "9"
			and FeatureLock.roman(8) == "VIII" and FeatureLock.roman(9) == "9",
		"%s %s" % [SubscriptionManager.roman(8), FeatureLock.roman(8)])
	var specs: Array[String] = []
	for row: Array in [["free", 5, 5], ["pro", 8, 8], ["enterprise", 32, 20], ["bare", 8, 8]]:
		SubscriptionManager.apply_plan_spec(String(row[0]))
		var spec_mercs: int = SubscriptionManager.max_mercs()
		var spec_slots: int = SubscriptionManager.max_contracts()
		if spec_mercs != int(row[1]) or spec_slots != int(row[2]):
			specs.append("%s %d/%d" % [row[0], spec_mercs, spec_slots])
	TestFixtures.check(res, "the plan flag reads free 5/5, pro 8/8, enterprise 32/20 and bare 8/8",
		specs.is_empty() and SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
			and SubscriptionManager.tiers().is_empty(),
		TestFixtures.detail(specs, 4, "specs"))
	SubscriptionManager.apply_plan_spec("")
	TestFixtures.check(res, "no plan flag leaves the state alone",
		SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
			and SubscriptionManager.max_mercs() == 8 and SubscriptionManager.max_contracts() == 8,
		"%s %d/%d" % [SubscriptionManager.plan_key(), SubscriptionManager.max_mercs(),
			SubscriptionManager.max_contracts()])
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "the caps case has a roster to copy", false, "no mercs")
		return
	var per_merc: int = int(UpgradeDefs.plan_data(SubscriptionManager.Plan.ENTERPRISE).get(
		"per_merc", 0))
	var crew: Array[MercenaryData] = _caps_crew(3)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var whole: int = SubscriptionManager.employed()
	crew[0].is_dead = true
	TestFixtures.check(res, "a dead merc frees the seat and the fee at once",
		whole == 3 and SubscriptionManager.employed() == 2 and GameState.mercs.size() == 3
			and SubscriptionManager.service_fee() == per_merc * 2 and per_merc > 0,
		"employed %d of %d, fee %d" % [SubscriptionManager.employed(), whole,
			SubscriptionManager.service_fee()])
	MercPool.add_captive(crew[1], "Escort", "Aerdis", "Day 1")
	var held: bool = SalarySystem.is_captive(crew[1])
	var held_seats: int = SubscriptionManager.employed()
	var held_fee: int = SubscriptionManager.service_fee()
	MercPool.take_captive(crew[1].merc_uid)
	TestFixtures.check(res, "a captive keeps the seat and the fee until freed or lost",
		held and held_seats == 2 and held_fee == per_merc * 2,
		"held %s, employed %d, fee %d" % [held, held_seats, held_fee])
	crew = _caps_crew(UpgradeDefs.ENTERPRISE_MERCS)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var no_room: int = PromotionsManager.free_slots()
	crew[0].is_dead = true
	TestFixtures.check(res, "a death hands a hiring slot back while the roster still lists the dead",
		no_room == 0 and PromotionsManager.free_slots() == 1
			and GameState.mercs.size() == UpgradeDefs.ENTERPRISE_MERCS,
		"full %d, after %d" % [no_room, PromotionsManager.free_slots()])
	crew = _caps_crew(UpgradeDefs.ENTERPRISE_MERCS + 4)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2})
	var floor_all: int = SubscriptionManager.min_tier("seats")
	var lock_all: bool = SubscriptionManager.can_lower("seats")
	crew[0].is_dead = true
	TestFixtures.check(res, "the seat floor counts the living, so a death lets a tier go",
		floor_all == 2 and not lock_all and SubscriptionManager.min_tier("seats") == 1
			and SubscriptionManager.can_lower("seats"),
		"floor %d then %d" % [floor_all, SubscriptionManager.min_tier("seats")])
	crew = _caps_crew(UpgradeDefs.PRO_MERCS + 1)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 1})
	var refused: String = SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)
	crew[0].is_dead = true
	TestFixtures.check(res, "a switch to Pro is refused over eight mercs and allowed once one dies",
		refused == "You have 9 mercs. Mercday Pro allows up to 8."
			and SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO) == "",
		"first %s, then %s" % [refused, SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)])
	GuiTreeTests._set_board(9)
	var closed: Array[int] = [GuiTypes.ContractStatus.ACTIVE, GuiTypes.ContractStatus.ACTIVE,
		GuiTypes.ContractStatus.EXPIRED, GuiTypes.ContractStatus.COMPLETED,
		GuiTypes.ContractStatus.REJECTED, GuiTypes.ContractStatus.FAILED]
	for i: int in range(closed.size()):
		GameState.contracts[i].status = closed[i]
	TestFixtures.check(res, "the board counts open postings only, never runs or closed rows",
		SubscriptionManager.board_count() == 3 and GameState.contracts.size() == 9,
		"counted %d of %d" % [SubscriptionManager.board_count(), GameState.contracts.size()])
	GuiTreeTests._set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 3)
	for i: int in range(3):
		GameState.contracts[i].status = GuiTypes.ContractStatus.ACTIVE
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"contracts": 1})
	TestFixtures.check(res, "runs under way hold no contract tier in place",
		SubscriptionManager.board_count() == UpgradeDefs.ENTERPRISE_CONTRACTS
			and SubscriptionManager.min_tier("contracts") == 0 and SubscriptionManager.can_lower("contracts"),
		"board %d floor %d" % [SubscriptionManager.board_count(), SubscriptionManager.min_tier("contracts")])


#A roster of n living mercs, each with a uid of its own, so one can die or be held alone.
static func _caps_crew(n: int) -> Array[MercenaryData]:
	var template: MercenaryData = GameState.mercs[0]
	var crew: Array[MercenaryData] = []
	for i: int in range(n):
		var hand: MercenaryData = template.duplicate() as MercenaryData
		hand.merc_uid = CAPS_UID + i
		hand.is_dead = false
		crew.append(hand)
	GameState.mercs = crew
	return crew

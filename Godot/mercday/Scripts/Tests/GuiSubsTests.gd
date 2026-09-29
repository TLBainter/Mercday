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
#The Pro plan as the prototype writes it: plans 412 to 416 and planCards 589 of the handoff.
const PRO_ACCENT: String = "#f2d33d"
const PRO_INDEX: int = 1
const PRO_FEATURES: Array[String] = ["Up to 20 mercenaries", "Up to 12 contracts",
	"Advanced Merc Manager", "Advanced Contract Manager", "Advanced Finance Management",
	"Guild Metrics", "See some physical attributes of your mercenaries"]
const RING_CURRENT_HEX: String = "#6cc36a"
const RING_IDLE_HEX: String = "#1f3560"
#The payroll case builds its own crew, so every merc carries a uid of its own.
const FIRST_UID: int = 9001
const SEATS_TWO_FEE: int = 9


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var roster: Array[MercenaryData] = GameState.mercs.duplicate()
	var board: Array[ContractView] = GameState.contracts.duplicate()
	var bank: int = GameState.bank_notes
	_fresh()
	await host.get_tree().process_frame
	var viewer: SubscriptionViewer = VIEWER.instantiate() as SubscriptionViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	await _case_tabs(res, host, viewer)
	await _case_cards(res, host, viewer)
	await _case_dialog(res, host, viewer)
	_case_switch_rules(res)
	_case_billing(res)
	_case_charges(res)
	_case_limits(res)
	await _case_spend(res, host, viewer)
	_case_payroll_fee(res)
	GuiFrameStack.clear()
	viewer.queue_free()
	CampaignClock.minutes = clock
	GameState.mercs = roster
	GameState.contracts = board
	GameState.bank_notes = bank
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI SUBS")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()


#Resizes the payroll by repeating the first merc; only the count is read by the billing rules.
static func _set_crew(n: int) -> void:
	if GameState.mercs.is_empty():
		return
	var template: MercenaryData = GameState.mercs[0]
	while GameState.mercs.size() > maxi(1, n):
		GameState.mercs.remove_at(GameState.mercs.size() - 1)
	while GameState.mercs.size() < n:
		GameState.mercs.append(template)


#Fills the board with n listed contracts, which is what board_count() counts.
static func _set_board(n: int) -> void:
	GameState.contracts.clear()
	for i: int in range(n):
		var view: ContractView = ContractView.new()
		view.status = GuiTypes.ContractStatus.AVAILABLE
		GameState.contracts.append(view)


#Puts the clock on midnight of one day of one month of the first campaign year.
static func _set_day(month: int, day: int) -> void:
	var start: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, month)
	CampaignClock.minutes = start + (day - 1) * CampaignClock.MINUTES_PER_DAY


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
		not customize.is_locked() and not viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB).locked,
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
	TestFixtures.check(res, "tab_for names the button of each key",
		viewer.tab_for(SubscriptionViewer.PLANS_TAB) != viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB)
			and viewer.tab_for(SubscriptionViewer.PLANS_TAB).index == 0
			and viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB).index == 1,
		"indices %d and %d" % [viewer.tab_for(SubscriptionViewer.PLANS_TAB).index,
			viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB).index])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	var customize_tab: TabButton = viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB)
	TestFixtures.check(res, "the Customize tab locks below Enterprise",
		customize_tab.locked and customize.is_locked()
			and customize_tab.tooltip_text == SubscriptionViewer.CUSTOMIZE_LOCKED_TITLE,
		"tooltip %s" % [customize_tab.tooltip_text])
	TestFixtures.check(res, "the locked Customize page covers itself and names the plan",
		customize.lock.visible and customize.note_text() == CustomizePage.NOTE_LOCKED
			and customize.note_color().is_equal_approx(CustomizePage.NOTE_LOCKED_COLOR),
		"note %s" % [customize.note_text()])
	SubscriptionManager.reset()
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
	var exists: bool = ResourceLoader.exists(CustomizePage.TREE_PATH)
	TestFixtures.check(res, "the Customize page hosts the tree only once its scene exists",
		customize.has_tree() == exists and customize.focus_upgrade("seats", 1) == exists,
		"scene %s host %s" % [exists, customize.has_tree()])
	viewer.open_tab(SubscriptionViewer.PLANS_TAB)
	await host.get_tree().process_frame
	var open_tab: TabButton = viewer.tab_for(SubscriptionViewer.PLANS_TAB)
	var idle_tab: TabButton = viewer.tab_for(SubscriptionViewer.CUSTOMIZE_TAB)
	TestFixtures.check(res, "a resting icon tab keeps the idle box and hides its label",
		not idle_tab.label_always and not idle_tab.text_label.visible
			and idle_tab.custom_minimum_size.is_equal_approx(TabButton.IDLE_SIZE),
		"box %s label %s" % [idle_tab.custom_minimum_size, idle_tab.text_label.visible])
	TestFixtures.check(res, "the open tab shows its label and stands taller",
		open_tab.active and open_tab.text_label.visible and not open_tab.label_always
			and is_equal_approx(open_tab.custom_minimum_size.x, TabButton.IDLE_SIZE.x)
			and is_equal_approx(open_tab.custom_minimum_size.y, float(TabButton.ACTIVE_HEIGHT)),
		"box %s label %s" % [open_tab.custom_minimum_size, open_tab.text_label.visible])


#Case 2: the three plan cards, their prices and every reason one of them refuses a switch.
static func _case_cards(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var plans: PlansPage = viewer.plans_page()
	_set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.reset()
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
	TestFixtures.check(res, "the pro card builds one check row per prototype feature",
		rows.size() == PRO_FEATURES.size() and bad.is_empty(),
		TestFixtures.detail(bad, rows.size(), "rows"))
	var order: Array[String] = []
	for card: PlanCard in plans.cards():
		order.append("%s %d" % [card.plan_id, card.plan_index()])
	TestFixtures.check(res, "the cards keep the prototype's plan order",
		order == ["free 0", "pro 1", "enterprise 2"], "order %s" % [order])
	TestFixtures.check(res, "the ring reads green on the current plan and navy on the others",
		PlanCard.RING_CURRENT == Color(RING_CURRENT_HEX)
			and PlanCard.RING_IDLE == Color(RING_IDLE_HEX)
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
	_set_crew(8)
	viewer.refresh()
	TestFixtures.check(res, "a roster over the cap blocks the downgrade",
		not free_card.is_enabled()
			and free_card.reason_text()
				== "You must fire 3 mercs before you are eligible to downgrade"
			and free_card.button_tooltip() == "You have 8 mercs. Mercday Free allows up to 5.",
		"%s and %s" % [free_card.reason_text(), free_card.button_tooltip()])
	_set_crew(6)
	viewer.refresh()
	TestFixtures.check(res, "one merc over the cap reads as one merc",
		free_card.reason_text() == "You must fire 1 merc before you are eligible to downgrade",
		"reason %s" % [free_card.reason_text()])
	_set_crew(3)
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
	dialog.press_back()
	await host.get_tree().process_frame


#Case 3: the switch dialog in both directions, its sections, its price and its two answers.
static func _case_dialog(res: Dictionary, host: Node, viewer: SubscriptionViewer) -> void:
	await host.get_tree().process_frame
	var dialog: PlanSwitchDialog = viewer.dialog()
	var done: Array[int] = []
	var back: Array[int] = []
	var switched: Array[int] = []
	dialog.confirmed.connect(func(plan: int) -> void: done.append(plan))
	dialog.cancelled.connect(func() -> void: back.append(1))
	viewer.plan_switched.connect(func(plan: int) -> void: switched.append(plan))
	_set_crew(3)
	_set_board(4)
	_set_day(SHORT_MONTH, 1)
	GameState.bank_notes = RICH
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the upgrade dialog names the direction and the plan",
		not dialog.is_downgrade() and dialog.kind_text() == "Upgrade Plan"
			and dialog.ok_text() == "Upgrade"
			and dialog.ring_color().is_equal_approx(PlanSwitchDialog.RING_UP)
			and dialog.target_label.text == "Mercday Pro",
		"%s to %s" % [dialog.kind_text(), dialog.target_label.text])
	TestFixtures.check(res, "the upgrade dialog lists what the plan includes",
		dialog.sections() == ["Includes:"], "sections %s" % [dialog.sections()])
	TestFixtures.check(res, "the upgrade dialog prices one month of the target",
		dialog.fee() == 15
			and dialog.note_text() == "5 notes per merc, billed with Loans & Services on the 15th.",
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
	dialog.press_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dead confirm refuses the switch",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE and dialog.visible
			and done.is_empty(),
		"plan %d visible %s" % [SubscriptionManager.plan(), dialog.visible])
	dialog.press_back()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Back closes the dialog and reports it",
		not dialog.visible and back.size() == 1, "visible %s back %s" % [dialog.visible, back])
	GameState.bank_notes = RICH
	dialog.open_for(SubscriptionManager.Plan.PRO)
	await host.get_tree().process_frame
	dialog.press_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the live confirm switches the plan and reports it",
		SubscriptionManager.plan() == SubscriptionManager.Plan.PRO and not dialog.visible
			and done == [SubscriptionManager.Plan.PRO] and switched == [SubscriptionManager.Plan.PRO],
		"plan %d done %s switched %s" % [SubscriptionManager.plan(), done, switched])
	SubscriptionManager.reset()
	_set_board(9)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the downgrade dialog swaps the words and the ring",
		dialog.is_downgrade() and dialog.kind_text() == "Downgrade Plan"
			and dialog.ok_text() == "Downgrade"
			and dialog.ring_color().is_equal_approx(PlanSwitchDialog.RING_DOWN),
		"%s ring %s" % [dialog.kind_text(), dialog.ring_color()])
	TestFixtures.check(res, "a downgrade swaps the confirm to danger and Back to blue",
		dialog._link is BevelButton and dialog._link.kind == &"danger"
			and dialog._link.text == "Downgrade"
			and dialog._solid is BevelButton and dialog._solid.kind == &"blue"
			and dialog._solid.text == "Back",
		"link %s solid %s" % [dialog._link.kind, dialog._solid.kind])
	TestFixtures.check(res, "a free target carries no service fee",
		dialog.fee() == 0 and dialog.note_text() == "No service fee."
			and not dialog.cost_glyph.visible,
		"fee %d note %s" % [dialog.fee(), dialog.note_text()])
	var lose_head: String = ("You will lose access to the following upgrades and will have to"
		+ " purchase them individually again")
	var board_head: String = ("4 contracts will be removed from your board in %d Days if you proceed"
		% SubscriptionManager.days_to_bill())
	TestFixtures.check(res, "leaving Enterprise lists the upgrades that go",
		dialog.sections().has(lose_head) and not SubscriptionManager.owned_lines().is_empty(),
		"sections %s" % [dialog.sections()])
	TestFixtures.check(res, "a full board warns how many contracts leave and when",
		dialog.sections().has(board_head) and dialog.sections()[0] == board_head,
		"sections %s" % [dialog.sections()])
	TestFixtures.check(res, "the free board cap that warning counts against comes from the table",
		UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
				== UpgradeDefs.FREE_CONTRACTS
			and UpgradeDefs.FREE_CONTRACTS == 5,
		"cap %d" % [UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)])
	TestFixtures.check(res, "a downgrade never lists what the target includes",
		not dialog.sections().has("Includes:"), "sections %s" % [dialog.sections()])
	_set_board(4)
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a board inside the free cap raises no warning",
		not dialog.sections().has(board_head) and dialog.sections() == [lose_head],
		"sections %s" % [dialog.sections()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	dialog.open_for(SubscriptionManager.Plan.FREE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a downgrade with nothing to lose names the plan it leaves",
		dialog.sections() == ["You will lose the features of Mercday Enterprise."],
		"sections %s" % [dialog.sections()])
	dialog.press_back()
	await host.get_tree().process_frame


#Case 4: what SubscriptionManager allows a switch to cost and when it refuses one outright.
static func _case_switch_rules(res: Dictionary) -> void:
	_set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	TestFixtures.check(res, "the current plan refuses a switch to itself",
		not SubscriptionManager.can_switch(SubscriptionManager.Plan.PRO)
			and SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)
				== "This is your current plan",
		"reason %s" % [SubscriptionManager.switch_reason(SubscriptionManager.Plan.PRO)])
	_set_crew(8)
	TestFixtures.check(res, "a roster over the cap refuses the switch",
		SubscriptionManager.switch_reason(SubscriptionManager.Plan.FREE)
			== "You have 8 mercs. Mercday Free allows up to 5.",
		"reason %s" % [SubscriptionManager.switch_reason(SubscriptionManager.Plan.FREE)])
	_set_crew(3)
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
	SubscriptionManager.reset()
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
	_set_day(SHORT_MONTH, 7)
	TestFixtures.check(res, "day_of_month follows the game calendar",
		SubscriptionManager.day_of_month() == 7, "day %d" % SubscriptionManager.day_of_month())
	_set_day(SHORT_MONTH, 1)
	var first: int = SubscriptionManager.days_to_bill()
	_set_day(SHORT_MONTH, 14)
	TestFixtures.check(res, "days_to_bill counts down to the 15th",
		first == 14 and SubscriptionManager.days_to_bill() == 1,
		"day 1 reads %d, day 14 reads %d" % [first, SubscriptionManager.days_to_bill()])
	_set_day(SHORT_MONTH, SubscriptionManager.BILL_DAY)
	TestFixtures.check(res, "the 15th reads the whole short month ahead",
		SubscriptionManager.days_to_bill() == 30, "reads %d" % SubscriptionManager.days_to_bill())
	_set_day(SHORT_MONTH, 16)
	var after: int = SubscriptionManager.days_to_bill()
	_set_day(SHORT_MONTH, 30)
	TestFixtures.check(res, "days_to_bill counts through the end of a short month",
		after == 29 and SubscriptionManager.days_to_bill() == 15,
		"day 16 reads %d, day 30 reads %d" % [after, SubscriptionManager.days_to_bill()])
	_set_day(LONG_MONTH, SubscriptionManager.BILL_DAY)
	TestFixtures.check(res, "the 15th of a long month reads forty days ahead",
		SubscriptionManager.days_to_bill() == 40, "reads %d" % SubscriptionManager.days_to_bill())
	_set_day(LONG_MONTH, 16)
	var long_after: int = SubscriptionManager.days_to_bill()
	_set_day(LONG_MONTH, 40)
	TestFixtures.check(res, "days_to_bill counts through the end of a long month",
		long_after == 39 and SubscriptionManager.days_to_bill() == 15,
		"day 16 reads %d, day 40 reads %d" % [long_after, SubscriptionManager.days_to_bill()])


#Case 6: what one more tier costs today, pro-rated to the billing day and never charged twice.
static func _case_charges(res: Dictionary) -> void:
	_set_crew(3)
	GameState.bank_notes = RICH
	SubscriptionManager.reset()
	TestFixtures.check(res, "tier_price reads one tier without the tiers under it",
		SubscriptionManager.tier_price("seats", 1) == 3
			and SubscriptionManager.tier_price("seats", 3) == 12
			and SubscriptionManager.tier_price("seats", 0) == 0,
		"tier 3 costs %d" % SubscriptionManager.tier_price("seats", 3))
	_set_day(LONG_MONTH, SubscriptionManager.BILL_DAY)
	var over: Array[String] = []
	var counted: int = 0
	for id: String in UpgradeDefs.ORDER:
		for tier: int in range(1, UpgradeDefs.tier_count(id) + 1):
			counted += 1
			if (SubscriptionManager.upgrade_charge_today(id, tier)
					> SubscriptionManager.tier_price(id, tier)):
				over.append("%s %d" % [id, tier])
	TestFixtures.check(res, "a charge today never passes the month's price",
		over.is_empty(), TestFixtures.detail(over, counted, "tiers"))
	_set_day(SHORT_MONTH, SubscriptionManager.BILL_DAY)
	var short: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		for tier: int in range(1, UpgradeDefs.tier_count(id) + 1):
			if (SubscriptionManager.upgrade_charge_today(id, tier)
					!= SubscriptionManager.tier_price(id, tier)):
				short.append("%s %d" % [id, tier])
	TestFixtures.check(res, "the whole month is charged on the billing day",
		short.is_empty(), TestFixtures.detail(short, counted, "tiers"))
	_set_day(SHORT_MONTH, 14)
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
	_set_day(SHORT_MONTH, 14)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	_set_crew(UpgradeDefs.ENTERPRISE_MERCS)
	var seats_at_cap: int = SubscriptionManager.min_tier("seats")
	_set_crew(UpgradeDefs.ENTERPRISE_MERCS + 1)
	var seats_over: int = SubscriptionManager.min_tier("seats")
	_set_crew(UpgradeDefs.ENTERPRISE_MERCS + 5)
	var seats_full: int = SubscriptionManager.min_tier("seats")
	_set_crew(UpgradeDefs.ENTERPRISE_MERCS + 6)
	TestFixtures.check(res, "min_tier keeps the seats the roster is sitting in",
		seats_at_cap == 0 and seats_over == 1 and seats_full == 1
			and SubscriptionManager.min_tier("seats") == 2,
		"20 reads %d, 21 reads %d, 25 reads %d, 26 reads %d" % [seats_at_cap, seats_over,
			seats_full, SubscriptionManager.min_tier("seats")])
	_set_board(UpgradeDefs.ENTERPRISE_CONTRACTS)
	var board_at_cap: int = SubscriptionManager.min_tier("contracts")
	_set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 1)
	var board_over: int = SubscriptionManager.min_tier("contracts")
	_set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 2)
	var board_full: int = SubscriptionManager.min_tier("contracts")
	_set_board(UpgradeDefs.ENTERPRISE_CONTRACTS + 3)
	TestFixtures.check(res, "min_tier keeps the slots the board is using",
		board_at_cap == 0 and board_over == 1 and board_full == 1
			and SubscriptionManager.min_tier("contracts") == 2
			and SubscriptionManager.board_count() == 15,
		"12 reads %d, 13 reads %d, 14 reads %d, 15 reads %d" % [board_at_cap, board_over,
			board_full, SubscriptionManager.min_tier("contracts")])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"seats": 2, "contracts": 2})
	TestFixtures.check(res, "a seat tier the roster is using cannot be dropped",
		not SubscriptionManager.can_lower("seats")
			and SubscriptionManager.lower_reason("seats")
				== "Can't go below Tier 2: 26 mercs are using those seats.",
		"reason %s" % [SubscriptionManager.lower_reason("seats")])
	TestFixtures.check(res, "a contract tier the board is using cannot be dropped",
		not SubscriptionManager.can_lower("contracts")
			and SubscriptionManager.lower_reason("contracts")
				== "Can't go below Tier 2: 15 contracts are on your board.",
		"reason %s" % [SubscriptionManager.lower_reason("contracts")])
	_set_crew(3)
	_set_board(4)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"opspermit": 1, "representation": 2})
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
	_set_crew(3)
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
	SubscriptionManager.reset()
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

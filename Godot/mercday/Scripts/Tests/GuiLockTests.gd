class_name GuiLockTests extends RefCounted

#Suite for the lock family: GuiColors, the lock glyph, NotificationDot, FeatureLock,
#FeatureLockDialog, LockedPage, and the locked/dot additions on TabButton and GridMenuButton.
#Flag --gui-lock-tests.

const FEATURE_LOCK := preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const LOCKED_PAGE := preload("res://Scenes/GUI/Shared/LockedPage.tscn")
const TAB_BUTTON := preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const GRID_MENU_BUTTON := preload("res://Scenes/GUI/Shared/GridMenuButton.tscn")
const NOTIFICATION_DOT := preload("res://Scenes/GUI/Shared/NotificationDot.tscn")
const TEST_UPGRADE := "oddjobs"
#Gate keys of SubscriptionManager.entitlements(): a flag, a tier count, and a key it never holds.
const FLAG_KEY := "bazaar"
const TIER_KEY := "oddJobs"
const MISSING_KEY := "noSuchEntitlementKey"

#Every icon the handoff package named, as the atlas id its screen draws now.
const ICON_IDS: Array[String] = [
	"magnifier", "cart", "parcel", "shop", "direct_sale", "flyers", "radio", "sponsorship",
	"wom", "whistle", "mercday", "bazaar_cat", "bazaar_node", "better_items", "counsel",
	"faster_items", "legal_cat", "less_legal", "odd_jobs", "ops_permit", "representation",
	"teleport", "who_knows", "add_person", "eye", "bazaar", "legal", "promotions", "bail_bars",
	"coin", "permit", "contracts", "guild_banner", "mercs", "pip_ancestral", "pip_auto",
	"pip_defensive", "pip_existing", "pip_new", "pip_offensive", "pip_random", "pip_skills",
	"pip_spell", "pip_stats", "pip_support", "pip_tradition", "pip_universal", "pip_utility",
	"guild_ads", "job_ads",
]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	_case_gui_colors(res)
	_case_lock_glyph(res)
	await _case_notification_dot(res, host)
	await _case_feature_lock(res, host)
	await _case_lock_gate(res, host)
	await _case_lock_open_default(res, host)
	await _case_locked_page(res, host)
	await _case_tab_button(res, host)
	await _case_grid_menu_button(res, host)
	_case_icons(res)
	SubscriptionManager.reset()
	return TestFixtures.summarize(res, "GUI LOCK")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	_reset_subscription()


#The bare baseline: Enterprise with no upgrade tier and no override, so a tier read starts at 0.
static func _reset_subscription() -> void:
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})


static func _case_gui_colors(res: Dictionary) -> void:
	TestFixtures.check(res, "tier_color reaches red at the first rank",
		GuiColors.tier_color(0, 5).is_equal_approx(GuiColors.RAMP_RED),
		"got %s" % GuiColors.tier_color(0, 5))
	TestFixtures.check(res, "tier_color reaches green at the last rank",
		GuiColors.tier_color(4, 5).is_equal_approx(GuiColors.RAMP_GREEN),
		"got %s" % GuiColors.tier_color(4, 5))
	TestFixtures.check(res, "tier_color reads green when n is one or less",
		GuiColors.tier_color(0, 1).is_equal_approx(GuiColors.RAMP_GREEN),
		"got %s" % GuiColors.tier_color(0, 1))
	var cat_lo: Color = GuiColors.cat_color(0.0)
	var cat_hi: Color = GuiColors.cat_color(1.0)
	TestFixtures.check(res, "cat_color dims the ramp toward black at zero",
		is_equal_approx(cat_lo.r, GuiColors.RAMP_RED.r * 0.30),
		"got %.4f want %.4f" % [cat_lo.r, GuiColors.RAMP_RED.r * 0.30])
	TestFixtures.check(res, "cat_color reaches full brightness at one",
		cat_hi.is_equal_approx(GuiColors.RAMP_GREEN),
		"got %s" % cat_hi)
	var gate_lo: Color = GuiColors.gate_color(0.0)
	TestFixtures.check(res, "gate_color keeps more brightness than cat_color at zero",
		is_equal_approx(gate_lo.r, GuiColors.RAMP_RED.r * 0.55),
		"got %.4f want %.4f" % [gate_lo.r, GuiColors.RAMP_RED.r * 0.55])
	var mixed: Color = GuiColors.mix([GuiColors.RAMP_RED, GuiColors.RAMP_GREEN])
	TestFixtures.check(res, "mix averages the channels of every colour given",
		is_equal_approx(mixed.r, (GuiColors.RAMP_RED.r + GuiColors.RAMP_GREEN.r) / 2.0),
		"got %.4f" % mixed.r)
	var empty_mix: Array[Color] = []
	TestFixtures.check(res, "mix falls back to white with nothing to average",
		GuiColors.mix(empty_mix) == Color.WHITE, "got %s" % GuiColors.mix(empty_mix))


static func _case_lock_glyph(res: Dictionary) -> void:
	var tex: ImageTexture = GuiGlyphs.lock(Color.WHITE, 3)
	TestFixtures.check(res, "the lock glyph scales to 24 by 27",
		tex.get_size() == Vector2(24, 27), str(tex.get_size()))
	var img: Image = tex.get_image()
	var lit: int = 0
	var pure: int = 0
	var tinted_bad: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			lit += 1
			if px.r >= 1.0 and px.g >= 1.0 and px.b >= 1.0:
				pure += 1
			elif not (is_equal_approx(px.r, px.g) and is_equal_approx(px.g, px.b)):
				tinted_bad += 1
	TestFixtures.check(res, "a white tint paints the lock art white",
		lit > 0 and pure > 0 and tinted_bad == 0,
		"lit %d pure %d off %d" % [lit, pure, tinted_bad])
	var cached_again: ImageTexture = GuiGlyphs.lock(Color.WHITE, 3)
	TestFixtures.check(res, "the lock glyph is cached by colour and scale",
		tex == cached_again, "distinct instances returned for the same key")
	TestFixtures.check(res, "the check glyph is 11 by 10",
		GuiGlyphs.check(Color.WHITE).get_size() == Vector2(11, 10),
		str(GuiGlyphs.check(Color.WHITE).get_size()))
	TestFixtures.check(res, "the cross glyph is 10 by 10",
		GuiGlyphs.cross(Color.WHITE).get_size() == Vector2(10, 10),
		str(GuiGlyphs.cross(Color.WHITE).get_size()))
	TestFixtures.check(res, "the funnel glyph is 10 by 10",
		GuiGlyphs.funnel(Color.WHITE).get_size() == Vector2(10, 10),
		str(GuiGlyphs.funnel(Color.WHITE).get_size()))


static func _case_notification_dot(res: Dictionary, host: Node) -> void:
	var dot: NotificationDot = NOTIFICATION_DOT.instantiate()
	host.add_child(dot)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a notification dot carries its whole 28x28 ring box",
		dot.size == NotificationDot.FRAME_SIZE
			and dot.custom_minimum_size == NotificationDot.FRAME_SIZE
			and dot.z_index == NotificationDot.DOT_Z,
		"size %s minimum %s z %d" % [dot.size, dot.custom_minimum_size, dot.z_index])
	dot.on = false
	TestFixtures.check(res, "on false hides the dot", not dot.visible, "visible was %s" % dot.visible)
	dot.on = true
	TestFixtures.check(res, "on true shows the dot", dot.visible, "visible was %s" % dot.visible)
	var host_control: Control = Control.new()
	host_control.size = Vector2(100, 100)
	host.add_child(host_control)
	var attached: NotificationDot = NotificationDot.attach(host_control)
	TestFixtures.check(res, "attach pins the whole dot inside the host's top-right corner",
		attached.anchor_left == 1.0 and attached.anchor_right == 1.0
			and attached.anchor_top == 0.0 and attached.anchor_bottom == 0.0
			and attached.offset_right == -2.0 and attached.offset_left == -30.0
			and attached.offset_top == 2.0 and attached.offset_bottom == 30.0,
		"anchors %s,%s offsets %s,%s,%s,%s" % [attached.anchor_left, attached.anchor_top,
			attached.offset_left, attached.offset_top, attached.offset_right,
			attached.offset_bottom])
	dot.queue_free()
	host_control.queue_free()


static func _case_feature_lock(res: Dictionary, host: Node) -> void:
	var lock: FeatureLock = FEATURE_LOCK.instantiate()
	host.add_child(lock)
	await host.get_tree().process_frame
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	TestFixtures.check(res, "a free plan locks a feature that names Enterprise",
		lock.locked(), "locked() was %s" % lock.locked())
	SubscriptionManager.set_plan(SubscriptionManager.Plan.ENTERPRISE)
	TestFixtures.check(res, "an enterprise plan unlocks a plain feature",
		not lock.locked(), "locked() was %s" % lock.locked())
	TestFixtures.check(res, "an unlocked, non-pinned control hides itself",
		not lock.visible, "visible was %s" % lock.visible)
	lock.upgrade_id = TEST_UPGRADE
	lock.tier = 2
	var short_tier: bool = SubscriptionManager.set_tier(TEST_UPGRADE, 1)
	TestFixtures.check(res, "a short upgrade tier still locks the feature",
		short_tier and lock.locked(),
		"set_tier %s, locked() was %s" % [short_tier, lock.locked()])
	var full_tier: bool = SubscriptionManager.set_tier(TEST_UPGRADE, 2)
	TestFixtures.check(res, "reaching the required tier unlocks the feature",
		full_tier and not lock.locked(),
		"set_tier %s, locked() was %s" % [full_tier, lock.locked()])
	lock.upgrade_id = ""
	TestFixtures.check(res, "icon mode is a square the height of the control",
		is_equal_approx(lock.custom_minimum_size.x, lock.height)
			and is_equal_approx(lock.custom_minimum_size.y, lock.height),
		"got %s want %.1f" % [lock.custom_minimum_size, lock.height])
	TestFixtures.check(res, "icon mode's text label stays hidden",
		not lock.text_label.visible, "visible was %s" % lock.text_label.visible)
	lock.label = "Bazaar"
	TestFixtures.check(res, "label mode shows the given text",
		lock.text_label.visible and lock.text_label.text == "Bazaar",
		"visible %s text '%s'" % [lock.text_label.visible, lock.text_label.text])
	TestFixtures.check(res, "label mode's text reads the locked palette",
		lock.text_label.get_theme_color("font_color").is_equal_approx(GuiColors.LOCKED_TEXT),
		"got %s" % lock.text_label.get_theme_color("font_color"))
	lock.label = ""
	var plan_lines: Array[String] = FeatureLock.build_copy("the Bazaar", "Mercday Pro", "", "",
		1, 1, "view")
	TestFixtures.check(res, "plan copy names the plan and the feature",
		plan_lines[0] == "This feature of Mercday is not available on your plan!"
			and plan_lines[1] == "Upgrade to Mercday Pro to view the Bazaar.",
		"got %s" % [plan_lines])
	SubscriptionManager.set_plan(SubscriptionManager.Plan.ENTERPRISE)
	var upgrade_lines: Array[String] = FeatureLock.build_copy("the Bazaar", "Mercday Enterprise",
		"Faster Items", "faster_items", 2, 3, "use")
	TestFixtures.check(res, "upgrade copy names the tier and the upgrade",
		upgrade_lines[0] == "the Bazaar is locked."
			and upgrade_lines[1] == "It requires the Tier II Faster Items upgrade!",
		"got %s" % [upgrade_lines])
	var plain_lines: Array[String] = FeatureLock.build_copy("Promotions",
		"Mercday Enterprise", "Promotions", "promotions", 1, 1, "use")
	TestFixtures.check(res, "the default end mark closes both upgrade lines with a bang",
		upgrade_lines[1].ends_with("upgrade!")
			and plain_lines[1] == "It requires the Promotions upgrade!",
		"got %s" % [plain_lines])
	var dot_tiered: Array[String] = FeatureLock.build_copy("the Bazaar",
		"Mercday Enterprise", "Faster Items", "faster_items", 2, 3, "use", ".")
	var dot_plain: Array[String] = FeatureLock.build_copy("Promotions",
		"Mercday Enterprise", "Promotions", "promotions", 1, 1, "use", ".")
	TestFixtures.check(res, "an end mark of a period closes both upgrade lines with a period",
		dot_tiered[1] == "It requires the Tier II Faster Items upgrade."
			and dot_plain[1] == "It requires the Promotions upgrade.",
		"got %s / %s" % [dot_tiered[1], dot_plain[1]])
	lock.upgrade = "Promotions"
	lock.upgrade_id = "promotions"
	lock.tiers = 1
	lock.tier = 1
	lock.upgrade_end = "."
	TestFixtures.check(res, "the upgrade_end export reaches the lock's own copy",
		lock.copy_lines()[1] == "It requires the Promotions upgrade.",
		"got %s" % [lock.copy_lines()])
	lock.upgrade_end = "!"
	lock.upgrade = ""
	var depth_before: int = GuiFrameStack.depth()
	lock.upgrade_id = TEST_UPGRADE
	lock.tier = 1
	var cleared_tier: bool = SubscriptionManager.set_tier(TEST_UPGRADE, 0)
	TestFixtures.check(res, "dropping the upgrade tier back to nothing locks the feature again",
		cleared_tier and lock.locked(),
		"set_tier %s, locked() was %s" % [cleared_tier, lock.locked()])
	lock.pressed.emit()
	await host.get_tree().process_frame
	var dialog: FeatureLockDialog = GuiFrameStack.top() as FeatureLockDialog
	TestFixtures.check(res, "pressing the lock opens the dialog on the frame stack",
		GuiFrameStack.depth() == depth_before + 1 and dialog != null,
		"depth %d top %s" % [GuiFrameStack.depth(), GuiFrameStack.top()])
	var heard: Array = []
	var handler := func(target: Dictionary) -> void: heard.append(target)
	GameState.go_to_plans_requested.connect(handler)
	if dialog != null:
		dialog.press_take_me_there()
	TestFixtures.check(res, "take me there hands off the customize target and calls go_to_plans",
		heard.size() == 1 and heard[0].get("tab") == "customize"
			and heard[0].get("upgrade") == TEST_UPGRADE and heard[0].get("tier") == 1,
		"got %s" % [heard])
	TestFixtures.check(res, "take me there closes the dialog and pops the frame stack",
		GuiFrameStack.depth() == depth_before, "depth %d" % GuiFrameStack.depth())
	GameState.go_to_plans_requested.disconnect(handler)
	lock.queue_free()
	_reset_subscription()


#The entitlement gate and the width a host asks for. A key answers on its own; with no key the plan
#rank and the upgrade tier answer.
static func _case_lock_gate(res: Dictionary, host: Node) -> void:
	var lock: FeatureLock = FEATURE_LOCK.instantiate()
	host.add_child(lock)
	await host.get_tree().process_frame
	lock.always_visible = true
	TestFixtures.check(res, "a min_width of zero leaves icon mode a square of the height",
		is_equal_approx(lock.custom_minimum_size.x, lock.height),
		"got %.1f want %.1f" % [lock.custom_minimum_size.x, lock.height])
	lock.min_width = 150.0
	TestFixtures.check(res, "min_width widens icon mode to the asked width",
		is_equal_approx(lock.custom_minimum_size.x, 150.0),
		"got %.1f" % lock.custom_minimum_size.x)
	lock.label = "Locked"
	TestFixtures.check(res, "label mode keeps the asked width",
		is_equal_approx(lock.custom_minimum_size.x, 150.0)
			and is_equal_approx(lock.custom_minimum_size.y, lock.height),
		"got %s" % lock.custom_minimum_size)
	lock.feature = "Odd Jobs"
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	TestFixtures.check(res, "a later refresh keeps the width the host asked for",
		is_equal_approx(lock.custom_minimum_size.x, 150.0),
		"got %.1f" % lock.custom_minimum_size.x)
	lock.label = ""
	lock.min_width = 0.0
	TestFixtures.check(res, "clearing min_width returns icon mode to its square",
		is_equal_approx(lock.custom_minimum_size.x, lock.height),
		"got %.1f want %.1f" % [lock.custom_minimum_size.x, lock.height])
	lock.entitlement = FLAG_KEY
	SubscriptionManager.set_entitlements({FLAG_KEY: false})
	TestFixtures.check(res, "a flag key that reads false locks the feature",
		lock.locked(), "locked() was %s" % lock.locked())
	SubscriptionManager.set_entitlements({FLAG_KEY: true})
	TestFixtures.check(res, "an override opens the feature although the plan is free",
		SubscriptionManager.plan() == SubscriptionManager.Plan.FREE and not lock.locked(),
		"plan %d locked() %s" % [SubscriptionManager.plan(), lock.locked()])
	lock.entitlement = TIER_KEY
	lock.entitlement_tier = 2
	SubscriptionManager.set_entitlements({TIER_KEY: 1})
	TestFixtures.check(res, "a numeric key below entitlement_tier locks the feature",
		lock.locked(), "locked() was %s" % lock.locked())
	SubscriptionManager.set_entitlements({TIER_KEY: 2})
	TestFixtures.check(res, "a numeric key at entitlement_tier opens the feature",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.entitlement_tier = 0
	lock.tier = 3
	TestFixtures.check(res, "entitlement_tier of zero reads the tier export instead",
		lock.wanted_tier() == 3 and lock.locked(),
		"wanted %d locked() %s" % [lock.wanted_tier(), lock.locked()])
	SubscriptionManager.set_entitlements({TIER_KEY: 3})
	TestFixtures.check(res, "reaching the tier export opens the feature",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.entitlement = MISSING_KEY
	SubscriptionManager.reset()
	TestFixtures.check(res, "a key entitlements() does not carry stays locked",
		not SubscriptionManager.entitlements().has(MISSING_KEY) and lock.locked(),
		"locked() was %s" % lock.locked())
	lock.entitlement = ""
	lock.upgrade_id = ""
	lock.tier = 1
	_reset_subscription()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	lock.required_plan = SubscriptionManager.Plan.FREE
	TestFixtures.check(res, "required_plan free leaves the feature open on the free plan",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.required_plan = SubscriptionManager.Plan.PRO
	TestFixtures.check(res, "required_plan pro locks the feature on the free plan",
		lock.locked(), "locked() was %s" % lock.locked())
	SubscriptionManager.set_plan(SubscriptionManager.Plan.PRO)
	TestFixtures.check(res, "required_plan pro opens the feature on the pro plan",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.required_plan = SubscriptionManager.Plan.ENTERPRISE
	TestFixtures.check(res, "required_plan enterprise locks the feature on the pro plan",
		lock.locked(), "locked() was %s" % lock.locked())
	SubscriptionManager.set_plan(SubscriptionManager.Plan.ENTERPRISE)
	TestFixtures.check(res, "required_plan enterprise opens the feature on the enterprise plan",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.queue_free()
	_reset_subscription()


#A lock that names no key, no upgrade and no plan text gates nothing on the free plan; naming
#a plan or an unowned upgrade locks it again (GX4F-05).
static func _case_lock_open_default(res: Dictionary, host: Node) -> void:
	var lock: FeatureLock = FEATURE_LOCK.instantiate()
	host.add_child(lock)
	await host.get_tree().process_frame
	_reset_subscription()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	lock.plan = ""
	TestFixtures.check(res, "a lock that names no gate reads open on the free plan",
		not lock.locked(), "locked() was %s" % lock.locked())
	lock.plan = "Mercday Enterprise"
	TestFixtures.check(res, "plan text alone locks through the required_plan default",
		lock.locked(), "locked() was %s" % lock.locked())
	lock.plan = ""
	lock.upgrade_id = TEST_UPGRADE
	lock.tier = 1
	TestFixtures.check(res, "an upgrade alone locks until it is owned",
		lock.locked(), "locked() was %s" % lock.locked())
	lock.queue_free()
	_reset_subscription()


static func _case_locked_page(res: Dictionary, host: Node) -> void:
	var page: LockedPage = LOCKED_PAGE.instantiate()
	host.add_child(page)
	await host.get_tree().process_frame
	page.feature = "the Bazaar"
	page.plan = "Mercday Pro"
	page.verb = "view"
	var lines: Array[String] = FeatureLock.build_copy(page.feature, page.plan, page.upgrade,
		page.upgrade_id, page.tier, page.tiers, page.verb)
	TestFixtures.check(res, "LockedPage copy follows the same rule as FeatureLock",
		page.line1_label.text == lines[0] and page.line2_label.text == lines[1],
		"got '%s' / '%s'" % [page.line1_label.text, page.line2_label.text])
	TestFixtures.check(res, "target reads plans when the guild holds no matching upgrade",
		page.target().get("tab") == "plans", "got %s" % page.target())
	SubscriptionManager.set_plan(SubscriptionManager.Plan.ENTERPRISE)
	page.upgrade_id = TEST_UPGRADE
	page.tier = 3
	TestFixtures.check(res, "target reads customize once the plan covers Enterprise",
		page.target().get("tab") == "customize" and page.target().get("upgrade") == TEST_UPGRADE
			and page.target().get("tier") == 3,
		"got %s" % page.target())
	var heard: Array = []
	var handler := func(target: Dictionary) -> void: heard.append(target)
	GameState.go_to_plans_requested.connect(handler)
	page.press_take_me_there()
	TestFixtures.check(res, "pressing take me there on LockedPage calls go_to_plans",
		heard.size() == 1 and heard[0].get("tab") == "customize", "got %s" % [heard])
	GameState.go_to_plans_requested.disconnect(handler)
	page.queue_free()
	_reset_subscription()


static func _case_tab_button(res: Dictionary, host: Node) -> void:
	var tab: TabButton = TAB_BUTTON.instantiate()
	host.add_child(tab)
	await host.get_tree().process_frame
	tab.icon_cols = 16
	tab.icon_px = 1.5
	TestFixtures.check(res, "a 16 column, 1.5 px icon box comes out 24x24",
		tab.icon_rect.custom_minimum_size == Vector2(24, 24),
		"got %s" % tab.icon_rect.custom_minimum_size)
	tab.badge = 3
	TestFixtures.check(res, "a positive badge shows its count",
		tab.badge_panel.visible and tab.badge_label.text == "3",
		"visible %s text '%s'" % [tab.badge_panel.visible, tab.badge_label.text])
	var badge_style: StyleBoxFlat = tab.badge_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "the badge colour defaults to BADGE_BG, every tab of today's look",
		tab.badge_color == TabButton.BADGE_BG
		and badge_style.bg_color.is_equal_approx(TabButton.BADGE_BG),
		"colour %s, style %s" % [tab.badge_color, badge_style.bg_color])
	tab.badge_color = Color("#f28c28")
	badge_style = tab.badge_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "a changed badge_color reaches the rendered badge style",
		badge_style.bg_color.is_equal_approx(Color("#f28c28")), "got %s" % badge_style.bg_color)
	tab.badge_color = TabButton.BADGE_BG
	tab.dot = true
	TestFixtures.check(res, "dot hides the badge (the two are exclusive)",
		not tab.badge_panel.visible and tab.dot_node.visible,
		"badge %s dot %s" % [tab.badge_panel.visible, tab.dot_node.visible])
	tab.dot = false
	tab.icon_id = "lock"
	tab.locked = true
	TestFixtures.check(res, "locked draws the lock glyph over the icon",
		tab.lock_overlay.visible, "visible was %s" % tab.lock_overlay.visible)
	TestFixtures.check(res, "locked sets the tooltip to Locked",
		tab.tooltip_text == "Locked", "got '%s'" % tab.tooltip_text)
	var heard: Array = []
	tab.tab_pressed.connect(func(i: int) -> void: heard.append(i))
	tab.index = 4
	tab.pressed.emit()
	TestFixtures.check(res, "a locked tab still emits tab_pressed",
		heard.size() == 1 and heard[0] == 4, "got %s" % [heard])
	tab.queue_free()


static func _case_grid_menu_button(res: Dictionary, host: Node) -> void:
	var btn: GridMenuButton = GRID_MENU_BUTTON.instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	var opened_heard: Array = []
	var locked_heard: Array = []
	btn.opened.connect(func(s: PackedScene) -> void: opened_heard.append(s))
	btn.locked_pressed.connect(func() -> void: locked_heard.append(true))
	btn.locked = true
	btn.locked_tooltip = "Locked"
	btn.description = "Opens the bazaar"
	TestFixtures.check(res, "locked swaps the tooltip for locked_tooltip",
		btn.tooltip_text == "Locked", "got '%s'" % btn.tooltip_text)
	TestFixtures.check(res, "locked greys the label",
		btn.text_color().is_equal_approx(GuiColors.LOCKED_TEXT), "got %s" % btn.text_color())
	btn.pressed.emit()
	TestFixtures.check(res, "pressing a locked tile emits locked_pressed and never opened",
		locked_heard.size() == 1 and opened_heard.is_empty(),
		"locked_heard %d opened_heard %s" % [locked_heard.size(), opened_heard])
	btn.hover(true)
	TestFixtures.check(res, "hover raises the tile above its neighbours",
		btn.z_index == GridMenuButton.HOVER_Z_INDEX, "got %d" % btn.z_index)
	btn.hover(false)
	TestFixtures.check(res, "leaving restores the tile to its own layer",
		btn.z_index == 0, "got %d" % btn.z_index)
	btn.locked = false
	btn.dot = true
	var dot_top_alone: float = btn.dot_node.offset_top
	btn.pressed.emit()
	TestFixtures.check(res, "unlocked presses reach opened again",
		opened_heard.size() == 1, "got %s" % [opened_heard])
	btn.locked = true
	TestFixtures.check(res, "the dot moves below the lock badge once both show",
		btn.dot_node.offset_top > dot_top_alone,
		"alone %.1f with badge %.1f" % [dot_top_alone, btn.dot_node.offset_top])
	btn.queue_free()


static func _case_icons(res: Dictionary) -> void:
	var bad: Array[String] = []
	for id: String in ICON_IDS:
		if not Icons.has(id) or Icons.tex(id) == null:
			bad.append(id)
	TestFixtures.check(res, "every handoff icon is a cell of the icon sheet",
		bad.is_empty(), TestFixtures.detail(bad, ICON_IDS.size(), "icons"))
	var loose: Array[String] = []
	var dir: DirAccess = DirAccess.open(Icons.ATLAS_PATH.get_base_dir())
	if dir != null:
		for file: String in dir.get_files():
			var name: String = file.trim_suffix(".import")
			if not name.ends_with(".png") or name == Icons.ATLAS_PATH.get_file():
				continue
			if not loose.has(name):
				loose.append(name)
	TestFixtures.check(res, "Art/GUI/Icons holds no loose icon PNG", loose.is_empty(),
		TestFixtures.detail(loose, loose.size(), "loose png"))

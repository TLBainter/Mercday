class_name GuiClickJATests
extends RefCounted

#README Part J, steps 1 to 8, driven headless through the real screens: the Customize tree,
#the HUD lock on My Promotions, the two ad tabs and the New Campaign builder. A synthetic
#click never reaches a button headless, so every step calls the press helper the button
#handler calls. The README line of a step stands above its case.

const TREE: PackedScene = preload("res://Scenes/GUI/Subscription/SkillTree.tscn")
const VIEWER: PackedScene = preload("res://Scenes/GUI/Promotions/PromotionsViewer.tscn")
const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const BANK: int = 20000
#README I1: a finished category box reads bg #123321 with the full progress green ring.
const DONE_BG: Color = Color("#123321")
#README J5: the day caps Long Promos tiers 0 to 4 hand the builder; tier 5 lifts the cap.
const DAY_CAPS: Array[int] = [5, 10, 17, 25, 30]
#README J1: the combined Promo Methods and Marketing Agency tiers Guild Promo waits on.
const GUILD_PROMO_NEED: int = 5
#README J6: the Effect column of the five methods with no Marketing Agency.
const BASE_EFFECTS: Array[String] = ["Varies", "2%", "9%", "12%", "15%"]
#README J6: Flyers reads 2.5 percent at plus 25 percent.
const BOOST_TOP: int = 25
const FLYERS_BOOSTED: String = "2.5%"
#README J7: the three towns no radio mast reaches.
const NO_RADIO_TOWNS: Array[String] = ["Buern", "Rossade", "Vaernebo"]
#README J7: Buern has no radio mast but Sponsorship can still reach it.
const BUERN_LOC: int = 0
#README E1 and I2: the copy of the locked My Promotions tile.
const LOCK_LINE1: String = "Promotions is locked."
const LOCK_LINE2: String = "It requires the Promotions upgrade."
#README 464: the box and its line back to Base read this orange once a tier drops below full.
const ORANGE: Color = Color("#f28c28")
#README 506: "Top-right hint "Up to N days" / "No limit"."
const HINT_UP_TO: String = "Up to %d days"
const HINT_NO_LIMIT: String = "No limit"
#README 507: "Infinite: stepper disabled (opacity 0.35 ...)."
const INFINITE_ALPHA_DESIGN: float = 0.35
#README 506: "qty max = floor(min(cap,30) / unit_days) (Weeks 7, Months 30)."
#At the 17-day cap (Long Promos tier II) floor(17/7) is Weeks 2; Months stays locked until
#Long Promos tier IV, so no Months quantity applies at this tier.
const WEEKS_AT_17: int = 2
#README 506: at the top tier the 30-day ceiling gives Days 30, Weeks floor(30/7)=4 and
#Months floor(30/30)=1.
const TOP_DAYS_MAX: int = 30
const TOP_WEEKS_MAX: int = 4
const TOP_MONTHS_MAX: int = 1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	_fresh()
	var tree: SkillTree = TREE.instantiate() as SkillTree
	host.add_child(tree)
	var viewer: PromotionsViewer = VIEWER.instantiate() as PromotionsViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	_case_j01_column(res, tree)
	_case_j01_guild_gate(res, tree)
	_case_j02_limits_green(res, tree)
	_case_j02_shared_stem(res, tree)
	await _case_j03_hud_lock(res, host)
	_case_j04_tabs(res, viewer)
	_case_j04_types(res, viewer)
	_case_j05_caps(res, viewer)
	_case_j05_unit_locks(res, viewer)
	_case_j05_infinite(res, viewer)
	_case_j06_boost(res, viewer)
	_case_j07_targets(res, viewer)
	_case_j08_guild_tiers(res, viewer)
	GuiFrameStack.clear()
	viewer.queue_free()
	tree.queue_free()
	CampaignClock.minutes = clock
	LegalManager.reset()
	PromotionsManager.reset()
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI CLICK JA")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	LegalManager.reset()
	PromotionsManager.reset()
	GameState.bank_notes = BANK


#Enterprise holding exactly the tiers the step names. reset() runs first, because set_state
#keeps an entitlement override an earlier case may have left behind.
static func _plan_with(tiers: Dictionary) -> void:
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, tiers)


static func _all_max() -> Dictionary:
	var out: Dictionary = {}
	for id: String in UpgradeDefs.ORDER:
		out[id] = UpgradeDefs.tier_count(id)
	return out


#The colour of the connector whose last point sits on the given spot.
static func _color_into(lines: Array[Dictionary], target: Vector2) -> Color:
	for row: Dictionary in lines:
		var points: PackedVector2Array = row["points"]
		if points.size() > 0 and points[points.size() - 1].is_equal_approx(target):
			var last: Color = row["color_b"]
			return last
	return Color(0.0, 0.0, 0.0, 0.0)


#The colour of the connector that starts on the given spot.
static func _color_from(lines: Array[Dictionary], start: Vector2) -> Color:
	for row: Dictionary in lines:
		var points: PackedVector2Array = row["points"]
		if points.size() > 0 and points[0].is_equal_approx(start):
			var first: Color = row["color_a"]
			return first
	return Color(0.0, 0.0, 0.0, 0.0)


static func _arm_of(cat: String) -> Vector2:
	var g: Dictionary = TreeLayout.geo(cat)
	return Vector2(float(g["r"]), float(g["cy"]))


static func _stem_start() -> Vector2:
	var bg: Dictionary = TreeLayout.geo("base")
	return Vector2(float(bg["cx"]) - TreeLayout.SIDE_EXIT, float(bg["b"]))


static func _top_arm_of(cat: String) -> Vector2:
	var g: Dictionary = TreeLayout.geo(cat)
	return Vector2(float(g["cx"]), float(g["t"]))


#Every town gets its Operations Permit, so the only note a location card can carry is the
#radio note of the step. On a fresh game two towns hold a permit and seven do not.
static func _grant_permits() -> void:
	for i: int in range(TraitFilterDefs.LOCATION_COUNT):
		LegalManager.permits[i] = {"ops": true, "tele": true}


static func _ads_row() -> int:
	for row: Dictionary in FinanceLedger.expense_breakdown():
		if String(row["key"]) == "ads":
			return int(row["amount"])
	return -1


static func _check_boxes(guild: GuildTargeting, key: StringName, count: int) -> Array[String]:
	var missing: Array[String] = []
	var want: Vector2 = Vector2(ModuleTile.CHECK_PX, ModuleTile.CHECK_PX)
	for i: int in range(count):
		var tile: ModuleTile = guild.tile_for(key, i)
		var ok: bool = tile != null and tile.check_box != null and tile.check_mark != null
		if ok:
			ok = tile.check_box.custom_minimum_size.is_equal_approx(want)
		if not ok:
			missing.append("%s %d" % [key, i])
	return missing


#README J1: "Customize: Limits forks up, Bazaar runs down, Promotions sits between them;
#Limits/Promotions/Bazaar boxes align in one column."
static func _case_j01_column(res: Dictionary, tree: SkillTree) -> void:
	_fresh()
	var canvas: TreeCanvas = tree.canvas()
	canvas.refresh()
	var limits: CategoryBox = canvas.cat_box("limits")
	var promos: CategoryBox = canvas.cat_box("promoCat")
	var bazaar: CategoryBox = canvas.cat_box("bazaarCat")
	TestFixtures.check(res, "J1 the three category boxes stand on the Customize tree",
		limits != null and promos != null and bazaar != null,
		"%s %s %s" % [limits != null, promos != null, bazaar != null])
	if limits == null or promos == null or bazaar == null:
		return
	TestFixtures.check(res, "J1 Limits, Promotions and Bazaar share one column",
		is_equal_approx(limits.position.x, promos.position.x)
		and is_equal_approx(promos.position.x, bazaar.position.x)
		and is_equal_approx(TreeLayout.cat_center("limits").x,
		TreeLayout.cat_center("bazaarCat").x),
		"x %.1f %.1f %.1f" % [limits.position.x, promos.position.x, bazaar.position.x])
	TestFixtures.check(res, "J1 Promotions sits between Limits and Bazaar",
		limits.position.y < promos.position.y and promos.position.y < bazaar.position.y,
		"y %.1f %.1f %.1f" % [limits.position.y, promos.position.y, bazaar.position.y])
	var limits_def: Dictionary = TreeLayout.cat_def("limits")
	var up_kids: Array = limits_def["kids"]
	var forks_up: bool = String(limits_def["side"]) == "upFork" and up_kids.size() == 2
	for kid: Variant in up_kids:
		if TreeLayout.block_center(String(kid)).y >= float(TreeLayout.geo("limits")["t"]):
			forks_up = false
	TestFixtures.check(res, "J1 Limits forks up to its two upgrades",
		forks_up, "side %s, %d kids" % [limits_def["side"], up_kids.size()])
	var bazaar_def: Dictionary = TreeLayout.cat_def("bazaarCat")
	var down_kids: Array = bazaar_def["kids"]
	var runs_down: bool = String(bazaar_def["side"]) == "down" and down_kids.size() > 0
	for kid: Variant in down_kids:
		if TreeLayout.block_center(String(kid)).y <= float(TreeLayout.geo("bazaarCat")["b"]):
			runs_down = false
	TestFixtures.check(res, "J1 Bazaar runs down to its upgrade",
		runs_down, "side %s, %d kids" % [bazaar_def["side"], down_kids.size()])
	var promo_def: Dictionary = TreeLayout.cat_def("promoCat")
	TestFixtures.check(res, "J1 Promotions leaves Base by its own left exit, level with Base",
		String(promo_def["via"]) == "left" and String(promo_def["side"]) == "left"
		and is_equal_approx(TreeLayout.cat_center("promoCat").y,
		TreeLayout.block_center("base").y),
		"via %s at y %.1f" % [promo_def["via"], TreeLayout.cat_center("promoCat").y])


#README J1: "Guild Promo shows [n/5] and unlocks at 5 combined Promo Methods + Marketing
#Agency tiers."
static func _case_j01_guild_gate(res: Dictionary, tree: SkillTree) -> void:
	_fresh()
	var canvas: TreeCanvas = tree.canvas()
	_plan_with({"promotions": 1})
	canvas.refresh()
	var gate: RequirementGate = canvas.gate("guildpromo")
	TestFixtures.check(res, "J1 the Guild Promo gate asks for five combined tiers",
		gate != null and UpgradeDefs.requirement_need("guildpromo") == GUILD_PROMO_NEED,
		"need %d" % [UpgradeDefs.requirement_need("guildpromo")])
	if gate == null:
		return
	TestFixtures.check(res, "J1 the gate counts Promo Methods and Marketing Agency together",
		UpgradeDefs.requirement_have("guildpromo", {"promomethods": 3, "marketing": 2}) == 5
		and UpgradeDefs.requirement_have("guildpromo", {"promomethods": 3}) == 3
		and UpgradeDefs.requirement_have("guildpromo", {"marketing": 2}) == 2,
		"%d" % [UpgradeDefs.requirement_have("guildpromo", {"promomethods": 3, "marketing": 2})])
	TestFixtures.check(res, "J1 with no method and no agency the gate reads 0/5 and stays shut",
		gate.text_value() == "0/5" and gate.need == GUILD_PROMO_NEED and not gate.is_met()
		and not SubscriptionManager.can_buy("guildpromo", 1), gate.text_value())
	_plan_with({"promotions": 1, "promomethods": 2, "marketing": 1})
	canvas.refresh()
	TestFixtures.check(res, "J1 three combined tiers read 3/5 and keep Guild Promo shut",
		gate.text_value() == "3/5" and not gate.is_met()
		and not SubscriptionManager.can_buy("guildpromo", 1), gate.text_value())
	_plan_with({"promotions": 1, "promomethods": 3, "marketing": 2})
	canvas.refresh()
	TestFixtures.check(res, "J1 five combined tiers read 5/5 and open Guild Promo",
		gate.text_value() == "5/5" and gate.is_met()
		and SubscriptionManager.can_buy("guildpromo", 1), gate.text_value())


#README J2: "Max out Limits -> its box and its line to Base turn green; drop one tier ->
#orange again."
static func _case_j02_limits_green(res: Dictionary, tree: SkillTree) -> void:
	_fresh()
	var canvas: TreeCanvas = tree.canvas()
	var green: Color = GuiColors.cat_color(1.0)
	var arm: Vector2 = _arm_of("limits")
	var full: Dictionary = _all_max()
	_plan_with(full)
	canvas.refresh()
	var box: CategoryBox = canvas.cat_box("limits")
	TestFixtures.check(res, "J2 every Limits tier owned counts the category as complete",
		box != null and TreeLayout.category_done("limits", full),
		"progress %.2f" % [TreeLayout.category_progress("limits", full)])
	if box == null:
		return
	TestFixtures.check(res, "J2 a completed Limits box turns green",
		box.is_complete() and box.bg_color().is_equal_approx(DONE_BG)
		and CategoryBox.DONE_BG.is_equal_approx(DONE_BG)
		and box.ring_color().is_equal_approx(green),
		"bg %s ring %s" % [box.bg_color(), box.ring_color()])
	TestFixtures.check(res, "J2 the Limits line back to Base turns the same green",
		_color_into(canvas.connectors(), arm).is_equal_approx(green),
		"%s" % [_color_into(canvas.connectors(), arm)])
	var short: Dictionary = full.duplicate()
	short["seats"] = maxi(0, int(full["seats"]) - 1)
	_plan_with(short)
	canvas.refresh()
	TestFixtures.check(res, "J2 one tier less puts the Limits box back to orange",
		not box.is_complete() and box.bg_color().is_equal_approx(CategoryBox.BG)
		and box.ring_color().is_equal_approx(ORANGE),
		"bg %s ring %s" % [box.bg_color(), box.ring_color()])
	TestFixtures.check(res, "J2 one tier less puts the Limits line back to orange",
		_color_into(canvas.connectors(), arm).is_equal_approx(TreeLayout.BASE_LINE),
		"%s" % [_color_into(canvas.connectors(), arm)])


#README J2: "Legal + Less Legal share a stem: stem green only when both are complete."
static func _case_j02_shared_stem(res: Dictionary, tree: SkillTree) -> void:
	_fresh()
	var canvas: TreeCanvas = tree.canvas()
	var green: Color = GuiColors.cat_color(1.0)
	var stem: Vector2 = _stem_start()
	var full: Dictionary = _all_max()
	var legal_id: String = TreeLayout.cat_members("legalCat")[0]
	var less_id: String = TreeLayout.cat_members("lessLegal")[0]
	_plan_with(full)
	canvas.refresh()
	TestFixtures.check(res, "J2 the shared stem is green when Legal and Less Legal are complete",
		TreeLayout.category_done("legalCat", full)
		and TreeLayout.category_done("lessLegal", full)
		and _color_from(canvas.connectors(), stem).is_equal_approx(green),
		"%s" % [_color_from(canvas.connectors(), stem)])
	var no_less: Dictionary = full.duplicate()
	no_less[less_id] = 0
	_plan_with(no_less)
	canvas.refresh()
	TestFixtures.check(res, "J2 Legal complete alone leaves the shared stem orange",
		TreeLayout.category_done("legalCat", no_less)
		and not TreeLayout.category_done("lessLegal", no_less)
		and _color_from(canvas.connectors(), stem).is_equal_approx(TreeLayout.BASE_LINE),
		"%s" % [_color_from(canvas.connectors(), stem)])
	TestFixtures.check(res, "J2 the Legal arm is green by itself while the stem stays orange",
		_color_into(canvas.connectors(), _top_arm_of("legalCat")).is_equal_approx(green),
		"%s" % [_color_into(canvas.connectors(), _top_arm_of("legalCat"))])
	var no_legal: Dictionary = full.duplicate()
	no_legal[legal_id] = 0
	_plan_with(no_legal)
	canvas.refresh()
	TestFixtures.check(res, "J2 Less Legal complete alone leaves the shared stem orange",
		TreeLayout.category_done("lessLegal", no_legal)
		and not TreeLayout.category_done("legalCat", no_legal)
		and _color_from(canvas.connectors(), stem).is_equal_approx(TreeLayout.BASE_LINE),
		"%s" % [_color_from(canvas.connectors(), stem)])
	var neither: Dictionary = full.duplicate()
	neither[legal_id] = 0
	neither[less_id] = 0
	_plan_with(neither)
	canvas.refresh()
	TestFixtures.check(res, "J2 neither category complete leaves the shared stem orange",
		_color_from(canvas.connectors(), stem).is_equal_approx(TreeLayout.BASE_LINE)
		and not _color_into(canvas.connectors(),
		_top_arm_of("legalCat")).is_equal_approx(green),
		"%s" % [_color_from(canvas.connectors(), stem)])


#README J3: "Enterprise without Promotions: My Promotions locked with the upgrade copy;
#Take Me There lands on the Promotions upgrade."
static func _case_j03_hud_lock(res: Dictionary, host: Node) -> void:
	_fresh()
	_plan_with({})
	var scene: PackedScene = load(HUD_SCENE) as PackedScene
	var hud: GameHUD = scene.instantiate() as GameHUD
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	await host.get_tree().process_frame
	var tile: GridMenuButton = hud.button_of(&"promotions")
	TestFixtures.check(res, "J3 Enterprise without the upgrade locks the My Promotions tile",
		tile != null and hud.is_locked(&"promotions"),
		"locked %s" % [hud.is_locked(&"promotions")])
	if tile == null:
		hud.queue_free()
		return
	TestFixtures.check(res, "J3 the locked tile stays on the grid and shows its badge",
		tile.visible and tile.locked and tile.lock_badge.visible,
		"visible %s locked %s" % [tile.visible, tile.locked])
	tile.press()
	await host.get_tree().process_frame
	var dialog: FeatureLockDialog = hud.lock_dialog()
	var line1: String = "" if dialog == null else dialog.line1_label.text
	var line2: String = "" if dialog == null else dialog.line2_label.text
	TestFixtures.check(res, "J3 the locked tile opens the upgrade copy and never the window",
		dialog != null and dialog.visible and not hud.popup().is_open()
		and line1 == LOCK_LINE1 and line2 == LOCK_LINE2,
		"%s / %s" % [line1, line2])
	if dialog == null:
		hud.queue_free()
		return
	var seen: Array[Dictionary] = []
	var catcher: Callable = func(target: Dictionary) -> void:
		seen.append(target)
	GameState.go_to_plans_requested.connect(catcher)
	dialog.press_take_me_there()
	GameState.go_to_plans_requested.disconnect(catcher)
	var got: Dictionary = {} if seen.is_empty() else seen[0]
	TestFixtures.check(res, "J3 Take Me There lands on the Promotions upgrade of Customize",
		String(got.get("tab", "")) == "customize"
		and String(got.get("upgrade", "")) == "promotions"
		and int(got.get("tier", 0)) == 1, "%s" % [got])
	hud.popup().close()
	TestFixtures.check(res, "J3 the named upgrade is the Promotions upgrade of the tree",
		UpgradeDefs.has_id("promotions") and UpgradeDefs.name_of("promotions") == "Promotions"
		and TreeLayout.PLACE.has("promotions")
		and TreeLayout.bill_cat("promotions") == "promoCat",
		UpgradeDefs.name_of("promotions"))
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame


#README J4: "Buy Promotions I: Job Ads opens; Guild Ads shows its lock."
static func _case_j04_tabs(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	_plan_with({"promotions": 1})
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "J4 Promotions I opens the Job Ads tab",
		not viewer.mode_locked() and viewer.toolbar_shown() and viewer.new_shown()
		and not viewer.lock_shown() and viewer.title_text() == PromotionsViewer.JOB_TITLE,
		viewer.title_text())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	var block: ModeLock = viewer.lock_block()
	TestFixtures.check(res, "J4 Guild Ads shows the Guild Promotion lock",
		viewer.mode_locked() and viewer.lock_shown() and block != null
		and viewer.title_text() == PromotionsViewer.PROMO_TITLE,
		"locked %s shown %s" % [viewer.mode_locked(), viewer.lock_shown()])
	if block == null:
		return
	TestFixtures.check(res, "J4 the locked Guild Ads line reads the manager copy, centred",
		block.text() == "Guild Promotion is locked."
		and block.line.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, block.text())
	var lock: FeatureLock = block.lock_button()
	TestFixtures.check(res, "J4 the locked tab carries the Guild Promo label button",
		lock != null and lock.visible and lock.label == "Locked"
		and lock.upgrade_id == "guildpromo" and lock.tier == 1 and lock.tiers == 4,
		"%s tier %d of %d" % ["" if lock == null else lock.label,
		0 if lock == null else lock.tier, 0 if lock == null else lock.tiers])
	TestFixtures.check(res, "J4 the locked tab drops the new campaign button, the sort and filter",
		not viewer.new_shown() and not viewer.toolbar_shown(),
		"new %s toolbar %s" % [viewer.new_shown(), viewer.toolbar_shown()])
	_plan_with({"promotions": 1, "promomethods": 3, "marketing": 2, "guildpromo": 1})
	viewer.refresh()
	TestFixtures.check(res, "J4 Guild Promo I opens the Guild Ads tab",
		not viewer.mode_locked() and viewer.toolbar_shown() and viewer.new_shown()
		and not viewer.lock_shown(), viewer.title_text())
	viewer.open_tab(PromotionsViewer.JOB_KEY)


#README J4: "Flyers usable; Direct Sale/Radio/Sponsorship locked until Promo Methods
#I/II/III."
static func _case_j04_types(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	_plan_with({"promotions": 1})
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	TestFixtures.check(res, "J4 the new campaign button opens the builder",
		builder != null and builder.is_open(), "open %s" % [builder != null and builder.is_open()])
	if builder == null:
		return
	builder.pick_type(&"flyers")
	var flyers: TypeRow = builder.type_row(&"flyers")
	TestFixtures.check(res, "J4 Flyers is usable as soon as Promotions I is owned",
		flyers != null and not flyers.is_locked() and flyers.is_pickable()
		and builder.type_key() == &"flyers", String(builder.type_key()))
	TestFixtures.check(res, "J4 Direct Sale, Radio and Sponsorship are locked with no methods",
		builder.type_row(&"direct").is_locked() and builder.type_row(&"radio").is_locked()
		and builder.type_row(&"sponsor").is_locked(),
		"%s %s %s" % [builder.type_row(&"direct").is_locked(),
		builder.type_row(&"radio").is_locked(), builder.type_row(&"sponsor").is_locked()])
	TestFixtures.check(res, "J4 each locked method names the Promo Methods tier that opens it",
		builder.type_row(&"direct").lock_button().upgrade_id == "promomethods"
		and builder.type_row(&"direct").lock_button().tier == 1
		and builder.type_row(&"radio").lock_button().tier == 2
		and builder.type_row(&"sponsor").lock_button().tier == 3,
		"%d %d %d" % [builder.type_row(&"direct").lock_button().tier,
		builder.type_row(&"radio").lock_button().tier,
		builder.type_row(&"sponsor").lock_button().tier])
	builder.press_close()
	var want: Array[String] = ["direct", "direct,radio", "direct,radio,sponsor"]
	var keys: Array[StringName] = [&"direct", &"radio", &"sponsor"]
	for tier: int in range(1, 4):
		_plan_with({"promotions": 1, "promomethods": tier})
		viewer.press_new()
		var opened: Array[String] = []
		for key: StringName in keys:
			if not builder.type_row(key).is_locked():
				opened.append(String(key))
		var joined: String = ",".join(opened)
		TestFixtures.check(res, "J4 Promo Methods %s opens exactly its own method"
			% [FeatureLock.roman(tier)], joined == want[tier - 1], joined)
		builder.press_close()
	_plan_with({"promotions": 1, "promomethods": 3})
	viewer.press_new()
	TestFixtures.check(res, "J4 Direct Sale stays a Guild Ads method on the Job Ads tab",
		not builder.type_row(&"direct").is_locked()
		and builder.type_row(&"direct").is_blocked()
		and not builder.type_row(&"direct").is_pickable(),
		"blocked %s" % [builder.type_row(&"direct").is_blocked()])
	builder.press_close()


#README J5: "Duration: cap follows Long Promos (5/10/17/25/30/inf)."
static func _case_j05_caps(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	for tier: int in range(0, 6):
		_plan_with({"promotions": 1, "longpromos": tier})
		viewer.press_new()
		var builder: CampaignBuilder = viewer.builder()
		var dur: DurationControl = builder.duration_control()
		var cap: int = CampaignTypeDefs.cap_of(SubscriptionManager.entitlements())
		if tier < DAY_CAPS.size():
			TestFixtures.check(res, "J5 Long Promos tier %d caps a campaign at %d days"
				% [tier, DAY_CAPS[tier]],
				cap == DAY_CAPS[tier] and dur.max_quantity() == DAY_CAPS[tier]
				and dur.hint_text() == DurationControl.UP_TO % [DAY_CAPS[tier]]
				and DurationControl.UP_TO == HINT_UP_TO,
				"cap %d hint %s" % [cap, dur.hint_text()])
			if tier == 2:
				builder.pick_unit(CampaignTypeDefs.UNIT_WEEKS)
				TestFixtures.check(res, "J5 the %d day cap gives Weeks a max of %d"
					% [DAY_CAPS[tier], WEEKS_AT_17],
					dur.max_quantity() == WEEKS_AT_17, str(dur.max_quantity()))
				var picker17: UnitDropdown = builder.duration_control().unit_picker()
				TestFixtures.check(res, "J5 Months stays locked at the %d day cap"
					% [DAY_CAPS[tier]],
					picker17.row_locked(CampaignTypeDefs.UNIT_MONTHS), "")
		else:
			TestFixtures.check(res, "J5 Long Promos V lifts the cap and drops the day hint",
				cap >= CampaignTypeDefs.INFINITE_CAP
				and dur.hint_text() == DurationControl.NO_LIMIT
				and DurationControl.NO_LIMIT == HINT_NO_LIMIT,
				"cap %d hint %s" % [cap, dur.hint_text()])
			TestFixtures.check(res, "J5 the top tier caps Days at %d" % [TOP_DAYS_MAX],
				dur.max_quantity() == TOP_DAYS_MAX, str(dur.max_quantity()))
			builder.pick_unit(CampaignTypeDefs.UNIT_WEEKS)
			TestFixtures.check(res, "J5 the top tier caps Weeks at %d" % [TOP_WEEKS_MAX],
				dur.max_quantity() == TOP_WEEKS_MAX, str(dur.max_quantity()))
			builder.pick_unit(CampaignTypeDefs.UNIT_MONTHS)
			TestFixtures.check(res, "J5 the top tier caps Months at %d" % [TOP_MONTHS_MAX],
				dur.max_quantity() == TOP_MONTHS_MAX, str(dur.max_quantity()))
		builder.press_close()


#README J5: "Weeks/Months/Infinite locks."
static func _case_j05_unit_locks(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var rows: Array[Dictionary] = [
		{"unit": CampaignTypeDefs.UNIT_WEEKS, "name": "Weeks", "tier": 1},
		{"unit": CampaignTypeDefs.UNIT_MONTHS, "name": "Months", "tier": 4},
		{"unit": CampaignTypeDefs.UNIT_INFINITE, "name": "Infinite", "tier": 5},
	]
	for row: Dictionary in rows:
		var unit: StringName = StringName(row["unit"])
		var label: String = String(row["name"])
		var tier: int = int(row["tier"])
		_plan_with({"promotions": 1, "longpromos": tier - 1})
		viewer.press_new()
		var builder: CampaignBuilder = viewer.builder()
		var picker: UnitDropdown = builder.duration_control().unit_picker()
		var lock: FeatureLock = picker.lock_for(unit)
		TestFixtures.check(res, "J5 %s stays locked one tier short of Long Promos %s"
			% [label, FeatureLock.roman(tier)],
			picker.row_locked(unit) and lock != null and lock.visible
			and lock.upgrade_id == "longpromos" and lock.tier == tier,
			"locked %s tier %d" % [picker.row_locked(unit), 0 if lock == null else lock.tier])
		builder.press_close()
		_plan_with({"promotions": 1, "longpromos": tier})
		viewer.press_new()
		TestFixtures.check(res, "J5 Long Promos %s opens %s" % [FeatureLock.roman(tier), label],
			not picker.row_locked(unit)
			and CampaignTypeDefs.unit_unlocked(unit, SubscriptionManager.entitlements()),
			"locked %s" % [picker.row_locked(unit)])
		builder.press_close()
	_plan_with({"promotions": 1})
	viewer.press_new()
	var days: UnitDropdown = viewer.builder().duration_control().unit_picker()
	TestFixtures.check(res, "J5 Days never carries a lock",
		not days.row_locked(CampaignTypeDefs.UNIT_DAYS)
		and days.lock_for(CampaignTypeDefs.UNIT_DAYS) == null,
		"locked %s" % [days.row_locked(CampaignTypeDefs.UNIT_DAYS)])
	viewer.builder().press_close()


#README J5: "Infinite disables qty and shows the monthly notice; launching Infinite charges
#one month and adds an Ads expense in Finance."
static func _case_j05_infinite(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	_plan_with({"promotions": 1, "longpromos": 5})
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	builder.pick_type(&"flyers")
	builder.pick_unit(CampaignTypeDefs.UNIT_INFINITE)
	var dur: DurationControl = builder.duration_control()
	TestFixtures.check(res, "J5 an Infinite campaign disables the quantity stepper",
		dur.is_infinite() and dur.stepper_disabled()
		and is_equal_approx(dur.quantity_stepper().modulate.a, DurationControl.INFINITE_ALPHA)
		and is_equal_approx(DurationControl.INFINITE_ALPHA, INFINITE_ALPHA_DESIGN),
		"infinite %s alpha %.2f" % [dur.is_infinite(), dur.quantity_stepper().modulate.a])
	TestFixtures.check(res, "J5 an Infinite campaign shows the monthly notice",
		builder.chip_shown()
		and CampaignBuilder.CHIP_TEXT == "Billed monthly, starting immediately",
		CampaignBuilder.CHIP_TEXT)
	var month: int = CampaignTypeDefs.monthly_cost(&"flyers")
	TestFixtures.check(res, "J5 an Infinite campaign is priced at one month up front",
		month == 150 and builder.cost() == month and builder.cost_text().ends_with("/ month"),
		"%d notes, %s" % [builder.cost(), builder.cost_text()])
	var bank: int = GameState.bank_notes
	var ads_before: int = FinanceLedger.ads()
	var row_before: int = _ads_row()
	TestFixtures.check(res, "J5 the Infinite campaign is ready to launch",
		builder.launch_enabled(), builder.reason_text())
	builder.press_launch()
	TestFixtures.check(res, "J5 launching an Infinite campaign charges one month at once",
		not builder.is_open() and GameState.bank_notes == bank - month,
		"bank %d of %d" % [GameState.bank_notes, bank])
	TestFixtures.check(res, "J5 the launch adds its month to the Ads expense of Finance",
		FinanceLedger.ads() == ads_before + month and _ads_row() == row_before + month
		and PromotionsManager.monthly_ad_bill() == FinanceLedger.ads(),
		"ads %d of %d, row %d of %d" % [FinanceLedger.ads(), ads_before, _ads_row(), row_before])


#README J6: "Marketing Agency tiers raise every Effect value (e.g. Flyers 2% -> 2.5% at
#+25%)."
static func _case_j06_boost(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	_plan_with({"promotions": 1})
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var lines: Array[String] = []
	for row: TypeRow in builder.type_rows():
		lines.append(row.effect_line())
	TestFixtures.check(res, "J6 with no Marketing Agency the Effect column reads the base rates",
		lines == BASE_EFFECTS, "%s" % [lines])
	TestFixtures.check(res, "J6 with no Marketing Agency the column header names no boost",
		not builder.boost_label.visible, builder.boost_label.text)
	builder.press_close()
	var priced: Array[StringName] = [&"flyers", &"direct", &"radio", &"sponsor"]
	var raw: Dictionary = {}
	var shown: Dictionary = {}
	var falls: Array[String] = []
	var drops: Array[String] = []
	var top: int = UpgradeDefs.tier_count("marketing")
	for tier: int in range(0, top + 1):
		_plan_with({"promotions": 1, "marketing": tier})
		viewer.press_new()
		var ent: Dictionary = SubscriptionManager.entitlements()
		var boost: float = CampaignTypeDefs.number_of(ent, CampaignTypeDefs.BOOST_KEY)
		for key: StringName in priced:
			var base: float = float(CampaignTypeDefs.find(key)["effect"])
			var now: float = base * (1.0 + boost / 100.0)
			var text: float = builder.type_row(key).effect_line().trim_suffix("%").to_float()
			if tier > 0 and now <= float(raw.get(key, 0.0)):
				falls.append("%s tier %d" % [key, tier])
			if tier > 0 and text < float(shown.get(key, 0.0)):
				drops.append("%s tier %d" % [key, tier])
			raw[key] = now
			shown[key] = text
		builder.press_close()
	TestFixtures.check(res, "J6 every Marketing Agency tier raises every priced Effect value",
		falls.is_empty(), TestFixtures.detail(falls, (top + 1) * priced.size(), "values"))
	TestFixtures.check(res, "J6 no shown Effect ever falls as a Marketing Agency tier is added",
		drops.is_empty(), TestFixtures.detail(drops, (top + 1) * priced.size(), "values"))
	_plan_with({"promotions": 1, "marketing": top})
	viewer.press_new()
	var boosted: Dictionary = SubscriptionManager.entitlements()
	var pct: int = roundi(CampaignTypeDefs.number_of(boosted, CampaignTypeDefs.BOOST_KEY))
	TestFixtures.check(res, "J6 Flyers reads 2 percent at 2.5 percent with plus 25 percent",
		pct == BOOST_TOP and builder.type_row(&"flyers").effect_line() == FLYERS_BOOSTED
		and BASE_EFFECTS[1] == "2%", "%d percent, %s"
		% [pct, builder.type_row(&"flyers").effect_line()])
	TestFixtures.check(res, "J6 the Effect column header names the boost",
		builder.boost_label.visible
		and builder.boost_label.text == "Marketing Agency +%d%%" % [BOOST_TOP],
		builder.boost_label.text)
	TestFixtures.check(res, "J6 Word of Mouth keeps reading Varies with the agency bought",
		builder.type_row(&"wom").effect_line() == "Varies"
		and builder.type_row(&"wom").effect_color().is_equal_approx(TypeRow.SKY),
		builder.type_row(&"wom").effect_line())
	builder.press_close()


#README J7: "Radio: Buern/Rossade/Vaernebo unpickable. Sponsorship: one location.
#Checkboxes on every card."
static func _case_j07_targets(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	_plan_with({"promotions": 1, "promomethods": 3, "marketing": 2, "guildpromo": 1})
	_grant_permits()
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var guild: GuildTargeting = builder.guild_panel()
	builder.pick_type(&"radio")
	var blocked: Array[String] = []
	var open_towns: Array[String] = []
	for i: int in range(TraitFilterDefs.LOCATION_COUNT):
		var tile: ModuleTile = guild.tile_for(GuildTargeting.LOC_KEY, i)
		if tile == null:
			continue
		if tile.is_blocked():
			blocked.append(CampaignTypeDefs.location_name(i))
		else:
			open_towns.append(CampaignTypeDefs.location_name(i))
	TestFixtures.check(res, "J7 Radio cannot reach Buern, Rossade or Vaernebo",
		blocked == NO_RADIO_TOWNS, "%s" % [blocked])
	TestFixtures.check(res, "J7 Radio reaches every other town",
		open_towns.size() == TraitFilterDefs.LOCATION_COUNT - NO_RADIO_TOWNS.size(),
		"%d towns" % [open_towns.size()])
	var first: ModuleTile = guild.tile_for(GuildTargeting.LOC_KEY, 0)
	TestFixtures.check(res, "J7 a town with no mast is greyed and says why",
		first != null and first.disabled_reason == GuildTargeting.NO_RADIO
		and GuildTargeting.NO_RADIO == "No radio coverage"
		and is_equal_approx(first.modulate.a, ModuleTile.BLOCKED_ALPHA),
		"" if first == null else first.disabled_reason)
	builder.toggle_location(0)
	TestFixtures.check(res, "J7 a town with no mast refuses the pick",
		guild.locations().is_empty(), "%s" % [guild.locations()])
	builder.toggle_location(1)
	TestFixtures.check(res, "J7 a town Radio reaches takes the pick",
		guild.locations().size() == 1 and guild.locations()[0] == 1, "%s" % [guild.locations()])
	builder.toggle_location(2)
	TestFixtures.check(res, "J7 a second town Radio reaches adds to the pick",
		guild.locations().size() == 2 and guild.locations()[0] == 1
		and guild.locations()[1] == 2, "%s" % [guild.locations()])
	builder.pick_type(&"sponsor")
	var section: FilterSection = guild.section_for(GuildTargeting.LOC_KEY)
	var sponsor_tile: ModuleTile = guild.tile_for(GuildTargeting.LOC_KEY, 0)
	TestFixtures.check(res, "J7 Sponsorship takes one location only",
		section != null and sponsor_tile != null and sponsor_tile.single
		and section.title_text().ends_with(FilterSection.PICK_ONE_NOTE),
		"" if section == null else section.title_text())
	TestFixtures.check(res, "J7 switching to Sponsorship trims two Radio picks to one",
		guild.locations().size() == 1 and guild.locations()[0] == 1, "%s" % [guild.locations()])
	builder.toggle_location(2)
	var one: Array[int] = guild.locations()
	builder.toggle_location(3)
	TestFixtures.check(res, "J7 a second Sponsorship pick replaces the first",
		one.size() == 1 and one[0] == 2 and guild.locations().size() == 1
		and guild.locations()[0] == 3, "%s then %s" % [one, guild.locations()])
	builder.toggle_location(BUERN_LOC)
	TestFixtures.check(res, "J7 Sponsorship takes a town with no radio mast",
		guild.locations().size() == 1 and guild.locations()[0] == BUERN_LOC,
		"%s" % [guild.locations()])
	builder.pick_type(&"radio")
	TestFixtures.check(res, "J7 switching to Radio drops a pick it cannot reach",
		guild.locations().is_empty(), "%s" % [guild.locations()])
	builder.pick_type(&"sponsor")
	var loc_missing: Array[String] = _check_boxes(guild, GuildTargeting.LOC_KEY,
		TraitFilterDefs.LOCATION_COUNT)
	TestFixtures.check(res, "J7 every Location card carries its checkbox",
		loc_missing.is_empty() and is_equal_approx(ModuleTile.CHECK_PX, 16.0),
		TestFixtures.detail(loc_missing, TraitFilterDefs.LOCATION_COUNT, "cards"))
	builder.press_close()
	_plan_with({"promotions": 1, "promomethods": 3, "marketing": 2, "guildpromo": 4})
	viewer.press_new()
	builder.pick_type(&"flyers")
	var type_missing: Array[String] = _check_boxes(guild, GuildTargeting.TYPE_KEY,
		TraitFilterDefs.CONTRACT_TYPE_COUNT)
	TestFixtures.check(res, "J7 every Contract Type card carries its checkbox",
		type_missing.is_empty(),
		TestFixtures.detail(type_missing, TraitFilterDefs.CONTRACT_TYPE_COUNT, "cards"))
	guild.toggle_type(0)
	TestFixtures.check(res, "J7 a picked Contract Type card ticks its checkbox",
		guild.contract_types().size() == 1 and guild.contract_types()[0] == 0
		and guild.tile_for(GuildTargeting.TYPE_KEY, 0).selected,
		"%s" % [guild.contract_types()])
	builder.press_close()
	LegalManager.reset()


#README J8: "Guild Promo I-IV unlock Min, Max, Contract Type in that order."
static func _case_j08_guild_tiers(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	_grant_permits()
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	var order: Array[String] = []
	for gp: int in range(1, 5):
		_plan_with({"promotions": 1, "promomethods": 3, "marketing": 2, "guildpromo": gp})
		viewer.press_new()
		var builder: CampaignBuilder = viewer.builder()
		var guild: GuildTargeting = builder.guild_panel()
		var diff: FilterSection = guild.section_for(GuildTargeting.DIFF_KEY)
		var types: FilterSection = guild.section_for(GuildTargeting.TYPE_KEY)
		var stars: StarRangePicker = null if diff == null else diff.star_picker()
		if stars == null or types == null:
			TestFixtures.check(res, "J8 Guild Promo %s shows the difficulty and type sections"
				% [FeatureLock.roman(gp)], false, "diff %s types %s" % [stars, types])
			builder.press_close()
			continue
		var min_open: bool = not stars.is_row_locked(StarRangePicker.ROW_MIN)
		var max_open: bool = not stars.is_row_locked(StarRangePicker.ROW_MAX)
		var type_open: bool = not types.is_locked()
		order.append("%s%s%s" % ["m" if min_open else "-", "M" if max_open else "-",
			"T" if type_open else "-"])
		if gp == 1:
			var min_lock: FeatureLock = stars.lock_for(StarRangePicker.ROW_MIN)
			TestFixtures.check(res, "J8 Guild Promo I keeps Min, Max and Contract Type shut",
				not min_open and not max_open and not type_open,
				"%s %s %s" % [min_open, max_open, type_open])
			TestFixtures.check(res, "J8 a locked difficulty row shows the Locked label button",
				min_lock != null and min_lock.visible and min_lock.label == "Locked"
				and min_lock.upgrade_id == "guildpromo" and min_lock.tier == 2,
				"tier %d" % [0 if min_lock == null else min_lock.tier])
			stars.press_star(StarRangePicker.ROW_MIN, 3.0)
			stars.press_star(StarRangePicker.ROW_MAX, 2.0)
			TestFixtures.check(res, "J8 a locked difficulty row keeps its default value",
				is_equal_approx(stars.row_value(StarRangePicker.ROW_MIN),
				StarRangePicker.MIN_VALUE)
				and is_equal_approx(stars.row_value(StarRangePicker.ROW_MAX),
				StarRangePicker.MAX_VALUE),
				"%.1f to %.1f" % [stars.row_value(StarRangePicker.ROW_MIN),
				stars.row_value(StarRangePicker.ROW_MAX)])
		elif gp == 2:
			TestFixtures.check(res, "J8 Guild Promo II opens Min and leaves Max and the type shut",
				min_open and not max_open and not type_open,
				"%s %s %s" % [min_open, max_open, type_open])
			stars.press_star(StarRangePicker.ROW_MIN, 2.0)
			stars.press_star(StarRangePicker.ROW_MAX, 3.0)
			TestFixtures.check(res, "J8 the open Min row takes a value while Max stays pinned",
				is_equal_approx(stars.row_value(StarRangePicker.ROW_MIN), 2.0)
				and is_equal_approx(stars.row_value(StarRangePicker.ROW_MAX),
				StarRangePicker.MAX_VALUE),
				"%.1f to %.1f" % [stars.row_value(StarRangePicker.ROW_MIN),
				stars.row_value(StarRangePicker.ROW_MAX)])
		elif gp == 3:
			var type_lock: FeatureLock = types.section_lock()
			TestFixtures.check(res, "J8 Guild Promo III opens Max and leaves Contract Type shut",
				min_open and max_open and not type_open,
				"%s %s %s" % [min_open, max_open, type_open])
			TestFixtures.check(res, "J8 the locked Contract Type section shows its label button",
				type_lock != null and type_lock.visible and type_lock.label == "Locked"
				and type_lock.upgrade_id == "guildpromo" and type_lock.tier == 4
				and type_lock.tiers == 4,
				"tier %d" % [0 if type_lock == null else type_lock.tier])
			stars.press_star(StarRangePicker.ROW_MAX, 4.0)
			TestFixtures.check(res, "J8 the open Max row takes a value",
				is_equal_approx(stars.row_value(StarRangePicker.ROW_MAX), 4.0),
				"%.1f" % [stars.row_value(StarRangePicker.ROW_MAX)])
		else:
			TestFixtures.check(res, "J8 Guild Promo IV opens Min, Max and Contract Type",
				min_open and max_open and type_open,
				"%s %s %s" % [min_open, max_open, type_open])
			TestFixtures.check(res, "J8 the open Contract Type section holds every type",
				types.tiles().size() == TraitFilterDefs.CONTRACT_TYPE_COUNT,
				"%d tiles" % [types.tiles().size()])
		builder.press_close()
	TestFixtures.check(res, "J8 the four Guild Promo tiers open Min, Max and Contract Type in turn",
		order.size() == 4 and order[0] == "---" and order[1] == "m--"
		and order[2] == "mM-" and order[3] == "mMT", "%s" % [order])
	LegalManager.reset()

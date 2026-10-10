class_name GuiTreeTests
extends RefCounted

#Run: godot --headless --path . with the --gui-tree-tests flag.
#The Customize skill tree: cell geometry, category boxes, connector colours, requirement gates, the
#pan, the deep link, the tier popover and the module captions. Every case drives the public helpers,
#because a synthetic click never reaches a button headless.

const TREE: PackedScene = preload("res://Scenes/GUI/Subscription/SkillTree.tscn")
const VIEW: Vector2 = Vector2(1200.0, 540.0)
#Daith holds 30 days, so the 22nd sits 10 whole days from the bill on the 2nd of Ruadd.
const SHORT_MONTH: int = 0
const DAY: int = 22
const RICH: int = 5000
const CREW: int = 3
const BOARD: int = 4
#Three prior tiers of the six Criminal Records asks for: a half full gate.
const GATE_FIX: Dictionary = {"discrim": 2, "background": 1}
#Pixels a caption may sit off the middle of its gap.
const CAPTION_TOL: float = 1.0
#How far a sampled pulse scale may sit off its peak or its edge, and the seconds stepped past the window.
const PULSE_TOL: float = 0.001


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	_fresh()
	await host.get_tree().process_frame
	var tree: SkillTree = TREE.instantiate() as SkillTree
	host.add_child(tree)
	await host.get_tree().process_frame
	_case_places(res)
	_case_categories(res)
	_case_colors(res)
	_case_connectors(res)
	_case_gates(res)
	_case_pan(res, tree)
	await _case_focus(res, host, tree)
	await _case_rows(res, host, tree)
	await _case_money(res, host, tree)
	await _case_tooltip(res, host, tree)
	_case_canvas(res, tree)
	await _case_follow(res, host)
	await _case_press(res, host, tree)
	await _case_pointer(res, host, tree)
	await _case_outside(res, host, tree)
	_case_captions(res, tree)
	GuiFrameStack.clear()
	tree.queue_free()
	CampaignClock.minutes = clock
	SubscriptionManager.max_out()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI TREE")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


#Every upgrade at its highest tier, which is the state a fresh manager starts in.
static func _all_max() -> Dictionary:
	var out: Dictionary = {}
	for id: String in UpgradeDefs.ORDER:
		out[id] = UpgradeDefs.tier_count(id)
	return out


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


#The small guild the money cases price against: 3 mercs, 4 listed contracts, the 22nd of Daith and the fallback income.
static func _small_guild() -> void:
	_set_crew(CREW)
	_set_board(BOARD)
	_set_day(SHORT_MONTH, DAY)
	GameState.bank_notes = RICH
	TestFixtures.fund_budget(SubscriptionManager.BUDGET_FALLBACK)


#Case 1: one cell per upgrade, the cell to pixel step and the world every block stands on.
static func _case_places(res: Dictionary) -> void:
	var missing: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		if not TreeLayout.PLACE.has(id):
			missing.append(id)
	TestFixtures.check(res, "every upgrade holds a cell in the tree", missing.is_empty(),
		TestFixtures.detail(missing, UpgradeDefs.ORDER.size(), "upgrades"))
	var stray: Array[String] = []
	for id: String in TreeLayout.block_ids():
		if id != "base" and not UpgradeDefs.has_id(id):
			stray.append(id)
	TestFixtures.check(res, "no cell names an upgrade that does not exist", stray.is_empty(),
		TestFixtures.detail(stray, TreeLayout.PLACE.size(), "cells"))
	TestFixtures.check(res, "the tree holds the Base plan and nothing else beside the upgrades",
		TreeLayout.PLACE.has("base")
			and TreeLayout.PLACE.size() == UpgradeDefs.ORDER.size() + 1,
		"cells %d upgrades %d" % [TreeLayout.PLACE.size(), UpgradeDefs.ORDER.size()])
	var seen: Dictionary = {}
	var shared: Array[String] = []
	for id: String in TreeLayout.block_ids():
		var key: String = str(TreeLayout.PLACE[id])
		if seen.has(key):
			shared.append(id)
		seen[key] = id
	TestFixtures.check(res, "no two modules sit on the same cell", shared.is_empty(),
		TestFixtures.detail(shared, TreeLayout.PLACE.size(), "cells"))
	TestFixtures.check(res, "the cell origin is the Base column on the first row",
		TreeLayout.grid_to_px(0.0, 0.0) == Vector2(TreeLayout.BASE_X, TreeLayout.ROW0),
		"origin %s" % [TreeLayout.grid_to_px(0.0, 0.0)])
	TestFixtures.check(res, "one cell across is one column and one cell up is one row",
		TreeLayout.grid_to_px(2.0, -1.0)
			== Vector2(TreeLayout.BASE_X + 2.0 * TreeLayout.GX, TreeLayout.ROW0 - TreeLayout.GY),
		"step %s" % [TreeLayout.grid_to_px(2.0, -1.0)])
	TestFixtures.check(res, "the Base plan is the widest module",
		TreeLayout.block_size("base") == TreeLayout.BASE_BLOCK
			and TreeLayout.block_size("seats") == TreeLayout.BLOCK,
		"base %.0f seats %.0f" % [TreeLayout.block_size("base"), TreeLayout.block_size("seats")])
	var box: Rect2 = TreeLayout.block_rect("counsel")
	TestFixtures.check(res, "a module box is square and centred on its cell",
		box.size == Vector2(TreeLayout.BLOCK, TreeLayout.BLOCK)
			and box.get_center().is_equal_approx(TreeLayout.block_center("counsel")),
		"box %s centre %s" % [box, TreeLayout.block_center("counsel")])
	var outside: Array[String] = []
	for id: String in TreeLayout.block_ids():
		var r: Rect2 = TreeLayout.block_rect(id)
		var top: float = r.position.y + TreeLayout.OY
		var inside: bool = r.position.x >= 0.0 and r.end.x <= TreeLayout.WORLD.x
		inside = inside and top >= 0.0 and top + r.size.y <= TreeLayout.WORLD.y
		if not inside:
			outside.append(id)
	TestFixtures.check(res, "every module stands inside the world", outside.is_empty(),
		TestFixtures.detail(outside, TreeLayout.PLACE.size(), "modules"))


#Case 2: the eight category boxes, the branch each upgrade counts towards and the box it bills to.
static func _case_categories(res: Dictionary) -> void:
	var cats: Array[String] = TreeLayout.cat_ids()
	TestFixtures.check(res, "the tree carries eight category boxes", cats.size() == 8,
		"boxes %d" % [cats.size()])
	var thin: Array[String] = []
	for cat: String in cats:
		var def: Dictionary = TreeLayout.cat_def(cat)
		var whole: bool = def.has("name") and def.has("desc") and def.has("at") and def.has("via")
		if not whole or TreeLayout.cat_rect(cat).size != TreeLayout.CAT_BOX:
			thin.append(cat)
	TestFixtures.check(res, "each box knows its name, blurb, cell and stem", thin.is_empty(),
		TestFixtures.detail(thin, cats.size(), "boxes"))
	var missing: Array[String] = []
	for key: String in TreeIcons.IDS.keys():
		var id: String = TreeIcons.id_of(key)
		if id == "" or not Icons.has(id):
			missing.append(key)
	for up_id: String in UpgradeDefs.ORDER:
		if not TreeIcons.IDS.has(up_id):
			missing.append(up_id)
	for cat_id: String in cats:
		if not TreeIcons.IDS.has(cat_id):
			missing.append(cat_id)
	TestFixtures.check(res, "every tree key maps to an atlas id", missing.is_empty(),
		TestFixtures.detail(missing, TreeIcons.IDS.size(), "keys"))
	TestFixtures.check(res, "the metrics branch reads as the Insights box",
		TreeLayout.cat_label("metricsCat") == TreeLayout.cat_label("insights")
			and TreeLayout.cat_label("insights") != "insights",
		"label %s" % [TreeLayout.cat_label("metricsCat")])
	#PROTO 107, 108 and 112 of the Subscription Viewer: the branch name reads blue at 11 px in the
	#regular face and the total cream at 12 px in the bold one.
	TestFixtures.check(res, "a branch box wears the label colours, faces and sizes of the sheet",
		CategoryBox.NAME_COLOR.is_equal_approx(GuiColors.SKY)
			and CategoryBox.TOTAL_COLOR.is_equal_approx(GuiColors.CREAM)
			and CategoryBox.NAME_SIZE == 11 and CategoryBox.TOTAL_SIZE == 12
			and CategoryBox.NAME_FONT.resource_path.ends_with("SilkscreenRegular.tres")
			and CategoryBox.TOTAL_FONT.resource_path.ends_with("SilkscreenBold.tres"),
		"name %s total %s sizes %d and %d" % [CategoryBox.NAME_COLOR, CategoryBox.TOTAL_COLOR,
			CategoryBox.NAME_SIZE, CategoryBox.TOTAL_SIZE])
	var homeless: Array[String] = []
	var double_billed: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		var boxes: int = 0
		var bills: int = 0
		for cat: String in cats:
			if TreeLayout.in_cat(id, cat):
				boxes += 1
			if TreeLayout.bill_cat(id) == cat:
				bills += 1
		if boxes == 0:
			homeless.append(id)
		if bills != 1:
			double_billed.append(id)
	TestFixtures.check(res, "every upgrade counts towards a box", homeless.is_empty(),
		TestFixtures.detail(homeless, UpgradeDefs.ORDER.size(), "upgrades"))
	TestFixtures.check(res, "every upgrade bills to exactly one box", double_billed.is_empty(),
		TestFixtures.detail(double_billed, UpgradeDefs.ORDER.size(), "upgrades"))
	var full: Dictionary = _all_max()
	var wrong: Array[String] = []
	for cat: String in cats:
		var total: int = 0
		for id: String in TreeLayout.cat_members(cat):
			total += UpgradeDefs.tier_count(id)
		var counts: Vector2i = TreeLayout.category_counts(cat, full)
		if counts.y != total or counts.x != total:
			wrong.append(cat)
	TestFixtures.check(res, "a box counts every tier of its branch", wrong.is_empty(),
		TestFixtures.detail(wrong, cats.size(), "boxes"))
	var empty: Vector2i = TreeLayout.category_counts("limits", {})
	TestFixtures.check(res, "an untouched branch owns nothing and is not finished",
		empty.x == 0 and empty.y > 0 and not TreeLayout.category_done("limits", {})
			and is_zero_approx(TreeLayout.category_progress("limits", {})),
		"counts %s" % [empty])
	TestFixtures.check(res, "a finished branch reads full",
		TreeLayout.category_done("limits", full)
			and is_equal_approx(TreeLayout.category_progress("limits", full), 1.0),
		"progress %.2f" % [TreeLayout.category_progress("limits", full)])
	var fees: int = 0
	for cat: String in cats:
		fees += TreeLayout.category_fee(cat, full)
	var billed: int = 0
	for id: String in UpgradeDefs.ORDER:
		billed += UpgradeDefs.monthly_of(id, UpgradeDefs.tier_count(id))
	TestFixtures.check(res, "the box totals add up to the whole upgrade bill", fees == billed,
		"boxes %d bill %d" % [fees, billed])
	TestFixtures.check(res, "the Base plan tracks the whole tree",
		TreeLayout.base_counts(full).x == TreeLayout.base_counts(full).y
			and TreeLayout.base_counts({}).x == 0
			and is_zero_approx(TreeLayout.base_progress({}))
			and is_equal_approx(TreeLayout.base_progress(full), 1.0),
		"counts %s" % [TreeLayout.base_counts(full)])


#Case 3: the colour every module and every line leaves a box with.
static func _case_colors(res: Dictionary) -> void:
	var full: Dictionary = _all_max()
	TestFixtures.check(res, "the Base icon reads the progress of the whole tree",
		TreeLayout.block_color("base", {}) == GuiColors.cat_color(0.0)
			and TreeLayout.block_color("base", full) == GuiColors.cat_color(1.0),
		"empty %s" % [TreeLayout.block_color("base", {})])
	TestFixtures.check(res, "an unowned module is muted and an owned one takes its tier colour",
		TreeLayout.block_color("seats", {}) == TreeLayout.MUTED_ICON
			and TreeLayout.block_color("seats", {"seats": 1})
				== GuiColors.tier_color(0, UpgradeDefs.tier_count("seats")),
		"unowned %s" % [TreeLayout.block_color("seats", {})])
	TestFixtures.check(res, "a branch with no progress passes the Base colour through",
		TreeLayout.out_color("limits", {}, true) == TreeLayout.BASE_LINE
			and TreeLayout.out_color("limits", {}, false) == TreeLayout.BASE_LINE_OFF,
		"on %s off %s" % [TreeLayout.out_color("limits", {}, true),
			TreeLayout.out_color("limits", {}, false)])
	var part: Dictionary = {"seats": 2}
	TestFixtures.check(res, "a branch with progress leaves in its own progress colour",
		TreeLayout.out_color("limits", part, true)
			== GuiColors.cat_color(TreeLayout.category_progress("limits", part)),
		"colour %s" % [TreeLayout.out_color("limits", part, true)])
	TestFixtures.check(res, "a module leaves in its tier colour and an empty one in the gate colour",
		TreeLayout.out_color("seats", {"seats": 3}, true)
				== GuiColors.tier_color(2, UpgradeDefs.tier_count("seats"))
			and TreeLayout.out_color("seats", {}, true) == GuiColors.gate_color(0.0),
		"owned %s" % [TreeLayout.out_color("seats", {"seats": 3}, true)])
	TestFixtures.check(res, "a half full requirement reads half",
		is_equal_approx(TreeLayout.gate_fraction("criminal", GATE_FIX), 0.5),
		"fraction %.2f" % [TreeLayout.gate_fraction("criminal", GATE_FIX)])
	TestFixtures.check(res, "an over served requirement never reads past full",
		is_equal_approx(TreeLayout.gate_fraction("criminal", full), 1.0)
			and is_equal_approx(TreeLayout.gate_fraction("seats", full), 1.0),
		"fraction %.2f" % [TreeLayout.gate_fraction("criminal", full)])


#Case 4: the connector segments, their ends and the two alphas they are drawn at.
static func _case_connectors(res: Dictionary) -> void:
	var full: Dictionary = _all_max()
	var lines: Array[Dictionary] = TreeLayout.build_connectors(full, true)
	TestFixtures.check(res, "the tree draws its connectors", lines.size() > 50,
		"lines %d" % [lines.size()])
	var short_line: int = 0
	var flat: int = 0
	var odd_alpha: int = 0
	for row: Dictionary in lines:
		var points: PackedVector2Array = row["points"]
		if points.size() < 2:
			short_line += 1
			continue
		if points[0] == points[points.size() - 1]:
			flat += 1
		var alpha: float = float(row["alpha"])
		if not (is_equal_approx(alpha, 1.0) or is_equal_approx(alpha, TreeLayout.DIM)):
			odd_alpha += 1
	TestFixtures.check(res, "every segment carries two ends", short_line == 0,
		"short %d of %d" % [short_line, lines.size()])
	TestFixtures.check(res, "no segment has zero length", flat == 0,
		"flat %d of %d" % [flat, lines.size()])
	TestFixtures.check(res, "a segment is drawn solid or dimmed and nothing between", odd_alpha == 0,
		"odd %d of %d" % [odd_alpha, lines.size()])
	TestFixtures.check(res, "nothing is dimmed once every requirement is met",
		_count_alpha(lines, TreeLayout.DIM) == 0,
		"dimmed %d" % [_count_alpha(lines, TreeLayout.DIM)])
	var bare: Array[Dictionary] = TreeLayout.build_connectors({}, true)
	TestFixtures.check(res, "an unreachable module is reached by a dimmed line",
		_count_alpha(bare, TreeLayout.DIM) > 0,
		"dimmed %d" % [_count_alpha(bare, TreeLayout.DIM)])
	TestFixtures.check(res, "the Base arms run orange on Enterprise",
		_has_color(bare, TreeLayout.BASE_LINE), "no orange arm")
	var off: Array[Dictionary] = TreeLayout.build_connectors({}, false)
	TestFixtures.check(res, "the Base arms turn blue below Enterprise",
		_has_color(off, TreeLayout.BASE_LINE_OFF) and not _has_color(off, TreeLayout.BASE_LINE),
		"no blue arm")
	TestFixtures.check(res, "a finished branch turns its arm green",
		_has_color(lines, GuiColors.cat_color(1.0)), "no green arm")
	var half: Array[Dictionary] = TreeLayout.build_connectors(GATE_FIX, true)
	TestFixtures.check(res, "the leg out of a gate carries the average of its sources",
		_has_color(half, GuiColors.gate_color(0.5)),
		"no half gate colour among %d lines" % [half.size()])
	TestFixtures.check(res, "a met gate leaves solid and a short one dimmed",
		_color_alpha(lines, GuiColors.gate_color(1.0), 1.0)
			and _color_alpha(half, GuiColors.gate_color(0.5), TreeLayout.DIM),
		"gate alphas")
	var every: Array[Dictionary] = []
	every.append_array(lines)
	every.append_array(bare)
	every.append_array(half)
	var off_band: Array[String] = []
	var checked: int = 0
	for row: Dictionary in every:
		var points: PackedVector2Array = row["points"]
		if points.size() < 2:
			continue
		var at_a: Vector2 = points[0]
		var at_b: Vector2 = points[points.size() - 1]
		if not is_equal_approx(at_a.x, at_b.x) or is_equal_approx(at_a.y, at_b.y):
			continue
		checked += 1
		if not _same_band(at_a, at_b):
			off_band.append("%s to %s" % [at_a, at_b])
	if not _same_band(Vector2(10.0, 20.0), Vector2(10.0, 100.0)):
		off_band.append("downward")
	if not _same_band(Vector2(10.0, 100.0), Vector2(10.0, 20.0)):
		off_band.append("upward")
	TestFixtures.check(res, "a vertical segment drawn in two colours covers the same band",
		off_band.is_empty(), TestFixtures.detail(off_band, checked + 2, "segments"))
	var built: Dictionary = TreeLayout.build(GATE_FIX, true)
	var packed: Array[Dictionary] = built["lines"]
	var rows: Array[Dictionary] = built["gates"]
	TestFixtures.check(res, "one build hands back the same lines and gates",
		packed.size() == half.size() and rows.size() == TreeLayout.gates_for(GATE_FIX, true).size(),
		"lines %d gates %d" % [packed.size(), rows.size()])


#The gradient quad of one segment and the solid band of the same segment cover one rectangle.
static func _same_band(a: Vector2, b: Vector2) -> bool:
	var band: Rect2 = TreeCanvas.bar_rect(a, b)
	var quad: PackedVector2Array = TreeCanvas.quad_points(a, b)
	var bounds: Rect2 = Rect2(quad[0], Vector2.ZERO)
	for at: Vector2 in quad:
		bounds = bounds.expand(at)
	return bounds.position.is_equal_approx(band.position) and bounds.size.is_equal_approx(band.size)


static func _count_alpha(lines: Array[Dictionary], alpha: float) -> int:
	var total: int = 0
	for row: Dictionary in lines:
		if is_equal_approx(float(row["alpha"]), alpha):
			total += 1
	return total


static func _has_color(lines: Array[Dictionary], tint: Color) -> bool:
	for row: Dictionary in lines:
		var first: Color = row["color_a"]
		var last: Color = row["color_b"]
		if first == tint or last == tint:
			return true
	return false


static func _color_alpha(lines: Array[Dictionary], tint: Color, alpha: float) -> bool:
	for row: Dictionary in lines:
		var first: Color = row["color_a"]
		if first == tint and is_equal_approx(float(row["alpha"]), alpha):
			return true
	return false


#Case 5: the requirement gates, the numbers they print and the lane they sit in.
static func _case_gates(res: Dictionary) -> void:
	var wanted: int = 0
	for id: String in UpgradeDefs.ORDER:
		if UpgradeDefs.requirement_need(id) > 0:
			wanted += 1
	var rows: Array[Dictionary] = TreeLayout.gates_for({})
	TestFixtures.check(res, "one gate stands on every requirement", rows.size() == wanted,
		"gates %d requirements %d" % [rows.size(), wanted])
	var needs: Dictionary = {"criminal": 6, "education": 3, "skilltest": 2, "customer": 2,
		"fastmetrics": 2, "counsel": 5, "guildpromo": 5}
	var wrong: Array[String] = []
	for id: Variant in needs:
		var key: String = String(id)
		if int(_gate_row(rows, key).get("need", -1)) != int(needs[id]):
			wrong.append(key)
	TestFixtures.check(res, "each named gate asks for the tiers its upgrade needs", wrong.is_empty(),
		TestFixtures.detail(wrong, needs.size(), "gates"))
	var half: Array[Dictionary] = TreeLayout.gates_for(GATE_FIX)
	var criminal: Dictionary = _gate_row(half, "criminal")
	var education: Dictionary = _gate_row(half, "education")
	TestFixtures.check(res, "a gate counts the tiers already standing under it",
		int(criminal.get("have", -1)) == 3 and int(education.get("have", -1)) == 1
			and not bool(criminal.get("met", true)),
		"criminal %s education %s" % [criminal.get("have", -1), education.get("have", -1)])
	TestFixtures.check(res, "a gate never counts past what it asks for",
		int(_gate_row(TreeLayout.gates_for(_all_max()), "criminal").get("have", -1)) == 6,
		"have %s" % [_gate_row(TreeLayout.gates_for(_all_max()), "criminal").get("have", -1)])
	var met: Array[Dictionary] = TreeLayout.gates_for(_all_max(), true)
	var open_gates: int = 0
	for row: Dictionary in met:
		if bool(row["met"]):
			open_gates += 1
	TestFixtures.check(res, "every gate opens once the tree is finished", open_gates == met.size(),
		"open %d of %d" % [open_gates, met.size()])
	var boxes: Array[String] = []
	for row: Dictionary in half:
		var lane: Rect2 = row["rect"]
		var tint: Color = row["color"]
		var fits: bool = lane.size == TreeLayout.GATE_BOX
		fits = fits and tint == GuiColors.gate_color(TreeLayout.gate_fraction(String(row["id"]),
			GATE_FIX))
		if not fits:
			boxes.append(String(row["id"]))
	TestFixtures.check(res, "each gate holds one lane box in its own colour", boxes.is_empty(),
		TestFixtures.detail(boxes, half.size(), "gates"))


static func _gate_row(rows: Array[Dictionary], id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row["id"]) == id:
			return row
	return {}


#Case 6: the pan, its margins and the jump that centres one module.
static func _case_pan(res: Dictionary, tree: SkillTree) -> void:
	var frame: Vector2 = tree.view()
	TestFixtures.check(res, "the frame reads its own size, and a fixed one before it has any",
		frame == tree.size and SkillTree.DEFAULT_VIEW == VIEW,
		"view %s size %s" % [frame, tree.size])
	tree.home()
	var start: Vector2 = tree.pan()
	TestFixtures.check(res, "the first view is the home pan",
		start.is_equal_approx(TreeLayout.clamp_pan(TreeLayout.home_pan(frame), frame)),
		"pan %s" % [start])
	var bg: Dictionary = TreeLayout.geo("base")
	var bl: float = float(bg["l"])
	var br: float = float(bg["r"])
	var bt: float = float(bg["t"])
	var btb: float = float(bg["tb"])
	for c: Dictionary in TreeLayout.CATS:
		var cg: Dictionary = TreeLayout.geo(String(c["id"]))
		bl = minf(bl, float(cg["l"]))
		br = maxf(br, float(cg["r"]))
		bt = minf(bt, float(cg["t"]))
		btb = maxf(btb, float(cg["tb"]))
	var centre: Vector2 = Vector2((bl + br) / 2.0, (bt + btb) / 2.0)
	var framed: Vector2 = tree.pan() + centre + Vector2(0.0, TreeLayout.OY)
	TestFixtures.check(res, "the home view centres Base and every category exactly",
		absf(framed.x - frame.x / 2.0) <= 0.5 and absf(framed.y - frame.y / 2.0) <= 0.5,
		"centre %s frame/2 %s" % [framed, frame / 2.0])
	var base_x: float = start.x + TreeLayout.BASE_X
	TestFixtures.check(res, "the home view holds the Base column",
		base_x > 0.0 and base_x < frame.x, "base at %.0f" % [base_x])
	TestFixtures.check(res, "the world never slides past its margin",
		TreeLayout.clamp_pan(Vector2(9000.0, 9000.0), frame)
			== Vector2(TreeLayout.PAN_MARGIN, TreeLayout.PAN_MARGIN)
			and TreeLayout.clamp_pan(Vector2(-90000.0, -90000.0), frame)
				== Vector2(frame.x - TreeLayout.WORLD.x - TreeLayout.PAN_MARGIN,
					frame.y - TreeLayout.WORLD.y - TreeLayout.PAN_MARGIN),
		"clamp %s" % [TreeLayout.clamp_pan(Vector2(9000.0, 9000.0), frame)])
	tree.set_pan(Vector2(9000.0, 9000.0))
	TestFixtures.check(res, "a drag stays inside the margin",
		tree.pan() == Vector2(TreeLayout.PAN_MARGIN, TreeLayout.PAN_MARGIN)
			and tree.canvas().position == tree.pan(),
		"pan %s canvas %s" % [tree.pan(), tree.canvas().position])
	tree.set_pan(Vector2(9000.0, 9000.0), false)
	TestFixtures.check(res, "a jump is free to leave the margin",
		tree.pan() == Vector2(9000.0, 9000.0), "pan %s" % [tree.pan()])
	var mid: Vector2 = TreeLayout.focus_pan("counsel", frame) + TreeLayout.block_center("counsel")
	TestFixtures.check(res, "the focus pan puts a module in the middle of the frame",
		(mid + Vector2(0.0, TreeLayout.OY)).is_equal_approx(frame / 2.0),
		"centre %s" % [mid + Vector2(0.0, TreeLayout.OY)])
	tree.home()


#Case 7: the deep link, the click on one module and the Take Me There relay.
static func _case_focus(res: Dictionary, host: Node, tree: SkillTree) -> void:
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	var dialog: UpgradeTierDialog = tree.dialog()
	var frame: Vector2 = tree.view()
	tree.focus_upgrade("counsel", 3)
	var centre: Vector2 = tree.pan() + TreeLayout.block_center("counsel") \
		+ Vector2(0.0, TreeLayout.OY)
	TestFixtures.check(res, "a deep link centres the module it names",
		centre.is_equal_approx(frame / 2.0), "centre %s" % [centre])
	TestFixtures.check(res, "a deep link opens the popover on that module",
		dialog.is_open() and dialog.upgrade_id() == "counsel" and not tree.tooltip().visible,
		"open %s id %s" % [dialog.is_open(), dialog.upgrade_id()])
	var spot: Vector2 = dialog.position
	var inside: bool = spot.x >= SkillTree.DIALOG_MARGIN and spot.y >= SkillTree.DIALOG_MARGIN
	inside = inside and spot.x + UpgradeTierDialog.BOX.x <= frame.x - SkillTree.DIALOG_MARGIN
	inside = inside and spot.y + UpgradeTierDialog.BOX.y <= frame.y - SkillTree.DIALOG_MARGIN
	TestFixtures.check(res, "the popover stays inside the frame", inside, "at %s" % [spot])
	TestFixtures.check(res, "the popover holds one row per tier",
		dialog.row_count() == UpgradeDefs.tier_count("counsel"),
		"rows %d tiers %d" % [dialog.row_count(), UpgradeDefs.tier_count("counsel")])
	tree.close_dialog()
	tree.focus_upgrade("nosuchupgrade", 1)
	TestFixtures.check(res, "a deep link to nothing opens nothing", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	tree.press_block("base")
	TestFixtures.check(res, "the Base plan has no popover", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	tree.press_block("oddjobs")
	TestFixtures.check(res, "no module opens below Enterprise", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	tree.press_block("criminal")
	TestFixtures.check(res, "a module behind a shut gate does not open", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	tree.press_block("oddjobs")
	TestFixtures.check(res, "a reachable module opens on a click",
		dialog.is_open() and dialog.upgrade_id() == "oddjobs",
		"open %s id %s" % [dialog.is_open(), dialog.upgrade_id()])
	TestFixtures.check(res, "Take Me There is the shared BevelButton scene",
		dialog._plans is BevelButton and dialog._plans.kind == &"blue"
			and dialog._plans.text == UpgradeTierDialog.PLANS_TEXT,
		"plans %s" % [dialog._plans.kind])
	var seen: Array[String] = []
	tree.go_to_plans_pressed.connect(func() -> void: seen.append("plans"))
	dialog.press_plans()
	TestFixtures.check(res, "Take Me There closes the popover and asks for the Plans tab",
		seen.size() == 1 and not dialog.is_open(), "seen %d" % [seen.size()])
	tree.canvas().hover_changed.emit("cat", "limits", Rect2(Vector2(200.0, 200.0),
		TreeLayout.CAT_BOX))
	TestFixtures.check(res, "a hover card shows once the popover is gone", tree.tooltip().visible,
		"visible %s" % [tree.tooltip().visible])
	tree.press_block("oddjobs")
	tree.canvas().hover_changed.emit("cat", "limits", Rect2(Vector2(200.0, 200.0),
		TreeLayout.CAT_BOX))
	TestFixtures.check(res, "no hover card stands behind an open popover",
		not tree.tooltip().visible, "visible %s" % [tree.tooltip().visible])
	tree.close_dialog()
	tree.tooltip().hide_tip()
	TestFixtures.check(res, "the tree is not being dragged on its own", not tree.is_dragging(),
		"dragging %s" % [tree.is_dragging()])


#The "name count" of each named child under the base that does not hold exactly one NoteIcon.
static func _glyph_misses(base: Node, prefix: String, names: Array[String]) -> Array[String]:
	var misses: Array[String] = []
	for entry: String in names:
		var line: Node = base.get_node_or_null(prefix + entry)
		var glyphs: int = 0
		if line != null:
			for child: Node in line.get_children():
				if child is NoteIcon:
					glyphs += 1
		if glyphs != 1:
			misses.append("%s %d" % [entry, glyphs])
	return misses


#Case 8: the tier rows of the popover and the readout above them.
static func _case_rows(res: Dictionary, host: Node, tree: SkillTree) -> void:
	_small_guild()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"oddjobs": 1})
	await host.get_tree().process_frame
	var dialog: UpgradeTierDialog = tree.dialog()
	dialog.open_for("oddjobs")
	var style: StyleBoxFlat = dialog.get_theme_stylebox("panel") as StyleBoxFlat
	var frame_bg: Color = style.bg_color if style != null else Color.BLACK
	var frame_px: int = style.border_width_left if style != null else 0
	TestFixtures.check(res, "the popover wears the frame the prototype draws",
		style != null and frame_bg.is_equal_approx(GuiColors.BOX_BG) and frame_px == 4
			and style.border_width_top == 4 and style.border_width_right == 4
			and style.border_width_bottom == 4,
		"bg %s border %d" % [frame_bg, frame_px])
	var bare_lines: Array[String] = _glyph_misses(dialog, "Pad/Col/Controls/Clip/Middle/",
		["Today", "Monthly", "MaxNote"])
	TestFixtures.check(res, "every money line of the popover carries one notes glyph",
		bare_lines.is_empty(), TestFixtures.detail(bare_lines, 3, "lines"))
	var row0: PanelContainer = dialog.get_node("Pad/Col/Tiers/Rows").get_child(0) as PanelContainer
	var row_icon: IconRect = row0.get_node("Line/Icon") as IconRect
	TestFixtures.check(res, "a tier row carries its module icon in a 38 px row",
		row_icon != null and row_icon.icon_id == TreeIcons.id_of("oddjobs")
			and row_icon.pixel_scale == 2
			and row_icon.custom_minimum_size == Vector2(32, 32)
			and is_equal_approx(row0.custom_minimum_size.y, UpgradeTierDialog.ROW_ICON),
		"icon %s row %.1f" % [str(row_icon.custom_minimum_size) if row_icon != null else "null",
			row0.custom_minimum_size.y])
	TestFixtures.check(res, "the popover names the tier owned out of the tiers there are",
		dialog.tier_label_text() == "Tier 1 / 3" and dialog.tier() == 1 and dialog.max_tier() == 3,
		"label %s" % [dialog.tier_label_text()])
	TestFixtures.check(res, "the rows run owned, next, then locked",
		dialog.row_count() == 3 and dialog.row_state(0) == "have"
			and dialog.row_state(1) == "next" and dialog.row_state(2) == "locked",
		"states %s %s %s" % [dialog.row_state(0), dialog.row_state(1), dialog.row_state(2)])
	TestFixtures.check(res, "a row is labelled in Roman numerals and the next one by name",
		dialog.row_label(0) == "Tier I" and dialog.row_label(1) == UpgradeTierDialog.NEXT_LABEL
			and dialog.row_label(2) == "Tier III",
		"labels %s %s %s" % [dialog.row_label(0), dialog.row_label(1), dialog.row_label(2)])
	TestFixtures.check(res, "each row prints what its tier hands the guild",
		dialog.row_text(0) == UpgradeDefs.tier_text("oddjobs", 1)
			and dialog.row_text(2) == UpgradeDefs.tier_text("oddjobs", 3),
		"row %s" % [dialog.row_text(0)])
	TestFixtures.check(res, "an owned row takes its tier colour, the next one orange",
		dialog.row_label_color(0) == GuiColors.tier_color(0, 3)
			and dialog.row_label_color(1) == UpgradeTierDialog.NAME_COLOR
			and dialog.row_label_color(2) == UpgradeTierDialog.LOCKED_LABEL,
		"colour %s" % [dialog.row_label_color(0)])
	TestFixtures.check(res, "a locked row reads muted and an owned one cream",
		dialog.row_text_color(0) == UpgradeTierDialog.CREAM
			and dialog.row_text_color(1) == UpgradeTierDialog.NEXT_TEXT
			and dialog.row_text_color(2) == UpgradeTierDialog.LOCKED_TEXT,
		"colour %s" % [dialog.row_text_color(2)])
	TestFixtures.check(res, "each row wears the frame of its state",
		dialog.row_style(0) == UpgradeTierDialog.HAVE_STYLE
			and dialog.row_style(1) == UpgradeTierDialog.NEXT_STYLE
			and dialog.row_style(2) == UpgradeTierDialog.LOCKED_STYLE,
		"style %s" % [dialog.row_style(1)])
	dialog.scroll_to_tier(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "asking for a tier keeps every row in place", dialog.row_count() == 3,
		"rows %d" % [dialog.row_count()])
	TestFixtures.check(res, "the next tier prices itself per month and against the bill",
		dialog.next_fee() == SubscriptionManager.tier_price("oddjobs", 2)
			and dialog.monthly_text() == "+%d/month starting Rua %s" % [dialog.next_fee(),
				TrynnCalendar.ordinal(SubscriptionManager.BILL_DAY)],
		"monthly %s" % [dialog.monthly_text()])
	TestFixtures.check(res, "the charge today is the tier price pro rated to the 2nd",
		dialog.charge_today() == 9 and dialog.today_text() == "9 today",
		"today %s" % [dialog.today_text()])
	TestFixtures.check(res, "the popover is not refusing anything on open",
		not dialog.is_rejecting() and dialog.reject_kind() == "" and dialog.reason_text() == "",
		"reason %s" % [dialog.reason_text()])
	TestFixtures.check(res, "a tier chunk sits at rest while the upgrade is unfinished",
		is_equal_approx(dialog.chunk_glow(0), 1.0) and not dialog.is_max(),
		"glow %.2f" % [dialog.chunk_glow(0)])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	dialog.open_for("aptitude")
	TestFixtures.check(res, "a finished upgrade asks for nothing more",
		dialog.is_max() and dialog.charge_today() == 0 and dialog.next_fee() == 0
			and dialog.tier_label_text() == "Tier 1 / 1",
		"label %s today %d" % [dialog.tier_label_text(), dialog.charge_today()])
	TestFixtures.check(res, "a finished upgrade prints the fee it goes on billing",
		dialog.max_note_text() == "%d/month" % [SubscriptionManager.upgrade_fee("aptitude")],
		"note %s" % [dialog.max_note_text()])
	TestFixtures.check(res, "only seats and contracts carry an in use line",
		dialog.in_use_text() == "", "line %s" % [dialog.in_use_text()])
	#The popover is BOX tall in the game; the first headless layout pass wraps its autowrap labels
	#at no width and leaves the panel stretched, so it is put back on its own size and settles
	#before the deep link asks for a tier of a list that does not fit.
	dialog.reset_size()
	await GuiHiringTests._frames(host, 2)
	dialog.open_for("seats")
	var top_tier: int = dialog.max_tier()
	dialog.scroll_to_tier(top_tier)
	await GuiHiringTests._frames(host, 2)
	TestFixtures.check(res, "the first open of a long upgrade scrolls the asked tier into view",
		dialog.row_count() == top_tier and top_tier == 8 and dialog.tier_scroll() > 0
			and dialog.tier_scroll() <= dialog.row_offset(top_tier - 1),
		"scroll %d last row %d rows %d" % [dialog.tier_scroll(),
			dialog.row_offset(top_tier - 1), dialog.row_count()])
	dialog.scroll_to_tier(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "asking for the first tier scrolls back to the top",
		dialog.tier_scroll() == dialog.row_offset(0) and dialog.row_count() == top_tier,
		"scroll %d rows %d" % [dialog.tier_scroll(), dialog.row_count()])
	dialog.press_close()
	TestFixtures.check(res, "the X shuts the popover", not dialog.is_open(),
		"open %s" % [dialog.is_open()])


#Case 9: plus and minus, the refusals they print and what a drop takes with it.
static func _case_money(res: Dictionary, host: Node, tree: SkillTree) -> void:
	_small_guild()
	TestFixtures.check(res, "the small guild has the fallback income to spend",
		SubscriptionManager.budget_available() == SubscriptionManager.BUDGET_FALLBACK,
		"budget %d" % [SubscriptionManager.budget_available()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	var dialog: UpgradeTierDialog = tree.dialog()
	dialog.open_for("oddjobs")
	TestFixtures.check(res, "the first tier is priced pro rated as well",
		dialog.tier() == 0 and dialog.charge_today() == 5,
		"tier %d today %d" % [dialog.tier(), dialog.charge_today()])
	dialog.press_plus()
	TestFixtures.check(res, "plus buys the next tier",
		dialog.tier() == 1 and not dialog.is_rejecting() and dialog.reason_text() == ""
			and SubscriptionManager.tier_of("oddjobs") == 1,
		"tier %d reason %s" % [dialog.tier(), dialog.reason_text()])
	TestFixtures.check(res, "the income line reads what the month has left",
		dialog.income_text() == str(dialog.income_value())
			and dialog.income_value() == SubscriptionManager.budget_available()
				- SubscriptionManager.service_fee() - SubscriptionManager.upgrade_fee(),
		"income %s" % [dialog.income_text()])
	dialog.press_minus()
	TestFixtures.check(res, "minus drops the tier again",
		dialog.tier() == 0 and not dialog.is_rejecting(),
		"tier %d" % [dialog.tier()])
	TestFixtures.check(res, "a tier this cycle already paid for costs nothing today",
		dialog.charge_today() == 0 and dialog.today_text() == "0 today"
			and SubscriptionManager.prepaid_tier("oddjobs") == 1,
		"today %s" % [dialog.today_text()])
	dialog.press_plus()
	TestFixtures.check(res, "buying it back is allowed", dialog.tier() == 1
		and not dialog.is_rejecting(), "tier %d" % [dialog.tier()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"opspermit": 1, "representation": 2})
	await host.get_tree().process_frame
	dialog.open_for("representation")
	dialog.press_plus()
	TestFixtures.check(res, "an upgrade over the monthly income is refused",
		dialog.is_rejecting() and dialog.reject_kind() == "up"
			and dialog.reason_text() == "Not enough monthly income."
			and dialog.tier() == 2,
		"reason %s tier %d" % [dialog.reason_text(), dialog.tier()])
	TestFixtures.check(res, "the income line turns red on a refusal",
		dialog.income_color() == UpgradeTierDialog.RED, "colour %s" % [dialog.income_color()])
	TestFixtures.check(res, "an income refusal starts the income pulse",
		dialog.is_flashing() and is_equal_approx(dialog.flash_scale(), 1.0)
			and is_equal_approx(dialog.income_scale(), 1.0),
		"flashing %s scale %.3f" % [dialog.is_flashing(), dialog.income_scale()])
	var pulse: float = UpgradeTierDialog.FLASH_SECONDS / float(UpgradeTierDialog.FLASH_COUNT)
	var elapsed: float = 0.0
	var peaks: int = 0
	var edges: int = 0
	for k: int in UpgradeTierDialog.FLASH_COUNT:
		var middle: float = (float(k) + 0.5) * pulse
		dialog.step_flash(middle - elapsed)
		elapsed = middle
		if (absf(dialog.flash_scale() - UpgradeTierDialog.FLASH_SCALE) <= PULSE_TOL
				and absf(dialog.income_scale() - UpgradeTierDialog.FLASH_SCALE) <= PULSE_TOL
				and dialog.income_glow().is_equal_approx(UpgradeTierDialog.GLOW)):
			peaks += 1
		var edge: float = float(k + 1) * pulse
		dialog.step_flash(edge - elapsed)
		elapsed = edge
		if absf(dialog.flash_scale() - 1.0) <= PULSE_TOL:
			edges += 1
	TestFixtures.check(res, "the pulse peaks three times inside the refusal window",
		peaks == UpgradeTierDialog.FLASH_COUNT and edges == UpgradeTierDialog.FLASH_COUNT,
		"peaks %d edges %d" % [peaks, edges])
	dialog.step_flash(PULSE_TOL)
	TestFixtures.check(res, "the pulse ends with the refusal window",
		not dialog.is_flashing() and dialog.income_scale() == 1.0 and dialog.income_glow() == Color.WHITE,
		"flashing %s scale %.3f glow %s" % [dialog.is_flashing(), dialog.income_scale(), dialog.income_glow()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"representation": SubscriptionManager.max_tier("representation")})
	await host.get_tree().process_frame
	dialog.open_for("representation")
	dialog.press_plus()
	TestFixtures.check(res, "a highest tier refusal leaves the number still",
		dialog.is_rejecting() and dialog.reject_kind() == "up"
			and dialog.reason_text() == "Already at the highest tier."
			and not dialog.is_flashing() and dialog.income_scale() == 1.0,
		"reason %s flashing %s scale %.3f" % [dialog.reason_text(), dialog.is_flashing(),
			dialog.income_scale()])
	_set_crew(UpgradeDefs.ENTERPRISE_MERCS + 6)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2})
	await host.get_tree().process_frame
	dialog.open_for("seats")
	var line: String = UpgradeTierDialog.SEATS_LINE % [2, UpgradeDefs.ENTERPRISE_MERCS + 6]
	TestFixtures.check(res, "the seats popover names the mercs holding the tier down",
		dialog.in_use_text() == line, "line %s" % [dialog.in_use_text()])
	dialog.press_minus()
	TestFixtures.check(res, "a tier the roster is using cannot be dropped",
		dialog.is_rejecting() and dialog.reject_kind() == "down" and dialog.reason_text() == line
			and dialog.tier() == 2,
		"reason %s tier %d" % [dialog.reason_text(), dialog.tier()])
	_set_crew(CREW)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"opspermit": 1, "representation": 1})
	await host.get_tree().process_frame
	dialog.open_for("opspermit")
	dialog.press_minus()
	TestFixtures.check(res, "dropping a tier takes down what stood on it",
		not dialog.is_rejecting() and SubscriptionManager.tier_of("opspermit") == 0
			and SubscriptionManager.tier_of("representation") == 0,
		"permit %d counsel %d" % [SubscriptionManager.tier_of("opspermit"),
			SubscriptionManager.tier_of("representation")])
	dialog.open_for("representation")
	TestFixtures.check(res, "the first row is up for sale again after a cascade",
		dialog.row_state(0) == "next" and dialog.tier() == 0,
		"state %s" % [dialog.row_state(0)])
	dialog.close()


#Case 10: the hover card of a branch, the Base plan, a gate and one module.
static func _case_tooltip(res: Dictionary, host: Node, tree: SkillTree) -> void:
	var state: Dictionary = {"discrim": 2, "background": 1, "seats": 2}
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, state)
	await host.get_tree().process_frame
	var tip: TreeTooltip = tree.tooltip()
	var anchor: Rect2 = Rect2(Vector2(100.0, 10.0), TreeLayout.CAT_BOX)
	tip.show_for("cat", "limits", anchor, VIEW)
	var counts: Vector2i = TreeLayout.category_counts("limits", state)
	TestFixtures.check(res, "a branch card names the branch and what it owns",
		not tip.is_rich() and tip.kind_text() == TreeTooltip.CAT_KIND
			and tip.name_text() == String(TreeLayout.cat_def("limits")["name"])
			and tip.close_text() == "%d/%d upgrades owned" % [counts.x, counts.y],
		"close %s" % [tip.close_text()])
	TestFixtures.check(res, "a plain card sits below its anchor",
		tip.visible and is_equal_approx(tip.position.y, anchor.end.y + TreeTooltip.EDGE_GAP)
			and is_equal_approx(tip.position.x, anchor.position.x + TreeTooltip.SIDE_INSET),
		"at %s" % [tip.position])
	var low: Rect2 = Rect2(Vector2(100.0, 500.0), TreeLayout.CAT_BOX)
	tip.show_for("cat", "limits", low, VIEW)
	TestFixtures.check(res, "a card with no room below flips above its anchor",
		is_equal_approx(tip.position.y, low.position.y - tip.tip_height())
			and is_equal_approx(tip.tip_height(), TreeTooltip.PLAIN_HEIGHT),
		"at %s height %.0f" % [tip.position, tip.tip_height()])
	tip.show_for("cat", "limits", Rect2(Vector2(1100.0, 10.0), TreeLayout.CAT_BOX), VIEW)
	TestFixtures.check(res, "a card never runs off the right edge",
		is_equal_approx(tip.position.x, VIEW.x - TreeTooltip.RIGHT_ROOM),
		"at %s" % [tip.position])
	tip.show_for("block", "base", anchor, VIEW)
	TestFixtures.check(res, "the Base card explains the root of the tree",
		tip.kind_text() == TreeLayout.BASE_KIND and tip.name_text() == TreeLayout.BASE_NAME
			and tip.desc_text() == TreeLayout.BASE_DESC and not tip.is_rich(),
		"name %s" % [tip.name_text()])
	tip.show_for("gate", "criminal", anchor, VIEW)
	TestFixtures.check(res, "a gate card counts the upgrades still missing",
		tip.kind_text() == TreeTooltip.GATE_KIND
			and tip.name_text() == UpgradeDefs.name_of("criminal")
			and tip.desc_text() == "3 prior upgrades still required",
		"desc %s" % [tip.desc_text()])
	tip.show_for("block", "seats", anchor, VIEW)
	var fee: int = SubscriptionManager.upgrade_fee("seats")
	TestFixtures.check(res, "a module card prints its tiers, its fee and the next tier",
		tip.is_rich() and tip.stat_text() == "2/8   %d/month" % [fee]
			and tip.next_text() == UpgradeDefs.tier_text("seats", 3)
			and tip.next_fee_text() == "+%d/month" % [SubscriptionManager.tier_price("seats", 3)],
		"stat %s next %s" % [tip.stat_text(), tip.next_fee_text()])
	TestFixtures.check(res, "a reachable module card carries no warning",
		tip.note_text() == "" and is_equal_approx(tip.tip_height(), TreeTooltip.RICH_HEIGHT),
		"note %s" % [tip.note_text()])
	var plain_rows: Array[String] = _glyph_misses(tip, "Pad/Rows/", ["Stat", "NextFee"])
	TestFixtures.check(res, "both fee rows of the hover card carry one notes glyph",
		plain_rows.is_empty(), TestFixtures.detail(plain_rows, 2, "rows"))
	tip.show_for("block", "criminal", anchor, VIEW)
	TestFixtures.check(res, "a gated module card repeats what it is waiting on",
		tip.note_text() == "3 prior upgrades still required",
		"note %s" % [tip.note_text()])
	TestFixtures.check(res, "the hover card heads itself with the module icon",
		tip.icon_id() == TreeIcons.id_of("criminal"), "id '%s'" % [tip.icon_id()])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	tip.show_for("gate", "criminal", anchor, VIEW)
	TestFixtures.check(res, "a met requirement says so",
		tip.desc_text() == TreeTooltip.MET_TEXT, "desc %s" % [tip.desc_text()])
	TestFixtures.check(res, "a requirement card shows no icon at all",
		tip.icon_id() == "", "id '%s'" % [tip.icon_id()])
	tip.show_for("block", "aptitude", anchor, VIEW)
	TestFixtures.check(res, "a finished module card drops the next tier lines",
		tip.next_text() == "" and tip.next_fee_text() == ""
			and is_equal_approx(tip.tip_height(), TreeTooltip.MAXED_HEIGHT),
		"height %.0f" % [tip.tip_height()])
	tip.show_for("", "", anchor, VIEW)
	TestFixtures.check(res, "an empty hover puts the card away", not tip.visible,
		"visible %s" % [tip.visible])


#Case 11: the world the tree stands on and the state its children read.
static func _case_canvas(res: Dictionary, tree: SkillTree) -> void:
	var canvas: TreeCanvas = tree.canvas()
	TestFixtures.check(res, "the world is the size the layout asks for",
		canvas.size == TreeLayout.WORLD, "size %s" % [canvas.size])
	TestFixtures.check(res, "the world holds one child per module, box and gate",
		canvas.block_ids().size() == TreeLayout.PLACE.size()
			and canvas.gate_ids().size() == TreeLayout.gates_for({}).size()
			and canvas.cat_box("limits") != null,
		"blocks %d gates %d" % [canvas.block_ids().size(), canvas.gate_ids().size()])
	var wrong: Array[String] = []
	for id: String in canvas.block_ids():
		var mod: CustomizeBlock = canvas.block(id)
		var want: Vector2 = TreeLayout.block_rect(id).position + Vector2(0.0, TreeLayout.OY)
		if not mod.position.is_equal_approx(want) or mod.upgrade_id != id:
			wrong.append(id)
	TestFixtures.check(res, "every module stands on its own cell", wrong.is_empty(),
		TestFixtures.detail(wrong, canvas.block_ids().size(), "modules"))
	SubscriptionManager.max_out()
	canvas.refresh()
	var stuck: Array[String] = []
	for id: String in canvas.block_ids():
		var mod: CustomizeBlock = canvas.block(id)
		if mod.is_base():
			continue
		if mod.is_gated() or not mod.is_usable() or not mod.is_maxed():
			stuck.append(id)
	TestFixtures.check(res, "every module is open once the tree is finished", stuck.is_empty(),
		TestFixtures.detail(stuck, canvas.block_ids().size(), "modules"))
	var unlit: Array[String] = []
	for cat: String in TreeLayout.cat_ids():
		var box: CategoryBox = canvas.cat_box(cat)
		if not box.is_complete() or box.bg_color() != CategoryBox.DONE_BG:
			unlit.append(cat)
	TestFixtures.check(res, "a finished branch box turns green", unlit.is_empty(),
		TestFixtures.detail(unlit, TreeLayout.cat_ids().size(), "boxes"))
	var money_box: CategoryBox = canvas.cat_box("limits")
	TestFixtures.check(res, "a branch box prints its total and the monthly suffix beside the glyph",
		money_box.total_text() == CategoryBox.TOTAL_PREFIX + str(money_box.monthly_fee())
			and money_box.total_suffix() == "/month"
			and money_box.monthly_fee() == TreeLayout.category_fee("limits",
				SubscriptionManager.tiers()),
		"total %s%s" % [money_box.total_text(), money_box.total_suffix()])
	var shut: Array[String] = []
	for id: String in canvas.gate_ids():
		var node: RequirementGate = canvas.gate(id)
		if not node.is_met() or node.text_value() != "%d/%d" % [node.need, node.need]:
			shut.append(id)
	TestFixtures.check(res, "every gate reads full once the tree is finished", shut.is_empty(),
		TestFixtures.detail(shut, canvas.gate_ids().size(), "gates"))
	TestFixtures.check(res, "the Base module reads the progress of the whole tree",
		canvas.block("base").icon_color()
			== GuiColors.cat_color(TreeLayout.base_progress(SubscriptionManager.tiers())),
		"colour %s" % [canvas.block("base").icon_color()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	canvas.refresh()
	TestFixtures.check(res, "below Enterprise every module dims and its ring goes dark",
		not canvas.block("seats").is_usable()
			and canvas.block("seats").ring_color() == CustomizeBlock.RING_OFF
			and is_equal_approx(canvas.block("seats").alpha_value(), CustomizeBlock.DIM_ALPHA),
		"ring %s" % [canvas.block("seats").ring_color()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, GATE_FIX)
	canvas.refresh()
	TestFixtures.check(res, "a gated module dims while a reachable one stays lit",
		canvas.block("criminal").is_gated() and not canvas.block("oddjobs").is_gated()
			and canvas.block("oddjobs").is_usable()
			and is_equal_approx(canvas.block("criminal").alpha_value(), CustomizeBlock.DIM_ALPHA),
		"criminal %s" % [canvas.block("criminal").is_gated()])
	TestFixtures.check(res, "a gate prints the tiers it has out of the tiers it wants",
		canvas.gate("criminal").text_value() == "3/6"
			and canvas.gate("criminal").gate_color() == GuiColors.gate_color(0.5),
		"gate %s" % [canvas.gate("criminal").text_value()])
	TestFixtures.check(res, "an unfinished branch box drops back to its plain frame",
		not canvas.cat_box("limits").is_complete()
			and canvas.cat_box("limits").bg_color() == CategoryBox.BG
			and canvas.cat_box("limits").progress_text() == "0/12",
		"progress %s" % [canvas.cat_box("limits").progress_text()])


#Case 12: the first view follows the real frame once it settles, and every resize after it,
#unless the player has moved the view; a move keeps its pan across a later resize.
static func _case_follow(res: Dictionary, host: Node) -> void:
	var tree: SkillTree = TREE.instantiate() as SkillTree
	host.add_child(tree)
	await GuiHiringTests._frames(host, 2)
	var real: Vector2 = Vector2(1192.0, 527.0)
	tree.size = real
	await GuiHiringTests._frames(host, 2)
	var home_a: Vector2 = TreeLayout.clamp_pan(TreeLayout.home_pan(real), real)
	TestFixtures.check(res, "the first view follows the real frame once it settles",
		tree.view() == real and (tree.pan() - home_a).length() <= 0.5,
		"pan %s vs %s view %s" % [tree.pan(), home_a, tree.view()])
	var second: Vector2 = Vector2(1000.0, 500.0)
	tree.size = second
	await GuiHiringTests._frames(host, 2)
	var home_b: Vector2 = TreeLayout.clamp_pan(TreeLayout.home_pan(second), second)
	TestFixtures.check(res, "a second size moves the first view with it",
		tree.view() == second and (tree.pan() - home_b).length() <= 0.5,
		"pan %s vs %s view %s" % [tree.pan(), home_b, tree.view()])
	tree.set_pan(tree.pan() + Vector2(TreeLayout.DRAG_SLOP + 1.0, 0.0))
	var dragged: Vector2 = tree.pan()
	tree.size = real
	await GuiHiringTests._frames(host, 2)
	TestFixtures.check(res, "a resize after a drag keeps the dragged pan",
		tree.pan() == dragged, "pan %s vs %s" % [tree.pan(), dragged])
	tree.focus_upgrade("counsel")
	var focused: Vector2 = tree.pan()
	tree.size = second
	await GuiHiringTests._frames(host, 2)
	TestFixtures.check(res, "a resize after a focus jump keeps the focus pan",
		tree.pan() == focused, "pan %s vs %s" % [tree.pan(), focused])
	tree.close_dialog()
	tree.home()
	tree.size = real
	await GuiHiringTests._frames(host, 2)
	var home_c: Vector2 = TreeLayout.clamp_pan(TreeLayout.home_pan(real), real)
	TestFixtures.check(res, "home called by the test brings the follow rule back",
		tree.view() == real and (tree.pan() - home_c).length() <= 0.5,
		"pan %s vs %s view %s" % [tree.pan(), home_c, tree.view()])
	tree.queue_free()


#A mouse button event at a frame position, the way the engine hands it to a control.
static func _click(at: Vector2, down: bool,
		button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = at
	click.button_index = button
	click.pressed = down
	return click


static func _motion(at: Vector2) -> InputEventMouseMotion:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	return move


#The name of every Control at or below root that still takes the pointer.
static func _pointer_takers(root: Node) -> Array[String]:
	var out: Array[String] = []
	var control: Control = root as Control
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append(String(root.name))
	for child: Node in root.get_children():
		out.append_array(_pointer_takers(child))
	return out


#Case 13: a module sinks under a held left press, and one the plan cannot use stays flat.
static func _case_press(res: Dictionary, host: Node, tree: SkillTree) -> void:
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	tree.canvas().refresh()
	await host.get_tree().process_frame
	var mod: CustomizeBlock = tree.canvas().block("oddjobs")
	var spot: Vector2 = Vector2(10.0, 10.0)
	var rest_bg: Color = mod.bg_color()
	var rest_hi: Color = mod.hi_color()
	var rest_lo: Color = mod.lo_color()
	TestFixtures.check(res, "a module at rest is not pressed", not mod.is_down(),
		"down %s" % [mod.is_down()])
	mod._gui_input(_click(spot, true, MOUSE_BUTTON_RIGHT))
	TestFixtures.check(res, "only the left button presses a module", not mod.is_down(),
		"down %s" % [mod.is_down()])
	mod._gui_input(_click(spot, true))
	TestFixtures.check(res, "a held left press darkens the face and swaps the bevel edges",
		mod.is_down() and mod.bg_color().is_equal_approx(rest_bg.darkened(BevelButton.PRESS_DROP))
			and mod.hi_color() == rest_lo and mod.lo_color() == rest_hi,
		"bg %s hi %s lo %s" % [mod.bg_color(), mod.hi_color(), mod.lo_color()])
	mod._gui_input(_click(spot, false))
	tree.close_dialog()
	TestFixtures.check(res, "the release lifts the module back to its rest look",
		not mod.is_down() and mod.bg_color() == rest_bg and mod.hi_color() == rest_hi
			and mod.lo_color() == rest_lo,
		"bg %s down %s" % [mod.bg_color(), mod.is_down()])
	mod._gui_input(_click(spot, true))
	mod.mouse_exited.emit()
	TestFixtures.check(res, "the pointer leaving a held module lifts it", not mod.is_down(),
		"down %s" % [mod.is_down()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	tree.canvas().refresh()
	await host.get_tree().process_frame
	var flat_bg: Color = mod.bg_color()
	var flat_hi: Color = mod.hi_color()
	var flat_lo: Color = mod.lo_color()
	mod._gui_input(_click(spot, true))
	TestFixtures.check(res, "a module the plan cannot use never sinks",
		not mod.is_down() and mod.bg_color() == flat_bg and mod.hi_color() == flat_hi
			and mod.lo_color() == flat_lo and flat_hi != flat_lo,
		"down %s bg %s" % [mod.is_down(), mod.bg_color()])
	mod._gui_input(_click(spot, false))
	TestFixtures.check(res, "a release on an unusable module opens nothing",
		not tree.dialog().is_open(), "open %s" % [tree.dialog().is_open()])
	var base: CustomizeBlock = tree.canvas().block("base")
	base._gui_input(_click(spot, true))
	TestFixtures.check(res, "the Base module never sinks", not base.is_down(),
		"down %s" % [base.is_down()])
	base._gui_input(_click(spot, false))


#Case 14: the hover card rides below and right of the pointer, flips at the frame edges and
#never takes the pointer itself.
static func _case_pointer(res: Dictionary, host: Node, tree: SkillTree) -> void:
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	var tip: TreeTooltip = tree.tooltip()
	var gap: float = TreeTooltip.POINTER_GAP + float(TooltipPanel.GAP)
	var back: float = float(TooltipPanel.GAP)
	var frame: Rect2 = Rect2(Vector2.ZERO, VIEW)
	tip.show_for("cat", "limits", Rect2(Vector2(100.0, 10.0), TreeLayout.CAT_BOX), VIEW)
	tip.place_at_pointer(Vector2(300.0, 200.0), frame)
	TestFixtures.check(res, "the card opens below and right of the pointer",
		tip.position.is_equal_approx(Vector2(300.0 + gap, 200.0 + gap)),
		"at %s" % [tip.position])
	tip.place_at_pointer(Vector2(1100.0, 200.0), frame)
	TestFixtures.check(res, "a card with no room on the right flips to the left of the pointer",
		tip.position.is_equal_approx(Vector2(1100.0 - back - TreeTooltip.WIDTH, 200.0 + gap)),
		"at %s" % [tip.position])
	tip.place_at_pointer(Vector2(300.0, 480.0), frame)
	TestFixtures.check(res, "a card with no room below flips above the pointer",
		tip.position.is_equal_approx(Vector2(300.0 + gap, 480.0 - back - tip.tip_height())),
		"at %s height %.0f" % [tip.position, tip.tip_height()])
	tip.place_at_pointer(Vector2(1100.0, 480.0), frame)
	TestFixtures.check(res, "a card in the bottom right corner flips on both axes",
		tip.position.is_equal_approx(Vector2(1100.0 - back - TreeTooltip.WIDTH,
			480.0 - back - tip.tip_height())),
		"at %s" % [tip.position])
	var cell: Vector2 = Vector2(TreeLayout.BLOCK, TreeLayout.BLOCK)
	tip.show_for("block", "seats", Rect2(Vector2(100.0, 10.0), cell), VIEW)
	tip.place_at_pointer(Vector2(300.0, 400.0), frame)
	TestFixtures.check(res, "a tall module card flips above the pointer and stays in the frame",
		is_equal_approx(tip.tip_height(), TreeTooltip.RICH_HEIGHT)
			and tip.position.y >= TreeTooltip.TOP_MIN
			and tip.position.y + tip.tip_height() <= 400.0,
		"at %s height %.0f" % [tip.position, tip.tip_height()])
	tip.follow(Vector2(500.0, 100.0))
	TestFixtures.check(res, "a shown card follows the pointer",
		tip.position.is_equal_approx(Vector2(500.0 + gap, 100.0 + gap)),
		"at %s" % [tip.position])
	tip.hide_tip()
	var parked: Vector2 = tip.position
	tip.follow(Vector2(50.0, 50.0))
	TestFixtures.check(res, "a hidden card stays where it was", tip.position == parked,
		"at %s" % [tip.position])
	var takers: Array[String] = _pointer_takers(tip)
	TestFixtures.check(res, "the card and every row inside it ignore the pointer",
		takers.is_empty(), TestFixtures.detail(takers, 1, "nodes"))
	tree.canvas().hover_changed.emit("cat", "limits", Rect2(Vector2(200.0, 200.0),
		TreeLayout.CAT_BOX))
	var mouse: Vector2 = tree.get_local_mouse_position()
	TestFixtures.check(res, "a new hover puts the card at the pointer",
		tip.visible and tip.position.is_equal_approx(mouse + Vector2(gap, gap)),
		"at %s mouse %s" % [tip.position, mouse])
	tree._gui_input(_motion(Vector2(300.0, 200.0)))
	TestFixtures.check(res, "the pointer moving over the tree brings the card along",
		tip.position.is_equal_approx(Vector2(300.0 + gap, 200.0 + gap)),
		"at %s" % [tip.position])
	tip.hide_tip()


#Case 15: a left press outside the popover closes it and stays free for the module under it.
static func _case_outside(res: Dictionary, host: Node, tree: SkillTree) -> void:
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	var dialog: UpgradeTierDialog = tree.dialog()
	tree.press_block("oddjobs")
	var box: Rect2 = dialog.get_global_rect()
	var away: Vector2 = box.end + Vector2(20.0, 20.0)
	dialog._input(_click(box.get_center(), true))
	TestFixtures.check(res, "a press inside the popover keeps it open", dialog.is_open(),
		"open %s" % [dialog.is_open()])
	dialog._input(_click(away, false))
	dialog._input(_click(away, true, MOUSE_BUTTON_RIGHT))
	dialog._input(_motion(away))
	TestFixtures.check(res, "a release, another button or plain motion outside leaves it open",
		dialog.is_open(), "open %s" % [dialog.is_open()])
	var idle: InputEventAction = InputEventAction.new()
	idle.action = &"ui_accept"
	idle.pressed = false
	dialog.get_viewport().push_input(idle)
	dialog._input(_click(box.position - Vector2(20.0, 20.0), true))
	TestFixtures.check(res, "a left press outside the popover closes it", not dialog.is_open(),
		"open %s" % [dialog.is_open()])
	TestFixtures.check(res, "the press that closed it is left for the module beneath",
		not dialog.get_viewport().is_input_handled(), "the press was marked handled")
	tree.focus_upgrade("counsel", 1)
	TestFixtures.check(res, "another module opens its popover right after",
		dialog.is_open() and dialog.upgrade_id() == "counsel",
		"open %s id %s" % [dialog.is_open(), dialog.upgrade_id()])
	var shut: Vector2 = dialog.get_global_rect().end + Vector2(20.0, 20.0)
	dialog._input(_click(shut, true))
	dialog._input(_click(shut, true))
	TestFixtures.check(res, "a press outside a popover that is already shut leaves it shut",
		not dialog.is_open(), "open %s" % [dialog.is_open()])



#Case 16: a module name wraps inside the label width, and its lines and the fee sit centred in the gap
#the connectors leave under the module.
static func _case_captions(res: Dictionary, tree: SkillTree) -> void:
	var canvas: TreeCanvas = tree.canvas()
	var pip: CustomizeBlock = canvas.block("pip")
	var lines: PackedStringArray = pip.name_lines()
	var widest: float = 0.0
	for line: String in lines:
		widest = maxf(widest, CustomizeBlock.name_width(line))
	TestFixtures.check(res, "the longest name wraps onto two lines and prints whole",
		lines.size() == 2 and " ".join(lines) == pip.name_text()
			and widest <= CustomizeBlock.LABEL_WIDTH,
		"lines %s widest %.1f of %.1f" % [lines, widest, CustomizeBlock.LABEL_WIDTH])
	var seats: PackedStringArray = canvas.block("seats").name_lines()
	var root: PackedStringArray = canvas.block("base").name_lines()
	TestFixtures.check(res, "a short name stays on one line", seats.size() == 1 and root.size() == 1,
		"seats %s base %s" % [seats, root])
	var cut: Array[String] = []
	for id: String in canvas.block_ids():
		var mod: CustomizeBlock = canvas.block(id)
		var parts: PackedStringArray = mod.name_lines()
		var over: bool = parts.size() > CustomizeBlock.NAME_MAX_LINES
		for part: String in parts:
			over = over or CustomizeBlock.name_width(part) > CustomizeBlock.LABEL_WIDTH
		if over or " ".join(parts) != mod.name_text():
			cut.append(id)
	TestFixtures.check(res, "every module name prints whole inside the label width", cut.is_empty(),
		TestFixtures.detail(cut, canvas.block_ids().size(), "modules"))
	var sides: Array[float] = [TreeLayout.BLOCK, TreeLayout.BASE_BLOCK]
	var mid: float = (TreeLayout.NODE_STUB + TreeLayout.LABEL_DROP) / 2.0
	var off: Array[String] = []
	var crowded: Array[String] = []
	for side: float in sides:
		for count: int in range(1, CustomizeBlock.NAME_MAX_LINES + 1):
			var rows: PackedFloat32Array = CustomizeBlock.caption_baselines(side, count)
			var top: float = rows[0] - CustomizeBlock.name_rise()
			var bottom: float = rows[count] + CustomizeBlock.FEE_TILE_DROP
			var tag: String = "%d lines on %d: %.2f to %.2f" % [count, int(side), top, bottom]
			if absf((top + bottom) / 2.0 - (side + mid)) > CAPTION_TOL:
				off.append(tag)
			var clear_top: float = side + TreeLayout.NODE_STUB + TreeCanvas.HALF
			var clear_bottom: float = side + TreeLayout.LABEL_DROP - TreeCanvas.HALF
			if top < clear_top or bottom > clear_bottom:
				crowded.append(tag)
	TestFixtures.check(res, "one and two name lines with the fee sit centred in the gap", off.is_empty(),
		TestFixtures.detail(off, sides.size() * CustomizeBlock.NAME_MAX_LINES, "captions"))
	TestFixtures.check(res, "the caption clears the stub above and the line that resumes below",
		crowded.is_empty(),
		TestFixtures.detail(crowded, sides.size() * CustomizeBlock.NAME_MAX_LINES, "captions"))
	var one: PackedFloat32Array = CustomizeBlock.caption_baselines(TreeLayout.BLOCK, 1)
	var two: PackedFloat32Array = CustomizeBlock.caption_baselines(TreeLayout.BLOCK, 2)
	var tile_top: float = two[2] - (NoteIcon.TILE_SIZE_PX.y - CustomizeBlock.FEE_TILE_DROP)
	TestFixtures.check(res, "name lines step down one pitch and the fee tile sits under the last line",
		one.size() == 2 and two.size() == 3 and one[1] > one[0]
			and is_equal_approx(two[1] - two[0], CustomizeBlock.NAME_PITCH)
			and two[2] > two[1] and tile_top > two[1],
		"one %s two %s tile top %s" % [one, two, tile_top])
	var stacked: float = 2.0 * TreeLayout.GY - TreeLayout.BLOCK
	TestFixtures.check(res, "the label drop leaves a stacked pair a line to resume on",
		TreeLayout.LABEL_DROP <= stacked - TreeCanvas.HALF,
		"drop %s of %s" % [TreeLayout.LABEL_DROP, stacked])

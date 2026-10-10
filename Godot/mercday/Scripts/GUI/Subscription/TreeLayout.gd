class_name TreeLayout
extends RefCounted

#Geometry, progress and colours of the Customize skill tree. Every block, category box, gate and
#connector is derived from the grid here, so no line is routed by hand. Coordinates are content
#space: the host adds OY once when it places the canvas.

const GX: float = 135.0
const GY: float = 76.0
const ROW0: float = 500.0
const BASE_X: float = 1900.0
const OY: float = 780.0
const WORLD: Vector2 = Vector2(5200.0, 2900.0)
const BLOCK: float = 92.0
const BASE_BLOCK: float = 100.0
const CAT_BOX: Vector2 = Vector2(140.0, 44.0)
const GATE_BOX: Vector2 = Vector2(52.0, 26.0)
const LINE_WIDTH: float = 4.0
const LABEL_DROP: float = 56.0
const NODE_STUB: float = 10.0
const CAT_STUB: float = 8.0
const CAT_TOTAL_DROP: float = 76.0
const PAN_MARGIN: float = 500.0
const DRAG_SLOP: float = 4.0

const BASE_LINE: Color = GuiColors.ORANGE
const BASE_LINE_OFF: Color = GuiColors.BLUE
const MUTED_ICON: Color = GuiColors.MUTED
const DIM: float = 0.5

const BASE_NAME: String = "Base Plan"
const BASE_DESC: String = "The root of your Enterprise customizations. Every branch starts here."
const BASE_KIND: String = "Enterprise"
const OWNED_SUFFIX: String = " upgrades owned"

const GATE_LANE: float = 118.0
const GATE_STEP: float = 59.0
const LANE_GAP: float = 92.0
const LANE_HALF: float = 46.0
const BAR_LIFT: float = 40.0
const SIDE_EXIT: float = 44.0
const LEFT_EXIT: float = 30.0
const BR_DROP: float = 140.0
const BR_BACK: float = 60.0

#UpgradeDefs keeps the metrics upgrades under their own key; the tree hangs them under Insights.
const CAT_ALIAS: Dictionary = {"metricsCat": "insights"}

#Grid cell of every block, ported from the prototype place table.
const PLACE: Dictionary = {
	"base": Vector2(0.0, 0.0),
	"seats": Vector2(-5.5, -5.5),
	"contracts": Vector2(-3.5, -5.5),
	"promotions": Vector2(-8.0, 0.0),
	"promomethods": Vector2(-9.0, -4.0),
	"longpromos": Vector2(-7.0, -4.0),
	"marketing": Vector2(-9.0, 4.0),
	"guildpromo": Vector2(-11.0, 0.0),
	"pip": Vector2(0.0, -5.5),
	"combatpip": Vector2(-1.0, -9.5),
	"skillpip": Vector2(1.0, -9.5),
	"magicpip": Vector2(0.0, -13.5),
	"personality": Vector2(4.0, -6.0),
	"readiness": Vector2(4.0, -4.0),
	"brawn": Vector2(4.0, -2.0),
	"aptitude": Vector2(4.0, 0.0),
	"skilltest": Vector2(6.0, -2.0),
	"education": Vector2(8.5, 1.0),
	"bazaar": Vector2(-4.5, 5.5),
	"betteritems": Vector2(-5.5, 10.0),
	"fasteritems": Vector2(-3.5, 10.0),
	"opspermit": Vector2(-1.0, 5.5),
	"teleport": Vector2(-2.0, 10.0),
	"representation": Vector2(0.0, 10.0),
	"whoknows": Vector2(0.25, 6.5),
	"oddjobs": Vector2(1.75, 6.5),
	"discrim": Vector2(3.25, 6.5),
	"counsel": Vector2(1.75, 10.0 + 138.0 / 76.0),
	"criminal": Vector2(5.25, 10.0),
	"background": Vector2(6.5, 3.5),
	"contractmetrics": Vector2(10.0, 2.5),
	"mercmetrics": Vector2(10.0, 4.5),
	"survey": Vector2(12.0, 4.5),
	"customer": Vector2(14.0, 2.5),
	"peer": Vector2(14.0, 6.5),
	"fastmetrics": Vector2(16.0, 4.5),
}

#Category boxes, ported from the prototype catDefs table. via = how Base reaches the box,
#side = where its upgrades hang.
const CATS: Array[Dictionary] = [
	{"id": "limits", "name": "Limits", "at": Vector2(-4.5, -2.5), "via": "leftHigh",
		"side": "upFork", "kids": ["seats", "contracts"],
		"desc": "Upgrades that raise your guild's caps."},
	{"id": "promoCat", "name": "Promotions", "at": Vector2(-4.5, 0.0), "via": "left",
		"side": "left", "kids": ["promotions"],
		"desc": "Advertise jobs and promote your guild."},
	{"id": "coaching", "name": "Coaching", "at": Vector2(0.0, -2.5), "via": "top",
		"side": "up", "kids": ["pip"],
		"desc": "Coach your mercs as they level up."},
	{"id": "testing", "name": "Testing", "at": Vector2(2.0, 0.0), "via": "trunk",
		"side": "right", "kids": ["personality", "readiness", "brawn", "aptitude"],
		"desc": "Tests that reveal your mercs' core stats."},
	{"id": "bazaarCat", "name": "Bazaar", "at": Vector2(-4.5, 2.5), "via": "leftLow",
		"side": "down", "kids": ["bazaar"],
		"desc": "Buy gear for your mercs from the Bazaar."},
	{"id": "legalCat", "name": "Legal", "at": Vector2(-1.0, 3.5), "via": "bl",
		"side": "down", "kids": ["opspermit"],
		"desc": "Permits, representation, and counsel for your guild."},
	{"id": "lessLegal", "name": "Less Legal", "at": Vector2(1.75, 3.5), "via": "bl",
		"side": "fork", "kids": ["whoknows", "oddjobs", "discrim"],
		"desc": "Upgrades of questionable legality."},
	{"id": "insights", "name": "Insights", "at": Vector2(4.25, 3.5), "via": "br",
		"side": "right", "kids": ["background"],
		"desc": "Upgrades that reveal hidden information about your mercs."},
]


static func grid_to_px(col: float, row: float) -> Vector2:
	return Vector2(BASE_X + col * GX, ROW0 + row * GY)


static func block_ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in PLACE:
		out.append(String(key))
	return out


static func upgrade_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		if PLACE.has(id):
			out.append(id)
	return out


static func block_size(id: String) -> float:
	return BASE_BLOCK if id == "base" else BLOCK


static func block_center(id: String) -> Vector2:
	var cell: Vector2 = PLACE.get(id, Vector2.ZERO) as Vector2
	return grid_to_px(cell.x, cell.y)


static func block_rect(id: String) -> Rect2:
	var side: float = block_size(id)
	return Rect2(block_center(id) - Vector2(side, side) / 2.0, Vector2(side, side))


static func cat_ids() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in CATS:
		out.append(String(c["id"]))
	return out


static func cat_def(cat: String) -> Dictionary:
	for c: Dictionary in CATS:
		if String(c["id"]) == cat:
			return c
	return {}


static func cat_center(cat: String) -> Vector2:
	var def: Dictionary = cat_def(cat)
	if def.is_empty():
		return Vector2.ZERO
	var cell: Vector2 = def["at"] as Vector2
	return grid_to_px(cell.x, cell.y)


static func cat_rect(cat: String) -> Rect2:
	return Rect2(cat_center(cat) - CAT_BOX / 2.0, CAT_BOX)


#The kind a block tooltip prints: the name of the category box it belongs to.
static func cat_label(cat: String) -> String:
	var def: Dictionary = cat_def(cat)
	if not def.is_empty():
		return String(def["name"])
	var alias: String = String(CAT_ALIAS.get(cat, ""))
	if alias != "":
		return cat_label(alias)
	return cat


#Edges of one block or category box: l/r/t/b, tb = under its label, stub = the leg off its bottom.
static func geo(key: String) -> Dictionary:
	if PLACE.has(key):
		var c: Vector2 = block_center(key)
		var half: float = block_size(key) / 2.0
		return {"cx": c.x, "cy": c.y, "l": c.x - half, "r": c.x + half, "t": c.y - half,
			"b": c.y + half, "tb": c.y + half + LABEL_DROP, "stub": NODE_STUB}
	if cat_def(key).is_empty():
		return {}
	var p: Vector2 = cat_center(key)
	return {"cx": p.x, "cy": p.y, "l": p.x - CAT_BOX.x / 2.0, "r": p.x + CAT_BOX.x / 2.0,
		"t": p.y - CAT_BOX.y / 2.0, "b": p.y + CAT_BOX.y / 2.0, "tb": p.y + CAT_TOTAL_DROP,
		"stub": CAT_STUB}


#True when the upgrade counts towards this category box, following the metrics alias.
static func in_cat(id: String, cat: String) -> bool:
	if UpgradeDefs.in_category(id, cat):
		return true
	return String(CAT_ALIAS.get(UpgradeDefs.category_of(id), "")) == cat


#The one category box an upgrade is billed to.
static func bill_cat(id: String) -> String:
	var billed: String = UpgradeDefs.bill_category(id)
	return String(CAT_ALIAS.get(billed, billed))


static func cat_members(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		if in_cat(id, cat):
			out.append(id)
	return out


#Owned tiers and total tiers over a list of upgrades.
static func tier_counts(ids: Array[String], tiers: Dictionary) -> Vector2i:
	var have: int = 0
	var total: int = 0
	for id: String in ids:
		var top: int = UpgradeDefs.tier_count(id)
		total += top
		have += mini(top, int(tiers.get(id, 0)))
	return Vector2i(have, total)


#Owned tiers and total tiers of one category box.
static func category_counts(cat: String, tiers: Dictionary) -> Vector2i:
	return tier_counts(cat_members(cat), tiers)


static func category_progress(cat: String, tiers: Dictionary) -> float:
	return _fraction(category_counts(cat, tiers))


static func category_done(cat: String, tiers: Dictionary) -> bool:
	var counts: Vector2i = category_counts(cat, tiers)
	return counts.y > 0 and counts.x >= counts.y


#The monthly fee of the upgrades billed to one category box.
static func category_fee(cat: String, tiers: Dictionary) -> int:
	var total: int = 0
	for id: String in UpgradeDefs.ORDER:
		if bill_cat(id) == cat:
			total += UpgradeDefs.monthly_of(id, int(tiers.get(id, 0)))
	return total


static func base_counts(tiers: Dictionary) -> Vector2i:
	return tier_counts(UpgradeDefs.ORDER, tiers)


static func base_progress(tiers: Dictionary) -> float:
	return _fraction(base_counts(tiers))


#Owned over total, 0 while there is nothing to own.
static func _fraction(counts: Vector2i) -> float:
	if counts.y <= 0:
		return 0.0
	return float(counts.x) / float(counts.y)


#The icon colour of one block: the Base plan tracks the whole tree, an upgrade its own tier.
static func block_color(id: String, tiers: Dictionary) -> Color:
	if id == "base":
		return GuiColors.cat_color(base_progress(tiers))
	var tier: int = int(tiers.get(id, 0))
	if tier <= 0:
		return MUTED_ICON
	return GuiColors.tier_color(tier - 1, UpgradeDefs.tier_count(id))


#The colour a line takes leaving an element: a category its icon colour, passing the incoming
#colour through while it has no progress; an upgrade its own progress colour.
static func out_color(key: String, tiers: Dictionary, enterprise: bool = true) -> Color:
	var base_col: Color = BASE_LINE if enterprise else BASE_LINE_OFF
	if not cat_def(key).is_empty():
		var counts: Vector2i = category_counts(key, tiers)
		if counts.x > 0:
			return GuiColors.cat_color(category_progress(key, tiers))
		return base_col
	var tier: int = int(tiers.get(key, 0))
	if tier > 0:
		return GuiColors.tier_color(tier - 1, UpgradeDefs.tier_count(key))
	return GuiColors.gate_color(0.0)


#How full a requirement is, 0 to 1.
static func gate_fraction(id: String, tiers: Dictionary) -> float:
	var need: int = UpgradeDefs.requirement_need(id)
	if need <= 0:
		return 1.0
	var have: int = mini(UpgradeDefs.requirement_have(id, tiers), need)
	return float(have) / float(need)


#Every connector segment of one tree state, Base outward; gate_list collects the gates on the way.
static func build_connectors(tiers: Dictionary, enterprise: bool,
		gate_list: Array[Dictionary] = []) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	_base_lines(lines, tiers, enterprise)
	_kid_lines(lines, tiers, enterprise)
	_gate_lines(lines, gate_list, tiers, enterprise)
	return lines


#Every requirement gate of one tree state, with its lane position.
static func gates_for(tiers: Dictionary, enterprise: bool = true) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var gate_list: Array[Dictionary] = []
	_gate_lines(lines, gate_list, tiers, enterprise)
	return gate_list


#The lines and the gates of one tree state from a single routing pass.
static func build(tiers: Dictionary, enterprise: bool) -> Dictionary:
	var gate_list: Array[Dictionary] = []
	var lines: Array[Dictionary] = build_connectors(tiers, enterprise, gate_list)
	return {"lines": lines, "gates": gate_list}


#The first view: the true bounding box of Base and every category box, centred in the frame.
static func home_pan(view: Vector2) -> Vector2:
	var base: Dictionary = geo("base")
	var l: float = float(base["l"])
	var r: float = float(base["r"])
	var t: float = float(base["t"])
	var tb: float = float(base["tb"])
	for c: Dictionary in CATS:
		var cg: Dictionary = geo(String(c["id"]))
		l = minf(l, float(cg["l"]))
		r = maxf(r, float(cg["r"]))
		t = minf(t, float(cg["t"]))
		tb = maxf(tb, float(cg["tb"]))
	return Vector2(view.x / 2.0 - (l + r) / 2.0, view.y / 2.0 - (t + tb) / 2.0 - OY)


#The pan that puts one block in the middle of the frame; never clamped, so an edge block lands in
#the same spot as the rest.
static func focus_pan(id: String, view: Vector2) -> Vector2:
	var c: Vector2 = block_center(id)
	return Vector2(view.x / 2.0 - c.x, view.y / 2.0 - c.y - OY)


static func clamp_pan(pan: Vector2, view: Vector2) -> Vector2:
	return Vector2(clampf(pan.x, view.x - WORLD.x - PAN_MARGIN, PAN_MARGIN),
		clampf(pan.y, view.y - WORLD.y - PAN_MARGIN, PAN_MARGIN))


static func _seg(lines: Array[Dictionary], a: Vector2, b: Vector2, c: Color, o: float) -> void:
	_seg2(lines, a, b, c, o, c)


static func _seg2(lines: Array[Dictionary], a: Vector2, b: Vector2, c: Color, o: float,
		c2: Color) -> void:
	if a.x == b.x and a.y == b.y:
		return
	lines.append({"points": PackedVector2Array([a, b]), "color_a": c, "color_b": c2, "alpha": o})


#Leaves the bottom of a box: a stub, a gap for the label, then the rest of the drop. The line
#leaves at the box centre unless x names another column.
static func _down(lines: Array[Dictionary], g: Dictionary, y: float, c: Color, o: float,
		x: Variant = null) -> void:
	var cx: float = float(g["cx"]) if x == null else float(x)
	var b: float = float(g["b"])
	var tb: float = float(g["tb"])
	_seg(lines, Vector2(cx, b), Vector2(cx, b + float(g["stub"])), c, o)
	if y > tb:
		_seg(lines, Vector2(cx, tb), Vector2(cx, y), c, o)


#Enters a box from below: stops under its label, then the stub onto the box.
static func _up_into(lines: Array[Dictionary], g: Dictionary, y: float, c: Color,
		o: float) -> void:
	var cx: float = float(g["cx"])
	var b: float = float(g["b"])
	var tb: float = float(g["tb"])
	if y > tb:
		_seg(lines, Vector2(cx, y), Vector2(cx, tb), c, o)
	_seg(lines, Vector2(cx, b), Vector2(cx, b + float(g["stub"])), c, o)


static func _cats_via(via: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in CATS:
		if String(c["via"]) == via:
			out.append(c)
	return out


#Base to every category box. A finished category turns its own arm green; a shared stem turns
#green only when every category on it is finished.
static func _base_lines(lines: Array[Dictionary], tiers: Dictionary, enterprise: bool) -> void:
	var base_col: Color = BASE_LINE if enterprise else BASE_LINE_OFF
	var done_col: Color = GuiColors.cat_color(1.0)
	var bg: Dictionary = geo("base")
	var trunk: Array[Dictionary] = _cats_via("trunk")
	var trunk_x: float = float(bg["r"])
	if not trunk.is_empty():
		var nearest: float = INF
		var lowest: float = -INF
		for c: Dictionary in trunk:
			var g: Dictionary = geo(String(c["id"]))
			nearest = minf(nearest, float(g["l"]))
			lowest = maxf(lowest, float(g["cy"]))
		trunk_x = (float(bg["r"]) + nearest) / 2.0
		var all_done: bool = true
		for c: Dictionary in trunk:
			if not category_done(String(c["id"]), tiers):
				all_done = false
		var stem: Color = done_col if enterprise and all_done else base_col
		_seg(lines, Vector2(float(bg["r"]), float(bg["cy"])), Vector2(trunk_x, float(bg["cy"])), stem, 1.0)
		_seg(lines, Vector2(trunk_x, float(bg["cy"])), Vector2(trunk_x, lowest), stem, 1.0)
	var left_arms: float = -INF
	for c: Dictionary in CATS:
		var via: String = String(c["via"])
		if via == "leftHigh" or via == "leftLow":
			left_arms = maxf(left_arms, float(geo(String(c["id"]))["r"]))
	for c: Dictionary in CATS:
		var cat: String = String(c["id"])
		var g: Dictionary = geo(cat)
		var via: String = String(c["via"])
		var col: Color = done_col if category_done(cat, tiers) else base_col
		if via == "trunk":
			_seg(lines, Vector2(trunk_x, float(g["cy"])), Vector2(float(g["l"]), float(g["cy"])), col, 1.0)
		elif via == "left":
			_seg(lines, Vector2(float(bg["l"]), float(g["cy"])), Vector2(float(g["r"]), float(g["cy"])), col, 1.0)
		elif via == "leftHigh" or via == "leftLow":
			var up: bool = via == "leftHigh"
			var ey: float = float(bg["cy"]) + (-LEFT_EXIT if up else LEFT_EXIT)
			var fx: float = roundf((float(bg["l"]) + left_arms) / 2.0)
			_seg(lines, Vector2(float(bg["l"]), ey), Vector2(fx, ey), col, 1.0)
			_seg(lines, Vector2(fx, ey), Vector2(fx, float(g["cy"])), col, 1.0)
			_seg(lines, Vector2(fx, float(g["cy"])), Vector2(float(g["r"]), float(g["cy"])), col, 1.0)
		elif via == "top":
			_up_into(lines, g, float(bg["t"]), col, 1.0)
	_base_bottom(lines, tiers, enterprise)


#The two bottom exits of Base, one either side of its label: the left one splits to its
#categories, the right one runs across and into the left side of its category.
static func _base_bottom(lines: Array[Dictionary], tiers: Dictionary,
		enterprise: bool) -> void:
	var base_col: Color = BASE_LINE if enterprise else BASE_LINE_OFF
	var done_col: Color = GuiColors.cat_color(1.0)
	var bg: Dictionary = geo("base")
	for via: String in ["bl", "br"]:
		var group: Array[Dictionary] = _cats_via(via)
		if group.is_empty():
			continue
		var ex: float = float(bg["cx"]) + (-SIDE_EXIT if via == "bl" else SIDE_EXIT)
		var top: float = INF
		var all_done: bool = true
		for c: Dictionary in group:
			top = minf(top, float(geo(String(c["id"]))["t"]))
			if not category_done(String(c["id"]), tiers):
				all_done = false
		var y2: float = top - BAR_LIFT
		var stem: Color = done_col if all_done else base_col
		if via == "bl":
			_down(lines, bg, y2, stem, 1.0, ex)
			for c: Dictionary in group:
				var cat: String = String(c["id"])
				var g: Dictionary = geo(cat)
				var col: Color = done_col if category_done(cat, tiers) else base_col
				_seg(lines, Vector2(ex, y2), Vector2(float(g["cx"]), y2), col, 1.0)
				_seg(lines, Vector2(float(g["cx"]), y2), Vector2(float(g["cx"]), float(g["t"])), col, 1.0)
		else:
			var y1: float = float(bg["cy"]) + BR_DROP
			var g0: Dictionary = geo(String(group[0]["id"]))
			var xd: float = float(g0["l"]) - BR_BACK
			_down(lines, bg, y1, stem, 1.0, ex)
			_seg(lines, Vector2(ex, y1), Vector2(xd, y1), stem, 1.0)
			_seg(lines, Vector2(xd, y1), Vector2(xd, float(g0["cy"])), stem, 1.0)
			_seg(lines, Vector2(xd, float(g0["cy"])), Vector2(float(g0["l"]), float(g0["cy"])), stem, 1.0)


#Category box to the upgrades hanging off it.
static func _kid_lines(lines: Array[Dictionary], tiers: Dictionary, enterprise: bool) -> void:
	var full: float = 1.0 if enterprise else DIM
	for c: Dictionary in CATS:
		var cat: String = String(c["id"])
		var g: Dictionary = geo(cat)
		var col: Color = out_color(cat, tiers, enterprise)
		var side: String = String(c["side"])
		var ks: Array[Dictionary] = []
		for kid: Variant in c["kids"] as Array:
			ks.append(geo(String(kid)))
		if ks.is_empty():
			continue
		if side == "right" or side == "left":
			_spine(lines, g, ks, side == "right", col, full)
		elif side == "fork":
			var by: float = _min_of(ks, "t") - BAR_LIFT
			_down(lines, g, by, col, full)
			_seg(lines, Vector2(_min_of(ks, "cx"), by), Vector2(_max_of(ks, "cx"), by), col, full)
			for k: Dictionary in ks:
				_seg(lines, Vector2(float(k["cx"]), by), Vector2(float(k["cx"]), float(k["t"])), col, full)
		elif side == "down":
			for k: Dictionary in ks:
				_down(lines, g, float(k["t"]), col, full)
		elif side == "up":
			for k: Dictionary in ks:
				_up_into(lines, k, float(g["t"]), col, full)
		elif side == "upFork":
			var bar: float = roundf((float(g["t"]) + _max_of(ks, "tb")) / 2.0)
			_seg(lines, Vector2(float(g["cx"]), float(g["t"])), Vector2(float(g["cx"]), bar), col, full)
			_seg(lines, Vector2(_min_of(ks, "cx"), bar), Vector2(_max_of(ks, "cx"), bar), col,
				full)
			for k: Dictionary in ks:
				_up_into(lines, k, bar, col, full)


#One spine between a category box and the upgrades on that side.
static func _spine(lines: Array[Dictionary], g: Dictionary, ks: Array[Dictionary], right: bool,
		col: Color, alpha: float) -> void:
	var edge: float = float(g["r"]) if right else float(g["l"])
	var facing: float = _min_of(ks, "l") if right else _max_of(ks, "r")
	var sp: float = (edge + facing) / 2.0
	var low: float = float(g["cy"])
	var high: float = float(g["cy"])
	for k: Dictionary in ks:
		low = minf(low, float(k["cy"]))
		high = maxf(high, float(k["cy"]))
	_seg(lines, Vector2(edge, float(g["cy"])), Vector2(sp, float(g["cy"])), col, alpha)
	_seg(lines, Vector2(sp, low), Vector2(sp, high), col, alpha)
	for k: Dictionary in ks:
		var side: float = float(k["l"]) if right else float(k["r"])
		_seg(lines, Vector2(sp, float(k["cy"])), Vector2(side, float(k["cy"])), col, alpha)


static func _min_of(list: Array[Dictionary], key: String) -> float:
	var out: float = INF
	for d: Dictionary in list:
		out = minf(out, float(d[key]))
	return out


static func _max_of(list: Array[Dictionary], key: String) -> float:
	var out: float = -INF
	for d: Dictionary in list:
		out = maxf(out, float(d[key]))
	return out


#Gated upgrades: the sources converge in the gate lane, then one line runs into the target.
static func _gate_lines(lines: Array[Dictionary], gate_list: Array[Dictionary],
		tiers: Dictionary, enterprise: bool) -> void:
	var full: float = 1.0 if enterprise else DIM
	for id: String in upgrade_ids():
		var req: Dictionary = UpgradeDefs.req_of(id)
		if req.is_empty():
			continue
		var ids: Array[String] = []
		for src: Variant in req.get("ids", []) as Array:
			ids.append(String(src))
		if ids.is_empty():
			continue
		var t: Dictionary = geo(id)
		var srcs: Array[Dictionary] = []
		var cols: Array[Color] = []
		for src: String in ids:
			srcs.append(geo(src))
			cols.append(out_color(src, tiers, enterprise))
		var need: int = UpgradeDefs.requirement_need(id)
		var have: int = mini(UpgradeDefs.requirement_have(id, tiers), need)
		var met: bool = UpgradeDefs.requirement_met(id, tiers)
		var merged: Color = GuiColors.mix(cols)
		var gate_col: Color = GuiColors.gate_color(gate_fraction(id, tiers))
		var out_alpha: float = 1.0 if met and enterprise else DIM
		var lane: Vector2 = _gate_route(lines, t, srcs, ids, cols, req, merged, gate_col, full,
			out_alpha)
		gate_list.append({"id": id, "rect": Rect2(lane - GATE_BOX / 2.0, GATE_BOX),
			"have": have, "need": need, "color": gate_col, "met": met})


#Chooses the lane for one requirement and draws every leg into it; returns the gate centre.
static func _gate_route(lines: Array[Dictionary], t: Dictionary, srcs: Array[Dictionary],
		ids: Array[String], cols: Array[Color], req: Dictionary, merged: Color, gate_col: Color,
		in_alpha: float, out_alpha: float) -> Vector2:
	var tcx: float = float(t["cx"])
	var tcy: float = float(t["cy"])
	var right_of: bool = true
	var left_of: bool = true
	var below: bool = true
	for g: Dictionary in srcs:
		if tcx - float(g["cx"]) < 2.0 * GX:
			right_of = false
		if float(g["cx"]) - tcx < 2.0 * GX:
			left_of = false
		if float(g["cy"]) <= tcy:
			below = false
	if right_of:
		return _route_from_left(lines, t, srcs, ids, cols, req, merged, gate_col, in_alpha, out_alpha)
	if left_of:
		return _route_from_right(lines, t, srcs, cols, merged, gate_col, in_alpha, out_alpha)
	if below:
		return _route_from_below(lines, t, srcs, cols, merged, gate_col, in_alpha, out_alpha)
	return _route_from_above(lines, t, srcs, ids, cols, req, merged, gate_col, in_alpha, out_alpha)


#Every source stands two or more columns left of the target: the legs merge in a lane on its left.
static func _route_from_left(lines: Array[Dictionary], t: Dictionary, srcs: Array[Dictionary],
		ids: Array[String], cols: Array[Color], req: Dictionary, merged: Color, gate_col: Color,
		in_alpha: float, out_alpha: float) -> Vector2:
	var tops: Array = req.get("top_exit", []) as Array
	var exit_dy: Dictionary = req.get("exit_dy", {}) as Dictionary
	var tcy: float = float(t["cy"])
	var cx: float = float(t["l"]) - GATE_LANE
	var lane: Vector2 = Vector2(float(t["l"]) - GATE_STEP, tcy)
	var merge: Vector2 = Vector2(cx, tcy)
	for i: int in range(srcs.size()):
		var g: Dictionary = srcs[i]
		var pts: Array[Vector2] = []
		if tops.has(ids[i]):
			pts = [Vector2(float(g["cx"]), float(g["t"])), Vector2(float(g["cx"]), tcy), merge]
		else:
			var dy: float = float(exit_dy.get(ids[i], 0))
			pts = [Vector2(float(g["r"]), float(g["cy"]) + dy),
				Vector2(cx, float(g["cy"]) + dy), merge]
		_leg(lines, pts, cols[i], in_alpha, merged)
	_seg(lines, merge, Vector2(lane.x - GATE_BOX.x / 2.0, tcy), merged, in_alpha)
	_seg(lines, Vector2(lane.x + GATE_BOX.x / 2.0, tcy), Vector2(float(t["l"]), tcy),
		gate_col, out_alpha)
	return lane


#Every source stands two or more columns right of the target: the legs merge in a lane on its right.
static func _route_from_right(lines: Array[Dictionary], t: Dictionary, srcs: Array[Dictionary],
		cols: Array[Color], merged: Color, gate_col: Color, in_alpha: float,
		out_alpha: float) -> Vector2:
	var tcy: float = float(t["cy"])
	var cx: float = float(t["r"]) + GATE_LANE
	var lane: Vector2 = Vector2(float(t["r"]) + GATE_STEP, tcy)
	var merge: Vector2 = Vector2(cx, tcy)
	for i: int in range(srcs.size()):
		var g: Dictionary = srcs[i]
		_leg(lines, [Vector2(float(g["l"]), float(g["cy"])), Vector2(cx, float(g["cy"])), merge],
			cols[i], in_alpha, merged)
	_seg(lines, merge, Vector2(lane.x + GATE_BOX.x / 2.0, tcy), merged, in_alpha)
	_seg(lines, Vector2(lane.x - GATE_BOX.x / 2.0, tcy), Vector2(float(t["r"]), tcy),
		gate_col, out_alpha)
	return lane


#Every source sits below the target: the legs merge in a lane under it and one line runs up into it.
static func _route_from_below(lines: Array[Dictionary], t: Dictionary, srcs: Array[Dictionary],
		cols: Array[Color], merged: Color, gate_col: Color, in_alpha: float,
		out_alpha: float) -> Vector2:
	var tcx: float = float(t["cx"])
	var cy: float = float(t["tb"]) + LANE_GAP
	var lane: Vector2 = Vector2(tcx, float(t["tb"]) + LANE_HALF)
	var merge: Vector2 = Vector2(tcx, cy)
	for i: int in range(srcs.size()):
		var g: Dictionary = srcs[i]
		_leg(lines, [Vector2(float(g["cx"]), float(g["t"])), Vector2(float(g["cx"]), cy), merge],
			cols[i], in_alpha, merged)
	_seg(lines, merge, Vector2(tcx, lane.y + GATE_BOX.y / 2.0), merged, in_alpha)
	_up_into(lines, t, lane.y - GATE_BOX.y / 2.0, gate_col, out_alpha)
	return lane


#Any other spread of sources: the legs merge in a lane over the target and one line drops into it.
static func _route_from_above(lines: Array[Dictionary], t: Dictionary, srcs: Array[Dictionary],
		ids: Array[String], cols: Array[Color], req: Dictionary, merged: Color, gate_col: Color,
		in_alpha: float, out_alpha: float) -> Vector2:
	var sides: Array = req.get("side_exit", []) as Array
	var tcx: float = float(t["cx"])
	var cy: float = float(t["t"]) - LANE_GAP
	if not sides.is_empty():
		cy = float(geo(String(sides[0]))["cy"])
	var lane: Vector2 = Vector2(tcx, float(t["t"]) - LANE_HALF)
	var merge: Vector2 = Vector2(tcx, cy)
	for i: int in range(srcs.size()):
		var g: Dictionary = srcs[i]
		var left_side: bool = float(g["cx"]) < tcx
		var face: float = float(g["r"]) if left_side else float(g["l"])
		if sides.has(ids[i]) or absf(float(g["cy"]) - cy) < 2.0:
			_leg(lines, [Vector2(face, float(g["cy"])), Vector2(tcx, float(g["cy"])), merge], cols[i],
				in_alpha, merged)
			continue
		if float(g["b"]) + float(g["stub"]) > cy:
			var side_lane: float = float(t["r"]) + GATE_LANE
			if left_side:
				side_lane = float(t["l"]) - GATE_LANE
			_leg(lines, [Vector2(face, float(g["cy"])), Vector2(side_lane, float(g["cy"])),
				Vector2(side_lane, cy), merge], cols[i], in_alpha, merged)
			continue
		_seg(lines, Vector2(float(g["cx"]), float(g["b"])),
			Vector2(float(g["cx"]), float(g["b"]) + float(g["stub"])), cols[i], in_alpha)
		_leg(lines, [Vector2(float(g["cx"]), float(g["tb"])), Vector2(float(g["cx"]), cy), merge], cols[i],
			in_alpha, merged)
	_seg(lines, merge, Vector2(tcx, lane.y - GATE_BOX.y / 2.0), merged, in_alpha)
	_seg(lines, Vector2(tcx, lane.y + GATE_BOX.y / 2.0), Vector2(tcx, float(t["t"])), gate_col,
		out_alpha)
	return lane


#One source leg: its own colour all the way, fading into the merged colour on its last segment.
static func _leg(lines: Array[Dictionary], pts: Array[Vector2], c: Color, alpha: float,
		merged: Color) -> void:
	var kept: Array[Vector2] = []
	for p: Vector2 in pts:
		if kept.is_empty() or kept[kept.size() - 1] != p:
			kept.append(p)
	var last: int = kept.size() - 2
	for i: int in range(kept.size() - 1):
		_seg2(lines, kept[i], kept[i + 1], c, alpha, merged if i == last else c)

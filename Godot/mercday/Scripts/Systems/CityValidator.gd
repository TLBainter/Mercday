class_name CityValidator

#Checks one generated city map against the street, plot, lot and fill rules of the city block design.
#CityGenerator runs the layout rules before the fill passes and both sets after them.

const MAX_ISSUES := 12
const DEAD_GROW := 2
const MOUTH_GROW := 3
const STAT_KEYS: Array[String] = ["mains", "sides", "alleys", "dead_ends", "back_lanes",
	"plots_large", "plots_medium", "plots_small", "lots", "buildings", "failed_lots",
	"nature_objects", "street_objects", "alley_ring_cells", "alley_connector_cells",
	"alley_connectors", "alley_isolated", "alley_connect_d"]
const STREET_TAGS: Array[String] = ["lamp", "alley", "sidewalk", "square"]


#One short text per broken rule, at most MAX_ISSUES of them; an empty list means the map is clean.
static func validate(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	if _layout(area, out):
		_fill(area, out)
	return out


#The rules a map must keep before and after the fill passes.
static func validate_layout(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	_layout(area, out)
	return out


#False when the map is too broken for any further rule to mean anything.
static func _layout(area: BattlefieldArea, out: Array[String]) -> bool:
	if area == null:
		_note(out, "no map")
		return false
	if not _grids(area, out):
		return false
	_tier(area, out)
	_mains(area, out)
	_segments(area, out)
	_wrapped(area, out)
	_curbs(area, out)
	_reach(area, out)
	_plots(area, out)
	_lots(area, out)
	_dead_ends(area, out)
	_stats(area, out)
	return true


#Fill rules 3 to 7; a map that stopped after the layout pass keeps none of them.
static func _fill(area: BattlefieldArea, out: Array[String]) -> void:
	if _layout_only(area):
		return
	_building_issues(area, out)
	_lot_fill(area, out)
	_spacing(area, out)
	_floors(area, out)
	for text: String in CityAccessRules.check(area):
		_note(out, text)
	_spawn(area, out)
	_lanes(area, out)


#True for a map that never ran a fill pass: no spawn record, no building and no failed lot.
static func _layout_only(area: BattlefieldArea) -> bool:
	if area.city.has("spawn") or not area.buildings.is_empty():
		return false
	for entry: Variant in (area.city.get("lots", []) as Array):
		if (entry as Dictionary).has("failed"):
			return false
	return true


static func _note(out: Array[String], text: String) -> void:
	if out.size() < MAX_ISSUES:
		out.append(text)


#Records one hit of a rule while the rule and the list have room; returns the new hit count.
static func _hit(out: Array[String], hits: int, text: String) -> int:
	if hits < CityAccess.HITS_PER_RULE:
		_note(out, text)
	return hits + 1


static func _streets(area: BattlefieldArea) -> Array:
	return area.city.get("streets", []) as Array


static func _across(rect: Rect2i, axis: String) -> int:
	return rect.size.y if axis == "x" else rect.size.x


#First cell of rect whose surface is not want; (-1, -1) when every cell holds want.
static func _first_not(area: BattlefieldArea, rect: Rect2i, want: int) -> Vector2i:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if CityGrid.surf(area, x, y) != want:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


#First cell of rect that is neither carriageway nor sidewalk; cells off the map are skipped.
static func _first_unpaved(area: BattlefieldArea, rect: Rect2i) -> Vector2i:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not area.in_bounds_xy(x, y):
				continue
			var s: int = CityGrid.surf(area, x, y)
			if not CityGrid.is_paved(s):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


#4-connected flood over a mask where 1 marks a member cell; visited cells become 2. Returns cells reached.
static func _flood(mask: PackedByteArray, w: int, h: int, sx: int, sy: int) -> int:
	var qx := PackedInt32Array()
	var qy := PackedInt32Array()
	qx.append(sx)
	qy.append(sy)
	mask[sy * w + sx] = 2
	var seen: int = 0
	while not qx.is_empty():
		var last: int = qx.size() - 1
		var cx: int = qx[last]
		var cy: int = qy[last]
		qx.remove_at(last)
		qy.remove_at(last)
		seen += 1
		for d: int in range(4):
			var nx: int = cx + CityGrid.DX_XFIRST[d]
			var ny: int = cy + CityGrid.DY_XFIRST[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var i: int = ny * w + nx
			if mask[i] != 1:
				continue
			mask[i] = 2
			qx.append(nx)
			qy.append(ny)
	return seen


#True when the union of the rects is one 4-connected cell set.
static func _one_piece(rects: Array[Rect2i]) -> bool:
	if rects.is_empty():
		return false
	var b: Rect2i = rects[0]
	for r: Rect2i in rects:
		b = b.merge(r)
	if b.size.x <= 0 or b.size.y <= 0:
		return false
	var mask := PackedByteArray()
	mask.resize(b.size.x * b.size.y)
	var total: int = 0
	for r2: Rect2i in rects:
		for y: int in range(r2.position.y, r2.end.y):
			for x: int in range(r2.position.x, r2.end.x):
				var i: int = (y - b.position.y) * b.size.x + (x - b.position.x)
				if mask[i] == 0:
					mask[i] = 1
					total += 1
	if total == 0:
		return false
	var seen: int = _flood(mask, b.size.x, b.size.y, rects[0].position.x - b.position.x,
		rects[0].position.y - b.position.y)
	return seen == total


#Rule 1: the map is a city map, both grids are sized and every cell carries a surface.
static func _grids(area: BattlefieldArea, out: Array[String]) -> bool:
	var n: int = area.width * area.length
	if not area.is_city:
		_note(out, "is_city is false")
	if area.surface_grid.size() != n or area.street_grid.size() != n:
		_note(out, "grids hold %d and %d cell(s) for a %dx%d map"
			% [area.surface_grid.size(), area.street_grid.size(), area.width, area.length])
		return false
	var hits: int = 0
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			if area.surface_grid[row + x] != BattlefieldArea.SURF_NONE:
				continue
			hits = _hit(out, hits, "cell %d,%d carries no surface" % [x, y])
			if hits >= CityAccess.HITS_PER_RULE:
				return true
	return true


#Rule 2: the map sides lie in the range of its tier.
static func _tier(area: BattlefieldArea, out: Array[String]) -> void:
	var tier: String = String(area.city.get("tier", ""))
	if not CityGenerator.TIER_SIDE.has(tier):
		_note(out, "tier '%s' is no city tier" % tier)
		return
	var span: Vector2i = CityGenerator.TIER_SIDE[tier]
	if area.width < span.x or area.width > span.y or area.length < span.x or area.length > span.y:
		_note(out, "%s map %dx%d lies outside %d..%d" % [tier, area.width, area.length, span.x, span.y])


#Rules 3 and 4: the main street count of the tier, and one straight banded carriageway per main.
static func _mains(area: BattlefieldArea, out: Array[String]) -> void:
	var main_w: int = int(area.city.get("main_w", 0))
	var nx: int = 0
	var ny: int = 0
	var hits: int = 0
	for entry: Variant in _streets(area):
		var st: Dictionary = entry as Dictionary
		if String(st.get("kind", "")) != "main":
			continue
		var id: int = int(st.get("id", -1))
		var axis: String = String(st.get("axis", ""))
		if axis == "x":
			nx += 1
		else:
			ny += 1
		if hits >= CityAccess.HITS_PER_RULE:
			continue
		var segs: Array = st.get("segments", [])
		if segs.size() != 1:
			hits = _hit(out, hits, "main %d holds %d segment(s)" % [id, segs.size()])
			continue
		var seg: Dictionary = segs[0]
		var r: Rect2i = seg.get("rect", Rect2i())
		var spans: bool = (r.position.x == 0 and r.size.x == area.width) if axis == "x" \
			else (r.position.y == 0 and r.size.y == area.length)
		if not spans:
			hits = _hit(out, hits, "main %d %s does not span the map along %s" % [id, str(r), axis])
		var across: int = _across(r, axis)
		if across != main_w or int(seg.get("width", 0)) != main_w:
			hits = _hit(out, hits, "main %d spans %d cell(s), says width %d, main_w %d"
				% [id, across, int(seg.get("width", 0)), main_w])
		var bad: Vector2i = _first_not(area, r, BattlefieldArea.SURF_MAIN)
		if bad.x >= 0:
			hits = _hit(out, hits, "main %d cell %d,%d is no carriageway" % [id, bad.x, bad.y])
		for band: Rect2i in _main_bands(area, r, axis):
			var loose: Vector2i = _first_unpaved(area, band)
			if loose.x >= 0:
				hits = _hit(out, hits, "main %d band cell %d,%d holds surface %d"
					% [id, loose.x, loose.y, CityGrid.surf(area, loose.x, loose.y)])
	_main_counts(String(area.city.get("tier", "")), nx, ny, out)


static func _main_bands(area: BattlefieldArea, r: Rect2i, axis: String) -> Array[Rect2i]:
	var bands: Array[Rect2i] = []
	if axis == "x":
		bands.append(Rect2i(0, r.position.y - CityGenerator.MAIN_SIDEWALK, area.width, CityGenerator.MAIN_SIDEWALK))
		bands.append(Rect2i(0, r.end.y, area.width, CityGenerator.MAIN_SIDEWALK))
	else:
		bands.append(Rect2i(r.position.x - CityGenerator.MAIN_SIDEWALK, 0, CityGenerator.MAIN_SIDEWALK, area.length))
		bands.append(Rect2i(r.end.x, 0, CityGenerator.MAIN_SIDEWALK, area.length))
	return bands


static func _main_counts(tier: String, nx: int, ny: int, out: Array[String]) -> void:
	if tier == "Small":
		if nx + ny != 1:
			_note(out, "a Small map holds %d main street(s)" % (nx + ny))
	elif tier == "Medium":
		if nx != 1 or ny != 1:
			_note(out, "a Medium map holds %d x and %d y main street(s)" % [nx, ny])
	elif tier == "Large":
		if nx != 2 or ny != 2:
			_note(out, "a Large map holds %d x and %d y main street(s)" % [nx, ny])
	elif tier == "Massive":
		if nx < 3 or nx > 4 or ny < 3 or ny > 4:
			_note(out, "a Massive map holds %d x and %d y main street(s)" % [nx, ny])


#Rules 5 and 6: every side street and alley segment, and the one piece each street but a ring forms.
static func _segments(area: BattlefieldArea, out: Array[String]) -> void:
	var hits: int = 0
	var loose: int = 0
	for entry: Variant in _streets(area):
		var st: Dictionary = entry as Dictionary
		var kind: String = String(st.get("kind", ""))
		if kind != "side" and kind != "alley":
			continue
		var id: int = int(st.get("id", -1))
		var want: int = BattlefieldArea.SURF_SIDE if kind == "side" else BattlefieldArea.SURF_ALLEY
		var span: Vector2i = CityStreets.SIDE_W if kind == "side" else CityStreets.ALLEY_W
		var segs: Array = st.get("segments", [])
		if segs.is_empty():
			hits = _hit(out, hits, "street %d holds no segment" % id)
			continue
		var rects: Array[Rect2i] = []
		for sv: Variant in segs:
			var seg: Dictionary = sv as Dictionary
			var r: Rect2i = seg.get("rect", Rect2i())
			rects.append(r)
			if hits >= CityAccess.HITS_PER_RULE:
				continue
			var axis: String = String(seg.get("axis", ""))
			if axis != "x" and axis != "y":
				hits = _hit(out, hits, "street %d segment runs along '%s'" % [id, axis])
				continue
			var across: int = _across(r, axis)
			if int(seg.get("width", 0)) != across:
				hits = _hit(out, hits, "street %d segment %s says width %d, holds %d"
					% [id, str(r), int(seg.get("width", 0)), across])
			if across < span.x or across > span.y:
				hits = _hit(out, hits, "street %d %s segment is %d cell(s) wide" % [id, kind, across])
			if r.position.x < 0 or r.position.y < 0 or r.end.x > area.width or r.end.y > area.length:
				hits = _hit(out, hits, "street %d segment %s leaves the map" % [id, str(r)])
				continue
			var bad: Vector2i = _first_not(area, r, want)
			if bad.x >= 0:
				hits = _hit(out, hits, "street %d %s cell %d,%d holds surface %d"
					% [id, kind, bad.x, bad.y, CityGrid.surf(area, bad.x, bad.y)])
		if CityAlleys.is_ring(st):
			continue
		if not _one_piece(rects):
			loose = _hit(out, loose, "street %d falls into parts" % id)


#Rule 7: a carriageway cell never touches anything but carriageway and sidewalk.
static func _wrapped(area: BattlefieldArea, out: Array[String]) -> void:
	var w: int = area.width
	var hits: int = 0
	for y: int in range(area.length):
		var row: int = y * w
		for x: int in range(w):
			if not CityGrid.is_carriage(area.surface_grid[row + x]):
				continue
			for dy: int in range(-1, 2):
				var ny: int = y + dy
				if ny < 0 or ny >= area.length:
					continue
				var nrow: int = ny * w
				for dx: int in range(-1, 2):
					var nx: int = x + dx
					if nx < 0 or nx >= w or (dx == 0 and dy == 0):
						continue
					var s: int = area.surface_grid[nrow + nx]
					if CityGrid.is_paved(s):
						continue
					hits = _hit(out, hits, "carriageway %d,%d touches surface %d at %d,%d"
						% [x, y, s, nx, ny])
					if hits >= CityAccess.HITS_PER_RULE:
						return


#Rule 8: terrain_heights holds the curb of every sidewalk and alley cell and nothing else.
static func _curbs(area: BattlefieldArea, out: Array[String]) -> void:
	var want: int = 0
	for i: int in range(area.surface_grid.size()):
		var s: int = area.surface_grid[i]
		if s == BattlefieldArea.SURF_SIDEWALK or s == BattlefieldArea.SURF_ALLEY:
			want += 1
	var hits: int = 0
	for key: Variant in area.terrain_heights.keys():
		if typeof(key) != TYPE_VECTOR2I:
			hits = _hit(out, hits, "curb key %s is no cell" % str(key))
		else:
			var c: Vector2i = key
			var s2: int = CityGrid.surf(area, c.x, c.y)
			if s2 != BattlefieldArea.SURF_SIDEWALK and s2 != BattlefieldArea.SURF_ALLEY:
				hits = _hit(out, hits, "curb on %d,%d, which holds surface %d" % [c.x, c.y, s2])
			elif not is_equal_approx(float(area.terrain_heights[key]), CityGenerator.CURB):
				hits = _hit(out, hits, "curb %d,%d stands at %.2f, not %.2f"
					% [c.x, c.y, float(area.terrain_heights[key]), CityGenerator.CURB])
		if hits >= CityAccess.HITS_PER_RULE:
			return
	if area.terrain_heights.size() != want:
		_note(out, "%d curb(s) for %d sidewalk and alley cell(s)"
			% [area.terrain_heights.size(), want])


#Rule 9: every street cell reaches a main street over street cells. Ring and connector cells conduct but
#are not counted: a ring around a building nothing reaches is still an alley.
static func _reach(area: BattlefieldArea, out: Array[String]) -> void:
	var skip: Dictionary = CityAlleys.wrap_cells(area)
	var mask := PackedByteArray()
	mask.resize(area.surface_grid.size())
	var total: int = 0
	var sx: int = -1
	var sy: int = -1
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			var s: int = area.surface_grid[row + x]
			if not CityGrid.is_street(s):
				continue
			mask[row + x] = 1
			if not skip.has(Vector2i(x, y)):
				total += 1
			if sx < 0 and s == BattlefieldArea.SURF_MAIN:
				sx = x
				sy = y
	if sx < 0:
		_note(out, "the map holds no main street cell")
		return
	_flood(mask, area.width, area.length, sx, sy)
	var missed: int = 0
	for y2: int in range(area.length):
		var row2: int = y2 * area.width
		for x2: int in range(area.width):
			if mask[row2 + x2] == 1 and not skip.has(Vector2i(x2, y2)):
				missed += 1
	if missed > 0:
		_note(out, "%d of %d street cell(s) reach a main street" % [total - missed, total])


#Rule 10: plots lie in their block, keep to the size range, carry the right class and reach a street.
static func _plots(area: BattlefieldArea, out: Array[String]) -> void:
	var plots: Array = area.city.get("plots", [])
	if plots.is_empty():
		return
	var blocks: Array = area.city.get("blocks", [])
	var th: Dictionary = CityPlots.class_thresholds()
	var owner := PackedInt32Array()
	owner.resize(area.width * area.length)
	owner.fill(-1)
	var hits: int = 0
	for pi: int in range(plots.size()):
		var p: Dictionary = plots[pi]
		if int(p.get("id", -1)) != pi:
			hits = _hit(out, hits, "plot %d carries id %d" % [pi, int(p.get("id", -1))])
		var r: Rect2i = p.get("rect", Rect2i())
		if r.position.x < 0 or r.position.y < 0 or r.end.x > area.width or r.end.y > area.length:
			hits = _hit(out, hits, "plot %d %s leaves the map" % [pi, str(r)])
			if hits >= CityAccess.HITS_PER_RULE:
				return
			continue
		var bi: int = int(p.get("block", -1))
		if bi < 0 or bi >= blocks.size():
			hits = _hit(out, hits, "plot %d names block %d" % [pi, bi])
		else:
			var br: Rect2i = (blocks[bi] as Dictionary).get("rect", Rect2i())
			if not br.encloses(r):
				hits = _hit(out, hits, "plot %d %s leaves block %d %s" % [pi, str(r), bi, str(br)])
		if mini(r.size.x, r.size.y) < CityPlots.PLOT_MIN or maxi(r.size.x, r.size.y) > CityPlots.PLOT_MAX:
			hits = _hit(out, hits, "plot %d is %dx%d" % [pi, r.size.x, r.size.y])
		var want: String = CityPlots.class_of(mini(r.size.x, r.size.y), th)
		if String(p.get("class", "")) != want:
			hits = _hit(out, hits, "plot %d is class %s, %dx%d wants %s"
				% [pi, String(p.get("class", "")), r.size.x, r.size.y, want])
		if not CityGrid.has_any_access(area, r):
			hits = _hit(out, hits, "plot %d %s reaches no street" % [pi, str(r)])
		var clash: bool = false
		for y: int in range(r.position.y, r.end.y):
			var row: int = y * area.width
			for x: int in range(r.position.x, r.end.x):
				if owner[row + x] >= 0:
					hits = _hit(out, hits, "plot %d overlaps plot %d at %d,%d"
						% [pi, owner[row + x], x, y])
					clash = true
					break
				owner[row + x] = pi
			if clash:
				break
		if hits >= CityAccess.HITS_PER_RULE:
			return


#Rules 11 and 12: lots fit their plot and their class, name the rows that fit, and cover every lot cell.
static func _lots(area: BattlefieldArea, out: Array[String]) -> void:
	var lots: Array = area.city.get("lots", [])
	var plots: Array = area.city.get("plots", [])
	var th: Dictionary = CityPlots.class_thresholds()
	var owner := PackedInt32Array()
	owner.resize(area.width * area.length)
	owner.fill(-1)
	var listed: Array[PackedInt32Array] = []
	for _i: int in range(plots.size()):
		listed.append(PackedInt32Array())
	var hits: int = 0
	for li: int in range(lots.size()):
		var lot: Dictionary = lots[li]
		var r: Rect2i = lot.get("rect", Rect2i())
		var pi: int = int(lot.get("plot", -1))
		if pi >= 0 and pi < plots.size():
			listed[pi].append(li)
		if hits < CityAccess.HITS_PER_RULE:
			hits = _lot_record(area, lot, li, pi, plots, th, out, hits)
		var clash: bool = false
		for y: int in range(maxi(r.position.y, 0), mini(r.end.y, area.length)):
			var row: int = y * area.width
			for x: int in range(maxi(r.position.x, 0), mini(r.end.x, area.width)):
				if owner[row + x] >= 0:
					hits = _hit(out, hits, "lot %d overlaps lot %d at %d,%d" % [li, owner[row + x], x, y])
					clash = true
					break
				owner[row + x] = li
			if clash:
				break
	var short: int = 0
	for pi2: int in range(plots.size()):
		var got: Array = (plots[pi2] as Dictionary).get("lots", [])
		if not _same_ids(got, listed[pi2]):
			short = _hit(out, short, "plot %d lists %d lot(s), %d name it"
				% [pi2, got.size(), listed[pi2].size()])
			if short >= CityAccess.HITS_PER_RULE:
				break
	var stray: int = 0
	for y2: int in range(area.length):
		var row2: int = y2 * area.width
		for x2: int in range(area.width):
			if area.surface_grid[row2 + x2] != BattlefieldArea.SURF_LOT or owner[row2 + x2] >= 0:
				continue
			stray = _hit(out, stray, "lot cell %d,%d lies outside every lot" % [x2, y2])
			if stray >= CityAccess.HITS_PER_RULE:
				return


static func _lot_record(area: BattlefieldArea, lot: Dictionary, li: int, pi: int, plots: Array,
		th: Dictionary, out: Array[String], hits: int) -> int:
	var r: Rect2i = lot.get("rect", Rect2i())
	if int(lot.get("id", -1)) != li:
		hits = _hit(out, hits, "lot %d carries id %d" % [li, int(lot.get("id", -1))])
	if pi < 0 or pi >= plots.size():
		hits = _hit(out, hits, "lot %d names plot %d" % [li, pi])
	else:
		var pr: Rect2i = (plots[pi] as Dictionary).get("rect", Rect2i())
		if not pr.encloses(r):
			hits = _hit(out, hits, "lot %d %s leaves plot %d %s" % [li, str(r), pi, str(pr)])
	var cls: String = String(lot.get("class", ""))
	if not th.has(cls):
		hits = _hit(out, hits, "lot %d is class '%s'" % [li, cls])
	elif mini(r.size.x, r.size.y) < int(th[cls]):
		hits = _hit(out, hits, "lot %d is %dx%d for class %s" % [li, r.size.x, r.size.y, cls])
	var front: String = String(lot.get("front", ""))
	if not CityGrid.SIDES.has(front):
		hits = _hit(out, hits, "lot %d fronts '%s'" % [li, front])
	else:
		var span: Vector2i = CityGrid.front_span(r.size, front)
		var frontage: int = span.x
		var depth: int = span.y
		var fit: Array[String] = CityPlots.rows_that_fit(cls, frontage, depth)
		var rows: Array = lot.get("rows", [])
		if rows.is_empty():
			hits = _hit(out, hits, "lot %d names no building row" % li)
		elif not _same_rows(rows, fit):
			hits = _hit(out, hits, "lot %d names %d row(s), %d fit" % [li, rows.size(), fit.size()])
		if not CityGrid.side_has_access(area, r, front):
			hits = _hit(out, hits, "lot %d front %s reaches no street" % [li, front])
		var kind: String = String(CityGrid.side_touch(area, r, front)["kind"])
		if kind != String(lot.get("front_kind", "")):
			hits = _hit(out, hits, "lot %d front %s meets '%s', not '%s'"
				% [li, front, kind, String(lot.get("front_kind", ""))])
	return _lot_surface(area, lot, li, out, hits)


#A cell a building owns holds SURF_LOT; any other lot cell holds SURF_LOT before the lot pass and
#SURF_NATURE after it. A back lane, a building ring and a connector may cross a lot.
static func _lot_surface(area: BattlefieldArea, lot: Dictionary, li: int, out: Array[String],
		hits: int) -> int:
	var r: Rect2i = lot.get("rect", Rect2i())
	var open: bool = int(lot.get("building", -1)) < 0 and not lot.has("failed")
	var want: int = BattlefieldArea.SURF_LOT if open else BattlefieldArea.SURF_NATURE
	for y: int in range(maxi(r.position.y, 0), mini(r.end.y, area.length)):
		var row: int = y * area.width
		for x: int in range(maxi(r.position.x, 0), mini(r.end.x, area.width)):
			var s: int = area.surface_grid[row + x]
			var owned: bool = area.building_id_at.has(Vector2i(x, y))
			if s == (BattlefieldArea.SURF_LOT if owned else want):
				continue
			if not owned and s == BattlefieldArea.SURF_ALLEY and _is_lane(area, row + x):
				continue
			hits = _hit(out, hits, "lot %d cell %d,%d holds surface %d" % [li, x, y, s])
			if hits >= CityAccess.HITS_PER_RULE:
				return hits
	return hits


#True when the street that owns the cell is a painted back lane, a building ring or a connector.
static func _is_lane(area: BattlefieldArea, i: int) -> bool:
	var sid: int = area.street_grid[i]
	var streets: Array = _streets(area)
	if sid < 0 or sid >= streets.size():
		return false
	var st: Dictionary = streets[sid] as Dictionary
	if String(st.get("kind", "")) != "alley":
		return false
	return st.has("back_door") or CityAlleys.is_wrap(st)


static func _same_rows(got: Array, want: Array[String]) -> bool:
	if got.size() != want.size():
		return false
	for i: int in range(want.size()):
		if String(got[i]) != want[i]:
			return false
	return true


static func _same_ids(got: Array, want: PackedInt32Array) -> bool:
	if got.size() != want.size():
		return false
	for i: int in range(want.size()):
		if int(got[i]) != want[i]:
			return false
	return true


#Rule 13: no foreign street cell sits beside the far end of a dead end. Mouth cells, back lanes, rings and
#connectors are exempt.
static func _dead_ends(area: BattlefieldArea, out: Array[String]) -> void:
	var hits: int = 0
	var lanes: Dictionary = {}
	for entry: Variant in _streets(area):
		var lane: Dictionary = entry as Dictionary
		if lane.has("back_door") or CityAlleys.is_wrap(lane):
			lanes[int(lane.get("id", -1))] = true
	for entry: Variant in _streets(area):
		var st: Dictionary = entry as Dictionary
		if not bool(st.get("dead_end", false)) or st.has("back_door") or CityAlleys.is_wrap(st):
			continue
		var segs: Array = st.get("segments", [])
		if segs.is_empty():
			continue
		var id: int = int(st.get("id", -1))
		var first: Rect2i = (segs[0] as Dictionary).get("rect", Rect2i())
		var last: Rect2i = (segs[segs.size() - 1] as Dictionary).get("rect", Rect2i())
		var mouth: Rect2i = first.grow(MOUTH_GROW)
		var zone: Rect2i = last.grow(DEAD_GROW)
		for y: int in range(maxi(zone.position.y, 0), mini(zone.end.y, area.length)):
			var row: int = y * area.width
			for x: int in range(maxi(zone.position.x, 0), mini(zone.end.x, area.width)):
				if mouth.has_point(Vector2i(x, y)):
					continue
				var sid: int = area.street_grid[row + x]
				if sid < 0 or sid == id or lanes.has(sid):
					continue
				hits = _hit(out, hits, "dead end %d meets street %d at %d,%d" % [id, sid, x, y])
				if hits >= CityAccess.HITS_PER_RULE:
					return


#Rule 14: the stats line counts what the model holds.
static func _stats(area: BattlefieldArea, out: Array[String]) -> void:
	var lots: Array = area.city.get("lots", []) as Array
	var failed: int = 0
	for lv: Variant in lots:
		if (lv as Dictionary).has("failed"):
			failed += 1
	var objects: Dictionary = _object_counts(area)
	var counted: Dictionary = {"mains": 0, "sides": 0, "alleys": 0, "dead_ends": 0, "back_lanes": 0,
		"plots_large": 0, "plots_medium": 0, "plots_small": 0,
		"lots": lots.size(), "buildings": area.buildings.size(), "failed_lots": failed,
		"nature_objects": int(objects["nature"]), "street_objects": int(objects["street"]),
		"alley_ring_cells": 0, "alley_connector_cells": 0, "alley_connectors": 0, "alley_isolated": 0,
		"alley_connect_d": CityAlleys.connect_d_for(mini(area.width, area.length))}
	for entry: Variant in _streets(area):
		var st: Dictionary = entry as Dictionary
		if CityAlleys.is_wrap(st):
			_count_wrap(st, counted)
			continue
		if st.has("back_door"):
			counted["back_lanes"] = int(counted["back_lanes"]) + 1
			continue
		var kind: String = String(st.get("kind", ""))
		if kind == "main":
			counted["mains"] = int(counted["mains"]) + 1
		elif kind == "side":
			counted["sides"] = int(counted["sides"]) + 1
		elif kind == "alley":
			counted["alleys"] = int(counted["alleys"]) + 1
		if bool(st.get("dead_end", false)):
			counted["dead_ends"] = int(counted["dead_ends"]) + 1
	for pv: Variant in (area.city.get("plots", []) as Array):
		var key: String = "plots_%s" % String((pv as Dictionary).get("class", "")).to_lower()
		if counted.has(key):
			counted[key] = int(counted[key]) + 1
	var stats: Dictionary = area.city.get("stats", {})
	var hits: int = 0
	for key2: String in STAT_KEYS:
		if int(stats.get(key2, -1)) == int(counted[key2]):
			continue
		hits = _hit(out, hits, "stats %s says %s, the map holds %d"
			% [key2, str(stats.get(key2, "-")), int(counted[key2])])
		if hits >= CityAccess.HITS_PER_RULE:
			return


#Adds one ring or connector record to the alley counts of the stats line.
static func _count_wrap(st: Dictionary, counted: Dictionary) -> void:
	var cells: int = (st.get("cells", []) as Array).size()
	if st.has("connector"):
		counted["alley_connector_cells"] = int(counted["alley_connector_cells"]) + cells
		counted["alley_connectors"] = int(counted["alley_connectors"]) + 1
		return
	counted["alley_ring_cells"] = int(counted["alley_ring_cells"]) + cells
	if bool(st.get("isolated", false)):
		counted["alley_isolated"] = int(counted["alley_isolated"]) + 1


#Outdoor objects of the city passes, split into the nature tag and the four street tags.
static func _object_counts(area: BattlefieldArea) -> Dictionary:
	var nature: int = 0
	var street: int = 0
	for entry: Variant in area.obstacles:
		var obs: Dictionary = entry as Dictionary
		if not obs.has("city"):
			continue
		var tag: String = String(obs["city"])
		if tag == "nature":
			nature += 1
		elif STREET_TAGS.has(tag):
			street += 1
	return {"nature": nature, "street": street}


#Rule 3: a building that reached the map carries no issue of its own.
static func _building_issues(area: BattlefieldArea, out: Array[String]) -> void:
	var hits: int = 0
	for bi: int in range(area.buildings.size()):
		var rec: Dictionary = area.buildings[bi]
		var issues: Array = rec.get("issues", []) as Array
		if issues.is_empty():
			continue
		hits = _hit(out, hits, "building %d (%s) carries %d issue(s): %s"
			% [bi, String(rec.get("name", "")), issues.size(), String(issues[0])])
		if hits >= CityAccess.HITS_PER_RULE:
			return


#Rule 5: one building per lot, inside the lot rect, with the setbacks of the design.
static func _lot_fill(area: BattlefieldArea, out: Array[String]) -> void:
	var lots: Array = area.city.get("lots", []) as Array
	var owner: Dictionary = {}
	var hits: int = 0
	for li: int in range(lots.size()):
		var lot: Dictionary = lots[li]
		var bid: int = int(lot.get("building", -1))
		if bid < 0:
			if not lot.has("failed"):
				hits = _hit(out, hits, "lot %d holds no building and did not fail" % li)
			elif _holds_building(area, lot.get("rect", Rect2i())):
				hits = _hit(out, hits, "failed lot %d holds a building cell" % li)
			if hits >= CityAccess.HITS_PER_RULE:
				return
			continue
		if bid >= area.buildings.size():
			hits = _hit(out, hits, "lot %d names building %d of %d" % [li, bid, area.buildings.size()])
		elif owner.has(bid):
			hits = _hit(out, hits, "lots %d and %d share building %d" % [int(owner[bid]), li, bid])
		else:
			owner[bid] = li
			hits = _setback(area, lot, li, bid, out, hits)
		if hits >= CityAccess.HITS_PER_RULE:
			return
	for bi: int in range(area.buildings.size()):
		if owner.has(bi):
			continue
		hits = _hit(out, hits, "building %d lies in no lot" % bi)
		if hits >= CityAccess.HITS_PER_RULE:
			return


static func _holds_building(area: BattlefieldArea, r: Rect2i) -> bool:
	for y: int in range(maxi(r.position.y, 0), mini(r.end.y, area.length)):
		for x: int in range(maxi(r.position.x, 0), mini(r.end.x, area.width)):
			if area.building_id_at.has(Vector2i(x, y)):
				return true
	return false


#Gaps between the building rect and the lot edge: 1 or more on the back and both sides, 0 or more in front.
static func _setback(area: BattlefieldArea, lot: Dictionary, li: int, bid: int, out: Array[String],
		hits: int) -> int:
	var lr: Rect2i = lot.get("rect", Rect2i())
	var br: Rect2i = (area.buildings[bid] as Dictionary).get("rect", Rect2i())
	if not lr.encloses(br):
		return _hit(out, hits, "building %d %s leaves lot %d %s" % [bid, str(br), li, str(lr)])
	var gaps: Array[int] = [br.position.y - lr.position.y, lr.end.y - br.end.y,
		br.position.x - lr.position.x, lr.end.x - br.end.x]
	var want: Array[int] = [1, 1, 1, 1]
	var front: int = CityGrid.SIDES.find(String(lot.get("front", "")))
	if front >= 0:
		want[front] = 0
	for i: int in range(4):
		if gaps[i] >= want[i]:
			continue
		hits = _hit(out, hits, "building %d leaves %d cell(s) on side %s of lot %d"
			% [bid, gaps[i], String(CityGrid.SIDES[i]), li])
		if hits >= CityAccess.HITS_PER_RULE:
			return hits
	return hits


#Spacing rule: CityLots.GAP or more free cells lie between the cells of two buildings, corners included.
static func _spacing(area: BattlefieldArea, out: Array[String]) -> void:
	var hits: int = 0
	var seen: Dictionary = {}
	for key: Variant in area.building_id_at.keys():
		var cell: Vector2i = key as Vector2i
		var id: int = int(area.building_id_at[cell])
		for dy: int in range(-CityLots.GAP, CityLots.GAP + 1):
			for dx: int in range(-CityLots.GAP, CityLots.GAP + 1):
				var other: int = int(area.building_id_at.get(Vector2i(cell.x + dx, cell.y + dy), id))
				if other == id:
					continue
				var pair := Vector2i(mini(id, other), maxi(id, other))
				if seen.has(pair):
					continue
				seen[pair] = true
				hits = _hit(out, hits, "building %d stands within %d cells of building %d at %d,%d"
					% [id, CityLots.GAP, other, cell.x, cell.y])
				if hits >= CityAccess.HITS_PER_RULE:
					return


#Rule 7: a building of more than one floor keeps a stair on every floor but one end floor.
static func _floors(area: BattlefieldArea, out: Array[String]) -> void:
	if area.building_planes.size() != area.buildings.size():
		_note(out, "%d plane set(s) for %d building(s)"
			% [area.building_planes.size(), area.buildings.size()])
		return
	var stairs: Dictionary = {}
	for key: Variant in area.stair_links.keys():
		var c: Vector3i = key as Vector3i
		if not stairs.has(c.z):
			stairs[c.z] = []
		(stairs[c.z] as Array).append(Vector2i(c.x, c.y))
	var hits: int = 0
	for bi: int in range(area.buildings.size()):
		var rec: Dictionary = area.buildings[bi]
		var floors: Array = rec.get("floors", []) as Array
		if floors.size() < 2:
			continue
		var r: Rect2i = rec.get("rect", Rect2i())
		var missing: Array[int] = []
		for fv: Variant in floors:
			var f: int = int(fv)
			if not _stair_in(stairs, f, r):
				missing.append(f)
		if missing.is_empty():
			continue
		var ends: bool = missing.size() == 1 \
			and (missing[0] == int(floors[0]) or missing[0] == int(floors[floors.size() - 1]))
		if ends:
			continue
		hits = _hit(out, hits, "building %d holds %d floor(s) and %d without a stair"
			% [bi, floors.size(), missing.size()])
		if hits >= CityAccess.HITS_PER_RULE:
			return


static func _stair_in(stairs: Dictionary, f: int, r: Rect2i) -> bool:
	if not stairs.has(f):
		return false
	for c: Vector2i in (stairs[f] as Array):
		if r.has_point(c):
			return true
	return false


#Spawn rule: two opposite sides, both centres standing on ground the main streets reach, enough open room.
static func _spawn(area: BattlefieldArea, out: Array[String]) -> void:
	if not area.city.has("spawn"):
		_note(out, "the map holds no spawn record")
		return
	var sp: Dictionary = area.city["spawn"]
	if int(sp.get("side_a", -1)) == int(sp.get("side_b", -2)):
		_note(out, "both teams spawn on side %d" % int(sp.get("side_a", -1)))
	var reach0: PackedByteArray = (area.city.get("access", {}) as Dictionary).get("reach0",
		PackedByteArray())
	_spawn_side(area, "a", area.spawn_center_a, int(sp.get("outdoor_a", 0)), reach0, out)
	_spawn_side(area, "b", area.spawn_center_b, int(sp.get("outdoor_b", 0)), reach0, out)


static func _spawn_side(area: BattlefieldArea, tag: String, c: Vector2i, outdoor: int,
		reach0: PackedByteArray, out: Array[String]) -> void:
	if not area.in_bounds_xy(c.x, c.y):
		_note(out, "spawn %s stands at %d,%d, off the map" % [tag, c.x, c.y])
		return
	if area.building_id_at.has(c):
		_note(out, "spawn %s stands at %d,%d, inside a building" % [tag, c.x, c.y])
	elif reach0.size() == area.width * area.length and reach0[c.y * area.width + c.x] != 1:
		_note(out, "spawn %s at %d,%d reaches no main street" % [tag, c.x, c.y])
	if outdoor < CitySpawns.MIN_OUTDOOR:
		_note(out, "spawn %s holds %d outdoor cell(s), %d wanted" % [tag, outdoor, CitySpawns.MIN_OUTDOOR])


#Back lane rule: every painted lane serves a back door and joins a street of its own.
static func _lanes(area: BattlefieldArea, out: Array[String]) -> void:
	var doors: Dictionary = {}
	for dv: Variant in ((area.city.get("access", {}) as Dictionary).get("doors", []) as Array):
		var d: Dictionary = dv as Dictionary
		if String(d.get("kind", "")) == "back":
			doors[int(d.get("building", -1))] = d.get("outside", Vector2i(-1, -1))
	var hits: int = 0
	for entry: Variant in _streets(area):
		var st: Dictionary = entry as Dictionary
		if not st.has("back_door"):
			continue
		var id: int = int(st.get("id", -1))
		var bid: int = int(st["back_door"])
		if bid < 0 or bid >= area.buildings.size():
			hits = _hit(out, hits, "lane %d names building %d" % [id, bid])
		elif not doors.has(bid):
			hits = _hit(out, hits, "lane %d serves building %d, which holds no back door" % [id, bid])
		else:
			var segs: Array = st.get("segments", [])
			var outside: Vector2i = doors[bid]
			if segs.is_empty():
				hits = _hit(out, hits, "lane %d holds no segment" % id)
			else:
				var last: Rect2i = (segs[segs.size() - 1] as Dictionary).get("rect", Rect2i())
				if not last.has_point(outside):
					hits = _hit(out, hits, "lane %d ends away from the door of building %d at %d,%d"
						% [id, bid, outside.x, outside.y])
		hits = _lane_mouth(area, st, id, out, hits)
		if hits >= CityAccess.HITS_PER_RULE:
			return


static func _lane_mouth(area: BattlefieldArea, st: Dictionary, id: int, out: Array[String],
		hits: int) -> int:
	var m: Vector2i = st.get("mouth", Vector2i(-1, -1))
	if not area.in_bounds_xy(m.x, m.y):
		return _hit(out, hits, "lane %d joins %d,%d, off the map" % [id, m.x, m.y])
	var s: int = CityGrid.surf(area, m.x, m.y)
	if not CityGrid.is_street(s):
		return _hit(out, hits, "lane %d joins %d,%d, which holds surface %d"
			% [id, m.x, m.y, s])
	if CityGrid.street_id(area, m.x, m.y) == id:
		return _hit(out, hits, "lane %d joins itself at %d,%d" % [id, m.x, m.y])
	return hits

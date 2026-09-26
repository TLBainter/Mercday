class_name CityPlots

#Cuts the free ground of one city block into plots, fills the plots with lots and paints the ground.
#Runs after every street of the map is on the grid, so SURF_NONE marks the buildable cells.

const PLOT_MIN := 6
const PLOT_MAX := 28
const MAX_PASSES := 64
const GROW_MAX := 4
const CLASSES: Array[String] = ["Large", "Medium", "Small"]

static var _rows_by_class: Dictionary = {}
static var _thresholds: Dictionary = {}


#Plots, lots and ground surfaces of one block; appends to area.city["plots"] and area.city["lots"].
static func build(area: BattlefieldArea, block: Dictionary) -> void:
	if area == null or block.is_empty():
		return
	if not area.city.has("plots") or not area.city.has("lots"):
		return
	var rect: Rect2i = block.get("rect", Rect2i())
	if rect.size.x < 1 or rect.size.y < 1:
		return
	var bw: int = rect.size.x
	var found: Dictionary = _regions(area, rect)
	var region: PackedInt32Array = found["ids"]
	var bboxes: Array = found["bboxes"]
	var used := PackedByteArray()
	used.resize(bw * rect.size.y)
	var plots: Array = area.city["plots"]
	var fresh: Array[int] = []
	for rid: int in range(bboxes.size()):
		var bbox: Rect2i = bboxes[rid]
		var passes: int = 0
		while passes < MAX_PASSES:
			passes += 1
			var take: Rect2i = _largest_rect(region, used, bw, rid, bbox)
			if take.size.x < PLOT_MIN or take.size.y < PLOT_MIN:
				break
			for y: int in range(take.position.y, take.end.y):
				for x: int in range(take.position.x, take.end.x):
					used[y * bw + x] = 1
			for part: Rect2i in _split_parts(take):
				var pr := Rect2i(part.position + rect.position, part.size)
				if not CityGrid.has_any_access(area, pr):
					pr = _grow_to_access(area, region, used, rect, rid, part)
					if pr.size.x <= 0:
						continue
				var pid: int = plots.size()
				var lot_ids: Array[int] = []
				plots.append({
					"id": pid,
					"block": int(block.get("id", -1)),
					"rect": pr,
					"class": class_of(mini(pr.size.x, pr.size.y), class_thresholds()),
					"lots": lot_ids,
				})
				fresh.append(pid)
	for done: int in fresh:
		_fill_plot(area, plots[done])
	CityGrid.fill_ground(area, rect, BattlefieldArea.SURF_NATURE)


#Smallest lot side each building class needs: the narrowest row of the class plus a 2 cell margin all round.
static func class_thresholds() -> Dictionary:
	if not _thresholds.is_empty():
		return _thresholds
	var table: Dictionary = _rows()
	var out: Dictionary = {}
	for cls: String in CLASSES:
		var best: int = 1 << 20
		for row: Dictionary in table.get(cls, []):
			best = mini(best, mini(int(row["w"]), int(row["d"])) + 4)
		out[cls] = PLOT_MIN if best >= (1 << 20) else maxi(PLOT_MIN, best)
	if table.is_empty():
		return out
	_thresholds = out
	return _thresholds


#Names of the buildable rows of one class that fit a lot with this frontage and depth, in file order.
static func rows_that_fit(size_class: String, frontage: int, depth: int) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _rows().get(size_class, []):
		if frontage >= int(row["w"]) + 4 and depth >= int(row["d"]) + 4:
			out.append(String(row["name"]))
	return out


#Non legacy Buildings.tsv rows grouped by size class; the pool does not change at run time.
static func _rows() -> Dictionary:
	if not _rows_by_class.is_empty():
		return _rows_by_class
	var table: Dictionary = {}
	for row: Dictionary in DataManager.areas_pool:
		if not row.has("building") or BuildingRules.is_legacy(row):
			continue
		var b: Dictionary = row["building"]
		var cls: String = String(b.get("size_class", ""))
		if cls == "":
			continue
		if not table.has(cls):
			table[cls] = []
		var w: Vector2i = b.get("width", Vector2i.ZERO)
		var d: Vector2i = b.get("depth", Vector2i.ZERO)
		(table[cls] as Array).append({"name": String(row.get("name", "")), "w": w.x, "d": d.x})
	if table.is_empty():
		return table
	_rows_by_class = table
	return _rows_by_class


#4 connected regions of SURF_NONE cells inside rect: {"ids": region per block cell, "bboxes": one rect each}.
static func _regions(area: BattlefieldArea, rect: Rect2i) -> Dictionary:
	var bw: int = rect.size.x
	var bh: int = rect.size.y
	var n: int = bw * bh
	var ids := PackedInt32Array()
	ids.resize(n)
	ids.fill(-1)
	var free := PackedByteArray()
	free.resize(n)
	for y: int in range(bh):
		for x: int in range(bw):
			if CityGrid.surf(area, rect.position.x + x, rect.position.y + y) == BattlefieldArea.SURF_NONE:
				free[y * bw + x] = 1
	var bboxes: Array[Rect2i] = []
	var sx := PackedInt32Array()
	var sy := PackedInt32Array()
	sx.resize(n)
	sy.resize(n)
	for y0: int in range(bh):
		for x0: int in range(bw):
			var seed_i: int = y0 * bw + x0
			if free[seed_i] == 0 or ids[seed_i] >= 0:
				continue
			var rid: int = bboxes.size()
			var lo := Vector2i(x0, y0)
			var hi := Vector2i(x0, y0)
			ids[seed_i] = rid
			sx[0] = x0
			sy[0] = y0
			var sp: int = 1
			while sp > 0:
				sp -= 1
				var cx: int = sx[sp]
				var cy: int = sy[sp]
				lo.x = mini(lo.x, cx)
				lo.y = mini(lo.y, cy)
				hi.x = maxi(hi.x, cx)
				hi.y = maxi(hi.y, cy)
				for d: int in range(4):
					var nx: int = cx + CityGrid.DX_XFIRST[d]
					var ny: int = cy + CityGrid.DY_XFIRST[d]
					if nx < 0 or ny < 0 or nx >= bw or ny >= bh:
						continue
					var ni: int = ny * bw + nx
					if free[ni] == 0 or ids[ni] >= 0:
						continue
					ids[ni] = rid
					sx[sp] = nx
					sy[sp] = ny
					sp += 1
			bboxes.append(Rect2i(lo, hi - lo + Vector2i.ONE))
	return {"ids": ids, "bboxes": bboxes}


#Largest area rectangle with both sides >= PLOT_MIN among the free cells of one region; ties go row major.
static func _largest_rect(region: PackedInt32Array, used: PackedByteArray, bw: int, rid: int,
		bbox: Rect2i) -> Rect2i:
	var rw: int = bbox.size.x
	var heights := PackedInt32Array()
	heights.resize(rw)
	var stack := PackedInt32Array()
	stack.resize(rw + 2)
	var best := Rect2i()
	var best_area: int = 0
	for y: int in range(bbox.position.y, bbox.end.y):
		var base: int = y * bw + bbox.position.x
		for k: int in range(rw):
			var i: int = base + k
			if region[i] == rid and used[i] == 0:
				heights[k] += 1
			else:
				heights[k] = 0
		var sp: int = 0
		for k2: int in range(rw + 1):
			var h: int = 0 if k2 == rw else heights[k2]
			while sp > 0 and heights[stack[sp - 1]] > h:
				sp -= 1
				var th: int = heights[stack[sp]]
				var left: int = 0 if sp == 0 else stack[sp - 1] + 1
				var w: int = k2 - left
				var a: int = th * w
				if th < PLOT_MIN or w < PLOT_MIN:
					continue
				var x0: int = bbox.position.x + left
				var y0: int = y - th + 1
				var first: bool = y0 < best.position.y or (y0 == best.position.y and x0 < best.position.x)
				if a > best_area or (a == best_area and first):
					best_area = a
					best = Rect2i(x0, y0, w, th)
			stack[sp] = k2
			sp += 1
	return best


#A taken rectangle cut into plot sized parts: a side over PLOT_MAX gives Large sized pieces and one remainder.
static func _split_parts(rect: Rect2i) -> Array[Rect2i]:
	var xs: Array[int] = _cuts(rect.position.x, rect.size.x)
	var ys: Array[int] = _cuts(rect.position.y, rect.size.y)
	var out: Array[Rect2i] = []
	for yi: int in range(ys.size() - 1):
		for xi: int in range(xs.size() - 1):
			out.append(Rect2i(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))
	return out


#large_in pins the Large threshold for the suite; both production callers pass two arguments.
static func _cuts(start: int, size: int, large_in: int = -1) -> Array[int]:
	var large: int = large_in if large_in > 0 \
		else clampi(int(class_thresholds().get("Large", 20)), PLOT_MIN, PLOT_MAX)
	var pieces: Array[int] = []
	var left: int = size
	while left > PLOT_MAX:
		var hi: int = mini(PLOT_MAX, left - PLOT_MIN)
		var piece: int = randi_range(mini(large, hi), hi)
		pieces.append(piece)
		left -= piece
	pieces.append(left)
	if pieces.size() > 1 and randi_range(0, 1) == 0:
		pieces.reverse()
	var out: Array[int] = [start]
	var at: int = start
	for p: int in pieces:
		at += p
		out.append(at)
	return out


#A part with no street access widened over free cells of its region, up to GROW_MAX on one side, until it has access.
static func _grow_to_access(area: BattlefieldArea, region: PackedInt32Array, used: PackedByteArray,
		block: Rect2i, rid: int, part: Rect2i) -> Rect2i:
	var bw: int = block.size.x
	for side: String in CityGrid.SIDES:
		var cur: Rect2i = part
		for _g: int in range(GROW_MAX):
			var strip: Rect2i = _strip(cur, side)
			if not Rect2i(Vector2i.ZERO, block.size).encloses(strip):
				break
			if not _all_free(region, used, bw, rid, strip):
				break
			cur = cur.merge(strip)
			if cur.size.x > PLOT_MAX or cur.size.y > PLOT_MAX:
				break
			var world := Rect2i(cur.position + block.position, cur.size)
			if not CityGrid.has_any_access(area, world):
				continue
			for y: int in range(cur.position.y, cur.end.y):
				for x: int in range(cur.position.x, cur.end.x):
					used[y * bw + x] = 1
			return world
	return Rect2i()


#The one cell wide row or column just outside a side of a rectangle.
static func _strip(r: Rect2i, side: String) -> Rect2i:
	match side:
		"N":
			return Rect2i(r.position.x, r.position.y - 1, r.size.x, 1)
		"S":
			return Rect2i(r.position.x, r.end.y, r.size.x, 1)
		"W":
			return Rect2i(r.position.x - 1, r.position.y, 1, r.size.y)
	return Rect2i(r.end.x, r.position.y, 1, r.size.y)


static func _all_free(region: PackedInt32Array, used: PackedByteArray, bw: int, rid: int, r: Rect2i) -> bool:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var i: int = y * bw + x
			if region[i] != rid or used[i] != 0:
				return false
	return true


#Plot class of a shortest side m against the thresholds th; the one owner of the class rule.
static func class_of(m: int, th: Dictionary) -> String:
	if m >= int(th.get("Large", 20)):
		return "Large"
	if m >= int(th.get("Medium", 13)):
		return "Medium"
	return "Small"


#Picks one valid filling for a plot and records its lots; a plot with no valid filling keeps no lot.
static func _fill_plot(area: BattlefieldArea, plot: Dictionary) -> void:
	var valid: Array = []
	for option: Array in _options(plot["rect"], String(plot["class"])):
		for alt: Array in option:
			var lots: Array = _resolve(area, alt)
			if lots.is_empty():
				continue
			valid.append(lots)
			break
	if valid.is_empty():
		return
	var pick: int = 0 if valid.size() == 1 else randi() % valid.size()
	var all_lots: Array = area.city["lots"]
	var ids: Array = plot["lots"]
	for lot: Dictionary in valid[pick]:
		var lid: int = all_lots.size()
		lot["id"] = lid
		lot["plot"] = int(plot["id"])
		all_lots.append(lot)
		ids.append(lid)
		CityGrid.fill_ground(area, lot["rect"], BattlefieldArea.SURF_LOT)


#The fillings of a plot class in table order; each option holds the arrangements to try, best first.
static func _options(rect: Rect2i, cls: String) -> Array:
	var out: Array = []
	if cls != "Large" and cls != "Medium":
		out.append([[_spec(rect, "Small")]])
		return out
	var along_x: bool = rect.size.x >= rect.size.y
	var half: Array[Rect2i] = _split2(rect, along_x)
	if cls == "Medium":
		out.append([[_spec(rect, "Medium")]])
		out.append([[_spec(half[0], "Small"), _spec(half[1], "Small")]])
		return out
	out.append([[_spec(rect, "Large")]])
	out.append([[_spec(half[0], "Medium"), _spec(half[1], "Medium")]])
	var first: int = randi() % 2
	var mixed: Array = []
	for k: int in range(2):
		var m: int = (first + k) % 2
		var cross: Array[Rect2i] = _split2(half[1 - m], not along_x)
		mixed.append([_spec(half[m], "Medium"), _spec(cross[0], "Small"), _spec(cross[1], "Small")])
	out.append(mixed)
	var quads: Array[Rect2i] = []
	for hr: Rect2i in half:
		quads.append_array(_split2(hr, not along_x))
	var four: Array = []
	for q: Rect2i in quads:
		four.append(_spec(q, "Small"))
	out.append([four])
	return out


static func _spec(rect: Rect2i, cls: String) -> Dictionary:
	return {"rect": rect, "class": cls}


#Two parts of rect, the first one cell longer on an odd side; split_x cuts the x extent, else the y extent.
static func _split2(rect: Rect2i, split_x: bool) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if split_x:
		var w: int = (rect.size.x + 1) >> 1
		out.append(Rect2i(rect.position.x, rect.position.y, w, rect.size.y))
		out.append(Rect2i(rect.position.x + w, rect.position.y, rect.size.x - w, rect.size.y))
		return out
	var h: int = (rect.size.y + 1) >> 1
	out.append(Rect2i(rect.position.x, rect.position.y, rect.size.x, h))
	out.append(Rect2i(rect.position.x, rect.position.y + h, rect.size.x, rect.size.y - h))
	return out


#The lot records of one arrangement, or an empty Array when any lot of it has no usable front.
static func _resolve(area: BattlefieldArea, specs: Array) -> Array:
	var out: Array = []
	for spec: Dictionary in specs:
		var lot: Dictionary = _front_of(area, spec["rect"], String(spec["class"]))
		if lot.is_empty():
			return []
		out.append(lot)
	return out


#The best fronting side of a lot: street kind first, then touched cells, ties rolled; {} when none fits.
static func _front_of(area: BattlefieldArea, rect: Rect2i, cls: String) -> Dictionary:
	if mini(rect.size.x, rect.size.y) < int(class_thresholds().get(cls, PLOT_MIN)):
		return {}
	var open: Array = []
	for side: String in CityGrid.SIDES:
		if not CityGrid.side_has_access(area, rect, side):
			continue
		var touch: Dictionary = CityGrid.side_touch(area, rect, side)
		open.append({"side": side, "kind": String(touch["kind"]), "count": int(touch["count"])})
	while open.size() > 0:
		var at: int = _best_side(open)
		var entry: Dictionary = open[at]
		open.remove_at(at)
		var flat: bool = entry["side"] == "N" or entry["side"] == "S"
		var frontage: int = rect.size.x if flat else rect.size.y
		var depth: int = rect.size.y if flat else rect.size.x
		var rows: Array[String] = rows_that_fit(cls, frontage, depth)
		if rows.is_empty():
			continue
		return {
			"id": -1,
			"plot": -1,
			"rect": rect,
			"class": cls,
			"front": String(entry["side"]),
			"front_kind": String(entry["kind"]),
			"rows": rows,
			"building": -1,
		}
	return {}


static func _best_side(open: Array) -> int:
	var tied: Array[int] = []
	var best_rank: int = -1
	var best_count: int = -1
	for i: int in range(open.size()):
		var e: Dictionary = open[i]
		var r: int = CityGrid.kind_rank(String(e["kind"]))
		var c: int = int(e["count"])
		if r > best_rank or (r == best_rank and c > best_count):
			best_rank = r
			best_count = c
			tied.clear()
			tied.append(i)
		elif r == best_rank and c == best_count:
			tied.append(i)
	if tied.size() < 2:
		return tied[0]
	return tied[randi() % tied.size()]

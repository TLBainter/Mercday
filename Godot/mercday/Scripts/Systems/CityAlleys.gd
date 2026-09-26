class_name CityAlleys

#Alleys that wrap the buildings of a city block map: a ring of 1 or 2 Paces around every building, then the
#connector strips that join an alley reaching no street to the nearest street or alley within D Paces.

const RING_W := Vector2i(1, 2)
const RING_FAR := 4
const D_MIN := 2
const D_MAX := 7
const D_RISE := 5.0
const D_SIDE := 48.0
const D_SPAN := 152.0
#Clockwise order; the ring and connector walks of this file depend on it, so it is part of their contract.
const DX: Array[int] = [1, 0, -1, 0]
const DY: Array[int] = [0, 1, 0, -1]


#Paints the rings and the connectors and appends one street record for each; runs before the object passes.
static func build(area: BattlefieldArea) -> void:
	if area == null or not area.city.has("streets"):
		return
	var rings: Array[Dictionary] = _rings(area)
	var links: Array[Dictionary] = _connect(area, rings)
	area.city["alleys"] = {
		"ring_cells": _cell_count(rings),
		"connector_cells": _cell_count(links),
		"connectors": links.size(),
		"isolated": _isolated_count(rings),
		"d": connect_d_for(mini(area.width, area.length)),
	}


#The connector reach in Paces of a map whose shorter side is side: 2 at 48 rising to 7 at 200.
static func connect_d_for(side: int) -> int:
	return clampi(D_MIN + roundi(D_RISE * (float(side) - D_SIDE) / D_SPAN), D_MIN, D_MAX)


#True when the street record is a ring or a connector of this pass.
static func is_wrap(st: Dictionary) -> bool:
	return st.has("ring") or st.has("connector")


#True when the street record is the ring of a building, not a connector.
static func is_ring(st: Dictionary) -> bool:
	return int(st.get("ring", -1)) >= 0


#Every cell the rings and the connectors of the map painted, as a Vector2i set.
static func wrap_cells(area: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for entry: Variant in (area.city.get("streets", []) as Array):
		var st: Dictionary = entry as Dictionary
		if not is_wrap(st):
			continue
		for cv: Variant in (st.get("cells", []) as Array):
			out[cv as Vector2i] = true
	return out


static func _cell_count(recs: Array[Dictionary]) -> int:
	var out: int = 0
	for rec: Dictionary in recs:
		out += (rec.get("cells", []) as Array).size()
	return out


static func _isolated_count(recs: Array[Dictionary]) -> int:
	var out: int = 0
	for rec: Dictionary in recs:
		if bool(rec.get("isolated", false)):
			out += 1
	return out


#### Rings.


#One ring record per placed building; a ring cell that already carries a street or an object is skipped.
static func _rings(area: BattlefieldArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var streets: Array = area.city["streets"] as Array
	for bid: int in range(area.buildings.size()):
		var rect: Rect2i = (area.buildings[bid] as Dictionary).get("rect", Rect2i())
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var w: int = randi_range(RING_W.x, RING_W.y)
		var id: int = streets.size()
		var cells: Array[Vector2i] = []
		for d: int in range(1, w + 1):
			for c: Vector2i in _band(area, rect, d):
				if not _ring_ok(area, c, bid, d):
					continue
				_paint(area, c, id)
				cells.append(c)
		if cells.is_empty():
			continue
		var rec: Dictionary = {
			"id": id,
			"kind": "alley",
			"ring": bid,
			"width": w,
			"axis": "x",
			"dead_end": false,
			"block": -1,
			"mouth": Vector2i(-1, -1),
			"cells": cells,
			"segments": _row_segments(cells),
		}
		streets.append(rec)
		out.append(rec)
	return out


#The cells exactly d Paces from rect, in row then column order.
static func _band(area: BattlefieldArea, rect: Rect2i, d: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var outer: Rect2i = rect.grow(d)
	var inner: Rect2i = rect.grow(d - 1)
	for y: int in range(maxi(outer.position.y, 0), mini(outer.end.y, area.length)):
		for x: int in range(maxi(outer.position.x, 0), mini(outer.end.x, area.width)):
			if inner.has_point(Vector2i(x, y)):
				continue
			out.append(Vector2i(x, y))
	return out


#A second ring Pace needs RING_FAR Paces to every other building, so two rings never merge wider than 2.
static func _ring_ok(area: BattlefieldArea, c: Vector2i, bid: int, d: int) -> bool:
	if not _ground_ok(area, c):
		return false
	if d < 2:
		return true
	for other: int in range(area.buildings.size()):
		if other == bid:
			continue
		var r: Rect2i = (area.buildings[other] as Dictionary).get("rect", Rect2i())
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		if _cheb(c, r) < RING_FAR:
			return false
	return true


static func _cheb(c: Vector2i, r: Rect2i) -> int:
	var dx: int = maxi(maxi(r.position.x - c.x, c.x - r.end.x + 1), 0)
	var dy: int = maxi(maxi(r.position.y - c.y, c.y - r.end.y + 1), 0)
	return maxi(dx, dy)


#True when the cell takes alley paint: open ground on floor 0 with no building, object, stair or roof.
static func _ground_ok(area: BattlefieldArea, c: Vector2i) -> bool:
	if not CityGrid.inside(area, c.x, c.y):
		return false
	var s: int = CityGrid.surf(area, c.x, c.y)
	if s != BattlefieldArea.SURF_LOT and s != BattlefieldArea.SURF_NATURE \
			and s != BattlefieldArea.SURF_NONE:
		return false
	if area.building_id_at.has(c):
		return false
	if not area.get_obs(c, 0).is_empty():
		return false
	return not area.is_stair_cell(c, 0) and area.roof_level_at(c) < 0


static func _paint(area: BattlefieldArea, c: Vector2i, id: int) -> void:
	CityGrid.paint_force(area, c.x, c.y, BattlefieldArea.SURF_ALLEY, id)
	area.terrain_heights[c] = CityGenerator.CURB


#A ring is no single lane, so its segments are the maximal runs of one row each.
static func _row_segments(cells: Array[Vector2i]) -> Array[Dictionary]:
	var rows: Dictionary = {}
	for c: Vector2i in cells:
		var xs: PackedInt32Array = rows.get(c.y, PackedInt32Array())
		xs.append(c.x)
		rows[c.y] = xs
	var ys: Array = rows.keys()
	ys.sort()
	var out: Array[Dictionary] = []
	for y: int in ys:
		var xs2: PackedInt32Array = rows[y]
		xs2.sort()
		var start: int = 0
		for i: int in range(xs2.size()):
			if i + 1 < xs2.size() and xs2[i + 1] == xs2[i] + 1:
				continue
			out.append({"rect": Rect2i(xs2[start], y, xs2[i] - xs2[start] + 1, 1), "axis": "x",
				"width": 1})
			start = i + 1
	return out


#### Connectors.


#Joins every alley component that reaches no street to another one; returns the records it added.
static func _connect(area: BattlefieldArea, rings: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = area.width * area.length
	var labels: Array[int] = []
	labels.resize(n)
	labels.fill(-1)
	var roots: Array[int] = []
	var open: Array[bool] = []
	var cells_of: Array = []
	_label(area, labels, roots, open, cells_of)
	var dist: Array[int] = []
	dist.resize(n)
	var prev: Array[int] = []
	prev.resize(n)
	var seen: Array[int] = []
	seen.resize(n)
	seen.fill(-1)
	var d: int = connect_d_for(mini(area.width, area.length))
	var run: int = 0
	var moved: bool = true
	while moved:
		moved = false
		for lab: int in range(roots.size()):
			if open[lab] or _find(roots, lab) != lab:
				continue
			for want: int in range(2):
				run += 1
				var rec: Dictionary = _bfs(area, labels, roots, open, cells_of, dist, prev, seen,
					lab, d, run, want == 0)
				if rec.is_empty():
					continue
				out.append(rec)
				moved = true
				break
	_mark_isolated(area, labels, roots, open, rings)
	return out


#One label per 4-connected street component, with its cells and whether it holds a street or sidewalk cell.
static func _label(area: BattlefieldArea, labels: Array[int], roots: Array[int], open: Array[bool],
		cells_of: Array) -> void:
	var w: int = area.width
	for y: int in range(area.length):
		for x: int in range(w):
			var i: int = y * w + x
			if labels[i] >= 0 or not CityGrid.is_street(area.surface_grid[i]):
				continue
			var id: int = roots.size()
			roots.append(id)
			open.append(false)
			var mine: Array[int] = []
			cells_of.append(mine)
			labels[i] = id
			var stack: Array[int] = [i]
			while not stack.is_empty():
				var cur: int = stack.pop_back()
				mine.append(cur)
				if area.surface_grid[cur] != BattlefieldArea.SURF_ALLEY:
					open[id] = true
				var cx: int = cur % w
				var cy: int = int(cur / float(w))
				for k: int in range(4):
					var nx: int = cx + DX[k]
					var ny: int = cy + DY[k]
					if nx < 0 or ny < 0 or nx >= w or ny >= area.length:
						continue
					var ni: int = ny * w + nx
					if labels[ni] >= 0 or not CityGrid.is_street(area.surface_grid[ni]):
						continue
					labels[ni] = id
					stack.append(ni)


#Multi-source BFS from every cell of lab over ground, at most d Paces; the first other component wins.
static func _bfs(area: BattlefieldArea, labels: Array[int], roots: Array[int], open: Array[bool],
		cells_of: Array, dist: Array[int], prev: Array[int], seen: Array[int], lab: int, d: int,
		run: int, want_open: bool) -> Dictionary:
	var w: int = area.width
	var src: Array[int] = cells_of[lab]
	src.sort()
	var queue: Array[int] = []
	for i: int in src:
		seen[i] = run
		dist[i] = 0
		prev[i] = -1
		queue.append(i)
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		var x: int = at % w
		var y: int = int(at / float(w))
		for k: int in range(4):
			var nx: int = x + DX[k]
			var ny: int = y + DY[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= area.length:
				continue
			var ni: int = ny * w + nx
			var nl: int = labels[ni]
			if nl >= 0:
				var rb: int = _find(roots, nl)
				if rb == lab or (want_open and not open[rb]):
					continue
				return _strip(area, labels, roots, open, cells_of, prev, at, lab, rb)
			if dist[at] >= d or seen[ni] == run or not _ground_ok(area, Vector2i(nx, ny)):
				continue
			seen[ni] = run
			dist[ni] = dist[at] + 1
			prev[ni] = at
			queue.append(ni)
	return {}


#Paints the path from the source cell out to at, records it and merges the two components.
static func _strip(area: BattlefieldArea, labels: Array[int], roots: Array[int], open: Array[bool],
		cells_of: Array, prev: Array[int], at: int, lab: int, rb: int) -> Dictionary:
	var w: int = area.width
	var path: Array[Vector2i] = []
	var cur: int = at
	while cur >= 0 and labels[cur] < 0:
		var cy: int = int(cur / float(w))
		path.append(Vector2i(cur % w, cy))
		cur = prev[cur]
	if path.is_empty():
		return {}
	path.reverse()
	var streets: Array = area.city["streets"] as Array
	var id: int = streets.size()
	var mine: Array[int] = cells_of[lab]
	for c: Vector2i in path:
		_paint(area, c, id)
		var i: int = c.y * w + c.x
		labels[i] = lab
		mine.append(i)
	var theirs: Array[int] = cells_of[rb]
	for i2: int in theirs:
		mine.append(i2)
	theirs.clear()
	roots[rb] = lab
	open[lab] = open[lab] or open[rb]
	var segments: Array[Dictionary] = CityAccess.lane_segments(path)
	var rec: Dictionary = {
		"id": id,
		"kind": "alley",
		"connector": true,
		"ring": -1,
		"width": 1,
		"axis": String((segments[0] as Dictionary)["axis"]),
		"dead_end": false,
		"block": -1,
		"mouth": Vector2i(-1, -1),
		"cells": path,
		"segments": segments,
	}
	streets.append(rec)
	return rec


#A ring no street reaches is kept as it is and marked, so the validator and the stats know of it.
static func _mark_isolated(area: BattlefieldArea, labels: Array[int], roots: Array[int],
		open: Array[bool], rings: Array[Dictionary]) -> void:
	var w: int = area.width
	for rec: Dictionary in rings:
		for cv: Variant in (rec.get("cells", []) as Array):
			var c: Vector2i = cv as Vector2i
			var lab: int = labels[c.y * w + c.x]
			if lab >= 0 and open[_find(roots, lab)]:
				continue
			rec["isolated"] = true
			break


static func _find(roots: Array[int], a: int) -> int:
	var r: int = a
	while roots[r] != r:
		r = roots[r]
	while roots[a] != r:
		var up: int = roots[a]
		roots[a] = r
		a = up
	return r

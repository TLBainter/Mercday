class_name CavernGenerator

const MAX_ATTEMPTS := 10
const CHAMBER_MARGIN := 3
const TUNNEL_MARGIN := 2
const CHAMBER_TRIES := 200
const MIN_CHAMBER := 3
const MAX_CHAMBER := 12
const MAX_CLEARANCE := 12
const SLOPE := 0.25
const EPS := 0.000001
const SPILL_RANGE := 2
const ENTRANCE_DRY_RANGE := 3

#Tunnel width 1/2/3 and tunnel height 1/2/3.
const WIDTH_WEIGHTS: Array[int] = [40, 40, 20]
const HEIGHT_WEIGHTS: Array[int] = [25, 45, 30]
#Entrance count 1/2/3.
const ENTRANCE_WEIGHTS: Array[int] = [50, 35, 15]
#Pool depth 1..15 in tenths of a percent.
const DEPTH_WEIGHTS: Array[int] = [80, 120, 200, 200, 150, 70, 50, 40, 30, 20, 8, 8, 8, 8, 8]


#Carves a whole cavern into field; retries the layout while validate() reports a broken invariant.
static func generate(field: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext) -> void:
	var violations: Array[String] = []
	var rejects: Array[String] = []
	for attempt: int in range(MAX_ATTEMPTS):
		_build(field, area_data, ctx)
		violations = validate(field)
		if violations.is_empty():
			break
		rejects.append("[CAVERN] attempt %d rejected" % (attempt + 1))
		for v: String in violations:
			rejects.append("[CAVERN] VIOLATION %s" % v)
	field.generation_log.append_array(rejects)
	var pools: int = 0
	for ch: Dictionary in field.cavern_chambers:
		if bool(ch.get("flooded", false)):
			pools += 1
	field.generation_log.append("[CAVERN] %s %dx%d chambers=%d tunnels=%d entrances=%d pools=%d violations=%d" % [
		str(area_data.get("name", field.area_name)), field.width, field.length,
		field.cavern_chambers.size(), field.cavern_tunnels.size(),
		_entrance_count(field), pools, violations.size()])


#Every non-rock cell of the map.
static func open_cells(field: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for y: int in range(field.length):
		for x: int in range(field.width):
			var cell := Vector2i(x, y)
			if not field.rock_cells.has(cell):
				out[cell] = true
	return out


#8-way flood over open cells; rock, solid obstacles and steps above one slope stop it.
static func reachable_from(field: BattlefieldArea, starts: Array[Vector2i]) -> Dictionary:
	return _flood(starts, PathCost.DIRS8, _walkable_step.bind(field))


static func _walkable_step(curr: Vector2i, nb: Vector2i, field: BattlefieldArea) -> bool:
	if not field.in_bounds_xy(nb.x, nb.y):
		return false
	if field.rock_cells.has(nb) or field.is_obstacle(nb, 0):
		return false
	return absf(field.surface_height(nb) - field.surface_height(curr)) <= SLOPE + EPS


static func _in_set(_from: Vector2i, cell: Vector2i, cells: Dictionary) -> bool:
	return cells.has(cell)


#Breadth-first flood in seed, then direction order; returns cell -> steps from the nearest seed.
static func _flood(seeds: Array[Vector2i], dirs: Array[Vector2i], can_step: Callable, first_dist: int = 0,
		max_dist: int = -1, limit: int = -1) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s: Vector2i in seeds:
		if dist.has(s):
			continue
		dist[s] = first_dist
		queue.append(s)
	var qi: int = 0
	while qi < queue.size() and (limit < 0 or dist.size() < limit):
		var curr: Vector2i = queue[qi]
		qi += 1
		var nd: int = int(dist[curr]) + 1
		if max_dist >= 0 and nd > max_dist:
			continue
		for d: Vector2i in dirs:
			var nb: Vector2i = curr + d
			if dist.has(nb) or not bool(can_step.call(curr, nb)):
				continue
			dist[nb] = nd
			queue.append(nb)
			if limit >= 0 and dist.size() >= limit:
				break
	return dist


#One line per broken invariant; empty when the cavern is sound.
static func validate(field: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var open: Dictionary = open_cells(field)
	var chambers: Array[Dictionary] = field.cavern_chambers
	if chambers.size() < 2 or chambers.size() > 6:
		out.append("chambers=%d outside 2..6" % chambers.size())
	for i: int in range(chambers.size()):
		var rect: Rect2i = chambers[i]["rect"] as Rect2i
		if rect.size.x < MIN_CHAMBER or rect.size.x > MAX_CHAMBER \
				or rect.size.y < MIN_CHAMBER or rect.size.y > MAX_CHAMBER:
			out.append("chamber %d size %dx%d outside 3..12" % [i, rect.size.x, rect.size.y])
	var ent_count: int = _entrance_count(field)
	if ent_count < 1 or ent_count > 3:
		out.append("entrances=%d outside 1..3" % ent_count)
	if field.entrance_cells.is_empty():
		out.append("no entrance cells")
	for cell: Vector2i in field.entrance_cells:
		if cell.x != 0 and cell.y != 0 and cell.x != field.width - 1 and cell.y != field.length - 1:
			out.append("entrance cell (%d,%d) off the border" % [cell.x, cell.y])
		if not open.has(cell):
			out.append("entrance cell (%d,%d) is rock" % [cell.x, cell.y])
		if field.is_water(cell):
			out.append("entrance cell (%d,%d) flooded" % [cell.x, cell.y])
		if field.is_obstacle(cell, 0):
			out.append("entrance cell (%d,%d) blocked by an obstacle" % [cell.x, cell.y])
	if not field.entrance_cells.is_empty():
		var reach: Dictionary = reachable_from(field, [field.entrance_cells[0]])
		var unreached: int = 0
		for cell: Vector2i in open.keys():
			if field.is_obstacle(cell, 0):
				continue
			if not reach.has(cell):
				unreached += 1
		if unreached > 0:
			out.append("%d open cell(s) unreachable from the party entrance" % unreached)
	out.append_array(_validate_heights(field, open))
	out.append_array(_validate_ceilings(field, open))
	out.append_array(_validate_water(field, open))
	out.append_array(_validate_rock(field, open))
	out.append_array(_validate_spawns(field, open))
	return out


static func _validate_heights(field: BattlefieldArea, open: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for cell: Vector2i in open.keys():
		var h: float = field.get_terrain_height(cell)
		var wet: bool = field.is_water(cell)
		if h < -EPS and not wet:
			out.append("cell (%d,%d) height %.2f below 0" % [cell.x, cell.y, h])
		for d: Vector2i in PathCost.DIRS8:
			var nb: Vector2i = cell + d
			if not open.has(nb) or wet or field.is_water(nb):
				continue
			if absf(field.get_terrain_height(nb) - h) > SLOPE + EPS:
				out.append("step (%d,%d)->(%d,%d) over one slope" % [cell.x, cell.y, nb.x, nb.y])
				return out
	return out


static func _validate_ceilings(field: BattlefieldArea, open: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var in_chamber: Dictionary = chamber_index(field)
	for cell: Vector2i in open.keys():
		if not field.cavern_ceiling.has(cell):
			out.append("cell (%d,%d) has no ceiling" % [cell.x, cell.y])
			return out
		var c: float = field.clearance(cell)
		if c < 1.0 - EPS:
			out.append("cell (%d,%d) clearance %.2f below 1" % [cell.x, cell.y, c])
			return out
		var limit: float = float(MAX_CLEARANCE) if in_chamber.has(cell) else 3.0
		if c > limit + EPS:
			out.append("cell (%d,%d) clearance %.2f over %.1f" % [cell.x, cell.y, c, limit])
			return out
	for i: int in range(field.cavern_chambers.size()):
		var ch: Dictionary = field.cavern_chambers[i]
		var peak_c: float = float(ch.get("peak_clearance", 0.0))
		var edge_c: float = float(ch.get("edge_clearance", 0.0))
		if peak_c < edge_c:
			out.append("chamber %d peak clearance %.2f under the edge %.2f" % [i, peak_c, edge_c])
		var peak: Vector2i = ch.get("peak", Vector2i.ZERO) as Vector2i
		var size: int = int(ch.get("peak_size", 1))
		var cells: Dictionary = ch["cells"] as Dictionary
		for dy: int in range(size):
			for dx: int in range(size):
				var pc := Vector2i(peak.x + dx, peak.y + dy)
				if not cells.has(pc) or _hangs(field, pc):
					continue
				if absf(field.clearance(pc) - peak_c) > EPS:
					out.append("chamber %d peak cell (%d,%d) clearance %.2f" % [i, pc.x, pc.y, field.clearance(pc)])
	return out


static func _validate_water(field: BattlefieldArea, open: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if field.water_cells.is_empty():
		return out
	var allowed: Dictionary = {}
	var rims: Dictionary = {}
	for i: int in range(field.cavern_chambers.size()):
		var ch: Dictionary = field.cavern_chambers[i]
		if not bool(ch.get("flooded", false)):
			continue
		rims[i] = false
		var cells: Dictionary = ch["cells"] as Dictionary
		for cell: Vector2i in _spill_zone(open, cells).keys():
			allowed[cell] = i
	for cell: Vector2i in field.water_cells.keys():
		var depth: int = field.water_depth(cell)
		if depth < 1 or depth > 15:
			out.append("water (%d,%d) depth %d outside 1..15" % [cell.x, cell.y, depth])
		if not allowed.has(cell):
			out.append("water (%d,%d) outside a flooded chamber and its spill" % [cell.x, cell.y])
			continue
		var pool_ch: Dictionary = field.cavern_chambers[int(allowed[cell])]
		var surface: float = float(pool_ch.get("surface", 0.0))
		if absf(surface - float(pool_ch.get("level", 0.0))) > EPS:
			out.append("pool of chamber %d surface %.2f off its level %.2f" % [
				int(allowed[cell]), surface, float(pool_ch.get("level", 0.0))])
		if absf(field.get_terrain_height(cell) - (surface - float(depth))) > EPS:
			out.append("water (%d,%d) floor %.2f is not surface %.2f minus depth %d" % [
				cell.x, cell.y, field.get_terrain_height(cell), surface, depth])
		for d8: Vector2i in PathCost.DIRS8:
			var lip: Vector2i = cell + d8
			if not open.has(lip) or field.is_water(lip):
				continue
			var lip_h: float = field.get_terrain_height(lip)
			if lip_h < surface - EPS or lip_h > surface + SLOPE + EPS:
				out.append("water (%d,%d) lip (%d,%d) height %.2f off the surface %.2f" % [
					cell.x, cell.y, lip.x, lip.y, lip_h, surface])
		for d: Vector2i in PathCost.DIRS4:
			var nb: Vector2i = cell + d
			if open.has(nb) and not field.is_water(nb):
				rims[allowed[cell]] = true
				break
	for i: Variant in rims.keys():
		if not bool(rims[i]):
			out.append("pool of chamber %d has no dry rim" % int(i))
	return out


static func _touches_open(open: Dictionary, cell: Vector2i) -> bool:
	for d: Vector2i in PathCost.DIRS8:
		if open.has(cell + d):
			return true
	return false


static func _validate_rock(field: BattlefieldArea, open: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for cell: Vector2i in field.rock_cells.keys():
		if not _touches_open(open, cell):
			continue
		var obs: Dictionary = field.get_obs(cell, 0)
		if obs.get("cell_type", "") != "wall":
			out.append("rock (%d,%d) on the shell carries no wall" % [cell.x, cell.y])
			return out
	for cell: Vector2i in open.keys():
		if field.jagged_cells.has(cell):
			out.append("open cell (%d,%d) is jagged" % [cell.x, cell.y])
			return out
		if field.get_obs(cell, 0).get("cell_type", "") == "wall":
			out.append("open cell (%d,%d) carries a wall" % [cell.x, cell.y])
			return out
	return out


static func _validate_spawns(field: BattlefieldArea, open: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if field.spawn_zone_a.is_empty():
		out.append("spawn zone A empty")
	if field.spawn_zone_b.is_empty():
		out.append("spawn zone B empty")
	for entry: Array in [["A", field.spawn_center_a], ["B", field.spawn_center_b]]:
		var label: String = entry[0] as String
		var cell: Vector2i = entry[1] as Vector2i
		if not open.has(cell):
			out.append("spawn center %s (%d,%d) is rock" % [label, cell.x, cell.y])
			continue
		if field.is_water(cell):
			out.append("spawn center %s (%d,%d) flooded" % [label, cell.x, cell.y])
		if field.clearance(cell) < 1.0 - EPS:
			out.append("spawn center %s (%d,%d) clearance %.2f" % [label, cell.x, cell.y, field.clearance(cell)])
	return out


static func _hangs(field: BattlefieldArea, cell: Vector2i) -> bool:
	return bool(field.get_obs(cell, 0).get("hanging", false))


static func _entrance_count(field: BattlefieldArea) -> int:
	var count: int = 0
	for t: Dictionary in field.cavern_tunnels:
		if str(t.get("kind", "")) == "entrance":
			count += 1
	return count


#Vector2i -> chamber index over every chamber cell.
static func chamber_index(field: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(field.cavern_chambers.size()):
		for cell: Vector2i in (field.cavern_chambers[i]["cells"] as Dictionary).keys():
			out[cell] = i
	return out


#Chamber cells plus every open cell within two steps of them.
static func _spill_zone(open: Dictionary, cells: Dictionary) -> Dictionary:
	var seeds: Array[Vector2i] = []
	seeds.assign(cells.keys())
	return _flood(seeds, PathCost.DIRS4, _in_set.bind(open), 0, SPILL_RANGE)


static func _build(field: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext) -> void:
	field.reset_generated_state()
	field.is_cavern = true
	field.area_name = str(area_data.get("name", field.area_name))
	var open: Dictionary = {}
	for y: int in range(field.length):
		for x: int in range(field.width):
			field.rock_cells[Vector2i(x, y)] = true
	var cell_chamber: Dictionary = {}
	var tunnel_h: Dictionary = {}
	var chambers: Array[Dictionary] = _place_chambers(field, open, cell_chamber)
	_carve_tunnels(field, open, cell_chamber, tunnel_h, chambers)
	var entrances: Array[Dictionary] = _carve_entrances(field, open, cell_chamber, tunnel_h, chambers)
	var dead_ends: Array[Dictionary] = _carve_dead_ends(field, open, cell_chamber, tunnel_h)
	_assign_levels(field, open, chambers, entrances, dead_ends)
	_build_ceilings(field, open, cell_chamber, tunnel_h, chambers)
	_flood_chambers(field, open, chambers, entrances)
	_build_rock_shell(field, open)
	_place_spawns(field, open, chambers, entrances, ctx)
	var scatters: int = CavernScatter.place(field)
	field.generation_log.append("[CAVERN] scatters placed: %d" % scatters)
	field._rebuild_cover_obstacles()
	field._rebuild_droppable_obs_map()


static func _place_chambers(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary) -> Array[Dictionary]:
	var rects: Array[Rect2i] = []
	var max_w: int = mini(MAX_CHAMBER, field.width - 2 * CHAMBER_MARGIN)
	var max_l: int = mini(MAX_CHAMBER, field.length - 2 * CHAMBER_MARGIN)
	var target: int = randi_range(3, 6)
	for _i: int in range(target):
		if max_w < MIN_CHAMBER or max_l < MIN_CHAMBER:
			break
		for _try: int in range(CHAMBER_TRIES):
			var w: int = randi_range(MIN_CHAMBER, max_w)
			var l: int = randi_range(MIN_CHAMBER, max_l)
			var rect := Rect2i(
				randi_range(CHAMBER_MARGIN, field.width - CHAMBER_MARGIN - w),
				randi_range(CHAMBER_MARGIN, field.length - CHAMBER_MARGIN - l), w, l)
			var clear: bool = true
			for other: Rect2i in rects:
				if rect.grow(CHAMBER_MARGIN).intersects(other):
					clear = false
					break
			if clear:
				rects.append(rect)
				break
	if rects.size() < 2:
		rects = [Rect2i(CHAMBER_MARGIN, CHAMBER_MARGIN, 5, 5),
			Rect2i(field.width - CHAMBER_MARGIN - 5, field.length - CHAMBER_MARGIN - 5, 5, 5)]
	var chambers: Array[Dictionary] = []
	for i: int in range(rects.size()):
		var cells: Dictionary = _chamber_cells(rects[i])
		for cell: Vector2i in cells.keys():
			_open_cell(field, open, cell)
			cell_chamber[cell] = i
		chambers.append({
			"rect": rects[i], "cells": cells, "level": 0.0, "peak": rects[i].position,
			"peak_size": 1, "peak_clearance": 1.0, "edge_clearance": 1.0,
			"flooded": false, "depth": 0, "surface": 0.0, "name": "Chamber %d" % (i + 1)})
		field.generation_log.append("[CAVERN] chamber %d pos=(%d,%d) size=%dx%d cells=%d" % [
			i + 1, rects[i].position.x, rects[i].position.y, rects[i].size.x, rects[i].size.y, cells.size()])
	field.cavern_chambers = chambers
	return chambers


#Rect cells minus a random block at each corner; a 3x3 chamber keeps every cell.
static func _chamber_cells(rect: Rect2i) -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = true
	var max_cx: int = mini(2, (rect.size.x - MIN_CHAMBER) >> 1)
	var max_cy: int = mini(2, (rect.size.y - MIN_CHAMBER) >> 1)
	if max_cx <= 0 or max_cy <= 0:
		return cells
	for corner: int in range(4):
		var cx: int = randi_range(0, max_cx)
		var cy: int = randi_range(0, max_cy)
		for dx: int in range(cx):
			for dy: int in range(cy):
				var px: int = (rect.position.x + dx) if (corner % 2 == 0) else (rect.end.x - 1 - dx)
				var py: int = (rect.position.y + dy) if (corner < 2) else (rect.end.y - 1 - dy)
				cells.erase(Vector2i(px, py))
	return cells


static func _carve_tunnels(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary,
		tunnel_h: Dictionary, chambers: Array[Dictionary]) -> void:
	var edges: Array[Dictionary] = _mst_edges(chambers)
	var joined: Dictionary = {}
	for e: Dictionary in edges:
		joined[_pair_key(int(e["a"]), int(e["b"]))] = true
	var spare: Array[Vector2i] = []
	for a: int in range(chambers.size()):
		for b: int in range(a + 1, chambers.size()):
			if not joined.has(_pair_key(a, b)):
				spare.append(Vector2i(a, b))
	for _i: int in range(randi_range(1, 3)):
		if spare.is_empty():
			break
		var idx: int = randi_range(0, spare.size() - 1)
		edges.append({"a": spare[idx].x, "b": spare[idx].y, "kind": "loop"})
		spare.remove_at(idx)
	for e: Dictionary in edges:
		var a: int = int(e["a"])
		var b: int = int(e["b"])
		var from_pt: Vector2i = _edge_cell(chambers[a], _chamber_center(chambers[b]))
		var to_pt: Vector2i = _edge_cell(chambers[b], _chamber_center(chambers[a]))
		var w: int = WeightedTable.pick_index(WIDTH_WEIGHTS) + 1
		var h: int = WeightedTable.pick_index(HEIGHT_WEIGHTS) + 1
		var cells: Array[Vector2i] = []
		var points: Array[Vector2i] = _tunnel_points(field, from_pt, to_pt)
		for p: int in range(points.size() - 1):
			_carve(field, open, cell_chamber, tunnel_h, cells, points[p], points[p + 1], w, h, TUNNEL_MARGIN)
		field.cavern_tunnels.append({"cells": cells, "width": w, "height": h,
			"from": a, "to": b, "kind": str(e["kind"])})
		field.generation_log.append("[CAVERN] tunnel %s %d->%d width=%d height=%d length=%d" % [
			str(e["kind"]), a + 1, b + 1, w, h, cells.size()])


static func _mst_edges(chambers: Array[Dictionary]) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	var in_tree: Array[int] = [0]
	var outside: Array[int] = []
	for i: int in range(1, chambers.size()):
		outside.append(i)
	while not outside.is_empty():
		var best_a: int = in_tree[0]
		var best_b: int = outside[0]
		var best_d: float = INF
		for a: int in in_tree:
			for b: int in outside:
				var d: float = Vector2(_chamber_center(chambers[a]) - _chamber_center(chambers[b])).length()
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		edges.append({"a": best_a, "b": best_b, "kind": "mst"})
		in_tree.append(best_b)
		outside.erase(best_b)
	return edges


static func _pair_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


static func _chamber_center(ch: Dictionary) -> Vector2i:
	var rect: Rect2i = ch["rect"] as Rect2i
	return rect.position + Vector2i(rect.size.x >> 1, rect.size.y >> 1)


#Random cell on the rect edge of ch that faces toward.
static func _edge_cell(ch: Dictionary, toward: Vector2i) -> Vector2i:
	var rect: Rect2i = ch["rect"] as Rect2i
	var c: Vector2i = _chamber_center(ch)
	if absi(toward.x - c.x) >= absi(toward.y - c.y):
		var ex: int = (rect.end.x - 1) if toward.x >= c.x else rect.position.x
		return Vector2i(ex, randi_range(rect.position.y, rect.end.y - 1))
	var ey: int = (rect.end.y - 1) if toward.y >= c.y else rect.position.y
	return Vector2i(randi_range(rect.position.x, rect.end.x - 1), ey)


#Polyline from from_pt to to_pt with one to three waypoints pushed off the straight line.
static func _tunnel_points(field: BattlefieldArea, from_pt: Vector2i, to_pt: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = [from_pt]
	var count: int = randi_range(1, 3)
	var delta := Vector2(to_pt - from_pt)
	var perp := Vector2(-delta.normalized().y, delta.normalized().x)
	for i: int in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var base := Vector2(from_pt) + delta * t
		var off: float = float(randi_range(-4, 4))
		points.append(Vector2i(
			clampi(int(round(base.x + perp.x * off)), TUNNEL_MARGIN, field.width - 1 - TUNNEL_MARGIN),
			clampi(int(round(base.y + perp.y * off)), TUNNEL_MARGIN, field.length - 1 - TUNNEL_MARGIN)))
	points.append(to_pt)
	return points


static func _carve(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary, tunnel_h: Dictionary,
		cells: Array[Vector2i], from_pt: Vector2i, to_pt: Vector2i, w: int, h: int, margin: int) -> void:
	var pos := from_pt
	var step := Vector2i(1, 0)
	var guard: int = (field.width + field.length) * 4
	while pos != to_pt and guard > 0:
		guard -= 1
		var ddx: int = to_pt.x - pos.x
		var ddy: int = to_pt.y - pos.y
		if ddy == 0:
			step = Vector2i(signi(ddx), 0)
		elif ddx == 0:
			step = Vector2i(0, signi(ddy))
		elif randf() < absf(float(ddx)) / (absf(float(ddx)) + absf(float(ddy))):
			step = Vector2i(signi(ddx), 0)
		else:
			step = Vector2i(0, signi(ddy))
		_stamp(field, open, cell_chamber, tunnel_h, cells, pos, Vector2i(-step.y, step.x), w, h, margin)
		pos += step
	_stamp(field, open, cell_chamber, tunnel_h, cells, pos, Vector2i(-step.y, step.x), w, h, margin)


#Lays the tunnel width across the step direction at center.
static func _stamp(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary, tunnel_h: Dictionary,
		cells: Array[Vector2i], center: Vector2i, perp: Vector2i, w: int, h: int, margin: int) -> void:
	for cell: Vector2i in _band_cells(field, center, perp, w, margin):
		_open_cell(field, open, cell)
		if cell_chamber.has(cell):
			continue
		tunnel_h[cell] = maxi(int(tunnel_h.get(cell, 0)), h)
		if not cells.has(cell):
			cells.append(cell)


static func _band_cells(field: BattlefieldArea, center: Vector2i, perp: Vector2i, w: int, margin: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: int in _band_offsets(w):
		out.append(Vector2i(
			clampi(center.x + perp.x * p, margin, field.width - 1 - margin),
			clampi(center.y + perp.y * p, margin, field.length - 1 - margin)))
	return out


static func _band_offsets(w: int) -> Array[int]:
	var out: Array[int] = [0]
	if w == 2:
		out = [0, 1]
	elif w >= 3:
		out = [-1, 0, 1]
	return out


static func _open_cell(field: BattlefieldArea, open: Dictionary, cell: Vector2i) -> void:
	field.rock_cells.erase(cell)
	open[cell] = true


static func _carve_entrances(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary,
		tunnel_h: Dictionary, chambers: Array[Dictionary]) -> Array[Dictionary]:
	var count: int = WeightedTable.pick_index(ENTRANCE_WEIGHTS) + 1
	var sides: Array[int] = [0, 1, 2, 3]
	sides.shuffle()
	var entrances: Array[Dictionary] = []
	for i: int in range(count):
		var side: int = sides[i]
		var ci: int = _chamber_nearest_side(field, chambers, side)
		var border: Vector2i = _border_cell(field, side)
		var w: int = WeightedTable.pick_index(WIDTH_WEIGHTS) + 1
		var h: int = WeightedTable.pick_index(HEIGHT_WEIGHTS) + 1
		var cells: Array[Vector2i] = []
		_carve(field, open, cell_chamber, tunnel_h, cells, _edge_cell(chambers[ci], border), border, w, h, 0)
		var along := Vector2i(1, 0) if side < 2 else Vector2i(0, 1)
		_stamp(field, open, cell_chamber, tunnel_h, cells, border, along, w, h, 0)
		var mouth: Array[Vector2i] = []
		for cell: Vector2i in _band_cells(field, border, along, w, 0):
			if not mouth.has(cell):
				mouth.append(cell)
		for cell: Vector2i in mouth:
			field.entrance_cells.append(cell)
		field.cavern_tunnels.append({"cells": cells, "width": w, "height": h,
			"from": ci, "to": -1, "kind": "entrance"})
		entrances.append({"cells": mouth, "chamber": ci, "level": randi_range(2, 5)})
		field.generation_log.append("[CAVERN] entrance %d side=%d chamber=%d mouth=%d width=%d height=%d" % [
			i + 1, side, ci + 1, mouth.size(), w, h])
	return entrances


#0 top, 1 bottom, 2 left, 3 right; the chamber whose center sits closest to that border line.
static func _chamber_nearest_side(field: BattlefieldArea, chambers: Array[Dictionary], side: int) -> int:
	var best: int = 0
	var best_d: int = 1 << 30
	for i: int in range(chambers.size()):
		var c: Vector2i = _chamber_center(chambers[i])
		var d: int = c.y
		if side == 1:
			d = field.length - 1 - c.y
		elif side == 2:
			d = c.x
		elif side == 3:
			d = field.width - 1 - c.x
		if d < best_d:
			best_d = d
			best = i
	return best


static func _border_cell(field: BattlefieldArea, side: int) -> Vector2i:
	if side == 0:
		return Vector2i(randi_range(3, field.width - 4), 0)
	if side == 1:
		return Vector2i(randi_range(3, field.width - 4), field.length - 1)
	if side == 2:
		return Vector2i(0, randi_range(3, field.length - 4))
	return Vector2i(field.width - 1, randi_range(3, field.length - 4))


static func _carve_dead_ends(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary,
		tunnel_h: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count: int = randi_range(0, 3)
	for _i: int in range(count):
		var start: Vector2i = _random_open_cell(open)
		var dir: Vector2i = PathCost.DIRS4[randi_range(0, 3)]
		var cells: Array[Vector2i] = []
		var carved: Dictionary = {start: true}
		var length: int = randi_range(3, 10)
		var pos := start
		var h: int = randi_range(1, 3)
		for s: int in range(length):
			if s > 0 and randf() < 0.25:
				dir = Vector2i(-dir.y, dir.x) if randf() < 0.5 else Vector2i(dir.y, -dir.x)
			var nxt: Vector2i = pos + dir
			if not _dead_end_free(field, open, carved, nxt, pos, s == 0):
				break
			_open_cell(field, open, nxt)
			carved[nxt] = true
			cells.append(nxt)
			if not cell_chamber.has(nxt):
				tunnel_h[nxt] = maxi(int(tunnel_h.get(nxt, 0)), h)
			pos = nxt
		if cells.is_empty():
			continue
		field.cavern_tunnels.append({"cells": cells, "width": 1, "height": h,
			"from": -1, "to": -1, "kind": "dead_end"})
		out.append({"cells": cells, "anchor": start})
		field.generation_log.append("[CAVERN] dead end from (%d,%d) length=%d height=%d" % [
			start.x, start.y, cells.size(), h])
	return out


#A dead end may only touch its own cells; the first step may also brush the cells around its anchor.
static func _dead_end_free(field: BattlefieldArea, open: Dictionary, carved: Dictionary,
		cell: Vector2i, prev: Vector2i, first: bool) -> bool:
	if cell.x < TUNNEL_MARGIN or cell.x >= field.width - TUNNEL_MARGIN:
		return false
	if cell.y < TUNNEL_MARGIN or cell.y >= field.length - TUNNEL_MARGIN:
		return false
	if open.has(cell):
		return false
	for d: Vector2i in PathCost.DIRS8:
		var nb: Vector2i = cell + d
		if not open.has(nb) or carved.has(nb):
			continue
		if first and maxi(absi(nb.x - prev.x), absi(nb.y - prev.y)) <= 1:
			continue
		return false
	return true


static func _random_open_cell(open: Dictionary) -> Vector2i:
	var keys: Array = open.keys()
	return keys[randi_range(0, keys.size() - 1)] as Vector2i


#Entrance and chamber levels first, then one height per open cell from the anchor distances.
static func _assign_levels(field: BattlefieldArea, open: Dictionary, chambers: Array[Dictionary],
		entrances: Array[Dictionary], dead_ends: Array[Dictionary]) -> void:
	if entrances.is_empty():
		return
	var top: float = 0.0
	for e: Dictionary in entrances:
		top = maxf(top, float(int(e["level"])))
	var anchors: Array[Dictionary] = []
	anchors.append({"dist": _bfs_dist(open, entrances[0]["cells"] as Array[Vector2i]), "level": float(int(entrances[0]["level"]))})
	for i: int in range(1, entrances.size()):
		var cells: Array[Vector2i] = entrances[i]["cells"] as Array[Vector2i]
		var span: Vector2 = _feasible(anchors, cells, top)
		anchors.append({"dist": _bfs_dist(open, cells), "level": span.y})
		entrances[i]["level"] = span.y
	var party: Dictionary = anchors[0]["dist"] as Dictionary
	var scores: Array[float] = []
	for i: int in range(chambers.size()):
		scores.append(_set_distance(party, chambers[i]["cells"] as Dictionary))
	var order: Array[int] = _order_by(scores, true)
	for i: int in order:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in (chambers[i]["cells"] as Dictionary).keys():
			cells.append(cell)
		var span: Vector2 = _feasible(anchors, cells, top)
		var steps: int = int(round((span.y - span.x) * 4.0))
		var level: float = span.x + 0.25 * float(randi_range(0, int(steps / 3.0)))
		anchors.append({"dist": _bfs_dist(open, cells), "level": level})
		chambers[i]["level"] = level
	for cell: Vector2i in open.keys():
		var h: float = INF
		for a: Dictionary in anchors:
			var dist: Dictionary = a["dist"] as Dictionary
			if not dist.has(cell):
				continue
			h = minf(h, float(a["level"]) + SLOPE * float(int(dist[cell])))
		if h == INF:
			h = 0.0
		field.terrain_heights[cell] = h
		field.ground_heights[cell] = h
	for de: Dictionary in dead_ends:
		var flat: float = field.get_terrain_height(de["anchor"] as Vector2i)
		for cell: Vector2i in (de["cells"] as Array[Vector2i]):
			field.terrain_heights[cell] = flat
			field.ground_heights[cell] = flat
	for i: int in range(chambers.size()):
		field.generation_log.append("[CAVERN] chamber %d level=%.2f" % [i + 1, float(chambers[i]["level"])])


#Lowest and highest level a new anchor may take without breaking the one-slope rule.
static func _feasible(anchors: Array[Dictionary], cells: Array[Vector2i], top: float) -> Vector2:
	var lo: float = 0.0
	var hi: float = top
	for a: Dictionary in anchors:
		var d: float = _list_distance(a["dist"] as Dictionary, cells)
		if d >= INF:
			continue
		lo = maxf(lo, float(a["level"]) - SLOPE * d)
		hi = minf(hi, float(a["level"]) + SLOPE * d)
	lo = ceilf(maxf(lo, 0.0) * 4.0) / 4.0
	hi = floorf(minf(hi, top) * 4.0) / 4.0
	if hi < lo:
		hi = lo
	return Vector2(lo, hi)


#Fewest steps from a distance map to any cell of the set; INF when none is reachable.
static func _list_distance(dist: Dictionary, cells: Array[Vector2i]) -> float:
	var best: float = INF
	for cell: Vector2i in cells:
		if dist.has(cell):
			best = minf(best, float(int(dist[cell])))
	return best


static func _set_distance(dist: Dictionary, cells: Dictionary) -> float:
	var list: Array[Vector2i] = []
	list.assign(cells.keys())
	return _list_distance(dist, list)


static func _bfs_dist(open: Dictionary, starts: Array[Vector2i]) -> Dictionary:
	var seeds: Array[Vector2i] = []
	for s: Vector2i in starts:
		if open.has(s):
			seeds.append(s)
	return _flood(seeds, PathCost.DIRS8, _in_set.bind(open))


static func _build_ceilings(field: BattlefieldArea, open: Dictionary, cell_chamber: Dictionary,
		tunnel_h: Dictionary, chambers: Array[Dictionary]) -> void:
	for cell: Vector2i in open.keys():
		if cell_chamber.has(cell):
			continue
		var h: int = maxi(1, int(tunnel_h.get(cell, 1)))
		field.cavern_ceiling[cell] = field.get_terrain_height(cell) + float(h)
	for i: int in range(chambers.size()):
		var ch: Dictionary = chambers[i]
		var cells: Dictionary = ch["cells"] as Dictionary
		var edge_c: int = 1
		for cell: Vector2i in cells.keys():
			for d: Vector2i in PathCost.DIRS8:
				var nb: Vector2i = cell + d
				if open.has(nb) and not cell_chamber.has(nb):
					edge_c = maxi(edge_c, int(tunnel_h.get(nb, 1)))
		var d_edge: Dictionary = _edge_distance(cells)
		var peak_size: int = randi_range(1, 3)
		var peak: Vector2i = _peak_anchor(cells, peak_size)
		var peak_cells: Dictionary = {}
		var peak_d: int = 1
		for dy: int in range(peak_size):
			for dx: int in range(peak_size):
				var pc := Vector2i(peak.x + dx, peak.y + dy)
				if not cells.has(pc):
					continue
				peak_cells[pc] = true
				peak_d = maxi(peak_d, int(d_edge.get(pc, 1)))
		var peak_c: int = randi_range(edge_c + 1, MAX_CLEARANCE)
		for cell: Vector2i in cells.keys():
			var c: float = float(peak_c)
			if not peak_cells.has(cell):
				var t: float = float(int(d_edge.get(cell, 1))) / float(maxi(1, peak_d))
				c = minf(float(peak_c), float(edge_c) + (float(peak_c) - float(edge_c)) * t)
				c = round(c * 4.0) / 4.0
			field.cavern_ceiling[cell] = field.get_terrain_height(cell) + c
		ch["peak"] = peak
		ch["peak_size"] = peak_size
		ch["peak_clearance"] = float(peak_c)
		ch["edge_clearance"] = float(edge_c)
		field.generation_log.append("[CAVERN] chamber %d peak=(%d,%d) size=%d clearance=%d edge=%d" % [
			i + 1, peak.x, peak.y, peak_size, peak_c, edge_c])


#Chebyshev distance from each chamber cell to the nearest cell outside the chamber.
static func _edge_distance(cells: Dictionary) -> Dictionary:
	var rim: Array[Vector2i] = []
	for cell: Vector2i in cells.keys():
		for d: Vector2i in PathCost.DIRS8:
			if not cells.has(cell + d):
				rim.append(cell)
				break
	return _flood(rim, PathCost.DIRS8, _in_set.bind(cells), 1)


#Top-left cell of a peak block that lies wholly inside the chamber.
static func _peak_anchor(cells: Dictionary, size: int) -> Vector2i:
	var keys: Array = cells.keys()
	for _try: int in range(50):
		var cand: Vector2i = keys[randi_range(0, keys.size() - 1)] as Vector2i
		var fits: bool = true
		for dy: int in range(size):
			for dx: int in range(size):
				if not cells.has(Vector2i(cand.x + dx, cand.y + dy)):
					fits = false
					break
			if not fits:
				break
		if fits:
			return cand
	return keys[randi_range(0, keys.size() - 1)] as Vector2i


static func _flood_chambers(field: BattlefieldArea, open: Dictionary, chambers: Array[Dictionary],
		entrances: Array[Dictionary]) -> void:
	if chambers.size() < 2:
		return
	var dry_near: Dictionary = {}
	for cell: Vector2i in field.entrance_cells:
		for dy: int in range(-ENTRANCE_DRY_RANGE, ENTRANCE_DRY_RANGE + 1):
			for dx: int in range(-ENTRANCE_DRY_RANGE, ENTRANCE_DRY_RANGE + 1):
				dry_near[Vector2i(cell.x + dx, cell.y + dy)] = true
	var party: int = int(entrances[0]["chamber"])
	var max_pools: int = int(ceil(float(chambers.size()) / 2.0))
	var pools: int = 0
	for i: int in range(chambers.size()):
		if i == party or pools >= max_pools:
			continue
		if randi_range(1, 100) > 25:
			continue
		var pool: Array[Vector2i] = _grow_pool(field, open, chambers[i], dry_near)
		if pool.is_empty():
			continue
		var depth: int = WeightedTable.pick_index(DEPTH_WEIGHTS) + 1
		var surface: float = float(chambers[i]["level"])
		for cell: Vector2i in pool:
			var clear: float = float(field.cavern_ceiling[cell]) - field.get_terrain_height(cell)
			field.water_cells[cell] = depth
			field.terrain_heights[cell] = surface - float(depth)
			field.ground_heights[cell] = surface - float(depth)
			field.cavern_ceiling[cell] = surface + clear
		chambers[i]["flooded"] = true
		chambers[i]["depth"] = depth
		chambers[i]["surface"] = surface
		chambers[i]["name"] = "Flooded Chamber %d" % (i + 1)
		pools += 1
		field.generation_log.append("[CAVERN] pool in chamber %d cells=%d depth=%d surface=%.2f floor=%.2f" % [
			i + 1, pool.size(), depth, surface, surface - float(depth)])


#Grows a pool over the chamber, spilling at most two cells into the tunnels that meet it.
static func _grow_pool(field: BattlefieldArea, open: Dictionary, ch: Dictionary,
		dry_near: Dictionary) -> Array[Vector2i]:
	var cells: Dictionary = ch["cells"] as Dictionary
	var allowed: Dictionary = _spill_zone(open, cells)
	for cell: Vector2i in dry_near.keys():
		allowed.erase(cell)
	var level: float = float(ch.get("level", 0.0))
	for cell: Vector2i in allowed.keys().duplicate():
		if not _holds_water(field, open, cell, level):
			allowed.erase(cell)
	var seeds: Array[Vector2i] = []
	for cell: Vector2i in cells.keys():
		if allowed.has(cell):
			seeds.append(cell)
	var empty: Array[Vector2i] = []
	if seeds.is_empty():
		return empty
	var target: int = maxi(1, int(round(float(cells.size()) * float(randi_range(40, 100)) / 100.0)))
	var pool: Array[Vector2i] = [seeds[randi_range(0, seeds.size() - 1)]]
	var in_pool: Dictionary = {pool[0]: true}
	while pool.size() < target:
		var cand: Array[Vector2i] = []
		for cell: Vector2i in pool:
			for d: Vector2i in PathCost.DIRS4:
				var nb: Vector2i = cell + d
				if allowed.has(nb) and not in_pool.has(nb) and not cand.has(nb):
					cand.append(nb)
		if cand.is_empty():
			break
		var pick: Vector2i = cand[randi_range(0, cand.size() - 1)]
		pool.append(pick)
		in_pool[pick] = true
	while pool.size() > 1 and not _has_rim(open, in_pool):
		in_pool.erase(pool[pool.size() - 1])
		pool.remove_at(pool.size() - 1)
	return pool


#True when water at `level` covers cell and stays: the cell lies at that level and no open neighbour lies under it.
static func _holds_water(field: BattlefieldArea, open: Dictionary, cell: Vector2i, level: float) -> bool:
	if absf(field.get_terrain_height(cell) - level) > EPS:
		return false
	for d: Vector2i in PathCost.DIRS8:
		var nb: Vector2i = cell + d
		if open.has(nb) and field.get_terrain_height(nb) < level - EPS:
			return false
	return true


#True when at least one open cell beside the pool stays dry.
static func _has_rim(open: Dictionary, in_pool: Dictionary) -> bool:
	for cell: Vector2i in in_pool.keys():
		for d: Vector2i in PathCost.DIRS4:
			var nb: Vector2i = cell + d
			if open.has(nb) and not in_pool.has(nb):
				return true
	return false


static func _build_rock_shell(field: BattlefieldArea, open: Dictionary) -> void:
	var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
	var walls: int = 0
	for cell: Vector2i in field.rock_cells.keys():
		if not _touches_open(open, cell):
			field.jagged_cells[cell] = true
			continue
		var obs := {"pos": cell, "size": 1, "data": wall_data, "floor": 0,
			"cell_type": "wall", "orientation": "v"}
		field.add_obstacle(obs, field.obs_key(cell, 0))
		walls += 1
	field.generation_log.append("[CAVERN] rock shell: %d wall(s), %d solid cell(s)" % [walls, field.jagged_cells.size()])


static func _place_spawns(field: BattlefieldArea, open: Dictionary, chambers: Array[Dictionary],
		entrances: Array[Dictionary], ctx: GenerationContext) -> void:
	field.spawn_radius = 3.0
	if entrances.is_empty():
		return
	var mouth: Array[Vector2i] = entrances[0]["cells"] as Array[Vector2i]
	var mid: Vector2i = mouth[mouth.size() >> 1]
	field.spawn_center_a = _inward_cell(field, open, mid)
	field.spawn_zone_a = _spawn_zone_a(field, open, mouth, maxi(ctx.team_size_a, 4) + 2)
	var dist: Dictionary = _bfs_dist(open, mouth)
	var scores: Array[float] = []
	for i: int in range(chambers.size()):
		scores.append(_set_distance(dist, chambers[i]["cells"] as Dictionary))
	var order: Array[int] = _order_by(scores, false)
	var need: int = ctx.team_size_b + 2
	var chosen: int = order[0]
	for i: int in order:
		if _dry_cells(field, chambers[i]).size() >= need:
			chosen = i
			break
	var dry: Array[Vector2i] = _dry_cells(field, chambers[chosen])
	var zone: Dictionary = {}
	for cell: Vector2i in dry:
		zone[cell] = true
	field.spawn_zone_b = zone
	field.spawn_center_b = _chamber_center(chambers[chosen])
	if not zone.has(field.spawn_center_b) and not dry.is_empty():
		field.spawn_center_b = _nearest(dry, field.spawn_center_b)
	field.generation_log.append("[CAVERN] spawns: A=(%d,%d) zone=%d  B=(%d,%d) chamber %d zone=%d" % [
		field.spawn_center_a.x, field.spawn_center_a.y, field.spawn_zone_a.size(),
		field.spawn_center_b.x, field.spawn_center_b.y, chosen + 1, field.spawn_zone_b.size()])


#The open cell one step in from an entrance mouth; the mouth cell itself when nothing lies inside.
static func _inward_cell(field: BattlefieldArea, open: Dictionary, mouth: Vector2i) -> Vector2i:
	for d: Vector2i in PathCost.DIRS8:
		var nb: Vector2i = mouth + d
		if not open.has(nb) or field.is_water(nb):
			continue
		if nb.x == 0 or nb.y == 0 or nb.x == field.width - 1 or nb.y == field.length - 1:
			continue
		if field.clearance(nb) < 1.0 - EPS:
			continue
		return nb
	return mouth


static func _spawn_zone_a(field: BattlefieldArea, open: Dictionary, mouth: Array[Vector2i], want: int) -> Dictionary:
	return _flood(mouth, PathCost.DIRS8, _dry_open_step.bind(field, open), 0, -1, want)


static func _dry_open_step(_from: Vector2i, cell: Vector2i, field: BattlefieldArea, open: Dictionary) -> bool:
	return open.has(cell) and not field.is_water(cell) and field.clearance(cell) >= 1.0 - EPS


static func _dry_cells(field: BattlefieldArea, ch: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in (ch["cells"] as Dictionary).keys():
		if not field.is_water(cell) and field.clearance(cell) >= 1.0 - EPS:
			out.append(cell)
	return out


static func _nearest(cells: Array[Vector2i], to: Vector2i) -> Vector2i:
	var best: Vector2i = cells[0]
	var best_d: int = 1 << 30
	for cell: Vector2i in cells:
		var d: int = maxi(absi(cell.x - to.x), absi(cell.y - to.y))
		if d < best_d:
			best_d = d
			best = cell
	return best


#Indices of scores sorted by value, nearest first when ascending.
static func _order_by(scores: Array[float], ascending: bool) -> Array[int]:
	var order: Array[int] = []
	for i: int in range(scores.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] == scores[b]:
			return a < b
		return scores[a] < scores[b] if ascending else scores[a] > scores[b])
	return order


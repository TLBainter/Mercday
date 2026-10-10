class_name RoofBuilder
extends RefCounted

#One roof level above the top floor of every footprint cell: parts, shapes, cell types and rises.
#Writes only the roof tables of BattlefieldArea and never rolls a die.

const FLAT := 0
const SLOPE := 1
const PEAK := 2
const SOLID := 3
const PITCH := 0.25
const SHAPES: Array[String] = ["Flat", "Hip", "Gable", "Lean-to", "Awning", "Battlement", "Steeple", "Dome", "Clock Tower"]
const ROOF_ROWS: Array[String] = ["Parapet", "Merlon", "Chimney", "Large Chimney", "Dormer"]
const GLYPHS := "_/^X"            #index = cell type
const AWNING_LO := 2.5            #above floor 0
const AWNING_HI := 2.75
const STEEPLE_H := 8.0            #block height above the roof plane
const CLOCK_H := 6.0
const TOWER_SIDE := 3
const DOME_MIN_R := 2.0
const DOME_MAX_R := 5.0

const DIRS4: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const DIRS8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const TYPE_NAMES: Array[String] = ["flat", "slope", "peak", "solid"]

static var enabled: bool = true


#Roof shape of one Buildings.tsv area row; an unknown or missing cell is Flat.
static func shape_of(area_data: Dictionary) -> String:
	if not area_data.has("building"):
		return "Flat"
	var b: Dictionary = area_data["building"] as Dictionary
	var name: String = String(b.get("roof", ""))
	return name if SHAPES.has(name) else "Flat"


#Builds the whole roof level of a generated building; call it once, after the masks are final.
static func build(area: BattlefieldArea, shape: String, front: String) -> void:
	if not enabled or area == null or not area.is_interior_map:
		return
	area.roof_cells.clear()
	area.roof_rise.clear()
	area.rugged_cells.clear()
	area.roof_parts.clear()
	area.roof_elevations.clear()
	area.roof_span.clear()
	area.invalidate_roof_levels()
	var tops: Dictionary = _tops_of(area)
	if tops.is_empty():
		return
	var build_shape: String = shape if SHAPES.has(shape) else "Flat"
	var sets: Array = []
	var parts: Array[Dictionary] = _parts_of(tops, sets)
	if parts.is_empty():
		return
	var main_id: int = main_part(parts)
	for i: int in range(parts.size()):
		var part: Dictionary = parts[i]
		var cells: Dictionary = sets[i] as Dictionary
		_shape_part(part, cells, tops, build_shape, front, i == main_id)
		_fill_part(area, part, cells)
	if main_id >= 0:
		_unique_block(area, parts[main_id], sets[main_id] as Dictionary, front)
	for done: Dictionary in parts:
		done["max_rise"] = _max_rise(area, done)
		area.roof_parts.append(done)
	rebuild_index(area)


#Rewrites roof_elevations and roof_span from the parts; the plane of a cell is its top floor plus one storey.
static func rebuild_index(area: BattlefieldArea) -> void:
	if area == null:
		return
	area.roof_elevations.clear()
	area.roof_span.clear()
	for part: Dictionary in area.roof_parts:
		var level: int = int(part["level"])
		var base: float = float(part["base"])
		for cell: Vector2i in (part["cells"] as Array):
			var fh_c: int = area.interior_floor_height
			var bid: int = int(area.building_id_at.get(cell, -1))
			if bid >= 0 and bid < area.buildings.size():
				fh_c = int((area.buildings[bid] as Dictionary).get("fh", fh_c))
			var plane: int = roundi(area.floor_elevation_at(cell, level - 1)) + fh_c
			area.roof_elevations[cell] = plane
			var key := Vector3i(cell.x, cell.y, level)
			var rise: float = float(area.roof_rise.get(key, 0.0))
			var lo: float = float(plane) + base
			var hi: float = float(plane) + rise
			area.roof_span[cell] = Vector2(minf(lo, hi), maxf(lo, hi))


#One flat standable roof over an outdoor hut at level 1; the generator calls it once per accepted hut.
static func add_hut_roof(area: BattlefieldArea, rect: Rect2i, wall_height: float) -> void:
	if not enabled or area == null or area.is_interior_map:
		return
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var plane: int = roundi(area.get_terrain_height(rect.position) + wall_height)
	var cells: Array[Vector2i] = []
	var steps := PackedInt32Array()
	steps.resize(rect.size.x * rect.size.y)
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			cells.append(cell)
			steps[_di(rect, cell)] = 1
			var key := Vector3i(x, y, 1)
			area.roof_cells[key] = FLAT
			area.roof_rise[key] = 0.0
			area.roof_elevations[cell] = plane
			area.roof_span[cell] = Vector2(float(plane), float(plane))
	area.roof_parts.append(_new_part(area.roof_parts.size(), area.building_data.size() - 1, 1, rect, cells, steps))
	area.invalidate_roof_levels()


#A flat roof part record; later passes set the shape, kind and steps.
static func _new_part(id: int, building: int, level: int, rect: Rect2i, cells: Array[Vector2i],
		d: PackedInt32Array) -> Dictionary:
	return {
		"id": id,
		"building": building,
		"level": level,
		"shape": "Flat",
		"kind": "flat",
		"rect": rect,
		"cells": cells,
		"d": d,
		"axis": "",
		"high": "",
		"base": 0.0,
		"max_rise": 0.0,
	}


#Copies a scratch building's roof into a city map at offset; the map index is rebuilt by finish().
static func copy_to(scratch: BattlefieldArea, map: BattlefieldArea, offset: Vector2i, bid: int) -> void:
	if not enabled or scratch == null or map == null:
		return
	for ck: Variant in scratch.roof_cells.keys():
		map.roof_cells[BuildingStamp._shift(ck, offset)] = int(scratch.roof_cells[ck])
	for rk: Variant in scratch.roof_rise.keys():
		map.roof_rise[BuildingStamp._shift(rk, offset)] = float(scratch.roof_rise[rk])
	for gk: Variant in scratch.rugged_cells.keys():
		map.rugged_cells[BuildingStamp._shift(gk, offset)] = true
	for part: Dictionary in scratch.roof_parts:
		var copy: Dictionary = part.duplicate(true)
		copy["id"] = map.roof_parts.size()
		copy["building"] = bid
		var rect: Rect2i = part["rect"] as Rect2i
		copy["rect"] = Rect2i(rect.position + offset, rect.size)
		var cells: Array[Vector2i] = []
		for cell: Vector2i in (part["cells"] as Array):
			cells.append(cell + offset)
		copy["cells"] = cells
		if copy.has("dome"):
			var dome: Dictionary = copy["dome"] as Dictionary
			dome["cx"] = float(dome.get("cx", 0.0)) + float(offset.x)
			dome["cy"] = float(dome.get("cy", 0.0)) + float(offset.y)
		map.roof_parts.append(copy)
	map.invalidate_roof_levels()


#Height of every part vertex above the roof plane, row major, (w + 1) * (h + 1) entries.
static func vertex_heights(part: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var w: int = rect.size.x
	var h: int = rect.size.y
	if w <= 0 or h <= 0:
		return out
	out.resize((w + 1) * (h + 1))
	var kind: String = String(part.get("kind", "flat"))
	if kind == "dome":
		return out
	var axis: String = String(part.get("axis", ""))
	var high: String = String(part.get("high", ""))
	var d: PackedInt32Array = part.get("d", PackedInt32Array()) as PackedInt32Array
	for vy: int in range(h + 1):
		for vx: int in range(w + 1):
			var val: float = 0.0
			if kind == "hip":
				val = PITCH * float(_vertex_d(d, w, h, vx, vy))
			elif kind == "gable":
				val = PITCH * float(mini(vx, w - vx) if axis == "y" else mini(vy, h - vy))
			elif kind == "lean":
				if high == "n":
					val = PITCH * float(h - vy)
				elif high == "s":
					val = PITCH * float(vy)
				elif high == "w":
					val = PITCH * float(w - vx)
				elif high == "e":
					val = PITCH * float(vx)
			out[vy * (w + 1) + vx] = val
	return out


#Roof level over xy, -1 when the cell carries no roof. A reader for the dump, the viewer and the tests.
static func level_at(area: BattlefieldArea, xy: Vector2i) -> int:
	if area == null:
		return -1
	for lv: int in range(1, 12):
		if area.roof_cells.has(Vector3i(xy.x, xy.y, lv)):
			return lv
	return -1


#Cell types of one part tallied by name.
static func counts(area: BattlefieldArea, part: Dictionary) -> Dictionary:
	var out: Dictionary = {"flat": 0, "slope": 0, "peak": 0, "solid": 0}
	if area == null:
		return out
	var level: int = int(part.get("level", 0))
	for cell: Vector2i in (part.get("cells", []) as Array):
		var t: int = int(area.roof_cells.get(Vector3i(cell.x, cell.y, level), -1))
		if t >= 0 and t < TYPE_NAMES.size():
			out[TYPE_NAMES[t]] = int(out[TYPE_NAMES[t]]) + 1
	return out


#Highest floor per footprint cell; a cell whose highest floor is a basement gets no roof.
static func _tops_of(area: BattlefieldArea) -> Dictionary:
	var tops: Dictionary = {}
	for k: Variant in area.footprint_cells.keys():
		var c: Vector3i = k as Vector3i
		var xy := Vector2i(c.x, c.y)
		if not tops.has(xy) or c.z > int(tops[xy]):
			tops[xy] = c.z
	for tk: Variant in tops.keys():
		if int(tops[tk]) < 0:
			tops.erase(tk)
	return tops


#One part per connected run of equal top floor; sets_out takes the cell set of each part.
static func _parts_of(tops: Dictionary, sets_out: Array) -> Array[Dictionary]:
	var before := func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	var order: Array[Vector2i] = []
	for tk: Variant in tops.keys():
		order.append(tk as Vector2i)
	order.sort_custom(before)
	var parts: Array[Dictionary] = []
	var seen: Dictionary = {}
	for start: Vector2i in order:
		if seen.has(start):
			continue
		var top: int = int(tops[start])
		var cells: Dictionary = {}
		var queue: Array[Vector2i] = [start]
		cells[start] = true
		seen[start] = true
		var head: int = 0
		while head < queue.size():
			var cur: Vector2i = queue[head]
			head += 1
			for dir: Vector2i in DIRS4:
				var n: Vector2i = cur + dir
				if seen.has(n) or not tops.has(n) or int(tops[n]) != top:
					continue
				seen[n] = true
				cells[n] = true
				queue.append(n)
		var list: Array[Vector2i] = []
		for ck: Variant in cells.keys():
			list.append(ck as Vector2i)
		list.sort_custom(before)
		parts.append(_new_part(parts.size(), -1, top + 1, _rect_of(list), list, PackedInt32Array()))
		sets_out.append(cells)
	return parts


#Index of the part that carries the building shape: the highest, then the largest, then the first.
static func main_part(parts: Array[Dictionary]) -> int:
	var best: int = -1
	for i: int in range(parts.size()):
		if best < 0:
			best = i
			continue
		var a: Dictionary = parts[i]
		var b: Dictionary = parts[best]
		var al: int = int(a["level"])
		var bl: int = int(b["level"])
		if al > bl or (al == bl and (a["cells"] as Array).size() > (b["cells"] as Array).size()):
			best = i
	return best


#Shape, kind, ridge axis and high side of one part.
static func _shape_part(part: Dictionary, cells: Dictionary, tops: Dictionary, build_shape: String,
		front: String, is_main: bool) -> void:
	if build_shape == "Awning":
		part["shape"] = "Awning"
		part["kind"] = "awning"
		return
	#A dome is the whole roof, so every part domes and the lean-to fallback never takes a wing.
	if build_shape == "Dome":
		part["shape"] = "Dome"
		part["kind"] = "dome"
		return
	var high: String = _high_side(part, cells, tops)
	if high != "":
		part["shape"] = "Lean-to"
		part["kind"] = "lean"
		part["high"] = high
		return
	var shape: String = build_shape if is_main else _base_shape(build_shape)
	var kind: String = _kind_of(shape)
	part["shape"] = shape
	part["kind"] = kind
	if kind == "lean":
		part["high"] = _front_letter(front)
	elif kind == "gable":
		var rect: Rect2i = part["rect"] as Rect2i
		if (part["cells"] as Array).size() != rect.size.x * rect.size.y:
			part["kind"] = "hip"
		else:
			part["axis"] = _gable_axis(rect, front)


#Side of the part that leans against a taller wall over at least half its length; "" when none does.
static func _high_side(part: Dictionary, cells: Dictionary, tops: Dictionary) -> String:
	var rect: Rect2i = part["rect"] as Rect2i
	var level: int = int(part["level"])
	var tally: Dictionary = {"n": 0, "s": 0, "w": 0, "e": 0}
	for x: int in range(rect.position.x, rect.end.x):
		tally["n"] = int(tally["n"]) + _leans(cells, tops, level, Vector2i(x, rect.position.y), Vector2i(0, -1))
		tally["s"] = int(tally["s"]) + _leans(cells, tops, level, Vector2i(x, rect.end.y - 1), Vector2i(0, 1))
	for y: int in range(rect.position.y, rect.end.y):
		tally["w"] = int(tally["w"]) + _leans(cells, tops, level, Vector2i(rect.position.x, y), Vector2i(-1, 0))
		tally["e"] = int(tally["e"]) + _leans(cells, tops, level, Vector2i(rect.end.x - 1, y), Vector2i(1, 0))
	var best: String = ""
	var best_count: int = 0
	for side: String in ["n", "s", "w", "e"]:
		var span: int = rect.size.x if side == "n" or side == "s" else rect.size.y
		var count: int = int(tally[side])
		if count * 2 < span or count <= best_count:
			continue
		best = side
		best_count = count
	return best


#1 when the part owns cell and the neighbour beyond it belongs to a taller part.
static func _leans(cells: Dictionary, tops: Dictionary, level: int, cell: Vector2i, step: Vector2i) -> int:
	if not cells.has(cell):
		return 0
	return 1 if int(tops.get(cell + step, -99)) >= level else 0


#Shape a part other than the main one takes when the building carries a unique shape.
static func _base_shape(shape: String) -> String:
	if shape == "Steeple":
		return "Gable"
	if shape == "Clock Tower":
		return "Hip"
	if shape == "Battlement":
		return "Flat"
	return shape


#Index of a cell in the part step array, which runs row by row over the rect.
static func _di(rect: Rect2i, cell: Vector2i) -> int:
	return (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)


#Height rule behind a shape name.
static func _kind_of(shape: String) -> String:
	if shape == "Hip" or shape == "Clock Tower":
		return "hip"
	if shape == "Dome":
		return "dome"
	if shape == "Gable" or shape == "Steeple":
		return "gable"
	if shape == "Lean-to":
		return "lean"
	if shape == "Awning":
		return "awning"
	return "flat"


#Front side of the building as a map letter; an unset front counts as the low y side.
static func _front_letter(front: String) -> String:
	var f: String = front.to_lower()
	return f if ["n", "s", "w", "e"].has(f) else "n"


#Ridge axis of a gable: along the longer side, or along the front side on a square part.
static func _gable_axis(rect: Rect2i, front: String) -> String:
	if rect.size.x > rect.size.y:
		return "x"
	if rect.size.y > rect.size.x:
		return "y"
	var f: String = _front_letter(front)
	return "y" if f == "w" or f == "e" else "x"


#Writes the step counts, cell types and rises of one part.
static func _fill_part(area: BattlefieldArea, part: Dictionary, cells: Dictionary) -> void:
	var kind: String = String(part["kind"])
	var rect: Rect2i = part["rect"] as Rect2i
	var w: int = rect.size.x
	var list: Array = part["cells"] as Array
	var d := PackedInt32Array()
	d.resize(w * rect.size.y)
	if kind == "hip":
		_hip_d(part, cells, d)
	elif kind == "gable":
		_gable_d(part, d)
	elif kind == "lean":
		_lean_d(part, d)
	else:
		for cell: Vector2i in list:
			d[_di(rect, cell)] = 1
	part["d"] = d
	if kind == "dome":
		_fill_dome(area, part)
		return
	if kind == "awning":
		part["base"] = AWNING_LO - float(area.interior_floor_height)
	var max_d: int = 0
	for cell2: Vector2i in list:
		max_d = maxi(max_d, d[_di(rect, cell2)])
	var level: int = int(part["level"])
	for cell3: Vector2i in list:
		var dv: int = d[_di(rect, cell3)]
		var t: int = FLAT
		var rise: float = 0.0
		if kind == "awning":
			t = SOLID
			rise = AWNING_HI - float(area.interior_floor_height)
		elif kind == "hip":
			t = PEAK if _is_hip_peak(cells, d, rect, cell3, dv) else SLOPE
			rise = PITCH * float(dv)
		elif kind == "gable" or kind == "lean":
			t = PEAK if dv == max_d else SLOPE
			rise = PITCH * float(dv)
		var key := Vector3i(cell3.x, cell3.y, level)
		area.roof_cells[key] = t
		area.roof_rise[key] = rise
		if t == SLOPE:
			area.rugged_cells[key] = true


#Smooth elliptical dome over the whole rect: a flat crown of x Paces, solid shell around it, no rugged cell.
static func _fill_dome(area: BattlefieldArea, part: Dictionary) -> void:
	var rect: Rect2i = part["rect"] as Rect2i
	var w: int = rect.size.x
	var dep: int = rect.size.y
	if w <= 0 or dep <= 0:
		return
	var cx: float = float(rect.position.x) + float(w) * 0.5
	var cy: float = float(rect.position.y) + float(dep) * 0.5
	var a: float = float(w) * 0.5
	var b: float = float(dep) * 0.5
	var h: float = clampf(float(mini(w, dep)) / 2.0, DOME_MIN_R, DOME_MAX_R)
	var crown: int = clampi(int(mini(w, dep) / 4.0), 1, 5)
	var r_min: float = minf(a, b)
	var plateau: float = h * sqrt(maxf(0.0, 1.0 - pow(float(crown) / r_min, 2)))
	part["dome"] = {"cx": cx, "cy": cy, "a": a, "b": b, "h": h, "crown": crown, "plateau": plateau}
	var level: int = int(part["level"])
	for cell: Vector2i in (part["cells"] as Array):
		var ux: float = (float(cell.x) + 0.5 - cx) / a
		var uy: float = (float(cell.y) + 0.5 - cy) / b
		var u: float = sqrt(ux * ux + uy * uy)
		var key := Vector3i(cell.x, cell.y, level)
		if u * r_min <= float(crown):
			area.roof_cells[key] = FLAT
			area.roof_rise[key] = plateau
		else:
			area.roof_cells[key] = SOLID
			area.roof_rise[key] = maxf(0.04, h * sqrt(maxf(0.0, 1.0 - u * u)))
		area.rugged_cells.erase(key)


#Rings inward over the 8 neighbours: 1 on the outline, one more per ring.
static func _hip_d(part: Dictionary, cells: Dictionary, d: PackedInt32Array) -> void:
	var rect: Rect2i = part["rect"] as Rect2i
	var queue: Array[Vector2i] = []
	for cell: Vector2i in (part["cells"] as Array):
		if not _on_outline(cells, cell):
			continue
		d[_di(rect, cell)] = 1
		queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var cd: int = d[_di(rect, cur)]
		for dir: Vector2i in DIRS8:
			var n: Vector2i = cur + dir
			if not cells.has(n):
				continue
			var ni: int = _di(rect, n)
			if d[ni] != 0:
				continue
			d[ni] = cd + 1
			queue.append(n)


static func _on_outline(cells: Dictionary, cell: Vector2i) -> bool:
	for dir: Vector2i in DIRS8:
		if not cells.has(cell + dir):
			return true
	return false


#A hip cell is the peak of its run when no cardinal neighbour of the part climbs higher.
static func _is_hip_peak(cells: Dictionary, d: PackedInt32Array, rect: Rect2i, cell: Vector2i, dv: int) -> bool:
	for dir: Vector2i in DIRS4:
		var n: Vector2i = cell + dir
		if not cells.has(n):
			continue
		if d[_di(rect, n)] > dv:
			return false
	return true


#Distance to the nearer of the two eave lines, one step per cell.
static func _gable_d(part: Dictionary, d: PackedInt32Array) -> void:
	var rect: Rect2i = part["rect"] as Rect2i
	var axis: String = String(part["axis"])
	for cell: Vector2i in (part["cells"] as Array):
		var dv: int = mini(cell.y - rect.position.y, rect.end.y - 1 - cell.y) + 1
		if axis == "y":
			dv = mini(cell.x - rect.position.x, rect.end.x - 1 - cell.x) + 1
		d[_di(rect, cell)] = dv


#Distance from the low edge, one step per cell; the high side ends at the part maximum.
static func _lean_d(part: Dictionary, d: PackedInt32Array) -> void:
	var rect: Rect2i = part["rect"] as Rect2i
	var high: String = String(part["high"])
	for cell: Vector2i in (part["cells"] as Array):
		var dv: int = rect.end.y - cell.y
		if high == "s":
			dv = cell.y - rect.position.y + 1
		elif high == "w":
			dv = rect.end.x - cell.x
		elif high == "e":
			dv = cell.x - rect.position.x + 1
		d[_di(rect, cell)] = dv


#Steeple or clock tower block over the main part; every other shape keeps its fill.
static func _unique_block(area: BattlefieldArea, part: Dictionary, cells: Dictionary, front: String) -> void:
	var shape: String = String(part["shape"])
	if shape == "Steeple":
		_tower_block(area, part, cells, front, STEEPLE_H)
	elif shape == "Clock Tower":
		_tower_block(area, part, cells, front, CLOCK_H)


#Square tower against the front edge, stepped inward until it fits; no block when no position does.
static func _tower_block(area: BattlefieldArea, part: Dictionary, cells: Dictionary, front: String,
		height: float) -> void:
	var rect: Rect2i = part["rect"] as Rect2i
	if rect.size.x < TOWER_SIDE or rect.size.y < TOWER_SIDE:
		return
	var f: String = _front_letter(front)
	var half: int = int(TOWER_SIDE / 2.0)
	var cx: int = rect.position.x + int(rect.size.x / 2.0)
	var cy: int = rect.position.y + int(rect.size.y / 2.0)
	var at := Vector2i(rect.position.x, cy - half)
	var step := Vector2i(1, 0)
	if f == "n":
		at = Vector2i(cx - half, rect.position.y)
		step = Vector2i(0, 1)
	elif f == "s":
		at = Vector2i(cx - half, rect.end.y - TOWER_SIDE)
		step = Vector2i(0, -1)
	elif f == "e":
		at = Vector2i(rect.end.x - TOWER_SIDE, cy - half)
		step = Vector2i(-1, 0)
	for move: int in range(5):
		var block := Rect2i(at + step * move, Vector2i(TOWER_SIDE, TOWER_SIDE))
		if not _block_fits(cells, block):
			continue
		_solid_block(area, part, block, height)
		return


static func _block_fits(cells: Dictionary, block: Rect2i) -> bool:
	for x: int in range(block.position.x, block.end.x):
		for y: int in range(block.position.y, block.end.y):
			if not cells.has(Vector2i(x, y)):
				return false
	return true


#Turns a rect of part cells into solid roof of one height; the step counts stay as they were.
static func _solid_block(area: BattlefieldArea, part: Dictionary, block: Rect2i, height: float) -> void:
	var level: int = int(part["level"])
	for x: int in range(block.position.x, block.end.x):
		for y: int in range(block.position.y, block.end.y):
			var key := Vector3i(x, y, level)
			area.roof_cells[key] = SOLID
			area.roof_rise[key] = height
			area.rugged_cells.erase(key)


static func _max_rise(area: BattlefieldArea, part: Dictionary) -> float:
	var level: int = int(part["level"])
	var cells: Array = part["cells"] as Array
	if cells.is_empty():
		return 0.0
	var out: float = -INF
	for cell: Vector2i in cells:
		out = maxf(out, float(area.roof_rise.get(Vector3i(cell.x, cell.y, level), 0.0)))
	return out


#Lowest step count of the four cells that share a vertex; a cell off the rect counts as 0.
static func _vertex_d(d: PackedInt32Array, w: int, h: int, vx: int, vy: int) -> int:
	var lo: int = 1 << 30
	for oy: int in [vy - 1, vy]:
		for ox: int in [vx - 1, vx]:
			var dv: int = 0
			if ox >= 0 and ox < w and oy >= 0 and oy < h:
				dv = d[oy * w + ox]
			lo = mini(lo, dv)
	return lo


static func _rect_of(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for cell: Vector2i in cells:
		lo.x = mini(lo.x, cell.x)
		lo.y = mini(lo.y, cell.y)
		hi.x = maxi(hi.x, cell.x)
		hi.y = maxi(hi.y, cell.y)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

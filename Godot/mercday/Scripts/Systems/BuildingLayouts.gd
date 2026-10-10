class_name BuildingLayouts
extends RefCounted

#Floor plans of a planned building: the Open, Shop and Hall layouts, the street doors and the room labels.
#Every layout is built in front axis terms: t runs along the front wall, s runs away from it.

const WALL_SZ := 4


#World cell of the front axis pair (t, s); t is absolute, s counts away from the front wall.
static func cell(geo: FloorGeo, t: int, s: int) -> Vector2i:
	var front: String = geo.front
	if front == "E":
		return Vector2i(geo.ux1 - s, t)
	if front == "N":
		return Vector2i(t, geo.iy0 + s)
	if front == "S":
		return Vector2i(t, geo.iy1 - s)
	return Vector2i(geo.ux0 + s, t)


static func rect_of(geo: FloorGeo, t_lo: int, t_hi: int, s_lo: int, s_hi: int) -> Rect2i:
	var a: Vector2i = cell(geo, t_lo, s_lo)
	var b: Vector2i = cell(geo, t_hi, s_hi)
	return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)


#Orientation of a wall that runs along t, and of one that runs along s.
static func _orient_t(geo: FloorGeo) -> String:
	return _wall_orient(geo.front)


static func _orient_s(geo: FloorGeo) -> String:
	return _cross_orient(geo.front)


static func _front_we(geo: FloorGeo) -> bool:
	var front: String = geo.front
	return front == "W" or front == "E"


#Wall obstacles on every empty cell of one straight line; the cells leave the interior set.
static func _wall_line(area: BattlefieldArea, f: int, from: Vector2i, to: Vector2i,
		wall_data: ObstacleData, fh: int) -> void:
	for x: int in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y: int in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			var p3 := Vector3i(x, y, f)
			InteriorGenerator.place_wall_if_empty(area, p3, WALL_SZ, wall_data, fh)
			area.building_interiors.erase(p3)


static func _door(area: BattlefieldArea, pos: Vector3i, fh: int, orientation: String) -> void:
	InteriorGenerator.place_door_at(area, pos, DataManager.door_data(), fh, orientation)


#One room record in the shape the partitioner uses, mirrored into the label list.
static func _record(area: BattlefieldArea, result: Array[Dictionary], room: ObstacleData,
		rect: Rect2i, f: int, is_main: bool) -> void:
	if room == null or rect.size.x < 2 or rect.size.y < 2:
		return
	var rec: Dictionary = {"room": room, "rect": rect, "floor": f}
	var label: Dictionary = {"rect": rect, "name": room.obstacle_name, "floor": f}
	if is_main:
		rec["main"] = true
		label["main"] = true
	result.append(rec)
	area.interior_rooms.append(label)


static func _is_top_room(room_name: String) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
	return d != null and d.room_type.ends_with("Top")


#Required rooms of the plan that fit floor f and have not been handed out yet.
static func _unused_required(plan: Dictionary, f: int, geo: FloorGeo) -> Array[String]:
	var out: Array[String] = []
	var used: Dictionary = geo.used
	var top: int = geo.top_floor
	for entry: Variant in (plan.get("required_rooms", []) as Array):
		var n: String = String(entry)
		if n == "" or used.has(n):
			continue
		if BuildingRules.room_fits_floor(n, f, top):
			out.append(n)
	return out


#Room for one slot: an unused required room first, then a random other room, then any fit, then main.
static func _pick_room(plan: Dictionary, f: int, geo: FloorGeo) -> ObstacleData:
	var used: Dictionary = geo.used
	var top: int = geo.top_floor
	var req: Array[String] = _unused_required(plan, f, geo)
	if not req.is_empty():
		var pick: String = req[0]
		#A room that cannot sit on floor 0 goes first, so an upper or lower floor does not spend its slot on a free room.
		if f != 0:
			for n0: String in req:
				if not BuildingRules.room_fits_floor(n0, 0, top):
					pick = n0
					break
		if top >= 1 and f == top:
			for n: String in req:
				if _is_top_room(n):
					pick = n
					break
		var d: ObstacleData = DataManager.get_obstacle_by_name(pick)
		if d != null:
			used[pick] = true
			return d
	var others: Array[String] = []
	for entry: Variant in (plan.get("other_rooms", []) as Array):
		var n2: String = String(entry)
		if n2 != "" and BuildingRules.room_fits_floor(n2, f, top):
			others.append(n2)
	if not others.is_empty():
		var n3: String = others[randi() % others.size()]
		var d2: ObstacleData = DataManager.get_obstacle_by_name(n3)
		if d2 != null:
			used[n3] = true
			return d2
	for entry2: Variant in (plan.get("required_rooms", []) as Array):
		var n4: String = String(entry2)
		if n4 == "" or not BuildingRules.room_fits_floor(n4, f, top):
			continue
		var d3: ObstacleData = DataManager.get_obstacle_by_name(n4)
		if d3 != null:
			used[n4] = true
			return d3
	return DataManager.get_obstacle_by_name(String(plan.get("main_room", "")))


#The room a floor opens with and whether it is the plan main room; floor 0 takes the main room first.
static func _floor_room(plan: Dictionary, f: int, geo: FloorGeo) -> Array:
	var room: ObstacleData = null
	var is_main: bool = false
	if f == 0:
		room = DataManager.get_obstacle_by_name(String(plan.get("main_room", "")))
		is_main = room != null
	if room == null:
		room = _pick_room(plan, f, geo)
	return [room, is_main]


#Near equal spans of [lo, hi] with one wall cell between them; the count drops until every span fits.
static func _spans(lo: int, hi: int, n: int, min_len: int) -> Array:
	var out: Array = []
	var total: int = hi - lo + 1
	var count: int = maxi(1, n)
	while count > 1 and total - (count - 1) < min_len * count:
		count -= 1
	var avail: int = total - (count - 1)
	if avail < 1:
		return out
	var base: int = floori(float(avail) / float(count))
	var rem: int = avail - base * count
	var cur: int = lo
	for i: int in range(count):
		var span_len: int = base + (1 if i < rem else 0)
		if span_len < 1:
			break
		out.append([cur, cur + span_len - 1])
		cur += span_len + 1
	return out


#The stair band lies against the front wall only when the front is W or E.
static func _band_on_front(geo: FloorGeo) -> bool:
	return geo.band_x0 >= 0 and _front_we(geo)


static func _is_landing(geo: FloorGeo, t: int) -> bool:
	var rows: Vector2i = geo.rows
	return t == rows.x - 1 or t == rows.y + 1


#One room fills the usable rect; floor 0 carries the main room.
static func open_floor(area: BattlefieldArea, f: int, plan: Dictionary, geo: FloorGeo) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var picked: Array = _floor_room(plan, f, geo)
	var room: ObstacleData = picked[0] as ObstacleData
	var is_main: bool = bool(picked[1])
	_record(area, result, room, rect_of(geo, geo.t0, geo.t1, 0, geo.s_size - 1), f, is_main)
	return result


#Main room across the front, one dividing wall, one to three back rooms behind it.
static func shop_floor(area: BattlefieldArea, f: int, plan: Dictionary, geo: FloorGeo,
		wall_data: ObstacleData, fh: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var t0: int = geo.t0
	var t1: int = geo.t1
	var tn: int = t1 - t0 + 1
	var sn: int = geo.s_size
	if sn < 7 or tn < 3:
		return open_floor(area, f, plan, geo)
	var ms: int = clampi(roundi(float(sn) * randf_range(0.45, 0.60)), 3, sn - 4)
	var picked: Array = _floor_room(plan, f, geo)
	var front_room: ObstacleData = picked[0] as ObstacleData
	var is_main: bool = bool(picked[1])
	_record(area, result, front_room, rect_of(geo, t0, t1, 0, ms - 1), f, is_main)
	_wall_line(area, f, cell(geo, t0, ms), cell(geo, t1, ms), wall_data, fh)
	var n_max: int = maxi(1, (tn + 1) >> 2)
	var want: int = maxi(randi_range(1, 3), _unused_required(plan, f, geo).size())
	var spans: Array = _spans(t0, t1, clampi(want, 1, n_max), 3)
	for i: int in range(spans.size()):
		var span: Array = spans[i]
		var sa: int = span[0] as int
		var sb: int = span[1] as int
		if i > 0:
			_wall_line(area, f, cell(geo, sa - 1, ms), cell(geo, sa - 1, sn - 1), wall_data, fh)
		_record(area, result, _pick_room(plan, f, geo), rect_of(geo, sa, sb, ms + 1, sn - 1), f, false)
		var dc: Vector2i = cell(geo, (sa + sb) >> 1, ms)
		_door(area, Vector3i(dc.x, dc.y, f), fh, _orient_t(geo))
	return result


#Hall from the street door to the back wall with room strips along one or two sides.
static func hall_floor(area: BattlefieldArea, f: int, plan: Dictionary, geo: FloorGeo,
		wall_data: ObstacleData, fh: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var t0: int = geo.t0
	var t1: int = geo.t1
	var tn: int = t1 - t0 + 1
	var sn: int = geo.s_size
	if tn < 5 or sn < 4:
		return open_floor(area, f, plan, geo)
	var forced: bool = _band_on_front(geo) and String(plan.get("band_side", "")) == String(plan.get("front", ""))
	var t_door: int = geo.t_door
	if t_door < t0 or t_door > t1:
		t_door = clampi(geo.ent_row, t0, t1) if forced else (t0 + t1) >> 1
	var low_free: int = t_door - t0 - 1
	var high_free: int = t1 - t_door - 1
	var low_k: int = clampi(low_free, 4, 8) if low_free >= 4 else 0
	var high_k: int = clampi(high_free, 4, 8) if high_free >= 4 else 0
	if low_k > 0 and high_k > 0 and tn < 11:
		if low_free >= high_free:
			high_k = 0
		else:
			low_k = 0
	#The hall is the main room of the building, so it keeps two fifths of the frontage.
	var hall_min: int = maxi(3, floori(float(tn * 2 + 4) / 5.0))
	while low_k + high_k > 0 and tn - low_k - high_k < hall_min:
		if low_k >= high_k:
			low_k = low_k - 1 if low_k > 4 else 0
		else:
			high_k = high_k - 1 if high_k > 4 else 0
	if low_k == 0 and high_k > 0:
		high_k = clampi(tn - hall_min, high_k, mini(8, high_free))
	elif high_k == 0 and low_k > 0:
		low_k = clampi(tn - hall_min, low_k, mini(8, low_free))
	if low_k == 0 and high_k == 0 and tn >= 7 and not forced:
		var one_k: int = clampi(tn - hall_min, 4, 8)
		if randi() % 2 == 0:
			low_k = one_k
		else:
			high_k = one_k
		t_door = ((t0 + low_k) + (t1 - high_k)) >> 1
	low_k = _shift_strip(geo, t0, t1, low_k, high_k, true)
	high_k = _shift_strip(geo, t0, t1, high_k, low_k, false)
	geo.t_door = t_door
	var end_len: int = 0
	if int(plan.get("entrances", 1)) < 2 and sn >= 10 and randi() % 2 == 0:
		end_len = clampi(randi_range(3, 5), 3, sn - 6)
	var hall_lo: int = t0 + low_k
	var hall_hi: int = t1 - high_k
	var hall_s_hi: int = sn - 1 if end_len <= 0 else sn - end_len - 2
	if low_k > 0:
		_hall_strip(area, f, plan, geo, wall_data, fh, result, t0, t0 + low_k - 2, t0 + low_k - 1)
	if high_k > 0:
		_hall_strip(area, f, plan, geo, wall_data, fh, result, t1 - high_k + 2, t1, t1 - high_k + 1)
	if end_len > 0:
		_wall_line(area, f, cell(geo, hall_lo, sn - end_len - 1), cell(geo, hall_hi, sn - end_len - 1),
			wall_data, fh)
		var dc: Vector2i = cell(geo, (hall_lo + hall_hi) >> 1, sn - end_len - 1)
		_door(area, Vector3i(dc.x, dc.y, f), fh, _orient_t(geo))
		_record(area, result, _pick_room(plan, f, geo), rect_of(geo, hall_lo, hall_hi, sn - end_len, sn - 1),
			f, false)
	var picked: Array = _floor_room(plan, f, geo)
	var hall_room: ObstacleData = picked[0] as ObstacleData
	var is_main: bool = bool(picked[1])
	_record(area, result, hall_room, rect_of(geo, hall_lo, hall_hi, 0, hall_s_hi), f, is_main)
	return result


#Keeps a strip wall off a stair landing row so the band still reaches the rest of the floor.
static func _shift_strip(geo: FloorGeo, t0: int, t1: int, k: int, other_k: int, low: bool) -> int:
	if k <= 0 or not _band_on_front(geo):
		return k
	var wall_t: int = t0 + k - 1 if low else t1 - k + 1
	if not _is_landing(geo, wall_t):
		return k
	if (t1 - t0 + 1) - (k + 1) - other_k >= 3:
		return k + 1
	if k - 1 >= 4:
		return k - 1
	return k


#One side strip: the hall side wall, the rooms split along s and one door per room.
static func _hall_strip(area: BattlefieldArea, f: int, plan: Dictionary, geo: FloorGeo,
		wall_data: ObstacleData, fh: int, result: Array[Dictionary], t_lo: int, t_hi: int,
		wall_t: int) -> void:
	if t_hi < t_lo:
		return
	var sn: int = geo.s_size
	_wall_line(area, f, cell(geo, wall_t, 0), cell(geo, wall_t, sn - 1), wall_data, fh)
	var span_len: int = clampi(randi_range(4, 7), 3, sn)
	var count: int = maxi(1, floori(float(sn + 1) / float(span_len + 1)))
	count = maxi(count, mini(_unused_required(plan, f, geo).size(), (sn + 1) >> 2))
	var spans: Array = _spans(0, sn - 1, count, 3)
	for i: int in range(spans.size()):
		var span: Array = spans[i]
		var sa: int = span[0] as int
		var sb: int = span[1] as int
		if i > 0:
			_wall_line(area, f, cell(geo, t_lo, sa - 1), cell(geo, t_hi, sa - 1), wall_data, fh)
		_record(area, result, _pick_room(plan, f, geo), rect_of(geo, t_lo, t_hi, sa, sb), f, false)
		var dc: Vector2i = cell(geo, wall_t, (sa + sb) >> 1)
		_door(area, Vector3i(dc.x, dc.y, f), fh, _orient_s(geo))


#Market stall shell: the ring is open floor, four awning posts, one room record, no walls.
static func open_shell(area: BattlefieldArea, plan: Dictionary, geo: FloorGeo) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bld_x: int = geo.bld_x
	var top_y: int = geo.top_y
	var ring := Rect2i(bld_x, top_y, geo.floor_w + 2, geo.floor_d + 2)
	for ix: int in range(ring.position.x, ring.end.x):
		for iy: int in range(ring.position.y, ring.end.y):
			area.building_interiors[Vector3i(ix, iy, 0)] = true
			area.footprint_cells[Vector3i(ix, iy, 0)] = true
	area.set_footprint_from_cells()
	var post: ObstacleData = DataManager.get_obstacle_by_name("Awning Post")
	if post == null:
		area.generation_log.append("[GEN] open shell: Awning Post obstacle missing")
	else:
		var pw: int = ceili(post.size_x)
		var ph: int = ceili(post.size_y)
		for corner: Vector2i in [ring.position, Vector2i(ring.end.x - 1, ring.position.y),
				Vector2i(ring.position.x, ring.end.y - 1), Vector2i(ring.end.x - 1, ring.end.y - 1)]:
			var p3 := Vector3i(corner.x, corner.y, 0)
			area.add_obstacle({"pos": p3, "size": pw * ph, "data": post,
				"cell_type": "furniture", "pw": pw, "ph": ph, "floor": 0}, p3)
	var room: ObstacleData = DataManager.get_obstacle_by_name(String(plan.get("main_room", "")))
	_record(area, result, room, Rect2i(geo.ix0, geo.iy0, geo.floor_w,
		geo.floor_d), 0, true)
	return result


static func opposite(side: String) -> String:
	if side == "W":
		return "E"
	if side == "E":
		return "W"
	if side == "N":
		return "S"
	return "N"


static func _wall_orient(side: String) -> String:
	return "v" if side == "W" or side == "E" else "h"


static func _cross_orient(side: String) -> String:
	return "h" if side == "W" or side == "E" else "v"


static func inward(side: String) -> Vector3i:
	var step: Vector2i = inward_step(side)
	return Vector3i(step.x, step.y, 0)


#Step from the outside of a side into the building; N is the low y side.
static func inward_step(side: String) -> Vector2i:
	if side == "W":
		return Vector2i(1, 0)
	if side == "E":
		return Vector2i(-1, 0)
	if side == "N":
		return Vector2i(0, 1)
	return Vector2i(0, -1)


#The outer wall cell of one side at position t along it.
static func wall_cell(geo: FloorGeo, side: String, t: int) -> Vector2i:
	var bld_x: int = geo.bld_x
	var top_y: int = geo.top_y
	if side == "W":
		return Vector2i(bld_x, t)
	if side == "E":
		return Vector2i(bld_x + geo.floor_w + 1, t)
	if side == "N":
		return Vector2i(t, top_y)
	return Vector2i(t, top_y + geo.floor_d + 1)


#Positions along one wall that face the interior.
static func wall_t_range(geo: FloorGeo, side: String) -> Vector2i:
	if side == "W" or side == "E":
		return Vector2i(geo.iy0, geo.iy1)
	return Vector2i(geo.ix0, geo.ix1)


static func _rect_t_range(geo: FloorGeo, rect: Rect2i) -> Vector2i:
	if _front_we(geo):
		return Vector2i(rect.position.y, rect.end.y - 1)
	return Vector2i(rect.position.x, rect.end.x - 1)


static func _touches_front(geo: FloorGeo, side: String, rect: Rect2i) -> bool:
	if side == "W":
		return rect.position.x == geo.ix0
	if side == "E":
		return rect.end.x - 1 == geo.ix1
	if side == "N":
		return rect.position.y == geo.iy0
	return rect.end.y - 1 == geo.iy1


#A wing blocks only the wall it grows from.
static func _in_wing_x(wings: Array[Dictionary], side: String, x: int) -> bool:
	for wing: Dictionary in wings:
		if String(wing.get("side", "")).to_upper() != side:
			continue
		var x0: int = int(wing["x0"]) - 1
		if x >= x0 and x <= x0 + int(wing["len"]) + 1:
			return true
	return false


#True when the cell behind a street door is open; strict rules out the stair band as well.
static func _inside_free(area: BattlefieldArea, p: Vector3i, strict: bool) -> bool:
	if not area._obs_map.has(p):
		return true
	if strict:
		return false
	var ct: String = area.cell_type_at(p)
	return ct == "reserved_stairwell" or ct == "stair_run"


static func _door_t_ok(area: BattlefieldArea, geo: FloorGeo, side: String, t: int,
		wings: Array[Dictionary], strict: bool) -> bool:
	var p: Vector2i = wall_cell(geo, side, t)
	if (side == "N" or side == "S") and _in_wing_x(wings, side, p.x):
		return false
	if not strict:
		return true
	var inn: Vector3i = Vector3i(p.x, p.y, 0) + inward(side)
	if not _inside_free(area, inn, true):
		return false
	var band_x0: int = geo.band_x0
	if band_x0 >= 0 and (inn.x == band_x0 or inn.x == band_x0 + 1):
		return false
	if band_x0 >= 0 and (side == "W" or side == "E") and InteriorGenerator._well_row_blocked(area, p.y):
		return false
	return true


#Position on one wall nearest want that takes a door; -1 when the wall has none.
static func _slide_t(area: BattlefieldArea, geo: FloorGeo, side: String, span: Vector2i,
		want: int, wings: Array[Dictionary], strict: bool) -> int:
	for d: int in range(0, span.y - span.x + 1):
		for cand: int in [want - d, want + d]:
			if cand < span.x or cand > span.y:
				continue
			if _door_t_ok(area, geo, side, cand, wings, strict):
				return cand
	return -1


#Opens the cell behind a street door: a wall becomes a second door, a stair cell is left alone.
static func _open_inside(area: BattlefieldArea, inn: Vector3i, fh: int, orientation: String) -> void:
	var ct: String = area.cell_type_at(inn)
	if ct == "wall":
		_door(area, inn, fh, orientation)
		return
	if ct == "stairs" or ct == "stair_run" or ct == "reserved_stairwell" or ct == "door":
		return
	InteriorGenerator._clear_cell(area, inn)
	area.building_interiors[inn] = true


#The street door in the front wall and, for two entrances, a second door in the opposite wall.
static func place_doors(area: BattlefieldArea, plan: Dictionary, geo: FloorGeo,
		rooms: Array[Dictionary], fh: int, wings: Array[Dictionary]) -> void:
	if String(plan.get("shell", "Walled")) == "Open":
		return
	var front: String = String(plan.get("front", "W"))
	var corridor: bool = String(plan.get("layout_f0", "Open")) == "Corridor"
	var span: Vector2i = wall_t_range(geo, front)
	var want: int = (span.x + span.y) >> 1
	var chosen: Dictionary = {}
	if corridor:
		chosen = _corridor_main(geo, front, rooms)
	elif String(plan.get("layout_f0", "Open")) == "Hall" and geo.t_door >= 0:
		want = clampi(geo.t_door, span.x, span.y)
	elif _band_on_front(geo) and String(plan.get("band_side", "")) == front:
		want = clampi(geo.ent_row, span.x, span.y)
	else:
		want = _main_front_t(geo, rooms, want)
	var t_pick: int = -1
	if not chosen.is_empty():
		t_pick = _room_door_t(area, geo, front, chosen["rect"] as Rect2i, wings)
		if t_pick < 0:
			chosen = {}
	if t_pick < 0:
		t_pick = _slide_t(area, geo, front, span, want, wings, corridor)
	if t_pick < 0:
		t_pick = _slide_t(area, geo, front, span, want, wings, false)
	if t_pick < 0:
		t_pick = want
	var wall_p: Vector2i = wall_cell(geo, front, t_pick)
	var door_p := Vector3i(wall_p.x, wall_p.y, 0)
	_door(area, door_p, fh, _wall_orient(front))
	_open_inside(area, door_p + inward(front), fh, _cross_orient(front))
	area.building_plan["front_door"] = door_p
	if corridor and not chosen.is_empty():
		_room_path(area, door_p + inward(front), front, chosen["rect"] as Rect2i, fh, true)
		_mark_main(area, chosen)
	if int(plan.get("entrances", 1)) < 2:
		return
	var back: String = opposite(front)
	var bspan: Vector2i = wall_t_range(geo, back)
	var b_pick: int = _slide_t(area, geo, back, bspan, (bspan.x + bspan.y) >> 1, wings, true)
	if b_pick < 0:
		return
	var bwall: Vector2i = wall_cell(geo, back, b_pick)
	var back_p := Vector3i(bwall.x, bwall.y, 0)
	_door(area, back_p, fh, _wall_orient(back))
	_open_inside(area, back_p + inward(back), fh, _cross_orient(back))
	area.building_plan["back_door"] = back_p


#Corridor floors: the floor 0 room of the main block nearest the front wall, the largest among equals.
static func _corridor_main(geo: FloorGeo, front: String, rooms: Array[Dictionary]) -> Dictionary:
	var block := Rect2i(geo.ix0, geo.iy0, geo.floor_w, geo.floor_d)
	var best: Dictionary = {}
	var best_gap: int = 4
	var best_area: int = -1
	for rec: Dictionary in rooms:
		if int(rec.get("floor", 0)) != 0 or _is_exterior_rec(rec):
			continue
		var rect: Rect2i = rec["rect"] as Rect2i
		if not block.encloses(rect):
			continue
		var gap: int = _front_gap(geo, front, rect)
		var size: int = rect.size.x * rect.size.y
		if gap < best_gap or (gap == best_gap and size > best_area):
			best_gap = gap
			best_area = size
			best = rec
	return best


#Cells between the front wall and the rect's near edge; 0 when the room touches the front wall.
static func _front_gap(geo: FloorGeo, side: String, rect: Rect2i) -> int:
	if side == "W":
		return rect.position.x - geo.ix0
	if side == "E":
		return geo.ix1 - (rect.end.x - 1)
	if side == "N":
		return rect.position.y - geo.iy0
	return geo.iy1 - (rect.end.y - 1)


#Front wall position whose door leads straight into the room; a door already in the room's near wall is preferred.
static func _room_door_t(area: BattlefieldArea, geo: FloorGeo, side: String, rect: Rect2i,
		wings: Array[Dictionary]) -> int:
	var rt: Vector2i = _rect_t_range(geo, rect)
	var span: Vector2i = wall_t_range(geo, side)
	var want: int = (rt.x + rt.y) >> 1
	for pass_i: int in range(0, 2):
		for d: int in range(0, rt.y - rt.x + 1):
			for cand: int in [want - d, want + d]:
				if cand < rt.x or cand > rt.y or cand < span.x or cand > span.y:
					continue
				if not _door_t_ok(area, geo, side, cand, wings, true):
					continue
				var wall_p: Vector2i = wall_cell(geo, side, cand)
				var inn: Vector3i = Vector3i(wall_p.x, wall_p.y, 0) + inward(side)
				var walls: int = _room_path(area, inn, side, rect, 0, false)
				if walls < 0 or (pass_i == 0 and walls > 0):
					continue
				return cand
	return -1


#Walls (0 or 1) on the straight line inward from inn to the room's open floor; -1 when the line fails. cut opens the wall.
static func _room_path(area: BattlefieldArea, inn: Vector3i, side: String, rect: Rect2i,
		fh: int, cut: bool) -> int:
	var p: Vector3i = inn
	var walls: int = 0
	for _i: int in range(0, 5):
		if not area._obs_map.has(p):
			if rect.has_point(Vector2i(p.x, p.y)):
				return walls
		else:
			var ct: String = area.cell_type_at(p)
			if ct == "wall":
				walls += 1
				if walls > 1:
					return -1
				if cut:
					_door(area, p, fh, _wall_orient(side))
			elif ct != "door":
				return -1
		p += inward(side)
	return -1


#Centre of the main room's front edge; the wall centre when floor 0 has no main room yet.
static func _main_front_t(geo: FloorGeo, rooms: Array[Dictionary], fallback: int) -> int:
	for rec: Dictionary in rooms:
		if int(rec.get("floor", 0)) != 0 or not bool(rec.get("main", false)):
			continue
		var rt: Vector2i = _rect_t_range(geo, rec["rect"] as Rect2i)
		return (rt.x + rt.y) >> 1
	return fallback


#The interior_rooms label covering the record's rect on its floor; {} when the floor carries none.
static func _label_for(area: BattlefieldArea, rec: Dictionary) -> Dictionary:
	var rect: Rect2i = rec["rect"] as Rect2i
	var f: int = int(rec.get("floor", 0))
	for label: Dictionary in area.interior_rooms:
		if int(label.get("floor", 0)) != f or (label["rect"] as Rect2i) != rect:
			continue
		return label
	return {}


static func _mark_main(area: BattlefieldArea, rec: Dictionary) -> void:
	rec["main"] = true
	var label: Dictionary = _label_for(area, rec)
	if not label.is_empty():
		label["main"] = true


static func _rename(area: BattlefieldArea, rec: Dictionary, room: ObstacleData, is_main: bool) -> void:
	rec["room"] = room
	if is_main:
		rec["main"] = true
	var label: Dictionary = _label_for(area, rec)
	if label.is_empty():
		return
	label["name"] = room.obstacle_name
	if is_main:
		label["main"] = true


static func _is_exterior_rec(rec: Dictionary) -> bool:
	var room: ObstacleData = rec.get("room") as ObstacleData
	return room != null and room.room_type.begins_with("Exterior")


static func _rec_name(rec: Dictionary) -> String:
	var room: ObstacleData = rec.get("room") as ObstacleData
	return "" if room == null else room.obstacle_name


#Names the main room at the front door and gives every required room a slot on a floor it fits.
static func label_rooms(area: BattlefieldArea, plan: Dictionary, rooms: Array[Dictionary],
		geo: FloorGeo) -> void:
	var main_data: ObstacleData = DataManager.get_obstacle_by_name(String(plan.get("main_room", "")))
	if main_data != null:
		for rec: Dictionary in rooms:
			if int(rec.get("floor", 0)) != 0 or not bool(rec.get("main", false)):
				continue
			if _rec_name(rec) != main_data.obstacle_name:
				_rename(area, rec, main_data, true)
			break
	var top: int = geo.top_floor
	var required: Dictionary = {}
	for entry: Variant in (plan.get("required_rooms", []) as Array):
		required[String(entry)] = true
	for entry2: Variant in (plan.get("required_rooms", []) as Array):
		var want_name: String = String(entry2)
		var data: ObstacleData = DataManager.get_obstacle_by_name(want_name)
		if data == null or _has_name(rooms, want_name):
			continue
		var want_area: int = maxi(1, ceili(data.size_x) * ceili(data.size_y))
		var best: Dictionary = {}
		var best_diff: int = 1 << 30
		for rec: Dictionary in rooms:
			if bool(rec.get("main", false)) or _is_exterior_rec(rec):
				continue
			if required.has(_rec_name(rec)):
				continue
			if not BuildingRules.room_fits_floor(want_name, int(rec.get("floor", 0)), top):
				continue
			var rect: Rect2i = rec["rect"] as Rect2i
			var diff: int = absi(rect.size.x * rect.size.y - want_area)
			if diff < best_diff:
				best_diff = diff
				best = rec
		if not best.is_empty():
			_rename(area, best, data, false)


static func _has_name(rooms: Array[Dictionary], room_name: String) -> bool:
	for rec: Dictionary in rooms:
		if _rec_name(rec) == room_name:
			return true
	return false

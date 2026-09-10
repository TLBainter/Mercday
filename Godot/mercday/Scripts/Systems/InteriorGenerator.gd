class_name InteriorGenerator


static func generate_interior(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext) -> void:
	var _gen_start := Time.get_ticks_msec()
	area.reset_generated_state()
	area.spawn_zone_a.clear()
	area.spawn_zone_b.clear()
	area.interior_rooms.clear()

	var fp: int = area_data.get("f_plus", 0)
	var fm: int = area_data.get("f_minus", 0)
	var min_sz: int = area_data.get("min_size", 18)
	var max_sz: int = area_data.get("max_size", 45)
	var num_floors: int = fp + fm + 1

	var fh: int = randi_range(3, 4)
	var floor_d: int = randi_range(min_sz, max_sz)
	var floor_w: int = randi_range(min_sz, max_sz)
	var street: int = randi_range(3, 5)

	area.width = floor_w + 2 + 2 * street
	area.length = floor_d + 1 + 2 * street
	area.height = randi_range(20, 40)
	area.cover_amount = 2
	area.is_interior_map = true
	area.unevenness = 6
	area.interior_floor_height = fh
	area.interior_floor_depth = floor_d
	area.area_name = area_data.get("name", "Unknown")

	var bld_x: int = street

	#floors sorted from lowest to highest: -fm, ..., 0, ..., fp
	var floor_list: Array[int] = []
	for f: int in range(-fm, fp + 1):
		floor_list.append(f)
	floor_list.sort()
	for fi: int in range(floor_list.size()):
		var f: int = floor_list[fi]
		area.interior_floor_elevations[f] = fi * fh

	#One well per building: every floor is partitioned around the same column pair.
	var _sx: int = bld_x + 2 + (randi() % maxi(1, floor_w - 3))
	var _tdx: int = -1 if (_sx % 2 == 1 and _sx - 1 >= bld_x + 1) else 1
	if _tdx > 0 and _sx + 1 > bld_x + floor_w:
		_tdx = -1
	var stairwell_xs: Dictionary = {}
	var stairwell_adj_xs: Dictionary = {}
	for f: int in range(fp, -fm, -1):
		stairwell_xs[f] = _sx
		stairwell_adj_xs[f] = _sx + _tdx

	var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
	if wall_data == null:
		push_error("InteriorGenerator: Wall obstacle missing")
		return
	var stairs_data: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	var window_data: ObstacleData = DataManager.get_obstacle_by_name("Window")

	var top_y: int = street
	area.interior_top_y = top_y

	var all_rooms: Array[Dictionary] = []

	for f: int in range(fp, -(fm + 1), -1):
		_place_floor_shell(area, f, bld_x, top_y, floor_w, floor_d, wall_data, fh)
	area.building_footprint = Rect2i(bld_x, top_y, floor_w + 2, floor_d + 2)

	_mark_ceiling_cells(area, fp, fm, bld_x, floor_w, floor_d, top_y)

	var ent_y: int = _place_entrance_doors(area, bld_x, top_y, floor_w, floor_d, fh, num_floors)

	var floor_v_cors: Dictionary = {}
	for f: int in range(fp, -(fm + 1), -1):
		var sx_below: int = stairwell_xs.get(f, -1)
		var sx_above: int = stairwell_xs.get(f + 1, -1)
		var ax_below: int = stairwell_adj_xs.get(f, -1)
		var ax_above: int = stairwell_adj_xs.get(f + 1, -1)
		var v_cors_out: Array = []
		var rooms: Array[Dictionary] = _partition_rooms(
			area, f, bld_x, top_y, floor_w, floor_d, area_data, wall_data, fh,
			sx_below, sx_above, ax_below, ax_above, v_cors_out)
		all_rooms.append_array(rooms)
		floor_v_cors[f] = v_cors_out
		_place_exterior_rooms(area, f, bld_x, top_y, floor_w, floor_d, area_data, wall_data, fh, street, all_rooms)

	if num_floors > 1:
		_build_stairwells(area, floor_v_cors, fp, fm, bld_x, floor_w, floor_d, top_y,
			stairs_data, stairwell_xs, stairwell_adj_xs)

	_open_entrance_cells(area, bld_x, floor_w, ent_y, fh)

	_place_windows(area, fp, fm, bld_x, floor_w, floor_d, window_data, stairwell_xs, top_y, fh)
	_fix_blind_doors(area)
	_place_furniture_in_rooms(area, all_rooms)
	_assign_spawns(area, ctx, bld_x, floor_w, floor_d, top_y)

	area.build_stair_links()
	area.build_drop_links()
	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()

	var total_ms: int = Time.get_ticks_msec() - _gen_start
	_log_generation(area, total_ms, num_floors, floor_w, fh, floor_d)


static func _place_floor_shell(area: BattlefieldArea, f: int, bld_x: int, top_y: int, floor_w: int, floor_d: int, wall_data: ObstacleData, fh: int) -> void:
	var wall_sz: int = 4
	var bot_y: int = top_y + floor_d + 1

	for x: int in range(bld_x, bld_x + floor_w + 2):
		_place_wall_if_empty(area, Vector3i(x, top_y, f), wall_sz, wall_data, fh)
		_place_wall_if_empty(area, Vector3i(x, bot_y, f), wall_sz, wall_data, fh)

	for y: int in range(top_y + 1, bot_y):
		_place_wall_if_empty(area, Vector3i(bld_x, y, f), wall_sz, wall_data, fh)
		_place_wall_if_empty(area, Vector3i(bld_x + floor_w + 1, y, f), wall_sz, wall_data, fh)

	for iy: int in range(top_y + 1, bot_y):
		for ix: int in range(bld_x + 1, bld_x + floor_w + 1):
			area.building_interiors[Vector3i(ix, iy, f)] = true


static func _mark_ceiling_cells(area: BattlefieldArea, fp: int, fm: int, bld_x: int, floor_w: int, floor_d: int, top_y: int) -> void:
	var ceiling_y: int = top_y + floor_d
	for f: int in range(fp, -fm, -1):
		for x: int in range(bld_x, bld_x + floor_w + 2):
			area.ceiling_cells[Vector3i(x, ceiling_y, f)] = true


static func _partition_rooms(area: BattlefieldArea, f: int, bld_x: int, top_y: int, floor_w: int, floor_d: int, area_data: Dictionary, wall_data: ObstacleData, fh: int, stairwell_x_below: int = -1, stairwell_x_above: int = -1, adj_x_below: int = -1, adj_x_above: int = -1, v_cors_out: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var eligible: Array[ObstacleData] = DataManager.get_rooms_for_floor(area_data, f)
	if eligible.is_empty():
		return result
	eligible.shuffle()
	var door_data: ObstacleData = BuildingGenerator._get_door_template()
	if floor_d >= 4:
		_partition_corridor(area, f, bld_x, top_y, floor_w, floor_d, eligible, wall_data, fh, door_data, result, stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above, v_cors_out)
	else:
		_partition_strip(area, f, bld_x + 1, top_y + 1, floor_w, floor_d, eligible, wall_data, fh, result, stairwell_x_below, adj_x_below, true)
	return result


static func _partition_corridor(area: BattlefieldArea, f: int, bld_x: int, top_y: int, floor_w: int, floor_d: int, eligible: Array[ObstacleData], wall_data: ObstacleData, fh: int, door_data: ObstacleData, result: Array[Dictionary], stairwell_x_below: int = -1, stairwell_x_above: int = -1, adj_x_below: int = -1, adj_x_above: int = -1, v_cors_out: Array = []) -> void:
	var wall_sz: int = 4
	var ix0: int = bld_x + 1
	var iy0: int = top_y + 1
	var ix1: int = bld_x + floor_w
	var iy1: int = top_y + floor_d

	var max_room_sz_x: int = 0
	var max_room_sz_y: int = 0
	for r: ObstacleData in eligible:
		max_room_sz_x = maxi(max_room_sz_x, ceili(r.size_x))
		max_room_sz_y = maxi(max_room_sz_y, ceili(r.size_y))
	if max_room_sz_x == 0:
		max_room_sz_x = 4
	if max_room_sz_y == 0:
		max_room_sz_y = 4

	var floor_h_depth: int = iy1 - iy0
	var min_strip: int = maxi(3, mini(max_room_sz_y, (floor_h_depth >> 1) - 1))
	var min_v_strip: int = maxi(3, max_room_sz_x)
	var h_min: int = iy0 + min_strip
	var h_max: int = iy1 - min_strip
	var v_min: int = ix0 + min_v_strip
	var v_max: int = ix1 - min_v_strip
	var can_h: bool = h_min <= h_max
	var can_v: bool = v_min <= v_max

	var h_cors: Array[int] = []
	var v_cors: Array[int] = []

	if not can_h and not can_v:
		_partition_strip(area, f, ix0, iy0, floor_w, floor_d, eligible, wall_data, fh, result, stairwell_x_above, adj_x_above, true)
		return

	var sw_covers_v: bool = false
	for _swx: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
		if _swx >= ix0 and _swx <= ix1:
			sw_covers_v = true
			break

	var run_rows: Vector2i = _run_rows(top_y, floor_d, fh)
	var well_band: bool = sw_covers_v and run_rows.x - 1 >= iy0 and run_rows.y + 1 <= iy1
	if well_band:
		#A corridor at each end of the run band reaches the landing and the run top; nothing crosses the band.
		h_cors.append(run_rows.x - 1)
		h_cors.append(run_rows.y + 1)
		for band: Array in [[iy0, run_rows.x - 2], [run_rows.y + 2, iy1]]:
			var by0: int = band[0] as int
			var by1: int = band[1] as int
			if by1 - by0 + 1 >= min_strip * 2 + 1:
				h_cors.append(randi_range(by0 + min_strip, by1 - min_strip))
		if can_v:
			var v_cands: Array[int] = []
			for vx: int in range(v_min, v_max + 1):
				var far_enough: bool = true
				for _swx3: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
					if _swx3 >= 0 and absi(vx - _swx3) < 4:
						far_enough = false
				if far_enough:
					v_cands.append(vx)
			if not v_cands.is_empty():
				v_cors.append(v_cands[randi() % v_cands.size()])
	else:
		var valid_pats: Array[int] = []
		if can_h:
			valid_pats.append(0)
			valid_pats.append(0)
		if can_v and not sw_covers_v:
			valid_pats.append(1)
		if can_h and can_v and not sw_covers_v:
			valid_pats.append(2)
		if can_h and h_max - h_min >= min_strip * 2 + 1:
			valid_pats.append(3)
		if valid_pats.is_empty():
			_partition_strip(area, f, ix0, iy0, floor_w, floor_d, eligible, wall_data, fh, result, stairwell_x_above, adj_x_above, true)
			return
		var pat: int = valid_pats[randi() % valid_pats.size()]
		match pat:
			0:
				h_cors.append(randi_range(h_min, h_max))
			1:
				v_cors.append(randi_range(v_min, v_max))
			2:
				h_cors.append(randi_range(h_min, h_max))
				v_cors.append(randi_range(v_min, v_max))
			3:
				var mid: int = (h_min + h_max) >> 1
				var cy1: int = randi_range(h_min, maxi(h_min, mid - min_strip))
				var cy2: int = randi_range(mini(h_max, mid + min_strip), h_max)
				if cy1 < cy2:
					h_cors.append(cy1)
					h_cors.append(cy2)
				else:
					h_cors.append(randi_range(h_min, h_max))
		if h_cors.is_empty() and sw_covers_v and can_h:
			h_cors.append(randi_range(h_min, h_max))

	for sw_x: int in [stairwell_x_below, stairwell_x_above]:
		if sw_x >= ix0 and sw_x <= ix1 and not v_cors.has(sw_x):
			v_cors.append(sw_x)
	for ax: int in [adj_x_below, adj_x_above]:
		if ax >= ix0 and ax <= ix1 and not v_cors.has(ax):
			v_cors.append(ax)

	for cx: int in v_cors:
		if cx >= ix0 and cx <= ix1 and not v_cors_out.has(cx):
			v_cors_out.append(cx)

	for cy: int in h_cors:
		for x: int in range(ix0, ix1 + 1):
			area.reserved_corridor_cells[Vector2i(x, cy)] = true
	for cx: int in v_cors:
		for y: int in range(iy0, iy1 + 1):
			area.reserved_corridor_cells[Vector2i(cx, y)] = true

	h_cors.sort()
	v_cors.sort()

	var y_edges: Array[int] = [iy0]
	for cy: int in h_cors:
		y_edges.append(cy - 1)
		y_edges.append(cy + 1)
	y_edges.append(iy1)

	var x_edges: Array[int] = [ix0]
	for cx: int in v_cors:
		x_edges.append(cx - 1)
		x_edges.append(cx + 1)
	x_edges.append(ix1)

	var y_bands: Array[Array] = []
	for i: int in range(0, y_edges.size(), 2):
		if y_edges[i] <= y_edges[i + 1]:
			y_bands.append([y_edges[i], y_edges[i + 1]])

	var x_bands: Array[Array] = []
	for i: int in range(0, x_edges.size(), 2):
		if x_edges[i] <= x_edges[i + 1]:
			x_bands.append([x_edges[i], x_edges[i + 1]])

	var elig: Array[ObstacleData] = eligible.duplicate()
	elig.shuffle()

	for yb: Array in y_bands:
		for xb: Array in x_bands:
			var rx0: int = xb[0] as int
			var ry0: int = yb[0] as int
			var rw: int = (xb[1] as int) - rx0 + 1
			var rh: int = (yb[1] as int) - ry0 + 1
			if rw < 3 or rh < 2:
				continue
			var reg_result: Array[Dictionary] = []
			var sw_x: int = stairwell_x_above if ry0 == iy0 else stairwell_x_below
			var ax: int = adj_x_above if ry0 == iy0 else adj_x_below
			var right_x: int = xb[1] as int
			var at_outer: bool = right_x == ix1 or v_cors.has(right_x + 1)
			_partition_strip(area, f, rx0, ry0, rw, rh, elig, wall_data, fh, reg_result, sw_x, ax, at_outer)
			result.append_array(reg_result)

	var h_cor_set: Dictionary = {}
	for cy: int in h_cors:
		h_cor_set[cy] = true
	var v_cor_set: Dictionary = {}
	for cx: int in v_cors:
		v_cor_set[cx] = true
	var stairwell_v_set: Dictionary = {}
	for _swx2: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
		if _swx2 >= ix0 and _swx2 <= ix1:
			stairwell_v_set[_swx2] = true
	var accessible_rects: Dictionary = {}
	for _are: Dictionary in result:
		if (_are["floor"] as int) != f:
			continue
		var _ar: Rect2i = _are["rect"] as Rect2i
		var _arhc: bool = h_cor_set.has(_ar.position.y - 1) or h_cor_set.has(_ar.end.y)
		var _arns: bool = (v_cor_set.has(_ar.position.x - 1) and not stairwell_v_set.has(_ar.position.x - 1)) or (v_cor_set.has(_ar.end.x) and not stairwell_v_set.has(_ar.end.x))
		if _arhc or _arns:
			accessible_rects[_ar.position] = true
	var _arc: bool = true
	while _arc:
		_arc = false
		for _are: Dictionary in result:
			if (_are["floor"] as int) != f:
				continue
			var _ar: Rect2i = _are["rect"] as Rect2i
			if accessible_rects.has(_ar.position):
				continue
			for _are2: Dictionary in result:
				if (_are2["floor"] as int) != f:
					continue
				var _ar2: Rect2i = _are2["rect"] as Rect2i
				if not accessible_rects.has(_ar2.position):
					continue
				if _ar2.position.x == _ar.position.x and _ar2.end.x == _ar.end.x and ((_ar.end.y + 1 == _ar2.position.y) or (_ar2.end.y + 1 == _ar.position.y)):
					accessible_rects[_ar.position] = true
					_arc = true
					break

	for entry: Dictionary in result:
		if (entry["floor"] as int) != f:
			continue
		var rect: Rect2i = entry["rect"] as Rect2i
		var door_x: int = rect.position.x + (rect.size.x >> 1)
		var door_y: int = rect.position.y + (rect.size.y >> 1)

		if h_cor_set.has(rect.position.y - 1):
			var _hx_t: int = door_x
			if _well_row_blocked(area, rect.position.y - 1):
				_hx_t = _door_col_clear(stairwell_v_set, rect.position.x, rect.end.x, door_x)
			_place_edge_doors(area, f, "h", rect.position.y, rect.position.x, rect.end.x,
				_hx_t, false, wall_sz, wall_data, fh, door_data)

		if h_cor_set.has(rect.end.y):
			var _hx_b: int = door_x
			if _well_row_blocked(area, rect.end.y):
				_hx_b = _door_col_clear(stairwell_v_set, rect.position.x, rect.end.x, door_x)
			_place_edge_doors(area, f, "h", rect.end.y - 1, rect.position.x, rect.end.x,
				_hx_b, false, wall_sz, wall_data, fh, door_data)

		if v_cor_set.has(rect.position.x - 1):
			var _skip_l: bool = stairwell_v_set.has(rect.position.x - 1) and accessible_rects.has(rect.position)
			var _vy_l: int = door_y
			if stairwell_v_set.has(rect.position.x - 1):
				_vy_l = _door_row_clear(area, rect.position.y, rect.end.y, door_y)
			_place_edge_doors(area, f, "v", rect.position.x, rect.position.y, rect.end.y,
				_vy_l, _skip_l, wall_sz, wall_data, fh, door_data)

		if v_cor_set.has(rect.end.x):
			var _skip_r: bool = stairwell_v_set.has(rect.end.x) and accessible_rects.has(rect.position)
			var _vy_r: int = door_y
			if stairwell_v_set.has(rect.end.x):
				_vy_r = _door_row_clear(area, rect.position.y, rect.end.y, door_y)
			_place_edge_doors(area, f, "v", rect.end.x - 1, rect.position.y, rect.end.y,
				_vy_r, _skip_r, wall_sz, wall_data, fh, door_data)


#One room edge: a wall run along "axis" with a single door at door_i unless skip_door.
static func _place_edge_doors(area: BattlefieldArea, f: int, axis: String, fixed: int,
		from_i: int, to_i: int, door_i: int, skip_door: bool,
		wall_sz: int, wall_data: ObstacleData, fh: int, door_data: ObstacleData) -> void:
	for i: int in range(from_i, to_i):
		var p3 := Vector3i(i, fixed, f) if axis == "h" else Vector3i(fixed, i, f)
		if i == door_i and not skip_door:
			_place_door_at(area, p3, door_data, fh, axis)
		else:
			_place_wall_if_empty(area, p3, wall_sz, wall_data, fh)
			area.building_interiors.erase(p3)


static func _partition_strip(area: BattlefieldArea, f: int, sx0: int, sy0: int, sw: int, sh: int, rooms: Array[ObstacleData], wall_data: ObstacleData, fh: int, result: Array[Dictionary], stairwell_x: int = -1, adj_x: int = -1, expand_right: bool = false) -> void:
	if rooms.is_empty():
		return
	var wall_sz: int = 4
	var x_off: int = 0
	var room_idx: int = 0
	var sw_limit: int = sw if expand_right else sw - 1
	while x_off < sw_limit:
		var room: ObstacleData = rooms[room_idx % rooms.size()]
		room_idx += 1
		var base_w: int = maxi(3, ceili(room.size_x / 2.0))
		var rw: int = mini(clamp(base_w + randi_range(-1, 1), 3, sw_limit), sw_limit - x_off)
		if rw < 3 or x_off + rw > sw_limit:
			break
		for _sx: int in [stairwell_x, adj_x]:
			if _sx >= sx0 and _sx < sx0 + sw_limit:
				var dist: int = _sx - (sx0 + x_off)
				if dist > 0 and dist <= rw:
					rw = dist
		if rw < 3:
			break
		var has_div: bool = x_off + rw + 1 < sw
		if expand_right and x_off + rw < sw and sw - x_off - rw < 3:
			has_div = false
			rw = sw - x_off
		if not expand_right and has_div and x_off + rw == sw_limit - 1:
			var _div_x: int = sx0 + x_off + rw
			if _div_x != stairwell_x and _div_x != adj_x:
				has_div = false
				rw = sw_limit - x_off
		var y_slots: Array = []
		var y_off: int = 0
		var y_room_idx: int = room_idx - 1
		while y_off < sh:
			var yroom: ObstacleData = rooms[y_room_idx % rooms.size()]
			y_room_idx += 1
			var sh_rem: int = sh - y_off
			var aspect_ratio: float = yroom.size_y / yroom.size_x if yroom.size_x > 0.0 else 1.0
			var target_rh: int = maxi(3, roundi(float(rw) * aspect_ratio))
			var rh: int = mini(clamp(target_rh + randi_range(-1, 1), 3, sh_rem), sh_rem)
			if rh < 3:
				break
			var has_h_div: bool = sh_rem - rh - 1 >= 3
			if not has_h_div:
				rh = sh_rem
			y_slots.append([y_off, rh, has_h_div, yroom])
			y_off += rh + (1 if has_h_div else 0)
		if has_div:
			var div_x: int = sx0 + x_off + rw
			if div_x == stairwell_x or div_x == adj_x:
				for iy: int in range(sy0, sy0 + sh):
					area.reserved_corridor_cells[Vector2i(div_x, iy)] = true
			else:
				var mid_y: int = sy0 + (sh >> 1)
				var door_iy: int = -1
				for slot: Array in y_slots:
					var sly0: int = sy0 + (slot[0] as int)
					var sly1: int = sly0 + (slot[1] as int)
					if mid_y >= sly0 and mid_y < sly1:
						door_iy = mid_y
						break
				if door_iy == -1 and not y_slots.is_empty():
					var s0: Array = y_slots[0]
					door_iy = sy0 + (s0[0] as int) + ((s0[1] as int) >> 1)
				var div_door_data: ObstacleData = BuildingGenerator._get_door_template()
				for iy: int in range(sy0, sy0 + sh):
					if iy == door_iy:
						_place_door_at(area, Vector3i(div_x, iy, f), div_door_data, fh, "v")
					else:
						_place_wall_if_empty(area, Vector3i(div_x, iy, f), wall_sz, wall_data, fh)
						area.building_interiors.erase(Vector3i(div_x, iy, f))
		for slot: Array in y_slots:
			var slot_y_off: int = slot[0] as int
			var slot_rh: int = slot[1] as int
			var slot_has_h_div: bool = slot[2] as bool
			var slot_room: ObstacleData = slot[3] as ObstacleData
			if slot_has_h_div:
				var div_y: int = sy0 + slot_y_off + slot_rh
				var door_ix: int = sx0 + x_off + (rw >> 1)
				var h_div_door: ObstacleData = BuildingGenerator._get_door_template()
				for ix: int in range(sx0 + x_off, sx0 + x_off + rw):
					if ix == door_ix:
						_place_door_at(area, Vector3i(ix, div_y, f), h_div_door, fh, "h")
					else:
						_place_wall_if_empty(area, Vector3i(ix, div_y, f), wall_sz, wall_data, fh)
						area.building_interiors.erase(Vector3i(ix, div_y, f))
			var room_rect := Rect2i(sx0 + x_off, sy0 + slot_y_off, rw, slot_rh)
			result.append({"room": slot_room, "rect": room_rect, "floor": f})
			area.interior_rooms.append({"rect": room_rect, "name": slot_room.obstacle_name, "floor": f})
		x_off += rw + (1 if has_div else 0)
		if x_off >= sw:
			break
	while x_off < sw:
		var col_x: int = sx0 + x_off
		if col_x == stairwell_x or col_x == adj_x:
			for iy: int in range(sy0, sy0 + sh):
				area.reserved_corridor_cells[Vector2i(col_x, iy)] = true
		elif x_off == sw - 1 and not expand_right:
			for iy: int in range(sy0, sy0 + sh):
				_place_wall_if_empty(area, Vector3i(col_x, iy, f), wall_sz, wall_data, fh)
				area.building_interiors.erase(Vector3i(col_x, iy, f))
		x_off += 1


static func _place_door_at(area: BattlefieldArea, pos: Vector3i, door_data: ObstacleData, fh: int, orientation: String = "v") -> void:
	_clear_cell(area, pos)
	area.building_interiors.erase(pos)
	var door_obs := {"pos": pos, "size": 2, "data": door_data, "cell_type": "door", OpenCloseState.KEY: false,
		"orientation": orientation, "height": float(fh), "floor": pos.z}
	_add_obstacle(area, door_obs, pos)


#Highest floor in the building; the run parity is measured down from it.
static func _top_floor(area: BattlefieldArea) -> int:
	var best: int = 0
	var first: bool = true
	for k: Variant in area.interior_floor_elevations.keys():
		var f: int = k as int
		if first or f > best:
			best = f
			first = false
	return best


#Climb direction of the run on floor f: +1 rises with y, -1 rises against it. Alternates by floor.
static func _run_up(area: BattlefieldArea, f: int) -> int:
	return 1 if ((_top_floor(area) - f) % 2) == 0 else -1


#Row of the street doors: the level corridor at the floor 0 end of the well; the middle row without a well.
static func _entrance_row(area: BattlefieldArea, top_y: int, floor_d: int, fh: int, num_floors: int) -> int:
	if num_floors <= 1:
		return top_y + 1 + (floor_d >> 1)
	var rows: Vector2i = _run_rows(top_y, floor_d, fh)
	return rows.x - 1 if _run_up(area, 1) > 0 else rows.y + 1


#Rows of every run: 2 * fh steps of half a pace, centered so level corridor remains beyond both ends.
static func _run_rows(top_y: int, floor_d: int, fh: int) -> Vector2i:
	var iy0: int = top_y + 1
	var iy1: int = top_y + floor_d
	var steps: int = 2 * fh
	var r0: int = ((iy0 + iy1) >> 1) - fh
	r0 = clampi(r0, iy0 + 1, maxi(iy0 + 1, iy1 - 1 - steps))
	return Vector2i(r0, mini(r0 + steps, iy1 - 1))


#True at rows where a well column is a tread or lies under one; no door opens onto them.
static func _well_row_blocked(area: BattlefieldArea, y: int) -> bool:
	var rows: Vector2i = _run_rows(area.interior_top_y, area.interior_floor_depth, area.interior_floor_height)
	return y >= rows.x and y < rows.y


#Value nearest want in [lo, hi) that passes ok; fallback when no value in the span does.
static func _nearest_clear(lo: int, hi: int, want: int, ok: Callable, fallback: int) -> int:
	if ok.call(want):
		return want
	for d: int in range(1, hi - lo):
		for cand: int in [want - d, want + d]:
			if cand >= lo and cand < hi and ok.call(cand):
				return cand
	return fallback


#Row nearest want in [y0, y1) where a well door opens onto level floor; -1 when the wall has none.
static func _door_row_clear(area: BattlefieldArea, y0: int, y1: int, want: int) -> int:
	return _nearest_clear(y0, y1, want, func(v: int) -> bool: return not _well_row_blocked(area, v), -1)


#Column nearest want in [x0, x1) that is not a stair column; want when none is.
static func _door_col_clear(stair_cols: Dictionary, x0: int, x1: int, want: int) -> int:
	return _nearest_clear(x0, x1, want, func(v: int) -> bool: return not stair_cols.has(v), want)


#True when any door sits in column x on any floor of the building.
static func _column_has_door(area: BattlefieldArea, x: int, fp: int, fm: int, top_y: int, floor_d: int) -> bool:
	for f: int in range(fp, -(fm + 1), -1):
		for iy: int in range(top_y + 1, top_y + floor_d + 1):
			if (area._obs_map.get(Vector3i(x, iy, f), {}) as Dictionary).get("cell_type", "") == "door":
				return true
	return false


#One column pair for the whole building: adjacent vertical corridors on every floor, both door free.
static func _pick_stair_columns(area: BattlefieldArea, floor_v_cors: Dictionary, fp: int, fm: int,
		bld_x: int, floor_w: int, top_y: int, floor_d: int, fb_sx: int, fb_adj: int) -> Array[int]:
	var common: Dictionary = {}
	var first: bool = true
	for f: int in range(fp, -(fm + 1), -1):
		var vcors: Array = floor_v_cors.get(f, [])
		if first:
			for cx: int in vcors:
				common[cx] = true
			first = false
			continue
		for cx: Variant in common.keys():
			if not vcors.has(cx as int):
				common.erase(cx)
	var cands: Array[int] = []
	for cx: Variant in common.keys():
		var x: int = cx as int
		if x < bld_x + 1 or x + 1 > bld_x + floor_w or not common.has(x + 1):
			continue
		if _column_has_door(area, x, fp, fm, top_y, floor_d):
			continue
		if _column_has_door(area, x + 1, fp, fm, top_y, floor_d):
			continue
		cands.append(x)
	if cands.is_empty():
		return [fb_sx, fb_adj]
	cands.sort()
	var pick: int = cands[randi() % cands.size()]
	return [pick, pick + 1]


#One well per building: the run on floor f takes one column, the next run takes the neighbour and
#climbs back the other way, so its landing sits beside the top of the run below it.
static func _place_stairwells(area: BattlefieldArea, fp: int, fm: int, bld_x: int, floor_w: int, floor_d: int, stairs_data: ObstacleData, stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary, top_y: int) -> void:
	var run_rows: Vector2i = _run_rows(top_y, floor_d, area.interior_floor_height)
	var upper_y: int = run_rows.y
	var lower_y: int = run_rows.x
	for f: int in range(fp, -fm, -1):
		var sx: int = stairwell_xs.get(f, bld_x + 1 + (floor_w >> 1))
		var adj_x: int = stairwell_adj_xs.get(f, -1)
		if adj_x == -1:
			var tdx: int = -1 if (sx % 2 == 1 and sx - 1 >= bld_x + 1) else 1
			if tdx > 0 and sx + 1 > bld_x + floor_w:
				tdx = -1
			adj_x = sx + tdx
		var up: int = _run_up(area, f)
		var col: int = sx if up > 0 else adj_x
		var top_row: int = upper_y if up > 0 else lower_y
		var bot_row: int = lower_y if up > 0 else upper_y
		var top_cell := Vector3i(col, top_row, f)
		if area.ceiling_cells.has(top_cell):
			_clear_cell(area, top_cell)
			area.ceiling_cells.erase(top_cell)
		for cy: int in range(lower_y, upper_y + 1):
			var sv := Vector3i(col, cy, f)
			_clear_cell(area, sv)
			area.building_interiors[sv] = true
			area.stair_run_cells[sv] = true
		if area.interior_floor_elevations.has(f - 1):
			var landing := Vector3i(col, bot_row, f - 1)
			_clear_cell(area, landing)
			area.building_interiors[landing] = true
			area.stair_run_cells[landing] = true
		#stairwell at floor f connects f to f-1; cell is on floor f at the run top
		area.stairwell_cells[top_cell] = true
		if stairs_data != null:
			var upper := Vector3i(col, top_row, f)
			var lower := Vector3i(col, bot_row, f - 1)
			area.stairwell_connections[upper] = lower
			area.stairwell_connections[lower] = upper
			if area.building_interiors.has(upper):
				_clear_cell(area, upper)
				area.building_interiors[upper] = true
				var up_obs := {"pos": upper, "size": stairs_data.size, "data": stairs_data, "cell_type": "stairs", "floor": f}
				_add_obstacle(area, up_obs, upper)
			if area.building_interiors.has(lower):
				_clear_cell(area, lower)
				area.building_interiors[lower] = true
				var lo_obs := {"pos": lower, "size": stairs_data.size, "data": stairs_data, "cell_type": "stairs", "floor": f - 1}
				_add_obstacle(area, lo_obs, lower)


static func _place_furniture_in_rooms(area: BattlefieldArea, room_list: Array[Dictionary]) -> void:
	var total_cells: int = 0
	for entry: Dictionary in room_list:
		total_cells += (entry["rect"] as Rect2i).size.x * (entry["rect"] as Rect2i).size.y
	var s_min: int = maxi(1, floori(float(total_cells) / 40.0))
	var s_max: int = maxi(s_min + 1, floori(float(total_cells) / 15.0))
	var scatter_left: int = randi_range(s_min, s_max)

	for entry: Dictionary in room_list:
		var room: ObstacleData = entry["room"] as ObstacleData
		var rect: Rect2i = entry["rect"] as Rect2i
		var f: int = entry.get("floor", 0) as int

		var base_free: Array[Vector3i] = _room_free_cells(area, rect, f)
		var wadj: Dictionary = _wall_adj_set(area, base_free)
		var corners: Dictionary = _corner_set(area, base_free, wadj)
		var wadjwin: Dictionary = _window_adj_set(area, base_free)

		var obj_adj: Dictionary = {}
		var placed_alike: Dictionary = {}

		for sname: String in room.guaranteed_structures:
			var pick: Dictionary = _free_non_articulation(area, rect, f)
			var ap_set: Dictionary = pick["ap"]
			var pfree: Array[Vector3i] = pick["free"]
			pfree.shuffle()
			_place_pref(area, sname, pfree, rect, f, wadj, corners, wadjwin, obj_adj, placed_alike, ap_set)

		if not room.possible_structures.is_empty():
			var avail: int = _room_free_cells(area, rect, f).size()
			for _i: int in range(maxi(0, floori(float(avail) / 3.0))):
				var pick: Dictionary = _free_non_articulation(area, rect, f)
				var ap_set: Dictionary = pick["ap"]
				var pfree: Array[Vector3i] = pick["free"]
				pfree.shuffle()
				var sname: String = room.possible_structures[randi() % room.possible_structures.size()]
				_place_pref(area, sname, pfree, rect, f, wadj, corners, wadjwin, obj_adj, placed_alike, ap_set)

		if room.possible_scatter.is_empty() or scatter_left <= 0:
			continue

		var init_pick: Dictionary = _free_non_articulation(area, rect, f)
		var ap2_init: Dictionary = init_pick["ap"]
		var free2_init: Array[Vector3i] = init_pick["free"]
		if free2_init.is_empty():
			continue

		var room_total: int = rect.size.x * rect.size.y
		var free_ratio: float = float(free2_init.size()) / float(maxi(1, room_total))
		var room_max: int = maxi(0, roundi(float(free2_init.size()) * free_ratio * 0.4))
		var count: int = mini(room_max, scatter_left)
		if count <= 0:
			continue

		var wadj2: Dictionary = _wall_adj_set(area, free2_init)
		var corners2: Dictionary = _corner_set(area, free2_init, wadj2)
		var wadjwin2: Dictionary = _window_adj_set(area, free2_init)

		for _s: int in range(count):
			var loop_pick: Dictionary = _free_non_articulation(area, rect, f)
			var ap2: Dictionary = loop_pick["ap"]
			var free2: Array[Vector3i] = loop_pick["free"]
			if free2.is_empty():
				break
			free2.shuffle()
			var sname: String = room.possible_scatter[randi() % room.possible_scatter.size()]
			if _place_pref(area, sname, free2, rect, f, wadj2, corners2, wadjwin2, obj_adj, placed_alike, ap2):
				scatter_left -= 1
			if scatter_left <= 0:
				break


#Room cells free for furniture minus the articulation points, with that point set: {"ap", "free"}.
static func _free_non_articulation(area: BattlefieldArea, rect: Rect2i, f: int) -> Dictionary:
	var ap_set: Dictionary = _find_articulation_points(_room_walkable_set(area, rect, f))
	var free: Array[Vector3i] = _room_free_cells(area, rect, f)
	return {"ap": ap_set, "free": free.filter(func(p: Vector3i) -> bool: return not ap_set.has(p))}


static func _ap_dfs(u: Vector3i, parent: Vector3i, cell_set: Dictionary, visited: Dictionary, disc: Dictionary, low: Dictionary, ap: Dictionary, timer: Array) -> void:
	visited[u] = true
	disc[u] = timer[0]
	low[u] = timer[0]
	timer[0] += 1
	var child_count: int = 0
	for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		var v := u + off
		if not cell_set.has(v):
			continue
		if not visited.has(v):
			child_count += 1
			_ap_dfs(v, u, cell_set, visited, disc, low, ap, timer)
			low[u] = mini(low[u] as int, low[v] as int)
			if parent == Vector3i(-9999, -9999, -9999) and child_count > 1:
				ap[u] = true
			if parent != Vector3i(-9999, -9999, -9999) and (low[v] as int) >= (disc[u] as int):
				ap[u] = true
		elif v != parent:
			low[u] = mini(low[u] as int, disc[v] as int)


static func _find_articulation_points(cell_set: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var disc: Dictionary = {}
	var low: Dictionary = {}
	var ap: Dictionary = {}
	var timer: Array = [0]
	for node: Variant in cell_set.keys():
		var u := node as Vector3i
		if not visited.has(u):
			_ap_dfs(u, Vector3i(-9999, -9999, -9999), cell_set, visited, disc, low, ap, timer)
	return ap


static func _room_free_cells(area: BattlefieldArea, rect: Rect2i, f: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for ix: int in range(rect.position.x, rect.end.x):
		for iy: int in range(rect.position.y, rect.end.y):
			var p3 := Vector3i(ix, iy, f)
			if area._obs_map.has(p3) or area.reserved_corridor_cells.has(Vector2i(ix, iy)):
				continue
			var near_door := false
			for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
				if (area._obs_map.get(p3 + off, {}) as Dictionary).get("cell_type", "") == "door":
					near_door = true
					break
			if not near_door:
				result.append(p3)
	return result


static func _room_walkable_set(area: BattlefieldArea, rect: Rect2i, f: int) -> Dictionary:
	var result: Dictionary = {}
	for ix: int in range(rect.position.x, rect.end.x):
		for iy: int in range(rect.position.y, rect.end.y):
			var p3 := Vector3i(ix, iy, f)
			var ct: String = (area._obs_map.get(p3, {}) as Dictionary).get("cell_type", "") as String
			if not ct in ["wall", "fence", "furniture", "reserved"]:
				result[p3] = true
	return result


static func _wall_adj_set(area: BattlefieldArea, free: Array[Vector3i]) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		for off: Vector3i in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]:
			if (area._obs_map.get(p + off, {}) as Dictionary).get("cell_type", "") == "wall":
				result[p] = true
				break
	return result


static func _corner_set(area: BattlefieldArea, free: Array[Vector3i], wadj: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		if not wadj.has(p):
			continue
		var has_nx: bool = (area._obs_map.get(p + Vector3i(-1, 0, 0), {}) as Dictionary).get("cell_type", "") == "wall"
		var has_px: bool = (area._obs_map.get(p + Vector3i(1, 0, 0), {}) as Dictionary).get("cell_type", "") == "wall"
		var has_ny: bool = (area._obs_map.get(p + Vector3i(0, -1, 0), {}) as Dictionary).get("cell_type", "") == "wall"
		var has_py: bool = (area._obs_map.get(p + Vector3i(0, 1, 0), {}) as Dictionary).get("cell_type", "") == "wall"
		if (has_nx or has_px) and (has_ny or has_py):
			result[p] = true
	return result


static func _window_adj_set(area: BattlefieldArea, free: Array[Vector3i]) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		for off: Vector3i in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]:
			var e: Dictionary = area._obs_map.get(p + off, {}) as Dictionary
			var d2: ObstacleData = e.get("data", null)
			if d2 != null and d2.obstacle_name == "Window":
				result[p] = true
				break
	return result


static func _room_still_connected(area: BattlefieldArea, rect: Rect2i, f: int) -> bool:
	var walkable := _room_walkable_set(area, rect, f)
	if walkable.is_empty():
		return false
	var start: Vector3i = walkable.keys()[0] as Vector3i
	var visited: Dictionary = {}
	var stack: Array[Vector3i] = [start]
	visited[start] = true
	while not stack.is_empty():
		var curr: Vector3i = stack.pop_back() as Vector3i
		for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			var nb := curr + off
			if walkable.has(nb) and not visited.has(nb):
				visited[nb] = true
				stack.append(nb)
	return visited.size() == walkable.size()


static func _room_accessible_from_doors(area: BattlefieldArea, rect: Rect2i, f: int) -> bool:
	var walkable := _room_walkable_set(area, rect, f)
	if walkable.is_empty():
		return true
	var entry_points: Array[Vector3i] = []
	for p: Vector3i in walkable.keys():
		for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			if (area._obs_map.get(p + off, {}) as Dictionary).get("cell_type", "") == "door":
				entry_points.append(p)
				break
	if entry_points.is_empty():
		return _room_still_connected(area, rect, f)
	var visited: Dictionary = {}
	var stack: Array[Vector3i] = []
	for ep: Vector3i in entry_points:
		if not visited.has(ep):
			visited[ep] = true
			stack.append(ep)
	while not stack.is_empty():
		var curr: Vector3i = stack.pop_back() as Vector3i
		for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			var nb := curr + off
			if walkable.has(nb) and not visited.has(nb):
				visited[nb] = true
				stack.append(nb)
	#Parts that only touch a shared door are unreachable from the corridor, so the room must stay one region.
	return visited.size() == walkable.size() and _room_still_connected(area, rect, f)


static func _footprint_free(area: BattlefieldArea, rect: Rect2i, origin: Vector3i, pw: int, ph: int, ap_set: Dictionary) -> bool:
	for dx: int in range(pw):
		for dy: int in range(ph):
			var p := Vector3i(origin.x + dx, origin.y + dy, origin.z)
			if not rect.has_point(Vector2i(p.x, p.y)):
				return false
			if area._obs_map.has(p) or area.reserved_corridor_cells.has(Vector2i(p.x, p.y)):
				return false
			if ap_set.has(p):
				return false
			for off: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
				if (area._obs_map.get(p + off, {}) as Dictionary).get("cell_type", "") == "door":
					return false
	return true


#Wall hugging footprints for one furniture size; restrict, when non empty, limits the cells scanned.
static func _wall_candidates(area: BattlefieldArea, rect: Rect2i, free: Array[Vector3i], ceil_x: int,
		ceil_y: int, kinds: Array, ap_set: Dictionary, restrict: Dictionary) -> Array:
	var out: Array = []
	var pw_wide: int = maxi(ceil_x, ceil_y)
	var ph_wide: int = mini(ceil_x, ceil_y)
	var limited: bool = not restrict.is_empty()
	for p: Vector3i in free:
		if limited and not restrict.has(p):
			continue
		var has_ny: bool = (area._obs_map.get(p + Vector3i(0, -1, 0), {}) as Dictionary).get("cell_type", "") in kinds
		var has_py: bool = (area._obs_map.get(p + Vector3i(0, 1, 0), {}) as Dictionary).get("cell_type", "") in kinds
		var has_nx: bool = (area._obs_map.get(p + Vector3i(-1, 0, 0), {}) as Dictionary).get("cell_type", "") in kinds
		var has_px: bool = (area._obs_map.get(p + Vector3i(1, 0, 0), {}) as Dictionary).get("cell_type", "") in kinds
		if has_ny:
			var o := Vector3i(p.x, p.y, p.z)
			if _footprint_free(area, rect, o, pw_wide, ph_wide, ap_set):
				out.append([o, pw_wide, ph_wide])
		if has_py:
			var o := Vector3i(p.x, p.y - ph_wide + 1, p.z)
			if _footprint_free(area, rect, o, pw_wide, ph_wide, ap_set):
				out.append([o, pw_wide, ph_wide])
		if has_nx:
			var o := Vector3i(p.x, p.y, p.z)
			if _footprint_free(area, rect, o, ph_wide, pw_wide, ap_set):
				out.append([o, ph_wide, pw_wide])
		if has_px:
			var o := Vector3i(p.x - ph_wide + 1, p.y, p.z)
			if _footprint_free(area, rect, o, ph_wide, pw_wide, ap_set):
				out.append([o, ph_wide, pw_wide])
	return out


static func _place_pref(
	area: BattlefieldArea,
	obs_name: String,
	free: Array[Vector3i],
	rect: Rect2i,
	_f: int,
	wadj: Dictionary,
	corners: Dictionary,
	wadjwin: Dictionary,
	obj_adj: Dictionary,
	placed_alike: Dictionary,
	ap_set: Dictionary
) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(obs_name)
	if d == null:
		return false
	var pref: String = d.preferred_position
	var ceil_x: int = ceili(d.size_x)
	var ceil_y: int = ceili(d.size_y)
	var no_fallback: bool = pref == "Align Alike" and placed_alike.has(obs_name)
	var narrow_short: int = mini(rect.size.x, rect.size.y) - 2
	var force_wall: bool = (pref == "Anywhere" or pref == "") and (mini(ceil_x, ceil_y) >= maxi(1, narrow_short))
	var candidates: Array = []

	match pref:
		"Corner":
			for p: Vector3i in free:
				if not corners.has(p):
					continue
				var has_nx: bool = (area._obs_map.get(p + Vector3i(-1, 0, 0), {}) as Dictionary).get("cell_type", "") == "wall"
				var has_ny: bool = (area._obs_map.get(p + Vector3i(0, -1, 0), {}) as Dictionary).get("cell_type", "") == "wall"
				var orient_list: Array = [[ceil_x, ceil_y]] if ceil_x == ceil_y else [[ceil_x, ceil_y], [ceil_y, ceil_x]]
				for orient in orient_list:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					var ox: int = p.x if has_nx else (p.x - pw + 1)
					var oy: int = p.y if has_ny else (p.y - ph + 1)
					var origin := Vector3i(ox, oy, p.z)
					if _footprint_free(area, rect, origin, pw, ph, ap_set):
						candidates.append([origin, pw, ph])
		"Any Wall":
			candidates = _wall_candidates(area, rect, free, ceil_x, ceil_y, ["wall"], ap_set, wadj)
		"Window":
			for p: Vector3i in free:
				if not wadjwin.has(p):
					continue
				var orient_list: Array = [[ceil_x, ceil_y]] if ceil_x == ceil_y else [[ceil_x, ceil_y], [ceil_y, ceil_x]]
				for orient in orient_list:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					if _footprint_free(area, rect, p, pw, ph, ap_set):
						candidates.append([p, pw, ph])
						break
		"By Object", "On Object":
			for p: Vector3i in free:
				if not obj_adj.has(p):
					continue
				var src: Dictionary = obj_adj[p] as Dictionary if obj_adj[p] is Dictionary else {}
				var src_pw: int = src.get("pw", 1) as int
				var src_ph: int = src.get("ph", 1) as int
				var orders: Array
				if ceil_x == ceil_y:
					orders = [[ceil_x, ceil_y]]
				elif src_pw > src_ph:
					orders = [[maxi(ceil_x, ceil_y), mini(ceil_x, ceil_y)], [mini(ceil_x, ceil_y), maxi(ceil_x, ceil_y)]]
				elif src_ph > src_pw:
					orders = [[mini(ceil_x, ceil_y), maxi(ceil_x, ceil_y)], [maxi(ceil_x, ceil_y), mini(ceil_x, ceil_y)]]
				else:
					orders = [[ceil_x, ceil_y], [ceil_y, ceil_x]]
				for orient in orders:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					if _footprint_free(area, rect, p, pw, ph, ap_set):
						candidates.append([p, pw, ph])
						break
		"Align Alike":
			if not placed_alike.has(obs_name):
				for p: Vector3i in free:
					if _footprint_free(area, rect, p, ceil_x, ceil_y, ap_set):
						candidates.append([p, ceil_x, ceil_y])
			else:
				var cset: Dictionary = {}
				for entry in (placed_alike[obs_name] as Array):
					var pp: Vector3i = (entry as Array)[0] as Vector3i
					var epw: int = (entry as Array)[1] as int
					var eph: int = (entry as Array)[2] as int
					var mx: int = rect.position.x + rect.end.x - pp.x - epw
					var my: int = rect.position.y + rect.end.y - pp.y - eph
					cset[Vector3i(mx, pp.y, pp.z)] = [epw, eph]
					cset[Vector3i(pp.x, my, pp.z)] = [epw, eph]
					cset[Vector3i(mx, my, pp.z)] = [epw, eph]
				for p: Vector3i in free:
					if cset.has(p):
						var dims: Array = cset[p] as Array
						var pw: int = dims[0] as int
						var ph: int = dims[1] as int
						if _footprint_free(area, rect, p, pw, ph, ap_set):
							candidates.append([p, pw, ph])
		_:
			if force_wall:
				candidates = _wall_candidates(area, rect, free, ceil_x, ceil_y, ["wall", "fence"],
					ap_set, {})
			else:
				for p: Vector3i in free:
					if _footprint_free(area, rect, p, ceil_x, ceil_y, ap_set):
						candidates.append([p, ceil_x, ceil_y])

	if candidates.is_empty():
		if no_fallback or force_wall:
			return false
		for p: Vector3i in free:
			if _footprint_free(area, rect, p, ceil_x, ceil_y, ap_set):
				candidates.append([p, ceil_x, ceil_y])
		if candidates.is_empty():
			return false

	candidates.shuffle()
	for cand: Array in candidates:
		var pos: Vector3i = cand[0] as Vector3i
		var pw: int = cand[1] as int
		var ph: int = cand[2] as int
		var obs := {"pos": pos, "size": pw * ph, "data": d, "cell_type": "furniture", "pw": pw, "ph": ph, "floor": pos.z}
		_add_obstacle(area, obs, pos)
		var extra_cells: Array[Vector3i] = []
		for dx: int in range(pw):
			for dy: int in range(ph):
				if dx == 0 and dy == 0:
					continue
				var extra := Vector3i(pos.x + dx, pos.y + dy, pos.z)
				if not area._obs_map.has(extra):
					area._obs_map[extra] = {"cell_type": "reserved", "floor": pos.z}
					extra_cells.append(extra)
		if not _room_accessible_from_doors(area, rect, pos.z):
			area.obstacles.pop_back()
			area._obs_map.erase(pos)
			for ep: Vector3i in extra_cells:
				area._obs_map.erase(ep)
			continue
		for dx: int in range(-1, pw + 1):
			obj_adj[Vector3i(pos.x + dx, pos.y - 1, pos.z)] = {"pw": pw, "ph": ph}
			obj_adj[Vector3i(pos.x + dx, pos.y + ph, pos.z)] = {"pw": pw, "ph": ph}
		for dy: int in range(ph):
			obj_adj[Vector3i(pos.x - 1, pos.y + dy, pos.z)] = {"pw": pw, "ph": ph}
			obj_adj[Vector3i(pos.x + pw, pos.y + dy, pos.z)] = {"pw": pw, "ph": ph}
		if pref == "Align Alike":
			if not placed_alike.has(obs_name):
				placed_alike[obs_name] = []
			(placed_alike[obs_name] as Array).append([pos, pw, ph])
		return true
	return false


static func _assign_spawns(area: BattlefieldArea, ctx: GenerationContext, bld_x: int, floor_w: int, floor_d: int, top_y: int) -> void:
	var max_team: int = maxi(ctx.team_size_a, ctx.team_size_b)
	area.spawn_radius = maxf(3.0, float(max_team))
	area.spawn_radius = minf(area.spawn_radius, minf(float(floor_w), float(floor_d)) / 2.0)

	var half: int = maxi(1, floor_w >> 1)
	area.spawn_center_a = Vector2i(bld_x + 1 + (half >> 1), top_y + 1 + (floor_d >> 1))
	area.spawn_center_b = Vector2i(bld_x + 1 + half + ((floor_w - half) >> 1), top_y + 1 + (floor_d >> 1))
	for ix: int in range(bld_x + 1, bld_x + 1 + half):
		for iy: int in range(top_y + 1, top_y + 1 + floor_d):
			var p := Vector2i(ix, iy)
			if not area._obs_map.has(Vector3i(ix, iy, 0)):
				area.spawn_zone_a[p] = true
	for ix: int in range(bld_x + 1 + half, bld_x + floor_w + 1):
		for iy: int in range(top_y + 1, top_y + 1 + floor_d):
			var p := Vector2i(ix, iy)
			if not area._obs_map.has(Vector3i(ix, iy, 0)):
				area.spawn_zone_b[p] = true


static func _place_exterior_rooms(area: BattlefieldArea, f: int, bld_x: int, top_y: int, floor_w: int, floor_d: int, area_data: Dictionary, wall_data: ObstacleData, fh: int, street: int, all_rooms: Array[Dictionary]) -> void:
	if f < 0:
		return
	var eligible: Array[ObstacleData] = DataManager.get_exterior_rooms_for_floor(area_data, f)
	if eligible.is_empty():
		return
	eligible.shuffle()
	var room: ObstacleData = eligible[0]
	var max_ext_w: int = street - 1
	if max_ext_w < 2:
		return
	var ext_w: int = randi_range(2, max_ext_w)
	var use_right: bool = (f == 0) or (randi() % 2 == 0)
	var fence_data: ObstacleData = DataManager.get_obstacle_by_name("Fence")
	if fence_data == null:
		fence_data = wall_data

	var bld_wall_x: int
	var ix_start: int
	var ix_end: int
	var far_wall_x: int
	if use_right:
		bld_wall_x = bld_x + floor_w + 1
		ix_start = bld_wall_x + 1
		ix_end = ix_start + ext_w
		far_wall_x = ix_end
	else:
		bld_wall_x = bld_x
		ix_end = bld_wall_x
		ix_start = ix_end - ext_w
		far_wall_x = ix_start - 1

	for ix: int in range(ix_start, ix_end):
		for iy: int in range(top_y + 1, top_y + floor_d + 1):
			area.building_interiors[Vector3i(ix, iy, f)] = true

	var w_x_lo: int = mini(far_wall_x, ix_start)
	var w_x_hi: int = maxi(far_wall_x, ix_end - 1)
	for ix: int in range(w_x_lo, w_x_hi + 1):
		_place_fence_if_empty(area, Vector3i(ix, top_y, f), fence_data, f, "h")
		_place_fence_if_empty(area, Vector3i(ix, top_y + floor_d + 1, f), fence_data, f, "h")

	var door_y: int = top_y + 2 + (floor_d >> 1)
	for iy: int in range(top_y, top_y + floor_d + 2):
		if f == 0 and iy == door_y:
			continue
		_place_fence_if_empty(area, Vector3i(far_wall_x, iy, f), fence_data, f)

	var adj_x: int = bld_wall_x + (-1 if use_right else 1)
	if area._obs_map.has(Vector3i(adj_x, door_y, f)):
		var mid_y: int = door_y
		var best_dist: int = floor_d + 1
		for try_y: int in range(top_y + 1, top_y + floor_d + 1):
			if not area._obs_map.has(Vector3i(adj_x, try_y, f)):
				var dist: int = absi(try_y - mid_y)
				if dist < best_dist:
					best_dist = dist
					door_y = try_y
	var door_data: ObstacleData = BuildingGenerator._get_door_template()
	_place_door_at(area, Vector3i(bld_wall_x, door_y, f), door_data, fh)

	var rect := Rect2i(ix_start, top_y + 1, ext_w, floor_d)
	area.interior_rooms.append({"rect": rect, "name": room.obstacle_name, "floor": f})
	all_rooms.append({"room": room, "rect": rect, "floor": f})


static func _place_fence_if_empty(area: BattlefieldArea, pos: Vector3i, fence_data: ObstacleData, floor_num: int = -999, orientation: String = "v") -> void:
	if area._obs_map.has(pos):
		return
	var obs := {"pos": pos, "size": fence_data.size if fence_data != null else 2, "data": fence_data, "cell_type": "fence", "floor": floor_num, "orientation": orientation}
	_add_obstacle(area, obs, pos)


#A divider door placed on the next column's wall row faces a wall; it slides along its wall to a row open on both sides.
static func _fix_blind_doors(area: BattlefieldArea) -> void:
	var doors: Array[Dictionary] = []
	for obs: Dictionary in area.obstacles:
		if obs.get("cell_type", "") == "door" and typeof(obs.get("pos")) == TYPE_VECTOR3I:
			doors.append(obs)
	for door: Dictionary in doors:
		var pos: Vector3i = door["pos"] as Vector3i
		var orientation: String = door.get("orientation", "v") as String
		var across := Vector3i(1, 0, 0) if orientation == "v" else Vector3i(0, 1, 0)
		var along := Vector3i(0, 1, 0) if orientation == "v" else Vector3i(1, 0, 0)
		if not _door_is_blind(area, pos, across):
			continue
		for step: int in [1, -1, 2, -2, 3, -3]:
			var cand: Vector3i = pos + along * step
			var wall: Dictionary = area._obs_map.get(cand, {}) as Dictionary
			if wall.get("cell_type", "") != "wall" or not _door_sides_open(area, cand, across):
				continue
			var fh: int = int(door.get("height", 4.0) as float)
			var door_data: ObstacleData = door.get("data") as ObstacleData
			var wall_data: ObstacleData = wall.get("data") as ObstacleData
			var wall_sz: int = wall.get("size", 1) as int
			_clear_cell(area, pos)
			_place_wall_if_empty(area, pos, wall_sz, wall_data, fh)
			area.building_interiors.erase(pos)
			_place_door_at(area, cand, door_data, fh, orientation)
			area.generation_log.append("[GEN] blind door F%d (%d,%d) moved to (%d,%d)" % [pos.z, pos.x, pos.y, cand.x, cand.y])
			break


static func _door_is_blind(area: BattlefieldArea, pos: Vector3i, across: Vector3i) -> bool:
	var walls: int = 0
	var open: int = 0
	for side: Vector3i in [pos - across, pos + across]:
		if (area._obs_map.get(side, {}) as Dictionary).get("cell_type", "") == "wall":
			walls += 1
		elif not area._obs_map.has(side) and area.building_interiors.has(side):
			open += 1
	return walls == 1 and open == 1


static func _door_sides_open(area: BattlefieldArea, pos: Vector3i, across: Vector3i) -> bool:
	for side: Vector3i in [pos - across, pos + across]:
		if area._obs_map.has(side) or not area.building_interiors.has(side):
			return false
	return true


static func _place_wall_if_empty(area: BattlefieldArea, pos: Vector3i, wall_sz: int, wall_data: ObstacleData, fh: int) -> void:
	if area._obs_map.has(pos):
		return
	var obs := {"pos": pos, "size": wall_sz, "data": wall_data, "cell_type": "wall", "height": float(fh), "floor": pos.z}
	_add_obstacle(area, obs, pos)


#Appends an obstacle dict to the area and mirrors it into the obstacle map.
static func _add_obstacle(area: BattlefieldArea, obs: Dictionary, pos: Vector3i) -> void:
	area.obstacles.append(obs)
	area._obs_map[pos] = obs


static func _clear_cell(area: BattlefieldArea, pos: Vector3i) -> void:
	if not area._obs_map.has(pos):
		return
	area._obs_map.erase(pos)
	for i: int in range(area.obstacles.size() - 1, -1, -1):
		if (area.obstacles[i]["pos"] as Vector3i) == pos:
			area.obstacles.remove_at(i)
			break


static func _replace_wall_with(area: BattlefieldArea, pos: Vector3i, obs: Dictionary) -> void:
	if area._obs_map.has(pos):
		if (area._obs_map[pos] as Dictionary).get("cell_type", "") != "wall":
			return
		_clear_cell(area, pos)
	_add_obstacle(area, obs, pos)


static func _place_windows(area: BattlefieldArea, fp: int, fm: int, bld_x: int, floor_w: int, floor_d: int, window_data: ObstacleData, stairwell_xs: Dictionary, top_y: int, fh: int) -> void:
	if window_data == null:
		return
	var win_sz: int = window_data.size
	var stairwell_x_set: Dictionary = {}
	for v: Variant in stairwell_xs.values():
		stairwell_x_set[v as int] = true
	for f: int in range(fp, -(fm + 1), -1):
		if f < 0:
			continue
		var mid_y: int = top_y + 1 + (floor_d >> 1)
		for wx: int in [bld_x, bld_x + floor_w + 1]:
			for wy: int in range(top_y + 1, top_y + floor_d + 1):
				var dist: int = absi(wy - mid_y)
				if dist % 2 != 0:
					continue
				var adj_door := false
				for adj_wy: int in [wy - 1, wy + 1]:
					if (area._obs_map.get(Vector3i(wx, adj_wy, f), {}) as Dictionary).get("cell_type", "") == "door":
						adj_door = true
						break
				if adj_door:
					continue
				var int_x: int = wx + 1 if wx == bld_x else wx - 1
				if (area._obs_map.get(Vector3i(int_x, wy, f), {}) as Dictionary).get("cell_type", "") == "wall":
					continue
				var pos := Vector3i(wx, wy, f)
				var w_obs := {"pos": pos, "size": win_sz, "data": window_data, "cell_type": "window", "orientation": "v",
					"height": float(fh), "floor": f}
				_replace_wall_with(area, pos, w_obs)
	#north wall of the top floor and south wall shared by all floors are at fixed Y
	var ns_wall_ys: Array[int] = [top_y, top_y + floor_d + 1]
	for wy: int in ns_wall_ys:
		var candidates: Array[int] = []
		for wx: int in range(bld_x + 1, bld_x + floor_w + 1):
			if not stairwell_x_set.has(wx):
				candidates.append(wx)
		if candidates.is_empty():
			continue
		var mid_x: int = bld_x + 1 + (floor_w >> 1)
		for f: int in range(fp, -(fm + 1), -1):
			if f < 0:
				continue
			for wx: int in candidates:
				var dist: int = absi(wx - mid_x)
				if dist % 2 != 0:
					continue
				var adj_door := false
				for adj_wx: int in [wx - 1, wx + 1]:
					if (area._obs_map.get(Vector3i(adj_wx, wy, f), {}) as Dictionary).get("cell_type", "") == "door":
						adj_door = true
						break
				if adj_door:
					continue
				var int_y: int = wy + 1 if wy == top_y else wy - 1
				if (area._obs_map.get(Vector3i(wx, int_y, f), {}) as Dictionary).get("cell_type", "") == "wall":
					continue
				var pos := Vector3i(wx, wy, f)
				var w_obs := {"pos": pos, "size": win_sz, "data": window_data, "cell_type": "window", "orientation": "h",
					"height": float(fh), "floor": f}
				_replace_wall_with(area, pos, w_obs)


#Cuts the two street level doors into the end walls and returns the row they share.
static func _place_entrance_doors(area: BattlefieldArea, bld_x: int, top_y: int, floor_w: int,
		floor_d: int, fh: int, num_floors: int) -> int:
	var ent_y: int = _entrance_row(area, top_y, floor_d, fh, num_floors)
	var ent_door: ObstacleData = BuildingGenerator._get_door_template()
	_place_door_at(area, Vector3i(bld_x, ent_y, 0), ent_door, fh)
	_clear_cell(area, Vector3i(bld_x + 1, ent_y, 0))
	var exit_x: int = bld_x + floor_w + 1
	_place_door_at(area, Vector3i(exit_x, ent_y, 0), ent_door, fh)
	_clear_cell(area, Vector3i(exit_x - 1, ent_y, 0))
	return ent_y


#Chooses the shared stair columns, builds the runs and reserves both columns on every floor.
static func _build_stairwells(area: BattlefieldArea, floor_v_cors: Dictionary, fp: int, fm: int,
		bld_x: int, floor_w: int, floor_d: int, top_y: int, stairs_data: ObstacleData,
		stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary) -> void:
	var stair_pair: Array[int] = _pick_stair_columns(area, floor_v_cors, fp, fm, bld_x, floor_w,
		top_y, floor_d, stairwell_xs.get(fp, bld_x + 1) as int, stairwell_adj_xs.get(fp, bld_x + 2) as int)
	for f: int in range(fp, -fm, -1):
		stairwell_xs[f] = stair_pair[0]
		stairwell_adj_xs[f] = stair_pair[1]
	_place_stairwells(area, fp, fm, bld_x, floor_w, floor_d, stairs_data, stairwell_xs, stairwell_adj_xs, top_y)
	for stair_f: int in stairwell_xs.keys():
		for sw_x: int in stair_pair:
			for affected_f: int in [stair_f, stair_f - 1]:
				if not area.interior_floor_elevations.has(affected_f):
					continue
				for iy: int in range(top_y + 1, top_y + floor_d + 1):
					var p := Vector3i(sw_x, iy, affected_f)
					if area._obs_map.has(p):
						continue
					if area.stair_run_cells.has(p):
						area._obs_map[p] = {"cell_type": "stair_run", "floor": affected_f}
					else:
						area._obs_map[p] = {"cell_type": "reserved_stairwell", "floor": affected_f}


#Turns the cell just inside each entrance into a door or open floor.
static func _open_entrance_cells(area: BattlefieldArea, bld_x: int, floor_w: int, ent_y: int,
		fh: int) -> void:
	var ent_rx: int = bld_x + floor_w + 1
	var _edt := BuildingGenerator._get_door_template()
	var _el := Vector3i(bld_x + 1, ent_y, 0)
	if (area._obs_map.get(_el, {}) as Dictionary).get("cell_type", "") == "wall":
		_place_door_at(area, _el, _edt, fh, "h")
	else:
		_clear_cell(area, _el)
		area.building_interiors[_el] = true
	var _er := Vector3i(ent_rx - 1, ent_y, 0)
	if (area._obs_map.get(_er, {}) as Dictionary).get("cell_type", "") == "wall":
		_place_door_at(area, _er, _edt, fh, "h")
	else:
		_clear_cell(area, _er)
		area.building_interiors[_er] = true


#Writes the interior header lines to the generation log and prints the total.
static func _log_generation(area: BattlefieldArea, total_ms: int, num_floors: int, floor_w: int,
		fh: int, floor_d: int) -> void:
	area.generation_log.append("Area: %s  terrain: %s" % [area.area_name, BattlefieldArea.UNEVENNESS_NAMES[6]])
	area.generation_log.append("[GEN] interior floors: %d  floor_w: %d  fh: %d  floor_d: %d  map: %dx%d" % [
		num_floors, floor_w, fh, floor_d, area.width, area.length])
	area.generation_log.append("[GEN] TOTAL: %dms  -  %s" % [total_ms, area.to_header_string()])
	print("[GEN] interior TOTAL: %dms  -  %s" % [total_ms, area.to_header_string()])


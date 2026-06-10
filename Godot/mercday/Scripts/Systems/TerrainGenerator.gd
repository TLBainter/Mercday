class_name TerrainGenerator


static func generate(area: BattlefieldArea) -> void:
	match area.unevenness:
		0: _gen_flat(area)
		1: _gen_gentle(area)
		2: _gen_hilly(area)
		3: _gen_rough(area)
		4: _gen_extreme(area)
		5: _gen_mountainous(area)
	if area.unevenness < 6:
		for _jcell: Vector2i in area.spawn_zone_a.keys():
			area.jagged_cells.erase(_jcell)
		for _jcell: Vector2i in area.spawn_zone_b.keys():
			area.jagged_cells.erase(_jcell)


static func _gen_flat(area: BattlefieldArea) -> void:
	var h := BattlefieldArea.UNEVENNESS_RANGE[0]
	_seed_peaks(area, randi_range(2, 4), h, 8.0, 15.0)
	_clamp_all(area, h)
	for _i: int in range(randi_range(5, 8)):
		smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)


static func _gen_gentle(area: BattlefieldArea) -> void:
	var h := BattlefieldArea.UNEVENNESS_RANGE[1]
	_seed_peaks(area, randi_range(3, 5), h, 5.0, 10.0)
	_clamp_all(area, h)
	for _i: int in range(randi_range(3, 5)):
		smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)


static func _gen_hilly(area: BattlefieldArea) -> void:
	var h := BattlefieldArea.UNEVENNESS_RANGE[2]
	var buf := BattlefieldArea.SPAWN_BUFFER
	for _i: int in range(randi_range(3, 7)):
		var hx := randi() % area.width
		var hy := randi_range(buf, area.length - buf - 1)
		var peak := randf_range(2.0, 5.0)
		var radius := randf_range(4.0, 8.0)
		_add_peak(area, hx, hy, peak, radius)
		for _s: int in range(randi_range(1, 2)):
			_add_peak(area,
				hx + randi_range(-3, 3), hy + randi_range(-3, 3),
				peak * randf_range(0.4, 0.7), radius * randf_range(0.5, 0.8))
	for _i: int in range(randi_range(1, 3)):
		_add_peak(area,
			randi() % area.width, randi_range(buf, area.length - buf - 1),
			randf_range(-2.0, -0.5), randf_range(3.0, 6.0))
	_clamp_all(area, h)
	for _i: int in range(randi_range(2, 3)):
		smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)


static func _gen_rough(area: BattlefieldArea) -> void:
	var h := BattlefieldArea.UNEVENNESS_RANGE[3]
	_seed_peaks(area, randi_range(8, 14), h, 2.0, 5.0)
	_clamp_all(area, h)
	smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)


static func _gen_extreme(area: BattlefieldArea) -> void:
	var h := BattlefieldArea.UNEVENNESS_RANGE[4]
	_seed_peaks(area, randi_range(12, 18), h, 1.0, 5.0)
	_clamp_all(area, h)
	if randi() % 2 == 0:
		smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)


static func _gen_mountainous(area: BattlefieldArea) -> void:
	var base_h := BattlefieldArea.UNEVENNESS_RANGE[1]
	_seed_peaks(area, randi_range(3, 5), base_h, 5.0, 10.0)
	_clamp_all(area, base_h)
	for _i: int in range(3):
		smooth(area.terrain_heights, area.width, area.length, area.reserved_corridor_cells)
	@warning_ignore("integer_division")
	var n_mountains := randi_range(
		maxi(1, (area.width * area.length) / 600),
		maxi(2, (area.width * area.length) / 300))
	var plateau_cells: Dictionary = {}
	for _i: int in range(n_mountains):
		_place_mountain(area, plateau_cells)
	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if area.reserved_corridor_cells.has(pos):
				continue
			if area.terrain_heights.get(pos, 0.0) >= 8.0 and not plateau_cells.has(pos):
				area.jagged_cells[pos] = true


static func _place_mountain(area: BattlefieldArea, plateau_cells: Dictionary) -> void:
	var margin := BattlefieldArea.SPAWN_BUFFER + 5
	var cx := randi_range(2, area.width - 3)
	var cy := randi_range(margin, area.length - margin - 1)
	var peak_h := randf_range(10.0, 40.0)
	var base_r := peak_h * randf_range(0.4, 0.7)
	_add_mountain_peak(area, cx, cy, peak_h, base_r)
	for _s: int in range(randi_range(1, 3)):
		var angle := randf() * TAU
		var d := base_r * randf_range(0.3, 0.7)
		_add_mountain_peak(area,
			cx + int(cos(angle) * d), cy + int(sin(angle) * d),
			peak_h * randf_range(0.4, 0.75), base_r * randf_range(0.3, 0.6))
	for _p: int in range(randi_range(1, 3)):
		_carve_plateau(area, cx, cy, base_r, plateau_cells)
	for _c: int in range(randi_range(1, 3)):
		_carve_cave(area, cx, cy, base_r)


static func _add_mountain_peak(area: BattlefieldArea, cx: int, cy: int, peak: float, radius: float) -> void:
	var ri := ceili(radius)
	for y: int in range(maxi(0, cy - ri), mini(area.length, cy + ri + 1)):
		for x: int in range(maxi(0, cx - ri), mini(area.width, cx + ri + 1)):
			var pos := Vector2i(x, y)
			if area.reserved_corridor_cells.has(pos):
				continue
			var dist := Vector2(float(x - cx), float(y - cy)).length()
			if dist >= radius:
				continue
			var t := 1.0 - dist / radius
			var h_add := peak * t * t * (3.0 - 2.0 * t)
			area.terrain_heights[pos] = maxf(area.terrain_heights.get(pos, 0.0), h_add)


static func _carve_plateau(area: BattlefieldArea, cx: int, cy: int, base_r: float, plateau_cells: Dictionary) -> void:
	var buf := BattlefieldArea.SPAWN_BUFFER
	var best := Vector2i(-1, -1)
	var best_h := -999.0
	for _a: int in range(20):
		var angle := randf() * TAU
		var d := base_r * randf_range(0.2, 0.8)
		var px: int = clampi(cx + int(cos(angle) * d), 0, area.width - 1)
		var py: int = clampi(cy + int(sin(angle) * d), buf, area.length - buf - 1)
		var pos := Vector2i(px, py)
		var h: float = area.terrain_heights.get(pos, 0.0)
		if h > 1.0 and h > best_h:
			best_h = h
			best = pos
	if best.x < 0:
		return
	var pr := randi_range(1, 3)
	for dy: int in range(-pr - 1, pr + 2):
		for dx: int in range(-pr - 1, pr + 2):
			var pos := Vector2i(best.x + dx, best.y + dy)
			if pos.x < 0 or pos.x >= area.width or pos.y < 0 or pos.y >= area.length:
				continue
			if area.reserved_corridor_cells.has(pos):
				continue
			if Vector2(float(dx), float(dy)).length() <= float(pr):
				if area.terrain_heights.get(pos, 0.0) > 0.5:
					area.terrain_heights[pos] = best_h
					plateau_cells[pos] = true


static func _carve_cave(area: BattlefieldArea, cx: int, cy: int, base_r: float) -> void:
	var cave_h: float
	if randf() < 0.6:
		cave_h = randf_range(-0.5, 0.5)
	else:
		cave_h = randf_range(0.5, 3.0)
	var cave_w := maxi(1, int(base_r / 6.0))
	var wall_t := 2
	var min_wall_h := cave_h + 3.0
	var buf := BattlefieldArea.SPAWN_BUFFER
	if randi() % 2 == 0:
		var offset := randi_range(-int(base_r * 0.3), int(base_r * 0.3))
		var cave_cy: int = clampi(cy + offset, buf + 2, area.length - buf - 3)
		var wy_vals: Array[int] = [cave_cy - wall_t, cave_cy + wall_t]
		for x: int in range(area.width):
			var can := true
			for wy: int in wy_vals:
				if wy < 0 or wy >= area.length:
					can = false
					break
				if area.terrain_heights.get(Vector2i(x, wy), 0.0) < min_wall_h:
					can = false
					break
			if not can:
				continue
			for w: int in range(-cave_w, cave_w + 1):
				var cp := Vector2i(x, cave_cy + w)
				if cp.y >= 0 and cp.y < area.length and not area.reserved_corridor_cells.has(cp):
					area.terrain_heights[cp] = cave_h
	else:
		var offset := randi_range(-int(base_r * 0.3), int(base_r * 0.3))
		var cave_cx: int = clampi(cx + offset, wall_t + 1, area.width - wall_t - 2)
		var wx_vals: Array[int] = [cave_cx - wall_t, cave_cx + wall_t]
		for y: int in range(buf, area.length - buf):
			var can := true
			for wx: int in wx_vals:
				if wx < 0 or wx >= area.width:
					can = false
					break
				if area.terrain_heights.get(Vector2i(wx, y), 0.0) < min_wall_h:
					can = false
					break
			if not can:
				continue
			for w: int in range(-cave_w, cave_w + 1):
				var cp := Vector2i(cave_cx + w, y)
				if cp.x >= 0 and cp.x < area.width and not area.reserved_corridor_cells.has(cp):
					area.terrain_heights[cp] = cave_h


static func _seed_peaks(area: BattlefieldArea, count: int, h_range: Vector2, r_min: float, r_max: float) -> void:
	var buf := BattlefieldArea.SPAWN_BUFFER
	for _i: int in range(count):
		_add_peak(area,
			randi() % area.width,
			randi_range(buf, area.length - buf - 1),
			randf_range(h_range.x, h_range.y),
			randf_range(r_min, r_max))


static func _add_peak(area: BattlefieldArea, sx: int, sy: int, peak: float, radius: float) -> void:
	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if area.reserved_corridor_cells.has(pos):
				continue
			var dist := Vector2(float(x - sx), float(y - sy)).length()
			var influence := maxf(0.0, 1.0 - dist / radius)
			area.terrain_heights[pos] = area.terrain_heights.get(pos, 0.0) + peak * influence


static func _clamp_all(area: BattlefieldArea, h_range: Vector2) -> void:
	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if area.reserved_corridor_cells.has(pos):
				continue
			area.terrain_heights[pos] = clampf(area.terrain_heights.get(pos, 0.0), h_range.x, h_range.y)


static func clamp_spawn_zones(area: BattlefieldArea) -> void:
	for cell: Vector2i in area.spawn_zone_a.keys():
		if not area.reserved_corridor_cells.has(cell):
			area.terrain_heights[cell] = clampf(area.terrain_heights.get(cell, 0.0), 0.0, 0.25)
	for cell: Vector2i in area.spawn_zone_b.keys():
		if not area.reserved_corridor_cells.has(cell):
			area.terrain_heights[cell] = clampf(area.terrain_heights.get(cell, 0.0), 0.0, 0.25)
	var outer: float = area.spawn_radius + 4.0
	var ri: int = ceili(outer)
	for center: Vector2i in [area.spawn_center_a, area.spawn_center_b]:
		for dy: int in range(-ri, ri + 1):
			for dx: int in range(-ri, ri + 1):
				var dist: float = Vector2(float(dx), float(dy)).length()
				if dist <= area.spawn_radius or dist > outer:
					continue
				var cell := Vector2i(center.x + dx, center.y + dy)
				if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
					continue
				if area.spawn_zone_a.has(cell) or area.spawn_zone_b.has(cell):
					continue
				if area.reserved_corridor_cells.has(cell):
					continue
				var t: float = (dist - area.spawn_radius) / 4.0
				var max_h: float = lerpf(0.25, 2.0, t)
				area.terrain_heights[cell] = clampf(area.terrain_heights.get(cell, 0.0), 0.0, max_h)


static func smooth(terrain_heights: Dictionary, width: int, length: int, skip_cells: Dictionary = {}) -> void:
	var smoothed: Dictionary = {}
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if skip_cells.has(pos):
				smoothed[pos] = terrain_heights.get(pos, 0.0)
				continue
			var sum: float = terrain_heights.get(pos, 0.0)
			var count: int = 1
			for dir: Vector2i in cardinal:
				var nb: Vector2i = pos + dir
				if nb.x >= 0 and nb.x < width and nb.y >= 0 and nb.y < length:
					sum += terrain_heights.get(nb, 0.0)
					count += 1
			smoothed[pos] = sum / float(count)
	for key: Vector2i in smoothed.keys():
		terrain_heights[key] = smoothed[key]

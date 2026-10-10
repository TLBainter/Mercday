class_name ExteriorGenerator


static func generate_cover(area: BattlefieldArea, config: BuildingConfig = null) -> void:
	area.reset_generated_state()
	var gen_start := Time.get_ticks_msec()
	area.generation_log.append("Area: %s  terrain: %s" % [area.area_name, BattlefieldArea.UNEVENNESS_NAMES[area.unevenness]])

	area.stage("corridor_reservation", func() -> void:
		_reserve_spawn_corridors(area))

	area.stage("base_terrain", func() -> void:
		TerrainGenerator.generate(area))

	smooth_corridor_edges(area)

	var density: float = BattlefieldArea.COVER_DENSITY[area.cover_amount]
	var total_count: int = int(area.width * area.length * density)
	var terrain_count: int = int(total_count / 4.0)

	area.stage("terrain_obstacles", func() -> String:
		var placed_terrain: int = ObstacleGenerator.place_terrain_obstacles(area, terrain_count)
		return "(%d placed)" % placed_terrain)

	area.stage("terrain_effects", func() -> void:
		ObstacleGenerator.apply_terrain_effects(area))

	TerrainGenerator.clamp_spawn_zones(area)

	area.stage("buildings", func() -> void:
		BuildingGenerator.generate_buildings(area, config))

	_log_layout(area)

	area.stage("furniture", func() -> void:
		BuildingGenerator.place_furniture_in_buildings(area))

	var scatter_count: int = total_count - terrain_count
	area.stage("obstacle_placement", func() -> String:
		var placed_scatter: int = ObstacleGenerator.place_obstacles(area, scatter_count)
		return "(%d placed)" % placed_scatter)

	area.stage("stairs", func() -> void:
		_place_stairs_at_transitions(area))

	_log_approach_zones(area)

	area.stage("pathability", func() -> void:
		ensure_pathability(area))

	area.stage("spawn_connectivity", func() -> void:
		ConnectivityVerifier.carve_corridor(area))

	area.stage("pocket_removal", func() -> void:
		ConnectivityVerifier.remove_pockets(area))

	area.stage("spawn_approaches", func() -> void:
		ConnectivityVerifier.verify_spawn_approaches(area))

	area.stage("fly_only_cells", func() -> String:
		classify_fly_only_cells(area)
		return "(%d classified)" % area.fly_only_cells.size())

	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()

	var total_ms := Time.get_ticks_msec() - gen_start
	area.log_total(total_ms)


#Spawn centers and every placed building, logged once the buildings stage has run.
static func _log_layout(area: BattlefieldArea) -> void:
	area.generation_log.append("Spawn centers: Team-0=(%d,%d) r=%.1f  Team-1=(%d,%d) r=%.1f" % [
		area.spawn_center_a.x, area.spawn_center_a.y, area.spawn_radius,
		area.spawn_center_b.x, area.spawn_center_b.y, area.spawn_radius])
	if area.building_data.is_empty():
		area.generation_log.append("Buildings placed: 0")
	else:
		area.generation_log.append("Buildings placed: %d" % area.building_data.size())
		for i: int in range(area.building_data.size()):
			var b: Dictionary = area.building_data[i]
			var rect: Rect2i = b["rect"] as Rect2i
			area.generation_log.append("  Building %d [%s]: pos=(%d,%d) size=%dx%d" % [
				i + 1, b.get("name", "?"),
				rect.position.x, rect.position.y, rect.size.x, rect.size.y])


#Logs whether either team is walled in within the clear margin around its spawn.
static func _log_approach_zones(area: BattlefieldArea) -> void:
	var az_a_blocked: bool = spawn_exit_blocked(area, area.spawn_center_a, area.spawn_zone_a)
	var az_b_blocked: bool = spawn_exit_blocked(area, area.spawn_center_b, area.spawn_zone_b)
	if not az_a_blocked and not az_b_blocked:
		area.log_gen("[GEN] approach_zone: OK")
	else:
		var az_parts: Array[String] = []
		if az_a_blocked:
			az_parts.append("Team-0")
		if az_b_blocked:
			az_parts.append("Team-1")
		var az_msg: String = "[GEN] approach_zone: BLOCKED (%s)" % ", ".join(az_parts)
		area.log_gen(az_msg)


static func _reserve_spawn_corridors(area: BattlefieldArea) -> void:
	area.reserved_corridor_cells.clear()
	area.gate_cells.clear()
	var difficulty: int = area.unevenness + area.cover_amount
	var map_area: int = area.width * area.length
	var max_width: int = 1 if map_area < 600 else (2 if map_area < 1500 else 3)
	if difficulty <= 1:
		area.path_width = min(3, max_width)
	elif difficulty <= 4:
		area.path_width = min(2, max_width)
	else:
		area.path_width = 1
	var max_paths: int = clampi(1 + int(map_area / 600.0), 1, 3)
	if area.unevenness >= 4:
		max_paths = mini(max_paths, 2)
	var fork_count: int = randi_range(0, max_paths - 1)

	var delta := Vector2(float(area.spawn_center_b.x - area.spawn_center_a.x),
		float(area.spawn_center_b.y - area.spawn_center_a.y))
	var perp := Vector2(-delta.normalized().y, delta.normalized().x)
	var max_offset: float = minf(float(area.width), float(area.length)) * 0.3

	var num_waypoints: int = randi_range(2, 5)
	var waypoints: Array[Vector2i] = [area.spawn_center_a]
	for i: int in range(num_waypoints):
		var t: float = float(i + 1) / float(num_waypoints + 1)
		var base := Vector2(float(area.spawn_center_a.x), float(area.spawn_center_a.y)) + delta * t
		var offset: float = randf_range(-max_offset, max_offset)
		waypoints.append(Vector2i(
			clampi(int(base.x + perp.x * offset), 0, area.width - 1),
			clampi(int(base.y + perp.y * offset), 0, area.length - 1)))
	waypoints.append(area.spawn_center_b)

	for i: int in range(waypoints.size() - 1):
		_carve_path_segment(area, waypoints[i], waypoints[i + 1])

	for _f: int in range(fork_count):
		var src_idx: int = randi_range(1, waypoints.size() - 2)
		var fork_offset: float = randf_range(-max_offset * 0.5, max_offset * 0.5)
		var fork_end := Vector2i(
			clampi(int(float(area.spawn_center_b.x) + perp.x * fork_offset), 0, area.width - 1),
			clampi(int(float(area.spawn_center_b.y) + perp.y * fork_offset), 0, area.length - 1))
		_carve_path_segment(area, waypoints[src_idx], fork_end)

	area.generation_log.append("Corridor reservation: %d waypoint(s), %d fork(s), width=%d, %d cells reserved" % [
		num_waypoints, fork_count, area.path_width, area.reserved_corridor_cells.size()])


static func _carve_path_segment(area: BattlefieldArea, from_pt: Vector2i, to_pt: Vector2i) -> void:
	var hw: int = area.path_width >> 1
	var pos := from_pt
	while pos != to_pt:
		var ddx: int = to_pt.x - pos.x
		var ddy: int = to_pt.y - pos.y
		var step: Vector2i
		if ddx == 0:
			step = Vector2i(0, signi(ddy))
		elif ddy == 0:
			step = Vector2i(signi(ddx), 0)
		elif randf() < absf(float(ddx)) / (absf(float(ddx)) + absf(float(ddy))):
			step = Vector2i(signi(ddx), 0)
		else:
			step = Vector2i(0, signi(ddy))
		_stamp(area, pos, Vector2i(-step.y, step.x), hw)
		pos += step
	var end_perp := Vector2i(1, 0) if (to_pt.x - from_pt.x) == 0 else Vector2i(0, 1)
	_stamp(area, pos, end_perp, hw)


#Reserves and flattens hw cells either side of pos along perp, clamped to the map.
static func _stamp(area: BattlefieldArea, pos: Vector2i, perp: Vector2i, hw: int) -> void:
	for p: int in range(-hw, hw + 1):
		var cell := Vector2i(
			clampi(pos.x + perp.x * p, 0, area.width - 1),
			clampi(pos.y + perp.y * p, 0, area.length - 1))
		area.reserved_corridor_cells[cell] = true
		area.terrain_heights[cell] = 0.0


static func _place_stairs_at_transitions(area: BattlefieldArea) -> void:
	var stairs_template: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	if stairs_template == null:
		return
	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if area._in_spawn_zone(pos) or area.is_obstacle(pos) or area.building_interiors.has(pos):
				continue
			var qualifies := false
			for dir: Vector2i in PathCost.DIRS4:
				var nb: Vector2i = pos + dir
				if not area.in_bounds(nb):
					continue
				var h_diff: float = absf(area.get_terrain_height(nb) - area.get_terrain_height(pos))
				if h_diff > 0.25 and h_diff <= 0.5:
					qualifies = true
					break
			if qualifies and randf() < 0.4:
				var stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template, "floor": 0}
				area.add_obstacle(stair_obs, pos)


static func classify_fly_only_cells(area: BattlefieldArea) -> void:
	for y: int in range(area.length):
		for x: int in range(area.width):
			var cell := Vector2i(x, y)
			if area.jagged_cells.has(cell):
				continue
			if area._obs_map.has(cell):
				continue
			if area.reserved_corridor_cells.has(cell):
				continue
			var cell_h: float = area.get_terrain_height(cell)
			var reachable: bool = false
			for dir: Vector2i in PathCost.DIRS4:
				var nb := cell + dir
				if not area.in_bounds(nb):
					continue
				if area.jagged_cells.has(nb):
					continue
				var h_diff: float = cell_h - area.get_terrain_height(nb)
				if h_diff <= 2.0:
					reachable = true
					break
			if not reachable:
				area.fly_only_cells[cell] = true


static func smooth_corridor_edges(area: BattlefieldArea) -> void:
	for _pass: int in range(3):
		for cell: Vector2i in area.reserved_corridor_cells.keys():
			var sum: float = area.terrain_heights.get(cell, 0.0)
			var count: int = 1
			for dir: Vector2i in PathCost.DIRS4:
				var nb: Vector2i = cell + dir
				if area.in_bounds(nb):
					sum += area.terrain_heights.get(nb, 0.0)
					count += 1
			area.terrain_heights[cell] = clampf(sum / float(count), -0.1, 0.1)


static func ensure_pathability(area: BattlefieldArea) -> void:
	var skip: Dictionary = {}
	for k: Vector2i in area.reserved_corridor_cells.keys():
		skip[k] = true
	for k: Vector2i in area.jagged_cells.keys():
		skip[k] = true
	var terrain_passes := 0
	while not _is_passable(area) and terrain_passes < 5:
		TerrainGenerator.smooth(area.terrain_heights, area.width, area.length, skip)
		terrain_passes += 1


#Cardinal flood from starts over ground cells; true as soon as reached returns true for one cell.
#Steps reject a height change over 0.5, or over 0.25 onto a cell without stairs.
static func _flood(area: BattlefieldArea, starts: Array[Vector2i], reached: Callable) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for start: Vector2i in starts:
		if not visited.has(start):
			visited[start] = true
			queue.append(start)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if bool(reached.call(curr)):
			return true
		for d: Vector2i in PathCost.DIRS4:
			var nxt: Vector2i = curr + d
			if not area.in_bounds(nxt):
				continue
			if visited.has(nxt) or area.is_obstacle(nxt) or area.jagged_cells.has(nxt):
				continue
			var h_diff: float = absf(area.get_terrain_height(nxt) - area.get_terrain_height(curr))
			if h_diff > 0.5:
				continue
			if h_diff > 0.25 and not area.has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


static func _is_passable(area: BattlefieldArea) -> bool:
	var starts: Array[Vector2i] = []
	for x: int in range(area.width):
		var start := Vector2i(x, 0)
		if not area.is_obstacle(start):
			starts.append(start)
	return _flood(area, starts, func(cell: Vector2i) -> bool: return cell.y == area.length - 1)


static func spawn_exit_blocked(area: BattlefieldArea, center: Vector2i, zone: Dictionary) -> bool:
	var outer: float = area.spawn_radius + BattlefieldArea.SPAWN_CLEAR_MARGIN
	var starts: Array[Vector2i] = []
	for cell: Vector2i in zone.keys():
		if not area.is_obstacle(cell) and not area.jagged_cells.has(cell):
			starts.append(cell)
	var far := func(cell: Vector2i) -> bool:
		return Vector2(float(cell.x - center.x), float(cell.y - center.y)).length() > outer
	return not _flood(area, starts, far)


static func approach_zone_ok(area: BattlefieldArea) -> bool:
	return not spawn_exit_blocked(area, area.spawn_center_a, area.spawn_zone_a) \
		and not spawn_exit_blocked(area, area.spawn_center_b, area.spawn_zone_b)

class_name ExteriorGenerator


static func generate_cover(area: BattlefieldArea, config: BuildingConfig = null) -> void:
	area.reset_generated_state()
	var gen_start := Time.get_ticks_msec()
	area.generation_log.append("Area: %s  terrain: %s" % [area.area_name, BattlefieldArea.UNEVENNESS_NAMES[area.unevenness]])

	area.stage("corridor_reservation", func() -> void:
		_reserve_spawn_corridors(area))

	area.stage("base_terrain", func() -> void:
		TerrainGenerator.generate(area))

	area._smooth_corridor_edges()

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

	area.stage("furniture", func() -> void:
		BuildingGenerator.place_furniture_in_buildings(area))

	var scatter_count: int = total_count - terrain_count
	area.stage("obstacle_placement", func() -> String:
		var placed_scatter: int = ObstacleGenerator.place_obstacles(area, scatter_count)
		return "(%d placed)" % placed_scatter)

	area.stage("stairs", func() -> void:
		_place_stairs_at_transitions(area))

	var az_a_blocked: bool = area._spawn_exit_blocked(area.spawn_center_a, area.spawn_zone_a)
	var az_b_blocked: bool = area._spawn_exit_blocked(area.spawn_center_b, area.spawn_zone_b)
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

	area.stage("pathability", func() -> void:
		area._ensure_pathability())

	area.stage("spawn_connectivity", func() -> void:
		ConnectivityVerifier.carve_corridor(area))

	area.stage("pocket_removal", func() -> void:
		ConnectivityVerifier.remove_pockets(area))

	area.stage("spawn_approaches", func() -> void:
		ConnectivityVerifier.verify_spawn_approaches(area))

	area.stage("fly_only_cells", func() -> String:
		area._classify_fly_only_cells()
		return "(%d classified)" % area.fly_only_cells.size())

	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()

	var total_ms := Time.get_ticks_msec() - gen_start
	area.log_gen("[GEN] TOTAL: %dms  -  %s" % [total_ms, area.to_header_string()])


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
		var perp := Vector2i(-step.y, step.x)
		for p: int in range(-hw, hw + 1):
			var cell := Vector2i(
				clampi(pos.x + perp.x * p, 0, area.width - 1),
				clampi(pos.y + perp.y * p, 0, area.length - 1))
			area.reserved_corridor_cells[cell] = true
			area.terrain_heights[cell] = 0.0
		pos += step
	var end_perp := Vector2i(1, 0) if (to_pt.x - from_pt.x) == 0 else Vector2i(0, 1)
	for p: int in range(-hw, hw + 1):
		var cell := Vector2i(
			clampi(pos.x + end_perp.x * p, 0, area.width - 1),
			clampi(pos.y + end_perp.y * p, 0, area.length - 1))
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
			for dir: Vector2i in BattlefieldArea.DROP_DIRS:
				var nb: Vector2i = pos + dir
				if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
					continue
				var h_diff: float = absf(area.get_terrain_height(nb) - area.get_terrain_height(pos))
				if h_diff > 0.25 and h_diff <= 0.5:
					qualifies = true
					break
			if qualifies and randf() < 0.4:
				var stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template, "floor": 0}
				area.obstacles.append(stair_obs)
				area._obs_map[pos] = stair_obs

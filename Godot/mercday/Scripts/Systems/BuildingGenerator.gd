class_name BuildingGenerator

static var _door_template: ObstacleData


static func generate_buildings(area: BattlefieldArea, config: BuildingConfig = null) -> void:
	var forced: ObstacleData = config.forced_template if config != null else null
	var pool: Array = _filtered_pool(config)
	if forced == null and pool.is_empty():
		return
	var max_b: int
	if config != null and config.max_count >= 0:
		max_b = config.max_count
	else:
		max_b = BattlefieldArea.MAX_BUILDINGS_BY_DENSITY[area.cover_amount]
	for _i: int in range(max_b):
		var template: ObstacleData = forced if forced != null else pool[randi() % pool.size()] as ObstacleData
		place_building(area, template)


static func _filtered_pool(config: BuildingConfig) -> Array:
	var pool: Array = DataManager.building_pool.duplicate()
	if config == null:
		return pool
	if config.allowed_types.is_empty() and config.excluded_types.is_empty():
		return pool
	var filtered: Array = []
	for o: ObstacleData in pool:
		if not config.allowed_types.is_empty() and not config.allowed_types.has(o.obstacle_name):
			continue
		if config.excluded_types.has(o.obstacle_name):
			continue
		filtered.append(o)
	return filtered


static func place_building(area: BattlefieldArea, template: ObstacleData) -> bool:
	var _fw: int = maxi(2, ceili(template.size_x))
	var _fh: int = maxi(2, ceili(template.size_y))
	if _fw != _fh and randi() % 2 == 0:
		var _tmp: int = _fw
		_fw = _fh
		_fh = _tmp
	var floor_w: int = _fw
	var floor_h: int = _fh
	var outer_w: int = floor_w + 2
	var outer_h: int = floor_h + 2

	for _attempt: int in range(50):
		var tl := Vector2i(
			randi() % maxi(1, area.width - outer_w),
			BattlefieldArea.SPAWN_BUFFER + randi() % maxi(1, area.length - outer_h - BattlefieldArea.SPAWN_BUFFER * 2)
		)
		if not _footprint_clear(area, tl, outer_w, outer_h):
			continue

		if _footprint_in_keep_clear(area, tl, outer_w, outer_h):
			continue

		var nav_overlap := false
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				if area.reserved_corridor_cells.has(tl + Vector2i(bx, by)):
					nav_overlap = true
					break
			if nav_overlap:
				break
		if nav_overlap:
			continue

		var door_facing: Vector2i = _choose_door_direction(area, tl, outer_w, outer_h)
		var door_positions: Array[Vector2i] = _compute_door_positions(tl, outer_w, outer_h, door_facing, template.size)

		var doors_valid := true
		for dp: Vector2i in door_positions:
			var ext: Vector2i = dp + door_facing
			if ext.x < 0 or ext.x >= area.width or ext.y < 0 or ext.y >= area.length:
				doors_valid = false
				break
			if area.is_obstacle(ext) or area.building_interiors.has(ext):
				doors_valid = false
				break
		if not doors_valid:
			continue

		var snap_obstacles: Array[Dictionary] = area.obstacles.duplicate(false)
		var snap_obs_map: Dictionary = area._obs_map.duplicate(false)
		var snap_interiors: Dictionary = area.building_interiors.duplicate(false)
		var snap_terrain: Dictionary = area.terrain_heights.duplicate(false)

		var h_sum: float = 0.0
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				h_sum += area.get_terrain_height(tl + Vector2i(bx, by))
		var flat_h: float = clampf(h_sum / float(outer_w * outer_h), -0.25, 0.25)
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				area.terrain_heights[tl + Vector2i(bx, by)] = flat_h

		var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
		var wall_size: int = maxi(1, ceili(template.size_z))
		var wall_height: float = maxf(3.0, template.size_z)

		var window_data: ObstacleData = DataManager.get_obstacle_by_name("Window")
		var window_positions: Dictionary = {}
		if window_data != null:
			var candidates: Array[Vector2i] = []
			for bx: int in range(outer_w):
				for by: int in range(outer_h):
					var cell := tl + Vector2i(bx, by)
					var is_perim := (bx == 0 or bx == outer_w - 1 or by == 0 or by == outer_h - 1)
					if not is_perim or door_positions.has(cell):
						continue
					var adj_door := false
					for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if door_positions.has(cell + dir):
							adj_door = true
							break
					if not adj_door:
						candidates.append(cell)
			candidates.shuffle()
			@warning_ignore("integer_division")
			var num_windows: int = randi_range(1, maxi(1, candidates.size() / 6))
			for i: int in range(mini(num_windows, candidates.size())):
				window_positions[candidates[i]] = true

		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				var cell: Vector2i = tl + Vector2i(bx, by)
				var is_perim: bool = (bx == 0 or bx == outer_w - 1 or by == 0 or by == outer_h - 1)
				if is_perim:
					if door_positions.has(cell):
						_add_perimeter_obstacle(area, cell, 2, _get_door_template(), "door",
							wall_height, {OpenCloseState.KEY: false})
					elif window_positions.has(cell):
						_add_perimeter_obstacle(area, cell, 2, window_data, "window", wall_height, {})
					else:
						_add_perimeter_obstacle(area, cell, wall_size, wall_data, "wall",
							wall_height, {})
				else:
					area.building_interiors[cell] = true

		if not ConnectivityVerifier.spawns_connected(area):
			area.obstacles = snap_obstacles
			area._obs_map = snap_obs_map
			area.building_interiors = snap_interiors
			area.terrain_heights = snap_terrain
			area.generation_log.append(
				"Building rejected: would disconnect spawns at pos=(%d,%d) size=%dx%d" % [
				tl.x, tl.y, outer_w, outer_h])
			continue

		area.building_data.append({
			"rect": Rect2i(tl, Vector2i(outer_w, outer_h)),
			"door_facing": door_facing,
			"door_positions": door_positions,
			"name": template.obstacle_name,
			"guaranteed_structures": template.guaranteed_structures,
		})
		return true

	return false


#One perimeter obstacle appended to the area and mirrored into its obstacle map.
static func _add_perimeter_obstacle(area: BattlefieldArea, cell: Vector2i, size: int,
		data: ObstacleData, cell_type: String, height: float, extra: Dictionary) -> void:
	var obs: Dictionary = {"pos": cell, "size": size, "data": data, "cell_type": cell_type,
		"height": height, "floor": 0}
	for k: Variant in extra:
		obs[k] = extra[k]
	area.obstacles.append(obs)
	area._obs_map[cell] = obs


static func _place_guaranteed_structures(area: BattlefieldArea, b: Dictionary) -> void:
	var guaranteed: Array = b.get("guaranteed_structures", [])
	if guaranteed.is_empty():
		return
	var rect: Rect2i = b["rect"]
	var door_positions: Array = b["door_positions"]
	var door_facing: Vector2i = b["door_facing"]
	var entry_cells: Dictionary = {}
	for dp: Vector2i in door_positions:
		entry_cells[dp - door_facing] = true
	var preferred: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for ix: int in range(rect.position.x + 1, rect.end.x - 1):
		for iy: int in range(rect.position.y + 1, rect.end.y - 1):
			var p := Vector2i(ix, iy)
			if area.is_obstacle(p):
				continue
			if entry_cells.has(p):
				fallback.append(p)
			else:
				preferred.append(p)
	preferred.shuffle()
	fallback.shuffle()
	var candidates: Array[Vector2i] = preferred + fallback
	var idx: int = 0
	for struct_name: String in guaranteed:
		if idx >= candidates.size():
			break
		var struct_data: ObstacleData = DataManager.get_obstacle_by_name(struct_name)
		if struct_data == null:
			continue
		var pos: Vector2i = candidates[idx]
		idx += 1
		var obs := {"pos": pos, "size": struct_data.size,
			"data": struct_data, "cell_type": "furniture", "floor": 0}
		area.obstacles.append(obs)
		area._obs_map[pos] = obs


static func place_furniture_in_buildings(area: BattlefieldArea) -> void:
	var indoor_pool: Array = []
	indoor_pool.append_array(DataManager.obstacles_by_type.get("Furniture", []))
	for obs: ObstacleData in DataManager.building_only_pool:
		if obs.obstacle_type != "Furniture":
			indoor_pool.append(obs)
	for b: Dictionary in area.building_data:
		_place_guaranteed_structures(area, b)
		if (b.get("excluded_structures", []) as Array).has("All"):
			continue
		if indoor_pool.is_empty():
			continue
		var rect: Rect2i = b["rect"] as Rect2i
		var free_cells: Array[Vector2i] = []
		for ix: int in range(rect.position.x + 1, rect.end.x - 1):
			for iy: int in range(rect.position.y + 1, rect.end.y - 1):
				var p := Vector2i(ix, iy)
				if not area.is_obstacle(p):
					free_cells.append(p)
		if free_cells.is_empty():
			continue
		var count: int = randi_range(0, maxi(1, int(free_cells.size() / 3.0)))
		free_cells.shuffle()
		for i: int in range(mini(count, free_cells.size())):
			var furn: ObstacleData = indoor_pool[randi() % indoor_pool.size()] as ObstacleData
			var _furn_obs := {"pos": free_cells[i], "size": furn.size,
				"data": furn, "cell_type": "furniture", "floor": 0}
			area.obstacles.append(_furn_obs)
			area._obs_map[free_cells[i]] = _furn_obs


static func _footprint_clear(area: BattlefieldArea, tl: Vector2i, w: int, h: int) -> bool:
	for bx: int in range(w):
		for by: int in range(h):
			var cell: Vector2i = tl + Vector2i(bx, by)
			if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
				return false
			if area._in_spawn_zone(cell):
				return false
			if area.reserved_corridor_cells.has(cell):
				return false
			if area.is_obstacle(cell) or area.building_interiors.has(cell):
				return false
	return true


static func _footprint_in_keep_clear(area: BattlefieldArea, tl: Vector2i, w: int, h: int) -> bool:
	var cx: int = area.width >> 1
	for bx: int in range(w):
		var cell_x: int = tl.x + bx
		if cell_x >= cx - 1 and cell_x <= cx + 1:
			for by: int in range(h):
				var cell_y: int = tl.y + by
				if cell_y >= BattlefieldArea.SPAWN_BUFFER and cell_y < area.length - BattlefieldArea.SPAWN_BUFFER:
					return true
	return false


static func _choose_door_direction(area: BattlefieldArea, tl: Vector2i, outer_w: int, outer_h: int) -> Vector2i:
	var center_x: int = tl.x + int(outer_w / 2.0)
	var center_y: int = tl.y + int(outer_h / 2.0)
	var street_range: int = outer_w + outer_h + 6

	for b: Dictionary in area.building_data:
		var other_facing: Vector2i = b["door_facing"] as Vector2i
		var other_rect: Rect2i = b["rect"] as Rect2i
		var other_cx: int = other_rect.position.x + int(other_rect.size.x / 2.0)
		var other_cy: int = other_rect.position.y + int(other_rect.size.y / 2.0)
		var dist: int = maxi(abs(center_x - other_cx), abs(center_y - other_cy))
		if dist <= street_range:
			var toward_us: Vector2i = Vector2i(signi(center_x - other_cx), signi(center_y - other_cy))
			if toward_us == other_facing:
				return -other_facing

	var map_center_y: int = int(area.length / 2.0)
	if tl.y + int(outer_h / 2.0) < map_center_y:
		return Vector2i(0, 1)
	return Vector2i(0, -1)


static func _compute_door_positions(tl: Vector2i, outer_w: int, outer_h: int,
		door_facing: Vector2i, template_size: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	var primary := _wall_center_cell(tl, outer_w, outer_h, door_facing)
	positions.append(primary)

	if template_size >= 8 and randi() % 2 == 0:
		var side: Vector2i = Vector2i(door_facing.y, door_facing.x)
		var alt: Vector2i = primary + side
		if _is_on_wall(alt, tl, outer_w, outer_h, door_facing):
			positions.append(alt)

	if template_size >= 8 and randi() % 3 == 0:
		var back := _wall_center_cell(tl, outer_w, outer_h, -door_facing)
		positions.append(back)

	return positions


static func _wall_center_cell(tl: Vector2i, outer_w: int, outer_h: int, facing: Vector2i) -> Vector2i:
	if facing == Vector2i(0, -1):
		return tl + Vector2i(int(outer_w / 2.0), 0)
	if facing == Vector2i(0, 1):
		return tl + Vector2i(int(outer_w / 2.0), outer_h - 1)
	if facing == Vector2i(-1, 0):
		return tl + Vector2i(0, int(outer_h / 2.0))
	return tl + Vector2i(outer_w - 1, int(outer_h / 2.0))


static func _is_on_wall(pos: Vector2i, tl: Vector2i, outer_w: int, outer_h: int, facing: Vector2i) -> bool:
	var rel: Vector2i = pos - tl
	if rel.x < 0 or rel.y < 0 or rel.x >= outer_w or rel.y >= outer_h:
		return false
	if facing == Vector2i(0, -1):
		return rel.y == 0 and rel.x > 0 and rel.x < outer_w - 1
	if facing == Vector2i(0, 1):
		return rel.y == outer_h - 1 and rel.x > 0 and rel.x < outer_w - 1
	if facing == Vector2i(-1, 0):
		return rel.x == 0 and rel.y > 0 and rel.y < outer_h - 1
	return rel.x == outer_w - 1 and rel.y > 0 and rel.y < outer_h - 1


static func _get_door_template() -> ObstacleData:
	if _door_template == null:
		_door_template = ObstacleData.new()
		_door_template.obstacle_name = "Door"
		_door_template.size_x = 1.0
		_door_template.size_y = 0.25
		_door_template.size_z = 2.0
		_door_template.obstacle_type = "Structure"
		_door_template.health = 4
		_door_template.susceptible_to = "Strike"
		_door_template.passthrough = false
		#TODO: replace this code template with a Door row in Obstacles.tsv.
		_door_template.interactable = true
		_door_template.interaction_result = "Open/Close"
	return _door_template

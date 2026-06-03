class_name ObstacleGenerator


static func place_obstacles(area: BattlefieldArea, target_count: int) -> int:
	var placed := 0
	var max_attempts := target_count * 30
	for _i: int in range(max_attempts):
		if placed >= target_count:
			break
		var pos := Vector2i(randi() % area.width, randi() % area.length)
		if area._in_spawn_zone(pos) or area._is_obstacle_at(pos):
			continue
		if area.reserved_corridor_cells.has(pos) or area.building_interiors.has(pos):
			continue
		var template: ObstacleData = DataManager.get_random_obstacle()
		if not _terrain_compatible(template, area, pos):
			continue
		var _new_obs := {"pos": pos, "size": template.size, "data": template}
		area.obstacles.append(_new_obs)
		area._obs_map[pos] = _new_obs
		placed += 1
		placed += _expand_obstacle(area, template, pos, target_count - placed)
	return placed


static func _expand_obstacle(area: BattlefieldArea, template: ObstacleData, origin: Vector2i, budget: int) -> int:
	var added := 0
	var odds: int = template.growth_pct
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var corridor_cells: Array = area.reserved_corridor_cells.keys()
	var expansion_safety_radius: int = 1 + (area.path_width >> 1)
	var frontier: Array[Vector2i] = [origin]
	while odds > 0 and added < budget and not frontier.is_empty() and randi() % 100 < odds:
		var parent: Vector2i = frontier[randi() % frontier.size()]
		dirs.shuffle()
		var placed := false
		for d: Vector2i in dirs:
			var np: Vector2i = parent + d
			if np.x < 0 or np.x >= area.width or np.y < 0 or np.y >= area.length:
				continue
			if area._in_spawn_zone(np) or area._is_obstacle_at(np):
				continue
			if area.reserved_corridor_cells.has(np) or area.building_interiors.has(np):
				continue
			var too_close := false
			for cc: Vector2i in corridor_cells:
				if maxi(abs(np.x - cc.x), abs(np.y - cc.y)) <= expansion_safety_radius:
					too_close = true
					break
			if too_close:
				continue
			if not _terrain_compatible(template, area, np):
				continue
			var _exp_obs := {"pos": np, "size": template.size, "data": template}
			area.obstacles.append(_exp_obs)
			area._obs_map[np] = _exp_obs
			frontier.append(np)
			added += 1
			placed = true
			break
		if not placed:
			break
		odds = int(odds * 0.75)
	return added


static func _terrain_compatible(template: ObstacleData, area: BattlefieldArea, pos: Vector2i) -> bool:
	match template.obstacle_type:
		"Structure", "Furniture":
			return absf(area.get_terrain_height(pos)) <= 0.25
		_:
			return true


static func apply_terrain_effects(area: BattlefieldArea) -> void:
	for obs: Dictionary in area.obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.thd_min == 0.0:
			continue
		var pos: Vector2i = obs["pos"] as Vector2i
		if d.obstacle_name == "Pit":
			var pit_depth: float = randf_range(d.thd_min, d.thd_max)
			var pit_radius: float = float(ceili(sqrt(float(d.size))) + 2)
			for y: int in range(area.length):
				for x: int in range(area.width):
					var cell := Vector2i(x, y)
					if area.reserved_corridor_cells.has(cell):
						continue
					if cell.y < BattlefieldArea.SPAWN_BUFFER + 4 or cell.y >= area.length - BattlefieldArea.SPAWN_BUFFER - 4:
						continue
					var dist: float = Vector2(float(cell.x - pos.x), float(cell.y - pos.y)).length()
					if dist <= pit_radius:
						var t: float = 1.0 - dist / pit_radius
						var weight: float = t * t * t * t
						area.terrain_heights[cell] = area.terrain_heights.get(cell, 0.0) + pit_depth * weight
		elif d.obstacle_name == "Cliff Edge":
			var cliff_drop: float = randf_range(d.thd_min, d.thd_max)
			var facing: Vector2i = _cliff_facing(area, pos)
			for step: int in range(1, 4):
				var cell: Vector2i = pos + facing * step
				if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
					break
				if area.reserved_corridor_cells.has(cell):
					continue
				area.terrain_heights[cell] = maxf(0.0, area.terrain_heights.get(cell, 0.0) + cliff_drop)


static func _cliff_facing(area: BattlefieldArea, pos: Vector2i) -> Vector2i:
	var dist_left: int = pos.x
	var dist_right: int = area.width - 1 - pos.x
	var dist_top: int = pos.y
	var dist_bottom: int = area.length - 1 - pos.y
	var min_dist: int = mini(mini(dist_left, dist_right), mini(dist_top, dist_bottom))
	if min_dist == dist_left:
		return Vector2i(-1, 0)
	if min_dist == dist_right:
		return Vector2i(1, 0)
	if min_dist == dist_top:
		return Vector2i(0, -1)
	return Vector2i(0, 1)

class_name ObstacleGenerator


static func _instance_size(template: ObstacleData) -> int:
	if template.obstacle_type == "Vegetation" or template.obstacle_type == "Terrain":
		var eff_z: float = template.size_z * randf_range(0.75, 1.25)
		if template.size_z == 0.0:
			return ceili((template.size_x + template.size_y) / 2.0)
		return ceili((template.size_x + template.size_y + eff_z) / 3.0)
	return template.size


static func _make_obs(template: ObstacleData, pos: Vector2i) -> Dictionary:
	var rotated := template.size_x != template.size_y and randi() % 2 == 0
	return {"pos": pos, "size": _instance_size(template), "data": template, "rotated": rotated}


static func place_terrain_obstacles(area: BattlefieldArea, target_count: int) -> int:
	if DataManager.obstacles_terrain_pool.is_empty():
		return 0
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
		var template: ObstacleData = DataManager.obstacles_terrain_pool[
			randi() % DataManager.obstacles_terrain_pool.size()]
		var new_obs := _make_obs(template, pos)
		area.obstacles.append(new_obs)
		area._obs_map[pos] = new_obs
		placed += 1
		placed += _expand_obstacle(area, template, pos, target_count - placed)
	return placed


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
		var new_obs := _make_obs(template, pos)
		area.obstacles.append(new_obs)
		area._obs_map[pos] = new_obs
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
			var exp_obs := _make_obs(template, np)
			area.obstacles.append(exp_obs)
			area._obs_map[np] = exp_obs
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
		if d == null or d.obstacle_type != "Terrain":
			continue
		if d.thd_min == 0.0 and d.thd_max == 0.0:
			continue
		var _raw_op = obs["pos"]
		var pos: Vector2i = Vector2i((_raw_op as Vector3i).x, (_raw_op as Vector3i).y) if typeof(_raw_op) == TYPE_VECTOR3I else _raw_op as Vector2i
		var amount: float = randf_range(d.thd_min, d.thd_max)
		var aspect: float = maxf(d.size_x, d.size_y) / maxf(minf(d.size_x, d.size_y), 0.01)
		if d.obstacle_name == "Cliff Edge":
			_apply_cliff_deformation(area, pos, amount, d.size)
		elif aspect >= 2.5:
			_apply_linear_deformation(area, pos, amount, d.size)
		else:
			_apply_radial_deformation(area, pos, amount, d.size)


static func _apply_radial_deformation(area: BattlefieldArea, center: Vector2i, amount: float, size: int) -> void:
	var radius: float = sqrt(float(size)) * 2.0 + 1.0
	var ri: int = ceili(radius)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
				continue
			if area.reserved_corridor_cells.has(cell):
				continue
			var _da: float = Vector2(float(cell.x - area.spawn_center_a.x), float(cell.y - area.spawn_center_a.y)).length()
			var _db: float = Vector2(float(cell.x - area.spawn_center_b.x), float(cell.y - area.spawn_center_b.y)).length()
			if _da < area.spawn_radius + 4.0 or _db < area.spawn_radius + 4.0:
				continue
			var dist: float = Vector2(float(dx), float(dy)).length()
			if dist > radius:
				continue
			var t: float = 1.0 - dist / radius
			area.terrain_heights[cell] = area.terrain_heights.get(cell, 0.0) + amount * t * t


static func _apply_linear_deformation(area: BattlefieldArea, center: Vector2i, amount: float, size: int) -> void:
	var main_extent: int = ceili(sqrt(float(size)) * 2.5)
	var perp_extent: int = ceili(sqrt(float(size)) * 0.8)
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var main_axis: Vector2i = axes[randi() % 2]
	var perp: Vector2i = Vector2i(main_axis.y, main_axis.x)
	for mi: int in range(-main_extent, main_extent + 1):
		for pi: int in range(-perp_extent, perp_extent + 1):
			var cell := Vector2i(
				center.x + main_axis.x * mi + perp.x * pi,
				center.y + main_axis.y * mi + perp.y * pi)
			if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
				continue
			if area.reserved_corridor_cells.has(cell):
				continue
			var _da: float = Vector2(float(cell.x - area.spawn_center_a.x), float(cell.y - area.spawn_center_a.y)).length()
			var _db: float = Vector2(float(cell.x - area.spawn_center_b.x), float(cell.y - area.spawn_center_b.y)).length()
			if _da < area.spawn_radius + 4.0 or _db < area.spawn_radius + 4.0:
				continue
			var main_t: float = 1.0 - float(absi(mi)) / float(main_extent + 1)
			var perp_t: float = 1.0 - float(absi(pi)) / float(perp_extent + 1)
			area.terrain_heights[cell] = area.terrain_heights.get(cell, 0.0) + amount * main_t * perp_t


static func _apply_cliff_deformation(area: BattlefieldArea, center: Vector2i, amount: float, size: int) -> void:
	var facing := _cliff_facing(area, center)
	var perp := Vector2i(-facing.y, facing.x)
	var num_tiers: int = randi_range(2, 4)
	var base_tier_w: int = maxi(2, ceili(sqrt(float(size)) * 1.8))
	var perp_half: int = maxi(2, ceili(sqrt(float(size)) * 1.5))
	var d := 1
	for ti: int in range(num_tiers):
		var tier_depth: float = amount * float(ti + 1) / float(num_tiers)
		var tier_w: int = maxi(2, base_tier_w + randi_range(-1, 2))
		var tier_perp: int = maxi(2, perp_half + randi_range(-1, 1))
		for bd: int in range(d, d + tier_w):
			for p: int in range(-tier_perp, tier_perp + 1):
				var cell := center + facing * bd + perp * p
				if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
					continue
				if area.reserved_corridor_cells.has(cell):
					continue
				var _cda: float = Vector2(float(cell.x - area.spawn_center_a.x), float(cell.y - area.spawn_center_a.y)).length()
				var _cdb: float = Vector2(float(cell.x - area.spawn_center_b.x), float(cell.y - area.spawn_center_b.y)).length()
				if _cda < area.spawn_radius + 4.0 or _cdb < area.spawn_radius + 4.0:
					continue
				area.terrain_heights[cell] = minf(area.terrain_heights.get(cell, 0.0), tier_depth)
		d += tier_w


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

class_name BattlefieldArea extends RefCounted

const MIN_DIM := 20
const MAX_DIM := 50

# cells per area unit per density level; 0 = minimal, 4 = excessive
const COVER_DENSITY: Array[float] = [0.01, 0.03, 0.05, 0.08, 0.12]
const COVER_AMOUNT_NAMES: Array[String] = ["minimal", "some", "average", "many", "excessive"]

const SPAWN_BUFFER := 3

# Max buildings per combat, indexed by cover_amount (0-4)
const MAX_BUILDINGS_BY_DENSITY: Array[int] = [0, 0, 1, 2, 3]

const UNEVENNESS_NAMES: Array[String] = ["flat", "gentle", "hilly", "rough", "extreme"]
const UNEVENNESS_RANGE: Array[Vector2] = [
	Vector2(-0.25, 1.25),
	Vector2(-0.5,  2.0),
	Vector2(-1.0,  3.0),
	Vector2(-3.0,  5.0),
	Vector2(-20.0, 10.0),
]

var width: int
var length: int
var height: int
var cover_amount: int
var unevenness: int = 0
var obstacles: Array[Dictionary] = []   # [{pos, size, data, ?cell_type, ?door_open}]
var building_interiors: Dictionary = {} # Vector2i -> true
var building_data: Array[Dictionary] = []  # [{rect, door_facing, door_positions, name}]
var terrain_heights: Dictionary = {}    # Vector2i -> float; absent key = 0.0

static var _door_template: ObstacleData


static func generate_random() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width  = randi_range(MIN_DIM, MAX_DIM)
	f.length = randi_range(MIN_DIM, MAX_DIM)
	f.height = randi_range(MIN_DIM, MAX_DIM)
	f.cover_amount = randi() % 5
	f.unevenness = randi() % 5
	f._generate_cover()
	return f


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


func to_log_string() -> String:
	return to_header_string()


func to_header_string() -> String:
	var b_str := " (%d building%s)" % [building_data.size(), "s" if building_data.size() != 1 else ""] \
		if not building_data.is_empty() else ""
	return "Battlefield: %d×%d (height %d) — %s cover, %s terrain%s" % [
		width, length, height, COVER_AMOUNT_NAMES[cover_amount],
		UNEVENNESS_NAMES[unevenness], b_str]


func to_visual_string() -> String:
	var pos_map: Dictionary = {}
	for obs: Dictionary in obstacles:
		pos_map[obs["pos"] as Vector2i] = obs
	var rows: Array[String] = []
	for y: int in range(length):
		var row := ""
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if not pos_map.has(pos):
				var h: float = get_terrain_height(pos)
				if h <= -5.0:
					row += "[color=#334455]_[/color]"
				elif h < -0.25:
					row += "[color=gray],[/color]"
				elif h <= 0.25:
					row += "."
				elif h <= 0.75:
					row += "[color=yellow]'[/color]"
				elif h <= 2.0:
					row += "[color=orange]^[/color]"
				else:
					row += "[color=white]▲[/color]"
			else:
				var obs: Dictionary = pos_map[pos]
				var d: ObstacleData = obs.get("data") as ObstacleData
				if d != null and d.is_stairs:
					row += "[color=cyan]S[/color]"
				else:
					var ct: String = obs.get("cell_type", "")
					if ct == "wall" or ct == "door":
						row += "[color=orange]#[/color]"
					elif d == null or not d.passthrough:
						row += "[color=orange]#[/color]"
					elif d.passthrough_enter_harm > 0 or d.passthrough_exit_harm > 0:
						row += "[color=red]*[/color]"
					else:
						row += "[color=pink]~[/color]"
		rows.append(row)
	return "\n".join(rows)


func is_interior(pos: Vector2i) -> bool:
	return building_interiors.has(pos)


func _generate_cover() -> void:
	obstacles.clear()
	building_interiors.clear()
	building_data.clear()
	terrain_heights.clear()
	_generate_base_terrain()   # heights must exist before obstacle terrain checks

	var density: float = COVER_DENSITY[cover_amount]
	var target_count: int = int(width * length * density)
	var placed := 0
	var max_attempts := target_count * 30
	for _i: int in range(max_attempts):
		if placed >= target_count:
			break
		var pos := Vector2i(randi() % width, randi() % length)
		if _in_spawn_zone(pos) or _is_obstacle_at(pos):
			continue
		var template: ObstacleData = DataManager.get_random_obstacle()
		if not _terrain_compatible(template, pos):
			continue
		obstacles.append({"pos": pos, "size": template.size, "data": template})
		placed += 1
		placed += _expand_obstacle(template, pos, target_count - placed)

	_generate_buildings()
	_place_furniture_in_buildings()
	_apply_obstacle_terrain_effects()
	_place_stairs_at_transitions()
	_ensure_pathability()
	_ensure_spawn_connectivity()


func _generate_buildings() -> void:
	if DataManager.building_pool.is_empty():
		return
	var max_b: int = MAX_BUILDINGS_BY_DENSITY[cover_amount]
	for _i: int in range(max_b):
		var template: ObstacleData = DataManager.building_pool[randi() % DataManager.building_pool.size()]
		_place_building(template)


func _place_building(template: ObstacleData) -> void:
	# Compute interior dimensions from floor area (size ≈ floor area in cells)
	var floor_w: int = maxi(2, int(round(sqrt(float(template.size)))))
	var floor_h: int = maxi(2, int(ceil(float(template.size) / float(floor_w))))
	# Small random variance for variety
	if randi() % 2 == 0:
		floor_w += 1
	else:
		floor_h += 1
	var outer_w: int = floor_w + 2
	var outer_h: int = floor_h + 2

	# Try to find a valid placement
	for _attempt: int in range(50):
		var tl := Vector2i(
			randi() % maxi(1, width - outer_w),
			SPAWN_BUFFER + randi() % maxi(1, length - outer_h - SPAWN_BUFFER * 2)
		)
		if not _footprint_clear(tl, outer_w, outer_h):
			continue

		# Determine door direction (Vector2i facing OUTWARD from the building)
		var door_facing: Vector2i = _choose_door_direction(tl, outer_w, outer_h)

		# Determine door cell positions
		var door_positions: Array[Vector2i] = _compute_door_positions(tl, outer_w, outer_h, door_facing, template.size)

		# Validate: each door cell's external neighbor must be open space
		var doors_valid := true
		for dp: Vector2i in door_positions:
			var ext: Vector2i = dp + door_facing
			if ext.x < 0 or ext.x >= width or ext.y < 0 or ext.y >= length:
				doors_valid = false
				break
			if _is_obstacle_at(ext) or building_interiors.has(ext):
				doors_valid = false
				break
		if not doors_valid:
			continue

		# Flatten terrain under the entire building footprint
		var h_sum: float = 0.0
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				h_sum += get_terrain_height(tl + Vector2i(bx, by))
		var flat_h: float = clampf(h_sum / float(outer_w * outer_h), -0.25, 0.25)
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				terrain_heights[tl + Vector2i(bx, by)] = flat_h

		# Place wall + door cells
		var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
		var wall_size: int = maxi(3, template.height_min)

		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				var cell: Vector2i = tl + Vector2i(bx, by)
				var is_perim: bool = (bx == 0 or bx == outer_w - 1 or by == 0 or by == outer_h - 1)
				if is_perim:
					if door_positions.has(cell):
						obstacles.append({
							"pos": cell, "size": 2,
							"data": _get_door_template(),
							"cell_type": "door", "door_open": false
						})
					else:
						obstacles.append({
							"pos": cell, "size": wall_size,
							"data": wall_data,
							"cell_type": "wall"
						})
				else:
					building_interiors[cell] = true

		building_data.append({
			"rect": Rect2i(tl, Vector2i(outer_w, outer_h)),
			"door_facing": door_facing,
			"door_positions": door_positions,
			"name": template.obstacle_name,
		})
		return  # placed successfully


func _footprint_clear(tl: Vector2i, w: int, h: int) -> bool:
	for bx: int in range(w):
		for by: int in range(h):
			var cell: Vector2i = tl + Vector2i(bx, by)
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= length:
				return false
			if _in_spawn_zone(cell):
				return false
			if _is_obstacle_at(cell) or building_interiors.has(cell):
				return false
	return true


func _choose_door_direction(tl: Vector2i, outer_w: int, outer_h: int) -> Vector2i:
	# Check existing buildings for street formation
	var center_x: int = tl.x + int(outer_w / 2.0)
	var center_y: int = tl.y + int(outer_h / 2.0)
	var street_range: int = outer_w + outer_h + 6

	for b: Dictionary in building_data:
		var other_facing: Vector2i = b["door_facing"] as Vector2i
		var other_rect: Rect2i = b["rect"] as Rect2i
		var other_cx: int = other_rect.position.x + int(other_rect.size.x / 2.0)
		var other_cy: int = other_rect.position.y + int(other_rect.size.y / 2.0)
		var dist: int = maxi(abs(center_x - other_cx), abs(center_y - other_cy))
		if dist <= street_range:
			# The other building's door faces outward. If it faces toward this building's center,
			# point our door back at theirs.
			var toward_us: Vector2i = Vector2i(signi(center_x - other_cx), signi(center_y - other_cy))
			if toward_us == other_facing:
				return -other_facing  # face back toward them

	# Default: prefer facing the vertical center of the map (more interesting encounters)
	var map_center_y: int = int(length / 2.0)
	if tl.y + int(outer_h / 2.0) < map_center_y:
		return Vector2i(0, 1)   # south
	return Vector2i(0, -1)      # north


func _compute_door_positions(tl: Vector2i, outer_w: int, outer_h: int,
		door_facing: Vector2i, template_size: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	# Primary door (centered on the facing wall)
	var primary := _wall_center_cell(tl, outer_w, outer_h, door_facing)
	positions.append(primary)

	# Large buildings: chance for double doors (2 adjacent on same wall)
	if template_size >= 8 and randi() % 2 == 0:
		var side: Vector2i = Vector2i(door_facing.y, door_facing.x)  # perpendicular
		var alt: Vector2i = primary + side
		if _is_on_wall(alt, tl, outer_w, outer_h, door_facing):
			positions.append(alt)

	# Large buildings: chance for back door
	if template_size >= 8 and randi() % 3 == 0:
		var back := _wall_center_cell(tl, outer_w, outer_h, -door_facing)
		positions.append(back)

	return positions


func _wall_center_cell(tl: Vector2i, outer_w: int, outer_h: int, facing: Vector2i) -> Vector2i:
	if facing == Vector2i(0, -1):  # north wall (top row)
		return tl + Vector2i(int(outer_w / 2.0), 0)
	if facing == Vector2i(0, 1):   # south wall (bottom row)
		return tl + Vector2i(int(outer_w / 2.0), outer_h - 1)
	if facing == Vector2i(-1, 0):  # west wall (left column)
		return tl + Vector2i(0, int(outer_h / 2.0))
	# east wall (right column)
	return tl + Vector2i(outer_w - 1, int(outer_h / 2.0))


func _is_on_wall(pos: Vector2i, tl: Vector2i, outer_w: int, outer_h: int, facing: Vector2i) -> bool:
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


func _place_furniture_in_buildings() -> void:
	var furn_pool: Array = DataManager.obstacles_by_type.get("Furniture", [])
	if furn_pool.is_empty():
		return
	for b: Dictionary in building_data:
		var rect: Rect2i = b["rect"] as Rect2i
		var free_cells: Array[Vector2i] = []
		for ix: int in range(rect.position.x + 1, rect.end.x - 1):
			for iy: int in range(rect.position.y + 1, rect.end.y - 1):
				var p := Vector2i(ix, iy)
				if not _is_obstacle_at(p):
					free_cells.append(p)
		if free_cells.is_empty():
			continue
		var count: int = randi_range(0, maxi(1, int(free_cells.size() / 3.0)))
		free_cells.shuffle()
		for i: int in range(mini(count, free_cells.size())):
			var furn: ObstacleData = furn_pool[randi() % furn_pool.size()] as ObstacleData
			obstacles.append({
				"pos": free_cells[i], "size": furn.size,
				"data": furn, "cell_type": "furniture"
			})


func _expand_obstacle(template: ObstacleData, origin: Vector2i, budget: int) -> int:
	var added := 0
	var odds: int = template.expansion_odds
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var frontier: Array[Vector2i] = [origin]
	while odds > 0 and added < budget and not frontier.is_empty() and randi() % 100 < odds:
		var parent: Vector2i = frontier[randi() % frontier.size()]
		dirs.shuffle()
		var placed := false
		for d: Vector2i in dirs:
			var np: Vector2i = parent + d
			if np.x < 0 or np.x >= width or np.y < 0 or np.y >= length:
				continue
			if _in_spawn_zone(np) or _is_obstacle_at(np):
				continue
			if not _terrain_compatible(template, np):
				continue
			obstacles.append({"pos": np, "size": template.size, "data": template})
			frontier.append(np)
			added += 1
			placed = true
			break
		if not placed:
			break
		odds = int(odds * 0.75)
	return added


func _in_spawn_zone(pos: Vector2i) -> bool:
	return pos.y < SPAWN_BUFFER or pos.y >= length - SPAWN_BUFFER


# Returns true only for solid, impassable non-door obstacles.
# Passthrough obstacles and doors are never "blocking" for path/spawn checks.
func _is_obstacle_at(pos: Vector2i) -> bool:
	for obs: Dictionary in obstacles:
		if (obs["pos"] as Vector2i) == pos:
			if obs.get("cell_type", "") == "door":
				return false  # doors are navigable routes
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d != null and (d.passthrough or d.is_stairs):
				return false  # can be walked through or climbed
			return true
	return false


func _ensure_pathability() -> void:
	while not _is_passable() and obstacles.size() > 0:
		# Only remove non-building obstacle cells to avoid partial building deletion
		var removable: Array[int] = []
		for i: int in range(obstacles.size()):
			var ct: String = obstacles[i].get("cell_type", "")
			if ct != "wall" and ct != "door" and ct != "furniture":
				removable.append(i)
		if removable.is_empty():
			break  # can't improve without removing building cells
		obstacles.remove_at(removable[randi() % removable.size()])
	# If terrain gradients are the barrier (no obstacles left to remove), smooth until traversable.
	var _terrain_passes := 0
	while not _is_passable() and _terrain_passes < 15:
		_smooth_terrain_once()
		_terrain_passes += 1


func _is_passable() -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for x: int in range(width):
		var start := Vector2i(x, 0)
		if not _is_obstacle_at(start) and not visited.has(start):
			visited[start] = true
			queue.append(start)
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if curr.y == length - 1:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt) or _is_obstacle_at(nxt):
				continue
			var h_diff: float = absf(get_terrain_height(nxt) - get_terrain_height(curr))
			if h_diff > 0.5:
				continue
			if h_diff > 0.25 and not has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


# Check connectivity using Pathfinder-accurate blocking rules (closed doors are impassable).
# Returns true if any Team-0 spawn cell can reach any Team-1 spawn cell.
func _is_spawn_connected() -> bool:
	var spawn_a := Vector2i(width >> 1, 2)
	var spawn_b := Vector2i(width >> 1, length - 3)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn_a]
	visited[spawn_a] = true
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if curr == spawn_b:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt):
				continue
			# Mirror Pathfinder.cell_pace_cost blocking rules exactly.
			var obs: Dictionary = get_obstacle_at(nxt)
			if not obs.is_empty():
				var ct: String = obs.get("cell_type", "")
				if ct == "wall":
					continue
				if ct == "door":
					if not obs.get("door_open", false):
						continue
				else:
					var d_data: ObstacleData = obs.get("data") as ObstacleData
					if d_data != null and not d_data.passthrough and not d_data.is_stairs:
						continue
			var h_diff: float = get_terrain_height(nxt) - get_terrain_height(curr)
			if h_diff > 0.5:
				continue
			if h_diff <= -1.0:
				continue
			if absf(h_diff) > 0.25 and not has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


# Widen the barrier between spawn zones by carving the impassable tiles that lie
# closest to the straight line between the two spawn centers.  One tile per call;
# caller loops until connected.
func _carve_spawn_corridor_step() -> void:
	var spawn_a := Vector2i(width >> 1, 2)
	var spawn_b := Vector2i(width >> 1, length - 3)

	# Collect all impassable tiles and score them by distance to the line A->B.
	var best_pos := Vector2i(-1, -1)
	var best_score := INF

	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			var obs: Dictionary = get_obstacle_at(pos)
			var is_blocking := false
			if not obs.is_empty():
				var ct: String = obs.get("cell_type", "")
				if ct == "wall" or ct == "door":
					is_blocking = true
				elif ct != "furniture":
					var d_data: ObstacleData = obs.get("data") as ObstacleData
					if d_data != null and not d_data.passthrough and not d_data.is_stairs:
						is_blocking = true
			# Also treat steep terrain as blocking even with no obstacle.
			if not is_blocking:
				var blocked_by_terrain := false
				var dirs_t: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
				for d: Vector2i in dirs_t:
					var nb: Vector2i = pos + d
					if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
						continue
					var h_diff: float = get_terrain_height(pos) - get_terrain_height(nb)
					if h_diff > 0.5 or h_diff <= -1.0 or (absf(h_diff) > 0.25 and not has_stairs_at(pos)):
						blocked_by_terrain = true
						break
				if not blocked_by_terrain:
					continue  # already passable, skip

			# Score: perpendicular distance to the segment A->B, with tiebreak on
			# proximity to the midpoint (prefer the narrowest central choke).
			var ax := float(spawn_a.x)
			var ay := float(spawn_a.y)
			var bx := float(spawn_b.x)
			var by_ := float(spawn_b.y)
			var px := float(x)
			var py := float(y)
			var seg_len := Vector2(bx - ax, by_ - ay).length()
			var perp_dist: float
			if seg_len < 0.001:
				perp_dist = Vector2(px - ax, py - ay).length()
			else:
				perp_dist = absf((by_ - ay) * px - (bx - ax) * py + bx * ay - by_ * ax) / seg_len
			var mid_x := (ax + bx) * 0.5
			var mid_y := (ay + by_) * 0.5
			var mid_dist := Vector2(px - mid_x, py - mid_y).length()
			var score := perp_dist + mid_dist * 0.01  # perp distance primary, proximity to mid secondary
			if score < best_score:
				best_score = score
				best_pos = pos

	if best_pos == Vector2i(-1, -1):
		return  # nothing to carve

	# Remove all obstacle entries at this position and flatten terrain.
	var i: int = obstacles.size() - 1
	while i >= 0:
		if (obstacles[i]["pos"] as Vector2i) == best_pos:
			obstacles.remove_at(i)
		i -= 1
	terrain_heights[best_pos] = 0.0


func _ensure_spawn_connectivity() -> void:
	var max_carve := (width + length) * 2  # safety cap — never infinite loop
	var passes := 0
	while not _is_spawn_connected() and passes < max_carve:
		_carve_spawn_corridor_step()
		passes += 1


func is_obstacle(pos: Vector2i) -> bool:
	return _is_obstacle_at(pos)


func get_obstacle_at(pos: Vector2i) -> Dictionary:
	for obs: Dictionary in obstacles:
		if (obs["pos"] as Vector2i) == pos:
			return obs
	return {}


func get_adjacent_obstacles(pos: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var obs: Dictionary = get_obstacle_at(pos + Vector2i(dx, dy))
			if not obs.is_empty():
				result.append(obs)
	return result


static func _get_door_template() -> ObstacleData:
	if _door_template == null:
		_door_template = ObstacleData.new()
		_door_template.obstacle_name = "Door"
		_door_template.size = 2
		_door_template.obstacle_type = "Structure"
		_door_template.health = 4
		_door_template.susceptible_to = "Strike"
		_door_template.passthrough = false
		_door_template.height_min = 2
		_door_template.height_max = 3
	return _door_template


func get_terrain_height(pos: Vector2i) -> float:
	return terrain_heights.get(pos, 0.0)


func has_stairs_at(pos: Vector2i) -> bool:
	var obs := get_obstacle_at(pos)
	if obs.is_empty():
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	return d != null and d.is_stairs


func _generate_base_terrain() -> void:
	var h_range: Vector2 = UNEVENNESS_RANGE[unevenness]
	var n_seeds: int = 3 + unevenness * 3
	for _s: int in range(n_seeds):
		var sx: int = randi() % width
		var sy: int = randi_range(SPAWN_BUFFER, length - SPAWN_BUFFER - 1)
		var peak: float = randf_range(h_range.x, h_range.y)
		var radius: float = float(randi_range(3, 8))
		for y: int in range(length):
			for x: int in range(width):
				var pos := Vector2i(x, y)
				var dist: float = Vector2(float(x - sx), float(y - sy)).length()
				var influence: float = maxf(0.0, 1.0 - dist / radius)
				terrain_heights[pos] = terrain_heights.get(pos, 0.0) + peak * influence

	# Clamp all cells to h_range
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), h_range.x, h_range.y)

	# Force spawn buffer rows to [0.0, 0.25]
	for x: int in range(width):
		for y: int in range(SPAWN_BUFFER):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)
		for y: int in range(length - SPAWN_BUFFER, length):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)

	# Smoothing passes: more passes for rougher terrain to prevent impassable gradients.
	for _p: int in range(1 + unevenness):
		_smooth_terrain_once()


func _smooth_terrain_once() -> void:
	var smoothed: Dictionary = {}
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			var sum: float = terrain_heights.get(pos, 0.0)
			var count: int = 1
			for dir: Vector2i in cardinal:
				var nb: Vector2i = pos + dir
				if nb.x >= 0 and nb.x < width and nb.y >= 0 and nb.y < length:
					sum += terrain_heights.get(nb, 0.0)
				count += 1
			smoothed[pos] = sum / float(count)
	terrain_heights = smoothed


func _apply_obstacle_terrain_effects() -> void:
	for obs: Dictionary in obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.terrain_height_delta_min == 0.0:
			continue
		var pos: Vector2i = obs["pos"] as Vector2i
		if d.obstacle_name == "Pit":
			var pit_depth: float = randf_range(d.terrain_height_delta_min, d.terrain_height_delta_max)
			var pit_radius: float = float(ceili(sqrt(float(d.size))) + 2)
			for y: int in range(length):
				for x: int in range(width):
					var cell := Vector2i(x, y)
					var dist: float = Vector2(float(cell.x - pos.x), float(cell.y - pos.y)).length()
					if dist <= pit_radius:
						var t: float = 1.0 - dist / pit_radius
						var weight: float = t * t * t * t  # quartic: steep inner wall, flat outer rim
						terrain_heights[cell] = terrain_heights.get(cell, 0.0) + pit_depth * weight
		elif d.obstacle_name == "Cliff Edge":
			var cliff_drop: float = randf_range(d.terrain_height_delta_min, d.terrain_height_delta_max)
			var facing: Vector2i = _cliff_facing(pos)
			for step: int in range(1, 4):
				var cell: Vector2i = pos + facing * step
				if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= length:
					break
				terrain_heights[cell] = maxf(0.0, terrain_heights.get(cell, 0.0) + cliff_drop)


func _terrain_compatible(template: ObstacleData, pos: Vector2i) -> bool:
	match template.obstacle_type:
		"Structure", "Furniture":
			return absf(get_terrain_height(pos)) <= 0.25
		_:  # Terrain, Vegetation — full tolerance
			return true


func _cliff_facing(pos: Vector2i) -> Vector2i:
	var dist_left: int = pos.x
	var dist_right: int = width - 1 - pos.x
	var dist_top: int = pos.y
	var dist_bottom: int = length - 1 - pos.y
	var min_dist: int = mini(mini(dist_left, dist_right), mini(dist_top, dist_bottom))
	if min_dist == dist_left:
		return Vector2i(-1, 0)
	if min_dist == dist_right:
		return Vector2i(1, 0)
	if min_dist == dist_top:
		return Vector2i(0, -1)
	return Vector2i(0, 1)


func _place_stairs_at_transitions() -> void:
	var stairs_template: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	if stairs_template == null:
		return
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(SPAWN_BUFFER, length - SPAWN_BUFFER):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if _is_obstacle_at(pos):
				continue
			var qualifies := false
			for dir: Vector2i in cardinal:
				var nb: Vector2i = pos + dir
				if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
					continue
				var h_diff: float = absf(get_terrain_height(nb) - get_terrain_height(pos))
				if h_diff > 0.25 and h_diff <= 0.5:
					qualifies = true
					break
			if qualifies and randf() < 0.4:
				obstacles.append({"pos": pos, "size": stairs_template.size, "data": stairs_template})

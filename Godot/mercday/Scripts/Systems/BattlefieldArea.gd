class_name BattlefieldArea extends RefCounted

const MIN_DIM := 20
const MAX_DIM := 50

# cells per area unit per density level; 0 = minimal, 4 = excessive
const COVER_DENSITY: Array[float] = [0.01, 0.03, 0.05, 0.08, 0.12]
const COVER_AMOUNT_NAMES: Array[String] = ["minimal", "some", "average", "many", "excessive"]

const SPAWN_BUFFER := 3

# Max buildings per combat, indexed by cover_amount (0-4)
const MAX_BUILDINGS_BY_DENSITY: Array[int] = [0, 0, 1, 2, 3]

const UNEVENNESS_NAMES: Array[String] = ["flat", "gentle", "hilly", "rough", "extreme", "mountainous", "interior"]
const UNEVENNESS_RANGE: Array[Vector2] = [
	Vector2(-2.0, 2.0),
	Vector2(-2.0, 2.0),
	Vector2(-2.0, 5.0),
	Vector2(-5.0, 5.0),
	Vector2(-5.0, 9.0),
	Vector2(-0.5, 2.0),
	Vector2(0.0,  0.0),
]

var width: int
var length: int
var height: int
var cover_amount: int
var unevenness: int = 0
var area_name: String = ""
var jagged_cells: Dictionary = {}
var fly_only_cells: Dictionary = {}
var obstacles: Array[Dictionary] = []   # [{pos, size, data, ?cell_type, ?door_open}]
var building_interiors: Dictionary = {} # Vector3i(x,y,floor_num) -> true (interior); Vector2i(x,y) -> true (exterior)
var building_data: Array[Dictionary] = []  # [{rect, door_facing, door_positions, name}]
var terrain_heights: Dictionary = {}    # Vector2i -> float; absent key = 0.0
# Generation log lines collected during _generate_cover(); flushed by EncounterLogger.log_generation().
var generation_log: Array[String] = []
var _obs_map: Dictionary = {}               # Vector2i -> obstacle dict; O(1) position lookup
var cover_obstacles: Array[Dictionary] = [] # pre-filtered to provides_cover==true; rebuilt after generation
var droppable_obs_map: Dictionary = {}      # Vector2i -> true; obstacles that have drops and are destroyable
var is_interior_map: bool = false
var cell_floor: Dictionary = {}              # DEPRECATED: superseded by Vector3i key floor component; removal pending full migration
var ceiling_cells: Dictionary = {}          # Vector3i(x,y,floor_num) -> true
var stairwell_cells: Dictionary = {}        # Vector3i(x,y,floor_num) -> true
var interior_floor_height: int = 4          # interior cell rows per floor strip
var interior_floor_depth: int = 0
var interior_top_y: int = 0
var interior_floor_y_starts: Dictionary = {} # DEPRECATED: int floor_num -> int y band offset; removal pending full migration
var interior_floor_elevations: Dictionary = {} # int floor_num -> int base elevation in cells above ground
var stairwell_connections: Dictionary = {}  # Vector3i -> Vector3i; maps stair entry cell to connected cell on adjacent floor
var interior_rooms: Array[Dictionary] = []   # interior only: [{rect, name, floor}] for wireframe labels

# Path width: 1 (extreme/dense) -> 3 (gentle/sparse). Computed from unevenness + cover_amount.
# Stored so ConnectivityVerifier can match the width used during nav path generation.
var path_width: int = 2

# Cells reserved as walkable corridors between spawns. Established before any obstacle or terrain
# effect placement so nothing can block them. Exposed to Pathfinder as passable_cells at runtime.
var reserved_corridor_cells: Dictionary = {}

var spawn_center_a: Vector2i = Vector2i.ZERO
var spawn_center_b: Vector2i = Vector2i.ZERO
var spawn_radius: float = 3.0
var spawn_zone_a: Dictionary = {}
var spawn_zone_b: Dictionary = {}


static func generate_random(config: BuildingConfig = null, context: GenerationContext = null, area_type: String = "Exterior") -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width  = randi_range(MIN_DIM, MAX_DIM)
	f.length = randi_range(MIN_DIM, MAX_DIM)
	f.height = randi_range(MIN_DIM, MAX_DIM)
	f.cover_amount = randi() % 5
	var area_data: Dictionary = DataManager.get_random_area(area_type)
	f.area_name = area_data.get("name", "Unknown")
	var weights: Array = area_data.get("weights", [])
	var total_w: int = 0
	for w: int in weights:
		total_w += w
	var ctx: GenerationContext = context if context != null else GenerationContext.new()
	if total_w == 0:
		f.unevenness = 6
		f.is_interior_map = true
		InteriorGenerator.generate_interior(f, area_data, ctx)
		return f
	var roll: int = randi() % total_w
	var cum: int = 0
	f.unevenness = 0
	for i: int in range(weights.size()):
		cum += (weights[i] as int)
		if roll < cum:
			f.unevenness = i
			break
	f._pick_spawn_centers(ctx)
	for _attempt: int in range(4):
		f._generate_cover(config)
		if f._is_spawn_connected() and f._approach_zone_ok():
			break
	return f


func _pick_spawn_centers(ctx: GenerationContext) -> void:
	var max_team: int = maxi(ctx.team_size_a, ctx.team_size_b)
	spawn_radius = maxf(3.0, float(max_team))
	spawn_radius = maxf(spawn_radius, sqrt(float(width * length)) / 12.0)
	var side_a: int = randi() % 4
	var side_b: int = side_a ^ 1
	spawn_center_a = _pick_side_center(side_a)
	spawn_center_b = _pick_side_center(side_b)
	spawn_zone_a = _build_spawn_zone(spawn_center_a)
	spawn_zone_b = _build_spawn_zone(spawn_center_b)


func _pick_side_center(side: int) -> Vector2i:
	var margin: int = clampi(ceili(sqrt(float(width * length)) / 10.0), 1, 6)
	match side:
		0:
			return Vector2i(randi_range(0, width - 1), randi_range(1, margin))
		1:
			return Vector2i(randi_range(0, width - 1), randi_range(length - 1 - margin, length - 2))
		2:
			return Vector2i(randi_range(1, margin), randi_range(0, length - 1))
		_:
			return Vector2i(randi_range(width - 1 - margin, width - 2), randi_range(0, length - 1))


func _build_spawn_zone(center: Vector2i) -> Dictionary:
	var zone: Dictionary = {}
	var ri: int = ceili(spawn_radius)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= length:
				continue
			if Vector2(float(dx), float(dy)).length() <= spawn_radius:
				zone[cell] = true
	return zone


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


func to_log_string() -> String:
	return to_header_string()


func to_header_string() -> String:
	var b_str := " (%d building%s)" % [building_data.size(), "s" if building_data.size() != 1 else ""] \
		if not building_data.is_empty() else ""
	var loc := ("[%s] " % area_name) if area_name != "" else ""
	return "Battlefield: %dx%d (height %d)  %s %s cover, %s terrain%s" % [
		width, length, height, loc, COVER_AMOUNT_NAMES[cover_amount],
		UNEVENNESS_NAMES[unevenness], b_str]


func to_visual_string() -> String:
	var pos_map: Dictionary = {}
	for obs: Dictionary in obstacles:
		var raw_pos = obs["pos"]
		var map_key: Vector2i
		if typeof(raw_pos) == TYPE_VECTOR3I:
			map_key = Vector2i((raw_pos as Vector3i).x, (raw_pos as Vector3i).y)
		else:
			map_key = raw_pos as Vector2i
		pos_map[map_key] = obs
	var rows: Array[String] = []
	for y: int in range(length):
		var row := ""
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if not pos_map.has(pos):
				var h: float = get_terrain_height(pos)
				if jagged_cells.has(pos):
					row += "[color=red]^[/color]"
				elif h <= -5.0:
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
					row += "[color=white]^[/color]"
			else:
				var obs: Dictionary = pos_map[pos]
				var d: ObstacleData = obs.get("data") as ObstacleData
				if d != null and d.ramp:
					row += "[color=cyan]S[/color]"
				else:
					var ct: String = obs.get("cell_type", "")
					if ct == "wall" or ct == "door":
						row += "[color=orange]#[/color]"
					elif d == null or not d.passthrough:
						row += "[color=orange]#[/color]"
					elif d.pt_enter_harm > 0 or d.pt_exit_harm > 0:
						row += "[color=red]*[/color]"
					else:
						row += "[color=pink]~[/color]"
		rows.append(row)
	return "\n".join(rows)


func is_building_interior(pos: Vector2i) -> bool:
	return building_interiors.has(pos)


func is_interior_cell(pos: Vector3i) -> bool:
	return building_interiors.has(pos)


func get_obstacle_at_floor(pos: Vector2i, floor_num: int) -> Dictionary:
	return _obs_map.get(Vector3i(pos.x, pos.y, floor_num), {}) as Dictionary


func get_nav_cells_for_floor(floor_num: int) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in building_interiors.keys():
		if typeof(key) == TYPE_VECTOR3I and (key as Vector3i).z == floor_num:
			var k3 := key as Vector3i
			result[Vector2i(k3.x, k3.y)] = true
	return result


func get_obstacle_at_3d(pos: Vector3i) -> Dictionary:
	return _obs_map.get(pos, {}) as Dictionary


func is_obstacle_3d(pos: Vector3i) -> bool:
	return _obs_map.has(pos)


func _generate_cover(config: BuildingConfig = null) -> void:
	generation_log.clear()
	var _gen_start := Time.get_ticks_msec()
	obstacles.clear()
	_obs_map.clear()
	cover_obstacles.clear()
	droppable_obs_map.clear()
	building_interiors.clear()
	building_data.clear()
	terrain_heights.clear()
	jagged_cells.clear()
	fly_only_cells.clear()
	reserved_corridor_cells.clear()
	ceiling_cells.clear()
	stairwell_cells.clear()
	stairwell_connections.clear()
	cell_floor.clear()
	interior_floor_y_starts.clear()
	interior_floor_elevations.clear()

	generation_log.append("Area: %s  terrain: %s" % [area_name, UNEVENNESS_NAMES[unevenness]])

	var _t := Time.get_ticks_msec()
	_reserve_spawn_corridors()
	var _ms := Time.get_ticks_msec() - _t
	generation_log.append("[GEN] corridor_reservation: %dms" % _ms)
	print("[GEN] corridor_reservation: %dms" % _ms)

	_t = Time.get_ticks_msec()
	TerrainGenerator.generate(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] base_terrain: %dms" % _ms)
	print("[GEN] base_terrain: %dms" % _ms)

	_smooth_corridor_edges()

	var density: float = COVER_DENSITY[cover_amount]
	var total_count: int = int(width * length * density)
	@warning_ignore("integer_division")
	var terrain_count: int = total_count / 4

	_t = Time.get_ticks_msec()
	var placed_terrain: int = ObstacleGenerator.place_terrain_obstacles(self, terrain_count)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] terrain_obstacles: %dms (%d placed)" % [_ms, placed_terrain])
	print("[GEN] terrain_obstacles: %dms (%d placed)" % [_ms, placed_terrain])

	_t = Time.get_ticks_msec()
	ObstacleGenerator.apply_terrain_effects(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] terrain_effects: %dms" % _ms)
	print("[GEN] terrain_effects: %dms" % _ms)

	TerrainGenerator.clamp_spawn_zones(self)

	_t = Time.get_ticks_msec()
	BuildingGenerator.generate_buildings(self, config)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] buildings: %dms" % _ms)
	print("[GEN] buildings: %dms" % _ms)

	generation_log.append("Spawn centers: Team-0=(%d,%d) r=%.1f  Team-1=(%d,%d) r=%.1f" % [
		spawn_center_a.x, spawn_center_a.y, spawn_radius,
		spawn_center_b.x, spawn_center_b.y, spawn_radius])
	if building_data.is_empty():
		generation_log.append("Buildings placed: 0")
	else:
		generation_log.append("Buildings placed: %d" % building_data.size())
		for i: int in range(building_data.size()):
			var b: Dictionary = building_data[i]
			var rect: Rect2i = b["rect"] as Rect2i
			generation_log.append("  Building %d [%s]: pos=(%d,%d) size=%dx%d" % [
				i + 1, b.get("name", "?"),
				rect.position.x, rect.position.y, rect.size.x, rect.size.y])

	_t = Time.get_ticks_msec()
	BuildingGenerator.place_furniture_in_buildings(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] furniture: %dms" % _ms)
	print("[GEN] furniture: %dms" % _ms)

	var scatter_count: int = total_count - terrain_count
	_t = Time.get_ticks_msec()
	var placed_scatter: int = ObstacleGenerator.place_obstacles(self, scatter_count)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed_scatter])
	print("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed_scatter])

	_t = Time.get_ticks_msec()
	_place_stairs_at_transitions()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] stairs: %dms" % _ms)
	print("[GEN] stairs: %dms" % _ms)

	var _az_a_blocked: bool = _spawn_exit_blocked(spawn_center_a, spawn_zone_a)
	var _az_b_blocked: bool = _spawn_exit_blocked(spawn_center_b, spawn_zone_b)
	if not _az_a_blocked and not _az_b_blocked:
		generation_log.append("[GEN] approach_zone: OK")
		print("[GEN] approach_zone: OK")
	else:
		var _az_parts: Array[String] = []
		if _az_a_blocked:
			_az_parts.append("Team-0")
		if _az_b_blocked:
			_az_parts.append("Team-1")
		var _az_msg: String = "[GEN] approach_zone: BLOCKED (%s)" % ", ".join(_az_parts)
		generation_log.append(_az_msg)
		print(_az_msg)

	_t = Time.get_ticks_msec()
	_ensure_pathability()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] pathability: %dms" % _ms)
	print("[GEN] pathability: %dms" % _ms)

	_t = Time.get_ticks_msec()
	ConnectivityVerifier.carve_corridor(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] spawn_connectivity: %dms" % _ms)
	print("[GEN] spawn_connectivity: %dms" % _ms)

	_t = Time.get_ticks_msec()
	ConnectivityVerifier.remove_pockets(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] pocket_removal: %dms" % _ms)
	print("[GEN] pocket_removal: %dms" % _ms)

	_t = Time.get_ticks_msec()
	ConnectivityVerifier.verify_spawn_approaches(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] spawn_approaches: %dms" % _ms)
	print("[GEN] spawn_approaches: %dms" % _ms)

	_t = Time.get_ticks_msec()
	_classify_fly_only_cells()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] fly_only_cells: %dms (%d classified)" % [_ms, fly_only_cells.size()])
	print("[GEN] fly_only_cells: %dms (%d classified)" % [_ms, fly_only_cells.size()])

	_rebuild_cover_obstacles()
	_rebuild_droppable_obs_map()

	var _total_ms := Time.get_ticks_msec() - _gen_start
	generation_log.append("[GEN] TOTAL: %dms  -  %s" % [_total_ms, to_header_string()])
	print("[GEN] TOTAL: %dms  -  %s" % [_total_ms, to_header_string()])


func _classify_fly_only_cells() -> void:
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var cell := Vector2i(x, y)
			if jagged_cells.has(cell):
				continue
			if _obs_map.has(cell):
				continue
			if reserved_corridor_cells.has(cell):
				continue
			var cell_h: float = get_terrain_height(cell)
			var reachable: bool = false
			for dir: Vector2i in cardinal:
				var nb := cell + dir
				if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
					continue
				if jagged_cells.has(nb):
					continue
				var h_diff: float = cell_h - get_terrain_height(nb)
				if h_diff <= 2.0:
					reachable = true
					break
			if not reachable:
				fly_only_cells[cell] = true


func _smooth_corridor_edges() -> void:
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for _pass: int in range(3):
		for cell: Vector2i in reserved_corridor_cells.keys():
			var sum: float = terrain_heights.get(cell, 0.0)
			var count: int = 1
			for dir: Vector2i in cardinal:
				var nb: Vector2i = cell + dir
				if nb.x >= 0 and nb.x < width and nb.y >= 0 and nb.y < length:
					sum += terrain_heights.get(nb, 0.0)
				count += 1
			terrain_heights[cell] = clampf(sum / float(count), -0.1, 0.1)


func _in_spawn_zone(pos: Vector2i) -> bool:
	return spawn_zone_a.has(pos) or spawn_zone_b.has(pos)


# Returns true only for solid, impassable non-door obstacles.
# Passthrough obstacles and doors are never "blocking" for path/spawn checks.
func _is_obstacle_at(pos: Vector2i) -> bool:
	var obs: Dictionary = _obs_map.get(pos, {}) as Dictionary
	if obs.is_empty():
		return false
	if obs.get("cell_type", "") == "door":
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null and (d.passthrough or d.ramp):
		return false
	return true


func _ensure_pathability() -> void:
	var skip: Dictionary = {}
	for k: Vector2i in reserved_corridor_cells.keys():
		skip[k] = true
	for k: Vector2i in jagged_cells.keys():
		skip[k] = true
	var _terrain_passes := 0
	while not _is_passable() and _terrain_passes < 5:
		TerrainGenerator.smooth(terrain_heights, width, length, skip)
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
			if visited.has(nxt) or _is_obstacle_at(nxt) or jagged_cells.has(nxt):
				continue
			var h_diff: float = absf(get_terrain_height(nxt) - get_terrain_height(curr))
			if h_diff > 0.5:
				continue
			if h_diff > 0.25 and not has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


func _is_spawn_connected() -> bool:
	return ConnectivityVerifier.spawns_connected(self)


func _spawn_exit_blocked(center: Vector2i, zone: Dictionary) -> bool:
	var outer: float = spawn_radius + 4.0
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in zone.keys():
		if not _is_obstacle_at(cell) and not jagged_cells.has(cell):
			visited[cell] = true
			queue.append(cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if Vector2(float(curr.x - center.x), float(curr.y - center.y)).length() > outer:
			return false
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt) or _is_obstacle_at(nxt) or jagged_cells.has(nxt):
				continue
			var h_diff: float = absf(get_terrain_height(nxt) - get_terrain_height(curr))
			if h_diff > 0.5:
				continue
			if h_diff > 0.25 and not has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return true


func _approach_zone_ok() -> bool:
	return not _spawn_exit_blocked(spawn_center_a, spawn_zone_a) \
		and not _spawn_exit_blocked(spawn_center_b, spawn_zone_b)


func is_obstacle(pos: Vector2i) -> bool:
	return _is_obstacle_at(pos)


func get_obstacle_at(pos: Vector2i) -> Dictionary:
	return _obs_map.get(pos, {}) as Dictionary


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


func get_terrain_height(pos: Vector2i) -> float:
	return terrain_heights.get(pos, 0.0)


func has_stairs_at(pos: Vector2i) -> bool:
	var obs := get_obstacle_at(pos)
	if obs.is_empty():
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	return d != null and d.ramp


func _reserve_spawn_corridors() -> void:
	reserved_corridor_cells.clear()
	var difficulty: int = unevenness + cover_amount
	var map_area: int = width * length
	var max_width: int = 1 if map_area < 600 else (2 if map_area < 1500 else 3)
	if difficulty <= 1:
		path_width = min(3, max_width)
	elif difficulty <= 4:
		path_width = min(2, max_width)
	else:
		path_width = 1
	@warning_ignore("integer_division")
	var max_paths: int = clampi(1 + map_area / 600, 1, 3)
	if unevenness >= 4:
		max_paths = mini(max_paths, 2)
	var fork_count: int = randi_range(0, max_paths - 1)

	var delta := Vector2(float(spawn_center_b.x - spawn_center_a.x),
		float(spawn_center_b.y - spawn_center_a.y))
	var perp := Vector2(-delta.normalized().y, delta.normalized().x)
	var max_offset: float = minf(float(width), float(length)) * 0.3

	var num_waypoints: int = randi_range(2, 5)
	var waypoints: Array[Vector2i] = [spawn_center_a]
	for i: int in range(num_waypoints):
		var t: float = float(i + 1) / float(num_waypoints + 1)
		var base := Vector2(float(spawn_center_a.x), float(spawn_center_a.y)) + delta * t
		var offset: float = randf_range(-max_offset, max_offset)
		waypoints.append(Vector2i(
			clampi(int(base.x + perp.x * offset), 0, width - 1),
			clampi(int(base.y + perp.y * offset), 0, length - 1)))
	waypoints.append(spawn_center_b)

	for i: int in range(waypoints.size() - 1):
		_carve_path_segment(waypoints[i], waypoints[i + 1])

	for _f: int in range(fork_count):
		var src_idx: int = randi_range(1, waypoints.size() - 2)
		var fork_offset: float = randf_range(-max_offset * 0.5, max_offset * 0.5)
		var fork_end := Vector2i(
			clampi(int(float(spawn_center_b.x) + perp.x * fork_offset), 0, width - 1),
			clampi(int(float(spawn_center_b.y) + perp.y * fork_offset), 0, length - 1))
		_carve_path_segment(waypoints[src_idx], fork_end)

	generation_log.append("Corridor reservation: %d waypoint(s), %d fork(s), width=%d, %d cells reserved" % [
		num_waypoints, fork_count, path_width, reserved_corridor_cells.size()])


func _carve_path_segment(from_pt: Vector2i, to_pt: Vector2i) -> void:
	var hw: int = path_width >> 1
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
				clampi(pos.x + perp.x * p, 0, width - 1),
				clampi(pos.y + perp.y * p, 0, length - 1))
			reserved_corridor_cells[cell] = true
			terrain_heights[cell] = 0.0
		pos += step
	var end_perp := Vector2i(1, 0) if (to_pt.x - from_pt.x) == 0 else Vector2i(0, 1)
	for p: int in range(-hw, hw + 1):
		var cell := Vector2i(
			clampi(pos.x + end_perp.x * p, 0, width - 1),
			clampi(pos.y + end_perp.y * p, 0, length - 1))
		reserved_corridor_cells[cell] = true
		terrain_heights[cell] = 0.0


func get_nav_passable_cells() -> Dictionary:
	return reserved_corridor_cells


func _place_stairs_at_transitions() -> void:
	var stairs_template: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	if stairs_template == null:
		return
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if _in_spawn_zone(pos) or _is_obstacle_at(pos) or building_interiors.has(pos):
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
				var _stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template}
				obstacles.append(_stair_obs)
				_obs_map[pos] = _stair_obs


func _rebuild_cover_obstacles() -> void:
	cover_obstacles.clear()
	for obs: Dictionary in obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.covers:
			cover_obstacles.append(obs)


static func get_ray_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return result
	var nx := absi(dx)
	var ny := absi(dy)
	var sign_x := signi(dx)
	var sign_y := signi(dy)
	var p := Vector2i(from.x, from.y)
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var sc_x := (2 * ix + 1) * ny
		var sc_y := (2 * iy + 1) * nx
		if sc_x < sc_y:
			p.x += sign_x
			ix += 1
		elif sc_y < sc_x:
			p.y += sign_y
			iy += 1
		else:
			p.x += sign_x
			p.y += sign_y
			ix += 1
			iy += 1
		if p != to:
			result.append(p)
	return result


func get_ray_cover(atk_pos: Vector2i, def_pos: Vector2i, atk_height: int, def_size: int) -> String:
	var ray := BattlefieldArea.get_ray_cells(atk_pos, def_pos)
	var best := ""
	for cell: Vector2i in ray:
		var obs: Dictionary = _obs_map.get(cell, {}) as Dictionary
		if obs.is_empty():
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or not d.covers:
			continue
		if obs.get("cell_type", "") == "door" and (obs.get("door_open", false) as bool):
			continue
		var horiz_dist := maxi(abs(atk_pos.x - cell.x), abs(atk_pos.y - cell.y))
		if atk_height > 0 and atk_height >= d.size + horiz_dist:
			continue
		if d.narrow:
			if best == "":
				best = "partial"
		elif d.size >= def_size:
			return "full"
		else:
			if best == "":
				best = "partial"
	return best


func _rebuild_droppable_obs_map() -> void:
	droppable_obs_map.clear()
	for obs: Dictionary in obstacles:
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.health == 0 or d.drops.is_empty() or d.passthrough or d.ramp:
			continue
		var raw_pos = obs.get("pos", Vector2i(-1, -1))
		var pos: Vector2i
		if typeof(raw_pos) == TYPE_VECTOR3I:
			pos = Vector2i((raw_pos as Vector3i).x, (raw_pos as Vector3i).y)
		else:
			pos = raw_pos as Vector2i
		if pos.x >= 0:
			droppable_obs_map[pos] = true

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
# Generation log lines collected during _generate_cover(); flushed by EncounterLogger.log_generation().
var generation_log: Array[String] = []
var _obs_map: Dictionary = {}               # Vector2i -> obstacle dict; O(1) position lookup
var cover_obstacles: Array[Dictionary] = [] # pre-filtered to provides_cover==true; rebuilt after generation

# Path width: 1 (extreme/dense) -> 3 (gentle/sparse). Computed from unevenness + cover_amount.
# Stored so ConnectivityVerifier can match the width used during nav path generation.
var path_width: int = 2

# Cells reserved as walkable corridors between spawns. Established before any obstacle or terrain
# effect placement so nothing can block them. Exposed to Pathfinder as passable_cells at runtime.
var reserved_corridor_cells: Dictionary = {}


static func generate_random() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width  = randi_range(MIN_DIM, MAX_DIM)
	f.length = randi_range(MIN_DIM, MAX_DIM)
	f.height = randi_range(MIN_DIM, MAX_DIM)
	f.cover_amount = randi() % 5
	f.unevenness = randi() % 5
	for _attempt: int in range(4):
		f._generate_cover()
		if f._is_spawn_connected() and f._approach_zone_ok():
			break
	return f


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


func to_log_string() -> String:
	return to_header_string()


func to_header_string() -> String:
	var b_str := " (%d building%s)" % [building_data.size(), "s" if building_data.size() != 1 else ""] \
		if not building_data.is_empty() else ""
	return "Battlefield: %dx%d (height %d)  -  %s cover, %s terrain%s" % [
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


func is_interior(pos: Vector2i) -> bool:
	return building_interiors.has(pos)


func _generate_cover() -> void:
	generation_log.clear()
	var _gen_start := Time.get_ticks_msec()
	obstacles.clear()
	_obs_map.clear()
	cover_obstacles.clear()
	building_interiors.clear()
	building_data.clear()
	terrain_heights.clear()

	reserved_corridor_cells.clear()
	var _t := Time.get_ticks_msec()
	TerrainGenerator.generate(width, length, unevenness, terrain_heights)
	var _ms := Time.get_ticks_msec() - _t
	generation_log.append("[GEN] base_terrain: %dms" % _ms)
	print("[GEN] base_terrain: %dms" % _ms)

	_t = Time.get_ticks_msec()
	_reserve_spawn_corridors()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] corridor_reservation: %dms" % _ms)
	print("[GEN] corridor_reservation: %dms" % _ms)

	var density: float = COVER_DENSITY[cover_amount]
	var target_count: int = int(width * length * density)
	_t = Time.get_ticks_msec()
	var placed: int = ObstacleGenerator.place_obstacles(self, target_count)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed])
	print("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed])

	_t = Time.get_ticks_msec()
	BuildingGenerator.generate_buildings(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] buildings: %dms" % _ms)
	print("[GEN] buildings: %dms" % _ms)

	var spawn_a := Vector2i(width >> 1, 2)
	var spawn_b := Vector2i(width >> 1, length - 3)
	generation_log.append("Spawn centers: Team-0=(%d,%d)  Team-1=(%d,%d)" % [
		spawn_a.x, spawn_a.y, spawn_b.x, spawn_b.y])
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

	_t = Time.get_ticks_msec()
	ObstacleGenerator.apply_terrain_effects(self)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] terrain_effects: %dms" % _ms)
	print("[GEN] terrain_effects: %dms" % _ms)

	# Diagnostic: log any dangerous terrain heights in the approach zone immediately outside spawn.
	var _az_warns: Array[String] = []
	for _az_x: int in range(width):
		for _az_off: int in range(SPAWN_BUFFER, SPAWN_BUFFER + 4):
			for _az_y: int in [_az_off, length - 1 - _az_off]:
				var _az_cell := Vector2i(_az_x, _az_y)
				var _az_h: float = terrain_heights.get(_az_cell, 0.0)
				if _az_h < -0.3:
					_az_warns.append("(%d,%d)=%.2f" % [_az_cell.x, _az_cell.y, _az_h])
	if _az_warns.is_empty():
		generation_log.append("[GEN] approach_zone: OK")
		print("[GEN] approach_zone: OK")
	else:
		var _az_msg: String = "[GEN] approach_zone: WARNING %d cells h<-0.3: " % _az_warns.size() + ", ".join(_az_warns)
		generation_log.append(_az_msg)
		print("[GEN] approach_zone: WARNING %d cells" % _az_warns.size())

	_t = Time.get_ticks_msec()
	_place_stairs_at_transitions()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] stairs: %dms" % _ms)
	print("[GEN] stairs: %dms" % _ms)

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

	_rebuild_cover_obstacles()

	var _total_ms := Time.get_ticks_msec() - _gen_start
	generation_log.append("[GEN] TOTAL: %dms  -  %s" % [_total_ms, to_header_string()])
	print("[GEN] TOTAL: %dms  -  %s" % [_total_ms, to_header_string()])


func _in_spawn_zone(pos: Vector2i) -> bool:
	return pos.y < SPAWN_BUFFER or pos.y >= length - SPAWN_BUFFER


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
	# Corridors are pre-reserved flat and obstacle-free, so obstacle removal is no longer needed.
	# Smooth terrain only to resolve any remaining gradient issues on non-corridor cells.
	var _terrain_passes := 0
	while not _is_passable() and _terrain_passes < 5:
		TerrainGenerator.smooth(terrain_heights, width, length)
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


func _is_spawn_connected() -> bool:
	return ConnectivityVerifier.spawns_connected(self)


# Returns true if the approach zone near each spawn has no severe terrain pits.
# A pit is defined as h < -1.0; more than 10 such cells in the approach zone triggers a re-roll.
func _approach_zone_ok() -> bool:
	var severe := 0
	for x: int in range(width):
		for off: int in range(SPAWN_BUFFER, SPAWN_BUFFER + 6):
			for y: int in [off, length - 1 - off]:
				if terrain_heights.get(Vector2i(x, y), 0.0) < -1.0:
					severe += 1
					if severe > 10:
						return false
	return true


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
	if difficulty <= 1:
		path_width = 3
	elif difficulty <= 4:
		path_width = 2
	else:
		path_width = 1
	var half_width: int = path_width >> 1

	var spawn_a := Vector2i(width >> 1, SPAWN_BUFFER)
	var spawn_b := Vector2i(width >> 1, length - SPAWN_BUFFER - 1)
	var path_count: int = randi_range(1, 3)
	var path_centers: Array[int] = []
	for p: int in range(path_count):
		var x_offset: int = (p - 1) * maxi(2, int(float(width) / 6.0))
		var ax: int = clamp(spawn_a.x + x_offset, 1, width - 2)
		var bx: int = clamp(spawn_b.x + x_offset, 1, width - 2)
		var ay: int = spawn_a.y
		var by_: int = spawn_b.y
		var steps: int = absi(by_ - ay) + absi(bx - ax)
		var cx: int = ax
		var cy: int = ay
		for _s: int in range(steps + 1):
			for dx: int in range(-half_width, half_width + 1):
				var cell := Vector2i(clamp(cx + dx, 0, width - 1), cy)
				reserved_corridor_cells[cell] = true
				terrain_heights[cell] = 0.0
			if cx != bx:
				cx += signi(bx - cx)
			elif cy != by_:
				cy += signi(by_ - cy)
		path_centers.append(ax)

	# Lateral bridge connecting isolated corridor paths at map midpoint.
	if path_count > 1:
		@warning_ignore("integer_division")
		var bridge_y: int = (SPAWN_BUFFER + length - SPAWN_BUFFER - 1) / 2
		path_centers.sort()
		for pi: int in range(path_centers.size() - 1):
			var x_left: int = path_centers[pi]
			var x_right: int = path_centers[pi + 1]
			for bx2: int in range(x_left, x_right + 1):
				var cell := Vector2i(clamp(bx2, 0, width - 1), bridge_y)
				reserved_corridor_cells[cell] = true
				terrain_heights[cell] = 0.0

	# Post-reservation corridor smoothing -- clamp corridor cells tightly to 0.0 height.
	# Three passes average each cell with its cardinal neighbours then re-clamp to [-0.1, 0.1]
	# so terrain noise or effects cannot leave gradients inside reserved corridors.
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

	generation_log.append("Corridor reservation: %d path(s), width=%d, %d cells reserved" % [
		path_count, path_width, reserved_corridor_cells.size()])


func get_nav_passable_cells() -> Dictionary:
	return reserved_corridor_cells


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
				var _stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template}
				obstacles.append(_stair_obs)
				_obs_map[pos] = _stair_obs


func _rebuild_cover_obstacles() -> void:
	cover_obstacles.clear()
	for obs: Dictionary in obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.covers:
			cover_obstacles.append(obs)

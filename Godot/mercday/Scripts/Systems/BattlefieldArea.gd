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
var _obs_map: Dictionary = {}               # Vector2i → obstacle dict; O(1) position lookup
var cover_obstacles: Array[Dictionary] = [] # pre-filtered to provides_cover==true; rebuilt after generation

# Path width: 1 (extreme/dense) -> 3 (gentle/sparse). Computed from unevenness + cover_amount.
# Stored so _carve_spawn_corridor_step can match the width used during nav path generation.
var path_width: int = 2

# Cells reserved as walkable corridors between spawns. Established before any obstacle or terrain
# effect placement so nothing can block them. Exposed to Pathfinder as passable_cells at runtime.
var reserved_corridor_cells: Dictionary = {}

static var _door_template: ObstacleData


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
	_generate_base_terrain()
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
	var placed := 0
	var max_attempts := target_count * 30
	_t = Time.get_ticks_msec()
	for _i: int in range(max_attempts):
		if placed >= target_count:
			break
		var pos := Vector2i(randi() % width, randi() % length)
		if _in_spawn_zone(pos) or _is_obstacle_at(pos):
			continue
		if reserved_corridor_cells.has(pos):
			continue
		var template: ObstacleData = DataManager.get_random_obstacle()
		if not _terrain_compatible(template, pos):
			continue
		var _new_obs := {"pos": pos, "size": template.size, "data": template}
		obstacles.append(_new_obs)
		_obs_map[pos] = _new_obs
		placed += 1
		placed += _expand_obstacle(template, pos, target_count - placed)
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed])
	print("[GEN] obstacle_placement: %dms (%d placed)" % [_ms, placed])

	_t = Time.get_ticks_msec()
	_generate_buildings()
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
	_place_furniture_in_buildings()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] furniture: %dms" % _ms)
	print("[GEN] furniture: %dms" % _ms)

	_t = Time.get_ticks_msec()
	_apply_obstacle_terrain_effects()
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
	_ensure_spawn_connectivity()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] spawn_connectivity: %dms" % _ms)
	print("[GEN] spawn_connectivity: %dms" % _ms)

	_t = Time.get_ticks_msec()
	_remove_isolated_pockets()
	_ms = Time.get_ticks_msec() - _t
	generation_log.append("[GEN] pocket_removal: %dms" % _ms)
	print("[GEN] pocket_removal: %dms" % _ms)

	_rebuild_cover_obstacles()

	var _total_ms := Time.get_ticks_msec() - _gen_start
	generation_log.append("[GEN] TOTAL: %dms — %s" % [_total_ms, to_header_string()])
	print("[GEN] TOTAL: %dms — %s" % [_total_ms, to_header_string()])


func _generate_buildings() -> void:
	if DataManager.building_pool.is_empty():
		return
	var max_b: int = MAX_BUILDINGS_BY_DENSITY[cover_amount]
	for _i: int in range(max_b):
		var template: ObstacleData = DataManager.building_pool[randi() % DataManager.building_pool.size()]
		_place_building(template)


# Returns true if any cell of the footprint (tl, wxh) overlaps the central keep-clear zone.
# The keep-clear zone is a 3-tile-wide vertical strip centered on the spawn X coordinate,
# spanning the full map length between spawn buffers.  Prevents buildings from entirely
# sealing the primary north-south navigation corridor.
func _footprint_in_keep_clear(tl: Vector2i, w: int, h: int) -> bool:
	var cx: int = width >> 1
	for bx: int in range(w):
		var cell_x: int = tl.x + bx
		if cell_x >= cx - 1 and cell_x <= cx + 1:
			for by: int in range(h):
				var cell_y: int = tl.y + by
				if cell_y >= SPAWN_BUFFER and cell_y < length - SPAWN_BUFFER:
					return true
	return false


func _place_building(template: ObstacleData) -> void:
	# Compute interior dimensions from floor area (size ~ floor area in cells)
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

		# Rule 2: reject placements that overlap the central keep-clear corridor.
		if _footprint_in_keep_clear(tl, outer_w, outer_h):
			continue

		var nav_overlap := false
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				if reserved_corridor_cells.has(tl + Vector2i(bx, by)):
					nav_overlap = true
					break
			if nav_overlap:
				break
		if nav_overlap:
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

		# --- Rule 1: connectivity rollback ---
		# Snapshot mutable state before writing so we can undo if the building
		# breaks spawn connectivity.
		var snap_obstacles: Array[Dictionary] = obstacles.duplicate(false)
		var snap_obs_map: Dictionary = _obs_map.duplicate(false)
		var snap_interiors: Dictionary = building_interiors.duplicate(false)
		var snap_terrain: Dictionary = terrain_heights.duplicate(false)

		# Flatten terrain under the entire building footprint
		var h_sum: float = 0.0
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				h_sum += get_terrain_height(tl + Vector2i(bx, by))
		var flat_h: float = clampf(h_sum / float(outer_w * outer_h), -0.25, 0.25)
		for bx: int in range(outer_w):
			for by: int in range(outer_h):
				terrain_heights[tl + Vector2i(bx, by)] = flat_h

		# Place wall + door + window cells
		var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
		var wall_size: int = maxi(3, template.height_min)

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
						var _door_obs := {"pos": cell, "size": 2,
							"data": _get_door_template(), "cell_type": "door", "door_open": false}
						obstacles.append(_door_obs)
						_obs_map[cell] = _door_obs
					elif window_positions.has(cell):
						var _win_obs := {"pos": cell, "size": 2,
							"data": window_data, "cell_type": "window"}
						obstacles.append(_win_obs)
						_obs_map[cell] = _win_obs
					else:
						var _wall_obs := {"pos": cell, "size": wall_size,
							"data": wall_data, "cell_type": "wall"}
						obstacles.append(_wall_obs)
						_obs_map[cell] = _wall_obs
				else:
					building_interiors[cell] = true

		# Rule 1: verify connectivity; roll back if the building breaks it.
		if not _is_spawn_connected():
			obstacles = snap_obstacles
			_obs_map = snap_obs_map
			building_interiors = snap_interiors
			terrain_heights = snap_terrain
			generation_log.append(
				"Building rejected: would disconnect spawns at pos=(%d,%d) size=%dx%d" % [
				tl.x, tl.y, outer_w, outer_h])
			continue  # try another position for this template

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
			if reserved_corridor_cells.has(cell):
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
			var _furn_obs := {"pos": free_cells[i], "size": furn.size,
				"data": furn, "cell_type": "furniture"}
			obstacles.append(_furn_obs)
			_obs_map[free_cells[i]] = _furn_obs


func _expand_obstacle(template: ObstacleData, origin: Vector2i, budget: int) -> int:
	var added := 0
	var odds: int = template.expansion_odds
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	# Cache corridor cells once to avoid O(n^3) per-expansion lookup.
	var corridor_cells: Array = reserved_corridor_cells.keys()
	var expansion_safety_radius: int = 1 + (path_width >> 1)
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
			if reserved_corridor_cells.has(np):
				continue
			# Reject expansion into the exclusion radius around any corridor cell.
			var too_close := false
			for cc: Vector2i in corridor_cells:
				if maxi(abs(np.x - cc.x), abs(np.y - cc.y)) <= expansion_safety_radius:
					too_close = true
					break
			if too_close:
				continue
			if not _terrain_compatible(template, np):
				continue
			var _exp_obs := {"pos": np, "size": template.size, "data": template}
			obstacles.append(_exp_obs)
			_obs_map[np] = _exp_obs
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
	var obs: Dictionary = _obs_map.get(pos, {}) as Dictionary
	if obs.is_empty():
		return false
	if obs.get("cell_type", "") == "door":
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null and (d.passthrough or d.is_stairs):
		return false
	return true


func _ensure_pathability() -> void:
	# Corridors are pre-reserved flat and obstacle-free, so obstacle removal is no longer needed.
	# Smooth terrain only to resolve any remaining gradient issues on non-corridor cells.
	var _terrain_passes := 0
	while not _is_passable() and _terrain_passes < 5:
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


# Returns true if `from` can step into `to` using the same rules as _is_spawn_connected.
func _spawn_step_ok(from: Vector2i, to: Vector2i) -> bool:
	if to.x < 0 or to.x >= width or to.y < 0 or to.y >= length:
		return false
	var obs: Dictionary = get_obstacle_at(to)
	if not obs.is_empty():
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			return false
		if ct == "door":
			if not obs.get("door_open", false):
				return false
		else:
			var d_data: ObstacleData = obs.get("data") as ObstacleData
			if d_data != null and not d_data.passthrough and not d_data.is_stairs:
				return false
	var h_diff: float = get_terrain_height(to) - get_terrain_height(from)
	if h_diff > 0.5:
		return false
	if h_diff <= -1.0:
		if int(floor(-h_diff)) >= 4:
			return false
	elif absf(h_diff) > 0.25 and not has_stairs_at(to):
		return false
	return true


# Returns true if `cell` has at least one neighbour that can be stepped into from it.
# Mirrors Pathfinder._has_exit so the connectivity BFS skips one-way-entry traps.
func _spawn_cell_has_exit(cell: Vector2i, dirs: Array[Vector2i]) -> bool:
	for d: Vector2i in dirs:
		if _spawn_step_ok(cell, cell + d):
			return true
	return false


# Check connectivity using Pathfinder-accurate blocking rules (closed doors are impassable).
# Returns true if any Team-0 spawn cell can reach any Team-1 spawn cell.
func _is_spawn_connected() -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	# Seed from all non-blocked cells in team-A's spawn rows for robustness against
	# a blocked single seed point.
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for seed_y: int in range(SPAWN_BUFFER + 2):
		for seed_x: int in range(width):
			var seed_cell := Vector2i(seed_x, seed_y)
			if not _is_obstacle_at(seed_cell) and not visited.has(seed_cell) \
					and _spawn_cell_has_exit(seed_cell, dirs):
				visited[seed_cell] = true
				queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if curr.y >= length - SPAWN_BUFFER - 2:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(curr, nxt):
				continue
			if nxt.y < length - SPAWN_BUFFER - 2 and not _spawn_cell_has_exit(nxt, dirs):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


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


# Carve one step toward restoring spawn connectivity.
# Selects the best blocking tile using a directional bias: tiles that reduce
# Chebyshev distance to the target spawn (spawn_b) are heavily preferred so
# the carve algorithm actively drives toward the disconnected spawn rather than
# wandering to the geometric midpoint of the map.
# The carve width matches path_width so cleared corridors are consistent with
# the nav paths generated earlier.
# Returns a description of each tile carved (for generation logging).
func _carve_spawn_corridor_step() -> Array[String]:
	var spawn_a := Vector2i(width >> 1, 2)
	var spawn_b := Vector2i(width >> 1, length - 3)

	# Find the frontier of the BFS from spawn_a: the last reachable cell before
	# connectivity breaks.  We want to carve near tiles adjacent to this frontier
	# that are close to spawn_b -- i.e., tiles that would actually open a new path.
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn_a]
	visited[spawn_a] = true
	var dirs8: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	# BFS to map reachable cells using the same rules as _is_spawn_connected.
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in dirs8:
			var nxt: Vector2i = curr + d
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(curr, nxt):
				continue
			if not _spawn_cell_has_exit(nxt, dirs8):
				continue
			visited[nxt] = true
			queue.append(nxt)

	# Collect all impassable tiles and score them.
	# Primary key: Chebyshev distance to spawn_b -- tiles closer to the target get carved first.
	# Secondary key: proximity to a reachable frontier cell -- prefer tiles adjacent to the BFS frontier.
	# Tertiary key: perpendicular distance to A->B segment -- prefer tiles near the corridor axis.
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
			# Also treat steep terrain or no-exit traps as blocking.
			if not is_blocking:
				if not _spawn_cell_has_exit(pos, dirs8):
					is_blocking = true
				else:
					var dirs_t: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
					for d: Vector2i in dirs_t:
						var nb: Vector2i = pos + d
						if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
							continue
						var h_diff: float = get_terrain_height(pos) - get_terrain_height(nb)
						var terrain_blocks: bool
						if h_diff > 0.5:
							terrain_blocks = true
						elif h_diff <= -1.0:
							terrain_blocks = int(floor(-h_diff)) >= 4
						elif absf(h_diff) > 0.25 and not has_stairs_at(pos):
							terrain_blocks = true
						else:
							terrain_blocks = false
						if terrain_blocks:
							is_blocking = true
							break
				if not is_blocking:
					continue  # already passable, skip

			# Only consider tiles adjacent to at least one reachable cell.
			# This focuses carving on the actual blockage boundary rather than
			# arbitrary interior obstacles.
			var adj_to_frontier := false
			for d: Vector2i in dirs8:
				if visited.has(pos + d):
					adj_to_frontier = true
					break
			if not adj_to_frontier:
				continue

			# Score: Chebyshev distance to spawn_b (primary -- directional bias toward target).
			var cheby_b: float = float(maxi(absi(x - spawn_b.x), absi(y - spawn_b.y)))

			# Perpendicular distance to segment A->B (secondary -- keep carving near corridor axis).
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

			# Combined score: directional bias dominates, corridor alignment is tiebreak.
			var score := cheby_b * 10.0 + perp_dist
			if score < best_score:
				best_score = score
				best_pos = pos

	var carved_log: Array[String] = []
	if best_pos == Vector2i(-1, -1):
		return carved_log  # nothing to carve

	# Determine widening direction: perpendicular to the A->B axis.
	# A->B is primarily vertical (same x), so the perpendicular is horizontal.
	# More generally: if |dy| >= |dx| the corridor is more vertical, widen along x.
	var delta := spawn_b - spawn_a
	var perp: Vector2i
	if abs(delta.y) >= abs(delta.x):
		perp = Vector2i(1, 0)   # corridor runs north-south -> widen east-west
	else:
		perp = Vector2i(0, 1)   # corridor runs east-west -> widen north-south

	# Build the set of positions to carve: center + +/-half_width in perpendicular direction.
	# Use the same path_width computed during _generate_nav_paths so carve corridors are
	# consistent with the nav cells already reserved.
	var half_w: int = path_width >> 1
	var carve_candidates: Array[Vector2i] = [best_pos]
	for w: int in range(1, half_w + 1):
		carve_candidates.append(best_pos + perp * w)
		carve_candidates.append(best_pos - perp * w)
	# Always include at least +/-1 so a single carve step opens a traversable gap.
	if half_w == 0:
		carve_candidates.append(best_pos + perp)
		carve_candidates.append(best_pos - perp)

	# Carve each candidate only if it is actually impassable (don't overwrite open floor).
	for cp: Vector2i in carve_candidates:
		# Bounds check -- skip any candidate that falls outside the map.
		if cp.x < 0 or cp.x >= width or cp.y < 0 or cp.y >= length:
			continue
		# Only carve if this tile is blocking (same test as the scoring loop above).
		var cp_obs: Dictionary = get_obstacle_at(cp)
		var cp_blocking := false
		var cp_prev_type := "terrain"
		if not cp_obs.is_empty():
			var ct: String = cp_obs.get("cell_type", "")
			if ct == "wall" or ct == "door":
				cp_blocking = true
				cp_prev_type = ct
			elif ct != "furniture":
				var d_data: ObstacleData = cp_obs.get("data") as ObstacleData
				if d_data != null and not d_data.passthrough and not d_data.is_stairs:
					cp_blocking = true
					cp_prev_type = d_data.obstacle_name if d_data != null else "obstacle"
		if not cp_blocking:
			# Check terrain blocking or no-exit trap for non-obstacle tiles.
			if not _spawn_cell_has_exit(cp, dirs8):
				cp_blocking = true
				cp_prev_type = "steep-terrain"
			else:
				var dirs_t: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
				for d: Vector2i in dirs_t:
					var nb: Vector2i = cp + d
					if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
						continue
					var h_diff: float = get_terrain_height(cp) - get_terrain_height(nb)
					var cp_terrain_blocks: bool
					if h_diff > 0.5:
						cp_terrain_blocks = true
					elif h_diff <= -1.0:
						cp_terrain_blocks = int(floor(-h_diff)) >= 4
					elif absf(h_diff) > 0.25 and not has_stairs_at(cp):
						cp_terrain_blocks = true
					else:
						cp_terrain_blocks = false
					if cp_terrain_blocks:
						cp_blocking = true
						cp_prev_type = "steep-terrain"
						break
		if not cp_blocking:
			continue

		# Remove all obstacle entries at this position.
		_obs_map.erase(cp)
		var idx: int = obstacles.size() - 1
		while idx >= 0:
			if (obstacles[idx]["pos"] as Vector2i) == cp:
				obstacles.remove_at(idx)
			idx -= 1
		# Also clear interior flag so the tile is no longer treated as a building cell.
		building_interiors.erase(cp)
		# For terrain-height-blocked tiles, match the height of the nearest reachable
		# frontier neighbor so the gradient is eliminated rather than replaced by a cliff
		# in the opposite direction.  For obstacle-cleared tiles, flatten to 0.0.
		if cp_prev_type == "steep-terrain":
			var dirs_c: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
			var matched := false
			for d: Vector2i in dirs_c:
				var nb: Vector2i = cp + d
				if visited.has(nb):
					terrain_heights[cp] = terrain_heights.get(nb, 0.0)
					matched = true
					break
			if not matched:
				terrain_heights[cp] = 0.0
		else:
			terrain_heights[cp] = 0.0
		reserved_corridor_cells[cp] = true
		var label := "center" if cp == best_pos else ("wing+%d,%d" % [cp.x - best_pos.x, cp.y - best_pos.y])
		carved_log.append("  carve (%d,%d) [%s] prev=%s" % [cp.x, cp.y, label, cp_prev_type])

	return carved_log


func _ensure_spawn_connectivity() -> void:
	var max_carve := (width + length) * 4  # safety cap -- never infinite loop
	var passes := 0
	while not _is_spawn_connected() and passes < max_carve:
		var step_log: Array[String] = _carve_spawn_corridor_step()
		for entry: String in step_log:
			generation_log.append("Carve step %d: %s" % [passes + 1, entry.strip_edges()])
		passes += 1
	if not _is_spawn_connected():
		push_warning("Hard guarantee pass: direct corridor carve between spawns")
		var spawn_a := Vector2i(width >> 1, 2)
		var spawn_b := Vector2i(width >> 1, length - 3)
		_carve_direct_corridor(spawn_a, spawn_b)
	generation_log.append("Connectivity: %s after %d carve step(s)" % [
		"CONNECTED" if _is_spawn_connected() else "DISCONNECTED", passes])


func _remove_isolated_pockets() -> void:
	var dirs8: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = []
	for seed_y: int in range(SPAWN_BUFFER + 2):
		for seed_x: int in range(width):
			var seed_cell := Vector2i(seed_x, seed_y)
			if not _is_obstacle_at(seed_cell) and not reachable.has(seed_cell):
				reachable[seed_cell] = true
				queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in dirs8:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if reachable.has(nxt):
				continue
			if not _spawn_step_ok(curr, nxt):
				continue
			reachable[nxt] = true
			queue.append(nxt)

	var pockets: Array[Vector2i] = []
	for y: int in range(SPAWN_BUFFER, length - SPAWN_BUFFER):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if not _is_obstacle_at(pos) and not reachable.has(pos):
				pockets.append(pos)

	if pockets.is_empty():
		generation_log.append("Pocket check: no isolated walkable cells")
		return

	var carved := 0
	for pc: Vector2i in pockets:
		if reachable.has(pc):
			continue
		var best := Vector2i(-1, -1)
		var best_d := 9999
		for rc: Vector2i in reachable.keys():
			var cheby: int = maxi(absi(pc.x - rc.x), absi(pc.y - rc.y))
			if cheby < best_d:
				best_d = cheby
				best = rc
		if best == Vector2i(-1, -1):
			continue
		var cx := best.x
		var cy := best.y
		while Vector2i(cx, cy) != pc:
			if cx != pc.x:
				cx += signi(pc.x - cx)
			elif cy != pc.y:
				cy += signi(pc.y - cy)
			var step := Vector2i(cx, cy)
			_obs_map.erase(step)
			var idx: int = obstacles.size() - 1
			while idx >= 0:
				if (obstacles[idx]["pos"] as Vector2i) == step:
					obstacles.remove_at(idx)
				idx -= 1
			building_interiors.erase(step)
			terrain_heights[step] = 0.0
			reserved_corridor_cells[step] = true
			reachable[step] = true
			carved += 1
		reachable[pc] = true

	generation_log.append("Pocket check: %d pocket cell(s) found, %d cell(s) carved to connect" % [pockets.size(), carved])


# Hard-guarantee corridor: carve a straight-line path from `from` to `to`,
# removing all obstacles and flattening terrain along the way.
# Uses the same step logic as _generate_nav_paths (prefer X movement first).
# Carves path_width cells wide perpendicular to travel direction.
func _carve_direct_corridor(from: Vector2i, to: Vector2i) -> void:
	var half_w: int = path_width >> 1
	# Perpendicular to the A->B axis (same logic as _carve_spawn_corridor_step).
	var delta := to - from
	var perp: Vector2i
	if abs(delta.y) >= abs(delta.x):
		perp = Vector2i(1, 0)
	else:
		perp = Vector2i(0, 1)

	var cx: int = from.x
	var cy: int = from.y
	var steps: int = absi(to.y - from.y) + absi(to.x - from.x)
	for _s: int in range(steps + 1):
		var center := Vector2i(cx, cy)
		# Build the set of cells to carve at this step: center +/- half_w in perp direction.
		var candidates: Array[Vector2i] = [center]
		for w: int in range(1, half_w + 1):
			candidates.append(center + perp * w)
			candidates.append(center - perp * w)
		# Always at least +/-1 wide so the corridor is traversable.
		if half_w == 0:
			candidates.append(center + perp)
			candidates.append(center - perp)

		for cell: Vector2i in candidates:
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= length:
				continue
			# Remove all obstacles at this cell.
			_obs_map.erase(cell)
			var idx: int = obstacles.size() - 1
			while idx >= 0:
				if (obstacles[idx]["pos"] as Vector2i) == cell:
					obstacles.remove_at(idx)
				idx -= 1
			building_interiors.erase(cell)
			terrain_heights[cell] = terrain_heights.get(from, 0.0)
			reserved_corridor_cells[cell] = true
			generation_log.append("Direct corridor carve (%d,%d)" % [cell.x, cell.y])

		# Advance one step toward `to` -- prefer X movement first.
		if cx != to.x:
			cx += signi(to.x - cx)
		elif cy != to.y:
			cy += signi(to.y - cy)

	var final_connected: bool = _is_spawn_connected()
	generation_log.append("Direct corridor result: %s" % ["CONNECTED" if final_connected else "STILL DISCONNECTED"])
	if not final_connected:
		push_warning("_carve_direct_corridor: spawns STILL disconnected after hard guarantee pass")


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

	# Smoothing passes: more passes for rougher terrain to prevent impassable gradients.
	for _p: int in range(1 + unevenness):
		_smooth_terrain_once()

	# Force spawn buffer rows flat, then taper the approach zone to prevent extreme dips/spikes.
	# Applied AFTER smoothing so smooth passes cannot bleed extreme terrain back into these zones.
	for x: int in range(width):
		for y: int in range(SPAWN_BUFFER + 2):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)
		for y: int in range(length - SPAWN_BUFFER - 2, length):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)
		# Approach zone: rows just beyond the flat spawn buffer get a gentle clamp
		# so enemies who move into that area can still be followed.
		for y: int in range(SPAWN_BUFFER + 2, SPAWN_BUFFER + 6):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), -0.5, 1.0)
		for y: int in range(length - SPAWN_BUFFER - 6, length - SPAWN_BUFFER - 2):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), -0.5, 1.0)


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
					if reserved_corridor_cells.has(cell):
						continue
					# Protect the spawn zone and approach rows so mercs never get trapped on exit.
					if cell.y < SPAWN_BUFFER + 4 or cell.y >= length - SPAWN_BUFFER - 4:
						continue
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
				if reserved_corridor_cells.has(cell):
					continue
				terrain_heights[cell] = maxf(0.0, terrain_heights.get(cell, 0.0) + cliff_drop)


func _terrain_compatible(template: ObstacleData, pos: Vector2i) -> bool:
	match template.obstacle_type:
		"Structure", "Furniture":
			return absf(get_terrain_height(pos)) <= 0.25
		_:
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
				var _stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template}
				obstacles.append(_stair_obs)
				_obs_map[pos] = _stair_obs


func _rebuild_cover_obstacles() -> void:
	cover_obstacles.clear()
	for obs: Dictionary in obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.provides_cover:
			cover_obstacles.append(obs)

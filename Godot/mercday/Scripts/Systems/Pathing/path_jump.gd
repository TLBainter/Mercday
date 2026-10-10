class_name PathJump

#Jump landing kinds: never, always, or only while the door on the cell is open.
const JUMP_DEST_NONE := 0
const JUMP_DEST_OK := 1
const JUMP_DEST_DOOR := 2


#The size independent half of the landing test; the headroom test lives in jump_dest_kind.
static func jump_dest_kind_base(pos: Vector3i, field: BattlefieldArea) -> int:
	if not field.in_bounds_xy(pos.x, pos.y):
		return JUMP_DEST_NONE
	if not PathCost.floor_exists(field, pos.z):
		return JUMP_DEST_NONE
	var pos2d := Vector2i(pos.x, pos.y)
	if not field.has_walkable_surface(pos2d, pos.z):
		return JUMP_DEST_NONE
	if field.is_stair_cell(pos2d, pos.z):
		return JUMP_DEST_NONE if PathCost.is_landing_alias(pos, field) else JUMP_DEST_OK
	var obs: Dictionary = field.get_obs(pos2d, pos.z)
	if obs.is_empty():
		return JUMP_DEST_OK
	var cell_type: String = obs.get("cell_type", "")
	if cell_type == "wall":
		return JUMP_DEST_NONE
	if cell_type == "door":
		return JUMP_DEST_DOOR
	#Footprint cells of multi-cell furniture, windows and fences carry no data and cannot be landed on.
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data != null and (data.passthrough or data.ramp):
		return JUMP_DEST_OK
	return JUMP_DEST_NONE


static func jump_dest_kind(pos: Vector3i, field: BattlefieldArea, merc_size: int = 0) -> int:
	var base := jump_dest_kind_base(pos, field)
	if base == JUMP_DEST_NONE:
		return JUMP_DEST_NONE
	if PathCost.under_stair_blocked(pos, field, merc_size):
		return JUMP_DEST_NONE
	return base


static func _jump_kind_cached(field: BattlefieldArea, pos: Vector3i) -> int:
	if field.jump_kind_static.has(pos):
		return field.jump_kind_static[pos] as int
	var kind := jump_dest_kind_base(pos, field)
	field.jump_kind_static[pos] = kind
	return kind


static func is_valid_jump_dest(pos: Vector3i, field: BattlefieldArea, merc_size: int = 0) -> bool:
	var kind := jump_dest_kind(pos, field, merc_size)
	if kind == JUMP_DEST_DOOR:
		return OpenCloseState.is_open(field.get_obs(Vector2i(pos.x, pos.y), pos.z))
	return kind == JUMP_DEST_OK


#Cells a leap crosses between take-off and landing, the landing included, in order.
static func leap_line(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for step: Dictionary in LineOfSight.line_steps(Vector2i(from.x, from.y), Vector2i(to.x, to.y)):
		var c: Vector2i = step["c"] as Vector2i
		out.append(Vector3i(c.x, c.y, to.z))
	return out


#True when the cell holds a wall or an unbroken window: too tall to clear in a leap.
static func _leap_solid(field: BattlefieldArea, cell: Vector3i) -> bool:
	var obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty():
		return false
	var ct: String = obs.get("cell_type", "")
	if ct == "wall":
		return true
	return ct == "window" and not (obs.get("broken", false) as bool)


#True when a wall, an unbroken window or a diagonal wall corner stands in the leap's way.
static func leap_wall_blocked(field: BattlefieldArea, from: Vector3i, to: Vector3i) -> bool:
	if field == null:
		return false
	var steps: Array[Dictionary] = LineOfSight.line_steps(Vector2i(from.x, from.y), Vector2i(to.x, to.y))
	var last: int = steps.size() - 1
	for i: int in range(steps.size()):
		var step: Dictionary = steps[i]
		var c: Vector2i = step["c"] as Vector2i
		if i < last and _leap_solid(field, Vector3i(c.x, c.y, to.z)):
			return true
		var ortho: Array = step["o"] as Array
		if ortho.size() < 2:
			continue
		var a: Vector2i = ortho[0] as Vector2i
		var b: Vector2i = ortho[1] as Vector2i
		if _leap_solid(field, Vector3i(a.x, a.y, to.z)) \
				and _leap_solid(field, Vector3i(b.x, b.y, to.z)):
			return true
	return false


#Door obstacles the leap crosses, the landing door included; the caller reads their open state.
static func leap_doors(field: BattlefieldArea, from: Vector3i, to: Vector3i) -> Array:
	var out: Array = []
	if field == null:
		return out
	for cell: Vector3i in leap_line(from, to):
		var obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
		if not obs.is_empty() and obs.get("cell_type", "") == "door":
			out.append(obs)
	return out


#True when the leap cannot be made: a wall in the way, or a shut door on the line.
static func leap_blocked(field: BattlefieldArea, from: Vector3i, to: Vector3i) -> bool:
	if leap_wall_blocked(field, from, to):
		return true
	for obs: Dictionary in leap_doors(field, from, to):
		if not OpenCloseState.is_open(obs):
			return true
	return false


#True when a roof part between the two cells stands above the height the leap clears.
static func roof_in_way(field: BattlefieldArea, from2: Vector2i, to2: Vector2i,
		clear_elev: float) -> bool:
	if field == null or field.roof_span.is_empty():
		return false
	var steps: Array[Dictionary] = LineOfSight.line_steps(from2, to2)
	var last: int = steps.size() - 1
	for i: int in range(last):
		var c: Vector2i = steps[i]["c"] as Vector2i
		if not field.roof_span.has(c):
			continue
		if (field.roof_span[c] as Vector2).y > clear_elev + 0.01:
			return true
	return false


#True when a jump_dests row cannot be used now: a shut door on the line or at the landing.
static func jump_row_blocked(dest: Array) -> bool:
	var door: Dictionary = dest[2] as Dictionary
	if not door.is_empty() and not OpenCloseState.is_open(door):
		return true
	if dest.size() < 4:
		return false
	for obs: Dictionary in (dest[3] as Array):
		if not OpenCloseState.is_open(obs):
			return true
	return false


#Size independent landing table of `cell`, built once at the widest range asked for so far:
#[landing, paces, door obstacle or {}, crossed doors, chebyshev distance] rows.
static func _jump_geom(field: BattlefieldArea, cell: Vector3i, jump_range: int) -> Array:
	if field.jump_geom.has(cell):
		var entry: Array = field.jump_geom[cell]
		if (entry[0] as int) >= jump_range:
			var kept: Array = entry[1]
			return kept
	var rows: Array = []
	var cell_h: float = field.cell_base_elevation(Vector2i(cell.x, cell.y), cell.z)
	for dx: int in range(-jump_range, jump_range + 1):
		for dy: int in range(-jump_range, jump_range + 1):
			var cdist := maxi(abs(dx), abs(dy))
			if cdist == 0 or cdist > jump_range:
				continue
			var jcell := Vector3i(cell.x + dx, cell.y + dy, cell.z)
			var kind := _jump_kind_cached(field, jcell)
			if kind == JUMP_DEST_NONE:
				continue
			var h_cost := int(ceil(maxf(0.0, field.cell_base_elevation(Vector2i(jcell.x, jcell.y), jcell.z) - cell_h)))
			if cdist + h_cost > jump_range:
				continue
			if leap_wall_blocked(field, cell, jcell):
				continue
			var door: Dictionary = {}
			if kind == JUMP_DEST_DOOR:
				door = field.get_obs(Vector2i(jcell.x, jcell.y), jcell.z)
			rows.append([jcell, cdist + h_cost, door, leap_doors(field, cell, jcell), cdist])
	field.jump_geom[cell] = [jump_range, rows]
	return rows


#Jump landings from `cell` for one range and size: [landing, paces, door obstacle or {},
#crossed doors] rows.
#Cached on the field until path_version is bumped; the caller reads the door open state live.
#The rows are filtered out of the shared size independent landing table of the cell.
static func jump_dests(field: BattlefieldArea, cell: Vector3i, jump_range: int, merc_size: int) -> Array:
	var key: Array = [merc_size, jump_range]
	if not field.jump_static.has(key):
		field.jump_static[key] = {}
	var by_cell: Dictionary = field.jump_static[key]
	if by_cell.has(cell):
		var hit: Array = by_cell[cell]
		return hit
	var out: Array = []
	for g: Array in _jump_geom(field, cell, jump_range):
		if (g[4] as int) > jump_range:
			continue
		if (g[1] as int) > jump_range:
			continue
		if PathCost.under_stair_blocked(g[0] as Vector3i, field, merc_size):
			continue
		out.append([g[0], g[1], g[2], g[3]])
	by_cell[cell] = out
	return out


#Cross level roof leaps out of `cell`: [landing, paces] rows, empty for every mover without a jump
#stat and on every map without roofs. Geometry only, like jump_dests; the caller tests occupancy.
#Cached on the field per [size, jump range, fall tolerance] until path_version is bumped.
static func roof_jumps(cell: Vector3i, field: BattlefieldArea, merc_size: int) -> Array:
	if PathCost.jump_roofs <= 0 or field == null or field.roof_cells.is_empty():
		return []
	var cell2 := Vector2i(cell.x, cell.y)
	if not field.is_roof_footing(cell2, cell.z):
		return []
	var key: Array = [merc_size, PathCost.jump_roofs, PathCost.jump_fall]
	if not field.roof_jump_cache.has(key):
		field.roof_jump_cache[key] = {}
	var by_cell: Dictionary = field.roof_jump_cache[key]
	if by_cell.has(cell):
		var hit: Array = by_cell[cell]
		return hit
	var rows: Array = []
	var from_e: float = field.cell_base_elevation(cell2, cell.z)
	for dx: int in range(-PathCost.jump_roofs, PathCost.jump_roofs + 1):
		for dy: int in range(-PathCost.jump_roofs, PathCost.jump_roofs + 1):
			var cdist := maxi(abs(dx), abs(dy))
			if cdist == 0 or cdist > PathCost.jump_roofs:
				continue
			var land2 := Vector2i(cell2.x + dx, cell2.y + dy)
			if not field.in_bounds_xy(land2.x, land2.y):
				continue
			var lz: int = field.roof_level_at(land2)
			if lz < 0 or lz == cell.z or not field.is_roof_footing(land2, lz):
				continue
			var land := Vector3i(land2.x, land2.y, lz)
			#A pair the climb or drop links already serve is taken by the Climb action, never leapt.
			if not PathCost.climb_link(cell, land, field).is_empty() or not PathCost.drop_link(cell, land, field).is_empty():
				continue
			if not is_valid_jump_dest(land, field, merc_size) or not PathHelper.is_standable(land, field, merc_size):
				continue
			if not PathCost.has_exit_neighbor(land, field, {}, 1.0, false, false, merc_size):
				continue
			var land_e: float = field.cell_base_elevation(land2, lz)
			var rise: int = int(ceil(maxf(0.0, land_e - from_e)))
			if cdist + rise > PathCost.jump_roofs:
				continue
			if leap_wall_blocked(field, cell, Vector3i(land2.x, land2.y, cell.z)):
				continue
			if roof_in_way(field, cell2, land2, maxf(from_e, land_e)):
				continue
			var cost: int = cdist + rise
			var drop: float = from_e - land_e
			if drop >= 1.0:
				var fall: int = PathCost.fall_cost(int(floor(drop)), PathCost.jump_fall)
				if fall < 0:
					continue
				cost += fall
			rows.append([land, cost])
	by_cell[cell] = rows
	return rows


#The roof leap this mover takes over the pair instead of walking it: {} for none, else {to, paces}.
static func roof_jump_step(from: Vector3i, to: Vector3i, field: BattlefieldArea, is_flying: bool,
		merc_size: int) -> Dictionary:
	if is_flying or from.z == to.z or PathCost.jump_roofs <= 0 or field.roof_cells.is_empty():
		return {}
	for row: Array in roof_jumps(from, field, merc_size):
		if (row[0] as Vector3i) == to:
			return {"to": to, "paces": row[1] as int}
	return {}

class_name PathCost

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

#Pace cost of crossing an obstacle cell by vaulting.
const VAULT_COST := 2

#Pace surcharge for routing through a closed door the mover would have to Interact
#with; -1 keeps closed doors impassable. Set per mover from door_penalty().
static var door_pace_penalty: int = -1


#The only writer of door_pace_penalty; 0 plans every openable door free.
static func set_door_penalty(value: int) -> void:
	door_pace_penalty = value


#Pace the mover trades for the AP an Interact would cost on the way through: one Move of
#paces per door. A mover that cannot pay the Interact when it gets there halts at the door.
static func door_penalty(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var move_ap: int = maxi(1, _CONFIG.move_base_ap)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var cap: int = ConstStates.max_paces(merc)
	if cap >= 0:
		pace = mini(pace, cap)
	return int(ceil(2.0 / float(move_ap))) * pace


#True when a merc could open this obstacle with the Interact action.
static func is_interactable_door(obs: Dictionary) -> bool:
	if obs.get("cell_type", "") != "door":
		return false
	var data: ObstacleData = obs.get("data") as ObstacleData
	return data != null and data.interactable and data.interaction_result == "Open/Close"


#True when this cell holds a shut door a merc could open with the Interact action.
static func is_shut_door(field: BattlefieldArea, cell: Vector3i) -> bool:
	if field == null:
		return false
	var obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty() or OpenCloseState.is_open(obs):
		return false
	return is_interactable_door(obs)


#Cost of entering a shut door cell, or -1 when it cannot be planned through.
static func shut_door_cost(obs: Dictionary) -> int:
	if door_pace_penalty < 0 or not is_interactable_door(obs):
		return -1
	return 1 + door_pace_penalty

const DIRS8: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


static func to2(p: Vector3i) -> Vector2i:
	return Vector2i(p.x, p.y)


static func floor_exists(field: BattlefieldArea, f: int) -> bool:
	if not field.is_interior_map:
		return f == 0
	return field.interior_floor_elevations.has(f)


#Walkable neighbours of node: the in-bounds same-floor cells plus any stair, well or drop link.
#Cached per node on the field; the cache is dropped whenever path_version is bumped.
static func neighbors(node: Vector3i, field: BattlefieldArea) -> Array[Vector3i]:
	if field.neighbor_cache.has(node):
		var hit: Array[Vector3i] = field.neighbor_cache[node]
		return hit
	var result: Array[Vector3i] = []
	for d: Vector2i in DIRS8:
		var nx: int = node.x + d.x
		var ny: int = node.y + d.y
		if nx < 0 or nx >= field.width or ny < 0 or ny >= field.length:
			continue
		result.append(Vector3i(nx, ny, node.z))
	if field.stair_links.has(node):
		for link: Vector3i in (field.stair_links[node] as Array):
			result.append(link)
	if field.well_links.has(node):
		for wlink: Vector3i in (field.well_links[node] as Array):
			result.append(wlink)
	if field.drop_links.has(node):
		for dl: Dictionary in (field.drop_links[node] as Array):
			result.append(dl["to"] as Vector3i)
	field.neighbor_cache[node] = result
	return result


#True when the run cell on floor f is the row that is physically the landing below.
static func is_landing_alias(cell: Vector3i, field: BattlefieldArea) -> bool:
	if not field.stair_runs.has(cell.z):
		return false
	if not field.stair_run_cells.has(cell):
		return false
	if field.stairwell_connections.has(cell):
		return false
	var run: Dictionary = field.stair_runs[cell.z] as Dictionary
	return cell.y == BattlefieldArea.run_bottom_y(run) and absi(cell.x - (run["sx"] as int)) <= 1


#True when the stair run overhead leaves a walker of merc_size too little headroom to enter the cell.
static func under_stair_blocked(cell: Vector3i, field: BattlefieldArea, merc_size: int) -> bool:
	if merc_size <= 0:
		return false
	return field.stair_headroom(Vector2i(cell.x, cell.y), cell.z) < float(merc_size)


static func _stair_link_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> int:
	if not field.stair_links.has(from):
		return -1
	if (field.stair_links[from] as Array).has(to):
		return 1
	return -1


#True when the pair is a flight step through the stair well opening.
static func is_well_link(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> bool:
	if field == null or not field.well_links.has(from):
		return false
	return (field.well_links[from] as Array).has(to)


#Pace cost of flying up or down the stair well; -1 for a walker or a pair that is no well link.
static func _well_link_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea, is_flying: bool,
		altitude: int, _merc_size: int) -> int:
	if not is_flying or not is_well_link(from, to, field):
		return -1
	if to.z > from.z:
		var from_e: float = field.cell_base_elevation(Vector2i(from.x, from.y), from.z) + float(altitude)
		return 1 + maxi(0, int(ceil(field.floor_base_elevation(to.z) - from_e)))
	return 1


#The drop edge from -> to, or {} when the pair is not a drop link.
static func drop_link(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> Dictionary:
	if not field.drop_links.has(from):
		return {}
	for dl: Dictionary in (field.drop_links[from] as Array):
		if (dl["to"] as Vector3i) == to:
			return dl
	return {}


#True when an obstacle is low enough for a merc of merc_size to vault it.
static func can_vault(obs: Dictionary, merc_size: int) -> bool:
	if merc_size < 2:
		return false
	return BattlefieldArea.obstacle_height(obs) <= float(merc_size) - 1.0


#Pace surcharge for a fall of paces at this tolerance; -1 once the fall reaches severity 4.
static func _fall_cost(paces: int, tol: float) -> int:
	if float(paces) / tol >= 4.0:
		return -1
	return int(ceil(paces * 4.0 / tol))


#Pace cost of a deliberate drop; -1 when there is no link, the vault fails, or the fall is too severe.
static func _drop_link_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		merc_fall_tolerance: float, merc_size: int) -> int:
	var dl := drop_link(from, to, field)
	if dl.is_empty():
		return -1
	var vault: Vector3i = dl["vault"] as Vector3i
	if vault.x >= 0:
		var vobs: Dictionary = field.get_obs(Vector2i(vault.x, vault.y), vault.z)
		if not vobs.is_empty() and not can_vault(vobs, merc_size):
			return -1
	var paces: int = dl["paces"] as int
	var fall := _fall_cost(paces, merc_fall_tolerance)
	if fall < 0:
		return -1
	return fall + 1


#True when the only way into the cell is a vault; a merc may cross it but not stop on it or vault again from it.
static func is_vault_cell(cell: Vector3i, field: BattlefieldArea, merc_size: int) -> bool:
	var cell2d := Vector2i(cell.x, cell.y)
	if field.is_stair_cell(cell2d, cell.z):
		return false
	var obs: Dictionary = field.get_obs(cell2d, cell.z)
	if obs.is_empty():
		return false
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "door":
		return false
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data != null and (data.ramp or data.passthrough):
		return false
	return can_vault(obs, merc_size)


#True when a flyer may cross the cell but never stop on it: an obstacle a walker
#could not stand on. Walls, closed doors and intact windows are blocked outright.
static func is_flyover_cell(cell: Vector3i, field: BattlefieldArea) -> bool:
	var cell2d := Vector2i(cell.x, cell.y)
	if field.is_stair_cell(cell2d, cell.z):
		return false
	var obs: Dictionary = field.get_obs(cell2d, cell.z)
	if obs.is_empty():
		return false
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "window":
		return true
	if ct == "door":
		return not OpenCloseState.is_open(obs)
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data == null:
		return true
	return not (data.ramp or data.passthrough)


#Elevation of the lowest slab above floor f at pos, or NO_CEILING when there is none.
const NO_CEILING := 1.0e9

static func slab_above(pos: Vector2i, f: int, field: BattlefieldArea) -> float:
	if not field.is_interior_map:
		return NO_CEILING
	var best := NO_CEILING
	for other: int in field.interior_floor_elevations.keys():
		if other <= f:
			continue
		if not field.has_slab(pos, other):
			continue
		var e := field.floor_base_elevation(other)
		if e < best:
			best = e
	return best


#Pace cost of a same-floor step for a flyer. Walls, closed doors and intact windows
#block it exactly as they block a walker; any other obstacle is crossed by flying over
#its top, and the climb from the flyer's current z is charged on top of the base pace.
static func fly_cell_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		merc_fall_tolerance: float, merc_size: int, altitude: int) -> int:
	var to2d := Vector2i(to.x, to.y)
	var from2d := Vector2i(from.x, from.y)
	var to_base: float = field.cell_base_elevation(to2d, to.z)
	#The underside of a run overhead is a ceiling: the flyer's top must clear it.
	if merc_size > 0 and float(altitude + merc_size) > field.stair_headroom(to2d, to.z):
		return -1
	var top := to_base
	var obs: Dictionary = field.get_obs(to2d, to.z)
	var door_extra := 0
	if not obs.is_empty() and not field.is_stair_cell(to2d, to.z):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			return -1
		if ct == "door" and not OpenCloseState.is_open(obs):
			var shut := shut_door_cost(obs)
			if shut < 0:
				return -1
			door_extra = shut - 1
		if ct == "window" and not (obs.get("broken", false) as bool):
			return -1
		if not is_ground_pass(obs):
			top = to_base + BattlefieldArea.obstacle_height(obs)
			var ceiling := slab_above(to2d, to.z, field)
			if ceiling < NO_CEILING and top + float(maxi(1, merc_size)) >= ceiling:
				return -1
	var from_z: float = field.cell_base_elevation(from2d, from.z) + float(altitude)
	#Terrain and stair rises cost the flat pace; only an obstacle top charges the climb.
	var cost := 1 + door_extra
	if top > to_base:
		cost += int(ceil(maxf(0.0, top - from_z)))
	if altitude >= 1:
		return cost
	#A flyer settles onto or off a stair run from the side at the flat pace; only an open drop charges the fall.
	if field.is_stair_cell(to2d, to.z) or field.is_stair_cell(from2d, from.z):
		return cost
	var drop := from_z - to_base
	if drop >= 1.0:
		var fall := _fall_cost(int(floor(drop)), merc_fall_tolerance)
		if fall < 0:
			return -1
		cost += fall
	return cost


#Altitude a flyer has on arriving at `to`, given the altitude it left `from` with.
#It never drops during a move: the flyer stays at the highest top it crossed.
static func fly_arrival_altitude(from: Vector3i, to: Vector3i, field: BattlefieldArea, altitude: int) -> int:
	if from.z != to.z:
		if to.z > from.z and is_well_link(from, to, field):
			return 0
		return altitude
	var to2d := Vector2i(to.x, to.y)
	if field.is_stair_cell(to2d, to.z):
		return altitude
	var obs: Dictionary = field.get_obs(to2d, to.z)
	if obs.is_empty() or is_ground_pass(obs):
		return altitude
	return maxi(altitude, int(ceil(BattlefieldArea.obstacle_height(obs))))


#True when a flyer enters the cell at floor level like a walker: doors it may use, ramps, passthrough obstacles.
static func is_ground_pass(obs: Dictionary) -> bool:
	if obs.is_empty():
		return true
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "window":
		return false
	if ct == "door":
		return OpenCloseState.is_open(obs) or is_interactable_door(obs)
	var data: ObstacleData = obs.get("data") as ObstacleData
	return data != null and (data.passthrough or data.ramp)


#Elevation change of a same-floor step; 0 between two cells of one stair run (stairs cost 1 pace per cell).
static func walk_h_diff(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> float:
	var from2d := Vector2i(from.x, from.y)
	var to2d := Vector2i(to.x, to.y)
	if field.is_stair_cell(to2d, to.z) and field.is_stair_cell(from2d, from.z):
		return 0.0
	return field.walk_elevation(to2d, to.z) - field.walk_elevation(from2d, from.z)


#Fields of a static_entry row.
const SE_BLOCKED := 0
const SE_JAGGED := 1
const SE_WALK_BLOCKED := 2
const SE_ON_STAIRS := 3
const SE_HAS_STAIRS := 4
const SE_ELEV := 5
const SE_KIND := 6
const SE_BASE := 7
const SE_OBS := 8
const SE_DOOR_OK := 9
const SE_CAN_VAULT := 10
const SE_VAULT_CELL := 11

#Obstacle kinds a walker meets on the cell it enters.
const KIND_OPEN := 0
const KIND_WALL := 1
const KIND_DOOR := 2
const KIND_VAULT := 3


#Per-cell walk facts that hold for a given merc_size until path_version is bumped.
#Door open state is never baked; it is read live from the stored obstacle.
static func static_entry(field: BattlefieldArea, cell: Vector3i, merc_size: int) -> Array:
	if not field.path_static.has(merc_size):
		field.path_static[merc_size] = {}
	var by_size: Dictionary = field.path_static[merc_size]
	if by_size.has(cell):
		var hit: Array = by_size[cell]
		return hit
	var cell2d := Vector2i(cell.x, cell.y)
	var obs: Dictionary = field.get_obs(cell2d, cell.z)
	var on_stairs: bool = field.is_stair_cell(cell2d, cell.z)
	var kind: int = KIND_OPEN
	var base: int = 1
	var door_ok: bool = false
	if not on_stairs and not obs.is_empty():
		var cell_type: String = obs.get("cell_type", "")
		if cell_type == "wall":
			kind = KIND_WALL
		elif cell_type == "door":
			kind = KIND_DOOR
			door_ok = is_interactable_door(obs)
		else:
			var data: ObstacleData = obs.get("data") as ObstacleData
			if data == null:
				kind = KIND_VAULT
			elif data.ramp:
				base = 1
			elif not data.passthrough:
				kind = KIND_VAULT
			elif data.pt_enter_harm > 0 or data.pt_exit_harm > 0:
				base = 10
			else:
				base = 2 if data.rugged else 1
	var entry: Array = [
		is_landing_alias(cell, field) or not field.has_walkable_surface(cell2d, cell.z),
		field.jagged_cells.has(cell2d),
		field.fly_only_cells.has(cell2d) or under_stair_blocked(cell, field, merc_size),
		on_stairs,
		field.has_stairs_at(cell2d, cell.z),
		field.walk_elevation(cell2d, cell.z),
		kind,
		base,
		obs,
		door_ok,
		can_vault(obs, merc_size),
		is_vault_cell(cell, field, merc_size),
	]
	by_size[cell] = entry
	return entry


#Pace cost to enter `to` from `from`. Returns -1 if impassable.
#`altitude` is the flyer's height above its own cell as it leaves `from`.
#`p_from_entry` is the static_entry of `from` when the caller already holds it.
static func cell_pace_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		merc_size: int = 1,
		altitude: int = 0,
		p_from_entry: Array = []) -> int:
	if to.x < 0 or to.x >= field.width or to.y < 0 or to.y >= field.length:
		return -1
	if not floor_exists(field, to.z):
		return -1
	if from.z != to.z:
		var stair_cost := _stair_link_cost(from, to, field)
		if stair_cost >= 0:
			return stair_cost
		var well_cost := _well_link_cost(from, to, field, is_flying, altitude, merc_size)
		if well_cost >= 0:
			return well_cost
		return _drop_link_cost(from, to, field, merc_fall_tolerance, merc_size)

	var entry: Array = static_entry(field, to, merc_size)
	var blocked: bool = entry[SE_BLOCKED]
	if blocked:
		return -1
	var jagged: bool = entry[SE_JAGGED]
	if jagged and not (is_flying and altitude >= 1):
		return -1
	if is_flying:
		return fly_cell_cost(from, to, field, merc_fall_tolerance, merc_size, altitude)
	var walk_blocked: bool = entry[SE_WALK_BLOCKED]
	if walk_blocked:
		return -1

	var from_entry: Array = p_from_entry
	if from_entry.is_empty():
		from_entry = static_entry(field, from, merc_size)
	var on_stairs: bool = entry[SE_ON_STAIRS]
	var from_stairs: bool = from_entry[SE_ON_STAIRS]
	var to_elev: float = entry[SE_ELEV]
	var from_elev: float = from_entry[SE_ELEV]
	var h_diff: float = 0.0 if (on_stairs and from_stairs) else to_elev - from_elev
	#A run is entered and left only at its level ends; no hop onto or off the treads from the side.
	if absf(h_diff) > 0.25 and (on_stairs or from_stairs):
		return -1
	var has_stairs: bool = entry[SE_HAS_STAIRS]

	if passable_cells.has(to):
		if h_diff > 0.5:
			if h_diff <= 1.0:
				return 3
			if not can_climb or h_diff > 2.0:
				return -1
			return 3
		if h_diff <= -1.0:
			if _fall_cost(int(floor(-h_diff)), merc_fall_tolerance) < 0:
				return -1
		elif absf(h_diff) > 0.25 and not (on_stairs or has_stairs):
			return -1
		return 1

	var kind: int = entry[SE_KIND]
	var base_cost: int = entry[SE_BASE]
	if kind == KIND_WALL:
		return -1
	if kind == KIND_DOOR:
		var obs: Dictionary = entry[SE_OBS]
		if OpenCloseState.is_open(obs):
			base_cost = 1
		else:
			var door_ok: bool = entry[SE_DOOR_OK]
			if door_pace_penalty < 0 or not door_ok:
				return -1
			base_cost = 1 + door_pace_penalty
	elif kind == KIND_VAULT:
		var vaultable: bool = entry[SE_CAN_VAULT]
		var from_vault: bool = from_entry[SE_VAULT_CELL]
		if not vaultable or from_vault:
			return -1
		base_cost = VAULT_COST

	if h_diff > 0.5:
		if h_diff <= 1.0:
			return base_cost + 2
		elif not can_climb or h_diff > 2.0:
			return -1
		else:
			base_cost += 2

	if h_diff <= -1.0:
		var fall := _fall_cost(int(floor(-h_diff)), merc_fall_tolerance)
		if fall < 0:
			return -1
		base_cost += fall

	elif absf(h_diff) > 0.25:
		if not (on_stairs or has_stairs):
			return -1
		if h_diff > 0.0:
			base_cost += 1
		else:
			base_cost = maxi(0, base_cost - 1)

	return base_cost


static func has_exit_neighbor(cell: Vector3i, field: BattlefieldArea,
		passable_cells: Dictionary, merc_fall_tolerance: float,
		is_flying: bool, can_climb: bool = false, merc_size: int = 1,
		altitude: int = 0) -> bool:
	for nb: Vector3i in neighbors(cell, field):
		if cell_pace_cost(cell, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, altitude) >= 0:
			return true
	return false


#Jump landing kinds: never, always, or only while the door on the cell is open.
const JUMP_DEST_NONE := 0
const JUMP_DEST_OK := 1
const JUMP_DEST_DOOR := 2


static func jump_dest_kind(pos: Vector3i, field: BattlefieldArea, merc_size: int = 0) -> int:
	if pos.x < 0 or pos.x >= field.width or pos.y < 0 or pos.y >= field.length:
		return JUMP_DEST_NONE
	if not floor_exists(field, pos.z):
		return JUMP_DEST_NONE
	var pos2d := Vector2i(pos.x, pos.y)
	if not field.has_walkable_surface(pos2d, pos.z):
		return JUMP_DEST_NONE
	if under_stair_blocked(pos, field, merc_size):
		return JUMP_DEST_NONE
	if field.is_stair_cell(pos2d, pos.z):
		return JUMP_DEST_NONE if is_landing_alias(pos, field) else JUMP_DEST_OK
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


static func is_valid_jump_dest(pos: Vector3i, field: BattlefieldArea, merc_size: int = 0) -> bool:
	var kind := jump_dest_kind(pos, field, merc_size)
	if kind == JUMP_DEST_DOOR:
		return OpenCloseState.is_open(field.get_obs(Vector2i(pos.x, pos.y), pos.z))
	return kind == JUMP_DEST_OK


#Jump landings from `cell` for one range and size: [landing, paces, door obstacle or {}] rows.
#Cached on the field until path_version is bumped; the caller reads the door open state live.
static func jump_dests(field: BattlefieldArea, cell: Vector3i, jump_range: int, merc_size: int) -> Array:
	var key: Array = [merc_size, jump_range]
	if not field.jump_static.has(key):
		field.jump_static[key] = {}
	var by_cell: Dictionary = field.jump_static[key]
	if by_cell.has(cell):
		var hit: Array = by_cell[cell]
		return hit
	var out: Array = []
	var cell_h: float = field.cell_base_elevation(Vector2i(cell.x, cell.y), cell.z)
	for dx: int in range(-jump_range, jump_range + 1):
		for dy: int in range(-jump_range, jump_range + 1):
			var cdist := maxi(abs(dx), abs(dy))
			if cdist == 0 or cdist > jump_range:
				continue
			var jcell := Vector3i(cell.x + dx, cell.y + dy, cell.z)
			var kind := jump_dest_kind(jcell, field, merc_size)
			if kind == JUMP_DEST_NONE:
				continue
			var h_cost := int(ceil(maxf(0.0, field.cell_base_elevation(Vector2i(jcell.x, jcell.y), jcell.z) - cell_h)))
			if cdist + h_cost > jump_range:
				continue
			var door: Dictionary = {}
			if kind == JUMP_DEST_DOOR:
				door = field.get_obs(Vector2i(jcell.x, jcell.y), jcell.z)
			out.append([jcell, cdist + h_cost, door])
	by_cell[cell] = out
	return out

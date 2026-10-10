class_name PathCost

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

#Pace cost of crossing an obstacle cell by vaulting.
const VAULT_COST := 2

#Pace surcharge for routing through a closed door the mover would have to Interact
#with; -1 keeps closed doors impassable. Set per mover from door_penalty().
static var door_pace_penalty: int = -1

#How the mover gets through a locked door: not at all, by picking it, or with a key.
const LOCK_NONE := 0
const LOCK_PICK := 1
const LOCK_KEYS := 2

#Set per mover with the door penalty; the surcharge prices the picks a locked door is expected to cost.
static var lock_mode: int = LOCK_NONE
static var lock_pace_penalty: int = 0

#The locked doors this mover may route through; every other locked door is a wall to it.
static var wanted_locks: Array[Dictionary] = []
static var wanted_sig: String = ""


#Pace a cavern water cell costs the mover, and how deep below the surface a sunk mover stands.
static var water_cost: int = 2
static var sunk_depth: int = 0


#Climb routing of the mover: false keeps every climb link out of its graph.
static var link_climbs: bool = false
static var climb_pace: int = 1
static var climb_hp: int = 0


#Roof jump routing of the mover: 0 keeps every cross level roof leap out of its graph.
static var jump_roofs: int = 0
static var jump_fall: float = 1.0


#The only writer of door_pace_penalty; 0 plans every openable door free.
static func set_door_penalty(value: int) -> void:
	door_pace_penalty = value
	lock_mode = LOCK_NONE
	lock_pace_penalty = 0
	wanted_locks = []
	wanted_sig = ""
	clear_climb()


#Every per-mover routing surcharge at once: shut doors, locked doors and cavern water.
#warm skips the lock plan: its expected-chance formula draws the RNG, and a spawn warm-up must not.
static func set_mover_doors(merc: MercenaryData, state: BattleState, warm: bool = false) -> void:
	set_door_penalty(door_penalty(merc))
	set_water_cost(merc, state)
	set_climb(merc)
	if warm or state == null or state.battlefield == null or not state.battlefield.is_dungeon:
		return
	if DungeonLocks.can_pick(merc, state):
		lock_mode = LOCK_PICK
		lock_pace_penalty = DungeonLocks.plan_lock_penalty(merc, state.battlefield)
		_fill_wanted(merc, state)
	elif DungeonLocks.holds_keys(merc, state):
		lock_mode = LOCK_KEYS
		lock_pace_penalty = 0


#The locked doors this mover has a reason to pick, and a signature the reach cache keys on.
static func _fill_wanted(merc: MercenaryData, state: BattleState) -> void:
	var parts := PackedStringArray()
	var reasons := PackedStringArray()
	for row: Dictionary in DungeonLocks.locked_doors(state.battlefield):
		var obs: Dictionary = row["obs"] as Dictionary
		var cell: Vector3i = row["cell"] as Vector3i
		var why: String = DungeonLocks.wanted_reason(merc, obs, cell, state)
		if why == "":
			continue
		wanted_locks.append(obs)
		parts.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
		reasons.append("(%d,%d) F%d %s" % [cell.x, cell.y, cell.z, why])
	wanted_sig = "|".join(parts)
	DungeonLocks.log_wanted(merc, reasons)


#The only writer of water_cost and sunk_depth; both are read at cost time, never cached.
static func set_water_cost(merc: MercenaryData, state: BattleState) -> void:
	if merc == null:
		water_cost = 2
		sunk_depth = 0
		return
	water_cost = CavernRules.water_pace_cost(merc)
	sunk_depth = 0
	if state != null and state.is_sunk(merc):
		water_cost = 2
		sunk_depth = state.sunk_depth(merc)


#Unset: no climb link or cross level roof leap is a route edge for the mover.
static func clear_climb() -> void:
	link_climbs = false
	climb_pace = 1
	climb_hp = 0
	jump_roofs = 0
	jump_fall = 1.0


#The only writer of the climb routing values; every walker the Climb action would take routes over
#climb links, at the pace its own climb stat, Deposed and Athletics Vigor buy. Call after
#set_water_cost, which is what tells a sunk mover apart from a dry one.
static func set_climb(merc: MercenaryData) -> void:
	clear_climb()
	if merc == null or sunk_depth > 0:
		return
	#The gates ClimbAction and execute_climb refuse on: no body to grab with, and no Move to spend.
	if int(merc.stats.get("size", 0)) <= 0:
		return
	if PaceBudget.pace_per_move(merc) <= 0 or StateEffects.is_blocked(merc, "action:move"):
		return
	link_climbs = true
	climb_pace = maxi(1, ClimbExecutor.climb_pace_cost(merc))
	climb_hp = maxi(1, merc.current_hp)
	jump_roofs = maxi(0, int(merc.stats.get("jump", 0)))
	jump_fall = PathTargeter.fall_tolerance(merc)


#The five values set_climb and clear_climb write, so a probe can borrow them and hand them back.
static func climb_snapshot() -> Array:
	return [link_climbs, climb_pace, climb_hp, jump_roofs, jump_fall]


static func restore_climb(snap: Array) -> void:
	if snap.size() < 5:
		return
	link_climbs = bool(snap[0])
	climb_pace = int(snap[1])
	climb_hp = int(snap[2])
	jump_roofs = int(snap[3])
	jump_fall = float(snap[4])


#True when this mover prices climb links into its route graph at all; false costs nothing further.
static func climbs_links(field: BattlefieldArea, is_flying: bool) -> bool:
	return link_climbs and not is_flying and not field.climb_links.is_empty()


#True when the rock ceiling leaves a mover of merc_size too little room to walk upright here.
static func crawl_cell(field: BattlefieldArea, cell: Vector2i, merc_size: int) -> bool:
	return field.is_cavern and field.clearance(cell) < float(merc_size)


#Water and crawl surcharges of one cavern step, on top of the base pace of the cell entered.
static func cavern_step_cost(field: BattlefieldArea, from: Vector3i, to: Vector3i,
		merc_size: int, base_cost: int) -> int:
	var to2d := Vector2i(to.x, to.y)
	var from2d := Vector2i(from.x, from.y)
	var cost: int = water_cost if field.is_water(to2d) else base_cost
	var crawl_to := crawl_cell(field, to2d, merc_size)
	var crawl_from := crawl_cell(field, from2d, merc_size)
	if crawl_to:
		cost += 1
	if crawl_to != crawl_from:
		cost += 1
	return cost


#Pace the mover trades for the AP an Interact would cost on the way through: one Move of
#paces per door. A mover that cannot pay the Interact when it gets there halts at the door.
static func door_penalty(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var move_ap: int = maxi(1, _CONFIG.move_base_ap)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var cap: int = StateEffects.max_paces(merc)
	if cap >= 0:
		pace = mini(pace, cap)
	return int(ceil(2.0 / float(move_ap))) * pace


#True when the obstacle is a door an Interact could work at all, lock aside.
static func is_openable_door(obs: Dictionary) -> bool:
	if obs.get("cell_type", "") != "door":
		return false
	var data: ObstacleData = obs.get("data") as ObstacleData
	return data != null and data.interactable and data.interaction_result == "Open/Close"


#True when the mover's lock mode gets it through this door's lock.
static func lock_passable(obs: Dictionary) -> bool:
	if not DungeonLocks.is_locked(obs):
		return true
	if lock_mode == LOCK_PICK:
		for entry: Dictionary in wanted_locks:
			if is_same(entry, obs):
				return true
		return false
	if lock_mode == LOCK_KEYS:
		return DungeonLocks.is_keyed(obs) and not DungeonLocks.keep_shut(obs)
	return false


#True when a merc could open this obstacle with the Interact action.
static func is_interactable_door(obs: Dictionary) -> bool:
	return is_openable_door(obs) and lock_passable(obs)


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
	return 1 + door_pace_penalty + (lock_pace_penalty if DungeonLocks.is_locked(obs) else 0)

const DIRS4: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const DIRS8: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


static func to2(p: Vector3i) -> Vector2i:
	return Vector2i(p.x, p.y)


static func floor_exists(field: BattlefieldArea, f: int) -> bool:
	if not field.is_interior_map:
		return f == 0 or (f >= 1 and field.has_roof_level(f))
	return field.interior_floor_elevations.has(f) or field.has_roof_level(f)


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
		if not field.in_bounds_xy(nx, ny):
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
	if field.roof_fly_links.has(node):
		for rlink: Vector3i in (field.roof_fly_links[node] as Array):
			result.append(rlink)
	#Mover independent: only cell_pace_cost decides whether this mover may climb the link.
	if field.climb_links.has(node):
		for cl: Dictionary in (field.climb_links[node] as Array):
			result.append(cl["top"] as Vector3i)
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
	var run: Dictionary = field.stair_run_at(Vector2i(cell.x, cell.y), cell.z)
	if run.is_empty():
		return false
	return cell.y == BattlefieldArea.run_bottom_y(run) and absi(cell.x - (run["sx"] as int)) <= 1


#True when the stair run overhead leaves a walker of merc_size too little headroom to enter the cell.
static func under_stair_blocked(cell: Vector3i, field: BattlefieldArea, merc_size: int) -> bool:
	if merc_size <= 0:
		return false
	var cell2d := Vector2i(cell.x, cell.y)
	#Only solid rock stops a cavern walker; a low ceiling is crawled under instead.
	if field.is_cavern:
		return field.clearance(cell2d) < 1.0
	return field.stair_headroom(cell2d, cell.z) < float(merc_size)


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
		altitude: int) -> int:
	if not is_flying or not is_well_link(from, to, field):
		return -1
	if to.z > from.z:
		var from_e: float = field.cell_base_elevation(Vector2i(from.x, from.y), from.z) + float(altitude)
		return 1 + maxi(0, int(ceil(field.floor_elevation_at(Vector2i(to.x, to.y), to.z) - from_e)))
	return 1


#True when the pair is a flyer's rise from a drop landing back up onto the roof over it.
static func is_roof_fly_link(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> bool:
	if field == null or not field.roof_fly_links.has(from):
		return false
	return (field.roof_fly_links[from] as Array).has(to)


#Pace cost of flying up onto a roof; -1 for a walker or a pair that is no roof fly link.
static func _roof_fly_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea, is_flying: bool,
		altitude: int) -> int:
	if not is_flying or not is_roof_fly_link(from, to, field):
		return -1
	var from_e: float = field.cell_base_elevation(Vector2i(from.x, from.y), from.z) + float(altitude)
	return 1 + maxi(0, int(ceil(field.cell_base_elevation(Vector2i(to.x, to.y), to.z) - from_e)))


#The drop edge from -> to, or {} when the pair is not a drop link.
static func drop_link(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> Dictionary:
	if not field.drop_links.has(from):
		return {}
	for dl: Dictionary in (field.drop_links[from] as Array):
		if (dl["to"] as Vector3i) == to:
			return dl
	return {}


#The climb edge from -> to, or {} when the pair is not a climb link.
static func climb_link(from: Vector3i, to: Vector3i, field: BattlefieldArea) -> Dictionary:
	if not field.climb_links.has(from):
		return {}
	for cl: Dictionary in (field.climb_links[from] as Array):
		if (cl["top"] as Vector3i) == to:
			return cl
	return {}


#True when an obstacle is low enough for a merc of merc_size to vault it.
static func can_vault(obs: Dictionary, merc_size: int) -> bool:
	if obs.get("rubble", false):
		return false
	if merc_size < 2:
		return false
	return BattlefieldArea.obstacle_height(obs) <= float(merc_size) - 1.0


#Pace surcharge for a fall of paces at this tolerance; -1 once the fall reaches severity 4.
static func fall_cost(paces: int, tol: float) -> int:
	if float(paces) / tol >= 4.0:
		return -1
	return int(ceil(paces * 4.0 / tol))


#Pace cost of a deliberate drop; -1 when there is no link, the vault fails, or the fall is too severe.
static func _drop_link_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		merc_fall_tolerance: float, merc_size: int, is_flying: bool = false) -> int:
	var dl := drop_link(from, to, field)
	if dl.is_empty():
		return -1
	#A flyer passes over the vault cell and descends the edge under control, so no fall and no refusal.
	if is_flying:
		return 1
	if not _vault_clear(dl["vault"] as Vector3i, field, merc_size):
		return -1
	var paces: int = dl["paces"] as int
	var fall := fall_cost(paces, merc_fall_tolerance)
	if fall < 0:
		return -1
	return fall + 1


#Pace cost of climbing one link, up or down; -1 when the link is empty or its vault cell blocks the mover.
static func _link_climb_cost(link: Dictionary, field: BattlefieldArea, merc_size: int) -> int:
	if link.is_empty():
		return -1
	if not _vault_clear(link["vault"] as Vector3i, field, merc_size):
		return -1
	return 1 + int(link["paces"]) * climb_pace


#True when a link has no vault cell or the mover can vault the obstacle on it.
static func _vault_clear(vault: Vector3i, field: BattlefieldArea, merc_size: int) -> bool:
	if vault.x < 0:
		return true
	var vobs: Dictionary = field.get_obs(Vector2i(vault.x, vault.y), vault.z)
	return vobs.is_empty() or can_vault(vobs, merc_size)


#True when a climber would rather climb this drop down than fall it; the one test ClimbAction shares.
static func prefers_down_climb(paces: int, tol: float, hp: int) -> bool:
	return fall_cost(paces, tol) < 0 or paces * 4 >= hp


#The climb this mover takes over the pair instead of walking it: {} for none, else {link, down}.
static func climb_step(from: Vector3i, to: Vector3i, field: BattlefieldArea, is_flying: bool,
		merc_fall_tolerance: float, merc_size: int) -> Dictionary:
	if from.z == to.z or not climbs_links(field, is_flying):
		return {}
	#A pair the stairs already serve is walked, whatever link table it also sits in.
	if _stair_link_cost(from, to, field) >= 0:
		return {}
	var up := climb_link(from, to, field)
	if not up.is_empty():
		if _link_climb_cost(up, field, merc_size) < 0:
			return {}
		return {"link": up, "down": false}
	if to.z >= from.z:
		return {}
	var dl := drop_link(from, to, field)
	if dl.is_empty() or not prefers_down_climb(int(dl["paces"]), merc_fall_tolerance, climb_hp):
		return {}
	if _link_climb_cost(dl, field, merc_size) < 0:
		return {}
	return {"link": dl, "down": true}


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
	if not field.is_interior_map and field.roof_cells.is_empty():
		return NO_CEILING
	var best := NO_CEILING
	if field.is_interior_map:
		for other: int in field.interior_floor_elevations.keys():
			if other <= f:
				continue
			if not field.has_slab(pos, other):
				continue
			var e := field.floor_elevation_at(pos, other)
			if e < best:
				best = e
	#The roof plane over pos is a ceiling for every floor under it; a flyer on the roof has none.
	if field.roof_elevations.has(pos):
		var roof_f: int = field.roof_level_at(pos)
		if roof_f > f:
			best = minf(best, float(field.roof_elevations[pos]))
	return best


#Pace cost of a same-floor step for a flyer. Walls, closed doors and intact windows
#block it exactly as they block a walker; any other obstacle is crossed by flying over
#its top, and the climb from the flyer's current z is charged on top of the base pace.
static func fly_cell_cost(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		merc_fall_tolerance: float, merc_size: int, altitude: int) -> int:
	var to2d := Vector2i(to.x, to.y)
	var from2d := Vector2i(from.x, from.y)
	var to_base: float = field.cell_base_elevation(to2d, to.z)
	#A cavern cell too low to fly through is entered on the ground at the crawling price.
	var cavern_crawl: bool = crawl_cell(field, to2d, merc_size)
	if cavern_crawl and field.clearance(to2d) < 1.0:
		return -1
	#The underside of a run overhead is a ceiling: the flyer's top must clear it.
	if not cavern_crawl and merc_size > 0 and float(altitude + merc_size) > field.stair_headroom(to2d, to.z):
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
	if cavern_crawl:
		if top > to_base:
			return -1
		return cavern_step_cost(field, from, to, merc_size, 1)
	#A flyer skims a pool only while it has height; on the surface it pays the swim price.
	if altitude < 1 and field.is_water(to2d):
		return cavern_step_cost(field, from, to, merc_size, 1)
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
		var fall := fall_cost(int(floor(drop)), merc_fall_tolerance)
		if fall < 0:
			return -1
		cost += fall
	return cost


#Altitude a flyer has on arriving at `to`, given the altitude it left `from` with.
#It never drops during a move: the flyer stays at the highest top it crossed.
static func fly_arrival_altitude(from: Vector3i, to: Vector3i, field: BattlefieldArea, altitude: int,
		merc_size: int = 1) -> int:
	if from.z != to.z:
		if to.z > from.z and (is_well_link(from, to, field) or is_roof_fly_link(from, to, field)):
			return 0
		return altitude
	var to2d := Vector2i(to.x, to.y)
	#A cavern cell too low to fly through is entered on the ground.
	if crawl_cell(field, to2d, merc_size):
		return 0
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
#Door open state and the lock are never baked; both are read live from the stored obstacle.
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
		if obs.get("rubble", false):
			kind = KIND_WALL
		elif cell_type == "wall":
			kind = KIND_WALL
		elif cell_type == "door":
			kind = KIND_DOOR
			door_ok = is_openable_door(obs)
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
	#A sloping roof cell is rugged footing and costs a walker what rugged ground costs.
	if kind == KIND_OPEN and base == 1 and not field.rugged_cells.is_empty() and field.rugged_cells.has(cell):
		base = 2
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
	if not field.in_bounds_xy(to.x, to.y):
		return -1
	if not floor_exists(field, to.z):
		return -1
	if from.z != to.z:
		var stair_cost := _stair_link_cost(from, to, field)
		if stair_cost >= 0:
			return stair_cost
		var well_cost := _well_link_cost(from, to, field, is_flying, altitude)
		if well_cost >= 0:
			return well_cost
		var roof_cost := _roof_fly_cost(from, to, field, is_flying, altitude)
		if roof_cost >= 0:
			return roof_cost
		var climbs: bool = climbs_links(field, is_flying)
		if climbs:
			var up := climb_link(from, to, field)
			if not up.is_empty():
				return _link_climb_cost(up, field, merc_size)
		var drop_cost := _drop_link_cost(from, to, field, merc_fall_tolerance, merc_size, is_flying)
		if climbs and to.z < from.z:
			var dl := drop_link(from, to, field)
			if not dl.is_empty() and prefers_down_climb(int(dl["paces"]), merc_fall_tolerance, climb_hp):
				var down_cost := _link_climb_cost(dl, field, merc_size)
				if down_cost >= 0:
					return down_cost
		return drop_cost

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
	var cavern: bool = field.is_cavern
	#A mover sunk to the pool floor leaves the water by climbing out, never on foot.
	if cavern and sunk_depth > 0 and field.is_water(Vector2i(from.x, from.y)):
		if not field.is_water(Vector2i(to.x, to.y)):
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
			if fall_cost(int(floor(-h_diff)), merc_fall_tolerance) < 0:
				return -1
		elif absf(h_diff) > 0.25 and not (on_stairs or has_stairs):
			return -1
		if cavern:
			return cavern_step_cost(field, from, to, merc_size, 1)
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
			base_cost = shut_door_cost(obs) if door_ok else -1
			if base_cost < 0:
				return -1
	elif kind == KIND_VAULT:
		var vaultable: bool = entry[SE_CAN_VAULT]
		var from_vault: bool = from_entry[SE_VAULT_CELL]
		if not vaultable or from_vault:
			return -1
		base_cost = VAULT_COST

	if cavern:
		base_cost = cavern_step_cost(field, from, to, merc_size, base_cost)

	if h_diff > 0.5:
		if h_diff <= 1.0:
			return base_cost + 2
		elif not can_climb or h_diff > 2.0:
			return -1
		else:
			base_cost += 2

	if h_diff <= -1.0:
		var fall := fall_cost(int(floor(-h_diff)), merc_fall_tolerance)
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

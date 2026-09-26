class_name PathHelper

const CARDINALS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

#True when a merc of merc_size may end a move standing on the cell.
#Rejects walls, intact windows, closed doors, vault-only cells and solid furniture.
static func is_standable(cell: Vector3i, field: BattlefieldArea, merc_size: int = 1) -> bool:
	var cell2d := Vector2i(cell.x, cell.y)
	if PathCost.under_stair_blocked(cell, field, merc_size):
		return false
	#Solid rock holds nobody; a pool does, since the mover swims or stands on its floor.
	if field.is_cavern and field.rock_cells.has(cell2d):
		return false
	if field.is_stair_cell(cell2d, cell.z):
		return true
	if PathCost.is_vault_cell(cell, field, merc_size):
		return false
	var obs: Dictionary = field.get_obs(cell2d, cell.z)
	if obs.is_empty():
		return true
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "window":
		return false
	if ct == "door":
		return OpenCloseState.is_open(obs)
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data == null:
		return false
	return data.passthrough or data.ramp


#True when a merc of merc_size may stand on top of the solid obstacle filling the cell.
#Tops are furniture-like: no stairs, no walls, doors or windows, no passthrough or ramp.
static func is_top_standable(cell: Vector3i, field: BattlefieldArea, merc_size: int = 1) -> bool:
	var cell2d := Vector2i(cell.x, cell.y)
	if field.is_stair_cell(cell2d, cell.z) or field.jagged_cells.has(cell2d):
		return false
	var obs: Dictionary = field.get_obs(cell2d, cell.z)
	if obs.is_empty():
		return false
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "window" or ct == "door":
		return false
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data == null:
		return false
	if data.passthrough or data.ramp or data.narrow or data.is_building or data.is_room:
		return false
	var top_h := BattlefieldArea.obstacle_height(obs)
	if top_h < 1.0:
		return false
	#In a cavern the rock roof is the ceiling: the mover's top must fit under it.
	if field.is_cavern:
		return top_h + float(maxi(1, merc_size)) <= field.clearance(cell2d)
	var ceiling := PathCost.slab_above(cell2d, cell.z, field)
	if ceiling >= PathCost.NO_CEILING:
		return true
	return field.cell_base_elevation(cell2d, cell.z) + top_h + float(maxi(1, merc_size)) <= ceiling


#Like Pathfinder.find_path, but when the goal is unreachable returns a path to the
#closest reachable node, ranked by (floor gap, 2D Chebyshev) lexicographically.
#Returns [] only when no node at all can be reached.
static func find_path_toward(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		jump_range: int = 0,
		merc_size: int = 1,
		altitude: int = 0) -> Array[Vector3i]:
	var g_of: Dictionary = {from: 0}
	var parent_of: Dictionary = {}
	var alt_of: Dictionary = {from: altitude}
	var heap: Array = [[Pathfinder.chebyshev(from, to), from]]
	var closed: Dictionary = {}

	var best_reachable := from
	var best_dz := absi(from.z - to.z)
	var best_dist := Pathfinder.chebyshev(from, to)
	#Start already holds the best possible rank and no jump pass can beat it: nothing to return.
	if jump_range == 0 and best_dz == 0 and best_dist == 1:
		var at_best: Array[Vector3i] = []
		return at_best

	while not heap.is_empty():
		var top: Array = Pathfinder.heap_pop(heap)
		var curr: Vector3i = top[1]
		if closed.has(curr):
			continue
		closed[curr] = true

		var curr_alt: int = altitude
		if is_flying:
			curr_alt = alt_of[curr] as int
		var curr_g: int = g_of[curr] as int
		var curr_entry: Array = PathCost.static_entry(field, curr, merc_size)
		var dz := absi(curr.z - to.z)
		var dist := Pathfinder.chebyshev(curr, to)
		#A flyer may not stop on a flyover cell, so it is never a partial goal.
		if (dz < best_dz or (dz == best_dz and dist < best_dist)) \
				and not curr_entry[PathCost.SE_VAULT_CELL] \
				and not (is_flying and PathCost.is_flyover_cell(curr, field)):
			var has_fwd := false
			for fn: Vector3i in PathCost.neighbors(curr, field):
				var fdz := absi(fn.z - to.z)
				var fdist := Pathfinder.chebyshev(fn, to)
				if (fdz < dz or (fdz == dz and fdist < dist)) \
						and PathCost.cell_pace_cost(curr, fn, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, curr_alt, curr_entry) >= 0:
					has_fwd = true
					break
			if has_fwd:
				best_dz = dz
				best_dist = dist
				best_reachable = curr
				#Best possible rank reached and no jump pass follows, so no later pop can improve it.
				if jump_range == 0 and best_dz == 0 and best_dist == 1:
					break

		Pathfinder.relax_neighbors(curr, curr_alt, curr_g, curr_entry, field, to, passable_cells,
			merc_fall_tolerance, is_flying, can_climb, merc_size, closed, {},
			g_of, parent_of, alt_of, heap)

	if jump_range > 0:
		#The exit test left the expansion loop: a closed cell without one counts as unreached here, from and to exempt.
		var exit_ok: Dictionary = {}
		for cell: Vector3i in closed.keys():
			#A jump stays on the cell's floor and lands at most jump_range cells nearer: skip cells that cannot beat the rank.
			var cdz := absi(cell.z - to.z)
			if cdz > best_dz:
				continue
			if cdz == best_dz and Pathfinder.chebyshev(cell, to) - jump_range >= best_dist:
				continue
			if not _toward_reached(cell, from, to, exit_ok, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, altitude, alt_of):
				continue
			for dest: Array in PathCost.jump_dests(field, cell, jump_range, merc_size):
				var jcell: Vector3i = dest[0] as Vector3i
				if closed.has(jcell) and _toward_reached(jcell, from, to, exit_ok, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, altitude, alt_of):
					continue
				if PathCost.jump_row_blocked(dest):
					continue
				var jdist := Pathfinder.chebyshev(jcell, to)
				if cdz < best_dz or (cdz == best_dz and jdist < best_dist):
					best_dz = cdz
					best_dist = jdist
					best_reachable = cell

	if best_reachable == from:
		var empty: Array[Vector3i] = []
		return empty
	return Pathfinder.path_from_parents(parent_of, best_reachable, from)


#True when a closed cell counts as reached: from, to, or a cell with an exit at its altitude (cached in exit_ok).
static func _toward_reached(cell: Vector3i, from: Vector3i, to: Vector3i, exit_ok: Dictionary, field: BattlefieldArea,
		passable_cells: Dictionary, merc_fall_tolerance: float, is_flying: bool, can_climb: bool, merc_size: int,
		altitude: int, alt_of: Dictionary) -> bool:
	if cell == from or cell == to:
		return true
	if exit_ok.has(cell):
		return exit_ok[cell] as bool
	var cell_alt: int = altitude
	if is_flying:
		cell_alt = alt_of.get(cell, altitude) as int
	var ok := PathCost.has_exit_neighbor(cell, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, cell_alt)
	exit_ok[cell] = ok
	return ok


#True when the mover could end on `cell`: standable, unoccupied and enterable from a cardinal neighbour.
static func is_goal_passable(cell: Vector3i, field: BattlefieldArea, p_fall_tolerance: float, p_can_climb: bool,
		p_merc_size: int, p_is_flying: bool, p_altitude: int, p_state: BattleState, p_merc: MercenaryData) -> bool:
	if not is_standable(cell, field, p_merc_size):
		return false
	if p_state != null and p_state.is_position_occupied(Vector2i(cell.x, cell.y), p_merc, cell.z):
		return false
	for cd: Vector2i in CARDINALS:
		var nb := Vector3i(cell.x + cd.x, cell.y + cd.y, cell.z)
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		if PathCost.cell_pace_cost(nb, cell, field, {}, p_fall_tolerance, p_is_flying, p_can_climb, p_merc_size, p_altitude) >= 0:
			return true
	return false


#Nearest standable cell to pos within 3 cells, on pos.z only. Returns pos when already valid.
#`p_reachable` is a reachable_from() result; cells in it (at cost <= p_max_cost when that is
#positive) win over merely locally passable ones, so the mover gets a goal it can path to.
#The local-passability search is the fallback when nothing reachable is in range.
#Ties break on squared distance to pos, then to p_from; never on DIRS8 order.
#`mover` carries the mover profile: fall_tolerance, can_climb, merc_size, flying, altitude, state, merc.
static func nearest_passable_to(pos: Vector3i, field: BattlefieldArea, mover: Dictionary,
		p_excluded: Dictionary = {}, p_reachable: Dictionary = {},
		p_from: Vector3i = Vector3i(-1, -1, -1), p_max_cost: int = 0) -> Vector3i:
	var p_fall_tolerance := float(mover.get("fall_tolerance", 1.0))
	var p_can_climb := bool(mover.get("can_climb", false))
	var p_merc_size := int(mover.get("merc_size", 1))
	var p_is_flying := bool(mover.get("flying", false))
	var p_altitude := int(mover.get("altitude", 0))
	var p_state: BattleState = mover.get("state") as BattleState
	var p_merc: MercenaryData = mover.get("merc") as MercenaryData
	var is_passable := func(cell: Vector3i) -> bool:
		return is_goal_passable(cell, field, p_fall_tolerance, p_can_climb, p_merc_size, p_is_flying, p_altitude, p_state, p_merc)

	var use_reach := not p_reachable.is_empty()
	for pass_idx: int in [0, 1]:
		if pass_idx == 0 and not use_reach:
			continue
		var found := false
		var best := pos
		var best_d := 0.0
		var best_f := 0.0
		for dx: int in range(-3, 4):
			for dy: int in range(-3, 4):
				var cell := Vector3i(pos.x + dx, pos.y + dy, pos.z)
				if cell.x < 0 or cell.x >= field.width or cell.y < 0 or cell.y >= field.length:
					continue
				if p_excluded.has(cell):
					continue
				if pass_idx == 0:
					if not p_reachable.has(cell):
						continue
					if p_max_cost > 0 and (p_reachable[cell] as int) > p_max_cost:
						continue
				if not is_passable.call(cell):
					continue
				var kd := float(dx * dx + dy * dy)
				var kf := 0.0
				if p_from.x >= 0:
					kf = float((cell.x - p_from.x) * (cell.x - p_from.x) + (cell.y - p_from.y) * (cell.y - p_from.y))
				if not found or kd < best_d or (kd == best_d and kf < best_f):
					found = true
					best_d = kd
					best_f = kf
					best = cell
		if found:
			return best
	return pos

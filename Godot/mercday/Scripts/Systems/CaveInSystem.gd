class_name CaveInSystem

#The cavern ceiling hazard: a rising chance queues a round, the round drops rubble, and the rubble
#crushes, buries and cuts off whoever stands under it. Every state it holds carries the engine source
#CavernRules.RUBBLE_SOURCE, so only clearing the last cube of the cell ends it.
const BASE_CHANCE := 1
const POINT_WEIGHTS: Array[int] = [30, 20, 14, 10, 7, 5, 4, 3, 2, 2, 2, 1]
const MAX_CUBES := 3
const CUBE_HP_MIN := 10
const CUBE_HP_SPREAD := 25
const SEAL_MAX := 5
const BLOCK_MAX := 5
const CRUSH_STRIKE := 3
const CRUSH_LACERATE := 1
const CRUSH_EP := 1
const CRUSH_SPEC: Dictionary = {"type": "resist", "stat": "dexterity", "trial": 1, "attempt": ""}
const RUBBLE_NAME := "Cave-In Rubble"
const MARK := "Cave-In"
const OFF_MAP := Vector2i(-1, -1)
const CELL_DRAWS := 500
const SAFE_STEPS := 12

static var force_every: bool = false      #harness: every cavern battle queues a cave-in at start
static var triggered_total: int = 0       #harness: cave-ins fired since launch


static func is_cavern(state: BattleState) -> bool:
	return state != null and state.battlefield != null and state.battlefield.is_cavern


static func on_battle_start(state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if not is_cavern(state):
		return lines
	state.cave_in_chance = BASE_CHANCE
	state.cave_in_due.clear()
	state.cave_in_buried.clear()
	state.cave_in_marked.clear()
	if force_every or roll(state):
		lines.append_array(queue(state, randi_range(1, 3)))
	return lines


static func bump_round(state: BattleState) -> void:
	if state == null:
		return
	state.cave_in_chance += 1


static func roll(state: BattleState) -> bool:
	if state == null:
		return false
	return randi_range(1, 100) <= state.cave_in_chance


static func queue(state: BattleState, round_no: int) -> Array[String]:
	var lines: Array[String] = []
	if state == null:
		return lines
	if not state.cave_in_due.has(round_no):
		state.cave_in_due.append(round_no)
	var rolled: int = state.cave_in_chance
	state.cave_in_chance = BASE_CHANCE
	var line := "CAVE-IN QUEUED: end of round %d (chance %d%%)" % [round_no, rolled]
	lines.append(line)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose(line)
	return lines


static func start_of_round(state: BattleState, lines: Array[String]) -> void:
	if not is_cavern(state):
		return
	bump_round(state)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CAVE-IN CHANCE: %d%%" % state.cave_in_chance)
	if roll(state):
		lines.append_array(queue(state, state.round_number + randi_range(0, 2)))


#Strike and Sonic shake the ceiling; the raw roll before defence pays 1 point per full 5 damage.
static func note_damage(state: BattleState, damage_type: String, damage: int) -> void:
	if not is_cavern(state) or damage <= 0:
		return
	if damage_type != "Strike" and damage_type != "Sonic":
		return
	var bump: int = 1 + int(damage / 5.0)
	state.cave_in_chance += bump
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CAVE-IN CHANCE: %d%% (+%d from %s %d)" % [
			state.cave_in_chance, bump, damage_type, damage])


static func end_of_round(state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if not is_cavern(state) or not state.cave_in_due.has(state.round_number):
		return lines
	state.cave_in_due.erase(state.round_number)
	return trigger(state)


static func trigger(state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var field: BattlefieldArea = state.battlefield if state != null else null
	if field == null:
		return lines
	state.cave_in_count += 1
	triggered_total += 1
	var points: int = WeightedTable.pick_index(POINT_WEIGHTS) + 1
	var tunnel_index: Dictionary = {}
	for i: int in range(field.cavern_tunnels.size()):
		for cell: Vector2i in (field.cavern_tunnels[i]["cells"] as Array):
			tunnel_index[cell] = i
	var chamber_index: Dictionary = CavernGenerator.chamber_index(field)
	var footprint: Dictionary = {}
	for _p: int in range(points):
		_point_footprint(field, tunnel_index, chamber_index, footprint)
	_filter_footprint(field, footprint)
	var body: Array[String] = []
	var crushed: Array[MercenaryData] = _crush_all(state, footprint, body)
	var cells: int = _spawn_rubble(state, footprint)
	for merc: MercenaryData in crushed:
		var cell: Vector2i = state.get_position(merc)
		if not field.get_obs(cell, 0).is_empty():
			_bury(merc, state, cell, body)
	_mark_party(state, body)
	lines.append("CAVE-IN: %d point(s), %d rubble cell(s)" % [points, cells])
	lines.append_array(body)
	return lines


#A tunnel point seals the tunnel across its width; anything else drops a rectangular block.
static func _point_footprint(field: BattlefieldArea, tunnel_index: Dictionary, chamber_index: Dictionary,
		out: Dictionary) -> void:
	var cell := _random_open_cell(field)
	if cell == OFF_MAP:
		return
	var anchor := cell
	var t: int = int(tunnel_index.get(cell, -1))
	if t < 0:
		for d: Vector2i in PathCost.DIRS8:
			var nb: Vector2i = cell + d
			if tunnel_index.has(nb):
				t = int(tunnel_index[nb])
				anchor = nb
				break
	if t >= 0 and not chamber_index.has(anchor):
		if _seal(field, t, anchor, out) > 0:
			return
	_block(field, cell, out)


static func _random_open_cell(field: BattlefieldArea) -> Vector2i:
	for _i: int in range(CELL_DRAWS):
		var cell := Vector2i(randi_range(0, field.width - 1), randi_range(0, field.length - 1))
		if not field.rock_cells.has(cell) and field.cavern_ceiling.has(cell):
			return cell
	for y: int in range(field.length):
		for x: int in range(field.width):
			var cell := Vector2i(x, y)
			if not field.rock_cells.has(cell) and field.cavern_ceiling.has(cell):
				return cell
	return OFF_MAP


static func _seal(field: BattlefieldArea, t: int, anchor: Vector2i, out: Dictionary,
		fixed_len: int = 0) -> int:
	if t < 0 or t >= field.cavern_tunnels.size():
		return 0
	var cells: Dictionary = {}
	for cell: Vector2i in (field.cavern_tunnels[t]["cells"] as Array):
		cells[cell] = true
	if not cells.has(anchor):
		return 0
	var chambers: Dictionary = CavernGenerator.chamber_index(field)
	var rows: int = 0
	var cols: int = 0
	for cell: Vector2i in cells.keys():
		if cell.y == anchor.y and absi(cell.x - anchor.x) <= 3:
			rows += 1
		if cell.x == anchor.x and absi(cell.y - anchor.y) <= 3:
			cols += 1
	var along_x: bool = rows >= cols
	var seal_len: int = fixed_len if fixed_len > 0 else randi_range(1, SEAL_MAX)
	var lo: int = anchor.x if along_x else anchor.y
	var hi: int = lo + seal_len - 1
	var width: int = maxi(1, int(field.cavern_tunnels[t].get("width", 1)))
	var perp_at: int = anchor.y if along_x else anchor.x
	var candidates: Dictionary = {}
	for cell: Vector2i in cells.keys():
		if chambers.has(cell):
			continue
		var axis: int = cell.x if along_x else cell.y
		var perp: int = cell.y if along_x else cell.x
		if axis >= lo and axis <= hi and absi(perp - perp_at) < width:
			candidates[cell] = true
	if not candidates.has(anchor):
		return 0
	var added: int = 0
	var queued: Array[Vector2i] = [anchor]
	var seen: Dictionary = {anchor: true}
	var qi: int = 0
	while qi < queued.size():
		var curr: Vector2i = queued[qi]
		qi += 1
		if not out.has(curr):
			out[curr] = true
			added += 1
		for d: Vector2i in PathCost.DIRS8:
			var nb: Vector2i = curr + d
			if seen.has(nb) or not candidates.has(nb):
				continue
			seen[nb] = true
			queued.append(nb)
	return added


static func _block(field: BattlefieldArea, cell: Vector2i, out: Dictionary) -> void:
	var w: int = randi_range(1, BLOCK_MAX)
	var l: int = randi_range(1, BLOCK_MAX)
	var origin := cell - Vector2i(randi_range(0, w - 1), randi_range(0, l - 1))
	for dy: int in range(l):
		for dx: int in range(w):
			var c := Vector2i(origin.x + dx, origin.y + dy)
			if not field.in_bounds_xy(c.x, c.y):
				continue
			if field.rock_cells.has(c) or not field.cavern_ceiling.has(c):
				continue
			out[c] = true


#Cells a footprint never takes: rubble that already stands there, walls, doors, windows and buildings.
static func _filter_footprint(field: BattlefieldArea, footprint: Dictionary) -> void:
	var drop: Array[Vector2i] = []
	for cell: Vector2i in footprint.keys():
		var obs: Dictionary = field.get_obs(cell, 0)
		if obs.is_empty():
			continue
		if bool(obs.get("rubble", false)):
			drop.append(cell)
			continue
		var ct: String = str(obs.get("cell_type", ""))
		if ct == "wall" or ct == "door" or ct == "window":
			drop.append(cell)
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.is_building:
			drop.append(cell)
	for cell: Vector2i in drop:
		footprint.erase(cell)


static func cube_count(field: BattlefieldArea, cell: Vector2i) -> int:
	return clampi(floori(field.clearance(cell) + float(field.water_depth(cell)) + CavernGenerator.EPS),
		1, MAX_CUBES)


static func is_submerged(field: BattlefieldArea, cell: Vector2i) -> bool:
	return field.is_water(cell) and cube_count(field, cell) < field.water_depth(cell)


static func _spawn_rubble(state: BattleState, footprint: Dictionary) -> int:
	var field := state.battlefield
	var data := _rubble_data()
	if data == null:
		return 0
	var count: int = 0
	for cell: Vector2i in footprint.keys():
		var existing: Dictionary = field.get_obs(cell, 0)
		if not existing.is_empty():
			var raw_pos: Variant = existing.get("pos", cell)
			ObstacleUtils.remove_obstacle(existing, raw_pos, cell, 0,
				existing.get("data") as ObstacleData, state)
		var depth: int = field.water_depth(cell)
		var n: int = cube_count(field, cell)
		var cubes: Array[int] = []
		for _c: int in range(n):
			cubes.append(_cube_hp())
		if is_submerged(field, cell):
			field.terrain_heights[cell] = field.get_terrain_height(cell) + float(n)
			field.ground_heights[cell] = field.ground_height(cell) + float(n)
			field.water_cells[cell] = depth - n
			for merc: MercenaryData in state.positions.keys():
				if state.get_position(merc) == cell and state.is_sunk(merc):
					state.set_sunk(merc, depth - n)
		else:
			var obs: Dictionary = {"pos": cell, "floor": 0, "size": 1, "data": data,
				"cell_type": "terrain", "rubble": true, "cubes": cubes,
				"current_hp": cubes[0], "hp_max": cubes[0], "height": float(cubes.size())}
			if depth > 0:
				obs["water_depth"] = depth
				field.water_cells.erase(cell)
			field.add_obstacle(obs, field.obs_key(cell, 0))
		count += 1
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CAVE-IN CELL: (%d,%d) cubes=%d hp=%s water=%d" % [
				cell.x, cell.y, n, str(cubes), depth])
	field.los_version += 1
	field.bump_path_version()
	field._rebuild_cover_obstacles()
	field._rebuild_droppable_obs_map()
	MovementExecutor.clear_caches()
	CoverSearch.clear_scan_cache()
	return count


static func _cube_hp() -> int:
	return CUBE_HP_MIN + randi_range(0, CUBE_HP_SPREAD) + randi_range(0, CUBE_HP_SPREAD)


static func _rubble_data() -> ObstacleData:
	var sheet: ObstacleData = DataManager.obstacles_by_name.get(RUBBLE_NAME) as ObstacleData
	if sheet == null:
		push_error("CaveInSystem: no '%s' row in Obstacles.tsv" % RUBBLE_NAME)
	return sheet


#Runs before the rubble lands: positions, water flags and sunk depths are still the original ones.
static func _crush_all(state: BattleState, footprint: Dictionary,
		lines: Array[String]) -> Array[MercenaryData]:
	var field := state.battlefield
	var out: Array[MercenaryData] = []
	var standing: Array[MercenaryData] = []
	standing.assign(state.positions.keys())
	for merc: MercenaryData in standing:
		if not BattleState._is_alive(merc):
			continue
		var cell: Vector2i = state.get_position(merc)
		if not footprint.has(cell):
			continue
		var takes_obstacle: bool = not is_submerged(field, cell)
		if field.is_water(cell) and takes_obstacle:
			CavernRules.on_surface(merc, state, lines)
		if _crush_attempt(merc, state, footprint, lines) and takes_obstacle:
			out.append(merc)
	return out


static func _crush_attempt(merc: MercenaryData, state: BattleState, footprint: Dictionary,
		lines: Array[String]) -> bool:
	var can_try: bool = ExcessPool.available_ep(merc) >= CRUSH_EP \
		and not ConstStates.has_state(merc, ConstStates.DYING) \
		and not ConstStates.has_state(merc, ConstStates.UNCONSCIOUS) \
		and not StateEffects.is_blocked(merc, "action:move")
	if not can_try:
		return _resolve_crush(merc, state, footprint, false, lines)
	ExcessPool.pay_ep(merc, CRUSH_EP)
	var res := StateInfliction.resist_check(merc, CRUSH_SPEC, "", 0, 0, null)
	var passed := bool(res.get("passed", false))
	lines.append("CRUSH CHECK: %s %s" % [
		BattleState.colored_name(merc, state), "passed" if passed else "failed"])
	return _resolve_crush(merc, state, footprint, passed, lines)


static func _resolve_crush(merc: MercenaryData, state: BattleState, footprint: Dictionary,
		passed: bool, lines: Array[String]) -> bool:
	var field := state.battlefield
	var from: Vector2i = state.get_position(merc)
	if passed:
		var sunk: bool = state.is_sunk(merc)
		var dest := _nearest_safe_cell(state, from, footprint, sunk)
		if dest != OFF_MAP:
			state.set_position(merc, dest)
			if sunk:
				state.set_sunk(merc, field.water_depth(dest))
			elif not PathTargeter.is_flying(merc):
				state.set_height(merc, 0)
			var from_for_entry: Vector2i = from
			if field != null and field.is_water(from) and not is_submerged(field, from):
				from_for_entry = OFF_MAP
			CavernRules.on_enter_cell(merc, from_for_entry, dest, state, lines)
			lines.append("DODGED RUBBLE: %s to (%d,%d)" % [
				BattleState.colored_name(merc, state), dest.x, dest.y])
			return false
	lines.append_array(CombatApplicator.apply_damage(null, merc, CRUSH_STRIKE, "Strike", state, 0, true))
	if BattleState._is_alive(merc):
		lines.append_array(CombatApplicator.apply_damage(null, merc, CRUSH_LACERATE, "Lacerate",
			state, 0, true))
	lines.append("CRUSHED: %s" % BattleState.colored_name(merc, state))
	state.cave_in_marked[merc] = "crushed"
	return true


static func _bury(merc: MercenaryData, state: BattleState, cell: Vector2i,
		lines: Array[String]) -> void:
	if not BattleState._is_alive(merc):
		return
	state.set_height(merc, 0)
	_hold(merc, ConstStates.GRAPPLED)
	_hold(merc, ConstStates.INHIBITED)
	_hold(merc, ConstStates.SUFFOCATING)
	state.cave_in_buried[merc] = cell
	lines.append("BURIED: %s" % BattleState.colored_name(merc, state))


static func _hold(merc: MercenaryData, state_name: String) -> void:
	if CavernRules.apply(merc, state_name, CavernRules.RUBBLE_SOURCE):
		return
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE REFUSED: %s %s" % [merc.merc_name, state_name])


static func _free(merc: MercenaryData, state: BattleState) -> void:
	CavernRules.release(merc, ConstStates.GRAPPLED, CavernRules.RUBBLE_SOURCE, state, "rubble cleared")
	CavernRules.release(merc, ConstStates.INHIBITED, CavernRules.RUBBLE_SOURCE, state, "rubble cleared")
	CavernRules.release(merc, ConstStates.SUFFOCATING, CavernRules.RUBBLE_SOURCE, state, "rubble cleared")


#Nearest cell outside the whole footprint; the walk may cross footprint cells to get there.
#A sunk merc walks the pool floor, so only water cells count and the floor sets the slope.
static func _nearest_safe_cell(state: BattleState, from: Vector2i, footprint: Dictionary,
		water_only: bool = false) -> Vector2i:
	var field := state.battlefield
	if field == null:
		return OFF_MAP
	var occupied: Dictionary = {}
	for merc: MercenaryData in state.positions.keys():
		if BattleState._is_alive(merc):
			occupied[state.get_position(merc)] = true
	var seen: Dictionary = {from: true}
	var frontier: Array[Vector2i] = [from]
	var steps: int = 0
	while not frontier.is_empty() and steps < SAFE_STEPS:
		steps += 1
		var next: Array[Vector2i] = []
		for curr: Vector2i in frontier:
			for d: Vector2i in PathCost.DIRS8:
				var nb: Vector2i = curr + d
				if seen.has(nb):
					continue
				seen[nb] = true
				if not field.in_bounds_xy(nb.x, nb.y):
					continue
				if field.rock_cells.has(nb) or not field.cavern_ceiling.has(nb):
					continue
				if water_only and not field.is_water(nb):
					continue
				if not footprint.has(nb) and field.is_obstacle(nb, 0):
					continue
				var h_nb: float = field.get_terrain_height(nb) if water_only else field.surface_height(nb)
				var h_cur: float = field.get_terrain_height(curr) if water_only else field.surface_height(curr)
				if absf(h_nb - h_cur) > CavernGenerator.SLOPE + CavernGenerator.EPS:
					continue
				next.append(nb)
		next.shuffle()
		for nb: Vector2i in next:
			if not footprint.has(nb) and not occupied.has(nb):
				return nb
		frontier = next
	return OFF_MAP


#True when the cell lost its last cube; the caller then removes the obstacle.
static func pop_cube(obs_cell: Dictionary, state: BattleState, lines: Array[String]) -> bool:
	var cubes: Array = obs_cell.get("cubes", []) as Array
	if not cubes.is_empty():
		cubes.pop_front()
	if cubes.is_empty():
		return true
	obs_cell["current_hp"] = int(cubes[0])
	obs_cell["hp_max"] = int(cubes[0])
	obs_cell["height"] = float(cubes.size())
	if state != null and state.battlefield != null:
		state.battlefield.los_version += 1
	lines.append("  Rubble above collapses into the gap (%d cube(s) left)." % cubes.size())
	return false


static func on_cell_cleared(obs_cell: Dictionary, cell: Vector2i, state: BattleState,
		lines: Array[String]) -> void:
	if state == null:
		return
	var field := state.battlefield
	if field != null and obs_cell.has("water_depth"):
		field.water_cells[cell] = int(obs_cell["water_depth"])
		field.los_version += 1
		field.bump_path_version()
		MovementExecutor.clear_caches()
	var freed: Array[MercenaryData] = []
	for merc: MercenaryData in state.cave_in_buried.keys():
		if state.cave_in_buried[merc] == cell:
			freed.append(merc)
	for merc: MercenaryData in freed:
		_free(merc, state)
		state.cave_in_buried.erase(merc)
		lines.append("FREED: %s" % BattleState.colored_name(merc, state))
		if field != null and field.is_water(cell):
			CavernRules.on_enter_cell(merc, OFF_MAP, cell, state, lines)


#A buried merc spends its whole turn hacking at the cube on its own cell.
static func buried_turn(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if state == null:
		return lines
	var cell: Vector2i = state.cave_in_buried.get(merc, OFF_MAP)
	var field := state.battlefield
	var obs: Dictionary = field.get_obs(cell, 0) if field != null else {}
	if obs.is_empty() or not bool(obs.get("rubble", false)):
		on_cell_cleared({}, cell, state, lines)
		return lines
	lines.append("  %s digs at the rubble." % BattleState.colored_name(merc, state))
	lines.append_array(SpecialActionSystem.attack_obstacle_at(merc, state, obs, enhancements))
	return lines


#Rubble beside the merc that holds a buried ally; {} when there is none.
static func dig_target(merc: MercenaryData, state: BattleState) -> Dictionary:
	if state == null or state.battlefield == null:
		return {}
	var field := state.battlefield
	var pos := state.get_position(merc)
	var team: int = int(state._merc_team_index.get(merc, -1))
	for obs: Dictionary in field.get_adjacent_obstacles(pos, state.get_floor(merc)):
		if not bool(obs.get("rubble", false)):
			continue
		var cell := BattlefieldArea.cell_of(obs.get("pos", OFF_MAP))
		for buried: MercenaryData in state.cave_in_buried.keys():
			if state.cave_in_buried[buried] != cell or not BattleState._is_alive(buried):
				continue
			if int(state._merc_team_index.get(buried, -2)) == team:
				return obs
	return {}


static func _mark_party(state: BattleState, lines: Array[String]) -> void:
	var field := state.battlefield
	if field == null or state.teams.is_empty():
		return
	var party: Array[MercenaryData] = []
	for merc: MercenaryData in (state.teams[0] as Array):
		if BattleState._is_alive(merc):
			party.append(merc)
	if party.is_empty():
		return
	var reach: Dictionary = CavernGenerator.reachable_from(field, field.entrance_cells)
	for merc: MercenaryData in party:
		if str(state.cave_in_marked.get(merc, "")) == "crushed":
			continue
		var cell: Vector2i = state.get_position(merc)
		if not reach.has(cell):
			state.cave_in_marked[merc] = "cut_off"
			lines.append("CUT OFF: %s" % BattleState.colored_name(merc, state))
			continue
		var starts: Array[Vector2i] = [cell]
		var comp: Dictionary = CavernGenerator.reachable_from(field, starts)
		var outside: int = 0
		for other: MercenaryData in party:
			if other != merc and not comp.has(state.get_position(other)):
				outside += 1
		if outside * 2 > party.size():
			state.cave_in_marked[merc] = "separated"
			lines.append("SEPARATED: %s (%d of %d beyond the rubble)" % [
				BattleState.colored_name(merc, state), outside, party.size()])


static func settle(run: ContractRun, state: BattleState, roster: Array[MercenaryData]) -> Array[String]:
	var out: Array[String] = []
	if run == null or state == null:
		return out
	for merc: MercenaryData in roster:
		if not state.cave_in_marked.has(merc):
			continue
		run.add_merc_mark(merc, MARK)
		out.append("CAVE-IN MARK: %s (%s)" % [merc.merc_name, str(state.cave_in_marked[merc])])
	return out

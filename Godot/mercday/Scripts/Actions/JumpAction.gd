class_name JumpAction extends ActionData

const NO_JUMP := Vector3i(-9999, -9999, -9999)

#Why the last pick qualified; to_decision_dict passes it on to the executor's log.
var _jump_why: String = ""
#Last target picked by can_execute; to_decision_dict reads it back so the search runs once.
var _jump_pick: Vector3i = NO_JUMP

func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not super.can_execute(merc, ctx):
		return false
	if int(merc.stats.get("jump", 0)) <= 0:
		return false
	_jump_pick = _find_best_jump_target(merc, ctx)
	return _jump_pick != NO_JUMP

func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := super.to_decision_dict(merc, ctx)
	var best := _jump_pick
	if best == NO_JUMP:
		result["jump_target_pos"] = Vector2i(-1, -1)
		result["jump_target_floor"] = 0
		result["jump_why"] = ""
	else:
		result["jump_target_pos"] = Vector2i(best.x, best.y)
		result["jump_target_floor"] = best.z
		result["jump_why"] = _jump_why
	return result


#Ground landing: a cell the jumper may drop onto, stand in and walk out of.
static func _plain_landing(cell3: Vector3i, field: BattlefieldArea, merc_size: int) -> bool:
	if not PathCost.is_valid_jump_dest(cell3, field, merc_size):
		return false
	if not PathHelper.is_standable(cell3, field, merc_size):
		return false
	return PathCost.has_exit_neighbor(cell3, field, {}, 1.0, false, false, merc_size)


#Landing test for one candidate cell; {} when the cell is no landing.
#"elev" is the absolute standing elevation, "why" is "same", "top", "up", "down" or "roof".
static func _landing_at(cell3: Vector3i, field: BattlefieldArea, state: BattleState,
		merc: MercenaryData, merc_size: int, merc_floor: int) -> Dictionary:
	if cell3.x < 0 or cell3.x >= field.width or cell3.y < 0 or cell3.y >= field.length:
		return {}
	if not PathCost.floor_exists(field, cell3.z):
		return {}
	var cell2d := Vector2i(cell3.x, cell3.y)
	if state.is_position_occupied(cell2d, merc, cell3.z):
		return {}
	var base := field.cell_base_elevation(cell2d, cell3.z)
	if cell3.z != merc_floor and field.is_roof_footing(cell2d, cell3.z):
		if not _plain_landing(cell3, field, merc_size):
			return {}
		return {"elev": base, "why": "roof"}
	if cell3.z > merc_floor:
		if not field.is_stair_cell(cell2d, cell3.z) or PathCost.is_landing_alias(cell3, field):
			return {}
		if not _plain_landing(cell3, field, merc_size):
			return {}
		return {"elev": base, "why": "up"}
	if cell3.z < merc_floor:
		if field.is_stair_cell(cell2d, cell3.z):
			return {}
		if not field.has_walkable_surface(cell2d, cell3.z):
			return {}
		if not _plain_landing(cell3, field, merc_size):
			return {}
		return {"elev": base, "why": "down"}
	if _plain_landing(cell3, field, merc_size):
		return {"elev": base, "why": "same"}
	if not PathHelper.is_top_standable(cell3, field, merc_size):
		return {}
	if not PathCost.has_exit_neighbor(cell3, field, {}, 1.0, false, false, merc_size, 0):
		return {}
	var obs: Dictionary = field.get_obs(cell2d, cell3.z)
	return {"elev": base + BattlefieldArea.obstacle_height(obs), "why": "top"}


#A landing a pace or more below the jumper costs fall damage, so it is never chosen.
#A roof landing accepts any fall the jumper survives, so a leap down onto a lower roof is allowed.
static func _fall_ok(merc: MercenaryData, drop: float, roof_landing: bool = false) -> bool:
	if drop < 1.0:
		return true
	if not roof_landing:
		return false
	return PathCost._fall_cost(int(floor(drop)), PathTargeter.fall_tolerance(merc)) >= 0


#True when a roof part between the two cells stands above the height the leap clears.
static func _roof_in_way(field: BattlefieldArea, from2: Vector2i, to2: Vector2i,
		clear_elev: float) -> bool:
	if field == null or field.roof_span.is_empty():
		return false
	var steps: Array[Dictionary] = LineOfSight._steps(from2, to2)
	var last: int = steps.size() - 1
	for i: int in range(last):
		var c: Vector2i = steps[i]["c"] as Vector2i
		if c == from2 or c == to2:
			continue
		if not field.roof_span.has(c):
			continue
		if (field.roof_span[c] as Vector2).y > clear_elev + 0.01:
			return true
	return false


#"" when walking there beats the leap; else "unreachable" or "shorter".
static func _walk_reason(from3: Vector3i, cell3: Vector3i, field: BattlefieldArea,
		merc_size: int, chebyshev: int, move_paces: int) -> String:
	var path := Pathfinder.find_path(from3, cell3, field, {}, 1.0, false, false, merc_size)
	if path.is_empty():
		return "unreachable"
	var walk_cost := 0
	for i: int in range(1, path.size()):
		var step := PathCost.cell_pace_cost(path[i - 1], path[i], field, {}, 1.0, false, false, merc_size, 0)
		walk_cost += 999 if step < 0 else step
	if walk_cost > chebyshev and walk_cost > move_paces:
		return "shorter"
	return ""


#The why string one candidate cell earns, or "" when the jumper may not take it.
static func _cell_pick(cell3: Vector3i, merc: MercenaryData, state: BattleState,
		field: BattlefieldArea, from3: Vector3i, merc_pos: Vector2i, merc_floor: int,
		merc_size: int, merc_elev: float, jump_stat: int, chebyshev: int, move_paces: int,
		roof_goal: bool) -> String:
	var land := _landing_at(cell3, field, state, merc, merc_size, merc_floor)
	if land.is_empty():
		return ""
	var cell_elev: float = land["elev"]
	var height_cost := int(ceil(maxf(0.0, cell_elev - merc_elev)))
	if chebyshev + height_cost > jump_stat:
		return ""
	var kind: String = land["why"]
	var roof_land: bool = kind == "roof"
	#A leap onto a roof is taken only by a jumper already on a roof or after an enemy who stands on one.
	if roof_land and not roof_goal:
		return ""
	if not _fall_ok(merc, merc_elev - cell_elev, roof_land):
		return ""
	var cell2 := Vector2i(cell3.x, cell3.y)
	var from_roof: bool = field.is_roof_footing(merc_pos, merc_floor)
	if roof_land or (from_roof and (cell3.z != merc_floor or field.is_roof_footing(cell2, cell3.z))):
		if _roof_in_way(field, merc_pos, cell2, maxf(merc_elev, cell_elev)):
			return ""
	var why := _walk_reason(from3, cell3, field, merc_size, chebyshev, move_paces)
	if why.is_empty():
		return ""
	return kind if kind != "same" else why


#The landing a pending roof route names, once it still stands; NO_JUMP when the route has gone stale.
#The route already weighed the trip, so the roof guard the nearest enemy sets is not asked here.
static func _routed_landing(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		merc_pos: Vector2i, merc_floor: int, merc_size: int, merc_elev: float,
		jump_stat: int) -> Vector3i:
	var land: Vector3i = state.jump_route(merc)["to"] as Vector3i
	var row := _landing_at(land, field, state, merc, merc_size, merc_floor)
	if row.is_empty() or String(row["why"]) != "roof":
		return NO_JUMP
	var land2 := Vector2i(land.x, land.y)
	var land_elev: float = row["elev"]
	var cheb := maxi(abs(land.x - merc_pos.x), abs(land.y - merc_pos.y))
	if cheb + int(ceil(maxf(0.0, land_elev - merc_elev))) > jump_stat:
		return NO_JUMP
	if not _fall_ok(merc, merc_elev - land_elev, true):
		return NO_JUMP
	var from3 := Vector3i(merc_pos.x, merc_pos.y, merc_floor)
	if PathCost.leap_blocked(field, from3, Vector3i(land.x, land.y, merc_floor)):
		return NO_JUMP
	if _roof_in_way(field, merc_pos, land2, maxf(merc_elev, land_elev)):
		return NO_JUMP
	return land


#The pending roof route's landing for callers outside the action; NO_JUMP for no route or a stale one.
static func routed_landing_for(merc: MercenaryData, state: BattleState) -> Vector3i:
	if merc == null or state == null or state.battlefield == null:
		return NO_JUMP
	if state.jump_route(merc).is_empty():
		return NO_JUMP
	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return NO_JUMP
	var merc_floor := state.get_floor(merc)
	var merc_elev := field.cell_base_elevation(merc_pos, merc_floor) + float(state.get_height(merc))
	return _routed_landing(merc, state, field, merc_pos, merc_floor,
		int(merc.stats.get("size", 1)), merc_elev, int(merc.stats.get("jump", 0)))


func _find_best_jump_target(merc: MercenaryData, ctx: Dictionary) -> Vector3i:
	_jump_why = ""
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return NO_JUMP

	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return NO_JUMP

	var jump_stat := int(merc.stats.get("jump", 0))
	var merc_floor := state.get_floor(merc)
	var merc_size := int(merc.stats.get("size", 1))
	var merc_elev := field.cell_base_elevation(merc_pos, merc_floor) + float(state.get_height(merc))

	#A roof leap the walk stopped at the take-off of runs whatever the nearest enemy is doing.
	if not state.jump_route(merc).is_empty():
		var routed := _routed_landing(merc, state, field, merc_pos, merc_floor, merc_size,
			merc_elev, jump_stat)
		if routed != NO_JUMP:
			_jump_why = "roof"
			return routed
		state.clear_jump_route(merc)

	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return NO_JUMP

	var nearest_enemy: MercenaryData = null
	var nearest_dist := INF
	for enemy: MercenaryData in enemies:
		var epos := state.get_position(enemy)
		var d := float(maxi(abs(merc_pos.x - epos.x), abs(merc_pos.y - epos.y)))
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = enemy
	if nearest_enemy == null:
		return NO_JUMP

	var target_pos := state.get_position(nearest_enemy)
	var current_dist := maxi(abs(merc_pos.x - target_pos.x), abs(merc_pos.y - target_pos.y))

	var from3 := Vector3i(merc_pos.x, merc_pos.y, merc_floor)
	var move_paces := MovementExecutor.pace_per_move(merc)
	#A jumper only reaches the floor below from a run it is already standing on.
	var cand_floors: Array[int] = [merc_floor, merc_floor + 1]
	if field.is_stair_cell(merc_pos, merc_floor):
		cand_floors.append(merc_floor - 1)

	var roof_goal: bool = field.is_roof_footing(merc_pos, merc_floor) \
		or field.is_roof_footing(target_pos, state.get_floor(nearest_enemy))

	var best_cell := NO_JUMP
	var best_dist := current_dist  #the landing must improve on the current position
	var best_why := ""

	for cell_floor: int in cand_floors:
		for dx: int in range(-jump_stat, jump_stat + 1):
			for dy: int in range(-jump_stat, jump_stat + 1):
				var chebyshev := maxi(abs(dx), abs(dy))
				if chebyshev == 0 or chebyshev > jump_stat:
					continue
				var cell := merc_pos + Vector2i(dx, dy)
				var dist := maxi(abs(cell.x - target_pos.x), abs(cell.y - target_pos.y))
				if dist >= best_dist:
					continue
				if PathCost.leap_blocked(field, from3, Vector3i(cell.x, cell.y, merc_floor)):
					continue
				var cell3 := Vector3i(cell.x, cell.y, cell_floor)
				var why := _cell_pick(cell3, merc, state, field, from3, merc_pos, merc_floor,
					merc_size, merc_elev, jump_stat, chebyshev, move_paces, roof_goal)
				if why.is_empty():
					continue
				best_dist = dist
				best_cell = cell3
				best_why = why

	#Roof landings the candidate floors cannot see: the roof level of the column is neither floor.
	for dx2: int in range(-jump_stat, jump_stat + 1):
		for dy2: int in range(-jump_stat, jump_stat + 1):
			var cheb2 := maxi(abs(dx2), abs(dy2))
			if cheb2 == 0 or cheb2 > jump_stat:
				continue
			var cell_r := merc_pos + Vector2i(dx2, dy2)
			var dist_r := maxi(abs(cell_r.x - target_pos.x), abs(cell_r.y - target_pos.y))
			if dist_r >= best_dist:
				continue
			var rl: int = field.roof_level_at(cell_r)
			if rl < 0 or cand_floors.has(rl):
				continue
			if PathCost.leap_blocked(field, from3, Vector3i(cell_r.x, cell_r.y, merc_floor)):
				continue
			var cell3_r := Vector3i(cell_r.x, cell_r.y, rl)
			var why_r := _cell_pick(cell3_r, merc, state, field, from3, merc_pos, merc_floor,
				merc_size, merc_elev, jump_stat, cheb2, move_paces, roof_goal)
			if why_r.is_empty():
				continue
			best_dist = dist_r
			best_cell = cell3_r
			best_why = why_r

	_jump_why = best_why
	return best_cell

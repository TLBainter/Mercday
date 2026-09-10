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
#"elev" is the absolute standing elevation, "why" is "same", "top", "up" or "down".
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
static func _fall_ok(_merc: MercenaryData, drop: float) -> bool:
	return drop < 1.0


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


func _find_best_jump_target(merc: MercenaryData, ctx: Dictionary) -> Vector3i:
	_jump_why = ""
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return NO_JUMP

	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return NO_JUMP

	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return NO_JUMP

	var jump_stat := int(merc.stats.get("jump", 0))
	var merc_floor := state.get_floor(merc)
	var merc_size := int(merc.stats.get("size", 1))
	var merc_elev := field.cell_base_elevation(merc_pos, merc_floor) + float(state.get_height(merc))

	# Find nearest enemy as jump target
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

	var best_cell := NO_JUMP
	var best_dist := current_dist  # must improve on current position
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
				var cell3 := Vector3i(cell.x, cell.y, cell_floor)
				var land := _landing_at(cell3, field, state, merc, merc_size, merc_floor)
				if land.is_empty():
					continue
				var cell_elev: float = land["elev"]
				# Upward height costs jump budget; going down is free
				var height_cost := int(ceil(maxf(0.0, cell_elev - merc_elev)))
				if chebyshev + height_cost > jump_stat:
					continue
				if not _fall_ok(merc, merc_elev - cell_elev):
					continue
				var why := _walk_reason(from3, cell3, field, merc_size, chebyshev, move_paces)
				if why.is_empty():
					continue
				var kind: String = land["why"]
				if kind != "same":
					why = kind
				best_dist = dist
				best_cell = cell3
				best_why = why

	_jump_why = best_why
	return best_cell

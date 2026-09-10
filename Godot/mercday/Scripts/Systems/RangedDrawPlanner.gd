class_name RangedDrawPlanner

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
const NO_CELL := Vector3i(-9999, -9999, -9999)
#Upper bound on cells tested for line of sight in one plan.
const MAX_CELLS := 240

static var _cache: Dictionary = {}
static var _logged: Dictionary = {}
static var _cache_round: int = -1
static var _depth: int = 0


static func none_plan() -> Dictionary:
	return {"mode": "none", "cell": NO_CELL, "target": null, "paces": 0, "moves": 0,
		"ap": 0, "turns": 0, "draw_ap": 0, "attack_ap": 0, "shoots": false}


static func _now_plan(cell: Vector3i, target: MercenaryData, attack_ap: int) -> Dictionary:
	return {"mode": "now", "cell": cell, "target": target, "paces": 0, "moves": 0,
		"ap": attack_ap, "turns": 1, "draw_ap": 0, "attack_ap": attack_ap, "shoots": true}


#A plan for taking a ranged weapon into hand: shoot now, walk to a firing cell, or wait a turn.
static func plan(
		merc: MercenaryData,
		weapon: WeaponData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		from_cell: Vector3i = NO_CELL) -> Dictionary:
	if merc == null or weapon == null or not weapon.is_ranged or state == null:
		return none_plan()
	#A nested call runs inside a cost query; answering "now" keeps that query at today's values.
	if _depth > 0:
		return _now_plan(state.pos3(merc), null, 0)
	if state.round_number != _cache_round:
		_cache.clear()
		_logged.clear()
		_cache_round = state.round_number
	var key := _key(merc, weapon, state, from_cell)
	if _cache.has(key):
		return _cache[key] as Dictionary
	_depth += 1
	var result := _compute(merc, weapon, enemies, state, attack_base_cost, from_cell)
	_depth -= 1
	_cache[key] = result
	_log_plan(merc, weapon, result)
	if from_cell == NO_CELL:
		_store(merc, weapon, state, result)
	return result


static func _key(merc: MercenaryData, weapon: WeaponData, state: BattleState, from_cell: Vector3i) -> String:
	var p := state.pos3(merc)
	return "%d|%d|%d|%d,%d,%d|%d,%d,%d" % [
		merc.get_instance_id(), weapon.get_instance_id(), state.round_number,
		p.x, p.y, p.z, from_cell.x, from_cell.y, from_cell.z]


static func _compute(
		merc: MercenaryData,
		weapon: WeaponData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		from_cell: Vector3i) -> Dictionary:
	if enemies.is_empty():
		return none_plan()
	if not WeaponEvaluator.is_ranged_usable(merc, weapon):
		return none_plan()
	var start := state.pos3(merc) if from_cell == NO_CELL else from_cell
	var attack_ap := state.get_cost(merc, "Attack", attack_base_cost)
	if state.battlefield == null:
		return _now_plan(start, enemies[0] as MercenaryData, attack_ap)
	var flying := PathTargeter.is_flying(merc)
	var height := state.get_height(merc) if flying else 0
	var size := maxi(1, int(merc.stats.get("size", 1)))
	var now_enemy := _visible_enemy_from(state, start, height, size, weapon, enemies)
	if now_enemy != null:
		return _now_plan(start, now_enemy, attack_ap)

	var reach := PathTargeter.reachable_for(merc, state)
	if reach.is_empty():
		return none_plan()
	var tp := MovementExecutor.turn_paces(merc, state, 0)
	var t1 := int(tp["paces"])
	var ppm := maxi(1, MovementExecutor.pace_per_move(merc))
	var horizon := t1 + ppm
	var base_cost := 0
	if from_cell != NO_CELL and reach.has(from_cell):
		var fc := int(reach[from_cell])
		if fc < PathTargeter.JUMP_COST_OFFSET:
			base_cost = fc
	var cells: Array[Vector3i] = []
	for cell: Vector3i in reach:
		var c := int(reach[cell])
		if c <= 0 or c >= PathTargeter.JUMP_COST_OFFSET:
			continue
		if maxi(c, base_cost) > horizon:
			continue
		if state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
			continue
		cells.append(cell)
	if cells.is_empty():
		return none_plan()
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return int(reach[a]) < int(reach[b]))
	if cells.size() > MAX_CELLS:
		cells.resize(MAX_CELLS)

	var best_cell := NO_CELL
	var best_cost := 0
	var best_gap := 999999
	var best_enemy: MercenaryData = null
	for cell: Vector3i in cells:
		var c := maxi(int(reach[cell]), base_cost)
		if best_enemy != null and c > best_cost:
			break
		var seen := _visible_enemy_from(state, cell, height, size, weapon, enemies)
		if seen == null:
			continue
		var gap := _cell_distance(state, cell, height, seen)
		if best_enemy == null or gap < best_gap:
			best_cell = cell
			best_cost = c
			best_gap = gap
			best_enemy = seen
	if best_enemy == null:
		return none_plan()

	var pool := state.get_pace_pool(merc)
	var moves := 0
	if best_cost > pool:
		moves = int(ceil(float(best_cost - pool) / float(ppm)))
	var draw_ap := WeaponActionExecutor.get_swap_cost(merc, weapon, state)
	if draw_ap < 0:
		return none_plan()
	var ap := merc.current_ap + merc.excess_ap
	var mode := "move_twice_then_draw"
	var turns := 2
	var shoots := false
	if best_cost <= t1:
		moves = mini(moves, int(tp["moves"]))
	var move_ap := 0
	for i: int in range(moves):
		move_ap += state.get_cost_after(merc, "Move Close", _CONFIG.move_base_ap, i)
	if best_cost <= t1:
		if move_ap + draw_ap + attack_ap <= ap:
			mode = "move_then_draw"
			turns = 1
			shoots = true
		elif move_ap + draw_ap <= ap:
			mode = "move_then_draw"
			turns = 1
		elif move_ap <= ap:
			mode = "move_then_draw_next_turn"
			turns = 2
	var plan_ap := move_ap + draw_ap
	if shoots:
		plan_ap += attack_ap
	return {"mode": mode, "cell": best_cell, "target": best_enemy, "paces": best_cost,
		"moves": moves, "ap": plan_ap, "turns": turns, "draw_ap": draw_ap,
		"attack_ap": attack_ap, "shoots": shoots}


static func _visible_enemy_from(
		state: BattleState,
		cell: Vector3i,
		height: int,
		size: int,
		weapon: WeaponData,
		enemies: Array) -> MercenaryData:
	for enemy: MercenaryData in enemies:
		if enemy == null or enemy.is_dead or enemy.current_hp <= 0:
			continue
		var d := _cell_distance(state, cell, height, enemy)
		if weapon.ranged_extended_range > 0 and d > weapon.ranged_extended_range:
			continue
		if not (LineOfSight.check_from(state, cell, height, size, enemy)["visible"] as bool):
			continue
		return enemy
	return null


#3D Chebyshev distance from a hypothetical stance to a merc, matching BattleState.distance_to.
static func _cell_distance(state: BattleState, cell: Vector3i, height: int, target: MercenaryData) -> int:
	var field := state.battlefield
	if field == null:
		return 0
	var tp := state.get_position(target)
	var ea := field.cell_base_elevation(Vector2i(cell.x, cell.y), cell.z) + float(height)
	var eb := field.cell_base_elevation(tp, state.get_floor(target)) + float(state.get_height(target))
	var dz := int(round(absf(ea - eb)))
	return maxi(maxi(abs(cell.x - tp.x), abs(cell.y - tp.y)), dz)


static func _log_plan(merc: MercenaryData, weapon: WeaponData, result: Dictionary) -> void:
	if not EncounterLogger.is_active():
		return
	var mode := str(result.get("mode", "none"))
	var key := "%d|%d" % [merc.get_instance_id(), weapon.get_instance_id()]
	if str(_logged.get(key, "")) == mode:
		return
	_logged[key] = mode
	var cell: Vector3i = result.get("cell", NO_CELL)
	var target: MercenaryData = result.get("target")
	EncounterLogger.log_verbose("DRAW PLAN: %s %s mode=%s cell=(%d,%d,F%d) cost=%d moves=%d ap=%d turns=%d target=%s" % [
		merc.merc_name, weapon.item_name, mode, cell.x, cell.y, cell.z,
		int(result.get("paces", 0)), int(result.get("moves", 0)), int(result.get("ap", 0)),
		int(result.get("turns", 0)), target.merc_name if target != null else "none"])
	if mode == "move_then_draw" and not bool(result.get("shoots", false)):
		EncounterLogger.log_verbose("DRAW PLAN NOSHOT: %s %s holds fire until next turn" % [
			merc.merc_name, weapon.item_name])


static func _store(merc: MercenaryData, weapon: WeaponData, state: BattleState, result: Dictionary) -> void:
	if str(result.get("mode", "none")) == "none":
		var held: Dictionary = merc.active_states.get("ranged_plan", {}) as Dictionary
		if held.get("weapon") == weapon:
			merc.active_states.erase("ranged_plan")
		return
	merc.active_states["ranged_plan"] = {
		"weapon": weapon,
		"cell": result.get("cell", NO_CELL),
		"round": state.round_number,
		"mode": str(result.get("mode", "none")),
		"target": result.get("target"),
	}


static func clear_plan(merc: MercenaryData) -> void:
	merc.active_states.erase("ranged_plan")


#The stored plan, or an empty dictionary once it ages out or the weapon leaves the merc.
static func stored_plan(merc: MercenaryData, state: BattleState) -> Dictionary:
	var held: Dictionary = merc.active_states.get("ranged_plan", {}) as Dictionary
	if held.is_empty():
		return {}
	var weapon: WeaponData = held.get("weapon")
	if weapon == null:
		merc.active_states.erase("ranged_plan")
		return {}
	if state != null and state.round_number - int(held.get("round", 0)) > 2:
		merc.active_states.erase("ranged_plan")
		return {}
	if not WeaponEvaluator.get_available_weapons(merc).has(weapon):
		merc.active_states.erase("ranged_plan")
		return {}
	return held

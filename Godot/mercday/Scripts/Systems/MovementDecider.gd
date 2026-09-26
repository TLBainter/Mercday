class_name MovementDecider

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")
const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


#Moves a walk may buy this turn and the AP it holds back for an Attack the walk could set up.
static func plan_moves(mover: MercenaryData, enemies: Array, state: BattleState) -> Dictionary:
	var reach := _get_weapon_melee_range(mover)
	var free: Dictionary = MovementExecutor.turn_paces(mover, state, 0)
	var reserve := 0
	if not enemies.is_empty() and _min_enemy_distance(mover, enemies, state) <= int(free["paces"]) + reach:
		reserve = state.get_cost(mover, "Attack", _CONFIG.attack_base_ap)
	var plan: Dictionary = MovementExecutor.turn_paces(mover, state, reserve)
	if int(plan["paces"]) <= 0:
		plan = free
		reserve = 0
	var moves_allowed := int(plan["moves"])
	if int(plan["pool"]) <= 0:
		moves_allowed = maxi(1, moves_allowed)
	return {"paces": int(plan["paces"]), "pool": int(plan["pool"]), "moves_allowed": moves_allowed, "reserve_ap": reserve}


#Cheapest reachable cell within pace from which the target can be seen.
static func find_flanking_cell(mover: MercenaryData, target: MercenaryData, state: BattleState) -> Vector2i:
	if state.battlefield == null:
		return Vector2i(-1, -1)
	var pace: int = maxi(1, int(MovementExecutor.turn_paces(mover, state,
		state.get_cost(mover, "Attack", _CONFIG.attack_base_ap))["paces"]))
	var mover_size: int = maxi(1, int(mover.stats.get("size", 1)))
	var reach: Dictionary = PathTargeter.reachable_for(mover, state)
	var mover_floor := state.get_floor(mover)
	var best := Vector2i(-1, -1)
	var best_cost := 0
	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		if cost <= 0 or cost > pace or cell.z != mover_floor:
			continue
		if best != Vector2i(-1, -1) and cost >= best_cost:
			continue
		if state.is_position_occupied(Vector2i(cell.x, cell.y), mover, cell.z):
			continue
		if not (LineOfSight.check_from(state, cell, 0, mover_size, target)["visible"] as bool):
			continue
		best = Vector2i(cell.x, cell.y)
		best_cost = cost
	return best



static func is_in_danger(merc: MercenaryData) -> bool:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) <= _WEIGHTS.danger_hp_ratio


static func _get_weapon_melee_range(merc: MercenaryData) -> int:
	var weapon := merc.equipped_weapon
	if weapon != null and not weapon.is_ranged:
		return weapon.melee_range
	return 1


#Nearest enemy of enemies, or null when enemies is empty.
static func closest_enemy(
		mover: MercenaryData,
		enemies: Array,
		state: BattleState) -> MercenaryData:
	if enemies.is_empty():
		return null
	var best: MercenaryData = nearest_enemy(mover, enemies, state)["merc"] as MercenaryData
	return best if best != null else enemies[0]


static func _min_enemy_distance(mover: MercenaryData, enemies: Array, state: BattleState) -> int:
	return int(nearest_enemy(mover, enemies, state)["dist"])


#Closest enemy by grid distance and that distance: {"merc", "dist"}; max_dist below 0 means no cap.
static func nearest_enemy(mover: MercenaryData, enemies: Array, state: BattleState,
		max_dist: int = -1) -> Dictionary:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if max_dist >= 0 and d > max_dist:
			continue
		if d < best_dist:
			best_dist = d
			best = enemy
	return {"merc": best, "dist": best_dist}

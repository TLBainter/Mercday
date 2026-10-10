class_name PathTargeter

const JUMP_COST_OFFSET := ReachSearch.JUMP_COST_OFFSET
const NO_CELL := Vector3i(-1, -1, -1)

const MOVE_CLOSE_WEIGHTS: Dictionary = {
	"path_cost":           -1.0,
	"cover_at_dest":        2.0,
	"flanked_on_arrival":  -1.5,
	"route_hazard":         -1.0,
	"height_bonus":          0.5,
	"goal_persistence":      1.0,
	"jump_penalty":         -2.0,
	"ally_goal_conflict":   -1.5,
	"angle_diversity":       1.2,
	"corridor_crowded":     -0.8,
	"pace_block":           -1.2,
	"leader_aura":           1.0,
}

const MOVE_FAR_WEIGHTS: Dictionary = {
	"enemy_distance":      1.0,
	"cover_count":         1.5,
	"edge_penalty":        -2.0,
	"los_bonus":           1.5,
	"height_bonus":         0.5,
	"last_from_penalty":   -2.0,
	"goal_persistence":     1.5,
	"flanked_on_arrival":  -1.5,
}


#Single source of truth for whether a merc moves as a flyer this turn.
static func is_flying(merc: MercenaryData) -> bool:
	return int(merc.stats.get("fly", 0)) > 0 and not StateEffects.is_blocked(merc, "ability:fly")


#Fall risk this mover accepts: hp share plus the better of parkour and tolerance, clamped.
static func fall_tolerance(merc: MercenaryData) -> float:
	var hp_ratio := clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
	var break_fall := maxf(
		clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
		clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
	return clampf(hp_ratio + break_fall, 0.2, 2.0)


#Cost-ordered flood from `from`; returns Dictionary[Vector3i -> int] (node -> minimal cost).
#Nodes reachable only via jump have cost >= JUMP_COST_OFFSET.
#max_walk_cost < 0 floods the whole component; otherwise walk cells stop at that cost.
static func reachable_from(
		from: Vector3i,
		field: BattlefieldArea,
		passable: Dictionary,
		tolerance: float,
		flying: bool,
		can_climb: bool,
		jump_range: int = 0,
		merc_size: int = 1,
		altitude: int = 0,
		max_walk_cost: int = -1) -> Dictionary:
	var search := ReachSearch.create(
		from, field, passable, tolerance, flying, can_climb, jump_range, merc_size, altitude)
	if max_walk_cost < 0:
		search.ensure_all()
	else:
		search.ensure_cost(max_walk_cost)
	return search.result


#All valid standable nodes at exactly `stop_dist` Chebyshev distance from `target_pos`, on its floor.
#A candidate the mover cannot stand on is not an approach cell, so obstacles that are not
#passthrough, vault-only cells and cells another merc occupies are dropped here.
static func approach_candidates(
		target_pos: Vector3i,
		stop_dist: int,
		field: BattlefieldArea,
		flying: bool,
		state: BattleState = null,
		merc: MercenaryData = null,
		merc_size: int = 1,
		target: MercenaryData = null,
		mover_alt: int = 0,
		melee: bool = false) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var d := maxi(1, stop_dist)
	var ring := 0
	var dropped := 0
	for x: int in range(target_pos.x - d, target_pos.x + d + 1):
		for y: int in range(target_pos.y - d, target_pos.y + d + 1):
			if maxi(absi(x - target_pos.x), absi(y - target_pos.y)) != d:
				continue
			var cell := Vector3i(x, y, target_pos.z)
			if not field.in_bounds_xy(cell.x, cell.y):
				continue
			var cell2d := Vector2i(x, y)
			if field.jagged_cells.has(cell2d):
				continue
			if not flying and field.fly_only_cells.has(cell2d):
				continue
			if PathCost.is_landing_alias(cell, field):
				continue
			if not field.has_walkable_surface(cell2d, cell.z):
				continue
			if not PathHelper.is_standable(cell, field, merc_size):
				continue
			if state != null and state.is_position_occupied(cell2d, merc, cell.z):
				continue
			ring += 1
			if target != null and state != null:
				#Melee reach counts elevation the way BattleState.distance_to does.
				if melee:
					var ce := field.cell_base_elevation(cell2d, cell.z) + float(mover_alt)
					var te := field.cell_base_elevation(state.get_position(target), state.get_floor(target)) \
						+ float(state.get_height(target))
					if int(round(absf(ce - te))) > d:
						dropped += 1
						continue
				if not (LineOfSight.check_from(state, cell, mover_alt, merc_size, target)["visible"] as bool):
					dropped += 1
					continue
			result.append(cell)
	if ring > 0 and dropped == ring and merc != null and target != null and EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE RING: %s no cell at d=%d near %s sees it (ring=%d)" % [
			merc.merc_name, d, target.merc_name, ring])
	return result


#True if standing at `cell` would put the merc flanked given the provided known enemy positions.
static func is_flanked_by_known(cell: Vector3i, known: Dictionary) -> bool:
	var has_n := false
	var has_s := false
	var has_e := false
	var has_w := false
	for enemy: MercenaryData in known.keys():
		var ep: Vector3i = known[enemy] as Vector3i
		if ep.z != cell.z:
			continue
		var dx := ep.x - cell.x
		var dy := ep.y - cell.y
		if absi(dx) > 1 or absi(dy) > 1:
			continue
		if dy < 0:
			has_n = true
		if dy > 0:
			has_s = true
		if dx < 0:
			has_w = true
		if dx > 0:
			has_e = true
	return (has_n and has_s) or (has_e and has_w)


#Cells between two known enemies; a route may end on one but never passes through one unless the mover starts flanked.
static func flanked_cells(from: Vector3i, goal: Vector3i, field: BattlefieldArea, known: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if is_flanked_by_known(from, known):
		return out
	for enemy: MercenaryData in known.keys():
		var ep: Vector3i = known[enemy] as Vector3i
		for d: Vector2i in PathCost.DIRS8:
			var c := Vector3i(ep.x + d.x, ep.y + d.y, ep.z)
			if c == from or c == goal or out.has(c):
				continue
			if not field.in_bounds_xy(c.x, c.y):
				continue
			if is_flanked_by_known(c, known):
				out[c] = true
	return out


#Multi-factor candidate scoring. `weights` selects which factors apply and at what magnitude.
#`reachable` is the output of reachable_from() (node -> cumulative BFS cost).
#`known_enemies` is a snapshot of MercenaryData -> Vector3i (last known positions).
static func score_candidate(
		candidate: Vector3i,
		from: Vector3i,
		merc: MercenaryData,
		state: BattleState,
		reachable: Dictionary,
		known_enemies: Dictionary,
		weights: Dictionary) -> float:
	var field := state.battlefield
	var score := 0.0
	var cand2d := Vector2i(candidate.x, candidate.y)

	if weights.has("path_cost") and reachable.has(candidate):
		var raw_cost: int = reachable[candidate] as int
		var walk_cost: int = raw_cost if raw_cost < JUMP_COST_OFFSET else raw_cost - JUMP_COST_OFFSET
		score += float(weights["path_cost"]) * float(walk_cost)

	if weights.has("jump_penalty") and reachable.has(candidate):
		if (reachable[candidate] as int) >= JUMP_COST_OFFSET:
			score += float(weights["jump_penalty"])

	if weights.has("cover_at_dest") and field != null and not known_enemies.is_empty():
		var cover_size: int = merc.unit_size()
		for enemy: MercenaryData in known_enemies.keys():
			if enemy.equipped_weapon == null or not enemy.equipped_weapon.is_ranged:
				continue
			if state.is_covered_from_pos(enemy, candidate, cover_size):
				score += float(weights["cover_at_dest"])
				break

	if weights.has("flanked_on_arrival") and not known_enemies.is_empty():
		if is_flanked_by_known(candidate, known_enemies):
			score += float(weights["flanked_on_arrival"])

	if weights.has("route_hazard") and not known_enemies.is_empty():
		var hazard := 0
		for enemy: MercenaryData in known_enemies.keys():
			var ep: Vector3i = known_enemies[enemy] as Vector3i
			if ep.z != candidate.z:
				continue
			var from_dist := maxi(absi(ep.x - from.x), absi(ep.y - from.y))
			var cand_dist := maxi(absi(ep.x - candidate.x), absi(ep.y - candidate.y))
			if from_dist <= 1 and cand_dist > 1:
				hazard += 1
		score += float(weights["route_hazard"]) * float(hazard)

	if weights.has("height_bonus") and field != null:
		var from_h := field.cell_base_elevation(Vector2i(from.x, from.y), from.z)
		var cand_h := field.cell_base_elevation(cand2d, candidate.z)
		score += float(weights["height_bonus"]) * clampf((cand_h - from_h) * 0.5, 0.0, 1.0)

	if weights.has("enemy_distance") and not known_enemies.is_empty():
		var nearest_dist := INF
		for enemy: MercenaryData in known_enemies.keys():
			var ep: Vector3i = known_enemies[enemy] as Vector3i
			var d := float(maxi(absi(ep.x - candidate.x), absi(ep.y - candidate.y)) + absi(ep.z - candidate.z) * 4)
			if d < nearest_dist:
				nearest_dist = d
		if nearest_dist < INF:
			score += float(weights["enemy_distance"]) * nearest_dist

	if weights.has("cover_count") and field != null:
		var count := 0.0
		for obs: Dictionary in field.obstacles:
			if obs.get("cell_type", "") == "door" and OpenCloseState.is_open(obs):
				continue
			var od: ObstacleData = obs.get("data") as ObstacleData
			if od != null and not od.covers:
				continue
			if not obs.has("pos"):
				continue
			var raw_op2 = obs["pos"]
			var op: Vector2i = Vector2i((raw_op2 as Vector3i).x, (raw_op2 as Vector3i).y) if typeof(raw_op2) == TYPE_VECTOR3I else raw_op2 as Vector2i
			if maxi(absi(op.x - candidate.x), absi(op.y - candidate.y)) <= 2:
				count += 1.0
		score += float(weights["cover_count"]) * count

	if weights.has("edge_penalty") and field != null:
		if candidate.x < 3 or candidate.x >= field.width - 3 \
				or candidate.y < 3 or candidate.y >= field.length - 3:
			score += float(weights["edge_penalty"])

	if weights.has("los_bonus") and field != null \
			and merc.equipped_weapon != null and merc.equipped_weapon.is_ranged \
			and not known_enemies.is_empty():
		var los_size: int = merc.unit_size()
		for enemy: MercenaryData in known_enemies.keys():
			if not state.is_covered_from_pos(enemy, candidate, los_size):
				score += float(weights["los_bonus"])
				break

	if weights.has("last_from_penalty"):
		var esc: Dictionary = state.escalation.get(merc, {}) as Dictionary
		var last_from: Vector3i = esc.get("last_move_from", NO_CELL) as Vector3i
		if last_from != NO_CELL and candidate == last_from:
			score += float(weights["last_from_penalty"])

	if weights.has("goal_persistence"):
		var stored: Vector3i = state.move_goals.get(merc, NO_CELL) as Vector3i
		if stored != NO_CELL and candidate == stored:
			score += float(weights["goal_persistence"])

	return score


#Ally-aware scoring factors for Move Close candidates.
#Handles goal conflict, corridor crowding, pace blocking, and angle diversity.
static func _ally_score(
		candidate: Vector3i,
		from: Vector3i,
		merc: MercenaryData,
		target: MercenaryData,
		state: BattleState,
		weights: Dictionary) -> float:
	var score := 0.0
	var target_pos := state.pos3(target)

	for ally: MercenaryData in state.get_allies(merc):
		var ally_goal: Vector3i = state.move_goals.get(ally, NO_CELL) as Vector3i

		if weights.has("ally_goal_conflict") and ally_goal == candidate:
			score += float(weights["ally_goal_conflict"])

		if weights.has("leader_aura"):
			var reach: int = AuraTactics.aura_reach(ally)
			if reach > 0:
				var aura_pos: Vector3i = state.pos3(ally)
				if aura_pos.z == candidate.z \
						and maxi(absi(candidate.x - aura_pos.x), absi(candidate.y - aura_pos.y)) <= reach:
					score += float(weights["leader_aura"])

		var ally_target: MercenaryData = state.move_targets.get(ally) as MercenaryData
		if ally_target == null or ally_target != target:
			continue

		if weights.has("angle_diversity") and ally_goal != NO_CELL:
			var cand_dx := float(candidate.x - target_pos.x)
			var cand_dy := float(candidate.y - target_pos.y)
			var ally_dx := float(ally_goal.x - target_pos.x)
			var ally_dy := float(ally_goal.y - target_pos.y)
			var cand_len := maxf(0.001, sqrt(cand_dx * cand_dx + cand_dy * cand_dy))
			var ally_len := maxf(0.001, sqrt(ally_dx * ally_dx + ally_dy * ally_dy))
			var cos_angle := (cand_dx * ally_dx + cand_dy * ally_dy) / (cand_len * ally_len)
			if cos_angle < 0.0:
				score += float(weights["angle_diversity"])

		if weights.has("corridor_crowded"):
			var ally_pos: Vector3i = state.pos3(ally)
			var to_cand_dist := maxi(absi(candidate.x - from.x), absi(candidate.y - from.y))
			var to_ally_dist := maxi(absi(ally_pos.x - from.x), absi(ally_pos.y - from.y))
			if to_ally_dist > 0 and to_ally_dist < to_cand_dist:
				var dir_cx := float(candidate.x - from.x)
				var dir_cy := float(candidate.y - from.y)
				var dir_ax := float(ally_pos.x - from.x)
				var dir_ay := float(ally_pos.y - from.y)
				var clen := maxf(0.001, sqrt(dir_cx * dir_cx + dir_cy * dir_cy))
				var alen := maxf(0.001, sqrt(dir_ax * dir_ax + dir_ay * dir_ay))
				var dot := (dir_cx * dir_ax + dir_cy * dir_ay) / (clen * alen)
				if dot >= 0.7:
					score += float(weights["corridor_crowded"])
					if weights.has("pace_block"):
						var merc_pace := int(merc.stats.get("pace", 1))
						var ally_pace := int(ally.stats.get("pace", 1))
						if ally_pace <= merc_pace:
							score += float(weights["pace_block"])

	return score


#Returns the best node to approach `target` from, or NO_CELL if none reachable.
static func best_approach_cell(
		merc: MercenaryData,
		target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1) -> Vector3i:
	var field := state.battlefield
	if field == null:
		return state.pos3(merc)

	var from := state.pos3(merc)
	var target_pos := state.pos3(target)

	if from == target_pos:
		return from

	var flying := is_flying(merc)
	var can_climb := true
	var tolerance := fall_tolerance(merc)
	var ally_passable := state.ally_passable_3d(merc)
	var merc_size := int(merc.stats.get("size", 1))
	var altitude := state.get_height(merc)
	var reachable := ReachCache.reachable_for(merc, state)

	var stop_dist: int
	if stop_dist_override >= 0:
		stop_dist = stop_dist_override
	elif state.get_allies(merc).has(target):
		stop_dist = 0
	else:
		var weapon := merc.equipped_weapon
		stop_dist = (weapon.melee_range if weapon != null and not weapon.is_ranged else 1)

	if flank_ally != null:
		var ally_pos := state.pos3(flank_ally)
		var flank_step := Vector2i(signi(target_pos.x - ally_pos.x), signi(target_pos.y - ally_pos.y))
		if flank_step != Vector2i.ZERO:
			var mult := maxi(1, stop_dist)
			target_pos = Vector3i(target_pos.x + flank_step.x * mult, target_pos.y + flank_step.y * mult, target_pos.z)

	if stop_dist == 0:
		if not state.is_position_occupied(Vector2i(target_pos.x, target_pos.y), merc, target_pos.z):
			return target_pos
		reachable = ReachCache.reachable_around_for(merc, state, target_pos)
		return PathHelper.nearest_passable_to(target_pos, field,
			{"fall_tolerance": tolerance, "can_climb": can_climb, "merc_size": merc_size,
			"flying": flying, "altitude": altitude, "state": state, "merc": merc},
			{}, reachable, from, JUMP_COST_OFFSET - 1)

	var known_enemies: Dictionary = merc.last_known_enemy_positions.duplicate()

	#Only a melee approach measures the ring in elevation; a ranged mover is filtered by sight alone.
	var melee := false
	if stop_dist_override < 0 and not state.get_allies(merc).has(target):
		var mw := merc.equipped_weapon
		melee = mw != null and not mw.is_ranged
	var candidates := approach_candidates(target_pos, stop_dist, field, flying, state, merc, merc_size,
		target, altitude, melee)
	#No ring cell sees the target: close in one ring at a time, then take the plain ring rather than stand still.
	if candidates.is_empty() and target != null:
		var ring_d := maxi(1, stop_dist) - 1
		while candidates.is_empty() and ring_d >= 1:
			candidates = approach_candidates(target_pos, ring_d, field, flying, state, merc, merc_size,
				target, altitude, melee)
			ring_d -= 1
		var fallback := "closer"
		#A wider ring that sees the target comes before a plain ring that leaves the mover standing blind.
		var see_d := maxi(1, stop_dist) + 1
		while candidates.is_empty() and see_d <= stop_dist + 2:
			candidates = approach_candidates(target_pos, see_d, field, flying, state, merc, merc_size,
				target, altitude, melee)
			fallback = "wider"
			see_d += 1
		if candidates.is_empty():
			fallback = "plain"
			candidates = approach_candidates(target_pos, stop_dist, field, flying, state, merc, merc_size)
		if not candidates.is_empty() and EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE RING FALLBACK: %s near %s %s cands=%d" % [
				merc.merc_name, target.merc_name, fallback, candidates.size()])

	var reachable_candidates: Array[Vector3i] = []
	for c: Vector3i in candidates:
		if reachable.has(c):
			reachable_candidates.append(c)
	#The whole ring may sit beyond the default bound: grow the flood to it, then to wider rings so a merc
	#boxed out by an occupied cell still moves nearer. The capped growth runs first, the full one after it.
	if reachable_candidates.is_empty() and target != null:
		var cap: int = -1 if state.far_full.has(merc) else ReachCache.far_cap_for(merc, state)
		for _attempt: int in range(2):
			reachable = ReachCache.reachable_far_for(merc, state, candidates, ReachCache.RING_SLACK, cap)
			for fc: Vector3i in candidates:
				if reachable.has(fc):
					reachable_candidates.append(fc)
			var wide_d := stop_dist + 1
			while reachable_candidates.is_empty() and wide_d <= stop_dist + 3:
				var wide := approach_candidates(target_pos, wide_d, field, flying, state, merc, merc_size)
				reachable = ReachCache.reachable_far_for(merc, state, wide, ReachCache.RING_SLACK, cap)
				for wc: Vector3i in wide:
					if reachable.has(wc):
						reachable_candidates.append(wc)
				if not reachable_candidates.is_empty() and EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE RING WIDER: %s near %s d=%d cands=%d" % [
						merc.merc_name, target.merc_name, wide_d, reachable_candidates.size()])
				wide_d += 1
			if not reachable_candidates.is_empty() or cap < 0 or not ReachCache.far_capped(merc, state):
				break
			var here := ReachCache.far_box_distance(merc, state, from, candidates)
			var frontier := ReachCache.far_frontier_for(merc, state, candidates)
			var gap := ReachCache.far_box_distance(merc, state, frontier, candidates) if frontier != NO_CELL else here
			if frontier != NO_CELL and gap < here:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE FAR CAP: %s near %s settled=%d toward (%d,%d) F%d dist=%d" % [
						merc.merc_name, target.merc_name, reachable.size(), frontier.x, frontier.y,
						frontier.z, gap])
				return _set_goal(merc, target, frontier, state)
			state.far_full[merc] = true
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE FAR FULL: %s near %s settled=%d" % [
					merc.merc_name, target.merc_name, reachable.size()])
			cap = -1

	if reachable_candidates.is_empty():
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE NO CELL: %s near %s cands=%d reach=%d door_pen=%d" % [
				merc.merc_name, target.merc_name, candidates.size(), reachable.size(), PathCost.door_pace_penalty])
		_note_blocked(state, target)
		return NO_CELL

	var weights := MOVE_CLOSE_WEIGHTS

	var scored: Array = []
	for c: Vector3i in reachable_candidates:
		var s := score_candidate(c, from, merc, state, reachable, known_enemies, weights)
		s += _ally_score(c, from, merc, target, state, weights)
		scored.append([s, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as float) > (b[0] as float))

	#A walk-settled candidate has an exact path and a jump-only one never does; a partial path comes last.
	for entry: Array in scored:
		var c: Vector3i = entry[1] as Vector3i
		if (reachable[c] as int) < JUMP_COST_OFFSET:
			return _set_goal(merc, target, c, state)

	for entry: Array in scored:
		var c: Vector3i = entry[1] as Vector3i
		var partial := PathHelper.find_path_toward(from, c, field, ally_passable, tolerance, flying, can_climb, 0, merc_size, altitude)
		if not partial.is_empty():
			if EncounterLogger.is_active():
				var pe: Vector3i = partial[partial.size() - 1]
				EncounterLogger.log_verbose("MOVE PARTIAL GOAL: %s no exact path to %d cells near %s; toward (%d,%d) F%d ends (%d,%d) F%d" % [
					merc.merc_name, scored.size(), target.merc_name, c.x, c.y, c.z, pe.x, pe.y, pe.z])
			return _set_goal(merc, target, c, state)

	_note_blocked(state, target)
	return NO_CELL


#Records c as the merc's move goal toward target and returns it.
static func _set_goal(merc: MercenaryData, target: MercenaryData, c: Vector3i, state: BattleState) -> Vector3i:
	state.move_goals[merc] = c
	state.move_targets[merc] = target
	return c


static func _note_blocked(state: BattleState, target: MercenaryData) -> void:
	var tbr: int = state.team_blocked_round.get(target, -1) as int
	if tbr == state.round_number:
		state.team_blocked_count[target] = (state.team_blocked_count.get(target, 0) as int) + 1
	else:
		state.team_blocked_round[target] = state.round_number
		state.team_blocked_count[target] = 1


#Returns the best retreat node for a Move Far action.
static func best_retreat_cell(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		move_target: MercenaryData = null) -> Vector3i:
	var field := state.battlefield
	if field == null:
		return state.pos3(merc)

	var from := state.pos3(merc)
	var pace := maxi(1, int(PaceBudget.turn_paces(merc, state, 0)["paces"]))

	var _pre_goal: Vector3i = state.move_goals.get(merc, NO_CELL) as Vector3i
	if _pre_goal != NO_CELL:
		var pg2d := Vector2i(_pre_goal.x, _pre_goal.y)
		if state.is_position_occupied(pg2d, merc, _pre_goal.z) or field.is_obstacle(pg2d, _pre_goal.z):
			state.move_goals.erase(merc)

	var known_enemies: Dictionary = merc.last_known_enemy_positions.duplicate()

	var step := Vector2i.ZERO
	if move_target != null:
		var to := state.get_position(move_target)
		step = Vector2i(signi(to.x - from.x), signi(to.y - from.y))

	var retreat_dirs: Array[Vector2i] = [
		Vector2i(-step.x, -step.y),
		Vector2i(-step.x, 0), Vector2i(0, -step.y),
		Vector2i(-step.x, step.y), Vector2i(step.x, -step.y),
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
	]
	var seen: Dictionary = {}
	var candidates: Array[Vector3i] = []
	var allies := state.get_allies(merc)
	for rd: Vector2i in retreat_dirs:
		if rd == Vector2i.ZERO:
			continue
		for mult: int in [pace, pace >> 1]:
			if mult <= 0:
				continue
			var c2 := field.clamp_position(Vector2i(from.x, from.y) + rd * mult)
			var c := Vector3i(c2.x, c2.y, from.z)
			if c == from or seen.has(c):
				continue
			if not allies.is_empty():
				var near_ally := false
				for ally: MercenaryData in allies:
					var apos := state.get_position(ally)
					if maxi(absi(c.x - apos.x), absi(c.y - apos.y)) <= 20:
						near_ally = true
						break
				if not near_ally:
					continue
			seen[c] = true
			candidates.append(c)

	var reachable := ReachCache.reachable_for(merc, state)
	#Only cells the walk can fund this turn while holding back the Attack the retreat sets up.
	var budget := int(MovementDecider.plan_moves(merc, enemies, state)["paces"])

	var reachable_candidates: Array[Vector3i] = []
	for c: Vector3i in candidates:
		if reachable.has(c) and int(reachable[c]) <= budget:
			reachable_candidates.append(c)
	#A shooter retreats to a cell that still sees an enemy whenever one is in reach.
	if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged and not known_enemies.is_empty():
		var los_size := merc.unit_size()
		var seeing: Array[Vector3i] = []
		for c: Vector3i in reachable_candidates:
			for enemy: MercenaryData in known_enemies.keys():
				if LineOfSight.check_from(state, c, 0, los_size, enemy)["visible"] as bool:
					seeing.append(c)
					break
		if not seeing.is_empty():
			reachable_candidates = seeing

	if reachable_candidates.is_empty():
		if not candidates.is_empty():
			return candidates[0]
		var fb := field.clamp_position(Vector2i(from.x, from.y) - step * pace)
		return Vector3i(fb.x, fb.y, from.z)

	var weights := MOVE_FAR_WEIGHTS
	var best_cell := reachable_candidates[0]
	var best_score := -INF
	for c: Vector3i in reachable_candidates:
		var s := score_candidate(c, from, merc, state, reachable, known_enemies, weights)
		if s > best_score:
			best_score = s
			best_cell = c

	var existing_goal: Vector3i = state.move_goals.get(merc, NO_CELL) as Vector3i
	if existing_goal != NO_CELL and existing_goal != best_cell and reachable.has(existing_goal):
		var old_score := score_candidate(existing_goal, from, merc, state, reachable, known_enemies, weights)
		if best_score - old_score <= 2.0:
			return existing_goal

	state.move_goals[merc] = best_cell
	return best_cell

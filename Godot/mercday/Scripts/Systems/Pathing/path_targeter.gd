class_name PathTargeter

const JUMP_COST_OFFSET := 1000


static func _fall_tolerance(merc: MercenaryData) -> float:
	var hp_ratio := clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
	var break_fall := maxf(
		clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
		clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
	return clampf(hp_ratio + break_fall, 0.2, 2.0)


static func _ally_passable(merc: MercenaryData, state: BattleState) -> Dictionary:
	if state.turn_ally_passable.has(merc):
		return state.turn_ally_passable[merc] as Dictionary
	var passable: Dictionary = {}
	for ally: MercenaryData in state.get_allies(merc):
		if BattleState._is_alive(ally) and not ConstStates.has_state(ally, ConstStates.DEPOSED):
			var ap: Vector2i = state.positions.get(ally, Vector2i(-1, -1))
			if ap != Vector2i(-1, -1):
				passable[ap] = true
	passable.merge(state.battlefield.get_nav_passable_cells())
	return passable


# BFS flood-fill from `from`; returns Dictionary[Vector2i -> int] (cell -> cumulative cost).
# Cells reachable only via jump have cost >= JUMP_COST_OFFSET.
static func reachable_from(
		from: Vector2i,
		field: BattlefieldArea,
		passable: Dictionary,
		fall_tolerance: float,
		is_flying: bool,
		can_climb: bool,
		jump_range: int = 0) -> Dictionary:
	var visited: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var qi := 0
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	while qi < queue.size():
		var curr: Vector2i = queue[qi]
		qi += 1
		var curr_cost: int = visited[curr] as int
		for d: Vector2i in dirs:
			var nb := curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if visited.has(nb):
				continue
			var cost := PathCost.cell_pace_cost(curr, nb, field, passable, fall_tolerance, is_flying, can_climb)
			if cost < 0:
				continue
			visited[nb] = curr_cost + cost
			queue.append(nb)

	if jump_range > 0:
		var walk_cells: Array = visited.keys()
		for cell: Vector2i in walk_cells:
			if (visited[cell] as int) >= JUMP_COST_OFFSET:
				continue
			var cell_h: float = field.get_terrain_height(cell)
			for dx: int in range(-jump_range, jump_range + 1):
				for dy: int in range(-jump_range, jump_range + 1):
					var cdist := maxi(abs(dx), abs(dy))
					if cdist == 0 or cdist > jump_range:
						continue
					var jcell := cell + Vector2i(dx, dy)
					if jcell.x < 0 or jcell.x >= field.width or jcell.y < 0 or jcell.y >= field.length:
						continue
					if visited.has(jcell):
						continue
					if not PathCost.is_valid_jump_dest(jcell, field):
						continue
					var h_cost := int(ceil(maxf(0.0, field.get_terrain_height(jcell) - cell_h)))
					if cdist + h_cost > jump_range:
						continue
					visited[jcell] = (visited[cell] as int) + JUMP_COST_OFFSET + cdist + h_cost

	return visited


# All valid standable cells at exactly `stop_dist` Chebyshev distance from `target_pos`.
static func approach_candidates(
		target_pos: Vector2i,
		stop_dist: int,
		field: BattlefieldArea,
		is_flying: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var d := maxi(1, stop_dist)
	for x: int in range(target_pos.x - d, target_pos.x + d + 1):
		for y: int in range(target_pos.y - d, target_pos.y + d + 1):
			if maxi(absi(x - target_pos.x), absi(y - target_pos.y)) != d:
				continue
			var cell := Vector2i(x, y)
			if cell.x < 0 or cell.x >= field.width or cell.y < 0 or cell.y >= field.length:
				continue
			if field.jagged_cells.has(cell):
				continue
			if not is_flying and field.fly_only_cells.has(cell):
				continue
			var obs := field.get_obstacle_at(cell)
			if not obs.is_empty() and obs.get("cell_type", "") == "wall":
				continue
			result.append(cell)
	return result


# True if standing at `cell` would put the merc flanked given the provided known enemy positions.
static func is_flanked_by_known(cell: Vector2i, known: Dictionary) -> bool:
	var has_n := false
	var has_s := false
	var has_e := false
	var has_w := false
	for enemy: MercenaryData in known.keys():
		var ep: Vector2i = known[enemy] as Vector2i
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


# Multi-factor candidate scoring. `weights` selects which factors apply and at what magnitude.
# `reachable` is the output of reachable_from() (cell -> cumulative BFS cost).
# `known_enemies` is a snapshot of MercenaryData -> Vector2i (last known positions).
static func score_candidate(
		candidate: Vector2i,
		from: Vector2i,
		merc: MercenaryData,
		state: BattleState,
		reachable: Dictionary,
		known_enemies: Dictionary,
		weights: Dictionary) -> float:
	var field := state.battlefield
	var score := 0.0

	if weights.has("path_cost") and reachable.has(candidate):
		var raw_cost: int = reachable[candidate] as int
		var walk_cost: int = raw_cost if raw_cost < JUMP_COST_OFFSET else raw_cost - JUMP_COST_OFFSET
		score += float(weights["path_cost"]) * float(walk_cost)

	if weights.has("jump_penalty") and reachable.has(candidate):
		if (reachable[candidate] as int) >= JUMP_COST_OFFSET:
			score += float(weights["jump_penalty"])

	if weights.has("cover_at_dest") and field != null and not known_enemies.is_empty():
		var covered := false
		for obs: Dictionary in field.get_adjacent_obstacles(candidate):
			if covered:
				break
			var obs_pos: Vector2i = obs["pos"]
			var cover_dir := Vector2i(signi(obs_pos.x - candidate.x), signi(obs_pos.y - candidate.y))
			for enemy: MercenaryData in known_enemies.keys():
				if enemy.equipped_weapon == null or not enemy.equipped_weapon.is_ranged:
					continue
				var ep: Vector2i = known_enemies[enemy] as Vector2i
				var atk_dir := Vector2i(signi(ep.x - candidate.x), signi(ep.y - candidate.y))
				var blocks := true
				if cover_dir.x != 0 and cover_dir.x != atk_dir.x:
					blocks = false
				if cover_dir.y != 0 and cover_dir.y != atk_dir.y:
					blocks = false
				if blocks:
					covered = true
					break
		if covered:
			score += float(weights["cover_at_dest"])

	if weights.has("flanked_on_arrival") and not known_enemies.is_empty():
		if is_flanked_by_known(candidate, known_enemies):
			score += float(weights["flanked_on_arrival"])

	if weights.has("route_hazard") and not known_enemies.is_empty():
		var hazard := 0
		for enemy: MercenaryData in known_enemies.keys():
			var ep: Vector2i = known_enemies[enemy] as Vector2i
			var from_dist := maxi(absi(ep.x - from.x), absi(ep.y - from.y))
			var cand_dist := maxi(absi(ep.x - candidate.x), absi(ep.y - candidate.y))
			if from_dist <= 1 and cand_dist > 1:
				hazard += 1
		score += float(weights["route_hazard"]) * float(hazard)

	if weights.has("height_bonus") and field != null:
		var from_h := field.get_terrain_height(from)
		var cand_h := field.get_terrain_height(candidate)
		score += float(weights["height_bonus"]) * clampf((cand_h - from_h) * 0.5, 0.0, 1.0)

	if weights.has("enemy_distance") and not known_enemies.is_empty():
		var nearest_dist := INF
		for enemy: MercenaryData in known_enemies.keys():
			var ep: Vector2i = known_enemies[enemy] as Vector2i
			var d := float(maxi(absi(ep.x - candidate.x), absi(ep.y - candidate.y)))
			if d < nearest_dist:
				nearest_dist = d
		if nearest_dist < INF:
			score += float(weights["enemy_distance"]) * nearest_dist

	if weights.has("cover_count") and field != null:
		var count := 0.0
		for obs: Dictionary in field.obstacles:
			if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
				continue
			var od: ObstacleData = obs.get("data") as ObstacleData
			if od != null and not od.covers:
				continue
			var op: Vector2i = obs["pos"] as Vector2i
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
		for enemy: MercenaryData in known_enemies.keys():
			if not state.is_covered_from_pos(enemy, candidate):
				score += float(weights["los_bonus"])
				break

	if weights.has("last_from_penalty"):
		var esc: Dictionary = state.escalation.get(merc, {}) as Dictionary
		var last_from: Vector2i = esc.get("last_move_from", Vector2i(-1, -1)) as Vector2i
		if last_from != Vector2i(-1, -1) and candidate == last_from:
			score += float(weights["last_from_penalty"])

	if weights.has("goal_persistence"):
		var stored: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
		if stored != Vector2i(-1, -1) and candidate == stored:
			score += float(weights["goal_persistence"])

	return score


# Ally-aware scoring factors for Move Close candidates.
# Handles goal conflict, corridor crowding, pace blocking, and angle diversity.
static func _ally_score(
		candidate: Vector2i,
		from: Vector2i,
		merc: MercenaryData,
		target: MercenaryData,
		state: BattleState,
		weights: Dictionary) -> float:
	var score := 0.0
	var target_pos := state.get_position(target)

	for ally: MercenaryData in state.get_allies(merc):
		var ally_goal: Vector2i = state.move_goals.get(ally, Vector2i(-1, -1)) as Vector2i

		if weights.has("ally_goal_conflict") and ally_goal == candidate:
			score += float(weights["ally_goal_conflict"])

		var ally_target: MercenaryData = state.move_targets.get(ally) as MercenaryData
		if ally_target == null or ally_target != target:
			continue

		if weights.has("angle_diversity") and ally_goal != Vector2i(-1, -1):
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
			var ally_pos: Vector2i = state.get_position(ally)
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


# Returns the best adjacent cell to approach `target` from, or Vector2i(-1,-1) if none reachable.
static func best_approach_cell(
		merc: MercenaryData,
		target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		_valid_targets: Array[MercenaryData] = [],
		_enemies: Array[MercenaryData] = []) -> Vector2i:
	var field := state.battlefield
	if field == null:
		return state.get_position(merc)

	var from := state.get_position(merc)
	var target_pos := state.get_position(target)

	if from == target_pos:
		return from

	var is_flying := int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED)
	var can_climb := true
	var jump_range := int(merc.stats.get("jump", 0))
	var fall_tolerance := _fall_tolerance(merc)
	var ally_passable := _ally_passable(merc, state)

	var stop_dist: int
	if stop_dist_override >= 0:
		stop_dist = stop_dist_override
	elif state.get_allies(merc).has(target):
		stop_dist = 0
	else:
		var weapon := merc.equipped_weapon
		stop_dist = (weapon.melee_range if weapon != null and not weapon.is_ranged else 1)

	if flank_ally != null:
		var ally_pos := state.get_position(flank_ally)
		var flank_step := Vector2i(signi(target_pos.x - ally_pos.x), signi(target_pos.y - ally_pos.y))
		if flank_step != Vector2i.ZERO:
			target_pos = target_pos + flank_step * maxi(1, stop_dist)

	if stop_dist == 0:
		if not state.is_position_occupied(target_pos, merc):
			return target_pos
		return PathHelper.nearest_passable_to(target_pos, field, fall_tolerance, can_climb)

	var known_enemies: Dictionary = merc.last_known_enemy_positions.duplicate()

	var reachable := reachable_from(from, field, ally_passable, fall_tolerance, is_flying, can_climb, jump_range)
	var candidates := approach_candidates(target_pos, stop_dist, field, is_flying)

	var reachable_candidates: Array[Vector2i] = []
	for c: Vector2i in candidates:
		if reachable.has(c):
			reachable_candidates.append(c)

	if reachable_candidates.is_empty():
		var _tbr: int = state.team_blocked_round.get(target, -1) as int
		if _tbr == state.round_number:
			state.team_blocked_count[target] = (state.team_blocked_count.get(target, 0) as int) + 1
		else:
			state.team_blocked_round[target] = state.round_number
			state.team_blocked_count[target] = 1
		return Vector2i(-1, -1)

	var weights := ConstMoveWeights.MOVE_CLOSE_WEIGHTS

	var scored: Array = []
	for c: Vector2i in reachable_candidates:
		var s := score_candidate(c, from, merc, state, reachable, known_enemies, weights)
		s += _ally_score(c, from, merc, target, state, weights)
		scored.append([s, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as float) > (b[0] as float))

	for entry: Array in scored:
		var c: Vector2i = entry[1] as Vector2i
		if not Pathfinder.find_path(from, c, field, ally_passable, fall_tolerance, is_flying, can_climb).is_empty():
			state.move_goals[merc] = c
			state.move_targets[merc] = target
			return c
		if not PathHelper.find_path_toward(from, c, field, ally_passable, fall_tolerance, is_flying, can_climb, 0).is_empty():
			state.move_goals[merc] = c
			state.move_targets[merc] = target
			return c

	var _tbr2: int = state.team_blocked_round.get(target, -1) as int
	if _tbr2 == state.round_number:
		state.team_blocked_count[target] = (state.team_blocked_count.get(target, 0) as int) + 1
	else:
		state.team_blocked_round[target] = state.round_number
		state.team_blocked_count[target] = 1
	return Vector2i(-1, -1)


# Returns the best retreat cell for a Move Far action.
static func best_retreat_cell(
		merc: MercenaryData,
		_enemies: Array[MercenaryData],
		state: BattleState,
		move_target: MercenaryData = null,
		_valid_targets: Array[MercenaryData] = []) -> Vector2i:
	var field := state.battlefield
	if field == null:
		return state.get_position(merc)

	var from := state.get_position(merc)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)

	var is_flying := int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED)
	var can_climb := true
	var jump_range := int(merc.stats.get("jump", 0))
	var fall_tolerance := _fall_tolerance(merc)
	var ally_passable := _ally_passable(merc, state)

	var _pre_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
	if _pre_goal != Vector2i(-1, -1):
		if state.is_position_occupied(_pre_goal, merc) or field.is_obstacle(_pre_goal):
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
	var candidates: Array[Vector2i] = []
	var allies := state.get_allies(merc)
	for rd: Vector2i in retreat_dirs:
		if rd == Vector2i.ZERO:
			continue
		for mult: int in [pace, pace >> 1]:
			if mult <= 0:
				continue
			var c := field.clamp_position(from + rd * mult)
			if c == from or seen.has(c):
				continue
			if not allies.is_empty():
				var near_ally := false
				for ally: MercenaryData in allies:
					if maxi(absi(c.x - state.get_position(ally).x), absi(c.y - state.get_position(ally).y)) <= 20:
						near_ally = true
						break
				if not near_ally:
					continue
			seen[c] = true
			candidates.append(c)

	var reachable := reachable_from(from, field, ally_passable, fall_tolerance, is_flying, can_climb, jump_range)

	var reachable_candidates: Array[Vector2i] = []
	for c: Vector2i in candidates:
		if reachable.has(c):
			reachable_candidates.append(c)

	if reachable_candidates.is_empty():
		if not candidates.is_empty():
			return candidates[0]
		return field.clamp_position(from - step * pace)

	var weights := ConstMoveWeights.MOVE_FAR_WEIGHTS
	var best_cell := reachable_candidates[0]
	var best_score := -INF
	for c: Vector2i in reachable_candidates:
		var s := score_candidate(c, from, merc, state, reachable, known_enemies, weights)
		if s > best_score:
			best_score = s
			best_cell = c

	var existing_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
	if existing_goal != Vector2i(-1, -1) and existing_goal != best_cell and reachable.has(existing_goal):
		var old_score := score_candidate(existing_goal, from, merc, state, reachable, known_enemies, weights)
		if best_score - old_score <= 2.0:
			return existing_goal

	state.move_goals[merc] = best_cell
	return best_cell

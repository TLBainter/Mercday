class_name CoverNearbyFacet extends DecisionFacet

static var _scan_cache: Dictionary = {}

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	if ConstStates.has_state(merc, ConstStates.COVERED_FULL) \
			or ConstStates.has_state(merc, ConstStates.COVERED_PARTIAL):
		return 0.0
	var pos := state.get_position(merc)

	var ranged_enemies: Array = []
	for e in ctx.get("enemies", []):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)
	if ranged_enemies.is_empty():
		return 0.0

	var enemy_weights: Dictionary = {}
	var total_threat: float = 0.0
	for e: MercenaryData in ranged_enemies:
		var d := float(maxi(1, state.distance_2d(merc, e)))
		var w: float = clampf(8.0 / d, 0.2, 3.0)
		if (state.damage_dealt_last_round.get(e, {}) as Dictionary).get(merc, 0) > 0:
			w += 1.5
		if state.last_attacked.get(e) == merc:
			w += 1.0
		enemy_weights[e] = w
		total_threat += w
	if total_threat <= 0.0:
		return 0.0

	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var ap_available: int = merc.current_ap + merc.excess_ap
	var ap_after_move: int = ap_available - 2
	var ap_after_two_moves: int = ap_available - 4
	var seek_cover_cost: int = 2

	var max_hp_g: int = maxi(1, int(merc.stats.get("maximum_hit_points", 1)))
	var hp_ratio: float = float(merc.current_hp) / float(max_hp_g)

	# Retreating mercs accept cover in any direction; advancing mercs only score cover
	# that is forward-facing (moves them closer to at least one enemy).
	var is_retreating: bool = ConstStates.has_state(merc, ConstStates.TERRIFIED) \
			or hp_ratio <= 0.25

	var is_injured: bool = hp_ratio < 0.5
	var is_recently_targeted: bool = false
	for e: MercenaryData in ctx.get("enemies", []):
		if state.last_attacked.get(e) == merc:
			is_recently_targeted = true
			break
	var base_range: int = maxi(2, floori(float(ap_available - seek_cover_cost) / 2.0))
	var urgency_bonus: int = 0
	if hp_ratio < 0.25:
		urgency_bonus += 3
	elif is_injured:
		urgency_bonus += 1
	if ConstStates.has_state(merc, ConstStates.TERRIFIED):
		urgency_bonus += 3
	if is_recently_targeted:
		urgency_bonus += 2
	var search_range: int = mini(base_range + urgency_bonus, mini(10, pace * 4))

	# Cap search_range to what AP can actually reach so the BFS doesn't explore
	# cells the merc could never afford to move to and then seek cover from.
	if ap_after_two_moves >= seek_cover_cost:
		pass  # full range is valid; two-move distances are reachable
	elif ap_after_move >= seek_cover_cost:
		search_range = mini(search_range, pace)   # one-move distance only
	elif ap_available >= seek_cover_cost:
		search_range = 1                          # adjacent cover only
	else:
		return 0.0                                # can't afford seek_cover at all

	# Movement direction toward nearest ranged enemy -- used for alignment bonus.
	var nearest_enemy_dir := Vector2.ZERO
	var move_dir := Vector2.ZERO
	if not is_retreating:
		var nearest_dist_sq := INF
		for e: MercenaryData in ranged_enemies:
			var epos := state.get_position(e)
			var diff := Vector2(float(epos.x - pos.x), float(epos.y - pos.y))
			var dsq := diff.length_squared()
			if dsq < nearest_dist_sq:
				nearest_dist_sq = dsq
				nearest_enemy_dir = diff
		if nearest_enemy_dir != Vector2.ZERO:
			move_dir = nearest_enemy_dir.normalized()

	var has_moved: bool = ctx.get("has_moved", false)
	var cache_key: String = "%s_%d_%d" % [merc.merc_name, pos.x, pos.y]
	if _scan_cache.has(cache_key):
		var _cached: float = _scan_cache[cache_key]
		return minf(_cached + 0.05, 1.0) if (has_moved and _cached > 0.0) else _cached
	var best_score := 0.0
	var scan_candidates: Array = []

	var field := state.battlefield
	var _hp_ratio: float = clampf(float(merc.current_hp) / float(merc.stats.get("maximum_hit_points", 1)), 0.1, 1.0)
	var _best_break_fall: float = maxf(
		clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
		clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
	var fall_tolerance: float = clampf(_hp_ratio + _best_break_fall, 0.2, 2.0)
	var can_climb: bool = int(merc.stats.get("size", 0)) > 0
	var adj_dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	# BFS flood-fill from merc position to build a reachable-cell set in one pass.
	# Replaces per-candidate find_path calls (up to 8 x obstacles in range).
	var reachable: Dictionary = {}
	var bfs: Array[Vector2i] = [pos]
	reachable[pos] = true
	var bi := 0
	while bi < bfs.size():
		var curr: Vector2i = bfs[bi]
		bi += 1
		for bfs_d: Vector2i in adj_dirs:
			var nb: Vector2i = curr + bfs_d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if maxi(absi(nb.x - pos.x), absi(nb.y - pos.y)) > search_range:
				continue
			if reachable.has(nb):
				continue
			if Pathfinder.cell_pace_cost(curr, nb, field, {}, fall_tolerance, false, can_climb) < 0:
				continue
			reachable[nb] = true
			bfs.append(nb)

	# Iterate only cells in the bounding box and look up obstacles in O(1) via get_obstacle_at,
	# replacing the O(total_cover_obstacles) linear scan of field.cover_obstacles.
	for dx in range(-search_range, search_range + 1):
		for dy in range(-search_range, search_range + 1):
			var dist: int = maxi(absi(dx), absi(dy))
			if dist == 0 or dist > search_range:
				continue
			var obs_pos := Vector2i(pos.x + dx, pos.y + dy)
			if obs_pos.x < 0 or obs_pos.x >= field.width \
					or obs_pos.y < 0 or obs_pos.y >= field.length:
				continue
			var obs: Dictionary = field.get_obstacle_at(obs_pos)
			if obs.is_empty():
				continue
			if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
				continue
			var obs_data: ObstacleData = obs.get("data") as ObstacleData
			if obs_data == null or not obs_data.covers:
				continue

			var can_reach: bool
			if dist <= 1:
				can_reach = ap_available >= seek_cover_cost
			elif dist <= pace:
				can_reach = ap_after_move >= seek_cover_cost
			else:
				# Extended range: needs two moves (injured/targeted mercs only)
				can_reach = ap_after_two_moves >= seek_cover_cost
			if not can_reach:
				scan_candidates.append({"pos": obs_pos, "dist": dist, "skip": "no-ap"})
				continue

			var to_cover := Vector2(float(dx), float(dy))
			var threat_covered: float = 0.0
			for e: MercenaryData in ranged_enemies:
				var epos := state.get_position(e)
				var to_enemy := Vector2(float(epos.x - pos.x), float(epos.y - pos.y))
				if to_cover.dot(to_enemy) > 0.0:
					threat_covered += float(enemy_weights.get(e, 0.0))

			if threat_covered <= 0.0:
				scan_candidates.append({"pos": obs_pos, "dist": dist, "skip": "no-threat-coverage"})
				continue

			# Advancing mercs skip strictly-backward cover; lateral cover (dot=0) is allowed.
			if not is_retreating and nearest_enemy_dir != Vector2.ZERO \
					and to_cover.dot(nearest_enemy_dir) < 0.0:
				scan_candidates.append({"pos": obs_pos, "dist": dist, "skip": "wrong-direction"})
				continue

			var any_reachable := false
			for adj_d: Vector2i in adj_dirs:
				var candidate := obs_pos + adj_d
				if candidate.x < 0 or candidate.x >= field.width \
						or candidate.y < 0 or candidate.y >= field.length:
					continue
				if field.is_obstacle(candidate):
					continue
				if reachable.has(candidate):
					any_reachable = true
					break
			if not any_reachable:
				scan_candidates.append({"pos": obs_pos, "dist": dist, "skip": "unreachable"})
				continue

			var coverage_ratio: float = clampf(threat_covered / total_threat, 0.0, 1.0)
			var is_narrow: bool = obs_data != null and obs_data.narrow
			var obs_size: int = int(obs.get("size", 1))
			var is_full_cover: bool = not is_narrow and obs_size > merc_size

			# Base score: 0.9 for full cover, 0.5 for partial (starts at 0.9 ceiling)
			var base := coverage_ratio * (0.9 if is_full_cover else 0.5)

			# Alignment bonus: cover on the path toward the enemy earns up to +0.1
			var alignment_bonus := 0.0
			if move_dir != Vector2.ZERO and to_cover.length_squared() > 0.0:
				var alignment := clampf(to_cover.normalized().dot(move_dir), 0.0, 1.0)
				alignment_bonus = alignment * 0.1

			var ap_cost_penalty := 0.0
			if dist > pace:
				ap_cost_penalty = 0.3
			elif dist > 1:
				ap_cost_penalty = 0.15
			var seek_cost_penalty := 0.1 if is_full_cover else 0.0
			var fall_penalty := 0.0
			if obs_data != null and obs_data.passthrough:
				var max_hp: int = maxi(1, int(merc.stats.get("maximum_hit_points", 1)))
				fall_penalty = clampf(float(obs_data.pt_enter_harm) / float(max_hp), 0.0, 0.5)
			var access_penalty := ap_cost_penalty + seek_cost_penalty + fall_penalty
			var candidate_score := (base + alignment_bonus) * (1.0 - access_penalty)
			scan_candidates.append({"pos": obs_pos, "dist": dist, "score": candidate_score})
			best_score = maxf(best_score, candidate_score)

	if best_score <= 0.0:
		EncounterLogger.log_cover_scan(merc.merc_name, search_range, scan_candidates, 0.0)
		_scan_cache[cache_key] = 0.0
		return 0.0

	var move_ap_cost := 2
	var move_budget: int = floori(float(merc.current_ap) / float(move_ap_cost))
	var any_chebyshev_reachable := false
	for c: Dictionary in scan_candidates:
		if not c.has("score"):
			continue
		var cpos: Vector2i = c["pos"] as Vector2i
		if maxi(absi(cpos.x - pos.x), absi(cpos.y - pos.y)) <= move_budget:
			any_chebyshev_reachable = true
			break
	if not any_chebyshev_reachable:
		EncounterLogger.log_cover_scan(merc.merc_name, search_range, scan_candidates, 0.0)
		_scan_cache[cache_key] = 0.0
		return 0.0

	# Already-moved bonus: merc spent AP moving this turn, stopping for cover is cheaper
	if has_moved:
		best_score = minf(best_score + 0.05, 1.0)

	EncounterLogger.log_cover_scan(merc.merc_name, search_range, scan_candidates, best_score)
	var final_score: float = clampf(best_score, 0.0, 1.0)
	_scan_cache[cache_key] = final_score
	return minf(final_score + 0.05, 1.0) if (has_moved and final_score > 0.0) else final_score


static func create(p_weight: float = 1.0, p_required: bool = false) -> CoverNearbyFacet:
	var facet := CoverNearbyFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

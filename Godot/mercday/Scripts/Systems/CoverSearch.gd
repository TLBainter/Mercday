class_name CoverSearch
extends RefCounted

#Finds the cell that breaks the most ranged sight lines and scores Seek Cover for the
#decision layer; holds no action execution.


static var _scan_cache: Dictionary = {}


#Dropped at the start of every round by AutoBattle.
static func clear_scan_cache() -> void:
	_scan_cache.clear()


#How many ranged enemies lose sight of a unit of p_size standing on cell.
static func cover_score(cell: Vector3i, p_size: int, ranged: Array, state: BattleState) -> Dictionary:
	var full := 0
	var partial := 0
	for e: MercenaryData in ranged:
		var los := LineOfSight.check_from(state, cell, 0, p_size, e)
		if not (los["visible"] as bool):
			full += 1
		elif str(los["cover"]) == "partial":
			partial += 1
	return {"full": full, "partial": partial}


#cover_score with the caller's running best as a bound; {} when this cell can no longer beat it.
static func _cover_score_bounded(cell: Vector3i, p_size: int, ranged: Array, state: BattleState,
		best_full: int, best_partial: int, tie_ok: bool) -> Dictionary:
	var full := 0
	var partial := 0
	var rem: int = ranged.size()
	for e: MercenaryData in ranged:
		#Reaching best_full needs every remaining enemy to block fully, which leaves partial as it is.
		if full + rem < best_full:
			return {}
		if full + rem == best_full and partial < best_partial:
			return {}
		if full + rem == best_full and partial == best_partial and not tie_ok:
			return {}
		rem -= 1
		var los := LineOfSight.check_from(state, cell, 0, p_size, e)
		if not (los["visible"] as bool):
			full += 1
		elif str(los["cover"]) == "partial":
			partial += 1
	return {"full": full, "partial": partial}


static func ranged_enemies(enemies: Array) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	for e: MercenaryData in enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			result.append(e)
	return result


#Best reachable cell that breaks more ranged sight lines than the current one; NO_CELL when none does.
static func find_cover_cell(merc: MercenaryData, enemies: Array, state: BattleState) -> Vector3i:
	if state.battlefield == null:
		return PathTargeter.NO_CELL
	var ranged := ranged_enemies(enemies)
	if ranged.is_empty():
		return PathTargeter.NO_CELL
	var here := state.pos3(merc)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var reach: Dictionary = PathTargeter.reachable_for(merc, state)
	var base := cover_score(here, merc_size, ranged, state)
	var best := PathTargeter.NO_CELL
	var best_full: int = base["full"]
	var best_partial: int = base["partial"]
	var best_cost := 0
	#Seek Cover teleports to the cell, so a cross-floor drop would skip the fall; stay on this floor.
	var here_floor := state.get_floor(merc)
	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		if cost <= 0 or cost > pace:
			continue
		if cell.z != here_floor:
			continue
		if state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
			continue
		var sc := _cover_score_bounded(cell, merc_size, ranged, state, best_full, best_partial,
			best != PathTargeter.NO_CELL and cost < best_cost)
		if sc.is_empty():
			continue
		var f: int = sc["full"]
		var pa: int = sc["partial"]
		var better := f > best_full
		if not better and f == best_full:
			better = pa > best_partial
		if not better and f == best_full and pa == best_partial:
			better = best != PathTargeter.NO_CELL and cost < best_cost
		if better:
			best_full = f
			best_partial = pa
			best_cost = cost
			best = cell
	return best


#True when the merc is exposed to a ranged enemy, can pay for Seek Cover and a better cell exists.
static func _scan_gate(merc: MercenaryData, state: BattleState, ranged: Array) -> bool:
	var exposed := false
	for e: MercenaryData in ranged:
		if not state.is_covered_from(merc, e, ConstStates.COVERED_FULL):
			exposed = true
			break
	if not exposed:
		return false
	#Seek Cover charges a Move plus its own cost and needs a cell with more cover than here.
	var _seek_total: int = state.get_cost(merc, "seek_cover", 2) \
		+ state.get_cost(merc, "Move Close", AutoBattle.MOVE_BASE_AP)
	if not state.can_afford(merc, _seek_total):
		return false
	return find_cover_cell(merc, state.get_enemies(merc), state) != PathTargeter.NO_CELL


#Threat weight per ranged enemy: nearer weighs more, and so does one that hit or aimed at this merc.
static func _threat_weights(merc: MercenaryData, ranged: Array, state: BattleState) -> Dictionary:
	var weights: Dictionary = {}
	for e: MercenaryData in ranged:
		var d := float(maxi(1, state.distance_2d(merc, e)))
		var w: float = clampf(8.0 / d, 0.2, 3.0)
		if (state.damage_dealt_last_round.get(e, {}) as Dictionary).get(merc, 0) > 0:
			w += 1.5
		if state.last_attacked.get(e) == merc:
			w += 1.0
		weights[e] = w
	return weights


#How far the scan may look, from AP, pace, hp ratio and Terrified; 0 when seek_cover is unaffordable.
static func _search_range(merc: MercenaryData, ctx: Dictionary, pace: int, ap_available: int,
		seek_cover_cost: int) -> int:
	var state: BattleState = ctx.get("state")
	var max_hp_g: int = maxi(1, int(merc.stats.get("maximum_hit_points", 1)))
	var hp_ratio: float = float(merc.current_hp) / float(max_hp_g)
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
	var ap_after_move: int = ap_available - 2
	var ap_after_two_moves: int = ap_available - 4

	#Cap search_range to what the AP can reach so the scan skips cells the merc could never afford.
	#The full range holds while two Moves are affordable.
	if ap_after_two_moves < seek_cover_cost:
		if ap_after_move >= seek_cover_cost:
			search_range = mini(search_range, pace)  #one Move of distance only
		elif ap_available >= seek_cover_cost:
			search_range = 1  #adjacent cover only
		else:
			return 0  #seek_cover is not affordable at all
	return search_range


#Cover scan for the Seek Cover decision: caches one score per merc, cell and LOS version,
#and emits the COVER SCAN log line.
static func cover_scan_score(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	var pos := state.get_position(merc)

	var ranged_foes := DecisionFacet.ranged_enemies_in(ctx)
	if ranged_foes.is_empty():
		return 0.0
	if not _scan_gate(merc, state, ranged_foes):
		return 0.0

	var enemy_weights: Dictionary = _threat_weights(merc, ranged_foes, state)
	var total_threat: float = 0.0
	for w: float in enemy_weights.values():
		total_threat += w
	if total_threat <= 0.0:
		return 0.0

	var pace: int = maxi(1, int(MovementExecutor.turn_paces(merc, state, 0)["paces"]))
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var ap_available: int = merc.current_ap + merc.excess_ap
	var ap_after_move: int = ap_available - 2
	var ap_after_two_moves: int = ap_available - 4
	var seek_cover_cost: int = 2

	var max_hp_g: int = maxi(1, int(merc.stats.get("maximum_hit_points", 1)))
	var hp_ratio: float = float(merc.current_hp) / float(max_hp_g)

	#Retreating mercs accept cover in any direction; advancing mercs score only cover that closes on an enemy.
	var is_retreating: bool = ConstStates.has_state(merc, ConstStates.TERRIFIED) \
			or hp_ratio <= 0.25

	var search_range: int = _search_range(merc, ctx, pace, ap_available, seek_cover_cost)
	if search_range <= 0:
		return 0.0

	#Movement direction toward the nearest ranged enemy; the alignment bonus reads it.
	var nearest_enemy_dir := Vector2.ZERO
	var move_dir := Vector2.ZERO
	if not is_retreating:
		var nearest_dist_sq := INF
		for e: MercenaryData in ranged_foes:
			var epos := state.get_position(e)
			var diff := Vector2(float(epos.x - pos.x), float(epos.y - pos.y))
			var dsq := diff.length_squared()
			if dsq < nearest_dist_sq:
				nearest_dist_sq = dsq
				nearest_enemy_dir = diff
		if nearest_enemy_dir != Vector2.ZERO:
			move_dir = nearest_enemy_dir.normalized()

	var has_moved: bool = ctx.get("has_moved", false)
	var cache_key: String = "%s_%d_%d_%d" % [merc.merc_name, pos.x, pos.y, state.battlefield.los_version]
	if _scan_cache.has(cache_key):
		var _cached: float = _scan_cache[cache_key]
		return minf(_cached + 0.05, 1.0) if (has_moved and _cached > 0.0) else _cached
	var best_score := 0.0
	var scan_candidates: Array = []

	var reach: Dictionary = PathTargeter.reachable_for(merc, state)

	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		var cpos := Vector2i(cell.x, cell.y)
		var dist: int = maxi(absi(cell.x - pos.x), absi(cell.y - pos.y))
		if cost <= 0 or cost >= PathTargeter.JUMP_COST_OFFSET or dist > search_range:
			continue
		var can_reach: bool
		if cost <= 1:
			can_reach = ap_available >= seek_cover_cost
		elif cost <= pace:
			can_reach = ap_after_move >= seek_cover_cost
		else:
			can_reach = ap_after_two_moves >= seek_cover_cost
		if not can_reach:
			scan_candidates.append({"pos": cpos, "dist": dist, "skip": "no-ap"})
			continue
		if state.is_position_occupied(cpos, merc, cell.z):
			continue

		var full_w := 0.0
		var part_w := 0.0
		for e: MercenaryData in ranged_foes:
			var los := LineOfSight.check_from(state, cell, 0, merc_size, e)
			var ew: float = float(enemy_weights.get(e, 0.0))
			if not (los["visible"] as bool):
				full_w += ew
			elif str(los["cover"]) == "partial":
				part_w += ew
		if full_w <= 0.0 and part_w <= 0.0:
			scan_candidates.append({"pos": cpos, "dist": dist, "skip": "no-threat-coverage"})
			continue

		var to_cover := Vector2(float(cell.x - pos.x), float(cell.y - pos.y))
		if not is_retreating and nearest_enemy_dir != Vector2.ZERO \
				and to_cover.dot(nearest_enemy_dir) < 0.0:
			scan_candidates.append({"pos": cpos, "dist": dist, "skip": "wrong-direction"})
			continue

		var base: float = clampf((full_w + part_w * 0.5) / total_threat, 0.0, 1.0)
		var alignment_bonus := 0.0
		if move_dir != Vector2.ZERO and to_cover.length_squared() > 0.0:
			alignment_bonus = clampf(to_cover.normalized().dot(move_dir), 0.0, 1.0) * 0.1
		var ap_cost_penalty := 0.0
		if cost > pace:
			ap_cost_penalty = 0.3
		elif cost > 1:
			ap_cost_penalty = 0.15
		var candidate_score: float = (base + alignment_bonus) * (1.0 - ap_cost_penalty)
		scan_candidates.append({"pos": cpos, "dist": dist, "score": candidate_score})
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

	#Bonus for a merc that already spent AP moving this turn, because stopping for cover is cheaper.
	if has_moved:
		best_score = minf(best_score + 0.05, 1.0)

	EncounterLogger.log_cover_scan(merc.merc_name, search_range, scan_candidates, best_score)
	var final_score: float = clampf(best_score, 0.0, 1.0)
	_scan_cache[cache_key] = final_score
	return minf(final_score + 0.05, 1.0) if (has_moved and final_score > 0.0) else final_score

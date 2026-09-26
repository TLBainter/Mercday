class_name RoofPostScore

#A ranged unit standing off the roofs weighs the roof climbs in reach against walking for its first
#shot: the post is taken only when it stands on the top in fewer rounds than the walk needs to see
#a foe. Scored once per unit per turn and held on the state, dropped at turn start. No RNG.

#Candidates scored at most, the Moves of walking plus climbing one may cost, and the Moves a round buys.
const MAX_POSTS := 6
const MAX_MOVES := 8
const MOVES_PER_ROUND := 2
const HEIGHT_STEP := 0.25
const HEIGHT_CAP := 2.0

#Sight origins scored since the last reset; the tests read it to count the candidates.
static var origins_scored: int = 0
#Walk cells whose sight was weighed since the last reset; never counted as post origins.
static var walk_cells_scored: int = 0


static func reset_counter() -> void:
	origins_scored = 0
	walk_cells_scored = 0


#The post this unit wants this turn: {} for none, else {link, foot, top, score, post_round, walk_round}.
static func best(merc: MercenaryData, state: BattleState) -> Dictionary:
	if merc == null or state == null or state.battlefield == null:
		return {}
	if state.roof_posts.has(merc):
		return state.roof_posts[merc] as Dictionary
	#Held before the scoring runs, so anything it reaches reads {} instead of scoring again.
	state.roof_posts[merc] = {}
	var row: Dictionary = _compute(merc, state)
	state.roof_posts[merc] = row
	return row


#The cell a Move Close walks to for the post; NO_CELL when none is wanted or the unit is on the foot.
static func goal_cell(merc: MercenaryData, state: BattleState) -> Vector3i:
	var row: Dictionary = best(merc, state)
	if row.is_empty():
		return PathTargeter.NO_CELL
	var foot: Vector3i = row["foot"] as Vector3i
	if state.pos3(merc) == foot:
		return PathTargeter.NO_CELL
	return foot


#True when the unit stands on the foot of the post it scored, so the Climb takes the slot.
static func at_post(merc: MercenaryData, state: BattleState) -> bool:
	var row: Dictionary = best(merc, state)
	return not row.is_empty() and state.pos3(merc) == (row["foot"] as Vector3i)


#The link top of the scored post, or (-1,-1,-1) when this unit wants none.
static func post_top(merc: MercenaryData, state: BattleState) -> Vector3i:
	var row: Dictionary = best(merc, state)
	if row.is_empty():
		return Vector3i(-1, -1, -1)
	return row["top"] as Vector3i


static func _compute(merc: MercenaryData, state: BattleState) -> Dictionary:
	var field: BattlefieldArea = state.battlefield
	if field.roof_cells.is_empty() or field.climb_links.is_empty():
		return {}
	if not WeaponEvaluator.is_ranged_focused(merc):
		return {}
	if state.is_sunk(merc) or PathTargeter.is_flying(merc):
		return {}
	var here: Vector3i = state.pos3(merc)
	if here.x < 0 or field.is_roof_footing(Vector2i(here.x, here.y), here.z):
		return {}
	var foes: Array[MercenaryData] = _living_enemies(merc, state)
	if foes.is_empty():
		return {}
	#A shot from where it stands beats any climb, so no post is scored at all.
	for foe: MercenaryData in foes:
		if bool(LineOfSight.check(state, merc, foe).get("visible", true)):
			return {}
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var per_move: int = maxi(1, MovementExecutor.pace_per_move(merc))
	var walk_round: int = _walk_round(merc, state, here, foes, merc_size, per_move)
	var budget_moves: int = MAX_MOVES
	if walk_round > 0:
		budget_moves = mini(MAX_MOVES, MOVES_PER_ROUND * (walk_round - 1))
	if budget_moves <= 0:
		return {}
	var rows: Array = _candidates(merc, state, field, merc_size, per_move, budget_moves)
	if rows.is_empty():
		return {}
	var top: Dictionary = _score_candidates(merc, state, rows, foes, merc_size, per_move, walk_round)
	if top.is_empty():
		return {}
	var best_row: Array = top["row"] as Array
	var best_score: float = top["score"]
	var best_seen: int = top["seen"]
	var best_round: int = top["round"]
	var out: Dictionary = {"link": best_row[3] as Dictionary, "foot": best_row[1] as Vector3i,
		"top": best_row[2] as Vector3i, "score": best_score, "post_round": best_round,
		"walk_round": walk_round}
	if EncounterLogger.is_active():
		var t: Vector3i = out["top"] as Vector3i
		EncounterLogger.log_verbose("ROOF POST: %s top (%d,%d,%d) seen %d score %.2f post_round %d walk_round %d" % [
			merc.merc_name, t.x, t.y, t.z, best_seen, best_score, best_round, walk_round])
	return out


#The candidate the sight scoring picks: {} for none, else {row, score, seen, round}.
static func _score_candidates(merc: MercenaryData, state: BattleState, rows: Array,
		foes: Array[MercenaryData], merc_size: int, per_move: int, walk_round: int) -> Dictionary:
	var field: BattlefieldArea = state.battlefield
	var mean_e: float = 0.0
	for foe: MercenaryData in foes:
		mean_e += field.cell_base_elevation(state.get_position(foe), state.get_floor(foe))
	mean_e /= float(foes.size())
	var best_row: Array = []
	var best_score: float = 0.0
	var best_turns: int = 0
	var best_seen: int = 0
	var best_round: int = 0
	#The best scoring row with sight, gate or no gate; the refusal line reports its round.
	var seen_round: int = 0
	var seen_score: float = 0.0
	for i: int in range(mini(rows.size(), MAX_POSTS)):
		var row: Array = rows[i]
		var top: Vector3i = row[2] as Vector3i
		var seen: int = _seen_from(state, top, merc_size, foes)
		if seen <= 0:
			continue
		var rise: float = field.cell_base_elevation(Vector2i(top.x, top.y), top.z) - mean_e
		var height: float = clampf(1.0 + HEIGHT_STEP * maxf(0.0, rise), 1.0, HEIGHT_CAP)
		var turns: int = int(ceil(float(row[0] as int) / float(per_move)))
		var score: float = float(seen) * height / float(1 + turns)
		var post_round: int = maxi(1, int(ceil(float(turns) / float(MOVES_PER_ROUND))))
		if seen_round == 0 or score > seen_score:
			seen_round = post_round
			seen_score = score
		if walk_round > 0 and post_round >= walk_round:
			continue
		if not best_row.is_empty() and not (score > best_score
				or (is_equal_approx(score, best_score) and turns < best_turns)):
			continue
		best_row = row
		best_score = score
		best_turns = turns
		best_seen = seen
		best_round = post_round
	if best_row.is_empty():
		if seen_round > 0 and EncounterLogger.is_active():
			EncounterLogger.log_verbose("ROOF POST REFUSED: %s post_round %d walk_round %d" % [
				merc.merc_name, seen_round, walk_round])
		return {}
	return {"row": best_row, "score": best_score, "seen": best_seen, "round": best_round}


#best_approach_cell records goals, far_full and the team blocked counters; a probe puts back what it found.
static func _probe_approach(merc: MercenaryData, near: MercenaryData, state: BattleState) -> Vector3i:
	var tables: Array = [[state.move_goals, merc], [state.move_targets, merc], [state.far_full, merc],
		[state.team_blocked_round, near], [state.team_blocked_count, near]]
	var keep: Dictionary = {}
	for i: int in range(tables.size()):
		var table: Dictionary = (tables[i] as Array)[0]
		var key: Variant = (tables[i] as Array)[1]
		if table.has(key):
			keep[i] = table[key]
	var cell: Vector3i = PathTargeter.best_approach_cell(merc, near, state)
	for i2: int in range(tables.size()):
		var table2: Dictionary = (tables[i2] as Array)[0]
		var key2: Variant = (tables[i2] as Array)[1]
		if keep.has(i2):
			table2[key2] = keep[i2]
		else:
			table2.erase(key2)
	return cell


#Rounds of walking before this unit's first shot: 0 when no approach cell is left to walk to, and
#one round past the post budget when the route it would take never opens a line.
static func _walk_round(merc: MercenaryData, state: BattleState, here: Vector3i,
		foes: Array[MercenaryData], merc_size: int, per_move: int) -> int:
	var slow: int = int(ceil(float(MAX_MOVES) / float(MOVES_PER_ROUND))) + 1
	var near: MercenaryData = null
	var near_d: int = 1 << 30
	for foe: MercenaryData in foes:
		var p: Vector2i = state.get_position(foe)
		var d: int = maxi(abs(here.x - p.x), abs(here.y - p.y))
		if d < near_d:
			near_d = d
			near = foe
	if near == null:
		return 0
	var cell: Vector3i = _probe_approach(merc, near, state)
	if cell == PathTargeter.NO_CELL or cell == here:
		return 0
	var path: Array[Vector3i] = PathTargeter.walk_path_for(merc, state, here, cell)
	if path.size() < 2:
		return slow
	var reach: Dictionary = PathTargeter.reachable_for(merc, state)
	var bound: int = MAX_MOVES * per_move
	for i: int in range(1, path.size()):
		var step: Vector3i = path[i]
		if not reach.has(step):
			continue
		var cost: int = reach[step] as int
		if cost >= PathTargeter.JUMP_COST_OFFSET or cost > bound:
			break
		if not _sees_any(state, step, merc_size, foes):
			continue
		var moves: int = int(ceil(float(cost) / float(per_move)))
		return maxi(1, int(ceil(float(moves) / float(MOVES_PER_ROUND))))
	return slow


#Roof climbs whose foot the flood reaches and whose top the unit can be standing on within the
#budget in Moves: [total paces, foot, top, link] rows, cheapest first, then by y and x.
static func _candidates(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		merc_size: int, per_move: int, budget_moves: int) -> Array:
	var budget: int = budget_moves * per_move
	var pace_c: int = maxi(1, MovementExecutor.climb_pace_cost(merc))
	var rows: Array = []
	var reach: Dictionary = _reach_within(merc, state, budget)
	for key: Variant in reach.keys():
		var foot: Vector3i = key as Vector3i
		if not field.climb_links.has(foot):
			continue
		var cost: int = reach[key] as int
		if cost >= PathTargeter.JUMP_COST_OFFSET or cost > budget:
			continue
		for link: Dictionary in field.climb_links_at(foot):
			if String(link["kind"]) != "roof":
				continue
			var total: int = cost + 1 + int(link["paces"]) * pace_c
			if total > budget:
				continue
			var top: Vector3i = link["top"] as Vector3i
			if state.is_position_occupied(Vector2i(top.x, top.y), merc, top.z):
				continue
			if not ClimbAction._vault_ok(link, field, merc_size):
				continue
			rows.append([total, foot, top, link])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return _cheaper(a, b))
	return rows


#The unit's own flood while the budget fits inside its bound, else a wider one of its own: the
#cached flood is never grown here because its other readers walk every key it holds.
static func _reach_within(merc: MercenaryData, state: BattleState, budget: int) -> Dictionary:
	if budget <= PathTargeter.reach_budget(merc, state):
		return PathTargeter.reachable_for(merc, state)
	PathCost.set_mover_doors(merc, state)
	var search: ReachSearch = ReachSearch.create(state.pos3(merc), state.battlefield,
		PathTargeter._ally_passable(merc, state), PathTargeter.fall_tolerance(merc), false, true,
		int(merc.stats.get("jump", 0)), int(merc.stats.get("size", 1)), state.get_height(merc))
	search.ensure_cost(budget)
	return search.result


static func _cheaper(a: Array, b: Array) -> bool:
	var ca: int = a[0] as int
	var cb: int = b[0] as int
	if ca != cb:
		return ca < cb
	var fa: Vector3i = a[1] as Vector3i
	var fb: Vector3i = b[1] as Vector3i
	if fa.y != fb.y:
		return fa.y < fb.y
	return fa.x < fb.x


#Living enemies in sight from cell at the standing height of merc_size; stop_at_first ends on the first.
static func _count_seen(state: BattleState, cell: Vector3i, merc_size: int,
		foes: Array[MercenaryData], stop_at_first: bool) -> int:
	var seen: int = 0
	for foe: MercenaryData in foes:
		if bool(LineOfSight.check_from(state, cell, 0, merc_size, foe).get("visible", true)):
			seen += 1
			if stop_at_first:
				return seen
	return seen


#Living enemies with a clean or grazing sight line from cell, at the standing height of merc_size.
static func _seen_from(state: BattleState, cell: Vector3i, merc_size: int,
		foes: Array[MercenaryData]) -> int:
	origins_scored += 1
	return _count_seen(state, cell, merc_size, foes, false)


#True when one living enemy is in sight from a cell the walking route crosses.
static func _sees_any(state: BattleState, cell: Vector3i, merc_size: int,
		foes: Array[MercenaryData]) -> bool:
	walk_cells_scored += 1
	return _count_seen(state, cell, merc_size, foes, true) > 0


static func _living_enemies(merc: MercenaryData, state: BattleState) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for foe: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(foe):
			continue
		if state.get_position(foe) == Vector2i(-1, -1):
			continue
		out.append(foe)
	return out

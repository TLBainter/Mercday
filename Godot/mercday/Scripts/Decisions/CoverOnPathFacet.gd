class_name CoverOnPathFacet extends DecisionFacet

const DETOUR_LIMIT := 1.25


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 1.0

	var ranged_enemies := DecisionFacet.ranged_enemies_in(ctx)
	if ranged_enemies.is_empty():
		return 1.0

	var merc_pos := state.get_position(merc)
	var pace: int = maxi(1, int(PaceBudget.turn_paces(merc, state, 0)["paces"]))

	var nearest_enemy: MercenaryData = null
	var nearest_dist: float = INF
	for e: MercenaryData in ranged_enemies:
		var d := float(maxi(1, state.distance_2d(merc, e)))
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	var enemy_pos := state.get_position(nearest_enemy)

	var best_cover_pos := Vector2i(-1, -1)
	var best_cover_dist: float = INF
	for obs: Dictionary in state.battlefield.obstacles:
		if obs.get("cell_type", "") == "door" and OpenCloseState.is_open(obs):
			continue
		var obs_data: ObstacleData = obs.get("data") as ObstacleData
		if obs_data != null and not obs_data.covers:
			continue
		var obs_pos := BattlefieldArea.cell_of(obs["pos"])
		var delta := obs_pos - merc_pos
		var dist: float = float(maxi(absi(delta.x), absi(delta.y)))
		if dist == 0.0 or dist > float(pace) * 2.0:
			continue
		var to_cover := Vector2(float(delta.x), float(delta.y))
		var to_enemy := Vector2(float(enemy_pos.x - merc_pos.x), float(enemy_pos.y - merc_pos.y))
		if to_cover.dot(to_enemy) <= 0.0:
			continue
		if dist < best_cover_dist:
			best_cover_dist = dist
			best_cover_pos = obs_pos

	if best_cover_pos == Vector2i(-1, -1):
		return 1.0

	var cover_to_enemy := float(maxi(
		absi(best_cover_pos.x - enemy_pos.x),
		absi(best_cover_pos.y - enemy_pos.y)))
	var direct_dist := float(maxi(1, int(nearest_dist)))
	var detour_ratio := (best_cover_dist + cover_to_enemy) / direct_dist

	return 0.0 if detour_ratio > DETOUR_LIMIT else 1.0

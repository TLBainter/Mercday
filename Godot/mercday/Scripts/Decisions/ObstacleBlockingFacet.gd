class_name ObstacleBlockingFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	if not ctx.get("movement_blocked", false):
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	if merc.equipped_weapon == null or not merc.weapon_drawn:
		return 0.0
	var pos := state.get_position(merc)
	var enemies: Array = ctx.get("enemies", [])
	var nearest_enemy: MercenaryData = null
	var nearest_dist: int = 999999
	for e: MercenaryData in enemies:
		var d := state.distance_to(merc, e)
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.is_stairs:
			continue
		if d.health <= 0 or d.indestructible:
			continue
		if nearest_enemy == null:
			return 1.0
		var obs_pos: Vector2i = obs["pos"] as Vector2i
		var enemy_pos := state.get_position(nearest_enemy)
		var to_enemy := Vector2i(signi(enemy_pos.x - pos.x), signi(enemy_pos.y - pos.y))
		var to_obs := Vector2i(signi(obs_pos.x - pos.x), signi(obs_pos.y - pos.y))
		if to_obs == to_enemy or to_obs.x == to_enemy.x or to_obs.y == to_enemy.y:
			return 1.0
	return 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> ObstacleBlockingFacet:
	var facet := ObstacleBlockingFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

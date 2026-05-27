class_name CoverNearbyFacet extends DecisionFacet


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
	var raw_obs := state.battlefield.get_adjacent_obstacles(pos)
	for obs in raw_obs:
		# open doors are excluded by seek_cover execution, so skip them here too
		if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
			continue
		return 1.0
	return 0.0


static func create(p_weight: float = 1.0, p_required: bool = false) -> CoverNearbyFacet:
	var facet := CoverNearbyFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

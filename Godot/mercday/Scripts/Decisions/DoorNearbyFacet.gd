class_name DoorNearbyFacet extends DecisionFacet


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	var pos := state.get_position(merc)
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos):
		if obs.get("cell_type", "") == "door" and not obs.get("door_open", false):
			return 1.0
	return 0.0


static func create(p_weight: float = 1.0, p_required: bool = false) -> DoorNearbyFacet:
	var facet := DoorNearbyFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

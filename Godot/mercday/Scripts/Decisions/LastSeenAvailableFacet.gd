class_name LastSeenAvailableFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var last: MercenaryData = merc.active_states.get("last_target") as MercenaryData
	if last == null:
		return 0.0
	for enemy: MercenaryData in ctx.get("enemies", []):
		if enemy == last and BattleState._is_alive(enemy):
			return 1.0
	merc.active_states.erase("last_target")
	return 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> LastSeenAvailableFacet:
	var facet := LastSeenAvailableFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

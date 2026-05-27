class_name MovementNotBlockedFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 0.0 if ctx.get("movement_blocked", false) else 1.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> MovementNotBlockedFacet:
	var facet := MovementNotBlockedFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

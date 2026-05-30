class_name LastSeenAvailableFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	if ctx.get("valid_targets", []).is_empty() and not ctx.get("enemies", []).is_empty():
		return 1.0
	return 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> LastSeenAvailableFacet:
	var facet := LastSeenAvailableFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

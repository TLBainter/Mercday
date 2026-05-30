class_name NoClearShotFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 1.0 if ctx.get("valid_targets", []).is_empty() else 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> NoClearShotFacet:
	var facet := NoClearShotFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

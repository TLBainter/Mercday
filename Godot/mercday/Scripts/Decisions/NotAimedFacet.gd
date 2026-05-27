class_name NotAimedFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if not merc.aim_active else 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> NotAimedFacet:
	var facet := NotAimedFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

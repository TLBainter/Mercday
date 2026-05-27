class_name NotMisfiredFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 0.0 if merc.weapon_misfired else 1.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> NotMisfiredFacet:
	var facet := NotMisfiredFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

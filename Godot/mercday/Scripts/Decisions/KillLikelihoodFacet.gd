class_name KillLikelihoodFacet extends DecisionFacet


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var mover = ctx.get("mover")
	if mover == null:
		return 0.0
	return CombatDecision._estimate_kill_likelihood(merc, mover)


static func create(p_weight: float = 1.0, p_required: bool = false) -> KillLikelihoodFacet:
	var facet := KillLikelihoodFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

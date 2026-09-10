class_name KillLikelihoodFacet extends DecisionFacet


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var mover = ctx.get("mover")
	if mover == null:
		return 0.0
	return CombatDecision._estimate_kill_likelihood(merc, mover)

class_name ShoveFeasibilityFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var target: MercenaryData = ctx.get("current_target")
	if target == null:
		return 0.0
	var size_delta := int(merc.stats.get("size", 1)) - int(target.stats.get("size", 1))
	return 0.0 if size_delta <= -3 else 1.0

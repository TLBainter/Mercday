class_name LastTargetFacet extends DecisionFacet


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state = ctx.get("state")
	var mover = ctx.get("mover")
	if state == null or mover == null:
		return 0.0
	return 1.0 if state.last_attacked.get(merc) == mover else 0.0

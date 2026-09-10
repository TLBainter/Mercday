class_name MovementNotBlockedFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 0.0 if ctx.get("movement_blocked", false) else 1.0

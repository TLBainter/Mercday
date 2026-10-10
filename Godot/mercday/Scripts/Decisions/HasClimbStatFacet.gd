class_name HasClimbStatFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if int(merc.stats.get("climb", 0)) > 0 else 0.0

class_name HasClimbStatFacet extends DecisionFacet

#Returns 1.0 if this merc has the Climb stat (dedicated climber), else 0.0.
func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if int(merc.stats.get("climb", 0)) > 0 else 0.0

class_name AimActiveFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if merc.aim_active else 0.0

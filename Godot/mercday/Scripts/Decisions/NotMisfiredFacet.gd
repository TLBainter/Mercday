class_name NotMisfiredFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 0.0 if merc.weapon_misfired else 1.0

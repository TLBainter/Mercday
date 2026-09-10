class_name AimActiveFacet extends DecisionFacet

@export var aimed_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if aimed_is_high == merc.aim_active else 0.0

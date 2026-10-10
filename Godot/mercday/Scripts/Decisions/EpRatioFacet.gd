class_name EpRatioFacet extends DecisionFacet

@export var threshold: float = 0.5

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var ratio: float = float(merc.current_ep) / maxf(1.0, float(merc.stats.get("maximum_endurance_points", 1)))
	return 1.0 if ratio >= threshold else 0.0

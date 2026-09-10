class_name EpRatioFacet extends DecisionFacet

@export var threshold: float = 0.5
@export var below_is_high: bool = false

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var ratio: float = float(merc.current_ep) / maxf(1.0, float(merc.stats.get("maximum_endurance_points", 1)))
	if below_is_high:
		return 1.0 if ratio < threshold else 0.0
	else:
		return 1.0 if ratio >= threshold else 0.0

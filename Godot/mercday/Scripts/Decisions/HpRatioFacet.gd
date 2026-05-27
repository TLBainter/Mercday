class_name HpRatioFacet extends DecisionFacet

@export var threshold: float = 0.5
@export var below_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var max_hp: float = float(merc.stats.get("maximum_hit_points", 1))
	if max_hp <= 0.0:
		max_hp = 1.0
	var ratio: float = float(merc.current_hp) / max_hp
	if below_is_high:
		return 1.0 if ratio < threshold else 0.0
	else:
		return 1.0 if ratio >= threshold else 0.0

static func create(p_threshold: float, p_below_is_high: bool, p_weight: float = 1.0, p_required: bool = false) -> HpRatioFacet:
	var facet := HpRatioFacet.new()
	facet.threshold = p_threshold
	facet.below_is_high = p_below_is_high
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

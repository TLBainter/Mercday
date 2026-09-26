class_name HpRatioFacet extends DecisionFacet

@export var below_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var max_hp: float = float(merc.stats.get("maximum_hit_points", 1))
	max_hp = max(1.0, max_hp)
	var ratio: float = float(merc.current_hp) / max_hp
	if below_is_high:
		#1.0 when critically injured, 0.0 at full HP
		return 1.0 - ratio
	else:
		#1.0 at full HP, 0.0 when at 0 HP
		return ratio

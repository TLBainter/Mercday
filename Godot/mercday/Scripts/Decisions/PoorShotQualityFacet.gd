class_name PoorShotQualityFacet extends DecisionFacet

@export var accuracy_threshold: float = 30.0

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return 0.0
	var acc: float = float(merc.stats.get("ranged_accuracy", 0))
	return 1.0 if acc < accuracy_threshold else 0.0

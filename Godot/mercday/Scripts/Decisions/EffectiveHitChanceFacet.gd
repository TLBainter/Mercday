class_name EffectiveHitChanceFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var targets: Array = ctx.get("valid_targets", [])
	if targets.is_empty():
		return 0.0
	var base_acc: float = float(merc.stats.get("ranged_accuracy", 0))
	if base_acc <= 0.0:
		return 0.0
	var effective := base_acc
	if ConstStates.has_state(merc, ConstStates.THREATENED):
		effective -= 30.0
	return clampf(effective / base_acc, 0.0, 1.0)

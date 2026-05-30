class_name NoValidAttackTargetsFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 1.0 if ctx.get("valid_targets", []).is_empty() else 0.0

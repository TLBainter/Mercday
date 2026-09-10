class_name EnemiesExistFacet extends DecisionFacet

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 1.0 if not ctx.get("enemies", []).is_empty() else 0.0

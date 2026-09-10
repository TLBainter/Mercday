class_name RangedEnemyFacet extends DecisionFacet


func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	return 0.0 if DecisionFacet.ranged_enemies_in(ctx).is_empty() else 1.0

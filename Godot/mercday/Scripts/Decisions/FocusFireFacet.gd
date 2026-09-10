class_name FocusFireFacet extends DecisionFacet


func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var enemy_count: int = ctx.get("enemies", []).size()
	if enemy_count <= 0:
		return 0.0
	return 1.0 / float(enemy_count)

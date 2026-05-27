class_name FocusFireFacet extends DecisionFacet


func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var enemy_count: int = ctx.get("enemies", []).size()
	if enemy_count <= 0:
		return 0.0
	return 1.0 / float(enemy_count)


static func create(p_weight: float = 1.0, p_required: bool = false) -> FocusFireFacet:
	var facet := FocusFireFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

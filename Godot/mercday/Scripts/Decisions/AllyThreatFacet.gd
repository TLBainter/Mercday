class_name AllyThreatFacet extends DecisionFacet

@export var hp_threshold: float = 0.33


func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var allies: Array = ctx.get("allies", [])
	if allies.is_empty():
		return 0.0
	for ally in allies:
		var ratio := float(ally.current_hp) / float(ally.stats.get("maximum_hit_points", 1))
		if ratio <= hp_threshold:
			return 1.0
	return 0.0


static func create(p_hp_threshold: float = 0.33, p_weight: float = 1.0, p_required: bool = false) -> AllyThreatFacet:
	var facet := AllyThreatFacet.new()
	facet.hp_threshold = p_hp_threshold
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

class_name RangedEnemyFacet extends DecisionFacet


func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	for enemy in ctx.get("enemies", []):
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return 1.0
	return 0.0


static func create(p_weight: float = 1.0, p_required: bool = false) -> RangedEnemyFacet:
	var facet := RangedEnemyFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

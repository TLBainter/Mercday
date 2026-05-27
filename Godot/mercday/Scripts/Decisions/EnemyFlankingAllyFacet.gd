class_name EnemyFlankingAllyFacet extends DecisionFacet

## Scores 1.0 if the current target is adjacent to a flanked ally — shoving them could break the flanking.
func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var target: MercenaryData = ctx.get("current_target")
	if target == null:
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null:
		return 0.0
	for ally: MercenaryData in ctx.get("allies", []):
		if ConstStates.has_state(ally, ConstStates.FLANKED):
			if state.distance_to(target, ally) <= 1:
				return 1.0
	return 0.0


static func create(p_weight: float = 1.0, p_required: bool = false) -> EnemyFlankingAllyFacet:
	var facet := EnemyFlankingAllyFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

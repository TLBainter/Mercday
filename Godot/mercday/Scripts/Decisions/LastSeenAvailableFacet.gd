class_name LastSeenAvailableFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var last: MercenaryData = merc.active_states.get("last_target") as MercenaryData
	if last == null:
		return 0.0
	for enemy: MercenaryData in ctx.get("enemies", []):
		if enemy == last and BattleState._is_alive(enemy):
			return 1.0
	return 0.0

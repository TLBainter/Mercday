class_name CanStartClimbFacet extends DecisionFacet

#Returns 1.0 if this merc can initiate a climb right now.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	if int(merc.stats.get("size", 0)) <= 0:
		return 0.0
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	return 0.0 if ClimbAction.find_target(merc, state).is_empty() else 1.0

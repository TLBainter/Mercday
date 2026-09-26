class_name AdvantageThreatFacet extends DecisionFacet

#1.0 when stepping off this cell would draw an Advantage Attack and the merc can still step away.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or merc.advantage_immune:
		return 0.0
	if ConstStates.is_blocked(merc, "action:move") or MovementExecutor.pace_per_move(merc) == 0:
		return 0.0
	return 1.0 if FleeSystem.in_danger(merc, state) else 0.0

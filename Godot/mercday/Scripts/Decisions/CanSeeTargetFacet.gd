class_name CanSeeTargetFacet extends DecisionFacet

#1.0 when the mover cannot see its target now but a cell within pace can.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state") as BattleState
	if state == null or state.battlefield == null:
		return 0.0
	var target: MercenaryData = ctx.get("current_target") as MercenaryData
	if target == null:
		for e: MercenaryData in ctx.get("valid_targets", []):
			target = e
			break
	if target == null:
		target = MovementDecider.nearest_enemy(merc, ctx.get("enemies", []), state)["merc"]
	if target == null:
		return 0.0
	if LineOfSight.check(state, merc, target)["visible"] as bool:
		return 0.0
	var pace := MovementDecider.sight_pace(merc, state, int(ctx.get("attack_base_ap", 3)))
	var merc_size: int = merc.unit_size()
	var reach: Dictionary = ReachCache.reachable_for(merc, state)
	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		if cost <= 0 or cost > pace:
			continue
		if LineOfSight.check_from(state, cell, 0, merc_size, target)["visible"] as bool:
			return 1.0
	return 0.0

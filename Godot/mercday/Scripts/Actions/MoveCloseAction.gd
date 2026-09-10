class_name MoveCloseAction extends ActionData

func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var state: BattleState = ctx["state"]
	var result := super.to_decision_dict(merc, ctx)
	#Move Close walks toward the move target, not the nearest enemy the base class picks.
	result["target"] = TargetSelector.pick_move_target(merc, ctx, state)
	if ctx.get("seeking_mode", false):
		result["seeking"] = true
	return result

class_name MoveCloseAction extends ActionData

func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var state: BattleState = ctx["state"]
	var result := {
		"type": execution_type,
		"action_name": action_name,
		"target": TargetSelector.pick_move_target(merc, ctx, state),
		"flank_ally": null,
	}
	if ctx.get("seeking_mode", false):
		result["seeking"] = true
	return result

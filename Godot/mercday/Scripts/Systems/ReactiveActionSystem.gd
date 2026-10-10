class_name ReactiveActionSystem


static func get_triggered_reactions(
		trigger: String,
		mover: MercenaryData,
		old_pos: Vector2i,
		new_pos: Vector2i,
		state: BattleState) -> Array:
	var result := []
	if RescueSystem.shelters(state, mover):
		return result
	for reactor: MercenaryData in state.get_enemies(mover):
		if not BattleState._is_alive(reactor):
			continue
		if reactor.action_set == null:
			continue
		var ctx := {
			"mover": mover,
			"old_pos": old_pos,
			"new_pos": new_pos,
			"state": state,
			"allies": state.get_allies(reactor),
			"enemies": state.get_enemies(reactor),
			"valid_targets": [],
			"current_target": mover,
			"movement_blocked": false,
			"attack_base_ap": AutoBattle.ATTACK_BASE_AP,
			"move_base_ap": AutoBattle.MOVE_BASE_AP,
		}
		for action: ActionData in reactor.action_set.actions:
			if not action.is_reactive or action.trigger != trigger:
				continue
			if ExcessPool.available_ep(reactor) < action.ep_cost:
				continue
			if not action.can_execute(reactor, ctx):
				continue
			var score := action.decision.evaluate(reactor, ctx)
			if score >= action.decision.threshold:
				result.append({"reactor": reactor, "reaction": action})
	return result

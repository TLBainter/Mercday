class_name ReactiveActionSystem


class ReactiveActionDef extends RefCounted:
	var name: String
	var ep_cost: int
	var trigger: String  # event name, e.g. "enemy_leaves_melee_range"

	func _init(n: String, cost: int, t: String) -> void:
		name = n
		ep_cost = cost
		trigger = t


static var _default_reactions: Array = []


static func _ensure_defaults() -> void:
	if not _default_reactions.is_empty():
		return
	_default_reactions.append(ReactiveActionDef.new("Advantage Attack", 1, "enemy_leaves_melee_range"))


static func get_default_reactions() -> Array:
	_ensure_defaults()
	return _default_reactions

static func get_triggered_reactions(
		trigger: String,
		mover: MercenaryData,
		old_pos: Vector2i,
		new_pos: Vector2i,
		state: BattleState) -> Array:
	var result := []
	for reactor: MercenaryData in state.get_enemies(mover):
		if not BattleState._is_alive(reactor):
			continue
		if reactor.action_set == null:
			continue
		for action: ActionData in reactor.action_set.actions:
			if not action.is_reactive or action.trigger != trigger:
				continue
			if reactor.current_ep < action.ep_cost:
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
				"attack_base_ap": 3,
				"move_base_ap": 2,
			}
			if not action.can_execute(reactor, ctx):
				continue
			var score := action.decision.evaluate(reactor, ctx)
			if score >= action.decision.threshold:
				result.append({"reactor": reactor, "reaction": action})
	return result


static func _check_condition(
		reaction_name: String,
		reactor: MercenaryData,
		mover: MercenaryData,
		old_pos: Vector2i,
		new_pos: Vector2i,
		state: BattleState) -> bool:
	match reaction_name:
		"Advantage Attack":
			var weapon := reactor.equipped_weapon
			if weapon == null or weapon.is_ranged:
				return false
			var reactor_pos := state.get_position(reactor)
			var dz := absi(state.get_height(reactor) - state.get_height(mover))
			var old_dist := maxi(maxi(abs(reactor_pos.x - old_pos.x), abs(reactor_pos.y - old_pos.y)), dz)
			var new_dist := maxi(maxi(abs(reactor_pos.x - new_pos.x), abs(reactor_pos.y - new_pos.y)), dz)
			var effective_range := WeaponArmorPerkLibrary.get_effective_melee_range(reactor)
			return old_dist <= effective_range and new_dist > effective_range
	return false

class_name ActionData extends Resource

@export var action_name: String = ""
@export var enabled: bool = true
@export var ap_cost: int = 0
@export var ep_cost: int = 0
@export_enum("fixed", "attack_base", "move_base") var ap_cost_mode: String = "fixed"
@export var priority: int = 99
@export var is_reactive: bool = false
@export var trigger: String = ""
@export_enum("pass", "special", "attack", "move", "draw", "climb", "jump") var execution_type: String = "special"
@export_enum("none", "current_or_best", "nearest_enemy", "nearest_ally", "mover", "strategic_advance") var target_mode: String = "none"
@export var move_stop_dist: int = -1  ## -1 = auto (stops at weapon range); >=0 overrides stop distance
@export var draw_from_inventory: bool = false
@export var snap_require: Dictionary = {}
@export var decision: DecisionData


func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not enabled:
		return false
	var state: BattleState = ctx["state"]
	var base_cost := ap_cost
	match ap_cost_mode:
		"attack_base":
			base_cost = ctx.get("attack_base_ap", ap_cost)
		"move_base":
			base_cost = ctx.get("move_base_ap", ap_cost)
	var afford := false
	if ap_cost_mode == "move_base":
		afford = state.can_afford(merc, state.move_cost(merc, action_name, base_cost))
	else:
		afford = state.can_afford(merc, state.get_cost(merc, action_name, base_cost))
	if not afford:
		return false
	#A walk onto the cell a planned climb or leap already owns buys nothing, so it yields the slot.
	if execution_type == "move" or action_name == "withdraw":
		return not MovementExecutor.move_yields(merc, state, action_name)
	return true


func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := {
		"type": execution_type,
		"action_name": action_name,
		"target": _resolve_target(merc, ctx)
	}
	if execution_type == "move":
		result["flank_ally"] = null
		if move_stop_dist >= 0:
			result["move_stop_dist"] = move_stop_dist
		_add_move_plan(result, merc, ctx)
	if draw_from_inventory:
		result["weapon"] = _resolve_draw_weapon(merc)
	return result


#The Moves this walk may buy and the AP it holds back, priced as the movement decider prices them.
static func _add_move_plan(result: Dictionary, merc: MercenaryData, ctx: Dictionary) -> void:
	var state: BattleState = ctx.get("state")
	if state == null:
		return
	var plan: Dictionary = MovementDecider.plan_moves(merc, ctx.get("enemies", []), state)
	result["moves_allowed"] = int(plan["moves_allowed"])
	result["reserve_ap"] = int(plan["reserve_ap"])


func _resolve_target(merc: MercenaryData, ctx: Dictionary) -> MercenaryData:
	match target_mode:
		"current_or_best":
			var valid: Array = ctx.get("valid_targets", [])
			var cur = ctx.get("current_target")
			if cur != null and valid.has(cur) and not FleeSystem.has_better_quarry(cur, valid, ctx["state"]):
				return cur
			return TargetSelector.pick_target(merc, valid, ctx["state"])
		"nearest_enemy":
			var state: BattleState = ctx["state"]
			var nearest: MercenaryData = null
			var best_score := INF
			for enemy: MercenaryData in ctx.get("enemies", []):
				var d := state.distance_to(merc, enemy)
				var max_hp: float = float(enemy.stats.get("maximum_hit_points", 1))
				var hp_ratio := clampf(float(enemy.current_hp) / max_hp, 0.0, 1.0)
				var score := d - (1.0 - hp_ratio)
				if score < best_score:
					best_score = score
					nearest = enemy
			return nearest
		"nearest_ally":
			var state: BattleState = ctx["state"]
			var nearest_ally: MercenaryData = null
			var best_d := INF
			for ally: MercenaryData in ctx.get("allies", []):
				var d := float(state.distance_to(merc, ally))
				if d < best_d:
					best_d = d
					nearest_ally = ally
			return nearest_ally
		"mover":
			return ctx.get("mover")
		"strategic_advance":
			#Priority order: an ally in danger with an adjacent enemy, then the nearest enemy, then the ally closest to any enemy.
			var state: BattleState = ctx["state"]
			var enemies: Array = ctx.get("enemies", [])
			var allies: Array = ctx.get("allies", [])
			for ally: MercenaryData in allies:
				var max_hp := int(ally.stats.get("maximum_hit_points", 1))
				if float(ally.current_hp) / float(max_hp) <= 0.30:
					for enemy: MercenaryData in enemies:
						if state.distance_to(ally, enemy) <= 1:
							return ally
			var nearest: MercenaryData = null
			var best_d := INF
			for enemy: MercenaryData in enemies:
				var d := float(state.distance_to(merc, enemy))
				if d < best_d:
					best_d = d
					nearest = enemy
			if nearest != null:
				return nearest
			var best_ally: MercenaryData = null
			var best_ally_d := INF
			for ally: MercenaryData in allies:
				for enemy: MercenaryData in enemies:
					var d := float(state.distance_to(ally, enemy))
					if d < best_ally_d:
						best_ally_d = d
						best_ally = ally
			return best_ally
	return null


func _resolve_draw_weapon(merc: MercenaryData) -> WeaponData:
	if merc.equipped_weapon != null:
		return merc.equipped_weapon
	for entry in merc.inventory:
		if entry.get("type") == "weapon":
			return entry.get("data")
	return null

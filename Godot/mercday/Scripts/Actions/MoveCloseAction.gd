class_name MoveCloseAction extends ActionData

func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := {
		"type": execution_type,
		"action_name": action_name,
		"target": null,
		"flank_ally": null,
	}
	if ctx.get("seeking_mode", false):
		result["seeking"] = true

	var state: BattleState = ctx["state"]
	var blocked: Dictionary = ctx.get("blocked_targets", {})
	var enemies: Array = ctx.get("enemies", [])
	# Exclude enemies already proven unreachable this turn; fall back to all if every enemy is blocked.
	var candidates: Array = enemies.filter(func(e: MercenaryData) -> bool: return not blocked.has(e))
	if candidates.is_empty():
		candidates = enemies

	var valid: Array = ctx.get("valid_targets", [])
	if not valid.is_empty():
		var nearest: MercenaryData = null
		var best_score := INF
		for enemy: MercenaryData in candidates:
			var d := state.distance_to(merc, enemy)
			var max_hp: float = float(enemy.stats.get("maximum_hit_points", 1))
			var hp_ratio := clampf(float(enemy.current_hp) / max_hp, 0.0, 1.0)
			var score := d - (1.0 - hp_ratio)
			if score < best_score:
				best_score = score
				nearest = enemy
		result["target"] = nearest
		return result

	# No in-range enemies -- prefer last_seen_position (specific tracked target) then last known

	if merc.last_seen_position != Vector2i(-1, -1) and state.battlefield != null and not candidates.is_empty():
		var best_enemy: MercenaryData = null
		var best_dist := INF
		for enemy: MercenaryData in candidates:
			var epos := state.get_position(enemy)
			var d := float(maxi(
				absi(merc.last_seen_position.x - epos.x),
				absi(merc.last_seen_position.y - epos.y)))
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
		if best_enemy != null:
			result["target"] = best_enemy
			return result

	if not merc.last_known_enemy_positions.is_empty() and state.battlefield != null:
		var merc_pos := state.get_position(merc)
		var best_dist := INF
		var best_enemy: MercenaryData = null
		for enemy: MercenaryData in merc.last_known_enemy_positions.keys():
			if not candidates.has(enemy):
				continue
			var known_pos: Vector2i = merc.last_known_enemy_positions[enemy]
			var d := float(maxi(absi(known_pos.x - merc_pos.x), absi(known_pos.y - merc_pos.y)))
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
		if best_enemy != null:
			result["target"] = best_enemy
			return result

	# Fallback: nearest unblocked enemy
	if not candidates.is_empty():
		var nearest: MercenaryData = null
		var best_score := INF
		for enemy: MercenaryData in candidates:
			var d := float(state.distance_to(merc, enemy))
			if d < best_score:
				best_score = d
				nearest = enemy
		result["target"] = nearest

	return result

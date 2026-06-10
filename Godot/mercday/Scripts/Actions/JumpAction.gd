class_name JumpAction extends ActionData

func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not super.can_execute(merc, ctx):
		return false
	if int(merc.stats.get("jump", 0)) <= 0:
		return false
	return _find_best_jump_target(merc, ctx) != Vector2i(-1, -1)

func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := super.to_decision_dict(merc, ctx)
	result["jump_target_pos"] = _find_best_jump_target(merc, ctx)
	return result

func _find_best_jump_target(merc: MercenaryData, ctx: Dictionary) -> Vector2i:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return Vector2i(-1, -1)

	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return Vector2i(-1, -1)

	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return Vector2i(-1, -1)

	var jump_stat := int(merc.stats.get("jump", 0))
	var merc_h := field.get_terrain_height(merc_pos)

	# Find nearest enemy as jump target
	var nearest_enemy: MercenaryData = null
	var nearest_dist := INF
	for enemy: MercenaryData in enemies:
		var epos := state.get_position(enemy)
		var d := float(maxi(abs(merc_pos.x - epos.x), abs(merc_pos.y - epos.y)))
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = enemy
	if nearest_enemy == null:
		return Vector2i(-1, -1)

	var target_pos := state.get_position(nearest_enemy)
	var current_dist := maxi(abs(merc_pos.x - target_pos.x), abs(merc_pos.y - target_pos.y))

	var best_cell := Vector2i(-1, -1)
	var best_dist := current_dist  # must improve on current position

	for dx: int in range(-jump_stat, jump_stat + 1):
		for dy: int in range(-jump_stat, jump_stat + 1):
			var chebyshev := maxi(abs(dx), abs(dy))
			if chebyshev == 0 or chebyshev > jump_stat:
				continue
			var cell := merc_pos + Vector2i(dx, dy)
			if not PathCost.is_valid_jump_dest(cell, field):
				continue
			if state.is_position_occupied(cell, merc):
				continue
			# Upward height costs jump budget; going down is free
			var h_diff := field.get_terrain_height(cell) - merc_h
			var height_cost := int(ceil(maxf(0.0, h_diff)))
			if chebyshev + height_cost > jump_stat:
				continue
			if not Pathfinder.find_path(merc_pos, cell, field).is_empty():
				continue
			var dist := maxi(abs(cell.x - target_pos.x), abs(cell.y - target_pos.y))
			if dist < best_dist:
				best_dist = dist
				best_cell = cell

	return best_cell

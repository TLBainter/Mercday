class_name ShoveInsteadOfDamageFacet extends DecisionFacet

const _SHOVE_PACES := 1


#Scores a single-pace shove of the current target: terrain drop, cover break, flanking, Deposed setup.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var target: MercenaryData = ctx.get("current_target")
	if target == null:
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0

	var field: BattlefieldArea = state.battlefield
	var shover_size := int(merc.stats.get("size", 1))
	var shoved_size := int(target.stats.get("size", 1))
	var target_pos := state.get_position(target)
	var shover_pos := state.get_position(merc)
	var dir := Vector2i(signi(target_pos.x - shover_pos.x), signi(target_pos.y - shover_pos.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)

	var dest := field.clamp_position(target_pos + dir * _SHOVE_PACES)
	var target_floor := state.get_floor(target)
	if dest == target_pos:
		return 0.0
	var obs := field.get_obs(dest, target_floor)
	if not obs.is_empty():
		var od: ObstacleData = obs.get("data") as ObstacleData
		if od == null or not od.passthrough:
			return 0.0
	if state.is_position_occupied(dest, target, target_floor):
		return 0.0
	var dest3 := Vector3i(dest.x, dest.y, target_floor)
	var allies: Array = ctx.get("allies", [])
	var score := ShoveOutcomeFacet.terrain_drop_score(field, target_pos, dest)
	score += ShoveOutcomeFacet.cover_break_score(state, target, allies, dest3, shoved_size)
	score += ShoveOutcomeFacet.flank_bonus(state, allies, dest)
	score += ShoveOutcomeFacet.deposed_setup_score(merc, target, state, allies, dest, shover_size,
			shoved_size)
	return clampf(score, 0.0, 1.0)

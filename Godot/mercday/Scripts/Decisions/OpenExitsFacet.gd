class_name OpenExitsFacet extends DecisionFacet

#Returns low score when the merc's retreat direction leads into a map corner.
#Penalises Move Far when continuing to back away would box the merc in.

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 1.0
	var pos := state.get_position(merc)
	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return 1.0

	var nearest_enemy_pos := pos
	var nearest: MercenaryData = MovementDecider.nearest_enemy(merc, enemies, state, -1, true)["merc"]
	if nearest != null:
		nearest_enemy_pos = state.get_position(nearest)

	var to_enemy := Vector2(float(nearest_enemy_pos.x - pos.x), float(nearest_enemy_pos.y - pos.y))
	if to_enemy.length_squared() == 0.0:
		return 1.0
	var retreat_dir := -to_enemy.normalized()

	var bf := state.battlefield
	var look_ahead := 4
	var open_cells := 0
	for i in range(1, look_ahead + 1):
		var cx := pos.x + roundi(retreat_dir.x * float(i))
		var cy := pos.y + roundi(retreat_dir.y * float(i))
		if bf.in_bounds_xy(cx, cy):
			open_cells += 1
		else:
			break

	return clampf(float(open_cells) / float(look_ahead), 0.0, 1.0)

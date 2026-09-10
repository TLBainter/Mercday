class_name CanStartClimbFacet extends DecisionFacet

# Returns 1.0 if this merc can initiate a climb right now:
# - Size >= 1 (can grab)
# - Not already CLIMBING
# - At least one adjacent tile has terrain h_diff > 0.5 and is unoccupied by an enemy
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	if int(merc.stats.get("size", 0)) <= 0:
		return 0.0
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return 0.0
	var merc_h := field.get_terrain_height(merc_pos)
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for d: Vector2i in dirs:
		var nb := merc_pos + d
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		if field.get_terrain_height(nb) - merc_h > 0.5 and not state.is_position_occupied(nb, merc, state.get_floor(merc)):
			return 1.0
	return 0.0

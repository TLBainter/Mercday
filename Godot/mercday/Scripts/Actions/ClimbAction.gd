class_name ClimbAction extends ActionData


func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not super.can_execute(merc, ctx):
		return false
	var state: BattleState = ctx.get("state")
	if state == null:
		return false
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return not _is_climb_complete(merc, state)
	# Initiation: size must allow grabbing, and a valid steep tile must exist nearby
	if int(merc.stats.get("size", 0)) <= 0:
		return false
	return _find_climb_target(merc, state) != Vector2i(-1, -1)


func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := super.to_decision_dict(merc, ctx)
	var state: BattleState = ctx.get("state")
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		result["climb_continuing"] = true
	else:
		result["climb_target_pos"] = _find_climb_target(merc, state)
	return result


# Returns first adjacent tile where the merc could start climbing (h_diff > 0.5, not occupied by enemy).
func _find_climb_target(merc: MercenaryData, state: BattleState) -> Vector2i:
	if state == null or state.battlefield == null:
		return Vector2i(-1, -1)
	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var merc_h := field.get_terrain_height(merc_pos)
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for d: Vector2i in dirs:
		var nb := merc_pos + d
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		var h_diff := field.get_terrain_height(nb) - merc_h
		if h_diff <= 0.5:
			continue
		# Don't grab onto a tile occupied by an enemy
		if state.is_position_occupied(nb, merc):
			continue
		return nb
	return Vector2i(-1, -1)


func _is_climb_complete(merc: MercenaryData, state: BattleState) -> bool:
	var cd := state.get_climbing_data(merc)
	return int(cd.get("current_h", 0)) >= int(cd.get("target_h", 0))

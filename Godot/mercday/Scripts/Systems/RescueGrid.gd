class_name RescueGrid extends RefCounted

#Cell geometry and sight queries the rescue scripts share.


static func cell_free(field: BattlefieldArea, state: BattleState, cell: Vector3i,
		exclude: MercenaryData) -> bool:
	if field == null:
		return false
	var flat := Vector2i(cell.x, cell.y)
	if not field.has_walkable_surface(flat, cell.z):
		return false
	if not field.get_obs(flat, cell.z).is_empty():
		return false
	if state != null and state.is_position_occupied(flat, exclude, cell.z):
		return false
	return true


static func free_cells(field: BattlefieldArea, state: BattleState, rect: Rect2i, f: int,
		exclude: MercenaryData) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		for y: int in range(rect.position.y, rect.position.y + rect.size.y):
			var cell := Vector3i(x, y, f)
			if cell_free(field, state, cell, exclude):
				out.append(cell)
	return out


static func adjacent_free_cell(state: BattleState, target: Vector3i, merc: MercenaryData) -> Vector3i:
	return RescueSystem.best_free_cell(state, target, merc)


#Free cell beside the gate, outside the cell itself, nearest the merc.
static func approach_cell(merc: MercenaryData, state: BattleState) -> Vector3i:
	var target: Vector3i = RescueSystem.free_target_cell(state)
	if target == PathTargeter.NO_CELL:
		return PathTargeter.NO_CELL
	return RescueSystem.best_free_cell(state, target, merc, state.rescue["cell_rect"] as Rect2i)


static func is_adjacent(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return false
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


static func cell_seers(state: BattleState, cell: Vector3i, merc: MercenaryData) -> Dictionary:
	var out: Dictionary = {}
	var p_size: int = maxi(1, int(merc.stats.get("size", 1)))
	for enemy: MercenaryData in RescueSystem.enemy_team(state):
		if not BattleState._is_alive(enemy):
			continue
		if bool(LineOfSight.check_cell(state, enemy, cell, p_size).get("visible", false)):
			out[enemy] = true
	return out

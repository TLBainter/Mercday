class_name RescueGrid extends RefCounted

#Cell geometry and sight queries the rescue scripts share.

const FLOOR_PENALTY := 8


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


#Free cell beside the gate, outside the cell itself, nearest the merc.
static func approach_cell(merc: MercenaryData, state: BattleState) -> Vector3i:
	var target: Vector3i = RescueSystem.free_target_cell(state)
	if target == PathTargeter.NO_CELL:
		return PathTargeter.NO_CELL
	return RescueGrid.adjacent_free_cell(state, target, merc, state.rescue["cell_rect"] as Rect2i)


#True when both cells share a floor and lie within r cells of each other on both axes.
static func near(a: Vector3i, b: Vector3i, r: int) -> bool:
	return a.z == b.z and maxi(absi(a.x - b.x), absi(a.y - b.y)) <= r


static func is_adjacent(a: Vector3i, b: Vector3i) -> bool:
	return near(a, b, 1)


#Distance in cells along the longer axis, plus a penalty for every floor between the cells.
static func spread(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) + absi(a.z - b.z) * FLOOR_PENALTY


static func cell_seers(state: BattleState, cell: Vector3i, merc: MercenaryData) -> Dictionary:
	var out: Dictionary = {}
	var p_size: int = merc.unit_size()
	for enemy: MercenaryData in RescueSystem.enemy_team(state):
		if not BattleState._is_alive(enemy):
			continue
		if bool(LineOfSight.check_cell(state, enemy, cell, p_size).get("visible", false)):
			out[enemy] = true
	return out


#Free neighbour of the target nearest the merc, skipping the avoid rect; NO_CELL when the ring is shut.
static func adjacent_free_cell(state: BattleState, target: Vector3i, merc: MercenaryData,
		avoid: Rect2i = Rect2i()) -> Vector3i:
	var own: Vector3i = state.pos3(merc)
	var best: Vector3i = PathTargeter.NO_CELL
	var best_dist: int = 1 << 24
	for d: Vector2i in PathCost.DIRS8:
		var cell := Vector3i(target.x + d.x, target.y + d.y, target.z)
		if avoid.size.x > 0 and avoid.has_point(Vector2i(cell.x, cell.y)):
			continue
		if not RescueGrid.cell_free(state.battlefield, state, cell, merc):
			continue
		var dist: int = RescueGrid.spread(cell, own)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best

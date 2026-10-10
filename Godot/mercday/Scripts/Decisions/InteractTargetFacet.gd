class_name InteractTargetFacet extends DecisionFacet

const INTERACT_AP := 2


#The cell the merc would interact with this turn, or PathTargeter.NO_CELL.
#Priority: the door the traversal stopped in front of, then the rescue gate, then
#any adjacent closed door that lies on the route the mover is already following.
static func find_target(merc: MercenaryData, state: BattleState) -> Vector3i:
	var field := state.battlefield
	if field == null:
		return PathTargeter.NO_CELL
	PathCost.set_mover_doors(merc, state)
	var pos := state.pos3(merc)
	var pending: Vector3i = state.pending_interact.get(merc, PathTargeter.NO_CELL) as Vector3i
	if pending != PathTargeter.NO_CELL and _adjacent(pos, pending) and PathCost.is_shut_door(field, pending):
		return pending
	var gate: Vector3i = RescueSystem.gate_target(merc, state)
	if gate != PathTargeter.NO_CELL:
		return gate
	var on_path: Dictionary = {}
	for cell: Vector3i in MovementExecutor.turn_path(merc):
		on_path[cell] = true
	if on_path.is_empty():
		return PathTargeter.NO_CELL
	for d: Vector2i in PathCost.DIRS8:
		var nb := Vector3i(pos.x + d.x, pos.y + d.y, pos.z)
		if not on_path.has(nb):
			continue
		if PathCost.is_shut_door(field, nb):
			return nb
	return PathTargeter.NO_CELL


static func _adjacent(a: Vector3i, b: Vector3i) -> bool:
	return a.z == b.z and maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	if not state.can_afford(merc, state.get_cost(merc, "Interact", INTERACT_AP)):
		return 0.0
	if InteractTargetFacet.find_target(merc, state) == PathTargeter.NO_CELL:
		return 0.0
	return 1.0

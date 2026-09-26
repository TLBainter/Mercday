class_name ClimbAction extends ActionData

#Last climb picked by can_execute; to_decision_dict reads it back so the search runs once.
var _climb_found: Dictionary = {}


func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not super.can_execute(merc, ctx):
		return false
	var state: BattleState = ctx.get("state")
	if state == null:
		return false
	var pace_c := MovementExecutor.climb_pace_cost(merc)
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		if _is_climb_complete(merc, state):
			return false
		return MovementExecutor.can_fund_climb(merc, state, action_name, pace_c)
	#Starting a climb needs a size that can grab and a steep tile nearby.
	if int(merc.stats.get("size", 0)) <= 0:
		return false
	_climb_found = find_target(merc, state)
	if _climb_found.is_empty():
		return false
	var grab := maxi(1, int(merc.stats.get("size", 0)))
	return MovementExecutor.can_fund_climb(merc, state, action_name, grab * pace_c)


func to_decision_dict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var result := super.to_decision_dict(merc, ctx)
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		result["climb_continuing"] = true
	else:
		result["climb_target_pos"] = _climb_found.get("pos", Vector2i(-1, -1)) as Vector2i
		var link: Dictionary = _climb_found.get("link", {}) as Dictionary
		if not link.is_empty():
			result["climb_link"] = link
			result["climb_down"] = bool(_climb_found.get("down", false))
	return result


#The climb this merc would start now: {} for none, else {pos, link, down}; link is empty for terrain.
static func find_target(merc: MercenaryData, state: BattleState) -> Dictionary:
	if state == null or state.battlefield == null:
		return {}
	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return {}
	var cell := Vector3i(merc_pos.x, merc_pos.y, state.get_floor(merc))
	var routed: Dictionary = _route_target(merc, state, field, cell)
	if not routed.is_empty():
		return routed
	if field.climb_links.has(cell):
		var up := _link_up(merc, state, field, cell)
		if not up.is_empty():
			var top: Vector3i = up["top"] as Vector3i
			return {"pos": Vector2i(top.x, top.y), "link": up, "down": false}
	if field.drop_links.has(cell):
		var down := _link_down(merc, state, field, cell)
		if not down.is_empty():
			var to: Vector3i = down["to"] as Vector3i
			return {"pos": Vector2i(to.x, to.y), "link": down, "down": true}
	var pick := _find_climb_target(merc, state)
	if pick == Vector2i(-1, -1):
		return {}
	return {"pos": pick, "link": {}, "down": false}


#The climb a route stopped this walker at the foot of: {} when none stands, the link is gone or the
#landing is taken. It outranks the nearest-enemy tests because the route already weighed the trip.
static func _route_target(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		cell: Vector3i) -> Dictionary:
	var row: Dictionary = state.climb_route(merc)
	if row.is_empty():
		return {}
	if state.is_sunk(merc) or PathTargeter.is_flying(merc):
		return {}
	var link: Dictionary = row["link"] as Dictionary
	if link.is_empty():
		return {}
	var merc_size := maxi(1, int(merc.stats.get("size", 1)))
	if not _vault_ok(link, field, merc_size):
		return {}
	var down: bool = bool(row["down"])
	var end: Vector3i = (link["to"] if down else link["top"]) as Vector3i
	if down:
		if PathCost.drop_link(cell, end, field).is_empty():
			return {}
	elif PathCost.climb_link(cell, end, field).is_empty():
		return {}
	if state.is_position_occupied(Vector2i(end.x, end.y), merc, end.z):
		return {}
	return {"pos": Vector2i(end.x, end.y), "link": link, "down": down}


#Nearest enemy by 2D Chebyshev distance from pos: {"merc", "dist"}; dist is huge when none is left.
static func _nearest_enemy(merc: MercenaryData, state: BattleState, pos: Vector2i) -> Dictionary:
	var best: MercenaryData = null
	var best_d: int = 1 << 30
	for enemy: MercenaryData in state.get_enemies(merc):
		var epos := state.get_position(enemy)
		if epos == Vector2i(-1, -1):
			continue
		var d := maxi(abs(pos.x - epos.x), abs(pos.y - epos.y))
		if d < best_d:
			best_d = d
			best = enemy
	return {"merc": best, "dist": best_d}


#True when the link's vault cell is absent or low enough for this climber to cross.
static func _vault_ok(link: Dictionary, field: BattlefieldArea, merc_size: int) -> bool:
	var vault: Vector3i = link["vault"] as Vector3i
	if vault.x < 0:
		return true
	var obs: Dictionary = field.get_obs(Vector2i(vault.x, vault.y), vault.z)
	return obs.is_empty() or PathCost.can_vault(obs, merc_size)


#The climb link out of cell this merc wants to take up, fewest paces first; {} for none.
static func _link_up(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		cell: Vector3i) -> Dictionary:
	if state.is_sunk(merc) or PathTargeter.is_flying(merc):
		return {}
	var links: Array = field.climb_links_at(cell)
	if links.is_empty():
		return {}
	var cell2 := Vector2i(cell.x, cell.y)
	var near := _nearest_enemy(merc, state, cell2)
	var foe: MercenaryData = near["merc"] as MercenaryData
	var foe_floor: int = state.get_floor(foe) if foe != null else cell.z
	var foe_high: bool = foe != null and foe_floor > cell.z
	var foe_roof: bool = foe != null and field.is_roof_footing(state.get_position(foe), foe_floor)
	#The one roof link the post score picked for this unit this turn; (-1,-1,-1) when it wants none.
	var post_top: Vector3i = RoofPostScore.post_top(merc, state)
	var merc_size := maxi(1, int(merc.stats.get("size", 1)))
	var best: Dictionary = {}
	for link: Dictionary in links:
		var kind: String = String(link["kind"])
		var top: Vector3i = link["top"] as Vector3i
		var wanted: bool = false
		if foe_high:
			wanted = (kind == "roof" and foe_roof) or (kind != "roof" and foe_floor == top.z)
		if not wanted and kind == "roof" and top == post_top:
			wanted = true
		if not wanted:
			continue
		if not _vault_ok(link, field, merc_size):
			continue
		if state.is_position_occupied(Vector2i(top.x, top.y), merc, top.z):
			continue
		if best.is_empty() or int(link["paces"]) < int(best["paces"]):
			best = link
	return best


#The drop link out of cell this merc would rather climb down than fall, fewest paces first; {} for none.
static func _link_down(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		cell: Vector3i) -> Dictionary:
	if cell.z < 1 or PathTargeter.is_flying(merc):
		return {}
	var links: Array = field.drop_links.get(cell, []) as Array
	if links.is_empty():
		return {}
	var near := _nearest_enemy(merc, state, Vector2i(cell.x, cell.y))
	var foe: MercenaryData = near["merc"] as MercenaryData
	if foe == null or state.get_floor(foe) >= cell.z:
		return {}
	if WeaponEvaluator.is_ranged_focused(merc) and bool(LineOfSight.check(state, merc, foe).get("visible", true)):
		return {}
	var merc_size := maxi(1, int(merc.stats.get("size", 1)))
	var tol := PathTargeter.fall_tolerance(merc)
	var best: Dictionary = {}
	for link: Dictionary in links:
		var paces: int = int(link["paces"])
		#A drop the walker accepts and survives cheaply is left to movement.
		if not PathCost.prefers_down_climb(paces, tol, merc.current_hp):
			continue
		if not _vault_ok(link, field, merc_size):
			continue
		var to: Vector3i = link["to"] as Vector3i
		if state.is_position_occupied(Vector2i(to.x, to.y), merc, to.z):
			continue
		if best.is_empty() or paces < int(best["paces"]):
			best = link
	return best


static func _find_climb_target(merc: MercenaryData, state: BattleState) -> Vector2i:
	if state == null or state.battlefield == null:
		return Vector2i(-1, -1)
	var field: BattlefieldArea = state.battlefield
	var merc_pos := state.get_position(merc)
	if merc_pos == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var merc_h := field.surface_height(merc_pos)
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	#From the bottom of a pool the wall is the whole depth, and only a dry cell ends the climb.
	if state.is_sunk(merc):
		merc_h = field.get_terrain_height(merc_pos)
		for wd: Vector2i in dirs:
			var wet_nb := merc_pos + wd
			if wet_nb.x < 0 or wet_nb.x >= field.width or wet_nb.y < 0 or wet_nb.y >= field.length:
				continue
			if field.is_water(wet_nb) or field.rock_cells.has(wet_nb):
				continue
			if field.clearance(wet_nb) < 1.0:
				continue
			if not PathHelper.is_standable(Vector3i(wet_nb.x, wet_nb.y, 0), field, 1):
				continue
			if state.is_position_occupied(wet_nb, merc, state.get_floor(merc)):
				continue
			if field.get_terrain_height(wet_nb) - merc_h <= 0.5:
				continue
			return wet_nb
		return Vector2i(-1, -1)
	for d: Vector2i in dirs:
		var nb := merc_pos + d
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		var nb_h := field.get_terrain_height(nb)
		if nb_h <= merc_h + 0.1 and not field.get_nav_passable_cells().has(nb):
			#A building wall is climbed through its links, never hopped.
			if wall_hop(field, nb):
				nb_h = merc_h + 2.0
		var h_diff := nb_h - merc_h
		if h_diff <= 0.5:
			continue
		if state.is_position_occupied(nb, merc, state.get_floor(merc)):
			continue
		return nb
	return Vector2i(-1, -1)


#True when the cell holds a free-standing wall a climber may hop: never one of a building footprint.
static func wall_hop(field: BattlefieldArea, cell: Vector2i) -> bool:
	if field.in_footprint(cell):
		return false
	var obs := field.get_obs(cell, 0)
	return not obs.is_empty() and obs.get("cell_type", "") == "wall"


func _is_climb_complete(merc: MercenaryData, state: BattleState) -> bool:
	var cd := state.get_climbing_data(merc)
	return int(cd.get("current_h", 0)) >= int(cd.get("target_h", 0))

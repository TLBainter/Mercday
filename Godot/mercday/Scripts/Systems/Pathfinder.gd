class_name Pathfinder

# Returns A* path [from, ..., to] over the battlefield grid.
# Empty array = no path exists (completely blocked).
static func find_path(from: Vector2i, to: Vector2i, field: BattlefieldArea) -> Array[Vector2i]:
	if from == to:
		var r: Array[Vector2i] = [from]
		return r

	# open: pos -> {g, f, parent}
	var open: Dictionary = {}
	var closed: Dictionary = {}

	open[from] = {"g": 0, "f": _h(from, to), "parent": Vector2i(-999, -999)}

	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	while not open.is_empty():
		var best: Vector2i = _lowest_f(open)
		var node: Dictionary = open[best]
		open.erase(best)
		closed[best] = node

		if best == to:
			return _reconstruct(closed, best, from)

		for d: Vector2i in dirs:
			var nb: Vector2i = best + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if closed.has(nb):
				continue
			var cost: int = cell_pace_cost(best, nb, field)
			if cost < 0:
				continue  # impassable
			var g: int = node["g"] + cost
			if not open.has(nb) or g < (open[nb] as Dictionary)["g"]:
				open[nb] = {"g": g, "f": g + _h(nb, to), "parent": best}

	var empty: Array[Vector2i] = []
	return empty


# Pace cost to enter `to` from `from`. -1 = impassable.
static func cell_pace_cost(from: Vector2i, to: Vector2i, field: BattlefieldArea) -> int:
	var obs: Dictionary = field.get_obstacle_at(to)
	var base_cost: int

	if obs.is_empty():
		base_cost = 1  # open ground or building interior
	else:
		var cell_type: String = obs.get("cell_type", "")

		if cell_type == "wall":
			return -1

		if cell_type == "door":
			if not obs.get("door_open", false):
				return -1
			base_cost = 1
		else:
			var data: ObstacleData = obs.get("data") as ObstacleData
			if data == null:
				return -1
			if data.is_stairs:
				base_cost = 1  # handled further below with height logic
			elif not data.passthrough:
				return -1
			elif data.passthrough_enter_harm > 0 or data.passthrough_exit_harm > 0:
				# Hazardous passthrough — crossable but strongly penalised
				base_cost = 10
			else:
				base_cost = 2 if data.rugged else 1

	var h_diff: float = field.get_terrain_height(to) - field.get_terrain_height(from)

	if h_diff > 0.5:
		return -1   # too steep going up

	if h_diff <= -1.0:
		return -1   # fall zone — pathfinder routes around drops ≥ 1

	var abs_diff := absf(h_diff)
	if abs_diff > 0.25:
		if not field.has_stairs_at(to):
			return -1   # moderate slope with no stairs
		if h_diff > 0.0:
			base_cost += 1              # rugged going up stairs
		else:
			base_cost = maxi(0, base_cost - 1)  # slight discount going down

	return base_cost


static func _h(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))  # Chebyshev


static func _lowest_f(open: Dictionary) -> Vector2i:
	var best: Vector2i = open.keys()[0]
	var best_f: int = (open[best] as Dictionary)["f"]
	for k: Vector2i in open.keys():
		var f: int = (open[k] as Dictionary)["f"]
		if f < best_f:
			best_f = f
			best = k
	return best


static func _reconstruct(closed: Dictionary, end: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var curr: Vector2i = end
	while curr != start:
		path.append(curr)
		var node: Dictionary = closed[curr]
		curr = node["parent"]
	path.append(start)
	path.reverse()
	return path

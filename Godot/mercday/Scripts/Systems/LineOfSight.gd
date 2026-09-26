class_name LineOfSight

#Grazing band in paces: an obstacle top within TOLERANCE of the ray gives partial cover.
const TOLERANCE := 0.5
#Ray endpoints sit just inside the body so a plane at eye or foot height does not count as crossed.
const EPS := 0.01
#Sentinel for "no floor plane is exempt" in _floor_block.
const NO_SKIP := -1.0e9
#Sentinel for "the caller knows no floor" in _obstacle_test.
const NO_FLOOR := -9999


static func check(state: BattleState, attacker: MercenaryData, target: MercenaryData) -> Dictionary:
	if attacker == null:
		return clear_result()
	return check_from(state, state.pos3(attacker), state.body_height(attacker),
		maxi(1, int(attacker.stats.get("size", 1))), target)


static func check_from(state: BattleState, from: Vector3i, from_height: int, from_size: int,
		target: MercenaryData) -> Dictionary:
	if state == null or target == null or state.battlefield == null:
		return clear_result()
	return _cached(state, from, from_height, from_size, state.pos3(target),
		state.body_height(target), maxi(1, int(target.stats.get("size", 1))))


#LOS from a merc to a hypothetical unit of p_size standing on cell.
static func check_cell(state: BattleState, attacker: MercenaryData, cell: Vector3i, p_size: int) -> Dictionary:
	if state == null or attacker == null or state.battlefield == null:
		return clear_result()
	return _cached(state, state.pos3(attacker), state.body_height(attacker),
		maxi(1, int(attacker.stats.get("size", 1))), cell, 0, maxi(1, p_size))


static func clear_result() -> Dictionary:
	return {"visible": true, "cover": "none", "via": "", "blocker": "", "windows": [] as Array[Vector3i]}


static func _cached(state: BattleState, from: Vector3i, from_height: int, from_size: int,
		tp: Vector3i, t_height: int, t_size: int) -> Dictionary:
	var field: BattlefieldArea = state.battlefield
	var key := "%d,%d,%d|%d|%d|%d,%d,%d|%d|%d|%d" % [
		from.x, from.y, from.z, from_height, from_size,
		tp.x, tp.y, tp.z, t_height, t_size, field.los_version]
	if state.los_cache.has(key):
		return state.los_cache[key] as Dictionary
	var result := _compute(field, from, from_height, from_size, tp, t_height, t_size)
	state.los_cache[key] = result
	return result


static func _compute(field: BattlefieldArea, from: Vector3i, from_height: int, from_size: int,
		tp: Vector3i, t_height: int, t_size: int) -> Dictionary:
	var f2 := Vector2i(from.x, from.y)
	var t2 := Vector2i(tp.x, tp.y)
	var t_own := _own_cell_top(field, t2, tp.z)
	var f_own := _own_cell_top(field, f2, from.z)
	#Only orthogonal ground neighbours have no cell between them; diagonals still need the corner test.
	if from.z == tp.z and from_height == 0 and t_height == 0 \
			and absi(f2.x - t2.x) + absi(f2.y - t2.y) == 1 \
			and t_own.is_empty() and f_own.is_empty():
		var adjacent := clear_result()
		adjacent["via"] = "adjacent"
		return adjacent
	var cross_floor := from.z != tp.z
	var steps := _steps(f2, t2)
	if steps.is_empty():
		if not cross_floor:
			return clear_result()
		steps.append({"c": t2, "o": [] as Array[Vector2i]})

	var t_base := field.cell_base_elevation(t2, tp.z)
	var oz := field.cell_base_elevation(f2, from.z) + float(from_height) + float(from_size) - EPS
	var base := t_base + float(t_height)
	#A grounded target stands on its own tread, so that surface may not block the ray that ends on it.
	var stair_skip := t_base if t_height == 0 else NO_SKIP
	#A unit standing on a roof cell is not hidden by the roof of its own cell.
	var roof_skip := field.is_roof_footing(t2, tp.z)
	var targets: Array[float] = [
		base + float(t_size) * 0.5,
		base + float(t_size) - EPS,
		base + EPS,
	]
	var names: Array[String] = ["center", "top", "bottom"]
	#A body under a low cavern roof lies flat, so no ray may start or end above that roof.
	if field.is_cavern:
		oz = minf(oz, _ceiling_at(field, f2) - EPS)
		var t_cap := _ceiling_at(field, t2) - EPS
		for i: int in range(targets.size()):
			targets[i] = minf(targets[i], t_cap)

	if not f_own.is_empty() and oz < float(f_own["top"]) - EPS * 0.5:
		return {"visible": false, "cover": "full", "via": "", "blocker": str(f_own["label"]),
			"windows": [] as Array[Vector3i]}

	var own_blocked: Array[bool] = []
	for tz: float in targets:
		own_blocked.append(not t_own.is_empty() and tz < float(t_own["top"]) - EPS * 0.5)

	var own_cover := own_blocked.has(true)
	var rays: Array[Dictionary] = []
	for i: int in range(targets.size()):
		if own_blocked[i]:
			rays.append({"state": "blocked", "blocker": str(t_own["label"]),
				"windows": [] as Array[Vector3i]})
		else:
			rays.append(_trace(field, f2, t2, steps, oz, targets[i], stair_skip, roof_skip))
		#The first clean ray in index order wins, so the later rays are never needed.
		if str(rays[i]["state"]) == "clean":
			return {"visible": true, "cover": "partial" if own_cover else "none", "via": names[i],
				"blocker": "", "windows": rays[i]["windows"]}
	for i: int in range(rays.size()):
		if str(rays[i]["state"]) == "graze":
			return {"visible": true, "cover": "partial", "via": names[i], "blocker": "",
				"windows": rays[i]["windows"]}
	return {"visible": false, "cover": "full", "via": "", "blocker": str(rays[0]["blocker"]),
		"windows": [] as Array[Vector3i]}


#A solid obstacle filling a merc's own cell; {} when nothing there can hide a body standing in it.
static func _own_cell_top(field: BattlefieldArea, cell: Vector2i, fl: int) -> Dictionary:
	var obs := field.get_obs(cell, fl)
	if obs.is_empty():
		return {}
	if obs.get("hanging", false) as bool or obs.get("broken", false) as bool:
		return {}
	if BattlefieldArea.is_transparent(obs):
		return {}
	var ct := str(obs.get("cell_type", ""))
	if ct == "door" or ct == "window":
		return {}
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d == null or d.passthrough or d.ramp or d.narrow:
		return {}
	return {"top": field.cell_base_elevation(cell, fl) + BattlefieldArea.obstacle_height(obs),
		"label": _obs_label(obs, cell, fl)}


#Supercover cell walk; each entry is {"c": cell, "o": the two orthogonal cells of a diagonal step}.
static func _steps(f2: Vector2i, t2: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dx := t2.x - f2.x
	var dy := t2.y - f2.y
	if dx == 0 and dy == 0:
		return result
	var nx := absi(dx)
	var ny := absi(dy)
	var sx := signi(dx)
	var sy := signi(dy)
	var p := f2
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var sc_x := (2 * ix + 1) * ny
		var sc_y := (2 * iy + 1) * nx
		var ortho: Array[Vector2i] = []
		if sc_x < sc_y:
			p.x += sx
			ix += 1
		elif sc_y < sc_x:
			p.y += sy
			iy += 1
		else:
			ortho = [Vector2i(p.x + sx, p.y), Vector2i(p.x, p.y + sy)]
			p.x += sx
			p.y += sy
			ix += 1
			iy += 1
		result.append({"c": p, "o": ortho})
	return result


static func _trace(field: BattlefieldArea, f2: Vector2i, t2: Vector2i, steps: Array[Dictionary],
		oz: float, tz: float, stair_skip: float, roof_skip: bool = false) -> Dictionary:
	var o2 := Vector2(float(f2.x) + 0.5, float(f2.y) + 0.5)
	var p2 := Vector2(float(t2.x) + 0.5, float(t2.y) + 0.5)
	var d := p2 - o2
	var dlen2 := maxf(d.length_squared(), 0.0001)
	var windows: Array[Vector3i] = []
	var grazing := false
	var prev_z := oz
	var last_cell := f2
	var lowest := _lowest_floor(field)
	var city := not field.building_id_at.is_empty()
	var ground := field.floor_base_elevation(0) if city else 0.0
	#Half the ray's climb per cell: the roof span test reads the borders of a cell, not its centre.
	var half_dz := (tz - oz) * 0.5 / float(maxi(1, maxi(absi(t2.x - f2.x), absi(t2.y - f2.y))))

	for step: Dictionary in steps:
		var cell: Vector2i = step["c"] as Vector2i
		var ortho: Array = step["o"] as Array
		var z := tz if cell == t2 else _ray_z(cell, o2, d, dlen2, oz, tz)
		var came_from := last_cell
		last_cell = cell

		if not ortho.is_empty():
			var blocked := 0
			var corner := ""
			for oc: Vector2i in ortho:
				var res_o := _obstacle_test(field, oc, _ray_z(oc, o2, d, dlen2, oz, tz))
				if str(res_o["state"]) == "blocked":
					blocked += 1
					corner = str(res_o["blocker"])
			if blocked >= 2:
				return {"state": "blocked", "blocker": "corner %s" % corner, "windows": windows}

		if cell == t2 or cell == f2:
			if cell == t2:
				#The exemption holds for a ray that arrives over the roof plane or out of the open air, never from under the roof.
				var skip_here := roof_skip and (not field.roof_span.has(came_from)
						or prev_z >= (field.roof_span[came_from] as Vector2).x)
				var end_hit := _floor_block(field, cell, prev_z, z, lowest, stair_skip, skip_here,
					z - half_dz, z)
				if end_hit != "":
					return {"state": "blocked", "blocker": end_hit, "windows": windows}
			prev_z = z
			continue

		var fl := _floor_at_cell(field, cell, z)
		if fl == 0 and not (field.is_interior_map and field.in_footprint(cell)):
			if field.get_terrain_height(cell) + ground > z + TOLERANCE:
				return {"state": "blocked", "blocker": "terrain (%d,%d)" % [cell.x, cell.y],
					"windows": windows}
			if field.is_cavern:
				if field.rock_cells.has(cell):
					return {"state": "blocked", "blocker": "rock (%d,%d)" % [cell.x, cell.y],
						"windows": windows}
				if z > _ceiling_at(field, cell) + TOLERANCE:
					return {"state": "blocked", "blocker": "ceiling (%d,%d)" % [cell.x, cell.y],
						"windows": windows}

		#A ray under the street level runs through earth wherever the cell has no basement floor there.
		if city and z < ground - EPS and (fl >= 0 or not field.in_footprint_floor(cell, fl)):
			return {"state": "blocked", "blocker": "ground (%d,%d)" % [cell.x, cell.y], "windows": windows}

		#An open outdoor city cell holds the ground plane alone and no roof, so no slab can cross the ray.
		var open_outdoor := city and field.building_at(cell) < 0 and not field.roof_span.has(cell)
		if not open_outdoor:
			var floor_hit := _floor_block(field, cell, prev_z, z, lowest, NO_SKIP, false,
				z - half_dz, z + half_dz)
			if floor_hit != "":
				return {"state": "blocked", "blocker": floor_hit, "windows": windows}

		var res := _obstacle_test(field, cell, z,
			maxi(absi(cell.x - t2.x), absi(cell.y - t2.y)) == 1, fl)
		var st := str(res["state"])
		if st == "blocked":
			return {"state": "blocked", "blocker": str(res["blocker"]), "windows": windows}
		if st == "window":
			windows.append(res["cell3"] as Vector3i)
		elif st == "graze":
			grazing = true
		prev_z = z

	return {"state": "graze" if grazing else "clean", "blocker": "", "windows": windows}


static func _ray_z(cell: Vector2i, o2: Vector2, d: Vector2, dlen2: float,
		oz: float, tz: float) -> float:
	var cc := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	var t := clampf((cc - o2).dot(d) / dlen2, 0.0, 1.0)
	return oz + (tz - oz) * t


static func _crosses(a: float, b: float, level: float) -> bool:
	return level >= minf(a, b) and level <= maxf(a, b)


#Slab the ray crosses at cell between prev_z and z, or the sloped stair slab it hits; "" when none.
#A stair cell is solid only in the band [tread - STAIR_SLAB, tread]; below and above it is open air.
#A ray that only touches the underside of that band within EPS stays clear.
#skip_stair_e exempts one stair tread elevation: the one a grounded target is standing on.
#skip_roof exempts the roof span of the cell a target is standing on.
#roof_a and roof_b are the ray heights at the borders of the cell; without them the roof span test reads the centres.
static func _floor_block(field: BattlefieldArea, cell: Vector2i, prev_z: float, z: float, lowest: int,
		skip_stair_e: float = NO_SKIP, skip_roof: bool = false,
		roof_a: float = NO_SKIP, roof_b: float = NO_SKIP) -> String:
	if field.is_interior_map:
		var planes: Dictionary = field.floor_planes_at(cell)
		var low: int = lowest
		if not field.building_id_at.is_empty():
			low = _lowest_of(planes)
		for f: int in planes.keys():
			if f == low:
				continue
			if field.has_slab(cell, f) and _crosses(prev_z, z, field.floor_elevation_at(cell, f)):
				return "slab f%d (%d,%d)" % [f, cell.x, cell.y]
			if field.is_stair_cell(cell, f):
				var se := field.cell_base_elevation(cell, f)
				var under := se - BattlefieldArea.STAIR_SLAB
				if absf(se - skip_stair_e) <= EPS:
					#The tread under the target blocks only a ray that climbs to it from under the stairs.
					if minf(prev_z, z) < under - EPS:
						return "stairs f%d (%d,%d)" % [f, cell.x, cell.y]
				elif maxf(prev_z, z) > under + EPS and minf(prev_z, z) <= se + EPS:
					return "stairs f%d (%d,%d)" % [f, cell.x, cell.y]
	elif field.roof_span.is_empty():
		return ""
	#The roof over a footprint cell is solid across its span: the slab plane up to the top of the slope or block.
	if not skip_roof and field.roof_span.has(cell):
		var ra: float = roof_a if roof_a > NO_SKIP else prev_z
		var rb: float = roof_b if roof_b > NO_SKIP else z
		var span: Vector2 = field.roof_span[cell] as Vector2
		if maxf(ra, rb) >= span.x and minf(ra, rb) <= span.y:
			return "roof (%d,%d)" % [cell.x, cell.y]
	return ""


static func _lowest_floor(field: BattlefieldArea) -> int:
	return _lowest_of(field.interior_floor_elevations)


static func _lowest_of(planes: Dictionary) -> int:
	var low := 0
	var first := true
	for f: int in planes.keys():
		if first or f < low:
			low = f
			first = false
	return low


#Absolute ceiling elevation of a cavern cell; NO_HEADROOM_LIMIT where the rock is not vaulted.
static func _ceiling_at(field: BattlefieldArea, cell: Vector2i) -> float:
	return float(field.cavern_ceiling.get(cell, BattlefieldArea.NO_HEADROOM_LIMIT))


#A hanging obstacle fills only the band between the lowered ceiling and the rock it grew from.
static func _hanging_test(field: BattlefieldArea, obs: Dictionary, cell: Vector2i, z: float) -> Dictionary:
	var low := _ceiling_at(field, cell)
	var high := low + BattlefieldArea.obstacle_height(obs)
	if obs.has("restore_clearance"):
		high = field.ground_height(cell) + float(obs["restore_clearance"])
	if z >= low and z <= high:
		return {"state": "blocked", "blocker": _obs_label(obs, cell, 0), "cell3": Vector3i.ZERO}
	return {"state": "clear", "blocker": "", "cell3": Vector3i.ZERO}


static func _obstacle_test(field: BattlefieldArea, cell: Vector2i, z: float,
		near_target: bool = false, fl_known: int = NO_FLOOR) -> Dictionary:
	var fl := fl_known if fl_known != NO_FLOOR else _floor_at_cell(field, cell, z)
	var obs := field.get_obs(cell, fl)
	if obs.is_empty():
		return {"state": "clear", "blocker": "", "cell3": Vector3i.ZERO}
	if obs.get("hanging", false) as bool:
		return _hanging_test(field, obs, cell, z)
	if BattlefieldArea.is_transparent(obs):
		if str(obs.get("cell_type", "")) == "window" and not (obs.get("broken", false) as bool):
			return {"state": "window", "blocker": "", "cell3": Vector3i(cell.x, cell.y, fl)}
		return {"state": "clear", "blocker": "", "cell3": Vector3i.ZERO}
	#A Sight=Cover row never blocks; it grazes only beside the target when its top reaches the ray.
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null and d.sight_cover:
		var cover_top := field.cell_base_elevation(cell, fl) + BattlefieldArea.obstacle_height(obs)
		if near_target and cover_top >= z - TOLERANCE:
			return {"state": "graze", "blocker": "", "cell3": Vector3i.ZERO}
		return {"state": "clear", "blocker": "", "cell3": Vector3i.ZERO}
	var top := field.cell_base_elevation(cell, fl) + BattlefieldArea.obstacle_height(obs)
	if top > z + TOLERANCE:
		return {"state": "blocked", "blocker": _obs_label(obs, cell, fl), "cell3": Vector3i.ZERO}
	if top >= z - TOLERANCE:
		return {"state": "graze", "blocker": "", "cell3": Vector3i.ZERO}
	return {"state": "clear", "blocker": "", "cell3": Vector3i.ZERO}


static func _obs_label(obs: Dictionary, cell: Vector2i, fl: int) -> String:
	var d: ObstacleData = obs.get("data") as ObstacleData
	var name_str := d.obstacle_name if d != null else str(obs.get("cell_type", "obstacle"))
	if name_str == "":
		name_str = str(obs.get("cell_type", "obstacle"))
	return "%s (%d,%d) F%d" % [name_str, cell.x, cell.y, fl]


#Highest floor plane at or below z; lowest floor when z sits under the whole building.
static func _floor_at(field: BattlefieldArea, z: float) -> int:
	if not field.is_interior_map:
		return 0
	var best := 0
	var best_e := 0.0
	var found := false
	for f: int in field.interior_floor_elevations.keys():
		var e := field.floor_base_elevation(f)
		if e <= z and (not found or e > best_e):
			best_e = e
			best = f
			found = true
	return best if found else _lowest_floor(field)


#_floor_at for one cell: a city map picks among the planes that exist at that cell.
static func _floor_at_cell(field: BattlefieldArea, cell: Vector2i, z: float) -> int:
	if not field.is_interior_map:
		#Over an outdoor hut roof the ray reads level 1, so the wall below it is never tested.
		if not field.roof_cells.is_empty() and field.roof_elevations.has(cell) \
				and z >= float(field.roof_elevations[cell]):
			return field.roof_level_at(cell)
		return 0
	#A ray over a roof plane reads the roof level on interior and city maps too, so roof objects are tested.
	if not field.roof_cells.is_empty() and field.roof_elevations.has(cell) \
			and z >= float(field.roof_elevations[cell]):
		return field.roof_level_at(cell)
	if field.building_id_at.is_empty():
		return _floor_at(field, z)
	var planes: Dictionary = field.floor_planes_at(cell)
	var best := 0
	var best_e := 0.0
	var found := false
	var low := 0
	var first := true
	for f: int in planes.keys():
		var e := float(planes[f])
		if first or f < low:
			low = f
			first = false
		if e <= z and (not found or e > best_e):
			best_e = e
			best = f
			found = true
	return best if found else low

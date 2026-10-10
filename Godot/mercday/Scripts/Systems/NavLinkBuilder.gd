class_name NavLinkBuilder

#Builds the stair, drop, roof, dome and climb nav links of an area.


#Rebuilds stair_runs and stair_links from stairwell_connections; safe on exterior maps.
static func build_stair_links(area: BattlefieldArea) -> void:
	area.stair_runs.clear()
	area.stair_links.clear()
	area.well_links.clear()
	area.neighbor_cache.clear()
	if not area.is_interior_map:
		return
	for key: Vector3i in area.stairwell_connections.keys():
		var dest: Vector3i = area.stairwell_connections[key] as Vector3i
		if dest.z >= key.z:
			continue
		var runs: Array = area.stair_runs.get(key.z, []) as Array
		runs.append({"sx": key.x, "ly": mini(dest.y, key.y), "uy": maxi(dest.y, key.y),
			"up": 1 if key.y > dest.y else -1})
		area.stair_runs[key.z] = runs
	for f: int in area.stair_runs.keys():
		for entry: Variant in (area.stair_runs[f] as Array):
			var run: Dictionary = entry as Dictionary
			var sx: int = run["sx"] as int
			var ly: int = BattlefieldArea.run_bottom_y(run)
			var landing := Vector3i(sx, ly, f - 1)
			if not area.stair_run_cells.has(landing):
				continue
			#The well opening joins the landing to the floor cells around the run alias above it.
			for wdx: int in [-1, 0, 1]:
				for wdy: int in [-1, 0, 1]:
					if wdx == 0 and wdy == 0:
						continue
					var w2 := Vector2i(sx + wdx, ly + wdy)
					if not area.in_bounds(w2):
						continue
					if area.is_stair_cell(w2, f):
						continue
					if not area.has_walkable_surface(w2, f):
						continue
					var wn := Vector3i(w2.x, w2.y, f)
					_append_link(area.well_links, landing, wn)
					_append_link(area.well_links, wn, landing)
			var ups: Array[Vector3i] = []
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 1]:
					var c := Vector3i(sx + dx, ly + dy, f)
					if not area.stair_run_cells.has(c):
						continue
					ups.append(c)
			if ups.is_empty():
				continue
			area.stair_links[landing] = ups
			for c: Vector3i in ups:
				_append_link(area.stair_links, c, landing)


#Appends cell to the typed link list stored under key, creating the list when absent.
static func _append_link(table: Dictionary, key: Vector3i, cell: Vector3i) -> void:
	var list: Array[Vector3i] = []
	if table.has(key):
		list.assign(table[key] as Array)
	list.append(cell)
	table[key] = list


#Rebuilds drop_links from balcony edges, broken shell windows and roof edges; safe on exterior maps.
static func build_drop_links(area: BattlefieldArea) -> void:
	area.drop_links.clear()
	area.climb_links.clear()
	area.roof_fly_links.clear()
	#Every build path ends here, so the reach and cost caches are reset for the finished geometry.
	area.bump_path_version()
	if not area.is_interior_map:
		if not area.roof_cells.is_empty():
			_add_roof_drop_links(area)
			_add_dome_links(area)
			_build_climb_links(area)
		return
	for key: Variant in area.building_interiors.keys():
		if typeof(key) != TYPE_VECTOR3I:
			continue
		var b: Vector3i = key as Vector3i
		if b.z < 1:
			continue
		var b2 := Vector2i(b.x, b.y)
		if area.in_footprint(b2):
			continue
		for d: Vector2i in PathCost.DIRS4:
			var edge := Vector2i(b.x + d.x, b.y + d.y)
			if area.in_footprint(edge) or area.building_interiors.has(Vector3i(edge.x, edge.y, b.z)):
				continue
			var edge_obs: Dictionary = area.get_obs(edge, b.z)
			var land := edge
			var vault := Vector3i(-1, -1, -1)
			if not edge_obs.is_empty():
				if edge_obs.get("cell_type", "") == "wall":
					continue
				land = Vector2i(edge.x + d.x, edge.y + d.y)
				vault = Vector3i(edge.x, edge.y, b.z)
			_add_drop_link(area, b, land, vault, "balcony")
	for wkey: Variant in area._obs_map.keys():
		if typeof(wkey) != TYPE_VECTOR3I:
			continue
		var w: Vector3i = wkey as Vector3i
		if w.z < 1:
			continue
		var wobs: Dictionary = area._obs_map[wkey] as Dictionary
		if wobs.get("cell_type", "") != "window":
			continue
		if not (wobs.get("broken", false) as bool):
			continue
		if not _on_footprint_edge(area, Vector2i(w.x, w.y)):
			continue
		for d: Vector2i in PathCost.DIRS4:
			var inner := Vector2i(w.x - d.x, w.y - d.y)
			if not area.in_footprint(inner) or not area.building_interiors.has(Vector3i(inner.x, inner.y, w.z)):
				continue
			var outer := Vector2i(w.x + d.x, w.y + d.y)
			if area.in_footprint(outer) and not _roof_under(area, outer, w.z):
				continue
			_add_drop_link(area, Vector3i(inner.x, inner.y, w.z), outer, w, "window")
	_add_roof_drop_links(area)
	_add_dome_links(area)
	_build_climb_links(area)


#A broken roof object opens its cell, so the roof link tables are rebuilt from the new geometry.
static func relink_after_obstacle_loss(area: BattlefieldArea, obs: Dictionary) -> void:
	area.bump_path_version()
	area.los_version += 1
	if not area.is_interior_map or area.roof_cells.is_empty():
		return
	if not bool(obs.get("roof_object", false)):
		return
	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()
	build_drop_links(area)


#Sorts cells by z, then y, then x, so a table built from dictionary keys never follows hash order.
static func _cell_before(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return a.z < b.z
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


#Reverses every drop link into climb_links: the landing cell keys the top it rises to.
static func _build_climb_links(area: BattlefieldArea) -> void:
	var keys: Array[Vector3i] = []
	for k: Variant in area.drop_links.keys():
		keys.append(k as Vector3i)
	keys.sort_custom(_cell_before)
	for from: Vector3i in keys:
		for dl: Dictionary in (area.drop_links[from] as Array):
			var to: Vector3i = dl["to"] as Vector3i
			var ups: Array = area.climb_links.get(to, []) as Array
			ups.append({"top": from, "paces": int(dl["paces"]), "kind": String(dl["kind"]),
				"vault": dl["vault"] as Vector3i})
			area.climb_links[to] = ups


#True when pos carries a roof footing at or below floor_num: the drop has somewhere to land.
static func _roof_under(area: BattlefieldArea, pos: Vector2i, floor_num: int) -> bool:
	var rl: int = area.roof_level_at(pos)
	return rl >= 0 and rl <= floor_num and area.is_roof_footing(pos, rl)


#One drop edge off every open roof edge, plus the reverse rise a flyer takes back up.
static func _add_roof_drop_links(area: BattlefieldArea) -> void:
	if area.roof_cells.is_empty():
		return
	for rkey: Variant in area.roof_cells.keys():
		var r: Vector3i = rkey as Vector3i
		if int(area.roof_cells[rkey]) == RoofBuilder.SOLID:
			continue
		if not area.get_obs(Vector2i(r.x, r.y), r.z).is_empty():
			continue
		for d: Vector2i in PathCost.DIRS4:
			var n := Vector2i(r.x + d.x, r.y + d.y)
			if not area.in_bounds(n):
				continue
			var land := n
			var vault := BattlefieldArea.NO_VAULT
			var nobs: Dictionary = area.get_obs(n, r.z)
			if not nobs.is_empty():
				#A parapet or dormer is climbed over; a merlon stands too tall to clear.
				if not bool(nobs.get("roof_object", false)) or BattlefieldArea.obstacle_height(nobs) >= 2.0:
					continue
				land = Vector2i(n.x + d.x, n.y + d.y)
				vault = Vector3i(n.x, n.y, r.z)
				if not area.in_bounds(land):
					continue
			if area.is_roof_footing(land, r.z) or area.has_walkable_surface(land, r.z):
				continue
			if not _add_drop_link(area, r, land, vault, "roof"):
				continue
			_register_fly_back(area, r)


#The rise a flyer takes back up, written on the cell the drop link just appended lands on.
static func _register_fly_back(area: BattlefieldArea, from: Vector3i) -> void:
	var added: Array = area.drop_links[from] as Array
	var to: Vector3i = (added[added.size() - 1] as Dictionary)["to"] as Vector3i
	_append_link(area.roof_fly_links, to, from)


#A dome is climbed as a wall: every ground cell beside it links to the nearest crown cell of the dome.
static func _add_dome_links(area: BattlefieldArea) -> void:
	if area.roof_parts.is_empty():
		return
	for part: Dictionary in area.roof_parts:
		if String(part.get("kind", "")) != "dome":
			continue
		var level: int = int(part.get("level", 1))
		var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
		var crowns: Array[Vector3i] = []
		for cell: Vector2i in (part.get("cells", []) as Array):
			var key := Vector3i(cell.x, cell.y, level)
			if int(area.roof_cells.get(key, RoofBuilder.SOLID)) != RoofBuilder.FLAT:
				continue
			if not area.get_obs(cell, level).is_empty():
				continue
			crowns.append(key)
		if crowns.is_empty():
			continue
		for gy: int in range(rect.position.y - 1, rect.end.y + 1):
			for gx: int in range(rect.position.x - 1, rect.end.x + 1):
				var g := Vector2i(gx, gy)
				if rect.has_point(g) or not area.in_bounds(g):
					continue
				if area.in_footprint(g) or area.roof_level_at(g) >= 0:
					continue
				if not area.has_walkable_surface(g, 0) or not area.get_obs(g, 0).is_empty():
					continue
				_dome_link_to(area, crowns, g)


#Links the one crown cell nearest g, unless a roof edge already drops from it onto g.
static func _dome_link_to(area: BattlefieldArea, crowns: Array[Vector3i], g: Vector2i) -> void:
	var best := Vector3i(-1, -1, -1)
	var best_d: int = 1 << 30
	for c: Vector3i in crowns:
		var d2: int = (c.x - g.x) * (c.x - g.x) + (c.y - g.y) * (c.y - g.y)
		if d2 > best_d:
			continue
		if d2 == best_d and not (c.y < best.y or (c.y == best.y and c.x < best.x)):
			continue
		best = c
		best_d = d2
	if best.x < 0:
		return
	for old: Dictionary in (area.drop_links.get(best, []) as Array):
		var ot: Vector3i = old["to"] as Vector3i
		if ot.x == g.x and ot.y == g.y:
			return
	if not _add_drop_link(area, best, g, BattlefieldArea.NO_VAULT, "roof"):
		return
	_register_fly_back(area, best)


#True when pos sits on the outermost ring of the building footprint.
static func _on_footprint_edge(area: BattlefieldArea, pos: Vector2i) -> bool:
	if not area.in_footprint(pos):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not area.in_footprint(pos + d):
			return true
	return false


#Highest footing of the column `land` that lies under from_elev; -1 when the drop has no landing.
static func drop_landing_level(area: BattlefieldArea, land: Vector2i, from_elev: float, below: int) -> int:
	var rl: int = area.roof_level_at(land)
	if rl >= 0 and rl < below:
		if area.is_roof_footing(land, rl):
			if area.cell_base_elevation(land, rl) < from_elev:
				return rl
		elif float(area.roof_elevations.get(land, 0)) < from_elev:
			return -1
	var lz: int = 0
	for z: int in range(below - 1, 0, -1):
		if area.has_walkable_surface(land, z) and area.floor_elevation_at(land, z) < from_elev:
			lz = z
			break
	if area.in_footprint(land) and lz != rl:
		return -1
	return lz


#Records one drop edge from `from` down to `land`; false when the landing is unusable.
static func _add_drop_link(area: BattlefieldArea, from: Vector3i, land: Vector2i, vault: Vector3i, kind: String) -> bool:
	if not area.in_bounds(land):
		return false
	var from2 := Vector2i(from.x, from.y)
	var from_e: float = area.cell_base_elevation(from2, from.z) if area.is_roof_footing(from2, from.z) \
		else area.floor_elevation_at(from2, from.z)
	var lz: int = drop_landing_level(area, land, from_e, from.z + 1)
	if lz < 0:
		return false
	if lz == 0 and area.jagged_cells.has(land):
		return false
	var lobs: Dictionary = area.get_obs(land, lz)
	if not lobs.is_empty():
		var lct: String = lobs.get("cell_type", "")
		if lct == "wall":
			return false
		if lct == "door" and not OpenCloseState.is_open(lobs):
			return false
		#A roof edge never drops a mover into an obstacle cell; an open door is the one exception.
		if kind == "roof" and lct != "door":
			return false
	var paces: int = int(floor(from_e - area.cell_base_elevation(land, lz)))
	if paces <= 0:
		return false
	var links: Array = area.drop_links.get(from, []) as Array
	links.append({"to": Vector3i(land.x, land.y, lz), "paces": paces, "kind": kind, "vault": vault})
	area.drop_links[from] = links
	return true

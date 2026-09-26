class_name HtmlWireframeGenerator


static func save(field: BattlefieldArea, path_stem: String) -> void:
	save_to(field, path_stem + "_3d.html")


#Writes the viewer to an exact path; used for the battle-end re-serialization.
static func save_to(field: BattlefieldArea, path: String) -> void:
	if field == null:
		return
	var html := _build_html(field)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("HtmlWireframeGenerator: could not write %s" % path)
		return
	f.store_string(html)
	f.close()


static func _extract_data(field: BattlefieldArea) -> Dictionary:
	var data: Dictionary = {}
	data["width"] = field.width
	data["length"] = field.length
	data["is_interior"] = field.is_interior_map
	data["floor_height"] = field.interior_floor_height
	data["floor_depth"] = field.interior_floor_depth
	data["top_y"] = field.interior_top_y

	var floors: Dictionary = {}
	for k: Variant in field.interior_floor_elevations.keys():
		floors[str(k as int)] = field.interior_floor_elevations[k]
	data["floors"] = floors
	data["floor_list"] = _floor_list(field)

	var th: Dictionary = {}
	for k: Variant in field.terrain_heights.keys():
		var pos := k as Vector2i
		th["%d_%d" % [pos.x, pos.y]] = field.terrain_heights[k]
	data["terrain_heights"] = th

	var obs_list: Array = []
	for obs: Dictionary in field.obstacles:
		var cell := BattlefieldArea.cell_of(obs["pos"])
		var pos := Vector3i(cell.x, cell.y, BattlefieldArea.floor_of(obs["pos"]))
		var d: ObstacleData = obs.get("data") as ObstacleData
		var entry: Dictionary = {
			"x": pos.x, "y": pos.y, "floor": pos.z,
			"size": obs.get("size", 1),
			"cell_type": obs.get("cell_type", ""),
			"orient": obs.get("orientation", "v"),
			"size_x": d.size_x if d != null else 1.0,
			"size_y": d.size_y if d != null else 1.0,
			"size_z": d.size_z if d != null else 1.0,
			"pw": obs.get("pw", ceili(d.size_x) if d != null else 1),
			"ph": obs.get("ph", ceili(d.size_y) if d != null else 1),
			"name": d.obstacle_name.to_lower() if d != null else "",
			"type": d.obstacle_type.to_lower() if d != null else "",
			"narrow": d.narrow if d != null else false,
			"broken": obs.get("broken", false) as bool,
			"hanging": obs.get("hanging", false) as bool,
			"rubble": obs.get("rubble", false) as bool,
			"cubes": (obs.get("cubes", []) as Array).size(),
			"height": BattlefieldArea.obstacle_height(obs),
			"locked": obs.get("locked", false) as bool,
			"bars": obs.get("bars", false) as bool,
			"lock_d": int(obs.get("lock_difficulty", 0)),
		}
		if bool(obs.get("roof_object", false)):
			entry["roof_obj"] = 1
		if field.is_city and obs.has("city"):
			var blocking: bool = d == null or not (d.passthrough or d.ramp)
			entry["ct"] = String(obs.get("city", ""))
			entry["blk"] = 1 if blocking else 0
		obs_list.append(entry)
	data["obstacles"] = obs_list

	#Exterior buildings key their cells by Vector2i; the viewer draws those on floor 0.
	var bi: Array = []
	for k: Variant in field.building_interiors.keys():
		if k is Vector3i:
			var pos: Vector3i = k
			bi.append([pos.x, pos.y, pos.z])
		elif k is Vector2i:
			var flat: Vector2i = k
			bi.append([flat.x, flat.y, 0])
	data["building_interiors"] = bi

	data["stairwell_cells"] = _triples(field.stairwell_cells)

	var stc: Array = []
	for k: Variant in field.stair_run_cells.keys():
		var sp := k as Vector3i
		stc.append([sp.x, sp.y, sp.z, field.cell_base_elevation(Vector2i(sp.x, sp.y), sp.z)])
	data["stair_cells"] = stc

	var dls: Array = []
	for k: Variant in field.drop_links.keys():
		var dp := k as Vector3i
		for dl: Dictionary in (field.drop_links[k] as Array):
			if str(dl["kind"]) == "roof":
				continue
			var dt: Vector3i = dl["to"] as Vector3i
			dls.append({"x": dp.x, "y": dp.y, "floor": dp.z, "tx": dt.x, "ty": dt.y,
				"paces": int(dl["paces"]), "kind": str(dl["kind"])})
	data["drop_links"] = dls

	var rooms: Array = []
	for entry: Dictionary in field.interior_rooms:
		var rect: Rect2i = entry["rect"] as Rect2i
		rooms.append({
			"x": rect.position.x, "y": rect.position.y,
			"w": rect.size.x, "h": rect.size.y,
			"name": entry["name"], "floor": entry["floor"]
		})
	data["rooms"] = rooms

	var bdata: Array = []
	for b: Dictionary in field.building_data:
		var rect: Rect2i = b["rect"] as Rect2i
		bdata.append({"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y, "name": b.get("name", "")})
	data["buildings"] = bdata

	data["spawn_a"] = _pairs(field.spawn_zone_a)

	data["spawn_b"] = _pairs(field.spawn_zone_b)

	data["jagged_cells"] = _pairs(field.jagged_cells)

	data["is_cavern"] = field.is_cavern
	if field.is_cavern:
		_extract_cavern(field, data)

	data["is_dungeon"] = field.is_dungeon
	var halls: Array = []
	for entry: Dictionary in field.dungeon_halls:
		var hrect: Rect2i = entry["rect"] as Rect2i
		halls.append({"x": hrect.position.x, "y": hrect.position.y, "w": hrect.size.x,
			"h": hrect.size.y, "name": entry.get("name", ""), "floor": int(entry.get("floor", 0))})
	data["halls"] = halls

	if field.is_city:
		data["city"] = _extract_city(field)
	if not field.buildings.is_empty():
		_extract_buildings(field, data)
	if not field.roof_parts.is_empty():
		data["roofs"] = _extract_roofs(field)

	return data


#Ceilings, water, rock, entrances, chambers and tunnels of a cavern map.
static func _extract_cavern(field: BattlefieldArea, data: Dictionary) -> void:
	var ceil_map: Dictionary = {}
	for k: Variant in field.cavern_ceiling.keys():
		var cpos := k as Vector2i
		ceil_map["%d_%d" % [cpos.x, cpos.y]] = float(field.cavern_ceiling[k])
	data["cavern_ceiling"] = ceil_map

	var water: Dictionary = {}
	for k: Variant in field.water_cells.keys():
		var wpos := k as Vector2i
		water["%d_%d" % [wpos.x, wpos.y]] = int(field.water_cells[k])
	data["water_cells"] = water

	data["rock_cells"] = _pairs(field.rock_cells)

	var ent: Array = []
	for ec: Vector2i in field.entrance_cells:
		ent.append([ec.x, ec.y])
	data["entrance_cells"] = ent

	var chambers: Array = []
	for ch: Dictionary in field.cavern_chambers:
		var rect: Rect2i = ch.get("rect", Rect2i()) as Rect2i
		var peak: Vector2i = ch.get("peak", Vector2i.ZERO) as Vector2i
		chambers.append({
			"name": str(ch.get("name", "")),
			"x": rect.position.x, "y": rect.position.y,
			"w": rect.size.x, "h": rect.size.y,
			"level": float(ch.get("level", 0.0)),
			"px": peak.x, "py": peak.y,
			"peak_size": int(ch.get("peak_size", 1)),
			"peak_clearance": float(ch.get("peak_clearance", 0.0)),
			"flooded": ch.get("flooded", false) as bool,
			"depth": int(ch.get("depth", 0)),
		})
	data["cavern_chambers"] = chambers


#Tier, surface rectangles, lots and plots of a city block map.
static func _extract_city(field: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	out["tier"] = String(field.city.get("tier", ""))
	out["main_w"] = int(field.city.get("main_w", 0))
	out["rects"] = _surface_rects(field)
	var lots: Array = []
	for lot: Dictionary in (field.city.get("lots", []) as Array):
		var lr: Rect2i = lot.get("rect", Rect2i()) as Rect2i
		lots.append([int(lot.get("id", -1)), lr.position.x, lr.position.y, lr.size.x, lr.size.y,
			String(lot.get("class", "")), String(lot.get("front", "")), String(lot.get("front_kind", "")),
			int(lot.get("building", -1)), 1 if lot.has("failed") else 0])
	out["lots"] = lots
	var plots: Array = []
	for plot: Dictionary in (field.city.get("plots", []) as Array):
		var pr: Rect2i = plot.get("rect", Rect2i()) as Rect2i
		plots.append([int(plot.get("id", -1)), pr.position.x, pr.position.y, pr.size.x, pr.size.y,
			String(plot.get("class", ""))])
	out["plots"] = plots
	var spawn: Dictionary = field.city.get("spawn", {})
	out["spawn"] = {
		"side_a": int(spawn.get("side_a", -1)),
		"side_b": int(spawn.get("side_b", -1)),
		"a": [field.spawn_center_a.x, field.spawn_center_a.y],
		"b": [field.spawn_center_b.x, field.spawn_center_b.y],
		"buildings_a": _as_int_array(spawn.get("buildings_a", [])),
		"buildings_b": _as_int_array(spawn.get("buildings_b", [])),
		"outdoor_a": int(spawn.get("outdoor_a", 0)),
		"outdoor_b": int(spawn.get("outdoor_b", 0)),
	}
	out["objects"] = field.city.get("objects", {})
	var access: Dictionary = field.city.get("access", {})
	var doors: Array = []
	for door: Dictionary in (access.get("doors", []) as Array):
		var dv: Vector3i = door.get("door", Vector3i(-1, -1, 0))
		var ov: Vector2i = door.get("outside", Vector2i(-1, -1))
		doors.append([int(door.get("building", -1)), String(door.get("kind", "")),
			dv.x, dv.y, ov.x, ov.y])
	out["doors"] = doors
	return out


static func _as_int_array(values: Variant) -> Array:
	var out: Array = []
	for v: Variant in (values as Array):
		out.append(int(v))
	return out


#The surface grid merged greedily into [x, y, w, h, surface] rectangles, row-major.
static func _surface_rects(field: BattlefieldArea) -> Array:
	var out: Array = []
	var w: int = field.width
	var h: int = field.length
	if w <= 0 or h <= 0 or field.surface_grid.size() != w * h:
		return out
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			if seen[i] != 0:
				continue
			var s: int = field.surface_grid[i]
			var rw: int = 1
			while x + rw < w and seen[i + rw] == 0 and field.surface_grid[i + rw] == s:
				rw += 1
			var rh: int = 1
			while y + rh < h and _run_free(field, x, y + rh, rw, s, seen):
				rh += 1
			for yy: int in range(y, y + rh):
				var row: int = yy * w + x
				for k: int in range(rw):
					seen[row + k] = 1
			out.append([x, y, rw, rh, s])
	return out


static func _run_free(field: BattlefieldArea, x: int, y: int, run: int, s: int, seen: PackedByteArray) -> bool:
	var row: int = y * field.width + x
	for k: int in range(run):
		if seen[row + k] != 0 or field.surface_grid[row + k] != s:
			return false
	return true


#Per-building floor planes and the cell owner map of a stamped multi-building map.
static func _extract_buildings(field: BattlefieldArea, data: Dictionary) -> void:
	var list: Array = []
	for rec: Dictionary in field.buildings:
		var bid: int = int(rec.get("id", -1))
		var rect: Rect2i = rec.get("rect", Rect2i()) as Rect2i
		var planes: Dictionary = {}
		if bid >= 0 and bid < field.building_planes.size():
			var src: Dictionary = field.building_planes[bid]
			for k: Variant in src.keys():
				planes[str(k as int)] = int(src[k])
		var entry: Dictionary = {
			"id": bid,
			"name": String(rec.get("name", "")),
			"fh": int(rec.get("fh", field.interior_floor_height)),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"planes": planes,
		}
		if field.is_city:
			var floors: Array = rec.get("floors", []) as Array
			var lo_f: int = int(floors[0]) if not floors.is_empty() else 0
			var hi_f: int = int(floors[floors.size() - 1]) if not floors.is_empty() else 0
			entry["floors"] = [lo_f, hi_f]
			var dv: Vector3i = rec.get("front_door", Vector3i(-1, -1, 0))
			if dv.x < 0:
				dv = rec.get("back_door", Vector3i(-1, -1, 0))
			entry["door"] = [dv.x, dv.y]
		list.append(entry)
	data["bld"] = list
	var owner: Array = []
	owner.resize(field.width * field.length)
	owner.fill(-1)
	for k2: Variant in field.building_id_at.keys():
		var pos := k2 as Vector2i
		if pos.x < 0 or pos.y < 0 or pos.x >= field.width or pos.y >= field.length:
			continue
		owner[pos.y * field.width + pos.x] = int(field.building_id_at[k2])
	data["bld_owner"] = owner


#One viewer record per roof part: cell glyphs, per-cell rise and the vertex heights of the part rect.
static func _extract_roofs(field: BattlefieldArea) -> Array:
	var out: Array = []
	for part: Dictionary in field.roof_parts:
		var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
		var w: int = rect.size.x
		var h: int = rect.size.y
		if w <= 0 or h <= 0:
			continue
		var level: int = int(part.get("level", 0))
		var cells: Array = part.get("cells", []) as Array
		var owned: Dictionary = {}
		for c: Vector2i in cells:
			owned[c] = true
		var types: String = ""
		var rise: Array = []
		for yy: int in range(rect.position.y, rect.end.y):
			for xx: int in range(rect.position.x, rect.end.x):
				if not owned.has(Vector2i(xx, yy)):
					types += "."
					rise.append(0.0)
					continue
				var key := Vector3i(xx, yy, level)
				types += str(int(field.roof_cells.get(key, 0)))
				rise.append(snappedf(float(field.roof_rise.get(key, 0.0)), 0.01))
		var vh: Array = []
		for v: float in RoofBuilder.vertex_heights(part):
			vh.append(snappedf(v, 0.01))
		var plane: int = 0
		if not cells.is_empty():
			plane = int(field.roof_elevations.get(cells[0], 0))
		var rec: Dictionary = {
			"id": int(part.get("id", out.size())),
			"bld": int(part.get("building", -1)),
			"level": level,
			"shape": String(part.get("shape", "")),
			"kind": String(part.get("kind", "")),
			"rect": [rect.position.x, rect.position.y, w, h],
			"plane": plane,
			"base": snappedf(float(part.get("base", 0.0)), 0.01),
			"types": types,
			"rise": rise,
			"vh": vh,
		}
		if part.has("dome"):
			var dm: Dictionary = part["dome"] as Dictionary
			rec["dome"] = {
				"cx": snappedf(float(dm.get("cx", 0.0)), 0.01),
				"cy": snappedf(float(dm.get("cy", 0.0)), 0.01),
				"a": snappedf(float(dm.get("a", 0.0)), 0.01),
				"b": snappedf(float(dm.get("b", 0.0)), 0.01),
				"h": snappedf(float(dm.get("h", 0.0)), 0.01),
				"crown": int(dm.get("crown", 1)),
				"plateau": snappedf(float(dm.get("plateau", 0.0)), 0.01),
			}
		out.append(rec)
	return out


#Floor numbers of an interior map, top floor first; empty on an exterior map.
static func _floor_list(field: BattlefieldArea) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in field.interior_floor_elevations.keys():
		out.append(k as int)
	out.sort()
	out.reverse()
	return out


#Vector3i keys of d as [x, y, floor] arrays, in key order.
static func _triples(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		var pos := k as Vector3i
		out.append([pos.x, pos.y, pos.z])
	return out


#Vector2i keys of d as [x, y] arrays, in key order.
static func _pairs(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		var pos := k as Vector2i
		out.append([pos.x, pos.y])
	return out


static func _build_html(field: BattlefieldArea) -> String:
	var data := _extract_data(field)
	var json_str := JSON.stringify(data)
	var title := field.area_name + " - 3D"
	var type_label := "EXTERIOR"
	if field.is_dungeon:
		type_label = "DUNGEON"
		title += " D=%.1f" % field.dungeon_difficulty
	elif field.is_city:
		type_label = "CITY"
	elif field.is_interior_map:
		type_label = "INTERIOR"
	elif field.is_cavern:
		type_label = "CAVERN"
	if field.is_interior_map:
		var names: Array[String] = []
		for f: Variant in (data["floor_list"] as Array):
			names.append("F%d" % int(f))
		title += " floors=%s" % ",".join(names)
	var wh := "%dx%d" % [field.width, field.length]
	var num_floors: int = field.interior_floor_elevations.size()
	var slider_max: String = str(max(1, num_floors - 1)) if field.is_interior_map else "10"

	var html := _html_template()
	html = html.replace("{{SCENE_DATA}}", json_str)
	html = html.replace("{{TITLE}}", title)
	html = html.replace("{{TYPE_LABEL}}", type_label)
	html = html.replace("{{WH}}", wh)
	html = html.replace("{{SLIDER_MAX}}", slider_max)
	html = html.replace("{{EXPLODE_ON}}", " checked" if field.is_dungeon else "")
	return html


static func _html_template() -> String:
	return ViewerTemplate.text()

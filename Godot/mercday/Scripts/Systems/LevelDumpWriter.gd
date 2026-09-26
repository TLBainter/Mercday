class_name LevelDumpWriter
extends RefCounted

#Writes the generated level structure of one encounter to <stem>_level.txt.

const GRID_DIGITS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


static func save(field: BattlefieldArea, stem: String) -> void:
	if stem == "":
		return
	var fa := FileAccess.open(stem + "_level.txt", FileAccess.WRITE)
	if fa == null:
		return
	var lines: Array[String] = []
	lines.append("=== Level Structure ===")
	lines.append("Map: %dx%d  fh: %d" % [field.width, field.length, field.interior_floor_height])
	for f_num: Variant in field.interior_floor_elevations.keys():
		var floor_num: int = f_num as int
		var elev: int = field.interior_floor_elevations[floor_num]
		lines.append("F%d: elevation=%d" % [floor_num, elev])
	lines.append("")
	if field.is_cavern:
		CavernDumpWriter.append_cavern(field, lines)
		fa.store_string("\n".join(lines) + "\n")
		fa.close()
		return
	if field.is_interior_map:
		var fp: Rect2i = field.building_footprint
		lines.append("FOOTPRINT: %d,%d %dx%d" % [fp.position.x, fp.position.y, fp.size.x, fp.size.y])
		_append_masks(field, lines)
	_append_roofs(field, lines)
	var elev_keys: Array = field.interior_floor_elevations.keys()
	elev_keys.sort()
	for ek: Variant in elev_keys:
		lines.append("FLOOR ELEV: F%d=%d" % [ek as int, field.interior_floor_elevations[ek] as int])
	var run_keys: Array = field.stair_runs.keys()
	run_keys.sort()
	for rk: Variant in run_keys:
		var rf: int = rk as int
		var runs: Array = field.stair_runs[rf] as Array
		for entry: Variant in runs:
			var run: Dictionary = entry as Dictionary
			var rcount: int = 0
			for sk: Variant in field.stair_run_cells.keys():
				var sc: Vector3i = sk as Vector3i
				if sc.z != rf:
					continue
				if runs.size() > 1 and (absi(sc.x - int(run["sx"])) > 1 or sc.y < int(run["ly"]) or sc.y > int(run["uy"])):
					continue
				rcount += 1
			var rdir: String = "up" if int(run.get("up", 1)) > 0 else "down"
			lines.append("STAIRS: F%d (%d,%d) -> F%d (%d,%d) run=%d cells dir=%s" % [
				rf, int(run["sx"]), BattlefieldArea.run_top_y(run), rf - 1, int(run["sx"]),
				BattlefieldArea.run_bottom_y(run), rcount, rdir])
	if not field.buildings.is_empty():
		lines.append("BUILDINGS: %d" % field.buildings.size())
		for rec: Dictionary in field.buildings:
			var floors: Array = rec.get("floors", []) as Array
			var lo_f: int = int(floors[0]) if not floors.is_empty() else 0
			var hi_f: int = int(floors[floors.size() - 1]) if not floors.is_empty() else 0
			var br: Rect2i = rec.get("rect", Rect2i())
			var fd: Vector3i = rec.get("front_door", Vector3i(-1, -1, 0))
			lines.append("BUILDING: id=%d name=%s class=%s front=%s fh=%d floors=%d..%d rect=%d,%d %dx%d door=%d,%d" % [
				int(rec.get("id", -1)), String(rec.get("name", "")), String(rec.get("size_class", "")),
				String(rec.get("front", "")), int(rec.get("fh", 0)), lo_f, hi_f, br.position.x, br.position.y,
				br.size.x, br.size.y, fd.x, fd.y])
	if field.is_city:
		CityDumpWriter.append_city_model(field, lines)
	var drop_count: int = 0
	var drop_balcony: int = 0
	var drop_window: int = 0
	var drop_roof: int = 0
	for dk: Variant in field.drop_links.keys():
		for dl: Dictionary in (field.drop_links[dk] as Array):
			var dkind: String = str(dl["kind"])
			if dkind == "roof":
				drop_roof += 1
				continue
			drop_count += 1
			if dkind == "window":
				drop_window += 1
			else:
				drop_balcony += 1
	lines.append("DROP LINKS: %d (balcony=%d window=%d)" % [drop_count, drop_balcony, drop_window])
	for dk2: Variant in field.drop_links.keys():
		var dfrom: Vector3i = dk2 as Vector3i
		for dl2: Dictionary in (field.drop_links[dk2] as Array):
			if str(dl2["kind"]) == "roof":
				continue
			var dto: Vector3i = dl2["to"] as Vector3i
			lines.append("drop %s (%d,%d) F%d -> (%d,%d) F%d paces=%d" % [
				str(dl2["kind"]), dfrom.x, dfrom.y, dfrom.z, dto.x, dto.y, dto.z, int(dl2["paces"])])
	if drop_roof > 0:
		lines.append("ROOF DROP LINKS: %d" % drop_roof)
	var climb_count: int = 0
	for ck: Variant in field.climb_links.keys():
		climb_count += (field.climb_links[ck] as Array).size()
	if climb_count > 0:
		lines.append("CLIMB LINKS: %d" % climb_count)
	var roof_obj_count: int = 0
	for robs: Dictionary in field.obstacles:
		if bool(robs.get("roof_object", false)):
			roof_obj_count += 1
	if roof_obj_count > 0:
		lines.append("ROOF OBJECTS: %d" % roof_obj_count)
	for wobs: Dictionary in field.obstacles:
		if wobs.get("cell_type", "") != "window":
			continue
		var wcell := BattlefieldArea.cell_of(wobs["pos"])
		var wpos := Vector3i(wcell.x, wcell.y, BattlefieldArea.floor_of(wobs["pos"]))
		lines.append("WINDOWS: F%d (%d,%d) %s" % [
			wpos.z, wpos.x, wpos.y, "broken" if wobs.get("broken", false) else "intact"])
	lines.append("")
	lines.append("--- Rooms ---")
	for entry: Dictionary in field.interior_rooms:
		var rect: Rect2i = entry["rect"] as Rect2i
		var rname: String = entry["name"] as String
		var fl: int = entry["floor"] as int
		lines.append("F%d  %s  pos=(%d,%d) size=%dx%d" % [fl, rname, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	lines.append("")
	lines.append("--- Doors ---")
	for obs: Dictionary in field.obstacles:
		if obs.get("cell_type", "") != "door":
			continue
		var dcell := BattlefieldArea.cell_of(obs["pos"])
		var pos := Vector3i(dcell.x, dcell.y, BattlefieldArea.floor_of(obs["pos"]))
		var orient: String = obs.get("orientation", "v")
		var extra: String = ""
		if obs.get("bars", false):
			extra += " bars"
		if obs.get("locked", false):
			extra += " locked d=%d" % int(obs.get("lock_difficulty", 0))
		lines.append("door (%d,%d) F%d orient=%s%s" % [pos.x, pos.y, pos.z, orient, extra])
	lines.append("")
	lines.append("--- Stairwells ---")
	for p: Variant in field.stairwell_cells.keys():
		var pos: Vector3i = p as Vector3i
		lines.append("stairwell (%d,%d) F%d" % [pos.x, pos.y, pos.z])
	if field.is_dungeon:
		_append_dungeon(field, lines)
	elif field.is_interior_map:
		_append_floor_maps(field, lines, "=== Interior ===")
	if field.is_city:
		CityDumpWriter.append_city_surface(field, lines)
		CityDumpWriter.append_city_objects(field, lines)
	_append_roof_maps(field, lines)
	fa.store_string("\n".join(lines) + "\n")
	fa.close()


#One MASK line per floor: cell count and how much of that floor's own bounding box it fills.
static func _append_masks(field: BattlefieldArea, lines: Array[String]) -> void:
	if field.footprint_cells.is_empty():
		return
	var fkeys: Array = field.interior_floor_elevations.keys()
	fkeys.sort()
	fkeys.reverse()
	for fk: Variant in fkeys:
		var f: int = fk as int
		var info: Dictionary = DungeonGenerator.mask_info(field, f)
		var count: int = int(info["count"])
		var box: Rect2i = info["rect"] as Rect2i
		var pct: int = int(info["fill"])
		lines.append("MASK F%d: %d cells (%d%% of %dx%d box)" % [f, count, pct, box.size.x, box.size.y])


#One ROOF line per roof part: shape, extent, cell type counts, roof plane and greatest rise.
static func _append_roofs(field: BattlefieldArea, lines: Array[String]) -> void:
	for part: Dictionary in field.roof_parts:
		var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
		var cells: Array = part.get("cells", []) as Array
		var tally: Dictionary = RoofBuilder.counts(field, part)
		var plane: int = 0
		if not cells.is_empty():
			var first: Vector2i = cells[0] as Vector2i
			plane = int(field.roof_elevations.get(first, 0))
		var high: String = String(part.get("high", ""))
		var axis: String = String(part.get("axis", ""))
		lines.append("ROOF: part=%d bld=%d level=%d shape=%s kind=%s rect=(%d,%d %dx%d) cells=%d flat=%d slope=%d peak=%d solid=%d plane=%d max_rise=%.2f high=%s axis=%s" % [
			int(part.get("id", -1)), int(part.get("building", -1)), int(part.get("level", 0)),
			String(part.get("shape", "")), String(part.get("kind", "")),
			rect.position.x, rect.position.y, rect.size.x, rect.size.y, cells.size(),
			int(tally.get("flat", 0)), int(tally.get("slope", 0)), int(tally.get("peak", 0)),
			int(tally.get("solid", 0)), plane, float(part.get("max_rise", 0.0)),
			"-" if high == "" else high, "-" if axis == "" else axis])


#One ASCII map per roof level, highest level first, over that level's own bounding rect.
static func _append_roof_maps(field: BattlefieldArea, lines: Array[String]) -> void:
	if field.roof_parts.is_empty():
		return
	var levels: Array = []
	var lo: Dictionary = {}
	var hi: Dictionary = {}
	for k: Variant in field.roof_cells.keys():
		var c: Vector3i = k as Vector3i
		if not lo.has(c.z):
			levels.append(c.z)
			lo[c.z] = Vector2i(c.x, c.y)
			hi[c.z] = Vector2i(c.x, c.y)
			continue
		var l: Vector2i = lo[c.z] as Vector2i
		var h: Vector2i = hi[c.z] as Vector2i
		lo[c.z] = Vector2i(mini(l.x, c.x), mini(l.y, c.y))
		hi[c.z] = Vector2i(maxi(h.x, c.x), maxi(h.y, c.y))
	if levels.is_empty():
		return
	levels.sort()
	levels.reverse()
	lines.append("")
	lines.append("=== Roofs (_ flat / slope ^ peak X solid . none, P parapet M merlon C chimney D dormer) ===")
	if not field.is_interior_map:
		#Outdoor huts stand apart, so each one prints its own map.
		for part: Dictionary in field.roof_parts:
			var pr: Rect2i = part.get("rect", Rect2i()) as Rect2i
			var pl: int = int(part.get("level", 1))
			lines.append("")
			lines.append("--- Roof level %d hut %d origin=(%d,%d) size=%dx%d ---" % [
				pl, int(part.get("building", -1)), pr.position.x, pr.position.y, pr.size.x, pr.size.y])
			for y: int in range(pr.position.y, pr.end.y):
				var hut_row := ""
				for x: int in range(pr.position.x, pr.end.x):
					hut_row += _roof_glyph(field, Vector3i(x, y, pl))
				lines.append(hut_row)
		return
	for lk: Variant in levels:
		var level: int = lk as int
		var box_lo: Vector2i = lo[level] as Vector2i
		var box_hi: Vector2i = hi[level] as Vector2i
		lines.append("")
		lines.append("--- Roof level %d origin=(%d,%d) size=%dx%d ---" % [
			level, box_lo.x, box_lo.y, box_hi.x - box_lo.x + 1, box_hi.y - box_lo.y + 1])
		for y: int in range(box_lo.y, box_hi.y + 1):
			var row := ""
			for x: int in range(box_lo.x, box_hi.x + 1):
				row += _roof_glyph(field, Vector3i(x, y, level))
			lines.append(row)


static func _roof_glyph(field: BattlefieldArea, key: Vector3i) -> String:
	var kind: int = int(field.roof_cells.get(key, -1))
	if kind < 0 or kind >= RoofBuilder.GLYPHS.length():
		return "."
	var obs: Dictionary = field.get_obs(Vector2i(key.x, key.y), key.z)
	if bool(obs.get("roof_object", false)):
		var d: ObstacleData = obs.get("data") as ObstacleData
		var oname: String = "" if d == null else d.obstacle_name
		if oname == "Parapet":
			return "P"
		if oname == "Merlon":
			return "M"
		if oname == "Chimney" or oname == "Large Chimney":
			return "C"
		if oname == "Dormer":
			return "D"
	return RoofBuilder.GLYPHS[kind]


#One ASCII map per floor, deepest floor last; header is skipped when empty.
static func _append_floor_maps(field: BattlefieldArea, lines: Array[String], header: String) -> void:
	if header != "":
		lines.append("")
		lines.append(header)
	var keys: Array = field.interior_floor_elevations.keys()
	keys.sort()
	keys.reverse()
	for fk: Variant in keys:
		var f: int = fk as int
		var box: Rect2i = DungeonGenerator.mask_info(field, f)["rect"] as Rect2i
		lines.append("")
		lines.append("--- F%d (# wall . hall , room c cell + door L locked E entrance S stairs ~ run/void r band f furn w window b ext F fence) ---" % f)
		for y: int in range(field.length):
			var row := ""
			for x: int in range(field.width):
				row += _dungeon_glyph(field, Vector3i(x, y, f), box)
			lines.append(row)


#Dungeon stats, hall segments and one ASCII map per floor.
static func _append_dungeon(field: BattlefieldArea, lines: Array[String]) -> void:
	var st: Dictionary = field.dungeon_stats
	lines.append("")
	lines.append("=== Dungeon ===")
	lines.append("DIFFICULTY: %.1f  floors: %d  rooms: %d  cells: %d" % [field.dungeon_difficulty,
		int(st.get("floors", 0)), int(st.get("chambers", 0)), int(st.get("cells", 0))])
	lines.append("HALLS: %d  loops: %d  dead ends: %d  walls: %d" % [int(st.get("halls", 0)),
		int(st.get("loops", 0)), int(st.get("dead_ends", 0)), int(st.get("walls", 0))])
	lines.append("ENTRANCE: %s" % ("(%d,%d)" % [field.entrance_cells[0].x, field.entrance_cells[0].y]
		if not field.entrance_cells.is_empty() else "none"))
	lines.append("SPAWN: A F%d (%d,%d) zone=%d  B F%d (%d,%d) zone=%d" % [
		field.spawn_floor_a, field.spawn_center_a.x, field.spawn_center_a.y, field.spawn_zone_a.size(),
		field.spawn_floor_b, field.spawn_center_b.x, field.spawn_center_b.y, field.spawn_zone_b.size()])
	for hall: Dictionary in field.dungeon_halls:
		var hr: Rect2i = hall["rect"] as Rect2i
		lines.append("hall F%d %s pos=(%d,%d) size=%dx%d" % [int(hall.get("floor", 0)),
			str(hall.get("name", "")), hr.position.x, hr.position.y, hr.size.x, hr.size.y])
	_append_floor_maps(field, lines, "")


static func _dungeon_glyph(field: BattlefieldArea, c: Vector3i, box: Rect2i) -> String:
	var flat := Vector2i(c.x, c.y)
	var obs: Dictionary = field._obs_map.get(c, {}) as Dictionary
	var ct: String = String(obs.get("cell_type", ""))
	if not field.in_footprint_floor(flat, c.z):
		if ct == "fence":
			return "F"
		if field.building_interiors.has(c):
			return "b"
		if field.is_void(flat, c.z) and box.has_point(flat):
			return "~"
		return " "
	if ct == "door":
		if obs.get("locked", false):
			return "L"
		if field.entrance_cells.has(flat):
			return "E"
		return "+"
	if ct == "wall":
		return "#"
	if ct == "window":
		return "w"
	if ct == "fence":
		return "F"
	if ct == "stairs":
		return "S"
	if ct == "stair_run":
		return "~"
	if ct == "reserved_stairwell":
		return "r"
	if ct == "furniture":
		return "f"
	if ct != "":
		return "X"
	for entry: Dictionary in field.interior_rooms:
		if int(entry.get("floor", 0)) != c.z:
			continue
		if not (entry["rect"] as Rect2i).has_point(flat):
			continue
		return "c" if String(entry.get("name", "")) == DungeonGenerator.CELL_ROW else ","
	return "."

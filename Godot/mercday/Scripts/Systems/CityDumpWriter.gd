class_name CityDumpWriter
extends RefCounted


const CITY_LEGEND := "Legend: # main street  = side street  : sidewalk  a alley  0-9 lot (id mod 10)  , nature  ? none"
const CITY_OBJ_LEGEND := "Legend: A/B spawn  D door  # building  L lamp  Q square  o object  T tree  \" grass  + protected  a/b zone  = street  : walk  ~ alley  . ground"


#One CITY line, then every street, block, plot and lot of a city block map.
static func append_city_model(field: BattlefieldArea, lines: Array[String]) -> void:
	var city: Dictionary = field.city
	var stats: Dictionary = city.get("stats", {})
	var blocks: Array = city.get("blocks", [])
	lines.append("CITY: tier=%s size=%dx%d main_w=%d pitch=%d mains=%d sides=%d alleys=%d deadends=%d blocks=%d plots=%d/%d/%d lots=%d nature=%d%% tries=%d" % [
		String(city.get("tier", "")), field.width, field.length, int(city.get("main_w", 0)),
		int(city.get("pitch", 0)), int(stats.get("mains", 0)), int(stats.get("sides", 0)),
		int(stats.get("alleys", 0)), int(stats.get("dead_ends", 0)), blocks.size(),
		int(stats.get("plots_large", 0)), int(stats.get("plots_medium", 0)),
		int(stats.get("plots_small", 0)), int(stats.get("lots", 0)),
		int(round(float(stats.get("nature_pct", 0.0)))), int(city.get("tries", 0))])
	for street: Dictionary in (city.get("streets", []) as Array):
		lines.append(_street_line(street))
	for block: Dictionary in blocks:
		var brect: Rect2i = block.get("rect", Rect2i())
		lines.append("BLOCK %d: rect=%d,%d %dx%d full=%s mains=%s" % [
			int(block.get("id", -1)), brect.position.x, brect.position.y, brect.size.x, brect.size.y,
			"true" if bool(block.get("full", false)) else "false",
			",".join(_as_strings(block.get("main_sides", [])))])
	for plot: Dictionary in (city.get("plots", []) as Array):
		var prect: Rect2i = plot.get("rect", Rect2i())
		lines.append("PLOT %d: block=%d rect=%d,%d %dx%d class=%s lots=%s" % [
			int(plot.get("id", -1)), int(plot.get("block", -1)), prect.position.x, prect.position.y,
			prect.size.x, prect.size.y, String(plot.get("class", "")),
			",".join(_as_strings(plot.get("lots", [])))])
	for lot: Dictionary in (city.get("lots", []) as Array):
		var lrect: Rect2i = lot.get("rect", Rect2i())
		var rows: Array = lot.get("rows", [])
		lines.append("LOT %d: plot=%d rect=%d,%d %dx%d class=%s front=%s kind=%s rows=%d building=%d" % [
			int(lot.get("id", -1)), int(lot.get("plot", -1)), lrect.position.x, lrect.position.y,
			lrect.size.x, lrect.size.y, String(lot.get("class", "")), String(lot.get("front", "")),
			String(lot.get("front_kind", "")), rows.size(), int(lot.get("building", -1))])
	for lot2: Dictionary in (city.get("lots", []) as Array):
		if not lot2.has("failed"):
			continue
		lines.append("LOTFAIL %d: tried=%s" % [
			int(lot2.get("id", -1)), ",".join(_as_strings(lot2.get("tried", [])))])
	if city.has("spawn"):
		var spawn: Dictionary = city.get("spawn", {})
		lines.append(_spawn_line(field, spawn, "A"))
		lines.append(_spawn_line(field, spawn, "B"))
	if city.has("objects"):
		var objects: Dictionary = city.get("objects", {})
		lines.append("OBJECTS: nature=%d blocking=%d lamp=%d alley=%d sidewalk=%d square=%d rolled_back=%d" % [
			int(objects.get("nature", 0)), int(objects.get("blocking", 0)), int(objects.get("lamp", 0)),
			int(objects.get("alley", 0)), int(objects.get("sidewalk", 0)), int(objects.get("square", 0)),
			int(objects.get("rolled_back", 0))])
	var access: Dictionary = city.get("access", {})
	for door: Dictionary in (access.get("doors", []) as Array):
		var dpos: Vector3i = door.get("door", Vector3i(-1, -1, 0))
		var outside: Vector2i = door.get("outside", Vector2i(-1, -1))
		lines.append("DOOR: building=%d kind=%s door=%d,%d outside=%d,%d%s" % [
			int(door.get("building", -1)), String(door.get("kind", "")),
			dpos.x, dpos.y, outside.x, outside.y, " yard" if door.has("yard") else ""])
	for obs: Dictionary in field.obstacles:
		if not obs.has("city"):
			continue
		var tag: String = String(obs.get("city", ""))
		if tag == "nature":
			continue
		var ocell := BattlefieldArea.cell_of(obs["pos"])
		var od: ObstacleData = obs.get("data") as ObstacleData
		lines.append("CITYOBJ: %s %d,%d %dx%d tag=%s" % [
			od.obstacle_name if od != null else "?", ocell.x, ocell.y,
			int(obs.get("pw", 1)), int(obs.get("ph", 1)), tag])


#One SPAWN line per team: map side, centre cell, outdoor cell count and the buildings it opened.
static func _spawn_line(field: BattlefieldArea, spawn: Dictionary, team: String) -> String:
	var low: String = team.to_lower()
	var centre: Vector2i = field.spawn_center_a if team == "A" else field.spawn_center_b
	var ids: Array[String] = _as_strings(spawn.get("buildings_" + low, []))
	return "SPAWN %s: side=%d centre=%d,%d outdoor=%d buildings=%s" % [
		team, int(spawn.get("side_" + low, -1)), centre.x, centre.y,
		int(spawn.get("outdoor_" + low, 0)), "-" if ids.is_empty() else ",".join(ids)]


#Kind, axis, ending, block, segment count, segment width range and every segment rect of one street.
static func _street_line(street: Dictionary) -> String:
	var segs: Array = street.get("segments", [])
	var w_lo: int = 0
	var w_hi: int = 0
	var rects: Array[String] = []
	for seg: Dictionary in segs:
		var r: Rect2i = seg.get("rect", Rect2i())
		var w: int = int(seg.get("width", 0))
		w_lo = w if rects.is_empty() else mini(w_lo, w)
		w_hi = maxi(w_hi, w)
		rects.append("%d,%d %dx%d" % [r.position.x, r.position.y, r.size.x, r.size.y])
	var block_id: int = int(street.get("block", -1))
	var block_txt: String = "" if block_id < 0 else ("block=%d " % block_id)
	var mouth: Vector2i = street.get("mouth", Vector2i(-1, -1))
	var back_txt: String = "" if not street.has("back_door") else (" backdoor=%d" % int(street.get("back_door", -1)))
	return "STREET %d: %s axis=%s %s %ssegs=%d w=%d..%d mouth=%d,%d rects=%s%s" % [
		int(street.get("id", -1)), String(street.get("kind", "")), String(street.get("axis", "")),
		"deadend" if bool(street.get("dead_end", false)) else "through", block_txt, segs.size(),
		w_lo, w_hi, mouth.x, mouth.y, "; ".join(rects), back_txt]


static func _as_strings(values: Array) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in values:
		out.append(str(v))
	return out


#The whole surface grid as one ASCII map; a lot cell carries the last digit of its lot id.
static func append_city_surface(field: BattlefieldArea, lines: Array[String]) -> void:
	var cells: int = field.width * field.length
	if cells <= 0 or field.surface_grid.size() < cells:
		return
	var lot_of := PackedInt32Array()
	lot_of.resize(cells)
	lot_of.fill(-1)
	for lot: Dictionary in (field.city.get("lots", []) as Array):
		var r: Rect2i = lot.get("rect", Rect2i())
		var lid: int = int(lot.get("id", -1))
		for y: int in range(maxi(r.position.y, 0), mini(r.end.y, field.length)):
			for x: int in range(maxi(r.position.x, 0), mini(r.end.x, field.width)):
				lot_of[y * field.width + x] = lid
	lines.append("")
	lines.append("=== Surface (floor 0) ===")
	lines.append(CITY_LEGEND)
	for y: int in range(field.length):
		var row := ""
		for x: int in range(field.width):
			row += _surface_glyph(field, lot_of, y * field.width + x)
		lines.append(row)


static func _surface_glyph(field: BattlefieldArea, lot_of: PackedInt32Array, index: int) -> String:
	match field.surface_grid[index]:
		BattlefieldArea.SURF_MAIN:
			return "#"
		BattlefieldArea.SURF_SIDE:
			return "="
		BattlefieldArea.SURF_SIDEWALK:
			return ":"
		BattlefieldArea.SURF_ALLEY:
			return "a"
		BattlefieldArea.SURF_NATURE:
			return ","
		BattlefieldArea.SURF_LOT:
			var lid: int = lot_of[index]
			return "*" if lid < 0 else LevelDumpWriter.GRID_DIGITS[lid % 10]
	return "?"


#One ASCII map of the placed city objects, doors, spawn cells and protected paths on floor 0.
static func append_city_objects(field: BattlefieldArea, lines: Array[String]) -> void:
	var cells: int = field.width * field.length
	if cells <= 0 or field.surface_grid.size() < cells:
		return
	var marks := PackedStringArray()
	marks.resize(cells)
	for obs: Dictionary in field.obstacles:
		if not obs.has("city"):
			continue
		var anchor := BattlefieldArea.cell_of(obs["pos"])
		var od: ObstacleData = obs.get("data") as ObstacleData
		var blocking: bool = od == null or not (od.passthrough or od.ramp)
		var mark: String = _city_obj_glyph(String(obs.get("city", "")), blocking)
		for oy: int in range(anchor.y, anchor.y + maxi(1, int(obs.get("ph", 1)))):
			for ox: int in range(anchor.x, anchor.x + maxi(1, int(obs.get("pw", 1)))):
				if not field.in_bounds_xy(ox, oy):
					continue
				marks[oy * field.width + ox] = mark
	var centres: Dictionary = {}
	if field.city.has("spawn"):
		centres[field.spawn_center_a] = "A"
		centres[field.spawn_center_b] = "B"
	var doors: Dictionary = {}
	for rec: Dictionary in field.buildings:
		for key: String in ["front_door", "back_door"]:
			var dv: Vector3i = rec.get(key, Vector3i(-1, -1, 0))
			if dv.x >= 0 and dv.z == 0:
				doors[Vector2i(dv.x, dv.y)] = true
	var access: Dictionary = field.city.get("access", {})
	var layers: Dictionary = {
		"marks": marks, "centres": centres, "doors": doors,
		"protected": access.get("protected", {}),
	}
	lines.append("")
	lines.append("=== City objects (floor 0) ===")
	lines.append(CITY_OBJ_LEGEND)
	for y: int in range(field.length):
		var row := ""
		for x: int in range(field.width):
			row += _city_cell_glyph(field, layers, y * field.width + x, Vector2i(x, y))
		lines.append(row)


static func _city_cell_glyph(field: BattlefieldArea, layers: Dictionary, index: int, flat: Vector2i) -> String:
	var centres: Dictionary = layers["centres"]
	if centres.has(flat):
		return String(centres[flat])
	var doors: Dictionary = layers["doors"]
	if doors.has(flat):
		return "D"
	if field.building_id_at.has(flat):
		return "#"
	var marks: PackedStringArray = layers["marks"]
	var mark: String = marks[index]
	if mark != "":
		return mark
	var guarded: Dictionary = layers["protected"]
	if guarded.has(flat):
		return "+"
	if field.spawn_zone_a.has(flat):
		return "a"
	if field.spawn_zone_b.has(flat):
		return "b"
	match field.surface_grid[index]:
		BattlefieldArea.SURF_MAIN, BattlefieldArea.SURF_SIDE:
			return "="
		BattlefieldArea.SURF_SIDEWALK:
			return ":"
		BattlefieldArea.SURF_ALLEY:
			return "~"
	return "."


static func _city_obj_glyph(tag: String, blocking: bool) -> String:
	match tag:
		"lamp":
			return "L"
		"square":
			return "Q"
		"alley", "sidewalk":
			return "o"
	return "T" if blocking else "\""

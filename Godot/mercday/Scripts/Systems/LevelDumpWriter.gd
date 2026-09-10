class_name LevelDumpWriter
extends RefCounted

#Writes the generated level structure of one encounter to <stem>_level.txt.


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
	if field.is_interior_map:
		var fp: Rect2i = field.building_footprint
		lines.append("FOOTPRINT: %d,%d %dx%d" % [fp.position.x, fp.position.y, fp.size.x, fp.size.y])
	var elev_keys: Array = field.interior_floor_elevations.keys()
	elev_keys.sort()
	for ek: Variant in elev_keys:
		lines.append("FLOOR ELEV: F%d=%d" % [ek as int, field.interior_floor_elevations[ek] as int])
	var run_keys: Array = field.stair_runs.keys()
	run_keys.sort()
	for rk: Variant in run_keys:
		var rf: int = rk as int
		var run: Dictionary = field.stair_runs[rf] as Dictionary
		var rcount: int = 0
		for sk: Variant in field.stair_run_cells.keys():
			if (sk as Vector3i).z == rf:
				rcount += 1
		var rdir: String = "up" if int(run.get("up", 1)) > 0 else "down"
		lines.append("STAIRS: F%d (%d,%d) -> F%d (%d,%d) run=%d cells dir=%s" % [
			rf, int(run["sx"]), BattlefieldArea.run_top_y(run), rf - 1, int(run["sx"]),
			BattlefieldArea.run_bottom_y(run), rcount, rdir])
	var drop_count: int = 0
	var drop_balcony: int = 0
	var drop_window: int = 0
	for dk: Variant in field.drop_links.keys():
		for dl: Dictionary in (field.drop_links[dk] as Array):
			drop_count += 1
			if str(dl["kind"]) == "window":
				drop_window += 1
			else:
				drop_balcony += 1
	lines.append("DROP LINKS: %d (balcony=%d window=%d)" % [drop_count, drop_balcony, drop_window])
	for dk2: Variant in field.drop_links.keys():
		var dfrom: Vector3i = dk2 as Vector3i
		for dl2: Dictionary in (field.drop_links[dk2] as Array):
			var dto: Vector3i = dl2["to"] as Vector3i
			lines.append("drop %s (%d,%d) F%d -> (%d,%d) F0 paces=%d" % [
				str(dl2["kind"]), dfrom.x, dfrom.y, dfrom.z, dto.x, dto.y, int(dl2["paces"])])
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
		lines.append("door (%d,%d) F%d orient=%s" % [pos.x, pos.y, pos.z, orient])
	lines.append("")
	lines.append("--- Stairwells ---")
	for p: Variant in field.stairwell_cells.keys():
		var pos: Vector3i = p as Vector3i
		lines.append("stairwell (%d,%d) F%d" % [pos.x, pos.y, pos.z])
	fa.store_string("\n".join(lines) + "\n")
	fa.close()

class_name BuildingMapWriter
extends RefCounted

#Renders a generated field as a building map and writes the outhouse map file.


static func gen_outhouse_map() -> void:
	var outhouse_data: ObstacleData = DataManager.get_obstacle_by_name("Outhouse")
	if outhouse_data == null:
		print("Outhouse not found in DataManager.")
		return
	var config := BuildingConfig.new()
	config.forced_template = outhouse_data
	config.max_count = 20
	var field := BattlefieldArea.generate_random(config)
	_write_outhouse_map(field)
	print("Outhouse map written to encounter_logs.")


static func _write_outhouse_map(field: BattlefieldArea) -> void:
	DirAccess.make_dir_absolute("user://encounter_logs")
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var path := "user://encounter_logs/outhouse_map_%s_%s.txt" % [date_str, time_str]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("Could not write outhouse map.")
		return
	var lines: PackedStringArray = []
	var outhouse_count: int = 0
	for b: Dictionary in field.building_data:
		if (b["name"] as String) == "Outhouse":
			outhouse_count += 1
	lines.append("=== OUTHOUSE MAP DEBUG ===")
	lines.append("Date: %s %s" % [date_str, time_str.replace("-", ":")])
	lines.append("Field: %dx%d  Outhouses: %d / %d total buildings" % [
		field.width, field.length, outhouse_count, field.building_data.size()])
	lines.append("Legend: # wall  D door  W window  T toilet  f furniture  . floor  (space) open")
	var maps: Dictionary = _building_cell_maps(field)
	lines.append("")
	lines.append_array(_render_map_rows(field, maps))
	lines.append("")
	lines.append("--- BUILDINGS ---")
	lines.append_array(_building_report(field))
	f.store_string("
".join(lines) + "
")
	f.close()


#Perimeter, interior and door cell sets of every building, keyed "perim", "interior" and "doors".
static func _building_cell_maps(field: BattlefieldArea) -> Dictionary:
	var perim: Dictionary = {}
	var interior: Dictionary = {}
	var doors: Dictionary = {}
	for b: Dictionary in field.building_data:
		var rect: Rect2i = b["rect"]
		var door_positions: Array = b["door_positions"]
		for bx: int in range(rect.size.x):
			for by: int in range(rect.size.y):
				var cell := rect.position + Vector2i(bx, by)
				var on_perim: bool = (bx == 0 or bx == rect.size.x - 1 or by == 0 or by == rect.size.y - 1)
				if on_perim:
					perim[cell] = true
					if door_positions.has(cell):
						doors[cell] = true
				else:
					interior[cell] = true
	return {"perim": perim, "interior": interior, "doors": doors}


#The building legend character of one obstacle cell; inside a building a wall reads as a period.
static func _cell_char(obs: Dictionary, inside: bool) -> String:
	var ct: String = obs.get("cell_type", "")
	if ct == "furniture":
		var d: ObstacleData = obs.get("data") as ObstacleData
		return "T" if d != null and d.obstacle_name == "Toilet" else "f"
	if ct == "wall":
		return "." if inside else "#"
	if inside:
		return "*"
	if ct == "door":
		return "D"
	if ct == "window":
		return "W"
	return "*"


static func _render_map_rows(field: BattlefieldArea, maps: Dictionary) -> PackedStringArray:
	var doors: Dictionary = maps["doors"]
	var perim: Dictionary = maps["perim"]
	var interior: Dictionary = maps["interior"]
	var rows: PackedStringArray = []
	for y: int in range(field.length):
		var row := ""
		for x: int in range(field.width):
			var p := Vector2i(x, y)
			var obs: Dictionary = field._obs_map.get(p, {})
			if doors.has(p):
				row += "D"
			elif perim.has(p):
				row += "W" if obs.get("cell_type", "") == "window" else "#"
			elif interior.has(p):
				row += _cell_char(obs, true) if field._obs_map.has(p) else "."
			elif field._obs_map.has(p):
				row += _cell_char(obs, false)
			else:
				row += " "
		rows.append(row)
	return rows


static func _building_report(field: BattlefieldArea) -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in range(field.building_data.size()):
		var b: Dictionary = field.building_data[i]
		var rect: Rect2i = b["rect"]
		var df: Vector2i = b["door_facing"]
		var guaranteed: Array = b.get("guaranteed_structures", [])
		out.append("Building %d: %s  pos=(%d,%d) size=%dx%d  door=(%d,%d)" % [
			i + 1, b["name"], rect.position.x, rect.position.y,
			rect.size.x, rect.size.y, df.x, df.y])
		if not guaranteed.is_empty():
			out.append("  Guaranteed: %s" % ", ".join(guaranteed))
		for ix: int in range(rect.position.x + 1, rect.end.x - 1):
			for iy: int in range(rect.position.y + 1, rect.end.y - 1):
				var p := Vector2i(ix, iy)
				if field._obs_map.has(p):
					var obs: Dictionary = field._obs_map[p]
					var d: ObstacleData = obs.get("data") as ObstacleData
					if d != null:
						out.append("  (%d,%d) %s" % [p.x, p.y, d.obstacle_name])
		if guaranteed.size() > 0:
			var has_contents := false
			for ix: int in range(rect.position.x + 1, rect.end.x - 1):
				for iy: int in range(rect.position.y + 1, rect.end.y - 1):
					if field._obs_map.has(Vector2i(ix, iy)):
						has_contents = true
			if not has_contents:
				out.append("  (empty - placement failed)")
	return out

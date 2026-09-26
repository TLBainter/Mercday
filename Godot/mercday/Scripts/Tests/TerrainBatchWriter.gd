class_name TerrainBatchWriter
extends RefCounted

#Renders generated fields as ASCII maps and writes the terrain batch file.


static func gen_terrain_batch() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/terrain_batch_%s_%s.txt" % [date_str, time_str]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("ERROR: Could not open terrain batch log.")
		return
	print("Generating 50 terrain levels...")
	var lines: PackedStringArray = []
	lines.append("TERRAIN BATCH - 50 LEVELS")
	lines.append("Generated: %s %s" % [date_str, time_str.replace("-", ":")])
	lines.append("Legend:  ! jagged  # solid  D door  s ramp  ~ passthrough  * damaging  | corridor  > spawn-row")
	lines.append("Heights: = very-deep(h<-4)  _ deep(h<-2)  , dip(h<-0.5)  . flat  ' rise(h<1.5)  n moderate(h<3)  ^ hill(h<5)  A high(h<7)  M peak(h>=7)")
	lines.append("")
	for i: int in range(50):
		var field := BattlefieldArea.generate_random()
		if (i + 1) % 10 == 0:
			print("  Generated %d/50..." % (i + 1))
		lines.append("=".repeat(64))
		lines.append("LEVEL %d - %s" % [i + 1, field.to_header_string()])
		lines.append("Jagged: %d  |  Obstacles: %d  |  Buildings: %d  |  Corridors: %d" % [
			field.jagged_cells.size(), field.obstacles.size(),
			field.building_data.size(), field.reserved_corridor_cells.size()])
		for log_entry: String in field.generation_log:
			lines.append("  " + log_entry)
		lines.append("")
		lines.append(_field_to_ascii_map(field))
		lines.append("")
		lines.append(_field_height_summary(field))
		lines.append("")
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("Terrain batch written to: " + path)


static func _field_to_ascii_map(field: BattlefieldArea) -> String:
	var rows: Array[String] = []
	for y: int in range(field.length):
		var any_spawn := false
		for _cx: int in range(field.width):
			if field._in_spawn_zone(Vector2i(_cx, y)):
				any_spawn = true
				break
		var row := "%2d%s " % [y, ">" if any_spawn else " "]
		for x: int in range(field.width):
			row += _map_cell(field, Vector2i(x, y))
		rows.append(row)
	return "\n".join(rows)


static func _map_cell(field: BattlefieldArea, pos: Vector2i) -> String:
	if field.jagged_cells.has(pos):
		return "!"
	var obs: Dictionary = field.get_obs(pos, 0)
	if not obs.is_empty():
		var d: ObstacleData = obs.get("data") as ObstacleData
		var ct: String = obs.get("cell_type", "")
		if ct == "door":
			return "d" if OpenCloseState.is_open(obs) else "D"
		if ct == "wall":
			return "#"
		if ct == "window":
			return "w" if obs.get("broken", false) else "W"
		if ct == "fence":
			return "f"
		if d != null and d.ramp:
			return "s"
		if d != null and d.passthrough:
			return "*" if (d.pt_enter_harm > 0 or d.pt_exit_harm > 0) else "~"
		return "#"
	if field.is_stair_cell(pos, 0):
		return "s"
	if field.reserved_corridor_cells.has(pos):
		return "|"
	var h: float = float(field.terrain_heights.get(pos, 0.0))
	if h <= -4.0:
		return "="
	if h <= -2.0:
		return "_"
	if h <= -0.5:
		return ","
	if h < 0.5:
		return "."
	if h < 1.5:
		return "'"
	if h < 3.0:
		return "n"
	if h < 5.0:
		return "^"
	if h < 7.0:
		return "A"
	return "M"


static func _field_height_summary(field: BattlefieldArea) -> String:
	var min_h: float = 0.0
	var max_h: float = 0.0
	var sum_h: float = 0.0
	var count: int = 0
	for cell: Variant in field.terrain_heights.keys():
		var h: float = float(field.terrain_heights[cell])
		if count == 0:
			min_h = h
			max_h = h
		else:
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
		sum_h += h
		count += 1
	var avg_h: float = (sum_h / float(count)) if count > 0 else 0.0
	var obs_tally: Dictionary = {}
	for obs: Dictionary in field.obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null:
			var n: String = d.obstacle_name
			obs_tally[n] = (obs_tally.get(n, 0) as int) + 1
	var obs_parts: Array[String] = []
	for k: Variant in obs_tally.keys():
		obs_parts.append("%s x%d" % [k as String, obs_tally[k] as int])
	return "Height: min=%.2f  max=%.2f  avg=%.2f  |  %s" % [
		min_h, max_h, avg_h,
		", ".join(obs_parts) if not obs_parts.is_empty() else "no obstacles"]

class_name EncounterLogger

const MAX_LOGS := 10
const LOG_DIR := "user://encounter_logs"

static var _file: FileAccess = null
static var _bbcode_rx: RegEx = null
static var _buffer: PackedStringArray = []
static var _current_stem: String = ""


static func begin(encounter_type: String, state: BattleState) -> void:
	_ensure_dir()
	_rotate()
	var dt := Time.get_datetime_dict_from_system()
	var session := "%06x" % randi()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var safe_type := encounter_type.replace(" ", "-").to_lower()
	var filename := "%s_log_%s_%s_%s.txt" % [safe_type, session, date_str, time_str]
	_current_stem = LOG_DIR + "/" + filename.get_basename()
	_file = FileAccess.open(LOG_DIR + "/" + filename, FileAccess.WRITE)
	if _file == null:
		push_warning("EncounterLogger: could not open %s" % filename)
		return
	if state != null and state.battlefield != null:
		WireframeGenerator.save(state.battlefield, _current_stem)
		HtmlWireframeGenerator.save(state.battlefield, _current_stem)
	_buffer.clear()
	_buffer.append("=== MercManager Encounter Log ===")
	_buffer.append("Type: %s   Session: %s   Date: %s %s" % [
		encounter_type, session, date_str, time_str.replace("-", ":")])
	if state != null:
		for i in state.teams.size():
			var names: Array[String] = []
			for m: MercenaryData in state.teams[i]:
				names.append(m.merc_name)
			_buffer.append("Team %d: %s" % [i, ", ".join(names)])
	_buffer.append("=================================")
	_buffer.append("")


static func end(result: Dictionary) -> void:
	if _file == null:
		return
	_buffer.append("")
	var winner: int = result.get("winner", -1)
	var rounds: int = result.get("rounds", 0)
	var winner_str := "Draw" if winner < 0 else ("Team %d wins" % winner)
	_buffer.append("=== RESULT: %s in %d round(s) ===" % [winner_str, rounds])
	flush()
	_file.close()
	_file = null


static func flush() -> void:
	if _file == null or _buffer.is_empty():
		return
	_file.store_string("\n".join(_buffer) + "\n")
	_buffer.clear()


static func is_active() -> bool:
	return _file != null


static func log_line(text: String) -> void:
	if _file == null:
		return
	_buffer.append(_strip_bbcode(text))


static func log_verbose(text: String) -> void:
	if _file == null:
		return
	_buffer.append("  >> " + text)


static func log_cover_scan(merc_name: String, search_range: int, candidates: Array, best_score: float) -> void:
	if _file == null:
		return
	if candidates.is_empty():
		_buffer.append("  [cover-scan] %s  radius=%d  -> no candidates in range" % [merc_name, search_range])
		return
	var parts: Array[String] = []
	for c: Dictionary in candidates:
		var pos: Vector2i = c["pos"]
		var dist: int = c["dist"]
		var skip: String = c.get("skip", "")
		if skip != "":
			parts.append("(%d,%d) d=%d skipped:%s" % [pos.x, pos.y, dist, skip])
		else:
			parts.append("(%d,%d) d=%d score=%.2f" % [pos.x, pos.y, dist, c.get("score", 0.0)])
	var result_str := "no usable cover" if best_score <= 0.0 else ("best=%.2f" % best_score)
	_buffer.append("  [cover-scan] %s  radius=%d  %s  -> %s" % [
		merc_name, search_range, " | ".join(parts), result_str])


static func log_misfire_check(merc_name: String, weapon_name: String, threshold: int, roll: int, misfired: bool) -> void:
	if _file == null:
		return
	var outcome := "MISFIRE" if misfired else "clear"
	_buffer.append("  [misfire-check] %s / %s  threshold=%d  roll=%d  -> %s" % [
		merc_name, weapon_name, threshold, roll, outcome])


static func log_generation(field: BattlefieldArea) -> void:
	if _file == null:
		return
	_buffer.append("--- Battlefield Generation ---")
	_buffer.append("Dimensions: %dx%d (height %d)  Cover: %s" % [
		field.width, field.length, field.height,
		BattlefieldArea.COVER_AMOUNT_NAMES[field.cover_amount]])
	var wall_count := 0
	var door_count := 0
	var passthrough_count := 0
	var damaging_count := 0
	var other_count := 0
	for obs: Dictionary in field.obstacles:
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			wall_count += 1
		elif ct == "door":
			door_count += 1
		else:
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d != null and d.passthrough:
				if d.pt_enter_harm > 0 or d.pt_exit_harm > 0:
					damaging_count += 1
				else:
					passthrough_count += 1
			else:
				other_count += 1
	_buffer.append("Obstacles: %d total  walls=%d  doors=%d  passthrough=%d  damaging=%d  solid=%d" % [
		field.obstacles.size(), wall_count, door_count, passthrough_count, damaging_count, other_count])
	if field.building_data.is_empty():
		_buffer.append("Buildings: none")
	else:
		for i: int in range(field.building_data.size()):
			var b: Dictionary = field.building_data[i]
			var rect: Rect2i = b["rect"] as Rect2i
			var door_positions: Array = b.get("door_positions", [])
			var door_parts: Array[String] = []
			for dp in door_positions:
				var v: Vector2i = dp
				door_parts.append("(%d,%d)" % [v.x, v.y])
			_buffer.append("Building %d [%s]: pos=(%d,%d) size=%dx%d  doors=%d at %s" % [
				i + 1, b.get("name", "?"),
				rect.position.x, rect.position.y, rect.size.x, rect.size.y,
				door_positions.size(), ", ".join(door_parts)])
	_buffer.append("---")
	for entry: String in field.generation_log:
		log_verbose(entry)
	_write_level_log(field)


static func _write_level_log(field: BattlefieldArea) -> void:
	if _current_stem == "":
		return
	var fa := FileAccess.open(_current_stem + "_level.txt", FileAccess.WRITE)
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
		var pos: Vector3i = obs["pos"] as Vector3i
		var orient: String = obs.get("orientation", "v")
		lines.append("door (%d,%d) F%d orient=%s" % [pos.x, pos.y, pos.z, orient])
	lines.append("")
	lines.append("--- Stairwells ---")
	for p: Variant in field.stairwell_cells.keys():
		var pos: Vector3i = p as Vector3i
		lines.append("stairwell (%d,%d) F%d" % [pos.x, pos.y, pos.z])
	fa.store_string("\n".join(lines) + "\n")
	fa.close()


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LOG_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))


static func _rotate() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return
	var entries: Array[Dictionary] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".txt") and not name.ends_with("_level.txt"):
			var full := LOG_DIR + "/" + name
			entries.append({"name": name, "mtime": FileAccess.get_modified_time(full)})
		name = dir.get_next()
	dir.list_dir_end()
	if entries.size() < MAX_LOGS:
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["mtime"] < b["mtime"])
	var to_delete := entries.size() - MAX_LOGS + 1
	for i in to_delete:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + entries[i]["name"]))
		var svg_name: String = (entries[i]["name"] as String).get_basename() + ".svg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + svg_name))
		var level_name: String = (entries[i]["name"] as String).get_basename() + "_level.txt"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + level_name))
		var html_name: String = (entries[i]["name"] as String).get_basename() + "_3d.html"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + html_name))


static func _strip_bbcode(text: String) -> String:
	if _bbcode_rx == null:
		_bbcode_rx = RegEx.new()
		_bbcode_rx.compile("\\[[^\\]]*\\]")
	return _bbcode_rx.sub(text, "", true)

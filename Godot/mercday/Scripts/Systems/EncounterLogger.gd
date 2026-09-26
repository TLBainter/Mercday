class_name EncounterLogger

const LOG_DIR := "user://encounter_logs"

static var _file: FileAccess = null
static var _bbcode_rx: RegEx = null
static var _buffer: PackedStringArray = []
static var _current_stem: String = ""
static var _field: BattlefieldArea = null
#While true no log file is opened; batch runs use it to skip per-encounter logs.
static var suppressed := false


static func begin(encounter_type: String, state: BattleState) -> void:
	if suppressed:
		return
	_ensure_dir()
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
	_field = null
	if state != null and state.battlefield != null:
		_field = state.battlefield
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
		for i in state.teams.size():
			_buffer.append("Team %d gear: %s" % [i, ", ".join(_gear_notes(state.teams[i]))])
	_buffer.append("=================================")
	_buffer.append("")


#Per merc: fly when the merc can fly, then the weapons held and packed.
static func _gear_notes(team: Array) -> Array[String]:
	var notes: Array[String] = []
	for m: MercenaryData in team:
		var parts: Array[String] = []
		if int(m.stats.get("fly", 0)) > 0:
			parts.append("fly")
		if m.equipped_weapon != null and not m.equipped_weapon.is_virtual:
			parts.append(m.equipped_weapon.item_name)
		for entry: Dictionary in m.inventory:
			if entry.get("type") != "weapon":
				continue
			var w: WeaponData = entry.get("data") as WeaponData
			if w != null:
				parts.append(w.item_name)
		notes.append("%s [%s] %s" % [m.merc_name, " / ".join(parts), Encumbrance.short_text(m)])
	return notes


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
	if _file == null:
		return
	if _buffer.is_empty():
		return
	_file.store_string("\n".join(_buffer) + "\n")
	_buffer.clear()


static func is_active() -> bool:
	return _file != null


#Full path of the log file the last begin() opened; empty before the first encounter.
static func current_log_path() -> String:
	return _current_stem + ".txt" if _current_stem != "" else ""


#Buffers one already stripped line; a no-op while no log file is open.
static func _append(line: String) -> void:
	if _file == null:
		return
	_buffer.append(line)


#Per-floor map with every merc's starting cell marked by team number.
static func log_spawn_map(state: BattleState) -> void:
	if _field == null or state == null:
		return
	var spawns: Array[Dictionary] = []
	for i: int in state.teams.size():
		for m: MercenaryData in state.teams[i]:
			spawns.append({"team": i, "floor": state.get_floor(m), "pos": state.get_position(m)})
	_append("SPAWN MAP")
	_append(BattlefieldRender.to_spawn_map_string(_field, spawns))


static func log_line(text: String) -> void:
	_append(_strip_bbcode(text))


static func log_verbose(text: String) -> void:
	_append("  >> " + _strip_bbcode(text))


static func log_cover_scan(merc_name: String, search_range: int, candidates: Array, best_score: float) -> void:
	if candidates.is_empty():
		_append("  [cover-scan] %s  radius=%d  -> no candidates in range" % [merc_name, search_range])
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
	_append("  [cover-scan] %s  radius=%d  %s  -> %s" % [
		merc_name, search_range, " | ".join(parts), result_str])


static func log_misfire_check(merc_name: String, weapon_name: String, threshold: int, roll: int, misfired: bool,
		crit_saved: bool = false) -> void:
	var outcome := "MISFIRE" if misfired else "clear"
	if crit_saved:
		outcome = "clear (crit)"
	_append("  [misfire-check] %s / %s  threshold=%d  roll=%d  -> %s" % [
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
	if field.is_cavern:
		var pools := 0
		for ch: Dictionary in field.cavern_chambers:
			if ch.get("flooded", false) as bool:
				pools += 1
		_buffer.append("Cavern: chambers=%d tunnels=%d entrances=%d pools=%d scatters=%d" % [
			field.cavern_chambers.size(), field.cavern_tunnels.size(),
			_cavern_entrance_count(field), pools, field.obstacles.size() - wall_count])
	elif field.is_city:
		_buffer.append_array(_city_lines(field))
	elif field.is_interior_map:
		var ifp: Rect2i = field.building_footprint
		_buffer.append("Buildings: interior  footprint=(%d,%d) %dx%d (shell walls included) mask=%d cells" % [
			ifp.position.x, ifp.position.y, ifp.size.x, ifp.size.y, field.footprint_union.size()])
	elif field.building_data.is_empty():
		_buffer.append("Buildings: none (0 placed exterior buildings)")
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


#The two city summary lines of a generation block; readable without an open log file.
static func _city_lines(field: BattlefieldArea) -> PackedStringArray:
	var city: Dictionary = field.city
	var stats: Dictionary = city.get("stats", {})
	var spawn: Dictionary = city.get("spawn", {})
	var out := PackedStringArray()
	out.append("City: tier=%s mains=%d sides=%d alleys=%d dead_ends=%d plots=%d/%d/%d lots=%d buildings=%d failed_lots=%d back_lanes=%d street_objects=%d nature_objects=%d nature=%d%% tries=%d alley_ring=%d alley_conn=%d connectors=%d isolated=%d connect_d=%d" % [
		String(city.get("tier", "")), int(stats.get("mains", 0)), int(stats.get("sides", 0)),
		int(stats.get("alleys", 0)), int(stats.get("dead_ends", 0)),
		int(stats.get("plots_large", 0)), int(stats.get("plots_medium", 0)),
		int(stats.get("plots_small", 0)), int(stats.get("lots", 0)), int(stats.get("buildings", 0)),
		int(stats.get("failed_lots", 0)), int(stats.get("back_lanes", 0)),
		int(stats.get("street_objects", 0)), int(stats.get("nature_objects", 0)),
		int(round(float(stats.get("nature_pct", 0.0)))), int(city.get("tries", 0)),
		int(stats.get("alley_ring_cells", 0)), int(stats.get("alley_connector_cells", 0)),
		int(stats.get("alley_connectors", 0)), int(stats.get("alley_isolated", 0)),
		int(stats.get("alley_connect_d", 0))])
	out.append("City spawn: A side=%d outdoor=%d zone=%d buildings=%d posts=%d; B side=%d outdoor=%d zone=%d buildings=%d posts=%d" % [
		int(spawn.get("side_a", 0)), int(spawn.get("outdoor_a", 0)), field.spawn_zone_a.size(),
		(spawn.get("buildings_a", []) as Array).size(), CitySpawns.window_posts(field, 0).size(),
		int(spawn.get("side_b", 0)), int(spawn.get("outdoor_b", 0)), field.spawn_zone_b.size(),
		(spawn.get("buildings_b", []) as Array).size(), CitySpawns.window_posts(field, 1).size()])
	return out


#Entrance tunnels carved to the border; falls back to the border cell count.
static func _cavern_entrance_count(field: BattlefieldArea) -> int:
	var n := 0
	for t: Dictionary in field.cavern_tunnels:
		if str(t.get("kind", "")) == "entrance":
			n += 1
	return n if n > 0 else field.entrance_cells.size()


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LOG_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))


static func _strip_bbcode(text: String) -> String:
	if _bbcode_rx == null:
		_bbcode_rx = RegEx.new()
		_bbcode_rx.compile("\\[/?(color|b|i|u|s|url|img|font|font_size|bgcolor|fgcolor|outline_color|outline_size|center|right|left|fill|indent|code|p|lb|rb|wave|tornado|shake|fade|rainbow|pulse|hint|table|cell|ul|ol|char)(=[^\\]]*)?\\]")
	return _bbcode_rx.sub(text, "", true)

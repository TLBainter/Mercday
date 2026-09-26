class_name BuildingDataValidator
extends RefCounted

#Checks the Buildings.tsv rule cells, the room names they name and the Rooms.tsv rows behind them
#against BuildingRules and RoofBuilder; returns warning texts and changes nothing.

const _ROOM_PREFIXES: Array[String] = ["Interior", "Exterior", "Dungeon"]
const _ROOM_SUFFIXES: Array[String] = ["Any", "F0", "F+", "F-", "Top"]


#Buildings.tsv rule cells and room names, plus the Rooms.tsv rows those names resolve to.
static func building_warnings() -> Array[String]:
	var out: Array[String] = []
	for area: Dictionary in DataManager.areas_pool:
		if area.has("building"):
			out.append_array(_building_row_warnings(area))
	out.append_array(_room_warnings())
	out.append_array(_roof_object_row_warnings())
	return out


#The Obstacles.tsv rows the roof pass places by name; a missing row leaves a roof bare.
static func _roof_object_row_warnings() -> Array[String]:
	var out: Array[String] = []
	for name_val: String in RoofBuilder.ROOF_ROWS:
		if DataManager.get_obstacle_by_name(name_val) == null:
			out.append(ContractDataValidator.area_warning("Obstacles.tsv: roof object row %s is missing" % name_val))
	return out


static func _building_row_warnings(area: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var b: Dictionary = area["building"]
	var sheet_row: int = int(area.get("row", 0))
	var legacy: bool = bool(b.get("legacy", false))
	var size_class: String = String(b.get("size_class", ""))
	if size_class != "Small" and size_class != "Medium" and size_class != "Large":
		out.append(building_warning(sheet_row, "Size Class", "unknown size class %s" % size_class))
	var width: Vector2i = b.get("width", Vector2i.ZERO)
	var depth: Vector2i = b.get("depth", Vector2i.ZERO)
	if width == Vector2i.ZERO:
		out.append(building_warning(sheet_row, "Width", "expected a number or a range such as 5 to 8"))
	if depth == Vector2i.ZERO:
		out.append(building_warning(sheet_row, "Depth", "expected a number or a range such as 5 to 8"))
	var layout_f0: String = String(b.get("layout_f0", ""))
	var layout_other: String = String(b.get("layout_other", ""))
	if not legacy and not BuildingRules.LAYOUTS.has(layout_f0):
		out.append(building_warning(sheet_row, "Layout F0", "unknown layout %s" % layout_f0))
	if layout_other != "" and not BuildingRules.LAYOUTS.has(layout_other):
		out.append(building_warning(sheet_row, "Layout Other", "unknown layout %s" % layout_other))
	var shell: String = String(b.get("shell", ""))
	if not BuildingRules.SHELLS.has(shell):
		out.append(building_warning(sheet_row, "Shell", "unknown shell %s" % shell))
	if not BuildingRules.WINDOW_LEVELS.has(String(b.get("windows", ""))):
		out.append(building_warning(sheet_row, "Windows",
			"unknown window level %s" % String(b.get("windows", ""))))
	var roof: String = String(b.get("roof", ""))
	if not RoofBuilder.SHAPES.has(roof):
		out.append(building_warning(sheet_row, "Roof",
			"unknown roof %s, expected one of %s" % [roof, ", ".join(RoofBuilder.SHAPES)]))
	elif roof == "Gable" or roof == "Steeple":
		var wings: Vector2i = b.get("wings", Vector2i.ZERO)
		if wings.y > 0:
			out.append(building_warning(sheet_row, "Roof", "%s needs a rectangular outline" % roof))
	for entry: Variant in (b.get("roof_objects", []) as Array):
		var rec: Dictionary = entry as Dictionary
		var obj_name: String = String(rec.get("name", ""))
		if not RoofBuilder.OBJECTS.has(obj_name):
			out.append(building_warning(sheet_row, "Roof Objects",
				"unknown roof object %s, expected one of %s" % [obj_name, ", ".join(RoofBuilder.OBJECTS)]))
		elif int(rec.get("count", 0)) < 1:
			out.append(building_warning(sheet_row, "Roof Objects", "%s needs a count of 1 or more" % obj_name))
	var main_room: String = String(b.get("main_room", ""))
	var required_rooms: Array = b.get("required_rooms", [])
	var other_rooms: Array = b.get("other_rooms", [])
	if main_room == "":
		if not legacy:
			out.append(building_warning(sheet_row, "Main Room", "no main room"))
	elif not _is_room(main_room):
		out.append(building_warning(sheet_row, "Main Room", "unknown room %s" % main_room))
	out.append_array(_room_name_warnings(sheet_row, "Required Rooms", required_rooms))
	out.append_array(_room_name_warnings(sheet_row, "Rooms", other_rooms))
	out.append_array(_window_override_warnings(sheet_row, b, main_room, required_rooms, other_rooms))
	out.append_array(_required_floor_warnings(sheet_row, b, required_rooms))
	return out


static func _room_name_warnings(sheet_row: int, column: String, names: Array) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in names:
		if not _is_room(String(entry)):
			out.append(building_warning(sheet_row, column, "unknown room %s" % String(entry)))
	return out


#A window override must name a known level and a room this row actually builds.
static func _window_override_warnings(sheet_row: int, b: Dictionary, main_room: String,
		required_rooms: Array, other_rooms: Array) -> Array[String]:
	var out: Array[String] = []
	var row_rooms: Dictionary = {}
	if main_room != "":
		row_rooms[main_room] = true
	for entry: Variant in required_rooms:
		row_rooms[String(entry)] = true
	for entry: Variant in other_rooms:
		row_rooms[String(entry)] = true
	var window_rooms: Dictionary = b.get("window_rooms", {})
	for key: Variant in window_rooms:
		var room_name: String = String(key)
		var level: String = String(window_rooms[key])
		if not BuildingRules.WINDOW_LEVELS.has(level):
			out.append(building_warning(sheet_row, "Windows",
				"unknown window level %s for %s" % [level, room_name]))
		if not row_rooms.has(room_name):
			out.append(building_warning(sheet_row, "Windows",
				"%s is named by no room cell of this row" % room_name))
	return out


#A required room that only fits a floor the row never builds can never be placed.
static func _required_floor_warnings(sheet_row: int, b: Dictionary,
		required_rooms: Array) -> Array[String]:
	var out: Array[String] = []
	var f_plus: Vector2i = b.get("f_plus", Vector2i.ZERO)
	var f_minus: Vector2i = b.get("f_minus", Vector2i.ZERO)
	for entry: Variant in required_rooms:
		var room_name: String = String(entry)
		var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
		if d == null or not d.is_room:
			continue
		if d.room_type.ends_with("F-") and f_minus.y == 0:
			out.append(building_warning(sheet_row, "Required Rooms",
				"%s fits only a basement and this row has none" % room_name))
		elif (d.room_type.ends_with("F+") or d.room_type.ends_with("Top")) and f_plus.y == 0:
			out.append(building_warning(sheet_row, "Required Rooms",
				"%s fits only an upper floor and this row has none" % room_name))
	return out


#Every room row: its furniture names must resolve and its Room Type must be a known pair.
static func _room_warnings() -> Array[String]:
	var out: Array[String] = []
	for obs: ObstacleData in DataManager.obstacles_pool:
		if not obs.is_room:
			continue
		var sheet_row: int = int(DataManager.room_sheet_rows.get(obs.obstacle_name, 0))
		out.append_array(_furniture_warnings(sheet_row, "Guaranteed Structures", obs.guaranteed_structures))
		out.append_array(_furniture_warnings(sheet_row, "Possible Structures", obs.possible_structures))
		out.append_array(_furniture_warnings(sheet_row, "Possible Scatter", obs.possible_scatter))
		if not _room_type_ok(obs.room_type):
			out.append(ContractDataValidator.warning("Rooms.tsv", sheet_row, "Room Type",
				"expected Interior, Exterior or Dungeon plus Any, F0, F+, F- or Top, got %s" % obs.room_type))
	return out


static func _furniture_warnings(sheet_row: int, column: String, names: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for entry: String in names:
		if seen.has(entry):
			continue
		seen[entry] = true
		if DataManager.get_obstacle_by_name(entry) == null:
			out.append(ContractDataValidator.warning("Rooms.tsv", sheet_row, column, "unknown obstacle %s" % entry))
	return out


static func _room_type_ok(room_type: String) -> bool:
	var parts: PackedStringArray = room_type.split(" ", false)
	if parts.size() != 2:
		return false
	return _ROOM_PREFIXES.has(parts[0]) and _ROOM_SUFFIXES.has(parts[1])


static func _is_room(room_name: String) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
	return d != null and d.is_room


static func building_warning(sheet_row: int, column: String, detail: String) -> String:
	return ContractDataValidator.warning("Buildings.tsv", sheet_row, column, detail)

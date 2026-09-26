class_name ContractDataValidator
extends RefCounted

#Checks built ContractData and EventData against the stat, circumstance, knowledge, tool,
#tradition, location and penalty tables; returns warning texts and changes nothing.


static func validate_contract(data: ContractData, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var sheet_row: int = int(row.get("_row", 0))
	var stat_names: Dictionary = _stat_var_names()
	var stat_ok: Callable = _stat_ok.bind(stat_names)
	out.append_array(_boost_warnings(data.stat_boosts, stat_ok, sheet_row, "Stat", "stat"))
	out.append_array(_boost_warnings(data.circumstance_boosts, _circ_ok, sheet_row,
		"Circumstances", "circumstance"))
	out.append_array(_boost_warnings(data.knowledge_boosts, _know_ok, sheet_row, "Knowledge", "knowledge"))
	out.append_array(_boost_warnings(data.tool_boosts, _tool_prefix_exists, sheet_row, "Tool", "tool"))
	out.append_array(_boost_warnings(data.tradition_boosts, _tradition_exists, sheet_row,
		"Tradition", "tradition"))
	for entry: Dictionary in data.penalties:
		var column: String = "%d%% Penalty" % int(entry.get("percent", 0.0))
		var parsed: Dictionary = ContractPenalty.parse(String(entry.get("expr", "")))
		if not bool(parsed["ok"]):
			out.append(contract_warning(sheet_row, column, "bad penalty: %s" % String(parsed["error"])))
		elif String(parsed["kind"]) == "stat" and not stat_names.has(String(parsed["operand"])):
			out.append(contract_warning(sheet_row, column, "unknown stat %s" % String(parsed["operand"])))
		elif String(parsed["kind"]) == "tradition" and not _tradition_exists(String(parsed["value"])):
			out.append(contract_warning(sheet_row, column, "unknown tradition %s" % String(parsed["value"])))
	out.append_array(_name_warnings(data.possible_locations, _loc_ok, "Contracts.tsv", sheet_row,
		"Possible Locations", "location"))
	var steps: float = data.difficulty * 2.0
	if data.difficulty > 0.0 and (steps != floor(steps) or steps < 1.0 or steps > 10.0):
		out.append(contract_warning(sheet_row, "Difficulty",
			"expected 0.5 to 5 in steps of 0.5, got %s" % str(data.difficulty)))
	out.append_array(_terrain_odds_warnings(data.terrain_odds, sheet_row))
	return out


static func _terrain_odds_warnings(odds: Array[Dictionary], sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in odds:
		var name: String = String(entry.get("area", ""))
		var percent: int = int(entry.get("percent", -1))
		var area: Dictionary = DataManager.get_area_by_name(name)
		if area.is_empty():
			out.append(contract_warning(sheet_row, "Terrain Odds", "unknown area %s" % name))
			continue
		if not ContractTerrain.drawable(area):
			out.append(contract_warning(sheet_row, "Terrain Odds",
				"area %s is not Exterior, %s or %s" % [name, ContractTerrain.CAVERN, ContractTerrain.DUNGEON]))
			continue
		if percent < 1 or percent > 100:
			out.append(contract_warning(sheet_row, "Terrain Odds",
				"expected 1 to 100 for %s, got %d" % [name, percent]))
	return out


#Areas.tsv Environments keys and the Country rows no Area row covers (Settlements share their Country's
#Environment; Domains host no contract for now).
static func validate_areas() -> Array[String]:
	var out: Array[String] = []
	var known: Dictionary = {}
	for key: String in DataManager.locations:
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc != null:
			known[loc.environment.strip_edges().to_lower()] = true
	for area: Dictionary in DataManager.areas_pool:
		if not ContractTerrain.drawable(area):
			continue
		for env: String in (area.get("environments", {}) as Dictionary):
			if not known.has(env):
				out.append(area_warning("Areas.tsv row %d Environments: unknown environment %s"
					% [int(area.get("row", 0)), env]))
	for key: String in DataManager.locations:
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc == null or loc.location_type != "Country":
			continue
		var env_name: String = ContractTerrain.terrain_environment(loc)
		if env_name != "" and not ContractTerrain.has_terrain(loc):
			out.append(area_warning("Locations.tsv: %s Environment %s is named by no Areas.tsv row"
				% [loc.location_name, env_name]))
	out.append_array(BuildingDataValidator.building_warnings())
	return out


static func validate_event(data: EventData, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var sheet_row: int = int(row.get("_row", 0))
	var stat_ok: Callable = _stat_ok.bind(_stat_var_names())
	if data.event_type != "Primary" and data.event_type != "Mishap" and data.event_type != "Secondary":
		out.append(event_warning(sheet_row, "Event Type",
			"expected Primary, Mishap or Secondary, got %s" % data.event_type))
	out.append_array(_name_warnings(data.possible_contracts, _contract_type_exists, "Events.tsv",
		sheet_row, "Possible Contracts", "contract type"))
	out.append_array(_name_warnings(data.check_stats, stat_ok, "Events.tsv", sheet_row,
		"Check Stats", "stat"))
	out.append_array(_name_warnings(data.circumstances, _circ_ok, "Events.tsv", sheet_row,
		"Circumstances", "circumstance"))
	out.append_array(_name_warnings(data.knowledges, _know_ok, "Events.tsv", sheet_row,
		"Knowledges", "knowledge"))
	out.append_array(_name_warnings(data.tools, _tool_prefix_exists, "Events.tsv", sheet_row, "Tools", "tool"))
	out.append_array(_name_warnings(data.possible_locations, _loc_ok, "Events.tsv", sheet_row,
		"Possible Locations", "location"))
	if data.is_battle():
		if data.enemy == "":
			out.append(event_warning(sheet_row, "Enemy", "Battle event has no enemy"))
		if data.enemy_counter == "":
			out.append(event_warning(sheet_row, "Enemy Counter", "Battle event has no enemy counter"))
		if data.map_rule == "":
			out.append(event_warning(sheet_row, "Map", "Battle event has no map rule"))
		elif data.map_rule != "Location" and data.map_rule != "Cavern" and data.map_rule != "Dungeon":
			var interior: bool = data.map_rule.begins_with(ContractTerrain.INTERIOR_PREFIX)
			var area_name: String = data.map_rule.substr(ContractTerrain.INTERIOR_PREFIX.length()) if interior else ""
			if not interior:
				out.append(event_warning(sheet_row, "Map", "expected Location, Cavern, Dungeon or Interior:<area>, got %s" % data.map_rule))
			elif DataManager.get_area_by_name(area_name).is_empty():
				out.append(event_warning(sheet_row, "Map", "unknown area %s" % area_name))
	return out


#One warning per name the lookup rejects, all under the same sheet column.
static func _name_warnings(names: Array, exists_fn: Callable, sheet: String, sheet_row: int,
		column: String, label: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in names:
		if not exists_fn.call(name):
			out.append(warning(sheet, sheet_row, column, "unknown %s %s" % [label, name]))
	return out


#One warning per rejected boost key; the Contracts.tsv column carries the boost percent.
static func _boost_warnings(boosts: Dictionary, exists_fn: Callable, sheet_row: int,
		column_kind: String, label: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in boosts:
		if not exists_fn.call(name):
			out.append(contract_warning(sheet_row, "%d%% %s" % [int(boosts[name]), column_kind],
				"unknown %s %s" % [label, name]))
	return out


static func warning(sheet: String, sheet_row: int, column: String, detail: String) -> String:
	return "ContractResourceBuilder: %s row %d column %s: %s" % [sheet, sheet_row, column, detail]


static func contract_warning(sheet_row: int, column: String, detail: String) -> String:
	return warning("Contracts.tsv", sheet_row, column, detail)


static func event_warning(sheet_row: int, column: String, detail: String) -> String:
	return warning("Events.tsv", sheet_row, column, detail)


static func area_warning(detail: String) -> String:
	return "ContractResourceBuilder: %s" % detail


#The name lookups both sheet validators share; stat_names is bound once per row.
static func _stat_ok(n: String, stat_names: Dictionary) -> bool:
	return stat_names.has(ContractModifiers.stat_key(n))


static func _circ_ok(n: String) -> bool:
	return ConstCircumstances.DATA.has(n)


static func _know_ok(n: String) -> bool:
	return DataManager.knowledges.has(n)


static func _loc_ok(n: String) -> bool:
	return DataManager.locations.has(n)


static func _stat_var_names() -> Dictionary:
	var out: Dictionary = {}
	for stat_def: Dictionary in DataManager.stat_definitions:
		out[String(stat_def["var_name"])] = true
	return out


static func _tool_prefix_exists(name: String) -> bool:
	if name == "":
		return false
	for key: String in DataManager.tools:
		if key.begins_with(name):
			return true
	return false


static func _tradition_exists(name: String) -> bool:
	var lower: String = name.to_lower()
	for key: String in DataManager.traditions:
		if key.to_lower() == lower:
			return true
	return false


static func _contract_type_exists(name: String) -> bool:
	for row: Dictionary in DataManager.contract_rows:
		if String(row.get("Contract Type", "")) == name:
			return true
	return false

class_name ContractDataValidator
extends RefCounted

#Checks built ContractData and EventData against the stat, circumstance, knowledge, tool,
#tradition, location and penalty tables; returns warning texts and changes nothing.


static func validate_contract(data: ContractData, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var sheet_row: int = int(row.get("_row", 0))
	var stat_names: Dictionary = _stat_var_names()
	var stat_ok := func(n: String) -> bool: return stat_names.has(ContractModifiers.stat_key(n))
	var circ_ok := func(n: String) -> bool: return ConstCircumstances.DATA.has(n)
	var know_ok := func(n: String) -> bool: return DataManager.knowledges.has(n)
	var tool_ok := func(n: String) -> bool: return _tool_prefix_exists(n)
	var trad_ok := func(n: String) -> bool: return _tradition_exists(n)
	var loc_ok := func(n: String) -> bool: return DataManager.locations.has(n)
	out.append_array(_boost_warnings(data.stat_boosts, stat_ok, sheet_row, "Stat", "stat"))
	out.append_array(_boost_warnings(data.circumstance_boosts, circ_ok, sheet_row,
		"Circumstances", "circumstance"))
	out.append_array(_boost_warnings(data.knowledge_boosts, know_ok, sheet_row, "Knowledge", "knowledge"))
	out.append_array(_boost_warnings(data.tool_boosts, tool_ok, sheet_row, "Tool", "tool"))
	out.append_array(_boost_warnings(data.tradition_boosts, trad_ok, sheet_row, "Tradition", "tradition"))
	for entry: Dictionary in data.penalties:
		var column: String = "%d%% Penalty" % int(entry.get("percent", 0.0))
		var parsed: Dictionary = ContractPenalty.parse(String(entry.get("expr", "")))
		if not bool(parsed["ok"]):
			out.append(contract_warning(sheet_row, column, "bad penalty: %s" % String(parsed["error"])))
		elif String(parsed["kind"]) == "stat" and not stat_names.has(String(parsed["operand"])):
			out.append(contract_warning(sheet_row, column, "unknown stat %s" % String(parsed["operand"])))
		elif String(parsed["kind"]) == "tradition" and not _tradition_exists(String(parsed["value"])):
			out.append(contract_warning(sheet_row, column, "unknown tradition %s" % String(parsed["value"])))
	out.append_array(_name_warnings(data.possible_locations, loc_ok, "Contracts.tsv", sheet_row,
		"Possible Locations", "location"))
	var steps: float = data.difficulty * 2.0
	if data.difficulty > 0.0 and (steps != floor(steps) or steps < 2.0 or steps > 10.0):
		out.append(contract_warning(sheet_row, "Difficulty",
			"expected 1 to 5 in steps of 0.5, got %s" % str(data.difficulty)))
	return out


static func validate_event(data: EventData, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var sheet_row: int = int(row.get("_row", 0))
	var stat_names: Dictionary = _stat_var_names()
	var type_ok := func(n: String) -> bool: return _contract_type_exists(n)
	var stat_ok := func(n: String) -> bool: return stat_names.has(ContractModifiers.stat_key(n))
	var circ_ok := func(n: String) -> bool: return ConstCircumstances.DATA.has(n)
	var know_ok := func(n: String) -> bool: return DataManager.knowledges.has(n)
	var tool_ok := func(n: String) -> bool: return _tool_prefix_exists(n)
	var loc_ok := func(n: String) -> bool: return DataManager.locations.has(n)
	if data.event_type != "Primary" and data.event_type != "Mishap":
		out.append(event_warning(sheet_row, "Event Type", "expected Primary or Mishap, got %s" % data.event_type))
	out.append_array(_name_warnings(data.possible_contracts, type_ok, "Events.tsv", sheet_row,
		"Possible Contracts", "contract type"))
	out.append_array(_name_warnings(data.check_stats, stat_ok, "Events.tsv", sheet_row,
		"Check Stats", "stat"))
	out.append_array(_name_warnings(data.circumstances, circ_ok, "Events.tsv", sheet_row,
		"Circumstances", "circumstance"))
	out.append_array(_name_warnings(data.knowledges, know_ok, "Events.tsv", sheet_row,
		"Knowledges", "knowledge"))
	out.append_array(_name_warnings(data.tools, tool_ok, "Events.tsv", sheet_row, "Tools", "tool"))
	out.append_array(_name_warnings(data.possible_locations, loc_ok, "Events.tsv", sheet_row,
		"Possible Locations", "location"))
	if data.is_battle():
		if data.enemy == "":
			out.append(event_warning(sheet_row, "Enemy", "Battle event has no enemy"))
		if data.enemy_counter == "":
			out.append(event_warning(sheet_row, "Enemy Counter", "Battle event has no enemy counter"))
		if data.map_rule == "":
			out.append(event_warning(sheet_row, "Map", "Battle event has no map rule"))
		elif data.map_rule != "Location":
			if not data.map_rule.begins_with("Interior:"):
				out.append(event_warning(sheet_row, "Map", "expected Location or Interior:<area>, got %s" % data.map_rule))
			elif DataManager.get_area_by_name(data.map_rule.substr(9)).is_empty():
				out.append(event_warning(sheet_row, "Map", "unknown area %s" % data.map_rule.substr(9)))
	return out


#One warning per name the lookup rejects, all under the same sheet column.


#One warning per name the lookup rejects, all under the same sheet column.
static func _name_warnings(names: Array, exists_fn: Callable, sheet: String, sheet_row: int,
		column: String, label: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in names:
		if not exists_fn.call(name):
			out.append(warning(sheet, sheet_row, column, "unknown %s %s" % [label, name]))
	return out


#One warning per rejected boost key; the Contracts.tsv column carries the boost percent.


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

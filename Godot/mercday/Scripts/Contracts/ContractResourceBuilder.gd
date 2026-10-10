class_name ContractResourceBuilder

#Turns the Contracts.tsv and Events.tsv rows into ContractData and EventData resource files and deletes stale ones.

const CONTRACT_DIR := "res://Resources/Contracts"
const EVENT_DIR := "res://Resources/Events"

const BOOST_PATTERN := "^([0-9]+)% (Stat|Circumstances|Tool|Knowledge|Tradition|Penalty)$"

const CONTRACT_SCRIPT := "res://Scripts/Resources/ContractData.gd"
const EVENT_SCRIPT := "res://Scripts/Resources/EventData.gd"

#Warning texts from the most recent build_all, in emission order.
static var last_warnings: Array[String] = []

#False under the harness: build_all then fills the memory dictionaries and never touches the tracked .tres files.
static var write_enabled: bool = true
static var contract_dir: String = CONTRACT_DIR
static var event_dir: String = EVENT_DIR
#Row name -> ContractData and event name -> EventData from the last build_all with writes off; empty otherwise.
static var memory_contracts: Dictionary = {}
static var memory_events: Dictionary = {}


static func build_all() -> Dictionary:
	last_warnings = []
	memory_contracts = {}
	memory_events = {}
	if write_enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(contract_dir))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(event_dir))
	for text: String in BuildingDataValidator.area_warnings():
		_warn(text)
	var written: Dictionary = {}
	var events: Array[EventData] = []
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Event Name", "")) == "":
			continue
		var data: EventData = build_event(row)
		events.append(data)
		for text: String in ContractDataValidator.validate_event(data, row):
			_warn(text)
		if not write_enabled:
			memory_events[data.event_name] = data
			continue
		#ResourceSaver picks a random ext_resource id per run, so ResourceTextWriter writes the .tres text instead.
		var event_file: String = event_path(data.event_name)
		ResourceTextWriter.save(data, event_file, "EventData", EVENT_SCRIPT)
		written[event_file.to_lower()] = true
	var contract_count: int = 0
	var seen: Dictionary = {}
	for row: Dictionary in DataManager.contract_rows:
		var contract_name: String = row_name(row)
		if contract_name == "":
			continue
		var sheet_row: int = int(row.get("_row", 0))
		if String(row.get("Contract Name", "")).strip_edges() == "":
			_warn(ContractDataValidator.contract_warning(sheet_row, "Contract Name", "blank name, using type"))
		#Names that share a file stem would overwrite one file, so they count as duplicates too.
		var key: String = file_stem(contract_name).to_lower()
		if seen.has(key):
			_warn(ContractDataValidator.contract_warning(sheet_row, "Contract Name",
				"duplicate Contract Name %s, row skipped" % contract_name))
			continue
		seen[key] = true
		var contract: ContractData = build_contract(row, events)
		for text: String in ContractDataValidator.validate_contract(contract, row):
			_warn(text)
		contract_count += 1
		if not write_enabled:
			memory_contracts[contract_name] = contract
			continue
		var contract_file: String = contract_path(contract_name)
		ResourceTextWriter.save(contract, contract_file, "ContractData", CONTRACT_SCRIPT)
		written[contract_file.to_lower()] = true
	var pruned: int = _prune(written) if write_enabled else 0
	return {"contracts": contract_count, "events": events.size(), "warnings": last_warnings.size(), "pruned": pruned}


#Deletes every .tres in the two generated directories that this run did not write; returns the count.
static func _prune(written: Dictionary) -> int:
	var count: int = 0
	for dir_path: String in [contract_dir, event_dir]:
		for file_name: String in DirAccess.get_files_at(dir_path):
			var res_path: String = dir_path + "/" + file_name
			if file_name.get_extension() != "tres" or written.has(res_path.to_lower()):
				continue
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(res_path)) == OK:
				count += 1
			else:
				_warn("ContractResourceBuilder: could not delete stale %s" % res_path)
	return count


#The row key: Contract Name, or Contract Type when the name is blank.
static func row_name(row: Dictionary) -> String:
	var contract_name: String = String(row.get("Contract Name", "")).strip_edges()
	return contract_name if contract_name != "" else String(row.get("Contract Type", "")).strip_edges()


static func build_contract(row: Dictionary, events: Array[EventData]) -> ContractData:
	var data := ContractData.new()
	data.contract_type = String(row.get("Contract Type", ""))
	data.contract_name = row_name(row)
	var primary: Array[String] = []
	var mishap: Array[String] = []
	for e: EventData in events:
		if not e.possible_contracts.has(data.contract_type):
			continue
		#A triggered event reaches a run only through its trigger, never a pool roll.
		if e.trigger.strip_edges() != "":
			continue
		if e.event_type == "Primary":
			primary.append(e.event_name)
		elif e.event_type == "Mishap":
			mishap.append(e.event_name)
	data.primary_event_pool = primary
	data.mishap_pool = mishap
	var stat_boosts: Dictionary = {}
	var circ_boosts: Dictionary = {}
	var tool_boosts: Dictionary = {}
	var knowledge_boosts: Dictionary = {}
	var tradition_boosts: Dictionary = {}
	var penalties: Array[Dictionary] = []
	for column: Dictionary in _boost_columns(row):
		var header: String = String(column["header"])
		var kind: String = String(column["kind"])
		var percent: float = float(column["percent"])
		var cell: String = String(row.get(header, "")).strip_edges()
		if cell == "":
			continue
		if kind == "Penalty":
			penalties.append({"expr": cell, "percent": percent})
			continue
		var target: Dictionary = stat_boosts
		match kind:
			"Circumstances":
				target = circ_boosts
			"Tool":
				target = tool_boosts
			"Knowledge":
				target = knowledge_boosts
			"Tradition":
				target = tradition_boosts
		for name: String in TsvReader.split_field(cell):
			if target.has(name):
				_warn("ContractResourceBuilder: Contracts.tsv row %d column %s: duplicate entry %s"
					% [int(row.get("_row", 0)), header, name])
				continue
			target[name] = percent
	data.stat_boosts = stat_boosts
	data.circumstance_boosts = circ_boosts
	data.tool_boosts = tool_boosts
	data.knowledge_boosts = knowledge_boosts
	data.tradition_boosts = tradition_boosts
	data.penalties = penalties
	data.description_template = String(row.get("Description Template", ""))
	data.target_categories = TsvReader.split_field(String(row.get("Target Category", "")))
	data.possible_traits = TsvReader.split_field(String(row.get("Possible Traits", "")))
	data.possible_locations = TsvReader.split_field(String(row.get("Possible Locations", "")))
	data.terrain_odds = ContractTerrain.parse_odds(String(row.get("Terrain Odds", "")))
	data.reward_notes = 0
	data.max_mercs = _int_cell(row, "Max Mercs")
	data.min_mercs = _int_cell(row, "Min Mercs")
	data.local = _bool_cell(row, "Local")
	#A blank or missing Difficulty cell is silent; ContractGenerator rolls one when it is 0.
	data.difficulty = _float_cell(row, "Difficulty")
	data.unsavory = _unsavory_cell(row)
	data.level_min = _int_cell(row, "Level Min")
	data.level_max = _int_cell(row, "Level Max")
	data.issuer_type = String(row.get("Issuer Type", "")).strip_edges()
	data.issuer = String(row.get("Issuer", "")).strip_edges()
	data.difficulty_min = _float_cell(row, "Difficulty Min")
	data.difficulty_max = _float_cell(row, "Difficulty Max")
	data.story = String(row.get("Story", "")).strip_edges().to_upper() == "TRUE"
	data.style = String(row.get("Style", "")).strip_edges()
	data.roles = TsvReader.split_field(String(row.get("Roles", "")))
	data.target = String(row.get("Target", "")).strip_edges()
	data.completion = String(row.get("Completion", "")).strip_edges()
	data.event_config = String(row.get("Event Config", "")).strip_edges()
	data.time_minutes = _int_cell(row, "Time")
	data.consequence = String(row.get("Consequence", "")).strip_edges()
	data.descriptions = descriptions_for(data.contract_name)
	data.contract_level = 0
	data.assigned_primary_event = ""
	data.rolled_mishaps = []
	data.location_a = ""
	data.location_b = ""
	data.description = ""
	data.team_uids = []
	data.status = "Type"
	return data


#The Descriptions.tsv texts of one contract name, in file order; a blank Description is skipped.
static func descriptions_for(contract_name: String) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in DataManager.description_rows:
		var text: String = String(row.get("Description", ""))
		if text != "" and String(row.get("Contract Name", "")) == contract_name:
			out.append(text)
	return out


#A blank or missing cell reads 0; an unreadable one reads 0 with a warning.
static func _int_cell(row: Dictionary, column: String) -> int:
	var cell: String = String(row.get(column, "")).strip_edges()
	if cell == "":
		return 0
	if cell.is_valid_int():
		return int(cell)
	_warn(ContractDataValidator.contract_warning(int(row.get("_row", 0)), column,
		"unreadable %s %s" % [column.to_lower(), cell]))
	return 0


#TRUE in any case reads true; anything else reads false (ContractDataValidator warns on a cell that is not TRUE or FALSE).
static func _bool_cell(row: Dictionary, column: String) -> bool:
	return String(row.get(column, "")).strip_edges().to_upper() == "TRUE"


static func _float_cell(row: Dictionary, column: String) -> float:
	var cell: String = String(row.get(column, "")).strip_edges()
	if cell == "":
		return 0.0
	if cell.is_valid_float():
		return float(cell)
	_warn(ContractDataValidator.contract_warning(int(row.get("_row", 0)), column,
		"unreadable %s %s" % [column.to_lower(), cell]))
	return 0.0


static func build_event(row: Dictionary) -> EventData:
	var data := EventData.new()
	data.event_name = String(row.get("Event Name", ""))
	data.event_type = String(row.get("Event Type", ""))
	data.trigger = String(row.get("Trigger", ""))
	var stats_cell: String = String(row.get("Check Stats", ""))
	if stats_cell == "":
		stats_cell = String(row.get("Checks", ""))
	data.check_stats = TsvReader.split_field(stats_cell)
	data.circumstances = TsvReader.split_field(String(row.get("Circumstances", "")))
	data.knowledges = TsvReader.split_field(String(row.get("Knowledges", "")))
	data.tools = TsvReader.split_field(String(row.get("Tools", "")))
	data.success_formula = String(row.get("Success Formula", ""))
	data.possible_contracts = TsvReader.split_field(String(row.get("Possible Contracts", "")))
	data.possible_locations = TsvReader.split_field(String(row.get("Possible Locations", "")))
	data.enemy = String(row.get("Enemy", ""))
	data.enemy_counter = String(row.get("Enemy Counter", ""))
	data.map_rule = String(row.get("Map", ""))
	data.fail_ends_contract = _flag_cell(row, "Fail Ends Contract")
	return data


#TRUE, YES, 1 or X in any case reads true; a blank cell or a missing column reads false.
static func _flag_cell(row: Dictionary, column: String) -> bool:
	if not row.has(column):
		return false
	return String(row[column]).strip_edges().to_lower() in ["true", "yes", "1", "x"]


static func file_stem(name: String) -> String:
	return name.replace(" ", "_").replace("'", "")


static func contract_path(name: String) -> String:
	return contract_dir + "/" + file_stem(name) + ".tres"


static func event_path(name: String) -> String:
	return event_dir + "/" + file_stem(name) + ".tres"


static func _boost_columns(row: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var re := RegEx.new()
	re.compile(BOOST_PATTERN)
	for header: String in row.keys():
		var m: RegExMatch = re.search(header)
		if m == null:
			continue
		out.append({"header": header, "percent": float(m.get_string(1)), "kind": m.get_string(2)})
	out.sort_custom(_higher_percent)
	return out


static func _higher_percent(a: Dictionary, b: Dictionary) -> bool:
	return float(a["percent"]) > float(b["percent"])


#A blank or missing Unsavory cell reads false, so the column can arrive after the code.
static func _unsavory_cell(row: Dictionary) -> bool:
	var cell: String = String(row.get("Unsavory", "")).strip_edges()
	match cell.to_lower():
		"true", "yes", "1":
			return true
		"", "false", "no", "0":
			return false
	_warn(ContractDataValidator.contract_warning(int(row.get("_row", 0)), "Unsavory",
		"unreadable unsavory %s" % cell))
	return false


static func _warn(text: String) -> void:
	last_warnings.append(text)
	push_warning(text)

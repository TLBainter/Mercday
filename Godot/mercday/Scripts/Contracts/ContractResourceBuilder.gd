class_name ContractResourceBuilder

#Turns the Contracts.tsv and Events.tsv rows into ContractData and EventData resource files.

const CONTRACT_DIR := "res://Resources/Contracts"
const EVENT_DIR := "res://Resources/Events"

const BOOST_PATTERN := "^([0-9]+)% (Stat|Circumstances|Tool|Knowledge|Tradition|Penalty)$"

const CONTRACT_SCRIPT := "res://Scripts/Resources/ContractData.gd"
const EVENT_SCRIPT := "res://Scripts/Resources/EventData.gd"

#Warning texts from the most recent build_all, in emission order.
static var last_warnings: Array[String] = []


static func build_all() -> Dictionary:
	last_warnings = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTRACT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVENT_DIR))
	for text: String in ContractDataValidator.validate_areas():
		_warn(text)
	var events: Array[EventData] = []
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Event Name", "")) == "":
			continue
		var data: EventData = build_event(row)
		events.append(data)
		for text: String in ContractDataValidator.validate_event(data, row):
			_warn(text)
		#ResourceSaver picks a random ext_resource id per run, so ResourceTextWriter writes the .tres text instead.
		ResourceTextWriter.save(data, event_path(data.event_name), "EventData", EVENT_SCRIPT)
	var contract_count: int = 0
	for row: Dictionary in DataManager.contract_rows:
		if String(row.get("Contract Type", "")) == "":
			continue
		var contract: ContractData = build_contract(row, events)
		for text: String in ContractDataValidator.validate_contract(contract, row):
			_warn(text)
		ResourceTextWriter.save(contract, contract_path(contract.contract_type), "ContractData", CONTRACT_SCRIPT)
		contract_count += 1
	return {"contracts": contract_count, "events": events.size(), "warnings": last_warnings.size()}


static func build_contract(row: Dictionary, events: Array[EventData]) -> ContractData:
	var data := ContractData.new()
	data.contract_type = String(row.get("Contract Type", ""))
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
	data.max_mercs = 0
	#A blank or missing Difficulty cell is silent; ContractGenerator rolls one when it is 0.
	var difficulty_cell: String = String(row.get("Difficulty", "")).strip_edges()
	if difficulty_cell == "":
		data.difficulty = 0.0
	elif difficulty_cell.is_valid_float():
		data.difficulty = float(difficulty_cell)
	else:
		data.difficulty = 0.0
		_warn(ContractDataValidator.contract_warning(int(row.get("_row", 0)), "Difficulty",
			"unreadable difficulty %s" % difficulty_cell))
	data.unsavory = _unsavory_cell(row)
	data.contract_level = 0
	data.assigned_primary_event = ""
	data.rolled_mishaps = []
	data.location_a = ""
	data.location_b = ""
	data.description = ""
	data.team_uids = []
	data.status = "Type"
	return data


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
	return data


static func file_stem(name: String) -> String:
	return name.replace(" ", "_").replace("'", "")


static func contract_path(name: String) -> String:
	return CONTRACT_DIR + "/" + file_stem(name) + ".tres"


static func event_path(name: String) -> String:
	return EVENT_DIR + "/" + file_stem(name) + ".tres"


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

@tool
class_name ContractBuilderData extends RefCounted

#Sheet reads for the builder through TsvReader static calls; DataManager is an autoload the editor lacks.
#The path vars start at the res:// sheets; tests point them at copies under user:// and call reset_paths().

const CONTRACTS_PATH: String = "res://TSVs/Contracts.tsv"
const CONTRACTS_OLD_PATH: String = "res://TSVs/Contracts_OLD.tsv"
const TYPES_PATH: String = "res://TSVs/Types.tsv"
const ORGANIZATIONS_PATH: String = "res://TSVs/Organizations.tsv"
const LOCATIONS_PATH: String = "res://TSVs/Locations.tsv"
const DESCRIPTIONS_PATH: String = "res://TSVs/Descriptions.tsv"
const AREAS_PATH: String = "res://TSVs/Areas.tsv"
const BUILDINGS_PATH: String = "res://TSVs/Buildings.tsv"
const NPCS_PATH: String = "res://TSVs/NPCs.tsv"
const TRADITIONS_PATH: String = "res://TSVs/Traditions.tsv"
const CHECKS_PATH: String = "res://TSVs/Checks.tsv"
const STATS_PATH: String = "res://TSVs/Stats.tsv"
const CIRCUMSTANCES_PATH: String = "res://TSVs/Circumstances.tsv"
const KNOWLEDGES_PATH: String = "res://TSVs/Knowledges and Tools.tsv"
const EVENTS_PATH: String = "res://TSVs/Events.tsv"
const TYPES_COLUMN: String = "CONTRACT"
const CREATURES_COLUMN: String = "CREATURES"
const LOCATIONS_NAME_COLUMN: int = 1
const LOCATIONS_TYPE_COLUMN: int = 23
const PLACE_TYPES: Array[String] = ["Country", "Settlement"]
const AREAS_NAME_COLUMN: int = 0
const AREAS_TYPE_COLUMN: int = 1
const BUILDINGS_NAME_COLUMN: int = 0
const INTERIOR_TYPE: String = "Interior"
const ORGANIZATIONS_NAME_COLUMN: String = "Name"
const ORGANIZATIONS_WIDTH: int = 3
const ISSUER_TYPES: Array[String] = ["person", "place", "org"]
const DESCRIPTIONS_KEY_COLUMN: int = 0
const DESCRIPTIONS_HEADER: Array[String] = ["Contract Name", "Description"]
const NPCS_TITLE_COLUMN: String = "Title"
const TRADITIONS_NAME_COLUMN: String = "Tradition Name"
const CHECKS_NAME_COLUMN: int = 0
const STATS_NAME_COLUMN: int = 0
const STATS_TYPE_COLUMN: int = 3
const STATS_CORE_TYPE: String = "core"
const CIRCUMSTANCES_STAT_COLUMN: int = 0
const CIRCUMSTANCES_NAME_COLUMN: int = 1
const CIRCUMSTANCES_RARITY_COLUMN: int = 4
const KNOWLEDGES_NAME_COLUMN: int = 0
const KNOWLEDGES_CATEGORY_COLUMN: int = 2
const KNOWLEDGES_RARITY_COLUMN: int = 3
const TOOLS_NAME_COLUMN: int = 4
const TOOLS_CATEGORY_COLUMN: int = 6
const TOOLS_RARITY_COLUMN: int = 7
const EVENTS_NAME_COLUMN: String = "Event Name"
const EVENTS_TYPE_COLUMN: String = "Event Type"
const EVENTS_PRIMARY_TYPE: String = "Primary"
#attribute_names() when Stats.tsv has no core row; the StatCalculator.CORE_STATS names, capitalized.
const CORE_STATS_FALLBACK: Array[String] = ["Cognition", "Dexterity", "Vigor", "Wile"]

static var contracts_path: String = CONTRACTS_PATH
static var contracts_old_path: String = CONTRACTS_OLD_PATH
static var types_path: String = TYPES_PATH
static var organizations_path: String = ORGANIZATIONS_PATH
static var locations_path: String = LOCATIONS_PATH
static var descriptions_path: String = DESCRIPTIONS_PATH
static var areas_path: String = AREAS_PATH
static var buildings_path: String = BUILDINGS_PATH
static var npcs_path: String = NPCS_PATH
static var traditions_path: String = TRADITIONS_PATH
static var checks_path: String = CHECKS_PATH
static var stats_path: String = STATS_PATH
static var circumstances_path: String = CIRCUMSTANCES_PATH
static var knowledges_path: String = KNOWLEDGES_PATH
static var events_path: String = EVENTS_PATH


static func reset_paths() -> void:
	contracts_path = CONTRACTS_PATH
	contracts_old_path = CONTRACTS_OLD_PATH
	types_path = TYPES_PATH
	organizations_path = ORGANIZATIONS_PATH
	locations_path = LOCATIONS_PATH
	descriptions_path = DESCRIPTIONS_PATH
	areas_path = AREAS_PATH
	buildings_path = BUILDINGS_PATH
	npcs_path = NPCS_PATH
	traditions_path = TRADITIONS_PATH
	checks_path = CHECKS_PATH
	stats_path = STATS_PATH
	circumstances_path = CIRCUMSTANCES_PATH
	knowledges_path = KNOWLEDGES_PATH
	events_path = EVENTS_PATH


static func contract_rows() -> Array[Dictionary]:
	return TsvReader.load_header_rows(contracts_path)


static func contract_row(contract_name: String) -> Dictionary:
	for row: Dictionary in contract_rows():
		if String(row.get("Contract Name", "")) == contract_name:
			return row
	return {}


#The first row of a type: the template a new contract of that type copies (ContractDraft.apply_template).
#The live sheet wins; a type it lacks falls back to its first Contracts_OLD.tsv row.
static func template_row(contract_type: String) -> Dictionary:
	for rows: Array[Dictionary] in [contract_rows(), TsvReader.load_header_rows(contracts_old_path)]:
		for row: Dictionary in rows:
			if String(row.get("Contract Type", "")) == contract_type:
				return row
	return {}


#Contract Name per row, Contract Type when the name is blank; distinct and sorted.
static func contract_names() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in contract_rows():
		var title: String = String(row.get("Contract Name", ""))
		if title == "":
			title = String(row.get("Contract Type", ""))
		_add_unique(out, title)
	out.sort()
	return out


#The Types.tsv CONTRACT column plus every Contract Type in Contracts.tsv; distinct and sorted.
static func contract_type_names() -> Array[String]:
	var out: Array[String] = _type_column()
	for row: Dictionary in contract_rows():
		_add_unique(out, String(row.get("Contract Type", "")))
	out.sort()
	return out


#Only the Types.tsv CONTRACT column counts, so writing the Contracts row first does not change the answer.
static func type_exists(name: String) -> bool:
	return _type_column().has(name)


static func person_issuers() -> Array[String]:
	return ContractDataValidator.PERSON_ISSUERS.duplicate()


#Locations.tsv names whose Location Type is in PLACE_TYPES, in file order.
static func place_names() -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(locations_path)
	for i: int in range(1, rows.size()):
		if PLACE_TYPES.has(TsvReader.row_get(rows[i], LOCATIONS_TYPE_COLUMN)):
			_add_unique(out, TsvReader.row_get(rows[i], LOCATIONS_NAME_COLUMN))
	return out


#{"name", "type"} per Locations.tsv row of each PLACE_TYPES type in turn, in file order; distinct names.
static func place_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(locations_path)
	for place_type: String in PLACE_TYPES:
		for i: int in range(1, rows.size()):
			if TsvReader.row_get(rows[i], LOCATIONS_TYPE_COLUMN) == place_type:
				_add_row(out, TsvReader.row_get(rows[i], LOCATIONS_NAME_COLUMN), place_type)
	return out


#{"name", "type"} per Areas.tsv row, then per Buildings.tsv row as INTERIOR_TYPE (DataManager._load_buildings); distinct names.
static func area_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var areas: Array[PackedStringArray] = TsvReader.load_tsv(areas_path)
	for i: int in range(1, areas.size()):
		_add_row(out, TsvReader.row_get(areas[i], AREAS_NAME_COLUMN), TsvReader.row_get(areas[i], AREAS_TYPE_COLUMN))
	var buildings: Array[PackedStringArray] = TsvReader.load_tsv(buildings_path)
	for i: int in range(1, buildings.size()):
		_add_row(out, TsvReader.row_get(buildings[i], BUILDINGS_NAME_COLUMN), INTERIOR_TYPE)
	return out


static func organization_names() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in TsvReader.load_header_rows(organizations_path):
		_add_unique(out, String(row.get(ORGANIZATIONS_NAME_COLUMN, "")))
	return out


static func organization_exists(name: String) -> bool:
	return organization_names().has(name)


static func issuer_options(issuer_type: String) -> Array[String]:
	match issuer_type:
		"person":
			return person_issuers()
		"place":
			return place_names()
		"org":
			return organization_names()
	var none: Array[String] = []
	return none


#The Descriptions.tsv texts of one contract name in file order, read as ContractResourceBuilder.descriptions_for
#reads DataManager.description_rows; a blank Description is skipped.
static func descriptions_for(contract_name: String) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in TsvReader.load_header_rows(descriptions_path):
		var text: String = String(row.get("Description", ""))
		if text != "" and String(row.get("Contract Name", "")) == contract_name:
			out.append(text)
	return out


#The Title cell of every NPCs.tsv row: distinct non-blank titles in file order.
static func npc_titles() -> Array[String]:
	return _header_column(npcs_path, NPCS_TITLE_COLUMN)


#The Types.tsv CREATURES column, read as _type_column reads CONTRACT.
static func creature_types() -> Array[String]:
	return _types_column(CREATURES_COLUMN)


#The Tradition Name cell of every Traditions.tsv row: distinct non-blank names in file order.
static func tradition_names() -> Array[String]:
	return _header_column(traditions_path, TRADITIONS_NAME_COLUMN)


#The Checks.tsv data rows in sheet order, header skipped; a row with a blank Check Name is skipped.
static func check_rows() -> Array[PackedStringArray]:
	return TsvReader.data_rows(checks_path, CHECKS_NAME_COLUMN)


#The Check Name cell of every Checks.tsv row: distinct non-blank names in sheet order.
static func check_names() -> Array[String]:
	return _column_values(checks_path, CHECKS_NAME_COLUMN)


#The Stats.tsv rows whose Type is STATS_CORE_TYPE, in sheet order; CORE_STATS_FALLBACK when there is none.
static func attribute_names() -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(stats_path)
	for i: int in range(1, rows.size()):
		if TsvReader.row_get(rows[i], STATS_TYPE_COLUMN) == STATS_CORE_TYPE:
			_add_unique(out, TsvReader.row_get(rows[i], STATS_NAME_COLUMN))
	if out.is_empty():
		return CORE_STATS_FALLBACK.duplicate()
	return out


#{"name", "stat", "rarity"} per Circumstances.tsv row in sheet order, blank names skipped; a name repeats under other stats.
static func circumstance_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(circumstances_path)
	for i: int in range(1, rows.size()):
		var row_name: String = TsvReader.row_get(rows[i], CIRCUMSTANCES_NAME_COLUMN)
		if row_name != "":
			out.append({"name": row_name, "stat": TsvReader.row_get(rows[i], CIRCUMSTANCES_STAT_COLUMN),
				"rarity": TsvReader.row_get(rows[i], CIRCUMSTANCES_RARITY_COLUMN).strip_edges()})
	return out


#{"name", "category", "rarity"} per knowledge of Knowledges and Tools.tsv in sheet order; a repeated name is kept once.
static func knowledge_rows() -> Array[Dictionary]:
	return _named_rows(knowledges_path, KNOWLEDGES_NAME_COLUMN, KNOWLEDGES_CATEGORY_COLUMN, KNOWLEDGES_RARITY_COLUMN)


#{"name", "category", "rarity"} per tool of Knowledges and Tools.tsv in sheet order; a repeated name is kept once.
static func tool_rows() -> Array[Dictionary]:
	return _named_rows(knowledges_path, TOOLS_NAME_COLUMN, TOOLS_CATEGORY_COLUMN, TOOLS_RARITY_COLUMN)


#The Knowledges column of Knowledges and Tools.tsv: distinct non-blank names in sheet order.
static func knowledge_names() -> Array[String]:
	return _column_values(knowledges_path, KNOWLEDGES_NAME_COLUMN)


#The Tools column of Knowledges and Tools.tsv: distinct non-blank names in sheet order.
static func tool_names() -> Array[String]:
	return _column_values(knowledges_path, TOOLS_NAME_COLUMN)


#The Event Name of every Events.tsv row whose Event Type is Primary: distinct non-blank names in sheet order.
static func event_names() -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(events_path)
	if rows.is_empty():
		return out
	var name_col: int = _column(rows[0], EVENTS_NAME_COLUMN)
	var type_col: int = _column(rows[0], EVENTS_TYPE_COLUMN)
	if name_col < 0 or type_col < 0:
		push_warning("ContractBuilderData: %s has no %s or %s column" % [events_path, EVENTS_NAME_COLUMN,
			EVENTS_TYPE_COLUMN])
		return out
	for i: int in range(1, rows.size()):
		if TsvReader.row_get(rows[i], type_col) == EVENTS_PRIMARY_TYPE:
			_add_unique(out, TsvReader.row_get(rows[i], name_col))
	return out


#event_names() then each EventConfig.PLANNED name the sheet does not hold yet, in PLANNED order.
static func event_options() -> Array[String]:
	var out: Array[String] = event_names()
	for planned: String in EventConfig.PLANNED:
		if not out.has(planned):
			out.append(planned)
	return out


#A PLANNED name with no Primary row in Events.tsv yet.
static func is_planned(name: String) -> bool:
	return EventConfig.PLANNED.has(name) and not event_names().has(name)


#The Contracts.tsv header cells in column order.
static func header() -> Array[String]:
	var out: Array[String] = []
	var file: FileAccess = FileAccess.open(contracts_path, FileAccess.READ)
	if file == null:
		push_error("ContractBuilderData: cannot open %s" % contracts_path)
		return out
	for column: String in file.get_line().split("\t"):
		out.append(column.strip_edges())
	file.close()
	return out


#The Types.tsv CONTRACT column: distinct names in file order.
static func _type_column() -> Array[String]:
	return _types_column(TYPES_COLUMN)


#The Types.tsv column titled title: distinct non-blank names in file order.
static func _types_column(title: String) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(types_path)
	if rows.is_empty():
		return out
	var col: int = _column(rows[0], title)
	if col < 0:
		push_warning("ContractBuilderData: %s has no %s column" % [types_path, title])
		return out
	for i: int in range(1, rows.size()):
		_add_unique(out, TsvReader.row_get(rows[i], col))
	return out


#One column of a sheet read through TsvReader.load_header_rows: distinct non-blank cells in file order.
static func _header_column(path: String, title: String) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[Dictionary] = TsvReader.load_header_rows(path)
	if not rows.is_empty() and not rows[0].has(title):
		push_warning("ContractBuilderData: %s has no %s column" % [path, title])
	for row: Dictionary in rows:
		_add_unique(out, String(row.get(title, "")))
	return out


#One column of a sheet by index, header row skipped: distinct non-blank cells in sheet order.
static func _column_values(path: String, column: int) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(path)
	for i: int in range(1, rows.size()):
		_add_unique(out, TsvReader.row_get(rows[i], column))
	return out


#Three columns of a sheet by index, header row skipped: blank names skipped, the first row of a name kept.
static func _named_rows(path: String, name_column: int, category_column: int, rarity_column: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(path)
	for i: int in range(1, rows.size()):
		var row_name: String = TsvReader.row_get(rows[i], name_column).strip_edges()
		if row_name == "" or seen.has(row_name):
			continue
		seen[row_name] = true
		out.append({"name": row_name, "category": TsvReader.row_get(rows[i], category_column).strip_edges(),
			"rarity": TsvReader.row_get(rows[i], rarity_column).strip_edges()})
	return out


static func _column(header_row: PackedStringArray, title: String) -> int:
	for c: int in range(header_row.size()):
		if TsvReader.row_get(header_row, c) == title:
			return c
	return -1


static func _add_unique(list: Array[String], value: String) -> void:
	var v: String = value.strip_edges()
	if v != "" and not list.has(v):
		list.append(v)


#Appends {"name", "type"} unless row_name is blank or already in rows; row_name comes trimmed from TsvReader.row_get.
static func _add_row(rows: Array[Dictionary], row_name: String, row_type: String) -> void:
	if row_name == "":
		return
	for row: Dictionary in rows:
		if String(row["name"]) == row_name:
			return
	rows.append({"name": row_name, "type": row_type})

class_name ContractDataValidator
extends RefCounted

#Checks built ContractData and EventData against the stat, circumstance, knowledge, tool, tradition,
#location, organization and penalty tables and the builder cell grammars; returns warning texts and changes nothing.

const LEVEL_CAP := 240
#The most mercs a contract takes; DispatchWindow shows this many slots.
const MERC_CAP := 5
const PERSON_ISSUERS: Array[String] = ["Commoner", "Aristocrat", "Mercenary", "Noble"]
const STYLES: Array[String] = ["check", "event", "timeline"]
#Leader and Support are implied on every contract; a row may still name them; Guide is offered only when named.
const ROLES: Array[String] = ["Assassin", "Driver", "Escort", "Investigator", "Leader", "Support", "Guide"]
const TARGET_PREFIXES: Array[String] = ["npc:", "monster:", "random:"]
const CONSEQUENCE_KINDS: Array[String] = ["retry", "hp", "ep", "mp", "guild"]


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
	if data.difficulty > 0.0 and not half_step_ok(data.difficulty):
		out.append(contract_warning(sheet_row, "Difficulty",
			"expected 0.5 to 5 in steps of 0.5, got %s" % str(data.difficulty)))
	out.append_array(_terrain_odds_warnings(data.terrain_odds, sheet_row))
	out.append_array(_builder_warnings(data, sheet_row))
	var local_cell: String = String(row.get("Local", "")).strip_edges()
	if local_cell.to_upper() not in ["", "TRUE", "FALSE"]:
		out.append(contract_warning(sheet_row, "Local", "expected TRUE, FALSE or blank, got %s" % local_cell))
	return out


#True for 0.5 to 5 in steps of 0.5.
static func half_step_ok(value: float) -> bool:
	var steps: float = value * 2.0
	return steps == floor(steps) and steps >= 1.0 and steps <= 10.0


#Blank, check:<name>, event:<name> or a timeline (a cell holding both "=" and ":").
static func completion_ok(cell: String) -> bool:
	if cell == "":
		return true
	for prefix: String in ["check:", "event:"]:
		if cell.begins_with(prefix):
			return cell.length() > prefix.length()
	return cell.contains("=") and cell.contains(":")


#"<kind> <n>" with kind in CONSEQUENCE_KINDS and n from -9 to -1; a bare kind reads as n -1.
static func consequence_token_ok(token: String) -> bool:
	var parts: PackedStringArray = token.split(" ", false)
	if parts.is_empty() or parts.size() > 2 or not CONSEQUENCE_KINDS.has(parts[0]):
		return false
	if parts.size() == 1:
		return true
	return parts[1].is_valid_int() and int(parts[1]) >= -9 and int(parts[1]) <= -1


#The columns only the contract builder writes: ranges, issuer, style, roles, target, completion, time, consequence.
static func _builder_warnings(data: ContractData, sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_level_warnings(data, sheet_row))
	out.append_array(_merc_count_warnings(data, sheet_row))
	out.append_array(_difficulty_range_warnings(data, sheet_row))
	out.append_array(_issuer_warnings(data, sheet_row))
	if data.style != "" and not STYLES.has(data.style):
		out.append(contract_warning(sheet_row, "Style", "expected check, event or timeline, got %s" % data.style))
	for role: String in data.roles:
		if not ROLES.has(role):
			out.append(contract_warning(sheet_row, "Roles", "unknown role %s" % role))
	if data.target != "" and not _has_prefix(data.target, TARGET_PREFIXES):
		out.append(contract_warning(sheet_row, "Target", "expected npc:, monster: or random:, got %s" % data.target))
	if data.style == "timeline" and data.completion != "":
		var timeline: String = _timeline_reason(data.completion, data.roles)
		if timeline != "":
			out.append(contract_warning(sheet_row, "Completion", "timeline: %s" % timeline))
	elif not completion_ok(data.completion):
		out.append(contract_warning(sheet_row, "Completion",
			"expected check:<name>, event:<name> or a timeline, got %s" % data.completion))
	if data.completion.begins_with(CheckStore.PREFIX) and completion_ok(data.completion) \
			and not CheckStore.has_row(CheckStore.bare_name(data.completion)):
		out.append(contract_warning(sheet_row, "Completion",
			"no Checks.tsv row named %s" % CheckStore.bare_name(data.completion)))
	if data.time_minutes < 0:
		out.append(contract_warning(sheet_row, "Time", "expected 0 or more minutes, got %d" % data.time_minutes))
	for token: String in TsvReader.split_field(data.consequence):
		if not consequence_token_ok(token):
			out.append(contract_warning(sheet_row, "Consequence", "bad token %s" % token))
	var event_name: String = ""
	if data.completion.begins_with("event:"):
		event_name = data.completion.trim_prefix("event:").strip_edges()
	if event_name != "":
		var reason: String = EventConfig.validate(event_name, data.event_config)
		if reason != "":
			out.append(contract_warning(sheet_row, "Event Config", reason))
	elif data.event_config != "":
		out.append(contract_warning(sheet_row, "Event Config", "set without an event completion"))
	return out


#The TimelineGrammar reason, else the first step role outside Leader, Support and the row's listed roles.
static func _timeline_reason(cell: String, roles: Array[String] = []) -> String:
	var reason: String = TimelineGrammar.error(cell)
	if reason != "":
		return reason
	var allowed: Array[String] = ["Leader", "Support"]
	for role: String in roles:
		if ROLES.has(role) and not allowed.has(role):
			allowed.append(role)
	for item: Variant in TimelineGrammar.parse(cell):
		var step: TimelineGrammar.Step = item
		if step.role != "" and not allowed.has(step.role):
			return "step %s role %s is not a contract role" % [step.id, step.role]
	return ""


static func _level_warnings(data: ContractData, sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	var ends: Dictionary = {"Level Min": data.level_min, "Level Max": data.level_max}
	for column: String in ends:
		var value: int = int(ends[column])
		if value < 0 or value > LEVEL_CAP:
			out.append(contract_warning(sheet_row, column, "expected 0 to %d, got %d" % [LEVEL_CAP, value]))
	if data.level_max > 0 and data.level_min > data.level_max:
		out.append(contract_warning(sheet_row, "Level Min", "%d is above Level Max %d" % [data.level_min, data.level_max]))
	return out


#A blank Max Mercs reads as default_max_mercs for the min check, since ContractGenerator clamps min to it.
static func _merc_count_warnings(data: ContractData, sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	var ends: Dictionary = {"Min Mercs": data.min_mercs, "Max Mercs": data.max_mercs}
	for column: String in ends:
		var value: int = int(ends[column])
		if value != 0 and (value < 1 or value > MERC_CAP):
			out.append(contract_warning(sheet_row, column, "expected 1 to %d, got %d" % [MERC_CAP, value]))
	var high: int = data.max_mercs if data.max_mercs > 0 else ContractLibrary.config().default_max_mercs
	if data.min_mercs > 0 and data.min_mercs > high:
		out.append(contract_warning(sheet_row, "Min Mercs", "%d is above Max Mercs %d" % [data.min_mercs, high]))
	return out


static func _difficulty_range_warnings(data: ContractData, sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	var ends: Dictionary = {"Difficulty Min": data.difficulty_min, "Difficulty Max": data.difficulty_max}
	for column: String in ends:
		var value: float = float(ends[column])
		if value != 0.0 and not half_step_ok(value):
			out.append(contract_warning(sheet_row, column, "expected 0.5 to 5 in steps of 0.5, got %s" % str(value)))
	if (data.difficulty_min == 0.0) != (data.difficulty_max == 0.0):
		var blank: String = "Difficulty Min" if data.difficulty_min == 0.0 else "Difficulty Max"
		out.append(contract_warning(sheet_row, blank, "blank while the other end of the range is set"))
	elif data.difficulty_min > data.difficulty_max:
		out.append(contract_warning(sheet_row, "Difficulty Min",
			"%s is above Difficulty Max %s" % [str(data.difficulty_min), str(data.difficulty_max)]))
	return out


#An org Issuer is checked only once Organizations.tsv has rows.
static func _issuer_warnings(data: ContractData, sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	match data.issuer_type:
		"":
			pass
		"person":
			if not PERSON_ISSUERS.has(data.issuer):
				out.append(contract_warning(sheet_row, "Issuer",
					"expected Commoner, Aristocrat, Mercenary or Noble, got %s" % data.issuer))
		"place":
			if not _loc_ok(data.issuer):
				out.append(contract_warning(sheet_row, "Issuer", "unknown location %s" % data.issuer))
		"org":
			if not DataManager.organization_rows.is_empty() and not _org_ok(data.issuer):
				out.append(contract_warning(sheet_row, "Issuer", "unknown organization %s" % data.issuer))
		_:
			out.append(contract_warning(sheet_row, "Issuer Type",
				"expected person, place or org, got %s" % data.issuer_type))
	return out


static func _has_prefix(text: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if text.begins_with(prefix):
			return true
	return false


static func _terrain_odds_warnings(odds: Array[Dictionary], sheet_row: int) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var edge: int = 0
	for entry: Dictionary in odds:
		var name: String = String(entry.get("area", ""))
		var percent: int = int(entry.get("percent", -1))
		if seen.has(name):
			out.append(contract_warning(sheet_row, "Terrain Odds", "duplicate area %s" % name))
		seen[name] = true
		var start: int = edge
		if percent >= 1:
			edge += mini(percent, 100)
		var area: Dictionary = DataManager.get_area_by_name(name)
		if area.is_empty():
			out.append(contract_warning(sheet_row, "Terrain Odds", "unknown area %s" % name))
			continue
		var area_type: String = String(area.get("type", ""))
		#The draw skips a TBD row on purpose until the designer builds it.
		if area_type == "TBD":
			continue
		if not ContractTerrain.odds_allowed(area):
			out.append(contract_warning(sheet_row, "Terrain Odds", "area %s of type %s cannot be forced" % [name, area_type]))
			continue
		if percent < 1 or percent > 100:
			out.append(contract_warning(sheet_row, "Terrain Odds",
				"expected 1 to 100 for %s, got %d" % [name, percent]))
		elif start >= 100:
			out.append(contract_warning(sheet_row, "Terrain Odds", "%s never draws: the entries before it fill 100" % name))
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


#The name lookups both sheet validators share; stat_names is bound once per row.
static func _stat_ok(n: String, stat_names: Dictionary) -> bool:
	return stat_names.has(ContractModifiers.stat_key(n))


static func _circ_ok(n: String) -> bool:
	return ConstCircumstances.DATA.has(n)


static func _know_ok(n: String) -> bool:
	return DataManager.knowledges.has(n)


static func _loc_ok(n: String) -> bool:
	return DataManager.locations.has(n)


static func _org_ok(n: String) -> bool:
	for row: Dictionary in DataManager.organization_rows:
		if String(row.get("Name", "")) == n:
			return true
	return false


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
	for rows: Array[Dictionary] in [DataManager.contract_rows, DataManager.contract_rows_old]:
		for row: Dictionary in rows:
			if String(row.get("Contract Type", "")) == name:
				return true
	return false

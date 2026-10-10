@tool
class_name ContractDraft extends RefCounted

#One Contracts.tsv row while the builder fills it: one field per column, the boost cells keyed by
#header, plus the Descriptions.tsv lines, a new Checks.tsv row and the page the builder shows. Stage 2 writes row_cells().

const BOOST_HEADERS: Array[String] = ["15% Stat", "10% Stat", "5% Stat", "15% Circumstances",
	"10% Circumstances", "5% Circumstances", "15% Tool", "10% Tool", "5% Tool", "15% Knowledge",
	"10% Knowledge", "5% Knowledge", "15% Tradition", "10% Tradition", "5% Tradition", "15% Penalty",
	"10% Penalty", "5% Penalty"]
const LIST_SEP: String = ", "
const NAME_MAX: int = 24
#Tags the game fills in a name; the builder cannot know the fill, so a tag counts 0 characters (answer 6).
const NAME_TAGS: Array[String] = ["%target%", "%location%", "%requestor%"]

var contract_name: String = ""
var contract_type: String = ""
var boosts: Dictionary = {}
var description_template: String = ""
var target_category: String = ""
var possible_traits: Array[String] = []
var possible_locations: Array[String] = []
var terrain_odds: String = ""
var level_min: int = 0
var level_max: int = 0
var issuer_type: String = ""
var issuer: String = ""
var difficulty_min: float = 0.0
var difficulty_max: float = 0.0
var story: bool = false
var style: String = ""
var roles: Array[String] = []
var target: String = ""
var completion: String = ""
var event_config: String = ""
var time: int = 0
var consequence: String = ""
#Min Mercs and Max Mercs; 0 is a blank cell.
var merc_min: int = 0
var merc_max: int = 0
#Local: the job is at the guild; a TRUE cell when set, a blank cell otherwise.
var local: bool = false
#The CheckSheet.WIDTH cells of the Checks.tsv row Confirm adds, the name first; empty for no new check.
var check_row: Array[String] = []
#Under Style timeline, the Checks.tsv rows built from steps, each CheckSheet.WIDTH cells; Confirm adds those a step names.
var timeline_checks: Array = []
var descriptions: Array[String] = []
var page: int = 0
#The Contract Name of the loaded row; "" for a new contract.
var source_name: String = ""


func to_dict() -> Dictionary:
	return {
		"contract_name": contract_name,
		"contract_type": contract_type,
		"boosts": boosts.duplicate(),
		"description_template": description_template,
		"target_category": target_category,
		"possible_traits": possible_traits.duplicate(),
		"possible_locations": possible_locations.duplicate(),
		"terrain_odds": terrain_odds,
		"level_min": level_min,
		"level_max": level_max,
		"issuer_type": issuer_type,
		"issuer": issuer,
		"difficulty_min": difficulty_min,
		"difficulty_max": difficulty_max,
		"story": story,
		"style": style,
		"roles": roles.duplicate(),
		"target": target,
		"completion": completion,
		"event_config": event_config,
		"time": time,
		"consequence": consequence,
		"merc_min": merc_min,
		"merc_max": merc_max,
		"local": local,
		"check_row": check_row.duplicate(),
		"timeline_checks": timeline_checks.duplicate(true),
		"descriptions": descriptions.duplicate(),
		"page": page,
		"source_name": source_name,
	}


#Missing or mistyped keys fall back to the unset value, so an old or hand-edited draft still loads.
func from_dict(d: Dictionary) -> void:
	contract_name = _text(d, "contract_name")
	contract_type = _text(d, "contract_type")
	boosts = {}
	var raw: Variant = d.get("boosts", {})
	if raw is Dictionary:
		for key: String in BOOST_HEADERS:
			var value: String = _text(raw as Dictionary, key)
			if value != "":
				boosts[key] = value
	description_template = _text(d, "description_template")
	target_category = _text(d, "target_category")
	possible_traits = _strings(d, "possible_traits")
	possible_locations = _strings(d, "possible_locations")
	terrain_odds = _text(d, "terrain_odds")
	level_min = _int(d, "level_min")
	level_max = _int(d, "level_max")
	issuer_type = _text(d, "issuer_type")
	issuer = _text(d, "issuer")
	difficulty_min = _float(d, "difficulty_min")
	difficulty_max = _float(d, "difficulty_max")
	story = _bool(d, "story")
	style = _text(d, "style")
	roles = _strings(d, "roles")
	target = _text(d, "target")
	completion = _text(d, "completion")
	event_config = _text(d, "event_config")
	time = _int(d, "time")
	consequence = _text(d, "consequence")
	merc_min = _int(d, "merc_min")
	merc_max = _int(d, "merc_max")
	local = _bool(d, "local")
	check_row = _cells(d, "check_row", CheckSheet.WIDTH)
	timeline_checks = []
	var pending: Variant = d.get("timeline_checks", [])
	if pending is Array:
		for entry: Variant in (pending as Array):
			var row: Array[String] = _row(entry, CheckSheet.WIDTH)
			if not row.is_empty():
				timeline_checks.append(row)
	descriptions = _strings(d, "descriptions")
	page = _int(d, "page")
	source_name = _text(d, "source_name")


func clear() -> void:
	from_dict({})


func is_new() -> bool:
	return source_name == ""


static func name_length(name: String) -> int:
	var tags: RegEx = RegEx.new()
	tags.compile("|".join(PackedStringArray(NAME_TAGS)))
	return tags.sub(name, "", true).length()


#Every field from a header-keyed row as ContractBuilderData.contract_rows() returns it; a missing cell reads "".
#The page stays; a Story or Local cell is set when it reads TRUE in any case, as ContractResourceBuilder reads it.
func from_row(row: Dictionary) -> void:
	contract_name = _text(row, "Contract Name")
	contract_type = _text(row, "Contract Type")
	apply_template(row)
	level_min = _int_text(_text(row, "Level Min"))
	level_max = _int_text(_text(row, "Level Max"))
	issuer_type = _text(row, "Issuer Type")
	issuer = _text(row, "Issuer")
	difficulty_min = _float_text(_text(row, "Difficulty Min"))
	difficulty_max = _float_text(_text(row, "Difficulty Max"))
	story = _text(row, "Story").strip_edges().to_upper() == "TRUE"
	style = _text(row, "Style")
	roles = TsvReader.split_field(_text(row, "Roles"))
	target = _text(row, "Target")
	completion = _text(row, "Completion")
	event_config = _text(row, "Event Config")
	time = _int_text(_text(row, "Time"))
	consequence = _text(row, "Consequence")
	merc_min = _int_text(_text(row, "Min Mercs"))
	merc_max = _int_text(_text(row, "Max Mercs"))
	local = _text(row, "Local").strip_edges().to_upper() == "TRUE"
	check_row = []
	timeline_checks = []
	descriptions = ContractBuilderData.descriptions_for(contract_name)
	source_name = contract_name


#The cells a type's template row carries over to a new contract of that type; an empty row clears them.
func apply_template(row: Dictionary) -> void:
	boosts = {}
	for key: String in BOOST_HEADERS:
		var value: String = _text(row, key)
		if value != "":
			boosts[key] = value
	description_template = _text(row, "Description Template")
	target_category = _text(row, "Target Category")
	possible_traits = TsvReader.split_field(_text(row, "Possible Traits"))
	possible_locations = TsvReader.split_field(_text(row, "Possible Locations"))
	terrain_odds = _text(row, "Terrain Odds")


#One cell per header name in the header's order; "" for an unset field or a column the draft lacks.
func row_cells(header: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for column: String in header:
		out.append(cell(column))
	return out


func cell(column: String) -> String:
	if BOOST_HEADERS.has(column):
		return _text(boosts, column)
	match column:
		"Contract Name":
			return contract_name
		"Contract Type":
			return contract_type
		"Description Template":
			return description_template
		"Target Category":
			return target_category
		"Possible Traits":
			return LIST_SEP.join(PackedStringArray(possible_traits))
		"Possible Locations":
			return LIST_SEP.join(PackedStringArray(possible_locations))
		"Terrain Odds":
			return terrain_odds
		"Level Min":
			return _int_cell(level_min)
		"Level Max":
			return _int_cell(level_max)
		"Issuer Type":
			return issuer_type
		"Issuer":
			return issuer
		"Difficulty Min":
			return _float_cell(difficulty_min)
		"Difficulty Max":
			return _float_cell(difficulty_max)
		"Story":
			return "TRUE" if story else ""
		"Style":
			return style
		"Roles":
			return LIST_SEP.join(PackedStringArray(roles))
		"Target":
			return target
		"Completion":
			return completion
		"Event Config":
			return event_config
		"Time":
			return _int_cell(time)
		"Consequence":
			return consequence
		"Min Mercs":
			return _int_cell(merc_min)
		"Max Mercs":
			return _int_cell(merc_max)
		"Local":
			return "TRUE" if local else ""
	return ""


static func _int_cell(value: int) -> String:
	return str(value) if value > 0 else ""


static func _float_cell(value: float) -> String:
	return "%.1f" % value if value > 0.0 else ""


static func _int_text(raw: String) -> int:
	var text: String = raw.strip_edges()
	return int(text) if text.is_valid_int() else 0


static func _float_text(raw: String) -> float:
	var text: String = raw.strip_edges()
	return float(text) if text.is_valid_float() else 0.0


static func _text(d: Dictionary, key: String) -> String:
	var value: Variant = d.get(key, "")
	if value is String or value is StringName:
		return String(value)
	return ""


static func _int(d: Dictionary, key: String) -> int:
	var value: Variant = d.get(key, 0)
	if value is int or value is float:
		return int(value)
	return 0


static func _float(d: Dictionary, key: String) -> float:
	var value: Variant = d.get(key, 0.0)
	if value is int or value is float:
		return float(value)
	return 0.0


static func _bool(d: Dictionary, key: String) -> bool:
	var value: Variant = d.get(key, false)
	return value if value is bool else false


static func _strings(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = d.get(key, [])
	if not (value is Array):
		return out
	for item: Variant in (value as Array):
		if item is String and String(item) != "":
			out.append(String(item))
	return out


static func _cells(d: Dictionary, key: String, width: int) -> Array[String]:
	return _row(d.get(key, []), width)


#An Array of exactly width Strings, blanks kept; anything else gives an empty array.
static func _row(value: Variant, width: int) -> Array[String]:
	var out: Array[String] = []
	if not (value is Array) or (value as Array).size() != width:
		return out
	for item: Variant in (value as Array):
		if not (item is String):
			out.clear()
			return out
		out.append(String(item))
	return out

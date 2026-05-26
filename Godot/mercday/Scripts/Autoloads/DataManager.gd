extends Node

var locations: Dictionary = {}
var ancestries: Dictionary = {}
var bloodlines: Dictionary = {}
var heritages: Dictionary = {}
var starting_lifepaths: Dictionary = {}
var lifepaths_by_category: Dictionary = {}
var items: Dictionary = {}  # TODO: populated by _load_items() once Items.tsv exists
var traditions: Dictionary = {}
var traits: Dictionary = {}
var knowledges: Dictionary = {}
var tools: Dictionary = {}
var knowledge_categories: Dictionary = {}
var tool_categories: Dictionary = {}
var stat_definitions: Array[Dictionary] = []
var creature_types: Array[String] = []
var environment_types: Array[String] = []
var critical_success_options: Array = []

const EFFECT_PREFIXES: PackedStringArray = ["immune to ", "protected from ", "susceptible to "]
const EFFECT_DSLS: PackedStringArray = ["immune:", "protected:", "susceptible:"]

const STAT_VAR_MAP: Dictionary = {
	"Maximum Hit Points": "max_hp", "Maximum HP": "max_hp",
	"Maximum Endurance Points": "max_ep", "Maximum EP": "max_ep",
	"Maximum Magic Points": "max_mp", "Maximum MP": "max_mp",
	"Maximum Cognition": "max_cognition", "Maximum Dexterity": "max_dexterity",
	"Maximum Vigor": "max_vigor", "Maximum Wile": "max_wile",
	"Defense": "defense", "Speed": "speed", "Pace": "pace",
	"Accuracy": "accuracy", "Combat": "combat", "Luck": "luck",
	"Avoid": "avoid", "Block": "block", "Dodge": "dodge",
	"Health": "health", "Social": "social", "Intellect": "intellect",
}


func _ready() -> void:
	ConstCircumstances.load_from_tsv("res://TSVs/Circumstances.tsv")
	_load_knowledges_and_tools()
	_load_stats()
	_load_locations()
	_load_ancestries()
	_load_heritages()
	_load_lifepaths()
	_load_traditions()
	_load_traits()
	_load_items()
	_load_types()
	_load_critical_successes()
	_resolve_location_parents()


#CSV Readers
func _csv_rows(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DataManager: cannot open %s" % path)
		return rows
	while not file.eof_reached():
		rows.append(file.get_csv_line("\t"))
	file.close()
	return rows


func _split_field(value: String) -> Array[String]:
	var result: Array[String] = []
	if value.strip_edges() == "":
		return result
	for part: String in value.split(","):
		var t: String = part.strip_edges()
		if t != "":
			result.append(t)
	return result


func _row_get(row: PackedStringArray, idx: int) -> String:
	return row[idx].strip_edges() if idx < row.size() else ""


#CSV loading
func _load_knowledges_and_tools() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Knowledges and Tools.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var k_name: String = _row_get(row, 0)
		var t_name: String = _row_get(row, 4)
		if k_name != "":
			var k := UtilityTraitData.new()
			k.utility_type = "Knowledge"
			k.utility_name = k_name
			k.utility_use = _row_get(row, 1)
			k.utility_category = _row_get(row, 2)
			k.utility_rarity = _row_get(row, 3)
			knowledges[k_name] = k
			var kcat_key: String = k.utility_category.to_upper()
			if kcat_key != "":
				if not knowledge_categories.has(kcat_key):
					knowledge_categories[kcat_key] = []
				var kcat: Array = knowledge_categories[kcat_key]
				kcat.append(k_name)
		if t_name != "":
			var t := UtilityTraitData.new()
			t.utility_type = "Tool"
			t.utility_name = t_name
			t.utility_use = _row_get(row, 5)
			t.utility_category = _row_get(row, 6)
			t.utility_rarity = _row_get(row, 7)
			tools[t_name] = t
			var tcat_key: String = t.utility_category.to_upper()
			if tcat_key != "":
				if not tool_categories.has(tcat_key):
					tool_categories[tcat_key] = []
				var tcat: Array = tool_categories[tcat_key]
				tcat.append(t_name)


func _load_stats() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Stats.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var stat_name: String = _row_get(row, 0)
		if stat_name == "":
			continue
		stat_definitions.append({
			"stat": stat_name,
			"var_name": stat_name.to_lower().replace(" ", "_"),
			"formula": _row_get(row, 1),
			"round": _row_get(row, 2),
			"type": _row_get(row, 3),
		})


func _load_locations() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Locations.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var loc_name: String = _row_get(row, 1)
		if loc_name == "":
			continue
		var loc := LocationData.new()
		loc.location_name = loc_name
		loc.prefix = _row_get(row, 0)
		loc.location_type = _row_get(row, 23)
		loc.demonym = _row_get(row, 20)
		loc.avg_temperature = _parse_temperature(_row_get(row, 11))
		_add_to_buff_dict(loc.knowledge_buffs, _row_get(row, 2), 5.0)
		_add_to_buff_dict(loc.knowledge_buffs, _row_get(row, 3), 3.0)
		_add_to_buff_dict(loc.knowledge_buffs, _row_get(row, 4), 1.0)
		_add_to_buff_dict(loc.tool_buffs, _row_get(row, 5), 4.0)
		_add_to_buff_dict(loc.tool_buffs, _row_get(row, 6), 2.0)
		_add_to_buff_dict(loc.tool_buffs, _row_get(row, 7), 1.0)
		_add_to_buff_dict(loc.circumstance_buffs, _row_get(row, 8), 5.0)
		_add_to_buff_dict(loc.circumstance_buffs, _row_get(row, 9), 3.0)
		_add_to_buff_dict(loc.circumstance_buffs, _row_get(row, 10), 1.0)
		_add_to_buff_dict(loc.ancestry_buffs, _row_get(row, 12), 5.0)
		_add_to_buff_dict(loc.ancestry_buffs, _row_get(row, 13), 2.0)
		_add_to_buff_dict(loc.bloodline_buffs, _row_get(row, 14), 5.0)
		_add_to_buff_dict(loc.bloodline_buffs, _row_get(row, 15), 2.0)
		_add_to_buff_dict(loc.heritage_buffs, _row_get(row, 16), 5.0)
		_add_to_buff_dict(loc.heritage_buffs, _row_get(row, 17), 2.0)
		_add_to_buff_dict(loc.ancestry_debuffs, _row_get(row, 18), 7.0)
		_add_to_buff_dict(loc.ancestry_debuffs, _row_get(row, 19), 4.0)
		loc.set_meta("parent_area", _row_get(row, 21))
		loc.set_meta("subparent_area", _row_get(row, 22))
		locations[loc_name] = loc


func _add_to_buff_dict(d: Dictionary, names_csv: String, pct: float) -> void:
	for buff_name: String in _split_field(names_csv):
		d[buff_name] = pct


func _parse_temperature(value: String) -> float:
	var parts: PackedStringArray = value.split(" ")
	if parts.size() >= 2:
		return float(parts[-1])
	return 0.0


func _resolve_location_parents() -> void:
	for loc_name: String in locations:
		var loc: LocationData = locations[loc_name] as LocationData
		var sub: String = str(loc.get_meta("subparent_area", ""))
		var parent_name: String = sub if sub != "" else str(loc.get_meta("parent_area", ""))
		if parent_name != "" and locations.has(parent_name):
			loc.parent = locations[parent_name] as LocationData


func _load_ancestries() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Ancestries.tsv")
	if rows.size() < 2:
		return
	var past_separator: bool = false
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 0)
		if name_val == "":
			past_separator = true
			continue
		var a := AncestryData.new()
		a.ancestry_name = name_val
		a.ancestry_category = "Bloodline" if past_separator else "Ancestry"
		a.possible_bloodlines = _split_field(_row_get(row, 1))
		a.rarity = _row_get(row, 2)
		if a.rarity == "":
			a.rarity = "Common"
		a.perks = _split_field(_row_get(row, 3))
		a.drawbacks = _split_field(_row_get(row, 4))
		var life_str: String = _row_get(row, 5)
		a.life_expectancy = int(life_str) if life_str.is_valid_int() else -1
		var dex_str: String = _row_get(row, 6)
		a.max_dexterity = int(dex_str) if dex_str.is_valid_int() else 0
		var vgr_str: String = _row_get(row, 7)
		a.max_vigor = int(vgr_str) if vgr_str.is_valid_int() else 0
		var size_str: String = _row_get(row, 8)
		a.size = 2 if size_str == "N/A" else (int(size_str) if size_str.is_valid_int() else 0)
		a.types = _split_field(_row_get(row, 9))
		a.hybrid_options = _row_get(row, 10)
		a.knowledge_odds_x20 = _split_field(_row_get(row, 11))
		a.tool_odds_x20 = _split_field(_row_get(row, 12))
		a.circumstance_odds_x20 = _split_field(_row_get(row, 13))
		a.stat_bonus_5pct = _split_field(_row_get(row, 14))
		if past_separator:
			bloodlines[name_val] = a
		else:
			ancestries[name_val] = a


func _load_heritages() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Heritages.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 0)
		if name_val == "":
			continue
		var h := HeritageData.new()
		h.heritage_name = name_val
		var cgn: String = _row_get(row, 1)
		h.max_cognition = int(cgn) if cgn.is_valid_int() else 0
		var wil: String = _row_get(row, 2)
		h.max_wile = int(wil) if wil.is_valid_int() else 0
		h.circumstances = _split_field(_row_get(row, 3))
		h.knowledges = _split_field(_row_get(row, 4))
		h.tools = _split_field(_row_get(row, 5))
		h.stat_bonus_5pct = _split_field(_row_get(row, 6))
		heritages[name_val] = h


func _load_lifepaths() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Lifepaths.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var event_type: String = _row_get(row, 0)
		if event_type == "":
			continue
		var name_val: String = _row_get(row, 1)
		if name_val == "":
			continue
		var lp := LifepathData.new()
		lp.event_type = event_type
		lp.event_name = name_val
		lp.description = _row_get(row, 2)
		lp.drawbacks = _split_field(_row_get(row, 6))
		lp.perks = _split_field(_row_get(row, 7))
		lp.rarity = _row_get(row, 8)
		if lp.rarity == "":
			lp.rarity = "Common"
		lp.stat_bonus_5pct = _split_field(_row_get(row, 10))
		if event_type == "Starting":
			starting_lifepaths[name_val] = lp
		else:
			if not lifepaths_by_category.has(event_type):
				lifepaths_by_category[event_type] = []
			var cat_arr: Array = lifepaths_by_category[event_type]
			cat_arr.append(lp)


func _load_traditions() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Traditions.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 0)
		if name_val == "":
			continue
		var t := TraditionData.new()
		t.tradition_name = name_val
		t.stat_boost_15 = _row_get(row, 2)
		t.stat_boost_10 = _row_get(row, 3)
		t.stat_boost_5 = _split_field(_row_get(row, 4))
		t.circumstance_boost = _row_get(row, 5)
		t.weight_plus_25 = _row_get(row, 6)
		t.weight_plus_10 = _row_get(row, 7)
		t.weight_minus_25 = _row_get(row, 8)
		t.weight_minus_5 = _row_get(row, 9)
		traditions[name_val] = t


func _load_types() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Types.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var creature: String = _row_get(row, 0)
		var environment: String = _row_get(row, 1)
		if creature != "":
			creature_types.append(creature)
		if environment != "":
			environment_types.append(environment)


func _load_items() -> void:
	# TODO: replace with ItemData resources once Godot imports ItemData.gd
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Items.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 0)
		if name_val == "":
			continue
		items[name_val] = {
			"item_name": name_val,
			"item_rarity": _row_get(row, 1),
			"item_type": _row_get(row, 2),
		}


func _load_traits() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Traits.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 3)
		if name_val == "":
			continue
		var trait_data := TraitData.new()
		trait_data.trait_source = _row_get(row, 0)
		trait_data.trait_category = _row_get(row, 1)
		trait_data.trait_type = _row_get(row, 2)
		trait_data.trait_name = name_val
		trait_data.description = _row_get(row, 4)
		trait_data.effect_dsl = _convert_legacy_effect(_row_get(row, 5))
		trait_data.rarity = _row_get(row, 6)
		if trait_data.rarity == "":
			trait_data.rarity = "Common"
		trait_data.is_bad = _row_get(row, 7).to_lower() == "true"
		trait_data.logline_a = _row_get(row, 8)
		trait_data.logline_b = _row_get(row, 9)
		traits[name_val] = trait_data




#Effect converter
func _convert_legacy_effect(raw: String) -> String:
	if raw == "" or raw == "No special effect.":
		return ""
	if _looks_like_dsl(raw):
		return raw
	var parts: Array[String] = []
	for sentence: String in raw.split(". "):
		var s: String = sentence.strip_edges().trim_suffix(".")
		if s != "":
			parts.append(s)
	var dsl_parts: Array[String] = []
	for part: String in parts:
		dsl_parts.append(_convert_one_effect(part))
	var result: String = "|".join(dsl_parts)
	return result if _looks_like_dsl(result) else "SPECIAL:" + raw


func _convert_one_effect(s: String) -> String:
	var lower: String = s.to_lower()
	if lower == "flying pace":
		return "grant:ability:flying_pace"
	if lower == "swimming pace":
		return "grant:ability:swimming_pace"
	if lower == "climbing pace":
		return "grant:ability:climbing_pace"
	if lower == "darksight":
		return "grant:ability:darksight"
	for i: int in range(EFFECT_PREFIXES.size()):
		var pfx: String = EFFECT_PREFIXES[i]
		if lower.begins_with(pfx):
			return EFFECT_DSLS[i] + s.substr(pfx.length()).strip_edges().to_lower().replace(" ", "_")
	if s.contains("random"):
		var count: int = _extract_count(s)
		if s.contains("Esoteric"):
			return "grant:random:esoteric:%d" % count
		if s.contains("Resist") and s.contains("Circumstance"):
			return "grant:random:circumstance:resist:%d" % count
		if s.contains("Circumstance"):
			return "grant:random:circumstance:%d" % count
		if s.contains("Tool"):
			return "grant:random:tool:%d" % count
		if s.contains("Knowledge"):
			return "grant:random:knowledge:%d" % count
	return _try_stat_dsl(s)


func _try_stat_dsl(s: String) -> String:
	for display_name: String in STAT_VAR_MAP:
		for op: String in ["+", "-"]:
			var pattern: String = display_name + " " + op
			if s.begins_with(pattern):
				var num: String = s.substr(pattern.length()).strip_edges()
				return "stat:%s:%s%s" % [str(STAT_VAR_MAP[display_name]), op, num]
	return "SPECIAL:" + s


func _extract_count(s: String) -> int:
	if s.contains("three") or s.contains("3"):
		return 3
	if s.contains("two") or s.contains("2"):
		return 2
	return 1


func _looks_like_dsl(s: String) -> bool:
	if s == "":
		return true
	for part: String in s.split("|"):
		var p: String = part.strip_edges()
		if p == "":
			continue
		if not (p.begins_with("stat:") or p.begins_with("grant:") or p.begins_with("remove:") or
				p.begins_with("on:") or p.begins_with("block:") or p.begins_with("block_and_replace:") or
				p.begins_with("immune:") or p.begins_with("protected:") or
				p.begins_with("susceptible:") or p.begins_with("cost:") or p.begins_with("SPECIAL:")):
			return false
	return true


func _load_critical_successes() -> void:
	var rows := _csv_rows("res://TSVs/Critical Successes.tsv")
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 2:
			continue
		critical_success_options.append({
			"stat": _row_get(row, 0),
			"effect_dsl": _row_get(row, 1),
			"frequency": _row_get(row, 2),
			"formula_stat_required": _row_get(row, 3),
		})


#Public Helpers, Getters
func get_settlement_locations() -> Array:
	var result: Array = []
	for loc: LocationData in locations.values():
		if loc.location_type == "Settlement":
			result.append(loc)
	return result


func expand_heritage_knowledges(heritage: HeritageData) -> Array[String]:
	var result: Array[String] = []
	for token: String in heritage.knowledges:
		if token == "Any":
			result.assign(knowledges.keys())
			return result
		var up: String = token.to_upper()
		if token == up and token.length() > 1 and knowledge_categories.has(up):
			var cat_arr: Array = knowledge_categories[up]
			result.append_array(cat_arr)
		else:
			result.append(token)
	return result


func expand_heritage_tools(heritage: HeritageData) -> Array[String]:
	var result: Array[String] = []
	for token: String in heritage.tools:
		if token == "Any":
			result.assign(tools.keys())
			return result
		var up: String = token.to_upper()
		if token == up and token.length() > 1 and tool_categories.has(up):
			var cat_arr: Array = tool_categories[up]
			result.append_array(cat_arr)
		else:
			result.append(token)
	return result

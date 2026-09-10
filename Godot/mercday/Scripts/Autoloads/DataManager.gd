extends Node

var locations: Dictionary = {}
var ancestries: Dictionary = {}
var bloodlines: Dictionary = {}
var heritages: Dictionary = {}
var starting_lifepaths: Dictionary = {}
var lifepaths_by_category: Dictionary = {}
var items: Dictionary = {}  #raw Items.tsv rows keyed by item name, filled by _load_items()
var traditions: Dictionary = {}
var traits: Dictionary = {}
var knowledges: Dictionary = {}
var tools: Dictionary = {}
var weapons: Dictionary = {}
var weapons_ordinary_melee: Array = []
var weapons_ordinary_ranged: Array[WeaponData] = []
var weapons_common_ranged: Array[WeaponData] = []
var ammo: Dictionary = {}
var ammo_ordinary_common: Array = []
var armor: Dictionary = {}
var armor_ordinary_common: Array = []
var obstacles_pool: Array[ObstacleData] = []
var obstacles_nonbuilding_pool: Array[ObstacleData] = []  # pre-filtered: not building, not ramp
var obstacles_terrain_pool: Array[ObstacleData] = []     # obstacle_type == "Terrain", non-building
var obstacles_scatter_pool: Array[ObstacleData] = []     # non-building, non-terrain, non-ramp
var obstacles_by_type: Dictionary = {}   # String -> Array[ObstacleData]
var obstacles_by_name: Dictionary = {}   # String -> ObstacleData
var building_pool: Array[ObstacleData] = []  # is_building == true
var building_only_pool: Array[ObstacleData] = []  # building_only == true
var areas_pool: Array[Dictionary] = []   # [{name, type, weights:[6 ints]}]
var knowledge_categories: Dictionary = {}
var tool_categories: Dictionary = {}
var stat_definitions: Array[Dictionary] = []
var creature_types: Array[String] = []
var environment_types: Array[String] = []
var type_columns: Dictionary = {}          # Types.tsv header -> Array[String] of that column's values
var critical_success_options: Array = []
var weapon_trait_library: Dictionary = {}   # weapon_name -> Array[TraitData]
var armor_trait_library: Dictionary = {}    # armor_category -> Array[TraitData]
var perk_group_library: Dictionary = {}     #group_key -> Array[TraitData], Perk rows only
var fight_weapon: WeaponData
var makeshift_weapons: Dictionary = {}      # name -> WeaponData template (duplicate before use at runtime)
var npc_templates: Dictionary = {}
var contract_rows: Array[Dictionary] = []
var event_rows: Array[Dictionary] = []

const _NPCTemplateClass = preload("res://Scripts/Resources/NPCTemplate.gd")

func _ready() -> void:
	ConstCircumstances.load_from_tsv("res://TSVs/Circumstances.tsv")
	ConstStates.load_from_tsv("res://TSVs/States.tsv")
	_load_knowledges_and_tools()
	_load_stats()
	_load_locations()
	_load_ancestries()
	_load_heritages()
	_load_lifepaths()
	_load_traditions()
	_load_traits()
	_load_items()
	_load_weapons()
	_load_ammo()
	_load_armor()
	_load_types()
	_seed_derived_perk_groups()
	DataValidator.validate_effect_tokens(traits)
	_load_critical_successes()
	_load_obstacles()
	_load_areas()
	_load_makeshift_weapons()
	_resolve_location_parents()
	_load_npc_templates()
	_load_contracts()
	_load_events()


func _csv_rows(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DataManager: cannot open %s" % path)
		return rows
	var source: String = path.get_file()
	AsciiNormalizer.reset_count()
	var row_index: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		for c: int in range(row.size()):
			row[c] = AsciiNormalizer.normalize(row[c], source, row_index)
		rows.append(row)
		row_index += 1
	file.close()
	AsciiNormalizer.report_file(source)
	return rows


#Reads a TSV into one dictionary per data row, keyed by the header cell text.
func _load_header_rows(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array[PackedStringArray] = _csv_rows(path)
	if rows.size() < 2:
		return out
	var header: Array[String] = []
	for c: int in range(rows[0].size()):
		header.append(_row_get(rows[0], c))
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if _row_get(row, 0) == "":
			continue
		var d: Dictionary = {}
		for c: int in range(header.size()):
			if header[c] == "":
				continue
			if d.has(header[c]):
				push_warning("DataManager: %s duplicate column %s" % [path.get_file(), header[c]])
				continue
			d[header[c]] = _row_get(row, c)
		d["_row"] = i + 1
		out.append(d)
	return out


func _load_contracts() -> void:
	contract_rows = _load_header_rows("res://TSVs/Contracts.tsv")


func _load_events() -> void:
	event_rows = _load_header_rows("res://TSVs/Events.tsv")


#Exact name lookup over areas_pool; empty dictionary when the area is absent.
func get_area_by_name(area_name: String) -> Dictionary:
	for area: Dictionary in areas_pool:
		if String(area.get("name", "")) == area_name:
			return area
	return {}


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


#Typed cell reads: a blank or unparsable cell falls back to the default.
func _cell_int(row: PackedStringArray, idx: int, default_value: int) -> int:
	var raw: String = _row_get(row, idx)
	return int(raw) if raw.is_valid_int() else default_value


func _cell_float(row: PackedStringArray, idx: int, default_value: float) -> float:
	var raw: String = _row_get(row, idx)
	return float(raw) if raw.is_valid_float() else default_value


func _cell_bool(row: PackedStringArray, idx: int) -> bool:
	return _row_get(row, idx).to_upper() == "TRUE"


#Data rows of a sheet: the header is dropped and rows with a blank key cell are skipped.
func _data_rows(path: String, key_col: int) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var rows: Array[PackedStringArray] = _csv_rows(path)
	for i: int in range(1, rows.size()):
		if _row_get(rows[i], key_col) == "":
			continue
		out.append(rows[i])
	return out


func _split_pipe(value: String) -> Array[String]:
	var result: Array[String] = []
	for part: String in value.split("|"):
		var t: String = part.strip_edges()
		if t != "":
			result.append(t)
	return result


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
	for row: PackedStringArray in _data_rows("res://TSVs/Stats.tsv", 0):
		var stat_name: String = _row_get(row, 0)
		stat_definitions.append({
			"stat": stat_name,
			"var_name": stat_name.to_lower().replace(" ", "_"),
			"formula": _row_get(row, 1),
			"round": _row_get(row, 2),
			"type": _row_get(row, 3),
		})
	StatCalculator.invalidate_cache()


func _load_locations() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Locations.tsv", 1):
		var loc_name: String = _row_get(row, 1)
		var loc := LocationData.new()
		loc.location_name = loc_name
		loc.prefix = _row_get(row, 0)
		loc.location_type = _row_get(row, 23)
		loc.environment = _row_get(row, 24)
		loc.demonym = _row_get(row, 20)
		loc.avg_temperature = _parse_temperature(_row_get(row, 11))
		loc.set_meta("temperature_raw", _row_get(row, 11))
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
		a.life_expectancy = _cell_int(row, 5, -1)
		a.max_dexterity = _cell_int(row, 6, 0)
		a.max_vigor = _cell_int(row, 7, 0)
		a.size = 2 if _row_get(row, 8) == "N/A" else _cell_int(row, 8, 0)
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
	for row: PackedStringArray in _data_rows("res://TSVs/Heritages.tsv", 0):
		var name_val: String = _row_get(row, 0)
		var h := HeritageData.new()
		h.heritage_name = name_val
		h.max_cognition = _cell_int(row, 1, 0)
		h.max_wile = _cell_int(row, 2, 0)
		h.circumstances = _split_field(_row_get(row, 3))
		h.knowledges = _split_field(_row_get(row, 4))
		h.tools = _split_field(_row_get(row, 5))
		h.stat_bonus_5pct = _split_field(_row_get(row, 6))
		heritages[name_val] = h


func _load_lifepaths() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Lifepaths.tsv")
	if rows.size() < 2:
		return
	var current: LifepathData = null
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var event_type: String = _row_get(row, 0)
		if event_type == "":
			_add_lifepath_requirement(current, row)
			continue
		var name_val: String = _row_get(row, 1)
		if name_val == "":
			current = null
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
		current = lp
		_add_lifepath_requirement(lp, row)
		if event_type == "Starting":
			starting_lifepaths[name_val] = lp
		else:
			if not lifepaths_by_category.has(event_type):
				lifepaths_by_category[event_type] = []
			var cat_arr: Array = lifepaths_by_category[event_type]
			cat_arr.append(lp)


#Cells 3-5 hold subject, operator and value; a trailing " AND" or " OR" joins the value to the next entry.
func _add_lifepath_requirement(lp: LifepathData, row: PackedStringArray) -> void:
	if lp == null:
		return
	var subject: String = _row_get(row, 3)
	if subject == "":
		return
	var value: String = _row_get(row, 5)
	var conj: String = ""
	if value.ends_with(" AND"):
		conj = "AND"
		value = value.substr(0, value.length() - 4).strip_edges()
	elif value.ends_with(" OR"):
		conj = "OR"
		value = value.substr(0, value.length() - 3).strip_edges()
	lp.requirements.append({"subject": subject, "op": _row_get(row, 4), "value": value, "conj": conj})


func _load_traditions() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Traditions.tsv", 0):
		var name_val: String = _row_get(row, 0)
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
	var headers: Array[String] = []
	for c: int in range(rows[0].size()):
		headers.append(_row_get(rows[0], c).strip_edges())
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var creature: String = _row_get(row, 0)
		var environment: String = _row_get(row, 1)
		if creature != "":
			creature_types.append(creature)
		if environment != "":
			environment_types.append(environment)
		for c: int in range(headers.size()):
			if headers[c] == "":
				continue
			var value: String = _row_get(row, c).strip_edges()
			if value == "":
				continue
			if not type_columns.has(headers[c]):
				type_columns[headers[c]] = []
			(type_columns[headers[c]] as Array).append(value)


func _load_items() -> void:
	#Items stay as raw row dictionaries; ItemData resources are not built here
	for row: PackedStringArray in _data_rows("res://TSVs/Items.tsv", 0):
		var name_val: String = _row_get(row, 0)
		items[name_val] = {
			"item_name": name_val,
			"item_rarity": _row_get(row, 1),
			"item_type": _row_get(row, 2),
		}


func _load_weapons() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Weapons.tsv", 1):
		var weapon_name: String = _row_get(row, 1)
		var w := WeaponData.new()
		w.item_name = weapon_name
		w.item_rarity = _row_get(row, 2)
		w.item_type = "Weapon"
		w.weapon_type = _row_get(row, 0)
		w.weight = _cell_int(row, 3, 0)
		w.cost = _cell_int(row, 4, 0)
		w.damage_formula_1 = _row_get(row, 5)
		w.damage_types_1 = _split_field(_row_get(row, 6))
		w.damage_formula_2 = _row_get(row, 7)
		w.damage_types_2 = _split_field(_row_get(row, 8))
		w.draw = _cell_int(row, 9, 0)
		w.load_time = _cell_int(row, 10, 0)
		w.chamber = _cell_int(row, 11, 0)
		w.range_ranged = _row_get(row, 12)
		w.range_thrown = _row_get(row, 13)
		w.misfire = _cell_int(row, 14, 0)
		w.misc_properties = _split_field(_row_get(row, 15))
		# col 16: Versatile (skip for now)
		# col 17: Effect (skip for now)
		w.weapon_class = _row_get(row, 18)
		w.resonance = _row_get(row, 19)
		w.resonance_requirement = _row_get(row, 20)
		w.symbiosis = _row_get(row, 21)
		w.symbiosis_requirement = _row_get(row, 22)
		w.fuel_type = _row_get(row, 23)
		w.fuel_max = _cell_int(row, 24, 0)
		w.inflict_states = _split_pipe(_row_get(row, 25))
		w.is_ranged = w.range_ranged != ""
		w.is_throwable = w.range_thrown != ""
		w.has_heavy = w.misc_properties.has("Heavy")
		w.has_light = w.misc_properties.has("Light")
		w.has_extend = w.misc_properties.has("Extend")
		w.melee_range = 2 if w.has_extend else 1
		if w.range_ranged != "":
			var rr := w.range_ranged.split("/")
			w.ranged_intended_range = int(rr[0]) if rr.size() > 0 else 0
			w.ranged_extended_range = int(rr[1]) if rr.size() > 1 else w.ranged_intended_range
		if w.range_thrown != "":
			var rt := w.range_thrown.split("/")
			w.thrown_intended_range = int(rt[0]) if rt.size() > 0 else 0
			w.thrown_extended_range = int(rt[1]) if rt.size() > 1 else w.thrown_intended_range
		for dt: String in w.damage_types_1:
			if dt != "Varies" and not ConstDamageTypes.DAMAGE_TYPES.has(dt):
				push_warning("DataManager: unknown damage type '%s' on weapon '%s'" % [dt, weapon_name])
		for dt: String in w.damage_types_2:
			if dt != "Varies" and not ConstDamageTypes.DAMAGE_TYPES.has(dt):
				push_warning("DataManager: unknown damage type '%s' on weapon '%s'" % [dt, weapon_name])
		weapons[weapon_name] = w
		if w.item_rarity == "Ordinary" and w.range_ranged == "":
			weapons_ordinary_melee.append(w)
		if w.item_rarity == "Ordinary" and w.is_ranged:
			weapons_ordinary_ranged.append(w)
		if w.item_rarity == "Common" and w.is_ranged:
			weapons_common_ranged.append(w)
	_create_fight_weapon()


func _create_fight_weapon() -> void:
	var w := WeaponData.new()
	w.item_name = "Fight"
	w.item_type = "Weapon"
	w.weapon_type = "Unarmed"
	w.damage_formula_1 = ""
	w.damage_types_1.assign(["Strike"])
	w.damage_formula_2 = ""
	w.damage_types_2.assign([])
	w.range_ranged = ""
	w.range_thrown = ""
	w.is_ranged = false
	w.is_throwable = false
	w.has_heavy = false
	w.has_light = false
	w.has_extend = false
	w.melee_range = 1
	w.draw = 0
	w.misfire = 0
	w.misc_properties.assign([])
	w.is_virtual = true
	fight_weapon = w


func _load_ammo() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Ammo.tsv", 0):
		var ammo_name: String = _row_get(row, 0)
		var a := AmmoData.new()
		a.item_name = ammo_name
		a.item_rarity = _row_get(row, 9)
		a.item_type = "Ammo"
		a.ammo_type = _row_get(row, 1)
		a.damage_formula_1 = _row_get(row, 2)
		a.damage_types_1 = _split_field(_row_get(row, 3))
		a.damage_formula_2 = _row_get(row, 4)
		a.damage_types_2 = _split_field(_row_get(row, 5))
		a.weight = _cell_int(row, 6, 0)
		a.cost = _cell_int(row, 7, 0)
		a.compatible = _split_field(_row_get(row, 8))
		a.amount = _cell_int(row, 10, 1)
		a.ammo_class = _row_get(row, 11)
		a.effect = _row_get(row, 12)
		a.inflict_states = _split_pipe(_row_get(row, 13))
		ammo[ammo_name] = a
		if a.item_rarity == "Ordinary" or a.item_rarity == "Common":
			ammo_ordinary_common.append(a)


func _load_armor() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Armor.tsv", 0):
		var armor_name: String = _row_get(row, 0)
		var a := ArmorData.new()
		a.item_name = armor_name
		a.item_type = "Armor"
		a.armor_type = _row_get(row, 1)
		a.weight = _cell_int(row, 2, 0)
		a.cost = _cell_int(row, 3, 0)
		a.item_rarity = _row_get(row, 4)
		a.armor_bonus = _cell_int(row, 5, 0)
		a.ep_cost = _cell_int(row, 6, 0)
		a.fatigue = _cell_int(row, 7, 0)
		a.protection = _split_field(_row_get(row, 8))
		# col 9: Damage Formula (ignored for now)
		# col 10: Damage Type (ignored for now)
		a.vigor_requirement = _cell_int(row, 11, 0)
		a.armor_class = _row_get(row, 12)
		var effect_raw: String = _row_get(row, 13)
		for s: String in effect_raw.split("|", false):
			a.special_effects.append(s)
		a.resonance = _row_get(row, 14)
		a.resonance_requirement = _row_get(row, 15)
		a.symbiosis = _row_get(row, 16)
		a.symbiosis_requirement = _row_get(row, 17)
		a.fuel_type = _row_get(row, 18)
		a.fuel_amount = _cell_int(row, 19, 0)
		match a.armor_type:
			"Medium":
				a.halve_swim = true
			"Heavy":
				a.halve_fly = true
				a.cannot_swim = true
			"Bulky":
				a.cannot_fly = true
				a.cannot_swim = true
		armor[armor_name] = a
		if a.item_rarity == "Ordinary" or a.item_rarity == "Common":
			armor_ordinary_common.append(a)


func _load_traits() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Traits.tsv", 3):
		var name_val: String = _row_get(row, 3)
		var trait_data := TraitData.new()
		trait_data.trait_source = _row_get(row, 0)
		trait_data.trait_category = _row_get(row, 1)
		trait_data.trait_type = _row_get(row, 2)
		trait_data.trait_name = name_val
		trait_data.description = _row_get(row, 4)
		trait_data.effect_dsl = EffectDslCompiler.convert_legacy_effect(_row_get(row, 5), "Traits.tsv " + name_val)
		trait_data.rarity = _row_get(row, 6)
		if trait_data.rarity == "":
			trait_data.rarity = "Common"
		trait_data.is_bad = _row_get(row, 7).to_lower() == "true"
		trait_data.logline_a = _row_get(row, 8)
		trait_data.logline_b = _row_get(row, 9)
		if trait_data.trait_type == "Perk":
			for group_raw: String in _row_get(row, 10).split(","):
				var group: String = normalize_perk_group(group_raw)
				if group != "" and not trait_data.perk_groups.has(group):
					trait_data.perk_groups.append(group)
			for group_key: String in trait_data.perk_groups:
				_add_to_perk_group(group_key, trait_data)
		traits[name_val] = trait_data
		if trait_data.trait_source == "Weapon":
			var weapon_name: String = name_val.split("|")[0]
			if not weapon_trait_library.has(weapon_name):
				weapon_trait_library[weapon_name] = []
			(weapon_trait_library[weapon_name] as Array).append(trait_data)
		elif trait_data.trait_source == "Armor":
			var armor_cat: String = trait_data.trait_category
			if not armor_trait_library.has(armor_cat):
				armor_trait_library[armor_cat] = []
			(armor_trait_library[armor_cat] as Array).append(trait_data)


#Sheet spelling and token spelling meet here: trimmed, lower case, spaces and hyphens as underscores.
func normalize_perk_group(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func _add_to_perk_group(group: String, trait_data: TraitData) -> void:
	if group == "" or trait_data == null:
		return
	if not perk_group_library.has(group):
		perk_group_library[group] = []
	var members: Array = perk_group_library[group]
	if not members.has(trait_data):
		members.append(trait_data)


#Weapon Perk rows join melee or ranged from the weapon type they are keyed under unless the sheet tagged them.
func _seed_derived_perk_groups() -> void:
	var ranged_by_type: Dictionary = {}
	for weapon_key: String in weapons.keys():
		var weapon: WeaponData = weapons[weapon_key]
		if weapon == null or weapon.weapon_type == "":
			continue
		var type_key: String = weapon.weapon_type.get_slice(" (", 0).strip_edges()
		ranged_by_type[type_key] = bool(ranged_by_type.get(type_key, false)) or weapon.is_ranged
	for library_key: String in weapon_trait_library.keys():
		if not ranged_by_type.has(library_key):
			continue
		var group: String = "ranged" if bool(ranged_by_type[library_key]) else "melee"
		for entry: Variant in (weapon_trait_library[library_key] as Array):
			var trait_data: TraitData = entry as TraitData
			if trait_data == null or trait_data.trait_type != "Perk":
				continue
			if trait_data.perk_groups.has("melee") or trait_data.perk_groups.has("ranged"):
				continue
			trait_data.perk_groups.append(group)
			_add_to_perk_group(group, trait_data)
	var tagged: int = 0
	for group_key: String in perk_group_library.keys():
		if group_key != "melee" and group_key != "ranged":
			tagged += 1
	print("PERK GROUPS: melee %d, ranged %d, tagged groups %d" % [
		(perk_group_library.get("melee", []) as Array).size(),
		(perk_group_library.get("ranged", []) as Array).size(), tagged])


func _load_obstacles() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Obstacles.tsv", 0):
		var name_val: String = _row_get(row, 0)
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		o.obstacle_type = _row_get(row, 1)
		o.size_x = _cell_float(row, 2, 1.0)
		o.size_y = _cell_float(row, 3, 1.0)
		o.size_z = _cell_float(row, 4, 0.0)
		o.height = o.size_z
		o.narrow = _cell_bool(row, 5)
		o.thd_min = _cell_float(row, 6, 0.0)
		o.thd_max = _cell_float(row, 7, 0.0)
		var moveable_str: String = _row_get(row, 8)
		o.moveable = moveable_str.to_upper() == "TRUE" or moveable_str == "1"
		o.climbable = _cell_bool(row, 9)
		o.climb_difficulty = _row_get(row, 10)
		o.health = _cell_int(row, 11, 1)
		o.susceptible_to = _row_get(row, 12)
		o.rugged = _cell_bool(row, 13)
		o.passthrough = _cell_bool(row, 14)
		o.is_building = _cell_bool(row, 15)
		o.building_only = _cell_bool(row, 16)
		o.is_room = _cell_bool(row, 17)
		o.room_type = _row_get(row, 18)
		o.pt_enter_harm = _cell_int(row, 19, 0)
		o.pt_exit_harm = _cell_int(row, 20, 0)
		o.pt_harm_type = _row_get(row, 21)
		o.growth_pct = _cell_int(row, 22, 0)
		o.ramp = _cell_bool(row, 23)
		o.covers = (_row_get(row, 24).to_lower() != "false") if row.size() > 24 else true
		o.drops = _split_field(_row_get(row, 25))
		o.guaranteed_structures = _split_field(_row_get(row, 26))
		o.possible_structures = _split_field(_row_get(row, 27))
		o.possible_scatter = _split_field(_row_get(row, 28))
		o.preferred_position = _row_get(row, 29)
		o.interactable = _cell_bool(row, 30)
		o.interaction_result = _row_get(row, 31)
		obstacles_pool.append(o)
		obstacles_by_name[o.obstacle_name] = o
		if not obstacles_by_type.has(o.obstacle_type):
			obstacles_by_type[o.obstacle_type] = []
		(obstacles_by_type[o.obstacle_type] as Array).append(o)
		if o.is_building:
			building_pool.append(o)
		if o.building_only:
			building_only_pool.append(o)
		if not o.is_building and not o.ramp and not o.building_only and not o.is_room:
			obstacles_nonbuilding_pool.append(o)
			if o.obstacle_type == "Terrain":
				obstacles_terrain_pool.append(o)
			else:
				obstacles_scatter_pool.append(o)


func _load_makeshift_weapons() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Makeshift Weapons.tsv", 0):
		var name_val: String = _row_get(row, 0)
		var base_type: String = _row_get(row, 1)
		var base: WeaponData = weapons.get(base_type) as WeaponData
		if base == null:
			push_warning("DataManager: makeshift base type '%s' not found for '%s'" % [base_type, name_val])
			continue
		var w := WeaponData.new()
		w.base_weapon = base
		w.item_type = base.item_type
		w.item_rarity = base.item_rarity
		w.weapon_type = base.weapon_type
		w.damage_formula_1 = base.damage_formula_1
		w.damage_formula_2 = base.damage_formula_2
		w.damage_types_1 = base.damage_types_1.duplicate()
		w.damage_types_2 = base.damage_types_2.duplicate()
		w.misc_properties = base.misc_properties.duplicate()
		w.is_ranged = base.is_ranged
		w.is_throwable = base.is_throwable
		w.has_heavy = base.has_heavy
		w.has_light = base.has_light
		w.has_extend = base.has_extend
		w.melee_range = base.melee_range
		w.draw = base.draw
		w.item_name = name_val
		var dmg_types_raw: String = _row_get(row, 2)
		if dmg_types_raw != "":
			w.damage_types_1 = _split_field(dmg_types_raw)
		var thrown_raw: String = _row_get(row, 3)
		if thrown_raw != "" and thrown_raw.to_upper() != "FALSE":
			w.range_thrown = thrown_raw
			w.is_throwable = true
			var rt := thrown_raw.split("/")
			w.thrown_intended_range = int(rt[0]) if rt.size() > 0 else 0
			w.thrown_extended_range = int(rt[1]) if rt.size() > 1 else w.thrown_intended_range
		var extend_raw: String = _row_get(row, 4)
		if extend_raw.to_upper() == "TRUE":
			if not w.misc_properties.has("Extend"):
				w.misc_properties.append("Extend")
			w.has_extend = true
			w.melee_range = 2
		else:
			w.misc_properties.erase("Extend")
			w.has_extend = false
			w.melee_range = 1
		w.fragility = _cell_int(row, 5, 0)
		w.current_fragility = w.fragility
		makeshift_weapons[name_val] = w


func get_random_obstacle() -> ObstacleData:
	if not obstacles_scatter_pool.is_empty():
		return obstacles_scatter_pool[randi() % obstacles_scatter_pool.size()]
	return obstacles_nonbuilding_pool[randi() % obstacles_nonbuilding_pool.size()]


func get_random_area(area_type: String = "Exterior") -> Dictionary:
	var pool: Array = areas_pool.filter(func(a: Dictionary) -> bool: return a.get("type", "") == area_type)
	if pool.is_empty():
		return {"name": "Unknown", "type": "Exterior", "weights": [17, 17, 17, 17, 16, 16]}
	return pool[randi() % pool.size()]


func _load_areas() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Areas.tsv", 0):
		var name_val: String = _row_get(row, 0)
		var area_type: String = _row_get(row, 1)
		var weights: Array[int] = []
		for c: int in range(2, 8):
			var w_str: String = _row_get(row, c).strip_edges().trim_suffix("%")
			weights.append(int(w_str) if w_str.is_valid_int() else 0)
		var furniture_raw: String = _row_get(row, 12)
		var rooms_raw: String = _row_get(row, 14)
		areas_pool.append({
			"name": name_val,
			"type": area_type,
			"weights": weights,
			"f_plus": _cell_int(row, 8, 0),
			"f_minus": _cell_int(row, 9, 0),
			"furniture_list": _split_field(furniture_raw),
			"rooms_list": _split_field(rooms_raw),
			"min_size": _cell_int(row, 19, 18),
			"max_size": _cell_int(row, 20, 45),
		})


func get_obstacle_by_name(obs_name: String) -> ObstacleData:
	return obstacles_by_name.get(obs_name) as ObstacleData


func get_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Interior", true)


func get_exterior_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Exterior", false)


#Rooms of this area whose room_type starts with prefix and whose floor suffix fits floor_num.
#any_floors also accepts the "Any" and "F-" suffixes.
func _rooms_for(area_data: Dictionary, floor_num: int, prefix: String,
		any_floors: bool) -> Array[ObstacleData]:
	var rooms_list: Array = area_data.get("rooms_list", [])
	var result: Array[ObstacleData] = []
	for room_name: String in rooms_list:
		var d: ObstacleData = get_obstacle_by_name(room_name)
		if d == null or not d.is_room:
			continue
		var rt: String = d.room_type
		if not rt.begins_with(prefix):
			continue
		var matches: bool = false
		if any_floors and rt.ends_with("Any") and floor_num >= 0:
			matches = true
		elif rt.ends_with("F0") and floor_num == 0:
			matches = true
		elif rt.ends_with("F+") and floor_num > 0:
			matches = true
		elif any_floors and rt.ends_with("F-") and floor_num < 0:
			matches = true
		if matches:
			result.append(d)
	return result


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


func get_settlement_locations() -> Array:
	var result: Array = []
	for loc: LocationData in locations.values():
		if loc.location_type == "Settlement":
			result.append(loc)
	return result


func _load_npc_templates() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/NPCs.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 13 or _row_get(row, 0).is_empty():
			continue
		var t = _NPCTemplateClass.new()
		t.npc_type = _row_get(row, 0)
		var name_val: String = _row_get(row, 1)
		t.name_mode = name_val if not name_val.is_empty() else "Random"
		t.origin_pool = _split_field(_row_get(row, 2))
		var anc_entries: Array[String] = _split_field(_row_get(row, 3))
		if anc_entries.has("Any"):
			t.ancestry_any = true
		else:
			for entry: String in anc_entries:
				if "(" in entry:
					var parts: PackedStringArray = entry.split("(")
					var aname: String = parts[0].strip_edges()
					var bname: String = parts[1].trim_suffix(")").strip_edges()
					t.ancestry_constraints[aname] = bname
				else:
					t.ancestry_constraints[entry] = ""
		var her_entries: Array[String] = _split_field(_row_get(row, 4))
		if her_entries.has("Any"):
			t.heritage_any = true
		else:
			t.heritage_pool = her_entries
		var trad_entries: Array[String] = _split_field(_row_get(row, 5))
		if trad_entries.has("Any"):
			t.tradition_any = true
		elif trad_entries.has("None"):
			t.tradition_none = true
		else:
			t.tradition_pool = trad_entries
		t.level_formula = _row_get(row, 6)
		t.sle_name = _row_get(row, 7) if not _row_get(row, 7).is_empty() else "None"
		var ele_entries: Array[String] = _split_field(_row_get(row, 8))
		if ele_entries.has("Any"):
			t.ele_any = true
		elif not ele_entries.has("None"):
			t.ele_pool = ele_entries
		t.le_count_str = _row_get(row, 9) if not _row_get(row, 9).is_empty() else "0"
		t.weapon_pool = _split_field(_row_get(row, 10))
		t.armor_pool = _split_field(_row_get(row, 11))
		t.loadout_pool = _split_field(_row_get(row, 12))
		t.passive_tokens = DataValidator.parse_npc_immunities(_row_get(row, 13), t.npc_type)
		npc_templates[t.npc_type] = t


#An all-caps token names a category and expands to its members; "Any" takes every name.
func _expand_tokens(list: Array[String], all_names: Dictionary, categories: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for token: String in list:
		if token == "Any":
			result.assign(all_names.keys())
			return result
		var up: String = token.to_upper()
		if token == up and token.length() > 1 and categories.has(up):
			var cat_arr: Array = categories[up]
			result.append_array(cat_arr)
		else:
			result.append(token)
	return result


func expand_heritage_knowledges(heritage: HeritageData) -> Array[String]:
	return _expand_tokens(heritage.knowledges, knowledges, knowledge_categories)


func expand_heritage_tools(heritage: HeritageData) -> Array[String]:
	return _expand_tokens(heritage.tools, tools, tool_categories)

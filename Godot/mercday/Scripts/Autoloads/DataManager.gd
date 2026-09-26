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
#Weapons.tsv rows that exist only as makeshift bases and must stay out of every loadout pool.
const MAKESHIFT_TEMPLATES: PackedStringArray = ["Basic Makeshift", "Specialized Makeshift", "Great Makeshift"]
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
#Cave features CavernScatter places by name; they must stay out of the open-map scatter pools.
const CAVERN_ONLY_OBSTACLES: PackedStringArray = ["Stalagmite", "Stalactite", "Column"]
#City use tokens of the Obstacles.tsv City column; any other token warns on load.
const CITY_USES: PackedStringArray = ["lamp", "sidewalk", "alley", "square"]
var city_obstacles: Dictionary = {}  # use token -> Array[ObstacleData], sheet row order
var building_pool: Array[ObstacleData] = []  # is_building == true
var building_only_pool: Array[ObstacleData] = []  # building_only == true
var areas_pool: Array[Dictionary] = []   # [{name, type, weights:[6 ints], environments:{env->weight}, row}]
var room_sheet_rows: Dictionary = {}     #room name -> Rooms.tsv sheet row, for validator messages
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
#Level Ups.tsv pool entries: {tier, levels: Array[int], option, weight, description, ordinal}
var level_up_rows: Array[Dictionary] = []

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
	_load_rooms()
	_load_areas()
	_load_buildings()
	MakeshiftTemplates.load_makeshift_weapons()
	_resolve_location_parents()
	_load_npc_templates()
	_load_contracts()
	_load_events()
	_load_level_ups()
	var excluded_words: Array[String] = []
	var excluded_syllables: Array[String] = []
	var pools: Dictionary = {}
	var prefab_pools: Dictionary = {}
	_load_exclusions(excluded_words, excluded_syllables)
	_load_prefab_names(prefab_pools)
	_load_names(pools)
	NameGenerator.install_pools(excluded_words, excluded_syllables, pools, prefab_pools)


func _load_contracts() -> void:
	contract_rows = TsvReader.load_header_rows("res://TSVs/Contracts.tsv")


func _load_events() -> void:
	event_rows = TsvReader.load_header_rows("res://TSVs/Events.tsv")


#One pool entry per row; ordinal separates two rows of the same option inside one tier.
func _load_level_ups() -> void:
	level_up_rows = []
	var counts: Dictionary = {}
	for row: Dictionary in TsvReader.load_header_rows("res://TSVs/Level Ups.tsv"):
		var option: String = str(row.get("Option", "")).strip_edges()
		if option == "":
			continue
		var tier: String = str(row.get("Tier", "")).strip_edges()
		var levels: Array[int] = []
		for part: String in TsvReader.split_field(str(row.get("Levels", ""))):
			if part.is_valid_int():
				levels.append(int(part))
		var raw_weight: String = str(row.get("Weight", "")).strip_edges()
		var weight: float = float(raw_weight) if raw_weight.is_valid_float() else 1.0
		var count_key: String = "%s|%s" % [tier, option]
		var ordinal: int = int(counts.get(count_key, 0)) + 1
		counts[count_key] = ordinal
		level_up_rows.append({
			"tier": tier,
			"levels": levels,
			"option": option,
			"weight": weight,
			"description": str(row.get("Description", "")).strip_edges(),
			"ordinal": ordinal,
		})
	if level_up_rows.is_empty():
		push_warning("DataManager: Level Ups.tsv has no rows")


#Exact name lookup over areas_pool; empty dictionary when the area is absent.
func get_area_by_name(area_name: String) -> Dictionary:
	for area: Dictionary in areas_pool:
		if String(area.get("name", "")) == area_name:
			return area
	return {}


#Typed cell reads: a blank or unparsable cell falls back to the default.
func _cell_int(row: PackedStringArray, idx: int, default_value: int) -> int:
	var raw: String = TsvReader.row_get(row, idx)
	return int(raw) if raw.is_valid_int() else default_value


func _cell_float(row: PackedStringArray, idx: int, default_value: float) -> float:
	var raw: String = TsvReader.row_get(row, idx)
	return float(raw) if raw.is_valid_float() else default_value


func _cell_bool(row: PackedStringArray, idx: int) -> bool:
	return TsvReader.row_get(row, idx).to_upper() == "TRUE"


#Data rows of a sheet: the header is dropped and rows with a blank key cell are skipped.
func _data_rows(path: String, key_col: int) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(path)
	for i: int in range(1, rows.size()):
		if TsvReader.row_get(rows[i], key_col) == "":
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
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Knowledges and Tools.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		_load_utility_row(row, 0, "Knowledge", knowledges, knowledge_categories)
		_load_utility_row(row, 4, "Tool", tools, tool_categories)


#One half of a Knowledges and Tools.tsv row: name, use, category and rarity from base_col onward.
func _load_utility_row(row: PackedStringArray, base_col: int, utility_type: String,
		target: Dictionary, categories: Dictionary) -> void:
	var name_val: String = TsvReader.row_get(row, base_col)
	if name_val == "":
		return
	var u := UtilityTraitData.new()
	u.utility_type = utility_type
	u.utility_name = name_val
	u.utility_use = TsvReader.row_get(row, base_col + 1)
	u.utility_category = TsvReader.row_get(row, base_col + 2)
	u.utility_rarity = TsvReader.row_get(row, base_col + 3)
	target[name_val] = u
	var cat_key: String = u.utility_category.to_upper()
	if cat_key == "":
		return
	if not categories.has(cat_key):
		categories[cat_key] = []
	(categories[cat_key] as Array).append(name_val)


func _load_stats() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Stats.tsv", 0):
		var stat_name: String = TsvReader.row_get(row, 0)
		stat_definitions.append({
			"stat": stat_name,
			"var_name": stat_name.to_lower().replace(" ", "_"),
			"formula": TsvReader.row_get(row, 1),
			"round": TsvReader.row_get(row, 2),
			"type": TsvReader.row_get(row, 3),
		})
	StatCalculator.invalidate_cache()


func _load_locations() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Locations.tsv", 1):
		var loc_name: String = TsvReader.row_get(row, 1)
		var loc := LocationData.new()
		loc.location_name = loc_name
		loc.prefix = TsvReader.row_get(row, 0)
		loc.location_type = TsvReader.row_get(row, 23)
		loc.environment = TsvReader.row_get(row, 24)
		loc.demonym = TsvReader.row_get(row, 20)
		loc.avg_temperature = _parse_temperature(TsvReader.row_get(row, 11))
		loc.set_meta("temperature_raw", TsvReader.row_get(row, 11))
		_add_to_buff_dict(loc.knowledge_buffs, TsvReader.row_get(row, 2), 5.0)
		_add_to_buff_dict(loc.knowledge_buffs, TsvReader.row_get(row, 3), 3.0)
		_add_to_buff_dict(loc.knowledge_buffs, TsvReader.row_get(row, 4), 1.0)
		_add_to_buff_dict(loc.tool_buffs, TsvReader.row_get(row, 5), 4.0)
		_add_to_buff_dict(loc.tool_buffs, TsvReader.row_get(row, 6), 2.0)
		_add_to_buff_dict(loc.tool_buffs, TsvReader.row_get(row, 7), 1.0)
		_add_to_buff_dict(loc.circumstance_buffs, TsvReader.row_get(row, 8), 5.0)
		_add_to_buff_dict(loc.circumstance_buffs, TsvReader.row_get(row, 9), 3.0)
		_add_to_buff_dict(loc.circumstance_buffs, TsvReader.row_get(row, 10), 1.0)
		_add_to_buff_dict(loc.ancestry_buffs, TsvReader.row_get(row, 12), 5.0)
		_add_to_buff_dict(loc.ancestry_buffs, TsvReader.row_get(row, 13), 2.0)
		_add_to_buff_dict(loc.bloodline_buffs, TsvReader.row_get(row, 14), 5.0)
		_add_to_buff_dict(loc.bloodline_buffs, TsvReader.row_get(row, 15), 2.0)
		_add_to_buff_dict(loc.heritage_buffs, TsvReader.row_get(row, 16), 5.0)
		_add_to_buff_dict(loc.heritage_buffs, TsvReader.row_get(row, 17), 2.0)
		_add_to_buff_dict(loc.ancestry_debuffs, TsvReader.row_get(row, 18), 7.0)
		_add_to_buff_dict(loc.ancestry_debuffs, TsvReader.row_get(row, 19), 4.0)
		loc.set_meta("parent_area", TsvReader.row_get(row, 21))
		loc.set_meta("subparent_area", TsvReader.row_get(row, 22))
		locations[loc_name] = loc


func _add_to_buff_dict(d: Dictionary, names_csv: String, pct: float) -> void:
	for buff_name: String in TsvReader.split_field(names_csv):
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
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Ancestries.tsv")
	if rows.size() < 2:
		return
	var past_separator: bool = false
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = TsvReader.row_get(row, 0)
		if name_val == "":
			past_separator = true
			continue
		var a := AncestryData.new()
		a.ancestry_name = name_val
		a.ancestry_category = "Bloodline" if past_separator else "Ancestry"
		a.possible_bloodlines = TsvReader.split_field(TsvReader.row_get(row, 1))
		a.rarity = TsvReader.row_get(row, 2)
		if a.rarity == "":
			a.rarity = "Common"
		a.perks = TsvReader.split_field(TsvReader.row_get(row, 3))
		a.drawbacks = TsvReader.split_field(TsvReader.row_get(row, 4))
		a.life_expectancy = _cell_int(row, 5, -1)
		a.max_dexterity = _cell_int(row, 6, 0)
		a.max_vigor = _cell_int(row, 7, 0)
		a.size = 2 if TsvReader.row_get(row, 8) == "N/A" else _cell_int(row, 8, 0)
		a.types = TsvReader.split_field(TsvReader.row_get(row, 9))
		a.hybrid_options = TsvReader.row_get(row, 10)
		a.knowledge_odds_x20 = TsvReader.split_field(TsvReader.row_get(row, 11))
		a.tool_odds_x20 = TsvReader.split_field(TsvReader.row_get(row, 12))
		a.circumstance_odds_x20 = TsvReader.split_field(TsvReader.row_get(row, 13))
		a.stat_bonus_5pct = TsvReader.split_field(TsvReader.row_get(row, 14))
		if past_separator:
			bloodlines[name_val] = a
		else:
			ancestries[name_val] = a


func _load_heritages() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Heritages.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var h := HeritageData.new()
		h.heritage_name = name_val
		h.max_cognition = _cell_int(row, 1, 0)
		h.max_wile = _cell_int(row, 2, 0)
		h.circumstances = TsvReader.split_field(TsvReader.row_get(row, 3))
		h.knowledges = TsvReader.split_field(TsvReader.row_get(row, 4))
		h.tools = TsvReader.split_field(TsvReader.row_get(row, 5))
		h.stat_bonus_5pct = TsvReader.split_field(TsvReader.row_get(row, 6))
		heritages[name_val] = h


func _load_lifepaths() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Lifepaths.tsv")
	if rows.size() < 2:
		return
	var current: LifepathData = null
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var event_type: String = TsvReader.row_get(row, 0)
		if event_type == "":
			_add_lifepath_requirement(current, row)
			continue
		var name_val: String = TsvReader.row_get(row, 1)
		if name_val == "":
			current = null
			continue
		var lp := LifepathData.new()
		lp.event_type = event_type
		lp.event_name = name_val
		lp.description = TsvReader.row_get(row, 2)
		lp.drawbacks = TsvReader.split_field(TsvReader.row_get(row, 6))
		lp.perks = TsvReader.split_field(TsvReader.row_get(row, 7))
		lp.rarity = TsvReader.row_get(row, 8)
		if lp.rarity == "":
			lp.rarity = "Common"
		lp.stat_bonus_5pct = TsvReader.split_field(TsvReader.row_get(row, 10))
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
	var subject: String = TsvReader.row_get(row, 3)
	if subject == "":
		return
	var value: String = TsvReader.row_get(row, 5)
	var conj: String = ""
	if value.ends_with(" AND"):
		conj = "AND"
		value = value.substr(0, value.length() - 4).strip_edges()
	elif value.ends_with(" OR"):
		conj = "OR"
		value = value.substr(0, value.length() - 3).strip_edges()
	lp.requirements.append({"subject": subject, "op": TsvReader.row_get(row, 4), "value": value, "conj": conj})


func _load_traditions() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Traditions.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var t := TraditionData.new()
		t.tradition_name = name_val
		t.stat_boost_15 = TsvReader.row_get(row, 2)
		t.stat_boost_10 = TsvReader.row_get(row, 3)
		t.stat_boost_5 = TsvReader.split_field(TsvReader.row_get(row, 4))
		t.circumstance_boost = TsvReader.row_get(row, 5)
		t.weight_plus_25 = TsvReader.row_get(row, 6)
		t.weight_plus_10 = TsvReader.row_get(row, 7)
		t.weight_minus_25 = TsvReader.row_get(row, 8)
		t.weight_minus_5 = TsvReader.row_get(row, 9)
		traditions[name_val] = t


func _load_types() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Types.tsv")
	if rows.size() < 2:
		return
	var headers: Array[String] = []
	for c: int in range(rows[0].size()):
		headers.append(TsvReader.row_get(rows[0], c).strip_edges())
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var creature: String = TsvReader.row_get(row, 0)
		var environment: String = TsvReader.row_get(row, 2)
		if creature != "":
			creature_types.append(creature)
		if environment != "":
			environment_types.append(environment)
		for c: int in range(headers.size()):
			if headers[c] == "":
				continue
			var value: String = TsvReader.row_get(row, c).strip_edges()
			if value == "":
				continue
			if not type_columns.has(headers[c]):
				type_columns[headers[c]] = []
			(type_columns[headers[c]] as Array).append(value)


func _load_items() -> void:
	#Items stay as raw row dictionaries; ItemData resources are not built here
	for row: PackedStringArray in _data_rows("res://TSVs/Items.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		items[name_val] = {
			"item_name": name_val,
			"item_rarity": TsvReader.row_get(row, 1),
			"item_type": TsvReader.row_get(row, 2),
		}


func _load_weapons() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Weapons.tsv", 1):
		var weapon_name: String = TsvReader.row_get(row, 1)
		var w := WeaponData.new()
		w.item_name = weapon_name
		w.item_rarity = TsvReader.row_get(row, 2)
		w.item_type = "Weapon"
		w.weapon_type = TsvReader.row_get(row, 0)
		w.weight = _cell_int(row, 3, 0)
		w.cost = _cell_int(row, 4, 0)
		w.damage_formula_1 = TsvReader.row_get(row, 5)
		w.damage_types_1 = TsvReader.split_field(TsvReader.row_get(row, 6))
		w.damage_formula_2 = TsvReader.row_get(row, 7)
		w.damage_types_2 = TsvReader.split_field(TsvReader.row_get(row, 8))
		w.draw = _cell_int(row, 9, 0)
		w.load_time = _cell_int(row, 10, 0)
		w.chamber = _cell_int(row, 11, 0)
		w.range_ranged = TsvReader.row_get(row, 12)
		w.range_thrown = TsvReader.row_get(row, 13)
		w.misfire = _cell_int(row, 14, 0)
		w.misc_properties = TsvReader.split_field(TsvReader.row_get(row, 15))
		# col 16: Versatile (skip for now)
		# col 17: Effect (skip for now)
		w.weapon_class = TsvReader.row_get(row, 18)
		w.resonance = TsvReader.row_get(row, 19)
		w.resonance_requirement = TsvReader.row_get(row, 20)
		w.symbiosis = TsvReader.row_get(row, 21)
		w.symbiosis_requirement = TsvReader.row_get(row, 22)
		w.fuel_type = TsvReader.row_get(row, 23)
		w.fuel_max = _cell_int(row, 24, 0)
		w.inflict_states = _split_pipe(TsvReader.row_get(row, 25))
		w.is_ranged = w.range_ranged != ""
		w.is_throwable = w.range_thrown != ""
		w.has_heavy = w.misc_properties.has("Heavy")
		w.has_light = w.misc_properties.has("Light")
		w.has_extend = w.misc_properties.has("Extend")
		w.melee_range = 2 if w.has_extend else 1
		if w.range_ranged != "":
			var rr: Array[int] = _parse_range(w.range_ranged)
			w.ranged_intended_range = rr[0]
			w.ranged_extended_range = rr[1]
		if w.range_thrown != "":
			var rt: Array[int] = _parse_range(w.range_thrown)
			w.thrown_intended_range = rt[0]
			w.thrown_extended_range = rt[1]
		for types: Array in [w.damage_types_1, w.damage_types_2]:
			for dt: String in types:
				if dt != "Varies" and not ConstDamageTypes.DAMAGE_TYPES.has(dt):
					push_warning("DataManager: unknown damage type '%s' on weapon '%s'" % [dt, weapon_name])
		weapons[weapon_name] = w
		#The three makeshift templates only seed Makeshift Weapons.tsv; they are never carried gear.
		if MAKESHIFT_TEMPLATES.has(weapon_name):
			continue
		if w.item_rarity == "Ordinary" and w.range_ranged == "":
			weapons_ordinary_melee.append(w)
		if w.item_rarity == "Ordinary" and w.is_ranged:
			weapons_ordinary_ranged.append(w)
		if w.item_rarity == "Common" and w.is_ranged:
			weapons_common_ranged.append(w)
	_create_fight_weapon()


#Splits an "intended/extended" range cell; the extended value falls back to the intended one.
func _parse_range(text: String) -> Array[int]:
	var parts: PackedStringArray = text.split("/")
	var intended: int = int(parts[0]) if parts.size() > 0 else 0
	var extended: int = int(parts[1]) if parts.size() > 1 else intended
	var out: Array[int] = [intended, extended]
	return out


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
		var ammo_name: String = TsvReader.row_get(row, 0)
		var a := AmmoData.new()
		a.item_name = ammo_name
		a.item_rarity = TsvReader.row_get(row, 9)
		a.item_type = "Ammo"
		a.ammo_type = TsvReader.row_get(row, 1)
		a.damage_formula_1 = TsvReader.row_get(row, 2)
		a.damage_types_1 = TsvReader.split_field(TsvReader.row_get(row, 3))
		a.damage_formula_2 = TsvReader.row_get(row, 4)
		a.damage_types_2 = TsvReader.split_field(TsvReader.row_get(row, 5))
		a.weight = _cell_int(row, 6, 0)
		a.cost = _cell_int(row, 7, 0)
		a.compatible = TsvReader.split_field(TsvReader.row_get(row, 8))
		a.amount = _cell_int(row, 10, 1)
		a.ammo_class = TsvReader.row_get(row, 11)
		a.effect = TsvReader.row_get(row, 12)
		a.inflict_states = _split_pipe(TsvReader.row_get(row, 13))
		ammo[ammo_name] = a
		#Magical ammo is a found reward, so it stays out of the pool ordinary loadouts draw from.
		if a.ammo_class == "Magical":
			continue
		if a.item_rarity == "Ordinary" or a.item_rarity == "Common":
			ammo_ordinary_common.append(a)


func _load_armor() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Armor.tsv", 0):
		var armor_name: String = TsvReader.row_get(row, 0)
		var a := ArmorData.new()
		a.item_name = armor_name
		a.item_type = "Armor"
		a.armor_type = TsvReader.row_get(row, 1)
		a.weight = _cell_int(row, 2, 0)
		a.cost = _cell_int(row, 3, 0)
		a.item_rarity = TsvReader.row_get(row, 4)
		a.armor_bonus = _cell_int(row, 5, 0)
		a.ep_cost = _cell_int(row, 6, 0)
		a.fatigue = _cell_int(row, 7, 0)
		a.protection = TsvReader.split_field(TsvReader.row_get(row, 8))
		# col 9: Damage Formula (ignored for now)
		# col 10: Damage Type (ignored for now)
		a.vigor_requirement = _cell_int(row, 11, 0)
		a.armor_class = TsvReader.row_get(row, 12)
		var effect_raw: String = TsvReader.row_get(row, 13)
		for s: String in effect_raw.split("|", false):
			a.special_effects.append(s)
		a.resonance = TsvReader.row_get(row, 14)
		a.resonance_requirement = TsvReader.row_get(row, 15)
		a.symbiosis = TsvReader.row_get(row, 16)
		a.symbiosis_requirement = TsvReader.row_get(row, 17)
		a.fuel_type = TsvReader.row_get(row, 18)
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
		var name_val: String = TsvReader.row_get(row, 3)
		var trait_data := TraitData.new()
		trait_data.trait_source = TsvReader.row_get(row, 0)
		trait_data.trait_category = TsvReader.row_get(row, 1)
		trait_data.trait_type = TsvReader.row_get(row, 2)
		trait_data.trait_name = name_val
		trait_data.description = TsvReader.row_get(row, 4)
		trait_data.effect_dsl = EffectDslCompiler.convert_legacy_effect(TsvReader.row_get(row, 5), "Traits.tsv " + name_val)
		trait_data.rarity = TsvReader.row_get(row, 6)
		if trait_data.rarity == "":
			trait_data.rarity = "Common"
		trait_data.is_bad = TsvReader.row_get(row, 7).to_lower() == "true"
		trait_data.logline_a = TsvReader.row_get(row, 8)
		trait_data.logline_b = TsvReader.row_get(row, 9)
		if trait_data.trait_type == "Perk":
			for group_raw: String in TsvReader.row_get(row, 10).split(","):
				var group: String = normalize_perk_group(group_raw)
				if group != "" and not trait_data.perk_groups.has(group):
					trait_data.perk_groups.append(group)
			for group_key: String in trait_data.perk_groups:
				_add_to_perk_group(group_key, trait_data)
		traits[name_val] = trait_data
		if trait_data.trait_source == "Weapon":
			var weapon_name: String = name_val.split("|")[0]
			trait_data.gear_key = weapon_name
			if not weapon_trait_library.has(weapon_name):
				weapon_trait_library[weapon_name] = []
			(weapon_trait_library[weapon_name] as Array).append(trait_data)
		elif trait_data.trait_source == "Armor":
			var armor_cat: String = trait_data.trait_category
			trait_data.gear_key = armor_cat
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


func _load_obstacles() -> void:
	for row: PackedStringArray in _data_rows("res://TSVs/Obstacles.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		o.obstacle_type = TsvReader.row_get(row, 1)
		o.size_x = _cell_float(row, 2, 1.0)
		o.size_y = _cell_float(row, 3, 1.0)
		o.size_z = _cell_float(row, 4, 0.0)
		o.height = o.size_z
		o.narrow = _cell_bool(row, 5)
		o.thd_min = _cell_float(row, 6, 0.0)
		o.thd_max = _cell_float(row, 7, 0.0)
		var moveable_str: String = TsvReader.row_get(row, 8)
		o.moveable = moveable_str.to_upper() == "TRUE" or moveable_str == "1"
		o.climbable = _cell_bool(row, 9)
		o.climb_difficulty = TsvReader.row_get(row, 10)
		o.health = _cell_int(row, 11, 1)
		o.susceptible_to = TsvReader.row_get(row, 12)
		o.immune_to = TsvReader.row_get(row, 32)
		o.rugged = _cell_bool(row, 13)
		o.passthrough = _cell_bool(row, 14)
		o.is_building = _cell_bool(row, 15)
		o.building_only = _cell_bool(row, 16)
		o.is_room = _cell_bool(row, 17)
		o.room_type = TsvReader.row_get(row, 18)
		o.pt_enter_harm = _cell_int(row, 19, 0)
		o.pt_exit_harm = _cell_int(row, 20, 0)
		o.pt_harm_type = TsvReader.row_get(row, 21)
		o.growth_pct = _cell_int(row, 22, 0)
		o.ramp = _cell_bool(row, 23)
		o.covers = (TsvReader.row_get(row, 24).to_lower() != "false") if row.size() > 24 else true
		o.drops = TsvReader.split_field(TsvReader.row_get(row, 25))
		o.guaranteed_structures = TsvReader.split_field(TsvReader.row_get(row, 26))
		o.possible_structures = TsvReader.split_field(TsvReader.row_get(row, 27))
		o.possible_scatter = TsvReader.split_field(TsvReader.row_get(row, 28))
		o.preferred_position = TsvReader.row_get(row, 29)
		o.interactable = _cell_bool(row, 30)
		o.interaction_result = TsvReader.row_get(row, 31)
		for token: String in TsvReader.split_field(TsvReader.row_get(row, 33)):
			var use: String = token.to_lower()
			if use == "only":
				o.city_only = true
				continue
			if not CITY_USES.has(use):
				push_warning("DataManager: Obstacles.tsv row '%s' has unknown City token '%s'"
					% [o.obstacle_name, token])
				continue
			if o.city_uses.has(use):
				continue
			o.city_uses.append(use)
			if not city_obstacles.has(use):
				var list: Array[ObstacleData] = []
				city_obstacles[use] = list
			(city_obstacles[use] as Array).append(o)
		var sight_val: String = TsvReader.row_get(row, 34)
		if sight_val != "":
			if sight_val.to_lower() == "cover":
				o.sight_cover = true
			else:
				push_warning("DataManager: Obstacles.tsv row '%s' has unknown Sight value '%s'"
					% [o.obstacle_name, sight_val])
		_register_obstacle(o)
		if o.is_building:
			building_pool.append(o)
		if o.building_only:
			building_only_pool.append(o)
		if not o.is_building and not o.ramp and not o.building_only and not o.is_room \
				and not CAVERN_ONLY_OBSTACLES.has(o.obstacle_name) \
				and not o.city_only:
			obstacles_nonbuilding_pool.append(o)
			if o.obstacle_type == "Terrain":
				obstacles_terrain_pool.append(o)
			else:
				obstacles_scatter_pool.append(o)


#Rooms.tsv rows become room ObstacleData entries registered beside the Obstacles.tsv rows.
func _load_rooms() -> void:
	var sheet_row: int = 1
	for row: PackedStringArray in _data_rows("res://TSVs/Rooms.tsv", 0):
		sheet_row += 1
		var name_val: String = TsvReader.row_get(row, 0)
		if obstacles_by_name.has(name_val):
			push_warning("DataManager: Rooms.tsv room '%s' already exists" % name_val)
			continue
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		o.obstacle_type = "Structure"
		o.size_x = _cell_float(row, 1, 1.0)
		o.size_y = _cell_float(row, 2, 1.0)
		o.size_z = 0.0
		o.height = 0.0
		o.health = 1
		o.is_room = true
		o.room_type = TsvReader.row_get(row, 3)
		o.covers = false
		o.growth_pct = _cell_int(row, 7, 0)
		o.guaranteed_structures = TsvReader.split_field(TsvReader.row_get(row, 4))
		o.possible_structures = TsvReader.split_field(TsvReader.row_get(row, 5))
		o.possible_scatter = TsvReader.split_field(TsvReader.row_get(row, 6))
		_register_obstacle(o)
		room_sheet_rows[o.obstacle_name] = sheet_row


#Adds a loaded obstacle to the shared pool, the by-name map and its type bucket.
func _register_obstacle(o: ObstacleData) -> void:
	obstacles_pool.append(o)
	obstacles_by_name[o.obstacle_name] = o
	if not obstacles_by_type.has(o.obstacle_type):
		obstacles_by_type[o.obstacle_type] = []
	(obstacles_by_type[o.obstacle_type] as Array).append(o)


#Buildings.tsv rows join areas_pool as Interior areas carrying a "building" rule Dictionary.
func _load_buildings() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Buildings.tsv")
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = TsvReader.row_get(row, 0)
		if name_val == "":
			continue
		if not get_area_by_name(name_val).is_empty():
			push_warning("DataManager: Buildings.tsv area '%s' already exists" % name_val)
			continue
		var layout_f0: String = TsvReader.row_get(row, 6)
		var shell: String = TsvReader.row_get(row, 8)
		var windows: Dictionary = _windows_cell(TsvReader.row_get(row, 11))
		var width: Vector2i = _range_cell(TsvReader.row_get(row, 2))
		var depth: Vector2i = _range_cell(TsvReader.row_get(row, 3))
		var f_plus: Vector2i = _range_cell(TsvReader.row_get(row, 4))
		var f_minus: Vector2i = _range_cell(TsvReader.row_get(row, 5))
		var main_room: String = TsvReader.row_get(row, 12)
		var required_rooms: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 13))
		var other_rooms: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 14))
		var roof: String = TsvReader.row_get(row, 16)
		if roof == "":
			roof = "Flat"
		var roof_objects: Array = _roof_objects_cell(TsvReader.row_get(row, 17), name_val)
		var legacy: bool = layout_f0 == ""
		var rooms_list: Array[String] = other_rooms.duplicate()
		var min_size: int = width.x
		var max_size: int = width.y
		if not legacy:
			var main_list: Array[String] = []
			if main_room != "":
				main_list.append(main_room)
			rooms_list = _dedup_names(main_list, required_rooms, other_rooms)
			min_size = mini(width.x, depth.x)
			max_size = maxi(width.y, depth.y)
		areas_pool.append({
			"name": name_val,
			"type": "Interior",
			"weights": [0, 0, 0, 0, 0, 0],
			"f_plus": f_plus.y,
			"f_minus": f_minus.y,
			"furniture_list": [],
			"rooms_list": rooms_list,
			"min_size": min_size,
			"max_size": max_size,
			"environments": _environment_weights(TsvReader.row_get(row, 15)),
			"row": i + 1,
			"building": {
				"legacy": legacy,
				"size_class": TsvReader.row_get(row, 1),
				"width": width,
				"depth": depth,
				"f_plus": f_plus,
				"f_minus": f_minus,
				"layout_f0": layout_f0,
				"layout_other": TsvReader.row_get(row, 7),
				"shell": shell if shell != "" else "Walled",
				"wings": _range_cell(TsvReader.row_get(row, 9)),
				"entrances": _range_cell(TsvReader.row_get(row, 10)),
				"windows": String(windows["level"]),
				"window_rooms": windows["rooms"],
				"main_room": main_room,
				"required_rooms": required_rooms,
				"other_rooms": other_rooms,
				"roof": roof,
				"roof_objects": roof_objects,
			},
		})


#Roof Objects cell: comma separated tokens, each "Name" or "Name xN"; unknown names are dropped.
func _roof_objects_cell(text: String, row_name: String) -> Array:
	var out: Array = []
	for raw: String in text.split(",", false):
		var token: String = raw.strip_edges()
		if token == "":
			continue
		var count: int = 1
		var name_part: String = token
		var cut: int = token.rfind(" x")
		if cut > 0:
			var tail: String = token.substr(cut + 2).strip_edges()
			if tail.is_valid_int():
				count = maxi(1, tail.to_int())
				name_part = token.substr(0, cut).strip_edges()
		if not RoofBuilder.OBJECTS.has(name_part):
			push_warning("DataManager: Buildings.tsv row '%s' unknown roof object '%s'" % [row_name, name_part])
			continue
		out.append({"name": name_part, "count": count})
	return out


#The three name lists joined in order, each name kept once.
func _dedup_names(first: Array[String], second: Array[String], third: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var joined: Array[String] = first.duplicate()
	joined.append_array(second)
	joined.append_array(third)
	for entry: String in joined:
		if entry == "" or seen.has(entry):
			continue
		seen[entry] = true
		out.append(entry)
	return out


#"5 to 8" -> (5,8); "7" -> (7,7); blank -> (0,0); a low end above the high end swaps.
func _range_cell(cell: String) -> Vector2i:
	var text: String = cell.strip_edges()
	if text == "":
		return Vector2i.ZERO
	if text.is_valid_int():
		return Vector2i(int(text), int(text))
	var parts: PackedStringArray = text.split(" to ", false)
	if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
		var lo: int = int(parts[0].strip_edges())
		var hi: int = int(parts[1].strip_edges())
		return Vector2i(mini(lo, hi), maxi(lo, hi))
	push_warning("DataManager: Buildings.tsv bad range cell '%s'" % cell)
	return Vector2i.ZERO


#"Few, Lookout Many" -> {"level": "Few", "rooms": {"Lookout": "Many"}}; a blank cell means Normal.
func _windows_cell(cell: String) -> Dictionary:
	var out: Dictionary = {"level": "Normal", "rooms": {}}
	var entries: Array[String] = TsvReader.split_field(cell)
	if entries.is_empty():
		return out
	out["level"] = entries[0]
	for i: int in range(1, entries.size()):
		var parts: PackedStringArray = entries[i].split(" ", false)
		if parts.size() < 2:
			continue
		var level: String = parts[parts.size() - 1]
		parts.remove_at(parts.size() - 1)
		var room_name: String = " ".join(parts).strip_edges()
		if room_name != "":
			(out["rooms"] as Dictionary)[room_name] = level
	return out


#Names of every areas_pool entry built from Buildings.tsv, in file order.
func get_building_names() -> Array[String]:
	var out: Array[String] = []
	for area: Dictionary in areas_pool:
		if area.has("building"):
			out.append(String(area.get("name", "")))
	return out


func get_random_obstacle() -> ObstacleData:
	if not obstacles_scatter_pool.is_empty():
		return obstacles_scatter_pool[randi() % obstacles_scatter_pool.size()]
	return obstacles_nonbuilding_pool[randi() % obstacles_nonbuilding_pool.size()]


#An Interior battle map never draws a Small building.
func get_random_area(area_type: String = "Exterior") -> Dictionary:
	var pool: Array = areas_pool.filter(func(a: Dictionary) -> bool: return a.get("type", "") == area_type)
	if area_type == "Interior":
		var kept: Array = []
		for entry: Dictionary in pool:
			var b: Dictionary = entry.get("building", {})
			if String(b.get("size_class", "")) != "Small":
				kept.append(entry)
		pool = kept
	if pool.is_empty():
		return {"name": "Unknown", "type": "Exterior", "weights": [17, 17, 17, 17, 16, 16]}
	return pool[randi() % pool.size()]


func _load_areas() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Areas.tsv")
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = TsvReader.row_get(row, 0)
		if name_val == "":
			continue
		var area_type: String = TsvReader.row_get(row, 1)
		var weights: Array[int] = []
		for c: int in range(2, 8):
			var w_str: String = TsvReader.row_get(row, c).strip_edges().trim_suffix("%")
			weights.append(int(w_str) if w_str.is_valid_int() else 0)
		var furniture_raw: String = TsvReader.row_get(row, 12)
		var rooms_raw: String = TsvReader.row_get(row, 14)
		areas_pool.append({
			"name": name_val,
			"type": area_type,
			"weights": weights,
			"f_plus": _cell_int(row, 8, 0),
			"f_minus": _cell_int(row, 9, 0),
			"furniture_list": TsvReader.split_field(furniture_raw),
			"rooms_list": TsvReader.split_field(rooms_raw),
			"vegetation_list": TsvReader.split_field(TsvReader.row_get(row, 11)),
			"structures_list": TsvReader.split_field(TsvReader.row_get(row, 13)),
			"vegetation_amt": TsvReader.row_get(row, 16),
			"min_size": _cell_int(row, 19, 18),
			"max_size": _cell_int(row, 20, 45),
			"environments": _environment_weights(TsvReader.row_get(row, 21)),
			"row": i + 1,
		})


#Environments cell entries are "<name> <weight>"; a missing weight is 100.
func _environment_weights(cell: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: String in TsvReader.split_field(cell):
		var parts: PackedStringArray = entry.split(" ", false)
		if parts.is_empty():
			continue
		var weight: int = 100
		if parts[parts.size() - 1].is_valid_int():
			weight = maxi(0, int(parts[parts.size() - 1]))
			parts.remove_at(parts.size() - 1)
		var key: String = " ".join(parts).strip_edges().to_lower()
		if key == "":
			continue
		out[key] = weight
	return out


func get_obstacle_by_name(obs_name: String) -> ObstacleData:
	return obstacles_by_name.get(obs_name) as ObstacleData


#Rows whose City cell names the use (lamp, sidewalk, alley, square), in sheet order.
func get_city_obstacles(use: String) -> Array[ObstacleData]:
	var out: Array[ObstacleData] = []
	for o: ObstacleData in (city_obstacles.get(use.to_lower(), []) as Array):
		out.append(o)
	return out


func get_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Interior", true)


func get_exterior_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Exterior", false)


#Dungeon rooms of this area: "Dungeon Any" on every floor, "Dungeon F0" on 0, "Dungeon F-" below 0.
func get_dungeon_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	var rooms_list: Array = area_data.get("rooms_list", [])
	var result: Array[ObstacleData] = []
	for room_name: String in rooms_list:
		var d: ObstacleData = get_obstacle_by_name(room_name)
		if d == null or not d.is_room or not d.room_type.begins_with("Dungeon"):
			continue
		var rt: String = d.room_type
		if rt.ends_with("Any") \
				or (rt.ends_with("F0") and floor_num == 0) \
				or (rt.ends_with("F-") and floor_num < 0):
			result.append(d)
	return result


#Rooms of this area whose room_type starts with prefix and whose floor suffix fits floor_num.
#any_floors also accepts the "Any" and "F-" suffixes. "Top" needs a top_floor of 1 or more.
func _rooms_for(area_data: Dictionary, floor_num: int, prefix: String,
		any_floors: bool) -> Array[ObstacleData]:
	var rooms_list: Array = area_data.get("rooms_list", [])
	var top_floor: int = int(area_data.get("top_floor", -999))
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
		elif rt.ends_with("Top") and top_floor >= 1 and floor_num == top_floor:
			matches = true
		if matches:
			result.append(d)
	return result


#once_key locks a Once reward. Repeated rows get a "#n" tail so each row is earned separately.
func _load_critical_successes() -> void:
	var rows := TsvReader.load_tsv("res://TSVs/Critical Successes.tsv")
	var totals: Dictionary = {}
	for i: int in range(1, rows.size()):
		if rows[i].size() < 2:
			continue
		var dsl_seen: String = TsvReader.row_get(rows[i], 1)
		totals[dsl_seen] = int(totals.get(dsl_seen, 0)) + 1
	var used: Dictionary = {}
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 2:
			continue
		var dsl: String = TsvReader.row_get(row, 1)
		var once_key: String = dsl
		if int(totals.get(dsl, 0)) > 1:
			once_key = "%s#%d" % [dsl, int(used.get(dsl, 0))]
			used[dsl] = int(used.get(dsl, 0)) + 1
		critical_success_options.append({
			"stat": TsvReader.row_get(row, 0),
			"effect_dsl": dsl,
			"frequency": TsvReader.row_get(row, 2),
			"formula_stat_required": TsvReader.row_get(row, 3),
			"once_key": once_key,
		})


func get_settlement_locations() -> Array:
	var result: Array = []
	for loc: LocationData in locations.values():
		if loc.location_type == "Settlement":
			result.append(loc)
	return result


func _load_npc_templates() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/NPCs.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 13 or TsvReader.row_get(row, 0).is_empty():
			continue
		var t = _NPCTemplateClass.new()
		t.npc_type = TsvReader.row_get(row, 0)
		var name_val: String = TsvReader.row_get(row, 1)
		t.name_mode = name_val if not name_val.is_empty() else "Random"
		t.origin_pool = TsvReader.split_field(TsvReader.row_get(row, 2))
		var anc_entries: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 3))
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
		var her_entries: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 4))
		if her_entries.has("Any"):
			t.heritage_any = true
		else:
			t.heritage_pool = her_entries
		var trad_entries: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 5))
		if trad_entries.has("Any"):
			t.tradition_any = true
		elif trad_entries.has("None"):
			t.tradition_none = true
		else:
			t.tradition_pool = trad_entries
		t.level_formula = TsvReader.row_get(row, 6)
		t.sle_name = TsvReader.row_get(row, 7) if not TsvReader.row_get(row, 7).is_empty() else "None"
		var ele_entries: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 8))
		if ele_entries.has("Any"):
			t.ele_any = true
		elif not ele_entries.has("None"):
			t.ele_pool = ele_entries
		t.le_count_str = TsvReader.row_get(row, 9) if not TsvReader.row_get(row, 9).is_empty() else "0"
		t.weapon_pool = TsvReader.split_field(TsvReader.row_get(row, 10))
		t.armor_pool = TsvReader.split_field(TsvReader.row_get(row, 11))
		t.loadout_pool = TsvReader.split_field(TsvReader.row_get(row, 12))
		t.passive_tokens = DataValidator.parse_npc_immunities(TsvReader.row_get(row, 13), t.npc_type)
		t.traits = TsvReader.split_field(TsvReader.row_get(row, 14))
		t.max_ammo = _cell_int(row, 15, -1)
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


func _load_exclusions(excluded_words: Array[String], excluded_syllables: Array[String]) -> void:
	var file := FileAccess.open("res://TSVs/NameExclusions.txt", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/NameExclusions.txt")
		return
	var section: String = ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line == "[words]":
			section = "words"
		elif line == "[syllables]":
			section = "syllables"
		elif section == "words":
			excluded_words.append(line.to_lower())
		elif section == "syllables":
			excluded_syllables.append(line.to_lower())
	file.close()


func _load_prefab_names(prefab_pools: Dictionary) -> void:
	var file := FileAccess.open("res://TSVs/Names_Prefab.tsv", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/Names_Prefab.tsv")
		return
	file.get_csv_line("\t")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if row.size() < 3:
			continue
		var region: String = row[0].strip_edges()
		if region.is_empty():
			continue
		if not prefab_pools.has(region):
			prefab_pools[region] = {"first": [], "last": []}
		var fn: String = row[1].strip_edges()
		var ln: String = row[2].strip_edges()
		if not fn.is_empty():
			(prefab_pools[region]["first"] as Array).append(fn)
		if not ln.is_empty():
			(prefab_pools[region]["last"] as Array).append(ln)
	file.close()


func _load_names(pools: Dictionary) -> void:
	var file := FileAccess.open("res://TSVs/Names_Gen.tsv", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/Names_Gen.tsv")
		return
	file.get_csv_line("\t")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if row.size() < 7:
			continue
		var region: String = row[0].strip_edges()
		if region.is_empty():
			continue
		if not pools.has(region):
			pools[region] = {
				"prefix1": [], "middlefix1": [], "suffix1": [],
				"prefix2": [], "middlefix2": [], "suffix2": []
			}
		var pool: Dictionary = pools[region]
		_add_to_pool(pool, "prefix1",    row[1])
		_add_to_pool(pool, "middlefix1", row[2])
		_add_to_pool(pool, "suffix1",    row[3])
		_add_to_pool(pool, "prefix2",    row[4])
		_add_to_pool(pool, "middlefix2", row[5])
		_add_to_pool(pool, "suffix2",    row[6])
	file.close()


func _add_to_pool(pool: Dictionary, key: String, value: String) -> void:
	var v: String = value.strip_edges()
	if v.is_empty():
		return
	var arr: Array = pool[key] as Array
	arr.append(v)

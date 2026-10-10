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
var obstacles_nonbuilding_pool: Array[ObstacleData] = []  #pre-filtered: not building, not ramp
var obstacles_terrain_pool: Array[ObstacleData] = []  #obstacle_type == "Terrain", non-building
var obstacles_scatter_pool: Array[ObstacleData] = []  #non-building, non-terrain, non-ramp
var obstacles_by_type: Dictionary = {}  #String -> Array[ObstacleData]
var obstacles_by_name: Dictionary = {}  #String -> ObstacleData
#Cave features CavernScatter places by name; they must stay out of the open-map scatter pools.
const CAVERN_ONLY_OBSTACLES: PackedStringArray = ["Stalagmite", "Stalactite", "Column"]
const CONTRACTS_TSV: String = "res://TSVs/Contracts.tsv"
#The stock type rows the suites name; they join contract_rows only in a harness run that is not a rebuild.
const CONTRACTS_OLD_TSV: String = "res://TSVs/Contracts_OLD.tsv"
#City use tokens of the Obstacles.tsv City column; any other token warns on load.
const CITY_USES: PackedStringArray = ["lamp", "sidewalk", "alley", "square"]
var city_obstacles: Dictionary = {}  #use token -> Array[ObstacleData], sheet row order
var building_pool: Array[ObstacleData] = []  #is_building == true
var building_only_pool: Array[ObstacleData] = []  #building_only == true
var areas_pool: Array[Dictionary] = []  #[{name, type, weights:[6 ints], environments:{env->weight}, row}]
var room_sheet_rows: Dictionary = {}     #room name -> Rooms.tsv sheet row, for validator messages
var knowledge_categories: Dictionary = {}
var tool_categories: Dictionary = {}
var stat_definitions: Array[Dictionary] = []
var creature_types: Array[String] = []
var environment_types: Array[String] = []
var type_columns: Dictionary = {}  #Types.tsv header -> Array[String] of that column's values
var critical_success_options: Array = []
var weapon_trait_library: Dictionary = {}  #weapon_name -> Array[TraitData]
var armor_trait_library: Dictionary = {}  #armor_category -> Array[TraitData]
var perk_group_library: Dictionary = {}     #group_key -> Array[TraitData], Perk rows only
var fight_weapon: WeaponData
var makeshift_weapons: Dictionary = {}  #name -> WeaponData template (duplicate before use at runtime)
var npc_templates: Dictionary = {}
var contract_rows: Array[Dictionary] = []
#Contracts_OLD.tsv rows, each tagged _old; always loaded so the validator knows the stock types.
var contract_rows_old: Array[Dictionary] = []
var event_rows: Array[Dictionary] = []
#Checks.tsv rows as header-keyed dictionaries; CheckStore parses and looks them up
var check_rows: Array[Dictionary] = []
#Descriptions.tsv rows: {Contract Name, Description}; several rows per name are allowed
var description_rows: Array[Dictionary] = []
#Organizations.tsv rows: {Name, Type, Home}; an org Issuer names one of them
var organization_rows: Array[Dictionary] = []
#Level Ups.tsv pool entries: {tier, levels: Array[int], option, weight, description, ordinal}
var level_up_rows: Array[Dictionary] = []


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
	DataValidator.require_stat_keys(stat_definitions, ["healthiness", "wile", "vigor"], "VacationDesire")
	_load_critical_successes()
	_load_obstacles()
	_load_rooms()
	_load_areas()
	_load_buildings()
	MakeshiftTemplates.load_makeshift_weapons()
	_load_npc_templates()
	_load_contracts()
	_load_events()
	_load_checks()
	_load_descriptions()
	_load_organizations()
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
	contract_rows = contract_rows_from(TsvReader.load_tsv(CONTRACTS_TSV))
	contract_rows_old = contract_rows_from(TsvReader.load_tsv(CONTRACTS_OLD_TSV))
	for row: Dictionary in contract_rows_old:
		row["_old"] = true
	if HarnessHook.wants_harness() and not OS.get_cmdline_user_args().has(ContractRebuild.BUILD_FLAG):
		contract_rows.append_array(contract_rows_old)


#Header-keyed rows like TsvReader.load_header_rows; a blank Contract Name row stays while its Contract Type is set.
func contract_rows_from(rows: Array[PackedStringArray]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rows.size() < 2:
		return out
	var header: Array[String] = []
	for c: int in range(rows[0].size()):
		var key: String = TsvReader.row_get(rows[0], c)
		if key != "" and header.has(key):
			push_warning("DataManager: Contracts.tsv duplicate column %s" % key)
			key = ""
		header.append(key)
	for i: int in range(1, rows.size()):
		var d: Dictionary = {}
		for c: int in range(header.size()):
			if header[c] != "":
				d[header[c]] = TsvReader.row_get(rows[i], c)
		if ContractResourceBuilder.row_name(d) == "":
			continue
		d["_row"] = i + 1
		out.append(d)
	return out


func _load_events() -> void:
	event_rows = TsvReader.load_header_rows("res://TSVs/Events.tsv")


func _load_checks() -> void:
	check_rows = TsvReader.load_header_rows("res://TSVs/Checks.tsv")


func _load_descriptions() -> void:
	description_rows = TsvReader.load_header_rows("res://TSVs/Descriptions.tsv")


func _load_organizations() -> void:
	organization_rows = TsvReader.load_header_rows("res://TSVs/Organizations.tsv")


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


#Appends value to the list under key, creating the list on first use.
static func _bucket_append(d: Dictionary, key: Variant, value: Variant) -> void:
	if not d.has(key):
		d[key] = []
	(d[key] as Array).append(value)


#A blank rarity cell means Common.
static func _rarity_or_common(cell: String) -> String:
	return "Common" if cell == "" else cell


func _load_knowledges_and_tools() -> void:
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Knowledges and Tools.tsv", 0):
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
	_bucket_append(categories, cat_key, name_val)


func _load_stats() -> void:
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Stats.tsv", 0):
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
	var parent_names: Dictionary = {}
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Locations.tsv", 1):
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
		var sub: String = TsvReader.row_get(row, 22)
		parent_names[loc_name] = sub if sub != "" else TsvReader.row_get(row, 21)
		locations[loc_name] = loc
	for loc_name: String in locations:
		var parent_name: String = parent_names[loc_name]
		if parent_name != "" and locations.has(parent_name):
			(locations[loc_name] as LocationData).parent = locations[parent_name] as LocationData


func _add_to_buff_dict(d: Dictionary, names_csv: String, pct: float) -> void:
	for buff_name: String in TsvReader.split_field(names_csv):
		d[buff_name] = pct


func _parse_temperature(value: String) -> float:
	var parts: PackedStringArray = value.split(" ")
	if parts.size() >= 2:
		return float(parts[-1])
	return 0.0


func _load_ancestries() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Ancestries.tsv")
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
		a.rarity = _rarity_or_common(TsvReader.row_get(row, 2))
		a.perks = TsvReader.split_field(TsvReader.row_get(row, 3))
		a.drawbacks = TsvReader.split_field(TsvReader.row_get(row, 4))
		a.life_expectancy = TsvReader.cell_int(row, 5, -1)
		a.max_dexterity = TsvReader.cell_int(row, 6, 0)
		a.max_vigor = TsvReader.cell_int(row, 7, 0)
		a.size = 2 if TsvReader.row_get(row, 8) == "N/A" else TsvReader.cell_int(row, 8, 0)
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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Heritages.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var h := HeritageData.new()
		h.heritage_name = name_val
		h.max_cognition = TsvReader.cell_int(row, 1, 0)
		h.max_wile = TsvReader.cell_int(row, 2, 0)
		h.circumstances = TsvReader.split_field(TsvReader.row_get(row, 3))
		h.knowledges = TsvReader.split_field(TsvReader.row_get(row, 4))
		h.tools = TsvReader.split_field(TsvReader.row_get(row, 5))
		h.stat_bonus_5pct = TsvReader.split_field(TsvReader.row_get(row, 6))
		heritages[name_val] = h


func _load_lifepaths() -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv("res://TSVs/Lifepaths.tsv")
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
		lp.rarity = _rarity_or_common(TsvReader.row_get(row, 8))
		lp.stat_bonus_5pct = TsvReader.split_field(TsvReader.row_get(row, 10))
		current = lp
		_add_lifepath_requirement(lp, row)
		if event_type == "Starting":
			starting_lifepaths[name_val] = lp
		else:
			_bucket_append(lifepaths_by_category, event_type, lp)


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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Traditions.tsv", 0):
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
			_bucket_append(type_columns, headers[c], value)


func _load_items() -> void:
	#Items stay as raw row dictionaries; ItemData resources are not built here
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Items.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		items[name_val] = {
			"item_name": name_val,
			"item_rarity": TsvReader.row_get(row, 1),
			"item_type": TsvReader.row_get(row, 2),
		}


func _load_weapons() -> void:
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Weapons.tsv", 1):
		var weapon_name: String = TsvReader.row_get(row, 1)
		var w := WeaponData.new()
		w.item_name = weapon_name
		w.item_rarity = TsvReader.row_get(row, 2)
		w.item_type = "Weapon"
		w.weapon_type = TsvReader.row_get(row, 0)
		w.weight = TsvReader.cell_int(row, 3, 0)
		w.cost = TsvReader.cell_int(row, 4, 0)
		w.damage_formula_1 = TsvReader.row_get(row, 5)
		w.damage_types_1 = TsvReader.split_field(TsvReader.row_get(row, 6))
		w.damage_formula_2 = TsvReader.row_get(row, 7)
		w.damage_types_2 = TsvReader.split_field(TsvReader.row_get(row, 8))
		w.draw = TsvReader.cell_int(row, 9, 0)
		w.load_time = TsvReader.cell_int(row, 10, 0)
		w.chamber = TsvReader.cell_int(row, 11, 0)
		w.range_ranged = TsvReader.row_get(row, 12)
		w.range_thrown = TsvReader.row_get(row, 13)
		w.misfire = TsvReader.cell_int(row, 14, 0)
		w.misc_properties = TsvReader.split_field(TsvReader.row_get(row, 15))
		w.weapon_class = TsvReader.row_get(row, 18)
		w.resonance = TsvReader.row_get(row, 19)
		w.resonance_requirement = TsvReader.row_get(row, 20)
		w.symbiosis = TsvReader.row_get(row, 21)
		w.symbiosis_requirement = TsvReader.row_get(row, 22)
		w.fuel_type = TsvReader.row_get(row, 23)
		w.fuel_max = TsvReader.cell_int(row, 24, 0)
		w.inflict_states = TsvReader.split_field(TsvReader.row_get(row, 25), "|")
		w.is_ranged = w.range_ranged != ""
		w.is_throwable = w.range_thrown != ""
		w.has_heavy = w.misc_properties.has("Heavy")
		w.has_light = w.misc_properties.has("Light")
		w.has_extend = w.misc_properties.has("Extend")
		w.melee_range = 2 if w.has_extend else 1
		if w.range_ranged != "":
			var rr: Array[int] = TsvReader.parse_range(w.range_ranged)
			w.ranged_intended_range = rr[0]
			w.ranged_extended_range = rr[1]
		if w.range_thrown != "":
			var rt: Array[int] = TsvReader.parse_range(w.range_thrown)
			w.thrown_intended_range = rt[0]
			w.thrown_extended_range = rt[1]
		for types: Array in [w.damage_types_1, w.damage_types_2]:
			for dt: String in types:
				if dt != "Varies" and not ConstDamageTypes.DAMAGE_TYPES.has(dt):
					push_warning("DataManager: unknown damage type '%s' on weapon '%s'" % [dt, weapon_name])
		weapons[weapon_name] = w
		#The three makeshift templates only seed Makeshift Weapons.tsv; they are never carried gear.
		if MakeshiftTemplates.BASES.has(weapon_name):
			continue
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
	w.damage_types_1.assign(["Strike"])
	w.melee_range = 1
	w.is_virtual = true
	fight_weapon = w


func _load_ammo() -> void:
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Ammo.tsv", 0):
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
		a.weight = TsvReader.cell_int(row, 6, 0)
		a.cost = TsvReader.cell_int(row, 7, 0)
		a.compatible = TsvReader.split_field(TsvReader.row_get(row, 8))
		a.amount = TsvReader.cell_int(row, 10, 1)
		a.ammo_class = TsvReader.row_get(row, 11)
		a.effect = TsvReader.row_get(row, 12)
		a.inflict_states = TsvReader.split_field(TsvReader.row_get(row, 13), "|")
		ammo[ammo_name] = a
		#Magical ammo is a found reward, so it stays out of the pool ordinary loadouts draw from.
		if a.ammo_class == "Magical":
			continue
		if a.item_rarity == "Ordinary" or a.item_rarity == "Common":
			ammo_ordinary_common.append(a)


func _load_armor() -> void:
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Armor.tsv", 0):
		var armor_name: String = TsvReader.row_get(row, 0)
		var a := ArmorData.new()
		a.item_name = armor_name
		a.item_type = "Armor"
		a.armor_type = TsvReader.row_get(row, 1)
		a.weight = TsvReader.cell_int(row, 2, 0)
		a.cost = TsvReader.cell_int(row, 3, 0)
		a.item_rarity = TsvReader.row_get(row, 4)
		a.armor_bonus = TsvReader.cell_int(row, 5, 0)
		a.ep_cost = TsvReader.cell_int(row, 6, 0)
		a.fatigue = TsvReader.cell_int(row, 7, 0)
		a.protection = TsvReader.split_field(TsvReader.row_get(row, 8))
		a.vigor_requirement = TsvReader.cell_int(row, 11, 0)
		a.armor_class = TsvReader.row_get(row, 12)
		var effect_raw: String = TsvReader.row_get(row, 13)
		for s: String in effect_raw.split("|", false):
			a.special_effects.append(s)
		a.resonance = TsvReader.row_get(row, 14)
		a.resonance_requirement = TsvReader.row_get(row, 15)
		a.symbiosis = TsvReader.row_get(row, 16)
		a.symbiosis_requirement = TsvReader.row_get(row, 17)
		a.fuel_type = TsvReader.row_get(row, 18)
		a.fuel_amount = TsvReader.cell_int(row, 19, 0)
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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Traits.tsv", 3):
		var name_val: String = TsvReader.row_get(row, 3)
		var trait_data := TraitData.new()
		trait_data.trait_source = TsvReader.row_get(row, 0)
		trait_data.trait_category = TsvReader.row_get(row, 1)
		trait_data.trait_type = TsvReader.row_get(row, 2)
		trait_data.trait_name = name_val
		trait_data.description = TsvReader.row_get(row, 4)
		trait_data.effect_dsl = EffectDslCompiler.convert_legacy_effect(TsvReader.row_get(row, 5), "Traits.tsv " + name_val)
		trait_data.rarity = _rarity_or_common(TsvReader.row_get(row, 6))
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
			_bucket_append(weapon_trait_library, weapon_name, trait_data)
		elif trait_data.trait_source == "Armor":
			var armor_cat: String = trait_data.trait_category
			trait_data.gear_key = armor_cat
			_bucket_append(armor_trait_library, armor_cat, trait_data)


#Sheet spelling and token spelling meet here: trimmed, lower case, spaces and hyphens as underscores.
func normalize_perk_group(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func _add_to_perk_group(group: String, trait_data: TraitData) -> void:
	if group == "" or trait_data == null:
		return
	if not (perk_group_library.get(group, []) as Array).has(trait_data):
		_bucket_append(perk_group_library, group, trait_data)


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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Obstacles.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		o.obstacle_type = TsvReader.row_get(row, 1)
		o.size_x = TsvReader.cell_float(row, 2, 1.0)
		o.size_y = TsvReader.cell_float(row, 3, 1.0)
		o.size_z = TsvReader.cell_float(row, 4, 0.0)
		o.narrow = TsvReader.cell_bool(row, 5)
		o.thd_min = TsvReader.cell_float(row, 6, 0.0)
		o.thd_max = TsvReader.cell_float(row, 7, 0.0)
		var moveable_str: String = TsvReader.row_get(row, 8)
		o.moveable = moveable_str.to_upper() == "TRUE" or moveable_str == "1"
		o.climbable = TsvReader.cell_bool(row, 9)
		o.climb_difficulty = TsvReader.row_get(row, 10)
		o.health = TsvReader.cell_int(row, 11, 1)
		o.susceptible_to = TsvReader.row_get(row, 12)
		o.immune_to = TsvReader.row_get(row, 32)
		o.rugged = TsvReader.cell_bool(row, 13)
		o.passthrough = TsvReader.cell_bool(row, 14)
		o.is_building = TsvReader.cell_bool(row, 15)
		o.building_only = TsvReader.cell_bool(row, 16)
		o.is_room = TsvReader.cell_bool(row, 17)
		o.room_type = TsvReader.row_get(row, 18)
		o.pt_enter_harm = TsvReader.cell_int(row, 19, 0)
		o.pt_exit_harm = TsvReader.cell_int(row, 20, 0)
		o.pt_harm_type = TsvReader.row_get(row, 21)
		o.growth_pct = TsvReader.cell_int(row, 22, 0)
		o.ramp = TsvReader.cell_bool(row, 23)
		o.covers = (TsvReader.row_get(row, 24).to_lower() != "false") if row.size() > 24 else true
		o.drops = TsvReader.split_field(TsvReader.row_get(row, 25))
		o.guaranteed_structures = TsvReader.split_field(TsvReader.row_get(row, 26))
		o.possible_structures = TsvReader.split_field(TsvReader.row_get(row, 27))
		o.possible_scatter = TsvReader.split_field(TsvReader.row_get(row, 28))
		o.preferred_position = TsvReader.row_get(row, 29)
		o.interactable = TsvReader.cell_bool(row, 30)
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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/Rooms.tsv", 0):
		sheet_row += 1
		var name_val: String = TsvReader.row_get(row, 0)
		if obstacles_by_name.has(name_val):
			push_warning("DataManager: Rooms.tsv room '%s' already exists" % name_val)
			continue
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		o.obstacle_type = "Structure"
		o.size_x = TsvReader.cell_float(row, 1, 1.0)
		o.size_y = TsvReader.cell_float(row, 2, 1.0)
		o.size_z = 0.0
		o.health = 1
		o.is_room = true
		o.room_type = TsvReader.row_get(row, 3)
		o.covers = false
		o.growth_pct = TsvReader.cell_int(row, 7, 0)
		o.guaranteed_structures = TsvReader.split_field(TsvReader.row_get(row, 4))
		o.possible_structures = TsvReader.split_field(TsvReader.row_get(row, 5))
		o.possible_scatter = TsvReader.split_field(TsvReader.row_get(row, 6))
		_register_obstacle(o)
		room_sheet_rows[o.obstacle_name] = sheet_row


#Adds a loaded obstacle to the shared pool, the by-name map and its type bucket.
func _register_obstacle(o: ObstacleData) -> void:
	obstacles_pool.append(o)
	obstacles_by_name[o.obstacle_name] = o
	_bucket_append(obstacles_by_type, o.obstacle_type, o)


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
		var windows: Dictionary = BuildingRules.windows_cell(TsvReader.row_get(row, 11))
		var width: Vector2i = BuildingRules.range_cell(TsvReader.row_get(row, 2))
		var depth: Vector2i = BuildingRules.range_cell(TsvReader.row_get(row, 3))
		var f_plus: Vector2i = BuildingRules.range_cell(TsvReader.row_get(row, 4))
		var f_minus: Vector2i = BuildingRules.range_cell(TsvReader.row_get(row, 5))
		var main_room: String = TsvReader.row_get(row, 12)
		var required_rooms: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 13))
		var other_rooms: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 14))
		var roof: String = TsvReader.row_get(row, 16)
		if roof == "":
			roof = "Flat"
		var roof_objects: Array = BuildingRules.roof_objects_cell(TsvReader.row_get(row, 17), name_val)
		var legacy: bool = layout_f0 == ""
		var rooms_list: Array[String] = other_rooms.duplicate()
		var min_size: int = width.x
		var max_size: int = width.y
		if not legacy:
			var main_list: Array[String] = []
			if main_room != "":
				main_list.append(main_room)
			rooms_list = BuildingRules.dedup_names(main_list, required_rooms, other_rooms)
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
				"wings": BuildingRules.range_cell(TsvReader.row_get(row, 9)),
				"entrances": BuildingRules.range_cell(TsvReader.row_get(row, 10)),
				"windows": String(windows["level"]),
				"window_rooms": windows["rooms"],
				"main_room": main_room,
				"required_rooms": required_rooms,
				"other_rooms": other_rooms,
				"roof": roof,
				"roof_objects": roof_objects,
			},
		})


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
			"f_plus": TsvReader.cell_int(row, 8, 0),
			"f_minus": TsvReader.cell_int(row, 9, 0),
			"furniture_list": TsvReader.split_field(furniture_raw),
			"rooms_list": TsvReader.split_field(rooms_raw),
			"vegetation_list": TsvReader.split_field(TsvReader.row_get(row, 11)),
			"structures_list": TsvReader.split_field(TsvReader.row_get(row, 13)),
			"vegetation_amt": TsvReader.row_get(row, 16),
			"min_size": TsvReader.cell_int(row, 19, 18),
			"max_size": TsvReader.cell_int(row, 20, 45),
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


var _door_template: ObstacleData


#Door obstacle data, built once and shared by every generator.
func door_data() -> ObstacleData:
	if _door_template == null:
		_door_template = ObstacleData.new()
		_door_template.obstacle_name = "Door"
		_door_template.size_x = 1.0
		_door_template.size_y = 0.25
		_door_template.size_z = 2.0
		_door_template.obstacle_type = "Structure"
		_door_template.health = 4
		_door_template.susceptible_to = "Strike"
		_door_template.passthrough = false
		#TODO: replace this code template with a Door row in Obstacles.tsv.
		_door_template.interactable = true
		_door_template.interaction_result = "Open/Close"
	return _door_template


#Rows whose City cell names the use (lamp, sidewalk, alley, square), in sheet order.
func get_city_obstacles(use: String) -> Array[ObstacleData]:
	var out: Array[ObstacleData] = []
	for o: ObstacleData in (city_obstacles.get(use.to_lower(), []) as Array):
		out.append(o)
	return out


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
	for row: PackedStringArray in TsvReader.data_rows("res://TSVs/NPCs.tsv", 0):
		if row.size() < 13:
			continue
		var t := NPCTemplate.new()
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
		var sle_val: String = TsvReader.row_get(row, 7)
		t.sle_name = sle_val if not sle_val.is_empty() else "None"
		var ele_entries: Array[String] = TsvReader.split_field(TsvReader.row_get(row, 8))
		if ele_entries.has("Any"):
			t.ele_any = true
		elif not ele_entries.has("None"):
			t.ele_pool = ele_entries
		var le_val: String = TsvReader.row_get(row, 9)
		t.le_count_str = le_val if not le_val.is_empty() else "0"
		t.weapon_pool = TsvReader.split_field(TsvReader.row_get(row, 10))
		t.armor_pool = TsvReader.split_field(TsvReader.row_get(row, 11))
		t.loadout_pool = TsvReader.split_field(TsvReader.row_get(row, 12))
		t.passive_tokens = DataValidator.parse_npc_immunities(TsvReader.row_get(row, 13), t.npc_type)
		t.traits = TsvReader.split_field(TsvReader.row_get(row, 14))
		t.max_ammo = TsvReader.cell_int(row, 15, -1)
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

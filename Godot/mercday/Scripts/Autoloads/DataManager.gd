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
var weapons: Dictionary = {}
var weapons_ordinary_melee: Array = []
var weapons_ordinary_ranged: Array[WeaponData] = []
var weapons_common_ranged: Array[WeaponData] = []
var ammo: Dictionary = {}
var ammo_ordinary_common: Array = []
var armor: Dictionary = {}
var armor_ordinary_common: Array = []
var obstacles_pool: Array[ObstacleData] = []
var obstacles_by_type: Dictionary = {}   # String -> Array[ObstacleData]
var obstacles_by_name: Dictionary = {}   # String -> ObstacleData
var building_pool: Array[ObstacleData] = []  # is_building == true
var knowledge_categories: Dictionary = {}
var tool_categories: Dictionary = {}
var stat_definitions: Array[Dictionary] = []
var creature_types: Array[String] = []
var environment_types: Array[String] = []
var critical_success_options: Array = []
var weapon_trait_library: Dictionary = {}   # weapon_name -> Array[TraitData]
var armor_trait_library: Dictionary = {}    # armor_category -> Array[TraitData]
var fight_weapon: WeaponData

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
	"Vigor": "vigor",
}


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
	_load_critical_successes()
	_load_obstacles()
	_resolve_location_parents()


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


func _load_weapons() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Weapons.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var weapon_name: String = _row_get(row, 1)
		if weapon_name == "":
			continue
		var w := WeaponData.new()
		w.item_name = weapon_name
		w.item_rarity = _row_get(row, 2)
		w.item_type = "Weapon"
		w.weapon_type = _row_get(row, 0)
		var weight_str: String = _row_get(row, 3)
		w.weight = int(weight_str) if weight_str.is_valid_int() else 0
		var cost_str: String = _row_get(row, 4)
		w.cost = int(cost_str) if cost_str.is_valid_int() else 0
		w.damage_formula_1 = _row_get(row, 5)
		w.damage_types_1 = _split_field(_row_get(row, 6))
		w.damage_formula_2 = _row_get(row, 7)
		w.damage_types_2 = _split_field(_row_get(row, 8))
		var draw_str: String = _row_get(row, 9)
		w.draw = int(draw_str) if draw_str.is_valid_int() else 0
		var load_str: String = _row_get(row, 10)
		w.load_time = int(load_str) if load_str.is_valid_int() else 0
		var chamber_str: String = _row_get(row, 11)
		w.chamber = int(chamber_str) if chamber_str.is_valid_int() else 0
		w.range_ranged = _row_get(row, 12)
		w.range_thrown = _row_get(row, 13)
		var misfire_str: String = _row_get(row, 14)
		w.misfire = int(misfire_str) if misfire_str.is_valid_int() else 0
		w.misc_properties = _split_field(_row_get(row, 15))
		# col 16: Versatile (skip for now)
		# col 17: Effect (skip for now)
		w.weapon_class = _row_get(row, 18)
		w.resonance = _row_get(row, 19)
		w.resonance_requirement = _row_get(row, 20)
		w.symbiosis = _row_get(row, 21)
		w.symbiosis_requirement = _row_get(row, 22)
		w.fuel_type = _row_get(row, 23)
		var fuel_str: String = _row_get(row, 24)
		w.fuel_max = int(fuel_str) if fuel_str.is_valid_int() else 0
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
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Ammo.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var ammo_name: String = _row_get(row, 0)
		if ammo_name == "":
			continue
		var a := AmmoData.new()
		a.item_name = ammo_name
		a.item_rarity = _row_get(row, 9)
		a.item_type = "Ammo"
		a.ammo_type = _row_get(row, 1)
		a.damage_formula_1 = _row_get(row, 2)
		a.damage_types_1 = _split_field(_row_get(row, 3))
		a.damage_formula_2 = _row_get(row, 4)
		a.damage_types_2 = _split_field(_row_get(row, 5))
		var weight_str: String = _row_get(row, 6)
		a.weight = int(weight_str) if weight_str.is_valid_int() else 0
		var cost_str: String = _row_get(row, 7)
		a.cost = int(cost_str) if cost_str.is_valid_int() else 0
		a.compatible = _split_field(_row_get(row, 8))
		var amount_str: String = _row_get(row, 10)
		a.amount = int(amount_str) if amount_str.is_valid_int() else 1
		a.ammo_class = _row_get(row, 11)
		a.effect = _row_get(row, 12)
		ammo[ammo_name] = a
		if a.item_rarity == "Ordinary" or a.item_rarity == "Common":
			ammo_ordinary_common.append(a)


func _load_armor() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Armor.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var armor_name: String = _row_get(row, 0)
		if armor_name == "":
			continue
		var a := ArmorData.new()
		a.item_name = armor_name
		a.item_type = "Armor"
		a.armor_type = _row_get(row, 1)
		var weight_str: String = _row_get(row, 2)
		a.weight = int(weight_str) if weight_str.is_valid_int() else 0
		var cost_str: String = _row_get(row, 3)
		a.cost = int(cost_str) if cost_str.is_valid_int() else 0
		a.item_rarity = _row_get(row, 4)
		var bonus_str: String = _row_get(row, 5)
		a.armor_bonus = int(bonus_str) if bonus_str.is_valid_int() else 0
		var ep_str: String = _row_get(row, 6)
		a.ep_cost = int(ep_str) if ep_str.is_valid_int() else 0
		var fatigue_str: String = _row_get(row, 7)
		a.fatigue = int(fatigue_str) if fatigue_str.is_valid_int() else 0
		a.protection = _split_field(_row_get(row, 8))
		# col 9: Damage Formula (ignored for now)
		# col 10: Damage Type (ignored for now)
		var vigor_str: String = _row_get(row, 11)
		a.vigor_requirement = int(vigor_str) if vigor_str.is_valid_int() else 0
		a.armor_class = _row_get(row, 12)
		var effect_raw: String = _row_get(row, 13)
		for s: String in effect_raw.split("|", false):
			a.special_effects.append(s)
		a.resonance = _row_get(row, 14)
		a.resonance_requirement = _row_get(row, 15)
		a.symbiosis = _row_get(row, 16)
		a.symbiosis_requirement = _row_get(row, 17)
		a.fuel_type = _row_get(row, 18)
		var fuel_str: String = _row_get(row, 19)
		a.fuel_amount = int(fuel_str) if fuel_str.is_valid_int() else 0
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
				p.begins_with("susceptible:") or p.begins_with("cost:") or p.begins_with("SPECIAL:") or
				p.begins_with("armor_weight_ignore:") or p.begins_with("armor_ep_ignore:") or
				p.begins_with("armor_fatigue_zero:") or p.begins_with("weapon_enhance:") or
				p.begins_with("weapon_stat:") or p.begins_with("weapon_two_handed:") or
				p.begins_with("weapon_passive:") or p.begins_with("on_hit:") or
				p.begins_with("on_pain:") or p.begins_with("on_crit:") or
				p.begins_with("spend:") or p.begins_with("action:") or
				p.begins_with("reactive_action:") or p.begins_with("on_kill:") or
				p.begins_with("on_grapple:")):
			return false
	return true


func _load_obstacles() -> void:
	var rows: Array[PackedStringArray] = _csv_rows("res://TSVs/Obstacles.tsv")
	if rows.size() < 2:
		return
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var name_val: String = _row_get(row, 0)
		if name_val == "":
			continue
		var o := ObstacleData.new()
		o.obstacle_name = name_val
		var size_str: String = _row_get(row, 1)
		o.size = int(size_str) if size_str.is_valid_int() else 1
		o.narrow = _row_get(row, 2).to_upper() == "TRUE"
		o.shape = _row_get(row, 3)
		var hmin_str: String = _row_get(row, 4)
		o.height_min = int(hmin_str) if hmin_str.is_valid_int() else 1
		var hmax_str: String = _row_get(row, 5)
		o.height_max = int(hmax_str) if hmax_str.is_valid_int() else 3
		o.obstacle_type = _row_get(row, 6)
		var hp_str: String = _row_get(row, 7)
		o.health = int(hp_str) if hp_str.is_valid_int() else 1
		o.susceptible_to = _row_get(row, 8)
		o.climbable = _row_get(row, 9).to_upper() == "TRUE"
		o.climb_difficulty = _row_get(row, 10)
		o.passthrough = _row_get(row, 11).to_upper() == "TRUE"
		var enter_str: String = _row_get(row, 12)
		o.passthrough_enter_harm = int(enter_str) if enter_str.is_valid_int() else 0
		var exit_str: String = _row_get(row, 13)
		o.passthrough_exit_harm = int(exit_str) if exit_str.is_valid_int() else 0
		o.passthrough_harm_type = _row_get(row, 14)
		o.rugged = _row_get(row, 15).to_upper() == "TRUE"
		var odds_str: String = _row_get(row, 16)
		o.expansion_odds = int(odds_str) if odds_str.is_valid_int() else 0
		o.is_building = _row_get(row, 17).to_upper() == "TRUE"
		o.is_stairs = _row_get(row, 18).to_upper() == "TRUE"
		var tdmin := _row_get(row, 19)
		o.terrain_height_delta_min = float(tdmin) if tdmin.is_valid_float() else 0.0
		var tdmax := _row_get(row, 20)
		o.terrain_height_delta_max = float(tdmax) if tdmax.is_valid_float() else 0.0
		o.provides_cover = (row[21].strip_edges().to_lower() != "false") if row.size() > 21 else true
		var moveable_str: String = _row_get(row, 22)
		o.moveable = moveable_str.to_upper() == "TRUE" or moveable_str == "1"
		var indestructible_str: String = _row_get(row, 23)
		o.indestructible = indestructible_str.to_upper() == "TRUE" or indestructible_str == "1"
		obstacles_pool.append(o)
		obstacles_by_name[o.obstacle_name] = o
		if not obstacles_by_type.has(o.obstacle_type):
			obstacles_by_type[o.obstacle_type] = []
		(obstacles_by_type[o.obstacle_type] as Array).append(o)
		if o.is_building:
			building_pool.append(o)


func get_random_obstacle() -> ObstacleData:
	var non_buildings: Array[ObstacleData] = []
	for o: ObstacleData in obstacles_pool:
		if not o.is_building and not o.is_stairs:
			non_buildings.append(o)
	return non_buildings[randi() % non_buildings.size()]


func get_obstacle_by_name(obs_name: String) -> ObstacleData:
	return obstacles_by_name.get(obs_name) as ObstacleData


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

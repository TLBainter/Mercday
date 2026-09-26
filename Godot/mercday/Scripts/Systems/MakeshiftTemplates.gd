class_name MakeshiftTemplates

#Makeshift rows that also exist as a better class; each extra key is "<row name>:<first word of the base>".
const MAKESHIFT_CLASS_VARIANTS := {"Rock Spike": ["Specialized Makeshift", "Great Makeshift"]}


static func load_makeshift_weapons() -> void:
	for row: PackedStringArray in DataManager._data_rows("res://TSVs/Makeshift Weapons.tsv", 0):
		var name_val: String = TsvReader.row_get(row, 0)
		var base_type: String = TsvReader.row_get(row, 1)
		var base: WeaponData = DataManager.weapons.get(base_type) as WeaponData
		if base == null:
			push_warning("DataManager: makeshift base type '%s' not found for '%s'" % [base_type, name_val])
			continue
		DataManager.makeshift_weapons[name_val] = makeshift_template(row, name_val, base)
		for variant_type: String in (MAKESHIFT_CLASS_VARIANTS.get(name_val, []) as Array):
			var variant_base: WeaponData = DataManager.weapons.get(variant_type) as WeaponData
			if variant_base == null:
				push_warning("DataManager: makeshift variant '%s' not found for '%s'" % [variant_type, name_val])
				continue
			var key: String = "%s:%s" % [name_val, variant_type.split(" ")[0]]
			DataManager.makeshift_weapons[key] = makeshift_template(row, name_val, variant_base)


#One makeshift template: the base weapon's stats with the row's damage type, throw, extend and fragility.
static func makeshift_template(row: PackedStringArray, name_val: String, base: WeaponData) -> WeaponData:
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
	var dmg_types_raw: String = TsvReader.row_get(row, 2)
	if dmg_types_raw != "":
		w.damage_types_1 = TsvReader.split_field(dmg_types_raw)
	var thrown_raw: String = TsvReader.row_get(row, 3)
	if thrown_raw != "" and thrown_raw.to_upper() != "FALSE":
		w.range_thrown = thrown_raw
		w.is_throwable = true
		var rt: Array[int] = DataManager._parse_range(thrown_raw)
		w.thrown_intended_range = rt[0]
		w.thrown_extended_range = rt[1]
	var extend_raw: String = TsvReader.row_get(row, 4)
	if extend_raw.to_upper() == "TRUE":
		if not w.misc_properties.has("Extend"):
			w.misc_properties.append("Extend")
		w.has_extend = true
		w.melee_range = 2
	else:
		w.misc_properties.erase("Extend")
		w.has_extend = false
		w.melee_range = 1
	w.fragility = DataManager._cell_int(row, 5, 0)
	w.current_fragility = w.fragility
	return w

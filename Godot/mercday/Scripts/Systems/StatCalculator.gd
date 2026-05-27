class_name StatCalculator


static func calculate_all(merc: MercenaryData) -> Dictionary:
	var vars: Dictionary = {}

	vars["size"] = float(merc.max_stats.get("size", 0))
	vars["level"] = float(merc.stats.get("level", 0))
	vars["max_cognition"] = float(merc.max_stats.get("max_cognition", 0))
	vars["max_dexterity"] = float(merc.max_stats.get("max_dexterity", 0))
	vars["max_vigor"] = float(merc.max_stats.get("max_vigor", 0))
	vars["max_wile"] = float(merc.max_stats.get("max_wile", 0))
	vars["luck_roll"] = float(merc.luck_roll)

	for stat_name: String in merc.stat_bonuses:
		var var_name: String = "stat_bonus_" + stat_name
		vars[var_name] = float(merc.stat_bonuses[stat_name])

	for core: String in ["cognition", "dexterity", "vigor", "wile"]:
		var key: String = "stat_bonus_" + core
		if not vars.has(key):
			vars[key] = 0.0

	var circ_presence: Dictionary = {
		"grace":               ConstCircumstances.GRACE_DEXTERITY,
		"speech":              ConstCircumstances.SPEECH_WILE,
		"performance_wile":    ConstCircumstances.PERFORMANCE_WILE,
		"attack_dexterity":    ConstCircumstances.ATTACK_DEXTERITY,
		"attack_vigor":        ConstCircumstances.ATTACK_VIGOR,
		"search_cognition":    ConstCircumstances.SEARCH_COGNITION,
		"notice_cognition":    ConstCircumstances.NOTICE_COGNITION,
		"intuition_cognition": ConstCircumstances.INTUITION_COGNITION,
	}
	for circ_var_name: String in circ_presence:
		var display: String = circ_presence[circ_var_name]
		if merc.circumstance_flags.get(display, false):
			vars[circ_var_name] = 15.0 + merc.circumstance_additional_bonus.get(display, 0.0)
		else:
			vars[circ_var_name] = 0.0

	var wile_count: int = 0
	for display_name: String in merc.circumstance_flags:
		if merc.circumstance_flags[display_name]:
			if ConstCircumstances.DATA.get(display_name, {}).get("stat", "") == "Wile":
				wile_count += 1
	vars["wile_circumstance_count"] = float(wile_count)

	var expr := Expression.new()
	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = stat_def["var_name"]
		var stat_type: String = stat_def["type"]
		var formula: String = stat_def["formula"]
		var round_mode: String = stat_def["round"]

		# ancestry/level stats are pre-injected; evaluating the formula would overwrite them.
		if stat_type == "ancestry" or stat_type == "level":
			continue

		var var_names: Array = vars.keys()
		var var_values: Array = vars.values()

		var err: int = expr.parse(formula, PackedStringArray(var_names))
		if err != OK:
			push_error("StatCalculator: failed to parse formula '%s' for stat '%s': %s" % [formula, stat_def["stat"], expr.get_error_text()])
			vars[var_name] = 0.0
			continue

		var raw: Variant = expr.execute(var_values)
		if expr.has_execute_failed():
			push_error("StatCalculator: failed to execute formula '%s' for stat '%s'" % [formula, stat_def["stat"]])
			vars[var_name] = 0.0
			continue

		var value: float = float(raw)

		if round_mode == "floor":
			var int_val: int = int(floor(value))
			if stat_def["type"] != "boolean":
				int_val = max(0, int_val)
			vars[var_name] = int_val
		else:
			if round_mode == "ceil":
				value = ceil(value)
			if stat_def["type"] != "boolean":
				value = max(0.0, value)
			vars[var_name] = value

	# TODO: apply armor weight/encumbrance penalty here once the mechanic is implemented.
	# The Weight Limit stat (vigor + size + 1) already exists; compare against equipped_armor.weight.
	# Guard with: if merc.equipped_armor and not WeaponArmorPerkLibrary.has_armor_perk_active(merc, "armor_weight_ignore:" + merc.equipped_armor.armor_class.to_lower()):
	#     # apply weight penalty (e.g. speed or pace reduction) based on equipped_armor.weight vs weight_limit

	# Core stats include stat_bonus_X in their formulas; skip them here.
	for stat_name: String in merc.stat_bonuses:
		if stat_name == "cognition" or stat_name == "dexterity" or stat_name == "vigor" or stat_name == "wile":
			continue
		var bonus: float = float(merc.stat_bonuses[stat_name])
		if bonus != 0.0 and vars.has(stat_name):
			vars[stat_name] = float(vars[stat_name]) + bonus

	return vars

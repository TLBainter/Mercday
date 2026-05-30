class_name CheckSystem


static func make_check(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var stat_keys: Array[String] = []
	for s in check_def.get("stat_keys", []):
		stat_keys.append(str(s))
	var circ_names: Array[String] = []
	for c in check_def.get("circumstances", []):
		circ_names.append(str(c))

	var success_chance := _evaluate_formula(str(check_def.get("formula", "0")), merc)
	var flat_bonus: float = float(check_def.get("flat_threshold_bonus", 0.0))
	flat_bonus += ConstStates.get_threshold_penalty(merc)

	var k_bonus := 0
	for kname in check_def.get("knowledges", []):
		for k: UtilityTraitData in merc.knowledges:
			if k.utility_name == str(kname):
				k_bonus = 1
				break
		if k_bonus > 0:
			break

	var t_bonus := 0
	for tname in check_def.get("tools", []):
		for t: UtilityTraitData in merc.tools:
			if t.utility_name.begins_with(str(tname)):
				t_bonus = 1
				break
		if t_bonus > 0:
			break

	var enhancements := k_bonus + t_bonus + int(check_def.get("enhancements", 0))
	var flaws := int(check_def.get("flaws", 0))

	var chosen_stat := _choose_stat(merc, success_chance, stat_keys, circ_names)
	var circ_bonus := _circumstance_bonus_for_stat(merc, chosen_stat, circ_names)
	var bsc := clampf(float(merc.stats.get("base_success_chance", 0.0)), 0.0, 100.0)
	var threshold := clampf(success_chance + circ_bonus + bsc + flat_bonus, 0.01, 100.0)
	var reroll_threshold := clampf(float(merc.stats.get("reroll", 0.0)), 0.0, 100.0)
	var stat_value := int(merc.stats.get(chosen_stat, 0))

	var instances: Array[bool] = []
	if stat_value <= 0:
		instances.append(true)
	else:
		for _i: int in stat_value:
			instances.append(false)
	for _i: int in enhancements:
		instances.append(false)
	var to_remove := mini(flaws, instances.size())
	if to_remove > 0:
		instances = instances.slice(0, instances.size() - to_remove)

	var successes := 0
	var failures := 0
	var roll1: Array = []
	var roll2: Array = []
	var rerolls := 0

	for is_hard: bool in instances:
		var init_val: int
		var init_entry: Variant
		if is_hard:
			var pair := _roll_pair()
			init_val = pair[1]
			init_entry = pair
		else:
			init_val = randi_range(1, 100)
			init_entry = init_val
		roll1.append(init_entry)

		var final_val := init_val
		var final_entry: Variant = init_entry
		if float(init_val) > threshold and float(randi_range(1, 100)) <= reroll_threshold:
			rerolls += 1
			if is_hard:
				var pair := _roll_pair()
				final_val = pair[1]
				final_entry = pair
			else:
				final_val = randi_range(1, 100)
				final_entry = final_val
		roll2.append(final_entry)

		if float(final_val) <= threshold:
			successes += 1
		else:
			failures += 1

	return {
		"successes": successes,
		"failures": failures,
		"roll1": roll1,
		"roll2": roll2,
		"rerolls": rerolls,
		"stat_used": chosen_stat,
		"threshold": threshold,
		"k_bonus": k_bonus,
		"t_bonus": t_bonus,
	}


static var _expr_cache: Dictionary = {}  # formula -> {expr, var_names}

static func _evaluate_formula(formula: String, merc: MercenaryData) -> float:
	if not _expr_cache.has(formula):
		var names: Array[String] = []
		for key in merc.stats:
			names.append(str(key))
		names.append("rand_factor")
		var new_expr := Expression.new()
		var err := new_expr.parse(formula, names)
		if err != OK:
			push_warning("CheckSystem: formula parse error: " + formula)
			return 0.0
		_expr_cache[formula] = {"expr": new_expr, "var_names": names}

	var cached: Dictionary = _expr_cache[formula]
	var expr: Expression = cached["expr"]
	var var_names: Array[String] = cached["var_names"]

	var var_values: Array = []
	for key: String in var_names:
		if key == "rand_factor":
			var_values.append(randf_range(0.1, 4.9))
		else:
			var_values.append(merc.stats.get(key, 0))

	var result = expr.execute(var_values)
	if expr.has_execute_failed():
		push_warning("CheckSystem: formula execute error: " + formula)
		return 0.0
	return clampf(float(result), 0.0, 100.0)


static func _choose_stat(
	merc: MercenaryData,
	success_chance: float,
	stat_keys: Array[String],
	circumstance_display_names: Array[String]
) -> String:
	if stat_keys.size() <= 1:
		return stat_keys[0] if stat_keys.size() > 0 else ""
	var p_reroll := clampf(float(merc.stats.get("reroll", 0.0)) / 100.0, 0.0, 1.0)
	var bsc := clampf(float(merc.stats.get("base_success_chance", 0.0)), 0.0, 100.0)
	var best_stat := stat_keys[0]
	var best_expected := -1.0
	for sk: String in stat_keys:
		var circ_bonus := _circumstance_bonus_for_stat(merc, sk, circumstance_display_names)
		var threshold := clampf(success_chance + circ_bonus + bsc, 0.01, 100.0)
		var stat_value := int(merc.stats.get(sk, 0))
		var num_instances := maxi(1, stat_value)
		var p_base: float
		if stat_value <= 0:
			p_base = (threshold / 100.0) * (threshold / 100.0)
		else:
			p_base = threshold / 100.0
		var p_eff := p_base + (1.0 - p_base) * p_reroll * p_base
		var expected := num_instances * p_eff
		if expected > best_expected:
			best_expected = expected
			best_stat = sk
	return best_stat


static func _circumstance_bonus_for_stat(
	merc: MercenaryData,
	stat_key: String,
	circumstance_display_names: Array[String]
) -> float:
	if circumstance_display_names.is_empty():
		return 0.0
	var stat_display := stat_key.capitalize()
	for circ_display: String in circumstance_display_names:
		if not circ_display.ends_with("(" + stat_display + ")"):
			continue
		if merc.circumstance_flags.get(circ_display, false):
			return 15.0 + merc.circumstance_additional_bonus.get(circ_display, 0.0)
	return 0.0


static func _roll_pair() -> Array[int]:
	var a := randi_range(1, 100)
	var b := randi_range(1, 100)
	return [mini(a, b), maxi(a, b)]

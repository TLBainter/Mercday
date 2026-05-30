class_name CriticalSuccessSystem

const CORE_STAT_KEYS: Array[String] = ["dexterity", "cognition", "vigor", "wile"]


static func is_critical_success(result: Dictionary, merc: MercenaryData) -> bool:
	if int(result.get("failures", 1)) > 0:
		return false
	var luck := float(merc.stats.get("luck", 0.0))
	var threshold := float(result.get("threshold", 0.0))
	for r: Variant in result.get("roll2", []) as Array:
		var final_val: int
		if r is int:
			final_val = r
		else:
			final_val = (r as Array)[1]
		if float(final_val) < threshold - luck:
			return false
	return true


static func build_option_pool(result: Dictionary, merc: MercenaryData, check_def: Dictionary) -> Array:
	var chosen_stat: String = (str(result.get("stat_used", ""))).capitalize()
	var formula: String = str(check_def.get("formula", "")).to_lower()
	var pool: Array = []
	for entry: Dictionary in DataManager.critical_success_options:
		if entry["stat"] != chosen_stat:
			continue
		var formula_req: String = (entry["formula_stat_required"] as String).strip_edges().to_lower().replace(" ", "_")
		if formula_req != "" and not formula.contains(formula_req):
			continue
		if entry["frequency"] == "Once" and merc.acquired_critical_successes.has(entry["effect_dsl"]):
			continue
		if not _is_effect_feasible(merc, entry["effect_dsl"]):
			continue
		pool.append(entry)
	return pool


static func roll_and_apply(merc: MercenaryData, pool: Array) -> String:
	if pool.is_empty():
		merc.stats["level"] = int(merc.stats.get("level", 0)) + 1
		return "Level Up! Now level %d" % int(merc.stats.get("level", 1))
	var entry: Dictionary = pool[randi() % pool.size()] as Dictionary
	if entry["frequency"] == "Once":
		merc.acquired_critical_successes.append(entry["effect_dsl"])
	var description: String = _apply_critical_effect(merc, entry["effect_dsl"])
	merc.stats = StatCalculator.calculate_all(merc)
	return description


static func _apply_critical_effect(merc: MercenaryData, dsl: String) -> String:
	if dsl.begins_with("stat:max_"):
		var parts: PackedStringArray = dsl.split(":")
		if parts.size() == 3:
			var stat_key: String = parts[1]
			var val_str: String = parts[2]
			var op: int = 1 if val_str.begins_with("+") else -1
			var amount: int = int(val_str.substr(1)) * op
			merc.max_stats[stat_key] = (merc.max_stats.get(stat_key, 0) as int) + amount
			return "+%d %s" % [amount, stat_key.replace("max_", "Maximum ").capitalize()]
	elif dsl.begins_with("stat:"):
		var parts: PackedStringArray = dsl.split(":")
		if parts.size() == 3:
			var stat_key: String = parts[1]
			var val_str: String = parts[2].trim_suffix("%")
			var is_pct: bool = parts[2].ends_with("%")
			var op: float = 1.0 if val_str.begins_with("+") else -1.0
			var amount: float = float(val_str.substr(1)) * op
			merc.stat_bonuses[stat_key] = (merc.stat_bonuses.get(stat_key, 0.0) as float) + amount
			var label: String = stat_key.replace("_", " ").capitalize()
			if is_pct:
				return "+%.4g%% %s" % [amount, label]
			return "+%g %s" % [amount, label]
	elif dsl.begins_with("grant:random:circumstance:"):
		# TODO: replace grant:weapon_perk:used_weapon:1 DSL entries with a proper
		# weapon perk grant once the weapon perk system is implemented.
		var parts: PackedStringArray = dsl.split(":")
		if parts.size() == 5:
			var filter_key: String = parts[3]
			var count: int = int(parts[4])
			var pool: Array[String] = _build_circumstance_pool(filter_key)
			var available: Array[String] = []
			for d: String in pool:
				if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
					available.append(d)
			available.shuffle()
			var granted: Array[String] = []
			for i: int in range(mini(count, available.size())):
				merc.circumstance_flags[available[i]] = true
				granted.append(available[i])
			if granted.is_empty():
				return "Circumstance (none available)"
			return "Circumstance: %s" % ", ".join(granted)
	return dsl


static func _build_circumstance_pool(filter_key: String) -> Array[String]:
	var parts: PackedStringArray = filter_key.split("_")
	var pool: Array[String] = []
	if parts.size() >= 2 and parts[-1].to_lower() == "all":
		# e.g. "dexterity_all" -> all circumstances where stat == "Dexterity"
		var stat_name_parts: PackedStringArray = parts.slice(0, parts.size() - 1)
		var stat_filter: String = " ".join(stat_name_parts).capitalize()
		for d: String in ConstCircumstances.ALL:
			if (ConstCircumstances.DATA[d] as Dictionary).get("stat", "") == stat_filter:
				pool.append(d)
	elif CORE_STAT_KEYS.has(filter_key.to_lower()):
		var stat_filter: String = filter_key.capitalize()
		for d: String in ConstCircumstances.ALL:
			if (ConstCircumstances.DATA[d] as Dictionary).get("stat", "") == stat_filter:
				pool.append(d)
	else:
		for d: String in ConstCircumstances.ALL:
			if (ConstCircumstances.DATA[d] as Dictionary).get("circumstance_name", "").to_lower() == filter_key.to_lower():
				pool.append(d)
	return pool


static func _is_effect_feasible(merc: MercenaryData, dsl: String) -> bool:
	if dsl.begins_with("stat:") and not dsl.begins_with("stat:max_") and not dsl.begins_with("stat:min_"):
		var parts: PackedStringArray = dsl.split(":")
		if parts.size() == 3 and CORE_STAT_KEYS.has(parts[1]):
			var core_key: String = parts[1]
			return int(merc.stats.get(core_key, 0)) < int(merc.stats.get("max_" + core_key, 0))
	elif dsl.begins_with("grant:random:circumstance:"):
		var parts: PackedStringArray = dsl.split(":")
		if parts.size() == 5:
			var pool: Array[String] = _build_circumstance_pool(parts[3])
			for d: String in pool:
				if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
					return true
			return false
	return true

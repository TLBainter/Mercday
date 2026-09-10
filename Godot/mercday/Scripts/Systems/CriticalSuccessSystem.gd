class_name CriticalSuccessSystem

const CORE_STAT_KEYS: Array[String] = ["dexterity", "cognition", "vigor", "wile"]

#While true a rolled reward is held on the merc and applied after the encounter.
static var banking: bool = false


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


#A core-stat check draws its stat's rows; a Defend or Dodge check draws the plain Dexterity rows plus its own row.
static func build_option_pool(result: Dictionary, merc: MercenaryData, check_def: Dictionary) -> Array:
	var stat_used: String = str(result.get("stat_used", ""))
	var chosen_stat: String = stat_used.capitalize()
	var core_check := CORE_STAT_KEYS.has(stat_used.to_lower())
	var formula: String = str(check_def.get("formula", "")).to_lower()
	var defense_check := not core_check and (formula == "defend" or formula == "dodge")
	var pool: Array = []
	for entry: Dictionary in DataManager.critical_success_options:
		if core_check and entry["stat"] != chosen_stat:
			continue
		var formula_req: String = (entry["formula_stat_required"] as String).strip_edges().to_lower().replace(" ", "_")
		if formula_req == "":
			if not core_check and not (defense_check and entry["stat"] == "Dexterity"):
				continue
		elif core_check:
			if not _formula_uses(formula, formula_req):
				continue
		elif defense_check:
			if formula_req != formula:
				continue
		elif not formula.contains(formula_req):
			continue
		if entry["frequency"] == "Once" and merc.acquired_critical_successes.has(entry["effect_dsl"]):
			continue
		if entry["frequency"] == "Once" and _is_pending(merc, entry["effect_dsl"]):
			continue
		if not _is_effect_feasible(merc, entry["effect_dsl"]):
			continue
		pool.append(entry)
	return pool


#True when the check formula names the required stat or derives from it through Stats.tsv.
static func _formula_uses(formula: String, required: String) -> bool:
	if formula.contains(required):
		return true
	var pending: Array[String] = []
	var seen: Dictionary = {}
	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = str(stat_def["var_name"])
		if formula.contains(var_name):
			pending.append(var_name)
	while not pending.is_empty():
		var name: String = pending.pop_back()
		if seen.has(name):
			continue
		seen[name] = true
		for stat_def: Dictionary in DataManager.stat_definitions:
			if str(stat_def["var_name"]) != name:
				continue
			var calc: String = str(stat_def["formula"]).to_lower()
			if calc.contains(required):
				return true
			for other: Dictionary in DataManager.stat_definitions:
				var other_name: String = str(other["var_name"])
				if calc.contains(other_name) and not seen.has(other_name):
					pending.append(other_name)
	return false


#Rolls one reward for a critical success and either banks it or applies it now.
static func on_critical(merc: MercenaryData, result: Dictionary, check_def: Dictionary) -> String:
	var entry: Dictionary = pick(merc, build_option_pool(result, merc, check_def))
	if banking:
		merc.pending_crit_rewards.append(entry)
		return "banked " + str(entry.get("effect_dsl", ""))
	return apply_entry(merc, entry)


#Picks one entry from the pool; an empty pool means a level up. A Once reward is marked when applied.
static func pick(_merc: MercenaryData, pool: Array) -> Dictionary:
	if pool.is_empty():
		return {"effect_dsl": "level_up", "frequency": "", "stat": ""}
	return pool[randi() % pool.size()] as Dictionary


static func apply_entry(merc: MercenaryData, entry: Dictionary) -> String:
	StatCalculator.prime(merc)
	var description: String = _apply_entry_effect(merc, entry)
	StatCalculator.refresh(merc)
	return description


#Applies every reward banked during an encounter and clears the bank.
static func apply_pending(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	if merc.pending_crit_rewards.is_empty():
		return out
	StatCalculator.prime(merc)
	for entry: Dictionary in merc.pending_crit_rewards:
		out.append(_apply_entry_effect(merc, entry))
	StatCalculator.refresh(merc)
	merc.pending_crit_rewards.clear()
	return out


static func _is_pending(merc: MercenaryData, dsl: String) -> bool:
	for entry: Dictionary in merc.pending_crit_rewards:
		if str(entry.get("effect_dsl", "")) == dsl:
			return true
	return false


static func _apply_entry_effect(merc: MercenaryData, entry: Dictionary) -> String:
	var dsl: String = str(entry.get("effect_dsl", ""))
	if str(entry.get("frequency", "")) == "Once" and not merc.acquired_critical_successes.has(dsl):
		merc.acquired_critical_successes.append(dsl)
	if dsl == "level_up":
		var lines: Array[String] = ExperienceSystem.award(merc, ExperienceSystem.XP_PER_LEVEL, "critical success")
		lines.append_array(ExperienceSystem.resolve_level_ups(merc))
		if lines.is_empty():
			return "Level Up reward: no campaign identity, no XP"
		return "; ".join(lines)
	return _apply_critical_effect(merc, dsl)


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
			var label: String = stat_key.replace("_", " ").capitalize()
			if is_pct:
				#A percent reward is a percent of the computed value, never flat points.
				StatCalculator.add_percent(merc, stat_key, amount / 100.0)
				return "+%s%% %s" % [String.num(amount, 4).rstrip("0").rstrip("."), label]
			StatCalculator.add_flat(merc, stat_key, amount)
			return "+%s %s" % [String.num(amount, 4).rstrip("0").rstrip("."), label]
	elif dsl.begins_with("grant:random:circumstance:"):
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
		#e.g. "dexterity_all" means all circumstances whose stat is "Dexterity"
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

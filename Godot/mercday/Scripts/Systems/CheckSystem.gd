class_name CheckSystem

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

#Test hook: while not empty every d100 of a check is drawn from here, front first.
static var forced_rolls: Array[int] = []


static func _d100() -> int:
	if not forced_rolls.is_empty():
		return forced_rolls.pop_front()
	return randi_range(1, 100)


#Shared make_check/_prepare prologue: stat choice, bonuses and the final threshold.
static func _resolve_check(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var stat_keys: Array[String] = []
	for s in check_def.get("stat_keys", []):
		stat_keys.append(str(s))
	var circ_names: Array[String] = []
	for c in check_def.get("circumstances", []):
		circ_names.append(str(c))

	var success_chance := _evaluate_formula(str(check_def.get("formula", "0")), merc)
	var flat_bonus: float = float(check_def.get("flat_threshold_bonus", 0.0))

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
	var mod := ConstStates.check_modifier(merc, chosen_stat)
	flat_bonus += float(mod["threshold"])
	enhancements += int(mod["enhancements"])
	flaws += int(mod["flaws"])
	var circ_bonus := _circumstance_bonus_for_stat(merc, chosen_stat, circ_names)
	var bsc := clampf(float(merc.stats.get(_CONFIG.base_success_chance_stat, 0.0)), 0.0, 100.0)
	var threshold := clampf(success_chance + circ_bonus + bsc + flat_bonus, 0.01, 100.0)
	return {
		"threshold": threshold,
		"chosen_stat": chosen_stat,
		"enhancements": enhancements,
		"flaws": flaws,
		"k_bonus": k_bonus,
		"t_bonus": t_bonus,
		"auto_fail": bool(mod["auto_fail"]),
		"mod": mod,
	}


static func make_check(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var prep := _resolve_check(merc, check_def)
	var mod: Dictionary = prep["mod"]
	var chosen_stat: String = prep["chosen_stat"]
	var threshold: float = prep["threshold"]
	var enhancements: int = prep["enhancements"]
	var flaws: int = prep["flaws"]
	var k_bonus: int = prep["k_bonus"]
	var t_bonus: int = prep["t_bonus"]
	var mod_states := states_text(mod["states"])

	if bool(mod["auto_fail"]):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CHECK AUTO-FAIL: %s %s states=%s" % [
				merc.merc_name, chosen_stat, mod_states])
		LifepathTally.record_check(merc, chosen_stat, 0, false)
		LifepathTally.record_target_check(merc, chosen_stat, false)
		return {
			"successes": 0,
			"failures": 1,
			"roll1": [],
			"roll2": [],
			"rerolls": 0,
			"stat_used": chosen_stat,
			"threshold": threshold,
			"k_bonus": k_bonus,
			"t_bonus": t_bonus,
			"critical": false,
			"crit_reward": "",
		}
	if EncounterLogger.is_active() and mod_states != "":
		EncounterLogger.log_verbose("CHECK STATE MOD: %s %s threshold=%+.1f flaws=%d enh=%d states=%s" % [
			merc.merc_name, chosen_stat, float(mod["threshold"]), int(mod["flaws"]),
			int(mod["enhancements"]), mod_states])

	var reroll_threshold := clampf(float(merc.stats.get(_CONFIG.reroll_stat, 0.0)), 0.0, 100.0)
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
	if instances.is_empty():
		instances.append(true)  # net-zero core dice -> disadvantage pair, take lowest

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
			init_val = _d100()
			init_entry = init_val
		roll1.append(init_entry)

		var final_val := init_val
		var final_entry: Variant = init_entry
		if float(init_val) > threshold and float(_d100()) <= reroll_threshold:
			rerolls += 1
			if is_hard:
				var pair := _roll_pair()
				final_val = pair[1]
				final_entry = pair
			else:
				final_val = _d100()
				final_entry = final_val
		roll2.append(final_entry)

		if float(final_val) <= threshold:
			successes += 1
		else:
			failures += 1

	LifepathTally.record_check(merc, chosen_stat, successes, successes > 0)
	LifepathTally.record_target_check(merc, chosen_stat, successes > 0)
	if rerolls > 0 and successes > 0:
		LifepathTally.record_check(merc, "reroll", successes, true, false)
	var result := {
		"successes": successes,
		"failures": failures,
		"roll1": roll1,
		"roll2": roll2,
		"rerolls": rerolls,
		"stat_used": chosen_stat,
		"threshold": threshold,
		"k_bonus": k_bonus,
		"t_bonus": t_bonus,
		"critical": false,
		"crit_reward": "",
	}
	if CriticalSuccessSystem.is_critical_success(result, merc):
		var reward := CriticalSuccessSystem.on_critical(merc, result, check_def)
		result["critical"] = true
		result["crit_reward"] = reward
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CRITICAL SUCCESS: %s %s reward=%s" % [
				merc.merc_name, chosen_stat, reward])
	return result


#Chance make_check would land at least `trial` successes, worked out without rolling or logging.
#A trial above the dice count can only be met by a critical success, so that is what it returns.
static func expected_success_chance(merc: MercenaryData, check_def: Dictionary, trial: int) -> float:
	var prep := _prepare(merc, check_def)
	if bool(prep["auto_fail"]):
		return 0.0
	var dice := int(prep["dice"])
	if trial > dice:
		return _crit_chance_of(prep)
	var p := float(prep["p"])
	var reroll := float(prep["reroll"])
	return _binomial_tail(dice, p + (1.0 - p) * reroll * p, trial)


#Chance every die of a check lands in the critical window, threshold - luck up to threshold.
static func crit_chance(merc: MercenaryData, check_def: Dictionary) -> float:
	var prep := _prepare(merc, check_def)
	if bool(prep["auto_fail"]):
		return 0.0
	return _crit_chance_of(prep)


static func _crit_chance_of(prep: Dictionary) -> float:
	var threshold := float(prep["threshold"])
	var luck := float(prep["luck"])
	var reroll := float(prep["reroll"])
	var p := float(prep["p"])
	var hi := clampi(floori(threshold), 0, 100)
	var lo := maxi(1, ceili(threshold - luck))
	if hi < lo:
		return 0.0
	var is_hard: bool = bool(prep["hard"])
	var base: float
	if is_hard:
		base = (float(hi) / 100.0) * (float(hi) / 100.0) - (float(lo - 1) / 100.0) * (float(lo - 1) / 100.0)
	else:
		base = float(hi - lo + 1) / 100.0
	var eff := base + (1.0 - p) * reroll * base
	if is_hard:
		return clampf(eff, 0.0, 1.0)
	return clampf(pow(eff, float(prep["dice"])), 0.0, 1.0)


#Threshold, dice count, hard-pair flag, reroll chance and luck a check would use, without rolling.
static func _prepare(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var prep := _resolve_check(merc, check_def)
	if bool(prep["auto_fail"]):
		return {"auto_fail": true, "threshold": 0.0, "dice": 1, "hard": false, "p": 0.0,
			"reroll": 0.0, "luck": 0.0}
	var chosen_stat: String = prep["chosen_stat"]
	var enhancements: int = prep["enhancements"]
	var flaws: int = prep["flaws"]
	var threshold: float = prep["threshold"]

	var dice := int(merc.stats.get(chosen_stat, 0)) + enhancements - flaws
	var p := threshold / 100.0
	var hard := false
	if dice <= 0:
		dice = 1
		hard = true
		p = p * p
	dice = mini(dice, 64)
	var reroll := clampf(float(merc.stats.get(_CONFIG.reroll_stat, 0.0)) / 100.0, 0.0, 1.0)
	return {"auto_fail": false, "threshold": threshold, "dice": dice, "hard": hard, "p": p,
		"reroll": reroll, "luck": float(merc.stats.get("luck", 0.0))}


#P(at least `trial` successes) over `n` independent dice each succeeding with chance `p`.
static func _binomial_tail(n: int, p: float, trial: int) -> float:
	if trial <= 0:
		return 1.0
	if trial > n:
		return 0.0
	p = clampf(p, 0.0, 1.0)
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0
	var term := pow(1.0 - p, float(n))
	var total := 0.0
	for k: int in range(n + 1):
		if k >= trial:
			total += term
		if k < n:
			term = term * float(n - k) / float(k + 1) * p / (1.0 - p)
	return clampf(total, 0.0, 1.0)


#Comma-joined unique state names for a state-mod log line.
static func states_text(states: Array) -> String:
	var seen: Array[String] = []
	for entry: Variant in states:
		var state_name := str(entry)
		if not seen.has(state_name):
			seen.append(state_name)
	return ",".join(seen)


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
			var_values.append(randf_range(_CONFIG.rand_factor_min, _CONFIG.rand_factor_max))
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
	var p_reroll := clampf(float(merc.stats.get(_CONFIG.reroll_stat, 0.0)) / 100.0, 0.0, 1.0)
	var bsc := clampf(float(merc.stats.get(_CONFIG.base_success_chance_stat, 0.0)), 0.0, 100.0)
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
	var a := _d100()
	var b := _d100()
	return [mini(a, b), maxi(a, b)]

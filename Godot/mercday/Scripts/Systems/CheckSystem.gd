class_name CheckSystem

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

#Flat threshold bonus of a flagged Circumstance, before its additional bonus.
const CIRCUMSTANCE_BONUS := 15.0
#Test hook: while not empty every d100 of a check is drawn from here, front first.
static var forced_rolls: Array[int] = []
#Knowledges every check counts as named while set; a Competition of War bout fills it and clears it.
static var ambient_knowledges: Array[String] = []
#Parsed formulas keyed by the formula and the variable names it was parsed against.
static var _expr_cache: Dictionary = {}


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
	var k_name := ""
	var k_names: Array = []
	k_names.append_array(check_def.get("knowledges", []))
	k_names.append_array(ambient_knowledges)
	for kname in k_names:
		for k: UtilityTraitData in merc.knowledges:
			if k.utility_name == str(kname):
				k_bonus = 1
				k_name = k.utility_name
				break
		if k_bonus > 0:
			break
	if k_name != "":
		k_bonus += int(merc.trained_bonus.get("knowledge:" + k_name, 0))

	var t_bonus := 0
	var t_name := ""
	for tname in check_def.get("tools", []):
		for t: UtilityTraitData in merc.tools:
			if t.utility_name.begins_with(str(tname)):
				t_bonus = 1
				t_name = t.utility_name
				break
		if t_bonus > 0:
			break
	if t_name != "":
		t_bonus += int(merc.trained_bonus.get("tool:" + t_name, 0))

	var enhancements := k_bonus + t_bonus + int(check_def.get("enhancements", 0))
	var flaws := int(check_def.get("flaws", 0))
	#Extra dice the caller adds to the chosen stat, such as the Armor Bonus on a Defend.
	var dice_bonus := int(check_def.get("dice_bonus", 0))

	var chosen_stat := _choose_stat(merc, success_chance, stat_keys, circ_names, dice_bonus)
	var mod := StateEffects.check_modifier(merc, chosen_stat)
	flat_bonus += float(mod["threshold"])
	enhancements += int(mod["enhancements"])
	flaws += int(mod["flaws"])
	var circ_name := _circumstance_name_for_stat(merc, chosen_stat, circ_names)
	var circ_bonus := _circumstance_bonus_for_stat(merc, chosen_stat, circ_names)
	var bsc := clampf(float(merc.stats.get(_CONFIG.base_success_chance_stat, 0.0)), 0.0, 100.0)
	var threshold := clampf(success_chance + circ_bonus + bsc + flat_bonus, 0.01, 100.0)
	return {
		"threshold": threshold,
		"raw": success_chance + circ_bonus + bsc + flat_bonus,
		"chosen_stat": chosen_stat,
		"enhancements": enhancements,
		"flaws": flaws,
		"dice_bonus": dice_bonus,
		"k_bonus": k_bonus,
		"t_bonus": t_bonus,
		"k_name": k_name,
		"t_name": t_name,
		"circ_name": circ_name,
		"auto_fail": bool(mod["auto_fail"]),
		"mod": mod,
	}


#The dice a check rolls: normal dice from the core stat and enhancements, less flaws.
#net-zero core dice -> disadvantage pair, take lowest
static func _dice_pool(stat_value: int, enhancements: int, flaws: int) -> Dictionary:
	var hard := 0
	var normal := 0
	if stat_value <= 0:
		hard = 1
		normal = maxi(0, enhancements - flaws)
	else:
		normal = maxi(0, stat_value + enhancements - flaws)
		if normal == 0:
			hard = 1
	return {"normal": normal, "hard": hard}


static func make_check(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var prep := _resolve_check(merc, check_def)
	_record_use(merc, "knowledge", str(prep["k_name"]))
	_record_use(merc, "tool", str(prep["t_name"]))
	_record_use(merc, "circumstance", str(prep["circ_name"]))
	var mod: Dictionary = prep["mod"]
	var chosen_stat: String = prep["chosen_stat"]
	var threshold: float = prep["threshold"]
	var enhancements: int = prep["enhancements"]
	var flaws: int = prep["flaws"]
	var mod_states := states_text(mod["states"])

	if bool(mod["auto_fail"]):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CHECK AUTO-FAIL: %s %s states=%s" % [
				merc.merc_name, chosen_stat, mod_states])
		LifepathTally.record_check(merc, chosen_stat, 0, false)
		LifepathTally.record_target_check(merc, chosen_stat, false)
		return _result(prep, 0, 1, [], [], 0)
	if EncounterLogger.is_active() and mod_states != "":
		EncounterLogger.log_verbose("CHECK STATE MOD: %s %s threshold=%+.1f flaws=%d enh=%d states=%s" % [
			merc.merc_name, chosen_stat, float(mod["threshold"]), int(mod["flaws"]),
			int(mod["enhancements"]), mod_states])

	var reroll_threshold := clampf(float(merc.stats.get(_CONFIG.reroll_stat, 0.0)), 0.0, 100.0)
	var stat_value := int(merc.stats.get(chosen_stat, 0)) + int(prep["dice_bonus"])

	var pool := _dice_pool(stat_value, enhancements, flaws)
	var instances: Array[bool] = []
	for _i: int in int(pool["hard"]):
		instances.append(true)
	for _i: int in int(pool["normal"]):
		instances.append(false)

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
			init_val = Dice.d100(forced_rolls)
			init_entry = init_val
		roll1.append(init_entry)

		var final_val := init_val
		var final_entry: Variant = init_entry
		if float(init_val) > threshold and float(Dice.d100(forced_rolls)) <= reroll_threshold:
			rerolls += 1
			if is_hard:
				var pair := _roll_pair()
				final_val = pair[1]
				final_entry = pair
			else:
				final_val = Dice.d100(forced_rolls)
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
	var result := _result(prep, successes, failures, roll1, roll2, rerolls)
	if CriticalSuccessSystem.is_critical_success(result, merc):
		var reward := CriticalSuccessSystem.on_critical(merc, result, check_def)
		result["critical"] = true
		result["crit_reward"] = reward
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CRITICAL SUCCESS: %s %s reward=%s" % [
				merc.merc_name, chosen_stat, reward])
	return result


static func _result(prep: Dictionary, successes: int, failures: int, roll1: Array, roll2: Array,
		rerolls: int) -> Dictionary:
	return {
		"successes": successes,
		"failures": failures,
		"roll1": roll1,
		"roll2": roll2,
		"rerolls": rerolls,
		"stat_used": prep["chosen_stat"],
		"threshold": prep["threshold"],
		"k_bonus": prep["k_bonus"],
		"t_bonus": prep["t_bonus"],
		"critical": false,
		"crit_reward": "",
	}


#Counts one real use of a Knowledge, Tool or Circumstance; the estimators never call it.
static func _record_use(merc: MercenaryData, prefix: String, name: String) -> void:
	if merc == null or name == "":
		return
	var key: String = prefix + ":" + name
	merc.use_counts[key] = int(merc.use_counts.get(key, 0)) + 1


#Chance make_check would land at least `trial` successes, worked out without rolling or logging.
#A trial above the dice count can only be met by a critical success, so that is what it returns.
static func expected_success_chance(merc: MercenaryData, check_def: Dictionary, trial: int) -> float:
	var prep := _prepare(merc, check_def)
	if bool(prep["auto_fail"]):
		return 0.0
	var dice := int(prep["dice"])
	if trial > dice:
		return _crit_chance_of(prep)
	return _pool_tail(prep, trial)


#Unclamped threshold sum a check would use, 0.0 when a state auto-fails it; stage 5 halves it for retries.
static func threshold_for(merc: MercenaryData, check_def: Dictionary) -> float:
	var prep := _resolve_check(merc, check_def)
	if bool(prep["auto_fail"]):
		return 0.0
	return float(prep["raw"])


#Two results rolled apart: a lone critical wins, otherwise more successes; equal loses.
static func result_wins(mine: Dictionary, theirs: Dictionary) -> bool:
	var my_crit: bool = bool(mine.get("critical", false))
	var their_crit: bool = bool(theirs.get("critical", false))
	if my_crit != their_crit:
		return my_crit
	return int(mine["successes"]) > int(theirs["successes"])


#Both sides roll (b its own def when given): a lone critical wins, otherwise more successes; equal is a tie.
static func opposed_check(a: MercenaryData, b: MercenaryData, check_def: Dictionary,
		check_def_b: Dictionary = {}) -> Dictionary:
	var ra: Dictionary = make_check(a, check_def)
	var rb: Dictionary = make_check(b, check_def if check_def_b.is_empty() else check_def_b)
	var sa: int = int(ra["successes"])
	var sb: int = int(rb["successes"])
	var ca: bool = bool(ra["critical"])
	var cb: bool = bool(rb["critical"])
	var a_wins: bool = result_wins(ra, rb)
	var tie: bool = ca == cb and sa == sb
	return {"a": ra, "b": rb, "margin": sa - sb, "a_wins": a_wins, "tie": tie}


#Mean successes make_check would land: every die of the pool times its own chance, reroll folded in.
static func expected_successes(merc: MercenaryData, check_def: Dictionary) -> float:
	var prep: Dictionary = _prepare(merc, check_def)
	if bool(prep["auto_fail"]):
		return 0.0
	var p: float = float(prep["p"])
	var reroll: float = float(prep["reroll"])
	return float(int(prep["normal"])) * _die_chance(p, reroll) + float(int(prep["hard"])) * _die_chance(p * p, reroll)


#Chance a lands strictly more successes than b when both roll their own def; criticals are ignored.
static func opposed_win_chance(a: MercenaryData, def_a: Dictionary, b: MercenaryData,
		def_b: Dictionary) -> float:
	var pa: Dictionary = _prepare(a, def_a)
	if bool(pa["auto_fail"]):
		return 0.0
	var pb: Dictionary = _prepare(b, def_b)
	if bool(pb["auto_fail"]):
		return expected_success_chance(a, def_a, 1)
	var pmf_a := _pool_distribution(pa)
	var pmf_b := _pool_distribution(pb)
	var total := 0.0
	var b_below := 0.0
	for k: int in range(1, pmf_a.size()):
		if k <= pmf_b.size():
			b_below += pmf_b[k - 1]
		total += pmf_a[k] * clampf(b_below, 0.0, 1.0)
	return clampf(total, 0.0, 1.0)


#Chance every die of a check lands in the critical window, threshold - luck up to threshold.
#Test entry point; production crit estimates reach _crit_chance_of through expected_success_chance.
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
	var base_n := float(hi - lo + 1) / 100.0
	var base_h := (float(hi) / 100.0) * (float(hi) / 100.0) - (float(lo - 1) / 100.0) * (float(lo - 1) / 100.0)
	var eff_n := base_n + (1.0 - p) * reroll * base_n
	var eff_h := base_h + (1.0 - p * p) * reroll * base_h
	return clampf(pow(eff_n, float(int(prep["normal"]))) * pow(eff_h, float(int(prep["hard"]))), 0.0, 1.0)


#Threshold, normal and hard dice counts, reroll chance and luck a check would use, without rolling.
static func _prepare(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var prep := _resolve_check(merc, check_def)
	if bool(prep["auto_fail"]):
		return {"auto_fail": true, "threshold": 0.0, "dice": 1, "normal": 1, "hard": 0, "p": 0.0,
			"reroll": 0.0, "luck": 0.0}
	var chosen_stat: String = prep["chosen_stat"]
	var enhancements: int = prep["enhancements"]
	var flaws: int = prep["flaws"]
	var threshold: float = prep["threshold"]

	var stat_value := int(merc.stats.get(chosen_stat, 0)) + int(prep["dice_bonus"])
	var pool := _dice_pool(stat_value, enhancements, flaws)
	var hard := int(pool["hard"])
	var normal := mini(int(pool["normal"]), maxi(0, 64 - hard))
	var p := threshold / 100.0
	var reroll := clampf(float(merc.stats.get(_CONFIG.reroll_stat, 0.0)) / 100.0, 0.0, 1.0)
	return {"auto_fail": false, "threshold": threshold, "dice": normal + hard,
		"normal": normal, "hard": hard, "p": p, "reroll": reroll,
		"luck": float(merc.stats.get("luck", 0.0))}


#P(at least `trial` successes) over `n` independent dice each succeeding with chance `p`.
static func _binomial_tail(n: int, p: float, trial: int) -> float:
	if trial <= 0:
		return 1.0
	if trial > n:
		return 0.0
	var pmf := binomial_distribution(n, p)
	var total := 0.0
	for k: int in range(trial, n + 1):
		total += pmf[k]
	return clampf(total, 0.0, 1.0)


#Chance one die ends under the threshold once the reroll of a first failure is folded in.
static func _die_chance(p: float, reroll: float) -> float:
	return p + (1.0 - p) * reroll * p


#P(at least `trial` successes) over the mixed pool a prep describes, hard pair included.
static func _pool_tail(prep: Dictionary, trial: int) -> float:
	var normal := int(prep["normal"])
	var p := float(prep["p"])
	var reroll := float(prep["reroll"])
	var qn := _die_chance(p, reroll)
	if int(prep["hard"]) <= 0:
		return _binomial_tail(normal, qn, trial)
	var qh := _die_chance(p * p, reroll)
	return clampf(qh * _binomial_tail(normal, qn, trial - 1)
		+ (1.0 - qh) * _binomial_tail(normal, qn, trial), 0.0, 1.0)


#P(exactly k successes) for k = 0..dice over the mixed pool, the hard pair folded in last.
static func _pool_distribution(prep: Dictionary) -> Array[float]:
	var p := float(prep["p"])
	var reroll := float(prep["reroll"])
	var out := binomial_distribution(int(prep["normal"]), _die_chance(p, reroll))
	if int(prep["hard"]) <= 0:
		return out
	var qh := _die_chance(p * p, reroll)
	var mixed: Array[float] = []
	for k: int in range(out.size() + 1):
		var total := 0.0
		if k < out.size():
			total += out[k] * (1.0 - qh)
		if k > 0:
			total += out[k - 1] * qh
		mixed.append(clampf(total, 0.0, 1.0))
	return mixed


#P(exactly k successes) for k = 0..n over n independent dice each succeeding with chance p.
static func binomial_distribution(n: int, p: float) -> Array[float]:
	var out: Array[float] = []
	n = maxi(0, n)
	p = clampf(p, 0.0, 1.0)
	if n == 0:
		out.append(1.0)
		return out
	if p >= 1.0:
		for _k: int in range(n):
			out.append(0.0)
		out.append(1.0)
		return out
	var term := pow(1.0 - p, float(n))
	for k: int in range(n + 1):
		out.append(clampf(term, 0.0, 1.0))
		if k < n:
			term = term * float(n - k) / float(k + 1) * p / (1.0 - p)
	return out


#The success-count distribution a check would roll, the threshold it uses and its critical chance.
static func success_distribution(merc: MercenaryData, check_def: Dictionary) -> Dictionary:
	var prep := _prepare(merc, check_def)
	if bool(prep["auto_fail"]):
		return {"dice": 0, "threshold": 0.0, "crit": 0.0, "pmf": [1.0] as Array[float]}
	return {"dice": int(prep["dice"]), "threshold": float(prep["threshold"]),
		"crit": _crit_chance_of(prep), "pmf": _pool_distribution(prep)}


#Comma-joined unique state names for a state-mod log line.
static func states_text(states: Array) -> String:
	var seen: Array[String] = []
	for entry: Variant in states:
		var state_name := str(entry)
		if not seen.has(state_name):
			seen.append(state_name)
	return ",".join(seen)


static func _evaluate_formula(formula: String, merc: MercenaryData) -> float:
	var names: Array[String] = []
	for key in merc.stats:
		names.append(str(key))
	names.append("rand_factor")
	var cache_key := formula + "\n" + "\n".join(names)
	if not _expr_cache.has(cache_key):
		var new_expr := Expression.new()
		var err := new_expr.parse(formula, names)
		if err != OK:
			push_warning("CheckSystem: formula parse error: " + formula)
			return 0.0
		_expr_cache[cache_key] = {"expr": new_expr, "var_names": names}

	var cached: Dictionary = _expr_cache[cache_key]
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
	circumstance_display_names: Array[String],
	dice_bonus: int = 0
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
		var stat_value := int(merc.stats.get(sk, 0)) + dice_bonus
		var num_instances := maxi(1, stat_value)
		var p_base: float
		if stat_value <= 0:
			p_base = (threshold / 100.0) * (threshold / 100.0)
		else:
			p_base = threshold / 100.0
		var p_eff := _die_chance(p_base, p_reroll)
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
	var circ_display: String = _circumstance_name_for_stat(merc, stat_key, circumstance_display_names)
	if circ_display == "":
		return 0.0
	return CIRCUMSTANCE_BONUS + merc.circumstance_additional_bonus.get(circ_display, 0.0)


#The flagged Circumstance whose bonus this stat would use; "" when none of them names it.
static func _circumstance_name_for_stat(
	merc: MercenaryData,
	stat_key: String,
	circumstance_display_names: Array[String]
) -> String:
	var stat_display := stat_key.capitalize()
	for circ_display: String in circumstance_display_names:
		if not circ_display.ends_with("(" + stat_display + ")"):
			continue
		if merc.circumstance_flags.get(circ_display, false):
			return circ_display
	return ""


static func _roll_pair() -> Array[int]:
	var a := Dice.d100(forced_rolls)
	var b := Dice.d100(forced_rolls)
	return [mini(a, b), maxi(a, b)]


#A luck check def on one stat and its circumstances; the enhancements key is set only when nonzero.
static func luck_def(stat_key: String, circumstances: Array, enhancements: int = 0) -> Dictionary:
	var d: Dictionary = {"stat_keys": [stat_key], "circumstances": circumstances, "knowledges": [], "tools": [],
		"formula": "luck", "flat_threshold_bonus": 0.0}
	if enhancements != 0:
		d["enhancements"] = enhancements
	return d


#Grace (Dexterity) luck check, the side keeping out of sight.
static func grace_def(enhancements: int = 0) -> Dictionary:
	return luck_def("dexterity", [ConstCircumstances.GRACE_DEXTERITY], enhancements)


#Notice (Cognition) luck check, the watching side.
static func notice_def() -> Dictionary:
	return luck_def("cognition", [ConstCircumstances.NOTICE_COGNITION])

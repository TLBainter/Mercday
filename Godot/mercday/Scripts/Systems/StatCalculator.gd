class_name StatCalculator

#Stat token keys with no Stats.tsv row; warned once per key so dead tokens stay visible.
static var _dropped_keys: Dictionary = {}

#Core stats read their bonus through stat_bonus_X inside the Stats.tsv formula, never as flat.
const CORE_STATS: PackedStringArray = ["cognition", "dexterity", "vigor", "wile"]
#Pool max stat, penalty field, current field, floor, and whether the current pool is capped when the stat is absent.
const _POOL_ROWS: Array = [
	["maximum_hit_points", "max_hp_penalty", "current_hp", 1, true],
	["maximum_endurance_points", "max_ep_penalty", "current_ep", 1, false],
	["maximum_magic_points", "max_mp_penalty", "current_mp", 0, false],
]

#Circumstance var name -> display name; the insertion order is part of the cached var name list.
static var _circ_vars: Dictionary = {
	"grace":               ConstCircumstances.GRACE_DEXTERITY,
	"speech":              ConstCircumstances.SPEECH_WILE,
	"performance_wile":    ConstCircumstances.PERFORMANCE_WILE,
	"attack_dexterity":    ConstCircumstances.ATTACK_DEXTERITY,
	"attack_vigor":        ConstCircumstances.ATTACK_VIGOR,
	"athletics_vigor":     ConstCircumstances.ATHLETICS_VIGOR,
	"power_vigor":         ConstCircumstances.POWER_VIGOR,
	"search_cognition":    ConstCircumstances.SEARCH_COGNITION,
	"notice_cognition":    ConstCircumstances.NOTICE_COGNITION,
	"intuition_cognition": ConstCircumstances.INTUITION_COGNITION,
}

#Fixed var name order every cached Expression was parsed against; values are passed in this order.
static var _var_names: PackedStringArray = PackedStringArray()
#Var name -> index into the value array handed to Expression.execute.
static var _var_index: Dictionary = {}
#Stat var name -> parsed Expression; a formula that failed to parse is absent.
static var _expr_cache: Dictionary = {}
#Var names whose Stats.tsv Round cell is signed; a percent bonus on these scales the magnitude.
static var _signed_vars: Dictionary = {}
static var _cached_def_count: int = -1


#Snapshots the formula output so the next refresh can merge only what the change moved.
static func prime(merc: MercenaryData) -> void:
	if merc == null or merc.stats.is_empty():
		return
	merc.stats_baseline = calculate_all(merc)


#Adds a flat amount to one stat; the fold applies it before the multiplier.
static func add_flat(merc: MercenaryData, key: String, amount: float) -> void:
	if merc == null or key == "":
		return
	if merc.stats_baseline.is_empty():
		prime(merc)
	merc.stat_flat_bonuses[key] = float(merc.stat_flat_bonuses.get(key, 0.0)) + amount


#Sums a fractional multiplier; two +5% boosts store 0.10 and scale the computed value once.
static func add_percent(merc: MercenaryData, key: String, fraction: float) -> void:
	if merc == null or key == "":
		return
	if merc.stats_baseline.is_empty():
		prime(merc)
	merc.stat_multipliers[key] = float(merc.stat_multipliers.get(key, 0.0)) + fraction


#The single recalculation point; merges the formula change so direct merc.stats writes survive a later pass.
static func refresh(merc: MercenaryData) -> void:
	if merc == null:
		return
	var fresh: Dictionary = calculate_all(merc)
	#Glaive Rend holds a maximum HP penalty until furlough; the baseline carries it so it never stacks.
	for row: Array in _POOL_ROWS:
		var penalty: int = merc.get(row[1]) as int
		if penalty > 0 and fresh.has(row[0]):
			fresh[row[0]] = maxi(row[3] as int, int(fresh[row[0]]) - penalty)
	var base: Dictionary = merc.stats_baseline
	for key: String in fresh:
		if key == "level":
			continue
		if not merc.stats.has(key):
			merc.stats[key] = fresh[key]
			continue
		if not base.has(key):
			continue
		var delta: float = float(fresh[key]) - float(base[key])
		if is_zero_approx(delta):
			continue
		if merc.stats[key] is int:
			merc.stats[key] = int(merc.stats[key]) + int(round(delta))
		else:
			merc.stats[key] = float(merc.stats[key]) + delta
	merc.stats_baseline = fresh
	for row: Array in _POOL_ROWS:
		if not (row[4] as bool) and not merc.stats.has(row[0]):
			continue
		var cap: int = maxi(row[3] as int, int(merc.stats.get(row[0], 1)))
		if (merc.get(row[2]) as int) > cap:
			merc.set(row[2], cap)
	apply_ability_grants(merc)


#Drops the parsed formula cache; called when Stats.tsv is loaded so edited formulas take effect.
static func invalidate_cache() -> void:
	_cached_def_count = -1
	_expr_cache.clear()


#Reapplies granted movement and sight stats, which no Stats.tsv formula can reproduce.
static func apply_ability_grants(merc: MercenaryData) -> void:
	if merc == null:
		return
	var all_traits: Array[TraitData] = []
	all_traits.append_array(merc.perks)
	all_traits.append_array(merc.drawbacks)
	for trait_data: TraitData in all_traits:
		if trait_data == null or trait_data.effect_dsl == "" or trait_data.effect_dsl.begins_with("SPECIAL:"):
			continue
		for token: String in trait_data.effect_dsl.split("|"):
			var t: String = token.strip_edges()
			if t.begins_with("grant:ability:"):
				match t.substr("grant:ability:".length()):
					"flying_pace":   merc.stats["fly"] = 1.0
					"swimming_pace": merc.stats["swim"] = 1.0
					"climbing_pace": merc.stats["climb"] = 1.0
					"darksight":     merc.stats["darksight"] = 1.0
			elif t.begins_with("remove:ability:"):
				match t.substr("remove:ability:".length()):
					"walking_pace":  merc.stats["walk"] = 0.0
					"flying_pace":   merc.stats["fly"] = 0.0
					"swimming_pace": merc.stats["swim"] = 0.0
					"climbing_pace": merc.stats["climb"] = 0.0


#Adds the flat bonuses then scales by the summed multipliers; the factor never goes below zero.
static func _fold(merc: MercenaryData, var_name: String, value: float, folded: Dictionary) -> float:
	if not merc.stat_flat_bonuses.has(var_name) and not merc.stat_multipliers.has(var_name):
		return value
	folded[var_name] = true
	var flat: float = float(merc.stat_flat_bonuses.get(var_name, 0.0))
	var mult: float = float(merc.stat_multipliers.get(var_name, 0.0))
	var base: float = value + flat
	#A signed stat can sit below zero, so the bonus scales the magnitude and always helps.
	if base < 0.0 and _signed_vars.has(var_name):
		return base * maxf(0.0, 1.0 - mult)
	return base * maxf(0.0, 1.0 + mult)


#Parses every Stats.tsv formula once against a fixed var name order and reuses the Expression.
static func _ensure_cache() -> void:
	if _cached_def_count == DataManager.stat_definitions.size():
		return
	_cached_def_count = DataManager.stat_definitions.size()
	_expr_cache.clear()
	_signed_vars.clear()
	for stat_def: Dictionary in DataManager.stat_definitions:
		if str(stat_def["round"]) == "signed":
			_signed_vars[str(stat_def["var_name"])] = true
	var seeds: Array[String] = ["size", "level", "max_cognition", "max_dexterity", "max_vigor", "max_wile", "luck_roll"]
	for core: String in CORE_STATS:
		seeds.append("stat_bonus_" + core)
	for circ_var_name: String in _circ_vars:
		seeds.append(circ_var_name)
	seeds.append_array(["wile_circumstance_count", "object_size", "object_weight"])
	var names: Array[String] = []
	names.append_array(seeds)
	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = stat_def["var_name"]
		if not names.has(var_name):
			names.append(var_name)
	_var_names = PackedStringArray(names)
	_var_index = {}
	for i: int in range(_var_names.size()):
		_var_index[_var_names[i]] = i
	#Encumbrance reads weight_limit while pace, dodge and action points are computed, so it must come first.
	var weight_idx: int = int(_var_index.get("weight_limit", -1))
	for later_name: String in ["pace", "dodge", "action_points"]:
		if _var_index.has(later_name) and weight_idx > int(_var_index[later_name]):
			push_error("StatCalculator: Stats.tsv orders weight_limit after %s" % later_name)
	for stat_def: Dictionary in DataManager.stat_definitions:
		var stat_type: String = stat_def["type"]
		if stat_type == "ancestry" or stat_type == "level":
			continue
		var expr := Expression.new()
		if expr.parse(str(stat_def["formula"]), _var_names) != OK:
			push_error("StatCalculator: failed to parse formula '%s' for stat '%s': %s"
				% [stat_def["formula"], stat_def["stat"], expr.get_error_text()])
			continue
		_expr_cache[str(stat_def["var_name"])] = expr


static func calculate_all(merc: MercenaryData) -> Dictionary:
	_ensure_cache()
	var vars: Dictionary = {}
	for name: String in _var_names:
		vars[name] = 0.0
	var folded: Dictionary = {}
	var carried: int = Encumbrance.carried_weight(merc)
	var held_bonuses: Dictionary = WeaponArmorPerkLibrary.held_stat_bonuses(merc)

	#Level is stored in merc.stats, so the folded value feeds the formulas and the raw one is returned.
	var raw_level: float = float(merc.stats.get("level", 0))
	_seed_vars(merc, vars, folded, raw_level)
	var values: Array = vars.values()
	_run_formula_loop(merc, vars, values, folded, carried, held_bonuses)
	_sweep_leftovers(merc, vars, folded)
	vars["level"] = raw_level
	return vars


#Seeds the ancestry, level, core bonus and circumstance vars, folding each through the token stores.
static func _seed_vars(merc: MercenaryData, vars: Dictionary, folded: Dictionary,
		raw_level: float) -> void:
	vars["size"] = _fold(merc, "size", float(merc.max_stats.get("size", 0)), folded)
	vars["level"] = _fold(merc, "level", raw_level, folded)
	for core: String in CORE_STATS:
		var max_key: String = "max_" + core
		vars[max_key] = _fold(merc, max_key, float(merc.max_stats.get(max_key, 0)), folded)
	vars["luck_roll"] = _fold(merc, "luck_roll", float(merc.luck_roll), folded)

	for core: String in CORE_STATS:
		vars["stat_bonus_" + core] = float(merc.stat_bonuses.get(core, 0.0))

	for circ_var_name: String in _circ_vars:
		var display: String = _circ_vars[circ_var_name]
		var circ_value: float = 0.0
		if merc.circumstance_flags.get(display, false):
			circ_value = 15.0 + float(merc.circumstance_additional_bonus.get(display, 0.0))
		vars[circ_var_name] = _fold(merc, circ_var_name, circ_value, folded)

	var wile_count: int = 0
	for display_name: String in merc.circumstance_flags:
		if merc.circumstance_flags[display_name]:
			if str((ConstCircumstances.DATA.get(display_name, {}) as Dictionary).get("stat", "")) == "Wile":
				wile_count += 1
	vars["wile_circumstance_count"] = _fold(merc, "wile_circumstance_count", float(wile_count), folded)
	vars["object_size"] = _fold(merc, "object_size", 0.0, folded)
	vars["object_weight"] = _fold(merc, "object_weight", 0.0, folded)


#Runs every Stats.tsv formula in row order, then clamps, encumbers and adds the held gear bonus.
static func _run_formula_loop(merc: MercenaryData, vars: Dictionary, values: Array,
		folded: Dictionary, carried: int, held_bonuses: Dictionary) -> void:
	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = stat_def["var_name"]
		var stat_type: String = stat_def["type"]
		var round_mode: String = stat_def["round"]

		#ancestry and level stats are pre-seeded; evaluating the formula would overwrite them.
		if stat_type == "ancestry" or stat_type == "level":
			continue

		var idx: int = _var_index[var_name]
		var expr: Expression = _expr_cache.get(var_name, null)
		if expr == null:
			_set_var(vars, values, idx, var_name, 0.0)
			continue

		var raw: Variant = expr.execute(values)
		if expr.has_execute_failed():
			push_error("StatCalculator: failed to execute formula '%s' for stat '%s'" % [stat_def["formula"], stat_def["stat"]])
			_set_var(vars, values, idx, var_name, 0.0)
			continue

		var value: float = _fold(merc, var_name, float(raw), folded)
		if stat_type == "core" and vars.has("max_" + var_name):
			value = clampf(value, 0.0, float(vars["max_" + var_name]))
		#Carried weight bites after the fold, so a percent bonus never scales the penalty away.
		value = _encumber(vars, var_name, value, carried)
		#A drawn weapon's passive bonus rides on top; holstering it takes the bonus back off.
		value += float(held_bonuses.get(var_name, 0))

		if round_mode == "floor":
			var int_val: int = int(floor(value))
			if stat_type != "boolean":
				int_val = max(0, int_val)
			_set_var(vars, values, idx, var_name, int_val)
		elif round_mode == "signed":
			#signed keeps the folded value as is: no rounding and no clamp at 0.
			_set_var(vars, values, idx, var_name, value)
		else:
			if round_mode == "ceil":
				value = ceil(value)
			if stat_type != "boolean":
				value = max(0.0, value)
			_set_var(vars, values, idx, var_name, value)


#Folds the flat and multiplier keys the formula loop never produced.
static func _sweep_leftovers(merc: MercenaryData, vars: Dictionary, folded: Dictionary) -> void:
	for key: String in merc.stat_flat_bonuses:
		_fold_leftover(merc, vars, folded, key)
	for key: String in merc.stat_multipliers:
		_fold_leftover(merc, vars, folded, key)


#The one paired write, so the vars dictionary and the values array cannot drift apart.
static func _set_var(vars: Dictionary, values: Array, idx: int, name: String, value: Variant) -> void:
	vars[name] = value
	values[idx] = float(value)


#Subtracts the encumbrance penalty from pace, dodge and action points; other stats pass through.
static func _encumber(vars: Dictionary, var_name: String, value: float, carried: int) -> float:
	if var_name != "pace" and var_name != "dodge" and var_name != "action_points":
		return value
	var pen: Dictionary = Encumbrance.penalties_for(carried, int(vars["weight_limit"]))
	var out: float = value - float(pen[var_name])
	if var_name == "pace":
		return maxf(out, float(Encumbrance.PACE_FLOOR))
	if var_name == "action_points":
		return maxf(out, float(Encumbrance.ACTION_POINTS_FLOOR))
	return out


#Folds a key the formula loop never produced, or reports it once when no Stats.tsv row owns it.
static func _fold_leftover(merc: MercenaryData, vars: Dictionary, folded: Dictionary, key: String) -> void:
	if folded.has(key):
		return
	if vars.has(key):
		vars[key] = _fold(merc, key, float(vars[key]), folded)
		return
	folded[key] = true
	if _dropped_keys.has(key):
		return
	_dropped_keys[key] = true
	push_warning("StatCalculator: stat token key '%s' has no Stats.tsv row; dropped" % key)


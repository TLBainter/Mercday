class_name StatCalculator

#Stat token keys with no Stats.tsv row; warned once per key so dead tokens stay visible.
static var _dropped_keys: Dictionary = {}

#Non core merc.stat_bonuses keys folded as flat; warned once so un-migrated callers stay visible.
static var _legacy_keys: Dictionary = {}

#Core stats read their bonus through stat_bonus_X inside the Stats.tsv formula, never as flat.
const CORE_STATS: PackedStringArray = ["cognition", "dexterity", "vigor", "wile"]
static var _core_set: Dictionary = _build_core_set()
#True while the merc being calculated holds a non core merc.stat_bonuses key.
static var _legacy_any: bool = false

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


#The single recalculation point; merges the formula change so direct merc.stats writes survive.
static func refresh(merc: MercenaryData) -> void:
	if merc == null:
		return
	var fresh: Dictionary = calculate_all(merc)
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


#Legacy channel for callers that still write merc.stat_bonuses for a non core stat.
static func _legacy_flat(merc: MercenaryData, var_name: String) -> float:
	if not _legacy_any or _core_set.has(var_name):
		return 0.0
	var legacy: float = float(merc.stat_bonuses.get(var_name, 0.0))
	if legacy != 0.0 and not _legacy_keys.has(var_name):
		_legacy_keys[var_name] = true
		push_warning("StatCalculator: '%s' still writes merc.stat_bonuses; use add_flat" % var_name)
	return legacy


#Adds the flat bonuses then scales by the summed multipliers; the factor never goes below zero.
static func _fold(merc: MercenaryData, var_name: String, value: float, folded: Dictionary) -> float:
	var legacy: float = _legacy_flat(merc, var_name)
	if legacy == 0.0 and not merc.stat_flat_bonuses.has(var_name) and not merc.stat_multipliers.has(var_name):
		return value
	folded[var_name] = true
	var flat: float = float(merc.stat_flat_bonuses.get(var_name, 0.0)) + legacy
	var mult: float = float(merc.stat_multipliers.get(var_name, 0.0))
	return (value + flat) * maxf(0.0, 1.0 + mult)


#Parses every Stats.tsv formula once against a fixed var name order and reuses the Expression.
static func _ensure_cache() -> void:
	if _cached_def_count == DataManager.stat_definitions.size():
		return
	_cached_def_count = DataManager.stat_definitions.size()
	_expr_cache.clear()
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
	_legacy_any = false
	for legacy_key: String in merc.stat_bonuses:
		if not _core_set.has(legacy_key):
			_legacy_any = true
			break
	var vars: Dictionary = {}
	for name: String in _var_names:
		vars[name] = 0.0
	var folded: Dictionary = {}

	#Level is stored in merc.stats, so the folded value feeds the formulas and the raw one is returned.
	var raw_level: float = float(merc.stats.get("level", 0))
	vars["size"] = _fold(merc, "size", float(merc.max_stats.get("size", 0)), folded)
	vars["level"] = _fold(merc, "level", raw_level, folded)
	vars["max_cognition"] = _fold(merc, "max_cognition", float(merc.max_stats.get("max_cognition", 0)), folded)
	vars["max_dexterity"] = _fold(merc, "max_dexterity", float(merc.max_stats.get("max_dexterity", 0)), folded)
	vars["max_vigor"] = _fold(merc, "max_vigor", float(merc.max_stats.get("max_vigor", 0)), folded)
	vars["max_wile"] = _fold(merc, "max_wile", float(merc.max_stats.get("max_wile", 0)), folded)
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

	var values: Array = vars.values()
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
			vars[var_name] = 0.0
			values[idx] = 0.0
			continue

		var raw: Variant = expr.execute(values)
		if expr.has_execute_failed():
			push_error("StatCalculator: failed to execute formula '%s' for stat '%s'" % [stat_def["formula"], stat_def["stat"]])
			vars[var_name] = 0.0
			values[idx] = 0.0
			continue

		var value: float = _fold(merc, var_name, float(raw), folded)
		if stat_type == "core" and vars.has("max_" + var_name):
			value = clampf(value, 0.0, float(vars["max_" + var_name]))

		if round_mode == "floor":
			var int_val: int = int(floor(value))
			if stat_type != "boolean":
				int_val = max(0, int_val)
			vars[var_name] = int_val
			values[idx] = float(int_val)
		else:
			if round_mode == "ceil":
				value = ceil(value)
			if stat_type != "boolean":
				value = max(0.0, value)
			vars[var_name] = value
			values[idx] = value

	for key: String in merc.stat_flat_bonuses:
		_fold_leftover(merc, vars, folded, key)
	for key: String in merc.stat_multipliers:
		_fold_leftover(merc, vars, folded, key)

	#TODO: armor weight encumbrance penalty is not applied yet; Weight Limit exists as a stat

	vars["level"] = raw_level
	return vars


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

#CORE_STATS as a set, so the four names are written once.
static func _build_core_set() -> Dictionary:
	var out: Dictionary = {}
	for core: String in CORE_STATS:
		out[core] = true
	return out


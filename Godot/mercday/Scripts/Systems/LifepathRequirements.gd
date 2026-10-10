class_name LifepathRequirements

#Folds a lifepath's requirements left to right; each entry's conj joins it to the next, no precedence.
#A contract run supplies the facts for every subject except State Immune, Age, the stat subjects,
#Knowledge, Lifepath and Weapon Perk Count.

#Check kinds that exist without a Stats.tsv row; a contract check also records under every
#team.<stat> its event's Success Formula names, so any stat var name is a check token too.
const CHECK_STATS: Array[String] = ["cheat_death", "resist", "reroll", "avoid_aoe"]
const ITEM_TYPES: Array[String] = ["ranged", "melee", "thrown"]
const OPS: Array[String] = ["IS", "IS NOT", "IS >=", "ONE OF", "CONTAINS", "HAS TAG"]
#Subjects read straight off merc.stats; the value cell is the number the operator compares against.
const STAT_SUBJECTS: Dictionary = {
	"WIL": "wile",
	"CGN": "cognition",
	"Level": "level",
	"Speed": "speed",
	"Max HP": "maximum_hit_points",
}
const HOME_TOKEN: String = "[MERC HOME]"
const ENVIRON_TOKEN: String = "[ENVIRON]"
const TYPE_TOKEN: String = "[Type]"
const BASE_SUBJECTS: Array[String] = ["State Immune", "Contract Success", "Contract Type",
	"Contract Location", "Contract Event", "Merc Relationship", "Betrayer Relationship", "Succeeded Check",
	"Success Count", "Failed Check", "Dead Mercs", "Damage Dealt", "Used Item Type",
	"Surviving Mercs", "Knowledge Count",
	"Has Knowledge", "Lifepath", "Weapon Perk Count", "Damage Taken", "Damage Type",
	"Reroll", "Target Creature", "Target Failed Check", "State Inflicted", "Count", "Age"]
#Every subject a requirement cell may name; the stat subjects are added from STAT_SUBJECTS.
static var SUBJECTS: Array[String] = _all_subjects()

#The three age bands merc.age_category may hold; MercGenerator writes it once at generation.
const AGE_VALUES: Array[String] = ["young", "adult", "elder"]

#Stats.tsv var names, filled on first use; stays empty until DataManager has loaded the table.
static var _stat_tokens: Dictionary = {}


static func _all_subjects() -> Array[String]:
	var out: Array[String] = BASE_SUBJECTS.duplicate()
	for subject: String in STAT_SUBJECTS:
		out.append(subject)
	return out


static func allows(merc: MercenaryData, lp: LifepathData, run: ContractRun = null) -> bool:
	if lp == null or lp.requirements.is_empty():
		return true
	var ctx: Dictionary = {"run": run, "stat": ""}
	var result: bool = _evaluate(merc, lp.requirements[0], ctx)
	var pending: String = str(lp.requirements[0].get("conj", ""))
	for i: int in range(1, lp.requirements.size()):
		var entry: Dictionary = lp.requirements[i]
		var value: bool = _evaluate(merc, entry, ctx)
		if pending == "OR":
			result = result or value
		else:
			result = result and value
		pending = str(entry.get("conj", ""))
	return result


static func filter(merc: MercenaryData, pool: Array, run: ContractRun = null) -> Array:
	var out: Array = []
	for entry in pool:
		if not (entry is LifepathData):
			continue
		if allows(merc, entry, run):
			out.append(entry)
	return out


#True when every requirement names a subject, operator and value this code can actually answer.
static func is_supported(lp: LifepathData) -> bool:
	if lp == null:
		return false
	for entry: Dictionary in lp.requirements:
		var subject: String = str(entry.get("subject", ""))
		if not SUBJECTS.has(subject):
			return false
		if _blank(entry):
			continue
		if not _value_supported(subject, _op(entry), str(entry.get("value", ""))):
			return false
	return true


#A blank operator cell means IS.
static func _op(entry: Dictionary) -> String:
	var op: String = str(entry.get("op", "")).strip_edges()
	return "IS" if op == "" else op


#A row with no operator and no value states nothing, so it neither passes nor blocks.
static func _blank(entry: Dictionary) -> bool:
	return str(entry.get("op", "")).strip_edges() == "" \
		and str(entry.get("value", "")).strip_edges() == ""


static func _compare_int(have: int, op: String, want: int) -> bool:
	match op:
		"IS":
			return have == want
		"IS NOT":
			return have != want
		"IS >=":
			return have >= want
	return false


static func _value_supported(subject: String, op: String, value: String) -> bool:
	if not OPS.has(op) or value.contains(" OR ") or value.contains(" AND "):
		return false
	if value.contains("[") and not _bracket_allowed(subject, value):
		return false
	if STAT_SUBJECTS.has(subject):
		return value.is_valid_int()
	match subject:
		"State Immune":
			return op == "IS" or op == "IS NOT"
		"Age":
			if op != "IS" and op != "IS NOT":
				return false
			return AGE_VALUES.has(value.strip_edges().to_lower())
		"Contract Success":
			return _is_bool(value)
		"Contract Type", "Contract Event", "Contract Location":
			return value != ""
		"Merc Relationship", "Betrayer Relationship", "Dead Mercs", "Surviving Mercs":
			return value.is_valid_int()
		"Succeeded Check":
			return _all_check_tokens(value)
		"Failed Check":
			if op == "IS >=":
				return value.is_valid_int()
			return _is_bool(value) or _all_check_tokens(value)
		"Success Count":
			return value.is_valid_int() or _all_check_tokens(value)
		"Damage Dealt":
			if StateTokens.normalize_token(value) == "tolerance":
				return true
			if value.begins_with("self."):
				return value.length() > 5
			return value.is_valid_int()
		"Used Item Type":
			return _all_tokens_in(value, ITEM_TYPES)
		"Knowledge Count", "Weapon Perk Count", "Count":
			return value.is_valid_int()
		"Has Knowledge":
			return (op == "IS" or op == "ONE OF") and value != ""
		"Lifepath":
			return op == "IS" and value != ""
		"Damage Taken":
			if _is_damage_type(value):
				return op == "IS" or op == "CONTAINS"
			if StateTokens.normalize_token(value) == "tolerance":
				return op == "IS >="
			return value.is_valid_int()
		"Damage Type":
			return (op == "IS" or op == "CONTAINS") and _is_damage_type(value)
		"Reroll":
			return op == "IS" and StateTokens.normalize_token(value) == "success"
		"Target Creature":
			if value == TYPE_TOKEN:
				return true
			return (op == "HAS TAG" or op == "IS") and value != ""
		"Target Failed Check":
			return op == "IS" and _all_check_tokens(value)
		"State Inflicted":
			return op == "IS" and ConstStates.state_from_token(value) != ""
	return false


#The only bracketed values the sheet may write; every other "[" is an unresolved placeholder.
static func _bracket_allowed(subject: String, value: String) -> bool:
	if subject == "Contract Location":
		return value == HOME_TOKEN or value == ENVIRON_TOKEN
	return subject == "Target Creature" and value == TYPE_TOKEN


static func _is_damage_type(value: String) -> bool:
	var wanted: String = StateTokens.normalize_token(value)
	if wanted == "":
		return false
	for type_name: String in DataManager.type_columns.get("DAMAGES", []) as Array:
		if StateTokens.normalize_token(type_name) == wanted:
			return true
	return false


static func _is_bool(value: String) -> bool:
	var v := value.strip_edges().to_lower()
	return v == "true" or v == "false"


static func _is_check_token(token: String) -> bool:
	if token == "":
		return false
	if TraitRuntime.CORE_STATS.has(token) or CHECK_STATS.has(token):
		return true
	if _stat_tokens.is_empty():
		for stat_def: Dictionary in DataManager.stat_definitions:
			_stat_tokens[String(stat_def["var_name"])] = true
	return _stat_tokens.has(token)


static func _all_check_tokens(value: String) -> bool:
	var tokens := _tokens(value)
	if tokens.is_empty():
		return false
	for t: String in tokens:
		if not _is_check_token(t):
			return false
	return true


static func _all_tokens_in(value: String, allowed: Array[String]) -> bool:
	var tokens := _tokens(value)
	if tokens.is_empty():
		return false
	for t: String in tokens:
		if not allowed.has(t):
			return false
	return true


static func _tokens(value: String) -> Array[String]:
	var out: Array[String] = []
	for raw: String in value.split(","):
		var t := StateTokens.normalize_token(raw)
		if t != "":
			out.append(t)
	return out


static func _run(ctx: Dictionary) -> ContractRun:
	return ctx.get("run", null) as ContractRun


static func _evaluate(merc: MercenaryData, entry: Dictionary, ctx: Dictionary) -> bool:
	if _blank(entry):
		return true
	var subject: String = str(entry.get("subject", ""))
	var value: String = str(entry.get("value", ""))
	var op: String = _op(entry)
	if STAT_SUBJECTS.has(subject):
		return _compare_int(int(merc.stats.get(str(STAT_SUBJECTS[subject]), 0)), op, value.to_int())
	match subject:
		"State Immune":
			return _state_immune(merc, op, value)
		"Age":
			return _age_matches(merc, op, value)
		"Contract Success":
			return _contract_success(ctx) == (value.strip_edges().to_lower() == "true")
		"Contract Type":
			var crun := _run(ctx)
			if crun == null or crun.contract == null:
				return false
			return StateTokens.normalize_token(crun.contract.contract_type) \
				== StateTokens.normalize_token(value)
		"Contract Location":
			return _contract_location(merc, ctx, value)
		"Contract Event":
			return _contract_event(ctx, value, merc)
		"Merc Relationship":
			return _compare_int(_best_relationship(merc, ctx), op, value.to_int())
		"Betrayer Relationship":
			return _betrayer_relationship(merc, op, value, ctx)
		"Succeeded Check":
			return _succeeded_check(merc, value, ctx)
		"Success Count":
			return _success_count(merc, value, ctx)
		"Failed Check":
			return _failed_check(merc, op, value)
		"Dead Mercs":
			var drun := _run(ctx)
			return drun != null and _compare_int(drun.casualties.size(), op, value.to_int())
		"Surviving Mercs":
			var srun := _run(ctx)
			return srun != null and _compare_int(srun.living_team().size(), op, value.to_int())
		"Damage Dealt":
			return _damage_dealt(merc, op, value)
		"Used Item Type":
			for t: String in _tokens(value):
				if LifepathTally.damage_met_tolerance(merc, t):
					return true
			return false
		"Knowledge Count":
			return _compare_int(merc.knowledges.size(), op, value.to_int())
		"Has Knowledge":
			return _has_knowledge(merc, value)
		"Lifepath":
			return LifepathProgression.has_event(merc, value)
		"Weapon Perk Count":
			return _compare_int(merc.weapon_perks.size(), op, value.to_int())
		"Damage Taken":
			return _damage_taken(merc, op, value)
		"Damage Type":
			return LifepathTally.took_damage_type(merc, value)
		"Reroll":
			return LifepathTally.succeeded(merc, "reroll")
		"Target Creature":
			return _target_creature(ctx, op, value)
		"Target Failed Check":
			for t: String in _tokens(value):
				if LifepathTally.target_failed(t):
					return true
			return false
		"State Inflicted":
			return _state_inflicted(merc, value, ctx)
		"Count":
			var state_key: String = str(ctx.get("state", ""))
			if state_key == "":
				return false
			return _compare_int(LifepathTally.inflicted_count(merc, state_key), op, value.to_int())
	return true


static func _age_matches(merc: MercenaryData, op: String, value: String) -> bool:
	var have: String = merc.age_category.to_lower() if merc != null else ""
	if have == "":
		return false
	var same: bool = have == value.strip_edges().to_lower()
	if op == "IS NOT":
		return not same
	return same


static func _state_immune(merc: MercenaryData, op: String, value: String) -> bool:
	var state_name: String = ConstStates.state_from_token(value)
	if state_name == "":
		push_warning("Lifepaths.tsv: State Immune value %s names no state" % value)
		state_name = value
	var immune: bool = ConstStates.is_immune(merc, state_name)
	match op:
		"IS":
			return immune
		"IS NOT":
			return not immune
	return false


static func _contract_success(ctx: Dictionary) -> bool:
	var run := _run(ctx)
	return run != null and run.verdict == "Succeeded"


#Reads outcomes, then team marks, then the merc's own marks; a matched Competition outcome leaves its
#best rounds_won in ctx so a following Success Count entry scores the wins.
static func _contract_event(ctx: Dictionary, value: String, merc: MercenaryData = null) -> bool:
	var run := _run(ctx)
	if run == null:
		return false
	var wanted := _tokens(value)
	var found := false
	var competition_seen := false
	var best_wins := 0
	for outcome: Dictionary in run.outcomes:
		var event_key := StateTokens.normalize_token(str(outcome.get("event", "")))
		if not wanted.has(event_key):
			continue
		found = true
		if event_key == "competition":
			var wins := int(outcome.get("rounds_won", 0))
			best_wins = maxi(best_wins, wins) if competition_seen else wins
			competition_seen = true
	if competition_seen:
		ctx["competition_wins"] = best_wins
	for mark: String in run.event_marks:
		if wanted.has(StateTokens.normalize_token(mark)):
			found = true
	if merc != null:
		for mark in run.merc_marks.get(merc, []):
			if wanted.has(StateTokens.normalize_token(str(mark))):
				found = true
	return found


#Type, name and resolved environment of a location; the words a sheet cell may name it by.
static func _location_tokens(loc: LocationData) -> Array[String]:
	var out: Array[String] = []
	if loc == null:
		return out
	for raw: String in [loc.location_type, loc.location_name, environment_of(loc)]:
		var t := StateTokens.normalize_token(raw)
		if t != "" and not out.has(t):
			out.append(t)
	return out


#A blank Environment cell borrows the parent's, so a settlement inherits its country's when unset.
static func environment_of(loc: LocationData) -> String:
	var node: LocationData = loc
	while node != null:
		if node.environment.strip_edges() != "":
			return node.environment
		node = node.parent
	return ""


static func _contract_location(merc: MercenaryData, ctx: Dictionary, value: String) -> bool:
	var run := _run(ctx)
	if run == null or run.location == null:
		return false
	if value == HOME_TOKEN:
		return _is_merc_home(merc, run.location)
	if value == ENVIRON_TOKEN:
		return environment_of(run.location) != ""
	return _location_tokens(run.location).has(StateTokens.normalize_token(value))


#True when the contract sits on the merc's home or on anything the home answers to.
static func _is_merc_home(merc: MercenaryData, loc: LocationData) -> bool:
	if merc == null or merc.starting_location == null or loc == null:
		return false
	var node: LocationData = merc.starting_location
	while node != null:
		if node.location_name == loc.location_name:
			return true
		node = node.parent
	return false


static func _has_knowledge(merc: MercenaryData, value: String) -> bool:
	var wanted := _tokens(value)
	for k: UtilityTraitData in merc.knowledges:
		if k != null and wanted.has(StateTokens.normalize_token(k.utility_name)):
			return true
	return false


#Tolerance keeps the old per-hit meaning; a number or a self.<stat> reads the contract total.
static func _damage_dealt(merc: MercenaryData, op: String, value: String) -> bool:
	if StateTokens.normalize_token(value) == "tolerance":
		return LifepathTally.damage_met_tolerance(merc, "")
	var want: int = 0
	if value.begins_with("self."):
		want = int(merc.stats.get(StateTokens.normalize_token(value.substr(5)), 0))
	elif value.is_valid_int():
		want = value.to_int()
	else:
		return false
	return _compare_int(LifepathTally.damage_dealt_total(merc), op, want)


static func _damage_taken(merc: MercenaryData, op: String, value: String) -> bool:
	if _is_damage_type(value):
		return LifepathTally.took_damage_type(merc, value)
	if StateTokens.normalize_token(value) == "tolerance":
		return LifepathTally.damage_taken_max(merc) >= int(merc.stats.get("tolerance", 0))
	if not value.is_valid_int():
		return false
	return _compare_int(LifepathTally.damage_taken_total(merc), op, value.to_int())


static func _target_creature(ctx: Dictionary, op: String, value: String) -> bool:
	var run := _run(ctx)
	if run == null:
		return false
	var tags: Array = run.target_record.get("tags", []) as Array
	if value == TYPE_TOKEN:
		for creature: String in DataManager.type_columns.get("CREATURES", []) as Array:
			if tags.has(StateTokens.normalize_token(creature)):
				return true
		return false
	if op != "HAS TAG" and op != "IS":
		return false
	return tags.has(StateTokens.normalize_token(value))


#Remembers the state named here so a following Count entry scores that same state.
static func _state_inflicted(merc: MercenaryData, value: String, ctx: Dictionary) -> bool:
	var key := StateTokens.normalize_token(value)
	if LifepathTally.inflicted_count(merc, key) <= 0:
		return false
	ctx["state"] = key
	return true


#The strongest feeling this merc holds toward anyone still on the team.
static func _best_relationship(merc: MercenaryData, ctx: Dictionary) -> int:
	var run := _run(ctx)
	if run == null:
		return -1
	var best := -1
	for other: MercenaryData in run.team:
		best = maxi(best, RelationshipSystem.value(merc, other))
	return best


#The strongest feeling this merc held toward any merc that switched sides this contract, dead or alive.
static func _betrayer_relationship(merc: MercenaryData, op: String, value: String, ctx: Dictionary) -> bool:
	var run := _run(ctx)
	if run == null:
		return false
	var found: bool = false
	var best: int = -1
	for betrayer: MercenaryData in run.betrayers:
		if betrayer == null or betrayer == merc:
			continue
		found = true
		best = maxi(best, RelationshipSystem.value(merc, betrayer))
	if not found:
		return false
	return _compare_int(best, op, value.to_int())


#Remembers the stat named here so a following Success Count entry scores that same stat.
static func _succeeded_check(merc: MercenaryData, value: String, ctx: Dictionary) -> bool:
	var tokens := _tokens(value)
	var hit := ""
	for t: String in tokens:
		if LifepathTally.succeeded(merc, t):
			hit = t
			break
	if hit != "":
		ctx["stat"] = hit
	elif not tokens.is_empty():
		ctx["stat"] = tokens[0]
	return hit != ""


static func _success_count(merc: MercenaryData, value: String, ctx: Dictionary) -> bool:
	var need: int = value.to_int() if value.is_valid_int() \
		else int(merc.stats.get(StateTokens.normalize_token(value), 0))
	var have: int = 0
	if ctx.has("competition_wins"):
		have = int(ctx["competition_wins"])
	else:
		var stat: String = str(ctx.get("stat", ""))
		have = LifepathTally.success_count(merc, stat) if stat != "" \
			else LifepathTally.best_success_count(merc)
	return have >= need


static func _failed_check(merc: MercenaryData, op: String, value: String) -> bool:
	if op == "IS >=":
		return LifepathTally.failure_count(merc) >= value.to_int()
	if _is_bool(value):
		return LifepathTally.failed_any(merc) == (value.strip_edges().to_lower() == "true")
	for t: String in _tokens(value):
		if LifepathTally.failed_stat(merc, t):
			return true
	return false

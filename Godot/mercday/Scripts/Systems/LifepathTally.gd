class_name LifepathTally

#Per-contract facts about each merc that lifepath requirements read when the contract ends.
#Keyed by merc_uid, so enemies, which carry no campaign identity, are never tallied.

static var _data: Dictionary = {}
#Facts about the contract's assigned target, which has no merc_uid of its own.
static var _target: Dictionary = {"failed": {}}


static func clear() -> void:
	_data.clear()
	_target = {"failed": {}}


static func begin_contract(run: ContractRun) -> void:
	clear()
	if run == null:
		return
	for merc: MercenaryData in run.team:
		_rec(merc)


static func _rec(merc: MercenaryData) -> Dictionary:
	if merc == null or merc.merc_uid <= 0:
		return {}
	if not _data.has(merc.merc_uid):
		_data[merc.merc_uid] = {
			"passed": {},
			"failed": {},
			"failures": 0,
			"damage": {},
			"dealt_total": 0,
			"taken_total": 0,
			"taken_max": 0,
			"taken_types": {},
			"inflicted": {},
		}
	return _data[merc.merc_uid] as Dictionary


#The record a read wants; a merc with no record yet reports an empty Dictionary and gains none.
static func _read(merc: MercenaryData) -> Dictionary:
	if merc == null or merc.merc_uid <= 0:
		return {}
	return _data.get(merc.merc_uid, {}) as Dictionary


#A passed check stores the best success count for that stat; a named kind (resist, cheat_death) skips the failures total.
static func record_check(merc: MercenaryData, stat: String, successes: int, passed: bool,
		counts_as_failure: bool = true) -> void:
	var rec := _rec(merc)
	if rec.is_empty():
		return
	var key := StateTokens.normalize_token(stat)
	if passed:
		var by_stat: Dictionary = rec["passed"]
		by_stat[key] = maxi(int(by_stat.get(key, 0)), successes)
		return
	var failed: Dictionary = rec["failed"]
	failed[key] = int(failed.get(key, 0)) + 1
	if counts_as_failure:
		rec["failures"] = int(rec["failures"]) + 1


static func record_cheat_death(merc: MercenaryData, successes: int, passed: bool) -> void:
	record_check(merc, "cheat_death", successes, passed, false)


static func record_damage(merc: MercenaryData, amount: int, tolerance: int, item_type: String) -> void:
	var rec := _rec(merc)
	if rec.is_empty() or tolerance <= 0 or amount < tolerance:
		return
	var by_type: Dictionary = rec["damage"]
	by_type[StateTokens.normalize_token(item_type)] = true


static func record_damage_dealt_total(merc: MercenaryData, amount: int) -> void:
	var rec := _rec(merc)
	if rec.is_empty() or amount <= 0:
		return
	rec["dealt_total"] = int(rec["dealt_total"]) + amount


static func record_damage_taken(merc: MercenaryData, amount: int, damage_type: String) -> void:
	var rec := _rec(merc)
	if rec.is_empty() or amount <= 0:
		return
	rec["taken_total"] = int(rec["taken_total"]) + amount
	rec["taken_max"] = maxi(int(rec["taken_max"]), amount)
	var key := StateTokens.normalize_token(damage_type)
	if key == "":
		return
	var by_type: Dictionary = rec["taken_types"]
	by_type[key] = int(by_type.get(key, 0)) + amount


#One field of the merc tally record, or default when the merc has no record yet.
static func _field(merc: MercenaryData, key: String, default: Variant) -> Variant:
	var rec := _read(merc)
	return default if rec.is_empty() else rec[key]


static func damage_dealt_total(merc: MercenaryData) -> int:
	return int(_field(merc, "dealt_total", 0))


static func damage_taken_total(merc: MercenaryData) -> int:
	return int(_field(merc, "taken_total", 0))


static func damage_taken_max(merc: MercenaryData) -> int:
	return int(_field(merc, "taken_max", 0))


static func took_damage_type(merc: MercenaryData, damage_type: String) -> bool:
	var by_type: Dictionary = _field(merc, "taken_types", {})
	return by_type.has(StateTokens.normalize_token(damage_type))


#Counts states this merc's own actions put on someone else.
static func record_inflicted(source: MercenaryData, state_name: String) -> void:
	var rec := _rec(source)
	if rec.is_empty():
		return
	var key := StateTokens.normalize_token(state_name)
	if key == "":
		return
	var by_state: Dictionary = rec["inflicted"]
	by_state[key] = int(by_state.get(key, 0)) + 1


static func inflicted_count(source: MercenaryData, state_name: String) -> int:
	var by_state: Dictionary = _field(source, "inflicted", {})
	return int(by_state.get(StateTokens.normalize_token(state_name), 0))


#Checks rolled by anyone without a campaign identity land on the contract target instead.
static func record_target_check(merc: MercenaryData, stat: String, passed: bool) -> void:
	if merc == null or merc.merc_uid > 0 or passed:
		return
	var key := StateTokens.normalize_token(stat)
	if key == "":
		return
	var failed: Dictionary = _target["failed"]
	failed[key] = int(failed.get(key, 0)) + 1


static func target_failed(stat: String) -> bool:
	return (_target["failed"] as Dictionary).has(StateTokens.normalize_token(stat))


static func succeeded(merc: MercenaryData, stat: String) -> bool:
	var passed: Dictionary = _field(merc, "passed", {})
	return passed.has(StateTokens.normalize_token(stat))


static func success_count(merc: MercenaryData, stat: String) -> int:
	var passed: Dictionary = _field(merc, "passed", {})
	return int(passed.get(StateTokens.normalize_token(stat), 0))


#Best success count over every stat, used when no Succeeded Check entry named one first.
static func best_success_count(merc: MercenaryData) -> int:
	var passed: Dictionary = _field(merc, "passed", {})
	var best := 0
	for key: String in passed:
		best = maxi(best, int(passed[key]))
	return best


static func failed_any(merc: MercenaryData) -> bool:
	return failure_count(merc) > 0


static func failure_count(merc: MercenaryData) -> int:
	return int(_field(merc, "failures", 0))


static func failed_stat(merc: MercenaryData, stat: String) -> bool:
	var failed: Dictionary = _field(merc, "failed", {})
	return failed.has(StateTokens.normalize_token(stat))


#An empty item type asks whether any weapon class landed a hit at or above the target's Tolerance.
static func damage_met_tolerance(merc: MercenaryData, item_type: String) -> bool:
	var by_type: Dictionary = _field(merc, "damage", {})
	if item_type == "":
		return not by_type.is_empty()
	return bool(by_type.get(StateTokens.normalize_token(item_type), false))

class_name RangedPlanStore

#The ranged draw plan a merc carries in active_states between decisions.
const KEY := "ranged_plan"


static func store(merc: MercenaryData, weapon: WeaponData, state: BattleState, result: Dictionary) -> void:
	if str(result.get("mode", "none")) == "none":
		var held: Dictionary = merc.active_states.get(KEY, {}) as Dictionary
		if held.get("weapon") == weapon:
			merc.active_states.erase(KEY)
		return
	merc.active_states[KEY] = {
		"weapon": weapon,
		"cell": result.get("cell", RangedDrawPlanner.NO_CELL),
		"round": state.round_number,
		"mode": str(result.get("mode", "none")),
		"target": result.get("target"),
	}


static func clear_plan(merc: MercenaryData) -> void:
	merc.active_states.erase(KEY)


#The stored plan, or an empty dictionary once it ages out or the weapon leaves the merc.
static func stored_plan(merc: MercenaryData, state: BattleState) -> Dictionary:
	var held: Dictionary = merc.active_states.get(KEY, {}) as Dictionary
	if held.is_empty():
		return {}
	var weapon: WeaponData = held.get("weapon")
	if weapon == null:
		merc.active_states.erase(KEY)
		return {}
	if state != null and state.round_number - int(held.get("round", 0)) > 2:
		merc.active_states.erase(KEY)
		return {}
	if not WeaponEvaluator.get_available_weapons(merc).has(weapon):
		merc.active_states.erase(KEY)
		return {}
	return held

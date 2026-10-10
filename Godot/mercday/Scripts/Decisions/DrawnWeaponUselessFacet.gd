class_name DrawnWeaponUselessFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or not weapon.is_ranged:
		return 0.0
	var state: BattleState = ctx.get("state")
	if state != null:
		var rp := RangedPlanStore.stored_plan(merc, state)
		if rp.get("weapon") == weapon and int(rp.get("round", -1)) == state.round_number:
			return 0.0
	#Only the loaded type can be reloaded; Fight is always there as the melee fallback.
	return 1.0 if WeaponEvaluator.drawn_ranged_useless(merc, weapon) else 0.0

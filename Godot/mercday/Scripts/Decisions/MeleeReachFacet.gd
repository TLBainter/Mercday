class_name MeleeReachFacet extends DecisionFacet

#A throwable weapon counts an enemy at throw range as valid, so the swing still needs real reach.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state") as BattleState
	if state == null or state.battlefield == null:
		return 1.0
	var weapon: WeaponData = merc.equipped_weapon
	if weapon != null and weapon.is_ranged:
		return 1.0
	var target := TargetSelector.current_or_best(merc, ctx, state)
	if target == null:
		return 0.0
	var reach := WeaponArmorPerkLibrary.get_effective_melee_range(merc)
	return 1.0 if state.distance_to(merc, target) <= reach else 0.0

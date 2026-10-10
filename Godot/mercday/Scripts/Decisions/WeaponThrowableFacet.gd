class_name WeaponThrowableFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or weapon.is_ranged or weapon.is_virtual:
		return 0.0
	var state: BattleState = ctx.get("state") as BattleState
	if state == null:
		return 0.0
	var target := TargetSelector.current_or_best(merc, ctx, state)
	if target == null:
		return 0.0
	if not weapon.is_throwable \
			and not ThrownWeaponRules.object_throw_allowed(merc, weapon, target, state):
		return 0.0
	var plan := ThrownWeaponRules.should_throw(
		merc, weapon, target, ctx.get("enemies", []), state, EncounterLogger.is_active())
	return 1.0 if bool(plan.get("throw", false)) else 0.0


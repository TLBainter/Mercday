class_name DrawnWeaponUselessFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or not weapon.is_ranged:
		return 0.0
	var state: BattleState = _ctx.get("state")
	if state != null:
		var rp := RangedDrawPlanner.stored_plan(merc, state)
		if rp.get("weapon") == weapon and int(rp.get("round", -1)) == state.round_number:
			return 0.0
	if weapon.misfire > 0 and not FirearmReliabilityFacet.aimed_viable(merc):
		return 1.0  # Fight is always available as melee fallback
	if merc.ammo_loaded <= 0:
		#Only the loaded type can be reloaded; reserves of any other type do not help.
		if merc.ammo_loaded_type == "":
			return 1.0
		return 0.0 if int(merc.ammo_inventory.get(merc.ammo_loaded_type, 0)) > 0 else 1.0
	return 0.0

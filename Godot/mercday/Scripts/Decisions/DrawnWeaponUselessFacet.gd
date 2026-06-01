class_name DrawnWeaponUselessFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or not weapon.is_ranged:
		return 0.0
	if merc.ammo_loaded <= 0:
		for v in merc.ammo_inventory.values():
			if int(v) > 0:
				return 0.0
		return 1.0
	if weapon.misfire > 0 and (FirearmReliabilityFacet.compute(merc) * 2.5 + 2.0) / 4.5 < 0.50:
		return 1.0  # Fight is always available as melee fallback
	return 0.0

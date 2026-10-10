class_name WeaponDrawnFacet extends DecisionFacet

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if merc.equipped_weapon != null and merc.weapon_drawn else 0.0

class_name AmmoStatusFacet extends DecisionFacet

#1.0 when the drawn ranged weapon has a round loaded; melee and unarmed always pass.
func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	if merc.equipped_weapon == null or not merc.equipped_weapon.is_ranged:
		return 1.0
	return 1.0 if merc.ammo_loaded > 0 else 0.0

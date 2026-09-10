class_name WeaponDrawnFacet extends DecisionFacet

@export var drawn_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var is_drawn: bool = merc.equipped_weapon != null and merc.weapon_drawn
	return 1.0 if drawn_is_high == is_drawn else 0.0

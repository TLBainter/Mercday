class_name WeaponTypeFacet extends DecisionFacet

@export var require_ranged: bool = false
@export var require_drawn: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	if merc.equipped_weapon == null:
		return 0.0
	if require_drawn and not merc.weapon_drawn:
		return 0.0
	if require_ranged:
		return 1.0 if merc.equipped_weapon.is_ranged else 0.0
	else:
		return 1.0 if not merc.equipped_weapon.is_ranged else 0.0

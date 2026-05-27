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

static func create(p_require_ranged: bool, p_weight: float = 1.0, p_required: bool = false, p_require_drawn: bool = true) -> WeaponTypeFacet:
	var facet := WeaponTypeFacet.new()
	facet.require_ranged = p_require_ranged
	facet.weight = p_weight
	facet.is_required = p_required
	facet.require_drawn = p_require_drawn
	return facet

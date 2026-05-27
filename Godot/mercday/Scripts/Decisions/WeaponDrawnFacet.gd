class_name WeaponDrawnFacet extends DecisionFacet

@export var drawn_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var is_drawn: bool = merc.equipped_weapon != null and merc.weapon_drawn
	return 1.0 if drawn_is_high == is_drawn else 0.0

static func create(p_drawn_is_high: bool, p_weight: float = 1.0, p_required: bool = false) -> WeaponDrawnFacet:
	var facet := WeaponDrawnFacet.new()
	facet.drawn_is_high = p_drawn_is_high
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

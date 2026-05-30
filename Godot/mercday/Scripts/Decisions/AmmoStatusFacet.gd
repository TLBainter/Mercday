class_name AmmoStatusFacet extends DecisionFacet

@export var mode: String = "has"

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	if merc.equipped_weapon == null or not merc.equipped_weapon.is_ranged:
		return 1.0
	var has_reserve := false
	for v in merc.ammo_inventory.values():
		if int(v) > 0:
			has_reserve = true
			break
	match mode:
		"has":
			return 1.0 if merc.ammo_loaded > 0 or has_reserve else 0.0
		"loaded":
			return 1.0 if merc.ammo_loaded > 0 else 0.0
		"empty":
			return 1.0 if merc.ammo_loaded == 0 and not has_reserve else 0.0
		"low":
			return 1.0 if merc.ammo_loaded <= 1 else 0.0
	return 0.0

static func create(p_mode: String, p_weight: float = 1.0, p_required: bool = false) -> AmmoStatusFacet:
	var facet := AmmoStatusFacet.new()
	facet.mode = p_mode
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

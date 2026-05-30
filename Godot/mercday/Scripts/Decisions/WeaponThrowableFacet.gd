class_name WeaponThrowableFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	if merc.equipped_weapon == null:
		return 0.0
	if not merc.weapon_drawn:
		return 0.0
	if not merc.equipped_weapon.is_throwable:
		return 0.0
	# Prefer melee when any valid target is already in melee reach -- keep the weapon.
	var state: BattleState = ctx.get("state")
	if state != null:
		var melee_r: int = merc.equipped_weapon.melee_range
		for t: MercenaryData in ctx.get("valid_targets", []):
			if state.distance_to(merc, t) <= melee_r:
				return 0.0
	return 1.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> WeaponThrowableFacet:
	var facet := WeaponThrowableFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

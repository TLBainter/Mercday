class_name WasInMeleeRangeFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var old_pos = ctx.get("old_pos")
	var state: BattleState = ctx.get("state")
	if old_pos == null or state == null or merc.equipped_weapon == null:
		return 0.0
	var merc_pos := state.get_position(merc)
	var old_dist := maxi(abs(old_pos.x - merc_pos.x), abs(old_pos.y - merc_pos.y))
	return 1.0 if old_dist <= merc.equipped_weapon.melee_range else 0.0

static func create(p_weight: float = 1.0, p_required: bool = false) -> WasInMeleeRangeFacet:
	var facet := WasInMeleeRangeFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

class_name RangedThreatFacet extends DecisionFacet

@export var invert: bool = false

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null:
		return 0.0

	var ranged_enemies: Array = []
	for e in ctx.get("enemies", []):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)
	if ranged_enemies.is_empty():
		return 0.0

	var threat: float = 0.0
	for e: MercenaryData in ranged_enemies:
		var d := float(maxi(1, state.distance_2d(merc, e)))
		threat += 1.0 / d

	var recently_targeted: bool = false
	var last_round: int = state.last_ranged_targeted_round.get(merc, -99) as int
	if state.round_number - last_round <= 2:
		recently_targeted = true

	if recently_targeted:
		threat += 1.5

	var raw := clampf(threat, 0.0, 1.0)
	return 1.0 - raw if invert else raw


static func create(p_weight: float = 0.6, p_required: bool = false) -> RangedThreatFacet:
	var facet := RangedThreatFacet.new()
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

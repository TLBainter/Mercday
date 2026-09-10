class_name RangedThreatFacet extends DecisionFacet

@export var invert: bool = false

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	if state == null:
		return 0.0

	var ranged_enemies := DecisionFacet.ranged_enemies_in(ctx)
	if ranged_enemies.is_empty():
		return 0.0

	var threat: float = 0.0
	for e: MercenaryData in ranged_enemies:
		var d := float(maxi(1, state.distance_2d(merc, e)))
		threat += maxf(0.25, 1.0 / d)  # floor ensures distant enemies still register

	var recently_targeted: bool = false
	var last_round: int = state.last_ranged_targeted_round.get(merc, -99) as int
	if state.round_number - last_round <= 2:
		recently_targeted = true

	if recently_targeted:
		threat += 1.5

	var raw := clampf(threat, 0.0, 1.0)
	return 1.0 - raw if invert else raw

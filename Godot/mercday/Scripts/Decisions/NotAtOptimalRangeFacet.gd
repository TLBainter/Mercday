class_name NotAtOptimalRangeFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return 0.0
	var intended: int = weapon.ranged_intended_range
	if intended <= 0:
		return 0.0
	var state = ctx.get("state")
	var enemies: Array = ctx.get("enemies", [])
	if state == null or enemies.is_empty():
		return 0.0
	var min_dist: float = INF
	for enemy in enemies:
		var d: float = state.distance_to(merc, enemy)
		if d < min_dist:
			min_dist = d
	# Already at or beyond intended range -- no need to reposition
	if min_dist >= float(intended):
		return 0.0
	# Score increases linearly as enemy closes in from intended range
	return clampf(1.0 - min_dist / float(intended), 0.0, 1.0)

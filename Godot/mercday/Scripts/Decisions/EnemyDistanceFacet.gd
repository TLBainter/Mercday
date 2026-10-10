class_name EnemyDistanceFacet extends DecisionFacet

@export var max_dist: float = 1.0
@export var close_is_high: bool = true

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var enemies: Array = ctx.get("enemies", [])
	var state = ctx.get("state")
	if enemies.is_empty() or state == null:
		return 0.0
	var min_dist := float(MovementDecider.nearest_enemy(merc, enemies, state)["dist"])
	if close_is_high:
		return 1.0 if min_dist <= max_dist else 0.0
	else:
		return 1.0 if min_dist > max_dist else 0.0

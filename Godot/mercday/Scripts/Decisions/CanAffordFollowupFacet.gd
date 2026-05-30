class_name CanAffordFollowupFacet extends DecisionFacet

# Minimum total AP (current + excess) required to cover this action AND a follow-up.
@export var min_total_ap: int = 5

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if merc.current_ap + merc.excess_ap >= min_total_ap else 0.0

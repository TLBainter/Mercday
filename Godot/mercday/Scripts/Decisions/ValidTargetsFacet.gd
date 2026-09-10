class_name ValidTargetsFacet extends DecisionFacet

@export var has_targets_is_high: bool = true

func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var has_targets: bool = not ctx.get("valid_targets", []).is_empty()
	return 1.0 if has_targets_is_high == has_targets else 0.0

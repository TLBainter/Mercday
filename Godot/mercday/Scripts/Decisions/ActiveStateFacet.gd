class_name ActiveStateFacet extends DecisionFacet

@export var state_name: String = ""
@export var present_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var active: bool = ConstStates.has_state(merc, state_name)
	if present_is_high:
		return 1.0 if active else 0.0
	else:
		return 1.0 if not active else 0.0

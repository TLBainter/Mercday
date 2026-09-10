class_name AnyStateFacet extends DecisionFacet

@export var states: PackedStringArray = []

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	for state_name in states:
		if ConstStates.has_state(merc, state_name):
			return 1.0
	return 0.0

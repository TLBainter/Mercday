class_name AnyStateFacet extends DecisionFacet

@export var states: PackedStringArray = []

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	for state_name in states:
		if ConstStates.has_state(merc, state_name):
			return 1.0
	return 0.0

static func create(p_states: PackedStringArray, p_weight: float = 1.0, p_required: bool = false) -> AnyStateFacet:
	var facet := AnyStateFacet.new()
	facet.states = p_states
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

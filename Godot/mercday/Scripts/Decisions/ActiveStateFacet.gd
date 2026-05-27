class_name ActiveStateFacet extends DecisionFacet

@export var state_name: String = ""
@export var present_is_high: bool = true

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var active: bool = ConstStates.has_state(merc, state_name)
	if present_is_high:
		return 1.0 if active else 0.0
	else:
		return 1.0 if not active else 0.0

static func create(p_state_name: String, p_present_is_high: bool, p_weight: float = 1.0, p_required: bool = false) -> ActiveStateFacet:
	var facet := ActiveStateFacet.new()
	facet.state_name = p_state_name
	facet.present_is_high = p_present_is_high
	facet.weight = p_weight
	facet.is_required = p_required
	return facet

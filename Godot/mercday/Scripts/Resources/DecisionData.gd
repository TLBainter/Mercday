class_name DecisionData extends Resource

@export var facets: Array[DecisionFacet] = []
@export var threshold: float = 0.5


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	if facets.is_empty():
		return 1.0

	for f in facets:
		if f.is_required and f.evaluate(merc, ctx) == 0.0:
			return 0.0

	var scored: Array[DecisionFacet] = []
	for f in facets:
		if not f.is_required:
			scored.append(f)

	if scored.is_empty():
		return 1.0

	var total_weight: float = 0.0
	for f in scored:
		total_weight += f.weight

	if total_weight == 0.0:
		return 1.0

	var weighted_sum: float = 0.0
	for f in scored:
		weighted_sum += f.evaluate(merc, ctx) * f.weight

	return weighted_sum / total_weight


func evaluate_verbose(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var details: Array[Dictionary] = []
	if facets.is_empty():
		return {"passed": true, "score": 1.0, "facets": details}
	for f: DecisionFacet in facets:
		if f.is_required:
			var s := f.evaluate(merc, ctx)
			var sname: String = f.get_script().get_global_name() \
				if f.get_script() and not f.get_script().get_global_name().is_empty() \
				else f.get_script().resource_path.get_file().get_basename()
			details.append({"name": sname, "required": true, "weight": f.weight, "score": s})
			if s == 0.0:
				return {"passed": false, "score": 0.0, "facets": details}
	var total_w := 0.0
	var w_sum := 0.0
	for f: DecisionFacet in facets:
		if not f.is_required:
			var s := f.evaluate(merc, ctx)
			var sname: String = f.get_script().get_global_name() \
				if f.get_script() and not f.get_script().get_global_name().is_empty() \
				else f.get_script().resource_path.get_file().get_basename()
			details.append({"name": sname, "required": false, "weight": f.weight, "score": s})
			total_w += f.weight
			w_sum += s * f.weight
	var final_score := 1.0 if total_w == 0.0 else w_sum / total_w
	return {"passed": true, "score": final_score, "facets": details}

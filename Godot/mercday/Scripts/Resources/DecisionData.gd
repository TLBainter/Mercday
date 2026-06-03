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

	var remaining_weight := total_weight
	var weighted_sum: float = 0.0
	for f in scored:
		weighted_sum += f.evaluate(merc, ctx) * f.weight
		remaining_weight -= f.weight
		if threshold > 0.0 and (weighted_sum + remaining_weight) / total_weight < threshold:
			return 0.0
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
	var nonfixed: Array[DecisionFacet] = []
	var total_w := 0.0
	for f: DecisionFacet in facets:
		if not f.is_required:
			nonfixed.append(f)
			total_w += f.weight
	var remaining_w := total_w
	var w_sum := 0.0
	for i: int in nonfixed.size():
		var f: DecisionFacet = nonfixed[i]
		var s := f.evaluate(merc, ctx)
		var sname: String = f.get_script().get_global_name() \
			if f.get_script() and not f.get_script().get_global_name().is_empty() \
			else f.get_script().resource_path.get_file().get_basename()
		details.append({"name": sname, "required": false, "weight": f.weight, "score": s})
		w_sum += s * f.weight
		remaining_w -= f.weight
		if threshold > 0.0 and total_w > 0.0 and (w_sum + remaining_w) / total_w < threshold:
			for j: int in range(i + 1, nonfixed.size()):
				var sf := nonfixed[j]
				var sfname: String = sf.get_script().get_global_name() \
					if sf.get_script() and not sf.get_script().get_global_name().is_empty() \
					else sf.get_script().resource_path.get_file().get_basename()
				details.append({"name": sfname, "required": false, "weight": sf.weight, "score": -1.0, "skipped": true})
			return {"passed": false, "score": 0.0, "facets": details}
	var final_score := 1.0 if total_w == 0.0 else w_sum / total_w
	return {"passed": true, "score": final_score, "facets": details}

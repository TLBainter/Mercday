class_name DecisionData extends Resource

@export var facets: Array[DecisionFacet] = []
@export var threshold: float = 0.5

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	return float(_run(merc, ctx, null)["score"])


func evaluate_verbose(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var details: Array[Dictionary] = []
	return _run(merc, ctx, details)


#Weighted sum with a required-facet veto and an early prune; details stays null for the plain path.
func _run(merc: MercenaryData, ctx: Dictionary, details: Variant) -> Dictionary:
	if facets.is_empty():
		return {"passed": true, "score": 1.0, "facets": details}
	for f: DecisionFacet in facets:
		if f.is_required:
			var s := f.evaluate(merc, ctx)
			if details != null:
				details.append({"name": _facet_name(f), "required": true, "weight": f.weight, "score": s})
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
		if details != null:
			details.append({"name": _facet_name(f), "required": false, "weight": f.weight, "score": s})
		w_sum += s * f.weight
		remaining_w -= f.weight
		if threshold > 0.0 and total_w > 0.0 and (w_sum + remaining_w) / total_w < threshold:
			if details != null:
				for j: int in range(i + 1, nonfixed.size()):
					var sf: DecisionFacet = nonfixed[j]
					details.append({"name": _facet_name(sf), "required": false, "weight": sf.weight,
						"score": -1.0, "skipped": true})
			return {"passed": false, "score": 0.0, "facets": details}
	var final_score := 1.0 if total_w == 0.0 else w_sum / total_w
	return {"passed": true, "score": final_score, "facets": details}


#Class name of the facet script, falling back to the script file name.
func _facet_name(f: DecisionFacet) -> String:
	return f.get_script().get_global_name() \
		if f.get_script() and not f.get_script().get_global_name().is_empty() \
		else f.get_script().resource_path.get_file().get_basename()
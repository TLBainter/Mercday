class_name StateReliefFacet extends DecisionFacet

@export var action_key: String = ""


#0.5 is the break-even: the relief scores at least as well as the best other use of the AP.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var verdict: Dictionary
	if action_key == "aid_ally":
		verdict = StateReliefEvaluator.best_aid(merc, ctx)
	else:
		verdict = StateReliefEvaluator.self_relief(merc, action_key, ctx)
	if verdict.is_empty():
		return 0.0
	return clampf(0.5 + (float(verdict["score"]) - float(verdict["alt"])), 0.0, 1.0)

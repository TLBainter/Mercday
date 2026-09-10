class_name MeleePreferredFacet extends DecisionFacet

## Returns 1.0 when the merc's best melee DPS (accuracy x avg damage) exceeds their best ranged DPS.
func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 1.0 if CombatDecision.is_melee_preferred(merc) else 0.0

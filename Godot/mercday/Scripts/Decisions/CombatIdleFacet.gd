class_name CombatIdleFacet extends DecisionFacet

@export var idle_threshold: int = 3

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return 0.0 if merc.combat_idle_rounds >= idle_threshold else 1.0

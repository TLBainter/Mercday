class_name CombatIdleFacet extends DecisionFacet

@export var idle_threshold: int = 3
@export var invert: bool = false

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var raw := 0.0 if merc.combat_idle_rounds >= idle_threshold else 1.0
	return 1.0 - raw if invert else raw

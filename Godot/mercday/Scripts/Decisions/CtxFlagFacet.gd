class_name CtxFlagFacet extends DecisionFacet

@export var key: String = ""


#1.0 when the ctx entry is a non-empty Array or is truthy.
func evaluate(_merc: MercenaryData, ctx: Dictionary) -> float:
	var v: Variant = ctx.get(key)
	if v is Array:
		return 0.0 if (v as Array).is_empty() else 1.0
	return 1.0 if v else 0.0

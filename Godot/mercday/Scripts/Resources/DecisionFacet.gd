class_name DecisionFacet extends Resource

@export var weight: float = 1.0
@export var is_required: bool = false
#Scores 1.0 - evaluate() instead; DecisionData applies it through score().
@export var invert: bool = false


func evaluate(_merc: MercenaryData, _ctx: Dictionary) -> float:
	return 0.0


func score(merc: MercenaryData, ctx: Dictionary) -> float:
	var s := evaluate(merc, ctx)
	return 1.0 - s if invert else s


#Enemies in ctx holding a drawn-or-not ranged weapon; several facets score off this set.
static func ranged_enemies_in(ctx: Dictionary) -> Array:
	return CoverSearch.ranged_enemies(ctx.get("enemies", []))

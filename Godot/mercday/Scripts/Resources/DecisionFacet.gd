class_name DecisionFacet extends Resource

@export var weight: float = 1.0
@export var is_required: bool = false


func evaluate(_merc: MercenaryData, _ctx: Dictionary) -> float:
	return 0.0


#Enemies in ctx holding a drawn-or-not ranged weapon; several facets score off this set.
static func ranged_enemies_in(ctx: Dictionary) -> Array:
	var out: Array = []
	for e in ctx.get("enemies", []):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			out.append(e)
	return out

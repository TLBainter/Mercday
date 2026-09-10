class_name EffectiveHitChanceFacet extends DecisionFacet

#Threatened costs the shot one core die; the share of the pool left is the share of the hits left.
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var targets: Array = ctx.get("valid_targets", [])
	if targets.is_empty():
		return 0.0
	var base_acc: float = float(merc.stats.get("ranged_accuracy", 0))
	if base_acc <= 0.0:
		return 0.0
	if not ConstStates.has_state(merc, ConstStates.THREATENED):
		return 1.0
	if WeaponArmorPerkLibrary.has_weapon_passive(merc, "weapon_passive:ignore_threatened"):
		return 1.0
	var pool := AttackSystem.attack_pool_size(merc, merc.equipped_weapon)
	return clampf(float(pool - 1) / float(pool), 0.0, 1.0)

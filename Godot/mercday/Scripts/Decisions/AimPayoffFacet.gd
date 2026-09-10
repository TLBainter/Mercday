class_name AimPayoffFacet extends DecisionFacet

# Passes only when aiming would flip a failed attack into a passing one.
# Blocks aim when: unaimed attack already passes (wasted AP), or aimed attack still fails.
# Weights mirror AttackRangeAimed.tres: reliability w=2.5, aim_boost w=2.0, threshold=0.50.
func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return 0.0
	if weapon.misfire <= 0:
		return 0.0  # non-firearms have reliability=1.0; unaimed attack already passes
	var reliability := FirearmReliabilityFacet.compute(merc)
	if FirearmReliabilityFacet.unaimed_viable_at(reliability):
		return 0.0  #Unaimed attack already clears the threshold; aiming wastes AP
	if not FirearmReliabilityFacet.aimed_viable_at(reliability):
		return 0.0  #Aimed score still below the threshold; aiming accomplishes nothing
	return 1.0

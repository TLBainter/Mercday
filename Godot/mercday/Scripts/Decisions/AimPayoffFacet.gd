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
	if reliability >= 0.5:
		return 0.0  # unaimed AttackRange already clears threshold — aim wastes AP
	if (reliability * 2.5 + 2.0) / 4.5 < 0.5:
		return 0.0  # aimed score still below threshold — aim accomplishes nothing
	return 1.0

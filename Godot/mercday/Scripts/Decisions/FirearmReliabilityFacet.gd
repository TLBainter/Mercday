class_name FirearmReliabilityFacet extends DecisionFacet

#Aim scoring mirrors AttackRangeAimed.tres: reliability w=2.5, aim_boost w=2.0, threshold 0.50.
const AIM_RELIABILITY_WEIGHT := 2.5
const AIM_BOOST_WEIGHT := 2.0
const AIM_TOTAL_WEIGHT := 4.5
const AIM_THRESHOLD := 0.50


func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	return compute(merc)


static func compute(merc: MercenaryData) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged or weapon.misfire <= 0:
		return 1.0
	var p := clampf(float(merc.stats.get("ranged_accuracy", 0.0)) / 100.0, 0.0, 1.0)
	var dex := maxf(0.0, float(merc.stats.get("dexterity", 0)))
	var vig := maxf(0.0, float(merc.stats.get("vigor", 0)))
	var num_dice := int(maxf(1.0, maxf(dex, vig)))
	var k := int(weapon.misfire)
	if num_dice < k:
		return 0.0
	return prob_at_least_k(num_dice, k, p)


static func aimed_score(reliability: float) -> float:
	return (reliability * AIM_RELIABILITY_WEIGHT + AIM_BOOST_WEIGHT) / AIM_TOTAL_WEIGHT


static func aimed_viable_at(reliability: float) -> bool:
	return aimed_score(reliability) >= AIM_THRESHOLD


static func unaimed_viable_at(reliability: float) -> bool:
	return (reliability * AIM_RELIABILITY_WEIGHT) / AIM_TOTAL_WEIGHT >= AIM_THRESHOLD


static func aimed_viable(merc: MercenaryData) -> bool:
	return aimed_viable_at(compute(merc))


static func unaimed_viable(merc: MercenaryData) -> bool:
	return unaimed_viable_at(compute(merc))


static func prob_at_least_k(n: int, k: int, p: float) -> float:
	if k <= 0:
		return 1.0
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0
	var prob := 0.0
	for i: int in range(k, n + 1):
		prob += _binomial_coef(n, i) * pow(p, i) * pow(1.0 - p, n - i)
	return clampf(prob, 0.0, 1.0)


static func _binomial_coef(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	if k == 0 or k == n:
		return 1.0
	var k2 := mini(k, n - k)
	var result := 1.0
	for i: int in range(k2):
		result *= float(n - i) / float(i + 1)
	return result

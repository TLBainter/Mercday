class_name GenLikelihood
#How many fresh contracts the round posts: one chance roll, then decaying extra rolls until a miss.


static func chance(blended: float) -> float:
	return clampf(GenConstants.LIKELY_BASE + GenConstants.LIKELY_SLOPE * (blended - 0.5),
		GenConstants.LIKELY_MIN, GenConstants.LIKELY_MAX)


static func count(blended: float, rng: RandomNumberGenerator) -> int:
	var p: float = chance(blended)
	var hits: int = 0
	while rng.randf() < p * pow(GenConstants.CHAIN_DECAY, hits):
		hits += 1
	return hits

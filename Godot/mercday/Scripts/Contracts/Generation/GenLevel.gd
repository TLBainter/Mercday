class_name GenLevel
#Contract level: a triangular draw around the weighted roster level centre.


#An empty group gives its weight to the others in proportion; no merc at all reads 1.0.
static func centre(all_living: Array[MercenaryData], available: Array[MercenaryData],
		resting: Array[MercenaryData]) -> float:
	var groups: Array = [all_living, available, resting]
	var weights: Array[float] = [GenConstants.LEVEL_W_ALL, GenConstants.LEVEL_W_AVAILABLE, GenConstants.LEVEL_W_RESTING]
	var sum: float = 0.0
	var weight_used: float = 0.0
	for i: int in range(groups.size()):
		var group: Array[MercenaryData] = groups[i]
		if group.is_empty():
			continue
		var total: int = 0
		for merc: MercenaryData in group:
			total += ExperienceSystem.current_level(merc)
		sum += weights[i] * float(total) / float(group.size())
		weight_used += weights[i]
	if weight_used <= 0.0:
		return 1.0
	return sum / weight_used


static func triangular(lo: float, peak: float, hi: float, rng: RandomNumberGenerator) -> float:
	if hi <= lo:
		return lo
	var f: float = (peak - lo) / (hi - lo)
	var u: float = rng.randf()
	if u < f:
		return lo + sqrt(u * (hi - lo) * (peak - lo))
	return hi - sqrt((1.0 - u) * (hi - lo) * (hi - peak))


static func roll(level_centre: float, rng: RandomNumberGenerator) -> int:
	var drawn: float = triangular(level_centre * GenConstants.LEVEL_LO, level_centre,
		level_centre * GenConstants.LEVEL_HI, rng)
	return clampi(roundi(drawn), 1, GenConstants.LEVEL_CAP)

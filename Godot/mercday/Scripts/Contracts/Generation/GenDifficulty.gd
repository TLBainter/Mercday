class_name GenDifficulty
#Contract difficulty: a record-driven centre, drawn toward the side the roster's mean difficulty leaves open.


static func centre(blended: float) -> float:
	return clampf(GenConstants.DIFF_CENTRE + GenConstants.DIFF_SLOPE * (blended - 0.5),
		GenConstants.DIFF_MIN, GenConstants.DIFF_MAX)


#A roster mean above the centre draws at or below it; otherwise at or above it.
static func roll(diff_centre: float, roster_mean: float, rng: RandomNumberGenerator) -> float:
	var drawn: float
	if roster_mean > diff_centre:
		drawn = GenLevel.triangular(GenConstants.DIFF_MIN, diff_centre, diff_centre, rng)
	else:
		drawn = GenLevel.triangular(diff_centre, diff_centre, GenConstants.DIFF_MAX, rng)
	var snapped: float = roundf(drawn / GenConstants.DIFF_SNAP) * GenConstants.DIFF_SNAP
	return clampf(snapped, GenConstants.DIFF_MIN, GenConstants.DIFF_MAX)


#The authored row difficulty when the row sets one, else a roll.
static func for_row(row: ContractData, diff_centre: float, roster_mean: float, rng: RandomNumberGenerator) -> float:
	if row != null and row.difficulty > 0.0:
		return row.difficulty
	return roll(diff_centre, roster_mean, rng)

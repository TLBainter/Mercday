class_name GenValue
#Contract value in notes: raw points over the level's mean raw, scaled to the level anchor and by quality.


#Piecewise linear through VALUE_ANCHORS, flat outside the first and last anchor.
static func anchor(level: int) -> float:
	var points: Array[Vector2] = GenConstants.VALUE_ANCHORS
	var x: float = float(level)
	if x <= points[0].x:
		return points[0].y
	for i: int in range(1, points.size()):
		if x <= points[i].x:
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return points[points.size() - 1].y


static func raw(face: int, level: int, difficulty: float, expense: int, hours: float, urgency: float) -> float:
	return float(face + 5) * GenConstants.CSAT_POINTS + float(level) * difficulty \
			+ float(expense) * GenConstants.EXPENSE_WEIGHT + hours / 8.0 * GenConstants.TIME_POINTS_PER_8H \
			+ urgency * GenConstants.URGENCY_POINTS


#Raw points of an average posting at this level; the expense is the tier mode's fare at the mean distance and team.
static func mean_raw(level: int) -> float:
	var fare: int = GenExpense.expense(GenExpense.tier_mode(float(level)), GenConstants.VALUE_MEAN_KM,
			GenConstants.VALUE_MEAN_TEAM)
	return raw(GenConstants.VALUE_MEAN_FACE, level, GenConstants.VALUE_MEAN_DIFFICULTY, fare,
			GenConstants.VALUE_MEAN_HOURS, GenConstants.VALUE_MEAN_URGENCY)


static func value(level: int, raw_points: float, q: float, travel_add: int) -> int:
	var mean: float = mean_raw(level)
	var ratio: float = raw_points / mean if mean > 0.0 else 1.0
	var mult: float = lerpf(GenConstants.QUALITY_MULT_LO, GenConstants.QUALITY_MULT_HI, q)
	return roundi(anchor(level) * ratio * mult * GenConstants.VALUE_TRIM) + travel_add

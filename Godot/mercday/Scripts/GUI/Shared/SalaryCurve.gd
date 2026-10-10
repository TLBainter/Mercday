class_name SalaryCurve extends SliderCurve

#The salary filter track. The first LOW_SHARE of the travel runs linear from SALARY_MIN to LOW_TOP by
#FINE_STEP; the rest follows a quadratic up to SALARY_MAX by COARSE_STEP, with the same slope at the join.

const SALARY_MIN: float = 1.0
const SALARY_MAX: float = 999.0
const LOW_TOP: float = 100.0
const LOW_SHARE: float = 0.35
const FINE_STEP: float = 1.0
const COARSE_STEP: float = 5.0
const LOW_SPAN: float = LOW_TOP - SALARY_MIN
const HIGH_SHARE: float = 1.0 - LOW_SHARE
#Above the join, with u the share of the upper run travelled: v = LOW_TOP + JOIN_SLOPE * u + BEND * u * u.
const JOIN_SLOPE: float = LOW_SPAN * HIGH_SHARE / LOW_SHARE
const BEND: float = SALARY_MAX - LOW_TOP - JOIN_SLOPE


func ratio_of(value: float, _lo: float, _hi: float) -> float:
	var v: float = clampf(value, SALARY_MIN, SALARY_MAX)
	if v <= LOW_TOP:
		return (v - SALARY_MIN) / LOW_SPAN * LOW_SHARE
	var root: float = sqrt(JOIN_SLOPE * JOIN_SLOPE + 4.0 * BEND * (v - LOW_TOP))
	var u: float = (root - JOIN_SLOPE) / (2.0 * BEND)
	return clampf(LOW_SHARE + u * HIGH_SHARE, 0.0, 1.0)


func value_of(ratio: float, _lo: float, _hi: float) -> float:
	var t: float = clampf(ratio, 0.0, 1.0)
	if t <= LOW_SHARE:
		return SALARY_MIN + LOW_SPAN * (t / LOW_SHARE)
	var u: float = (t - LOW_SHARE) / HIGH_SHARE
	return clampf(LOW_TOP + JOIN_SLOPE * u + BEND * u * u, SALARY_MIN, SALARY_MAX)


#FINE_STEP below LOW_TOP and COARSE_STEP above it; at LOW_TOP a fall takes FINE_STEP and a rise COARSE_STEP.
func step_at(value: float, rising: bool, _step: float) -> float:
	if value < LOW_TOP or (value == LOW_TOP and not rising):
		return FINE_STEP
	return COARSE_STEP


func snap(value: float, _lo: float, _hi: float, _step: float) -> float:
	var grid: float = FINE_STEP if value <= LOW_TOP else COARSE_STEP
	return clampf(roundf(value / grid) * grid, SALARY_MIN, SALARY_MAX)

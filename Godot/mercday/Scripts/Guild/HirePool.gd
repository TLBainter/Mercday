class_name HirePool
#The weekly hire pool and job posting numbers: pool size, card levels, fit to open work, the pro-rated first pay.

const OPINION_W_MERC: float = 0.5
const OPINION_W_CLIENT: float = 0.5
const POOL_MIN: int = 1
const POOL_OPEN_SEAT_FACTOR: int = 2
const POOL_SEAT_CAP_DIVISOR: int = 2
const POOL_START: int = 3
const LEVEL_LO: float = 0.25
const LEVEL_PEAK: float = 0.70
const LEVEL_HI: float = 1.15
const QUALITY_DRAWS_MIN: int = 1
const QUALITY_DRAWS_MAX: int = 3
const GOOD_MATCH_STARS: float = 3.5
const REFRESH_WEEKDAY: int = 1
const FILTER_TRIES: int = 4
const NEUTRAL_OPINION: float = 0.5
const SATISFACTION_MAX: float = 100.0


#Merc opinions run SalarySystem.OPINION_MIN..OPINION_MAX, client satisfactions 0..100; an empty side cedes its weight.
static func overall_opinion(merc_opinions: Array[int], satisfactions: Array[int]) -> float:
	var span: float = float(SalarySystem.OPINION_MAX - SalarySystem.OPINION_MIN)
	var merc_side: float = -1.0
	if not merc_opinions.is_empty():
		var sum: float = 0.0
		for o: int in merc_opinions:
			sum += clampf(float(o - SalarySystem.OPINION_MIN) / span, 0.0, 1.0)
		merc_side = sum / merc_opinions.size()
	var client_side: float = -1.0
	if not satisfactions.is_empty():
		var total: float = 0.0
		for s: int in satisfactions:
			total += clampf(float(s) / SATISFACTION_MAX, 0.0, 1.0)
		client_side = total / satisfactions.size()
	if merc_side < 0.0 and client_side < 0.0:
		return NEUTRAL_OPINION
	if merc_side < 0.0:
		return client_side
	if client_side < 0.0:
		return merc_side
	return (merc_side * OPINION_W_MERC + client_side * OPINION_W_CLIENT) / (OPINION_W_MERC + OPINION_W_CLIENT)


static func pool_cap(open_seats: int, seat_cap: int) -> int:
	return maxi(POOL_MIN, POOL_OPEN_SEAT_FACTOR * open_seats + int(seat_cap / float(POOL_SEAT_CAP_DIVISOR)))


static func pool_size(opinion: float, cap: int) -> int:
	var top: int = maxi(POOL_MIN, cap)
	return clampi(roundi(lerpf(float(POOL_MIN), float(top), clampf(opinion, 0.0, 1.0))), POOL_MIN, top)


static func quality_draws(opinion: float) -> int:
	var t: float = clampf(opinion, 0.0, 1.0)
	return clampi(roundi(lerpf(float(QUALITY_DRAWS_MIN), float(QUALITY_DRAWS_MAX), t)), QUALITY_DRAWS_MIN,
		QUALITY_DRAWS_MAX)


static func level_for(centre: float, rng: RandomNumberGenerator) -> int:
	var c: float = maxf(centre, 0.0)
	var level: float = GenLevel.triangular(c * LEVEL_LO, c * LEVEL_PEAK, c * LEVEL_HI, rng)
	return clampi(roundi(level), 1, GenConstants.LEVEL_CAP)


#The open contracts no roster merc matches at GOOD_MATCH_STARS or better.
static func needs(open_contracts: Array[ContractData], roster: Array[MercenaryData]) -> Array[ContractData]:
	var out: Array[ContractData] = []
	for c: ContractData in open_contracts:
		var covered: bool = false
		for m: MercenaryData in roster:
			if MatchScore.stars(MatchScore.solo_net(c, m)) >= GOOD_MATCH_STARS:
				covered = true
				break
		if not covered:
			out.append(c)
	return out


#Mean stars over the contracts the roster cannot cover; with none uncovered, over every open contract; with none, 0.
static func fit(merc: MercenaryData, contracts: Array[ContractData], roster: Array[MercenaryData] = []) -> float:
	if contracts.is_empty() or merc == null:
		return 0.0
	var pool: Array[ContractData] = needs(contracts, roster)
	if pool.is_empty():
		pool = contracts
	var sum: float = 0.0
	for c: ContractData in pool:
		sum += MatchScore.stars(MatchScore.solo_net(c, merc))
	return sum / pool.size()


static func is_refresh_day(date: Dictionary) -> bool:
	return int(date.get("weekday", -1)) == REFRESH_WEEKDAY


static func hire_charge(salary: int, days_to_payday: int, month_days: int) -> int:
	if days_to_payday <= 0 or salary <= 0:
		return 0
	if month_days <= 0:
		return salary
	return mini(salary, ceili(float(salary) * days_to_payday / month_days))


static func job_quality(opinion: float, match_pct: float) -> float:
	return GenQuality.promo_lift(opinion, match_pct)

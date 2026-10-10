class_name VacationDesire

#Vacation desire v2, -100..+100, derived on demand and never stored. Constants are PLACEHOLDER tuning values.

const W_FURLOUGH := 25.0
const W_DEFICIT := 25.0
const W_OVERALL := 20.0
const W_GUILD := 10.0
const W_HEALTH := 10.0
const W_FAILED := 10.0
const FURLOUGH_BEST := 0.0
const FURLOUGH_AVG := 20.0
const FURLOUGH_WORST := 330.0
const DEFICIT_MIN_FRAC := 0.10
const DEFICIT_SEV_FULL := 0.5
const DEFICIT_GRACE_DAYS := 10.0
const LOAD_BEST := 0.0
const LOAD_AVG := 20.0
const LOAD_WORST := 110.0
const OPINION_BEST := 5.0
const OPINION_AVG := 1.0
const OPINION_WORST := -5.0
const REL_BEST := 10.0
const REL_AVG := 3.0
const REL_WORST := 0.0
const STAT_BEST := 4.0
const STAT_AVG := 2.0
const STAT_WORST := 0.0
const HEALTH_BEST := 50.0
const HEALTH_AVG := 0.0
const HEALTH_WORST := -50.0
const FAIL_BEST := 0.0
const FAIL_AVG := 1.0
const FAIL_WORST := 3.0
const FAIL_DECAY_PER_DAY := 0.98282
const FAIL_FURLOUGH_MULT := 0.5
const VUL_BASE := 2.0
const COMPRESS := 1.5
const ROLL_MIN := 1.0
const REQ_P_MAX := 0.06
const REQ_K := 2.0
const LEAD_DAYS := 41
const LEAD_SPREAD := 20


static func term(x: float, best: float, avg: float, worst: float) -> float:
	if is_equal_approx(x, avg):
		return 0.0
	if (worst - avg) * (x - avg) > 0.0:
		return minf(1.0, (x - avg) / (worst - avg))
	return -minf(1.0, (x - avg) / (best - avg))


#Stats.tsv Healthiness, signed; a merc without the key fails loudly and reads average.
static func healthiness(m: MercenaryData) -> float:
	if not m.stats.has("healthiness"):
		push_error("VacationDesire: merc %d has no healthiness stat" % m.merc_uid)
		return HEALTH_AVG
	return float(m.stats["healthiness"])


static func vulnerability(m: MercenaryData) -> float:
	var u: float = (term(float(m.stats.get("wile", 0.0)), STAT_BEST, STAT_AVG, STAT_WORST)
		+ term(float(m.stats.get("vigor", 0.0)), STAT_BEST, STAT_AVG, STAT_WORST)
		+ term(healthiness(m), HEALTH_BEST, HEALTH_AVG, HEALTH_WORST)) / 3.0
	return pow(VUL_BASE, u)


#The worst pool deficit or maximum reduction, 0..1; a pool with no maximum reads 0.
static func severity(m: MercenaryData) -> float:
	var worst: float = 0.0
	var total: int = 0
	for p: Array in [[m.current_hp, RestSystem.MAX_HP], [m.current_ep, RestSystem.MAX_EP], [m.current_mp, RestSystem.MAX_MP]]:
		var most: int = RestActions.max_of(m, String(p[1]))
		total += most
		if most > 0:
			worst = maxf(worst, clampf(1.0 - float(p[0]) / float(most), 0.0, 1.0))
	var penalty: int = m.max_hp_penalty + m.max_ep_penalty + m.max_mp_penalty
	return maxf(worst, float(penalty) / float(maxi(1, total)))


#Once per game day per employed living merc, whatever its status (VacationBook.day_passed step 4).
static func day_tick(m: MercenaryData) -> void:
	var v: float = vulnerability(m)
	m.furlough_pressure += v
	m.fail_stress *= FAIL_DECAY_PER_DAY
	m.deficit_pressure = m.deficit_pressure + v if severity(m) >= DEFICIT_MIN_FRAC else 0.0


#Hook: GameState._settle, each ALIVE member of a failed result.
static func on_failed_contract(m: MercenaryData) -> void:
	m.fail_stress += vulnerability(m)


#Hook: RestSystem._furlough_finish (every completed Furlough).
static func on_furlough(m: MercenaryData, minute: int) -> void:
	m.furlough_pressure = 0.0
	m.deficit_pressure = 0.0
	m.fail_stress *= FAIL_FURLOUGH_MULT
	m.last_furlough_minute = minute


static func shape(s: float) -> float:
	if s <= 0.0:
		return s
	return s - COMPRESS * s * s * (1.0 - s)


static func compute(m: MercenaryData) -> float:
	var t_f: float = term(m.furlough_pressure, FURLOUGH_BEST, FURLOUGH_AVG, FURLOUGH_WORST)
	var sev: float = clampf(severity(m) / DEFICIT_SEV_FULL, 0.0, 1.0)
	var t_d: float = term(sev * maxf(0.0, m.deficit_pressure - DEFICIT_GRACE_DAYS), LOAD_BEST, LOAD_AVG, LOAD_WORST)
	var t_g: float = term(float(m.guild_opinion), OPINION_BEST, OPINION_AVG, OPINION_WORST)
	var rel: float = mean_relation(m)
	var t_p: float = 0.0 if rel < 0.0 else term(rel, REL_BEST, REL_AVG, REL_WORST)
	var t_h: float = term(healthiness(m), HEALTH_BEST, HEALTH_AVG, HEALTH_WORST)
	var t_x: float = term(m.fail_stress, FAIL_BEST, FAIL_AVG, FAIL_WORST)
	var s: float = (W_FURLOUGH * t_f + W_DEFICIT * t_d + W_OVERALL * (t_g + t_p) / 2.0 + W_GUILD * t_g
		+ W_HEALTH * t_h + W_FAILED * t_x) / 100.0
	return clampf(100.0 * shape(s), -100.0, 100.0)


#Mean relation toward employed living peers with a tracked pair; -1 when none is tracked. Never seeds a pair.
static func mean_relation(m: MercenaryData) -> float:
	var total: float = 0.0
	var count: int = 0
	for peer: MercenaryData in VacationDays.employed():
		if peer != m and CampaignKnowledge.has_relation(m.merc_uid, peer.merc_uid):
			total += float(CampaignKnowledge.relation(m.merc_uid, peer.merc_uid))
			count += 1
	return total / float(count) if count > 0 else -1.0


static func daily_chance(d: float) -> float:
	return 0.0 if d < ROLL_MIN else REQ_P_MAX * pow(d / 100.0, REQ_K)


static func length(cap: int, d: float) -> int:
	return clampi(ceili(cap * d / 100.0), 1, cap)


#One daily roll: Vector2i(start_day, days) on a hit, Vector2i(-1, 0) otherwise. The book checks can_book.
static func wish(m: MercenaryData, book: VacationBook, rng: RandomNumberGenerator, today: int) -> Vector2i:
	var cap: int = book.wish_cap(m.merc_uid, today)
	if cap < 1:
		return Vector2i(-1, 0)
	var d: float = compute(m)
	if rng.randf() >= daily_chance(d):
		return Vector2i(-1, 0)
	return Vector2i(today + LEAD_DAYS + rng.randi_range(0, LEAD_SPREAD), length(cap, d))

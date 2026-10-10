class_name LoanLogic extends RefCounted

#The loan formulas of the Finance Viewer prototype: how much a lender will lend, what a fair
#interest rate is, the approval odds of a request and what a payment costs.
#Static only; FinanceManager keeps the lender rows and the loans themselves.

#PLACEHOLDER: every number below is prototype data and none of it is balanced.
const AMOUNT_MIN: int = 100
const AMOUNT_FLOOR: int = 500
const MONEY_SHARE: float = 0.5
const REL_CAP_STEP: float = 0.08
const TERM_STEP: int = 3
const TERM_COUNT: int = 24
const TERM_MIN_SMALL: int = 3
const TERM_MIN_LARGE: int = 6
const LARGE_MONEY_MULT: int = 2
const RATE_TERM_WEIGHT: float = 0.01
const RATE_SHARE_WEIGHT: float = 0.04
const RATE_REL_WEIGHT: float = 0.01
const RATE_MIN: float = 0.02
const RATE_MAX: float = 0.45
const RATE_MUL_MIN: float = 0.6
const RATE_MUL_MAX: float = 1.6
const ODDS_BASE: float = 50.0
const ODDS_PER_REL: float = 5.0
const ODDS_SHARE_WEIGHT: float = 25.0
const ODDS_RATE_WEIGHT: float = 40.0
const ODDS_LONG_TERM_HIT: float = 5.0
const LONG_TERM_MONTHS: int = 48
const ODDS_PER_FIT: float = 20.0
const ODDS_MIN: float = 5.0
const ODDS_MAX: float = 95.0
const FIRST_DUE_MIN: int = 1
const FIRST_DUE_MAX: int = 6
const FIRST_DUE_FAIR: int = 2
const FIRST_DUE_BONUS: float = 5.0
const FIRST_DUE_HIT: float = 5.0
const FAIR_TERM_BASE: float = 6.0
const FAIR_TERM_SPAN: float = 30.0
const BETTER_ODDS_SHARE: float = 0.3
const BETTER_AMOUNT_MULT: float = 1.2
const BETTER_RATE_CUT: float = 0.02
const BETTER_RATE_MIN: float = 0.02
const WORSE_AMOUNT_MIN: float = 0.55
const WORSE_AMOUNT_SPAN: float = 0.3
const WORSE_RATE_ADD: float = 0.03
const WORSE_RATE_STEPS: float = 4.0
const OFFER_AMOUNT_MIN: int = 100
const OFFER_STEP: int = 100
const FIT_TRADITIONS: Array[String] = ["Performer", "Warrior"]
const FIT_TRADITION_WEIGHT: float = 0.4
const FIT_WILE_WEIGHT: float = 0.3
const FIT_VIGOR_WEIGHT: float = 0.3
const FIT_ATTRIBUTE_MAX: float = 10.0
const STAR_BASE: float = 0.5
const STAR_SPAN: float = 4.5
const STAR_MIN: float = 0.5
const STAR_MAX: float = 5.0
const OUTCOME_BETTER: String = "better"
const OUTCOME_EXACT: String = "exact"
const OUTCOME_WORSE: String = "worse"
const OFFER_HOURS: int = 72
const DEADLINE_CALM_HOURS: float = 48.0
const DEADLINE_WARN_HOURS: float = 24.0
const DEADLINE_CALM: Color = GuiColors.SKY
const DEADLINE_WARN: Color = GuiColors.AMBER
const DEADLINE_LATE: Color = GuiColors.RED
#Heat ramp of the request sliders: 0 is the best reading for the guild, 1 the worst.
const HEAT_BEST: Color = GuiColors.RAMP_GREEN
const HEAT_MID: Color = GuiColors.RAMP_YELLOW
const HEAT_WORST: Color = Color("#ff3b2f")
const HEAT_MID_STOP: float = 0.5
const RATE_HIGH: float = 0.2
const RATE_MID: float = 0.1
const RATE_HIGH_COLOR: Color = GuiColors.RED
const RATE_MID_COLOR: Color = GuiColors.AMBER
const RATE_LOW_COLOR: Color = GuiColors.GREEN
const CHANGE_SAME: float = 0.5
const CHANGE_BIG: float = 15.0
const CHANGE_NONE: String = "--"
const CHANGE_FLAT_COLOR: Color = GuiColors.MUTED
const CHANGE_NEUTRAL_COLOR: Color = GuiColors.LIGHT_BLUE
const CHANGE_GOOD_COLOR: Color = GuiColors.GREEN
const CHANGE_BAD_COLOR: Color = GuiColors.RED
const MONTHS_PER_TERM_YEAR: int = 12


#How well one merc talks a lender round: a Performer or a Warrior 40%, Wile 30%, Vigor 30%.
static func loan_fit(tradition: String, wile: int, vigor: int) -> float:
	var trad: float = FIT_TRADITION_WEIGHT if FIT_TRADITIONS.has(tradition) else 0.0
	return trad + FIT_WILE_WEIGHT * float(wile) / FIT_ATTRIBUTE_MAX \
		+ FIT_VIGOR_WEIGHT * float(vigor) / FIT_ATTRIBUTE_MAX


#The same fit as half stars, 0.5 to 5.0.
static func fit_stars(fit: float) -> float:
	return clampf(round((STAR_BASE + STAR_SPAN * fit) * 2.0) / 2.0, STAR_MIN, STAR_MAX)


#Every term a lender offers: 3 months to 6 years in steps of 3 months.
static func term_options() -> Array[int]:
	var out: Array[int] = []
	for i: int in range(TERM_COUNT):
		out.append((i + 1) * TERM_STEP)
	return out


static func term_label(months: int) -> String:
	if months < 12:
		return "%d Months" % months
	var years: int = floori(float(months) / 12.0)
	var rest: int = months % 12
	var text: String = "%d Year" % years if years == 1 else "%d Years" % years
	if rest > 0:
		text += ", %d Mo" % rest
	return text


#The most a lender will put up: its capacity scaled by the relationship plus half the guild notes.
static func amount_max(lender: Dictionary, money: int) -> int:
	var cap: float = float(int(lender.get("cap", 0)))
	var rel: int = int(lender.get("rel", 0))
	var raw: float = cap * (1.0 + float(rel) * REL_CAP_STEP) + float(money) * MONEY_SHARE
	return maxi(AMOUNT_FLOOR, roundi(raw / float(OFFER_STEP)) * OFFER_STEP)


#A request above twice the guild notes needs at least six months.
static func months_min(amount: int, money: int) -> int:
	return TERM_MIN_LARGE if amount > money * LARGE_MONEY_MULT else TERM_MIN_SMALL


#The longest term a lender allows grows with the relationship.
static func months_max(rel: int) -> int:
	if rel >= 3:
		return 72
	if rel >= 0:
		return 48
	if rel >= -2:
		return 24
	return 12


#The rate the lender calls fair: its base, plus the term and the share of its maximum, less the
#relationship.
static func fair_rate(lender: Dictionary, amount: int, amt_max: int, months: int) -> float:
	var base: float = float(lender.get("base", 0.0))
	var rel: int = int(lender.get("rel", 0))
	var raw: float = base + RATE_TERM_WEIGHT * float(months) / 12.0 \
		+ RATE_SHARE_WEIGHT * float(amount) / float(maxi(1, amt_max)) - RATE_REL_WEIGHT * float(rel)
	return clampf(raw, RATE_MIN, RATE_MAX)


#Everything one draft of a request works out to: the amount and term the lender allows, the fair
#rate against the proposed one, what it costs a month and the odds the lender says yes.
static func request(lender: Dictionary, draft: Dictionary, money: int,
		team_fit_sum: float) -> Dictionary:
	var rel: int = int(lender.get("rel", 0))
	var terms: Array[int] = term_options()
	var amt_max: int = amount_max(lender, money)
	var amount: int = clampi(int(draft.get("amount", 0)), AMOUNT_MIN, amt_max)
	var max_months: int = months_max(rel)
	var min_months: int = months_min(amount, money)
	var lo: int = terms.find(min_months)
	var hi: int = terms.find(max_months)
	var term_idx: int = clampi(int(draft.get("term_idx", 0)), lo, hi)
	var months: int = terms[term_idx]
	var fair: float = fair_rate(lender, amount, amt_max, months)
	var rate_mul: float = float(draft.get("rate_mul", 1.0))
	var rate: float = float(roundi(clampf(fair * rate_mul, fair * RATE_MUL_MIN,
		fair * RATE_MUL_MAX) * 1000.0)) / 1000.0
	var interest: int = roundi(float(amount) * rate)
	var monthly: int = ceili(float(amount + interest) / float(maxi(1, months)))
	var first_due: int = clampi(int(draft.get("first_due", FIRST_DUE_FAIR)), FIRST_DUE_MIN,
		FIRST_DUE_MAX)
	var share: float = float(amount) / float(maxi(1, amt_max))
	var long_hit: float = ODDS_LONG_TERM_HIT if months > LONG_TERM_MONTHS else 0.0
	var raw: float = ODDS_BASE + float(rel) * ODDS_PER_REL - share * ODDS_SHARE_WEIGHT \
		+ (rate - fair) / fair * ODDS_RATE_WEIGHT - long_hit + first_due_odds(first_due) \
		+ team_fit_sum * ODDS_PER_FIT
	var fair_idx: int = clampi(roundi((FAIR_TERM_BASE + FAIR_TERM_SPAN * share)
		/ float(TERM_STEP)) - 1, lo, hi)
	return {"amount": amount, "amt_max": amt_max, "months": months, "min_months": min_months,
		"max_months": max_months, "lo": lo, "hi": hi, "term_idx": term_idx, "fair": fair,
		"rate": rate, "rate_mul": rate_mul, "interest": interest, "monthly": monthly,
		"first_due": first_due, "share": share,
		"odds": roundi(clampf(raw, ODDS_MIN, ODDS_MAX)),
		"fair_amount": roundi(float(amt_max) * MONEY_SHARE / float(OFFER_STEP)) * OFFER_STEP,
		"fair_idx": fair_idx}


#Asking to pay a month early is worth 5 odds; every month later than the second costs twice what
#the one before it did.
static func first_due_odds(first_due: int) -> float:
	if first_due <= FIRST_DUE_MIN:
		return FIRST_DUE_BONUS
	return -FIRST_DUE_HIT * (pow(2.0, float(first_due - FIRST_DUE_FAIR)) - 1.0)


#Where every slider of the request window starts: the fair amount, the fair term for it, the fair
#rate and the second month.
static func fair_draft(lender: Dictionary, money: int) -> Dictionary:
	var wide: Dictionary = {"amount": amount_max(lender, money), "term_idx": 0, "rate_mul": 1.0,
		"first_due": FIRST_DUE_FAIR}
	var amount: int = int(request(lender, wide, money, 0.0)["fair_amount"])
	var far: Dictionary = {"amount": amount, "term_idx": TERM_COUNT - 1, "rate_mul": 1.0,
		"first_due": FIRST_DUE_FAIR}
	return {"amount": amount, "term_idx": int(request(lender, far, money, 0.0)["fair_idx"]),
		"rate_mul": 1.0, "first_due": FIRST_DUE_FAIR}


static func payment(principal: int, rate: float, months: int) -> int:
	return ceili(float(principal) * (1.0 + rate) / float(maxi(1, months)))


static func payoff(principal: int, months: int, paid: int) -> int:
	var left: int = maxi(0, months - paid)
	return ceili(float(principal) * float(left) / float(maxi(1, months)))


#What the lender comes back with. A low first roll beats the request (envoys only), a roll under
#the odds matches it and anything above it comes back worse: less money, a higher rate and the
#first payment a month sooner. The other two rolls size the worse offer.
static func resolve(request_row: Dictionary, roll_a: float, roll_b: float,
		roll_c: float) -> Dictionary:
	var amount: int = int(request_row.get("amount", 0))
	var rate: float = float(request_row.get("rate", 0.0))
	var term: int = int(request_row.get("term", request_row.get("months", 0)))
	var first_due: int = int(request_row.get("first_due", FIRST_DUE_FAIR))
	var odds: float = float(int(request_row.get("odds", 0)))
	var team: Array = request_row.get("team", []) as Array
	var roll: float = roll_a * 100.0
	var outcome: String = OUTCOME_WORSE
	if not team.is_empty() and roll < odds * BETTER_ODDS_SHARE:
		outcome = OUTCOME_BETTER
	elif roll < odds:
		outcome = OUTCOME_EXACT
	var offered: float = float(amount)
	var offered_rate: float = rate
	var shift: int = 0
	if outcome == OUTCOME_BETTER:
		offered = float(amount) * BETTER_AMOUNT_MULT
		offered_rate = maxf(BETTER_RATE_MIN, rate - BETTER_RATE_CUT)
		shift = 1
	elif outcome == OUTCOME_WORSE:
		offered = float(amount) * (WORSE_AMOUNT_MIN + roll_b * WORSE_AMOUNT_SPAN)
		offered_rate = rate + WORSE_RATE_ADD + float(roundi(roll_c * WORSE_RATE_STEPS)) / 100.0
		shift = -1
	return {"outcome": outcome, "approved": outcome != OUTCOME_WORSE,
		"offer_amount": maxi(OFFER_AMOUNT_MIN, roundi(offered / float(OFFER_STEP)) * OFFER_STEP),
		"offer_rate": float(roundi(offered_rate * 100.0)) / 100.0, "offer_term": term,
		"offer_first_due": clampi(first_due + shift, FIRST_DUE_MIN, FIRST_DUE_MAX)}


static func deadline_text(hours: float) -> String:
	return "Offer Expires in " + GuiDates.duration_text(hours)


#The success odds bands GuiTypes holds; odds under zero read as the lowest band.
static func odds_color(odds: int) -> Color:
	return GuiTypes.odds_color(maxi(0, odds))


static func deadline_color(hours: float) -> Color:
	if hours > DEADLINE_CALM_HOURS:
		return DEADLINE_CALM
	if hours > DEADLINE_WARN_HOURS:
		return DEADLINE_WARN
	return DEADLINE_LATE


#The slider colour ramp, bright green through yellow to bright red.
static func heat(t: float) -> Color:
	var f: float = clampf(t, 0.0, 1.0)
	if f < HEAT_MID_STOP:
		return HEAT_BEST.lerp(HEAT_MID, f / HEAT_MID_STOP)
	return HEAT_MID.lerp(HEAT_WORST, (f - HEAT_MID_STOP) / HEAT_MID_STOP)


#What an interest rate reads as: 20% and up is bad, 10% and up is watchful, below that is good.
static func rate_color(rate: float) -> Color:
	if rate >= RATE_HIGH:
		return RATE_HIGH_COLOR
	if rate >= RATE_MID:
		return RATE_MID_COLOR
	return RATE_LOW_COLOR


#A rate as a percent with one decimal.
static func percent_text(rate: float) -> String:
	return "%.1f%%" % (float(roundi(rate * 1000.0)) / 10.0)


static func months_label(n: int) -> String:
	return GuiDates.plural(n, "Month")


#A term change written as time: months, or years when the change is whole years.
static func term_delta(from_months: int, to_months: int, short: bool) -> String:
	var delta: int = to_months - from_months
	if delta == 0:
		return CHANGE_NONE
	var size: int = absi(delta)
	var sign_text: String = "+" if delta > 0 else "-"
	var years: bool = size % MONTHS_PER_TERM_YEAR == 0
	var whole: int = floori(float(size) / float(MONTHS_PER_TERM_YEAR))
	if short:
		return "%s%d %s" % [sign_text, whole if years else size, "yr" if years else "mo"]
	if years:
		return "%s%d %s" % [sign_text, whole, "year" if whole == 1 else "years"]
	return "%s%d %s" % [sign_text, size, "month" if size == 1 else "months"]


#One Change cell of the offer table: how far the offer moved and whether that is good news.
static func change_row(requested: float, offered: float, higher_is_good: int) -> Dictionary:
	var pct: float = 0.0
	if not is_zero_approx(requested):
		pct = (offered - requested) / requested * 100.0
	if absf(pct) < CHANGE_SAME:
		return {"pct": pct, "text": CHANGE_NONE, "color": CHANGE_FLAT_COLOR, "arrow": &""}
	var up: bool = offered > requested
	var color: Color = CHANGE_NEUTRAL_COLOR
	if higher_is_good != 0:
		color = CHANGE_GOOD_COLOR if up == (higher_is_good > 0) else CHANGE_BAD_COLOR
	var big: bool = absf(pct) >= CHANGE_BIG
	var arrow: StringName = &"up" if up else &"down"
	if not big:
		arrow = &"diag_up" if up else &"diag_down"
	var text: String = "%s%d%%" % ["+" if pct > 0.0 else "-", roundi(absf(pct))]
	return {"pct": pct, "text": text, "color": color, "arrow": arrow}

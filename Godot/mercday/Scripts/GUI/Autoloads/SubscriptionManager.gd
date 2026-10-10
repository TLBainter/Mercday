extends Node

#What the guild has paid for: one plan and, on Enterprise, a tier per Customize upgrade.
#entitlements() derives one flat key table from those two and is the only thing the screens read;
#set_entitlements() lays an override on top of the derived keys and holds it until reset().
#Every upgrade key reads 0 or false while the plan is below Enterprise, so a downgrade closes
#the screens it paid for without any screen knowing a plan name.

signal changed

enum Plan {FREE, PRO, ENTERPRISE}

const PLAN_NAMES: Array[String] = ["Mercday Free", "Mercday Pro", "Mercday Enterprise"]
const PLAN_KEYS: Array[String] = ["free", "pro", "enterprise"]
#Renegotiate bonus per Advisory Counsel tier.
const COUNSEL_PCT: Array[int] = [0, 5, 7, 9, 13, 15]
#The top Long Promos tier runs a promo until it is ended, so its cap stands in for no cap.
const PROMO_DAYS_INFINITE: int = 1000000
#How many days a promo may run per Long Promos tier.
const PROMO_DAY_CAPS: Array[int] = [5, 10, 17, 25, 30, PROMO_DAYS_INFINITE]
#Percent added to an advertisement's effect per Marketing Agency tier.
const AD_BOOST_PCT: Array[int] = [0, 5, 7, 12, 15, 20, 25]
#How often survey data refreshes per Faster Metrics tier, once Guild Survey is owned.
const SURVEY_REFRESH: Array[String] = ["quarterly", "monthly", "weekly", "daily",
	"instant", "instant"]
#"--plan=<spec>": the plan a headless run starts on.
const PLAN_FLAG := "--plan"

#Billing days of the game calendar month: the subscription and the Customize add-ons fall on the
#2nd. MONTH_DAYS is only the pro-rating base; a game month holds 30 or 40 days.
const BILL_DAY: int = 2
const MONTH_DAYS: int = 30
#What budget_available() answers while FinanceManager is not in the tree.
const BUDGET_FALLBACK: int = 1350
#The refusal raise_reason gives for a short budget; the tier dialog pulses its income number on it.
const INCOME_REASON: String = "Not enough monthly income."
#Tier numerals for the upgrade lines of the plan and tier dialogs.
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
#The metrics keys _derived() publishes in two spellings, each spelling to the other. An override
#handed one of them is laid under the other too, so a reader of either spelling sees it.
const _KEY_TWINS: Dictionary = {"contractMetrics": "contract_metrics",
	"contract_metrics": "contractMetrics", "mercMetrics": "merc_metrics",
	"merc_metrics": "mercMetrics", "guildOpinion": "guild_opinion",
	"guild_opinion": "guildOpinion", "clientOpinion": "client_opinion",
	"client_opinion": "clientOpinion"}

var _plan: int = Plan.ENTERPRISE
var _tiers: Dictionary = {}
var _overrides: Dictionary = {}
#Highest tier already billed this cycle per upgrade id; re-buying up to it costs nothing today.
var _prepaid: Dictionary = {}
var _last_bill_day: int = -1


func _ready() -> void:
	reset()
	GameState.day_changed.connect(_on_day_changed)


func plan() -> int:
	return _plan


func plan_key() -> String:
	return PLAN_KEYS[_plan]


func plan_name(p: int = -1) -> String:
	var index: int = _plan if p < 0 else p
	return PLAN_NAMES[clampi(index, 0, PLAN_NAMES.size() - 1)]


#Switching plans: anything below Enterprise drops every upgrade tier the guild held.
func set_plan(p: int) -> void:
	_plan = clampi(p, Plan.FREE, Plan.ENTERPRISE)
	if _plan != Plan.ENTERPRISE:
		_tiers.clear()
	changed.emit()


func tier_of(id: String) -> int:
	return int(_tiers.get(id, 0))


func tiers() -> Dictionary:
	return _tiers.duplicate()


func max_tier(id: String) -> int:
	return UpgradeDefs.tier_count(id)


#True when the guild could hold this tier right now: Enterprise, a real id, a tier in range, and
#a met requirement. Lowering a tier never cascades into what was bought on top of it.
func can_buy(id: String, tier: int) -> bool:
	if not UpgradeDefs.has_id(id) or _plan != Plan.ENTERPRISE:
		return false
	if tier < 0 or tier > max_tier(id):
		return false
	return tier == 0 or UpgradeDefs.requirement_met(id, _tiers)


#Test hook.
func set_tier(id: String, tier: int) -> bool:
	if not can_buy(id, tier):
		return false
	_tiers[id] = tier
	changed.emit()
	return true


#The plan fee for the payroll plus every upgrade tier the guild holds, billed monthly.
func monthly_cost() -> int:
	return service_fee() + monthly_upgrade_cost()


func monthly_upgrade_cost() -> int:
	var total: int = 0
	for id: String in UpgradeDefs.ORDER:
		total += UpgradeDefs.monthly_of(id, _paid_tier(id))
	return total


func max_mercs() -> int:
	return UpgradeDefs.plan_max_mercs(_plan, _paid_tier("seats"))


func max_contracts() -> int:
	return UpgradeDefs.plan_max_contracts(_plan, _paid_tier("contracts"))


func entitlements() -> Dictionary:
	var out: Dictionary = _derived()
	for key: Variant in _overrides:
		out[key] = _overrides[key]
	return out


#Lays keys over the derived table; they win until reset() clears them. A key with a twin spelling
#lays the same value under the twin as well, unless the caller gave that spelling its own value.
func set_entitlements(d: Dictionary) -> void:
	for key: Variant in d:
		_overrides[key] = d[key]
	for key: Variant in d:
		var twin: String = String(_KEY_TWINS.get(key, ""))
		if twin != "" and not d.has(twin):
			_overrides[twin] = d[key]
	changed.emit()


#The start: Free with every tier at 0, nothing prepaid, no overrides.
func reset() -> void:
	_plan = Plan.FREE
	_tiers.clear()
	_prepaid.clear()
	_last_bill_day = -1
	_overrides.clear()
	changed.emit()


#Enterprise with every upgrade maxed: the state behind --plan=enterprise and the suites that need every screen.
func max_out() -> void:
	_plan = Plan.ENTERPRISE
	_tiers.clear()
	_prepaid.clear()
	_last_bill_day = -1
	for id: String in UpgradeDefs.ORDER:
		_tiers[id] = UpgradeDefs.tier_count(id)
	_overrides.clear()
	changed.emit()


#Sets the plan and the owned tiers in one step; unknown ids and out of range tiers are dropped.
func set_state(p: int, t: Dictionary) -> void:
	_plan = clampi(p, Plan.FREE, Plan.ENTERPRISE)
	_tiers.clear()
	if _plan == Plan.ENTERPRISE:
		for id: Variant in t:
			var key: String = String(id)
			if UpgradeDefs.has_id(key):
				_tiers[key] = clampi(int(t[id]), 0, UpgradeDefs.tier_count(key))
	changed.emit()


#"--plan=free|pro|enterprise|bare": the headless state to start from; absent leaves the default.
func apply_harness_flag() -> void:
	apply_plan_spec(HarnessHook.auto_spec(PLAN_FLAG))


#free reads 5/5, pro 8/8, enterprise every tier maxed (32/20), bare Enterprise base 8/8; other specs change nothing.
func apply_plan_spec(spec: String) -> void:
	match spec:
		"free":
			set_state(Plan.FREE, {})
		"pro":
			set_state(Plan.PRO, {})
		"enterprise":
			max_out()
		"bare":
			set_state(Plan.ENTERPRISE, {})


#How many mercs may be plotted at once; two or more opens the comparison picker.
func merc_slots() -> int:
	return int(entitlements().get("merc_metrics", 0))


#An upgrade tier only counts while the plan is Enterprise.
func _paid_tier(id: String) -> int:
	return tier_of(id) if _plan == Plan.ENTERPRISE else 0


#The flat key table every screen reads. Names are fixed by the design prototype; nothing else derives them.
func _derived() -> Dictionary:
	var combat: int = _paid_tier("combatpip")
	var skill: int = _paid_tier("skillpip")
	var counsel: int = _paid_tier("counsel")
	var discrim: int = _paid_tier("discrim")
	var promotions: int = _paid_tier("promotions")
	var methods: int = _paid_tier("promomethods")
	var guild_promo: int = _paid_tier("guildpromo")
	var promo_days: int = PROMO_DAY_CAPS[clampi(_paid_tier("longpromos"), 0,
		PROMO_DAY_CAPS.size() - 1)]
	var background: int = _paid_tier("background")
	var fast: int = _paid_tier("fastmetrics")
	var survey: bool = _paid_tier("survey") >= 1
	var contract_metrics: bool = _paid_tier("contractmetrics") >= 1
	var merc_metrics: int = _paid_tier("mercmetrics")
	var client: bool = _paid_tier("customer") >= 1
	var peer: bool = _paid_tier("peer") >= 1
	var criminal: bool = _paid_tier("criminal") >= 1
	var education: bool = _paid_tier("education") >= 1
	var skilltest: bool = _paid_tier("skilltest") >= 1
	var paid: bool = _plan >= Plan.PRO
	var refresh: String = SURVEY_REFRESH[clampi(fast, 0, SURVEY_REFRESH.size() - 1)]
	if not survey:
		refresh = "none"
	return {
		"plan": plan_key(),
		"metrics": paid,
		"contract_metrics": contract_metrics,
		"merc_metrics": merc_metrics,
		"guild_opinion": survey,
		"client_opinion": client,
		"peer": peer,
		"fastmetrics": fast,
		"pip": _paid_tier("pip") >= 1,
		"lvSupport": combat >= 1,
		"lvDefensive": combat >= 2,
		"lvOffensive": combat >= 3,
		"lvExisting": skill >= 1,
		"lvNewSkills": skill >= 2,
		"lvUniversal": skill >= 3,
		"lvAncestral": skill >= 4,
		"lvTradition": skill >= 5,
		"lvSpell": _paid_tier("magicpip") >= 1,
		"oddJobs": _paid_tier("oddjobs"),
		"bazaar": _paid_tier("bazaar") >= 1,
		"bazaarRarity": _paid_tier("betteritems"),
		"bazaarSpeed": _paid_tier("fasteritems"),
		"opsPermits": _paid_tier("opspermit"),
		"teleport": _paid_tier("teleport"),
		"representation": _paid_tier("representation"),
		"counsel": counsel,
		"counselPct": COUNSEL_PCT[clampi(counsel, 0, COUNSEL_PCT.size() - 1)],
		"whoKnows": _paid_tier("whoknows"),
		"promotions": promotions >= 1,
		"jobPostings": promotions >= 1,
		"maxPromoDays": promo_days if promotions >= 1 else 0,
		"adBoost": AD_BOOST_PCT[clampi(_paid_tier("marketing"), 0, AD_BOOST_PCT.size() - 1)],
		"hiringDiscrim": discrim >= 4,
		"discrim": discrim,
		"background": background,
		"criminal": criminal,
		"education": education,
		"skilltest": skilltest,
		"aptitude": _paid_tier("aptitude") >= 1,
		"brawn": _paid_tier("brawn") >= 1,
		"readiness": _paid_tier("readiness") >= 1,
		"personality": _paid_tier("personality") >= 1,
		"seats": _paid_tier("seats"),
		"contracts": _paid_tier("contracts"),
		"adDirect": methods >= 1,
		"adRadio": methods >= 2,
		"adSponsor": methods >= 3,
		"guildPromo": guild_promo >= 1,
		"gpMinDifficulty": guild_promo >= 2,
		"gpMaxDifficulty": guild_promo >= 3,
		"gpContractType": guild_promo >= 4,
		"perMerc": int(UpgradeDefs.plan_data(_plan).get("per_merc", 0)),
		"maxMercs": max_mercs(),
		"maxContracts": max_contracts(),
		"ancestry": discrim >= 1,
		"bloodline": discrim >= 2,
		"age": discrim >= 3,
		"heritage": background >= 1,
		"perks": background >= 2,
		"drawbacks": background >= 3,
		"skills": background >= 4,
		"lifepath": background >= 5,
		"criminality": criminal,
		"contractMetrics": contract_metrics,
		"mercMetrics": merc_metrics,
		"guildOpinion": survey,
		"clientOpinion": client,
		"relationships": peer,
		"physical": paid,
		"cognition": _paid_tier("aptitude") >= 1,
		"vigor": _paid_tier("brawn") >= 1,
		"dexterity": _paid_tier("readiness") >= 1,
		"wile": _paid_tier("personality") >= 1,
		"tools": skilltest,
		"knowledges": education,
		"surveyRefresh": refresh,
		"predictive": fast >= 5,
		"veryFast": paid,
	}


#The day of the month on the game calendar: 1 to 30, or 1 to 40 in a long month.
func day_of_month() -> int:
	return int(TrynnCalendar.date_of(CampaignClock.now()).get("day", 1))


#Whole days to the next bill day; on the bill day itself the distance to the one of the next month.
func days_to_bill() -> int:
	var day: int = day_of_month()
	if day < BILL_DAY:
		return BILL_DAY - day
	return (_days_this_month() - day) + BILL_DAY


#Mercs holding a seat (GuiTypes.counts_toward_roster). A captive keeps the seat and the fee until freed or lost.
func employed() -> int:
	var total: int = 0
	for merc: MercenaryData in GameState.mercs:
		if merc != null and GuiTypes.counts_toward_roster(int(GameState.merc_status(merc)["status"])):
			total += 1
	return total


#Open postings taking up a board slot, campaign postings included; Active runs and closed rows hold none.
func board_count() -> int:
	var total: int = 0
	for view: ContractView in GameState.contracts:
		if view.status == GuiTypes.ContractStatus.AVAILABLE:
			total += 1
	return total


#The plan's own monthly fee: the per merc price times the payroll. -1 reads the current plan.
func service_fee(p: int = -1) -> int:
	var index: int = _plan if p < 0 else clampi(p, Plan.FREE, Plan.ENTERPRISE)
	return int(UpgradeDefs.plan_data(index).get("per_merc", 0)) * employed()


func can_switch(p: int) -> bool:
	return switch_reason(p) == ""


#Why a switch is refused, in the words the plan card shows; "" when it is allowed.
func switch_reason(p: int) -> String:
	var index: int = clampi(p, Plan.FREE, Plan.ENTERPRISE)
	if index == _plan:
		return "This is your current plan"
	var cap: int = int(UpgradeDefs.plan_data(index).get("max_mercs", 0))
	var crew: int = employed()
	if crew > cap:
		return "You have %d mercs. %s allows up to %d." % [crew, plan_name(index), cap]
	var fee: int = service_fee(index)
	if fee > GameState.bank_notes:
		return "You need at least %d notes (1 month of service) to switch." % fee
	return ""


#Switching needs one month of the new fee in the bank and charges nothing today.
func switch_plan(p: int) -> bool:
	if not can_switch(p):
		return false
	set_plan(clampi(p, Plan.FREE, Plan.ENTERPRISE))
	return true


#Monthly income a new add-on may be billed against: income less the other fixed expenses.
func budget_available() -> int:
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance == null or not finance.has_method("budget"):
		return BUDGET_FALLBACK
	var budget: Dictionary = finance.call("budget") as Dictionary
	return int(budget.get("income", 0)) - int(budget.get("other_expenses", 0))


#What the owned tiers cost every month: one upgrade when id is given, every upgrade otherwise.
func upgrade_fee(id: String = "") -> int:
	if id == "":
		return monthly_upgrade_cost()
	return UpgradeDefs.monthly_of(id, _paid_tier(id))


func prepaid_tier(id: String) -> int:
	return int(_prepaid.get(id, 0))


#The price of one tier on its own, without the tiers under it.
func tier_price(id: String, tier: int) -> int:
	if tier <= 0:
		return 0
	return UpgradeDefs.monthly_of(id, tier) - UpgradeDefs.monthly_of(id, tier - 1)


#What raising this upgrade to that tier costs right now: nothing when this cycle already paid for
#it, else the tier price pro-rated over the days left before the bill day, capped at the full price.
func upgrade_charge_today(id: String, tier: int) -> int:
	var price: int = tier_price(id, tier)
	if price <= 0 or tier <= prepaid_tier(id):
		return 0
	var share: float = float(price) * float(days_to_bill()) / float(MONTH_DAYS)
	return mini(price, int(ceil(share)))


#The tier a live roster or board holds in place: seats keep the mercs, contracts the board.
func min_tier(id: String) -> int:
	if id == "seats":
		var over: int = employed() - UpgradeDefs.ENTERPRISE_MERCS
		return maxi(0, int(ceil(float(over) / float(UpgradeDefs.MERCS_PER_SEAT))))
	if id == "contracts":
		var spare: int = board_count() - UpgradeDefs.ENTERPRISE_CONTRACTS
		return maxi(0, int(ceil(float(spare) / float(UpgradeDefs.CONTRACTS_PER_TIER))))
	return 0


func can_raise(id: String) -> bool:
	return raise_reason(id) == ""


#Why one more tier is refused; "" when it can be bought.
func raise_reason(id: String) -> String:
	if not UpgradeDefs.has_id(id):
		return "Already at the highest tier."
	if _plan != Plan.ENTERPRISE:
		return "Requires %s." % PLAN_NAMES[Plan.ENTERPRISE]
	var tier: int = tier_of(id)
	if tier >= max_tier(id):
		return "Already at the highest tier."
	if not UpgradeDefs.requirement_met(id, _tiers):
		var need: int = UpgradeDefs.requirement_need(id) - UpgradeDefs.requirement_have(id, _tiers)
		need = maxi(1, need)
		return "%d prior upgrade%s still required" % [need, "" if need == 1 else "s"]
	var next_fee: int = tier_price(id, tier + 1)
	if budget_available() - (service_fee() + upgrade_fee() + next_fee) < 0:
		return INCOME_REASON
	if upgrade_charge_today(id, tier + 1) > GameState.bank_notes:
		return "Not enough notes."
	return ""


#Buys one tier: spends the pro-rated charge and remembers what this cycle has paid for.
func buy_tier(id: String) -> bool:
	if not can_raise(id):
		return false
	var tier: int = tier_of(id) + 1
	var charge: int = upgrade_charge_today(id, tier)
	if charge > 0:
		var label: String = "%s %s" % [UpgradeDefs.name_of(id), roman(tier)]
		if not GameState.spend(charge, GameState.REASON_UPGRADE, label):
			return false
	_prepaid[id] = maxi(prepaid_tier(id), tier)
	_tiers[id] = tier
	changed.emit()
	return true


func can_lower(id: String) -> bool:
	return lower_reason(id) == ""


#Why one tier down is refused; "" when it can be dropped.
func lower_reason(id: String) -> String:
	if not UpgradeDefs.has_id(id):
		return "Already at the lowest tier."
	if _plan != Plan.ENTERPRISE:
		return "Requires %s." % PLAN_NAMES[Plan.ENTERPRISE]
	var tier: int = tier_of(id)
	if tier <= 0:
		return "Already at the lowest tier."
	var floor_tier: int = min_tier(id)
	if tier <= floor_tier:
		if id == "seats":
			return "Can't go below Tier %d: %d mercs are using those seats." % [floor_tier,
				employed()]
		if id == "contracts":
			return "Can't go below Tier %d: %d contracts are on your board." % [floor_tier,
				board_count()]
		return "Already at the lowest tier."
	return ""


#Drops one tier; nothing is refunded and every upgrade left without its requirement falls to 0.
func lower_tier(id: String) -> bool:
	if not can_lower(id):
		return false
	_tiers[id] = tier_of(id) - 1
	_cascade(id)
	changed.emit()
	return true


#Tier numerals I to VIII, then the plain number.
func roman(n: int) -> String:
	if n >= 1 and n <= ROMAN.size():
		return ROMAN[n - 1]
	return str(n)


#Every upgrade the guild owns in table order: id, owned tier, tier count and what that tier bills a month.
func owned_upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in UpgradeDefs.ORDER:
		var tier: int = _paid_tier(id)
		if tier > 0:
			out.append({"id": id, "tier": tier, "max": UpgradeDefs.tier_count(id),
				"fee": UpgradeDefs.monthly_of(id, tier)})
	return out


#Every upgrade the guild owns with its tier numeral, in table order.
func owned_lines() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in owned_upgrades():
		out.append("%s %s" % [UpgradeDefs.name_of(String(row["id"])), roman(int(row["tier"]))])
	return out


#Days in the calendar month that holds the current minute.
func _days_this_month() -> int:
	var month: int = int(TrynnCalendar.date_of(CampaignClock.now()).get("month", 0))
	month = clampi(month, 0, TrynnCalendar.MONTHS.size() - 1)
	return int(TrynnCalendar.MONTHS[month]["days"])


#Whatever an upgrade unlocked falls to 0 once its requirement is gone, and so on down the chain.
func _cascade(id: String) -> void:
	for other: String in UpgradeDefs.dependants_of(id):
		if tier_of(other) > 0 and not UpgradeDefs.requirement_met(other, _tiers):
			_tiers[other] = 0
			_cascade(other)


#The billing day starts a new cycle, so nothing is prepaid any more.
func _on_day_changed(day_index: int) -> void:
	if day_of_month() != BILL_DAY or _last_bill_day == day_index:
		return
	_last_bill_day = day_index
	_prepaid.clear()

extends Node

#Campaigns and applicants for My Promotions and Finance > Hiring: the one place both screens read.
#The tables live in CampaignTypeDefs and TraitFilterDefs, so nothing here branches per campaign
#type or per trait. Everything the design prototype marks PLACEHOLDER sits in the block below. Every applicant
#is a full merc rolled the moment they appear; reset() rolls fresh draws each game unless a test pins fixed_seed.
#Arrival timing and the campaign quality bias are open items.

signal campaigns_changed
signal applicants_changed
signal applicant_arrived(applicant: ApplicantData)
signal applicant_hired(applicant: ApplicantData, salary: int, opinion_delta: int)
signal counter_resolved(applicant_id: int, accepted: bool)
#Test hooks: one monthly charge of an Infinite campaign went through, or the bank could not cover
#it and the campaign came down.
signal campaign_billed(id: int, amount: int)
signal campaign_bill_failed(id: int, name: String)

#PLACEHOLDER
#The arrival and counter delays, the Odd Job pay and the fit a roster merc brings to a counter-offer.
#Every number here waits on a real system.
#The ledger reason every campaign charge and refund carries; Odd Job pay rides the one
#GameState already keeps.
const REASON_ADS: String = GameState.REASON_ADS
#The separator GuildTargeting joins several picked companies with.
const TARGET_JOIN: String = ", "
const ARRIVAL_DAYS: int = 3
#Word of Mouth daily chance in percent (answer 55): per crew Wile point, the Speech and Knowledge bonuses, the cap.
const WOM_PER_WILE: float = 2.0
const WOM_BONUS: float = 5.0
const WOM_CAP: float = 95.0
const WOM_KNOWLEDGES: Array[String] = ["Salesmanship", "Diplomacy", "Business Operations", "Psychology"]
const COUNTER_DAYS: int = 3
const DEFAULT_ODD_JOB_PAY: int = 25
const FIT_SEED: int = 7
const FIT_STEP: int = 37
const FIRST_APPLICANT_ID: int = 20
const RED_TEXT: String = "The guild is in the red."

#Guild Opinion on hire, richest step first: at the asking rate and at each margin over it.
const OPINION_STEPS: Array[Dictionary] = [{"over": 1.0, "delta": 5}, {"over": 0.5, "delta": 4},
	{"over": 0.25, "delta": 3}, {"over": 0.1, "delta": 2}, {"over": 0.0, "delta": 1}]
#The margin comparison runs on floats, so each step is met a hair early.
const OPINION_EPSILON: float = 0.0001
#The four sorts of the Hiring header, in dropdown order.
const SORTS: Array[Dictionary] = [{"key": &"uniqueness", "label": "Uniqueness"},
	{"key": &"fit", "label": "Fit"}, {"key": &"level", "label": "Level"},
	{"key": &"salary", "label": "Salary"}]
#The five sorts of the My Promotions header, in dropdown order. Start Date is the default and it
#reads newest first.
const CAMPAIGN_SORTS: Array[Dictionary] = [{"key": &"start", "label": "Start Date"},
	{"key": &"left", "label": "Time Remaining"}, {"key": &"success", "label": "Success Rate"},
	{"key": &"method", "label": "Campaign Method"}, {"key": &"cost", "label": "Cost"}]
const CAMPAIGN_SORT_DEFAULT: StringName = &"start"
const CAMPAIGN_ASCENDING_DEFAULT: bool = false
#A campaign list is per tab, and each tab is locked by its own entitlement. tiers is how many
#tiers the upgrade behind the lock holds, so a FeatureLock can read "tier N of M".
const MODE_LOCKS: Dictionary = {
	"job": {"gate": "jobPostings", "upgrade_id": "promotions", "tier": 1, "tiers": 1,
		"name": "Promotions", "feature": "Job Postings", "text": "Job Postings are locked."},
	"promo": {"gate": "guildPromo", "upgrade_id": "guildpromo", "tier": 1, "tiers": 4,
		"name": "Guild Promo", "feature": "Guild Promotion",
		"text": "Guild Promotion is locked."},
}
#The Guild Promo fields a locked tier keeps at its default: a builder that moved one off its
#default cannot launch. A null default means an empty list.
const GUILD_FIELD_LOCKS: Array[Dictionary] = [
	{"gate": "gpMinDifficulty", "field": "difficulty_lo", "default": 0.5,
		"label": "Minimum Difficulty"},
	{"gate": "gpMaxDifficulty", "field": "difficulty_hi", "default": 5.0,
		"label": "Maximum Difficulty"},
	{"gate": "gpContractType", "field": "contract_types", "default": null,
		"label": "Contract Type"},
]
const ODDS_LOW: float = 5.0
const ODDS_HIGH: float = 95.0
#What a merc sent on a counter-offer adds to the odds, per fit star.
const ODDS_PER_FIT: float = 3.0
#Why a crew cannot go out: one of its mercs is already away, on a contract or resting.
const CREW_BUSY_TEXT: String = "A picked merc is not free."

var campaigns: Array[CampaignData] = []
var applicants: Array[ApplicantData] = []
#Campaign id to name, kept for every campaign that ever ran so an applicant of an ended campaign
#still shows where it came from.
var campaign_names: Dictionary = {}
#Test hook: the Infinite campaigns the bank could not pay for, newest last: {id, name, day, amount}.
var billing_failures: Array[Dictionary] = []
var next_campaign_id: int = 1
var next_applicant_id: int = FIRST_APPLICANT_ID
#The merc the last hire signed on, for the screen that has to open their card; 0 = none yet.
var last_hired_uid: int = 0

#Test hook: zero or more seeds every reset with it so the applicant draws repeat; under zero each game rolls fresh.
var fixed_seed: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
#The merc behind each open applicant, by applicant id.
var _applicant_mercs: Dictionary = {}
var _seeded: bool = false
#True while reset() runs and while this manager writes away rows itself: set_away
#and clear_away both emit roster_changed, which calls this manager again. A crew coming home must
#not be sent straight back out by the restore that signal runs.
var _resetting: bool = false
var _restoring: bool = false
#The away rows this manager put in GameState, by merc uid. reset() clears these and no other.
var _away_uids: Dictionary = {}
#The last day this manager settled. A roster signal can arrive while the clock still reads an
#earlier day, and a campaign this manager has already closed must not be held open again.
var _last_day: int = -1


func _ready() -> void:
	GameState.game_started.connect(_on_game_started)
	GameState.roster_changed.connect(_restore_holds)
	GameState.day_changed.connect(_on_day_changed)


#A new game opens on an empty board of campaigns and the start pool of applicants.
func _on_game_started() -> void:
	reset()
	fill_start_pool()


#Drops every campaign, applicant and away row and reseeds the draws.
func reset() -> void:
	_seeded = true
	_resetting = true
	if fixed_seed >= 0:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()
	_last_day = -1
	_clear_away_rows()
	last_hired_uid = 0
	campaigns.clear()
	applicants.clear()
	_applicant_mercs.clear()
	campaign_names.clear()
	billing_failures.clear()
	next_applicant_id = FIRST_APPLICANT_ID
	next_campaign_id = 1
	_resetting = false
	campaigns_changed.emit()
	applicants_changed.emit()


func has_unseen() -> bool:
	_ensure()
	for applicant: ApplicantData in applicants:
		if applicant.unseen:
			return true
	return false


func mark_seen() -> void:
	_ensure()
	var applicants_dirty: bool = false
	for applicant: ApplicantData in applicants:
		if applicant.unseen:
			applicant.unseen = false
			applicants_dirty = true
	if applicants_dirty:
		applicants_changed.emit()


#Clears one card's dot: View, Offer and Reject all call this.
func mark_applicant_seen(id: int) -> bool:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null or not applicant.unseen:
		return false
	applicant.unseen = false
	applicants_changed.emit()
	return true


func next_campaign_name() -> String:
	_ensure()
	return "Campaign %d" % next_campaign_id


func campaign_of(id: int) -> CampaignData:
	_ensure()
	for campaign: CampaignData in campaigns:
		if campaign.id == id:
			return campaign
	return null


#What a campaign was called, whether or not it is still running. The Applied Via chips read it.
func campaign_name(id: int) -> String:
	_ensure()
	if id == ApplicantData.WALK_IN:
		return "Walk-In"
	return String(campaign_names.get(id, ""))


func applicant_of(id: int) -> ApplicantData:
	_ensure()
	for applicant: ApplicantData in applicants:
		if applicant.id == id:
			return applicant
	return null


#How many applicants could take an offer now: one mid counter-offer cannot until it settles.
func open_applicants() -> int:
	_ensure()
	var total: int = 0
	for applicant: ApplicantData in applicants:
		if applicant != null and applicant.is_open():
			total += 1
	return total


#One tab's campaigns, in list order. campaigns_filtered and campaigns_sorted do the rest.
func campaigns_in(mode: String) -> Array[CampaignData]:
	_ensure()
	var out: Array[CampaignData] = []
	for campaign: CampaignData in campaigns:
		if campaign.mode == mode:
			out.append(campaign)
	return out


#The M of "N of M shown".
func campaign_count(mode: String) -> int:
	return campaigns_in(mode).size()


#The campaigns the two header toggles leave standing.
func campaigns_filtered(mode: String, show_concluded: bool, show_infinite: bool,
		today: int) -> Array[CampaignData]:
	var out: Array[CampaignData] = []
	for campaign: CampaignData in campaigns_in(mode):
		if not show_infinite and campaign.infinite:
			continue
		if not show_concluded and campaign.is_concluded(today):
			continue
		out.append(campaign)
	return out


#One of the five header sorts. A tie always resolves to the newer campaign, whichever way the
#arrow points, so the newest work stays near the top.
func campaigns_sorted(list: Array[CampaignData], key: StringName, ascending: bool,
		today: int) -> Array[CampaignData]:
	var out: Array[CampaignData] = list.duplicate()
	out.sort_custom(_by_value(campaign_sort_value.bind(key, today), not ascending, true, true))
	return out


#A sort_custom comparator on value(row), larger first when high_first. Rows whose values match,
#or nearly match when approx is set, order by id, the newest first when newer_first is set.
func _by_value(value: Callable, high_first: bool, approx: bool, newer_first: bool) -> Callable:
	return func(a: Variant, b: Variant) -> bool:
		var left: float = value.call(a)
		var right: float = value.call(b)
		if left == right or (approx and is_equal_approx(left, right)):
			return a.id > b.id if newer_first else a.id < b.id
		return left > right if high_first else left < right


#What one campaign sorts on. Campaign Method reads minus the type index, so the best method
#leads when the arrow points up.
func campaign_sort_value(campaign: CampaignData, key: StringName, today: int) -> float:
	if campaign == null:
		return 0.0
	match key:
		&"left":
			return float(campaign.days_left(today))
		&"success":
			return success_rate(campaign, today)
		&"method":
			return -float(CampaignTypeDefs.keys().find(campaign.type_key))
		&"cost":
			return float(campaign.total_committed(today))
	return float(campaign.day_started)


func campaign_sort_label(key: StringName) -> String:
	return TraitFilterDefs.label_of(CAMPAIGN_SORTS, key)


#A job ad's mercs pulled in: the arrivals still on the list plus the ones already dealt with.
#A Guild Promo counts the contracts it has posted.
func results_of(campaign: CampaignData) -> int:
	if campaign == null:
		return 0
	var count: int = campaign.results
	if campaign.mode == CampaignData.MODE_JOB:
		count += _arrived_through(campaign.id)
	return count


#Results per week so far, which is what the card calls its success rate.
func success_rate(campaign: CampaignData, today: int) -> float:
	if campaign == null:
		return 0.0
	return float(results_of(campaign)) / float(maxi(1, campaign.run_days(today))) * 7.0


#The merc filter rows the Hiring list shows: the campaign chips need the live job campaigns.
func hiring_defs() -> Array[Dictionary]:
	return TraitFilterDefs.merc_defs(true, campaigns_in(CampaignData.MODE_JOB))


func pay_per_of(campaign: CampaignData) -> int:
	if campaign == null or campaign.pay_per <= 0:
		return default_pay()
	return campaign.pay_per


func default_pay() -> int:
	return DEFAULT_ODD_JOB_PAY


#What launching takes out of the bank now: the days up to the first bill date, or to the end of a
#fixed run if sooner, and a Word of Mouth campaign pays its crew.
func launch_cost(campaign: CampaignData) -> int:
	if campaign == null:
		return 0
	if CampaignTypeDefs.is_crew_paid(campaign.type_key):
		return CampaignTypeDefs.cost(campaign.type_key, 0, campaign.crew.size(),
			pay_per_of(campaign))
	return first_charge(campaign.type_key, GameState.day(), 0 if campaign.infinite else campaign.days)


#Days a launch on that day pays for: up to its first bill date, capped at days for a fixed run (days > 0).
func first_bill_days(day: int, days: int = 0) -> int:
	var gap: int = TrynnCalendar.next_day_on(day, FinanceManager.bill_day_from(day)) - day
	return gap if days <= 0 else mini(gap, days)


#A launch on that day: per_day for each of its first_bill_days.
func first_charge(key: StringName, day: int, days: int = 0) -> int:
	return int(CampaignTypeDefs.find(key).get("per_day", 0)) * first_bill_days(day, days)


func mode_unlocked(mode: String, ent: Dictionary) -> bool:
	var row: Dictionary = MODE_LOCKS.get(mode, {})
	if row.is_empty():
		return false
	return CampaignTypeDefs.gate_met(ent, String(row["gate"]))


#The FeatureLock target behind a locked tab, or an empty dictionary for an unknown tab.
func mode_lock(mode: String) -> Dictionary:
	var row: Dictionary = MODE_LOCKS.get(mode, {})
	return row.duplicate()


#Why a campaign cannot go out, in the order the builder shows the reasons.
func can_launch(campaign: CampaignData) -> Dictionary:
	_ensure()
	if campaign == null:
		return _refuse("No campaign.")
	var ent: Dictionary = SubscriptionManager.entitlements()
	var row: Dictionary = CampaignTypeDefs.find(campaign.type_key)
	if row.is_empty():
		return _refuse("Unknown campaign type.")
	var type_name: String = String(row["name"])
	if not CampaignTypeDefs.unlocked(campaign.type_key, ent):
		return _refuse("%s is locked." % type_name)
	if bool(row["guild_only"]) and campaign.mode == CampaignData.MODE_JOB:
		return _refuse("%s is for Guild Promo only." % type_name)
	var picks: String = String(row["picks"])
	if picks != "" and not _has_target(campaign):
		if picks == CampaignTypeDefs.PICK_COMPANY_OR_EVENT:
			return _refuse("Choose who to sponsor.")
		return _refuse("Choose who to advertise to.")
	var duration: Dictionary = _duration_verdict(campaign, ent)
	if not bool(duration["ok"]):
		return duration
	var places: Dictionary = _location_verdict(campaign, row)
	if not bool(places["ok"]):
		return places
	var fields: Dictionary = _guild_field_verdict(campaign, ent)
	if not bool(fields["ok"]):
		return fields
	if not mode_unlocked(campaign.mode, ent):
		return _refuse(String(mode_lock(campaign.mode).get("text", "That tab is locked.")))
	if CampaignTypeDefs.is_crew_paid(campaign.type_key):
		var seats: int = TraitFilterDefs.tier_of(ent, "oddJobs")
		if campaign.crew.is_empty():
			return _refuse("Add at least one merc.")
		if campaign.crew.size() > seats:
			return _refuse("Odd Jobs holds %d mercs." % seats)
	if not GameState.can_afford(launch_cost(campaign)):
		return _refuse("Not enough notes.")
	if _holds_busy_merc(campaign.crew):
		return _refuse(CREW_BUSY_TEXT)
	return _allow()


#Stamps the campaign, takes the notes and starts it running today.
func launch(campaign: CampaignData) -> bool:
	if not bool(can_launch(campaign)["ok"]):
		return false
	var row: Dictionary = CampaignTypeDefs.find(campaign.type_key)
	campaign.locations = CampaignTypeDefs.fit_locations(campaign.type_key, campaign.locations)
	if campaign.filters.has(&"loc"):
		campaign.filters[&"loc"] = campaign.locations.duplicate()
	campaign.pay_per = pay_per_of(campaign)
	campaign.per_day = int(row["per_day"])
	if campaign.infinite:
		campaign.days = 0
	campaign.total_cost = launch_cost(campaign)
	campaign.id = next_campaign_id
	next_campaign_id += 1
	if campaign.name.strip_edges() == "":
		campaign.name = "Campaign %d" % campaign.id
	campaign_names[campaign.id] = campaign.name
	campaign.day_started = GameState.day()
	campaign.results = 0
	campaign.next_bill_day = -1
	campaign.bill_day = -1
	if campaign.per_day > 0:
		campaign.bill_day = FinanceManager.bill_day_from(campaign.day_started)
		campaign.next_bill_day = campaign.bill_after(campaign.day_started)
	campaign.next_arrival_day = -1
	if campaign.mode == CampaignData.MODE_PROMO:
		campaign.next_arrival_day = campaign.day_started + ARRIVAL_DAYS
	if CampaignTypeDefs.is_crew_paid(campaign.type_key):
		GameState.spend(campaign.total_cost, GameState.REASON_ODD_JOB,
			"%s - Word of Mouth" % campaign.name)
	else:
		GameState.spend(campaign.total_cost, REASON_ADS, "%s - %s" % [campaign.name, String(row["name"])])
	campaigns.append(campaign)
	_crew_away(campaign)
	campaigns_changed.emit()
	return true


#What ending a campaign now would hand back, for the confirm dialog.
func end_preview(id: int) -> Dictionary:
	var campaign: CampaignData = campaign_of(id)
	if campaign == null:
		return {"ok": false, "refund": 0, "unused": 0, "infinite": false, "crew_paid": false}
	var today: int = GameState.day()
	return {"ok": not campaign.is_concluded(today), "refund": campaign.budget_remaining(today),
		"unused": campaign.unused_days(today), "infinite": campaign.infinite,
		"crew_paid": CampaignTypeDefs.is_crew_paid(campaign.type_key)}


#Takes a campaign down now and hands back the days it paid for and never used. A campaign that
#already ran out has nothing left to give, so it cannot be ended.
func end(id: int) -> bool:
	var campaign: CampaignData = campaign_of(id)
	if campaign == null:
		return false
	var today: int = GameState.day()
	if campaign.is_concluded(today):
		return false
	var refund: int = campaign.budget_remaining(today)
	if refund > 0:
		GameState.refund(refund, REASON_ADS, "%s - Refund" % campaign.name)
	_bring_home(campaign.crew)
	campaigns.erase(campaign)
	campaigns_changed.emit()
	return true


#What the next bill of every running campaign comes to: its days to the next bill date or its end.
func monthly_ad_bill() -> int:
	_ensure()
	var total: int = 0
	for campaign: CampaignData in campaigns:
		total += next_bill_amount(campaign)
	return total


#The campaign's next bill, or 0 when it has none left.
func next_bill_amount(campaign: CampaignData) -> int:
	if campaign == null or campaign.next_bill_day < 0:
		return 0
	return campaign.period_cost(campaign.next_bill_day)


#The campaigns with a bill still to come.
func billed_count() -> int:
	_ensure()
	var count: int = 0
	for campaign: CampaignData in campaigns:
		if campaign.next_bill_day >= 0:
			count += 1
	return count


func infinite_count() -> int:
	_ensure()
	var count: int = 0
	for campaign: CampaignData in campaigns:
		if campaign.infinite:
			count += 1
	return count


#Every bill falling due inside the window, earliest first, for the Finance calendar.
func ad_bill_days(today: int, horizon: int) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	var limit: int = today + maxi(0, horizon)
	for campaign: CampaignData in campaigns:
		var day: int = campaign.next_bill_day
		while day >= 0 and day < limit:
			if day >= today:
				out.append({"day": day, "amount": campaign.period_cost(day), "campaign_id": campaign.id})
			day = campaign.bill_after(day)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["day"]) == int(b["day"]):
			return int(a["campaign_id"]) < int(b["campaign_id"])
		return int(a["day"]) < int(b["day"]))
	return out


#Opens Hiring on one campaign's arrivals: the View Applicants button of a job ad card.
func view_applicants(id: int) -> void:
	_ensure()
	GameState.open_hiring(id)


#Opens the contract board on one campaign's postings: the View Contracts button of a Guild Promo card.
func view_contracts(id: int) -> void:
	_ensure()
	GameState.open_contracts(id)


#The applicants a filter set leaves, sorted by one of the four Hiring keys. via holds the
#campaign ids the Applied Via chips picked, with WALK_IN for the applicants nobody sent.
func applicants_filtered(filters: Dictionary = {}, via: Array[int] = [],
		sort: StringName = &"fit", descending: bool = true) -> Array[ApplicantData]:
	_ensure()
	var ent: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = hiring_defs()
	var out: Array[ApplicantData] = []
	for applicant: ApplicantData in applicants:
		if not via.is_empty() and not via.has(applicant.campaign_id):
			continue
		if _matches(applicant, filters, defs, ent):
			out.append(applicant)
	out.sort_custom(_by_value(_sort_value.bind(sort), descending, false, false))
	return out


func sort_label(key: StringName) -> String:
	return TraitFilterDefs.label_of(SORTS, key)


#The roster cap the plan and the Seats tier hold; the key "seats" is a tier, never a seat count.
func max_mercs() -> int:
	return SubscriptionManager.max_mercs()


func free_slots() -> int:
	return maxi(0, max_mercs() - SubscriptionManager.employed())


#What hiring at this salary does to Guild Opinion: the asking rate is worth one step already.
func opinion_delta(ask: int, salary: int) -> int:
	if ask <= 0:
		return 0
	var over: float = float(salary) / float(ask) - 1.0
	if over < -OPINION_EPSILON:
		return 0
	for step: Dictionary in OPINION_STEPS:
		if over >= float(step["over"]) - OPINION_EPSILON:
			return int(step["delta"])
	return 0


func can_hire(id: int, salary: int) -> Dictionary:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null:
		return _refuse("No such applicant.")
	if applicant.status == ApplicantData.STATUS_COUNTERED:
		return _refuse("Waiting for their answer.")
	if not applicant.is_open():
		return _refuse("This applicant is gone.")
	if free_slots() <= 0:
		return _refuse("No free merc slots.")
	if GameState.is_in_red():
		return _refuse(RED_TEXT)
	if not GameState.can_afford(hire_charge_for(salary)):
		return _refuse("Not enough notes for their first month.")
	return _allow()


#The first pay a hire costs now: the salary pro-rated over the days left to the next payday.
func hire_charge_for(salary: int) -> int:
	var now: int = CampaignClock.now()
	var days: int = TrynnCalendar.day_index(GameState.next_payday_minute()) - TrynnCalendar.day_index(now)
	var month: int = int(TrynnCalendar.date_of(now)["month"])
	return HirePool.hire_charge(salary, days, int(TrynnCalendar.MONTHS[month]["days"]))


#Signs an applicant on. The roster addition is the hook: applicant_hired carries the salary and
#the Guild Opinion the new merc starts with.
func hire(id: int, salary: int) -> bool:
	if not bool(can_hire(id, salary)["ok"]):
		return false
	var applicant: ApplicantData = applicant_of(id)
	return _hire_at(applicant, salary, opinion_delta(applicant.ask, salary))


#Signs one applicant on: the first pay leaves the bank, the merc rolled when they appeared joins the roster on the
#agreed salary, the opinion change lands on top of the opening opinion and the applicant leaves the list.
func _hire_at(applicant: ApplicantData, salary: int, delta: int) -> bool:
	if applicant == null:
		return false
	var pay: int = hire_charge_for(maxi(1, salary))
	if pay > 0 and not GameState.spend(pay, GameState.REASON_HIRE, "%s - First pay" % applicant.name):
		return false
	applicant.status = ApplicantData.STATUS_HIRED
	applicant.unseen = false
	_keep_result(applicant)
	applicants.erase(applicant)
	last_hired_uid = 0
	var merc: MercenaryData = merc_of(applicant)
	_applicant_mercs.erase(applicant.id)
	if merc != null:
		GameState.hire(merc)
		merc.monthly_salary = maxi(1, salary)
		SalarySystem.adjust_opinion(merc, delta)
		last_hired_uid = merc.merc_uid
		GameState.refresh_views()
		GameState.roster_changed.emit()
	applicants_changed.emit()
	applicant_hired.emit(applicant, salary, delta)
	return true


#The merc rolled for an applicant when they appeared; null for one this manager did not roll.
func merc_of(applicant: ApplicantData) -> MercenaryData:
	if applicant == null:
		return null
	return _applicant_mercs.get(applicant.id, null) as MercenaryData


#Rolls the merc behind an applicant; the name, level, tradition, ancestry, stats and asking rate read off it. The ask
#is stamped on the merc against the roster of this moment and stays frozen from then on.
func _give_merc(applicant: ApplicantData, level: int) -> void:
	applicant.level = level
	var merc: MercenaryData = _generate_merc(level, applicant.tradition)
	applicant.ancestry = _ancestry_of(merc, applicant.id)
	if merc == null:
		return
	_applicant_mercs[applicant.id] = merc
	applicant.name = merc.merc_name
	applicant.level = ExperienceSystem.current_level(merc)
	if merc.tradition != null:
		applicant.tradition = merc.tradition.tradition_name
	for key: String in ApplicantData.STAT_KEYS:
		applicant.stats[key] = roundi(float(merc.stats.get(key, 0.0)))
	merc.salary_ask = SalarySystem.asking_salary(merc, GameState.mercs)
	applicant.ask = merc.salary_ask


#The dominant ancestry name of a rolled merc; with none rolled, a real name picked by id so no draw is spent.
func _ancestry_of(merc: MercenaryData, id: int) -> String:
	if merc != null and merc.ancestry != null:
		return merc.ancestry.ancestry_name
	var known: Array[String] = TraitFilterDefs.ancestry_names()
	return known[id % known.size()] if not known.is_empty() else ""


func _generate_merc(level: int, tradition: String) -> MercenaryData:
	var held_level: int = MercGenerator.forced_level
	var held_tradition: String = MercGenerator.forced_tradition
	MercGenerator.forced_level = maxi(1, level)
	MercGenerator.forced_tradition = tradition
	var merc: MercenaryData = MercGenerator.generate(GameState.mercs.size())
	MercGenerator.forced_level = held_level
	MercGenerator.forced_tradition = held_tradition
	return merc


func reject(id: int) -> bool:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null or applicant.status == ApplicantData.STATUS_COUNTERED:
		return false
	applicant.status = ApplicantData.STATUS_REJECTED
	applicant.unseen = false
	_applicant_mercs.erase(applicant.id)
	_keep_result(applicant)
	applicants.erase(applicant)
	applicants_changed.emit()
	return true


#The fit a roster merc brings to an Odd Job, until a real fit reader exists.
func merc_fit(uid: int) -> float:
	var step: int = absi(uid * FIT_STEP + FIT_SEED) % 10
	return clampf(float(step) / 2.0 + 0.5, 0.5, 5.0)


#How likely an applicant is to take an offer under their asking rate.
func counter_odds(id: int, offer: int, team: Array[int] = []) -> int:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null or applicant.ask <= 0:
		return 0
	var ratio: float = float(offer) / float(applicant.ask)
	var odds: float = 100.0 - (1.0 - ratio) * 200.0
	for uid: int in team:
		odds += merc_fit(uid) * ODDS_PER_FIT
	return roundi(clampf(odds, ODDS_LOW, ODDS_HIGH))


func can_counter(id: int, offer: int, team: Array[int] = [], pay_per: int = 0) -> Dictionary:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null:
		return _refuse("No such applicant.")
	if applicant.status == ApplicantData.STATUS_COUNTERED:
		return _refuse("Waiting for their answer.")
	if not applicant.is_open():
		return _refuse("This applicant is gone.")
	if offer >= applicant.ask:
		return _refuse("That is their asking rate or better.")
	if free_slots() <= 0:
		return _refuse("No free merc slots.")
	if GameState.is_in_red():
		return _refuse(RED_TEXT)
	var seats: int = TraitFilterDefs.tier_of(SubscriptionManager.entitlements(), "oddJobs")
	if team.size() > seats:
		return _refuse("Odd Jobs holds %d mercs." % seats)
	if not GameState.can_afford(team.size() * maxi(0, pay_per)):
		return _refuse("Not enough notes for Odd Job pay.")
	if _holds_busy_merc(team):
		return _refuse(CREW_BUSY_TEXT)
	return _allow()


#Sends a counter-offer with an Odd Job crew. The pay leaves the bank now and the answer lands
#COUNTER_DAYS later on the day tick.
func counter(id: int, offer: int, team: Array[int] = [], pay_per: int = 0) -> bool:
	if not bool(can_counter(id, offer, team, pay_per)["ok"]):
		return false
	var applicant: ApplicantData = applicant_of(id)
	applicant.counter_odds = counter_odds(id, offer, team)
	applicant.counter_offer = offer
	applicant.counter_day = GameState.day()
	applicant.status = ApplicantData.STATUS_COUNTERED
	applicant.accepted_counter = false
	applicant.refused_counter = false
	applicant.unseen = false
	applicant.counter_team.assign(team)
	GameState.spend(team.size() * maxi(0, pay_per), GameState.REASON_ODD_JOB,
		"%s - Counter-offer" % applicant.name)
	_send_away(team, applicant.counter_day + COUNTER_DAYS)
	applicants_changed.emit()
	return true


#How many applicants arrived through one campaign, counting only the ones still on the list.
func _arrived_through(campaign_id: int) -> int:
	var count: int = 0
	for applicant: ApplicantData in applicants:
		if applicant.campaign_id == campaign_id:
			count += 1
	return count


#An applicant leaving the list still counts as a result of the campaign that sent them.
func _keep_result(applicant: ApplicantData) -> void:
	if applicant == null:
		return
	var campaign: CampaignData = campaign_of(applicant.campaign_id)
	if campaign != null:
		campaign.results += 1


#The crew of a Word of Mouth campaign is out spreading the word until the campaign ends.
func _crew_away(campaign: CampaignData) -> void:
	if campaign == null or campaign.crew.is_empty():
		return
	if not CampaignTypeDefs.is_crew_paid(campaign.type_key):
		return
	_send_away(campaign.crew, _until_day(campaign))


#The last day a crew-paid campaign holds its crew, or -1 when an Infinite one holds it for good.
func _until_day(campaign: CampaignData) -> int:
	return -1 if campaign.infinite else campaign.end_day()


#Marks a crew away on the Odd Job status until a day; a day under zero has no end. A uid the
#roster does not hold is left alone, so no phantom row reaches the registry.
func _send_away(team: Array[int], until_day: int) -> void:
	var until: int = -1
	if until_day >= 0:
		until = until_day * CampaignClock.MINUTES_PER_DAY
	for uid: int in team:
		if GameState.merc_by_uid(uid) == null:
			continue
		if not _free_for_hold(uid):
			continue
		if GameState.set_away(uid, GuiTypes.MercStatus.ODD_JOB, until):
			_away_uids[uid] = true


#A hold another manager wrote is never overwritten: only a merc the guild still has, or one of
#this manager's own Odd Job rows, takes a new end day.
func _free_for_hold(uid: int) -> bool:
	var status: int = GameState.away_status(uid)
	if status == -1:
		return true
	return _away_uids.has(uid) and status == GuiTypes.MercStatus.ODD_JOB


#True when one uid of a crew the roster knows cannot be sent anywhere right now.
func _holds_busy_merc(team: Array[int]) -> bool:
	if team.is_empty():
		return false
	var busy: Array[int] = GameState.busy_uids()
	for uid: int in team:
		if GameState.merc_by_uid(uid) == null:
			continue
		if busy.has(uid):
			return true
	return false


#Brings back only the mercs this manager sent away.
func _bring_home(team: Array[int]) -> void:
	var was_writing: bool = _restoring
	_restoring = true
	for uid: int in team:
		if not _away_uids.has(uid):
			continue
		if GameState.away_status(uid) != GuiTypes.MercStatus.ODD_JOB:
			continue
		_away_uids.erase(uid)
		GameState.clear_away(uid)
	_restoring = was_writing


func _clear_away_rows() -> void:
	for uid: int in _away_uids.keys():
		if GameState.away_status(int(uid)) == GuiTypes.MercStatus.ODD_JOB:
			GameState.clear_away(int(uid))
	_away_uids.clear()


#Puts back the Odd Job rows this manager owns. The away registry is emptied by a new game, so the
#cards would name crew mercs the roster shows as free. on_day under zero reads the later of the clock
#and the last day this manager settled.
func _restore_holds(on_day: int = -1) -> void:
	if _resetting or _restoring or not _seeded:
		return
	_restoring = true
	var today: int = on_day if on_day >= 0 else maxi(GameState.day(), _last_day)
	for uid: int in _away_uids.keys():
		if GameState.away_status(int(uid)) != GuiTypes.MercStatus.ODD_JOB:
			_away_uids.erase(uid)
	for campaign: CampaignData in campaigns:
		if campaign.crew.is_empty() or not CampaignTypeDefs.is_crew_paid(campaign.type_key):
			continue
		if campaign.is_concluded(today):
			continue
		var until_day: int = _until_day(campaign)
		for uid: int in campaign.crew:
			_restore_one(uid, until_day)
	for applicant: ApplicantData in applicants:
		if applicant.status != ApplicantData.STATUS_COUNTERED:
			continue
		for uid: int in applicant.counter_team:
			_restore_one(uid, applicant.counter_day + COUNTER_DAYS)
	_restoring = false


#One hold, written only for a merc the roster holds and the guild is not already missing.
func _restore_one(uid: int, until_day: int) -> void:
	if GameState.merc_by_uid(uid) == null:
		return
	if GameState.away_status(uid) != -1:
		return
	var until: int = -1
	if until_day >= 0:
		until = until_day * CampaignClock.MINUTES_PER_DAY
	if GameState.set_away(uid, GuiTypes.MercStatus.ODD_JOB, until):
		_away_uids[uid] = true


#A place the permit book has never heard of cannot want a permit.
func _known_place(index: int) -> bool:
	return LegalManager.location(index) != null


func _ensure() -> void:
	if not _seeded:
		reset()


#A new day: every monthly bill goes out, every due arrival lands and every answer comes back.
func _on_day_changed(day_index: int) -> void:
	if not _seeded:
		return
	_last_day = day_index
	var campaigns_dirty: bool = not campaigns.is_empty()
	var applicants_dirty: bool = false
	for campaign: CampaignData in campaigns.duplicate():
		if not _bill_campaign(campaign, day_index):
			continue
		_land_arrivals(campaign, day_index)
		if campaign.is_concluded(day_index):
			_bring_home(campaign.crew)
	for applicant: ApplicantData in applicants.duplicate():
		if applicant.status != ApplicantData.STATUS_COUNTERED:
			continue
		if day_index < applicant.counter_day + COUNTER_DAYS:
			continue
		_resolve_counter(applicant)
		applicants_dirty = true
	_restore_holds(day_index)
	if campaigns_dirty:
		campaigns_changed.emit()
	if applicants_dirty:
		applicants_changed.emit()


#Charges a campaign for every bill date it has passed. False once the campaign is gone: a bill the
#bank cannot cover takes the campaign down and hands nothing back.
func _bill_campaign(campaign: CampaignData, day_index: int) -> bool:
	while campaign.next_bill_day >= 0 and campaign.next_bill_day <= day_index:
		var amount: int = campaign.period_cost(campaign.next_bill_day)
		if not GameState.spend(amount, REASON_ADS, "%s - Monthly bill" % campaign.name):
			billing_failures.append({"id": campaign.id, "name": campaign.name, "day": day_index,
				"amount": amount})
			_bring_home(campaign.crew)
			campaigns.erase(campaign)
			campaign_bill_failed.emit(campaign.id, campaign.name)
			return false
		campaign.next_bill_day = campaign.bill_after(campaign.next_bill_day)
		campaign_billed.emit(campaign.id, amount)
	return true


#Steps a Guild Promo's arrival day on; its contracts come from the daily round (contract_campaigns) and job ads
#land through hire_round. A fixed run stops on its last day.
func _land_arrivals(campaign: CampaignData, day_index: int) -> void:
	var last: int = day_index
	if not campaign.infinite:
		last = mini(day_index, campaign.end_day() - 1)
	while campaign.next_arrival_day >= 0 and campaign.next_arrival_day <= last:
		campaign.next_arrival_day += ARRIVAL_DAYS
	if campaign.is_concluded(day_index):
		campaign.next_arrival_day = -1


#An accepted counter-offer becomes their new asking rate; a refusal leaves the old one standing.
func _resolve_counter(applicant: ApplicantData) -> void:
	var accepted: bool = _rng.randi_range(1, 100) <= applicant.counter_odds
	applicant.status = ApplicantData.STATUS_OPEN
	applicant.accepted_counter = accepted
	applicant.refused_counter = not accepted
	_bring_home(applicant.counter_team)
	applicant.counter_team.clear()
	if accepted:
		applicant.ask = applicant.counter_offer
		if bool(can_hire(applicant.id, applicant.counter_offer)["ok"]):
			_hire_at(applicant, applicant.counter_offer, 0)
	counter_resolved.emit(applicant.id, accepted)


#A campaign that asks who to speak to needs one pick: an index list, a first index or a name. A
#Direct Sale carries every picked index, a Sponsorship one, and an older save only the name.
func _has_target(campaign: CampaignData) -> bool:
	if not campaign.advertise_targets.is_empty():
		return true
	if campaign.sponsor_index >= 0:
		return true
	return campaign.sponsor_target.strip_edges() != ""


#A fixed run must fit its unit, the entitlement cap and the thirty day ceiling; an Infinite one
#only needs its unit unlocked.
func _duration_verdict(campaign: CampaignData, ent: Dictionary) -> Dictionary:
	var unit: StringName = campaign.unit_key
	if campaign.infinite:
		unit = CampaignTypeDefs.UNIT_INFINITE
	elif unit == &"":
		unit = CampaignTypeDefs.UNIT_DAYS
	if not CampaignTypeDefs.unit_unlocked(unit, ent):
		if CampaignTypeDefs.cap_of(ent) <= 0:
			return _refuse("Promos are locked.")
		var label: String = String(CampaignTypeDefs.unit_of(unit).get("name", "Long"))
		return _refuse("%s promos are locked." % label)
	if campaign.infinite:
		return _allow()
	if campaign.days < CampaignTypeDefs.MIN_DAYS:
		return _refuse("A promo runs at least %d day." % CampaignTypeDefs.MIN_DAYS)
	var cap: int = CampaignTypeDefs.cap_of(ent)
	if campaign.days > cap:
		return _refuse("Promos run up to %d days." % cap)
	if campaign.days > CampaignTypeDefs.MAX_DAYS:
		return _refuse("Promos run up to %d days." % CampaignTypeDefs.MAX_DAYS)
	return _allow()


func _location_verdict(campaign: CampaignData, row: Dictionary) -> Dictionary:
	var type_name: String = String(row["name"])
	for index: int in campaign.locations:
		if not CampaignTypeDefs.location_allowed(campaign.type_key, index):
			return _refuse("%s cannot reach %s." % [type_name,
				CampaignTypeDefs.location_name(index)])
		if _known_place(index):
			if not LegalManager.has_permit(index, LegalManager.PERMIT_OPS):
				return _refuse("No Operations Permit in %s."
					% CampaignTypeDefs.location_name(index))
	if bool(row["one_loc"]) and campaign.locations.size() > 1:
		return _refuse("%s takes one location." % type_name)
	return _allow()


#A Guild Promo field the plan has not paid for has to stay where it started.
func _guild_field_verdict(campaign: CampaignData, ent: Dictionary) -> Dictionary:
	if campaign.mode != CampaignData.MODE_PROMO:
		return _allow()
	for row: Dictionary in GUILD_FIELD_LOCKS:
		if CampaignTypeDefs.gate_met(ent, String(row["gate"])):
			continue
		if not _at_default(campaign.get(String(row["field"])), row["default"]):
			return _refuse("%s is locked." % String(row["label"]))
	return _allow()


#True when a field still holds the value a locked row leaves it at.
func _at_default(value: Variant, want: Variant) -> bool:
	if want == null:
		return (value as Array).is_empty()
	return is_equal_approx(float(value), float(want))


func _matches(applicant: ApplicantData, filters: Dictionary, defs: Array[Dictionary],
		ent: Dictionary) -> bool:
	for def: Dictionary in defs:
		if TraitFilterDefs.locked(def, ent):
			continue
		var want: Variant = _filter_value(filters, StringName(def["key"]))
		if not TraitFilterDefs.active(def, want):
			continue
		var have: Variant = _value_of(applicant, String(def["field"]))
		var kind: String = String(def["kind"])
		if kind == TraitFilterDefs.KIND_SLIDER2 or kind == TraitFilterDefs.KIND_RANGE:
			var pair: Array = want
			if float(have) < float(pair[0]) or float(have) > float(pair[1]):
				return false
		elif kind == TraitFilterDefs.KIND_MIN:
			if float(have) < float(want):
				return false
		elif not _any_match(have, want):
			return false
	return true


#A chip row passes when the applicant carries any one of the picked values.
func _any_match(have: Variant, want: Variant) -> bool:
	var picks: Array = want if want is Array else [want]
	var mine: Array = have if have is Array else [have]
	for pick: Variant in picks:
		if mine.has(pick):
			return true
	return false


#A filter set written with plain string keys reads the same as one written with StringNames.
func _filter_value(filters: Dictionary, key: StringName) -> Variant:
	if filters.has(key):
		return filters[key]
	var text: String = String(key)
	return filters[text] if filters.has(text) else null


func _value_of(applicant: ApplicantData, field: String) -> Variant:
	if field == "":
		return null
	if field.begins_with(TraitFilterDefs.STAT_PREFIX):
		return applicant.stat(field.substr(TraitFilterDefs.STAT_PREFIX.length()))
	return applicant.get(field)


func _sort_value(applicant: ApplicantData, key: StringName) -> float:
	match key:
		&"uniqueness":
			return applicant.uniq * 10.0 + float(applicant.rarity_rank())
		&"level":
			return float(applicant.level)
		&"salary":
			return float(applicant.ask)
	return applicant.fit


func _spawn_applicant(campaign: CampaignData) -> ApplicantData:
	return land_applicant(campaign)


#One arrival through a campaign. hit is one GenPromo.roll entry: its criteria are the filter keys that bind the card
#and its match_pct lifts the draw count. No cap, no results write and no arrival day are touched here.
func land_applicant(campaign: CampaignData, hit: Dictionary = {}) -> ApplicantData:
	var applied: Array[String] = []
	applied.assign(hit.get("criteria", []))
	var quality: float = HirePool.job_quality(hire_opinion(), float(hit.get("match_pct", 0.0)))
	var filters: Dictionary = campaign.filters if campaign != null else {}
	var applicant: ApplicantData = _draw_card(HirePool.quality_draws(quality), filters, applied, _fit_targets())
	applicant.campaign_id = campaign.id if campaign != null else ApplicantData.WALK_IN
	_post_card(applicant)
	return applicant


#The daily 8:00 hire pass: the job posting rolls, then on a refresh day the pool refresh, then one list signal.
func hire_round(now: int) -> void:
	if not _seeded:
		return
	var changed: bool = _roll_job_postings()
	if HirePool.is_refresh_day(TrynnCalendar.date_of(now)):
		changed = _refresh_pool() or changed
	if changed:
		applicants_changed.emit()


#The POOL_START applicants a new game opens with.
func fill_start_pool() -> void:
	_ensure()
	var targets: Array[ContractData] = _fit_targets()
	var draws: int = HirePool.quality_draws(hire_opinion())
	for _i: int in HirePool.POOL_START:
		_post_card(_pool_card(draws, targets))
	applicants_changed.emit()


#Every running, billed job posting as {id, effect, active}: active holds the filter keys off their default.
func job_campaigns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today: int = maxi(GameState.day(), _last_day)
	var ent: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	for campaign: CampaignData in campaigns:
		if campaign.mode != CampaignData.MODE_JOB or not campaign.is_launched() or campaign.is_concluded(today):
			continue
		var effect: float = CampaignTypeDefs.effect_value(campaign.type_key, ent)
		if effect < 0.0:
			effect = word_of_mouth_effect(campaign.crew)
		var active: Array[String] = []
		for def: Dictionary in defs:
			if TraitFilterDefs.active(def, _filter_value(campaign.filters, StringName(def["key"]))):
				active.append(String(def["key"]))
		out.append({"id": campaign.id, "effect": effect, "active": active})
	return out


#Guild Opinion for the pool: the roster's opinions of the guild beside the clients' satisfaction, 0..1.
func hire_opinion() -> float:
	var opinions: Array[int] = []
	for merc: MercenaryData in GameState.mercs:
		if merc != null and int(GameState.merc_status(merc)["status"]) != GuiTypes.MercStatus.DEAD:
			opinions.append(merc.guild_opinion)
	var satisfactions: Array[int] = []
	for id: int in IssuerOpinion.ids():
		satisfactions.append(IssuerOpinion.satisfaction(id))
	return HirePool.overall_opinion(opinions, satisfactions)


#The level centre of the live roster, weighted as the contract round weighs it.
func hire_level_centre() -> float:
	var living: Array[MercenaryData] = []
	var available: Array[MercenaryData] = []
	var resting: Array[MercenaryData] = []
	for merc: MercenaryData in GameState.mercs:
		if merc == null:
			continue
		var status: int = int(GameState.merc_status(merc)["status"])
		if status != GuiTypes.MercStatus.DEAD:
			living.append(merc)
		if status == GuiTypes.MercStatus.AVAILABLE:
			available.append(merc)
		elif status == GuiTypes.MercStatus.RESTING:
			resting.append(merc)
	return GenLevel.centre(living, available, resting)


func _roll_job_postings() -> bool:
	var landed: bool = false
	for row: Dictionary in job_campaigns():
		if _pool_full():
			break
		var campaign: CampaignData = campaign_of(int(row["id"]))
		var active: Array[String] = []
		active.assign(row["active"])
		for hit: Dictionary in GenPromo.roll(float(row["effect"]), active, _rng):
			if _pool_full():
				break
			land_applicant(campaign, hit)
			landed = true
	return landed


func _pool_full() -> bool:
	return open_applicants() >= HirePool.pool_cap(free_slots(), max_mercs())


#Drops the pool cards no counter-offer holds, then lands a fresh pool sized by opinion and the open seats.
func _refresh_pool() -> bool:
	var changed: bool = false
	for applicant: ApplicantData in applicants.duplicate():
		if applicant.pool and applicant.status != ApplicantData.STATUS_COUNTERED:
			_applicant_mercs.erase(applicant.id)
			applicants.erase(applicant)
			changed = true
	var opinion: float = hire_opinion()
	var count: int = HirePool.pool_size(opinion, HirePool.pool_cap(free_slots(), max_mercs()))
	var targets: Array[ContractData] = _fit_targets()
	var draws: int = HirePool.quality_draws(opinion)
	for _i: int in count:
		_post_card(_pool_card(draws, targets))
		changed = true
	return changed


func _pool_card(draws: int, targets: Array[ContractData]) -> ApplicantData:
	var applicant: ApplicantData = _draw_card(draws, {}, [], targets)
	applicant.campaign_id = ApplicantData.WALK_IN
	applicant.pool = true
	return applicant


func _post_card(applicant: ApplicantData) -> void:
	applicant.unseen = true
	applicants.append(applicant)
	applicant_arrived.emit(applicant)


#The open contracts a new merc is scored against: the ones the roster cannot cover, else every open one.
func _fit_targets() -> Array[ContractData]:
	var open: Array[ContractData] = []
	if GameState.board != null:
		for entry: BoardEntry in GameState.board.available():
			if entry != null and entry.contract != null:
				open.append(entry.contract)
	var targets: Array[ContractData] = HirePool.needs(open, GameState.mercs)
	return targets if not targets.is_empty() else open


#Draws draws candidates under one new id and keeps the best fit; the first candidate wins a tie.
func _draw_card(draws: int, filters: Dictionary, applied: Array[String],
		targets: Array[ContractData]) -> ApplicantData:
	var id: int = next_applicant_id
	next_applicant_id += 1
	var level: int = HirePool.level_for(hire_level_centre(), _rng)
	var best: ApplicantData = null
	var best_merc: MercenaryData = null
	for _i: int in maxi(1, draws):
		var card: ApplicantData = _candidate(id, level, filters, applied, targets)
		if best == null or card.fit > best.fit:
			best = card
			best_merc = merc_of(card)
	if best_merc != null:
		_applicant_mercs[id] = best_merc
	else:
		_applicant_mercs.erase(id)
	return best


#One candidate card: tradition forced from an applied filter, the merc re-drawn up to FILTER_TRIES times until the
#applied filters pass, the merc-read fields from the merc and the placeholder fields as _rng picks.
func _candidate(id: int, level: int, filters: Dictionary, applied: Array[String],
		targets: Array[ContractData]) -> ApplicantData:
	var bound: Dictionary = {}
	for key: String in applied:
		var want: Variant = _filter_value(filters, StringName(key))
		if want != null:
			bound[StringName(key)] = want
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	var ent: Dictionary = SubscriptionManager.entitlements()
	var card: ApplicantData = null
	for _try: int in HirePool.FILTER_TRIES:
		card = ApplicantData.new()
		card.id = id
		card.tradition = _pick_tradition(bound.get(&"tradition", null))
		_give_merc(card, level)
		if bound.is_empty() or _matches(card, bound, defs, ent):
			break
	var merc: MercenaryData = merc_of(card)
	if merc != null:
		card.rarity = ApplicantData.RARITIES[clampi(SalarySystem.rarity_score(merc), 0, ApplicantData.RARITIES.size() - 1)]
		card.uniq = float(SalarySystem.need_score(merc, GameState.mercs))
		card.fit = HirePool.fit(merc, targets)
	card.bloodline = _pick_name("Bloodline", TraitFilterDefs.BLOODLINE_COUNT)
	card.heritage = _pick_name("Heritage", TraitFilterDefs.HERITAGE_COUNT)
	card.criminality = _pick_name("Criminality", TraitFilterDefs.CRIMINALITY_COUNT)
	card.age = _rng.randi_range(int(TraitFilterDefs.AGE_MIN), int(TraitFilterDefs.AGE_MAX))
	card.tools = _one(_pick_name("Tool", TraitFilterDefs.TOOL_COUNT))
	card.knowledges = _one(_pick_name("Knowledge", TraitFilterDefs.KNOWLEDGE_COUNT))
	return card


#A tradition from the applied filter's allowed set, else from every tradition.
func _pick_tradition(allowed: Variant) -> String:
	var pool: Array[String] = []
	if allowed is Array:
		for entry: Variant in allowed:
			pool.append(String(entry))
	elif allowed != null and String(allowed) != "":
		pool.append(String(allowed))
	if pool.is_empty():
		pool = TraitFilterDefs.traditions()
	return pool[_rng.randi_range(0, pool.size() - 1)]


#Every running Guild Promo campaign in the GenPromo shape; an unset criterion is an empty list or a 0..0 band.
func contract_campaigns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today: int = maxi(GameState.day(), _last_day)
	var known: Array[String] = ContractLibrary.contract_type_names()
	var ent: Dictionary = SubscriptionManager.entitlements()
	for campaign: CampaignData in campaigns:
		if campaign.mode != CampaignData.MODE_PROMO or not campaign.is_launched() or campaign.is_concluded(today):
			continue
		var types: Array[String] = []
		for type_name: String in campaign.contract_types:
			if known.has(type_name) and not types.has(type_name):
				types.append(type_name)
		var places: Array[String] = []
		for index: int in campaign.locations:
			var place: String = CampaignTypeDefs.location_name(index)
			if place != "" and not places.has(place):
				places.append(place)
		var lo: float = minf(campaign.difficulty_lo, campaign.difficulty_hi)
		var hi: float = maxf(campaign.difficulty_lo, campaign.difficulty_hi)
		if lo <= GenConstants.DIFF_MIN and hi >= GenConstants.DIFF_MAX:
			lo = 0.0
			hi = 0.0
		var effect: float = CampaignTypeDefs.effect_value(campaign.type_key, ent)
		if effect < 0.0:
			effect = word_of_mouth_effect(campaign.crew)
		out.append({"id": campaign.id, "effect": effect, "types": types, "places": places,
			"diff_lo": lo, "diff_hi": hi, "issuers": _issuer_seats(campaign)})
	return out


#One contract the round generated for this campaign.
func credit_contract(campaign_id: int) -> void:
	for campaign: CampaignData in campaigns:
		if campaign.id == campaign_id:
			campaign.results += 1
			campaigns_changed.emit()
			return


#Word of Mouth percent: Wile summed over the crew, Speech once, one listed Knowledge once, capped.
func word_of_mouth_effect(crew: Array[int]) -> float:
	var wile: float = 0.0
	var speech: bool = false
	var knows: bool = false
	for uid: int in crew:
		var merc: MercenaryData = GameState.merc_by_uid(uid)
		if merc == null:
			continue
		wile += float(merc.stats.get("wile", 0.0))
		speech = speech or bool(merc.circumstance_flags.get(ConstCircumstances.SPEECH_WILE, false))
		for knowledge: String in WOM_KNOWLEDGES:
			knows = knows or ContractModifiers.knowledge_matches(merc, knowledge)
	var pct: float = WOM_PER_WILE * wile + (WOM_BONUS if speech else 0.0) + (WOM_BONUS if knows else 0.0)
	return minf(pct, WOM_CAP)


#Company picks map to their org seats; an event pick has no seat.
func _issuer_seats(campaign: CampaignData) -> Array[int]:
	var picks: Array[int] = []
	picks.assign(campaign.advertise_targets)
	if picks.is_empty() and campaign.sponsor_index >= 0:
		picks.append(campaign.sponsor_index)
	var out: Array[int] = []
	for index: int in picks:
		if index >= 0 and index < mini(TraitFilterDefs.COMPANY_COUNT, IssuerOpinion.ORG_SEATS):
			out.append(ContractIssuer.seat_id(IssuerOpinion.ORG_GROUP, index))
	return out


func _pick_name(prefix: String, count: int) -> String:
	return TraitFilterDefs.name_at(prefix, _rng.randi_range(0, maxi(1, count) - 1))


#One option as the single entry list a trait field holds.
func _one(value: String) -> Array[String]:
	var out: Array[String] = [value]
	return out


func _allow() -> Dictionary:
	return {"ok": true, "reason": ""}


func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

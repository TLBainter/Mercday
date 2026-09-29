extends Node

#Campaigns and applicants for My Promotions and Finance > Hiring: the one place both screens read.
#The tables live in CampaignTypeDefs and TraitFilterDefs, so nothing here branches per campaign
#type or per trait. Everything the handoff marks PLACEHOLDER sits in the block below; the seed is
#mercPromoSeed of promo-core.js re-based on today, and reset() reseeds it from RNG_SEED.
#Real applicant generation, arrival timing and the campaign quality bias are open items.

signal campaigns_changed
signal applicants_changed
signal applicant_arrived(applicant: ApplicantData)
signal applicant_hired(applicant: ApplicantData, salary: int, opinion_delta: int)
signal counter_resolved(applicant_id: int, accepted: bool)
#One monthly charge of an Infinite campaign went through, or the bank could not cover it and the
#campaign came down.
signal campaign_billed(id: int, amount: int)
signal campaign_bill_failed(id: int, name: String)

#PLACEHOLDER
#Seeded campaigns and applicants, the arrival and counter delays, the Odd Job pay and the fit a
#roster merc brings to a counter-offer. Every number here waits on a real system.
const RNG_SEED: int = 7
#The ledger reason every campaign charge and refund carries; Odd Job pay rides the one
#GameState already keeps.
const REASON_ADS: String = "ads"
#The separator GuildTargeting joins several picked companies with.
const TARGET_JOIN: String = ", "
const ARRIVAL_DAYS: int = 3
const COUNTER_DAYS: int = 3
const DEFAULT_ODD_JOB_PAY: int = 25
const FIT_SEED: int = 7
const FIT_STEP: int = 37
const FIRST_APPLICANT_ID: int = 20
const SEED_APPLICANTS: int = 8
const SEED_LEVELS: Array[int] = [4, 9, 2, 12, 6, 15, 3, 8]
const SEED_ASKS: Array[int] = [320, 540, 260, 780, 410, 960, 300, 600]
const SEED_UNIQ: Array[int] = [0, 2, 1, 3, 1, 4, 0, 2]
const SEED_RARITY: Array[int] = [0, 1, 0, 2, 1, 3, 0, 1]
const SEED_FIT: Array[float] = [2.0, 3.5, 1.5, 4.0, 3.0, 4.5, 2.5, 3.0]
const SEED_UNSEEN: Array[int] = [3, 5]
#Which campaign sent each seeded applicant. A value under zero stands for ApplicantData.WALK_IN,
#which a const cannot read off another class.
const SEED_FROM: Array[int] = [1, 3, -1, 5, 6, 9, -1, 10]
#The ten campaigns of mercPromoSeed, dated off today: age is how many days ago the campaign
#started, days 0 with infinite on means it bills monthly instead, res is the arrivals it already
#pulled, traditions and ctypes and locs and target are the picks it went out with, and crew with
#pay is the Odd Job a Word of Mouth campaign paid for.
const SEED_CAMPAIGNS: Array[Dictionary] = [
	{"id": 1, "mode": "job", "type": &"flyers", "age": 12, "days": 30, "res": 2,
		"traditions": [0, 5]},
	{"id": 2, "mode": "promo", "type": &"wom", "age": 3, "days": 14, "res": 1, "ctypes": [1],
		"locs": [0], "crew": [2, 5], "pay": 25},
	{"id": 3, "mode": "job", "type": &"radio", "age": 40, "days": 0, "res": 9, "infinite": true},
	{"id": 4, "mode": "job", "type": &"flyers", "age": 2, "days": 5, "res": 0,
		"traditions": [9]},
	{"id": 5, "mode": "job", "type": &"sponsor", "age": 20, "days": 30, "res": 5,
		"traditions": [2, 4], "target": 2},
	{"id": 6, "mode": "job", "type": &"radio", "age": 8, "days": 10, "res": 1,
		"traditions": [6]},
	{"id": 7, "mode": "job", "type": &"wom", "age": 5, "days": 7, "res": 1, "crew": [1, 4],
		"pay": 25},
	{"id": 8, "mode": "job", "type": &"flyers", "age": 45, "days": 30, "res": 4,
		"traditions": [3]},
	{"id": 9, "mode": "job", "type": &"sponsor", "age": 70, "days": 0, "res": 14,
		"infinite": true, "target": 7},
	{"id": 10, "mode": "job", "type": &"radio", "age": 1, "days": 25, "res": 0,
		"traditions": [1, 8]},
]
#The level, salary, uniqueness and stat bands a placeholder arrival is drawn from.
const NEW_LEVEL_LOW: int = 1
const NEW_LEVEL_HIGH: int = 15
#The asking rate is drawn in steps of NEW_ASK_STEP, so 10 to 50 steps is 200 to 1000 notes.
const NEW_ASK_STEP: int = 20
const NEW_ASK_LOW_STEPS: int = 10
const NEW_ASK_HIGH_STEPS: int = 50
const NEW_UNIQ_HIGH: int = 4
const NEW_STAT_LOW: int = 1
const NEW_STAT_HIGH: int = 9

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
#The Infinite campaigns the bank could not pay for, newest last: {id, name, day, amount}.
var billing_failures: Array[Dictionary] = []
var next_campaign_id: int = 1
var next_applicant_id: int = FIRST_APPLICANT_ID + SEED_APPLICANTS
#The merc the last hire signed on, for the screen that has to open their card; 0 = none yet.
var last_hired_uid: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seeded: bool = false
#True while reset() lays the seed down and while this manager writes away rows itself: set_away
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
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.day_changed.connect(_on_day_changed)


#Drops everything and lays the placeholder seed down again, dated off today.
func reset() -> void:
	_seeded = true
	_resetting = true
	_rng.seed = RNG_SEED
	_last_day = -1
	_clear_away_rows()
	last_hired_uid = 0
	campaigns.clear()
	applicants.clear()
	campaign_names.clear()
	billing_failures.clear()
	next_applicant_id = FIRST_APPLICANT_ID + SEED_APPLICANTS
	var today: int = GameState.day()
	for row: Dictionary in SEED_CAMPAIGNS:
		var campaign: CampaignData = _seed_campaign(row, today)
		campaigns.append(campaign)
		campaign_names[campaign.id] = campaign.name
		_crew_away(campaign)
	next_campaign_id = _next_id_after_seed()
	for i: int in range(SEED_APPLICANTS):
		applicants.append(_seed_applicant(i))
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
	out.sort_custom(func(a: CampaignData, b: CampaignData) -> bool:
		var left: float = campaign_sort_value(a, key, today)
		var right: float = campaign_sort_value(b, key, today)
		if is_equal_approx(left, right):
			return a.id > b.id
		return left < right if ascending else left > right)
	return out


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
	for row: Dictionary in CAMPAIGN_SORTS:
		if StringName(row["key"]) == key:
			return String(row["label"])
	return ""


#How many mercs a campaign has pulled in: the arrivals it still has on the list plus the ones
#already dealt with.
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


func builder_defs(mode: String, type_key: StringName) -> Array[Dictionary]:
	if mode == CampaignData.MODE_JOB:
		return TraitFilterDefs.merc_defs(false)
	return TraitFilterDefs.contract_defs(type_key)


func pay_per_of(campaign: CampaignData) -> int:
	if campaign == null or campaign.pay_per <= 0:
		return default_pay()
	return campaign.pay_per


func default_pay() -> int:
	return DEFAULT_ODD_JOB_PAY


#What launching takes out of the bank now: a fixed run pays for all its days, an Infinite one
#pays for its first month and a Word of Mouth campaign pays its crew.
func launch_cost(campaign: CampaignData) -> int:
	if campaign == null:
		return 0
	if CampaignTypeDefs.is_crew_paid(campaign.type_key):
		return CampaignTypeDefs.cost(campaign.type_key, 0, campaign.crew.size(),
			pay_per_of(campaign))
	if campaign.infinite:
		return CampaignTypeDefs.monthly_cost(campaign.type_key)
	return CampaignTypeDefs.cost(campaign.type_key, campaign.days)


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
	if campaign.infinite:
		campaign.next_bill_day = campaign.day_started + CampaignTypeDefs.BILL_DAYS
	campaign.next_arrival_day = -1
	if campaign.mode == CampaignData.MODE_JOB:
		campaign.next_arrival_day = campaign.day_started + ARRIVAL_DAYS
	if CampaignTypeDefs.is_crew_paid(campaign.type_key):
		_pay(campaign.total_cost, GameState.REASON_ODD_JOB,
			"%s - Word of Mouth" % campaign.name)
	else:
		_pay(campaign.total_cost, REASON_ADS, "%s - %s" % [campaign.name, String(row["name"])])
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
		_credit(refund, REASON_ADS, "%s - Refund" % campaign.name)
	_bring_home(campaign.crew)
	campaigns.erase(campaign)
	campaigns_changed.emit()
	return true


#What the Infinite campaigns add to a month of outgoings.
func monthly_ad_bill() -> int:
	_ensure()
	var total: int = 0
	for campaign: CampaignData in campaigns:
		if campaign.infinite:
			total += CampaignTypeDefs.monthly_cost(campaign.type_key)
	return total


func infinite_count() -> int:
	_ensure()
	var count: int = 0
	for campaign: CampaignData in campaigns:
		if campaign.infinite:
			count += 1
	return count


#Every monthly charge falling due inside the window, earliest first, for the Finance calendar.
func ad_bill_days(today: int, horizon: int) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	var limit: int = today + maxi(0, horizon)
	for campaign: CampaignData in campaigns:
		if not campaign.infinite or campaign.next_bill_day < 0:
			continue
		var amount: int = CampaignTypeDefs.monthly_cost(campaign.type_key)
		var day: int = campaign.next_bill_day
		while day < limit:
			if day >= today:
				out.append({"day": day, "amount": amount, "campaign_id": campaign.id})
			day += CampaignTypeDefs.BILL_DAYS
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["day"]) == int(b["day"]):
			return int(a["campaign_id"]) < int(b["campaign_id"])
		return int(a["day"]) < int(b["day"]))
	return out


#Opens Hiring on one campaign's arrivals: the View Applicants button of a job ad card.
func view_applicants(id: int) -> void:
	_ensure()
	GameState.open_hiring(id)


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
	var key: StringName = sort
	out.sort_custom(func(a: ApplicantData, b: ApplicantData) -> bool:
		var left: float = _sort_value(a, key)
		var right: float = _sort_value(b, key)
		if left == right:
			return a.id < b.id
		return left > right if descending else left < right)
	return out


func sort_label(key: StringName) -> String:
	for row: Dictionary in SORTS:
		if StringName(row["key"]) == key:
			return String(row["label"])
	return ""


#The roster cap the plan and the Seats tier hold; the key "seats" is a tier, never a seat count.
func max_mercs() -> int:
	return SubscriptionManager.max_mercs()


func free_slots() -> int:
	return maxi(0, max_mercs() - GameState.mercs.size())


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
	if not GameState.can_afford(salary):
		return _refuse("Not enough notes for their first month.")
	return _allow()


#Signs an applicant on. The roster addition is the hook: applicant_hired carries the salary and
#the Guild Opinion the new merc starts with, and real merc generation is an open item.
func hire(id: int, salary: int) -> bool:
	if not bool(can_hire(id, salary)["ok"]):
		return false
	var applicant: ApplicantData = applicant_of(id)
	return _hire_at(applicant, salary, opinion_delta(applicant.ask, salary))


#Signs one applicant on: a merc built at their level and tradition joins the roster on the agreed
#salary, the opinion change lands on top of the opening opinion and the applicant leaves the list.
func _hire_at(applicant: ApplicantData, salary: int, delta: int) -> bool:
	if applicant == null:
		return false
	applicant.status = ApplicantData.STATUS_HIRED
	applicant.unseen = false
	_keep_result(applicant)
	applicants.erase(applicant)
	last_hired_uid = 0
	var merc: MercenaryData = _new_merc(applicant)
	if merc != null:
		GameState.hire(merc)
		merc.monthly_salary = maxi(1, salary)
		merc.guild_opinion = clampi(merc.guild_opinion + delta, SalarySystem.OPINION_MIN,
			SalarySystem.OPINION_MAX)
		last_hired_uid = merc.merc_uid
		GameState.refresh_views()
		GameState.roster_changed.emit()
	applicants_changed.emit()
	applicant_hired.emit(applicant, salary, delta)
	return true


#The merc behind an applicant. DEFERRED: only the level and the tradition are carried over;
#ancestry, heritage, traits and stats are whatever the generator rolls.
func _new_merc(applicant: ApplicantData) -> MercenaryData:
	var held_level: int = MercGenerator.forced_level
	var held_tradition: String = MercGenerator.forced_tradition
	MercGenerator.forced_level = maxi(1, applicant.level)
	MercGenerator.forced_tradition = applicant.tradition
	var merc: MercenaryData = MercGenerator.generate(GameState.mercs.size())
	MercGenerator.forced_level = held_level
	MercGenerator.forced_tradition = held_tradition
	if merc != null and applicant.name != "":
		merc.merc_name = applicant.name
	return merc


func reject(id: int) -> bool:
	var applicant: ApplicantData = applicant_of(id)
	if applicant == null or applicant.status == ApplicantData.STATUS_COUNTERED:
		return false
	applicant.status = ApplicantData.STATUS_REJECTED
	applicant.unseen = false
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
	_pay(team.size() * maxi(0, pay_per), GameState.REASON_ODD_JOB,
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


#Notes leave the bank only here, so every campaign charge reaches the ledger with a label.
func _pay(amount: int, reason: String, label: String) -> bool:
	if GameState.has_method("charge"):
		return bool(GameState.call("spend", amount, reason, label))
	return GameState.spend(amount, reason)


func _credit(amount: int, reason: String, label: String) -> void:
	if GameState.has_method("charge"):
		GameState.call("refund", amount, reason, label)
		return
	GameState.refund(amount, reason)


#The crew of a Word of Mouth campaign is out spreading the word until the campaign ends.
func _crew_away(campaign: CampaignData) -> void:
	if campaign == null or campaign.crew.is_empty():
		return
	if not CampaignTypeDefs.is_crew_paid(campaign.type_key):
		return
	var until_day: int = -1 if campaign.infinite else campaign.end_day()
	_send_away(campaign.crew, until_day)


#Marks a crew away on the Odd Job status until a day; a day under zero has no end. A uid the
#roster does not hold is left alone, so no phantom row reaches the registry.
func _send_away(team: Array[int], until_day: int) -> void:
	if not GameState.has_method("set_away"):
		return
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
	if not GameState.has_method("clear_away"):
		return
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
	if not GameState.has_method("clear_away"):
		_away_uids.clear()
		return
	for uid: int in _away_uids.keys():
		if GameState.away_status(int(uid)) == GuiTypes.MercStatus.ODD_JOB:
			GameState.clear_away(int(uid))
	_away_uids.clear()


#Puts back the Odd Job rows this manager owns. The away registry is emptied by a new game, and a
#seed laid down before a game started never found a merc to hold, so the cards would name crew
#mercs the roster shows as free. on_day under zero reads the later of the clock and the last day
#this manager settled.
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
		var until_day: int = -1 if campaign.infinite else campaign.end_day()
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
func _known_place(legal: Node, index: int) -> bool:
	if not legal.has_method("location"):
		return true
	return legal.call("location", index) != null


func _ensure() -> void:
	if not _seeded:
		reset()


func _on_roster_changed() -> void:
	if not _seeded and GameState.started:
		reset()
		return
	_restore_holds()


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
		if _land_arrivals(campaign, day_index):
			applicants_dirty = true
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


#Charges an Infinite campaign for every period it has passed. False once the campaign is gone:
#a bill the bank cannot cover takes the campaign down and hands nothing back.
func _bill_campaign(campaign: CampaignData, day_index: int) -> bool:
	if not campaign.infinite:
		return true
	while campaign.next_bill_day >= 0 and campaign.next_bill_day <= day_index:
		var amount: int = CampaignTypeDefs.monthly_cost(campaign.type_key)
		if not _pay(amount, REASON_ADS, "%s - Monthly bill" % campaign.name):
			billing_failures.append({"id": campaign.id, "name": campaign.name, "day": day_index,
				"amount": amount})
			_bring_home(campaign.crew)
			campaigns.erase(campaign)
			campaign_bill_failed.emit(campaign.id, campaign.name)
			return false
		campaign.next_bill_day += CampaignTypeDefs.BILL_DAYS
		campaign_billed.emit(campaign.id, amount)
	return true


#Lands every arrival the campaign owes. A fixed run stops pulling on its last day.
func _land_arrivals(campaign: CampaignData, day_index: int) -> bool:
	var landed: bool = false
	var last: int = day_index
	if not campaign.infinite:
		last = mini(day_index, campaign.end_day() - 1)
	while campaign.next_arrival_day >= 0 and campaign.next_arrival_day <= last:
		_spawn_applicant(campaign)
		campaign.next_arrival_day += ARRIVAL_DAYS
		landed = true
	if campaign.is_concluded(day_index):
		campaign.next_arrival_day = -1
	return landed


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
	var legal: Node = get_node_or_null("/root/LegalManager")
	var can_ask: bool = legal != null and legal.has_method("has_permit")
	for index: int in campaign.locations:
		if not CampaignTypeDefs.location_allowed(campaign.type_key, index):
			return _refuse("%s cannot reach %s." % [type_name,
				CampaignTypeDefs.location_name(index)])
		if can_ask and _known_place(legal, index):
			if not bool(legal.call("has_permit", index, LegalManager.PERMIT_OPS)):
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


#One placeholder arrival through a job campaign. The campaign's quality stars do not bias the
#draw yet: that waits on real generation.
func _spawn_applicant(campaign: CampaignData) -> ApplicantData:
	var applicant := ApplicantData.new()
	applicant.id = next_applicant_id
	next_applicant_id += 1
	applicant.name = applicant_name(applicant.id)
	var traditions: Array[String] = TraitFilterDefs.traditions()
	applicant.tradition = traditions[_rng.randi_range(0, traditions.size() - 1)]
	applicant.level = _rng.randi_range(NEW_LEVEL_LOW, NEW_LEVEL_HIGH)
	applicant.ask = _rng.randi_range(NEW_ASK_LOW_STEPS, NEW_ASK_HIGH_STEPS) * NEW_ASK_STEP
	applicant.uniq = float(_rng.randi_range(0, NEW_UNIQ_HIGH))
	applicant.rarity = ApplicantData.RARITIES[mini(int(applicant.uniq),
		ApplicantData.RARITIES.size() - 1)]
	applicant.fit = float(_rng.randi_range(1, 10)) / 2.0
	applicant.campaign_id = campaign.id
	applicant.unseen = true
	applicant.ancestry = _pick_name("Ancestry", TraitFilterDefs.ANCESTRY_COUNT)
	applicant.bloodline = _pick_name("Bloodline", TraitFilterDefs.BLOODLINE_COUNT)
	applicant.heritage = _pick_name("Heritage", TraitFilterDefs.HERITAGE_COUNT)
	applicant.criminality = _pick_name("Criminality", TraitFilterDefs.CRIMINALITY_COUNT)
	applicant.age = _rng.randi_range(int(TraitFilterDefs.AGE_MIN), int(TraitFilterDefs.AGE_MAX))
	for key: String in ApplicantData.STAT_KEYS:
		applicant.stats[key] = _rng.randi_range(NEW_STAT_LOW, NEW_STAT_HIGH)
	applicant.tools = _one(_pick_name("Tool", TraitFilterDefs.TOOL_COUNT))
	applicant.knowledges = _one(_pick_name("Knowledge", TraitFilterDefs.KNOWLEDGE_COUNT))
	applicants.append(applicant)
	applicant_arrived.emit(applicant)
	return applicant


func _pick_name(prefix: String, count: int) -> String:
	return TraitFilterDefs.name_at(prefix, _rng.randi_range(0, maxi(1, count) - 1))


#One option as the single entry list a trait field holds.
func _one(value: String) -> Array[String]:
	var out: Array[String] = [value]
	return out


#Placeholder applicant names, the mname() of promo-core.js.
func applicant_name(id: int) -> String:
	return "FirstName%d LastName%d" % [id + 1, id + 1]


#The id the next launch takes, which is one past the highest seeded campaign.
func _next_id_after_seed() -> int:
	var top: int = 0
	for row: Dictionary in SEED_CAMPAIGNS:
		top = maxi(top, int(row["id"]))
	return top + 1


#One seeded campaign, dated off today and already carrying its results.
func _seed_campaign(row: Dictionary, today: int) -> CampaignData:
	var campaign := CampaignData.new()
	campaign.id = int(row["id"])
	campaign.name = "Campaign %d" % campaign.id
	campaign.mode = String(row["mode"])
	campaign.type_key = StringName(row["type"])
	campaign.infinite = bool(row.get("infinite", false))
	campaign.days = int(row.get("days", 0))
	campaign.unit_key = CampaignTypeDefs.UNIT_DAYS
	if campaign.infinite:
		campaign.unit_key = CampaignTypeDefs.UNIT_INFINITE
	campaign.day_started = today - int(row["age"])
	campaign.results = int(row.get("res", 0))
	campaign.per_day = int(CampaignTypeDefs.find(campaign.type_key)["per_day"])
	campaign.crew.assign(row.get("crew", []))
	campaign.pay_per = int(row.get("pay", 0))
	campaign.contract_types.assign(row.get("ctypes", []))
	campaign.locations.assign(row.get("locs", []))
	campaign.sponsor_index = int(row.get("target", CampaignData.NO_PICK))
	campaign.sponsor_target = _sponsor_name(campaign.type_key, campaign.sponsor_index)
	campaign.filters = _seed_filters(row, campaign)
	campaign.total_cost = launch_cost(campaign)
	campaign.next_bill_day = _next_bill_after(campaign, today)
	campaign.next_arrival_day = _next_arrival_after(campaign, today)
	return campaign


#The filter set a seeded campaign went out with, one entry per picked row.
func _seed_filters(row: Dictionary, campaign: CampaignData) -> Dictionary:
	var out: Dictionary = {}
	var traditions: Array[String] = TraitFilterDefs.traditions()
	var picked: Array[String] = []
	for index: int in (row.get("traditions", []) as Array):
		picked.append(traditions[index % traditions.size()])
	if not picked.is_empty():
		out[&"tradition"] = picked
	if not campaign.contract_types.is_empty():
		out[&"ctype"] = campaign.contract_types.duplicate()
	if not campaign.locations.is_empty():
		out[&"loc"] = campaign.locations.duplicate()
	if campaign.sponsor_target != "":
		out[&"target"] = _seed_target_value(campaign)
	return out


#A chips target row stores the picked names as a list; a pick-one row stores the one name.
func _seed_target_value(campaign: CampaignData) -> Variant:
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(campaign.type_key)
	var def: Dictionary = TraitFilterDefs.find(defs, &"target")
	if String(def.get("kind", "")) != TraitFilterDefs.KIND_CHIPS:
		return campaign.sponsor_target
	var options: Array = def.get("options", [])
	var out: Array[String] = []
	for index: int in campaign.advertise_targets:
		if index >= 0 and index < options.size():
			out.append(String(options[index]))
	if out.is_empty():
		for piece: String in campaign.sponsor_target.split(TARGET_JOIN, false):
			if options.has(piece):
				out.append(piece)
	return out


#The company or event one index of the sponsor picker stands for.
func _sponsor_name(type_key: StringName, index: int) -> String:
	if index < 0:
		return ""
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(type_key)
	var target: Dictionary = TraitFilterDefs.find(defs, &"target")
	if target.is_empty():
		return ""
	var options: Array = target["options"]
	return String(options[index]) if index < options.size() else ""


#The first arrival day of a running campaign that is still ahead of today.
func _next_arrival_after(campaign: CampaignData, today: int) -> int:
	if campaign.mode != CampaignData.MODE_JOB or campaign.is_concluded(today):
		return -1
	var day: int = campaign.day_started + ARRIVAL_DAYS
	while day <= today:
		day += ARRIVAL_DAYS
	return day


#The first monthly charge of an Infinite campaign that is still ahead of today.
func _next_bill_after(campaign: CampaignData, today: int) -> int:
	if not campaign.infinite:
		return -1
	var day: int = campaign.day_started + CampaignTypeDefs.BILL_DAYS
	while day <= today:
		day += CampaignTypeDefs.BILL_DAYS
	return day


func _seed_applicant(index: int) -> ApplicantData:
	var applicant := ApplicantData.new()
	applicant.id = FIRST_APPLICANT_ID + index
	applicant.name = applicant_name(applicant.id)
	var traditions: Array[String] = TraitFilterDefs.traditions()
	applicant.tradition = traditions[(index * 3 + 1) % traditions.size()]
	applicant.level = SEED_LEVELS[index]
	applicant.ask = SEED_ASKS[index]
	applicant.uniq = float(SEED_UNIQ[index])
	applicant.rarity = ApplicantData.RARITIES[SEED_RARITY[index]]
	applicant.fit = SEED_FIT[index]
	var from: int = SEED_FROM[index]
	applicant.campaign_id = ApplicantData.WALK_IN if from < 0 else from
	applicant.unseen = SEED_UNSEEN.has(index)
	applicant.ancestry = TraitFilterDefs.name_at("Ancestry",
		index % TraitFilterDefs.ANCESTRY_COUNT)
	applicant.bloodline = TraitFilterDefs.name_at("Bloodline",
		(index + 2) % TraitFilterDefs.BLOODLINE_COUNT)
	applicant.heritage = TraitFilterDefs.name_at("Heritage",
		(index + 1) % TraitFilterDefs.HERITAGE_COUNT)
	applicant.criminality = TraitFilterDefs.name_at("Criminality",
		index % TraitFilterDefs.CRIMINALITY_COUNT)
	applicant.age = 19 + index * 5
	applicant.stats = {"speed": 3 + (index * 4) % 6, "cognition": 2 + (index * 2) % 6,
		"vigor": 1 + (index * 3) % 7, "dexterity": 4 + index % 4, "wile": 2 + (index * 5) % 6}
	applicant.tools = _one(TraitFilterDefs.name_at("Tool",
		(index + 2) % TraitFilterDefs.TOOL_COUNT))
	applicant.knowledges = _one(TraitFilterDefs.name_at("Knowledge",
		index % TraitFilterDefs.KNOWLEDGE_COUNT))
	return applicant


func _allow() -> Dictionary:
	return {"ok": true, "reason": ""}


func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

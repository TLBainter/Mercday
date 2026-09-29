class_name GuiPromoTests

#PromotionsManager, CampaignTypeDefs and TraitFilterDefs: the campaign table and its gates, the
#effect and duration rules, the filter rows and their locks, the placeholder seed, the card
#stats, the campaign list, the Hiring filters and sorts, launching, monthly billing, ending with
#a refund, the ledger row of every charge, the permit gate, the away rows of both crews, hiring,
#counter-offers and what a new day brings. Days are driven by emitting
#GameState.day_changed, so the clock stays paused and no case waits on real time.


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_types(res)
	_case_effect(res)
	_case_fit_locations(res)
	_case_duration(res)
	_case_merc_defs(res)
	_case_contract_defs(res)
	_case_seed(res)
	_case_card_stats(res)
	_case_list(res)
	_case_filters(res)
	_case_launch(res)
	_case_launch_rules(res)
	_case_end_refund(res)
	_case_infinite_billing(res)
	_case_finance(res)
	_case_view_applicants(res)
	_case_hire(res)
	_case_counter(res)
	_case_day_tick(res)
	_case_ledger(res)
	_case_permit_gate(res)
	_case_away_rows(res)
	_case_hired_merc(res)
	_case_counter_hire(res)
	_case_restore_holds(res)
	_case_tick_restore(res)
	_case_busy_crew(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI PROMO")


#Every case starts bare: Enterprise with no upgrade tier and no override, plus the seeded permits.
static func _fresh(ent: Dictionary = {}) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	if not ent.is_empty():
		SubscriptionManager.set_entitlements(ent)
	LegalManager.reset()
	PromotionsManager.reset()


#The entitlements a launch case needs: the cheap types, two Odd Job slots, a thirty day cap and
#both tabs open.
static func _launch_ent() -> Dictionary:
	return {"promotions": true, "oddJobs": 2, "adDirect": true, "adSponsor": true,
		"maxPromoDays": 30, "jobPostings": true, "guildPromo": true}


static func _campaign(type_key: StringName, mode: String, days: int) -> CampaignData:
	var out := CampaignData.new()
	out.type_key = type_key
	out.mode = mode
	out.days = days
	return out


static func _forever(type_key: StringName, mode: String) -> CampaignData:
	var out: CampaignData = _campaign(type_key, mode, 0)
	out.infinite = true
	out.unit_key = CampaignTypeDefs.UNIT_INFINITE
	return out


static func _reason(verdict: Dictionary) -> String:
	return String(verdict["reason"])


#The first uids of the roster the guild can still send somewhere. A case that has to launch or
#counter picks its crew here, since the seed of this manager and the Legal seed already hold
#mercs of a fresh roster. A roster with too few free mercs fails the case that asked.
static func _free_uids(res: Dictionary, count: int, label: String) -> Array[int]:
	var out: Array[int] = []
	var busy: Array[int] = GameState.busy_uids()
	for merc: MercenaryData in GameState.mercs:
		if out.size() >= count:
			break
		if merc != null and not busy.has(merc.merc_uid):
			out.append(merc.merc_uid)
	if out.size() < count:
		TestFixtures.check(res, label, false, "%d free of %d wanted" % [out.size(), count])
		for merc: MercenaryData in GameState.mercs:
			if out.size() >= count:
				break
			if merc != null and not out.has(merc.merc_uid):
				out.append(merc.merc_uid)
	return out


static func _ids(rows: Array[ApplicantData]) -> Array[int]:
	var out: Array[int] = []
	for row: ApplicantData in rows:
		out.append(row.id)
	return out


#The filtered ids in plain id order, so a membership case does not depend on the sort.
static func _sorted_ids(rows: Array[ApplicantData]) -> Array[int]:
	var out: Array[int] = _ids(rows)
	out.sort()
	return out


static func _cids(rows: Array[CampaignData]) -> Array[int]:
	var out: Array[int] = []
	for row: CampaignData in rows:
		out.append(row.id)
	return out


#One campaign list sorted one way, as plain ids.
static func _order(mode: String, key: StringName, ascending: bool, today: int,
		concluded: bool = false, infinite: bool = true) -> Array[int]:
	var list: Array[CampaignData] = PromotionsManager.campaigns_filtered(mode, concluded,
		infinite, today)
	return _cids(PromotionsManager.campaigns_sorted(list, key, ascending, today))


#The entries of want, in the order they appear in have.
static func _kept(have: Array[int], want: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for id: int in have:
		if want.has(id):
			out.append(id)
	return out


static func _keys_of(defs: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in defs:
		out.append(String(def["key"]))
	return out


#Case 1: the five campaign types, their gates and what each one costs up front.
static func _case_types(res: Dictionary) -> void:
	var keys: Array[String] = []
	var stars: Array[int] = []
	for row: Dictionary in CampaignTypeDefs.TYPES:
		keys.append(String(row["key"]))
		stars.append(int(row["stars"]))
	TestFixtures.check(res, "the campaign table holds the five handoff types in order",
		keys == ["wom", "flyers", "direct", "radio", "sponsor"], "keys %s" % [keys])
	TestFixtures.check(res, "campaign quality runs one star to five",
		stars == [1, 2, 3, 4, 5], "stars %s" % [stars])
	TestFixtures.check(res, "an unknown type key finds nothing",
		CampaignTypeDefs.find(&"nope").is_empty(), "row %s" % [CampaignTypeDefs.find(&"nope")])
	TestFixtures.check(res, "Word of Mouth needs one Odd Job slot, Flyers the Promotions key",
		not CampaignTypeDefs.unlocked(&"wom", {"oddJobs": 0})
		and CampaignTypeDefs.unlocked(&"wom", {"oddJobs": 1})
		and not CampaignTypeDefs.unlocked(&"flyers", {})
		and CampaignTypeDefs.unlocked(&"flyers", {"promotions": true}),
		"wom on oddJobs, flyers on promotions")
	TestFixtures.check(res, "an unheld ad key keeps Direct Sale, Radio and Sponsorship locked",
		not CampaignTypeDefs.unlocked(&"direct", {})
		and not CampaignTypeDefs.unlocked(&"radio", {})
		and not CampaignTypeDefs.unlocked(&"sponsor", {"adSponsor": false}),
		"adDirect, adRadio and adSponsor all start false")
	TestFixtures.check(res, "a daily type costs its price over its days",
		CampaignTypeDefs.cost(&"flyers", 30) == 150 and CampaignTypeDefs.cost(&"direct", 1) == 40
		and CampaignTypeDefs.cost(&"radio", 7) == 560
		and CampaignTypeDefs.cost(&"sponsor", 2) == 500,
		"flyers 150, direct 40, radio 560, sponsor 500")
	TestFixtures.check(res, "Word of Mouth costs its crew's Odd Job pay and ignores the days",
		CampaignTypeDefs.cost(&"wom", 30, 3, 25) == 75
		and CampaignTypeDefs.cost(&"wom", 1, 3, 25) == 75
		and CampaignTypeDefs.cost(&"wom", 30, 0, 25) == 0,
		"3 mercs at 25 is 75")
	TestFixtures.check(res, "a month of an Infinite campaign is thirty days of its price",
		CampaignTypeDefs.BILL_DAYS == 30 and CampaignTypeDefs.monthly_cost(&"radio") == 2400
		and CampaignTypeDefs.monthly_cost(&"sponsor") == 7500
		and CampaignTypeDefs.monthly_cost(&"wom") == 0,
		"radio 2400, sponsor 7500, wom nothing")
	TestFixtures.check(res, "only Word of Mouth is paid as a crew",
		CampaignTypeDefs.is_crew_paid(&"wom") and not CampaignTypeDefs.is_crew_paid(&"flyers")
		and not CampaignTypeDefs.is_crew_paid(&"sponsor"), "per_day 0 marks the crew types")
	TestFixtures.check(res, "every type but Word of Mouth hands notes back when it ends",
		not bool(CampaignTypeDefs.find(&"wom")["refund"])
		and bool(CampaignTypeDefs.find(&"flyers")["refund"])
		and bool(CampaignTypeDefs.find(&"radio")["refund"]), "the crew was already paid")
	TestFixtures.check(res, "Direct Sale is the only guild-only type and the picks match",
		bool(CampaignTypeDefs.find(&"direct")["guild_only"])
		and not bool(CampaignTypeDefs.find(&"sponsor")["guild_only"])
		and String(CampaignTypeDefs.find(&"direct")["picks"]) == CampaignTypeDefs.PICK_COMPANY
		and String(CampaignTypeDefs.find(&"sponsor")["picks"])
			== CampaignTypeDefs.PICK_COMPANY_OR_EVENT
		and String(CampaignTypeDefs.find(&"flyers")["picks"]) == "",
		"direct picks a company, sponsor a company or event")
	TestFixtures.check(res, "each type names the upgrade tier that unlocks it",
		String(CampaignTypeDefs.find(&"wom")["upgrade_id"]) == "oddjobs"
		and String(CampaignTypeDefs.find(&"flyers")["upgrade_id"]) == "promotions"
		and String(CampaignTypeDefs.find(&"radio")["upgrade_id"]) == "promomethods"
		and int(CampaignTypeDefs.find(&"radio")["upgrade_tier"]) == 2
		and int(CampaignTypeDefs.find(&"sponsor")["upgrade_tier"]) == 3
		and int(CampaignTypeDefs.find(&"sponsor")["upgrade_tiers"]) == 3,
		"radio is tier 2 of Promo Methods")
	TestFixtures.check(res, "a fixed campaign runs from one day to thirty",
		CampaignTypeDefs.MIN_DAYS == 1 and CampaignTypeDefs.MAX_DAYS == 30,
		"%d to %d" % [CampaignTypeDefs.MIN_DAYS, CampaignTypeDefs.MAX_DAYS])


#Case 2: how effective each type reads, with and without the Marketing Agency boost.
static func _case_effect(res: Dictionary) -> void:
	var plain: Dictionary = {}
	TestFixtures.check(res, "Word of Mouth varies with the crew and carries no percentage",
		CampaignTypeDefs.effect_text(&"wom", plain) == "Varies"
		and is_equal_approx(CampaignTypeDefs.effect_value(&"wom", plain),
			CampaignTypeDefs.VARIES), "%s" % [CampaignTypeDefs.effect_text(&"wom", plain)])
	TestFixtures.check(res, "an unboosted type reads its own effect as a whole percentage",
		CampaignTypeDefs.effect_text(&"flyers", plain) == "2%"
		and CampaignTypeDefs.effect_text(&"direct", plain) == "9%"
		and CampaignTypeDefs.effect_text(&"radio", plain) == "12%"
		and CampaignTypeDefs.effect_text(&"sponsor", plain) == "15%",
		"2, 9, 12 and 15 per cent")
	var boost: Dictionary = {"adBoost": 25}
	TestFixtures.check(res, "a quarter of Marketing Agency boost lifts every percentage",
		CampaignTypeDefs.effect_text(&"flyers", boost) == "2.5%"
		and CampaignTypeDefs.effect_text(&"direct", boost) == "11.3%"
		and CampaignTypeDefs.effect_text(&"radio", boost) == "15%"
		and CampaignTypeDefs.effect_text(&"sponsor", boost) == "18.8%",
		"9 x 1.25 reads %s" % [CampaignTypeDefs.effect_text(&"direct", boost)])
	TestFixtures.check(res, "the boost rounds to one decimal and Word of Mouth stays Varies",
		CampaignTypeDefs.effect_text(&"flyers", {"adBoost": 7}) == "2.1%"
		and CampaignTypeDefs.effect_text(&"wom", boost) == "Varies",
		"%s" % [CampaignTypeDefs.effect_text(&"flyers", {"adBoost": 7})])
	TestFixtures.check(res, "an unknown type has no effect to read",
		CampaignTypeDefs.effect_text(&"nope", plain) == "Varies", "unknown reads as Varies")


#Case 3: the places each type can reach.
static func _case_fit_locations(res: Dictionary) -> void:
	TestFixtures.check(res, "the nine handoff locations are named, not numbered",
		CampaignTypeDefs.LOCATIONS.size() == 9
		and CampaignTypeDefs.location_name(0) == "Buern"
		and CampaignTypeDefs.location_name(4) == "Rossade"
		and CampaignTypeDefs.location_name(8) == "Cyfrolaef"
		and CampaignTypeDefs.location_name(9) == "", "%s" % [CampaignTypeDefs.LOCATIONS])
	var wide: Array[int] = [0, 1, 4, 7, 8]
	TestFixtures.check(res, "Radio cannot reach three of the nine locations",
		CampaignTypeDefs.fit_locations(&"radio", wide) == [1, 8]
		and not CampaignTypeDefs.location_allowed(&"radio", 0)
		and not CampaignTypeDefs.location_allowed(&"radio", 4)
		and not CampaignTypeDefs.location_allowed(&"radio", 7)
		and CampaignTypeDefs.location_allowed(&"radio", 1),
		"%s" % [CampaignTypeDefs.fit_locations(&"radio", wide)])
	var two: Array[int] = [3, 5]
	TestFixtures.check(res, "Sponsorship keeps the first location and drops the rest",
		CampaignTypeDefs.fit_locations(&"sponsor", two) == [3]
		and bool(CampaignTypeDefs.find(&"sponsor")["one_loc"])
		and not bool(CampaignTypeDefs.find(&"flyers")["one_loc"]),
		"%s" % [CampaignTypeDefs.fit_locations(&"sponsor", two)])
	TestFixtures.check(res, "Flyers reach everywhere and an off-list index is refused",
		CampaignTypeDefs.fit_locations(&"flyers", wide) == wide
		and not CampaignTypeDefs.location_allowed(&"flyers", -1)
		and not CampaignTypeDefs.location_allowed(&"flyers", 9),
		"%s" % [CampaignTypeDefs.fit_locations(&"flyers", wide)])
	TestFixtures.check(res, "the picker shows the place names the Legal autoload holds",
		TraitFilterDefs.location_names() == CampaignTypeDefs.LOCATIONS
		and LegalManager.location(0).name == CampaignTypeDefs.LOCATIONS[0],
		"%s" % [TraitFilterDefs.location_names()])


#Case 4: the duration units, the cap that opens each one and what a unit adds up to.
static func _case_duration(res: Dictionary) -> void:
	TestFixtures.check(res, "the four duration units run days, weeks, months and Infinite",
		CampaignTypeDefs.unit_keys() == [CampaignTypeDefs.UNIT_DAYS,
		CampaignTypeDefs.UNIT_WEEKS, CampaignTypeDefs.UNIT_MONTHS,
		CampaignTypeDefs.UNIT_INFINITE], "%s" % [CampaignTypeDefs.unit_keys()])
	TestFixtures.check(res, "the Infinite cap is the one SubscriptionManager hands out",
		CampaignTypeDefs.INFINITE_CAP == SubscriptionManager.PROMO_DAYS_INFINITE,
		"%d against %d" % [CampaignTypeDefs.INFINITE_CAP,
		SubscriptionManager.PROMO_DAYS_INFINITE])
	var caps: Array[int] = [5, 10, 17, 25, 30, CampaignTypeDefs.INFINITE_CAP]
	var weeks: Array[int] = []
	var months: Array[int] = []
	for cap: int in caps:
		weeks.append(CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_WEEKS,
			{"maxPromoDays": cap}))
		months.append(CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_MONTHS,
			{"maxPromoDays": cap}))
	TestFixtures.check(res, "the weeks a cap allows never pass the thirty day ceiling",
		weeks == [0, 1, 2, 3, 4, 4], "weeks %s" % [weeks])
	TestFixtures.check(res, "a month only fits once the cap reaches thirty days",
		months == [0, 0, 0, 0, 1, 1], "months %s" % [months])
	TestFixtures.check(res, "no duration at all is offered without the Long Promos cap",
		not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS, {})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS,
			{"maxPromoDays": 0})
		and CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_DAYS, {}) == 0,
		"cap 0 allows nothing")
	TestFixtures.check(res, "each unit opens at its own cap",
		CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS, {"maxPromoDays": 5})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_WEEKS,
			{"maxPromoDays": 5})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_WEEKS, {"maxPromoDays": 10})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_MONTHS,
			{"maxPromoDays": 25})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_MONTHS, {"maxPromoDays": 30}),
		"weeks at 10, months at 30")
	TestFixtures.check(res, "Infinite waits on the top tier of Long Promos",
		not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_INFINITE,
			{"maxPromoDays": 30})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_INFINITE,
			{"maxPromoDays": CampaignTypeDefs.INFINITE_CAP}), "only the sentinel cap opens it")
	TestFixtures.check(res, "a unit and a quantity add up to plain days",
		CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_WEEKS, 2) == 14
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_DAYS, 5) == 5
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_MONTHS, 1) == 30
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_INFINITE, 3) == 0
		and CampaignTypeDefs.days_of(&"nope", 3) == 0,
		"2 weeks is %d days" % [CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_WEEKS, 2)])


#Case 5: the merc filter rows, their groups, their locks and what counts as narrowing.
static func _case_merc_defs(res: Dictionary) -> void:
	_fresh()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs()
	var hiring: Array[Dictionary] = PromotionsManager.hiring_defs()
	TestFixtures.check(res, "the builder has fourteen merc filters and Hiring adds Applied Via",
		defs.size() == 14 and hiring.size() == 15
		and TraitFilterDefs.find(defs, &"from").is_empty(),
		"builder %d, hiring %d" % [defs.size(), hiring.size()])
	var from: Dictionary = TraitFilterDefs.find(hiring, &"from")
	var options: Array = from.get("options", [])
	var values: Array = from.get("values", [])
	TestFixtures.check(res, "Applied Via lists the nine job campaigns and ends with Walk-In",
		options.size() == 10 and String(options[0]) == "Campaign 1"
		and String(options[1]) == "Campaign 3" and String(options[9]) == "Walk-In"
		and int(values[1]) == 3 and int(values[8]) == 10
		and int(values[9]) == TraitFilterDefs.WALK_IN, "options %s values %s" % [options, values])
	var bad_group: Array[String] = []
	for def: Dictionary in hiring:
		if not TraitFilterDefs.GROUPS.has(String(def["group"])):
			bad_group.append(String(def["key"]))
	TestFixtures.check(res, "every merc filter sits in one of the four groups",
		bad_group.is_empty(), "off-group rows %s" % [bad_group])
	TestFixtures.check(res, "the Identity group holds tradition and the four trait rows",
		_keys_of(TraitFilterDefs.in_group(hiring, "Identity"))
		== ["tradition", "ancestry", "bloodline", "heritage", "criminality"],
		"%s" % [_keys_of(TraitFilterDefs.in_group(hiring, "Identity"))])
	TestFixtures.check(res, "the Mental group holds the two stats, knowledges and tools",
		_keys_of(TraitFilterDefs.in_group(hiring, "Mental"))
		== ["cognition", "wile", "knowledges", "tools"],
		"%s" % [_keys_of(TraitFilterDefs.in_group(hiring, "Mental"))])
	TestFixtures.check(res, "the Physical group holds age and the three stats",
		_keys_of(TraitFilterDefs.in_group(hiring, "Physical"))
		== ["age", "vigor", "speed", "dexterity"],
		"%s" % [_keys_of(TraitFilterDefs.in_group(hiring, "Physical"))])
	var ancestry: Dictionary = TraitFilterDefs.find(hiring, &"ancestry")
	TestFixtures.check(res, "Ancestry is locked until Hiring Discrimination is held",
		TraitFilterDefs.locked(ancestry, {})
		and TraitFilterDefs.locked(ancestry, {"hiringDiscrim": false})
		and not TraitFilterDefs.locked(ancestry, {"hiringDiscrim": true}),
		"lock key %s" % [ancestry.get("lock", "")])
	TestFixtures.check(res, "Bloodline and Age lock on the same key as Ancestry",
		TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"bloodline"), {})
		and TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"age"), {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"age"),
			{"hiringDiscrim": true}), "both name hiringDiscrim")
	TestFixtures.check(res, "Heritage waits on a Background Check, Criminality on a Criminal one",
		TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"heritage"), {"background": 0})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"heritage"),
			{"background": 1})
		and TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"criminality"), {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"criminality"),
			{"criminal": true}), "background tier 1 and criminal")
	var speed: Dictionary = TraitFilterDefs.find(hiring, &"speed")
	TestFixtures.check(res, "Min Speed opens at Mercday Pro and stays open above it",
		TraitFilterDefs.locked(speed, {"plan": "free"})
		and not TraitFilterDefs.locked(speed, {"plan": "pro"})
		and not TraitFilterDefs.locked(speed, {"plan": "enterprise"}),
		"plan tier %d on free" % [TraitFilterDefs.tier_of({"plan": "free"}, "plan")])
	TestFixtures.check(res, "Salary Request, Applied Via and Tradition are never locked",
		not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"salary"), {})
		and not TraitFilterDefs.locked(from, {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"tradition"), {}),
		"no lock key on the three open rows")
	var salary: Dictionary = TraitFilterDefs.find(hiring, &"salary")
	TestFixtures.check(res, "Salary Request is a two-handled slider over the asking rate",
		String(salary["kind"]) == TraitFilterDefs.KIND_SLIDER2
		and String(salary["field"]) == "ask" and float(salary["max"]) == 2000.0
		and float(salary["step"]) == 50.0, "kind %s field %s" % [salary["kind"], salary["field"]])
	TestFixtures.check(res, "a stat row reads the applicant's stats dictionary",
		String(TraitFilterDefs.find(hiring, &"vigor")["field"]) == "stats/vigor"
		and String(TraitFilterDefs.find(hiring, &"vigor")["kind"]) == TraitFilterDefs.KIND_MIN,
		"field %s" % [TraitFilterDefs.find(hiring, &"vigor")["field"]])
	TestFixtures.check(res, "a row only narrows once it leaves its own bounds",
		not TraitFilterDefs.active(salary, null)
		and not TraitFilterDefs.active(salary, [0.0, 2000.0])
		and TraitFilterDefs.active(salary, [50.0, 2000.0])
		and TraitFilterDefs.active(salary, [0.0, 1950.0])
		and not TraitFilterDefs.active(TraitFilterDefs.find(hiring, &"vigor"), 0)
		and TraitFilterDefs.active(TraitFilterDefs.find(hiring, &"vigor"), 1)
		and not TraitFilterDefs.active(ancestry, [])
		and TraitFilterDefs.active(ancestry, ["Ancestry 1"]), "bounds mean no filter")
	var picked: Dictionary = {&"ancestry": ["Ancestry 1"], &"tradition": ["Brave"]}
	TestFixtures.check(res, "a group's active count skips the rows the guild cannot read",
		TraitFilterDefs.active_count(hiring, "Identity", picked, {}) == 1
		and TraitFilterDefs.active_count(hiring, "Identity", picked,
			{"hiringDiscrim": true}) == 2,
		"1 without Hiring Discrimination, 2 with it")


#Case 6: the contract filters a Guild Promo campaign targets, and their tier locks.
static func _case_contract_defs(res: Dictionary) -> void:
	_fresh()
	var flyers: Array[Dictionary] = TraitFilterDefs.contract_defs(&"flyers")
	var direct: Array[Dictionary] = TraitFilterDefs.contract_defs(&"direct")
	var sponsor: Array[Dictionary] = TraitFilterDefs.contract_defs(&"sponsor")
	TestFixtures.check(res, "a guild campaign targets difficulty, contract type and location",
		_keys_of(flyers) == ["diff", "ctype", "loc"], "%s" % [_keys_of(flyers)])
	TestFixtures.check(res, "only a type that names a sponsor leads with the pick",
		_keys_of(direct) == ["target", "diff", "ctype", "loc"]
		and _keys_of(sponsor) == ["target", "diff", "ctype", "loc"],
		"direct %s" % [_keys_of(direct)])
	var target: Dictionary = TraitFilterDefs.find(direct, &"target")
	TestFixtures.check(res, "Direct Sale advertises to any number of the six companies",
		(target["options"] as Array).size() == 6 and String(target["short"]) == "Advertise To"
		and String(target["label"]) == "Advertise To"
		and String(target["kind"]) == TraitFilterDefs.KIND_CHIPS
		and (target["values"] as Array) == (target["options"] as Array)
		and bool(target["full_row"]),
		"kind %s, options %s" % [target["kind"], target["options"]])
	var sponsor_target: Dictionary = TraitFilterDefs.find(sponsor, &"target")
	var sponsor_options: Array = sponsor_target["options"]
	TestFixtures.check(res, "Sponsorship picks one company or one event",
		sponsor_options.size() == 9 and String(sponsor_options[5]) == "Company 6"
		and String(sponsor_options[6]) == "Event 1"
		and String(sponsor_target["label"]) == "Sponsor (Company or Event)"
		and String(sponsor_target["kind"]) == TraitFilterDefs.KIND_ONE,
		"options %s" % [sponsor_options])
	var diff: Dictionary = TraitFilterDefs.find(flyers, &"diff")
	TestFixtures.check(res, "the difficulty range only narrows inside half a star to five",
		not TraitFilterDefs.active(diff, [0.5, 5.0])
		and TraitFilterDefs.active(diff, [1.5, 5.0])
		and TraitFilterDefs.active(diff, [0.5, 4.0]), "stars2 bounds")
	var rows: Array = diff["row_locks"]
	var low: Dictionary = rows[0]
	var high: Dictionary = rows[1]
	TestFixtures.check(res, "the two difficulty handles are separate Guild Promo tiers",
		rows.size() == 2 and String(low["label"]) == "Min"
		and String(low["lock"]) == "gpMinDifficulty" and int(low["upgrade_tier"]) == 2
		and String(high["lock"]) == "gpMaxDifficulty" and int(high["upgrade_tier"]) == 3
		and int(high["upgrade_tiers"]) == TraitFilterDefs.GUILD_PROMO_TIERS,
		"row locks %s" % [rows])
	TestFixtures.check(res, "a difficulty handle stays locked until its own tier is paid for",
		TraitFilterDefs.locked(low, {}) and not TraitFilterDefs.locked(low,
			{"gpMinDifficulty": true}) and TraitFilterDefs.locked(high,
			{"gpMinDifficulty": true}), "the Min tier does not open the Max handle")
	var ctype: Dictionary = TraitFilterDefs.find(flyers, &"ctype")
	TestFixtures.check(res, "the Contract Type section is the fourth Guild Promo tier",
		String(ctype["lock"]) == "gpContractType" and int(ctype["upgrade_tier"]) == 4
		and String(ctype["upgrade_id"]) == TraitFilterDefs.GUILD_PROMO_ID
		and TraitFilterDefs.locked(ctype, {})
		and not TraitFilterDefs.locked(ctype, {"gpContractType": true}),
		"lock %s tier %s" % [ctype["lock"], ctype["upgrade_tier"]])
	var ctype_mods: Array = ctype["mods"]
	var hist: Array[int] = TraitFilterDefs.history(0, TraitFilterDefs.CTYPE_HIST_SEED)
	TestFixtures.check(res, "each contract type module carries its placeholder history",
		ctype_mods.size() == 6 and int((ctype_mods[0] as Dictionary)["received"]) == hist[0]
		and int((ctype_mods[0] as Dictionary)["completed"]) == hist[1]
		and int((ctype_mods[0] as Dictionary)["failed"]) == hist[2],
		"mod 0 %s against %s" % [ctype_mods[0], hist])
	TestFixtures.check(res, "a contract type module hides the relationship row",
		not bool((ctype_mods[0] as Dictionary)["has_relationship"]),
		"has_relationship %s" % [(ctype_mods[0] as Dictionary)["has_relationship"]])
	var loc: Dictionary = TraitFilterDefs.find(flyers, &"loc")
	var loc_mods: Array = loc["mods"]
	TestFixtures.check(res, "the nine locations show a relationship and gate on a permit",
		loc_mods.size() == 9 and bool((loc_mods[0] as Dictionary)["has_relationship"])
		and int((loc_mods[3] as Dictionary)["relationship"]) == -1
		and String(loc["gate"]) == "opsPermits" and String(loc["short"]) == "Locations",
		"relationship 3 %s" % [(loc_mods[3] as Dictionary)["relationship"]])
	var open_at: int = -1
	var shut_at: int = -1
	for i: int in range(loc_mods.size()):
		if LegalManager.has_permit(i, LegalManager.PERMIT_OPS) and open_at < 0:
			open_at = i
		elif not LegalManager.has_permit(i, LegalManager.PERMIT_OPS) and shut_at < 0:
			shut_at = i
	TestFixtures.check(res, "a location with no operating permit is disabled with the permit note",
		open_at >= 0 and shut_at >= 0
		and not bool((loc_mods[open_at] as Dictionary)["disabled"])
		and bool((loc_mods[shut_at] as Dictionary)["disabled"])
		and String((loc_mods[shut_at] as Dictionary)["disabled_reason"])
			== TraitFilterDefs.NO_PERMIT_NOTE
		and String((loc_mods[8] as Dictionary)["name"]) == "Cyfrolaef",
		"open %d, shut %d" % [open_at, shut_at])


#Case 7: the placeholder seed, field by field.
static func _case_seed(res: Dictionary) -> void:
	_fresh()
	var today: int = GameState.day()
	TestFixtures.check(res, "a fresh guild opens on the first day of play",
		today == TrynnCalendar.day_index(TrynnCalendar.START_MINUTE), "day %d" % today)
	var rows: Array[ApplicantData] = PromotionsManager.applicants
	TestFixtures.check(res, "the seed lays down eight applicants numbered from twenty",
		rows.size() == 8 and rows[0].id == 20 and rows[7].id == 27, "ids %s" % [_ids(rows)])
	var levels: Array[int] = []
	var asks: Array[int] = []
	var fits: Array[float] = []
	var rarities: Array[String] = []
	var bad: Array[String] = []
	for row: ApplicantData in rows:
		levels.append(row.level)
		asks.append(row.ask)
		fits.append(row.fit)
		rarities.append(row.rarity)
		if row.name == "" or row.tradition == "" or row.ancestry == "" or row.bloodline == "":
			bad.append("%d names" % row.id)
		if row.heritage == "" or row.criminality == "" or row.age <= 0:
			bad.append("%d traits" % row.id)
		if row.stats.size() != ApplicantData.STAT_KEYS.size() or row.tools.size() != 1:
			bad.append("%d stats" % row.id)
		if row.knowledges.size() != 1 or not ApplicantData.RARITIES.has(row.rarity):
			bad.append("%d rarity" % row.id)
		if not row.is_open():
			bad.append("%d status" % row.id)
	TestFixtures.check(res, "every seeded applicant has every field filled",
		bad.is_empty(), TestFixtures.detail(bad, rows.size(), "applicants"))
	TestFixtures.check(res, "the seeded levels, rates and fits are the handoff's numbers",
		levels == [4, 9, 2, 12, 6, 15, 3, 8] and asks == [320, 540, 260, 780, 410, 960, 300, 600]
		and fits == [2.0, 3.5, 1.5, 4.0, 3.0, 4.5, 2.5, 3.0],
		"levels %s asks %s" % [levels, asks])
	TestFixtures.check(res, "rarity rises with uniqueness across the seed",
		rarities == ["Common", "Uncommon", "Common", "Rare", "Uncommon", "Very Rare", "Common",
		"Uncommon"] and rows[5].rarity_rank() == 3, "rarities %s" % [rarities])
	TestFixtures.check(res, "the placeholder names follow the applicant id",
		rows[0].name == "FirstName21 LastName21" and rows[7].name == "FirstName28 LastName28",
		"%s and %s" % [rows[0].name, rows[7].name])
	TestFixtures.check(res, "each seeded applicant came through the campaign the handoff names",
		rows[0].campaign_id == 1 and rows[1].campaign_id == 3 and rows[3].campaign_id == 5
		and rows[4].campaign_id == 6 and rows[5].campaign_id == 9 and rows[7].campaign_id == 10
		and rows[2].is_walk_in() and rows[6].is_walk_in(),
		"walk-ins %d and %d" % [rows[2].id, rows[6].id])
	TestFixtures.check(res, "the seeded ages and stats read straight off the applicant",
		rows[0].age == 19 and rows[7].age == 54 and rows[0].stat("speed") == 3
		and rows[1].stat("vigor") == 4 and rows[0].stat("dexterity") == 4,
		"ages %d to %d" % [rows[0].age, rows[7].age])
	var campaigns: Array[CampaignData] = PromotionsManager.campaigns
	TestFixtures.check(res, "the seed runs ten campaigns, numbered one to ten",
		campaigns.size() == 10 and _cids(campaigns) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"%s" % [_cids(campaigns)])
	TestFixtures.check(res, "only campaign two is a guild promo",
		PromotionsManager.campaign_count(CampaignData.MODE_PROMO) == 1
		and PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 9
		and PromotionsManager.campaign_of(2).mode == CampaignData.MODE_PROMO,
		"%d job ads" % [PromotionsManager.campaign_count(CampaignData.MODE_JOB)])
	var job: CampaignData = PromotionsManager.campaign_of(1)
	TestFixtures.check(res, "the first job ad is twelve days into its thirty and counts its haul",
		job.type_key == &"flyers" and job.days == 30 and job.day_started == today - 12
		and PromotionsManager.results_of(job) == 3 and not job.is_concluded(today)
		and job.days_left(today) == 18,
		"started %d, %d results" % [job.day_started, PromotionsManager.results_of(job)])
	TestFixtures.check(res, "the job ad targets the two seeded traditions",
		(job.filters[&"tradition"] as Array) == ["Brave", "Mage"],
		"%s" % [job.filters[&"tradition"]])
	var promo: CampaignData = PromotionsManager.campaign_of(2)
	TestFixtures.check(res, "the guild promo is a Word of Mouth run with a type and a location",
		promo.type_key == &"wom" and promo.days == 14 and promo.day_started == today - 3
		and promo.contract_types == [1] and promo.locations == [0] and promo.crew == [2, 5]
		and promo.pay_per == 25 and PromotionsManager.results_of(promo) == 1,
		"types %s locations %s" % [promo.contract_types, promo.locations])
	var radio: CampaignData = PromotionsManager.campaign_of(3)
	TestFixtures.check(res, "the Radio ad runs on and bills again twenty days out",
		radio.infinite and radio.days == 0 and radio.per_day == 80
		and radio.days_left(today) == CampaignTypeDefs.INFINITE_CAP
		and radio.next_bill_day == today + 20 and PromotionsManager.results_of(radio) == 10,
		"next bill %d, today %d" % [radio.next_bill_day, today])
	var sponsor: CampaignData = PromotionsManager.campaign_of(5)
	var forever: CampaignData = PromotionsManager.campaign_of(9)
	TestFixtures.check(res, "a sponsored ad carries the company or event it picked",
		sponsor.sponsor_index == 2 and sponsor.sponsor_target == "Company 3"
		and forever.sponsor_index == 7 and forever.sponsor_target == "Event 2"
		and forever.next_bill_day == today + 20,
		"%s and %s" % [sponsor.sponsor_target, forever.sponsor_target])
	TestFixtures.check(res, "a sponsored ad files its pick as the one name a pick-one row reads",
		sponsor.filters[&"target"] is String
		and String(sponsor.filters[&"target"]) == "Company 3"
		and String(forever.filters[&"target"]) == "Event 2",
		"%s and %s" % [sponsor.filters[&"target"], forever.filters[&"target"]])
	var over: CampaignData = PromotionsManager.campaign_of(8)
	TestFixtures.check(res, "the oldest job ad has already run out",
		over.is_concluded(today) and over.days_left(today) == 0
		and over.next_arrival_day == -1 and PromotionsManager.results_of(over) == 4,
		"started %d, %d results" % [over.day_started, PromotionsManager.results_of(over)])
	TestFixtures.check(res, "the next campaign is named after the id it will take",
		PromotionsManager.next_campaign_name() == "Campaign 11"
		and PromotionsManager.next_campaign_id == 11,
		"%s" % [PromotionsManager.next_campaign_name()])
	TestFixtures.check(res, "a campaign name answers by id, and a walk-in names itself",
		PromotionsManager.campaign_name(1) == "Campaign 1"
		and PromotionsManager.campaign_name(10) == "Campaign 10"
		and PromotionsManager.campaign_name(ApplicantData.WALK_IN) == "Walk-In"
		and PromotionsManager.campaign_name(99) == "",
		"%s" % [PromotionsManager.campaign_name(10)])
	TestFixtures.check(res, "two seeded applicants are unseen until the player looks",
		PromotionsManager.has_unseen() and PromotionsManager.applicant_of(23).unseen
		and PromotionsManager.applicant_of(25).unseen
		and not PromotionsManager.applicant_of(20).unseen, "23 and 25 carry the dot")
	PromotionsManager.mark_seen()
	TestFixtures.check(res, "marking the page seen clears every dot",
		not PromotionsManager.has_unseen() and not PromotionsManager.applicant_of(23).unseen,
		"has_unseen %s" % [PromotionsManager.has_unseen()])
	TestFixtures.check(res, "an unknown id finds no campaign and no applicant",
		PromotionsManager.campaign_of(99) == null and PromotionsManager.applicant_of(99) == null,
		"both come back null")


#Case 8: the numbers one campaign card reads off itself.
static func _case_card_stats(res: Dictionary) -> void:
	_fresh()
	var t: int = GameState.day()
	var one: CampaignData = PromotionsManager.campaign_of(1)
	TestFixtures.check(res, "a fixed ad spends by the day and holds the rest of its budget",
		one.used(t) == 12 and one.run_days(t) == 12 and one.spent_so_far(t) == 60
		and one.unused_days(t) == 18 and one.budget_remaining(t) == 90
		and one.total_committed(t) == 150 and is_equal_approx(one.progress(t), 0.4),
		"spent %d, left %d" % [one.spent_so_far(t), one.budget_remaining(t)])
	var radio: CampaignData = PromotionsManager.campaign_of(3)
	TestFixtures.check(res, "an Infinite ad spends every day it has run and holds one month",
		radio.used(t) == 40 and radio.spent_so_far(t) == 3200
		and radio.unused_days(t) == 20 and radio.budget_remaining(t) == 1600
		and is_equal_approx(radio.progress(t), 1.0) and not radio.is_concluded(t),
		"spent %d, left %d" % [radio.spent_so_far(t), radio.budget_remaining(t)])
	var over: CampaignData = PromotionsManager.campaign_of(8)
	TestFixtures.check(res, "an ad that ran out spent its whole budget and no more",
		over.used(t) == 45 and over.run_days(t) == 30 and over.spent_so_far(t) == 150
		and over.budget_remaining(t) == 0 and over.is_concluded(t),
		"spent %d over %d days" % [over.spent_so_far(t), over.run_days(t)])
	var promo: CampaignData = PromotionsManager.campaign_of(2)
	var crew: CampaignData = PromotionsManager.campaign_of(7)
	TestFixtures.check(res, "a Word of Mouth ad spent its crew pay and holds nothing back",
		promo.spent_so_far(t) == 50 and promo.budget_remaining(t) == 0
		and crew.spent_so_far(t) == 50 and crew.budget_remaining(t) == 0
		and crew.unused_days(t) == 0,
		"promo %d, crew %d" % [promo.spent_so_far(t), crew.spent_so_far(t)])
	var forever: CampaignData = PromotionsManager.campaign_of(9)
	TestFixtures.check(res, "the oldest Infinite ad has spent seventy days of Sponsorship",
		forever.spent_so_far(t) == 17500 and forever.budget_remaining(t) == 5000
		and forever.total_committed(t) == 22500,
		"spent %d, left %d" % [forever.spent_so_far(t), forever.budget_remaining(t)])
	TestFixtures.check(res, "the success rate is the results a week so far",
		is_equal_approx(PromotionsManager.success_rate(one, t), 1.75)
		and is_equal_approx(PromotionsManager.success_rate(PromotionsManager.campaign_of(10), t),
			7.0)
		and is_equal_approx(PromotionsManager.success_rate(PromotionsManager.campaign_of(4), t),
			0.0), "campaign 1 at %.2f a week" % [PromotionsManager.success_rate(one, t)])
	TestFixtures.check(res, "no campaign has no stats to read",
		PromotionsManager.results_of(null) == 0
		and is_equal_approx(PromotionsManager.success_rate(null, t), 0.0), "both read nothing")


#Case 9: the My Promotions list: what the two toggles hide and how the five sorts order it.
static func _case_list(res: Dictionary) -> void:
	_fresh()
	var t: int = GameState.day()
	var job: String = CampaignData.MODE_JOB
	TestFixtures.check(res, "the tab count is every campaign of the tab",
		PromotionsManager.campaign_count(job) == 9
		and PromotionsManager.campaign_count(CampaignData.MODE_PROMO) == 1
		and PromotionsManager.campaigns_in(job).size() == 9,
		"%d job ads" % [PromotionsManager.campaign_count(job)])
	TestFixtures.check(res, "the list opens on the running ads and hides the one that ran out",
		PromotionsManager.campaigns_filtered(job, false, true, t).size() == 8
		and not _cids(PromotionsManager.campaigns_filtered(job, false, true, t)).has(8),
		"%s" % [_cids(PromotionsManager.campaigns_filtered(job, false, true, t))])
	TestFixtures.check(res, "Show Concluded brings the finished ad back",
		PromotionsManager.campaigns_filtered(job, true, true, t).size() == 9
		and _cids(PromotionsManager.campaigns_filtered(job, true, true, t)).has(8),
		"%d rows" % [PromotionsManager.campaigns_filtered(job, true, true, t).size()])
	TestFixtures.check(res, "dropping the Infinite ads takes two more rows out",
		PromotionsManager.campaigns_filtered(job, false, false, t).size() == 6
		and PromotionsManager.campaigns_filtered(job, true, false, t).size() == 7,
		"%d and %d rows" % [PromotionsManager.campaigns_filtered(job, false, false, t).size(),
		PromotionsManager.campaigns_filtered(job, true, false, t).size()])
	TestFixtures.check(res, "Start Date reads newest first and turns right around",
		_order(job, &"start", false, t)[0] == 10 and _order(job, &"start", true, t)[0] == 9
		and PromotionsManager.CAMPAIGN_SORT_DEFAULT == &"start"
		and not PromotionsManager.CAMPAIGN_ASCENDING_DEFAULT,
		"%s" % [_order(job, &"start", false, t)])
	var left: Array[int] = _order(job, &"left", true, t)
	TestFixtures.check(res, "Time Remaining leads with the ad closest to its end",
		left[0] == 7 and left[1] == 6 and left[6] == 9 and left[7] == 3,
		"%s" % [left])
	var method: Array[int] = _order(job, &"method", true, t)
	TestFixtures.check(res, "Campaign Method leads with the best method the guild bought",
		PromotionsManager.campaign_of(method[0]).type_key == &"sponsor" and method[0] == 9
		and PromotionsManager.campaign_of(method[7]).type_key == &"wom",
		"%s" % [method])
	var cost: Array[int] = _order(job, &"cost", true, t)
	TestFixtures.check(res, "Cost sorts on the notes the ad has committed",
		cost[0] == 4 and cost[7] == 9
		and _order(job, &"cost", false, t)[0] == 9, "%s" % [cost])
	var best: Array[int] = _order(job, &"success", false, t)
	TestFixtures.check(res, "Success Rate leads with the ad pulling the most a week",
		best[0] == 10 and _order(job, &"success", true, t)[0] == 4, "%s" % [best])
	var tied: Array[int] = [1, 3, 6]
	TestFixtures.check(res, "campaigns on the same rate hold the newest first, either way",
		_kept(best, tied) == [6, 3, 1]
		and _kept(_order(job, &"success", true, t), tied) == [6, 3, 1],
		"%s" % [_kept(best, tied)])
	TestFixtures.check(res, "the sort dropdown reads its five labels off the table",
		PromotionsManager.CAMPAIGN_SORTS.size() == 5
		and PromotionsManager.campaign_sort_label(&"start") == "Start Date"
		and PromotionsManager.campaign_sort_label(&"left") == "Time Remaining"
		and PromotionsManager.campaign_sort_label(&"success") == "Success Rate"
		and PromotionsManager.campaign_sort_label(&"method") == "Campaign Method"
		and PromotionsManager.campaign_sort_label(&"cost") == "Cost"
		and PromotionsManager.campaign_sort_label(&"nope") == "", "five sorts, no sixth")


#Case 10: the Hiring filters, the Applied Via chips and the four sorts.
static func _case_filters(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "an untouched filter set leaves every applicant standing",
		PromotionsManager.applicants_filtered().size() == 8,
		"%d rows" % [PromotionsManager.applicants_filtered().size()])
	var cheap: Dictionary = {&"salary": [0.0, 400.0]}
	TestFixtures.check(res, "the salary slider keeps the applicants inside its range",
		_sorted_ids(PromotionsManager.applicants_filtered(cheap)) == [20, 22, 26],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(cheap))])
	var strong: Dictionary = {&"vigor": 5}
	TestFixtures.check(res, "a locked stat row filters nothing until its test is held",
		PromotionsManager.applicants_filtered(strong).size() == 8,
		"%d rows" % [PromotionsManager.applicants_filtered(strong).size()])
	SubscriptionManager.set_entitlements({"brawn": true})
	TestFixtures.check(res, "Min Vigor keeps the applicants at or above it once unlocked",
		_sorted_ids(PromotionsManager.applicants_filtered(strong)) == [22, 24, 26],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(strong))])
	var one_tradition: Dictionary = {&"tradition": ["Chymist"]}
	TestFixtures.check(res, "a tradition chip keeps that tradition alone",
		_sorted_ids(PromotionsManager.applicants_filtered(one_tradition)) == [20],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(one_tradition))])
	var ancestry: Dictionary = {&"ancestry": ["Ancestry 1"]}
	TestFixtures.check(res, "an Ancestry chip needs Hiring Discrimination before it bites",
		PromotionsManager.applicants_filtered(ancestry).size() == 8, "still eight rows")
	SubscriptionManager.set_entitlements({"hiringDiscrim": true})
	TestFixtures.check(res, "the Ancestry chip then keeps the two who carry it",
		_sorted_ids(PromotionsManager.applicants_filtered(ancestry)) == [20, 26],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(ancestry))])
	var young: Dictionary = {&"age": [16.0, 30.0]}
	TestFixtures.check(res, "the age range keeps the applicants inside it",
		_sorted_ids(PromotionsManager.applicants_filtered(young)) == [20, 21, 22],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(young))])
	var tools: Dictionary = {&"tools": ["Tool 3"]}
	SubscriptionManager.set_entitlements({"skilltest": true})
	TestFixtures.check(res, "a tools chip matches an applicant's own list",
		_sorted_ids(PromotionsManager.applicants_filtered(tools)) == [20, 26],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(tools))])
	var two: Dictionary = {&"salary": [0.0, 400.0], &"age": [16.0, 30.0]}
	TestFixtures.check(res, "two filters narrow together",
		_sorted_ids(PromotionsManager.applicants_filtered(two)) == [20, 22],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered(two))])
	var walk: Array[int] = [ApplicantData.WALK_IN]
	var via_one: Array[int] = [1]
	var both: Array[int] = [1, ApplicantData.WALK_IN]
	TestFixtures.check(res, "the Applied Via chips read the campaign an applicant came through",
		_sorted_ids(PromotionsManager.applicants_filtered({}, walk)) == [22, 26]
		and _sorted_ids(PromotionsManager.applicants_filtered({}, via_one)) == [20]
		and PromotionsManager.applicants_filtered({}, both).size() == 3,
		"walk-ins %s" % [_sorted_ids(PromotionsManager.applicants_filtered({}, walk))])
	var empty: Array[int] = []
	TestFixtures.check(res, "Fit descending is the list's opening order",
		_ids(PromotionsManager.applicants_filtered())[0] == 25
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"fit", false))[0] == 22,
		"%s" % [_ids(PromotionsManager.applicants_filtered())])
	TestFixtures.check(res, "Level sorts both ways",
		_ids(PromotionsManager.applicants_filtered({}, empty, &"level", true))[0] == 25
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"level", false))[0] == 22,
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"level", true))])
	TestFixtures.check(res, "Salary sorts both ways",
		_ids(PromotionsManager.applicants_filtered({}, empty, &"salary", true))[0] == 25
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"salary", false))[0] == 22,
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"salary", false))])
	TestFixtures.check(res, "Uniqueness sorts on the rarity behind it and ties on the id",
		_ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", true))[0] == 25
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", false))[0] == 20,
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", true))])
	TestFixtures.check(res, "the sort dropdown reads its four labels off the table",
		PromotionsManager.sort_label(&"uniqueness") == "Uniqueness"
		and PromotionsManager.sort_label(&"fit") == "Fit"
		and PromotionsManager.sort_label(&"level") == "Level"
		and PromotionsManager.sort_label(&"salary") == "Salary"
		and PromotionsManager.sort_label(&"nope") == "", "four sorts, no fifth")


#Case 11: what stops a campaign going out, and what launching one costs.
static func _case_launch(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	PromotionsManager.mark_seen()
	GameState.bank_notes = 1000
	TestFixtures.check(res, "no campaign refuses with its own reason",
		_reason(PromotionsManager.can_launch(null)) == "No campaign.",
		_reason(PromotionsManager.can_launch(null)))
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "a type whose key is not held names itself as locked",
		_reason(PromotionsManager.can_launch(radio)) == "Radio is locked.",
		_reason(PromotionsManager.can_launch(radio)))
	var direct_job: CampaignData = _campaign(&"direct", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "Direct Sale refuses the Job Ads tab",
		_reason(PromotionsManager.can_launch(direct_job)) == "Direct Sale is for Guild Promo only.",
		_reason(PromotionsManager.can_launch(direct_job)))
	var direct: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	TestFixtures.check(res, "Direct Sale asks who it advertises to",
		_reason(PromotionsManager.can_launch(direct)) == "Choose who to advertise to.",
		_reason(PromotionsManager.can_launch(direct)))
	var sponsor: CampaignData = _campaign(&"sponsor", CampaignData.MODE_PROMO, 30)
	TestFixtures.check(res, "Sponsorship asks who it sponsors",
		_reason(PromotionsManager.can_launch(sponsor)) == "Choose who to sponsor.",
		_reason(PromotionsManager.can_launch(sponsor)))
	direct.sponsor_target = "Company 2"
	TestFixtures.check(res, "naming the company clears that reason",
		bool(PromotionsManager.can_launch(direct)["ok"]),
		_reason(PromotionsManager.can_launch(direct)))
	var three: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	var trio: Array[int] = [0, 2, 4]
	three.advertise_targets = trio
	TestFixtures.check(res, "three advertised companies clear the reason on the indices alone",
		bool(PromotionsManager.can_launch(three)["ok"]) and three.sponsor_target == "",
		_reason(PromotionsManager.can_launch(three)))
	var one_pick: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	var only: Array[int] = [3]
	one_pick.advertise_targets = only
	var no_pick: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	TestFixtures.check(res, "one company is enough and an empty pick list still refuses",
		bool(PromotionsManager.can_launch(one_pick)["ok"])
		and _reason(PromotionsManager.can_launch(no_pick)) == "Choose who to advertise to.",
		_reason(PromotionsManager.can_launch(one_pick)))
	var sponsor_pick: CampaignData = _campaign(&"sponsor", CampaignData.MODE_PROMO, 3)
	sponsor_pick.sponsor_index = 6
	TestFixtures.check(res, "a sponsored event index clears the sponsor reason",
		bool(PromotionsManager.can_launch(sponsor_pick)["ok"]),
		_reason(PromotionsManager.can_launch(sponsor_pick)))
	var short_run: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 0)
	var long_run: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 31)
	TestFixtures.check(res, "a run shorter than a day or longer than thirty refuses",
		_reason(PromotionsManager.can_launch(short_run)) == "A promo runs at least 1 day."
		and _reason(PromotionsManager.can_launch(long_run)) == "Promos run up to 30 days.",
		_reason(PromotionsManager.can_launch(short_run)))
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 14)
	TestFixtures.check(res, "Word of Mouth needs a crew to send",
		_reason(PromotionsManager.can_launch(wom)) == "Add at least one merc.",
		_reason(PromotionsManager.can_launch(wom)))
	var crowd: Array[int] = [1, 2, 3]
	wom.crew = crowd
	TestFixtures.check(res, "the crew cannot outrun the Odd Job slots the guild holds",
		_reason(PromotionsManager.can_launch(wom)) == "Odd Jobs holds 2 mercs.",
		_reason(PromotionsManager.can_launch(wom)))
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the Word of Mouth crew")
	wom.crew = pair
	TestFixtures.check(res, "Word of Mouth costs its crew's pay and nothing by the day",
		PromotionsManager.launch_cost(wom) == 50 and PromotionsManager.pay_per_of(wom) == 25,
		"cost %d" % [PromotionsManager.launch_cost(wom)])
	GameState.bank_notes = 100
	var pricey: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "a campaign the bank cannot cover refuses",
		_reason(PromotionsManager.can_launch(pricey)) == "Not enough notes.",
		_reason(PromotionsManager.can_launch(pricey)))
	GameState.bank_notes = 1000
	var flyers: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "a launch takes the whole price up front",
		PromotionsManager.launch(flyers) and GameState.bank_notes == 850,
		"bank %d" % GameState.bank_notes)
	TestFixtures.check(res, "the launched campaign is stamped and named after its id",
		flyers.id == 11 and flyers.name == "Campaign 11" and flyers.day_started == today
		and flyers.per_day == 5 and flyers.total_cost == 150 and flyers.next_bill_day == -1
		and flyers.next_arrival_day == today + PromotionsManager.ARRIVAL_DAYS,
		"id %d, started %d" % [flyers.id, flyers.day_started])
	TestFixtures.check(res, "the new name is on the roll and the next id moves on",
		PromotionsManager.campaign_name(11) == "Campaign 11"
		and PromotionsManager.next_campaign_name() == "Campaign 12",
		PromotionsManager.next_campaign_name())
	TestFixtures.check(res, "a job campaign joins the Job Ads tab",
		PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 10
		and _cids(PromotionsManager.campaigns_in(CampaignData.MODE_JOB)).has(11),
		"%d job campaigns" % [PromotionsManager.campaign_count(CampaignData.MODE_JOB)])
	TestFixtures.check(res, "ending a campaign that never ran hands the whole price back",
		PromotionsManager.end(11) and GameState.bank_notes == 1000
		and PromotionsManager.campaign_of(11) == null
		and PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 9,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "a campaign cannot be ended twice and an unknown id does nothing",
		not PromotionsManager.end(11) and not PromotionsManager.end(99), "both refuse")
	TestFixtures.check(res, "a Word of Mouth promo launches on its crew pay alone",
		PromotionsManager.launch(wom) and GameState.bank_notes == 950 and wom.id == 12
		and wom.total_cost == 50 and wom.per_day == 0 and wom.next_arrival_day == -1,
		"bank %d, cost %d" % [GameState.bank_notes, wom.total_cost])
	TestFixtures.check(res, "the guild promo tab holds both promos",
		PromotionsManager.campaign_count(CampaignData.MODE_PROMO) == 2
		and _cids(PromotionsManager.campaigns_in(CampaignData.MODE_PROMO)) == [2, 12],
		"%s" % [_cids(PromotionsManager.campaigns_in(CampaignData.MODE_PROMO))])
	var far: CampaignData = _campaign(&"sponsor", CampaignData.MODE_JOB, 5)
	far.sponsor_target = "Company 1"
	var one_place: Array[int] = [2]
	far.locations = one_place
	GameState.bank_notes = 5000
	TestFixtures.check(res, "a sponsored job ad goes out on the one location it holds",
		PromotionsManager.launch(far) and far.locations == [2] and far.id == 13
		and far.total_cost == 1250, "%s at %d" % [far.locations, far.total_cost])
	var wide: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var places: Array[int] = [0, 2]
	wide.locations = places
	wide.filters[&"loc"] = []
	TestFixtures.check(res, "a launch keeps every location the type reaches and syncs the filter",
		PromotionsManager.launch(wide) and wide.locations == places
		and (wide.filters[&"loc"] as Array) == places and wide.id == 14,
		"%s against %s" % [wide.locations, wide.filters[&"loc"]])
	var many: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	many.advertise_targets = trio
	many.sponsor_index = 0
	many.sponsor_target = "Company 1, Company 3, Company 5"
	many.advertise_to = CampaignData.TO_COMPANY
	var back: CampaignData = CampaignData.from_dict(many.to_dict())
	TestFixtures.check(res, "a campaign that advertises to three companies survives the save",
		back.advertise_targets == trio and back.sponsor_index == 0
		and back.sponsor_target == many.sponsor_target
		and back.advertise_to == CampaignData.TO_COMPANY,
		"%s" % [back.advertise_targets])
	var older: CampaignData = CampaignData.from_dict({"type_key": "direct", "days": 5,
		"mode": CampaignData.MODE_PROMO, "sponsor_index": 3, "sponsor_target": "Company 4"})
	TestFixtures.check(res, "a campaign saved before the multi pick loads and still launches",
		older.advertise_targets.is_empty() and older.sponsor_index == 3
		and bool(PromotionsManager.can_launch(older)["ok"]),
		_reason(PromotionsManager.can_launch(older)))


#Case 12: the tier gates a launch has to clear.
static func _case_launch_rules(res: Dictionary) -> void:
	_fresh({"promotions": true, "adRadio": true, "adDirect": true, "adSponsor": true,
		"maxPromoDays": 25, "jobPostings": true, "guildPromo": true})
	GameState.bank_notes = 100000
	var month: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "a run past the duration cap names the cap",
		_reason(PromotionsManager.can_launch(month)) == "Promos run up to 25 days.",
		_reason(PromotionsManager.can_launch(month)))
	var forever: CampaignData = _forever(&"flyers", CampaignData.MODE_JOB)
	TestFixtures.check(res, "an Infinite run waits on the top tier of Long Promos",
		_reason(PromotionsManager.can_launch(forever)) == "Infinite promos are locked.",
		_reason(PromotionsManager.can_launch(forever)))
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	TestFixtures.check(res, "the sentinel cap opens both the Infinite run and the thirty day one",
		bool(PromotionsManager.can_launch(forever)["ok"])
		and bool(PromotionsManager.can_launch(month)["ok"]),
		_reason(PromotionsManager.can_launch(forever)))
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 10)
	var far: Array[int] = [4]
	radio.locations = far
	TestFixtures.check(res, "a type refuses a location it cannot reach, by name",
		_reason(PromotionsManager.can_launch(radio)) == "Radio cannot reach Rossade.",
		_reason(PromotionsManager.can_launch(radio)))
	var sponsor: CampaignData = _campaign(&"sponsor", CampaignData.MODE_JOB, 10)
	sponsor.sponsor_target = "Company 1"
	var two: Array[int] = [0, 2]
	sponsor.locations = two
	TestFixtures.check(res, "Sponsorship refuses a second location",
		_reason(PromotionsManager.can_launch(sponsor)) == "Sponsorship takes one location.",
		_reason(PromotionsManager.can_launch(sponsor)))
	var promo: CampaignData = _campaign(&"flyers", CampaignData.MODE_PROMO, 10)
	promo.difficulty_lo = 1.5
	TestFixtures.check(res, "a Guild Promo field the guild has not paid for has to stay put",
		_reason(PromotionsManager.can_launch(promo)) == "Minimum Difficulty is locked.",
		_reason(PromotionsManager.can_launch(promo)))
	promo.difficulty_lo = 0.5
	promo.difficulty_hi = 4.0
	TestFixtures.check(res, "the Max Difficulty handle is its own tier",
		_reason(PromotionsManager.can_launch(promo)) == "Maximum Difficulty is locked.",
		_reason(PromotionsManager.can_launch(promo)))
	promo.difficulty_hi = 5.0
	var types: Array[int] = [2]
	promo.contract_types = types
	TestFixtures.check(res, "the Contract Type section is its own tier too",
		_reason(PromotionsManager.can_launch(promo)) == "Contract Type is locked.",
		_reason(PromotionsManager.can_launch(promo)))
	var open_types: Array[int] = []
	promo.contract_types = open_types
	SubscriptionManager.set_entitlements({"guildPromo": false})
	TestFixtures.check(res, "the Guild Ads tab itself is locked until Guild Promo is held",
		_reason(PromotionsManager.can_launch(promo)) == "Guild Promotion is locked."
		and not PromotionsManager.mode_unlocked(CampaignData.MODE_PROMO,
			SubscriptionManager.entitlements()),
		_reason(PromotionsManager.can_launch(promo)))
	SubscriptionManager.set_entitlements({"guildPromo": true, "jobPostings": false})
	var job: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 10)
	TestFixtures.check(res, "the Job Ads tab is locked until Job Postings are held",
		_reason(PromotionsManager.can_launch(job)) == "Job Postings are locked."
		and bool(PromotionsManager.can_launch(promo)["ok"]),
		_reason(PromotionsManager.can_launch(job)))
	var lock: Dictionary = PromotionsManager.mode_lock(CampaignData.MODE_PROMO)
	TestFixtures.check(res, "a locked tab names the upgrade tier behind it",
		String(lock["upgrade_id"]) == "guildpromo" and int(lock["tier"]) == 1
		and int(lock["tiers"]) == 4 and String(lock["name"]) == "Guild Promo"
		and String(PromotionsManager.mode_lock(CampaignData.MODE_JOB)["upgrade_id"])
			== "promotions" and PromotionsManager.mode_lock("nope").is_empty(),
		"%s" % [lock])
	_fresh({"promotions": true, "jobPostings": true})
	GameState.bank_notes = 100000
	TestFixtures.check(res, "without the Long Promos cap no campaign goes out at all",
		_reason(PromotionsManager.can_launch(_campaign(&"flyers", CampaignData.MODE_JOB, 5)))
		== "Promos are locked.",
		_reason(PromotionsManager.can_launch(_campaign(&"flyers", CampaignData.MODE_JOB, 5))))


#Case 13: ending a campaign early and what it hands back.
static func _case_end_refund(res: Dictionary) -> void:
	_fresh()
	var t: int = GameState.day()
	GameState.bank_notes = 1000
	var preview: Dictionary = PromotionsManager.end_preview(1)
	TestFixtures.check(res, "the confirm dialog reads the unused days and the notes back",
		bool(preview["ok"]) and int(preview["refund"]) == 90 and int(preview["unused"]) == 18
		and not bool(preview["infinite"]) and not bool(preview["crew_paid"]),
		"%s" % [preview])
	TestFixtures.check(res, "ending a fixed ad hands back the days it never used",
		PromotionsManager.end(1) and GameState.bank_notes == 1090
		and PromotionsManager.campaign_of(1) == null
		and PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 8,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "an ended ad still answers to its name for the applicants it sent",
		PromotionsManager.campaign_name(1) == "Campaign 1"
		and PromotionsManager.applicant_of(20).campaign_id == 1,
		"%s" % [PromotionsManager.campaign_name(1)])
	var crew: Dictionary = PromotionsManager.end_preview(7)
	TestFixtures.check(res, "a Word of Mouth crew was already paid, so nothing comes back",
		bool(crew["ok"]) and int(crew["refund"]) == 0 and bool(crew["crew_paid"])
		and PromotionsManager.end(7) and GameState.bank_notes == 1090,
		"%s" % [crew])
	var forever: Dictionary = PromotionsManager.end_preview(3)
	TestFixtures.check(res, "ending an Infinite ad hands back the rest of the month it paid for",
		bool(forever["infinite"]) and int(forever["refund"]) == 1600
		and int(forever["unused"]) == 20 and PromotionsManager.end(3)
		and GameState.bank_notes == 2690, "%s" % [forever])
	var over: Dictionary = PromotionsManager.end_preview(8)
	TestFixtures.check(res, "an ad that already ran out cannot be ended and gives nothing",
		not bool(over["ok"]) and int(over["refund"]) == 0 and not PromotionsManager.end(8)
		and PromotionsManager.campaign_of(8) != null, "%s" % [over])
	TestFixtures.check(res, "an unknown id previews nothing",
		not bool(PromotionsManager.end_preview(99)["ok"])
		and int(PromotionsManager.end_preview(99)["refund"]) == 0, "no such campaign")
	TestFixtures.check(res, "the day the ad ran out is still the day it was told to end",
		PromotionsManager.campaign_of(8).is_concluded(t), "concluded on the seed day")


#Case 14: the monthly charge an Infinite campaign brings, and what a short bank does to it.
static func _case_infinite_billing(res: Dictionary) -> void:
	_fresh({"promotions": true, "adRadio": true, "jobPostings": true,
		"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	var today: int = GameState.day()
	GameState.bank_notes = 100000
	PromotionsManager.end(3)
	PromotionsManager.end(9)
	TestFixtures.check(res, "the seeded Infinite ads can be taken down first",
		PromotionsManager.infinite_count() == 0 and PromotionsManager.monthly_ad_bill() == 0,
		"%d left" % [PromotionsManager.infinite_count()])
	GameState.bank_notes = 10000
	var radio: CampaignData = _forever(&"radio", CampaignData.MODE_JOB)
	TestFixtures.check(res, "an Infinite launch pays for its first month up front",
		PromotionsManager.launch_cost(radio) == 2400 and PromotionsManager.launch(radio)
		and GameState.bank_notes == 7600 and radio.days == 0
		and radio.next_bill_day == today + CampaignTypeDefs.BILL_DAYS,
		"bank %d, next bill %d" % [GameState.bank_notes, radio.next_bill_day])
	var paid: Array[int] = []
	var watcher: Callable = func(id: int, amount: int) -> void:
		if id == radio.id:
			paid.append(amount)
	PromotionsManager.campaign_billed.connect(watcher)
	GameState.day_changed.emit(today + CampaignTypeDefs.BILL_DAYS - 1)
	TestFixtures.check(res, "nothing more is charged inside the month",
		paid.is_empty() and GameState.bank_notes == 7600, "%s" % [paid])
	GameState.day_changed.emit(today + CampaignTypeDefs.BILL_DAYS)
	PromotionsManager.campaign_billed.disconnect(watcher)
	TestFixtures.check(res, "the thirtieth day charges another month and moves the bill on",
		paid == [2400] and GameState.bank_notes == 5200
		and radio.next_bill_day == today + 2 * CampaignTypeDefs.BILL_DAYS,
		"bank %d, %s" % [GameState.bank_notes, paid])
	var failed: Array[Dictionary] = []
	var loss: Callable = func(id: int, name: String) -> void:
		failed.append({"id": id, "name": name})
	PromotionsManager.campaign_bill_failed.connect(loss)
	GameState.bank_notes = 100
	GameState.day_changed.emit(today + 2 * CampaignTypeDefs.BILL_DAYS)
	PromotionsManager.campaign_bill_failed.disconnect(loss)
	TestFixtures.check(res, "a bill the bank cannot cover takes the campaign down",
		failed.size() == 1 and int(failed[0]["id"]) == radio.id
		and PromotionsManager.campaign_of(radio.id) == null and GameState.bank_notes == 100,
		"%s" % [failed])
	var rows: Array[Dictionary] = PromotionsManager.billing_failures
	TestFixtures.check(res, "the missed charge is written down for the player to read",
		rows.size() == 1 and int(rows[0]["amount"]) == 2400
		and int(rows[0]["day"]) == today + 2 * CampaignTypeDefs.BILL_DAYS
		and String(rows[0]["name"]) == "Campaign 11", "%s" % [rows])


#Case 15: what the Infinite campaigns add to the Finance screen.
static func _case_finance(res: Dictionary) -> void:
	_fresh()
	var t: int = GameState.day()
	TestFixtures.check(res, "the monthly ad bill is every Infinite campaign's month",
		PromotionsManager.monthly_ad_bill() == 9900
		and PromotionsManager.infinite_count() == 2,
		"%d notes a month" % [PromotionsManager.monthly_ad_bill()])
	var rows: Array[Dictionary] = PromotionsManager.ad_bill_days(t, 30)
	TestFixtures.check(res, "the next month of charges holds one row per Infinite campaign",
		rows.size() == 2 and int(rows[0]["day"]) == t + 20 and int(rows[0]["amount"]) == 2400
		and int(rows[0]["campaign_id"]) == 3 and int(rows[1]["day"]) == t + 20
		and int(rows[1]["amount"]) == 7500 and int(rows[1]["campaign_id"]) == 9,
		"%s" % [rows])
	TestFixtures.check(res, "a window that ends before the charge is empty",
		PromotionsManager.ad_bill_days(t, 20).is_empty()
		and PromotionsManager.ad_bill_days(t, 0).is_empty(),
		"%s" % [PromotionsManager.ad_bill_days(t, 20)])
	TestFixtures.check(res, "a longer window holds the charges that follow",
		PromotionsManager.ad_bill_days(t, 60).size() == 4,
		"%d rows" % [PromotionsManager.ad_bill_days(t, 60).size()])
	PromotionsManager.end(3)
	TestFixtures.check(res, "taking an Infinite ad down takes its charge off the calendar",
		PromotionsManager.monthly_ad_bill() == 7500
		and PromotionsManager.infinite_count() == 1
		and PromotionsManager.ad_bill_days(t, 30).size() == 1,
		"%d notes a month" % [PromotionsManager.monthly_ad_bill()])


#Case 16: the View Applicants button of a job ad card.
static func _case_view_applicants(res: Dictionary) -> void:
	_fresh()
	var seen: Array[int] = []
	var watcher: Callable = func(id: int) -> void:
		seen.append(id)
	GameState.open_hiring_requested.connect(watcher)
	PromotionsManager.view_applicants(5)
	GameState.open_hiring_requested.disconnect(watcher)
	var want: Array = [5]
	TestFixtures.check(res, "View Applicants opens Hiring filtered to that campaign",
		seen == [5] and GameState.hire_filter.size() == 1
		and (GameState.hire_filter.get("from", []) as Array) == want,
		"%s" % [GameState.hire_filter])
	var taken: Dictionary = GameState.take_hire_filter()
	TestFixtures.check(res, "the screen takes the filter once and leaves nothing behind",
		(taken.get("from", []) as Array) == want and GameState.hire_filter.is_empty(),
		"%s then %s" % [taken, GameState.hire_filter])
	var via: Array[int] = [5]
	TestFixtures.check(res, "that filter names the one applicant the campaign sent",
		_sorted_ids(PromotionsManager.applicants_filtered({}, via)) == [23],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered({}, via))])


#Case 17: the Guild Opinion a hire carries and the two reasons hiring refuses.
static func _case_hire(res: Dictionary) -> void:
	_fresh()
	GameState.bank_notes = 10000
	TestFixtures.check(res, "the asking rate is worth one step of Guild Opinion",
		PromotionsManager.opinion_delta(320, 320) == 1
		and PromotionsManager.opinion_delta(320, 300) == 0, "asking +1, under it nothing")
	TestFixtures.check(res, "each margin over the asking rate is worth another step",
		PromotionsManager.opinion_delta(320, 352) == 2
		and PromotionsManager.opinion_delta(320, 400) == 3
		and PromotionsManager.opinion_delta(320, 480) == 4
		and PromotionsManager.opinion_delta(320, 640) == 5,
		"+10 gives 2, +25 gives 3, +50 gives 4, +100 gives 5")
	TestFixtures.check(res, "the steps hold for any asking rate",
		PromotionsManager.opinion_delta(260, 286) == 2
		and PromotionsManager.opinion_delta(960, 1200) == 3
		and PromotionsManager.opinion_delta(0, 500) == 0, "260, 960 and a rate of nothing")
	var seen: Array[Dictionary] = []
	var watcher: Callable = func(a: ApplicantData, salary: int, delta: int) -> void:
		seen.append({"id": a.id, "salary": salary, "delta": delta})
	PromotionsManager.applicant_hired.connect(watcher)
	var before: int = GameState.bank_notes
	var counted: int = PromotionsManager.results_of(PromotionsManager.campaign_of(1))
	TestFixtures.check(res, "a hire reports the applicant, the salary and the opinion it earns",
		PromotionsManager.hire(20, 352) and seen.size() == 1 and int(seen[0]["id"]) == 20
		and int(seen[0]["salary"]) == 352 and int(seen[0]["delta"]) == 2,
		"%s" % [seen])
	PromotionsManager.applicant_hired.disconnect(watcher)
	TestFixtures.check(res, "hiring takes no notes now and drops the applicant off the list",
		GameState.bank_notes == before and PromotionsManager.applicant_of(20) == null
		and PromotionsManager.applicants_filtered().size() == 7,
		"bank %d, %d rows" % [GameState.bank_notes,
		PromotionsManager.applicants_filtered().size()])
	TestFixtures.check(res, "the campaign still counts the merc it brought in",
		PromotionsManager.results_of(PromotionsManager.campaign_of(1)) == counted,
		"%d results" % [PromotionsManager.results_of(PromotionsManager.campaign_of(1))])
	TestFixtures.check(res, "rejecting an applicant drops them too",
		PromotionsManager.reject(21) and PromotionsManager.applicant_of(21) == null
		and PromotionsManager.applicants_filtered().size() == 6
		and not PromotionsManager.reject(21),
		"%d rows left" % [PromotionsManager.applicants_filtered().size()])
	TestFixtures.check(res, "an applicant who is gone cannot be hired",
		_reason(PromotionsManager.can_hire(20, 320)) == "No such applicant.",
		_reason(PromotionsManager.can_hire(20, 320)))
	TestFixtures.check(res, "the plan roster cap sets how many mercs may still be signed",
		PromotionsManager.max_mercs() == UpgradeDefs.ENTERPRISE_MERCS
		and PromotionsManager.free_slots()
			== UpgradeDefs.ENTERPRISE_MERCS - GameState.mercs.size(),
		"cap %d, %d free" % [PromotionsManager.max_mercs(), PromotionsManager.free_slots()])
	var seat_tier: bool = SubscriptionManager.set_tier("seats", 1)
	TestFixtures.check(res, "a Seats tier adds its mercs to the roster cap",
		seat_tier and PromotionsManager.max_mercs()
			== UpgradeDefs.ENTERPRISE_MERCS + UpgradeDefs.MERCS_PER_SEAT
		and PromotionsManager.free_slots() == UpgradeDefs.ENTERPRISE_MERCS
			+ UpgradeDefs.MERCS_PER_SEAT - GameState.mercs.size(),
		"set_tier %s, cap %d" % [seat_tier, PromotionsManager.max_mercs()])
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	TestFixtures.check(res, "a full roster refuses the hire",
		PromotionsManager.max_mercs() == UpgradeDefs.FREE_MERCS
		and PromotionsManager.free_slots() == 0
		and _reason(PromotionsManager.can_hire(22, 260)) == "No free merc slots.",
		"cap %d, %s" % [PromotionsManager.max_mercs(),
		_reason(PromotionsManager.can_hire(22, 260))])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	GameState.bank_notes = 10
	TestFixtures.check(res, "a bank that cannot cover the first month refuses the hire",
		_reason(PromotionsManager.can_hire(22, 260))
		== "Not enough notes for their first month." and not PromotionsManager.hire(22, 260),
		_reason(PromotionsManager.can_hire(22, 260)))


#Case 18: counter-offer odds, what the offer costs and the answer on the third day.
static func _case_counter(res: Dictionary) -> void:
	_fresh({"oddJobs": 3})
	var today: int = GameState.day()
	GameState.bank_notes = 1000
	var uid: int = _free_uids(res, 1, "one free merc for the counter-offer crew")[0]
	var fit: float = PromotionsManager.merc_fit(uid)
	var team: Array[int] = [uid]
	TestFixtures.check(res, "a merc's Odd Job fit is the placeholder draw off their id",
		is_equal_approx(fit, clampf(float(absi(uid * PromotionsManager.FIT_STEP
		+ PromotionsManager.FIT_SEED) % 10) / 2.0 + 0.5, 0.5, 5.0))
		and fit >= 0.5 and fit <= 5.0, "uid %d fit %.1f" % [uid, fit])
	TestFixtures.check(res, "the odds clamp at ninety-five and at five",
		PromotionsManager.counter_odds(20, 320) == 95
		and PromotionsManager.counter_odds(20, 400) == 95
		and PromotionsManager.counter_odds(20, 160) == 5
		and PromotionsManager.counter_odds(20, 0) == 5,
		"at the asking rate %d" % [PromotionsManager.counter_odds(20, 320)])
	TestFixtures.check(res, "a quarter under the asking rate halves the odds",
		PromotionsManager.counter_odds(20, 240) == 50,
		"%d" % [PromotionsManager.counter_odds(20, 240)])
	TestFixtures.check(res, "every merc sent lifts the odds by three per fit star",
		PromotionsManager.counter_odds(20, 240, team)
		== roundi(clampf(50.0 + fit * PromotionsManager.ODDS_PER_FIT, 5.0, 95.0)),
		"%d with one merc" % [PromotionsManager.counter_odds(20, 240, team)])
	TestFixtures.check(res, "an unknown applicant has no odds at all",
		PromotionsManager.counter_odds(99, 100) == 0, "no applicant, no odds")
	TestFixtures.check(res, "an offer at or over the asking rate is no counter-offer",
		_reason(PromotionsManager.can_counter(20, 320)) == "That is their asking rate or better.",
		_reason(PromotionsManager.can_counter(20, 320)))
	var crowd: Array[int] = [1, 2, 3, 4]
	TestFixtures.check(res, "the Odd Job crew cannot outrun the slots the guild holds",
		_reason(PromotionsManager.can_counter(20, 240, crowd)) == "Odd Jobs holds 3 mercs.",
		_reason(PromotionsManager.can_counter(20, 240, crowd)))
	GameState.bank_notes = 10
	TestFixtures.check(res, "the Odd Job pay has to be there before the offer goes out",
		_reason(PromotionsManager.can_counter(20, 240, team, 25))
		== "Not enough notes for Odd Job pay.",
		_reason(PromotionsManager.can_counter(20, 240, team, 25)))
	GameState.bank_notes = 1000
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	TestFixtures.check(res, "sending the offer pays the crew and marks the applicant countered",
		PromotionsManager.counter(20, 240, team, 25) and GameState.bank_notes == 975
		and applicant.status == ApplicantData.STATUS_COUNTERED
		and applicant.counter_offer == 240 and applicant.counter_day == today
		and applicant.counter_odds > 0, "bank %d, odds %d" % [GameState.bank_notes,
		applicant.counter_odds])
	TestFixtures.check(res, "an applicant waiting on an answer cannot be hired or rejected",
		_reason(PromotionsManager.can_hire(20, 240)) == "Waiting for their answer."
		and not PromotionsManager.reject(20)
		and _reason(PromotionsManager.can_counter(20, 200)) == "Waiting for their answer.",
		_reason(PromotionsManager.can_hire(20, 240)))
	GameState.day_changed.emit(today + PromotionsManager.COUNTER_DAYS - 1)
	TestFixtures.check(res, "the answer does not come early",
		applicant.status == ApplicantData.STATUS_COUNTERED, "status %s" % [applicant.status])
	var seen: Array[Dictionary] = []
	var watcher: Callable = func(id: int, accepted: bool) -> void:
		seen.append({"id": id, "accepted": accepted})
	PromotionsManager.counter_resolved.connect(watcher)
	GameState.day_changed.emit(today + PromotionsManager.COUNTER_DAYS)
	PromotionsManager.counter_resolved.disconnect(watcher)
	var signed_on: bool = applicant.status == ApplicantData.STATUS_HIRED
	TestFixtures.check(res, "the answer lands three days out and settles the applicant",
		seen.size() == 1 and int(seen[0]["id"]) == 20 and (applicant.is_open() or signed_on)
		and applicant.accepted_counter != applicant.refused_counter,
		"%s, hired %s" % [seen, signed_on])
	TestFixtures.check(res, "an accepted offer becomes their rate and a refusal leaves it alone",
		applicant.ask == (240 if applicant.accepted_counter else 320)
		and signed_on == applicant.accepted_counter,
		"accepted %s, rate %d" % [applicant.accepted_counter, applicant.ask])


#Case 19: arrivals, a campaign running out and the dots a new day leaves behind.
static func _case_day_tick(res: Dictionary) -> void:
	_fresh()
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	PromotionsManager.mark_seen()
	var job: CampaignData = PromotionsManager.campaign_of(1)
	TestFixtures.check(res, "the first job ad is due its next applicant in three days",
		job.next_arrival_day == today + PromotionsManager.ARRIVAL_DAYS,
		"due %d, today %d" % [job.next_arrival_day, today])
	var seen: Array[int] = []
	var watcher: Callable = func(a: ApplicantData) -> void:
		seen.append(a.id)
	PromotionsManager.applicant_arrived.connect(watcher)
	var due_now: int = _due_by(today)
	GameState.day_changed.emit(today)
	TestFixtures.check(res, "no applicant arrives on the day the seed was laid down",
		due_now == 0 and PromotionsManager.applicants.size() == 8 and seen.is_empty(),
		"%s" % [seen])
	var due_one: int = _due_by(today + 1)
	GameState.day_changed.emit(today + 1)
	TestFixtures.check(res, "the four ads due tomorrow each bring one merc in",
		due_one == 4 and seen == [28, 29, 30, 31]
		and PromotionsManager.applicants.size() == 12,
		"%d due, %s" % [due_one, seen])
	var fresh_one: ApplicantData = PromotionsManager.applicant_of(28)
	TestFixtures.check(res, "an arrival comes in filled out, unseen and credited to its ad",
		fresh_one != null and fresh_one.campaign_id == 4
		and fresh_one.name == "FirstName29 LastName29" and fresh_one.tradition != ""
		and fresh_one.stats.size() == ApplicantData.STAT_KEYS.size()
		and fresh_one.tools.size() == 1 and fresh_one.knowledges.size() == 1
		and fresh_one.ask >= 200 and fresh_one.ask <= 1000
		and fresh_one.ask % PromotionsManager.NEW_ASK_STEP == 0 and fresh_one.level >= 1
		and fresh_one.fit >= 0.5 and fresh_one.fit <= 5.0
		and ApplicantData.RARITIES.has(fresh_one.rarity) and fresh_one.unseen
		and PromotionsManager.has_unseen(),
		"%s asking %d" % [fresh_one.name, fresh_one.ask])
	TestFixtures.check(res, "the campaign counts the arrival among its results",
		PromotionsManager.results_of(PromotionsManager.campaign_of(4)) == 1,
		"%d results" % [PromotionsManager.results_of(PromotionsManager.campaign_of(4))])
	TestFixtures.check(res, "clearing one card's dot leaves the rest of the page alone",
		PromotionsManager.mark_applicant_seen(28) and not fresh_one.unseen
		and not PromotionsManager.mark_applicant_seen(28)
		and PromotionsManager.has_unseen(), "one dot of four cleared")
	var due_two: int = _due_by(today + 2)
	GameState.day_changed.emit(today + 2)
	TestFixtures.check(res, "the three ads due the day after bring one each",
		due_two == 3 and seen.size() == 7 and PromotionsManager.applicants.size() == 15,
		"%d due, %d applicants" % [due_two, PromotionsManager.applicants.size()])
	TestFixtures.check(res, "the two ads that ran out stop pulling",
		PromotionsManager.campaign_of(6).is_concluded(today + 2)
		and PromotionsManager.campaign_of(7).is_concluded(today + 2)
		and PromotionsManager.campaign_of(6).next_arrival_day == -1
		and PromotionsManager.campaign_of(7).next_arrival_day == -1,
		"campaigns 6 and 7 are done")
	var promo: CampaignData = PromotionsManager.campaign_of(2)
	TestFixtures.check(res, "a guild promo brings no applicants in of its own",
		promo.next_arrival_day == -1
		and PromotionsManager.results_of(promo) == 1,
		"%d through the promo" % [PromotionsManager.results_of(promo)])
	var over: CampaignData = PromotionsManager.campaign_of(8)
	var count: int = PromotionsManager.applicants.size()
	GameState.day_changed.emit(today + 9)
	PromotionsManager.applicant_arrived.disconnect(watcher)
	TestFixtures.check(res, "a day that skips ahead lands every arrival it passed",
		PromotionsManager.applicants.size() > count and over.next_arrival_day == -1,
		"%d applicants" % [PromotionsManager.applicants.size()])
	TestFixtures.check(res, "an ad that had already run out brings nothing in",
		PromotionsManager.results_of(over) == 4, "%d results" % [PromotionsManager.results_of(over)])
	TestFixtures.check(res, "a fixed ad that reaches its last day stays on the list",
		PromotionsManager.campaign_of(4) != null
		and PromotionsManager.campaign_of(4).is_concluded(today + 9),
		"campaign 4 is concluded, not gone")


#How many arrivals the campaign list owes by one day, read off the public campaign data.
static func _due_by(day_index: int) -> int:
	var count: int = 0
	for campaign: CampaignData in PromotionsManager.campaigns:
		var due: int = campaign.next_arrival_day
		if due < 0:
			continue
		var last: int = day_index
		if not campaign.infinite:
			last = mini(day_index, campaign.end_day() - 1)
		while due <= last:
			count += 1
			due += PromotionsManager.ARRIVAL_DAYS
	return count


#Case 20: the ledger row every campaign charge and refund leaves behind.
static func _case_ledger(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var ledger: MoneyLog = MoneyLog.new()
	GameState.money_logged.connect(ledger.on_money)
	var flyers: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	PromotionsManager.launch(flyers)
	TestFixtures.check(res, "a launch charge names the campaign and the method it bought",
		_row_is(ledger, "Campaign 11 - Flyers", -25, "ads"), "%s" % [ledger.rows])
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 7)
	wom.crew.assign(_free_uids(res, 2, "two free mercs for the ledger crew"))
	PromotionsManager.launch(wom)
	TestFixtures.check(res, "Word of Mouth pay rides the Odd Job reason, not the ads one",
		_row_is(ledger, "Campaign 12 - Word of Mouth", -50, GameState.REASON_ODD_JOB),
		"%s" % [_row(ledger, "Campaign 12 - Word of Mouth")])
	PromotionsManager.end(flyers.id)
	TestFixtures.check(res, "the refund of an ended ad reaches the ledger as a refund",
		_row_is(ledger, "Campaign 11 - Refund", 25, PromotionsManager.REASON_ADS),
		"%s" % [_row(ledger, "Campaign 11 - Refund")])
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	var forever: CampaignData = _forever(&"flyers", CampaignData.MODE_JOB)
	PromotionsManager.launch(forever)
	GameState.day_changed.emit(today + CampaignTypeDefs.BILL_DAYS)
	TestFixtures.check(res, "the monthly bill of an Infinite ad says which ad it is for",
		_row_is(ledger, "Campaign 13 - Monthly bill", -150, PromotionsManager.REASON_ADS),
		"%s" % [_row(ledger, "Campaign 13 - Monthly bill")])
	var team: Array[int] = _free_uids(res, 1, "one free merc for the counter-offer ledger row")
	PromotionsManager.counter(20, 240, team, 25)
	TestFixtures.check(res, "the crew sent with a counter-offer is paid under the applicant's name",
		_row_is(ledger, "FirstName21 LastName21 - Counter-offer", -25, GameState.REASON_ODD_JOB),
		"%s" % [_row(ledger, "FirstName21 LastName21 - Counter-offer")])
	var bare: int = 0
	for row: Dictionary in ledger.rows:
		if String(row["reason"]) == "" or String(row["label"]) == "":
			bare += 1
	GameState.money_logged.disconnect(ledger.on_money)
	TestFixtures.check(res, "no campaign charge reaches the ledger without a reason and a label",
		bare == 0 and ledger.rows.size() >= 5, "%d bare of %d rows" % [bare, ledger.rows.size()])


#Case 21: the operations permit a picked location needs before an ad goes out.
static func _case_permit_gate(res: Dictionary) -> void:
	_fresh(_launch_ent())
	GameState.bank_notes = 100000
	var closed: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var one: Array[int] = [1]
	closed.locations = one
	TestFixtures.check(res, "a place the guild holds no operations permit for refuses by name",
		_reason(PromotionsManager.can_launch(closed)) == "No Operations Permit in Aerdis.",
		_reason(PromotionsManager.can_launch(closed)))
	var seeded: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var pair: Array[int] = [0, 2]
	seeded.locations = pair
	TestFixtures.check(res, "the two seeded permits let an ad go out in both their places",
		bool(PromotionsManager.can_launch(seeded)["ok"]),
		_reason(PromotionsManager.can_launch(seeded)))
	SubscriptionManager.set_entitlements({"opsPermits": 1})
	var bought: bool = LegalManager.request_permit(1, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "buying the permit opens that place to the same ad",
		bought and bool(PromotionsManager.can_launch(closed)["ok"]),
		"bought %s, %s" % [bought, _reason(PromotionsManager.can_launch(closed))])
	var bare: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	TestFixtures.check(res, "an ad that picked no place at all needs no permit",
		bool(PromotionsManager.can_launch(bare)["ok"]),
		_reason(PromotionsManager.can_launch(bare)))
	SubscriptionManager.set_entitlements({"adRadio": true})
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 5)
	var buern: Array[int] = [0]
	radio.locations = buern
	TestFixtures.check(res, "a place the type cannot reach is refused before the permit is read",
		_reason(PromotionsManager.can_launch(radio)) == "Radio cannot reach Buern.",
		_reason(PromotionsManager.can_launch(radio)))


#Case 22: the away rows a Word of Mouth crew and a counter-offer crew leave in GameState.
static func _case_away_rows(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the away row crews")
	var one: int = pair[0]
	var two: int = pair[1]
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([one, two])
	var day: int = CampaignClock.MINUTES_PER_DAY
	TestFixtures.check(res, "a Word of Mouth crew goes out on the Odd Job status until it ends",
		PromotionsManager.launch(wom) and GameState.is_away(one) and GameState.is_away(two)
		and GameState.away_status(one) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(one) == wom.end_day() * day
		and GameState.away_until(two) == wom.end_day() * day,
		"status %d until %d" % [GameState.away_status(one), GameState.away_until(one)])
	TestFixtures.check(res, "ending the campaign brings that crew home",
		PromotionsManager.end(wom.id) and not GameState.is_away(one)
		and not GameState.is_away(two), "%s and %s" % [GameState.is_away(one),
		GameState.is_away(two)])
	var short_run: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 2)
	short_run.crew.assign([one])
	PromotionsManager.launch(short_run)
	GameState.day_changed.emit(today + 2)
	TestFixtures.check(res, "a crew comes home on its own when the campaign runs out",
		short_run.is_concluded(today + 2) and not GameState.is_away(one),
		"concluded %s, away %s" % [short_run.is_concluded(today + 2), GameState.is_away(one)])
	var team: Array[int] = [one]
	PromotionsManager.counter(20, 240, team, 25)
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	TestFixtures.check(res, "the crew of a counter-offer is away until the answer day",
		GameState.is_away(one) and applicant.counter_team == team
		and GameState.away_until(one) == (applicant.counter_day
			+ PromotionsManager.COUNTER_DAYS) * day,
		"until %d" % [GameState.away_until(one)])
	applicant.counter_odds = 0
	GameState.day_changed.emit(today + PromotionsManager.COUNTER_DAYS)
	TestFixtures.check(res, "the answer brings that crew home and clears the row",
		not GameState.is_away(one) and applicant.counter_team.is_empty()
		and applicant.refused_counter, "away %s" % [GameState.is_away(one)])
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	var forever: CampaignData = _forever(&"wom", CampaignData.MODE_PROMO)
	forever.crew.assign([two])
	TestFixtures.check(res, "an Infinite Word of Mouth crew has no return day at all",
		PromotionsManager.launch(forever) and GameState.is_away(two)
		and GameState.away_until(two) == -1, "until %d" % [GameState.away_until(two)])
	PromotionsManager.end(forever.id)
	var ghost: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 3)
	var nobody: int = 99999
	ghost.crew.assign([nobody])
	TestFixtures.check(res, "a crew uid the roster does not hold never reaches the registry",
		PromotionsManager.launch(ghost) and not GameState.is_away(nobody)
		and GameState.merc_by_uid(nobody) == null, "away %s" % [GameState.is_away(nobody)])
	var last: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 3)
	last.crew.assign([one, two])
	PromotionsManager.launch(last)
	var both_out: bool = GameState.is_away(one) and GameState.is_away(two)
	PromotionsManager.reset()
	TestFixtures.check(res, "a reset takes back every away row this manager put up",
		both_out and not GameState.is_away(one) and not GameState.is_away(two),
		"out %s, back %s" % [both_out, not GameState.is_away(one)])


#Case 23: the merc a hire signs on.
static func _case_hired_merc(res: Dictionary) -> void:
	_fresh()
	GameState.bank_notes = 10000
	var before: int = GameState.mercs.size()
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	var want_name: String = applicant.name
	var want_level: int = applicant.level
	var want_tradition: String = applicant.tradition
	var delta: int = PromotionsManager.opinion_delta(applicant.ask, 400)
	var beats: Array[int] = []
	var beat_watcher: Callable = func() -> void:
		beats.append(1)
	GameState.roster_changed.connect(beat_watcher)
	TestFixtures.check(res, "a hire signs one merc on and says which uid it was",
		PromotionsManager.hire(20, 400) and GameState.mercs.size() == before + 1
		and PromotionsManager.last_hired_uid > 0
		and GameState.merc_by_uid(PromotionsManager.last_hired_uid) != null,
		"roster %d, uid %d" % [GameState.mercs.size(), PromotionsManager.last_hired_uid])
	GameState.roster_changed.disconnect(beat_watcher)
	TestFixtures.check(res, "the hire says the roster changed again once the wage was written",
		beats.size() >= 2, "%d roster signals" % [beats.size()])
	var merc: MercenaryData = GameState.merc_by_uid(PromotionsManager.last_hired_uid)
	TestFixtures.check(res, "the new merc carries the applicant's name and level",
		merc.merc_name == want_name and int(merc.stats.get("level", 0)) == want_level,
		"%s at level %d" % [merc.merc_name, int(merc.stats.get("level", 0))])
	TestFixtures.check(res, "the new merc keeps the tradition the applicant applied with",
		merc.tradition != null and merc.tradition.tradition_name == want_tradition,
		"%s wanted %s" % [merc.tradition.tradition_name if merc.tradition != null else "none",
		want_tradition])
	TestFixtures.check(res, "the agreed salary is the wage the merc signs on at",
		merc.monthly_salary == 400 and delta == 3,
		"%d notes, delta %d" % [merc.monthly_salary, delta])
	var wile: int = roundi(float(merc.stats.get("wile", 0.0)))
	TestFixtures.check(res, "the opinion the hire earned sits on top of their opening opinion",
		merc.guild_opinion == clampi(SalarySystem.OPINION_BASE + wile + delta,
			SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX),
		"opinion %d, wile %d" % [merc.guild_opinion, wile])
	var view: MercView = null
	for row: MercView in GameState.roster:
		if row.uid == PromotionsManager.last_hired_uid:
			view = row
	TestFixtures.check(res, "the roster view of the new merc holds the agreed wage and opinion",
		view != null and delta != 0 and view.monthly_salary == 400
		and view.guild_opinion == merc.guild_opinion,
		"none" if view == null else "%d notes, opinion %d against %d" % [view.monthly_salary,
		view.guild_opinion, merc.guild_opinion])
	TestFixtures.check(res, "hiring still takes no notes and leaves the applicant list shorter",
		GameState.bank_notes == 10000 and PromotionsManager.applicant_of(20) == null,
		"bank %d" % [GameState.bank_notes])


#Case 24: what an accepted counter-offer does, with a free merc slot and without one.
static func _case_counter_hire(res: Dictionary) -> void:
	_fresh({"oddJobs": 2})
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var hires: Array[Dictionary] = []
	var hire_watcher: Callable = func(a: ApplicantData, salary: int, delta: int) -> void:
		hires.append({"id": a.id, "salary": salary, "delta": delta})
	var answers: Array[Dictionary] = []
	var answer_watcher: Callable = func(id: int, accepted: bool) -> void:
		answers.append({"id": id, "accepted": accepted})
	PromotionsManager.applicant_hired.connect(hire_watcher)
	PromotionsManager.counter_resolved.connect(answer_watcher)
	PromotionsManager.counter(20, 240)
	var first: ApplicantData = PromotionsManager.applicant_of(20)
	first.counter_odds = 100
	var before: int = GameState.mercs.size()
	GameState.day_changed.emit(today + PromotionsManager.COUNTER_DAYS)
	TestFixtures.check(res, "an accepted counter-offer signs the merc on at the offer",
		answers.size() == 1 and bool(answers[0]["accepted"]) and hires.size() == 1
		and int(hires[0]["salary"]) == 240 and GameState.mercs.size() == before + 1,
		"%s and %s" % [answers, hires])
	TestFixtures.check(res, "a counter-offer hire earns no step of Guild Opinion",
		int(hires[0]["delta"]) == 0
		and GameState.merc_by_uid(PromotionsManager.last_hired_uid).monthly_salary == 240,
		"delta %d" % [int(hires[0]["delta"])])
	TestFixtures.check(res, "the applicant who accepted is hired and off the list",
		first.status == ApplicantData.STATUS_HIRED and first.accepted_counter
		and PromotionsManager.applicant_of(20) == null, "status %s" % [first.status])
	PromotionsManager.counter(21, 200)
	PromotionsManager.counter(22, 180)
	var second: ApplicantData = PromotionsManager.applicant_of(21)
	var third: ApplicantData = PromotionsManager.applicant_of(22)
	second.counter_odds = 100
	third.counter_odds = 0
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	var roster: int = GameState.mercs.size()
	GameState.day_changed.emit(today + PromotionsManager.COUNTER_DAYS)
	PromotionsManager.applicant_hired.disconnect(hire_watcher)
	PromotionsManager.counter_resolved.disconnect(answer_watcher)
	TestFixtures.check(res, "an accepted offer with no free slot leaves them open at the offer",
		second.is_open() and second.accepted_counter and second.ask == 200
		and PromotionsManager.free_slots() == 0 and GameState.mercs.size() == roster
		and hires.size() == 1, "status %s at %d" % [second.status, second.ask])
	TestFixtures.check(res, "a refused offer leaves their asking rate where it was",
		third.is_open() and third.refused_counter and not third.accepted_counter
		and third.ask == PromotionsManager.SEED_ASKS[2]
		and PromotionsManager.applicant_of(22) != null, "rate %d" % [third.ask])
	TestFixtures.check(res, "each answer was reported once, accepted or refused",
		answers.size() == 3 and int(answers[1]["id"]) == 21 and bool(answers[1]["accepted"])
		and int(answers[2]["id"]) == 22 and not bool(answers[2]["accepted"]),
		"%s" % [answers])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})


#Case 25: the Odd Job rows this manager owns go back up when something else clears them, and stay
#down once the campaign that wrote them is over.
static func _case_restore_holds(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the restored rows")
	var one: int = pair[0]
	var two: int = pair[1]
	var day: int = CampaignClock.MINUTES_PER_DAY
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([one])
	var sent: bool = PromotionsManager.launch(wom)
	GameState.clear_away(one)
	TestFixtures.check(res, "a cleared row of a running campaign crew goes back up",
		sent and GameState.away_status(one) == GuiTypes.MercStatus.ODD_JOB
		and GameState.busy_uids().has(one)
		and GameState.away_until(one) == wom.end_day() * day,
		"status %d until %d" % [GameState.away_status(one), GameState.away_until(one)])
	var team: Array[int] = [two]
	var offered: bool = PromotionsManager.counter(20, 240, team, 25)
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	GameState.clear_away(two)
	TestFixtures.check(res, "a cleared row of a counter-offer crew goes back up to the answer day",
		offered and GameState.away_status(two) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(two) == (applicant.counter_day
			+ PromotionsManager.COUNTER_DAYS) * day,
		"status %d until %d" % [GameState.away_status(two), GameState.away_until(two)])
	var moved: Array[int] = []
	var watcher: Callable = func(who: int) -> void:
		moved.append(who)
	GameState.away_changed.connect(watcher)
	GameState.roster_changed.emit()
	GameState.away_changed.disconnect(watcher)
	TestFixtures.check(res, "a roster signal with every row standing moves nothing",
		moved.is_empty(), "%s" % [moved])
	var ended: bool = PromotionsManager.end(wom.id)
	GameState.roster_changed.emit()
	TestFixtures.check(res, "the crew of an ended campaign is never held again",
		ended and GameState.away_status(one) == -1 and not GameState.busy_uids().has(one),
		"status %d" % [GameState.away_status(one)])
	var short_run: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 2)
	short_run.crew.assign([one])
	PromotionsManager.launch(short_run)
	GameState.day_changed.emit(today + 2)
	GameState.roster_changed.emit()
	TestFixtures.check(res, "the crew of a run that ran out is never held again",
		short_run.is_concluded(today + 2) and GameState.away_status(one) == -1,
		"status %d" % [GameState.away_status(one)])


#Case 25b: a campaign that ends on the same day tick a counter-offer is accepted must not have
#its crew held again by the roster signal the hire fires from inside that same tick.
static func _case_tick_restore(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the tick restore case")
	var ended_uid: int = pair[0]
	var running_uid: int = pair[1]
	var ended: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO,
		PromotionsManager.COUNTER_DAYS)
	ended.crew.assign([ended_uid])
	var running: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO,
		PromotionsManager.COUNTER_DAYS * 4)
	running.crew.assign([running_uid])
	var launched_ended: bool = PromotionsManager.launch(ended)
	var launched_running: bool = PromotionsManager.launch(running)
	var offered: bool = PromotionsManager.counter(20, 240)
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	applicant.counter_odds = 100
	var target_day: int = today + PromotionsManager.COUNTER_DAYS
	TestFixtures.check(res, "the tick restore fixture closes the campaign the day the offer lands",
		launched_ended and launched_running and offered and ended.end_day() == target_day
		and not running.is_concluded(target_day)
		and applicant.counter_day + PromotionsManager.COUNTER_DAYS == target_day,
		"end %d, target %d" % [ended.end_day(), target_day])
	var before: int = GameState.mercs.size()
	GameState.day_changed.emit(target_day)
	TestFixtures.check(res, "the counter-offer hire still lands from inside the day tick",
		GameState.mercs.size() == before + 1 and applicant.status == ApplicantData.STATUS_HIRED,
		"roster %d, status %s" % [GameState.mercs.size(), applicant.status])
	TestFixtures.check(res, "the crew of the campaign that ended this tick is never held again",
		GameState.away_status(ended_uid) == -1,
		"status %d" % [GameState.away_status(ended_uid)])
	TestFixtures.check(res, "the crew of the campaign still running stays held",
		GameState.away_status(running_uid) == GuiTypes.MercStatus.ODD_JOB,
		"status %d" % [GameState.away_status(running_uid)])


#Case 26: a merc the guild cannot send out is refused a crew seat, and a hold another manager
#wrote over an Odd Job row is left where it is.
static func _case_busy_crew(res: Dictionary) -> void:
	_fresh(_launch_ent())
	GameState.bank_notes = 200000
	var bank: int = GameState.bank_notes
	var free: Array[int] = _free_uids(res, 3, "three free mercs for the busy crew case")
	var held: int = free[0]
	GameState.set_away(held, GuiTypes.MercStatus.CAPTURED, -1)
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([held])
	TestFixtures.check(res, "a campaign crew the guild cannot send refuses the launch",
		_reason(PromotionsManager.can_launch(wom)) == PromotionsManager.CREW_BUSY_TEXT
		and not PromotionsManager.launch(wom)
		and GameState.away_status(held) == GuiTypes.MercStatus.CAPTURED
		and GameState.bank_notes == bank,
		"%s at %d" % [_reason(PromotionsManager.can_launch(wom)),
		GameState.away_status(held)])
	var team: Array[int] = [held]
	TestFixtures.check(res, "a counter-offer crew the guild cannot send refuses the offer",
		_reason(PromotionsManager.can_counter(20, 240, team, 25))
		== PromotionsManager.CREW_BUSY_TEXT
		and not PromotionsManager.counter(20, 240, team, 25)
		and GameState.bank_notes == bank,
		_reason(PromotionsManager.can_counter(20, 240, team, 25)))
	GameState.clear_away(held)
	var taken: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	taken.crew.assign([free[1]])
	var sent: bool = PromotionsManager.launch(taken)
	GameState.set_away(free[1], GuiTypes.MercStatus.CAPTURED, -1)
	TestFixtures.check(res, "an Odd Job row another manager wrote over is left where it is",
		sent and PromotionsManager.end(taken.id)
		and GameState.away_status(free[1]) == GuiTypes.MercStatus.CAPTURED,
		"status %d" % [GameState.away_status(free[1])])
	GameState.clear_away(free[1])
	var merc: MercenaryData = GameState.merc_by_uid(free[2])
	merc.on_contract = true
	var busy: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	busy.crew.assign([free[2]])
	var refused: String = _reason(PromotionsManager.can_launch(busy))
	var no_launch: bool = not PromotionsManager.launch(busy)
	merc.on_contract = false
	TestFixtures.check(res, "a merc out on a contract is refused a crew seat the same way",
		refused == PromotionsManager.CREW_BUSY_TEXT and no_launch, refused)


#The one money row that carries this label, or an empty dictionary when none does.
static func _row(ledger: MoneyLog, label: String) -> Dictionary:
	for row: Dictionary in ledger.rows:
		if String(row["label"]) == label:
			return row
	return {}


static func _row_is(ledger: MoneyLog, label: String, delta: int, reason: String) -> bool:
	var row: Dictionary = _row(ledger, label)
	if row.is_empty():
		return false
	return int(row["delta"]) == delta and String(row["reason"]) == reason


#Catches the ledger rows GameState hands out while a case runs.
class MoneyLog extends RefCounted:
	var rows: Array[Dictionary] = []

	func on_money(delta: int, reason: String, label: String) -> void:
		rows.append({"delta": delta, "reason": reason, "label": label})

class_name GuiPlanTests
extends RefCounted

#The subscription model: the upgrade table, the derived entitlement keys, the money and day
#helpers on GameState, the coached level-up modes and the shared pulse clock. No scene is built
#here; every case drives the autoloads straight.

#Every key entitlements() must carry, in the handoff's spelling.
const EXPECTED_KEYS: Array[String] = ["plan", "metrics", "contract_metrics", "merc_metrics",
	"guild_opinion", "client_opinion", "peer", "fastmetrics", "pip", "lvSupport", "lvDefensive",
	"lvOffensive", "lvExisting", "lvNewSkills", "lvUniversal", "lvAncestral", "lvTradition",
	"lvSpell", "oddJobs", "bazaar", "bazaarRarity", "bazaarSpeed", "opsPermits", "teleport",
	"representation", "counsel", "counselPct", "whoKnows", "promotions", "hiringDiscrim",
	"discrim", "background", "criminal", "education", "skilltest", "aptitude", "brawn",
	"readiness", "personality", "seats", "contracts", "adDirect", "adRadio", "adSponsor",
	"jobPostings", "maxPromoDays", "adBoost", "guildPromo", "gpMinDifficulty", "gpMaxDifficulty",
	"gpContractType", "perMerc", "maxMercs", "maxContracts", "ancestry", "bloodline", "age",
	"heritage", "perks", "drawbacks", "skills", "lifepath", "criminality", "contractMetrics",
	"mercMetrics", "guildOpinion", "clientOpinion", "relationships", "physical", "cognition",
	"vigor", "dexterity", "wile", "tools", "knowledges", "surveyRefresh", "predictive",
	"veryFast"]
#Keys the plan alone decides, so a paid plan that bought no upgrade still reads them.
const PLAN_DERIVED_KEYS: Array[String] = ["plan", "metrics", "physical", "veryFast", "perMerc",
	"maxMercs", "maxContracts"]
#The prototype keys an upgrade tier buys; every one of them is closed until Enterprise buys it.
const PROTO_UPGRADE_KEYS: Array[String] = ["ancestry", "bloodline", "age", "heritage", "perks",
	"drawbacks", "skills", "lifepath", "criminality", "contractMetrics", "mercMetrics",
	"guildOpinion", "clientOpinion", "relationships", "cognition", "vigor", "dexterity", "wile",
	"tools", "knowledges", "predictive"]
#The prototype spelling of a key wave 1 already carries; both must always read the same.
const ALIAS_KEYS: Dictionary = {
	"contractMetrics": "contract_metrics",
	"mercMetrics": "merc_metrics",
	"guildOpinion": "guild_opinion",
	"clientOpinion": "client_opinion",
	"relationships": "peer",
	"criminality": "criminal",
	"tools": "skilltest",
	"knowledges": "education",
	"cognition": "aptitude",
	"vigor": "brawn",
	"dexterity": "readiness",
	"wile": "personality",
}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	await _case_table(res, host)
	await _case_requirements(res, host)
	await _case_default_state(res, host)
	await _case_downgrade(res, host)
	await _case_set_tier(res, host)
	await _case_derived_keys(res, host)
	await _case_overrides(res, host)
	await _case_pair_spellings(res, host)
	await _case_costs(res, host)
	await _case_caps(res, host)
	await _case_money(res, host)
	await _case_pip(res, host)
	await _case_pip_defs(res, host)
	await _case_pulse(res, host)
	await _case_promo_table(res, host)
	await _case_promo_keys(res, host)
	await _case_promo_costs(res, host)
	await _case_hiring_handoff(res, host)
	await _case_proto_keys(res, host)
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI PLAN")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


#Case 1: the ported table holds together, prices add up and categories answer for their members.
static func _case_table(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var bad: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		var data: Dictionary = UpgradeDefs.of(id)
		if data.is_empty():
			bad.append("%s is not in the table" % id)
			continue
		var monthly: Array = data["monthly"] as Array
		var tiers: Array = data["tiers"] as Array
		if monthly.size() != tiers.size() or UpgradeDefs.tier_count(id) != tiers.size():
			bad.append("%s has %d prices for %d tiers" % [id, monthly.size(), tiers.size()])
		var req: Dictionary = UpgradeDefs.req_of(id)
		var ids: Array = req.get("ids", []) as Array
		if req.is_empty() != ids.is_empty():
			bad.append("%s has a half written requirement" % id)
		for other: String in ids:
			if not UpgradeDefs.has_id(other):
				bad.append("%s requires the unknown %s" % [id, other])
		if UpgradeDefs.category_of(id) == "":
			bad.append("%s has no category" % id)
	TestFixtures.check(res, "every upgrade row is whole", bad.is_empty(),
		TestFixtures.detail(bad, UpgradeDefs.ORDER.size(), "upgrades"))
	var missing: Array[String] = []
	for key: Variant in UpgradeDefs.UPGRADES:
		if not UpgradeDefs.ORDER.has(String(key)):
			missing.append(String(key))
	TestFixtures.check(res, "ORDER lists the whole table once",
		missing.is_empty() and UpgradeDefs.ORDER.size() == UpgradeDefs.UPGRADES.size(),
		"%d ids for %d rows, missing %s" % [UpgradeDefs.ORDER.size(),
			UpgradeDefs.UPGRADES.size(), str(missing)])
	TestFixtures.check(res, "monthly_of sums the tiers up to the one owned",
		UpgradeDefs.monthly_of("seats", 0) == 0 and UpgradeDefs.monthly_of("seats", 3) == 21
			and UpgradeDefs.monthly_of("seats", 99) == 189,
		"got %d, %d, %d" % [UpgradeDefs.monthly_of("seats", 0), UpgradeDefs.monthly_of("seats", 3),
			UpgradeDefs.monthly_of("seats", 99)])
	TestFixtures.check(res, "a second category counts as membership",
		UpgradeDefs.in_category("criminal", "insights")
			and UpgradeDefs.in_category("criminal", "lessLegal")
			and UpgradeDefs.in_category("discrim", "lessLegal")
			and UpgradeDefs.in_category("discrim", "insights")
			and not UpgradeDefs.in_category("seats", "insights"),
		"criminal in %s, discrim in %s" % [UpgradeDefs.category_of("criminal"),
			UpgradeDefs.category_of("discrim")])
	TestFixtures.check(res, "a category lists its members in table order",
		UpgradeDefs.ids_in_category("bazaarCat") == ["bazaar", "betteritems", "fasteritems"]
			and UpgradeDefs.ids_in_category("metricsCat") == ["survey", "peer", "customer",
				"fastmetrics"],
		"bazaarCat %s, metricsCat %s" % [str(UpgradeDefs.ids_in_category("bazaarCat")),
			str(UpgradeDefs.ids_in_category("metricsCat"))])
	TestFixtures.check(res, "a multi source upgrade bills to one category",
		UpgradeDefs.bill_category("counsel") == "legalCat"
			and UpgradeDefs.bill_category("criminal") == "insights"
			and UpgradeDefs.bill_category("education") == "testing"
			and UpgradeDefs.bill_category("seats") == "limits",
		"counsel %s, criminal %s, education %s" % [UpgradeDefs.bill_category("counsel"),
			UpgradeDefs.bill_category("criminal"), UpgradeDefs.bill_category("education")])


#Case 2: a requirement adds the tiers of every upgrade it names.
static func _case_requirements(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	TestFixtures.check(res, "an upgrade with no requirement is always buyable",
		UpgradeDefs.requirement_met("seats", {}) and UpgradeDefs.requirement_need("seats") == 0,
		"need %d" % UpgradeDefs.requirement_need("seats"))
	var short: Dictionary = {"discrim": 4, "background": 1}
	var enough: Dictionary = {"discrim": 4, "background": 2}
	TestFixtures.check(res, "the criminal check needs six tiers across two upgrades",
		UpgradeDefs.requirement_need("criminal") == 6
			and UpgradeDefs.requirement_have("criminal", short) == 5
			and not UpgradeDefs.requirement_met("criminal", short)
			and UpgradeDefs.requirement_met("criminal", enough),
		"need %d, short %d" % [UpgradeDefs.requirement_need("criminal"),
			UpgradeDefs.requirement_have("criminal", short)])
	TestFixtures.check(res, "a single source requirement reads the same way",
		not UpgradeDefs.requirement_met("combatpip", {})
			and UpgradeDefs.requirement_met("combatpip", {"pip": 1}),
		"have %d of %d" % [UpgradeDefs.requirement_have("combatpip", {"pip": 1}),
			UpgradeDefs.requirement_need("combatpip")])
	TestFixtures.check(res, "dependants point back at what they need",
		UpgradeDefs.dependants_of("pip") == ["combatpip", "skillpip"]
			and UpgradeDefs.dependants_of("bazaar") == ["betteritems", "fasteritems"],
		"pip %s" % str(UpgradeDefs.dependants_of("pip")))


#Case 3: the dev default every screen is reviewed on.
static func _case_default_state(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.reset()
	var bad: Array[String] = []
	for id: String in UpgradeDefs.ORDER:
		if SubscriptionManager.tier_of(id) != UpgradeDefs.tier_count(id):
			bad.append("%s at %d of %d" % [id, SubscriptionManager.tier_of(id),
				UpgradeDefs.tier_count(id)])
	TestFixtures.check(res, "a reset buys every upgrade to its top tier",
		bad.is_empty() and SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE,
		TestFixtures.detail(bad, UpgradeDefs.ORDER.size(), "upgrades"))
	var ent: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "the default still pays for the five metrics keys",
		bool(ent["metrics"]) and bool(ent["contract_metrics"]) and int(ent["merc_metrics"]) == 3
			and bool(ent["guild_opinion"]) and bool(ent["client_opinion"])
			and SubscriptionManager.merc_slots() == 3,
		"metrics %s, slots %d" % [ent["metrics"], SubscriptionManager.merc_slots()])
	var missing: Array[String] = []
	for key: String in EXPECTED_KEYS:
		if not ent.has(key):
			missing.append(key)
	TestFixtures.check(res, "entitlements carry every handoff key", missing.is_empty(),
		TestFixtures.detail(missing, EXPECTED_KEYS.size(), "keys"))
	TestFixtures.check(res, "the plan name and key read off the plan",
		String(ent["plan"]) == "enterprise"
			and SubscriptionManager.plan_name() == "Mercday Enterprise"
			and SubscriptionManager.plan_name(SubscriptionManager.Plan.FREE) == "Mercday Free",
		"plan %s as %s" % [ent["plan"], SubscriptionManager.plan_name()])


#Case 4: dropping the plan drops every upgrade with it.
static func _case_downgrade(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.reset()
	SubscriptionManager.set_plan(SubscriptionManager.Plan.PRO)
	var ent: Dictionary = SubscriptionManager.entitlements()
	var leaks: Array[String] = []
	for key: String in EXPECTED_KEYS:
		if PLAN_DERIVED_KEYS.has(key):
			continue
		var value: Variant = ent[key]
		if (value is bool and bool(value)) or (value is int and int(value) != 0):
			leaks.append(key)
	TestFixtures.check(res, "Pro holds the guild metrics and nothing an upgrade bought",
		leaks.is_empty() and bool(ent["metrics"]) and String(ent["plan"]) == "pro"
			and SubscriptionManager.tiers().is_empty(),
		TestFixtures.detail(leaks, EXPECTED_KEYS.size(), "keys"))
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	var free: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "Free holds no metrics at all",
		not bool(free["metrics"]) and not bool(free["promotions"])
			and String(free["plan"]) == "free",
		"metrics %s, plan %s" % [free["metrics"], free["plan"]])
	SubscriptionManager.set_plan(SubscriptionManager.Plan.ENTERPRISE)
	TestFixtures.check(res, "coming back up buys nothing back",
		SubscriptionManager.tiers().is_empty()
			and not bool(SubscriptionManager.entitlements()["pip"]),
		"tiers %s" % str(SubscriptionManager.tiers()))
	SubscriptionManager.reset()


#Case 5: what set_tier refuses.
static func _case_set_tier(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	TestFixtures.check(res, "a tier with an unmet requirement is refused",
		not SubscriptionManager.can_buy("combatpip", 1)
			and not SubscriptionManager.set_tier("combatpip", 1)
			and SubscriptionManager.tier_of("combatpip") == 0,
		"combatpip at %d" % SubscriptionManager.tier_of("combatpip"))
	TestFixtures.check(res, "an unknown id and a tier above the top are refused",
		not SubscriptionManager.set_tier("nonsense", 1)
			and not SubscriptionManager.set_tier("pip", 2)
			and SubscriptionManager.max_tier("pip") == 1,
		"pip tops out at %d" % SubscriptionManager.max_tier("pip"))
	TestFixtures.check(res, "buying the requirement first opens the tier",
		SubscriptionManager.set_tier("pip", 1) and SubscriptionManager.set_tier("combatpip", 2)
			and SubscriptionManager.tier_of("combatpip") == 2,
		"combatpip at %d" % SubscriptionManager.tier_of("combatpip"))
	SubscriptionManager.set_tier("pip", 0)
	TestFixtures.check(res, "lowering a requirement leaves what was bought on top standing",
		SubscriptionManager.tier_of("combatpip") == 2
			and not SubscriptionManager.can_buy("combatpip", 3),
		"combatpip at %d, pip at %d" % [SubscriptionManager.tier_of("combatpip"),
			SubscriptionManager.tier_of("pip")])
	SubscriptionManager.set_plan(SubscriptionManager.Plan.PRO)
	TestFixtures.check(res, "nothing is for sale below Enterprise",
		not SubscriptionManager.can_buy("seats", 1) and not SubscriptionManager.set_tier("seats", 1),
		"seats at %d" % SubscriptionManager.tier_of("seats"))
	SubscriptionManager.reset()


#Case 6: every derived key against a hand written state.
static func _case_derived_keys(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"combatpip": 2, "skillpip": 4, "magicpip": 1, "pip": 1, "oddjobs": 2, "bazaar": 1,
		"betteritems": 3, "fasteritems": 5, "opspermit": 3, "teleport": 1, "representation": 2,
		"counsel": 4, "whoknows": 7, "discrim": 3, "background": 5, "criminal": 1, "education": 1,
		"skilltest": 1, "aptitude": 1, "brawn": 0, "readiness": 1, "personality": 0, "seats": 2,
		"contracts": 3, "contractmetrics": 1, "mercmetrics": 2, "survey": 1, "peer": 1,
		"customer": 0, "fastmetrics": 3})
	var ent: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "the combat modes unlock one tier at a time",
		bool(ent["lvSupport"]) and bool(ent["lvDefensive"]) and not bool(ent["lvOffensive"]),
		"support %s, defensive %s, offensive %s" % [ent["lvSupport"], ent["lvDefensive"],
			ent["lvOffensive"]])
	TestFixtures.check(res, "the skill modes unlock one tier at a time",
		bool(ent["lvExisting"]) and bool(ent["lvNewSkills"]) and bool(ent["lvUniversal"])
			and bool(ent["lvAncestral"]) and not bool(ent["lvTradition"])
			and bool(ent["lvSpell"]) and bool(ent["pip"]),
		"universal %s, ancestral %s, tradition %s" % [ent["lvUniversal"], ent["lvAncestral"],
			ent["lvTradition"]])
	TestFixtures.check(res, "the bazaar keys read their own tiers",
		bool(ent["bazaar"]) and int(ent["bazaarRarity"]) == 3 and int(ent["bazaarSpeed"]) == 5
			and int(ent["oddJobs"]) == 2,
		"rarity %d, speed %d, odd jobs %d" % [ent["bazaarRarity"], ent["bazaarSpeed"],
			ent["oddJobs"]])
	TestFixtures.check(res, "the legal keys read their own tiers",
		int(ent["opsPermits"]) == 3 and int(ent["teleport"]) == 1
			and int(ent["representation"]) == 2 and int(ent["counsel"]) == 4
			and int(ent["whoKnows"]) == 7,
		"permits %d, counsel %d, who knows %d" % [ent["opsPermits"], ent["counsel"],
			ent["whoKnows"]])
	TestFixtures.check(res, "the insight keys split their tiers from their flags",
		int(ent["discrim"]) == 3 and not bool(ent["hiringDiscrim"]) and int(ent["background"]) == 5
			and bool(ent["criminal"]) and bool(ent["education"]) and bool(ent["skilltest"])
			and bool(ent["aptitude"]) and not bool(ent["brawn"]) and bool(ent["readiness"])
			and not bool(ent["personality"]),
		"discrim %d, hiring %s, brawn %s" % [ent["discrim"], ent["hiringDiscrim"], ent["brawn"]])
	TestFixtures.check(res, "the metrics keys read their own tiers",
		bool(ent["metrics"]) and bool(ent["contract_metrics"]) and int(ent["merc_metrics"]) == 2
			and bool(ent["guild_opinion"]) and not bool(ent["client_opinion"])
			and bool(ent["peer"]) and int(ent["fastmetrics"]) == 3,
		"merc metrics %d, client %s" % [ent["merc_metrics"], ent["client_opinion"]])
	TestFixtures.check(res, "the caps and the advertising keys read their own tiers",
		int(ent["seats"]) == 2 and int(ent["contracts"]) == 3 and not bool(ent["promotions"])
			and not bool(ent["jobPostings"]) and int(ent["maxPromoDays"]) == 0
			and int(ent["adBoost"]) == 0 and not bool(ent["adDirect"])
			and not bool(ent["adRadio"]) and not bool(ent["adSponsor"]),
		"seats %d, contracts %d" % [ent["seats"], ent["contracts"]])
	var pct: Array[int] = []
	for tier: int in range(6):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"counsel": tier})
		pct.append(int(SubscriptionManager.entitlements()["counselPct"]))
	TestFixtures.check(res, "the counsel bonus follows its own table",
		pct == [0, 5, 7, 9, 13, 15], "got %s" % str(pct))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"discrim": 4})
	TestFixtures.check(res, "the fourth discrimination tier opens hiring discrimination",
		bool(SubscriptionManager.entitlements()["hiringDiscrim"]),
		"hiring %s" % SubscriptionManager.entitlements()["hiringDiscrim"])
	SubscriptionManager.reset()


#Case 7: the override layer sits on top of the derived keys until a reset.
static func _case_overrides(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.reset()
	SubscriptionManager.set_entitlements({"bazaar": false, "bazaarRarity": 1, "merc_metrics": 1})
	var ent: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "an override wins over the derived key",
		not bool(ent["bazaar"]) and int(ent["bazaarRarity"]) == 1
			and SubscriptionManager.merc_slots() == 1
			and SubscriptionManager.tier_of("betteritems") == 4,
		"bazaar %s, rarity %d, tier %d" % [ent["bazaar"], ent["bazaarRarity"],
			SubscriptionManager.tier_of("betteritems")])
	SubscriptionManager.reset()
	var back: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a reset drops the overrides",
		bool(back["bazaar"]) and int(back["bazaarRarity"]) == 4
			and SubscriptionManager.merc_slots() == 3,
		"bazaar %s, rarity %d" % [back["bazaar"], back["bazaarRarity"]])
	TestFixtures.check(res, "entitlements hand out a copy, not the table",
		not bool(SubscriptionManager.entitlements().is_read_only()),
		"read only %s" % SubscriptionManager.entitlements().is_read_only())


#Case 7b: an override through one spelling of a metrics pair reads back under the other, so a
#screen that knows only the prototype spelling and one that knows only the wave 1 spelling agree.
static func _case_pair_spellings(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.reset()
	SubscriptionManager.set_entitlements({"mercMetrics": 1})
	var camel: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a camel override reads back under the wave 1 spelling",
		int(camel["merc_metrics"]) == 1 and int(camel["mercMetrics"]) == 1
			and SubscriptionManager.merc_slots() == 1,
		"merc_metrics %s, mercMetrics %s" % [str(camel["merc_metrics"]),
			str(camel["mercMetrics"])])
	SubscriptionManager.reset()
	SubscriptionManager.set_entitlements({"guild_opinion": false})
	var snake: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a wave 1 override reads back under the prototype spelling",
		not bool(snake["guildOpinion"]) and not bool(snake["guild_opinion"]),
		"guildOpinion %s, guild_opinion %s" % [str(snake["guildOpinion"]),
			str(snake["guild_opinion"])])
	SubscriptionManager.set_entitlements({"contract_metrics": false, "contractMetrics": true})
	var both: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a pair handed both spellings keeps the value each one was given",
		not bool(both["contract_metrics"]) and bool(both["contractMetrics"]),
		"contract_metrics %s, contractMetrics %s" % [str(both["contract_metrics"]),
			str(both["contractMetrics"])])
	SubscriptionManager.reset()


#Case 8: the monthly bill.
static func _case_costs(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var mercs: int = GameState.mercs.size()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var per_merc: int = int(UpgradeDefs.PLANS["enterprise"]["per_merc"])
	TestFixtures.check(res, "a bare Enterprise bill is the per merc fee alone",
		SubscriptionManager.monthly_cost() == per_merc * mercs
			and SubscriptionManager.monthly_upgrade_cost() == 0,
		"got %d for %d mercs" % [SubscriptionManager.monthly_cost(), mercs])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"seats": 2, "pip": 1})
	var upgrades: int = UpgradeDefs.monthly_of("seats", 2) + UpgradeDefs.monthly_of("pip", 1)
	TestFixtures.check(res, "every owned tier adds its own monthly price",
		SubscriptionManager.monthly_upgrade_cost() == upgrades and upgrades == 19
			and SubscriptionManager.monthly_cost() == per_merc * mercs + upgrades,
		"upgrades %d, total %d" % [SubscriptionManager.monthly_upgrade_cost(),
			SubscriptionManager.monthly_cost()])
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	TestFixtures.check(res, "the Free plan bills nothing",
		SubscriptionManager.monthly_cost() == 0, "got %d" % SubscriptionManager.monthly_cost())
	SubscriptionManager.reset()


#Case 9: the roster and board caps per plan.
static func _case_caps(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var free_mercs: int = SubscriptionManager.max_mercs()
	var free_contracts: int = SubscriptionManager.max_contracts()
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	var pro_mercs: int = SubscriptionManager.max_mercs()
	var pro_contracts: int = SubscriptionManager.max_contracts()
	TestFixtures.check(res, "Free and Pro carry fixed caps",
		free_mercs == 5 and free_contracts == 5 and pro_mercs == 20 and pro_contracts == 12,
		"free %d/%d, pro %d/%d" % [free_mercs, free_contracts, pro_mercs, pro_contracts])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var base_mercs: int = SubscriptionManager.max_mercs()
	var base_contracts: int = SubscriptionManager.max_contracts()
	SubscriptionManager.reset()
	TestFixtures.check(res, "Enterprise seats and contract slots stack onto the base",
		base_mercs == 20 and base_contracts == 12 and SubscriptionManager.max_mercs() == 50
			and SubscriptionManager.max_contracts() == 20,
		"base %d/%d, maxed %d/%d" % [base_mercs, base_contracts, SubscriptionManager.max_mercs(),
			SubscriptionManager.max_contracts()])


#Case 10: the bank helpers and the day the campaign stands on.
static func _case_money(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var held: int = GameState.bank_notes
	TestFixtures.check(res, "can_afford reads the bank",
		GameState.can_afford(held) and not GameState.can_afford(held + 1),
		"bank %d" % held)
	TestFixtures.check(res, "spending more than the bank holds is refused",
		not GameState.spend(held + 1) and not GameState.spend(-5)
			and GameState.bank_notes == held, "bank %d" % GameState.bank_notes)
	TestFixtures.check(res, "a spend debits and a refund credits the same notes",
		GameState.spend(10) and GameState.bank_notes == held - 10,
		"bank %d of %d" % [GameState.bank_notes, held])
	GameState.refund(10)
	TestFixtures.check(res, "the refund puts the notes back",
		GameState.bank_notes == held, "bank %d of %d" % [GameState.bank_notes, held])
	TestFixtures.check(res, "the day is the calendar day index",
		GameState.day() == TrynnCalendar.day_index(CampaignClock.now()),
		"day %d" % GameState.day())
	var seen: Array[Dictionary] = []
	var handler: Callable = func(target: Dictionary) -> void: seen.append(target)
	GameState.go_to_plans_requested.connect(handler)
	GameState.go_to_plans({"page": "customize", "id": "bazaar"})
	await host.get_tree().process_frame
	GameState.go_to_plans_requested.disconnect(handler)
	TestFixtures.check(res, "go_to_plans carries the target through",
		seen.size() == 1 and String(seen[0].get("id", "")) == "bazaar",
		"got %s" % str(seen))


#Case 11: the coached level-up modes, their gates and the engine field they mirror onto.
static func _case_pip(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.reset()
	var uid: int = GameState.roster[0].uid
	TestFixtures.check(res, "a met mode is stored and mirrored onto the engine field",
		GameState.set_pip_mode(uid, &"Offensive")
			and GameState.pip_mode(uid) == &"Offensive"
			and String(GameState.merc_extras[uid]["level_mode"]) == "Offensive",
		"mode %s, mirror %s" % [GameState.pip_mode(uid),
			GameState.merc_extras[uid]["level_mode"]])
	TestFixtures.check(res, "a mode the engine cannot express mirrors onto Auto",
		GameState.set_pip_mode(uid, &"Ancestral")
			and String(GameState.merc_extras[uid]["level_mode"]) == "Auto"
			and GameState.stored_pip_mode(uid) == &"Ancestral",
		"mirror %s, stored %s" % [GameState.merc_extras[uid]["level_mode"],
			GameState.stored_pip_mode(uid)])
	TestFixtures.check(res, "an unknown mode and an off roster uid are refused",
		not GameState.set_pip_mode(uid, &"Nonsense") and not GameState.set_pip_mode(-1, &"Auto")
			and GameState.stored_pip_mode(uid) == &"Ancestral",
		"stored %s" % GameState.stored_pip_mode(uid))
	GameState.set_pip_mode(uid, &"Offensive")
	SubscriptionManager.changed.disconnect(GameState.prune_pip_modes)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"pip": 1})
	TestFixtures.check(res, "a mode whose gate is gone falls back to Auto while it is still stored",
		GameState.pip_mode(uid) == &"Auto" and GameState.stored_pip_mode(uid) == &"Offensive",
		"effective %s, stored %s" % [GameState.pip_mode(uid), GameState.stored_pip_mode(uid)])
	SubscriptionManager.changed.connect(GameState.prune_pip_modes)
	GameState.prune_pip_modes()
	TestFixtures.check(res, "the prune drops the unmet mode and resets the mirror",
		GameState.pip_modes.is_empty() and GameState.pip_mode(uid) == &"Auto"
			and String(GameState.merc_extras[uid]["level_mode"]) == "Auto",
		"stored %s, mirror %s" % [str(GameState.pip_modes),
			GameState.merc_extras[uid]["level_mode"]])
	TestFixtures.check(res, "an unmet mode cannot be set at all",
		not GameState.set_pip_mode(uid, &"Offensive") and GameState.set_pip_mode(uid, &"Random"),
		"stored %s" % GameState.stored_pip_mode(uid))
	SubscriptionManager.reset()
	TestFixtures.check(res, "a met mode survives a subscription change",
		GameState.stored_pip_mode(uid) == &"Random", "stored %s" % GameState.stored_pip_mode(uid))
	GameState.pip_modes.clear()
	GameState.set_level_mode(uid, "Auto")


#Case 12: the mode table itself and the art it names.
static func _case_pip_defs(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	TestFixtures.check(res, "the table holds the fourteen modes in three groups",
		PipDefs.MODES.size() == 14 and PipDefs.groups() == [PipDefs.GROUP_STANDARD,
			PipDefs.GROUP_COMBAT, PipDefs.GROUP_SKILL]
			and PipDefs.modes_in(PipDefs.GROUP_STANDARD).size() == 4
			and PipDefs.modes_in(PipDefs.GROUP_COMBAT).size() == 3
			and PipDefs.modes_in(PipDefs.GROUP_SKILL).size() == 7,
		"groups %s" % str(PipDefs.groups()))
	var bad: Array[String] = []
	for data: Dictionary in PipDefs.MODES:
		var mode: StringName = StringName(data["mode"])
		if PipDefs.find(mode).is_empty() or not PipDefs.has(mode):
			bad.append("%s is not found" % mode)
		if String(data["desc"]) == "":
			bad.append("%s has no tooltip" % mode)
		if not Icons.has(PipDefs.icon_id(mode)):
			bad.append("%s has no icon" % mode)
		var upgrade: String = String(data["upgrade_id"])
		if upgrade != "" and not UpgradeDefs.has_id(upgrade):
			bad.append("%s names the unknown %s" % [mode, upgrade])
		if upgrade != "" and int(data["upgrade_tier"]) > UpgradeDefs.tier_count(upgrade):
			bad.append("%s asks for %s tier %d" % [mode, upgrade, int(data["upgrade_tier"])])
	TestFixtures.check(res, "every mode is whole and its icon is a cell of the icon sheet",
		bad.is_empty(), TestFixtures.detail(bad, PipDefs.MODES.size(), "modes"))
	var ent: Dictionary = {"pip": true, "lvSupport": true}
	TestFixtures.check(res, "a gate is read off the entitlements it names",
		PipDefs.unlocked(&"Auto", {}) and PipDefs.unlocked(&"Random", ent)
			and PipDefs.unlocked(&"Support", ent) and not PipDefs.unlocked(&"Defensive", ent)
			and not PipDefs.unlocked(&"Nonsense", ent),
		"random %s, defensive %s" % [PipDefs.unlocked(&"Random", ent),
			PipDefs.unlocked(&"Defensive", ent)])
	TestFixtures.check(res, "each group carries its own color",
		PipDefs.group_color(PipDefs.GROUP_COMBAT) == Color("#e8583f")
			and PipDefs.group_color(PipDefs.GROUP_SKILL) == Color("#6cc36a"),
		"combat %s" % PipDefs.group_color(PipDefs.GROUP_COMBAT).to_html(false))


#Case 13: the one pulse clock every glow reads.
static func _case_pulse(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	TestFixtures.check(res, "the pulse rises over the first fourteen percent of the cycle",
		is_zero_approx(PulseClock.shape(0.0)) and is_equal_approx(PulseClock.shape(0.07), 0.5)
			and is_equal_approx(PulseClock.shape(0.14), 1.0),
		"0 %.3f, 0.07 %.3f, 0.14 %.3f" % [PulseClock.shape(0.0), PulseClock.shape(0.07),
			PulseClock.shape(0.14)])
	TestFixtures.check(res, "the pulse falls to nothing by half the cycle and rests there",
		is_equal_approx(PulseClock.shape(0.32), 0.5) and is_zero_approx(PulseClock.shape(0.5))
			and is_zero_approx(PulseClock.shape(0.9)),
		"0.32 %.3f, 0.5 %.3f, 0.9 %.3f" % [PulseClock.shape(0.32), PulseClock.shape(0.5),
			PulseClock.shape(0.9)])
	var lead: float = PulseClock.STEP / PulseClock.CYCLE
	var sample: PackedFloat32Array = PulseClock.sample(2.0 * lead)
	TestFixtures.check(res, "each sweep chunk trails the one before it by one step",
		sample.size() == PulseClock.CHUNKS + 1
			and is_equal_approx(sample[0], PulseClock.shape(2.0 * lead))
			and is_equal_approx(sample[1], sample[0]) and is_zero_approx(sample[3])
			and is_equal_approx(sample[2], PulseClock.shape(lead)),
		"g %.3f, chunk 1 %.3f, chunk 2 %.3f" % [sample[0], sample[2], sample[3]])
	PulseClock.reset()
	TestFixtures.check(res, "the clock holds its last values for a late joiner",
		PulseClock.sweep.size() == PulseClock.CHUNKS and is_zero_approx(PulseClock.g)
			and is_zero_approx(PulseClock.phase()),
		"g %.3f, sweep %d" % [PulseClock.g, PulseClock.sweep.size()])
	var beats: Array[float] = []
	var handler: Callable = func(g: float, _sweep: PackedFloat32Array) -> void: beats.append(g)
	PulseClock.pulse.connect(handler)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	PulseClock.pulse.disconnect(handler)
	TestFixtures.check(res, "the clock beats once a frame while it runs",
		beats.size() >= 2 and PulseClock.phase() > 0.0,
		"%d beats, phase %.4f" % [beats.size(), PulseClock.phase()])
	PulseClock.reset()


#Case 14: the Promotions branch of the upgrade table.
static func _case_promo_table(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var counts: Dictionary = {"promotions": 1, "promomethods": 3, "longpromos": 5, "marketing": 6,
		"guildpromo": 4}
	var bad: Array[String] = []
	for id: String in counts:
		if not UpgradeDefs.has_id(id):
			bad.append("%s is missing" % id)
			continue
		if UpgradeDefs.category_of(id) != "promoCat":
			bad.append("%s sits in %s" % [id, UpgradeDefs.category_of(id)])
		if UpgradeDefs.tier_count(id) != int(counts[id]):
			bad.append("%s has %d tiers" % [id, UpgradeDefs.tier_count(id)])
	TestFixtures.check(res, "the five promotions rows carry their own tier counts", bad.is_empty(),
		TestFixtures.detail(bad, counts.size(), "rows"))
	TestFixtures.check(res, "the promotions prices are the handoff prices",
		UpgradeDefs.of("promotions")["monthly"] == [20]
			and UpgradeDefs.of("promomethods")["monthly"] == [25, 25, 25]
			and UpgradeDefs.of("longpromos")["monthly"] == [10, 10, 15, 15, 25]
			and UpgradeDefs.of("marketing")["monthly"] == [45, 45, 45, 45, 45, 45]
			and UpgradeDefs.of("guildpromo")["monthly"] == [30, 10, 10, 10],
		"promotions %s, guild promo %s" % [str(UpgradeDefs.of("promotions")["monthly"]),
			str(UpgradeDefs.of("guildpromo")["monthly"])])
	var texts: Array[Array] = [["promotions", 1, "Unlock the Promotions tab and Job Postings, with"
				+ " Flyers ads (promos run up to 5 days)"],
		["promomethods", 1, "Unlock Direct Sale ads (Guild Promo only)"],
		["promomethods", 2, "Unlock Radio ads"],
		["promomethods", 3, "Unlock Sponsorship ads"],
		["longpromos", 1, "Promos can run up to 10 days"],
		["longpromos", 4, "Promos can run up to 30 days"],
		["longpromos", 5, "Promos can run indefinitely (billed monthly)"],
		["marketing", 1, "Ads are 5% more effective"],
		["marketing", 6, "Ads are 25% more effective"],
		["guildpromo", 1, "Unlock Guild Promotion"],
		["guildpromo", 2, "Guild Promotion: set a Minimum Difficulty"],
		["guildpromo", 3, "Guild Promotion: set a Maximum Difficulty"],
		["guildpromo", 4, "Guild Promotion: choose Contract Types"]]
	var wrong: Array[String] = []
	for row: Array in texts:
		if UpgradeDefs.tier_text(String(row[0]), int(row[1])) != String(row[2]):
			wrong.append("%s tier %d" % [row[0], int(row[1])])
	TestFixtures.check(res, "every promotions tier text reads as the handoff wrote it",
		wrong.is_empty(), TestFixtures.detail(wrong, texts.size(), "tier texts"))
	TestFixtures.check(res, "the promotions category lists its five in table order",
		UpgradeDefs.ids_in_category("promoCat") == ["promotions", "promomethods", "longpromos",
			"marketing", "guildpromo"],
		"got %s" % str(UpgradeDefs.ids_in_category("promoCat")))
	var one: Dictionary = {"promotions": 1}
	TestFixtures.check(res, "the three children wait on the first Promotions tier",
		not UpgradeDefs.requirement_met("promomethods", {})
			and not UpgradeDefs.requirement_met("longpromos", {})
			and not UpgradeDefs.requirement_met("marketing", {})
			and UpgradeDefs.requirement_met("promomethods", one)
			and UpgradeDefs.requirement_met("longpromos", one)
			and UpgradeDefs.requirement_met("marketing", one),
		"have %d" % UpgradeDefs.requirement_have("promomethods", one))
	TestFixtures.check(res, "guild promo needs five tiers across methods and marketing",
		UpgradeDefs.requirement_need("guildpromo") == 5
			and UpgradeDefs.requirement_met("guildpromo", {"promomethods": 3, "marketing": 2})
			and not UpgradeDefs.requirement_met("guildpromo", {"promomethods": 3, "marketing": 1})
			and UpgradeDefs.requirement_met("guildpromo", {"marketing": 6}),
		"have %d of %d" % [UpgradeDefs.requirement_have("guildpromo", {"marketing": 6}),
			UpgradeDefs.requirement_need("guildpromo")])
	TestFixtures.check(res, "promotions carries its three children and they carry guild promo",
		UpgradeDefs.dependants_of("promotions") == ["promomethods", "longpromos", "marketing"]
			and UpgradeDefs.dependants_of("promomethods") == ["guildpromo"]
			and UpgradeDefs.dependants_of("marketing") == ["guildpromo"]
			and UpgradeDefs.dependants_of("longpromos").is_empty(),
		"promotions %s" % str(UpgradeDefs.dependants_of("promotions")))


#Case 15: the promotions entitlement keys, tier by tier and plan by plan.
static func _case_promo_keys(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var bare: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a bare Enterprise plan holds no promotions key",
		not bool(bare["promotions"]) and not bool(bare["jobPostings"])
			and int(bare["maxPromoDays"]) == 0 and int(bare["adBoost"]) == 0
			and not bool(bare["adDirect"]) and not bool(bare["adRadio"])
			and not bool(bare["adSponsor"]) and not bool(bare["guildPromo"])
			and not bool(bare["gpMinDifficulty"]) and not bool(bare["gpMaxDifficulty"])
			and not bool(bare["gpContractType"]),
		"promotions %s, days %d" % [bare["promotions"], bare["maxPromoDays"]])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"promotions": 1})
	var opened: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "the Promotions upgrade opens the window, postings and five days",
		bool(opened["promotions"]) and bool(opened["jobPostings"])
			and int(opened["maxPromoDays"]) == 5,
		"days %d" % opened["maxPromoDays"])
	var days: Array[int] = []
	for tier: int in range(1, 6):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
			{"promotions": 1, "longpromos": tier})
		days.append(int(SubscriptionManager.entitlements()["maxPromoDays"]))
	TestFixtures.check(res, "each Long Promos tier raises the day cap",
		days == [10, 17, 25, 30, SubscriptionManager.PROMO_DAYS_INFINITE], "got %s" % str(days))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"longpromos": 5})
	TestFixtures.check(res, "Long Promos without Promotions caps at nothing",
		int(SubscriptionManager.entitlements()["maxPromoDays"]) == 0,
		"days %d" % SubscriptionManager.entitlements()["maxPromoDays"])
	var boost: Array[int] = []
	for tier: int in range(7):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
			{"promotions": 1, "marketing": tier})
		boost.append(int(SubscriptionManager.entitlements()["adBoost"]))
	TestFixtures.check(res, "each Marketing Agency tier adds its own ad boost",
		boost == [0, 5, 7, 12, 15, 20, 25], "got %s" % str(boost))
	var ads: Array[String] = []
	for tier: int in range(4):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
			{"promotions": 1, "promomethods": tier})
		var ad: Dictionary = SubscriptionManager.entitlements()
		ads.append("%d%d%d" % [int(bool(ad["adDirect"])), int(bool(ad["adRadio"])),
			int(bool(ad["adSponsor"]))])
	TestFixtures.check(res, "the promo methods open Direct Sale, Radio and Sponsorship in order",
		ads == ["000", "100", "110", "111"], "got %s" % str(ads))
	var gp: Array[String] = []
	for tier: int in range(5):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"guildpromo": tier})
		var guild: Dictionary = SubscriptionManager.entitlements()
		gp.append("%d%d%d%d" % [int(bool(guild["guildPromo"])),
			int(bool(guild["gpMinDifficulty"])), int(bool(guild["gpMaxDifficulty"])),
			int(bool(guild["gpContractType"]))])
	TestFixtures.check(res, "the guild promo tiers open their four keys in order",
		gp == ["0000", "1000", "1100", "1110", "1111"], "got %s" % str(gp))
	var keys: Array[String] = ["promotions", "jobPostings", "maxPromoDays", "adBoost", "adDirect",
		"adRadio", "adSponsor", "guildPromo", "gpMinDifficulty", "gpMaxDifficulty",
		"gpContractType"]
	var owned: Dictionary = {"promotions": 1, "promomethods": 3, "longpromos": 5, "marketing": 6,
		"guildpromo": 4}
	var leaks: Array[String] = []
	for low_plan: int in [SubscriptionManager.Plan.PRO, SubscriptionManager.Plan.FREE]:
		SubscriptionManager.set_state(low_plan, owned)
		var low: Dictionary = SubscriptionManager.entitlements()
		for key: String in keys:
			var value: Variant = low[key]
			if (value is bool and bool(value)) or (value is int and int(value) != 0):
				leaks.append("%s on %s" % [key, SubscriptionManager.plan_key()])
	TestFixtures.check(res, "no promotions key survives below Enterprise", leaks.is_empty(),
		TestFixtures.detail(leaks, 2 * keys.size(), "keys"))
	SubscriptionManager.reset()
	var full: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "a reset owns every promotions tier",
		bool(full["promotions"]) and bool(full["jobPostings"]) and bool(full["adSponsor"])
			and bool(full["guildPromo"]) and bool(full["gpContractType"])
			and int(full["maxPromoDays"]) == SubscriptionManager.PROMO_DAYS_INFINITE
			and int(full["adBoost"]) == 25,
		"days %d, boost %d" % [full["maxPromoDays"], full["adBoost"]])


#Case 16: the monthly bill for the promotions branch.
static func _case_promo_costs(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"promotions": 1, "longpromos": 2})
	TestFixtures.check(res, "an owned promo tier adds its own monthly price",
		SubscriptionManager.monthly_upgrade_cost() == 40,
		"got %d" % SubscriptionManager.monthly_upgrade_cost())
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"promotions": 1, "promomethods": 3, "longpromos": 5, "marketing": 6, "guildpromo": 4})
	var branch: int = 20 + 75 + 75 + 270 + 60
	TestFixtures.check(res, "the whole promotions branch bills every tier it holds",
		SubscriptionManager.monthly_upgrade_cost() == branch and branch == 500,
		"got %d of %d" % [SubscriptionManager.monthly_upgrade_cost(), branch])
	SubscriptionManager.reset()


#Case 17: the hand off from Promotions to Hiring and the money the HUD flies.
static func _case_hiring_handoff(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var seen: Array[int] = []
	var handler: Callable = func(campaign_id: int) -> void: seen.append(campaign_id)
	GameState.open_hiring_requested.connect(handler)
	GameState.open_hiring(3)
	await host.get_tree().process_frame
	GameState.open_hiring_requested.disconnect(handler)
	TestFixtures.check(res, "open_hiring names the campaign and stores its filter",
		seen == [3] and GameState.hire_filter.get("from", []) == [3],
		"seen %s, filter %s" % [str(seen), str(GameState.hire_filter)])
	var taken: Dictionary = GameState.take_hire_filter()
	TestFixtures.check(res, "the filter is handed over once and then gone",
		taken.get("from", []) == [3] and GameState.hire_filter.is_empty()
			and GameState.take_hire_filter().is_empty(),
		"taken %s, left %s" % [str(taken), str(GameState.hire_filter)])
	GameState.open_hiring(5)
	GameState.start_new_game()
	TestFixtures.check(res, "a new game drops a stored filter",
		GameState.hire_filter.is_empty(), "filter %s" % str(GameState.hire_filter))
	var flown: Array[int] = []
	var fly: Callable = func(amount: int) -> void: flown.append(amount)
	GameState.money_fly_requested.connect(fly)
	var held: int = GameState.bank_notes
	GameState.fly_money(-16)
	GameState.fly_money(0)
	await host.get_tree().process_frame
	GameState.money_fly_requested.disconnect(fly)
	TestFixtures.check(res, "fly_money asks for the animation and never moves the bank",
		flown == [-16] and GameState.bank_notes == held,
		"flown %s, bank %d of %d" % [str(flown), GameState.bank_notes, held])


#Case 18: the prototype key spellings the wave 2 screens read, and the ladders behind them.
static func _case_proto_keys(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var bare: Dictionary = SubscriptionManager.entitlements()
	var leaks: Array[String] = _upgrade_leaks(bare)
	TestFixtures.check(res, "bare Enterprise opens no new upgrade key",
		leaks.is_empty() and bool(bare["physical"]) and bool(bare["veryFast"])
			and int(bare["perMerc"]) == 15,
		TestFixtures.detail(leaks, PROTO_UPGRADE_KEYS.size(), "keys"))
	var ladder: Array[String] = []
	var discrim: Array[String] = ["ancestry", "bloodline", "age"]
	for tier: int in range(0, 4):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"discrim": tier})
		var ent: Dictionary = SubscriptionManager.entitlements()
		for i: int in discrim.size():
			if bool(ent[discrim[i]]) != (tier >= i + 1):
				ladder.append("%s at %d" % [discrim[i], tier])
	TestFixtures.check(res, "the discrimination tiers open ancestry, bloodline and age in order",
		ladder.is_empty(), TestFixtures.detail(ladder, 12, "steps"))
	var back: Array[String] = []
	var background: Array[String] = ["heritage", "perks", "drawbacks", "skills", "lifepath"]
	for tier: int in range(0, 6):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"background": tier})
		var ent: Dictionary = SubscriptionManager.entitlements()
		for i: int in background.size():
			if bool(ent[background[i]]) != (tier >= i + 1):
				back.append("%s at %d" % [background[i], tier])
	TestFixtures.check(res, "the background tiers open their five keys in order", back.is_empty(),
		TestFixtures.detail(back, 30, "steps"))
	var refresh: Array[String] = []
	for tier: int in range(0, 6):
		SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
			{"survey": 1, "fastmetrics": tier})
		refresh.append(String(SubscriptionManager.entitlements()["surveyRefresh"]))
	TestFixtures.check(res, "the survey refresh rate follows the faster metrics tier",
		refresh == SubscriptionManager.SURVEY_REFRESH, "got %s" % str(refresh))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"fastmetrics": 5})
	var fast: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "faster metrics with no survey predicts but never refreshes",
		String(fast["surveyRefresh"]) == "none" and bool(fast["predictive"]),
		"refresh %s, predictive %s" % [fast["surveyRefresh"], fast["predictive"]])
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {"discrim": 3, "survey": 1})
	var pro: Dictionary = SubscriptionManager.entitlements()
	var pro_leaks: Array[String] = _upgrade_leaks(pro)
	TestFixtures.check(res, "Pro carries the physical and speed keys and no upgrade key",
		pro_leaks.is_empty() and bool(pro["physical"]) and bool(pro["veryFast"])
			and int(pro["perMerc"]) == 5 and int(pro["maxMercs"]) == 20
			and int(pro["maxContracts"]) == 12,
		TestFixtures.detail(pro_leaks, PROTO_UPGRADE_KEYS.size(), "keys"))
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var free: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "Free pays for no mercs and holds the five slot caps",
		not bool(free["physical"]) and not bool(free["veryFast"]) and int(free["perMerc"]) == 0
			and int(free["maxMercs"]) == 5 and int(free["maxContracts"]) == 5,
		"perMerc %d, mercs %d, contracts %d" % [int(free["perMerc"]), int(free["maxMercs"]),
			int(free["maxContracts"])])
	var splits: Array[String] = []
	SubscriptionManager.reset()
	var full: Dictionary = SubscriptionManager.entitlements()
	for state: Dictionary in [full, bare, pro]:
		for key: Variant in ALIAS_KEYS:
			var old_key: String = String(ALIAS_KEYS[key])
			if state[key] != state[old_key]:
				splits.append("%s vs %s" % [key, old_key])
	TestFixtures.check(res, "every prototype alias reads its wave 1 spelling", splits.is_empty(),
		TestFixtures.detail(splits, ALIAS_KEYS.size() * 3, "aliases"))
	SubscriptionManager.reset()


#The new upgrade keys that are open, which on any state below a bought tier must be none.
static func _upgrade_leaks(ent: Dictionary) -> Array[String]:
	var leaks: Array[String] = []
	for key: String in PROTO_UPGRADE_KEYS:
		var value: Variant = ent[key]
		if (value is bool and bool(value)) or (value is int and int(value) != 0):
			leaks.append(key)
	if String(ent["surveyRefresh"]) != "none":
		leaks.append("surveyRefresh")
	return leaks

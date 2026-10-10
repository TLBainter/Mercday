class_name UpgradeDefs
extends RefCounted

#The plan and upgrade tables behind the Subscription screens, ported from the design prototype
#with the DATA_DELTA rows applied on top. monthly[i] is the monthly cost of tier i+1, so owning
#tier t costs the sum of the first t entries every month. A req of {} means the upgrade is free
#to buy; otherwise the owned tiers of req.ids are summed and compared with req.tier.
#Prices marked PLACEHOLDER in the design prototype are carried over unchanged.

const PLANS: Dictionary = {
	"free": {"name": "Mercday Free", "short": "Free", "per_merc": 0, "max_mercs": 5,
		"accent": Color("#6cc36a"), "tagline": "Run a small crew of mercenaries at no cost!",
		"features": ["Up to 5 mercenaries", "Up to 5 contracts", "Advanced Merc Manager",
			"Advanced Contract Manager", "Advanced Finance Management"]},
	"pro": {"name": "Mercday Pro", "short": "Pro", "per_merc": 5, "max_mercs": 8,
		"accent": Color("#f2d33d"), "tagline": "Grow your guild with Mercday!",
		"features": ["Up to 8 mercenaries", "Up to 8 contracts", "Advanced Merc Manager",
			"Advanced Contract Manager", "Advanced Finance Management", "Guild Metrics",
			"See some physical attributes of your mercenaries"]},
	"enterprise": {"name": "Mercday Enterprise", "short": "Enterprise", "per_merc": 15,
		"max_mercs": 32, "accent": Color("#f28c28"),
		"tagline": "Customize Mercday for your needs!",
		"features": ["Everything in Pro", "Access to Plan Customization"]},
}

#Roster and board caps: the plan floor plus what the Seats and Contracts upgrades add.
const FREE_MERCS := 5
const PRO_MERCS := 8
const ENTERPRISE_MERCS := 8
const MERCS_PER_SEAT := 3
const FREE_CONTRACTS := 5
const PRO_CONTRACTS := 8
const ENTERPRISE_CONTRACTS := 8
const CONTRACTS_PER_TIER := 3

const UPGRADES: Dictionary = {
	"seats": {"name": "Seats", "cat": "limits", "also_cat": [], "req": {},
		"monthly": [3, 6, 12, 24, 48, 96, 192, 384], "desc": "Increase your merc roster's maximum size.",
		"tiers": ["+3 max mercenaries (11)", "+3 max mercenaries (14)", "+3 max mercenaries (17)",
			"+3 max mercenaries (20)", "+3 max mercenaries (23)", "+3 max mercenaries (26)",
			"+3 max mercenaries (29)", "+3 max mercenaries (32)"]},
	"contracts": {"name": "Contracts", "cat": "limits", "also_cat": [], "req": {},
		"monthly": [10, 20, 40, 80], "desc": "Increase your contract board's maximum size.",
		"tiers": ["+3 contract board slots (11)", "+3 contract board slots (14)",
			"+3 contract board slots (17)", "+3 contract board slots (20)"]},
	#PLACEHOLDER prices: Promotions, Long Promos and Guild Promo.
	"promotions": {"name": "Promotions", "cat": "promoCat", "also_cat": [], "req": {},
		"monthly": [20],
		"desc": "Open a Promotions account to post jobs and advertise your guild.",
		"tiers": ["Unlock the Promotions tab and Job Postings, with Flyers ads (promos run up to 5 days)"]},
	"promomethods": {"name": "Promo Methods", "cat": "promoCat", "also_cat": [],
		"req": {"ids": ["promotions"], "tier": 1}, "monthly": [25, 25, 25],
		"desc": "Unlock additional advertising methods. Word of Mouth comes with Odd Jobs.",
		"tiers": ["Unlock Direct Sale ads (Guild Promo only)", "Unlock Radio ads",
			"Unlock Sponsorship ads"]},
	"longpromos": {"name": "Long Promos", "cat": "promoCat", "also_cat": [],
		"req": {"ids": ["promotions"], "tier": 1}, "monthly": [10, 10, 15, 15, 25],
		"desc": "Increase the maximum duration of your advertisements (base 5 days).",
		"tiers": ["Promos can run up to 10 days", "Promos can run up to 17 days",
			"Promos can run up to 25 days", "Promos can run up to 30 days",
			"Promos can run indefinitely (billed monthly)"]},
	"marketing": {"name": "Marketing Agency", "cat": "promoCat", "also_cat": [],
		"req": {"ids": ["promotions"], "tier": 1}, "monthly": [45, 45, 45, 45, 45, 45],
		"desc": "Hire a marketing agency to make every ad more effective.",
		"tiers": ["Ads are 5% more effective", "Ads are 7% more effective",
			"Ads are 12% more effective", "Ads are 15% more effective",
			"Ads are 20% more effective", "Ads are 25% more effective"]},
	"guildpromo": {"name": "Guild Promo", "cat": "promoCat", "also_cat": [],
		"req": {"ids": ["promomethods", "marketing"], "tier": 5}, "monthly": [30, 10, 10, 10],
		"desc": "Promote your guild to attract new contracts.",
		"tiers": ["Unlock Guild Promotion", "Guild Promotion: set a Minimum Difficulty",
			"Guild Promotion: set a Maximum Difficulty",
			"Guild Promotion: choose Contract Types"]},
	"discrim": {"name": "Discrimination", "cat": "lessLegal", "also_cat": ["insights"], "req": {},
		"monthly": [20, 35, 50, 65], "desc": "Gain forbidden knowledge. You won't get sued!",
		"tiers": ["See merc ancestry", "See merc bloodline", "See merc age",
			"Hiring Discrimination: see and filter for these traits on applicants and job postings"]},
	"background": {"name": "Background Check", "cat": "insights", "also_cat": [], "req": {},
		"monthly": [25, 40, 55, 70, 85],
		"desc": "A perfectly legal investigation into the history of your mercs.",
		"tiers": ["See merc heritage", "See merc perks", "See merc drawbacks", "See merc skills",
			"Lifepath: see each merc's Lifepath events"]},
	"survey": {"name": "Employee Survey", "cat": "metricsCat", "also_cat": [],
		"req": {"ids": ["mercmetrics"], "tier": 1}, "monthly": [5],
		"desc": "\"Anonymously\" poll your mercs about the company.",
		"tiers": ["Get each merc's opinion of your guild in an \"anonymous\" survey (quarterly)"]},
	"peer": {"name": "Peer Review", "cat": "metricsCat", "also_cat": [],
		"req": {"ids": ["survey"], "tier": 1}, "monthly": [5],
		"desc": "\"Anonymously\" poll your mercs about each other.",
		"tiers": ["See each merc's opinion of other mercs"]},
	"customer": {"name": "Customer Satisfaction", "cat": "metricsCat", "also_cat": [],
		"req": {"ids": ["contractmetrics", "survey"], "tier": 2}, "monthly": [5],
		"desc": "Poll your customers about your company.",
		"tiers": ["See client and company opinions of your guild"]},
	"fastmetrics": {"name": "Rapid Survey", "cat": "metricsCat", "also_cat": [],
		"req": {"ids": ["peer", "customer"], "tier": 2}, "monthly": [9, 9, 9, 9, 9],
		"desc": "The same metrics, but faster!",
		"tiers": ["Surveys are conducted monthly (last weekday of the month)",
			"Surveys are conducted weekly", "Surveys are conducted daily",
			"Survey data is instantaneous", "Some survey data is predictive"]},
	"aptitude": {"name": "Aptitude Test", "cat": "testing", "also_cat": [], "req": {},
		"monthly": [3], "desc": "Test the abilities of your mercs.",
		"tiers": ["Reveal merc Cognition (CGN)"]},
	"brawn": {"name": "Brawn Test", "cat": "testing", "also_cat": [], "req": {},
		"monthly": [3], "desc": "Test the physicality of your mercs.",
		"tiers": ["Reveal merc Vigor (VGR)"]},
	"readiness": {"name": "Readiness Test", "cat": "testing", "also_cat": [], "req": {},
		"monthly": [3], "desc": "Test the reflexes of your mercs.",
		"tiers": ["Reveal merc Dexterity (DEX)"]},
	"personality": {"name": "Personality Test", "cat": "testing", "also_cat": [], "req": {},
		"monthly": [3], "desc": "Learn more about the personalities of your mercs.",
		"tiers": ["Reveal merc Wile (WIL)"]},
	"skilltest": {"name": "Skill Test", "cat": "testing", "also_cat": [],
		"req": {"ids": ["readiness", "aptitude"], "tier": 2, "exit_dy": {"aptitude": -18}},
		"monthly": [5], "desc": "Learn the unique skills of your mercs.",
		"tiers": ["Reveal merc Tools"]},
	"criminal": {"name": "Criminal Background Check", "cat": "insights",
		"also_cat": ["lessLegal"],
		"req": {"ids": ["discrim", "background"], "tier": 6, "side_exit": ["discrim"]},
		"monthly": [10],
		"desc": "A perfectly legal investigation into the misdeeds of your mercs.",
		"tiers": ["See each merc's Criminality rating"]},
	"pip": {"name": "Performance Improvement Plan", "cat": "coaching", "also_cat": [], "req": {},
		"monthly": [10],
		"desc": "Put your mercs on a basic Performance Improvement Plan to direct them as they level up!",
		"tiers": ["Unlock Random, Utility, Skills, and Stats-based Performance Improvement Plans."]},
	"combatpip": {"name": "Combat PIP", "cat": "coaching", "also_cat": [],
		"req": {"ids": ["pip"], "tier": 1}, "monthly": [2, 2, 2],
		"desc": "Have a merc focus on their combat abilities as they level up!",
		"tiers": ["Support: Have your merc focus on teamwork-based combat features as they level up!",
			"Defensive: Have a merc focus on defensive abilities as they level up!",
			"Offensive: Have a merc focus on offensive abilities as they level up!"]},
	"skillpip": {"name": "Skill PIP", "cat": "coaching", "also_cat": [],
		"req": {"ids": ["pip"], "tier": 1}, "monthly": [2, 2, 2, 2, 2],
		"desc": "Have a merc focus on their skills as they level up!",
		"tiers": ["Existing Skills: Direct your merc to focus only on improving their existing skills, where possible.",
			"New Skills: Direct your merc to always learn new skills, where possible.",
			"Universal: Have a merc focus on broader skills as they level up!",
			"Ancestral: Have a merc focus on their ancestry as they level up!",
			"Tradition: Have a merc focus on their tradition as they level up!"]},
	"magicpip": {"name": "Magic PIP", "cat": "coaching", "also_cat": [],
		"req": {"ids": ["combatpip", "skillpip"], "tier": 4}, "monthly": [2],
		"desc": "Have a merc focus on their magical abilities as they level up!",
		"tiers": ["Spell: Have a merc focus on spellcasting as they level up!"]},
	"contractmetrics": {"name": "Contract Metrics", "cat": "insights", "also_cat": [],
		"req": {"ids": ["background"], "tier": 1}, "monthly": [1],
		"desc": "See how your contracts perform over time.",
		"tiers": ["View details metrics for your contracts via the Contract Graph"]},
	"mercmetrics": {"name": "Merc Metrics", "cat": "insights", "also_cat": [],
		"req": {"ids": ["background"], "tier": 3}, "monthly": [1, 1, 1],
		"desc": "See how your mercs perform over time.",
		"tiers": ["See Merc averages via the Merc Graph", "Select individual mercs on the Merc Graph",
			"Compare two mercs on the Merc Graph"]},
	"oddjobs": {"name": "Odd Jobs", "cat": "lessLegal", "also_cat": [], "req": {},
		"monthly": [15, 25, 40],
		"desc": "Send your idle mercs out on Odd Jobs for a little extra coin.",
		"tiers": ["Send 1 merc on Odd Jobs", "Send up to 2 mercs on Odd Jobs",
			"Send up to 3 mercs on Odd Jobs"]},
	"opspermit": {"name": "Operations Permits", "cat": "legalCat", "also_cat": [], "req": {},
		"monthly": [50, 50, 50],
		"desc": "Operate in new locations. If you lose this upgrade you lose access to your permits"
			+ " and their benefits, but you keep them and never need to buy them again.",
		"tiers": ["Request and use Operations Permits from most nations",
			"Request and use Operations Permits from all nations",
			"Request and use Operations Permits from other Domains"]},
	"teleport": {"name": "Teleportation Permit", "cat": "legalCat", "also_cat": [],
		"req": {"ids": ["opspermit"], "tier": 2}, "monthly": [50, 50, 50],
		"desc": "Teleport your mercs to and from permitted locations.",
		"tiers": ["Add a teleportation circle to your guild and use it",
			"Request Teleportation Permits from all nations",
			"Request Teleportation Permits from other Domains"]},
	"representation": {"name": "Representation", "cat": "legalCat", "also_cat": [],
		"req": {"ids": ["opspermit"], "tier": 1}, "monthly": [500, 500, 500],
		"desc": "Keep a lawyer on retainer.",
		"tiers": ["Very low chance for a fine or legal charge to be dismissed",
			"Low chance for a fine or legal charge to be dismissed",
			"Moderate chance for a fine or legal charge to be dismissed"]},
	"counsel": {"name": "Advisory Counsel", "cat": "legalCat", "also_cat": [],
		"req": {"ids": ["representation", "oddjobs"], "tier": 5},
		"monthly": [100, 100, 100, 100, 100],
		"desc": "Your lawyer advises your mercs before they \"renegotiate\".",
		"tiers": ["Boosts Renegotiate Odd Job success chances by 5% per merc",
			"Boosts Renegotiate Odd Job success chances by 7% per merc",
			"Boosts Renegotiate Odd Job success chances by 9% per merc",
			"Boosts Renegotiate Odd Job success chances by 13% per merc",
			"Boosts Renegotiate Odd Job success chances by 15% per merc"]},
	"whoknows": {"name": "Who Knows a Guy", "cat": "lessLegal", "also_cat": [], "req": {},
		"monthly": [17, 17, 17, 17, 17, 17, 17, 17],
		"desc": "It's not what you know. Only affects future fines, bail, and sentences.",
		"tiers": ["Reduce future Bail and Fines by 5%", "Reduce future Prison Time by 5%",
			"Reduce future Bail and Fines by 20%", "Reduce future Prison Time by 15%",
			"Reduce future Bail and Fines by 25%", "Reduce future Prison Time by 20%",
			"Reduce future Fine Fees by 50%", "Ignore future Fine Fees"]},
	"bazaar": {"name": "Bazaar", "cat": "bazaarCat", "also_cat": [], "req": {}, "monthly": [10],
		"desc": "Open an account at the Bazaar to buy gear for your mercs.",
		"tiers": ["Unlock the Bazaar (orders take 20 days to arrive)"]},
	"betteritems": {"name": "Better Items", "cat": "bazaarCat", "also_cat": [],
		"req": {"ids": ["bazaar"], "tier": 1}, "monthly": [5, 5, 5, 5],
		"desc": "Increases the rarity of items available in the Bazaar.",
		"tiers": ["Common items are available", "Uncommon items are available",
			"Rare items are available", "Very Rare items are available"]},
	"fasteritems": {"name": "Faster Items", "cat": "bazaarCat", "also_cat": [],
		"req": {"ids": ["bazaar"], "tier": 1}, "monthly": [2, 2, 2, 2, 2],
		"desc": "Increases the delivery speed of Bazaar orders.",
		"tiers": ["Deliveries arrive 25% faster", "Deliveries arrive 30% faster",
			"Deliveries arrive 45% faster", "Deliveries arrive 50% faster",
			"2-Day delivery on all items"]},
	"education": {"name": "Education Exam", "cat": "testing", "also_cat": [],
		"req": {"ids": ["background", "aptitude"], "tier": 3, "exit_dy": {"aptitude": 18},
			"top_exit": ["background"]}, "monthly": [7],
		"desc": "Learn what your mercs have learned.",
		"tiers": ["Reveal merc Knowledges"]},
}

#Prototype order; the Customize screen and the billing list both walk the table this way.
const ORDER: Array[String] = ["seats", "contracts", "promotions", "promomethods", "longpromos",
	"marketing", "guildpromo", "discrim", "background", "survey", "peer", "customer", "fastmetrics",
	"aptitude", "brawn", "readiness", "personality", "skilltest", "criminal", "pip", "combatpip",
	"skillpip", "magicpip", "contractmetrics", "mercmetrics", "oddjobs", "opspermit", "teleport",
	"representation", "counsel", "whoknows", "bazaar", "betteritems", "fasteritems", "education"]

#An upgrade fed by several categories still bills to exactly one of them.
const BILL_CATEGORY: Dictionary = {"counsel": "legalCat", "criminal": "insights",
	"education": "testing"}


static func has_id(id: String) -> bool:
	return UPGRADES.has(id)


static func of(id: String) -> Dictionary:
	return UPGRADES.get(id, {}) as Dictionary


static func name_of(id: String) -> String:
	return String(of(id).get("name", id))


static func tier_count(id: String) -> int:
	return (of(id).get("monthly", []) as Array).size()


#The name a lock shows for an upgrade, or "" when the id is empty or unknown.
static func display_name(id: String) -> String:
	if id == "" or not has_id(id):
		return ""
	return name_of(id)


#The tier count a lock shows for an upgrade, never under 1, and 1 when the id is empty or unknown.
static func display_tiers(id: String) -> int:
	if id == "" or not has_id(id):
		return 1
	return maxi(1, tier_count(id))


static func tier_text(id: String, tier: int) -> String:
	var tiers: Array = of(id).get("tiers", []) as Array
	if tier < 1 or tier > tiers.size():
		return ""
	return String(tiers[tier - 1])


static func category_of(id: String) -> String:
	return String(of(id).get("cat", ""))


#The category an upgrade is billed to: its own, unless the table names another one.
static func bill_category(id: String) -> String:
	return String(BILL_CATEGORY.get(id, category_of(id)))


static func in_category(id: String, cat: String) -> bool:
	var data: Dictionary = of(id)
	if data.is_empty():
		return false
	return String(data.get("cat", "")) == cat or (data.get("also_cat", []) as Array).has(cat)


static func ids_in_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		if in_category(id, cat):
			out.append(id)
	return out


#What owning this tier costs every month: the sum of the tier prices up to it.
static func monthly_of(id: String, tier: int) -> int:
	var monthly: Array = of(id).get("monthly", []) as Array
	var total: int = 0
	for i: int in range(mini(maxi(0, tier), monthly.size())):
		total += int(monthly[i])
	return total


static func req_of(id: String) -> Dictionary:
	return of(id).get("req", {}) as Dictionary


static func requirement_need(id: String) -> int:
	return int(req_of(id).get("tier", 0))


#The owned tiers of every upgrade the requirement names, added together.
static func requirement_have(id: String, tiers: Dictionary) -> int:
	var req: Dictionary = req_of(id)
	var total: int = 0
	for other: String in req.get("ids", []) as Array:
		total += int(tiers.get(other, 0))
	return total


static func requirement_met(id: String, tiers: Dictionary) -> bool:
	if req_of(id).is_empty():
		return true
	return requirement_have(id, tiers) >= requirement_need(id)


#Every id whose requirement names this one, in table order.
static func dependants_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for other: String in ORDER:
		if (req_of(other).get("ids", []) as Array).has(id):
			out.append(other)
	return out


static func plan_key(plan: int) -> String:
	var keys: Array = PLANS.keys()
	if plan < 0 or plan >= keys.size():
		return ""
	return String(keys[plan])


static func plan_data(plan: int) -> Dictionary:
	return PLANS.get(plan_key(plan), {}) as Dictionary


#Free and Pro have fixed caps; Enterprise starts at 8, buys three more seats a tier and stops at
#the roster cap the plan table lists.
static func plan_max_mercs(plan: int, seats_tier: int) -> int:
	match plan_key(plan):
		"free":
			return FREE_MERCS
		"pro":
			return PRO_MERCS
		"enterprise":
			var bought: int = ENTERPRISE_MERCS + MERCS_PER_SEAT * maxi(0, seats_tier)
			return mini(int((PLANS["enterprise"] as Dictionary)["max_mercs"]), bought)
	return FREE_MERCS


static func plan_max_contracts(plan: int, contracts_tier: int) -> int:
	match plan_key(plan):
		"free":
			return FREE_CONTRACTS
		"pro":
			return PRO_CONTRACTS
		"enterprise":
			return ENTERPRISE_CONTRACTS + CONTRACTS_PER_TIER * maxi(0, contracts_tier)
	return FREE_CONTRACTS

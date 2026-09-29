class_name MercLocks

#One table for every Merc Viewer field and tab an upgrade gates. A row names the entitlement key
#SubscriptionManager.entitlements() returns, the wording the lock puts in front of "is locked."
#and the upgrade that sells it; the tier count comes from UpgradeDefs so a tier edit lands once.
#A key whose entitlement is a count carries "min", the tier the field needs.

const ENTERPRISE: String = "Mercday Enterprise"
const PRO: String = "Mercday Pro"
const LOCK_SCENE_PATH: String = "res://Scenes/GUI/Shared/FeatureLock.tscn"
const LOCK_HEIGHT: float = 20.0
const HIDDEN_SUFFIX: String = " hidden"

#Field and tab keys, held as constants so no caller spells one out.
const K_ANCESTRY: String = "ancestry"
const K_BLOODLINE: String = "bloodline"
const K_AGE: String = "age"
const K_HERITAGE: String = "heritage"
const K_PERKS: String = "perks"
const K_DRAWBACKS: String = "drawbacks"
const K_SKILLS: String = "skills"
const K_LIFEPATH: String = "lifepath"
const K_CRIMINALITY: String = "criminality"
const K_PHYSICAL: String = "physical"
const K_COGNITION: String = "cognition"
const K_VIGOR: String = "vigor"
const K_DEXTERITY: String = "dexterity"
const K_WILE: String = "wile"
const K_TOOLS: String = "tools"
const K_KNOWLEDGES: String = "knowledges"
const K_GUILD_OPINION: String = "guildOpinion"
const K_RELATIONSHIPS: String = "relationships"
const K_MERC_METRICS: String = "mercMetrics"

const ROWS: Dictionary = {
	K_ANCESTRY: {"feature": "Ancestry", "plan": ENTERPRISE, "upgrade_id": "discrim", "tier": 1},
	K_BLOODLINE: {"feature": "Bloodline", "plan": ENTERPRISE, "upgrade_id": "discrim", "tier": 2},
	K_AGE: {"feature": "Age", "plan": ENTERPRISE, "upgrade_id": "discrim", "tier": 3},
	K_HERITAGE: {"feature": "Heritage", "plan": ENTERPRISE, "upgrade_id": "background",
		"tier": 1},
	K_PERKS: {"feature": "Perks", "plan": ENTERPRISE, "upgrade_id": "background", "tier": 2},
	K_DRAWBACKS: {"feature": "Drawbacks", "plan": ENTERPRISE, "upgrade_id": "background",
		"tier": 3},
	K_SKILLS: {"feature": "Skills", "plan": ENTERPRISE, "upgrade_id": "background", "tier": 4},
	K_LIFEPATH: {"feature": "Lifepath", "plan": ENTERPRISE, "upgrade_id": "background",
		"tier": 5},
	K_CRIMINALITY: {"feature": "Criminality", "plan": ENTERPRISE, "upgrade_id": "criminal",
		"tier": 1},
	K_PHYSICAL: {"feature": "Physical Attributes", "plan": PRO, "upgrade_id": "", "tier": 1},
	K_COGNITION: {"feature": "Cognition", "plan": ENTERPRISE, "upgrade_id": "aptitude",
		"tier": 1},
	K_VIGOR: {"feature": "Vigor", "plan": ENTERPRISE, "upgrade_id": "brawn", "tier": 1},
	K_DEXTERITY: {"feature": "Dexterity", "plan": ENTERPRISE, "upgrade_id": "readiness",
		"tier": 1},
	K_WILE: {"feature": "Wile", "plan": ENTERPRISE, "upgrade_id": "personality", "tier": 1},
	K_TOOLS: {"feature": "Tools", "plan": ENTERPRISE, "upgrade_id": "skilltest", "tier": 1},
	K_KNOWLEDGES: {"feature": "Knowledges", "plan": ENTERPRISE, "upgrade_id": "education",
		"tier": 1},
	K_GUILD_OPINION: {"feature": "Guild Opinion", "plan": ENTERPRISE, "upgrade_id": "survey",
		"tier": 1},
	K_RELATIONSHIPS: {"feature": "Relationships", "plan": ENTERPRISE, "upgrade_id": "peer",
		"tier": 1},
	K_MERC_METRICS: {"feature": "Merc Metrics", "plan": ENTERPRISE, "upgrade_id": "mercmetrics",
		"tier": 2, "min": 2},
}

#The attribute key of each AttributeBox to the entitlement key that shows its number.
const ATTRIBUTE_KEYS: Dictionary = {"cognition": K_COGNITION, "dexterity": K_DEXTERITY,
	"vigor": K_VIGOR, "wile": K_WILE}

#The Merc Viewer tab key of each gated tab to its entitlement key.
const TAB_KEYS: Dictionary = {&"relationships": K_RELATIONSHIPS, &"perks": K_PERKS,
	&"drawbacks": K_DRAWBACKS, &"skills": K_SKILLS, &"metrics": K_MERC_METRICS}


static func has(key: String) -> bool:
	return ROWS.has(key)


static func row(key: String) -> Dictionary:
	return ROWS.get(key, {}) as Dictionary


static func keys() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in ROWS:
		out.append(String(key))
	return out


static func feature_of(key: String) -> String:
	return String(row(key).get("feature", ""))


static func plan_of(key: String) -> String:
	return String(row(key).get("plan", ENTERPRISE))


static func upgrade_id_of(key: String) -> String:
	return String(row(key).get("upgrade_id", ""))


static func tier_of(key: String) -> int:
	return int(row(key).get("tier", 1))


static func min_of(key: String) -> int:
	return int(row(key).get("min", 1))


#The plan rank the fallback gate needs. A row always carries an entitlement key, so the rank only
#matters to a caller that clears the key.
static func plan_rank_of(key: String) -> int:
	if plan_of(key) == PRO:
		return SubscriptionManager.Plan.PRO
	return SubscriptionManager.Plan.ENTERPRISE


static func upgrade_name_of(key: String) -> String:
	var id: String = upgrade_id_of(key)
	if id == "" or not UpgradeDefs.has_id(id):
		return ""
	return UpgradeDefs.name_of(id)


static func tiers_of(key: String) -> int:
	var id: String = upgrade_id_of(key)
	if id == "" or not UpgradeDefs.has_id(id):
		return 1
	return maxi(1, UpgradeDefs.tier_count(id))


#The caption a hidden block carries in place of its rows.
static func hidden_text(key: String) -> String:
	return feature_of(key) + HIDDEN_SUFFIX


#True when the guild may see this field. A count key needs its "min" tier; anything else is a flag.
static func entitled(key: String, ent: Dictionary) -> bool:
	if not has(key):
		return true
	var value: Variant = ent.get(key, false)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value) >= min_of(key)
	return bool(value)


static func locked(key: String, ent: Dictionary) -> bool:
	return not entitled(key, ent)


#Copies one row onto a FeatureLock. The lock is pinned visible because its owner hides the block
#the lock sits in from the entitlement key, which a fixture may set on its own. A label turns the
#icon into the wide button the lineage rows wear, where the field name has nowhere else to go.
static func apply(lock: FeatureLock, key: String, height: float = LOCK_HEIGHT,
		label: String = "") -> void:
	if lock == null or not has(key):
		return
	lock.feature = feature_of(key)
	lock.plan = plan_of(key)
	lock.entitlement = key
	lock.entitlement_tier = min_of(key)
	lock.required_plan = plan_rank_of(key)
	lock.upgrade = upgrade_name_of(key)
	lock.upgrade_id = upgrade_id_of(key)
	lock.tier = tier_of(key)
	lock.tiers = tiers_of(key)
	lock.verb = "view"
	lock.label = label
	lock.height = height
	lock.always_visible = true


static func make_lock(key: String, height: float = LOCK_HEIGHT,
		label: String = "") -> FeatureLock:
	var scene: PackedScene = load(LOCK_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var lock: FeatureLock = scene.instantiate() as FeatureLock
	apply(lock, key, height, label)
	return lock


#The LockedPage a gated tab shows in place of its page.
static func apply_page(page: LockedPage, key: String) -> void:
	if page == null or not has(key):
		return
	page.feature = feature_of(key)
	page.plan = plan_of(key)
	page.upgrade = upgrade_name_of(key)
	page.upgrade_id = upgrade_id_of(key)
	page.tier = tier_of(key)
	page.tiers = tiers_of(key)
	page.verb = "view"

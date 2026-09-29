class_name MetricsLocks

#Every subscription rule of the Metrics Viewer in one place, so the list, the viewer and the suite
#read the same answers. SubscriptionManager.entitlements() is the only source. The table carries the
#metrics keys in both spellings and set_entitlements writes both spellings of a pair, so each read
#takes the prototype's camel key first and falls back to the table's own snake one.

const GUILD_KEY: String = "metrics"
const CONTRACT_KEY: String = "contractMetrics"
const CONTRACT_SNAKE: String = "contract_metrics"
const MERC_KEY: String = "mercMetrics"
const MERC_SNAKE: String = "merc_metrics"
const SURVEY_KEY: String = "guildOpinion"
const CLIENT_KEY: String = "clientOpinion"
const SNAKE_OF: Dictionary = {"guildOpinion": "guild_opinion", "clientOpinion": "client_opinion",
	"contractMetrics": "contract_metrics", "mercMetrics": "merc_metrics"}

const ENTERPRISE_PLAN: String = "Mercday Enterprise"
const PRO_PLAN: String = "Mercday Pro"
const MERC_FEATURE: String = "Merc Metrics"
const MERC_UPGRADE_ID: String = "mercmetrics"
#The tier count of the Merc Metrics upgrade; UpgradeDefs owns the number.
static var MERC_TIERS: int = UpgradeDefs.tier_count(MERC_UPGRADE_ID)
#Tier 1 plots team averages only, tier 2 picks one merc, tier 3 opens the compare picker.
const PICK_TIER: int = 2
const COMPARE_TIER: int = 3

#One row per graph: the entitlement key that opens it and the upgrade that sells it. The upgrade
#name and its tier count come from UpgradeDefs when a reader asks for the row.
const GRAPH_LOCKS: Dictionary = {
	"Guild": {"feature": "Guild Metrics", "plan": PRO_PLAN, "entitlement": GUILD_KEY,
		"upgrade_id": "", "tier": 1},
	"Contract": {"feature": "Contract Metrics", "plan": ENTERPRISE_PLAN,
		"entitlement": CONTRACT_KEY, "upgrade_id": "contractmetrics", "tier": 1},
	"Merc": {"feature": MERC_FEATURE, "plan": ENTERPRISE_PLAN, "entitlement": MERC_KEY,
		"upgrade_id": MERC_UPGRADE_ID, "tier": 1},
}
const METRIC_UPGRADES: Dictionary = {
	"guildOpinion": {"upgrade_id": "survey"},
	"clientOpinion": {"upgrade_id": "customer"},
}


static func entitlement(camel: String, snake: String) -> Variant:
	var table: Dictionary = SubscriptionManager.entitlements()
	if table.has(camel):
		return table[camel]
	return table.get(snake, 0)


static func flag(camel: String, snake: String = "") -> bool:
	var value: Variant = entitlement(camel, _snake_of(camel) if snake == "" else snake)
	if value is bool:
		return bool(value)
	return int(value) >= 1


static func number(camel: String, snake: String = "") -> int:
	var value: Variant = entitlement(camel, _snake_of(camel) if snake == "" else snake)
	if value is bool:
		return 1 if bool(value) else 0
	return int(value)


#How many mercs the Merc graph may hold: 0 locked, 1 team averages, 2 one merc, 3 compare.
static func merc_slots() -> int:
	return number(MERC_KEY, MERC_SNAKE)


static func graph_locked(source_name: String) -> bool:
	match source_name:
		"Contract":
			return not flag(CONTRACT_KEY, CONTRACT_SNAKE)
		"Merc":
			return merc_slots() < 1
		_:
			return not flag(GUILD_KEY, GUILD_KEY)


#The FeatureLock and LockedPage copy for one graph, with the upgrade name and tier count filled in.
static func graph_lock(source_name: String) -> Dictionary:
	var row: Dictionary = GRAPH_LOCKS.get(source_name, GRAPH_LOCKS["Guild"])
	var out: Dictionary = row.duplicate()
	var id: String = String(out.get("upgrade_id", ""))
	out["upgrade"] = upgrade_name(id)
	out["tiers"] = upgrade_tiers(id)
	return out


#The upgrade name UpgradeDefs holds for an id, empty when the row names no upgrade.
static func upgrade_name(id: String) -> String:
	if id == "" or not UpgradeDefs.has_id(id):
		return ""
	return UpgradeDefs.name_of(id)


#How many tiers UpgradeDefs holds for an id; a row with no upgrade still reads one tier.
static func upgrade_tiers(id: String) -> int:
	if id == "" or not UpgradeDefs.has_id(id):
		return 1
	return maxi(1, UpgradeDefs.tier_count(id))


static func can_pick_merc() -> bool:
	return merc_slots() >= PICK_TIER


static func can_compare() -> bool:
	return merc_slots() >= COMPARE_TIER


#The embedded viewer of the Merc Viewer needs the merc pick, not the compare tier.
static func embed_unlocked() -> bool:
	return merc_slots() >= PICK_TIER


static func merc_tier_lock(tier_wanted: int) -> Dictionary:
	return {"feature": MERC_FEATURE, "plan": ENTERPRISE_PLAN, "entitlement": MERC_KEY,
		"upgrade": upgrade_name(MERC_UPGRADE_ID), "upgrade_id": MERC_UPGRADE_ID,
		"tier": tier_wanted, "tiers": upgrade_tiers(MERC_UPGRADE_ID)}


static func metric_locked(def: MetricDef) -> bool:
	if def == null or def.lock_key == "":
		return false
	return not flag(def.lock_key)


#The upgrade a locked metric row names; an unlocked row returns an empty table.
static func metric_lock(def: MetricDef) -> Dictionary:
	if def == null or def.lock_key == "":
		return {}
	var row: Dictionary = METRIC_UPGRADES.get(def.lock_key, {})
	var id: String = String(row.get("upgrade_id", def.upgrade_id))
	return {"feature": def.label, "plan": ENTERPRISE_PLAN, "entitlement": def.lock_key,
		"upgrade": upgrade_name(id), "upgrade_id": id, "tier": 1, "tiers": upgrade_tiers(id)}


static func _snake_of(camel: String) -> String:
	return String(SNAKE_OF.get(camel, camel))

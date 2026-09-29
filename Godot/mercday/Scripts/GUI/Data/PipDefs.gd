class_name PipDefs
extends RefCounted

#The level-up modes a merc can be coached into. A mode is offered when its gate key is held in
#SubscriptionManager.entitlements(); Auto has no gate and is always offered. upgrade_id and
#upgrade_tier name the tier the FeatureLock dialog sells when a locked mode is picked.

const GROUP_STANDARD := "Standard"
const GROUP_COMBAT := "Combat PIP"
const GROUP_SKILL := "Skill PIP"
const ICON_DIR := "res://Art/GUI/Icons/"

const GROUP_COLORS: Dictionary = {GROUP_STANDARD: Color("#9cc6ef"),
	GROUP_COMBAT: Color("#e8583f"), GROUP_SKILL: Color("#6cc36a")}

const MODES: Array[Dictionary] = [
	{"mode": &"Auto", "group": GROUP_STANDARD, "gate": "", "icon": "pip_auto_8x8",
		"upgrade_id": "", "upgrade_tier": 0,
		"desc": "Allow the merc to choose what's best for them each time they level up."},
	{"mode": &"Random", "group": GROUP_STANDARD, "gate": "pip", "icon": "pip_random_8x8",
		"upgrade_id": "pip", "upgrade_tier": 1,
		"desc": "Coach the merc to let chaos reign! Their level-ups will be completely randomized."},
	{"mode": &"Utility", "group": GROUP_STANDARD, "gate": "pip", "icon": "pip_utility_8x8",
		"upgrade_id": "pip", "upgrade_tier": 1,
		"desc": "Have your merc focus on features that make them useful outside of combat as they"
			+ " level up."},
	{"mode": &"Stats", "group": GROUP_STANDARD, "gate": "pip", "icon": "pip_stats_8x8",
		"upgrade_id": "pip", "upgrade_tier": 1,
		"desc": "Have your merc focus on improving their statistics and bonuses rather than gaining"
			+ " new abilities as they level up."},
	{"mode": &"Support", "group": GROUP_COMBAT, "gate": "lvSupport", "icon": "pip_support_8x8",
		"upgrade_id": "combatpip", "upgrade_tier": 1,
		"desc": "Have your merc focus on teamwork-based combat features as they level up!"},
	{"mode": &"Defensive", "group": GROUP_COMBAT, "gate": "lvDefensive",
		"icon": "pip_defensive_8x8", "upgrade_id": "combatpip", "upgrade_tier": 2,
		"desc": "Have a merc focus on defensive abilities as they level up!"},
	{"mode": &"Offensive", "group": GROUP_COMBAT, "gate": "lvOffensive",
		"icon": "pip_offensive_8x8", "upgrade_id": "combatpip", "upgrade_tier": 3,
		"desc": "Have a merc focus on offensive abilities as they level up!"},
	{"mode": &"Skills", "group": GROUP_SKILL, "gate": "pip", "icon": "pip_skills_8x8",
		"upgrade_id": "pip", "upgrade_tier": 1,
		"desc": "Direct your merc to focus on improving their skills as they level up."},
	{"mode": &"Existing Skills", "group": GROUP_SKILL, "gate": "lvExisting",
		"icon": "pip_existing_skills_8x8", "upgrade_id": "skillpip", "upgrade_tier": 1,
		"desc": "Direct your merc to focus only on improving their existing skills, where possible."},
	{"mode": &"New Skills", "group": GROUP_SKILL, "gate": "lvNewSkills",
		"icon": "pip_new_skills_8x8", "upgrade_id": "skillpip", "upgrade_tier": 2,
		"desc": "Direct your merc to always learn new skills, where possible."},
	{"mode": &"Universal", "group": GROUP_SKILL, "gate": "lvUniversal",
		"icon": "pip_universal_8x8", "upgrade_id": "skillpip", "upgrade_tier": 3,
		"desc": "Have a merc focus on broader skills as they level up!"},
	{"mode": &"Ancestral", "group": GROUP_SKILL, "gate": "lvAncestral",
		"icon": "pip_ancestral_8x8", "upgrade_id": "skillpip", "upgrade_tier": 4,
		"desc": "Have a merc focus on their ancestry as they level up!"},
	{"mode": &"Tradition", "group": GROUP_SKILL, "gate": "lvTradition",
		"icon": "pip_tradition_8x8", "upgrade_id": "skillpip", "upgrade_tier": 5,
		"desc": "Have a merc focus on their tradition as they level up!"},
	{"mode": &"Spell", "group": GROUP_SKILL, "gate": "lvSpell", "icon": "pip_spell_8x8",
		"upgrade_id": "magicpip", "upgrade_tier": 1,
		"desc": "Have a merc focus on spellcasting as they level up!"},
]

const DEFAULT_MODE := &"Auto"


static func find(mode: StringName) -> Dictionary:
	for data: Dictionary in MODES:
		if StringName(data["mode"]) == mode:
			return data
	return {}


static func has(mode: StringName) -> bool:
	return not find(mode).is_empty()


#True when the entitlements hold this mode's gate key; Auto carries no gate.
static func unlocked(mode: StringName, ent: Dictionary) -> bool:
	var data: Dictionary = find(mode)
	if data.is_empty():
		return false
	var gate: String = String(data.get("gate", ""))
	if gate == "":
		return true
	return bool(ent.get(gate, false))


static func modes_in(group: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for data: Dictionary in MODES:
		if String(data["group"]) == group:
			out.append(StringName(data["mode"]))
	return out


static func groups() -> Array[String]:
	var out: Array[String] = []
	for data: Dictionary in MODES:
		var group: String = String(data["group"])
		if not out.has(group):
			out.append(group)
	return out


static func group_color(group: String) -> Color:
	return GROUP_COLORS.get(group, Color("#f3ead7")) as Color


static func desc_of(mode: StringName) -> String:
	return String(find(mode).get("desc", ""))


static func icon_path(mode: StringName) -> String:
	var data: Dictionary = find(mode)
	if data.is_empty():
		return ""
	return ICON_DIR + String(data["icon"]) + ".png"


static func group_of(mode: StringName) -> String:
	return String(find(mode).get("group", ""))


static func upgrade_id(mode: StringName) -> String:
	return String(find(mode).get("upgrade_id", ""))


static func upgrade_tier(mode: StringName) -> int:
	return int(find(mode).get("upgrade_tier", 0))


#The upgrade display name and its tier count are held once in UpgradeDefs, so they are read from
#there instead of a second copy here that a price or tier edit would leave behind.
static func upgrade_name(mode: StringName) -> String:
	var id: String = upgrade_id(mode)
	if id == "" or not UpgradeDefs.has_id(id):
		return ""
	return UpgradeDefs.name_of(id)


static func upgrade_tiers(mode: StringName) -> int:
	var id: String = upgrade_id(mode)
	if id == "" or not UpgradeDefs.has_id(id):
		return 1
	return maxi(1, UpgradeDefs.tier_count(id))


#The wording the FeatureLock puts in front of "is locked."
static func feature_of(mode: StringName) -> String:
	if not has(mode):
		return ""
	return "%s mode" % String(mode)

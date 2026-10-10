class_name TraitFilterDefs

#Every trait a campaign or the Hiring list can target, one row each: the merc filters of
#mercDefs() and the contract filters of contractDefs() in promo-core.js. One renderer per kind
#reads these rows, so no screen holds a per-trait branch. field says where the value sits on an
#ApplicantData ("stats/" reads the stats dictionary), options are the labels and values what a
#chip stores, lock names the entitlement key that hides the row and lock_tier the tier that key
#must reach. Level, reward and uniqueness are never targetable and have no row.

const GROUPS: Array[String] = ["Value", "Identity", "Physical", "Mental"]
const KIND_SLIDER2: String = "slider2"
const KIND_TRAD: String = "trad"
const KIND_CHIPS: String = "chips"
const KIND_RANGE: String = "range"
const KIND_MIN: String = "min"
const KIND_ONE: String = "one"
const KIND_STARS2: String = "stars2"
const KIND_MODS: String = "mods"
#The plan names the "plan" entitlement carries, lowest tier first.
const PLAN_RANKS: Array[String] = ["free", "pro", "enterprise"]
#The Applied Via chip that stands for an applicant who walked in on their own.
const WALK_IN: int = ApplicantData.WALK_IN
const STAT_PREFIX: String = "stats/"
const NO_PERMIT_NOTE: String = "No Operations Permit"
#The upgrade behind the Guild Promo field locks.
const GUILD_PROMO_ID: String = "guildpromo"
const MIN_STARS: float = 0.5
const MAX_STARS: float = 5.0

#PLACEHOLDER
#Placeholder option counts, the picker history and the location relationships, per the design prototype.
const BLOODLINE_COUNT: int = 6
const HERITAGE_COUNT: int = 6
const CRIMINALITY_COUNT: int = 4
const KNOWLEDGE_COUNT: int = 6
const TOOL_COUNT: int = 6
const COMPANY_COUNT: int = 6
const EVENT_COUNT: int = 3
const CTYPE_HIST_SEED: int = 2
const LOC_HIST_SEED: int = 5
const LOCATION_RELATIONS: Array[int] = [2, 1, 3, -1, 0, -3, 1, 0, 2]
const STAT_MIN: float = 0.0
const STAT_MAX: float = 10.0
const AGE_MIN: float = 16.0
const AGE_MAX: float = 90.0
const SALARY_MIN: float = SalaryCurve.SALARY_MIN
const SALARY_MAX: float = SalaryCurve.SALARY_MAX
const SALARY_STEP: float = SalaryCurve.FINE_STEP
#The def "curve" value that puts a slider row on the SalaryCurve track.
const CURVE_SALARY: String = "salary"


#The merc filters, in design prototype order. hiring adds the Applied Via chips and the rows only applicant
#review narrows by (bloodline, heritage, criminality, age, knowledges, tools), none of which the campaign
#builder offers; job_campaigns are the Advertise Job campaigns those chips list.
static func merc_defs(hiring: bool = false,
		job_campaigns: Array[CampaignData] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_def(&"salary", "Salary Request", "Value", KIND_SLIDER2, "ask",
		{"min": SALARY_MIN, "max": SALARY_MAX, "step": SALARY_STEP, "unit": " / mo", "full_row": true,
		"curve": CURVE_SALARY}))
	if hiring:
		var labels: Array[String] = []
		var ids: Array = []
		for campaign: CampaignData in job_campaigns:
			if campaign == null or campaign.mode != CampaignData.MODE_JOB:
				continue
			labels.append(campaign.name)
			ids.append(campaign.id)
		labels.append("Walk-In")
		ids.append(WALK_IN)
		out.append(_def(&"from", "Applied Via", "Value", KIND_CHIPS, "campaign_id",
			{"options": labels, "values": ids, "full_row": true}))
	out.append(_def(&"tradition", "Tradition", "Identity", KIND_TRAD, "tradition",
		{"options": traditions(), "values": traditions(), "full_row": true}))
	out.append(_named_chips(&"ancestry", "Ancestry", "Identity", ancestry_names(), "hiringDiscrim"))
	if hiring:
		out.append(_chips(&"bloodline", "Bloodline", "Identity", "Bloodline", BLOODLINE_COUNT,
			"hiringDiscrim"))
		out.append(_chips(&"heritage", "Heritage", "Identity", "Heritage", HERITAGE_COUNT,
			"background"))
		out.append(_chips(&"criminality", "Criminality", "Identity", "Criminality",
			CRIMINALITY_COUNT, "criminal"))
		out.append(_def(&"age", "Age", "Physical", KIND_RANGE, "age",
			{"min": AGE_MIN, "max": AGE_MAX, "step": 1.0, "lock": "hiringDiscrim"}))
	out.append(_stat(&"vigor", "Min Vigor", "Physical", "brawn"))
	out.append(_stat(&"speed", "Min Speed", "Physical", "plan"))
	out.append(_stat(&"dexterity", "Min Dexterity", "Physical", "readiness"))
	out.append(_stat(&"cognition", "Min Cognition", "Mental", "aptitude"))
	out.append(_stat(&"wile", "Min Wile", "Mental", "personality"))
	if hiring:
		out.append(_chips(&"knowledges", "Knowledges", "Mental", "Knowledge", KNOWLEDGE_COUNT,
			"education"))
		out.append(_chips(&"tools", "Tools", "Mental", "Tool", TOOL_COUNT, "skilltest"))
	return out


#The contract filters of an Advertise Guild campaign. A type that picks a sponsor leads with
#that choice; the locations come from LegalManager when the build has one.
static func contract_defs(type_key: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var row: Dictionary = CampaignTypeDefs.find(type_key)
	var picks: String = String(row.get("picks", ""))
	if picks != "":
		var sponsor: bool = picks == CampaignTypeDefs.PICK_COMPANY_OR_EVENT
		var options: Array[String] = names("Company", COMPANY_COUNT)
		if sponsor:
			options.append_array(names("Event", EVENT_COUNT))
		#Sponsorship picks one company or event; Direct Sale advertises to any number of companies.
		var kind: String = KIND_ONE if sponsor else KIND_CHIPS
		out.append(_def(&"target",
			"Sponsor (Company or Event)" if sponsor else "Advertise To", "", kind, "",
			{"options": options, "values": options, "full_row": true,
			"short": "Sponsor" if sponsor else "Advertise To"}))
	out.append(_def(&"diff", "Difficulty", "", KIND_STARS2, "",
		{"min": MIN_STARS, "max": MAX_STARS, "step": MIN_STARS, "full_row": true,
		"row_locks": [_gp_lock("Min", "gpMinDifficulty", 2),
		_gp_lock("Max", "gpMaxDifficulty", 3)]}))
	var types: Array[String] = contract_type_labels()
	out.append(_def(&"ctype", "Contract Type", "", KIND_MODS, "",
		{"options": types, "values": indices(types.size()), "mods": _type_mods(types),
		"lock": "gpContractType", "upgrade_id": GUILD_PROMO_ID, "upgrade_tier": 4}))
	var places: Array[String] = location_names()
	out.append(_def(&"loc", "Locations, sets roughly how far contracts are", "", KIND_MODS, "",
		{"short": "Locations", "options": places, "values": indices(places.size()),
		"mods": _location_mods(places), "gate": "opsPermits"}))
	return out


#One Guild Promo tier lock, as a row of a def that holds two of them. It carries the same lock
#keys a def does, so locked() reads it unchanged.
static func _gp_lock(label: String, key: String, tier: int) -> Dictionary:
	return {"label": label, "lock": key, "lock_tier": 1, "upgrade_id": GUILD_PROMO_ID,
		"upgrade_tier": tier}


static func find(defs: Array[Dictionary], key: StringName, field: String = "key") -> Dictionary:
	for def: Dictionary in defs:
		if StringName(def[field]) == key:
			return def
	return {}


#The field of every row, in row order.
static func keys_of(defs: Array[Dictionary], field: String = "key") -> Array[StringName]:
	var out: Array[StringName] = []
	for def: Dictionary in defs:
		out.append(StringName(def[field]))
	return out


#The label of the row whose key matches, or an empty string when no row does.
static func label_of(defs: Array[Dictionary], key: StringName) -> String:
	return String(find(defs, key).get("label", ""))


static func in_group(defs: Array[Dictionary], group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in defs:
		if String(def["group"]) == group:
			out.append(def)
	return out


#True when the entitlement the row names has not reached the tier it asks for.
static func locked(def: Dictionary, ent: Dictionary) -> bool:
	var key: String = String(def.get("lock", ""))
	if key == "":
		return false
	return tier_of(ent, key) < maxi(1, int(def.get("lock_tier", 1)))


#The tier an entitlement stands at: a flag counts 1 when true, a plan name counts its rank.
static func tier_of(ent: Dictionary, key: String) -> int:
	var value: Variant = ent.get(key, false)
	if value is bool:
		return 1 if bool(value) else 0
	if value is int or value is float:
		return int(value)
	return maxi(0, PLAN_RANKS.find(String(value)))


#True when a stored filter value narrows anything; an untouched row never filters and never
#counts toward a group's active badge.
static func active(def: Dictionary, value: Variant) -> bool:
	if value == null:
		return false
	var kind: String = String(def["kind"])
	if kind == KIND_SLIDER2 or kind == KIND_RANGE or kind == KIND_STARS2:
		if not (value is Array):
			return false
		var pair: Array = value
		if pair.size() < 2:
			return false
		var low: float = MIN_STARS if kind == KIND_STARS2 else float(def["min"])
		var high: float = MAX_STARS if kind == KIND_STARS2 else float(def["max"])
		return float(pair[0]) > low or float(pair[1]) < high
	if kind == KIND_MIN:
		return float(value) > float(def["min"])
	if value is Array:
		return not (value as Array).is_empty()
	return true


#How many rows of a group are both readable and narrowing: the group header's count badge.
static func active_count(defs: Array[Dictionary], group: String, filters: Dictionary,
		ent: Dictionary) -> int:
	var count: int = 0
	for def: Dictionary in in_group(defs, group):
		if locked(def, ent):
			continue
		if active(def, filters.get(def["key"], null)):
			count += 1
	return count


static func traditions() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in GuiTypes.TRADITION_COLORS:
		out.append(String(key))
	return out


#The real ancestry names DataManager holds, in Ancestries.tsv order.
static func ancestry_names() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in DataManager.ancestries:
		out.append(String(key))
	return out


#The Contract Type options in ContractLibrary order, so a pick is an index into contract_type_names().
static func contract_type_labels() -> Array[String]:
	var out: Array[String] = []
	for type_name: String in ContractLibrary.contract_type_names():
		out.append(type_name.replace("_", " "))
	return out


#How many Contract Type options there are: one per ContractLibrary.contract_type_names() entry.
static func contract_type_count() -> int:
	return ContractLibrary.contract_type_names().size()


static func names(prefix: String, count: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(maxi(0, count)):
		out.append(name_at(prefix, i))
	return out


static func name_at(prefix: String, index: int) -> String:
	return "%s %d" % [prefix, index + 1]


static func indices(count: int) -> Array:
	var out: Array = []
	for i: int in range(maxi(0, count)):
		out.append(i)
	return out


#The placeholder history behind one picker module: received, completed and failed.
static func history(index: int, salt: int) -> Array[int]:
	return [(index * 7 + salt) % 12 + 1, (index * 5 + salt) % 9, (index * 3 + salt) % 4]


#The campaign places (the first nine Legal rows) LegalManager holds, or those nine from
#CampaignTypeDefs direct when the build carries no Legal autoload.
static func location_names() -> Array[String]:
	var legal: Node = legal_manager()
	if legal == null or not legal.has_method("locations"):
		return CampaignTypeDefs.locations()
	var out: Array[String] = []
	var rows: Array = legal.call("locations")
	for i: int in range(mini(rows.size(), CampaignTypeDefs.LOCATION_COUNT)):
		out.append(_loc_name(rows[i], i))
	return out if not out.is_empty() else CampaignTypeDefs.locations()


#The Legal autoload when the build carries one; screens and defs fall back without it.
static func legal_manager() -> Node:
	return ClientRegistry.autoload_node(&"LegalManager")


static func _stat(key: StringName, label: String, group: String, lock: String) -> Dictionary:
	return _def(key, label, group, KIND_MIN, STAT_PREFIX + String(key),
		{"min": STAT_MIN, "max": STAT_MAX, "step": 1.0, "lock": lock})


static func _chips(key: StringName, label: String, group: String, prefix: String, count: int,
		lock: String) -> Dictionary:
	return _named_chips(key, label, group, names(prefix, count), lock)


static func _named_chips(key: StringName, label: String, group: String, options: Array[String],
		lock: String) -> Dictionary:
	return _def(key, label, group, KIND_CHIPS, String(key),
		{"options": options, "values": options, "lock": lock})


static func _def(key: StringName, label: String, group: String, kind: String, field: String,
		extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"key": key, "label": label, "short": label, "group": group,
		"kind": kind, "field": field, "options": [], "values": [], "mods": [], "lock": "",
		"lock_tier": 1, "gate": "", "min": 0.0, "max": 0.0, "step": 1.0, "unit": "",
		"full_row": false, "row_locks": [], "upgrade_id": "", "upgrade_tier": 0}
	for entry: Variant in extra:
		row[entry] = extra[entry]
	return row


static func _type_mods(labels: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(labels.size()):
		var hist: Array[int] = history(i, CTYPE_HIST_SEED)
		out.append({"name": labels[i], "image": "Contract Image", "received": hist[0],
			"completed": hist[1], "failed": hist[2], "has_relationship": false,
			"relationship": 0, "disabled": false, "disabled_reason": ""})
	return out


#A location with no Operations Permit stays visible but greyed out and cannot be picked.
static func _location_mods(labels: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(labels.size()):
		var allowed: bool = LegalManager.has_permit(i, &"ops")
		var hist: Array[int] = history(i, LOC_HIST_SEED)
		out.append({"name": labels[i], "image": "Location Image", "received": hist[0],
			"completed": hist[1], "failed": hist[2], "has_relationship": true,
			"relationship": LOCATION_RELATIONS[i % LOCATION_RELATIONS.size()],
			"disabled": not allowed, "disabled_reason": NO_PERMIT_NOTE})
	return out


static func _loc_name(entry: Variant, index: int) -> String:
	if entry is Object:
		var obj: Object = entry
		for field: String in ["name", "location_name"]:
			if field in obj and String(obj.get(field)) != "":
				return String(obj.get(field))
	if entry is Dictionary:
		var row: Dictionary = entry
		if String(row.get("name", "")) != "":
			return String(row["name"])
	var fallback: String = CampaignTypeDefs.location_name(index)
	return fallback if fallback != "" else name_at("Location", index)

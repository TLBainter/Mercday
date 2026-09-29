class_name MercView extends RefCounted

#Everything the Merc Viewer, the lists and the Dispatch Window read about one merc, flattened off
#MercenaryData so no scene walks the engine resources. Rebuilt by GameState.refresh_views().
#Sample rows fill only the handoff fields and leave merc null. Beside the flat traits names the
#viewer tabs read perks, drawbacks, descriptors and skills, and the overview reads the lifepath chips.

#Relationship thresholds, low to high; the face is the index of the highest one reached.
const FACE_THRESHOLDS: Array[int] = [0, 3, 5, 8, 10]
#A pair that never served together reads as the middle face (G9).
const NEUTRAL_RELATION: int = 5

const ATTRIBUTE_KEYS: Array[String] = ["cognition", "dexterity", "vigor", "wile"]

var uid: int = 0
var name: String = ""
var heritage: String = ""
var level: int = 0
var tradition: String = ""
var age_group: String = ""
#PLACEHOLDER: no roster criminality record exists, so an employed merc reads blank; an
#applicant carries the value the hiring pool drew.
var criminality: String = ""
#The lineage of a view with no engine merc behind it: an applicant carries one of each.
var ancestry_text: String = ""
var bloodline_text: String = ""
var monthly_salary: int = 0
var employment_months: int = 0
var guild_opinion: int = 0
var status: int = GuiTypes.MercStatus.AVAILABLE
var status_time_left_hours: float = 0.0
var knowledges: Array[String] = []
var tools: Array[String] = []
var level_mode: String = "Auto"
var hp: int = 0
var hp_max: int = 0
var ep: int = 0
var ep_max: int = 0
var mp: int = 0
var mp_max: int = 0
var xp: int = 0
#Attribute key -> {"current": int, "max": int}; the maximum only shows in the tooltip (Q16).
var attributes: Dictionary = {}
var traits: Array[String] = []
#{"name", "description", "category", "acquired"}; acquired names the lifepath event that gave it, else "".
var perks: Array[Dictionary] = []
var drawbacks: Array[Dictionary] = []
var descriptors: Array[Dictionary] = []
#Placeholder until a skills system exists; always empty today.
var skills: Array[Dictionary] = []
#{"name", "description", "kind"} in lifepath order, at most LifepathProgression.MAX_EVENTS.
var lifepaths: Array[Dictionary] = []
#{"name", "times_used", "description"}; times_used reads merc.action_uses, the description is blank (Q19).
var actions: Array[Dictionary] = []
#{"slot": String, "name": String, "kind": String} in the Q18 order.
var equipment: Array[Dictionary] = []
var weight: float = 0.0
var weight_limit: float = 0.0
#Other merc uid -> 0..10; only pairs CampaignKnowledge holds a value for are listed.
var relationships: Dictionary = {}
#Other merc uid -> the campaign day the pair's value was first stored.
var relationship_known_since: Dictionary = {}
#Other merc uid -> the campaign day the pair's value last moved.
var relationship_last_changed: Dictionary = {}
var merc: MercenaryData = null


#Builds the view off a live merc. status and status_hours come from GameState.merc_status, the
#months from TrynnCalendar, and extras carries the placeholder fields GameState keeps per merc.
static func from_merc(m: MercenaryData, new_status: int, status_hours: float,
		months: int, extras: Dictionary = {}) -> MercView:
	var view := MercView.new()
	if m == null:
		return view
	view.merc = m
	view.uid = m.merc_uid
	view.name = m.merc_name
	view.heritage = m.heritage.heritage_name if m.heritage != null else ""
	view.level = ExperienceSystem.current_level(m)
	view.tradition = m.tradition.tradition_name if m.tradition != null else ""
	view.age_group = m.age_category
	view.monthly_salary = m.monthly_salary
	view.employment_months = maxi(0, months)
	view.guild_opinion = m.guild_opinion
	view.status = new_status
	view.status_time_left_hours = maxf(0.0, status_hours)
	view.level_mode = String(extras.get("level_mode", "Auto"))
	view.xp = m.xp
	for k: UtilityTraitData in m.knowledges:
		if k != null:
			view.knowledges.append(k.utility_name)
	for t: UtilityTraitData in m.tools:
		if t != null:
			view.tools.append(t.utility_name)
	view.hp = m.current_hp
	view.hp_max = int(m.stats.get("maximum_hit_points", 0))
	view.ep = m.current_ep
	view.ep_max = int(m.stats.get("maximum_endurance_points", 0))
	view.mp = m.current_mp
	view.mp_max = int(m.stats.get("maximum_magic_points", 0))
	for key: String in ATTRIBUTE_KEYS:
		view.attributes[key] = {
			"current": int(m.stats.get(key, 0)),
			"max": int(m.max_stats.get("max_" + key, 0)),
		}
	_add_trait_names(view.traits, m.perks)
	_add_trait_names(view.traits, m.drawbacks)
	_add_trait_names(view.traits, m.descriptors)
	view.perks = _trait_rows(m.perks, m)
	view.drawbacks = _trait_rows(m.drawbacks, m)
	view.descriptors = _trait_rows(m.descriptors, m)
	view.lifepaths = _lifepaths_of(m)
	view.actions = _actions_of(m, m.action_uses)
	view.equipment = _equipment_of(m)
	view.weight = float(Encumbrance.carried_weight(m))
	view.weight_limit = float(Encumbrance.weight_limit(m))
	_fill_relations(view, m)
	return view


#Reads a sample_data.json merc row; the engine-only fields stay at their defaults.
static func from_sample(d: Dictionary) -> MercView:
	var view := MercView.new()
	view.uid = int(d.get("id", 0))
	view.name = str(d.get("name", ""))
	view.heritage = str(d.get("heritage", ""))
	view.level = int(d.get("level", 0))
	view.tradition = str(d.get("tradition", ""))
	view.age_group = str(d.get("age_group", ""))
	view.criminality = str(d.get("criminality", ""))
	view.monthly_salary = int(d.get("monthly_salary", 0))
	view.employment_months = int(d.get("employment_months", 0))
	view.guild_opinion = int(d.get("guild_opinion", 0))
	view.status = status_from_text(str(d.get("status", "available")))
	view.status_time_left_hours = _hours_of(d.get("status_time_left", null))
	view.level_mode = str(d.get("level_mode", "Auto"))
	for k: Variant in (d.get("knowledges", []) as Array):
		view.knowledges.append(str(k))
	for t: Variant in (d.get("tools", []) as Array):
		view.tools.append(str(t))
	return view


#Reads a job applicant so the viewer can show one before hire. ApplicantData carries no salary
#history, resources, lifepath or opinion, so those fields keep their defaults; the age arrives as a
#number of years because an applicant has no life expectancy to band it with, and the status stays
#AVAILABLE because "Applicant" is a state of the viewer, not a roster status.
static func from_applicant(a: ApplicantData) -> MercView:
	var view := MercView.new()
	if a == null:
		return view
	view.uid = a.id
	view.name = a.name
	view.heritage = a.heritage
	view.level = a.level
	view.tradition = a.tradition
	view.age_group = str(a.age) if a.age > 0 else ""
	view.monthly_salary = a.ask
	view.criminality = a.criminality
	view.ancestry_text = a.ancestry
	view.bloodline_text = a.bloodline
	for key: String in ATTRIBUTE_KEYS:
		var score: int = a.stat(key)
		view.attributes[key] = {"current": score, "max": score}
	for k: String in a.knowledges:
		view.knowledges.append(k)
	for t: String in a.tools:
		view.tools.append(t)
	return view


static func status_from_text(text: String) -> int:
	match text.strip_edges().to_lower():
		"resting":
			return GuiTypes.MercStatus.RESTING
		"contract":
			return GuiTypes.MercStatus.CONTRACT
		"vacation":
			return GuiTypes.MercStatus.VACATION
	return GuiTypes.MercStatus.AVAILABLE


#The index of the highest threshold at or below the value; a value under 0 reads as the lowest face.
static func relationship_face(value: int) -> int:
	var face: int = 0
	for i: int in range(FACE_THRESHOLDS.size()):
		if value >= FACE_THRESHOLDS[i]:
			face = i
	return face


func face_for(other_uid: int) -> int:
	return relationship_face(int(relationships.get(other_uid, NEUTRAL_RELATION)))


func status_text() -> String:
	return GuiTypes.merc_status_text(status)


func tradition_color() -> Color:
	return GuiTypes.tradition_color(tradition)


#Sample rows carry {"days", "hours", "minutes"} or null when nothing is running.
static func _hours_of(entry: Variant) -> float:
	if not (entry is Dictionary):
		return 0.0
	var d: Dictionary = entry as Dictionary
	return float(int(d.get("days", 0))) * 24.0 + float(int(d.get("hours", 0))) \
		+ float(int(d.get("minutes", 0))) / 60.0


static func _add_trait_names(out: Array[String], list: Array[TraitData]) -> void:
	for data: TraitData in list:
		if data != null:
			out.append(data.trait_name)


static func _trait_rows(list: Array[TraitData], m: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for data: TraitData in list:
		if data == null:
			continue
		out.append({
			"name": data.trait_name,
			"description": data.description,
			"category": data.trait_category,
			"acquired": _acquired_from(m, data.trait_name),
		})
	return out


#The first lifepath event naming the trait among its perks or drawbacks; "" when the merc was born with it.
static func _acquired_from(m: MercenaryData, trait_full_name: String) -> String:
	for event: LifepathData in m.lifepaths:
		if event == null:
			continue
		if event.perks.has(trait_full_name) or event.drawbacks.has(trait_full_name):
			return event.event_name
	return ""


static func _lifepaths_of(m: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: LifepathData in m.lifepaths:
		if event == null:
			continue
		if out.size() >= LifepathProgression.MAX_EVENTS:
			break
		out.append({"name": event.event_name, "description": event.description,
			"kind": event.event_type})
	return out


static func _actions_of(m: MercenaryData, uses: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if m.action_set == null:
		return out
	for action: ActionData in m.action_set.actions:
		if action == null:
			continue
		out.append({
			"name": action.action_name,
			"times_used": int(uses.get(action.action_name, 0)),
			"description": "",
		})
	return out


static func _equipment_of(m: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add_slot(out, "Armor", m.equipped_armor, "armor")
	_add_slot(out, "Primary Hand", m.equipped_weapon, "weapon")
	_add_slot(out, "Secondary Hand", m.offhand_weapon, "weapon")
	for entry: Variant in m.inventory:
		if not (entry is Dictionary):
			continue
		var slot: Dictionary = entry
		_add_slot(out, "Carried", slot.get("data", null), String(slot.get("type", "item")))
	for entry: Variant in m.items:
		_add_slot(out, "Carried", entry, "item")
	for ammo_name: Variant in m.ammo_inventory:
		var rounds: int = int(m.ammo_inventory[ammo_name])
		if rounds > 0:
			out.append({"slot": "Quiver", "name": "%s x%d" % [String(ammo_name), rounds],
				"kind": "ammo"})
	return out


#Lifepath items arrive as DataManager.items rows (TraitDSL) until ItemData imports; both shapes are read.
static func _add_slot(out: Array[Dictionary], slot: String, entry: Variant, kind: String) -> void:
	if entry is ItemData:
		out.append({"slot": slot, "name": (entry as ItemData).item_name, "kind": kind})
	elif entry is Dictionary:
		var item_name: String = String((entry as Dictionary).get("item_name", ""))
		if item_name != "":
			out.append({"slot": slot, "name": item_name, "kind": kind})


#Directional relationships this merc holds toward the rest of the roster with their two campaign
#day stamps; unset pairs are left out of all three dictionaries.
static func _fill_relations(view: MercView, m: MercenaryData) -> void:
	if m.merc_uid <= 0:
		return
	for other: MercenaryData in GuildRoster.mercs:
		if other == null or other.merc_uid <= 0 or other.merc_uid == m.merc_uid:
			continue
		if not CampaignKnowledge.has_relation(m.merc_uid, other.merc_uid):
			continue
		view.relationships[other.merc_uid] = CampaignKnowledge.relation(m.merc_uid, other.merc_uid)
		view.relationship_known_since[other.merc_uid] = CampaignKnowledge.relation_known_since(
			m.merc_uid, other.merc_uid)
		view.relationship_last_changed[other.merc_uid] = CampaignKnowledge.relation_last_changed(
			m.merc_uid, other.merc_uid)

class_name Encumbrance

#Carried weight against the Weight Limit stat: at the limit costs pace, over it costs pace, dodge and AP.

const PACE_AT_LIMIT := 1
const PACE_FLOOR := 0
const ACTION_POINTS_FLOOR := 0


static func weapon_weight(w: WeaponData) -> int:
	if w == null or w.is_virtual:
		return 0
	return w.weight


#Ammo weighs one Ammo.tsv Weight per started bundle of Amount rounds, reserve plus loaded.
static func ammo_weight(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var names: Array[String] = []
	for ammo_name: String in merc.ammo_inventory:
		names.append(ammo_name)
	if merc.ammo_loaded > 0 and merc.ammo_loaded_type != "" and not names.has(merc.ammo_loaded_type):
		names.append(merc.ammo_loaded_type)
	var total: int = 0
	for ammo_name: String in names:
		var data: AmmoData = DataManager.ammo.get(ammo_name, null) as AmmoData
		if data == null:
			continue
		var rounds: int = int(merc.ammo_inventory.get(ammo_name, 0))
		if ammo_name == merc.ammo_loaded_type:
			rounds += maxi(0, merc.ammo_loaded)
		if rounds <= 0:
			continue
		var bundles: int = ceili(float(rounds) / float(maxi(1, data.amount)))
		total += bundles * data.weight
	return total


static func carried_weight(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var total: int = weapon_weight(merc.equipped_weapon) + weapon_weight(merc.offhand_weapon)
	for w: WeaponData in merc.inventory_weapons():
		total += weapon_weight(w)
	if merc.equipped_armor != null and not _armor_weight_ignored(merc):
		total += merc.equipped_armor.weight
	return total + ammo_weight(merc)


#A Weight Adjusted perk takes its own armor type out of the carried weight.
static func _armor_weight_ignored(merc: MercenaryData) -> bool:
	var token: String = "armor_weight_ignore:" + merc.equipped_armor.armor_type.to_lower()
	return WeaponArmorPerkLibrary.has_armor_perk_active(merc, token)


static func weight_limit(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return int(merc.stats.get("weight_limit", 0))


static func over_by(merc: MercenaryData) -> int:
	return carried_weight(merc) - weight_limit(merc)


#Positive amounts to subtract from pace, dodge and action points.
static func penalties_for(carried: int, limit: int) -> Dictionary:
	var over: int = carried - limit
	if over < 0:
		return {"pace": 0, "dodge": 0, "action_points": 0}
	if over == 0:
		return {"pace": PACE_AT_LIMIT, "dodge": 0, "action_points": 0}
	return {"pace": PACE_AT_LIMIT + over, "dodge": over, "action_points": over}


static func penalties(merc: MercenaryData) -> Dictionary:
	return penalties_for(carried_weight(merc), weight_limit(merc))


static func state_text(carried: int, limit: int) -> String:
	var over: int = carried - limit
	if over < 0:
		return "under"
	if over == 0:
		return "at limit"
	return "over by %d" % over


#The weight, the limit, the state and the penalties, without the merc name.
static func detail_text(merc: MercenaryData) -> String:
	var carried: int = carried_weight(merc)
	var limit: int = weight_limit(merc)
	var over: int = carried - limit
	var head: String = "%d/%d %s" % [carried, limit, state_text(carried, limit)]
	if over < 0:
		return head
	var pen: Dictionary = penalties_for(carried, limit)
	if over == 0:
		return "%s (pace -%d)" % [head, int(pen["pace"])]
	return "%s (pace -%d, dodge -%d, AP -%d)" % [head, int(pen["pace"]), int(pen["dodge"]), int(pen["action_points"])]


static func line(merc: MercenaryData) -> String:
	if merc == null:
		return ""
	return "LOADOUT: %s %s" % [merc.merc_name, detail_text(merc)]


static func short_text(merc: MercenaryData) -> String:
	var carried: int = carried_weight(merc)
	var limit: int = weight_limit(merc)
	var text: String = "wt %d/%d" % [carried, limit]
	if carried - limit >= 0:
		return "%s (%s)" % [text, state_text(carried, limit)]
	return text

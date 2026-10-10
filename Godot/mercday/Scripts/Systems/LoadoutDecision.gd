class_name LoadoutDecision

#Sheds carried weight that costs more burden than the item is worth.

const AT_LIMIT_BURDEN := 1.0
const PER_POINT_BURDEN := 2.0
const AMMO_BUNDLE_VALUE := 1.0
const NO_AMMO_RANGED_FACTOR := 0.25
const MAKESHIFT_FACTOR := 0.5
const EQUIPPED_BONUS := 1.0
const PICKUP_BURDEN_SCALE := 0.5


static func burden(over: int) -> float:
	if over < 0:
		return 0.0
	if over == 0:
		return AT_LIMIT_BURDEN
	return AT_LIMIT_BURDEN + float(over) * PER_POINT_BURDEN


static func _carries_ammo_for(merc: MercenaryData, w: WeaponData) -> bool:
	if merc == null or w == null:
		return false
	if merc.ammo_loaded > 0 and merc.ammo_loaded_type != "":
		var loaded: AmmoData = DataManager.ammo.get(merc.ammo_loaded_type, null) as AmmoData
		if loaded != null and loaded.compatible.has(w.weapon_type):
			return true
	return WeaponEvaluator.has_compatible_ammo(merc, w)


static func weapon_value(merc: MercenaryData, w: WeaponData) -> float:
	if w == null or w.is_virtual:
		return 0.0
	var value: float = WeaponEvaluator.parse_formula_for_avg(w.damage_formula_1)
	value += WeaponEvaluator.parse_formula_for_avg(w.damage_formula_2)
	if w.is_ranged and not w.is_throwable and not _carries_ammo_for(merc, w):
		value *= NO_AMMO_RANGED_FACTOR
	if w.fragility > 0:
		value *= MAKESHIFT_FACTOR
	if merc != null and w == merc.equipped_weapon:
		value += EQUIPPED_BONUS
	return value


static func _weapon_candidate(merc: MercenaryData, w: WeaponData, slot: String) -> Dictionary:
	return {"kind": "weapon", "name": w.item_name, "weight": w.weight,
			"value": weapon_value(merc, w), "weapon": w, "ammo": "", "slot": slot}


#Everything the decision may put down: weapons in any slot and reserve ammo bundles, never armor.
static func candidates(merc: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if merc == null:
		return out
	if merc.equipped_weapon != null and not merc.equipped_weapon.is_virtual:
		out.append(_weapon_candidate(merc, merc.equipped_weapon, "equipped"))
	if merc.offhand_weapon != null and not merc.offhand_weapon.is_virtual:
		out.append(_weapon_candidate(merc, merc.offhand_weapon, "offhand"))
	for w: WeaponData in merc.inventory_weapons():
		if not w.is_virtual:
			out.append(_weapon_candidate(merc, w, "inventory"))
	for ammo_name: String in merc.ammo_inventory:
		var reserve: int = int(merc.ammo_inventory[ammo_name])
		if reserve < 1:
			continue
		var data: AmmoData = DataManager.ammo.get(ammo_name, null) as AmmoData
		if data == null:
			continue
		var value: float = 0.0
		for held: WeaponData in WeaponEvaluator.get_available_weapons(merc):
			if held != null and not held.is_virtual and data.compatible.has(held.weapon_type):
				value = AMMO_BUNDLE_VALUE
				break
		out.append({"kind": "ammo", "name": ammo_name, "weight": data.weight, "value": value,
				"weapon": null, "ammo": ammo_name, "slot": "reserve"})
	var kept: Array[Dictionary] = []
	for c: Dictionary in out:
		if int(c["weight"]) > 0:
			kept.append(c)
	return kept


static func _weapon_count(merc: MercenaryData) -> int:
	var count: int = 0
	if merc.equipped_weapon != null and not merc.equipped_weapon.is_virtual:
		count += 1
	if merc.offhand_weapon != null and not merc.offhand_weapon.is_virtual:
		count += 1
	for w: WeaponData in merc.inventory_weapons():
		if not w.is_virtual:
			count += 1
	return count


static func _ammo_only(pool: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in pool:
		if str(c["kind"]) == "ammo":
			out.append(c)
	return out


#Best candidate by relief minus value at this over-weight amount; empty when nothing pays for itself.
static func _best_candidate(pool: Array[Dictionary], over: int) -> Dictionary:
	var best: Dictionary = {}
	var best_gain: float = 0.0
	for c: Dictionary in pool:
		var weight: int = int(c["weight"])
		var relief: float = burden(over) - burden(over - weight)
		var value: float = float(c["value"])
		if relief <= value:
			continue
		var gain: float = relief - value
		if best.is_empty() or gain > best_gain:
			best = c.duplicate()
			best["relief"] = relief
			best_gain = gain
	return best


static func _drop_candidate(merc: MercenaryData, c: Dictionary) -> void:
	var slot: String = str(c["slot"])
	if slot == "equipped":
		merc.equipped_weapon = null
		merc.weapon_drawn = false
		merc.ammo_loaded = 0
		merc.ammo_loaded_type = ""
		if merc.offhand_weapon != null:
			merc.equipped_weapon = merc.offhand_weapon
			merc.offhand_weapon = null
			merc.weapon_drawn = true
		elif DataManager.fight_weapon != null:
			merc.equipped_weapon = DataManager.fight_weapon
			merc.weapon_drawn = true
		return
	if slot == "offhand":
		merc.offhand_weapon = null
		return
	if slot == "inventory":
		var target: WeaponData = c["weapon"] as WeaponData
		for entry: Dictionary in merc.inventory:
			if entry.get("type") == "weapon" and entry.get("data") == target:
				merc.inventory.erase(entry)
				return
		return
	var ammo_name: String = str(c["ammo"])
	var data: AmmoData = DataManager.ammo.get(ammo_name, null) as AmmoData
	var reserve: int = int(merc.ammo_inventory.get(ammo_name, 0))
	var per_bundle: int = maxi(1, data.amount) if data != null else 1
	var left: int = reserve - mini(per_bundle, reserve)
	if left <= 0:
		merc.ammo_inventory.erase(ammo_name)
	else:
		merc.ammo_inventory[ammo_name] = left


#Drops what costs more burden than it is worth until the merc is back under its Weight Limit.
static func settle(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.is_dead or not merc.stats.has("weight_limit"):
		return lines
	var dropped: bool = false
	while true:
		var over: int = Encumbrance.over_by(merc)
		if over < 0:
			break
		var pool: Array[Dictionary] = candidates(merc)
		if _weapon_count(merc) <= 1:
			pool = _ammo_only(pool)
		var pick: Dictionary = _best_candidate(pool, over)
		if pick.is_empty():
			break
		_drop_candidate(merc, pick)
		StatCalculator.refresh(merc)
		dropped = true
		lines.append(drop_line(merc, pick))
	if dropped or Encumbrance.over_by(merc) >= 0:
		lines.append(Encumbrance.line(merc))
	return lines


#The burden points taking w would add to the merc's current load.
static func pickup_burden(merc: MercenaryData, w: WeaponData) -> float:
	if merc == null or w == null:
		return 0.0
	var over: int = Encumbrance.over_by(merc)
	return burden(over + Encumbrance.weapon_weight(w)) - burden(over)


#The packed item worth putting down to make room for w; never the equipped or offhand weapon.
static func shed_for(merc: MercenaryData, w: WeaponData) -> Dictionary:
	if merc == null or w == null:
		return {}
	var over_after: int = Encumbrance.over_by(merc) + Encumbrance.weapon_weight(w)
	var pool: Array[Dictionary] = []
	for c: Dictionary in candidates(merc):
		var slot: String = str(c["slot"])
		if slot == "inventory" or slot == "reserve":
			pool.append(c)
	if _weapon_count(merc) <= 1:
		pool = _ammo_only(pool)
	return _best_candidate(pool, over_after)


#The burden constants the loadout decision weighs a carried item against.
static func loadout_rules_line() -> String:
	return ("LOADOUT RULES: at limit %.1f, per point %.1f, ammo bundle %.1f,"
		+ " no-ammo ranged x%.2f, makeshift x%.2f, equipped +%.1f") % [
		AT_LIMIT_BURDEN, PER_POINT_BURDEN, AMMO_BUNDLE_VALUE,
		NO_AMMO_RANGED_FACTOR, MAKESHIFT_FACTOR, EQUIPPED_BONUS]


#One put-down reported as a line: the item, what it weighed and the load left after it.
static func drop_line(merc: MercenaryData, pick: Dictionary) -> String:
	return "LOADOUT DROP: %s drops %s (wt %d, value %.1f, relief %.1f) -> %d/%d" % [
		merc.merc_name, str(pick["name"]), int(pick["weight"]), float(pick["value"]),
		float(pick.get("relief", 0.0)), Encumbrance.carried_weight(merc), Encumbrance.weight_limit(merc)]

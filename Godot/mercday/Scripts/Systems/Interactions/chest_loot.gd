class_name ChestLoot extends RefCounted

#Loot a dungeon chest holds: entries stripped off a captive, handed back one Interact at a time.

const KEY := "loot"


static func entries(obs: Dictionary) -> Array:
	return obs.get(KEY, []) as Array


static func add(obs: Dictionary, entry: Dictionary) -> void:
	if obs.is_empty() or entry.is_empty():
		return
	if not obs.has(KEY):
		obs[KEY] = []
	(obs[KEY] as Array).append(entry)


static func take(obs: Dictionary, index: int) -> Dictionary:
	var list: Array = entries(obs)
	if index < 0 or index >= list.size():
		return {}
	var entry: Dictionary = list[index] as Dictionary
	list.remove_at(index)
	return entry


static func is_empty(obs: Dictionary) -> bool:
	return entries(obs).is_empty()


static func is_chest(obs: Dictionary) -> bool:
	if obs.is_empty():
		return false
	return InteractionSystem.obstacle_name(obs) == "Chest"


static func chests(field: BattlefieldArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if field == null:
		return out
	for obs: Dictionary in field.obstacles:
		if is_chest(obs):
			out.append(obs)
	return out


#Name printed for one entry; the resource name when it carries one.
static func entry_name(entry: Dictionary) -> String:
	var named := str(entry.get("name", ""))
	if named != "":
		return named
	var res: ItemData = entry.get("data") as ItemData
	if res != null and res.item_name != "":
		return res.item_name
	return "something"


#Takes every piece of gear off the merc and returns the chest entries for it.
static func strip_gear(merc: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if merc == null:
		return out
	var held: WeaponData = merc.equipped_weapon
	if held != null and not held.is_virtual:
		out.append({"type": "weapon", "name": held.item_name, "owner": merc, "data": held,
			"ammo_loaded": merc.ammo_loaded, "ammo_loaded_type": merc.ammo_loaded_type,
			"was_equipped": true})
	var off: WeaponData = merc.offhand_weapon
	if off != null and not off.is_virtual:
		out.append({"type": "weapon", "name": off.item_name, "owner": merc, "data": off,
			"ammo_loaded": 0, "ammo_loaded_type": "", "was_equipped": false})
	for entry: Dictionary in merc.inventory:
		if entry.get("type", "") != "weapon":
			continue
		var w: WeaponData = entry.get("data") as WeaponData
		if w == null or w.is_virtual:
			continue
		out.append({"type": "weapon", "name": w.item_name, "owner": merc, "data": w,
			"ammo_loaded": 0, "ammo_loaded_type": "", "was_equipped": false})
	for ammo_name: String in merc.ammo_inventory.keys():
		var amount: int = int(merc.ammo_inventory[ammo_name])
		if amount <= 0:
			continue
		out.append({"type": "ammo", "name": ammo_name, "owner": merc, "amount": amount})
	var armor: ArmorData = merc.equipped_armor
	if armor != null:
		out.append({"type": "armor", "name": armor.item_name, "owner": merc, "data": armor})
	for entry: Dictionary in merc.inventory:
		if entry.get("type", "") == "weapon":
			continue
		out.append({"type": "item", "name": entry_name(entry), "owner": merc, "data": entry})
	merc.equipped_weapon = null
	merc.offhand_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""
	merc.ammo_inventory = {}
	merc.inventory = []
	if armor != null:
		for prot_type: String in armor.protection:
			merc.passive_effects.erase("protected:" + prot_type.to_lower())
	merc.equipped_armor = null
	StatCalculator.refresh(merc)
	return out


#Entry this merc would reach for first, or -1 when the chest is empty.
static func pick_index(merc: MercenaryData, obs: Dictionary) -> int:
	var list: Array = entries(obs)
	if list.is_empty() or merc == null:
		return -1
	var want: String = ""
	var w: WeaponData = merc.equipped_weapon
	if w != null and w.is_ranged:
		want = merc.ammo_loaded_type
	var first_weapon: int = -1
	var first_ammo: int = -1
	var first_armor: int = -1
	var first_item: int = -1
	var match_ammo: int = -1
	for i: int in range(list.size()):
		var e: Dictionary = list[i] as Dictionary
		var t: String = str(e.get("type", ""))
		if t == "weapon":
			if bool(e.get("was_equipped", false)):
				return i
			if first_weapon < 0:
				first_weapon = i
		elif t == "ammo":
			if first_ammo < 0:
				first_ammo = i
			if want != "" and match_ammo < 0 and str(e.get("name", "")) == want:
				match_ammo = i
		elif t == "armor":
			if first_armor < 0:
				first_armor = i
		elif first_item < 0:
			first_item = i
	if match_ammo >= 0:
		return match_ammo
	if first_weapon >= 0:
		return first_weapon
	if first_ammo >= 0:
		return first_ammo
	if first_armor >= 0:
		return first_armor
	return first_item


#Hands one entry to a merc mid-battle; armor is only carried, never worn here.
static func give(merc: MercenaryData, entry: Dictionary, state: BattleState, lines: Array[String]) -> void:
	if merc == null or entry.is_empty():
		return
	var t: String = str(entry.get("type", ""))
	if t == "weapon":
		var w: WeaponData = entry.get("data") as WeaponData
		if w == null:
			return
		var held: WeaponData = merc.equipped_weapon
		if held == null or held.is_virtual:
			merc.equipped_weapon = w
			merc.weapon_drawn = true
			merc.ammo_loaded = int(entry.get("ammo_loaded", 0))
			merc.ammo_loaded_type = str(entry.get("ammo_loaded_type", ""))
		else:
			merc.inventory.append({"type": "weapon", "data": w})
	elif t == "ammo":
		var aname: String = str(entry.get("name", ""))
		if aname == "":
			return
		merc.ammo_inventory[aname] = int(merc.ammo_inventory.get(aname, 0)) + int(entry.get("amount", 0))
	elif t == "armor":
		var a: ArmorData = entry.get("data") as ArmorData
		if a == null:
			return
		merc.inventory.append({"type": "armor", "data": a})
	else:
		var raw: Dictionary = entry.get("data", {}) as Dictionary
		if raw.is_empty():
			return
		merc.inventory.append(raw)
	StatCalculator.refresh(merc)
	lines.append("  %s takes %s from the chest." % [BattleState.colored_name(merc, state), entry_name(entry)])


#Puts one entry back on its owner after the battle; armor goes back on.
static func restore(entry: Dictionary, fallback_owner: MercenaryData) -> void:
	if entry.is_empty():
		return
	var owner: MercenaryData = entry.get("owner") as MercenaryData
	if owner == null:
		owner = fallback_owner
	if owner == null:
		return
	var t: String = str(entry.get("type", ""))
	if t == "weapon":
		var w: WeaponData = entry.get("data") as WeaponData
		if w == null:
			return
		var held: WeaponData = owner.equipped_weapon
		if held == null or held.is_virtual:
			owner.equipped_weapon = w
			owner.ammo_loaded = int(entry.get("ammo_loaded", 0))
			owner.ammo_loaded_type = str(entry.get("ammo_loaded_type", ""))
		elif owner.offhand_weapon == null:
			owner.offhand_weapon = w
		else:
			owner.inventory.append({"type": "weapon", "data": w})
	elif t == "ammo":
		var aname: String = str(entry.get("name", ""))
		if aname == "":
			return
		owner.ammo_inventory[aname] = int(owner.ammo_inventory.get(aname, 0)) + int(entry.get("amount", 0))
	elif t == "armor":
		var a: ArmorData = entry.get("data") as ArmorData
		if a == null:
			return
		if owner.equipped_armor == null:
			_wear(owner, a)
		else:
			owner.inventory.append({"type": "armor", "data": a})
	else:
		var raw: Dictionary = entry.get("data", {}) as Dictionary
		if raw.is_empty():
			return
		owner.inventory.append(raw)
	StatCalculator.refresh(owner)


#Puts on a suit carried in the inventory; a merc already wearing one keeps it.
static func wear_carried_armor(merc: MercenaryData) -> void:
	if merc == null or merc.equipped_armor != null:
		return
	for i: int in range(merc.inventory.size()):
		var e: Dictionary = merc.inventory[i] as Dictionary
		if e.get("type", "") != "armor":
			continue
		var a: ArmorData = e.get("data") as ArmorData
		if a == null:
			continue
		merc.inventory.remove_at(i)
		_wear(merc, a)
		StatCalculator.refresh(merc)
		return


#Empties every chest on the field back onto its owners; returns the entries restored.
static func loot_all(field: BattlefieldArea, fallback_owner: MercenaryData) -> int:
	var count: int = 0
	for obs: Dictionary in chests(field):
		while not is_empty(obs):
			var e: Dictionary = take(obs, 0)
			if e.is_empty():
				break
			restore(e, fallback_owner)
			count += 1
	return count


static func _wear(merc: MercenaryData, armor: ArmorData) -> void:
	merc.equipped_armor = armor
	for prot_type: String in armor.protection:
		var eff: String = "protected:" + prot_type.to_lower()
		if not merc.passive_effects.has(eff):
			merc.passive_effects.append(eff)

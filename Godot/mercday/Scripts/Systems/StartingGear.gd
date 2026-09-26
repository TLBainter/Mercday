class_name StartingGear


#The ordinary melee weapons a starting merc can roll; the fallback draws from the same pool.
static func _starting_melee_pool() -> Array:
	return DataManager.weapons_ordinary_melee.filter(
		func(w: WeaponData) -> bool: return w.weapon_class != "Magical")


#The ordinary and common ranged weapons a starting merc can roll.
static func _starting_ranged_pool() -> Array[WeaponData]:
	var pool: Array[WeaponData] = []
	for w: WeaponData in DataManager.weapons_ordinary_ranged:
		if w.weapon_class != "Magical":
			pool.append(w)
	for w: WeaponData in DataManager.weapons_common_ranged:
		if w.weapon_class != "Magical":
			pool.append(w)
	return pool


#The armor a starting merc is strong enough to wear.
static func _starting_armor_pool(merc: MercenaryData) -> Array:
	var merc_vigor: int = int(merc.stats.get("vigor", 0))
	var pool: Array = []
	for a in DataManager.armor_ordinary_common:
		if a.vigor_requirement == 0 or merc_vigor >= a.vigor_requirement:
			pool.append(a)
	return pool


#The starting bundles a weapon can fire.
static func _compatible_ammo(w: WeaponData) -> Array:
	var pool: Array = []
	if w == null:
		return pool
	for a in DataManager.ammo_ordinary_common:
		if a.compatible.has(w.weapon_type):
			pool.append(a)
	return pool


#The lightest bundle a weapon can fire; 0 when it takes no ammo.
static func _lightest_ammo_weight(w: WeaponData) -> int:
	return _lightest_weight(_compatible_ammo(w))


#The lightest Weight in a pool of weapons, armor or ammo; 0 when the pool is empty.
static func _lightest_weight(pool: Array) -> int:
	if pool.is_empty():
		return 0
	var lightest: int = int(pool[0].weight)
	for item in pool:
		lightest = mini(lightest, int(item.weight))
	return lightest


#The lightest ranged weapon plus the lightest bundle it can fire.
static func _lightest_ranged_cost(pool: Array) -> int:
	var lightest: int = -1
	for w: WeaponData in pool:
		var cost: int = w.weight + _lightest_ammo_weight(w)
		if lightest < 0 or cost < lightest:
			lightest = cost
	return maxi(0, lightest)


#The pool entries light enough for the weight left.
static func _items_within(pool: Array, room: int) -> Array:
	var fits: Array = []
	for item in pool:
		if int(item.weight) <= room:
			fits.append(item)
	return fits


#The lightest cost of every category still in the draw, summed.
static func _lightest_total(lightest: Dictionary, categories: Array[String]) -> int:
	var total: int = 0
	for category: String in categories:
		total += int(lightest.get(category, 0))
	return total


#Draws armor, melee and ranged in a shuffled order, each fitted to the weight left.
static func step_gear(merc: MercenaryData) -> Array[String]:
	var limit: int = int(merc.stats.get("weight_limit", 0))
	var budget: int = limit - 1
	var melee_pool: Array = _starting_melee_pool()
	var ranged_pool: Array[WeaponData] = _starting_ranged_pool()
	var armor_pool: Array = _starting_armor_pool(merc)
	var lightest: Dictionary = {}
	var categories: Array[String] = []
	if not armor_pool.is_empty():
		categories.append("armor")
		lightest["armor"] = _lightest_weight(armor_pool)
	if not melee_pool.is_empty():
		categories.append("melee")
		lightest["melee"] = _lightest_weight(melee_pool)
	if not ranged_pool.is_empty():
		categories.append("ranged")
		lightest["ranged"] = _lightest_ranged_cost(ranged_pool)
	while _lightest_total(lightest, categories) > budget:
		if categories.has("ranged"):
			categories.erase("ranged")
		elif categories.has("armor"):
			categories.erase("armor")
		else:
			break
	categories.shuffle()
	var melee_w: WeaponData = null
	var ranged_w: WeaponData = null
	var ammo_pick: AmmoData = null
	var armor_pick: ArmorData = null
	var order: Array[String] = []
	var carried: int = 0
	for i: int in range(categories.size()):
		var category: String = categories[i]
		var reserve: int = 0
		for j: int in range(i + 1, categories.size()):
			reserve += int(lightest.get(categories[j], 0))
		var room: int = budget - carried - reserve
		if category == "armor":
			var armor_fits: Array = _items_within(armor_pool, room)
			if armor_fits.is_empty():
				continue
			armor_pick = armor_fits[randi() % armor_fits.size()] as ArmorData
			carried += armor_pick.weight
			order.append(category)
		elif category == "melee":
			var melee_fits: Array = _items_within(melee_pool, room)
			if melee_fits.is_empty():
				melee_fits = _items_within(melee_pool, _lightest_weight(melee_pool))
			if melee_fits.is_empty():
				continue
			melee_w = melee_fits[randi() % melee_fits.size()] as WeaponData
			carried += melee_w.weight
			order.append(category)
		else:
			var ranged_fits: Array[WeaponData] = []
			for w: WeaponData in ranged_pool:
				if w.weight + _lightest_ammo_weight(w) <= room:
					ranged_fits.append(w)
			if ranged_fits.is_empty():
				continue
			ranged_w = ranged_fits[randi() % ranged_fits.size()]
			var ammo_fits: Array = _items_within(_compatible_ammo(ranged_w), room - ranged_w.weight)
			if not ammo_fits.is_empty():
				ammo_pick = ammo_fits[randi() % ammo_fits.size()] as AmmoData
			carried += ranged_w.weight
			if ammo_pick != null:
				carried += ammo_pick.weight
			order.append(category)
	_equip_gear(merc, melee_w, ranged_w, ammo_pick, armor_pick)
	if categories.size() > 1 and Encumbrance.carried_weight(merc) >= limit:
		push_warning("MercGenerator: loadout %d/%d for %s" % [carried, limit, merc.merc_name])
	return order


#Puts the drawn gear on the merc; the melee weapon rides in the pack when a ranged one is held.
static func _equip_gear(merc: MercenaryData, melee_w: WeaponData, ranged_w: WeaponData,
		ammo_pick: AmmoData, armor_pick: ArmorData) -> void:
	if ranged_w != null:
		merc.equipped_weapon = ranged_w
		_load_starting_ammo(merc, ammo_pick)
		if melee_w != null:
			merc.inventory.append({"type": "weapon", "data": melee_w})
	elif melee_w != null:
		merc.equipped_weapon = melee_w
	if armor_pick == null:
		return
	merc.equipped_armor = armor_pick
	for prot_type: String in armor_pick.protection:
		var eff := "protected:" + prot_type.to_lower()
		if not merc.passive_effects.has(eff):
			merc.passive_effects.append(eff)


#Undoes one gear draw; only the passive effects that draw appended are erased.
static func clear_gear(merc: MercenaryData, armor_effects: Array[String]) -> void:
	merc.equipped_weapon = null
	merc.offhand_weapon = null
	var kept: Array = []
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			kept.append(entry)
	merc.inventory = kept
	merc.ammo_inventory = {}
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""
	merc.equipped_armor = null
	for eff: String in armor_effects:
		merc.passive_effects.erase(eff)


#Fills the chamber from the chosen bundle and keeps the rest in reserve.
static func _load_starting_ammo(merc: MercenaryData, chosen: AmmoData) -> void:
	var weapon := merc.equipped_weapon
	if weapon == null or chosen == null:
		return
	merc.ammo_loaded_type = chosen.item_name
	merc.ammo_loaded = chosen.amount if weapon.chamber <= 0 else mini(weapon.chamber, chosen.amount)
	var reserve: int = chosen.amount - merc.ammo_loaded
	if reserve > 0:
		merc.ammo_inventory[chosen.item_name] = reserve


#Trims the rounds carried to a cap over loaded plus reserve; a negative cap draws freely.
static func cap_carried_ammo(merc: MercenaryData, cap: int) -> void:
	if merc == null or cap < 0:
		return
	merc.ammo_loaded = mini(merc.ammo_loaded, cap)
	var room: int = cap - merc.ammo_loaded
	for ammo_name: String in merc.ammo_inventory.keys():
		var kept: int = mini(int(merc.ammo_inventory[ammo_name]), room)
		if kept <= 0:
			merc.ammo_inventory.erase(ammo_name)
			continue
		merc.ammo_inventory[ammo_name] = kept
		room -= kept


#Draws a random compatible bundle for the weapon in hand.
static func equip_starting_ammo(merc: MercenaryData) -> void:
	var pool: Array = _compatible_ammo(merc.equipped_weapon)
	if pool.is_empty():
		return
	_load_starting_ammo(merc, pool[randi() % pool.size()] as AmmoData)

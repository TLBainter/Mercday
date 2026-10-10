class_name DroppedItemStore extends RefCounted


#Adds one dropped weapon entry to the stack at pos, creating the stack when it is missing.
static func push(state: BattleState, pos: Vector2i, floor_num: int, weapon: WeaponData, ammo: int,
		ammo_type: String) -> void:
	if not state.dropped_weapons.has(pos):
		state.dropped_weapons[pos] = []
	(state.dropped_weapons[pos] as Array).append({
		"weapon": weapon,
		"ammo_loaded": ammo,
		"ammo_loaded_type": ammo_type,
		"floor": floor_num,
	})


static func drop_weapon(state: BattleState, merc: MercenaryData) -> void:
	var weapon := merc.equipped_weapon
	if weapon == null:
		return
	push(state, state.get_position(merc), state.get_floor(merc), weapon, merc.ammo_loaded, merc.ammo_loaded_type)
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""


#Returns how many weapons the merc picked back up.
static func retrieve_dropped_weapons_for(state: BattleState, merc: MercenaryData) -> int:
	if state.dropped_weapons.is_empty():
		return 0
	var merc_pos := state.get_position(merc)
	var merc_floor := state.get_floor(merc)
	var taken := 0
	for pos: Vector2i in state.dropped_weapons.keys().duplicate():
		if maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y)) <= 1:
			var kept: Array = []
			for entry: Dictionary in state.dropped_weapons[pos]:
				if int(entry.get("floor", merc_floor)) != merc_floor:
					kept.append(entry)
					continue
				merc.inventory.append({"type": "weapon", "data": entry["weapon"]})
				taken += 1
			if kept.is_empty():
				state.dropped_weapons.erase(pos)
			else:
				state.dropped_weapons[pos] = kept
	return taken


#Puts a packed weapon on the ground at the merc's cell; false when it is not in the inventory.
static func drop_packed_weapon(state: BattleState, merc: MercenaryData, weapon: WeaponData) -> bool:
	if merc == null or weapon == null:
		return false
	var found := false
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon" and entry.get("data") == weapon:
			merc.inventory.erase(entry)
			found = true
			break
	if not found:
		return false
	push(state, state.get_position(merc), state.get_floor(merc), weapon, 0, "")
	return true


#Sheds one bundle of reserve ammo; the rounds are gone, loose ammo is not modelled on the ground.
static func drop_ammo_bundle(merc: MercenaryData, ammo_name: String) -> int:
	if merc == null or ammo_name == "":
		return 0
	var reserve: int = int(merc.ammo_inventory.get(ammo_name, 0))
	if reserve <= 0:
		return 0
	var data: AmmoData = DataManager.ammo.get(ammo_name, null) as AmmoData
	var per_bundle: int = maxi(1, data.amount) if data != null else 1
	var dropped: int = mini(per_bundle, reserve)
	var left: int = reserve - dropped
	if left <= 0:
		merc.ammo_inventory.erase(ammo_name)
	else:
		merc.ammo_inventory[ammo_name] = left
	return dropped


#floor_num -1 keeps every entry; otherwise entries tagged with another floor are hidden.
static func get_dropped_weapons_at(state: BattleState, pos: Vector2i, floor_num: int = -1) -> Array:
	var stack: Array = state.dropped_weapons.get(pos, [])
	if floor_num < 0 or stack.is_empty():
		return stack
	var out: Array = []
	for entry: Dictionary in stack:
		if int(entry.get("floor", floor_num)) == floor_num:
			out.append(entry)
	return out


static func remove_dropped_weapon(state: BattleState, pos: Vector2i, entry: Dictionary) -> void:
	if not state.dropped_weapons.has(pos):
		return
	(state.dropped_weapons[pos] as Array).erase(entry)
	if (state.dropped_weapons[pos] as Array).is_empty():
		state.dropped_weapons.erase(pos)

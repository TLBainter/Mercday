class_name WeaponActionExecutor


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


static func get_draw_cost(merc: MercenaryData, weapon: WeaponData) -> int:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains("weapon_stat:draw:0"):
			return 0
	return weapon.draw


static func execute_reload(merc: MercenaryData, state: BattleState, enhancements: int = 0) -> Array[String]:
	# weapon_misfired is NOT cleared here; it resets at turn start before decisions are evaluated,
	# so reloading after a same-turn misfire is correctly allowed.
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return []
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "":
		return []
	var available: int = merc.ammo_inventory.get(ammo_type, 0)
	if available <= 0:
		return []
	if weapon.chamber <= 0:
		if merc.ammo_loaded > 0:
			return []
		merc.ammo_loaded = available
		var lines_q: Array[String] = ["  %s restocks quiver. (%d available)" % [_cn(merc, state), available]]
		lines_q.append_array(WeaponReactiveSystem.fire_trigger(merc, "after_reload", null, {}, state, enhancements))
		return lines_q
	if merc.ammo_loaded >= weapon.chamber:
		return []
	var reload_cost := weapon.load_time
	if reload_cost <= 0 or not state.can_afford(merc, reload_cost):
		return []
	var to_load := mini(weapon.chamber - merc.ammo_loaded, available)
	if to_load <= 0:
		return []
	merc.ammo_loaded += to_load
	merc.ammo_inventory[ammo_type] -= to_load
	if merc.ammo_inventory[ammo_type] <= 0:
		merc.ammo_inventory.erase(ammo_type)
	state.spend_ap(merc, reload_cost)
	var remaining: int = merc.ammo_inventory.get(ammo_type, 0)
	var lines: Array[String] = ["  %s reloads. [%d+%d]" % [_cn(merc, state), merc.ammo_loaded, remaining]]
	lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "after_reload", null, {}, state, enhancements))
	return lines


static func execute_draw(merc: MercenaryData, weapon: WeaponData, state: BattleState, enhancements: int = 0) -> Array[String]:
	if weapon == null:
		return []
	var draw_cost := state.get_cost(merc, "Draw", get_draw_cost(merc, weapon))
	if not state.can_afford(merc, draw_cost):
		return []
	if merc.equipped_weapon != weapon:
		if weapon.is_virtual:
			merc.equipped_weapon = weapon
		else:
			var found := false
			for i: int in range(merc.inventory.size()):
				var entry: Dictionary = merc.inventory[i]
				if entry.get("type") == "weapon" and entry.get("data") == weapon:
					merc.inventory.remove_at(i)
					found = true
					break
			if not found:
				return []
			merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	state.spend_ap(merc, draw_cost)
	state.record_action(merc, "Draw")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s draws %s [%dAP]" % [merc.merc_name, weapon.item_name, draw_cost])
	var lines: Array[String] = ["  %s draws %s [%dAP]" % [_cn(merc, state), weapon.item_name, draw_cost]]
	lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_draw", null, {}, state, enhancements))
	return lines


static func execute_holster(merc: MercenaryData, state: BattleState) -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var cost := state.get_cost(merc, "Holster", get_draw_cost(merc, weapon))
	if not state.can_afford(merc, cost):
		return []
	if not weapon.is_virtual:
		merc.inventory.append({"type": "weapon", "data": weapon})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	state.spend_ap(merc, cost)
	state.record_action(merc, "Holster")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("HOLSTER: %s holsters %s [%dAP]" % [merc.merc_name, weapon.item_name, cost])
	return ["  %s holsters %s [%dAP]" % [_cn(merc, state), weapon.item_name, cost]]


static func execute_drop(merc: MercenaryData, state: BattleState, cause: String = "") -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var pos := state.get_position(merc)
	state.drop_weapon(merc)
	if DataManager.fight_weapon != null:
		merc.equipped_weapon = DataManager.fight_weapon
		merc.weapon_drawn = true
	var cause_str := (" (%s)" % cause) if cause != "" else ""
	return ["  %s drops %s at (%d,%d)%s" % [_cn(merc, state), weapon.item_name, pos.x, pos.y, cause_str]]


static func execute_pickup(
		merc: MercenaryData,
		weapon_entry: Dictionary,
		weapon_pos: Vector2i,
		state: BattleState) -> Array[String]:
	var weapon: WeaponData = weapon_entry.get("weapon")
	if weapon == null:
		return []
	var still_there := false
	for e: Dictionary in state.get_dropped_weapons_at(weapon_pos):
		if e.get("weapon") == weapon:
			still_there = true
			break
	if not still_there:
		return []
	var pickup_cost := state.get_cost(merc, "PickUp", 1 + weapon.draw)
	if not state.can_afford(merc, pickup_cost):
		return []
	if merc.equipped_weapon != null and merc.weapon_drawn:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("HOLSTER: %s holsters %s to pick up %s" % [merc.merc_name, merc.equipped_weapon.item_name, weapon.item_name])
		if not merc.equipped_weapon.is_virtual:
			merc.inventory.append({"type": "weapon", "data": merc.equipped_weapon})
		merc.equipped_weapon = null
		merc.weapon_drawn = false
	state.remove_dropped_weapon(weapon_pos, weapon_entry)
	merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	merc.ammo_loaded = weapon_entry.get("ammo_loaded", 0)
	merc.ammo_loaded_type = weapon_entry.get("ammo_loaded_type", "")
	state.spend_ap(merc, pickup_cost)
	state.record_action(merc, "PickUp")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s picks up %s [%dAP]" % [merc.merc_name, weapon.item_name, pickup_cost])
	return ["  %s picks up %s. (AP: %d)" % [_cn(merc, state), weapon.item_name, pickup_cost]]

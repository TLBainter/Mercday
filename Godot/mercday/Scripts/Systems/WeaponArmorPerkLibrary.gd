class_name WeaponArmorPerkLibrary

# Tokens that are permanent stat/grant effects applied immediately on acquisition.
# All others are conditional; stored and queried at runtime.
const PERMANENT_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "immune:", "protected:", "susceptible:",
]

# Tokens that mark a perk as a combat action (not a passive).
const ACTION_PREFIXES: PackedStringArray = ["action:", "reactive_action:"]


static func get_active_weapon_perks(merc: MercenaryData) -> Array[TraitData]:
	if not merc.equipped_weapon:
		return []
	var weapon_name: String = merc.equipped_weapon.item_name
	var result: Array[TraitData] = []
	for perk: TraitData in merc.weapon_perks:
		if perk.trait_name.begins_with(weapon_name + "|"):
			result.append(perk)
	return result


static func get_weapon_actions(merc: MercenaryData) -> Array[TraitData]:
	var result: Array[TraitData] = []
	for perk: TraitData in get_active_weapon_perks(merc):
		for prefix: String in ACTION_PREFIXES:
			if perk.effect_dsl.begins_with(prefix):
				result.append(perk)
				break
	return result


static func get_weapon_passive_perks(merc: MercenaryData) -> Array[TraitData]:
	var result: Array[TraitData] = []
	for perk: TraitData in get_active_weapon_perks(merc):
		var is_action: bool = false
		for prefix: String in ACTION_PREFIXES:
			if perk.effect_dsl.begins_with(prefix):
				is_action = true
				break
		if not is_action:
			result.append(perk)
	return result


static func get_active_armor_perks(merc: MercenaryData) -> Array[TraitData]:
	if not merc.equipped_armor:
		return []
	var armor_cat: String = merc.equipped_armor.armor_class
	var result: Array[TraitData] = []
	for perk: TraitData in merc.armor_perks:
		if perk.trait_category == armor_cat:
			result.append(perk)
	return result


static func apply_permanent_armor_perks(merc: MercenaryData) -> void:
	for perk: TraitData in merc.armor_perks:
		if perk.effect_dsl == "" or perk.effect_dsl.begins_with("SPECIAL:"):
			continue
		var is_permanent: bool = false
		for token: String in perk.effect_dsl.split("|"):
			var t: String = token.strip_edges()
			for prefix: String in PERMANENT_PREFIXES:
				if t.begins_with(prefix):
					is_permanent = true
					break
			if is_permanent:
				break
		if is_permanent:
			MercGenerator._apply_dsl_to_merc(merc, perk.effect_dsl)


static func has_armor_perk_active(merc: MercenaryData, token: String) -> bool:
	for perk: TraitData in get_active_armor_perks(merc):
		if perk.effect_dsl.contains(token):
			return true
	return false


static func has_weapon_passive(merc: MercenaryData, key: String) -> bool:
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains(key):
			return true
	return false


static func is_wielding_two_handed(merc: MercenaryData) -> bool:
	if not merc.equipped_weapon:
		return false
	if merc.equipped_weapon.misc_properties.has("One-Handed"):
		return false
	for entry in merc.inventory:
		if entry.get("type") == "weapon":
			return false
	return true


static func get_two_handed_damage_bonus(merc: MercenaryData, is_thrown: bool = false) -> int:
	if not is_wielding_two_handed(merc):
		return 0
	var bonus := 0
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_two_handed:damage:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3:
				bonus += int(parts[2])
		elif is_thrown and perk.effect_dsl.begins_with("weapon_two_handed:thrown_damage:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3:
				bonus += int(parts[2])
	return bonus


static func get_effective_melee_range(merc: MercenaryData) -> int:
	if not merc.equipped_weapon:
		return 1
	var base: int = merc.equipped_weapon.melee_range
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_stat:melee_range:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3:
				base += int(parts[2])
	# also check active_states for temporary bonus
	var temp_bonus: int = merc.active_states.get("weapon_stat_melee_range_bonus", 0)
	return base + temp_bonus

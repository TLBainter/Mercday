class_name WeaponArmorPerkLibrary

# Tokens that are permanent stat/grant effects applied immediately on acquisition.
# All others are conditional; stored and queried at runtime.
const PERMANENT_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "immune:", "protected:", "susceptible:",
]

# Tokens that mark a perk as a combat action (not a passive).
const ACTION_PREFIXES: PackedStringArray = ["action:", "reactive_action:"]


#Perks explicitly granted to the merc plus the library entries for the drawn weapon's category.
static func get_active_weapon_perks(merc: MercenaryData) -> Array[TraitData]:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or weapon.is_virtual or weapon.weapon_type == "":
		return []
	var key: String = weapon.weapon_type.get_slice(" (", 0).strip_edges()
	return _merge_perks(merc.weapon_perks, DataManager.weapon_trait_library.get(key, []))


static func get_weapon_actions(merc: MercenaryData) -> Array[TraitData]:
	return _weapon_perks_by_kind(merc, true)


static func get_weapon_passive_perks(merc: MercenaryData) -> Array[TraitData]:
	return _weapon_perks_by_kind(merc, false)


#Active weapon perks whose token is an action prefix when want_action, and the rest otherwise.
static func _weapon_perks_by_kind(merc: MercenaryData, want_action: bool) -> Array[TraitData]:
	var result: Array[TraitData] = []
	for perk: TraitData in get_active_weapon_perks(merc):
		var is_action: bool = false
		for prefix: String in ACTION_PREFIXES:
			if perk.effect_dsl.begins_with(prefix):
				is_action = true
				break
		if is_action == want_action:
			result.append(perk)
	return result


#armor_trait_library is keyed by trait_category, which holds the armor_type words Light/Medium/Heavy/Bulky.
static func get_active_armor_perks(merc: MercenaryData) -> Array[TraitData]:
	var armor: ArmorData = merc.equipped_armor
	if armor == null or armor.armor_type == "":
		return []
	return _merge_perks(merc.armor_perks, DataManager.armor_trait_library.get(armor.armor_type, []))


#Granted perks first, then library perks, deduped by trait_name.
static func _merge_perks(granted: Array[TraitData], library: Variant) -> Array[TraitData]:
	var result: Array[TraitData] = []
	var seen: Dictionary = {}
	for perk: TraitData in granted:
		if perk == null or seen.has(perk.trait_name):
			continue
		seen[perk.trait_name] = true
		result.append(perk)
	for entry: Variant in (library as Array):
		var perk: TraitData = entry as TraitData
		if perk == null or seen.has(perk.trait_name):
			continue
		seen[perk.trait_name] = true
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


#True when an active weapon perk carries a "|"-separated effect token starting with prefix.
static func has_weapon_perk_prefix(merc: MercenaryData, prefix: String) -> bool:
	for perk: TraitData in get_active_weapon_perks(merc):
		for token: String in perk.effect_dsl.split("|"):
			if token.strip_edges().begins_with(prefix):
				return true
	return false


static func has_weapon_passive(merc: MercenaryData, key: String) -> bool:
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains(key):
			return true
	return false


#Both hands are on the drawn weapon whenever nothing else occupies the off hand.
static func is_wielding_two_handed(merc: MercenaryData) -> bool:
	if not merc.equipped_weapon or not merc.weapon_drawn:
		return false
	if merc.equipped_weapon.is_virtual:
		return false
	if merc.offhand_weapon != null:
		return false
	if merc.equipped_weapon.misc_properties.has("One-Handed"):
		return false
	return true


#A Protean or unmarked weapon can be held in one hand or two.
static func is_flex_grip(weapon: WeaponData) -> bool:
	if weapon == null or weapon.is_virtual:
		return false
	if weapon.misc_properties.has("One-Handed"):
		return false
	return not weapon.misc_properties.has("Two-Handed")


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
	var temp_bonus: int = merc.active_states.get("weapon_stat_melee_range_bonus", 0)
	return base + temp_bonus

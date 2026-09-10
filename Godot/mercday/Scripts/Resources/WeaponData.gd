class_name WeaponData extends ItemData

var weapon_type: String
var weight: int
var size: int = 0
var cost: int
var damage_formula_1: String
var damage_types_1: Array[String]
var damage_formula_2: String
var damage_types_2: Array[String]
var draw: int
var load_time: int
var chamber: int
var range_ranged: String
var range_thrown: String
var misfire: int
var misc_properties: Array[String]
var weapon_class: String
var resonance: String
var resonance_requirement: String
var symbiosis: String
var symbiosis_requirement: String
var fuel_type: String
var fuel_max: int
var inflict_states: Array[String] = []

var is_ranged: bool
var is_throwable: bool
var has_heavy: bool
var has_light: bool
var has_extend: bool
var melee_range: int           # 1 normally, 2 with Extend property
var ranged_intended_range: int # first number of range_ranged (e.g. 45 in "45/200")
var ranged_extended_range: int # second number; attacks here are +1 Flawed
var thrown_intended_range: int
var thrown_extended_range: int
var is_virtual: bool = false   # always-available pseudo-weapon; never stored in inventory

var fragility: int = 0           # 0 = indestructible; >0 = makeshift weapon, rolls fragility dice on each use
var current_fragility: int = 0   # runtime counter; decrements on survival roll; 0 = broken (when fragility > 0)
var base_weapon: WeaponData = null


#Fresh instance of a makeshift template: the fields a dropped copy needs, with its own fragility counter.
static func duplicate_template(base: WeaponData) -> WeaponData:
	var copy := WeaponData.new()
	copy.item_name = base.item_name
	copy.item_type = base.item_type
	copy.item_rarity = base.item_rarity
	copy.weapon_type = base.weapon_type
	copy.damage_formula_1 = base.damage_formula_1
	copy.damage_types_1 = base.damage_types_1.duplicate()
	copy.is_ranged = base.is_ranged
	copy.is_throwable = base.is_throwable
	copy.has_heavy = base.has_heavy
	copy.has_light = base.has_light
	copy.has_extend = base.has_extend
	copy.melee_range = base.melee_range
	copy.range_thrown = base.range_thrown
	copy.thrown_intended_range = base.thrown_intended_range
	copy.thrown_extended_range = base.thrown_extended_range
	copy.fragility = base.fragility
	copy.current_fragility = base.fragility
	return copy


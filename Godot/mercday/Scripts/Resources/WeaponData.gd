class_name WeaponData extends ItemData

var weapon_type: String
var weight: int
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

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
#A cut bowstring stops the weapon shooting until it is repaired.
var string_snapped: bool = false
#AP already spent toward the repair of this weapon.
var repair_ap_paid: int = 0


#Per-merc instance of a shared weapon resource; runtime flags on it never touch the template.
static func instance_copy(base: WeaponData) -> WeaponData:
	var copy := WeaponData.new()
	if base == null:
		return copy
	for entry: Dictionary in base.get_property_list():
		if (int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = base.get(str(entry["name"]))
		if value is Array or value is Dictionary:
			copy.set(str(entry["name"]), value.duplicate())
		else:
			copy.set(str(entry["name"]), value)
	return copy


#Fresh instance of a makeshift template: the fields a dropped copy needs, with its own fragility counter.
static func duplicate_template(base: WeaponData) -> WeaponData:
	var copy := instance_copy(base)
	copy.current_fragility = base.fragility
	return copy


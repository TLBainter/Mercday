class_name ConstDamageTypes

const STANDARD  = "Standard"
const ELEMENTAL = "Elemental"
const ESOTERIC  = "Esoteric"

const DAMAGE_TYPES: Dictionary = {
	"Impale":   {"category": STANDARD,  "block_min_1": true,  "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Lacerate": {"category": STANDARD,  "block_min_1": false, "dodge_min_1": true,  "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Strike":   {"category": STANDARD,  "block_min_1": false, "dodge_min_1": false, "defend_halved": true,  "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Acid":     {"category": ELEMENTAL, "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": true,  "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Electric": {"category": ELEMENTAL, "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Fire":     {"category": ELEMENTAL, "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": true,  "will_hp_floor": false},
	"Frost":    {"category": ELEMENTAL, "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Toxic":    {"category": ELEMENTAL, "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Holy":     {"category": ESOTERIC,  "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": true,  "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Rot":      {"category": ESOTERIC,  "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": false, "fire_first_point": false, "will_hp_floor": false},
	"Sonic":    {"category": ESOTERIC,  "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": true,  "fire_first_point": false, "will_hp_floor": false},
	"Will":     {"category": ESOTERIC,  "block_min_1": false, "dodge_min_1": false, "defend_halved": false, "defend_blocked": false, "dodge_blocked": false, "is_direct": true,  "fire_first_point": false, "will_hp_floor": true },
}


static func get_type(name: String) -> Dictionary:
	return DAMAGE_TYPES.get(name, {})


static func all_type_names() -> Array:
	return DAMAGE_TYPES.keys()

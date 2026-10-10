@tool
class_name AppearanceProfile extends Resource

#Appearance weights one ancestry, bloodline or tradition contributes; AppearanceRules layers and mixes them.
#Untouched parts are left out: a slot, color group or gear category with one positive weight defines its pool.

const KINDS: Array[String] = ["ancestry", "bloodline", "tradition"]
const CLOTHING_SLOTS: Array[String] = ["clothing1", "clothing2", "cloak1", "cloak2", "hat", "headband", "mask",
	"accessory", "neck", "glasses"]
const ROOT: String = "res://Resources/Appearance/Profiles"

@export var kind: String = "ancestry"
@export var profile_name: String = ""
#body part family -> weight
@export var body_weights: Dictionary = {}
#roll unit -> fill chance 0..1; an absent unit uses CharacterOdds.UNIT_ODDS
@export var slot_odds: Dictionary = {}
#slot -> {part family or CharacterOdds.NONE_ID: weight}
@export var part_weights: Dictionary = {}
#group (skin, hair, eyes, common) -> {row: weight}
@export var color_weights: Dictionary = {}
#"weapon" | "armor" -> {item_name: weight}
@export var gear_weights: Dictionary = {}


func sets_body() -> bool:
	return has_weight(body_weights)


func sets_slot(slot: String) -> bool:
	return has_weight(part_weights.get(slot, {}))


func sets_group(group: String) -> bool:
	return has_weight(color_weights.get(group, {}))


func sets_gear(category: String) -> bool:
	return has_weight(gear_weights.get(category, {}))


func is_empty() -> bool:
	if sets_body() or not slot_odds.is_empty():
		return false
	for table: Dictionary in [part_weights, color_weights, gear_weights]:
		for key: Variant in table:
			if has_weight(table[key]):
				return false
	return true


static func has_weight(weights: Variant) -> bool:
	if not (weights is Dictionary):
		return false
	for key: Variant in weights:
		if float(weights[key]) > 0.0:
			return true
	return false


static func path_for(profile_kind: String, name: String) -> String:
	var slug: String = ""
	for ch: String in name.to_lower():
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return ROOT.path_join("%s_%s.tres" % [profile_kind, slug])

@tool
class_name CharacterOdds extends RefCounted

#Default tuning for CharacterAppearance.roll; ancestry, bloodline and tradition profiles plug in through AppearanceRules.

const BODY_WEIGHTS: Dictionary = {"F": 42, "M": 43, "K": 15}
#Left out of the body roll for adults (every merc).
const KID_BODY: String = "K"
#Roll units in draw order. A unit is one slot, a "|" group (one pick across its slots) or a "&" link (one fill
#roll, then one pick per slot). Partner slots (cloak2) never roll; CharacterParts.cloak_partner fills them.
const UNITS: Array[String] = ["clothing2", "clothing1", "hair_front&hair_back", "ears", "hat", "cloak1",
	"beard", "glasses|mask", "facial_mark", "accessory|headband", "wings", "tail", "beast_ears", "neck"]
#Chance that a unit is filled when its pool sets no parts.
const UNIT_ODDS: Dictionary = {"clothing2": 1.0, "clothing1": 0.5, "hair_front&hair_back": 0.9, "ears": 0.3,
	"hat": 0.35, "cloak1": 0.15, "beard": 0.4, "glasses|mask": 0.2, "facial_mark": 0.2,
	"accessory|headband": 0.3, "wings": 0.05, "tail": 0.05, "beast_ears": 0.05, "neck": 0.2}
const PARTNER_SLOTS: Array[String] = ["cloak2"]
#Pool key for the empty choice of a unit.
const NONE_ID: String = "none"
const NO_BEARD: Array[String] = ["F", "K"]
#Groups rolled once per character and shared by every part; any other group rolls per part region.
const SHARED_GROUPS: Array[String] = ["skin", "hair", "eyes"]


static func unit_slots(unit: String) -> Array[String]:
	var out: Array[String] = []
	var sep: String = "|" if is_group(unit) else "&"
	for slot: String in unit.split(sep):
		out.append(slot)
	return out


#"" for body, partner slots and unknown slots.
static func unit_of(slot: String) -> String:
	for unit: String in UNITS:
		if slot in unit_slots(unit):
			return unit
	return ""


static func is_group(unit: String) -> bool:
	return unit.contains("|")


static func is_link(unit: String) -> bool:
	return unit.contains("&")

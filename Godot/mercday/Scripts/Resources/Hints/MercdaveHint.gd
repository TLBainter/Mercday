class_name MercdaveHint extends Resource

#One MercDave hint. The file name is its TSVs/Mercdave.tsv row id; label, text and Tell Me More text
#live only in that row and HintBook reads them. Faces: -5..5 opinion, 20-23 devil, 30 unselected.

const FACE_UNSET: int = -99
const FACE_UNSELECTED: int = 30
const DEVIL_IDS: Dictionary = {20: "face_devil_frown", 21: "face_devil_smile", 22: "face_devil_rage",
	23: "face_devil_laugh"}

@export var trigger: HintTrigger
@export_enum("Pick a face:-99", "-5:-5", "-4:-4", "-3:-3", "-2:-2", "-1:-1", "0:0", "+1:1", "+2:2", "+3:3",
	"+4:4", "+5:5", "Devil Frown:20", "Devil Smile:21", "Devil Rage:22", "Devil Laugh:23",
	"Unselected:30") var face: int = FACE_UNSET
@export_enum("Same as hint:-99", "-5:-5", "-4:-4", "-3:-3", "-2:-2", "-1:-1", "0:0", "+1:1", "+2:2", "+3:3",
	"+4:4", "+5:5", "Devil Frown:20", "Devil Smile:21", "Devil Rage:22", "Devil Laugh:23",
	"Unselected:30") var more_face: int = FACE_UNSET


func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())


#The face while Tell Me More shows: more_face, else the hint face.
func more_level() -> int:
	return face if more_face == FACE_UNSET else more_face


#The atlas id a face value draws: the outline opinion twin for -5..5, a devil face, else face_unselected_o.
static func icon_id(level: int) -> String:
	if DEVIL_IDS.has(level):
		return String(DEVIL_IDS[level])
	return Icons.face_id(level, true)

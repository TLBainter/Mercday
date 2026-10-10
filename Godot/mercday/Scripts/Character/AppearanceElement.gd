@tool
class_name AppearanceElement extends Resource

#One filled slot of a CharacterAppearance: the part and a gradient row per mask region ("r,g,b" -> {group, row}).
#Shared groups (CharacterOdds.SHARED_GROUPS) store row -1 and take the parent's shared row.

@export var slot: String = ""
@export var part_id: String = ""
@export var colors: Dictionary = {}


#{"group", "row"} for one region with the shared row substituted; empty when the key is unknown or unrolled.
func row_for(rgb_key: String, shared: Dictionary) -> Dictionary:
	if not colors.has(rgb_key):
		return {}
	var entry: Dictionary = colors[rgb_key]
	var group: String = String(entry.get("group", CharacterParts.DEFAULT_GROUP))
	var row: int = int(entry.get("row", -1))
	if row < 0:
		row = int(shared.get(group, -1))
	return {"group": group, "row": row} if row >= 0 else {}

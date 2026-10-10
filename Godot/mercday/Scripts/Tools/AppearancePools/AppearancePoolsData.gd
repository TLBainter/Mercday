@tool
class_name AppearancePoolsData extends RefCounted

#TSV reads for the Appearance Pools editor, through TsvReader because the editor has no DataManager.
#Ancestries.tsv holds the ancestries, a blank row, then the bloodlines.

const ANCESTRIES_PATH: String = "res://TSVs/Ancestries.tsv"
const TRADITIONS_PATH: String = "res://TSVs/Traditions.tsv"
const WEAPONS_PATH: String = "res://TSVs/Weapons.tsv"
const ARMOR_PATH: String = "res://TSVs/Armor.tsv"
const WEAPON_NAME_COLUMN: int = 1
const ARMOR_NAME_COLUMN: int = 0
const SIZE_HEADER: String = "Size"
const BLOODLINES_HEADER: String = "Possible Bloodlines"
#Size N/A counts as an adult size.
const DEFAULT_SIZE: int = 2


#{"ancestry": names, "bloodline": names, "tradition": names, "sizes": {ancestry: int}, "parents": {bloodline: ancestry}}
static func load_lists() -> Dictionary:
	var ancestries: Array[String] = []
	var bloodlines: Array[String] = []
	var sizes: Dictionary = {}
	var parents: Dictionary = {}
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(ANCESTRIES_PATH)
	var size_col: int = -1
	var parent_col: int = -1
	if not rows.is_empty():
		size_col = rows[0].find(SIZE_HEADER)
		parent_col = rows[0].find(BLOODLINES_HEADER)
	var past_blank: bool = false
	for i: int in range(1, rows.size()):
		var row_name: String = TsvReader.row_get(rows[i], 0)
		if row_name.is_empty():
			past_blank = past_blank or not ancestries.is_empty()
			continue
		if past_blank:
			_add_unique(bloodlines, row_name)
			continue
		_add_unique(ancestries, row_name)
		sizes[row_name] = TsvReader.cell_int(rows[i], size_col, DEFAULT_SIZE) if size_col >= 0 else DEFAULT_SIZE
		if parent_col < 0:
			continue
		for bloodline: String in TsvReader.split_field(TsvReader.row_get(rows[i], parent_col)):
			if not parents.has(bloodline):
				parents[bloodline] = row_name
	var traditions: Array[String] = []
	for row: PackedStringArray in TsvReader.data_rows(TRADITIONS_PATH, 0):
		_add_unique(traditions, TsvReader.row_get(row, 0))
	return {"ancestry": ancestries, "bloodline": bloodlines, "tradition": traditions, "sizes": sizes,
		"parents": parents}


#"weapon" or "armor": the item names a tradition's gear weights can name.
static func item_names(category: String) -> Array[String]:
	var out: Array[String] = []
	var weapon: bool = category == "weapon"
	var column: int = WEAPON_NAME_COLUMN if weapon else ARMOR_NAME_COLUMN
	for row: PackedStringArray in TsvReader.data_rows(WEAPONS_PATH if weapon else ARMOR_PATH, column):
		var item: String = TsvReader.row_get(row, column)
		if not (weapon and MakeshiftTemplates.BASES.has(item)):
			_add_unique(out, item)
	return out


static func _add_unique(list: Array[String], value: String) -> void:
	if not list.has(value):
		list.append(value)

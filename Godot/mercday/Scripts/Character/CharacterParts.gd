@tool
class_name CharacterParts extends RefCounted

#Read side of the parts library CharacterPartsBuilder writes: the index, parts by slot and body gender,
#base/mask image pairs and palette gradient rows, all cached.

const ROOT: String = "res://Art/Character/Parts"
const INDEX_FILE: String = "parts_index.json"
const CELL: Vector2i = CharacterPartsBuilder.CELL
const PAIR_CAP: int = 64
const DEFAULT_GROUP: String = "common"
#U parts fit adult bodies only; kid sheets use their own proportions.
const UNISEX_FITS: Array[String] = ["F", "M"]
#Ids are PACK_GENDER_SV_name; a family is the id with the gender token replaced by this, scoped to a slot.
const FAMILY_TOKEN: String = "X"
const CLOAK_BACK: String = "Cloak1"
const CLOAK_FRONT: String = "Cloak2"
const CLOAK_FRONT_SLOT: String = "cloak2"
#Designer colors appended after a palette's base rows: {"skin": ["#rrggbb", ...], ...}
const CUSTOM_COLORS_FILE: String = "res://Resources/Appearance/custom_colors.json"

static var _index: Dictionary = {}
static var _by_id: Dictionary = {}
static var _by_slot: Dictionary = {}
static var _pairs: Dictionary = {}
static var _pair_order: Array[String] = []
static var _palettes: Dictionary = {}
static var _rows: Dictionary = {}
static var _families: Dictionary = {}
static var _family_lookup: Dictionary = {}
static var _custom: Dictionary = {}
static var _custom_loaded: bool = false


static func index() -> Dictionary:
	if not _index.is_empty():
		return _index
	var path: String = ROOT.path_join(INDEX_FILE)
	if not FileAccess.file_exists(path):
		push_warning("CharacterParts: missing %s" % path)
		return _index
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("CharacterParts: %s does not parse" % path)
		return _index
	_index = parsed as Dictionary
	for p: Dictionary in _index.get("parts", []):
		for r: Dictionary in p.get("regions", []):
			var key: Array = r.get("key", [0, 0, 0]) as Array
			r["key"] = [int(key[0]), int(key[1]), int(key[2])]
		_by_id[String(p.get("id", ""))] = p
	for g: String in (_index.get("palettes", {}) as Dictionary).keys():
		var pal: Dictionary = _index["palettes"][g]
		pal["rows"] = int(pal.get("rows", 0))
	return _index


static func fits(part_gender: String, body_gender: String) -> bool:
	return part_gender == body_gender or (part_gender == "U" and body_gender in UNISEX_FITS)


static func parts(slot: String, gender: String) -> Array[Dictionary]:
	var cache_key: String = slot + "|" + gender
	if _by_slot.has(cache_key):
		return _by_slot[cache_key]
	var found: Array[Dictionary] = []
	for p: Dictionary in index().get("parts", []):
		if String(p.get("slot", "")) == slot and fits(String(p.get("gender", "")), gender):
			found.append(p)
	_by_slot[cache_key] = found
	return found


static func part(id: String) -> Dictionary:
	index()
	return _by_id.get(id, {})


static func family(id: String) -> String:
	var tokens: PackedStringArray = id.split("_")
	if tokens.size() < 3:
		return id
	tokens[1] = FAMILY_TOKEN
	return "_".join(tokens)


#One entry per family of the slot in index order: {"family", "slot", "pack", "genders", "ids"}.
static func families(slot: String) -> Array[Dictionary]:
	if _families.has(slot):
		return _families[slot]
	var found: Array[Dictionary] = []
	var lookup: Dictionary = {}
	for p: Dictionary in index().get("parts", []):
		if String(p.get("slot", "")) != slot:
			continue
		var id: String = String(p.get("id", ""))
		var fam: String = family(id)
		if not lookup.has(fam):
			var genders: Array[String] = []
			var ids: Array[String] = []
			var entry: Dictionary = {"family": fam, "slot": slot, "pack": String(p.get("pack", "")),
				"genders": genders, "ids": ids}
			lookup[fam] = entry
			found.append(entry)
		(lookup[fam]["genders"] as Array[String]).append(String(p.get("gender", "")))
		(lookup[fam]["ids"] as Array[String]).append(id)
	_families[slot] = found
	_family_lookup[slot] = lookup
	return found


#The member of the slot's family that fits the body gender, an exact gender before U; "" if none.
static func family_member(slot: String, fam: String, gender: String) -> String:
	families(slot)
	var entry: Dictionary = (_family_lookup[slot] as Dictionary).get(fam, {})
	if entry.is_empty():
		return ""
	var genders: Array[String] = entry["genders"]
	var ids: Array[String] = entry["ids"]
	var unisex: String = ""
	for i: int in range(ids.size()):
		if genders[i] == gender:
			return ids[i]
		if unisex.is_empty() and fits(genders[i], gender):
			unisex = ids[i]
	return unisex


#The cloak2 id or family drawn over a cloak1 id or family; "" when the pack has no front half.
static func cloak_partner(id_or_family: String) -> String:
	if not id_or_family.contains(CLOAK_BACK):
		return ""
	var partner: String = id_or_family.replace(CLOAK_BACK, CLOAK_FRONT)
	if String(part(partner).get("slot", "")) == CLOAK_FRONT_SLOT:
		return partner
	families(CLOAK_FRONT_SLOT)
	return partner if (_family_lookup[CLOAK_FRONT_SLOT] as Dictionary).has(partner) else ""


#[base 576x384, mask 576x384 or null], both RGBA8.
static func load_pair(id: String) -> Array[Image]:
	if _pairs.has(id):
		return _pairs[id]
	var pair: Array[Image] = []
	var p: Dictionary = part(id)
	if p.is_empty():
		return pair
	var sheet: Image = load_png(ROOT.path_join(String(p["file"])))
	if sheet == null:
		return pair
	pair.append(sheet.get_region(Rect2i(Vector2i.ZERO, CELL)))
	pair.append(sheet.get_region(Rect2i(Vector2i(CELL.x, 0), CELL)) if bool(p.get("has_mask", false)) else null)
	_pairs[id] = pair
	_pair_order.append(id)
	if _pair_order.size() > PAIR_CAP:
		_pairs.erase(_pair_order.pop_front())
	return pair


#Rows in the group's palette PNG.
static func base_rows(group: String) -> int:
	var pal: Dictionary = index().get("palettes", {}).get(group, {})
	return int(pal.get("rows", 0))


static func custom_colors(group: String) -> PackedColorArray:
	if not _custom_loaded:
		_custom_loaded = true
		_custom = {}
		if FileAccess.file_exists(CUSTOM_COLORS_FILE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_COLORS_FILE))
			if parsed is Dictionary:
				for g: Variant in parsed:
					var colors := PackedColorArray()
					for text: Variant in (parsed[g] as Array if parsed[g] is Array else []):
						colors.append(Color.html(String(text)))
					_custom[String(g)] = colors
			else:
				push_warning("CharacterParts: %s does not parse" % CUSTOM_COLORS_FILE)
	return _custom.get(group, PackedColorArray())


#Saves the group's custom colors (empty erases the group) and drops the cached rows.
static func set_custom_colors(group: String, colors: PackedColorArray) -> Error:
	custom_colors(group)
	var data: Dictionary = {}
	for g: String in _custom:
		data[g] = _custom[g]
	if colors.is_empty():
		data.erase(group)
	else:
		data[group] = colors
	var out: Dictionary = {}
	var groups: Array = data.keys()
	groups.sort()
	for g: Variant in groups:
		var texts: Array[String] = []
		for c: Color in data[g] as PackedColorArray:
			texts.append("#" + c.to_html(false))
		out[String(g)] = texts
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(CUSTOM_COLORS_FILE.get_base_dir()))
	if dir_err != OK:
		return dir_err
	var file: FileAccess = FileAccess.open(CUSTOM_COLORS_FILE, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out, "\t") + "\n")
	file.close()
	_custom_loaded = false
	_custom = {}
	_rows.clear()
	return OK


static func palette_rows(group: String) -> int:
	return base_rows(group) + custom_colors(group).size()


#One 256x1 gradient; row is clamped into the group's range. Rows past the PNG are custom colors ramped like row 0.
static func palette_row(group: String, row: int) -> Image:
	var count: int = palette_rows(group)
	var base: int = base_rows(group)
	if count <= 0 or base <= 0:
		return null
	row = clampi(row, 0, count - 1)
	var cache_key: String = "%s|%d" % [group, row]
	if _rows.has(cache_key):
		return _rows[cache_key]
	if row >= base:
		var template: Image = palette_row(group, 0)
		if template == null:
			return null
		var ramp: Image = PaletteRamp.generate(template, custom_colors(group)[row - base])
		_rows[cache_key] = ramp
		return ramp
	if not _palettes.has(group):
		var file: String = String(index()["palettes"][group].get("file", ""))
		var img: Image = load_png(ROOT.path_join(file))
		if img == null:
			return null
		_palettes[group] = img
	var line: Image = (_palettes[group] as Image).get_region(Rect2i(0, row, 256, 1))
	_rows[cache_key] = line
	return line


#Raw PNG bytes to an RGBA8 Image; the library files use the keep importer, so load() never sees them.
static func load_png(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img: Image = Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


static func reset() -> void:
	_index = {}
	_by_id.clear()
	_by_slot.clear()
	_pairs.clear()
	_pair_order.clear()
	_palettes.clear()
	_rows.clear()
	_families.clear()
	_family_lookup.clear()
	_custom = {}
	_custom_loaded = false
